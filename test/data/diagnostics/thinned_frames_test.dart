/// Прореживание кадров подписки — пункт 4 плана
/// `2026-09-19-hardware-diagnostics.md`.
///
/// # Почему отдельная проба, а не только сквозная через провод
///
/// Сквозная (`test/backend/diagnostics_op_test.dart`) доказывает главное:
/// кадров меньше, чем показаний, и последний не теряется. Два свойства она
/// проверить не может, потому что они видны не на планшете, а **на кассе**:
///
/// 1. **поток закрывается**, когда источник кончился с непустым хвостом. Не
///    закройся он — `await for` на принимающей стороне ждал бы вечно, и
///    вкладка осталась бы со спиннером на исправной кассе;
/// 2. **отмена гасит таймер.** Вкладку весов закрывают посреди взвешивания
///    каждый раз: наладчик посмотрел и ушёл. Таймер, переживший отмену,
///    остаётся на кассе навсегда и тикает по кадру на каждую открытую за
///    смену вкладку — беда, которая не проявляется ничем, кроме медленно
///    дурнеющей кассы.
///
/// # Чего эта проба НЕ доказывает
///
/// Что окно выбрано верно. 300 мс — решение (докстринг
/// `HardwareDiagnosticsRepository.watchScales`), а не измеренная величина, и
/// проба берёт своё короткое окно нарочно: мерить длину окна значило бы
/// мерить таймер, а не правило.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/diagnostics/local_hardware_diagnostics.dart';

void main() {
  test('первый кадр сразу, середина отброшена, последний досылается', () async {
    final source = StreamController<int>();
    final out = <int>[];
    final subscription = thinnedFrames(
      source.stream,
      const Duration(milliseconds: 100),
    ).listen(out.add);

    for (final value in [1, 2, 3, 4, 5, 6]) {
      source.add(value);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      out,
      [1],
      reason:
          'первый кадр обязан уйти сразу: вкладка, ждущая окна, открывается '
          'пустой на исправных весах',
    );

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      out,
      [1, 6],
      reason:
          'последнее показание — это УСТАНОВИВШИЙСЯ вес, число, по которому '
          'продают товар; прореживание, теряющее его, врёт именно в той '
          'цифре, за которой пришли',
    );

    await subscription.cancel();
    await source.close();
  });

  test('источник кончился с хвостом — хвост уходит, и поток закрывается', () async {
    // Иначе `await for` на принимающей стороне ждал бы вечно, а вкладка
    // осталась бы со спиннером на исправной кассе (И144).
    final source = StreamController<int>();
    final out = <int>[];
    var closed = false;
    final subscription = thinnedFrames(
      source.stream,
      const Duration(milliseconds: 100),
    ).listen(out.add, onDone: () => closed = true);

    source.add(1);
    source.add(2);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await source.close();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(out, [1, 2], reason: 'хвост уходит и после конца источника');
    expect(closed, isTrue, reason: 'поток обязан закрыться, а не зависнуть');

    await subscription.cancel();
  });

  test('отмена гасит таймер: закрытая вкладка не тикает на кассе', () async {
    // Вкладку весов закрывают посреди взвешивания каждый раз. Таймер,
    // переживший отмену, остаётся на кассе навсегда — и это беда, не
    // проявляющаяся ничем, кроме медленно дурнеющей кассы.
    final source = StreamController<int>();
    final out = <int>[];
    final subscription = thinnedFrames(
      source.stream,
      const Duration(milliseconds: 50),
    ).listen(out.add);

    source.add(1);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    source.add(2); // лёг в хвост — уйдёт по истечении окна, если не отменить
    await subscription.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(
      out,
      [1],
      reason:
          'после отмены кадров быть не должно: досылка в закрытый поток — '
          'это живой таймер на кассе за каждую закрытую вкладку',
    );

    await source.close();
  });

  test('повторов эта функция НЕ снимает — и это разделение обязанностей', () async {
    // Два правила прореживания разные: «одно и то же?» снимает `distinct`
    // перед этой функцией, «не слишком ли часто?» — она. Сведи их в одно
    // место, и снятие повторов начало бы зависеть от срока окна: два
    // одинаковых показания в разных окнах прошли бы оба.
    final source = StreamController<int>();
    final out = <int>[];
    final subscription = thinnedFrames(
      source.stream,
      const Duration(milliseconds: 20),
    ).listen(out.add);

    source.add(7);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    source.add(7);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(
      out,
      [7, 7],
      reason:
          'повтор здесь проходит намеренно: его снимает `distinct` выше по '
          'течению, и проба закрепляет границу обязанностей',
    );

    await subscription.cancel();
    await source.close();
  });
}
