# NaseerAI

A comprehensive Flutter mobile application featuring an intelligent offline chatbot with streaming responses, powered by local AI models. No internet connection required - all AI processing happens on your device for complete privacy and instant responses.

## Features

### 🤖 **Intelligent Chatbot**
- 💬 **Streaming Chat Interface**: Real-time word-by-word response generation
- 🧠 **Enhanced AI Responses**: Comprehensive knowledge about water purification, renewable energy, science, and technology
- 💡 **Smart Suggestions**: Context-aware question recommendations that update based on conversation topics
- 🎨 **Modern UI**: Material 3 design with smooth animations and typing indicators
- 📱 **Dual Interface**: Chat mode for natural conversations + Console mode for technical testing

### 🔒 **Complete Privacy & Offline Functionality**
- 🚀 Local AI model execution (no internet required)
- 🔐 Complete privacy - no data leaves your device
- ⚡ Instant responses without network latency
- 📱 Cross-platform support (Android & iOS)

### 🛠️ **Technical Excellence**
- 🔧 Modular and scalable architecture
- 🎯 TensorFlow Lite integration with enhanced fallbacks
- 🧹 Automatic session management and cleanup
- 🎭 Smooth animations and micro-interactions

### 🧠 **AI Capabilities**
- **Water Purification**: Detailed natural water cleaning methods using elements like sunlight, sand, plants
- **Renewable Energy**: Comprehensive explanations of solar, wind, hydro, and geothermal energy
- **Science & Technology**: Physics, chemistry, biology, and AI topics
- **Environmental Solutions**: Sustainability and eco-friendly practices
- **Educational Content**: Learning techniques and step-by-step explanations

### 📱 **Mobile Features**
- **Streaming Responses**: Real-time word-by-word message streaming
- **Session Management**: Automatic session creation and cleanup
- **Typing Indicators**: Animated typing indicators during AI response generation
- **Message Actions**: Copy messages, clear chat, session management
- **Responsive Design**: Optimized for various screen sizes
- **Smooth Animations**: Fluid transitions and micro-interactions

## Getting Started

### Prerequisites

- Flutter SDK (>= 3.0.0)
- Dart SDK (>= 3.0.0)
- Android Studio / Xcode for platform-specific development
- Git for version control

### Quick Start

1. Clone the repository:
```bash
git clone https://github.com/your-org/naseerai.git
cd naseerai
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application:
```bash
flutter run
```

4. **Start chatting!** 
   - Open the app and you'll see the Chat tab by default
   - Try asking: "How to clean water with natural elements?"
   - Watch the AI response stream in real-time!

### 🎯 **Try These Example Questions**

- "How to clean water with natural elements?"
- "Explain renewable energy sources"
- "What is solar disinfection?"
- "How do wind turbines work?"
- "Tell me about sustainable technologies"

### Adding AI Models

1. Place your `.tflite` model files in the `assets/models/` directory
2. Update the `pubspec.yaml` file to include your model in the assets section
3. Modify the model path in `lib/utils/constants.dart` if needed

Example:
```yaml
flutter:
  assets:
    - assets/models/your_model.tflite
```

## Project Structure

```
lib/
├── main.dart                      # Application entry point with navigation
├── screens/                       # UI screens
│   ├── chat_screen.dart          # Main streaming chat interface
│   └── home_screen.dart          # Console mode for technical testing
├── models/                        # Data models
│   ├── ai_model.dart             # AI model representation and metadata
│   └── chat_message.dart         # Chat message and session models
├── services/                      # Business logic and services
│   ├── chat_service.dart         # Chat session management and streaming
│   └── model_runner.dart         # Enhanced AI model with comprehensive responses
├── widgets/                       # Reusable UI components
│   ├── chat_input_widget.dart    # Message input with send button
│   ├── chat_message_widget.dart  # Message bubbles with animations
│   ├── suggestions_widget.dart   # Smart suggestion chips
│   └── typing_indicator.dart     # Animated typing indicator
└── utils/                         # Utilities and constants
    └── constants.dart            # Application-wide constants
