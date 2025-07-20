import 'dart:io';
import 'dart:convert';

/// Crash recovery and state management utility
class CrashRecovery {
  static const String _stateFile = '/storage/emulated/0/naseerai/app_state.json';
  static const String _crashLogFile = '/storage/emulated/0/naseerai/crash_log.txt';

  /// Save application state before risky operations
  static Future<void> saveState({
    String? lastModelPath,
    Map<String, dynamic>? lastConfig,
    String? operation,
  }) async {
    try {
      final state = {
        'timestamp': DateTime.now().toIso8601String(),
        'lastModelPath': lastModelPath,
        'lastConfig': lastConfig,
        'operation': operation,
        'version': '1.0.0',
      };

      final file = File(_stateFile);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(state));
    } catch (e) {
      print('Failed to save state: $e');
    }
  }

  /// Load last saved state
  static Future<Map<String, dynamic>?> loadLastState() async {
    try {
      final file = File(_stateFile);
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Failed to load state: $e');
    }
    return null;
  }

  /// Log a crash or error with context
  static Future<void> logCrash({
    required String error,
    String? modelPath,
    Map<String, dynamic>? deviceInfo,
    String? operation,
  }) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '''
========================================
CRASH REPORT - $timestamp
========================================
Error: $error
Model Path: ${modelPath ?? 'None'}
Operation: ${operation ?? 'Unknown'}
Device Info: ${deviceInfo ?? 'Not available'}
----------------------------------------

''';

      final file = File(_crashLogFile);
      await file.parent.create(recursive: true);
      
      // Append to existing log or create new
      await file.writeAsString(logEntry, mode: FileMode.append);
      
      // Keep only last 10 crash reports to prevent large files
      await _trimCrashLog();
      
    } catch (e) {
      print('Failed to log crash: $e');
    }
  }

  /// Clean up crash logs to prevent excessive storage use
  static Future<void> _trimCrashLog() async {
    try {
      final file = File(_crashLogFile);
      if (await file.exists()) {
        final content = await file.readAsString();
        final reports = content.split('========================================');
        
        if (reports.length > 20) { // Keep only 10 reports (2 entries per report)
          final trimmed = reports.takeLast(20).join('========================================');
          await file.writeAsString(trimmed);
        }
      }
    } catch (e) {
      print('Failed to trim crash log: $e');
    }
  }

  /// Check if app recovered from a crash
  static Future<bool> isRecoveringFromCrash() async {
    try {
      final state = await loadLastState();
      if (state != null) {
        final lastTimestamp = DateTime.parse(state['timestamp'] as String);
        final timeDiff = DateTime.now().difference(lastTimestamp);
        
        // If state is recent (less than 5 minutes) and app is starting, likely crashed
        if (timeDiff.inMinutes < 5) {
          return true;
        }
      }
    } catch (e) {
      print('Error checking crash recovery: $e');
    }
    return false;
  }

  /// Get crash recovery recommendations
  static Future<List<String>> getRecoveryRecommendations() async {
    final recommendations = <String>[];
    
    try {
      final state = await loadLastState();
      if (state != null) {
        final operation = state['operation'] as String?;
        final modelPath = state['lastModelPath'] as String?;
        
        if (operation == 'model_loading') {
          recommendations.add('Previous model loading failed');
          recommendations.add('Try using a smaller model');
          recommendations.add('Restart the device to free memory');
        }
        
        if (operation == 'inference') {
          recommendations.add('Previous inference operation failed');
          recommendations.add('Try shorter prompts');
          recommendations.add('Reduce token limits');
        }
        
        if (modelPath != null) {
          recommendations.add('Last attempted model: ${modelPath.split('/').last}');
        }
      }
      
      // General recommendations
      recommendations.addAll([
        'Close other apps to free memory',
        'Consider using a model with Q4_K_M quantization',
        'Ensure at least 2GB free RAM for stable operation',
      ]);
      
    } catch (e) {
      recommendations.add('Error generating recommendations: $e');
    }
    
    return recommendations;
  }

  /// Clear recovery state (call after successful operation)
  static Future<void> clearRecoveryState() async {
    try {
      final file = File(_stateFile);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Failed to clear recovery state: $e');
    }
  }

  /// Get crash statistics
  static Future<Map<String, dynamic>> getCrashStats() async {
    try {
      final file = File(_crashLogFile);
      if (await file.exists()) {
        final content = await file.readAsString();
        final reports = content.split('========================================').where((r) => r.trim().isNotEmpty).length;
        
        return {
          'totalCrashes': reports,
          'logFileSize': await file.length(),
          'lastCrashTime': _extractLastCrashTime(content),
        };
      }
    } catch (e) {
      print('Error getting crash stats: $e');
    }
    
    return {
      'totalCrashes': 0,
      'logFileSize': 0,
      'lastCrashTime': null,
    };
  }

  static String? _extractLastCrashTime(String content) {
    try {
      final lines = content.split('\n');
      for (final line in lines.reversed) {
        if (line.startsWith('CRASH REPORT -')) {
          return line.substring('CRASH REPORT - '.length);
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }
}

extension _ListExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return sublist(length - count);
  }
}