/// Пакет для студии собран по её правилам, а не по памяти.
///
/// # Зачем
///
/// Раздел 10 `docs/video-production.md` — список из десяти пунктов, который
/// человек проходит глазами перед передачей. Глазами его и проходили: в
/// маркетинговом пакете, уже собранном, лежало поле `number`, которое
/// правила запрещают («Поля `number` у него нет»), и версия `3.6.0` вместо
/// настоящей сборочной. В пакете урока стоял номер «1.3», а план серий
/// нумерует эту главу восьмой.
///
/// Ни одно из трёх расхождений не помешало бы файлам доехать. Все три
/// заставили бы студию писать нам вместо работы — а правила прямо
/// говорят: «Если пакета нет на месте или в нём не хватает файла — мы
/// пишем вам, а не догадываемся».
///
/// # Почему отсутствие пакетов — не отказ
///
/// `docs/internal/video/handoff/` лежит под `.gitignore`: видео в историю
/// не идёт. На свежем клоне пакетов нет вовсе, и требовать их значило бы
/// красить сборку у всякого, кто ничего не снимал. Сторож проверяет **то,
/// что есть**, и молчит, когда нет ничего.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final root = Directory('docs/internal/video/handoff');

  List<Directory> packages() => root.existsSync()
      ? root.listSync().whereType<Directory>().toList()
      : <Directory>[];

  /// Настоящая версия сборки — из `pubspec.yaml`, а не повторённая здесь.
  String pubspecVersion() {
    final yaml = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    return yaml['version'].toString();
  }

  Map<String, Object?> manifest(Directory pkg) =>
      json.decode(File('${pkg.path}/lesson.json').readAsStringSync())
          as Map<String, Object?>;

  test('каждый пакет несёт все четыре файла', () {
    for (final pkg in packages()) {
      for (final name in const [
        'lesson.json',
        'narration.txt',
        'take.mp4',
        'take.log',
      ]) {
        expect(
          File('${pkg.path}/$name').existsSync(),
          isTrue,
          reason:
              '${pkg.path}: нет $name. Недостающий take.log нельзя '
              'восстановить ничем: без отметок голос ложится не туда',
        );
      }
    }
  });

  test('обязательные поля заполнены и версия — настоящая', () {
    final version = pubspecVersion();
    for (final pkg in packages()) {
      final m = manifest(pkg);
      final where = pkg.path.split(RegExp(r'[\\/]')).last;

      for (final field in const [
        'slug',
        'tier',
        'goal',
        'product',
        'lang',
        'takeSeconds',
      ]) {
        expect(
          m[field],
          isNotNull,
          reason: '$where: поле "$field" обязательно (раздел 10 правил)',
        );
      }

      expect(
        m['slug'],
        where,
        reason:
            '$where: slug в манифесте не совпадает с именем каталога — '
            'студия ищет пакет по названному в чате slug',
      );

      expect(
        m['version'],
        version,
        reason:
            '$where: версия обязана быть НАСТОЯЩЕЙ версией сборки, которой '
            'снят дубль. В манифесте "${m['version']}", в pubspec "$version"',
      );
    }
  });

  test('маркетинговый пакет — без номера, урок — с номером', () {
    for (final pkg in packages()) {
      final m = manifest(pkg);
      final where = pkg.path.split(RegExp(r'[\\/]')).last;

      if (m['tier'] == 'marketing') {
        expect(
          where,
          startsWith('marketing-'),
          reason: '$where: каталог маркетингового ролика зовётся marketing-…',
        );
        expect(
          m.containsKey('number'),
          isFalse,
          reason:
              '$where: у маркетингового ролика поля "number" нет — так '
              'сказано в правилах прямо. Жанры разводятся на сборке, и '
              'лишний номер уводит ролик в нумерацию уроков',
        );
      } else {
        expect(
          m['number'],
          isNotNull,
          reason: '$where: у урока номер обязателен',
        );
        expect(
          where,
          startsWith('lesson-'),
          reason: '$where: каталог урока зовётся lesson-…',
        );
      }
    }
  });

  test('на каждый @-блок текста есть отметка с тем же именем', () {
    for (final pkg in packages()) {
      final where = pkg.path.split(RegExp(r'[\\/]')).last;
      final narration = File('${pkg.path}/narration.txt').readAsStringSync();
      final log = File('${pkg.path}/take.log').readAsStringSync();

      final blocks = RegExp(r'^@([a-z0-9-]+)', multiLine: true)
          .allMatches(narration)
          .map((m) => m.group(1)!)
          .toList();
      final marks = RegExp(r'\[VIDEO-MARK\] ([a-z0-9-]+) ')
          .allMatches(log)
          .map((m) => m.group(1)!)
          .toSet();

      expect(
        blocks,
        isNotEmpty,
        reason: '$where: в тексте нет ни одного @-блока',
      );
      expect(
        blocks.where((b) => !marks.contains(b)).toList(),
        isEmpty,
        reason:
            '$where: блоки без отметки в логе. Имена отметок и блоков — '
            'вся связь между текстом и картинкой, отдельной таблицы '
            'соответствий нет намеренно',
      );
    }
  });

  test('текст каждого блока укладывается в свой промежуток', () {
    // Скорость речи взята той же, какой считался дубль урока 8: сто
    // пятьдесят слов в минуту. Запас правил — пятнадцать процентов, и он
    // здесь дан: проверка ловит переполнение, а не тесноту.
    const wordsPerSecond = 2.5;
    const tolerance = 1.15;

    for (final pkg in packages()) {
      final where = pkg.path.split(RegExp(r'[\\/]')).last;
      final narration = File('${pkg.path}/narration.txt').readAsStringSync();
      final log = File('${pkg.path}/take.log').readAsStringSync();
      final total = (manifest(pkg)['takeSeconds']! as num).toDouble();

      final marks = <String, double>{};
      for (final m in RegExp(
        r'\[VIDEO-MARK\] ([a-z0-9-]+) ([0-9.]+)',
      ).allMatches(log)) {
        // Побеждает последняя: прогон мог повторяться в одном логе.
        marks[m.group(1)!] = double.parse(m.group(2)!);
      }

      final blocks = <({String name, int words})>[];
      for (final chunk in narration.split(RegExp(r'^@', multiLine: true)).skip(
        1,
      )) {
        final parts = chunk.split('\n');
        blocks.add((
          name: parts.first.trim(),
          words: parts.skip(1).join(' ').split(RegExp(r'\s+')).where(
            (w) => w.isNotEmpty,
          ).length,
        ));
      }

      for (var i = 0; i < blocks.length; i++) {
        final start = marks[blocks[i].name];
        if (start == null) continue; // ловит соседняя проба
        final end = i + 1 < blocks.length
            ? (marks[blocks[i + 1].name] ?? total)
            : total;
        final have = end - start;
        final need = blocks[i].words / wordsPerSecond;

        expect(
          have * tolerance >= need,
          isTrue,
          reason:
              '$where, блок «${blocks[i].name}»: ${blocks[i].words} слов '
              'это около ${need.toStringAsFixed(1)} с, а до следующей '
              'отметки ${have.toStringAsFixed(1)} с. Голос ляжет поверх '
              'следующей сцены — либо режьте текст, либо держите кадр '
              'дольше',
        );
      }
    }
  });
}
