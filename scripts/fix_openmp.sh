#!/bin/bash

# Quick fix script for OpenMP dependency issues
# This script rebuilds the native libraries without OpenMP to resolve Android runtime issues

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔧 Fixing OpenMP dependency issues for Android..."
echo ""
echo "The current native libraries were built with OpenMP enabled, which causes"
echo "runtime dependency issues on Android devices. This script will:"
echo "1. Clean existing build artifacts"
echo "2. Rebuild libraries without OpenMP"
echo "3. Copy updated libraries to Android jniLibs"
echo ""

read -p "Continue with rebuild? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Rebuild cancelled"
    exit 1
fi

echo "🧹 Cleaning build artifacts..."
rm -rf "$PROJECT_ROOT/build/native"

echo "🔨 Rebuilding native libraries without OpenMP..."
cd "$PROJECT_ROOT"

# Set Android NDK if not already set
if [ -z "$ANDROID_NDK" ]; then
    if [ -d "/home/forhad/android-sdk/ndk/27.0.12077973" ]; then
        export ANDROID_NDK="/home/forhad/android-sdk/ndk/27.0.12077973"
        echo "📱 Using Android NDK: $ANDROID_NDK"
    else
        echo "❌ Android NDK not found. Please set ANDROID_NDK environment variable."
        exit 1
    fi
fi

# Run the build script
if [ -f "./scripts/build_native_lib.sh" ]; then
    echo "🔧 Running build script..."
    ./scripts/build_native_lib.sh android
else
    echo "❌ Build script not found"
    exit 1
fi

echo "📚 Copying libraries to Android jniLibs..."
./scripts/copy_native_libs.sh

echo ""
echo "✅ OpenMP fix complete!"
echo ""
echo "📋 Summary:"
echo "- Native libraries rebuilt without OpenMP"
echo "- Dependencies copied to Android jniLibs"
echo "- App should now run without 'libomp.so not found' errors"
echo ""
echo "🚀 You can now run the app with: make android"
