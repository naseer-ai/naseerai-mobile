import 'dart:io';
import 'llama_service.dart';
import 'gguf_model_service.dart';
import '../models/ai_model.dart';

class NativeModelService {
  static NativeModelService? _instance;
  static NativeModelService get instance =>
      _instance ??= NativeModelService._();
  NativeModelService._();

  AIModel? _activeModel;
  final LlamaService _llamaService = LlamaService.instance;
  
  // Public getter for llama service
  LlamaService get llamaService => _llamaService;

  // Emergency fallback responses for when the model fails to load
  final List<String> _emergencyResponses = [
    "I'm having trouble accessing my AI model right now. Please try again.",
    "My knowledge base is temporarily unavailable. Can you rephrase your question?",
    "I'm experiencing technical difficulties. Let me try to help with basic information.",
    "The AI model is loading. Please wait a moment and try your question again.",
    "I'm working on connecting to my reasoning capabilities. Please be patient.",
  ];

  Future<bool> loadModel(String modelPath) async {
    try {
      print('Loading Llama model from: $modelPath');

      // Check if file exists
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        print('Model file not found at: $modelPath');
        return false;
      }

      // Load model using Llama service
      final success = await _llamaService.loadModel(modelPath);

      if (success) {
        _activeModel = _llamaService.activeModel;
        print('Llama model loaded successfully');
        return true;
      }

      return false;
    } catch (e) {
      print('Error loading Llama model: $e');
      return false;
    }
  }

  /// Auto-detect and load the best available model
  Future<bool> autoLoadBestModel() async {
    try {
      print('🔍 Auto-detecting best available model...');

      // Initialize Llama service first
      final initialized = await _llamaService.initialize();
      if (!initialized) {
        print('❌ Failed to initialize Llama service');
        return false;
      }

      // Try to auto-load GGUF models with Llama.cpp
      final success = await _llamaService.autoLoadBestModel();
      if (success) {
        _activeModel = _llamaService.activeModel;
        print('✅ Successfully auto-loaded model with Llama.cpp');
        await _printAvailableModels();
        return true;
      }

      // Fallback to GGUF models without direct loading
      List<String> ggufModels = await GgufModelService.getAvailableGgufModels();
      if (ggufModels.isNotEmpty) {
        print(
            '🧠 Found ${ggufModels.length} GGUF models - setting up enhanced AI responses');
        await _printAvailableModels();
        return true; // Return true because we can use GGUF context
      }

      print('⚠️ No working models found - using intelligent responses');
      return false;
    } catch (e) {
      print('❌ Auto-load failed: $e');
      return false;
    }
  }

  /// Print information about available models
  Future<void> _printAvailableModels() async {
    print('\n🤖 === Available Models ===');

    // Llama.cpp status
    if (_llamaService.isModelLoaded) {
      final info = await _llamaService.getModelInfo();
      print('✅ Active Llama Model: ${info['name']}');
      print('   Path: ${info['path']}');
      print('   Type: ${info['type']}');
    } else {
      print('❌ No Llama model loaded');
    }

    // GGUF models
    List<String> ggufModels = await GgufModelService.getAvailableGgufModels();
    print('📁 GGUF Models Found: ${ggufModels.length}');

    for (String model in ggufModels) {
      final info = await GgufModelService.getModelInfo(model);
      final size = info['size'] ?? 0;
      final sizeStr = size > 1024 * 1024
          ? '${(size / (1024 * 1024)).toStringAsFixed(1)}MB'
          : '${(size / 1024).toStringAsFixed(1)}KB';
      print('  🧠 ${model.split('/').last} ($sizeStr)');
    }

    print('==========================\n');
  }

  Future<String> generateResponse(String prompt) async {
    try {
      // First try Llama.cpp for real LLM inference with timeout
      if (_llamaService.isModelLoaded) {
        print('Using Llama.cpp for response generation');
        final response = await _llamaService.generateResponse(prompt).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('Response timed out, using fallback');
            return "I'm processing your request, but it's taking longer than expected. Let me provide a quick response instead.";
          },
        );
        
        // Return the actual llama response if it's not an error
        if (response.isNotEmpty && !response.startsWith('Error:')) {
          return response;
        }
      }

      // If model isn't loaded or llama failed, try initialization first
      print('Attempting to auto-load model...');
      final modelLoaded = await autoLoadBestModel();
      if (modelLoaded && _llamaService.isModelLoaded) {
        print('Model loaded successfully, trying generation again...');
        final response = await _llamaService.generateResponse(prompt);
        if (response.isNotEmpty && !response.startsWith('Error:')) {
          return response;
        }
      }

      print('Model not loaded, trying GGUF fallback or intelligent response');
      return await _generateWithGgufFallback(prompt);
    } catch (e) {
      print('Error in generateResponse: $e');
      return await _generateWithGgufFallback(prompt);
    }
  }

  /// Try GGUF model fallback for enhanced responses
  Future<String> _generateWithGgufFallback(String prompt) async {
    try {
      // Get available GGUF models
      List<String> ggufModels = await GgufModelService.getAvailableGgufModels();

      if (ggufModels.isNotEmpty) {
        // Use the first available GGUF model for enhanced responses
        String modelPath = ggufModels.first;
        print('🧠 Using GGUF model context: ${modelPath.split('/').last}');
        return await GgufModelService.generateWithGgufFallback(
            prompt, modelPath);
      } else {
        print('📋 No GGUF models available, using intelligent response');
        return _generateIntelligentResponse(prompt);
      }
    } catch (e) {
      print('GGUF fallback failed: $e');
      return _generateIntelligentResponse(prompt);
    }
  }

  String _generateIntelligentResponse(String prompt) {
    final lowerPrompt = prompt.toLowerCase();

    // Simple math calculations
    if (RegExp(r'\d+\s*[+\-*/]\s*\d+').hasMatch(prompt)) {
      return _tryBasicMath(prompt);
    }

    // Basic emergency handling
    if (lowerPrompt.contains('emergency') || lowerPrompt.contains('urgent')) {
      return "For true emergencies, please contact local emergency services immediately.";
    }

    // Simple greeting
    if (lowerPrompt.contains('hello') || lowerPrompt.contains('hi ') || lowerPrompt.startsWith('hi')) {
      return "Hello! I'm NaseerAI, your offline AI assistant. I can help with basic questions and calculations. What would you like to know?";
    }

    if (lowerPrompt.contains('how are you')) {
      return "I'm functioning and ready to help! What can I assist you with?";
    }

    if (lowerPrompt.contains('what') && lowerPrompt.contains('name')) {
      return "I'm NaseerAI, your offline AI assistant.";
    }
    
    if (lowerPrompt.contains('who are you') || lowerPrompt.contains('who r you')) {
      return "I'm NaseerAI, your offline AI assistant. I'm designed to provide help and information without requiring an internet connection. I can assist with various questions, calculations, and provide guidance on many topics.";
    }

    // Time/Date questions
    if (lowerPrompt.contains('time') || lowerPrompt.contains('date')) {
      final now = DateTime.now();
      return "The current time is ${now.hour}:${now.minute.toString().padLeft(2, '0')} and today's date is ${now.day}/${now.month}/${now.year}.";
    }

    // Default response
    return "I can help with basic questions, math, and general information. The advanced Qwen2 model features are currently being optimized. What would you like to know?";
  }

  String _tryBasicMath(String prompt) {
    try {
      final mathPattern = RegExp(r'(\d+(?:\.\d+)?)\s*([+\-*/])\s*(\d+(?:\.\d+)?)');
      final match = mathPattern.firstMatch(prompt);

      if (match != null) {
        final num1 = double.parse(match.group(1)!);
        final operator = match.group(2)!;
        final num2 = double.parse(match.group(3)!);

        double result;
        switch (operator) {
          case '+':
            result = num1 + num2;
            break;
          case '-':
            result = num1 - num2;
            break;
          case '*':
            result = num1 * num2;
            break;
          case '/':
            if (num2 == 0) return "I can't divide by zero!";
            result = num1 / num2;
            break;
          default:
            return "I can help with basic math (+, -, *, /). What calculation would you like me to do?";
        }

        if (result == result.toInt()) {
          return "${result.toInt()}";
        } else {
          return result.toStringAsFixed(2);
        }
      }
    } catch (e) {
      // Fall through
    }
    return "I can help with basic math! Try asking me something like '10 + 5' or '20 * 3'.";
  }


  AIModel? get activeModel => _activeModel ?? _llamaService.activeModel;

  bool get isModelLoaded => _llamaService.isModelLoaded;

  Future<List<String>> getAvailableModelFiles() async {
    try {
      // Return available GGUF models
      return await _llamaService.getAvailableModels();
    } catch (e) {
      print('Error getting available model files: $e');
      return [];
    }
  }

  String getModelStatus() {
    if (_llamaService.isModelLoaded) {
      return _llamaService.getModelStatus();
    }
    return 'No model loaded';
  }

  Future<Map<String, dynamic>> getSystemInfo() async {
    return {
      'platform': 'Android/iOS',
      'runtime': 'Llama.cpp',
      'model_loaded': isModelLoaded,
      'model_name': activeModel?.name ?? 'None',
    };
  }

  Future<void> unloadModel() async {
    try {
      await _llamaService.unloadModel();
      _activeModel = null;
      print('Model unloaded successfully');
    } catch (e) {
      print('Error unloading model: $e');
    }
  }

  void dispose() {
    _llamaService.dispose();
    _activeModel = null;
  }
}
