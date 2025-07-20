import 'device_info.dart';

/// Model configuration optimizer for mobile devices
class ModelConfigOptimizer {
  static Future<ModelConfig> getOptimalConfig({
    String? modelPath,
    int? availableMemoryMB,
  }) async {
    // Get device information if not provided
    availableMemoryMB ??= await _getAvailableMemory();
    
    // Determine model size category
    final modelSizeCategory = await _determineModelSize(modelPath);
    
    // Generate optimal configuration
    return _generateConfig(availableMemoryMB, modelSizeCategory);
  }

  static Future<int> _getAvailableMemory() async {
    try {
      final deviceInfo = await DeviceInfo.getDeviceInfo();
      return deviceInfo['availableMemoryMB'] ?? 2048;
    } catch (e) {
      return 2048; // Conservative fallback
    }
  }

  static Future<ModelSizeCategory> _determineModelSize(String? modelPath) async {
    if (modelPath == null) return ModelSizeCategory.medium;
    
    try {
      // Determine size from filename patterns
      final fileName = modelPath.split('/').last.toLowerCase();
      
      if (fileName.contains('tinyllama') || fileName.contains('1.1b')) {
        return ModelSizeCategory.small;
      } else if (fileName.contains('1.5b') || fileName.contains('qwen2')) {
        return ModelSizeCategory.medium;
      } else if (fileName.contains('3b') || fileName.contains('7b')) {
        return ModelSizeCategory.large;
      }
      
      return ModelSizeCategory.medium;
    } catch (e) {
      return ModelSizeCategory.medium;
    }
  }

  static ModelConfig _generateConfig(int availableMemoryMB, ModelSizeCategory modelSize) {
    // Base configuration
    ModelConfig config = ModelConfig(
      maxTokens: 256,
      temperature: 0.7,
      topK: 40,
      topP: 0.9,
      contextLength: 2048,
      batchSize: 1,
      numThreads: 4,
    );

    // Memory-based optimizations
    if (availableMemoryMB < 1024) {
      // Very low memory devices
      config = config.copyWith(
        maxTokens: 64,
        contextLength: 512,
        numThreads: 2,
        temperature: 0.8, // Higher temp for faster inference
      );
    } else if (availableMemoryMB < 2048) {
      // Low memory devices
      config = config.copyWith(
        maxTokens: 128,
        contextLength: 1024,
        numThreads: 3,
      );
    } else if (availableMemoryMB < 3072) {
      // Medium memory devices
      config = config.copyWith(
        maxTokens: 256,
        contextLength: 2048,
        numThreads: 4,
      );
    } else {
      // High memory devices
      config = config.copyWith(
        maxTokens: 512,
        contextLength: 4096,
        numThreads: 6,
      );
    }

    // Model size optimizations
    switch (modelSize) {
      case ModelSizeCategory.small:
        config = config.copyWith(
          maxTokens: (config.maxTokens * 1.2).round(),
          numThreads: config.numThreads,
        );
        break;
      case ModelSizeCategory.medium:
        // Keep current config
        break;
      case ModelSizeCategory.large:
        config = config.copyWith(
          maxTokens: (config.maxTokens * 0.8).round(),
          contextLength: (config.contextLength * 0.8).round(),
          numThreads: config.numThreads - 1,
        );
        break;
    }

    return config;
  }

  /// Get safe inference parameters for current conditions
  static Future<Map<String, dynamic>> getSafeInferenceParams() async {
    final config = await getOptimalConfig();
    
    return {
      'max_tokens': config.maxTokens,
      'temperature': config.temperature,
      'top_k': config.topK,
      'top_p': config.topP,
      'context_length': config.contextLength,
      'batch_size': config.batchSize,
      'num_threads': config.numThreads,
    };
  }

  /// Check if model loading is safe with current memory
  static Future<bool> isModelLoadingSafe(String modelPath) async {
    try {
      final deviceInfo = await DeviceInfo.getDeviceInfo();
      final availableMemory = deviceInfo['availableMemoryMB'] ?? 0;
      final totalMemory = deviceInfo['totalMemoryMB'] ?? 0;
      
      // Estimate model memory requirements (rough calculation)
      final modelSize = await _estimateModelMemoryRequirement(modelPath);
      final systemReserved = (totalMemory * 0.3).round(); // 30% for system
      
      return (availableMemory - systemReserved) > modelSize;
    } catch (e) {
      return false; // Conservative: assume not safe if we can't determine
    }
  }

  static Future<int> _estimateModelMemoryRequirement(String modelPath) async {
    try {
      final fileName = modelPath.split('/').last.toLowerCase();
      
      // Conservative estimates based on model names
      if (fileName.contains('tinyllama') || fileName.contains('1.1b')) {
        return 800; // ~800MB for TinyLlama
      } else if (fileName.contains('1.5b')) {
        return 1200; // ~1.2GB for Qwen2-1.5B
      } else if (fileName.contains('3b')) {
        return 2400; // ~2.4GB for 3B models
      } else if (fileName.contains('7b')) {
        return 5600; // ~5.6GB for 7B models
      }
      
      return 1000; // Default conservative estimate
    } catch (e) {
      return 1000;
    }
  }
}

enum ModelSizeCategory {
  small,  // < 1.5B parameters
  medium, // 1.5B - 3B parameters
  large,  // > 3B parameters
}

class ModelConfig {
  final int maxTokens;
  final double temperature;
  final int topK;
  final double topP;
  final int contextLength;
  final int batchSize;
  final int numThreads;

  const ModelConfig({
    required this.maxTokens,
    required this.temperature,
    required this.topK,
    required this.topP,
    required this.contextLength,
    required this.batchSize,
    required this.numThreads,
  });

  ModelConfig copyWith({
    int? maxTokens,
    double? temperature,
    int? topK,
    double? topP,
    int? contextLength,
    int? batchSize,
    int? numThreads,
  }) {
    return ModelConfig(
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      contextLength: contextLength ?? this.contextLength,
      batchSize: batchSize ?? this.batchSize,
      numThreads: numThreads ?? this.numThreads,
    );
  }

  @override
  String toString() {
    return 'ModelConfig(maxTokens: $maxTokens, temp: $temperature, topK: $topK, topP: $topP, ctx: $contextLength, threads: $numThreads)';
  }
}