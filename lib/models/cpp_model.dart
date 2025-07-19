import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'ai_model.dart';

typedef InitModelC = Int32 Function(Pointer<Utf8> modelPath);
typedef InitModel = int Function(Pointer<Utf8> modelPath);

typedef GenerateTextC = Pointer<Utf8> Function(Pointer<Utf8> prompt, Int32 maxTokens);
typedef GenerateText = Pointer<Utf8> Function(Pointer<Utf8> prompt, int maxTokens);

typedef CleanupModelC = Void Function();
typedef CleanupModel = void Function();

typedef FreeStringC = Void Function(Pointer<Utf8> str);
typedef FreeString = void Function(Pointer<Utf8> str);

class CppModel extends AIModel {
  late DynamicLibrary _lib;
  late InitModel _initModel;
  late GenerateText _generateText;
  late CleanupModel _cleanupModel;
  late FreeString _freeString;
  
  bool _isInitialized = false;

  CppModel({
    required super.id,
    required super.name,
    required super.modelPath,
    super.type = ModelType.textGeneration,
    super.version = '1.0.0',
    super.metadata = const {},
  });

  static CppModel fromModelFile(String modelPath, String modelName) {
    return CppModel(
      id: _getIdFromPath(modelPath),
      name: modelName,
      modelPath: modelPath,
      metadata: {
        'model_type': 'cpp_native',
        'supports_streaming': true,
        'max_context_length': 4096,
        'quantization': 'q4_0',
        'architecture': 'llama',
      },
    );
  }

  Future<bool> initializeNativeLibrary() async {
    try {
      if (_isInitialized) return true;

      String libraryPath;
      if (Platform.isAndroid) {
        libraryPath = 'libnaseer_model.so';
      } else if (Platform.isLinux) {
        // Try to find the library in the project lib directory first
        final currentDir = Directory.current.path;
        final projectLibPath = '$currentDir/lib/libnaseer_model.so';
        if (File(projectLibPath).existsSync()) {
          libraryPath = projectLibPath;
        } else {
          libraryPath = './lib/libnaseer_model.so';
        }
      } else if (Platform.isWindows) {
        libraryPath = 'naseer_model.dll';
      } else if (Platform.isMacOS) {
        libraryPath = 'libnaseer_model.dylib';
      } else {
        throw UnsupportedError('Platform not supported for native models');
      }

      _lib = DynamicLibrary.open(libraryPath);

      _initModel = _lib.lookup<NativeFunction<InitModelC>>('init_model').asFunction();
      _generateText = _lib.lookup<NativeFunction<GenerateTextC>>('generate_text').asFunction();
      _cleanupModel = _lib.lookup<NativeFunction<CleanupModelC>>('cleanup_model').asFunction();
      _freeString = _lib.lookup<NativeFunction<FreeStringC>>('free_string').asFunction();

      _isInitialized = true;
      setStatus(ModelStatus.loading);
      return true;
    } catch (e) {
      setError('Failed to initialize native library: ${e.toString()}');
      return false;
    }
  }

  Future<bool> loadModel() async {
    try {
      if (!_isInitialized) {
        bool initSuccess = await initializeNativeLibrary();
        if (!initSuccess) return false;
      }

      final modelPathPtr = modelPath.toNativeUtf8();
      final result = _initModel(modelPathPtr);
      malloc.free(modelPathPtr);

      if (result == 0) {
        setStatus(ModelStatus.loaded);
        return true;
      } else {
        setError('Native model initialization failed with code: $result');
        return false;
      }
    } catch (e) {
      setError('Failed to load model: ${e.toString()}');
      return false;
    }
  }

  Future<String> generateResponse(String prompt, {int maxTokens = 256}) async {
    try {
      if (!isLoaded) {
        throw Exception('Model not loaded. Call loadModel() first.');
      }

      final promptPtr = prompt.toNativeUtf8();
      final resultPtr = _generateText(promptPtr, maxTokens);
      malloc.free(promptPtr);

      if (resultPtr.address == 0) {
        throw Exception('Native model returned null response');
      }

      final response = resultPtr.toDartString();
      _freeString(resultPtr);

      return response;
    } catch (e) {
      throw Exception('Text generation failed: ${e.toString()}');
    }
  }

  void unloadModel() {
    try {
      if (_isInitialized && isLoaded) {
        _cleanupModel();
        setStatus(ModelStatus.unloaded);
      }
    } catch (e) {
      // Log error if needed - avoiding print in production
    }
  }

  @override
  void setStatus(ModelStatus status) {
    super.setStatus(status);
    if (status == ModelStatus.unloaded) {
      _isInitialized = false;
    }
  }

  static String _getIdFromPath(String path) {
    return path.split('/').last.replaceAll(RegExp(r'\.(gguf|bin|safetensors)$'), '');
  }

  bool get isNativeLibraryAvailable {
    try {
      if (Platform.isAndroid) {
        return true; // Assume library is bundled with Android app
      } else if (Platform.isLinux) {
        final currentDir = Directory.current.path;
        final projectLibPath = '$currentDir/lib/libnaseer_model.so';
        return File(projectLibPath).existsSync() || File('./lib/libnaseer_model.so').existsSync();
      } else if (Platform.isWindows) {
        return File('naseer_model.dll').existsSync();
      } else if (Platform.isMacOS) {
        return File('libnaseer_model.dylib').existsSync();
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> getModelInfo() {
    return {
      'id': id,
      'name': name,
      'path': modelPath,
      'type': 'cpp_native',
      'status': status.toString(),
      'initialized': _isInitialized,
      'library_available': isNativeLibraryAvailable,
      'metadata': metadata,
    };
  }
}