```

## Architecture Overview

### Core Components

1. **AIModel**: Represents an AI model with metadata, status tracking, and configuration
2. **ModelRunner**: Singleton service for loading, managing, and running AI models
3. **ChatService**: Manages sessions, message streaming, and AI integration
4. **HomeScreen**: Main UI for user interaction with AI models
5. **ChatScreen**: Streaming chat interface with real-time responses
6. **Constants**: Centralized configuration and app constants

### Key Features

- **Model Management**: Load, unload, and manage multiple AI models
- **Status Tracking**: Real-time model loading and inference status
- **Error Handling**: Comprehensive error management with user-friendly messages
- **Performance Optimization**: GPU delegation support and multi-threading
- **Extensible Design**: Easy to add new model types and inference methods
- **Streaming Chat**: Real-time word-by-word response generation
- **Session Management**: Automatic cleanup and memory management

### AI Integration
- Uses the enhanced `ModelRunner` with comprehensive response patterns
- Fallback responses when TensorFlow Lite model is unavailable
- Word-by-word streaming simulation for natural conversation flow
- Context-aware suggestions based on conversation history

### Offline Capabilities
- All AI processing happens on-device
- No network requests or external dependencies
- Session data stored locally and cleaned up automatically
- Instant responses without connectivity requirements

## Usage Guide

### Chat Mode
1. Open the app and navigate to the "Chat" tab
2. Type your message in the input field
3. Watch AI responses stream in real-time
4. Use suggested questions for quick interactions
5. Long-press messages to copy them

### Console Mode
- Access the original interface via the "Console" tab
- Single input/output format for technical testing
- Model status monitoring and debugging features

## Key Features in Detail

### Streaming Chat Experience
- **Real-time typing**: Messages appear word by word as the AI generates them
- **Typing indicators**: Animated dots show when AI is thinking
- **Smooth scrolling**: Auto-scroll to new messages with smooth animations
- **Message status**: Visual indicators for message delivery status

### Smart Suggestions
- **Context-aware**: Suggestions change based on conversation topics
- **Quick access**: Tap suggestions to instantly send questions
- **Comprehensive topics**: Covers water, energy, science, and technology
- **Dynamic updates**: Suggestions refresh after each AI response

### Session Management
- **Automatic cleanup**: Sessions are cleaned up when app is closed
- **Memory efficient**: Messages stored in memory only during active session
- **Unique IDs**: Each session and message has a unique identifier
- **Error handling**: Graceful handling of session errors and edge cases

## Performance Optimization

### Memory Management
- Automatic session cleanup on app close
- Efficient message storage using Dart collections
- Widget recycling in chat list for smooth scrolling
- Lazy loading of UI components

### Animation Performance
- Hardware-accelerated animations using Flutter's animation framework
- Optimized rebuild cycles with proper state management
- Efficient text streaming with minimal UI updates
- Smooth typing indicators with controlled animation loops

### AI Response Speed
- Pre-compiled response patterns for instant matching
- Efficient text processing algorithms
- Optimized word-by-word streaming with controlled timing
- Fallback responses when TensorFlow Lite model is unavailable

## Contributing

We welcome contributions from the community! Here's how you can help:

### Getting Started with Contributions

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes following our coding standards
4. Add tests for new functionality
5. Submit a pull request with a clear description

### Coding Standards

- Follow Dart/Flutter best practices
- Use meaningful variable and function names
- Add comments for complex logic
- Maintain the existing code style
- Write tests for new features

### Areas for Contribution

- 🔧 **Model Support**: Add support for new AI model formats (ONNX, CoreML, etc.)
- 🎨 **UI/UX**: Improve the user interface and user experience
- 📊 **Performance**: Optimize model loading and inference performance
- 🧪 **Testing**: Add unit tests and integration tests
- 📚 **Documentation**: Improve documentation and add tutorials
- 🐛 **Bug Fixes**: Fix reported issues and bugs

### Adding New AI Responses
To add new topics to the AI's knowledge base:

1. Edit `lib/services/model_runner.dart`
2. Add new response patterns in the `_handleAdvancedQuestions` method
3. Include relevant keywords for pattern matching
4. Test the new responses thoroughly

### UI Improvements
The chat interface uses Material 3 design principles:
- Follow Material Design guidelines for consistency
- Use theme colors and typography from the app's theme
- Ensure proper accessibility support
- Test on various screen sizes

### Pull Request Guidelines

1. Ensure your code follows the project's coding standards
2. Include tests for new functionality
3. Update documentation as needed
4. Provide a clear description of changes
5. Reference any related issues

## Testing

Run tests with:
```bash
flutter test
```

## Building for Production

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## Dependencies

- `flutter`: Flutter SDK
- `tflite_flutter`: TensorFlow Lite integration
- `path_provider`: File system access
- `flutter_isolate`: Background processing
- `camera`: Camera access for image models

## Troubleshooting

### Common Issues

**Model Loading Errors**: Ensure your `.tflite` file is properly placed in `assets/models/`

**Build Errors**: Run `flutter clean` and `flutter pub get`

**Performance Issues**: Check if GPU delegation is properly configured

**App crashes on startup:**
- Ensure Flutter SDK is properly installed
- Run `flutter clean && flutter pub get`
- Check device compatibility (Android 5.0+ required)

**Slow response generation:**
- This is normal for the first response as the AI model initializes
- Subsequent responses should be faster
- Consider the complexity of the question asked

**Suggestions not updating:**
- Restart the app to refresh the suggestion system
- Clear the chat and start a new conversation
- Check if the AI response completed successfully

**UI not responding:**
- Force close and restart the app
- Check available device memory
- Ensure the app has necessary permissions

### Debug Mode
Enable additional logging by:
1. Running the app in debug mode: `flutter run --debug`
2. Check console output for detailed error messages
3. Use the Console tab to test AI model status

### Platform-Specific Notes

#### Android
- Minimum SDK version: 21
- GPU delegation supported via OpenGL ES

#### iOS
- Minimum iOS version: 11.0
- Metal delegate support for GPU acceleration

## Future Enhancements

### Planned Features
- **Voice Input**: Speech-to-text integration for hands-free interaction
- **Image Analysis**: Add camera integration for visual questions
- **Export Chat**: Save conversations to device storage
- **Custom Themes**: Additional color schemes and personalization
- **Offline TTS**: Text-to-speech for accessibility
- **Search History**: Find previous conversations and responses

### Technical Improvements
- **Model Optimization**: Smaller, faster AI models for better performance
- **Caching**: Intelligent response caching for frequently asked questions
- **Background Processing**: Pre-generate responses for common questions
- **Battery Optimization**: Reduce power consumption during extended use

## Roadmap

- [ ] ONNX model support
- [ ] Model quantization tools
- [ ] Batch inference support
- [ ] Model marketplace integration
- [ ] Advanced preprocessing pipelines
- [ ] Model performance analytics

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📖 [Documentation](https://your-docs-url.com)
- 🐛 [Report Issues](https://github.com/your-org/naseerai/issues)
- 💬 [Discussions](https://github.com/your-org/naseerai/discussions)

For technical issues:
1. Check this README for common solutions
2. Review the troubleshooting section
3. Test in both Chat and Console modes
4. Create an issue with detailed error information

## Acknowledgments

- Flutter team for the amazing framework
- TensorFlow team for TensorFlow Lite
- Open-source community for inspiration and contributions

---

**Built with ❤️ using Flutter for completely offline AI assistance**