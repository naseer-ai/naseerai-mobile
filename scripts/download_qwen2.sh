#!/bin/bash

# Download Qwen2 1.5B Instruct GGUF model for NaseerAI
# This script downloads the quantized Qwen2 1.5B Instruct model optimized for mobile devices

set -e

MODEL_DIR="../model_files"
MODEL_FILE="qwen2-1_5b-instruct-q4_k_m.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen2-1.5B-Instruct-GGUF/resolve/main/qwen2-1_5b-instruct-q4_k_m.gguf"

echo "🤖 Downloading Qwen2 1.5B Instruct model for NaseerAI..."
echo "📁 Target directory: $MODEL_DIR"
echo "🔗 Source: $MODEL_URL"

# Create model directory if it doesn't exist
mkdir -p "$MODEL_DIR"

# Download the model
echo "⬇️ Downloading Qwen2 1.5B Instruct model (Q4_K_M quantization)..."
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
    echo "✅ Qwen2 1.5B Instruct model downloaded successfully!"
    echo "📊 File size: $(du -h "$MODEL_DIR/$MODEL_FILE" | cut -f1)"
    echo "📂 Location: $MODEL_DIR/$MODEL_FILE"
    echo ""
    echo "🚀 You can now run the NaseerAI app with Qwen2 1.5B Instruct!"
    echo "💡 Model info: Alibaba Qwen2 1.5B Instruct (1.5B parameters, Q4_K_M quantization)"
else
    echo "❌ Error: Download failed. Please check your internet connection and try again."
    exit 1
fi