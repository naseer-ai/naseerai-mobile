import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../services/capsule_search_service.dart';

class Capsule {
  final String title;
  final String shortDescription;
  final String installLink;
  final String uid;
  final List<String> topics;

  const Capsule({
    required this.title,
    required this.shortDescription,
    required this.installLink,
    required this.uid,
    required this.topics,
  });
}

class CapsulesScreen extends StatefulWidget {
  const CapsulesScreen({super.key});

  @override
  State<CapsulesScreen> createState() => _CapsulesScreenState();
}

class _CapsulesScreenState extends State<CapsulesScreen> {
  final List<Capsule> _capsules = [
    const Capsule(
      title: 'Burns First aid',
      shortDescription:
          'Learn how to identify and treat burns, from minor injuries to major emergencies. Includes first aid steps, when to seek medical help, and important do’s and don’ts for proper burn care.',
      installLink:
          'https://raw.githubusercontent.com/naseer-ai/naseerai-mobile/refs/heads/dev/sample_capsules/Burns_First_aid_embeddings.json',
      uid: 'kRE1AcS',
      topics: ['first aid', 'burns'],
    ),
    const Capsule(
      title: 'Cuts and scrapes',
      shortDescription:
          'Basic care tips for treating minor cuts and scrapes at home, including cleaning, bandaging, and when to seek medical help.',
      installLink:
          'https://drive.google.com/uc?export=download&id=1XHEjNFgV-Yr31oB7a_N0r5Z8_Gt7Gm2A',
      uid: 'N0r5Z8',
      topics: ['first aid', 'cuts', 'scrapes'],
    ),
    const Capsule(
      title: 'Sample Capsule',
      shortDescription: 'Sample capsule with a news realted layoffs by Trump',
      installLink:
          'https://raw.githubusercontent.com/naseer-ai/naseerai-mobile/refs/heads/dev/sample_capsules/sample_embeddings.json',
      uid: 'random123`',
      topics: ['sample', 'news'],
    ),
  ];

  final Map<String, bool> _installationStatus = {};

  @override
  void initState() {
    super.initState();
    _checkInstallationStatus();
  }

  Future<void> _checkInstallationStatus() async {
    // Check installation status efficiently without blocking UI
    final results = await _checkAllCapsulesInstalled();
    setState(() {
      _installationStatus.addAll(results);
    });
  }

  Future<Map<String, bool>> _checkAllCapsulesInstalled() async {
    final results = <String, bool>{};

    try {
      final directory = Directory('/sdcard/naseerai/capsules');
      if (!await directory.exists()) {
        // If directory doesn't exist, all capsules are not installed
        for (final capsule in _capsules) {
          results[capsule.uid] = false;
        }
        return results;
      }

      // Get all files once instead of listing for each capsule
      final files = await directory.list().toList();
      final fileNames =
          files.where((file) => file is File).map((file) => file.path).toSet();

      // Check each capsule against the file list
      for (final capsule in _capsules) {
        results[capsule.uid] = fileNames
            .any((fileName) => fileName.contains('__${capsule.uid}__.json'));
      }
    } catch (e) {
      // If any error occurs, assume all capsules are not installed
      for (final capsule in _capsules) {
        results[capsule.uid] = false;
      }
    }

    return results;
  }

  Future<void> _toggleInstall(Capsule capsule) async {
    final isInstalled = _installationStatus[capsule.uid] ?? false;

    if (isInstalled) {
      await _uninstallCapsule(capsule);
    } else {
      await _installCapsule(capsule);
    }

    await _checkInstallationStatus();
  }

  Future<void> _installCapsule(Capsule capsule) async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Installing ${capsule.title}...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final response = await http.get(Uri.parse(capsule.installLink));

      if (response.statusCode == 200) {
        final directory = Directory('/sdcard/naseerai/capsules');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        final fileName =
            '${capsule.title.replaceAll(' ', '_')}__${capsule.uid}__.json';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        CapsuleSearchService().refresh();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${capsule.title} installed successfully'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to download capsule');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to install ${capsule.title}: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uninstallCapsule(Capsule capsule) async {
    try {
      final directory = Directory('/sdcard/naseerai/capsules');
      if (await directory.exists()) {
        final files = await directory.list().toList();
        for (final file in files) {
          if (file is File && file.path.contains('__${capsule.uid}__.json')) {
            await file.delete();
            break;
          }
        }
      }

      CapsuleSearchService().refresh();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${capsule.title} uninstalled'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to uninstall ${capsule.title}: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isInstalled(Capsule capsule) {
    return _installationStatus[capsule.uid] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capsules'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Knowledge Capsules',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Install specialized knowledge modules for offline emergency assistance',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _capsules.length,
                itemBuilder: (context, index) {
                  final capsule = _capsules[index];
                  final isInstalled = _isInstalled(capsule);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      capsule.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      capsule.shortDescription,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () => _toggleInstall(capsule),
                                icon: Icon(
                                  isInstalled ? Icons.delete : Icons.download,
                                  size: 18,
                                ),
                                label:
                                    Text(isInstalled ? 'Uninstall' : 'Install'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isInstalled
                                      ? Colors.red
                                      : Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: capsule.topics.map((topic) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  topic,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
