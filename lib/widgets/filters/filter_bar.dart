import 'package:flutter/material.dart';

import '../../core/breakpoints.dart';

/// Панель фильтров. Первый элемент — поле поиска.
///
/// На широком экране все поля идут в одну панель с переносом (`Wrap`).
/// На узком поиск остаётся наверху, а остальные фильтры убираются в
/// раскрывающийся блок: иначе четыре поля друг под другом занимали бы
/// половину экрана телефона, и на сам список не оставалось места.
class FilterBar extends StatelessWidget {
  final List<Widget> children;

  const FilterBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (screenSizeOf(context) != ScreenSize.compact || children.length < 2) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    }
    return Column(
      children: [
        SizedBox(width: double.infinity, child: children.first),
        ExpansionTile(
          title: const Text('Фильтры'),
          dense: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          expandedAlignment: Alignment.centerLeft,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: children.skip(1).toList(),
            ),
          ],
        ),
      ],
    );
  }
}
