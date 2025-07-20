import 'dart:async';
import 'dart:io';

/// Memory monitoring utility for tracking memory usage during model operations
class MemoryMonitor {
  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  int _maxMemoryUsageMB = 0;
  final List<MemorySnapshot> _snapshots = [];

  /// Start monitoring memory usage
  void startMonitoring({Duration interval = const Duration(seconds: 2)}) {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _maxMemoryUsageMB = 0;
    _snapshots.clear();
    
    _monitoringTimer = Timer.periodic(interval, (timer) {
      _takeSnapshot();
    });
    
    print('🔍 Memory monitoring started');
  }

  /// Stop monitoring memory usage
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    
    print('🔍 Memory monitoring stopped');
    _printSummary();
  }

  /// Take a memory snapshot
  void _takeSnapshot([String? label]) {
    if (!_isMonitoring) return;
    
    try {
      final snapshot = MemorySnapshot(
        timestamp: DateTime.now(),
        label: label,
        memoryUsageMB: _getCurrentMemoryUsage(),
      );
      
      _snapshots.add(snapshot);
      
      if (snapshot.memoryUsageMB > _maxMemoryUsageMB) {
        _maxMemoryUsageMB = snapshot.memoryUsageMB;
      }
      
      // Check for concerning memory growth
      if (_snapshots.length > 5) {
        _checkMemoryTrend();
      }
    } catch (e) {
      print('Error taking memory snapshot: $e');
    }
  }

  /// Get current memory usage in MB
  int _getCurrentMemoryUsage() {
    try {
      if (Platform.isAndroid || Platform.isLinux) {
        return _getLinuxProcessMemory();
      }
      // Fallback for other platforms
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get process memory usage on Linux/Android
  int _getLinuxProcessMemory() {
    try {
      final currentPid = Platform.isAndroid ? 'self' : 'self';
      final statusFile = File('/proc/$currentPid/status');
      if (statusFile.existsSync()) {
        final content = statusFile.readAsStringSync();
        final lines = content.split('\n');
        
        for (String line in lines) {
          if (line.startsWith('VmRSS:')) {
            final match = RegExp(r'(\d+)\s*kB').firstMatch(line);
            if (match != null) {
              final memoryKB = int.parse(match.group(1)!);
              return (memoryKB / 1024).round();
            }
          }
        }
      }
    } catch (e) {
      // Silent failure for memory reading
    }
    return 0;
  }

  /// Check for concerning memory trends
  void _checkMemoryTrend() {
    if (_snapshots.length < 5) return;
    
    final recent = _snapshots.length > 5 
        ? _snapshots.sublist(_snapshots.length - 5)
        : _snapshots;
    final growth = recent.last.memoryUsageMB - recent.first.memoryUsageMB;
    
    if (growth > 100) { // 100MB growth in recent snapshots
      print('⚠️ High memory growth detected: +${growth}MB');
    }
    
    if (recent.last.memoryUsageMB > 1500) { // High absolute usage
      print('⚠️ High memory usage: ${recent.last.memoryUsageMB}MB');
    }
  }

  /// Log current memory usage with optional label
  void logCurrentUsage(String label) {
    final currentUsage = _getCurrentMemoryUsage();
    print('📊 Memory usage ($label): ${currentUsage}MB');
    
    if (_isMonitoring) {
      _takeSnapshot(label);
    }
  }

  /// Print memory monitoring summary
  void _printSummary() {
    if (_snapshots.isEmpty) return;
    
    print('📊 Memory Monitoring Summary:');
    print('   Total snapshots: ${_snapshots.length}');
    print('   Peak memory usage: ${_maxMemoryUsageMB}MB');
    
    if (_snapshots.length >= 2) {
      final first = _snapshots.first;
      final last = _snapshots.last;
      final totalGrowth = last.memoryUsageMB - first.memoryUsageMB;
      print('   Total memory change: ${totalGrowth > 0 ? '+' : ''}${totalGrowth}MB');
    }
    
    // Show labeled snapshots
    final labeledSnapshots = _snapshots.where((s) => s.label != null).toList();
    if (labeledSnapshots.isNotEmpty) {
      print('   Key checkpoints:');
      for (final snapshot in labeledSnapshots) {
        print('     ${snapshot.label}: ${snapshot.memoryUsageMB}MB');
      }
    }
  }

  /// Get current memory statistics
  Map<String, dynamic> getMemoryStats() {
    return {
      'isMonitoring': _isMonitoring,
      'currentUsageMB': _getCurrentMemoryUsage(),
      'maxUsageMB': _maxMemoryUsageMB,
      'snapshotCount': _snapshots.length,
    };
  }

  /// Dispose of the monitor
  void dispose() {
    stopMonitoring();
    _snapshots.clear();
  }
}

/// Memory snapshot data class
class MemorySnapshot {
  final DateTime timestamp;
  final String? label;
  final int memoryUsageMB;

  MemorySnapshot({
    required this.timestamp,
    this.label,
    required this.memoryUsageMB,
  });

  @override
  String toString() {
    final timeStr = timestamp.toLocal().toString().substring(11, 19);
    final labelStr = label != null ? ' ($label)' : '';
    return '$timeStr$labelStr: ${memoryUsageMB}MB';
  }
}