import 'dart:io';

/// Device information and capability detection utility
class DeviceInfo {
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      // Get basic system information
      final Map<String, dynamic> info = {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
        'numberOfProcessors': Platform.numberOfProcessors,
      };

      // Get memory information (platform-specific)
      if (Platform.isAndroid || Platform.isLinux) {
        final memInfo = await _getLinuxMemoryInfo();
        info.addAll(memInfo);
      } else {
        // Fallback estimates for other platforms
        info['totalMemoryMB'] = 4096; // Conservative estimate
        info['availableMemoryMB'] = 2048;
      }

      return info;
    } catch (e) {
      print('Error getting device info: $e');
      // Return safe fallback values
      return {
        'platform': Platform.operatingSystem,
        'version': 'unknown',
        'numberOfProcessors': 4,
        'totalMemoryMB': 2048,
        'availableMemoryMB': 1024,
      };
    }
  }

  /// Get memory information on Linux/Android systems
  static Future<Map<String, int>> _getLinuxMemoryInfo() async {
    try {
      // Try to read /proc/meminfo
      final file = File('/proc/meminfo');
      if (await file.exists()) {
        final content = await file.readAsString();
        final lines = content.split('\n');

        int totalMemKB = 0;
        int availableMemKB = 0;
        int freeMemKB = 0;
        int buffersKB = 0;
        int cachedKB = 0;

        for (String line in lines) {
          if (line.startsWith('MemTotal:')) {
            totalMemKB = _extractMemoryValue(line);
          } else if (line.startsWith('MemAvailable:')) {
            availableMemKB = _extractMemoryValue(line);
          } else if (line.startsWith('MemFree:')) {
            freeMemKB = _extractMemoryValue(line);
          } else if (line.startsWith('Buffers:')) {
            buffersKB = _extractMemoryValue(line);
          } else if (line.startsWith('Cached:')) {
            cachedKB = _extractMemoryValue(line);
          }
        }

        // If MemAvailable is not available, estimate it
        if (availableMemKB == 0) {
          availableMemKB = freeMemKB + buffersKB + cachedKB;
        }

        return {
          'totalMemoryMB': (totalMemKB / 1024).round(),
          'availableMemoryMB': (availableMemKB / 1024).round(),
        };
      }
    } catch (e) {
      print('Error reading memory info: $e');
    }

    // Fallback for mobile devices
    return {
      'totalMemoryMB': 3072, // Conservative estimate for modern mobile
      'availableMemoryMB': 1536,
    };
  }

  /// Extract memory value from /proc/meminfo line
  static int _extractMemoryValue(String line) {
    final regex = RegExp(r'(\d+)\s*kB');
    final match = regex.firstMatch(line);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 0;
  }

  /// Check if device meets minimum requirements for model loading
  static Future<bool> meetsMinimumRequirements({
    int minRAMMB = 2048,
    int minCores = 2,
  }) async {
    final info = await getDeviceInfo();
    final totalRAM = info['totalMemoryMB'] ?? 0;
    final cores = info['numberOfProcessors'] ?? 0;

    return totalRAM >= minRAMMB && cores >= minCores;
  }

  /// Get recommended model size based on available memory
  static Future<String> getRecommendedModelSize() async {
    final info = await getDeviceInfo();
    final availableRAM = info['availableMemoryMB'] ?? 0;

    if (availableRAM >= 4096) {
      return 'Large (3B+ parameters)';
    } else if (availableRAM >= 2048) {
      return 'Medium (1.5B parameters)';
    } else if (availableRAM >= 1024) {
      return 'Small (< 1B parameters)';
    } else {
      return 'Micro (< 500M parameters)';
    }
  }
}