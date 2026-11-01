/// Адрес API задаётся при сборке, а не константой в коде:
///
///   flutter build web --release --dart-define=API_BASE_URL=https://api.example.com/api
///
/// Если параметр не задан, берётся адрес /api на том же сайте, откуда
/// загружено приложение. Так сборка без параметров не содержит ни одного
/// зашитого адреса сервера.
const _configured = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl => _configured.isNotEmpty ? _configured : '/api';
