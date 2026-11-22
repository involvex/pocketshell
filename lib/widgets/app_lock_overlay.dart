import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:ssh_app/providers/app_lock_provider.dart';

/// Full-screen cover shown while [AppLockProvider.isLocked] is true.
class AppLockOverlay extends StatelessWidget {
  const AppLockOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppLockProvider>(
      builder: (context, lock, _) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            child,
            if (lock.isLocked)
              Positioned.fill(
                child: Material(
                  color: const Color(0xFF0B0B14),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'PocketShell is locked',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sessions stay connected. Unlock to continue.',
                          style: TextStyle(color: Colors.grey[400]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final ok = await lock.unlock();
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Authentication failed'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Unlock'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
