PROJECT ?= TinyPreview.xcodeproj
SCHEME ?= TinyPreview
CONFIGURATION ?= Debug
DERIVED_DATA ?= .build/xcode
DESTINATION ?= platform=macOS,arch=arm64
CODE_SIGN_IDENTITY ?= -
CODE_SIGN_STYLE ?= Manual
DEVELOPMENT_TEAM ?=
MARKETING_VERSION ?=
CURRENT_PROJECT_VERSION ?=
INSTALL_DIR ?= /Applications

APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/TinyPreview.app
INSTALL_PATH := $(INSTALL_DIR)/TinyPreview.app
XCODEBUILD := xcodebuild
XCODE_ARGS := \
	-project "$(PROJECT)" \
	-scheme "$(SCHEME)" \
	-configuration "$(CONFIGURATION)" \
	-destination "$(DESTINATION)" \
	-derivedDataPath "$(DERIVED_DATA)"
SIGNING_ARGS := \
	CODE_SIGN_STYLE="$(CODE_SIGN_STYLE)" \
	CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
	DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)"
VERSION_ARGS := \
	$(if $(MARKETING_VERSION),MARKETING_VERSION="$(MARKETING_VERSION)") \
	$(if $(CURRENT_PROJECT_VERSION),CURRENT_PROJECT_VERSION="$(CURRENT_PROJECT_VERSION)")

.DEFAULT_GOAL := build

.PHONY: build install test run clean open-project print-app help

build:
	$(XCODEBUILD) $(XCODE_ARGS) $(SIGNING_ARGS) $(VERSION_ARGS) build
	@printf 'Built TinyPreview: %s\n' "$(APP_PATH)"

install: build
	@if [ -w "$(INSTALL_DIR)" ]; then \
		rm -rf "$(INSTALL_PATH)"; \
		mv "$(APP_PATH)" "$(INSTALL_PATH)"; \
	else \
		printf 'Installing to %s requires administrator permission.\n' "$(INSTALL_DIR)"; \
		sudo rm -rf "$(INSTALL_PATH)"; \
		sudo mv "$(APP_PATH)" "$(INSTALL_PATH)"; \
	fi
	@printf 'Installed TinyPreview: %s\n' "$(INSTALL_PATH)"

test:
	swift test

run: build
	open -n "$(APP_PATH)"

clean:
	$(XCODEBUILD) $(XCODE_ARGS) clean
	@rm -rf "$(DERIVED_DATA)"

open-project:
	open "$(PROJECT)"

print-app:
	@printf '%s\n' "$(APP_PATH)"

help:
	@printf '%s\n' \
		'make                       Build an ad-hoc signed Debug app' \
		'make install               Build and move TinyPreview.app to /Applications' \
		'make run                   Build and launch TinyPreview' \
		'make test                  Run the Swift package test suite' \
		'make clean                 Remove generated Xcode build products' \
		'make open-project          Open TinyPreview.xcodeproj in Xcode' \
		'make print-app             Print the built app path' \
		'make build MARKETING_VERSION=1.2.3 CURRENT_PROJECT_VERSION=42' \
		'make build CONFIGURATION=Release CODE_SIGN_IDENTITY="Developer ID Application: …" DEVELOPMENT_TEAM=TEAMID'
