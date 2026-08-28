import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/telepos_icons.dart';

/// Сторож против **молчаливого «тофу»**: шрифт набора не загружен, каждый глиф
/// рисуется одинаковым пустым квадратом, а всё вокруг зелёное.
///
/// # Почему этот тест есть и почему он живёт здесь
///
/// 2026-08-27 прежний набор из 21 иконки был удалён как мёртвый, и вместе с
/// ним из `test/golden/flutter_test_config.dart` убрали загрузку шрифта.
/// Волны 1–2 завели новый набор на 33 глифа — загрузку не вернули.
///
/// Дальше произошло худшее, что может произойти с проверкой: **ничего**.
/// `matchesGoldenFile` записывает то, что нарисовалось, каким бы оно ни было,
/// поэтому 117 эталонов и 15 снимков README перезаписались с пустыми
/// квадратами вместо иконок, прогон остался зелёным, а `icon_set_is_used_test`
/// продолжал подтверждать, что «каждая иконка набора используется» — он
/// проверяет упоминание в коде, а не то, что глиф виден.
///
/// Нашлось это глазами, на снимке экрана продажи, при подготовке статьи.
///
/// **Файл лежит в `test/e2e/`, а не в `test/theme/`, и это вынужденно:**
/// шрифты грузит `flutter_test_config.dart`, а он действует только на свой
/// каталог и вложенные. В `test/golden/` его класть нельзя — тот каталог
/// исключён из гоняемого набора тегом `golden`, то есть сторож молчал бы
/// ровно там, где и появилась дыра.
void main() {
  /// Три глифа из разных мест набора: волна 1 (навигация), волна 2
  /// (действия) и снова волна 1. Если шрифта нет, все три — один и тот же
  /// квадрат подстановки, и попарное сравнение это ловит.
  const probes = <String, IconData>{
    'sale': TeleposIcons.sale,
    'delete': TeleposIcons.delete,
    'settings': TeleposIcons.settings,
  };

  testWidgets('глифы набора рисуются, и рисуются по-разному', (tester) async {
    final shots = <String, List<int>>{};

    for (final entry in probes.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: Icon(entry.value, size: 96, color: Colors.black),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // И `toImage`, и `toByteData` обязаны идти внутри `runAsync`: обе
      // ждут настоящий цикл событий, которого в испытательном времени нет.
      // Вынесенный наружу `toByteData` не падает, а **повисает навсегда**.
      late Uint8List png;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        png = data!.buffer.asUint8List();
        image.dispose();
      });
      shots[entry.key] = png;
    }

    // Непустой снимок: полностью прозрачный кадр значил бы, что не нарисовалось
    // вообще ничего, и попарное сравнение ниже прошло бы вхолостую.
    for (final entry in shots.entries) {
      expect(
        entry.value.length,
        greaterThan(100),
        reason: 'глиф ${entry.key} не нарисовался вовсе',
      );
    }

    final names = probes.keys.toList();
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        expect(
          shots[names[i]],
          isNot(equals(shots[names[j]])),
          reason:
              'глифы «${names[i]}» и «${names[j]}» нарисовались ОДИНАКОВО. '
              'Это подстановочный квадрат: шрифт `TeleposIcons` не загружен в '
              'испытательной среде. Загрузка живёт в '
              '`test/e2e/flutter_test_config.dart` и '
              '`test/golden/flutter_test_config.dart` — проверьте, что '
              '`assets/fonts/TeleposIcons.ttf` существует и регистрируется '
              'под семейством `TeleposIcons`.\n\n'
              'Пока это так, ЛЮБОЙ пересъём эталонов записывает пустые '
              'квадраты и остаётся зелёным.',
        );
      }
    }
  });
}
