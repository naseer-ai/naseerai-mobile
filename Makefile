# NaseerAI Development Makefile
# Usage: make <target>

.PHONY: help start linux android web clean build test deps setup auto

# Default target
help:
	@echo "🎯 NaseerAI Development Commands"
	@echo "================================"
	@echo "make start     - Smart launcher (interactive)"
	@echo "make linux     - Run on Linux Desktop (optimized input)"
	@echo "make android   - Run on Android emulator/device"
	@echo "make web       - Run on Web browser"
	@echo "make auto      - Auto-detect best platform"
	@echo "make clean     - Clean build cache"
	@echo "make build     - Build for all platforms"
	@echo "make test      - Run tests"
	@echo "make deps      - Get dependencies"
	@echo "make setup     - Setup development environment"

# Interactive launcher with platform selection
start:
	@echo "🎯 NaseerAI Development Launcher"
	@echo "================================"
	@echo "Available platforms:"
	@echo "  1) Linux Desktop (recommended for development)"
	@echo "  2) Android (emulator/device)"
	@echo "  3) Web (Chrome)"
	@echo "  4) Auto-detect best option"
	@echo ""
	@read -p "Choose platform (1-4): " choice; \
	case $$choice in \
		1|linux|desktop) $(MAKE) linux ;; \
		2|android|mobile) $(MAKE) android ;; \
		3|web|chrome) $(MAKE) web ;; \
		4|auto) $(MAKE) auto ;; \
		*) echo "❌ Invalid option. Use: linux, android, web, or auto"; exit 1 ;; \
	esac

# Platform-specific runs with enhanced functionality
linux:
	@echo "🚀 Starting NaseerAI on Linux Desktop..."
	@echo "📋 Using GTK simple input method for better keyboard support"
	@export GTK_IM_MODULE=gtk-im-context-simple && \
	export FLUTTER_NO_INPUT_METHOD=0 && \
	flutter run -d linux --verbose

android:
	@echo "🤖 Starting NaseerAI on Android..."
	@devices=$$(flutter devices | grep -E "(emulator|device)"); \
	if [ -z "$$devices" ]; then \
		echo "❌ No Android devices found"; \
		echo "🔧 Starting Android emulator..."; \
		flutter emulators --launch test_avd || { \
			echo "❌ Failed to start emulator. Please start an Android device manually."; \
			exit 1; \
		}; \
		echo "⏳ Waiting for emulator to boot..."; \
		sleep 10; \
	fi; \
	flutter run --verbose

web:
	@echo "🌐 Starting NaseerAI on Web..."
	@flutter run -d chrome

# Auto-detect best platform
auto:
	@if command -v google-chrome >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1; then \
		echo "🔍 Auto-detected: Linux Desktop (best for development)"; \
		$(MAKE) linux; \
	else \
		echo "🔍 Auto-detected: Web Browser"; \
		$(MAKE) web; \
	fi

# Development utilities
clean:
	@echo "🧹 Cleaning build cache..."
	@flutter clean

deps:
	@echo "📦 Getting dependencies..."
	@flutter pub get

test:
	@echo "🧪 Running tests..."
	@flutter test

build:
	@echo "🔨 Building for all platforms..."
	@flutter build linux
	@flutter build apk
	@flutter build web

# Install dependencies and setup
setup:
	@echo "⚙️ Setting up NaseerAI development environment..."
	@flutter pub get
	@chmod +x scripts/*.sh
	@echo "✅ Setup complete! Use 'make start' to begin development."