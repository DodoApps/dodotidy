.PHONY: build clean open generate-project install-dependencies

# Project settings
PROJECT_NAME = DodoTidy
SCHEME = DodoTidy
BUILD_DIR = .build
DERIVED_DATA = $(BUILD_DIR)/DerivedData
ARCHIVE_PATH = $(BUILD_DIR)/$(PROJECT_NAME).xcarchive
APP_PATH = $(DERIVED_DATA)/Build/Products/Release/$(PROJECT_NAME).app

# Generate Xcode project using xcodegen
generate-project:
	@if command -v xcodegen &> /dev/null; then \
		echo "Generating Xcode project with xcodegen..."; \
		xcodegen generate; \
	else \
		echo "xcodegen not found. Please install it with 'brew install xcodegen'"; \
	fi

# Build with xcodebuild
build:
	@echo "Building $(PROJECT_NAME)..."
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA) \
		build

# Build debug
build-debug:
	@echo "Building $(PROJECT_NAME) (Debug)..."
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		build

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	xcodebuild clean 2>/dev/null || true

# Open project in Xcode
open:
	@if [ -f "$(PROJECT_NAME).xcodeproj/project.pbxproj" ]; then \
		open $(PROJECT_NAME).xcodeproj; \
	else \
		echo "Project not found. Run 'make generate-project' first."; \
	fi

# Install development dependencies
install-dependencies:
	@echo "Installing dependencies..."
	brew install xcodegen || true

# Archive for distribution
archive:
	@echo "Archiving $(PROJECT_NAME)..."
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH) \
		archive

# Get version from project.yml
VERSION := $(shell grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*"\(.*\)"/\1/')

# Create DMG for distribution
dmg: build
	@echo "Creating DMG for $(PROJECT_NAME) v$(VERSION)..."
	@mkdir -p build
	@rm -f build/$(PROJECT_NAME)-$(VERSION).dmg
	create-dmg \
		--volname "$(PROJECT_NAME)" \
		--volicon "$(DERIVED_DATA)/Build/Products/Release/$(PROJECT_NAME).app/Contents/Resources/AppIcon.icns" \
		--background "dmg-resources/background.png" \
		--window-pos 200 120 \
		--window-size 660 400 \
		--icon-size 100 \
		--icon "$(PROJECT_NAME).app" 150 200 \
		--hide-extension "$(PROJECT_NAME).app" \
		--app-drop-link 510 200 \
		--no-internet-enable \
		"build/$(PROJECT_NAME)-$(VERSION).dmg" \
		"$(DERIVED_DATA)/Build/Products/Release/$(PROJECT_NAME).app"
	@echo "DMG created: build/$(PROJECT_NAME)-$(VERSION).dmg"

# Run the app
run: build-debug
	@echo "Running $(PROJECT_NAME)..."
	open "$(DERIVED_DATA)/Build/Products/Debug/$(PROJECT_NAME).app"

# Help
help:
	@echo "DodoTidy macOS App - Build Commands"
	@echo "===================================="
	@echo ""
	@echo "  make generate-project  Generate Xcode project (requires xcodegen)"
	@echo "  make build             Build release version"
	@echo "  make build-debug       Build debug version"
	@echo "  make clean             Clean build artifacts"
	@echo "  make open              Open project in Xcode"
	@echo "  make run               Build and run debug version"
	@echo "  make archive           Create release archive"
	@echo "  make dmg               Create DMG for distribution"
	@echo "  make help              Show this help"
	@echo ""
	@echo "First time setup:"
	@echo "  1. make install-dependencies"
	@echo "  2. make generate-project"
	@echo "  3. make build"
	@echo ""
	@echo "Creating a release:"
	@echo "  1. make dmg"
	@echo "  2. Upload build/DodoTidy-x.x.x.dmg to GitHub releases"
