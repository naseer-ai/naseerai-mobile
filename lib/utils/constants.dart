class AppConstants {
  static const String appName = 'NaseerAI';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Local AI Model Runner for Mobile';

  static const String defaultModelPath = 'assets/models/phi2_demo_placeholder.tflite';
  static const String modelsDirectory = 'assets/models/';
  
  static const int maxInputLength = 512;
  static const double defaultConfidenceThreshold = 0.5;
  static const int defaultThreadCount = 4;
  
  static const Duration inferenceTimeout = Duration(seconds: 30);
  static const Duration modelLoadTimeout = Duration(seconds: 60);

  static const Map<String, String> supportedModelFormats = {
    '.tflite': 'TensorFlow Lite',
    '.onnx': 'ONNX (Future Support)',
    '.bin': 'Custom Binary Format',
  };

  static const List<String> supportedInputTypes = [
    'text',
    'image',
    'audio',
    'custom',
  ];

  static const Map<String, dynamic> defaultModelMetadata = {
    'input_shape': {
      'batch_size': 1,
      'sequence_length': 2048,
      'vocab_size': 51200,
    },
    'output_shape': {
      'vocab_size': 51200,
    },
    'confidence_threshold': 0.5,
    'max_new_tokens': 256,
    'model_type': 'phi-2',
    'labels': <String>[],
  };

  static const List<String> preloadedModels = [
    'assets/models/phi2_demo_placeholder.tflite',
  ];

  static const String githubRepository = 'https://github.com/your-org/naseerai';
  static const String documentationUrl = 'https://your-docs-url.com';
  static const String issuesUrl = 'https://github.com/your-org/naseerai/issues';

  static const Map<String, String> errorMessages = {
    'model_not_found': 'The specified model file was not found.',
    'model_load_failed': 'Failed to load the AI model.',
    'inference_failed': 'Failed to run inference on the model.',
    'invalid_input': 'The provided input is invalid.',
    'unsupported_format': 'The model format is not supported.',
    'insufficient_memory': 'Insufficient memory to load the model.',
    'network_unavailable': 'Network connection is not available.',
  };

  static const Map<String, String> successMessages = {
    'model_loaded': 'Model loaded successfully.',
    'inference_complete': 'Inference completed successfully.',
    'model_unloaded': 'Model unloaded successfully.',
  };
}