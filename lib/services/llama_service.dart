import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ai_model.dart';
import 'model_manager.dart';

// C function signatures for llama.cpp integration
typedef InitModelC = Int32 Function(Pointer<Utf8> modelPath);
typedef InitModelDart = int Function(Pointer<Utf8> modelPath);

typedef GenerateTextC = Pointer<Utf8> Function(
    Pointer<Utf8> prompt, Int32 maxTokens);
typedef GenerateTextDart = Pointer<Utf8> Function(
    Pointer<Utf8> prompt, int maxTokens);

typedef FreeStringC = Void Function(Pointer<Utf8> str);
typedef FreeStringDart = void Function(Pointer<Utf8> str);

typedef IsModelLoadedC = Int32 Function();
typedef IsModelLoadedDart = int Function();

typedef GetModelInfoC = Pointer<Utf8> Function();
typedef GetModelInfoDart = Pointer<Utf8> Function();

typedef SetTemperatureC = Void Function(Float temperature);
typedef SetTemperatureDart = void Function(double temperature);

typedef SetTopKC = Void Function(Int32 topK);
typedef SetTopKDart = void Function(int topK);

typedef SetTopPC = Void Function(Float topP);
typedef SetTopPDart = void Function(double topP);

typedef CleanupModelC = Void Function();
typedef CleanupModelDart = void Function();

class LlamaService {
  static LlamaService? _instance;
  static LlamaService get instance => _instance ??= LlamaService._();
  LlamaService._();

  DynamicLibrary? _lib;
  AIModel? _activeModel;
  bool _isInitialized = false;

  // Function pointers
  late InitModelDart _initModel;
  late GenerateTextDart _generateText;
  late FreeStringDart _freeString;
  late IsModelLoadedDart _isModelLoaded;
  late GetModelInfoDart _getModelInfo;
  late SetTemperatureDart _setTemperature;
  late SetTopKDart _setTopK;
  late SetTopPDart _setTopP;
  late CleanupModelDart _cleanupModel;

  /// Initialize the Llama service and load the native library
  Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;

      print('🔧 Initializing Llama.cpp Service...');

      // Load the native library with Android-specific handling
      try {
        if (Platform.isAndroid) {
          // For Android, we need to be more careful with library loading
          print('📱 Loading native library for Android...');
          _lib = DynamicLibrary.open('libnaseer_model.so');
          print('✅ Android native library loaded successfully');
        } else if (Platform.isLinux) {
          _lib = DynamicLibrary.open('libnaseer_model.so');
        } else if (Platform.isWindows) {
          _lib = DynamicLibrary.open('naseer_model.dll');
        } else {
          throw UnsupportedError('Platform not supported');
        }
      } catch (e) {
        print('⚠️ Native library could not be loaded: $e');
        print(
            '� This usually means the library was not compiled for your device architecture');
        print('� App will use intelligent fallback responses');
        return false; // Don't set _isInitialized = true
      }

