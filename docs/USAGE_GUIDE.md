# NaseerAI Model Usage Guide

## Quick Start

### 1. Set Up the Application

```bash
# Clone and navigate to the project
cd naseerai-mobile

# Install Flutter dependencies
flutter pub get

# Build the native library (creates a stub for development)
./scripts/build_native_lib.sh stub

# Run the application
flutter run
```

### 2. Using with Local Models

#### Option A: Use Built-in Pattern Responses (No Model Required)
- The app works immediately with intelligent pattern-based responses
- Specialized for emergency guidance and water purification
- No additional setup required

#### Option B: Add Your Own Language Model
1. Download a compatible model (GGUF format recommended):
   ```bash
   # Example: Download a small model like TinyLlama
   # Place it in the model_files/ directory
   ```

2. Supported model formats:
   - `.gguf` (Recommended - llama.cpp format)
   - `.safetensors` (Hugging Face format)
   - `.bin`, `.pt`, `.pth` (PyTorch formats)

3. The app will automatically detect and load available models

## Model Recommendations

### For Emergency Response (Optimized for Gaza context)

| Model | Size | Memory | Best For |
|-------|------|---------|----------|
| **TinyLlama-Q4** | ~600MB | ~1GB | Fast responses, limited resources |
| **Phi-2-Q4** | ~1.5GB | ~2GB | Balanced performance and quality |
| **Phi-2-Q8** | ~2.8GB | ~3.5GB | Higher quality responses |

### Download Sources

- **Hugging Face**: Search for GGUF quantized models
- **llama.cpp**: Official model releases
- **TheBloke**: Popular quantized model repository

## Core Features

### 1. Emergency Response System
The app includes specialized knowledge for emergency situations:

- **Water Purification**: Solar disinfection, sand filtration, natural methods
- **Medical First Aid**: Wound care, burn treatment, emergency stabilization
- **Shelter Construction**: Improvised materials, weather protection
- **Communication**: Signal methods when networks are down

### 2. Offline Operation
- **No Internet Required**: Works completely offline
- **Local Processing**: All inference happens on your device
- **Privacy Focused**: No data leaves your device

### 3. Multiple Model Support
- **Native C++ Models**: Best performance, supports large models
- **TensorFlow Lite**: Fallback compatibility
- **Pattern Responses**: Always available as final fallback

## Usage Examples

### Basic Chat Interaction

```
User: "How can I purify water without electricity?"

AI Response: "Natural water purification methods include:

• Solar disinfection (SODIS): Clear plastic bottles filled with water 
  exposed to sunlight for 6+ hours can kill bacteria and viruses

• Sand filtration: Multiple layers of fine sand, gravel, and charcoal 
  can filter out particles and contaminants

• Boiling: Using wood, solar cookers, or any heat source to boil water 
  for 1-3 minutes kills most pathogens

• Clay pot filters: Ceramic filters made from clay and organic materials 
  can remove bacteria and particles

These methods use readily available natural elements."
```

### Emergency Guidance

```
User: "Emergency shelter help"

AI Response: "I understand this may be an emergency situation. For immediate 
shelter using available materials:

1. Find existing structures - walls, ruins, or natural features
2. Create windbreaks with fabric, tarps, boards, or cardboard
3. Insulate from ground using blankets, clothing, or debris
4. Slope any roof materials to shed water
5. Ensure ventilation and clear exit routes
6. Block wind from the dominant direction

What specific materials do you have available?"
```

## Advanced Configuration

### Model Parameters

You can adjust model behavior programmatically:

```dart
// Access the native model service
final modelService = NativeModelService();

// Load a specific model
final model = await modelService.loadModel('/path/to/model.gguf');

// Configure generation parameters
await model.setTemperature(0.7);  // Creativity (0.1-2.0)
await model.setTopK(40);          // Token filtering
await model.setTopP(0.95);        // Nucleus sampling

// Generate response
final response = await modelService.generateResponse(
  "Your question here",
  maxTokens: 256
);
```

### Model Management

```dart
// Check what models are available
final availableModels = await modelService.getAvailableModelFiles();

// Get system information
final systemInfo = await modelService.getSystemInfo();
print('Platform: ${systemInfo['platform']}');
print('Available models: ${systemInfo['available_models']}');

// Check model status
final status = await modelService.getModelStatus();
```

## Performance Tips

### For Mobile Devices

1. **Use Quantized Models**: Q4 quantization provides good quality with less memory
2. **Limit Response Length**: Shorter responses = faster generation
3. **Close Unused Apps**: Free up RAM for model operation
4. **Monitor Battery**: Large models consume more power

### For Desktop/Laptop

1. **Higher Precision Models**: F16 or F32 for better quality
2. **Larger Context**: Take advantage of more available RAM
3. **Multiple Models**: Switch between models for different use cases

## Troubleshooting

### Common Issues

**App starts but no model loads:**
- Check if model files are in the `model_files/` directory
- Verify model file format is supported (.gguf, .safetensors, etc.)
- The app will use pattern responses if no model is available

**Out of memory errors:**
- Use smaller/quantized models (Q4 instead of F16)
- Close other applications
- Restart the app to clear memory

**Slow responses:**
- Switch to a smaller model (TinyLlama vs Phi-2)
- Reduce max_tokens parameter
- Ensure device has sufficient RAM

**Build errors:**
- Run `./scripts/build_native_lib.sh stub` for development
- Install Flutter dependencies: `flutter pub get`
- Check platform compatibility

### Debug Information

Enable debug mode to see detailed information:

```dart
// Get comprehensive status
final chatService = ChatService();
await chatService.initialize();
final status = await chatService.getModelStatus();

// Print debug info
print('Model type: ${status['current_model_type']}');
print('Library status: ${status['native_model_status']}');
print('System info: ${status['system_info']}');
```

## Emergency Use Guidelines

### For Crisis Situations

1. **Battery Conservation**:
   - Use the app sparingly to preserve battery
   - Focus on critical information needs
   - Pattern responses use less battery than full models

2. **Information Prioritization**:
   - Water purification and safety come first
   - Medical guidance for injuries
   - Shelter and protection advice
   - Communication methods

3. **Offline Reliability**:
   - The app works without any internet connection
   - No reliance on external servers
   - All processing happens locally

### Key Emergency Topics

- **Water Safety**: Purification, testing, conservation
- **First Aid**: Wound care, bleeding control, burn treatment
- **Shelter**: Improvised construction, weather protection
- **Signaling**: Communication when networks are down
- **Resource Management**: Food preservation, fuel conservation

## Development and Customization

### Adding New Response Patterns

Edit `text_generator.cpp` to add specialized responses:

```cpp
// Add new emergency response patterns
if (lowerInput.find("fire safety") != std::string::npos) {
    return "Fire safety protocols:\n1. Stay low to avoid smoke\n2. Feel doors before opening\n...";
}
```

### Custom Model Integration

1. Place your model in `model_files/`
2. The app automatically detects supported formats
3. Model loading is prioritized by file size (smaller first)

### Contributing

- Test with different model sizes and formats
- Focus on emergency response accuracy
- Ensure offline functionality
- Optimize for mobile performance

## Support and Resources

- **Documentation**: `/docs/` directory contains technical details
- **Model Building**: `/scripts/build_native_lib.sh` for compilation
- **Emergency Patterns**: Built-in responses always available
- **Platform Support**: Android, Linux, Windows, macOS

Remember: This app is designed to work in challenging conditions with limited resources. The pattern-based responses ensure you always have access to critical information, even without a language model loaded.