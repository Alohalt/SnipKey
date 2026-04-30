SHELL := /bin/zsh

APP_EXECUTABLE := SnipKey
SWIFT_RUN_TARGET := SnipKeyApp
BUILD_CONFIGURATION ?= debug
BUILD_DIR := .build/$(BUILD_CONFIGURATION)
BUILD_PRODUCT := $(BUILD_DIR)/$(SWIFT_RUN_TARGET)
APP_ICON := Resources/AppIcon.icns
WINDOWS_PROJECT := Windows/SnipKey.Windows/SnipKey.Windows.csproj
WINDOWS_PUBLISH_DIR := .build/windows-publish

DIST_APP_NAME ?= SnipKey.app
DIST_APP_DISPLAY_NAME ?= SnipKey
DIST_BUNDLE_IDENTIFIER ?= com.snipkey.app
DIST_VOLUME_NAME ?= SnipKey
DIST_OUTPUT_DIR := .build/dist
DIST_APP_PATH := $(DIST_OUTPUT_DIR)/$(DIST_APP_NAME)
DIST_DMG_NAME ?= SnipKey.dmg
DIST_DMG_PATH := $(DIST_OUTPUT_DIR)/$(DIST_DMG_NAME)
DIST_DMG_STAGING_DIR := .build/dmg-root

DEV_APP_NAME ?= SnipKey Dev.app
DEV_APP_DISPLAY_NAME ?= SnipKey Dev
DEV_BUNDLE_IDENTIFIER ?= com.snipkey.app.dev
DEV_APPLICATIONS_DIR ?= $(HOME)/Applications
DEV_APP_PATH := $(DEV_APPLICATIONS_DIR)/$(DEV_APP_NAME)
DEV_STAGING_DIR := .build/dev-bundle/$(DEV_APP_NAME)
PERSONAL_TEAM_ID ?= $(shell defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | sed -n 's/.*teamID = \([A-Z0-9]*\);/\1/p' | head -n 1)
PERSONAL_TEAM_DERIVED_DATA := .build/xcode-personal-team-derived

