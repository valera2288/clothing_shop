import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/connection_notifier.dart';

/// Полоса «Нет связи с сервером». Списки сами перезагружаются, когда
/// связь возвращается (см. `restoredCount` в ConnectionNotifier).
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionNotifier>();
    final theme = Theme.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: conn.offline
          ? Material(
              color: theme.colorScheme.errorContainer,
              child: Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 18,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Нет связи с сервером. Повторяем попытку автоматически…',
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
