/// Мелкие помощники разбора записей PocketBase.
String jsonStr(Map<String, dynamic> j, String key) => (j[key] as String?) ?? '';

int jsonInt(Map<String, dynamic> j, String key) =>
    (j[key] as num?)?.toInt() ?? 0;

double jsonDouble(Map<String, dynamic> j, String key) =>
    (j[key] as num?)?.toDouble() ?? 0;

bool jsonBool(Map<String, dynamic> j, String key) => j[key] == true;

/// Дата из ответа сервера (`2026-10-21 04:48:49.000Z`); пустая строка — null.
DateTime? jsonDate(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v.replaceFirst(' ', 'T'));
}

/// Связанная запись из `expand` (параметр `expand=category` в запросе).
Map<String, dynamic>? jsonExpand(Map<String, dynamic> j, String key) {
  final e = j['expand'];
  if (e is Map && e[key] is Map) {
    return Map<String, dynamic>.from(e[key] as Map);
  }
  return null;
}

List<String> jsonIds(Map<String, dynamic> j, String key) =>
    ((j[key] as List?) ?? const []).map((e) => '$e').toList();
