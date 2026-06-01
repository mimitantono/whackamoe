BUILD_NUMBER := $(shell expr $(shell git rev-list --count HEAD) + 1)
VERSION      := $(shell grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
APK_OUT      := build/app/outputs/flutter-apk
AAB_OUT      := build/app/outputs/bundle/release

.PHONY: release release-aab clean

## Build a signed release APK for sideloading / direct device install.
release:
	@echo "Building $(VERSION)+$(BUILD_NUMBER) (APK)…"
	flutter build apk --release \
	    --no-tree-shake-icons \
	    --build-name=$(VERSION) \
	    --build-number=$(BUILD_NUMBER)
	mv $(APK_OUT)/app-release.apk $(APK_OUT)/whackamoe-$(VERSION)-$(BUILD_NUMBER).apk
	@echo "✓  $(APK_OUT)/whackamoe-$(VERSION)-$(BUILD_NUMBER).apk"

## Build a release AAB for Google Play upload.
release-aab:
	@echo "Building $(VERSION)+$(BUILD_NUMBER) (AAB)…"
	flutter build appbundle --release \
	    --no-tree-shake-icons \
	    --build-name=$(VERSION) \
	    --build-number=$(BUILD_NUMBER)
	mv $(AAB_OUT)/app-release.aab $(AAB_OUT)/whackamoe-$(VERSION)-$(BUILD_NUMBER).aab
	@echo "✓  $(AAB_OUT)/whackamoe-$(VERSION)-$(BUILD_NUMBER).aab"

## Remove all build artefacts.
clean:
	flutter clean
