import 'package:flutter/material.dart';

import '../state/load_status.dart';

/// Четыре состояния экрана: загрузка, данные, пустой результат, ошибка.
/// Загрузка, ошибка и пустой результат рисуются этими виджетами,
/// поэтому выглядят одинаково на всех экранах.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Загрузка'),
      );
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Повторить')),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;
  final Widget? action;

  const EmptyView({
    super.key,
    this.message = 'Ничего не найдено',
    this.icon = Icons.search_off,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}

/// Выбирает, что показать по статусу загрузки. Пустой результат — отдельное
/// состояние: это не ошибка и не загрузка.
class StatusBody extends StatelessWidget {
  final LoadStatus status;
  final String? error;
  final bool isEmpty;
  final VoidCallback onRetry;
  final String emptyMessage;
  final Widget? emptyAction;
  final WidgetBuilder builder;

  const StatusBody({
    super.key,
    required this.status,
    required this.error,
    required this.isEmpty,
    required this.onRetry,
    required this.builder,
    this.emptyMessage = 'Ничего не найдено',
    this.emptyAction,
  });

  @override
  Widget build(BuildContext context) => switch (status) {
        LoadStatus.idle || LoadStatus.loading => const LoadingView(),
        LoadStatus.error =>
          ErrorView(message: error ?? 'Ошибка', onRetry: onRetry),
        LoadStatus.success => isEmpty
            ? EmptyView(message: emptyMessage, action: emptyAction)
            : builder(context),
      };
}
