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
    // Base configuration optimized for quality and reduced repetition
    ModelConfig config = const ModelConfig(
      maxTokens: 256,
      temperature: 0.8, // Higher temperature for more varied responses
      topK: 50,         // Increased for more vocabulary diversity
      topP: 0.95,       // Higher for better coherence
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
        temperature: 0.9, // Higher temp for variety and faster inference
        topK: 40,         // Reduced for faster processing
      );
    } else if (availableMemoryMB < 2048) {
      // Low memory devices
      config = config.copyWith(
        maxTokens: 128,
        contextLength: 1024,
        numThreads: 3,
        temperature: 0.85, // Slightly higher for better variety
      );
    } else if (availableMemoryMB < 3072) {
      // Medium memory devices  
      config = config.copyWith(
        maxTokens: 256,
        contextLength: 2048,
        numThreads: 4,
        temperature: 0.8, // Optimal balance
      );
    } else {
      // High memory devices
      config = config.copyWith(
        maxTokens: 512,
        contextLength: 4096,
        numThreads: 6,
        temperature: 0.75, // Lower for more precise responses
        topK: 60,          // Higher diversity
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
      
      // Estimate model memory requirements (realistic calculation)
      final modelSize = await _estimateModelMemoryRequirement(modelPath);
      final systemReserved = (totalMemory * 0.2).round(); // 20% for system (less conservative)
      
      // Allow loading if we have at least the model size + minimal overhead
      final minimumRequired = modelSize + 100; // Just 100MB buffer
      return (availableMemory - systemReserved) > minimumRequired;
    } catch (e) {
      return false; // Conservative: assume not safe if we can't determine
    }
  }

  static Future<int> _estimateModelMemoryRequirement(String modelPath) async {
    try {
      final fileName = modelPath.split('/').last.toLowerCase();
      
      // More realistic estimates based on actual model names and Q4_K_M quantization
      if (fileName.contains('tinyllama') || fileName.contains('1.1b')) {
        return 700; // ~700MB for TinyLlama Q4_K_M (more realistic)
      } else if (fileName.contains('1.5b')) {
        return 1000; // ~1GB for Qwen2-1.5B Q4_K_M
      } else if (fileName.contains('3b')) {
        return 2000; // ~2GB for 3B models Q4_K_M
      } else if (fileName.contains('7b')) {
        return 4500; // ~4.5GB for 7B models Q4_K_M
      }
      
      return 800; // Default more realistic estimate
    } catch (e) {
      return 800;
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