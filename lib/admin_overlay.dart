import 'package:advertising_screen/provider/content_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminOverlay extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const AdminOverlay({
    super.key,
    required this.onClose,
    required this.onRefresh,
    required this.onLogout, required Map<String, dynamic> Function() getOdooStatus, required Future<void> Function() onManualOdooCheck,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Admin Controls',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Content info
              Consumer<ContentProvider>(
                builder: (context, contentProvider, child) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Content Status',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.photo_library,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${contentProvider.contentItems.length} items loaded',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          if (contentProvider.currentItem != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  contentProvider.currentItem!.type == MediaType.video
                                      ? Icons.play_circle
                                      : Icons.image,
                                  size: 20,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Current: ${contentProvider.currentItem!.title}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Action buttons
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      onRefresh();
                      onClose();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Content'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  Consumer<ContentProvider>(
                    builder: (context, contentProvider, child) {
                      return ElevatedButton.icon(
                        onPressed: contentProvider.contentItems.length > 1
                            ? () {
                          contentProvider.nextContent();
                          onClose();
                        }
                            : null,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Next Content'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      onClose();
                      onLogout();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Help text
              Text(
                'Long press the top-right corner to access admin controls',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}