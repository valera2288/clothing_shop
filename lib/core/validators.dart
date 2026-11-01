typedef Validator = String? Function(String?);

class V {
  static Validator required([String message = 'Поле обязательно']) {
    return (v) => (v == null || v.trim().isEmpty) ? message : null;
  }

  static Validator length({int min = 0, int max = 1000}) {
    return (v) {
      final t = v?.trim() ?? '';
      if (t.length < min) return 'Не короче $min символов';
      if (t.length > max) return 'Не длиннее $max символов';
      return null;
    };
  }

  static Validator integer({int? min, int? max, String? label}) {
    return (v) {
      final t = v?.trim() ?? '';
      if (t.isEmpty) return 'Введите целое число';
      final n = int.tryParse(t);
      if (n == null) return 'Не является целым числом';
      if (min != null && n < min) {
        return '${label ?? "Значение"} не меньше $min';
      }
      if (max != null && n > max) {
        return '${label ?? "Значение"} не больше $max';
      }
      return null;
    };
  }

  static Validator email() {
    final re = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    return (v) =>
        re.hasMatch(v?.trim() ?? '') ? null : 'Некорректный адрес почты';
  }

  static Validator phone() {
    final re = RegExp(r'^\+?[\d\s\-()]{7,20}$');
    return (v) =>
        re.hasMatch(v?.trim() ?? '') ? null : 'Некорректный номер телефона';
  }

  /// Значение должно подходить под регулярное выражение.
  static Validator pattern(RegExp re, String message) {
    return (v) {
      final t = v?.trim() ?? '';
      // Пустое значение проверяет required; необязательное поле может быть пустым
      return t.isEmpty || re.hasMatch(t) ? null : message;
    };
  }

  /// Число с дробной частью (цена) в заданных пределах.
  static Validator number({num? min, num? max, String label = 'Значение'}) {
    return (v) {
      final t = (v ?? '').trim().replaceAll(',', '.');
      if (t.isEmpty) return 'Введите число';
      final n = num.tryParse(t);
      if (n == null) return 'Не является числом';
      if (min != null && n < min) return '$label не меньше $min';
      if (max != null && n > max) return '$label не больше $max';
      return null;
    };
  }

  /// Надёжный пароль: не короче 8 символов, есть цифра и спецсимвол.
  static Validator strongPassword() {
    return (v) {
      final value = v ?? '';
      if (value.isEmpty) return 'Введите пароль';
      final failed = passwordRules(value).where((r) => !r.$1).map((r) => r.$2);
      return failed.isEmpty ? null : 'Нужно: ${failed.join(', ')}';
    };
  }

  static Validator combine(List<Validator> validators) {
    return (v) {
      for (final fn in validators) {
        final e = fn(v);
        if (e != null) return e;
      }
      return null;
    };
  }
}

/// Правила пароля для подсказок под полем: (выполнено, текст).
List<(bool, String)> passwordRules(String value) => [
      (value.length >= 8, 'не меньше 8 символов'),
      (RegExp(r'\d').hasMatch(value), 'хотя бы одна цифра'),
      (
        RegExp(r'[^A-Za-zА-Яа-яЁё0-9\s]').hasMatch(value),
        'хотя бы один спецсимвол',
      ),
    ];
