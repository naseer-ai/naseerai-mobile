import 'package:flutter/material.dart';

class AvailableCapsulesWidget extends StatelessWidget {
  final List<String> availableCapsules;
  final VoidCallback? onClose;

  const AvailableCapsulesWidget({
    super.key,
    required this.availableCapsules,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (availableCapsules.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withAlpha(128),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active capsules:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(179),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onClose != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Capsules chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: availableCapsules
                .map((capsule) => _buildCapsuleChip(context, capsule))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleChip(BuildContext context, String capsule) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(76),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 14,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            _formatCapsuleName(capsule),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCapsuleName(String fileName) {
    // Remove .json extension
    String name = fileName.replaceAll('.json', '');
    
    // Handle format like "sample__UID__" -> "sample"
    if (name.contains('__')) {
      // Split by __ and take the first part
      name = name.split('__').first;
    }
    
    // Convert underscores to spaces and capitalize
    name = name.replaceAll('_', ' ');
    
    // Capitalize each word
    return name.split(' ')
        .map((word) => word.isNotEmpty 
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ');
  }
}