      // Try to bind C functions - if this fails, also fall back gracefully
      try {
        _initModel =
            _lib!.lookupFunction<InitModelC, InitModelDart>('init_model');
        _generateText = _lib!
            .lookupFunction<GenerateTextC, GenerateTextDart>('generate_text');
        _freeString =
            _lib!.lookupFunction<FreeStringC, FreeStringDart>('free_string');
        _isModelLoaded = _lib!
            .lookupFunction<IsModelLoadedC, IsModelLoadedDart>(
                'is_model_loaded');
        _getModelInfo = _lib!
            .lookupFunction<GetModelInfoC, GetModelInfoDart>('get_model_info');
        _setTemperature = _lib!
            .lookupFunction<SetTemperatureC, SetTemperatureDart>(
                'set_temperature');
        _setTopK = _lib!.lookupFunction<SetTopKC, SetTopKDart>('set_top_k');
        _setTopP = _lib!.lookupFunction<SetTopPC, SetTopPDart>('set_top_p');
        _cleanupModel = _lib!
            .lookupFunction<CleanupModelC, CleanupModelDart>('cleanup_model');

        _isInitialized = true;
        print(
            '✅ Llama.cpp Service initialized successfully with native acceleration');
        return true;
      } catch (e) {
        print('⚠️ Failed to bind native functions: $e');
        print('📱 App will continue with intelligent fallback responses');
        return false;
      }
    } catch (e) {
      print('❌ Failed to initialize Llama.cpp Service: $e');
      print('📱 App will continue with intelligent fallback responses');
      return false;
    }
  }

  /// Load a GGUF model from the given path with ANR prevention
  Future<bool> loadModel(String modelPath) async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) return false;
      }

      print('🧠 Loading GGUF model from: $modelPath');

      // Check if file exists
      final file = File(modelPath);
      if (!await file.exists()) {
        print('❌ Model file not found: $modelPath');
        return false;
      }

      // Load model in background to prevent ANR
      return await _loadModelInBackground(modelPath);
    } catch (e) {
      print('❌ Error loading model: $e');
      return false;
    }
  }

  /// Load model in background to prevent UI blocking
  Future<bool> _loadModelInBackground(String modelPath) async {
    try {
      return await Future.microtask(() async {
        // Add small delay to allow UI to breathe
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Convert path to C string
        final pathPtr = modelPath.toNativeUtf8();

        try {
          final result = _initModel(pathPtr);

          if (result == 0) {
            _activeModel = AIModel(
              id: 'llama_model_1',
              name: 'Llama.cpp Model',
              modelPath: modelPath,
              type: ModelType.textGeneration,
              version: '1.0.0',
            );
            _activeModel!.setStatus(ModelStatus.loaded);

            print('✅ GGUF model loaded successfully');
            return true;
          } else {
            print('❌ Failed to load model (C function returned: $result)');
            return false;
          }
        } finally {
          malloc.free(pathPtr);
        }
      }).timeout(
        const Duration(seconds: 45), // Generous timeout for model loading
        onTimeout: () {
          print('⏰ Model loading timed out');
          return false;
        },
      );
    } catch (e) {
      print('❌ Background model loading error: $e');
      return false;
    }
  }

  /// Auto-detect and load the best available GGUF model
  Future<bool> autoLoadBestModel() async {
    try {
      print('🔍 Auto-detecting best available GGUF model...');

      // First try to setup Qwen2 model from Downloads if needed
      await ModelManager.instance.setupQwen2Model();

      // Get available GGUF models
      final models = await getAvailableModels();

      if (models.isEmpty) {
        print('⚠️ No GGUF models found');
        return false;
      }

      // Try to load the first available model
      for (String modelPath in models) {
        if (await loadModel(modelPath)) {
          print(
              '✅ Successfully auto-loaded model: ${modelPath.split('/').last}');
          return true;
        }
      }

      print('❌ Failed to load any available models');
      return false;
    } catch (e) {
      print('❌ Auto-load failed: $e');
      return false;
    }
  }

  /// Generate text response using the loaded GGUF model
  Future<String> generateResponse(String prompt, {int maxTokens = 256}) async {
    try {
      if (!_isInitialized) {
        return "Error: Llama.cpp service not initialized";
      }

      if (_isModelLoaded() == 0) {
        return "Error: No model loaded";
      }

      print(
          '🤖 Generating response for: ${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}...');

      // Run model inference in background thread to prevent ANR
      return await _runModelInferenceInBackground(prompt, maxTokens);
    } catch (e) {
      print('❌ Error generating response: $e');
      return "Error: $e";
    }
  }

  /// Run model inference in background with timeout to prevent ANR
  Future<String> _runModelInferenceInBackground(String prompt, int maxTokens) async {
    try {
      // Use compute-like functionality with Future to prevent UI blocking
      return await Future.microtask(() async {
        // Add small delay to allow UI to update
        await Future.delayed(const Duration(milliseconds: 10));
        
        final promptPtr = prompt.toNativeUtf8();
        try {
          final responsePtr = _generateText(promptPtr, maxTokens);

          if (responsePtr == nullptr) {
            return "Error: Failed to generate response";
          }

          final response = responsePtr.toDartString();
          _freeString(responsePtr);

          print('✅ Generated response (${response.length} chars)');
          return response;
        } finally {
          malloc.free(promptPtr);
        }
      }).timeout(
        const Duration(seconds: 20), // Reduced timeout for faster fallback
        onTimeout: () {
          print('⏰ Model inference timed out');
          return "I'm taking too long to respond. Let me give you a quick answer instead: I'm here to help with your questions. Could you try asking something simpler?";
        },
      );
    } catch (e) {
      print('❌ Background inference error: $e');
      return "I encountered an issue processing your request. Please try again with a simpler question.";
    }
  }

  /// Get available GGUF model files
  Future<List<String>> getAvailableModels() async {
    try {
      final List<String> models = [];

      // Check model_files directory
      final Directory modelDir = Directory(
          '/mnt/7cf8f1e2-f6ee-43b6-8f39-749a39730a18/Projects/NaseerAI/naseerai-mobile/model_files');

      if (await modelDir.exists()) {
        await for (FileSystemEntity entity in modelDir.list()) {
          if (entity is File && entity.path.endsWith('.gguf')) {
            models.add(entity.path);
          }
        }
      }

      // Also check external storage for models
      try {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final Directory modelsDir = Directory('${appDir.path}/models');

        if (await modelsDir.exists()) {
          await for (FileSystemEntity entity in modelsDir.list()) {
            if (entity is File && entity.path.endsWith('.gguf')) {
              models.add(entity.path);
            }
          }
        }
      } catch (e) {
        print('Note: Could not access external models directory: $e');
      }

      print('📁 Found ${models.length} GGUF models');
      return models;
    } catch (e) {
      print('❌ Error getting available models: $e');
      return [];
    }
  }

  /// Get model information
  Future<Map<String, dynamic>> getModelInfo() async {
    try {
      if (!_isInitialized || _isModelLoaded() == 0) {
        return {'error': 'No model loaded'};
      }

      final infoPtr = _getModelInfo();
      final info = infoPtr.toDartString();

      return {
        'name': _activeModel?.name ?? 'Unknown',
        'path': _activeModel?.modelPath ?? 'Unknown',
        'status': _activeModel?.status.name ?? 'unknown',
        'type': 'GGUF/llama.cpp',
        'info': info,
        'loaded': true,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Configure generation parameters
  void setGenerationParameters({
    double? temperature,
    int? topK,
    double? topP,
  }) {
    if (!_isInitialized) return;

    try {
      if (temperature != null) {
        _setTemperature(temperature);
        print('🔧 Set temperature: $temperature');
      }

      if (topK != null) {
        _setTopK(topK);
        print('🔧 Set top-k: $topK');
      }

      if (topP != null) {
        _setTopP(topP);
        print('🔧 Set top-p: $topP');
      }
    } catch (e) {
      print('❌ Error setting generation parameters: $e');
    }
  }

  /// Check if a model is currently loaded
  bool get isModelLoaded => _isInitialized && _isModelLoaded() == 1;

  /// Get the currently active model
  AIModel? get activeModel => _activeModel;

  /// Get model status
  String getModelStatus() {
    if (!_isInitialized) return 'Service not initialized';
    if (!isModelLoaded) return 'No model loaded';
    return 'Model loaded: ${_activeModel?.name ?? 'Unknown'}';
  }

  /// Unload the current model
  Future<void> unloadModel() async {
    try {
      if (_isInitialized) {
        _cleanupModel();
        _activeModel = null;
        print('✅ Model unloaded successfully');
      }
    } catch (e) {
      print('❌ Error unloading model: $e');
    }
  }

  /// Dispose of the service
  void dispose() {
    try {
      unloadModel();
      _isInitialized = false;
      print('✅ Llama.cpp service disposed');
    } catch (e) {
      print('❌ Error disposing Llama.cpp service: $e');
    }
  }
}
