.PHONY: setup generate build clean open

# Install xcodegen if needed, then generate the Xcode project
setup:
	@which xcodegen > /dev/null 2>&1 || brew install xcodegen
	xcodegen generate

# Regenerate project (e.g. after adding new source files)
generate:
	xcodegen generate

# Build from command line (Release)
build:
	xcodebuild -project Guardian.xcodeproj -scheme Guardian -configuration Release build

# Open the project in Xcode
open:
	open Guardian.xcodeproj

clean:
	xcodebuild -project Guardian.xcodeproj -scheme Guardian clean
	rm -rf build/
