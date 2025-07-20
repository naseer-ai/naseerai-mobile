import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import '../models/ai_model.dart';
import 'model_manager.dart';
import '../utils/device_info.dart';
import '../utils/memory_monitor.dart';
import '../utils/model_config_optimizer.dart';
import '../utils/crash_recovery.dart';

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
  bool _isModelLoading = false;
  final MemoryMonitor _memoryMonitor = MemoryMonitor();

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

      // Check for crash recovery
      final isRecovering = await CrashRecovery.isRecoveringFromCrash();
      if (isRecovering) {
        print('🚑 Detected potential previous crash - applying recovery mode');
        final recommendations = await CrashRecovery.getRecoveryRecommendations();
        for (final rec in recommendations) {
          print('💡 $rec');
        }
      }

      await CrashRecovery.saveState(operation: 'service_initialization');
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
        await CrashRecovery.clearRecoveryState(); // Clear any previous crash state
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

  /// Load a GGUF model from the given path with comprehensive safety checks
  Future<bool> loadModel(String modelPath) async {
    try {
      // Prevent concurrent model loading
      if (_isModelLoading) {
        print('⚠️ Model loading already in progress');
        return false;
      }
      _isModelLoading = true;

      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) {
          _isModelLoading = false;
          return false;
        }
      }

      print('🧠 Loading GGUF model from: $modelPath');

      // Pre-flight safety checks including memory requirements
      final safetyCheck = await _performSafetyChecks(modelPath);
      if (!safetyCheck) {
        _isModelLoading = false;
        return false;
      }

      // Additional check for model loading safety
      final isLoadingSafe = await ModelConfigOptimizer.isModelLoadingSafe(modelPath);
      if (!isLoadingSafe) {
        print('⚠️ Model loading not recommended with current memory conditions');
        print('💡 Try closing other apps or restarting device');
        _isModelLoading = false;
        return false;
      }

      // Load model in background with enhanced monitoring
      final result = await _loadModelInBackground(modelPath);
      _isModelLoading = false;
      return result;
    } catch (e) {
      print('❌ Error loading model: $e');
      _isModelLoading = false;
      return false;
    }
  }

  /// Perform comprehensive safety checks before loading model
  Future<bool> _performSafetyChecks(String modelPath) async {
    try {
      // Check if file exists and is readable
      final file = File(modelPath);
      if (!await file.exists()) {
        print('❌ Model file not found: $modelPath');
        return false;
      }

      // Get file size
      final fileSize = await file.length();
      print('📊 Model file size: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB');

      // Device capability check
      final deviceInfo = await DeviceInfo.getDeviceInfo();
      final availableRAM = deviceInfo['availableMemoryMB'] ?? 0;
      final totalRAM = deviceInfo['totalMemoryMB'] ?? 0;

      print('📱 Device RAM: ${totalRAM}MB total, ${availableRAM}MB available');

      // Conservative memory requirements (model size + overhead)
      final requiredRAM = (fileSize / (1024 * 1024)) * 2.5; // 2.5x overhead for safety
      
      if (availableRAM < requiredRAM) {
        print('⚠️ Insufficient memory: need ${requiredRAM.toStringAsFixed(0)}MB, have ${availableRAM}MB');
        print('💡 Suggestion: Close other apps or restart device');
        return false;
      }

      // Validate GGUF file format
      if (!await _validateGGUFFile(file)) {
        print('❌ Invalid GGUF file format');
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Safety check failed: $e');
      return false;
    }
  }

  /// Validate GGUF file format
  Future<bool> _validateGGUFFile(File file) async {
    try {
      final bytes = await file.openRead(0, 8).expand((chunk) => chunk).toList();
      if (bytes.length < 4) return false;
      
      final magic = String.fromCharCodes(bytes.sublist(0, 4));
      return magic == 'GGUF';
    } catch (e) {
      print('Error validating GGUF file: $e');
      return false;
    }
  }

  /// Load model in background with enhanced monitoring and safety
  Future<bool> _loadModelInBackground(String modelPath) async {
    Pointer<Utf8>? pathPtr;
    try {
      return await Future.microtask(() async {
        // Start memory monitoring
        _memoryMonitor.startMonitoring();
        
        // Gradual loading with UI updates
        await Future.delayed(const Duration(milliseconds: 100));
        print('🔄 Initializing model loader...');
        
        await Future.delayed(const Duration(milliseconds: 100));
        print('🔄 Allocating memory...');
        
        // Convert path to C string
        pathPtr = modelPath.toNativeUtf8();

        print('🔄 Loading model into memory...');
        final result = _initModel(pathPtr!);

        if (result == 0) {
          _activeModel = AIModel(
            id: 'llama_model_1',
            name: 'Llama.cpp Model (${modelPath.split('/').last})',
            modelPath: modelPath,
            type: ModelType.textGeneration,
            version: '1.0.0',
          );
          _activeModel!.setStatus(ModelStatus.loaded);

          // Validate model is actually loaded
          if (_isModelLoaded() == 1) {
            print('✅ GGUF model loaded and validated successfully');
            _memoryMonitor.logCurrentUsage('After model load');
            
            // Apply optimal generation parameters
            await setOptimalGenerationParameters(modelPath);
            
            print('🎯 Model configured with optimal parameters');
            return true;
          } else {
            print('❌ Model loading reported success but validation failed');
            return false;
          }
        } else {
          print('❌ Failed to load model (C function returned: $result)');
          _handleLoadingError(result);
          return false;
        }
      }).timeout(
        const Duration(seconds: 60), // Increased timeout for safety
        onTimeout: () {
          print('⏰ Model loading timed out - this may indicate insufficient resources');
          if (pathPtr != null) malloc.free(pathPtr!);
          _memoryMonitor.stopMonitoring();
          return false;
        },
      );
    } catch (e) {
      print('❌ Background model loading error: $e');
      if (pathPtr != null) malloc.free(pathPtr!);
      _memoryMonitor.stopMonitoring();
      return false;
    } finally {
      if (pathPtr != null) malloc.free(pathPtr!);
    }
  }

  /// Handle specific loading errors with helpful messages
  void _handleLoadingError(int errorCode) {
    switch (errorCode) {
      case -1:
        print('💡 Error -1: File format issue. Ensure model is proper GGUF format.');
        break;
      case -2:
        print('💡 Error -2: Memory allocation failed. Try closing other apps.');
        break;
      case -3:
        print('💡 Error -3: Model architecture unsupported.');
        break;
      default:
        print('💡 Error $errorCode: General loading failure. Check model file integrity.');
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

  /// Run model inference with comprehensive safety and monitoring
  Future<String> _runModelInferenceInBackground(String prompt, int maxTokens) async {
    Pointer<Utf8>? promptPtr;
    try {
      // Validate inputs
      if (prompt.trim().isEmpty) {
        return "Please provide a question or prompt.";
      }

      // Limit prompt length to prevent memory issues
      final trimmedPrompt = prompt.length > 2048 
          ? prompt.substring(0, 2048) + "..."
          : prompt;

      // Adjust maxTokens based on available memory
      final safeMaxTokens = await _calculateSafeTokenLimit(maxTokens);
      
      return await Future.microtask(() async {
        // Start memory monitoring for inference
        _memoryMonitor.logCurrentUsage('Before inference');
        
        // Progressive delays to prevent resource contention
        await Future.delayed(const Duration(milliseconds: 50));
        print('🤖 Starting inference (${safeMaxTokens} max tokens)...');
        
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Convert prompt to C string with error handling
        try {
          promptPtr = trimmedPrompt.toNativeUtf8();
        } catch (e) {
          return "Error: Failed to process prompt encoding";
        }

        Pointer<Utf8>? responsePtr;
        try {
          // Call native inference function
          responsePtr = _generateText(promptPtr!, safeMaxTokens);

          if (responsePtr == nullptr) {
            return "I'm having trouble generating a response right now. Please try again.";
          }

          // Extract response with validation
          final response = responsePtr.toDartString();
          
          // Validate response quality
          if (response.trim().isEmpty) {
            return "I generated an empty response. Please try rephrasing your question.";
          }

          if (response.length < 3) {
            return "I generated a very short response. Please try asking a more specific question.";
          }

          _memoryMonitor.logCurrentUsage('After inference');
          print('✅ Generated response (${response.length} chars)');
          return response;
          
        } finally {
          if (responsePtr != null && responsePtr != nullptr) {
            try {
              _freeString(responsePtr);
            } catch (e) {
              print('Warning: Failed to free response memory: $e');
            }
          }
        }
      }).timeout(
        const Duration(seconds: 30), // Balanced timeout
        onTimeout: () {
          _memoryMonitor.logCurrentUsage('After timeout');
          print('⏰ Model inference timed out');
          return "I'm taking longer than expected to process your request. This might be due to high system load. Please try a simpler question or restart the app if this persists.";
        },
      );
    } catch (e) {
      _memoryMonitor.logCurrentUsage('After error');
      print('❌ Background inference error: $e');
      return "I encountered a technical issue: ${e.toString().length > 100 ? 'Internal processing error' : e.toString()}. Please try again.";
    } finally {
      if (promptPtr != null) {
        try {
          malloc.free(promptPtr!);
        } catch (e) {
          print('Warning: Failed to free prompt memory: $e');
        }
      }
    }
  }

  /// Calculate safe token limit based on available memory
  Future<int> _calculateSafeTokenLimit(int requestedTokens) async {
    try {
      final deviceInfo = await DeviceInfo.getDeviceInfo();
      final availableRAM = deviceInfo['availableMemoryMB'] ?? 2048;
      
      // Conservative token limits based on available memory
      int safeLimit;
      if (availableRAM >= 3072) {
        safeLimit = 512; // High memory devices
      } else if (availableRAM >= 2048) {
        safeLimit = 256; // Medium memory devices
      } else if (availableRAM >= 1024) {
        safeLimit = 128; // Low memory devices
      } else {
        safeLimit = 64;  // Very low memory devices
      }
      
      final finalLimit = requestedTokens > safeLimit ? safeLimit : requestedTokens;
      if (finalLimit != requestedTokens) {
        print('📉 Reduced token limit from $requestedTokens to $finalLimit for stability');
      }
      
      return finalLimit;
    } catch (e) {
      print('Error calculating token limit: $e');
      return requestedTokens > 128 ? 128 : requestedTokens; // Conservative fallback
    }
  }

  /// Get available GGUF model files
  Future<List<String>> getAvailableModels() async {
    try {
      final List<String> models = [];

      // Only check the specified chat models directory
      final Directory chatModelsDir = Directory('/storage/emulated/0/naseerai/models/chat/');

      if (await chatModelsDir.exists()) {
        await for (FileSystemEntity entity in chatModelsDir.list()) {
          if (entity is File && entity.path.endsWith('.gguf')) {
            models.add(entity.path);
          }
        }
      } else {
        print('⚠️ Chat models directory does not exist: /storage/emulated/0/naseerai/models/chat/');
      }

      print('📁 Found ${models.length} GGUF models in chat directory');
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

  /// Configure generation parameters with optimization
  Future<void> setOptimalGenerationParameters([String? modelPath]) async {
    if (!_isInitialized) return;

    try {
      final config = await ModelConfigOptimizer.getOptimalConfig(
        modelPath: modelPath ?? _activeModel?.modelPath,
      );
      
      print('🔧 Applying optimal config: $config');
      
      _setTemperature(config.temperature);
      _setTopK(config.topK);
      _setTopP(config.topP);
      
      print('✅ Generation parameters optimized for device');
    } catch (e) {
      print('❌ Error setting optimal parameters: $e');
      // Fallback to safe defaults
      _setTemperature(0.7);
      _setTopK(40);
      _setTopP(0.9);
    }
  }

  /// Configure generation parameters manually
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
