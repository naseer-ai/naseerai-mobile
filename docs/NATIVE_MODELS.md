# Native C++ Model Integration

This document explains how to use the native C++ model integration in NaseerAI for running language models locally without internet connectivity.

## Overview

The native model system allows you to run large language models directly in C++ for better performance and memory efficiency. The system supports multiple model formats and provides a fallback pattern-based response system.

## Supported Model Formats

- **GGUF** (`.gguf`) - Recommended format for CPU inference
- **SafeTensors** (`.safetensors`) - Hugging Face format
- **PyTorch** (`.bin`, `.pt`, `.pth`) - PyTorch model files
- **ONNX** (`.onnx`) - ONNX runtime models

## Quick Setup

### 1. Build the Native Library

```bash
# Build for all available platforms
./scripts/build_native_lib.sh

# Or build for specific platform
./scripts/build_native_lib.sh android
./scripts/build_native_lib.sh linux
./scripts/build_native_lib.sh windows

# For development without CMake
./scripts/build_native_lib.sh stub
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Add Model Files

1. Place your model files in the `model_files/` directory
2. Supported models include Phi-2, TinyLlama, or any GGUF quantized model
3. The app will automatically detect available models

### 4. Run the Application

```bash
# The app will prioritize native models over TFLite models
flutter run
```

## Architecture

### Core Components

1. **CppModel** (`lib/models/cpp_model.dart`)
   - Dart wrapper for C++ model interface
   - Handles FFI bindings and memory management
   - Provides async API for text generation

2. **NativeModelService** (`lib/services/native_model_service.dart`)
   - High-level service for model management
   - Model discovery and loading
   - Fallback response generation

3. **C++ Model Engine** (`android/app/src/main/cpp/`)
   - Core inference engine
   - Model file parsing (GGUF, SafeTensors, etc.)
   - Pattern-based fallback responses

### Model Loading Priority

1. **Native C++ Models** - Highest priority, best performance
2. **TensorFlow Lite Models** - Fallback for compatibility
3. **Pattern Responses** - Always available for reliability

## Usage Examples

### Basic Usage

```dart
// Initialize the service
final modelService = NativeModelService();

// Get available models
final models = await modelService.getAvailableModelFiles();

// Load a model
final model = await modelService.loadModel(models.first);

// Generate response
final response = await modelService.generateResponse(
  "How to purify water naturally?",
  maxTokens: 256
);
```

### Integration with Chat Service

```dart
// The ChatService automatically uses native models when available
final chatService = ChatService();
await chatService.initialize();

// Check what type of model is loaded
final isNative = chatService.isUsingNativeModel;
final status = await chatService.getModelStatus();
```

## Model Recommendations

### For Emergency Response (Gaza Context)

- **Phi-2 (2.7B)** - Good balance of size and capability
- **TinyLlama (1.1B)** - Lightweight, fast responses
- **Quantized Llama models** - Better quality, larger size

### File Size Considerations

| Model | Size | Memory | Speed | Quality |
|-------|------|---------|-------|---------|
| TinyLlama-Q4 | ~600MB | ~1GB | Fast | Good |
| Phi-2-Q4 | ~1.5GB | ~2GB | Medium | Very Good |
| Llama-7B-Q4 | ~4GB | ~6GB | Slow | Excellent |

## Configuration

### Model Parameters

```dart
// Set generation parameters
await model.setTemperature(0.7);  // Creativity (0.1-2.0)
await model.setTopK(40);          // Token filtering
await model.setTopP(0.95);        // Nucleus sampling
```

### Directory Structure

```
project/
├── model_files/          # Large model binaries (gitignored)
│   ├── phi2-q4.gguf
│   ├── tinyllama.gguf
│   └── README.md
├── lib/models/           # Model code (in git)
│   ├── cpp_model.dart
│   └── ai_model.dart
└── android/app/src/main/cpp/  # C++ implementation
    ├── include/
    ├── src/
    └── CMakeLists.txt
```

## Emergency Response Features

The native model system includes specialized emergency response patterns:

### Water Purification
- Solar disinfection (SODIS) instructions
- Sand filtration methods
- Natural purification techniques

### Medical First Aid
- Basic wound care
- Burn treatment
- Emergency stabilization

### Shelter and Safety
- Improvised shelter construction
- Wind and weather protection
- Safety protocols

### Communication
- Signal methods when networks are down
- Visual and audio signaling
- Message documentation

## Troubleshooting

### Common Issues

1. **Library Not Found**
   ```
   Solution: Run ./scripts/build_native_lib.sh to build the library
   ```

2. **Model Loading Failed**
   ```
   Solution: Check model file format and ensure it's in model_files/
   ```

3. **Out of Memory**
   ```
   Solution: Use smaller quantized models (Q4, Q8) or increase device RAM
   ```

### Debug Information

```dart
// Get system information
final info = await modelService.getSystemInfo();
print('Platform: ${info['platform']}');
print('Available models: ${info['available_models']}');
print('Native library support: ${info['native_library_support']}');
```

## Performance Optimization

### For Mobile Devices

1. **Use Quantized Models** - Q4 or Q8 quantization reduces memory usage
2. **Limit Context Length** - Shorter context = faster inference
3. **Adjust Thread Count** - Match CPU cores for optimal performance
4. **Memory Management** - Unload models when not in use

### For Desktop

1. **Higher Precision** - F16 or F32 for better quality
2. **Larger Models** - Take advantage of more RAM
3. **GPU Acceleration** - If available (future enhancement)

## Development Notes

### Adding New Model Formats

1. Implement parser in `model_loader.cpp`
2. Add format detection in `is_supported_format()`
3. Update file extension checks
4. Test with sample model files

### Extending the API

1. Add new functions to `model_interface.h`
2. Implement in `model_interface.cpp`
3. Update Dart FFI bindings in `cpp_model.dart`
4. Add high-level API in `native_model_service.dart`

## Security Considerations

- Model files are stored locally and never transmitted
- No network access required for inference
- Pattern responses ensure functionality even without models
- Memory is properly managed to prevent leaks

## Contributing

When contributing to the native model system:

1. Test with multiple model formats
2. Ensure memory management is correct
3. Add appropriate error handling
4. Update documentation for new features
5. Test on multiple platforms (Android, Linux, Windows)

## License

This native model integration is part of the NaseerAI project and follows the same license terms as the main project.