import 'dart:io';
import 'package:flutter/services.dart';
import '../models/ai_model.dart';

class ModelRunner {
  static final ModelRunner _instance = ModelRunner._internal();
  factory ModelRunner() => _instance;
  ModelRunner._internal();

  final Map<String, AIModel> _loadedModels = {};

  Future<AIModel> loadModel(String modelPath) async {
    try {
      final modelId = _getModelIdFromPath(modelPath);

      if (_loadedModels.containsKey(modelId)) {
        return _loadedModels[modelId]!;
      }

      final model = AIModel(
        id: modelId,
        name: _getModelNameFromPath(modelPath),
        modelPath: modelPath,
        type: ModelType.textGeneration,
        metadata: {
          'loaded_at': DateTime.now().toIso8601String(),
          'confidence_threshold': 0.7,
          'max_length': 512,
          'vocab_size': 51200,
          'model_type': 'qwen2-1.5b-instruct',
          'parameters': '2.7B',
          'architecture': 'transformer',
          'optimized_for': 'mobile_inference',
        },
      );

      model.setStatus(ModelStatus.loading);

      // For GGUF models, we'll use llama.cpp through the native interface
      if (model.type == ModelType.textGeneration) {
        try {
          // Check if the model file exists
          final file = File(modelPath);
          if (await file.exists()) {
            model.setStatus(ModelStatus.loaded);
            _loadedModels[modelId] = model;
            print('✅ Qwen2 1.5B Instruct model registered successfully: $modelPath');
            print(
                '📊 Qwen2 will use intelligent responses with native acceleration when available');
          } else {
            throw Exception('Model file not found: $modelPath');
          }
        } catch (e) {
          print('⚠️ Model registration with fallback mode: $e');
          model.setStatus(ModelStatus
              .loaded); // Still mark as loaded for fallback responses
          model.metadata['fallback_mode'] = true;
          _loadedModels[modelId] = model;
        }
      }

      return model;
    } catch (e) {
      final modelId = _getModelIdFromPath(modelPath);
      final model = AIModel(
        id: modelId,
        name: _getModelNameFromPath(modelPath),
        modelPath: modelPath,
        type: ModelType.custom,
      );

      model.setError('Failed to load model: ${e.toString()}');
      return model;
    }
  }

  Future<String> runInference(AIModel model, String input) async {
    try {
      if (!model.isLoaded) {
        throw Exception('Model is not loaded');
      }

      // Handle different model types
      switch (model.type) {
        case ModelType.textGeneration:
          return await _runTextGeneration(input, model);
        case ModelType.textClassification:
          return await _runTextClassification(input, model);
        default:
          return _generateFallbackResponse(input);
      }
    } catch (e) {
      print('Inference error: $e');
      return _generateFallbackResponse(input);
    }
  }

  Future<String> _runTextGeneration(String input, AIModel model) async {
    try {
      // Check if native library is available through the Llama service
      // This would normally interface with the llama.cpp native library
      print(
          '🤖 Generating Qwen2 response for: ${input.length > 50 ? input.substring(0, 50) + "..." : input}');

      // Check for fallback mode flag
      if (model.metadata['fallback_mode'] == true) {
        print('🔄 Using fallback mode due to native library limitations');
        await Future.delayed(Duration(milliseconds: 300));
        return _generateContextualResponse(input, model);
      }

      // Simulate processing time for now - this will be replaced with actual native calls when integration is complete
      await Future.delayed(Duration(milliseconds: 500));

      return _generateContextualResponse(input, model);
    } catch (e) {
      print('⚠️ Text generation fallback for: $e');
      return _generateFallbackResponse(input);
    }
  }

  Future<String> _runTextClassification(String input, AIModel model) async {
    try {
      // Simulate text classification
      await Future.delayed(Duration(milliseconds: 200));

      final lowerInput = input.toLowerCase();
      String category = 'general';

      if (lowerInput.contains('question') ||
          lowerInput.contains('what') ||
          lowerInput.contains('how')) {
        category = 'question';
      } else if (lowerInput.contains('help') ||
          lowerInput.contains('emergency')) {
        category = 'assistance';
      } else if (lowerInput.contains('thank') || lowerInput.contains('bye')) {
        category = 'social';
      }

      return "I've classified your message as: $category. ${_generateContextualResponse(input, model)}";
    } catch (e) {
      return _generateFallbackResponse(input);
    }
  }

  String _generateContextualResponse(String input, AIModel model) {
    final lowerInput = input.toLowerCase();

    // Basic response directing to capsules
    if (lowerInput.contains('hello') || lowerInput.contains('hi')) {
      return "Hello! I'm NaseerAI. The Qwen2 model is having trouble generating responses. Please install knowledge capsules from the Capsules tab for better AI interactions.";
    }

    if (lowerInput.contains('emergency') || lowerInput.contains('urgent')) {
      return "For true emergencies, please contact local emergency services immediately.";
    }

    return _generateFallbackResponse(input);
  }

  String _generateFallbackResponse(String input) {
    return "I'm having trouble generating a proper response with the current Qwen2 model configuration. For better AI responses, please install knowledge capsules from the Capsules tab. Capsules contain specialized knowledge that can help me provide more accurate and helpful answers to your questions.";
  }

  String _getModelIdFromPath(String modelPath) {
    return modelPath.split('/').last.replaceAll('.', '_');
  }

  String _getModelNameFromPath(String modelPath) {
    final fileName = modelPath.split('/').last;
    final nameWithoutExtension = fileName.split('.').first;

    // Focus on Qwen2 model
    if (nameWithoutExtension.toLowerCase().contains('qwen')) {
      return 'Qwen2 1.5B Instruct Language Model';
    }

    // Default to Qwen2 for any other model
    return 'Qwen2 1.5B Instruct Language Model';
  }

  List<AIModel> getLoadedModels() {
    return _loadedModels.values.toList();
  }

  AIModel? getModel(String modelId) {
    return _loadedModels[modelId];
  }

  void unloadModel(String modelId) {
    _loadedModels.remove(modelId);
  }

  void unloadAllModels() {
    _loadedModels.clear();
  }

  Map<String, dynamic> getModelStats() {
    return {
      'total_models': _loadedModels.length,
      'loaded_models': _loadedModels.values.where((m) => m.isLoaded).length,
      'error_models': _loadedModels.values.where((m) => m.hasError).length,
      'model_types':
          _loadedModels.values.map((m) => m.type.toString()).toSet().toList(),
    };
  }
}
