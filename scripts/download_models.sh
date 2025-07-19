#!/bin/bash

# Download Models Script for Gaza Emergency Support App
# This script downloads necessary AI models for offline operation

set -e

MODELS_DIR="assets/models"
BASE_URL="https://huggingface.co"

# Create models directory if it doesn't exist
mkdir -p "$MODELS_DIR"

echo "🚀 Downloading models for Gaza Emergency Support App..."

# Function to download a model
download_model() {
    local model_name="$1"
    local model_url="$2"
    local output_file="$3"
    
    echo "📥 Downloading $model_name..."
    
    if [ -f "$MODELS_DIR/$output_file" ]; then
        echo "✅ $model_name already exists, skipping..."
        return
    fi
    
    # Try wget first, then curl as fallback
    if command -v wget >/dev/null 2>&1; then
        wget -O "$MODELS_DIR/$output_file" "$model_url" || {
            echo "❌ Failed to download $model_name with wget"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$MODELS_DIR/$output_file" "$model_url" || {
            echo "❌ Failed to download $model_name with curl"
            return 1
        }
    else
        echo "❌ Neither wget nor curl available. Please install one of them."
        return 1
    fi
    
    echo "✅ Successfully downloaded $model_name"
}

# Download lightweight models optimized for mobile devices
echo "📱 Downloading mobile-optimized AI models..."

# Option 1: Try to download a quantized Phi-2 or similar lightweight model
# Note: These URLs might need to be updated based on available models
download_model "Emergency Response Model" \
    "$BASE_URL/microsoft/phi-2/resolve/main/model.tflite" \
    "emergency_response.tflite" || echo "⚠️  Could not download emergency response model"

# Option 2: Download a basic text classification model
download_model "Text Classification Model" \
    "$BASE_URL/sentence-transformers/all-MiniLM-L6-v2/resolve/main/model.tflite" \
    "text_classifier.tflite" || echo "⚠️  Could not download text classification model"

# Create a placeholder model file if no downloads succeeded
if [ ! -f "$MODELS_DIR/emergency_response.tflite" ] && [ ! -f "$MODELS_DIR/text_classifier.tflite" ]; then
    echo "🔧 Creating placeholder model file..."
    
    # Create a minimal valid TFLite file structure (placeholder)
    cat > "$MODELS_DIR/phi2_demo_placeholder.tflite" << 'EOF'
# Placeholder TensorFlow Lite model file
# This file serves as a placeholder until actual models are downloaded
# The app will fall back to pattern-based responses
EOF
    
    echo "✅ Created placeholder model file"
fi

# Set appropriate permissions
chmod 644 "$MODELS_DIR"/*.tflite 2>/dev/null || true

echo ""
echo "🎉 Model setup complete!"
echo ""
echo "📋 Available models in $MODELS_DIR:"
ls -la "$MODELS_DIR"/*.tflite 2>/dev/null || echo "No .tflite files found"

echo ""
echo "📖 Notes:"
echo "• The app will work with pattern-based responses even without actual models"
echo "• For best performance, replace placeholder files with actual TensorFlow Lite models"
echo "• Models should be optimized for mobile devices (quantized, pruned)"
echo "• Check the README.md for more information on adding custom models"
echo ""
echo "🚀 You can now run: flutter run"