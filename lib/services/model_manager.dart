import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';

/// Service for managing AI model files
class ModelManager {
  static ModelManager? _instance;
  static ModelManager get instance => _instance ??= ModelManager._();
  ModelManager._();


  /// Check if Qwen2 model exists in chat directory
  Future<bool> setupQwen2Model() async {
    try {
      // Check if model exists in chat directory
      if (await isChatModelAvailable) {
        print('✅ Qwen2 1.5B Instruct model available in chat directory');
        return true;
      }

      print('⚠️ Qwen2 1.5B Instruct model not found in chat directory. Please place it in ${AppConstants.chatModelDir}');
      return false;
    } catch (e) {
      print('❌ Error checking Qwen2 1.5B Instruct model: $e');
      return false;
    }
  }


  /// Get all available GGUF models
  Future<List<String>> getAvailableModels() async {
    final models = <String>[];

    try {
      // Only check the designated chat models directory
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
        print('Scanning for GGUF models...');
        await for (final entity in downloadsDir.list()) {
          if (entity is File && entity.path.endsWith('.gguf')) {
            print('Found GGUF model: ${entity.path}');
            models.add(entity.path);
          }
        }
      }
    } catch (e) {
      print('Error accessing models directory: $e');
    }
  }

  /// Get the chat models directory from external storage
  Future<Directory> get chatModelsDirectory async {
    final chatModelsDir = Directory(AppConstants.chatModelDir);
    if (!await chatModelsDir.exists()) {
      await chatModelsDir.create(recursive: true);
    }
    return chatModelsDir;
  }

  /// Check if a file is a valid GGUF model
  Future<bool> isValidGGUFModel(String modelPath) async {
    try {
      final file = File(modelPath);
      if (!await file.exists()) {
        return false;
      }

      // Check file size (should be at least 1MB for a real model)
      final size = await file.length();
      if (size < 1000000) {
        return false;
      }

      // Check GGUF magic bytes
      final bytes = await file.openRead(0, 4).first;
      final magic = String.fromCharCodes(bytes);
      return magic == 'GGUF';
    } catch (e) {
      print('Error validating GGUF model: $e');
      return false;
    }
  }

  /// Check if model exists in the chat models directory
  Future<bool> get isChatModelAvailable async {
    final chatModelsDir = await chatModelsDirectory;
    final modelPath = '${chatModelsDir.path}/${AppConstants.chatModelName}';
    return await isValidGGUFModel(modelPath);
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
