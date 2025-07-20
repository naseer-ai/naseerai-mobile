#!/bin/bash

# Build script for NaseerAI native C++ library
# This script compiles the C++ model inference library for different platforms

set -e  # Exit on any error

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CPP_DIR="$PROJECT_ROOT/android/app/src/main/cpp"
BUILD_DIR="$PROJECT_ROOT/build/native"
OUTPUT_DIR="$PROJECT_ROOT/android/app/src/main/jniLibs"

echo "🔨 Building NaseerAI Native Library"
echo "Project root: $PROJECT_ROOT"
echo "C++ source: $CPP_DIR"
echo "Build directory: $BUILD_DIR"

# Create build directory
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

# Function to build for Android
build_android() {
    echo "📱 Building for Android..."
    
    # Check if Android NDK is available
    if [ -z "$ANDROID_NDK" ]; then
        echo "❌ ANDROID_NDK environment variable not set"
        echo "Please install Android NDK and set ANDROID_NDK variable"
        return 1
    fi
    
    cd "$BUILD_DIR"
    
    # Android ABI architectures to build for
    # Note: armeabi-v7a currently has FP16 intrinsic issues, focusing on modern architectures
    ANDROID_ABIS=("arm64-v8a" "x86_64")
    
    for ABI in "${ANDROID_ABIS[@]}"; do
        echo "Building for Android ABI: $ABI"
        
        ABI_BUILD_DIR="$BUILD_DIR/android-$ABI"
        mkdir -p "$ABI_BUILD_DIR"
        cd "$ABI_BUILD_DIR"
        
        cmake \
            -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
            -DANDROID_ABI="$ABI" \
            -DANDROID_PLATFORM=android-21 \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_ANDROID_ARCH_ABI="$ABI" \
            -DGGML_OPENMP=OFF \
            "$CPP_DIR"
        
        make -j$(nproc)
        
        # Copy library to jniLibs
        ABI_OUTPUT_DIR="$OUTPUT_DIR/$ABI"
        mkdir -p "$ABI_OUTPUT_DIR"
        cp libnaseer_model.so "$ABI_OUTPUT_DIR/"
        
        echo "✅ Built for $ABI"
        cd "$BUILD_DIR"
    done
}

# Function to build for Linux
build_linux() {
    echo "🐧 Building for Linux..."
    
    cd "$BUILD_DIR"
    
    LINUX_BUILD_DIR="$BUILD_DIR/linux"
    mkdir -p "$LINUX_BUILD_DIR"
    cd "$LINUX_BUILD_DIR"
    
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        "$CPP_DIR"
    
    make -j$(nproc)
    
    # Copy library to project lib directory
    LIB_DIR="$PROJECT_ROOT/lib"
    mkdir -p "$LIB_DIR"
    cp libnaseer_model.so "$LIB_DIR/"
    
    echo "✅ Built for Linux"
}

# Function to build for Windows (if running on Windows with MinGW)
build_windows() {
    echo "🪟 Building for Windows..."
    
    cd "$BUILD_DIR"
    
    WINDOWS_BUILD_DIR="$BUILD_DIR/windows"
    mkdir -p "$WINDOWS_BUILD_DIR"
    cd "$WINDOWS_BUILD_DIR"
    
    cmake \
        -G "MinGW Makefiles" \
        -DCMAKE_BUILD_TYPE=Release \
        "$CPP_DIR"
    
    mingw32-make -j$(nproc)
    
    # Copy library to project directory
    cp naseer_model.dll "$PROJECT_ROOT/"
    
    echo "✅ Built for Windows"
}

# Function to create a stub library for development
create_stub_library() {
    echo "🔧 Creating stub library for development..."
    
    STUB_DIR="$BUILD_DIR/stub"
    mkdir -p "$STUB_DIR"
    
    # Create a minimal stub library that provides the required symbols
    cat > "$STUB_DIR/stub.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Stub implementations for development/testing
int init_model(const char* model_path) {
    printf("Stub: init_model called with path: %s\n", model_path);
    return 0;  // Success
}

void cleanup_model() {
    printf("Stub: cleanup_model called\n");
}

char* generate_text(const char* prompt, int max_tokens) {
    printf("Stub: generate_text called with prompt: %s, max_tokens: %d\n", prompt, max_tokens);
    
    // Return a simple stub response
    const char* response = "This is a stub response from the C++ model. The actual model is not loaded.";
    char* result = malloc(strlen(response) + 1);
    strcpy(result, response);
    return result;
}

void free_string(char* str) {
    printf("Stub: free_string called\n");
    free(str);
}

int is_model_loaded() {
    return 1;  // Pretend model is loaded
}

const char* get_model_info() {
    return "Stub Library v1.0";
}

void set_temperature(float temperature) {
    printf("Stub: set_temperature called with value: %f\n", temperature);
}

void set_top_k(int top_k) {
    printf("Stub: set_top_k called with value: %d\n", top_k);
}

void set_top_p(float top_p) {
    printf("Stub: set_top_p called with value: %f\n", top_p);
}
EOF

    # Build stub library for different platforms
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        gcc -shared -fPIC -o "$STUB_DIR/libnaseer_model.so" "$STUB_DIR/stub.c"
        cp "$STUB_DIR/libnaseer_model.so" "$PROJECT_ROOT/lib/"
        echo "✅ Created Linux stub library"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        gcc -shared -o "$STUB_DIR/naseer_model.dll" "$STUB_DIR/stub.c"
        cp "$STUB_DIR/naseer_model.dll" "$PROJECT_ROOT/"
        echo "✅ Created Windows stub library"
    fi
}

# Main build logic
case "${1:-all}" in
    "android")
        build_android
        ;;
    "linux")
        build_linux
        ;;
    "windows")
        build_windows
        ;;
    "stub")
        create_stub_library
        ;;
    "all")
        if command -v cmake &> /dev/null; then
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                build_linux
                if [ -n "$ANDROID_NDK" ]; then
                    build_android
                fi
            elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
                build_windows
            fi
        else
            echo "⚠️  CMake not found, creating stub library for development"
            create_stub_library
        fi
        ;;
    *)
        echo "Usage: $0 [android|linux|windows|stub|all]"
        echo ""
        echo "Commands:"
        echo "  android  - Build for Android (requires ANDROID_NDK)"
        echo "  linux    - Build for Linux"
        echo "  windows  - Build for Windows (requires MinGW)"
        echo "  stub     - Create stub library for development"
        echo "  all      - Build for all available platforms (default)"
        exit 1
        ;;
esac

echo ""
echo "🎉 Build complete!"
echo ""
echo "📁 Output locations:"
echo "  Android: $OUTPUT_DIR"
echo "  Linux: $PROJECT_ROOT/lib/"
echo "  Windows: $PROJECT_ROOT/"
echo ""
echo "To use the native library in your Flutter app:"
echo "1. Run 'flutter packages get' to install FFI dependency"
echo "2. Place model files in the model_files directory"
echo "3. The app will automatically detect and use native models"