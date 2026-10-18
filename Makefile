# cm_libs: build, test and check every piece on its own.
# Every target that builds regenerates the project first.

PROJECT := cm_libs.xcodeproj
DERIVED := build/DerivedData

.PHONY: help project test build-ios consumer check-pieces clean

# Every target, with the first sentence of its comment.
help:
	@awk '/^# /{c=substr($$0,3)} /^[a-z-]+:/{sub(":.*","",$$1); if (c) printf "  %-14s %s\n", $$1, c; c=""}' Makefile

# Generates the Xcode project from project.yml.
project:
	xcodegen generate --quiet

# Runs every piece's tests on macOS, Debug, with the headermap off.
test: project
	rm -rf build/TestResults.xcresult
	xcodebuild test -project $(PROJECT) -scheme cm_libs -destination 'platform=macOS' \
		-derivedDataPath $(DERIVED) -resultBundlePath build/TestResults.xcresult -quiet
	@python3 -I scripts/checks/test-summary.py build/TestResults.xcresult

# Builds every piece for the iOS simulator, so an AppKit leak fails here.
build-ios: project
	xcodebuild build -project $(PROJECT) -scheme cm_libs -destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(DERIVED) -quiet

# Builds and runs a minimal app that takes the pieces as another app would.
consumer:
	cd Tests/Consumer && xcodegen generate --quiet
	xcodebuild build -project Tests/Consumer/Consumer.xcodeproj -scheme Consumer -configuration Release \
		-derivedDataPath build/ConsumerDerivedData -quiet
	build/ConsumerDerivedData/Build/Products/Release/Consumer

# Checks the piece rules, then breaks each rule in a copy to prove the check fails.
check-pieces:
	python3 -I scripts/checks/check-pieces.py
	python3 -I scripts/checks/check-pieces-test.py

# Removes build output and the generated project.
clean:
	rm -rf build $(PROJECT)
