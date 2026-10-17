PROJECT ?= TinyPreview.xcodeproj
SCHEME ?= TinyPreview
CONFIGURATION ?= Debug
DERIVED_DATA ?= .build/xcode
DESTINATION ?= platform=macOS,arch=arm64
MARKETING_VERSION ?=
CURRENT_PROJECT_VERSION ?=
APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/TinyPreview.app
XCODE_ARGS := -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -destination "$(DESTINATION)" -derivedDataPath "$(DERIVED_DATA)"
VERSION_ARGS := $(if $(MARKETING_VERSION),MARKETING_VERSION="$(MARKETING_VERSION)") $(if $(CURRENT_PROJECT_VERSION),CURRENT_PROJECT_VERSION="$(CURRENT_PROJECT_VERSION)")

.DEFAULT_GOAL := build
.PHONY: build clean run test test-ui

build:
	xcodebuild $(XCODE_ARGS) CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- $(VERSION_ARGS) build
	@printf 'Built TinyPreview: %s\n' "$(APP_PATH)"

test:
	@mkdir -p .build/tmp
	TMPDIR="$(CURDIR)/.build/tmp" CLANG_MODULE_CACHE_PATH="$(CURDIR)/.build/ModuleCache" swift test --disable-sandbox --cache-path .build/swiftpm-cache --scratch-path .build/swiftpm

test-ui:
	@mkdir -p .build/ModuleCache
	swiftc -swift-version 5 -target arm64-apple-macosx26.0 -module-cache-path .build/ModuleCache -larchive TinyPreview/Core/*.swift TinyPreview/QuickLook/*.swift Tests/PreviewInteractionChecks.swift -o .build/preview-interaction-checks
	.build/preview-interaction-checks

run: build
	open -n "$(APP_PATH)"

clean:
	xcodebuild $(XCODE_ARGS) clean
	rm -rf .build
