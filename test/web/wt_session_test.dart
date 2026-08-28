@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_session.dart';

/// ВНИМАНИЕ: этот набор **не выполняется**, и считать его покрытием нельзя —
/// ровно как соседний `api_client_decode_test.dart`.
///
/// # Почему, и это теперь измерено, а не предположено
///
/// Прежняя запись гласила: «вероятнее всего, `dart:js_interop` не поднимается
/// в тестовом окружении». Она **неверна**. 2026-08-05 пустой браузерный тест
/// без единого импорта, кроме `flutter_test`, отвалился по тому же таймауту в
/// 12 минут. Подключение к Chrome по протоколу отладки показало две причины, и
/// обе — дефекты `flutter_tools` 3.32.4, проявляющиеся только на Windows:
///
/// 1. **CanvasKit не отдаётся.** `flutter_web_platform.dart`,
///    `_localCanvasKitHandler`: `path.fromUri(request.url)` на Windows даёт
///    `canvaskit\canvaskit.js`, после чего `startsWith('canvaskit/')` ложно, и
///    сервер отвечает 404 на все файлы движка. Загрузчик Flutter ждёт их
///    вечно, `runWebTest` не начинается, набор упирается в таймаут.
/// 2. **Точка входа не находится.** `web_test_compiler.dart` кладёт в карту
///    ключ `relativeTestSegments.join('/')`, а `_wrapperHandler` ищет по
///    `path.fromUri(...)` — то есть по `web\wt_session_test.dart`. В консоли
///    это видно дословно: `Web test for web\browser_smoke_probe_test.dart not
///    found`.
///
/// Ни то, ни другое из проекта не чинится. Подробности и способ повторить —
/// `docs/internal/testing-notes.md`, раздел «Браузерный прогон на Windows».
///
/// # Что вместо этого проверено
///
/// Всё, кроме вызова самого конструктора: разбор отпечатка и переподнятие
/// сессии — `wt_channel_test.dart`, нарезка кадров — `wt_framing_test.dart`,
/// три рода обмена — `wt_dispatcher_test.dart`, показ причины — `wt_boot_gate_test.dart`.
/// Сюда попало ровно то, что иначе никак.
void main() {
  test('отсутствие WebTransport — значение, а не исключение', () async {
    // На незащищённой странице конструктора WebTransport нет вовсе. Терминал
    // обязан назвать это состояние, а не показать белый экран: ровно этот
    // класс отказа стоил белого экрана 2026-08-04.
    final outcome = await WtSession.open(
      host: 'till.invalid',
      port: 1,
      certSha256: '00' * 32,
    );

    expect(outcome, isA<WtUnavailable>());
    expect((outcome as WtUnavailable).reason, isNotEmpty);
  });

  test('негодный отпечаток называется до попытки соединения', () async {
    // Пин на половину отпечатка — это пин ни на что, и отказ выглядел бы
    // сетевым: искали бы не там.
    final outcome = await WtSession.open(
      host: 'till.invalid',
      port: 1,
      certSha256: 'не отпечаток',
    );

    expect(outcome, isA<WtUnavailable>());
    expect((outcome as WtUnavailable).reason, contains('SHA-256'));
  });

  test('без порта в документе сессия не выдумывается', () async {
    // Касса не впрыснула порт — значит слушатель QUIC на ней не поднялся.
    // Это состояние кассы, и терминал обязан его назвать.
    final outcome = await WtSession.openFromDocument();

    expect(outcome, isA<WtUnavailable>());
  });
}
