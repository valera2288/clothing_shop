import 'package:flutter/material.dart';

/// Загружает отложенную библиотеку (`import ... deferred as`) и строит экран.
///
/// Код редко используемых разделов не входит в первую загрузку приложения,
/// а скачивается при первом переходе на нужный экран.
class DeferredScreen extends StatefulWidget {
  final Future<void> Function() load;
  final WidgetBuilder builder;

  const DeferredScreen({super.key, required this.load, required this.builder});

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.builder(context);
        }
        return Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                          'Не удалось загрузить раздел. Проверьте соединение.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            setState(() => _future = widget.load()),
                        child: const Text('Повторить'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(
                    semanticsLabel: 'Загрузка раздела'),
          ),
        );
      },
    );
  }
}
