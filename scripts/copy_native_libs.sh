#!/bin/bash

# Script to copy native libraries to Android jniLibs directory
# This ensures all dependencies are properly included in the APK

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/native"
JNILIBS_DIR="$PROJECT_ROOT/android/app/src/main/jniLibs"

echo "🔧 Copying native libraries to Android jniLibs..."

# Function to copy libraries for a specific architecture
copy_libs_for_arch() {
    local arch=$1
    local build_arch_dir="$BUILD_DIR/android-$arch"
    local jni_arch_dir="$JNILIBS_DIR/$arch"
    
    echo "📱 Processing $arch architecture..."
    
    # Create jniLibs directory if it doesn't exist
    mkdir -p "$jni_arch_dir"
    
    # Copy libllama.so if it exists
    if [ -f "$build_arch_dir/bin/libllama.so" ]; then
        cp "$build_arch_dir/bin/libllama.so" "$jni_arch_dir/"
        echo "  ✅ Copied libllama.so"
    else
        echo "  ⚠️ libllama.so not found for $arch"
    fi
    
    # Copy ggml libraries
    if [ -d "$build_arch_dir/bin" ]; then
        cp "$build_arch_dir/bin/libggml"*.so "$jni_arch_dir/" 2>/dev/null || true
        echo "  ✅ Copied ggml libraries"
    fi
    
    # Note: OpenMP is disabled for Android builds to avoid runtime dependency issues
    # If you see "libomp.so not found" errors, rebuild the native libraries with:
    # ./scripts/build_native_lib.sh android
    
    # Copy libnaseer_model.so if it exists
    if [ -f "$build_arch_dir/libnaseer_model.so" ]; then
        cp "$build_arch_dir/libnaseer_model.so" "$jni_arch_dir/"
        echo "  ✅ Copied libnaseer_model.so"
    else
        echo "  ⚠️ libnaseer_model.so not found for $arch"
    fi
    
    echo "  📋 Libraries in $arch:"
    ls -la "$jni_arch_dir/" | grep "\.so$" || echo "    No .so files found"
}

# Copy libraries for all architectures
copy_libs_for_arch "x86_64"
copy_libs_for_arch "arm64-v8a"
copy_libs_for_arch "armeabi-v7a"

echo "✅ Native library copying complete!"
echo ""
echo "🔍 Summary of jniLibs:"
for arch in x86_64 arm64-v8a armeabi-v7a; do
    if [ -d "$JNILIBS_DIR/$arch" ]; then
        echo "  $arch:"
        ls -la "$JNILIBS_DIR/$arch/" | grep "\.so$" | awk '{print "    " $9 " (" $5 " bytes)"}' || echo "    No .so files"
    fi
done
