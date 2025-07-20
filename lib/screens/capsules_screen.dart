import 'package:flutter/material.dart';
import '../services/capsule_search_service.dart';

class Capsule {
  final String id;
  final String title;
  final String description;
  final List<String> topics;
  final bool isInstalled;

  const Capsule({
    required this.id,
    required this.title,
    required this.description,
    required this.topics,
    this.isInstalled = false,
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
      id: 'emergency_first_aid',
      title: 'Emergency First Aid',
      description: 'Essential medical assistance protocols',
      topics: ['Medical', 'Emergency', 'Safety'],
    ),
    const Capsule(
      id: 'shelter_guidance',
      title: 'Shelter Guidance',
      description: 'Safe shelter identification and preparation',
      topics: ['Safety', 'Shelter', 'Protection'],
    ),
    const Capsule(
      id: 'water_purification',
      title: 'Water Purification',
      description: 'Methods to make water safe for consumption',
      topics: ['Water', 'Health', 'Survival'],
    ),
    const Capsule(
      id: 'communication_methods',
      title: 'Communication Methods',
      description: 'Alternative ways to stay connected',
      topics: ['Communication', 'Networks', 'Coordination'],
    ),
    const Capsule(
      id: 'resource_conservation',
      title: 'Resource Conservation',
      description: 'Optimize battery and fuel usage',
      topics: ['Energy', 'Conservation', 'Efficiency'],
    ),
    const Capsule(
      id: 'psychological_support',
      title: 'Psychological Support',
      description: 'Mental health and stress management',
      topics: ['Mental Health', 'Support', 'Wellbeing'],
    ),
  ];

  List<Capsule> _installedCapsules = [];

  void _toggleInstall(Capsule capsule) {
    setState(() {
      if (_installedCapsules.any((c) => c.id == capsule.id)) {
        _installedCapsules.removeWhere((c) => c.id == capsule.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${capsule.title} uninstalled'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        _installedCapsules.add(capsule);
        // Refresh search service when new capsule is installed
        CapsuleSearchService().refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${capsule.title} installed'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  bool _isInstalled(Capsule capsule) {
    return _installedCapsules.any((c) => c.id == capsule.id);
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
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      capsule.description,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () => _toggleInstall(capsule),
                                icon: Icon(
                                  isInstalled ? Icons.check : Icons.download,
                                  size: 18,
                                ),
                                label: Text(isInstalled ? 'Installed' : 'Install'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isInstalled 
                                    ? Colors.green 
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
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  topic,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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