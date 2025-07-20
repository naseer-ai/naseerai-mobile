import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';

/// Service for managing AI model files
class ModelManager {
  static ModelManager? _instance;
  static ModelManager get instance => _instance ??= ModelManager._();
  ModelManager._();

  static String get _modelFileName => AppConstants.chatModelName;

  /// Get the app's models directory
  Future<Directory> get modelsDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// Get the path to the Qwen2 model
  Future<String> get qwen2ModelPath async {
    final modelsDir = await modelsDirectory;
    return '${modelsDir.path}/$_modelFileName';
  }

  /// Check if Qwen2 model exists
  Future<bool> get isQwen2ModelAvailable async {
    final modelPath = await qwen2ModelPath;
    final modelFile = File(modelPath);
    if (await modelFile.exists()) {
      // Check if it's a valid GGUF file (not just our placeholder)
      final bytes = await modelFile.openRead(0, 4).first;
      final magic = String.fromCharCodes(bytes);
      return magic == 'GGUF' &&
          await modelFile.length() > 1000000; // At least 1MB
    }
    return false;
  }

  /// Copy model from project directory to app directory
  Future<bool> setupQwen2Model() async {
    try {
      // Check if model already exists
      if (await isQwen2ModelAvailable) {
        print('✅ Qwen2 1.5B Instruct model already available');
        return true;
      }

      // Try to copy from project model_files directory
      final projectModelPath = 'model_files/$_modelFileName';
      final projectFile = File(projectModelPath);

      if (await projectFile.exists()) {
        final modelPath = await qwen2ModelPath;
        await projectFile.copy(modelPath);
        print('✅ Qwen2 1.5B Instruct model copied to app directory');
        return true;
      }

      // Try to copy from Downloads directory if available
      if (await _copyFromDownloads()) {
        return true;
      }

      print(
          '⚠️ Qwen2 1.5B Instruct model not found. Please download it to model_files/$_modelFileName');
      return false;
    } catch (e) {
      print('❌ Error setting up Qwen2 1.5B Instruct model: $e');
      return false;
    }
  }

  /// Try to copy model from Downloads directory to app directory
  Future<bool> _copyFromDownloads() async {
    try {
      // Check if we have storage permission
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          return false;
        }
      }

      final downloadsFile = File('${AppConstants.chatModelDir}$_modelFileName');
      if (await downloadsFile.exists()) {
        final modelPath = await qwen2ModelPath;
        await downloadsFile.copy(modelPath);
        print(
            '✅ Qwen2 1.5B Instruct model copied from Downloads to app directory');
        return true;
      }

      return false;
    } catch (e) {
      print('Error copying from Downloads: $e');
      return false;
    }
  }

  /// Get all available GGUF models
  Future<List<String>> getAvailableModels() async {
    final models = <String>[];

    try {
      // Check app's models directory
      final modelsDir = await modelsDirectory;
      await for (final entity in modelsDir.list()) {
        if (entity is File && entity.path.endsWith('.gguf')) {
          models.add(entity.path);
        }
      }

      // Also check Downloads directory for GGUF models
      await _checkDownloadsDirectory(models);
    } catch (e) {
      print('Error scanning models: $e');
    }

    return models;
  }

  /// Check Downloads directory for GGUF models with proper permissions
  Future<void> _checkDownloadsDirectory(List<String> models) async {
    try {
      // Try different permission strategies based on Android version
      bool hasPermission = false;

      // Try manage external storage permission (Android 11+)
      if (await Permission.manageExternalStorage.isGranted) {
        hasPermission = true;
      } else {
        var manageStatus = await Permission.manageExternalStorage.request();
        if (manageStatus.isGranted) {
          hasPermission = true;
        } else {
          // Fallback to regular storage permission
          var storageStatus = await Permission.storage.status;
          if (!storageStatus.isGranted) {
            storageStatus = await Permission.storage.request();
          }
          hasPermission = storageStatus.isGranted;
        }
      }

      if (!hasPermission) {
        print('Storage permission denied');
        return;
      }

      final downloadsDir = Directory(AppConstants.chatModelDir);
      if (await downloadsDir.exists()) {
        print('Scanning Downloads directory for GGUF models...');
        await for (final entity in downloadsDir.list()) {
          if (entity is File && entity.path.endsWith('.gguf')) {
            print('Found GGUF model: ${entity.path}');
            models.add(entity.path);
          }
        }
      }
    } catch (e) {
      print('Error accessing Downloads directory: $e');
    }
  }

  /// Get model info
  Future<Map<String, dynamic>> getModelInfo(String modelPath) async {
    try {
      final file = File(modelPath);
      if (!await file.exists()) {
        throw Exception('Model file not found: $modelPath');
      }

      final size = await file.length();
      return {
        'name': modelPath.split('/').last,
        'path': modelPath,
        'size': size,
        'size_mb': (size / (1024 * 1024)).toStringAsFixed(1),
        'available': true,
      };
    } catch (e) {
      return {
        'name': 'Unknown',
        'path': modelPath,
        'error': e.toString(),
        'available': false,
      };
    }
  }
}
