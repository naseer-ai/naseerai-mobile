#!/bin/bash

# Download Phi-2 GGUF model for NaseerAI
# This script downloads the quantized Phi-2 model optimized for mobile devices

set -e

MODEL_DIR="../model_files"
MODEL_FILE="phi-2.Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf"

echo "🤖 Downloading Phi-2 model for NaseerAI..."
echo "📁 Target directory: $MODEL_DIR"
echo "🔗 Source: $MODEL_URL"

# Create model directory if it doesn't exist
mkdir -p "$MODEL_DIR"

# Download the model
echo "⬇️ Downloading Phi-2 model (Q4_K_M quantization)..."
if command -v wget >/dev/null 2>&1; then
    wget -O "$MODEL_DIR/$MODEL_FILE" "$MODEL_URL"
elif command -v curl >/dev/null 2>&1; then
    curl -L -o "$MODEL_DIR/$MODEL_FILE" "$MODEL_URL"
else
    echo "❌ Error: Neither wget nor curl is available. Please install one of them."
    exit 1
fi

# Verify download
if [ -f "$MODEL_DIR/$MODEL_FILE" ]; then
    echo "✅ Phi-2 model downloaded successfully!"
    echo "📊 File size: $(du -h "$MODEL_DIR/$MODEL_FILE" | cut -f1)"
    echo "📂 Location: $MODEL_DIR/$MODEL_FILE"
    echo ""
    echo "🚀 You can now run the NaseerAI app with Phi-2!"
    echo "💡 Model info: Microsoft Phi-2 (2.7B parameters, Q4_K_M quantization)"
else
    echo "❌ Error: Download failed. Please check your internet connection and try again."
    exit 1
fi
