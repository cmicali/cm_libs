# The self-test's config: every key, with a subset.

STRINGS_ROOT=.

STRINGS_REGISTRY=Sources/FixtureStrings.h
STRINGS_MACROS=STR_
STRINGS_CATALOG=Localizable.xcstrings
STRINGS_SOURCES=(Sources)
STRINGS_SKIP=('*/Generated/*')
STRINGS_CATALOGS=(Localizable.xcstrings InfoPlist.xcstrings)
STRINGS_UPDATE='make strings'
STRINGS_GUIDE='The fixture has no conventions.'

STRINGS_SUBSET=extension
STRINGS_SUBSET_KEYS=extension.
STRINGS_SUBSET_MACROS=STR_EXTENSION_
STRINGS_SUBSET_CATALOG=Extension/Localizable.xcstrings
STRINGS_SUBSET_SOURCES=(Extension)
