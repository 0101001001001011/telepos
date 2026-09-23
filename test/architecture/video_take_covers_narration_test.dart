/// Картинки в дубле не меньше, чем слов в начитке.
///
/// # Чем это оплачено
///
/// Найдено при подготовке урока 2 (2026-09-23) — **замером, а не на
/// монтаже**. Первая редакция дубля держала кадр восемьдесят секунд, а
/// начитка к нему наговаривает сто девяносто девять. Видео кончилось бы на
/// середине фразы, и узнали бы об этом в студии, после сдачи пакета.
///
/// У снятых прежде уроков этого не случалось не потому, что кто-то считал,
/// а потому что в них много действий: нажатия, переходы, ожидание печати.
/// Урок 2 — почти неподвижный экран, и там, где действий нет, длину держать
/// нечем, кроме счёта.
///
/// # Как считается
///
/// Слов в блоке начитки, делить на сто пятьдесят слов в минуту — темп, с
/// которым читает синтез. Столько секунд блоку и нужно. Замеренное берётся
/// из `take.log` сданного пакета: расстояние между соседними отметками
/// `[VIDEO-MARK]`, а у последнего блока — до конца записи.
///
/// # Почему с запасом в четверть
///
/// Сто пятьдесят слов в минуту — средний темп, а не закон: у диктора он
/// плавает, паузы между предложениями считаются по-разному. Сторож не про
/// точность, а про **разряд величины**: он ловит блок, которому не хватает
/// вдвое, и молчит на том, где разница в секунду.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Слов в минуту у синтеза, читающего начитку.
const _wordsPerMinute = 150;

/// Насколько короче измеренного дозволено быть блоку.
///
/// Не ноль: темп речи плавает, и сторож, краснеющий на секунде, был бы
/// сторожем темпа, а не длины.
const _tolerance = 0.75;

void main() {
  final root = Directory('docs/internal/video/handoff');

  test('каждый блок дубля длиннее, чем его начитка', () {
    if (!root.existsSync()) return;

    final complaints = <String>[];

    for (final pkg in root.listSync().whereType<Directory>()) {
      final where = pkg.path.split(RegExp(r'[\\/]')).last;
      final narrationFile = File('${pkg.path}/narration.txt');
      final logFile = File('${pkg.path}/take.log');
      final manifestFile = File('${pkg.path}/lesson.json');
      if (!narrationFile.existsSync() || !logFile.existsSync()) continue;

      // ── Сколько слов в каждом блоке ──────────────────────────────────
      final words = <String, int>{};
      final order = <String>[];
      String? current;
      for (final line in narrationFile.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.startsWith('#')) continue;
        if (trimmed.startsWith('@')) {
          current = trimmed.substring(1).trim();
          order.add(current);
          words[current] = 0;
          continue;
        }
        if (current == null) continue;
        words[current] = words[current]! +
            trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      }
      if (order.isEmpty) continue;

      // ── Когда каждый блок начался в записи ───────────────────────────
      final marks = <String, double>{};
      // `[\w-]+`, а не `\w+`: имена блоков бывают с дефисом
      // («printer-tab»), и первая редакция сторожа их не ловила — а потом
      // честно сообщала, что блок «снят не был». Сторож, ошибающийся в
      // разборе, обвиняет продукт в своей ошибке.
      final markRe = RegExp(r'\[VIDEO-MARK\]\s+([\w-]+)\s+([0-9.]+)');
      for (final line in logFile.readAsLinesSync()) {
        final m = markRe.firstMatch(line);
        if (m != null) marks[m.group(1)!] = double.parse(m.group(2)!);
      }
      if (marks.isEmpty) continue;

      final total = manifestFile.existsSync()
          ? ((jsonDecode(manifestFile.readAsStringSync())
                  as Map<String, Object?>)['takeSeconds'] as num?)
                ?.toDouble()
          : null;

      for (var i = 0; i < order.length; i++) {
        final block = order[i];
        final startedAt = marks[block];
        if (startedAt == null) {
          complaints.add('$where: блок «$block» снят не был');
          continue;
        }
        final next = i + 1 < order.length ? marks[order[i + 1]] : null;
        final endsAt = next ?? total;
        if (endsAt == null) continue;

        final shown = endsAt - startedAt;
        final needed = words[block]! / _wordsPerMinute * 60;
        if (shown < needed * _tolerance) {
          complaints.add(
            '$where: блок «$block» — картинки ${shown.toStringAsFixed(0)} с, '
            'голоса ${needed.toStringAsFixed(0)} с '
            '(${words[block]} слов)',
          );
        }
      }
    }

    expect(
      complaints,
      isEmpty,
      reason:
          'видео кончится раньше голоса — блок оборвётся на середине '
          'фразы:\n${complaints.join('\n')}',
    );
  });
}