APPLE_DEVELOPMENT_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development:[^"]*\)"/\1/p' | head -n 1)
DEVELOPER_ID_APPLICATION_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application:[^"]*\)"/\1/p' | head -n 1)
DIST_SIGNING_IDENTITY ?= $(if $(DEVELOPER_ID_APPLICATION_IDENTITY),$(DEVELOPER_ID_APPLICATION_IDENTITY),$(APPLE_DEVELOPMENT_IDENTITY))

.PHONY: build test run run-swift clean windows-build windows-run windows-publish bundle bundle-dev bundle-dist dmg package-dmg verify-dist install-dev run-dev restart-dev verify-dev uninstall-dev signing-identities print-signing-identity print-dist-signing-identity signing-help bootstrap-personal-team generate-icon

define require_apple_development_identity
	@if [ -z "$(APPLE_DEVELOPMENT_IDENTITY)" ]; then \
		echo "No valid Apple Development signing identity was found."; \
		echo "Sign in to Xcode with your Apple Account and use the Personal Team to create one,"; \
		echo "or pass APPLE_DEVELOPMENT_IDENTITY=\"Apple Development: Your Name (TEAMID)\"."; \
		echo "Run 'make bootstrap-personal-team' to let Xcode create one automatically."; \
		echo "Run 'make signing-identities' to inspect available identities."; \
		echo "Run 'make signing-help' for the Xcode setup steps."; \
		exit 1; \
	fi
endef

define require_dist_signing_identity
	@if [ -z "$(DIST_SIGNING_IDENTITY)" ]; then \
		echo "No usable signing identity was found for distribution."; \
		echo "Install either a Developer ID Application certificate (recommended) or an Apple Development certificate."; \
		echo "For local packaging only, run 'make signing-help' to create an Apple Development identity first."; \
		exit 1; \
	fi
endef

define require_personal_team_id
	@if [ -z "$(PERSONAL_TEAM_ID)" ]; then \
		echo "No Personal Team ID was found in Xcode settings."; \
		echo "Open Xcode > Settings > Accounts and confirm an Apple Account is signed in."; \
		echo "If you have more than one team, rerun with PERSONAL_TEAM_ID=<TEAMID>."; \
		exit 1; \
	fi
endef

build:
	swift build

test:
	swift test

run: restart-dev

run-swift:
	swift run $(SWIFT_RUN_TARGET)

windows-build:
	@if ! command -v dotnet >/dev/null 2>&1; then \
		echo "dotnet SDK was not found. Install .NET 8 SDK on Windows, then rerun this target."; \
		exit 1; \
	fi
	dotnet build "$(WINDOWS_PROJECT)"

windows-run:
	@if ! command -v dotnet >/dev/null 2>&1; then \
		echo "dotnet SDK was not found. Install .NET 8 SDK on Windows, then rerun this target."; \
		exit 1; \
	fi
	dotnet run --project "$(WINDOWS_PROJECT)"

windows-publish:
	@if ! command -v dotnet >/dev/null 2>&1; then \
		echo "dotnet SDK was not found. Install .NET 8 SDK on Windows, then rerun this target."; \
		exit 1; \
	fi
	rm -rf "$(WINDOWS_PUBLISH_DIR)"
	dotnet publish "$(WINDOWS_PROJECT)" -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -o "$(WINDOWS_PUBLISH_DIR)"
	@echo "Windows publish output: $(WINDOWS_PUBLISH_DIR)"

clean:
	swift package clean
	rm -rf .build/dev-bundle
	rm -rf "$(PERSONAL_TEAM_DERIVED_DATA)"
	rm -rf .build/appicon

generate-icon:
	swift Scripts/generate_app_icon.swift

signing-identities:
	@security find-identity -v -p codesigning | grep "Apple Development" || { \
		echo "No valid Apple Development signing identities found."; \
		echo "Open Xcode > Settings > Accounts, add your Apple Account, and use the Personal Team to create one."; \
		echo "Run 'make signing-help' for the full setup steps."; \
		exit 1; \
	}

signing-help:
	@echo "Set up a free Personal Team signing identity in Xcode:"
	@echo "  1. Open Xcode."
	@echo "  2. Go to Settings... > Accounts."
	@echo "  3. Add your Apple Account if it is not already listed."
	@echo "  4. Select the account and confirm a team ending with '(Personal Team)' appears."
	@echo "  5. Return here and run 'make bootstrap-personal-team'."
	@echo
	@echo "After the Apple Development identity appears, use:"
	@echo "  make run"

bootstrap-personal-team:
	$(call require_personal_team_id)
	xcodebuild -scheme SnipKey -destination 'platform=macOS' -derivedDataPath "$(PERSONAL_TEAM_DERIVED_DATA)" DEVELOPMENT_TEAM="$(PERSONAL_TEAM_ID)" CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY='Apple Development' PRODUCT_BUNDLE_IDENTIFIER="$(DEV_BUNDLE_IDENTIFIER)" build
	@echo
	@echo "Personal Team bootstrap finished. Run 'make signing-identities' to confirm the Apple Development identity is available."

print-signing-identity:
	@if [ -n "$(APPLE_DEVELOPMENT_IDENTITY)" ]; then \
		echo "$(APPLE_DEVELOPMENT_IDENTITY)"; \
	else \
		echo "No Apple Development signing identity selected."; \
		exit 1; \
	fi

print-dist-signing-identity:
	@if [ -n "$(DIST_SIGNING_IDENTITY)" ]; then \
		echo "$(DIST_SIGNING_IDENTITY)"; \
	else \
		echo "No distribution signing identity selected."; \
		exit 1; \
	fi

bundle: bundle-dev

bundle-dev: build
	$(call require_apple_development_identity)
	rm -rf "$(DEV_STAGING_DIR)"
	mkdir -p "$(DEV_STAGING_DIR)/Contents/MacOS"
	mkdir -p "$(DEV_STAGING_DIR)/Contents/Resources"
	cp "$(BUILD_PRODUCT)" "$(DEV_STAGING_DIR)/Contents/MacOS/$(APP_EXECUTABLE)"
	cp Resources/Info.plist "$(DEV_STAGING_DIR)/Contents/Info.plist"
	cp "$(APP_ICON)" "$(DEV_STAGING_DIR)/Contents/Resources/AppIcon.icns"
	plutil -replace CFBundleIdentifier -string "$(DEV_BUNDLE_IDENTIFIER)" "$(DEV_STAGING_DIR)/Contents/Info.plist"
	plutil -replace CFBundleName -string "$(DEV_APP_DISPLAY_NAME)" "$(DEV_STAGING_DIR)/Contents/Info.plist"
	plutil -replace CFBundleExecutable -string "$(APP_EXECUTABLE)" "$(DEV_STAGING_DIR)/Contents/Info.plist"
	codesign --force --sign "$(APPLE_DEVELOPMENT_IDENTITY)" --entitlements Resources/SnipKeyApp.entitlements "$(DEV_STAGING_DIR)"
	@echo "Signed dev app bundle created at $(DEV_STAGING_DIR)"

bundle-dist: build
	$(call require_dist_signing_identity)
	rm -rf "$(DIST_APP_PATH)"
	mkdir -p "$(DIST_APP_PATH)/Contents/MacOS"
	mkdir -p "$(DIST_APP_PATH)/Contents/Resources"
	cp "$(BUILD_PRODUCT)" "$(DIST_APP_PATH)/Contents/MacOS/$(APP_EXECUTABLE)"
	cp Resources/Info.plist "$(DIST_APP_PATH)/Contents/Info.plist"
	cp "$(APP_ICON)" "$(DIST_APP_PATH)/Contents/Resources/AppIcon.icns"
	plutil -replace CFBundleIdentifier -string "$(DIST_BUNDLE_IDENTIFIER)" "$(DIST_APP_PATH)/Contents/Info.plist"
	plutil -replace CFBundleName -string "$(DIST_APP_DISPLAY_NAME)" "$(DIST_APP_PATH)/Contents/Info.plist"
	plutil -replace CFBundleDisplayName -string "$(DIST_APP_DISPLAY_NAME)" "$(DIST_APP_PATH)/Contents/Info.plist"
	plutil -replace CFBundleExecutable -string "$(APP_EXECUTABLE)" "$(DIST_APP_PATH)/Contents/Info.plist"
	codesign --force --sign "$(DIST_SIGNING_IDENTITY)" --entitlements Resources/SnipKeyApp.entitlements "$(DIST_APP_PATH)"
	@echo "Signed distribution app bundle created at $(DIST_APP_PATH)"

dmg: package-dmg

package-dmg: bundle-dist
	rm -rf "$(DIST_DMG_STAGING_DIR)"
	mkdir -p "$(DIST_DMG_STAGING_DIR)"
	cp -R "$(DIST_APP_PATH)" "$(DIST_DMG_STAGING_DIR)/$(DIST_APP_NAME)"
	ln -sfn /Applications "$(DIST_DMG_STAGING_DIR)/Applications"
	rm -f "$(DIST_DMG_PATH)"
	hdiutil create -volname "$(DIST_VOLUME_NAME)" -srcfolder "$(DIST_DMG_STAGING_DIR)" -format UDZO "$(DIST_DMG_PATH)"
	@echo "DMG created at $(DIST_DMG_PATH)"

install-dev: bundle-dev
	mkdir -p "$(DEV_APPLICATIONS_DIR)"
	rm -rf "$(DEV_APP_PATH)"
	ditto "$(DEV_STAGING_DIR)" "$(DEV_APP_PATH)"
	@echo "Installed dev app to $(DEV_APP_PATH)"

run-dev: restart-dev

restart-dev: install-dev
	@if pgrep -f "$(DEV_APP_PATH)/Contents/MacOS/$(APP_EXECUTABLE)" >/dev/null; then \
		pkill -f "$(DEV_APP_PATH)/Contents/MacOS/$(APP_EXECUTABLE)" || true; \
		sleep 1; \
	fi
	open "$(DEV_APP_PATH)"

verify-dev:
	@if [ ! -d "$(DEV_APP_PATH)" ]; then \
		echo "No installed dev app found at $(DEV_APP_PATH). Run 'make install-dev' first."; \
		exit 1; \
	fi
	@echo "Installed app: $(DEV_APP_PATH)"
	@echo "Selected signing identity: $(APPLE_DEVELOPMENT_IDENTITY)"
	@echo
	@codesign -dv --verbose=4 "$(DEV_APP_PATH)" 2>&1 | grep -E "^(Identifier=|TeamIdentifier=|Authority=)"
	@echo
	@echo "Designated requirement:"
	@codesign -d -r- "$(DEV_APP_PATH)" 2>&1 | sed 's/^/  /'

verify-dist:
	@if [ ! -d "$(DIST_APP_PATH)" ]; then \
		echo "No distribution app bundle found at $(DIST_APP_PATH). Run 'make bundle-dist' or 'make package-dmg' first."; \
		exit 1; \
	fi
	@echo "Distribution app: $(DIST_APP_PATH)"
	@echo "Selected signing identity: $(DIST_SIGNING_IDENTITY)"
	@echo
	@codesign -dv --verbose=4 "$(DIST_APP_PATH)" 2>&1 | grep -E "^(Identifier=|TeamIdentifier=|Authority=)"
	@echo
	@echo "Gatekeeper assessment:"
	@spctl -a -vv "$(DIST_APP_PATH)" 2>&1 | sed 's/^/  /' || true
	@if [ -f "$(DIST_DMG_PATH)" ]; then \
		echo; \
		echo "DMG: $(DIST_DMG_PATH)"; \
		hdiutil imageinfo "$(DIST_DMG_PATH)" | grep -E "^(format|Class|Software Version|Total Bytes)" | sed 's/^/  /'; \
	fi

uninstall-dev:
	rm -rf "$(DEV_APP_PATH)"
