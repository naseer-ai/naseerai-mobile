import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/model_manager.dart';
import '../utils/constants.dart';

class ModelInstallDialog extends StatefulWidget {
  const ModelInstallDialog({super.key});

  @override
  State<ModelInstallDialog> createState() => _ModelInstallDialogState();
}

class _ModelInstallDialogState extends State<ModelInstallDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

  static const String _modelUrl = 'https://huggingface.co/Qwen/Qwen2-1.5B-Instruct-GGUF/resolve/main/qwen2-1_5b-instruct-q4_k_m.gguf';
  static const String _modelFileName = AppConstants.defaultModelFileName;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDownloading,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: Colors.blue),
            SizedBox(width: 8),
            Text('Install AI Model'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To start chatting, you need to install an AI model. This is a one-time download that will enable offline AI conversations.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Text(
                  'Model Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('• Size: ~950 MB'),
            const Text('• Type: Language Model (GGUF)'),
            Text('• Storage: ${AppConstants.chatModelsPath}'),
            const Text('• Works completely offline'),
            const SizedBox(height: 16),
            if (_isDownloading) ...[
              Text(
                _downloadStatus,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          if (!_isDownloading) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _downloadModel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download, size: 20),
                  SizedBox(width: 4),
                  Text('Install Model'),
                ],
              ),
            ),
          ] else ...[
            TextButton(
              onPressed: null, // Disable cancel during download
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Preparing download...';
    });

    try {
      // Create the chat models directory
      final chatModelsDir = await ModelManager.instance.chatModelsDirectory;
      final filePath = '${chatModelsDir.path}/$_modelFileName';

      setState(() {
        _downloadStatus = 'Starting download...';
      });

      // Start the download
      final request = http.Request('GET', Uri.parse(_modelUrl));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Failed to download model: ${response.statusCode}');
      }

      final file = File(filePath);
      final sink = file.openWrite();
      
      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;

      setState(() {
        _downloadStatus = 'Downloading model... (${_formatBytes(totalBytes)})';
      });

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        
        if (totalBytes > 0) {
          setState(() {
            _downloadProgress = downloadedBytes / totalBytes;
            _downloadStatus = 'Downloading model... ${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}';
          });
        }
      }

      await sink.close();

      // Verify the downloaded file
      if (await ModelManager.instance.isValidGGUFModel(filePath)) {
        setState(() {
          _downloadStatus = 'Download completed successfully!';
          _downloadProgress = 1.0;
        });

        // Wait a moment to show success message
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Downloaded file is not a valid GGUF model');
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _downloadStatus = 'Download failed: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download model: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}