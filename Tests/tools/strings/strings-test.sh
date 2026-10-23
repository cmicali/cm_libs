#!/bin/bash
#
# The strings tools' self-test: each case runs the scripts over a fresh copy
# of Fixture/ and checks the exit status and a line of the output.
#
# Usage: Tests/tools/strings/strings-test.sh   (or: make test-strings)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="$(cd "$HERE/../../../tools/strings" && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
CASES=0
COPIES=0
COPY=""

fresh() {
    COPIES=$((COPIES + 1))
    COPY="$WORK/$COPIES"
    cp -R "$HERE/Fixture" "$COPY"
}

# expect <name> <exit status> <text the output must contain> <command...>
expect() {
    local name="$1" status="$2" text="$3" got=0 output
    shift 3
    CASES=$((CASES + 1))
    output=$("$@" 2>&1) || got=$?
    if [ "$got" != "$status" ] || ! grep -qF -- "$text" <<<"$output"; then
        echo "FAIL: $name: expected exit $status and \"$text\", got exit $got:"
        sed 's/^/    /' <<<"$output"
        FAILURES=$((FAILURES + 1))
    fi
}

# add_macro <line>: a registry entry, before the header's closing #endif.
add_macro() {
    sed -i '' -e "\$i\\
$1
" "$COPY/Sources/FixtureStrings.h"
}

set_json() {
    jq --indent 2 "$2" "$COPY/$1" > "$COPY/$1.tmp" && mv "$COPY/$1.tmp" "$COPY/$1"
}

extract() { "$TOOLS/extract-strings.sh" "$COPY/strings-config.sh" "$@"; }
translations() { "$TOOLS/check-translations.sh" "$COPY/strings-config.sh" "$@"; }

fresh
expect "the fixture is in sync" 0 "string catalogs are in sync" extract --check
expect "the fixture is translated" 0 "4 keys across 2 catalogs translated into all 2 languages" translations
expect "the languages are the catalog's" 0 "$(printf 'de\nen')" "$TOOLS/catalog-languages.sh" "$COPY/strings-config.sh"
expect "extraction counts the keys" 0 "3 keys in Localizable.xcstrings, 1 of them in the extension's" extract
CASES=$((CASES + 1))
for catalog in Localizable.xcstrings Extension/Localizable.xcstrings InfoPlist.xcstrings; do
    if ! cmp -s "$HERE/Fixture/$catalog" "$COPY/$catalog"; then
        echo "FAIL: extraction rewrote $catalog"
        diff -u "$HERE/Fixture/$catalog" "$COPY/$catalog" | sed 's/^/    /'
        FAILURES=$((FAILURES + 1))
    fi
done

fresh
add_macro '#define STR_NEW NSLS(@"greeting.new", @"New", @"A new key.")'
expect "a new key makes the catalog stale" 1 "error: Localizable.xcstrings is out of date — run: make strings" extract --check
expect "extraction adds the new key" 0 "4 keys in Localizable.xcstrings" extract
expect "the new key is shielded and translated in English" 0 '"manual translated New"' \
    jq '.strings["greeting.new"] | "\(.extractionState) \(.localizations.en.stringUnit.state) \(.localizations.en.stringUnit.value)"' \
    "$COPY/Localizable.xcstrings"
expect "the new key is missing German" 1 "Localizable.xcstrings  greeting.new  missing: de" translations
expect "the guide follows the report" 1 "  The fixture has no conventions." translations
expect "GitHub mode warns instead" 0 "::warning title=Untranslated key::Localizable.xcstrings greeting.new is missing de" \
    translations --github

fresh
sed -i '' 's/@"Goodbye"/@"Bye"/' "$COPY/Sources/FixtureStrings.h"
expect "a reworded default updates English" 0 "3 keys in Localizable.xcstrings" extract
expect "a reword flips the other languages" 0 '"Bye needs_review"' \
    jq '.strings["greeting.bye"].localizations | "\(.en.stringUnit.value) \(.de.stringUnit.state)"' "$COPY/Localizable.xcstrings"
expect "a needs_review unit is reported, never fatal" 0 "1 key(s) marked needs_review" translations

fresh
add_macro '#define STR_TWICE NSLS(@"greeting.bye", @"Farewell", @"The same key again.")'
expect "one key with two defaults fails" 1 'greeting.bye: "Farewell", "Goodbye"' extract --check

fresh
set_json Localizable.xcstrings '.strings["greeting.hello"].localizations.de.stringUnit.value = "Hallo"'
expect "a translation losing a specifier fails" 1 "greeting.hello: de" extract --check

fresh
echo 'let other = "STR_GREETING"' > "$COPY/Extension/FixtureStray.swift"
expect "an extension source outside its keys fails" 1 \
    "error: extension sources reference keys outside extension.*, which the extension's own catalog does not carry:" extract --check

fresh
set_json Extension/Localizable.xcstrings 'del(.strings["extension.title"])'
expect "a stale subset catalog fails" 1 "error: Extension/Localizable.xcstrings is out of date — run: make strings" extract --check

fresh
sed -i '' '/^STRINGS_SUBSET/d' "$COPY/strings-config.sh"
rm "$COPY/Extension/Localizable.xcstrings"
expect "a config with no subset counts one catalog" 0 "3 keys in Localizable.xcstrings" extract
CASES=$((CASES + 1))
if [ -e "$COPY/Extension/Localizable.xcstrings" ] || grep -q "of them" <<<"$(extract)"; then
    echo "FAIL: a config with no subset still wrote or counted one"
    FAILURES=$((FAILURES + 1))
fi

fresh
sed -i '' 's/^STRINGS_MACROS=STR_$/STRINGS_MACROS=TXT_/' "$COPY/strings-config.sh"
# TRAP: it fails silently. Under pipefail the empty grep stops the script
# before the "no TXT_* macros" message can print.
expect "a registry with none of the config's macros fails" 1 "" extract --check

expect "no config is a usage error" 2 "usage: extract-strings.sh <config> [--check]" "$TOOLS/extract-strings.sh"

if [ "$FAILURES" -gt 0 ]; then
    echo "strings tests: $FAILURES of $CASES cases failed"
    exit 1
fi
echo "strings tests OK: $CASES cases"
