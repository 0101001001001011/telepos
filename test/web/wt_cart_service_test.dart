/// Задача 12 плана «Продажа с браузерного терминала»: браузерная реализация
/// контракта корзины поверх провода.
///
/// # Почему подставлен транспорт, а не диспетчер
///
/// План рисует пробы поверх `RecordingDispatcher`. Так нельзя: `WtDispatcher`
/// — `final class`, его не наследуют и не реализуют. И это к лучшему:
/// подделанный диспетчер проверял бы только то, что `WtCartService` позвал
/// какой-то метод какого-то двойника, а настоящий — с подделанным
/// [WtStreams] под ним — гоняет **настоящие кадры**: имя операции, тело,
/// кодировщики `SaleOps`, разбор ответа. Ровно тот шов, где живут ошибки
/// копипасты («минус», зовущий «плюс») и деньги, уехавшие числом.
///
/// # Что здесь доказывается
///
/// 1. **очередь** — одна команда в полёте на рабочее место (I161), порядок
///    кассира сохраняется, отказ очередь не запирает, соседнее рабочее место
///    чужого скана не ждёт, задержка не копится;
/// 2. **повтор** — ровно один раз, тем же ключом, только на обрыв; отказ
///    кассы не повторяется никогда (повторённый отказ списал бы строку
///    дважды);
/// 3. **контракт целиком** — каждая операция каталога `sale.*` вызвана своим
///    методом своими доводами, и ни одна не кладёт в тело `terminalId`;
/// 4. **деньги строкой** (I159) — на настоящих кадрах и на значениях, где
///    `double` соврал бы. Сам запрет собирать денежное поле руками стоит не
///    здесь: кругом правки 1 область сторожа
///    `test/architecture/money_over_wire_test.dart` расширена на `lib/web`
///    целиком, а местная проба-заменитель снята — она читала один файл, то
///    есть охраняла собственное обоснование.
///
/// # Что здесь НЕ доказывается
///
/// Пробы на подставном проводе доказывают **форму и порядок отправки**, но
/// не применение: подставной провод отвечает постоянной версией, и сверять
/// метки некому. Всё, что про «команда применилась», живёт в группе петли,
/// против настоящей кассы. Круг правки 1 завёл это различие в имена проб:
/// «десять сканов **УХОДЯТ**» — подставной провод, «десять сканов
/// **ПРИМЕНЯЮТСЯ**» — петля.
library;

import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/cart_codec.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_cart_service.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

import '../data/transport/till_operations_stubs.dart';
import 'support/fake_dispatcher.dart';
import 'support/loopback.dart';
import '../helpers/discount_authority.dart';

const _terminal = 7;
const _otherTerminal = 8;

CartCommandMeta m(String key, {int baseVersion = 0, int? receiptNo = 41}) =>
    CartCommandMeta(key: key, baseVersion: baseVersion, receiptNo: receiptNo);

Decimal d(String v) => Decimal.parse(v);

CartView view({
  int version = 1,
  bool wholesale = false,
  int terminalId = _terminal,
}) => CartView(
  posId: 1,
  terminalId: terminalId,
  version: version,
  lines: const [],
  wholesale: wholesale,
  receiptNo: 41,
);

/// Ответ кассы: успешный кадр со снимком корзины.
String okCart({
  int version = 1,
  bool wholesale = false,
  int terminalId = _terminal,
}) => OkFrame(
  cartViewToWireJson(
    view(version: version, wholesale: wholesale, terminalId: terminalId),
  ),
).encode();

String updateCart({int version = 1}) =>
    UpdateFrame(cartViewToWireJson(view(version: version))).encode();

/// Что подставной провод делает с очередным запросом.
sealed class Reply {
  const Reply();
}

/// Ответить этими кадрами и закрыть поток.
final class Answer extends Reply {
  const Answer(this.frames);
  final List<String> frames;
}

/// Поток закрылся, не ответив ни одним кадром — так выглядит перезапуск
/// кассы посреди команды. `WtDispatcher.ask` переводит это в
/// `WtProtocolError('no_answer')`.
final class Broken extends Reply {
  const Broken();
}

/// Половина приёма отдала ошибку — так выглядит **настоящий** обрыв Wi-Fi:
/// `WtSession._pump` кладёт в поток `addError(error)` сырым объектом
/// (`lib/web/wt_session.dart:297`), и `ask` пропускает его наружу нетронутым.
final class RawFailure extends Reply {
  const RawFailure(this.error);
  final Object error;
}

/// Подставной транспорт: записывает каждый ушедший кадр и отвечает тем, что
/// велено. Настоящие `WtDispatcher`, `SaleOps` и `WireFrame` над ним.
class Wire implements WtStreams {
  Wire({Reply Function(RequestFrame request)? replyTo}) : _replyTo = replyTo;

  final Reply Function(RequestFrame request)? _replyTo;

  /// Всё, что терминал отправил кассе, по порядку отправки.
  final List<RequestFrame> sent = [];

  /// Ответы, которые придержаны ([hold]) — каждый отпускается вызовом.
  final List<void Function()> waiting = [];

  /// Придерживать ответы: обмен доходит до кассы и застревает.
  bool hold = false;

  int _open = 0;

  /// Наибольшее число одновременно открытых потоков. Больше единицы значит,
  /// что очередь пропустила вторую команду, не дождавшись первой.
  int peakOpen = 0;

  /// Сколько потоков открыто прямо сейчас. Смена длится двенадцать часов, и
  /// поток, оставшийся открытым после каждого скана, к вечеру становится
  /// сотнями.
  int get openNow => _open;

  @override
  Future<WtStream> openStream() async {
    _open++;
    if (_open > peakOpen) peakOpen = _open;
    return _WireStream(this);
  }

  @override
  Future<void> get closed => Completer<void>().future;

  @override
  Future<void> close() async {}

  /// Отпустить самый старый придержанный ответ.
  void releaseFirst() => waiting.removeAt(0)();

  /// Отпустить все придержанные ответы по порядку.
  void releaseAll() {
    while (waiting.isNotEmpty) {
      releaseFirst();
    }
  }

  Reply replyFor(RequestFrame request) =>
      _replyTo?.call(request) ?? Answer([okCart()]);
}

class _WireStream implements WtStream {
  _WireStream(this._wire);

  final Wire _wire;
  final _frames = StreamController<String>();
  RequestFrame? _request;

  @override
  Stream<String> get frames => _frames.stream;

  @override
  Future<void> send(String frame) async {
    final decoded = WireFrame.decode(frame);
    if (decoded is! RequestFrame) {
      throw StateError('терминал отправил не запрос: $decoded');
    }
    _request = decoded;
  }

  @override
  Future<void> finishSending() async {
    // Кадр становится событием кассы только здесь — так же, как в петле
    // `support/loopback.dart` и в настоящем `rk_quic`.
    final request = _request!;
    _wire.sent.add(request);
    if (_wire.hold) {
      _wire.waiting.add(deliver);
      return;
    }
    deliver();
  }

  void deliver() {
    if (_frames.isClosed) return;
    switch (_wire.replyFor(_request!)) {
      case Answer(:final frames):
        for (final frame in frames) {
          _frames.add(frame);
        }
      case Broken():
        break;
      case RawFailure(:final error):
        _frames.addError(error);
    }
    _frames.close();
  }

  @override
  Future<void> close() async {
    _wire._open--;
    if (!_frames.isClosed) await _frames.close();
  }
}

WtCartService cartOver(Wire wire) => WtCartService(WtDispatcher(wire));

/// Провод, который **переставляет команды местами**, если терминал шлёт их,
/// не дожидаясь ответов: чем позже открыт поток, тем быстрее он доезжает до
/// кассы.
///
/// Заведён кругом правки 1 и по измеренному поводу. Петля
/// (`support/loopback.dart`) отдаёт кадры кассе строго в том порядке, в
/// каком вызван `finishSending`, — то есть **сохраняет порядок сама**, и
/// проба поверх неё зелена и с очередью, и без неё (диверсия «очереди нет»
/// её не покрасила). Это ровно тот класс ловушки, о котором предупреждал
/// разбор соседней задачи про drift: одновременность по форме,
/// последовательность по существу.
///
/// Настоящий QUIC порядка между потоками не даёт вовсе
/// (`wt_dispatcher.dart:76-77`). Здесь это воспроизведено самым простым
/// способом, какой ловит дефект: задержка, обратная номеру потока. С
/// очередью переставлять нечего — в полёте всегда одна команда, и её
/// задержка ни с чем не соревнуется.
class Jittered implements WtStreams {
  Jittered(this._inner);

  final WtStreams _inner;
  int _issued = 0;

  @override
  Future<WtStream> openStream() async =>
      _JitteredStream(await _inner.openStream(), _issued++);

  @override
  Future<void> get closed => _inner.closed;

  @override
  Future<void> close() => _inner.close();
}

class _JitteredStream implements WtStream {
  _JitteredStream(this._inner, this._issued);

  final WtStream _inner;
  final int _issued;

  @override
  Stream<String> get frames => _inner.frames;

  @override
  Future<void> send(String frame) => _inner.send(frame);

  @override
  Future<void> finishSending() async {
    final ms = (12 - _issued).clamp(0, 12);
    await Future<void>.delayed(Duration(milliseconds: ms));
    await _inner.finishSending();
  }

  @override
  Future<void> close() => _inner.close();
}

void main() {
  group('очередь: одна команда в полёте', () {
    test('вторая команда не уходит, пока не ответила первая', () async {
      final wire = Wire()..hold = true;
      final cart = cartOver(wire);

      // Версии настоящие: вторая команда считается от того, чем станет
      // корзина после первой (`v + i`). Раньше обе шли от `baseVersion: 0` —
      // подставному проводу всё равно, а сторож в `_queued` красит именно
      // это, и красил бы справедливо.
      final first = cart.addByBarcode(_terminal, '111', m('k1'));
      final second = cart.addByBarcode(
        _terminal,
        '222',
        m('k2', baseVersion: 1),
      );

      await pumpEventQueue();
      expect(
        wire.sent,
        hasLength(1),
        reason:
            'обе команды ушли одновременно — провод даёт свой поток на каждый '
            'запрос и порядка между ними не держит',
      );

      wire.releaseFirst();
      await pumpEventQueue();
      wire.releaseAll();
      await Future.wait([first, second]);

      expect(wire.sent.map((r) => r.body['barcode']), ['111', '222']);
      expect(wire.peakOpen, 1, reason: 'два потока жили одновременно');
    });

    test('десять сканов УХОДЯТ в том порядке, в каком их дал кассир', () async {
      // Кассир сканирует быстрее, чем отвечает касса. Без очереди порядок
      // определял бы провод, а не кассир: потоки QUIC между собой не
      // упорядочены (`wt_dispatcher.dart:76-77`).
      //
      // **Имя пробы говорит «уходят», а не «применяются», и это честность,
      // а не придирка (круг правки 1).** Здесь подставной провод: он
      // отвечает на всё `okCart()` с постоянной версией, и сверять метки
      // некому. Значит проба доказывает **порядок отправки** и ресурсы — и
      // молчит о том, применятся ли команды. «Применяются» доказывает
      // соседняя проба в группе петли, против настоящей кассы; там девять
      // сканов из десяти теряются, если вызывающий не ведёт версию.
      final wire = Wire();
      final cart = cartOver(wire);

      final barcodes = [for (var i = 0; i < 10; i++) (i + 100).toString()];
      final all = <Future<CartView>>[
        for (var i = 0; i < 10; i++)
          cart.addByBarcode(_terminal, barcodes[i], m('k$i', baseVersion: i)),
      ];
      await Future.wait(all);

      expect(wire.sent.map((r) => r.body['barcode']), barcodes);
      expect(
        wire.peakOpen,
        1,
        reason:
            'больше одного потока сразу — значит команды обгоняли друг '
            'друга, и два быстрых скана могли примениться наоборот',
      );
      expect(
        wire.openNow,
        0,
        reason:
            'после десяти сканов остались открытые потоки — за смену их '
            'накопятся сотни',
      );
    });

    test('отказ в середине очереди не запирает её навсегда', () async {
      // Очередь, собранная цепочкой `Future`, наследует отказ: непойманный
      // отказ второй команды остановил бы третью и все следующие — касса
      // была бы жива, а рабочее место молчало бы до перезагрузки вкладки.
      final wire = Wire(
        replyTo: (request) => request.body['barcode'] == '222'
            ? Answer([
                const ErrorFrame(
                  cartProductNotFoundCode,
                  'товар не найден',
                ).encode(),
              ])
            : Answer([okCart()]),
      );
      final cart = cartOver(wire);

      // Версии предсказаны `v + i`. На настоящей кассе после отказа второй
      // третью пришлось бы пересчитать — отказ версию не поднимает, и это
      // тот же предел предсказания, что назван в докстринге
      // `WtCartService`; здесь проверяется живучесть очереди, а не
      // арифметика версий, и провод подставной.
      final first = cart.addByBarcode(_terminal, '111', m('k1'));
      final refused = cart.addByBarcode(
        _terminal,
        '222',
        m('k2', baseVersion: 1),
      );
      final third = cart.addByBarcode(
        _terminal,
        '333',
        m('k3', baseVersion: 2),
      );

      await first;
      await expectLater(refused, throwsA(isA<WireRefusal>()));
      await third;

      expect(wire.sent.map((r) => r.body['barcode']), ['111', '222', '333']);
    });

    test('очередь на рабочее место, а не одна на всех', () async {
      // Общая очередь означала бы, что соседнее рабочее место ждёт чужого
      // скана. Ловится тем, что команда другого терминала уходит, пока
      // первая держится.
      final wire = Wire()..hold = true;
      final cart = cartOver(wire);

      final mine = cart.addByBarcode(_terminal, '111', m('k1'));
      final neighbour = cart.addByBarcode(_otherTerminal, '222', m('k2'));

      await pumpEventQueue();
      expect(
        wire.sent,
        hasLength(2),
        reason: 'очередь общая: чужой терминал ждёт моего скана',
      );

      wire.releaseAll();
      await Future.wait([mine, neighbour]);
    });

    test('очередь не копит задержку: десять команд проходят разом', () async {
      // Страховка от вырождения: «одна команда в полёте» не имеет права
      // превратиться в «команды уходят по одной с задержкой». Кассир
      // сканирует быстро.
      final wire = Wire();
      final cart = cartOver(wire);
      final clock = Stopwatch()..start();

      for (var i = 0; i < 10; i++) {
        await cart.addByBarcode(_terminal, '$i', m('k$i'));
      }
      clock.stop();

      expect(
        clock.elapsedMilliseconds,
        lessThan(250),
        reason:
            'десять команд заняли ${clock.elapsedMilliseconds} мс на проводе, '
            'отвечающем мгновенно, — очередь ждёт таймером, а не ответом',
      );
      expect(wire.sent, hasLength(10));
    });

    test('поиск не стоит в очереди за сканом', () async {
      // Поиск ничего не меняет: ни повторять, ни упорядочивать его не с чем
      // (`SaleOps.search` — вопрос без метки команды). Поставь его в очередь
      // — и выдача перестала бы приходить, пока касса думает над сканом.
      final wire = Wire(
        replyTo: (request) => request.op == SaleOps.search.name
            ? Answer([
                const OkFrame({searchResultsKey: []}).encode(),
              ])
            : Answer([okCart()]),
      )..hold = true;
      final cart = cartOver(wire);

      final scan = cart.addByBarcode(_terminal, '111', m('k1'));
      final found = cart.search('мол');

      await pumpEventQueue();
      // Порядок здесь не утверждается, и это измерено: команда тратит одну
      // микрозадачу на вход в очередь, поэтому вопрос, заданный тем же
      // тактом, уходит первым. На корзину это не влияет — поиск её не
      // трогает; важно только то, что он ушёл, пока скан держат.
      expect(
        wire.sent.map((r) => r.op),
        containsAll([SaleOps.addByBarcode.name, SaleOps.search.name]),
        reason:
            'поиск встал в очередь за сканом: выдача не придёт, пока '
            'касса думает над товаром',
      );

      wire.releaseAll();
      await Future.wait<Object?>([scan, found]);
    });

    test('подписка не стоит в очереди за командой', () async {
      final wire = Wire(
        replyTo: (request) => request.op == SaleOps.cart.name
            ? Answer([updateCart()])
            : Answer([okCart()]),
      )..hold = true;
      final cart = cartOver(wire);

      final scan = cart.addByBarcode(_terminal, '111', m('k1'));
      final watched = cart.watch(_terminal).first;

      await pumpEventQueue();
      expect(
        wire.sent.map((r) => r.op),
        containsAll([SaleOps.addByBarcode.name, SaleOps.cart.name]),
        reason:
            'подписка встала в очередь за командой: экран не увидел бы '
            'корзину, пока касса думает над сканом',
      );

      wire.releaseAll();
      await scan;
      await watched;
    });
  });

  group('повтор: ровно один раз и только на обрыв', () {
    test('обрыв посреди команды повторяет её тем же ключом', () async {
      var attempt = 0;
      final wire = Wire(
        replyTo: (_) => ++attempt == 1 ? const Broken() : Answer([okCart()]),
      );
      final cart = cartOver(wire);

      await cart.addByBarcode(_terminal, '111', m('k1'));

      expect(wire.sent, hasLength(2));
      expect(
        wire.sent[0].body['key'],
        wire.sent[1].body['key'],
        reason: 'повтор новым ключом добавил бы вторую строку',
      );
      expect(
        wire.sent[1].body['baseVersion'],
        wire.sent[0].body['baseVersion'],
      );
      expect(wire.sent[1].body['receiptNo'], wire.sent[0].body['receiptNo']);
    });

    test('настоящий обрыв связи — сырая ошибка — тоже повторяется', () async {
      // Измерено в исходнике: `WtSession._pump` кладёт отказ чтения в поток
      // как `addError(error)` сырым объектом, а `WtDispatcher.ask` ловит
      // только `StateError` от пустого потока. То есть обрыв Wi-Fi посреди
      // скана — сценарий, ради которого повтор и заведён, — приходит **не**
      // `WtProtocolError`. Повтор, различающий только коды провода, в поле
      // не сработал бы ни разу.
      var attempt = 0;
      final wire = Wire(
        replyTo: (_) => ++attempt == 1
            ? const RawFailure('TypeError: Failed to fetch')
            : Answer([okCart()]),
      );
      final cart = cartOver(wire);

      await cart.addByBarcode(_terminal, '111', m('k1'));

      expect(wire.sent, hasLength(2));
      expect(wire.sent[0].body['key'], wire.sent[1].body['key']);
    });

    test('повтор ровно один раз: второй обрыв отдаёт отказ кассиру', () async {
      final wire = Wire(replyTo: (_) => const Broken());
      final cart = cartOver(wire);

      await expectLater(
        cart.addByBarcode(_terminal, '111', m('k1')),
        throwsA(isA<WtProtocolError>()),
      );

      expect(
        wire.sent,
        hasLength(2),
        reason: 'повторов больше одного — терминал крутит вечно вместо отказа',
      );
    });

    test('отказ кассы не повторяется — иначе строка спишется дважды', () async {
      // Самая дорогая из проб этой задачи. «Повторяем всё подряд» выглядит
      // надёжнее и стоит второй строки в чеке: отказ кассы — это ответ, а не
      // потерянный вопрос, и повторять в нём нечего.
      final wire = Wire(
        replyTo: (_) => Answer([
          const ErrorFrame(cartStaleCode, 'версия устарела').encode(),
        ]),
      );
      final cart = cartOver(wire);

      await expectLater(
        cart.addByBarcode(_terminal, '111', m('k1')),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', cartStaleCode),
        ),
      );

      expect(wire.sent, hasLength(1), reason: 'отказ кассы ушёл на повтор');
    });

    test('отказ по праву доезжает тем же типом, что и на кассе', () async {
      // Экран не различает реализаций (задача 13): кассовая
      // `LocalCartService` бросает `WireRefusal`, значит и браузерная
      // обязана. Оставь код кассы `WtProtocolError` — и `on WireRefusal`
      // экрана поймал бы отказ на кассе и не поймал бы по проводу.
      final wire = Wire(
        replyTo: (_) => Answer([
          const ErrorFrame('forbidden', 'нет права op.sell_discount').encode(),
        ]),
      );
      final cart = cartOver(wire);

      await expectLater(
        cart.setDiscountPercent(
          _terminal,
          'l1',
          d('10'),
          m('k1'),
          by: fullDiscountAuthority,
        ),
        throwsA(isA<WireRefusal>().having((r) => r.code, 'code', 'forbidden')),
      );
      expect(wire.sent, hasLength(1));
    });

    test('истёкший сеанс доезжает SessionLost и не повторяется', () async {
      final wire = Wire(
        replyTo: (_) =>
            Answer([const ErrorFrame('unauthorized', 'сеанс истёк').encode()]),
      );
      final cart = cartOver(wire);

      await expectLater(
        cart.addByBarcode(_terminal, '111', m('k1')),
        throwsA(isA<SessionLost>()),
      );
      expect(wire.sent, hasLength(1));
    });

    test('обрыв не выдаётся за отказ кассы: тип остаётся проводным', () async {
      // Обрыв — «связь потеряна», отказ — «касса сказала нет». Смешай их, и
      // экран покажет кассиру причину, которой касса не называла (шаг 10
      // спеки: терминал показывает названное состояние связи).
      final wire = Wire(replyTo: (_) => const Broken());
      final cart = cartOver(wire);

      await expectLater(
        cart.clear(_terminal, m('k1')),
        throwsA(
          isA<WtProtocolError>().having((e) => e.code, 'code', 'no_answer'),
        ),
      );
    });
  });

  group('беды кассы: отказ по форме, авария по существу', () {
    // Круг правки 2. Умолчание было названо докстрингом `_named` и держалось
    // **только** им: разбор перенёс эти три кода в `_wireCodes` — и весь
    // набор четырёх каталогов остался 911 passed, 0 failed. Значит завтрашняя
    // правка «падение кассы — это не отказ корзины» прошла бы молча, а
    // следствие, ради названности которого писан раздел, исчезло бы.
    //
    // Диверсия 8 (снять перевод целиком) этого не ловит: она красит другое.
    for (final code in ['handler_failed', 'guard_failed', 'not_a_request']) {
      test('$code доезжает отказом и не повторяется', () async {
        final wire = Wire(
          replyTo: (_) =>
              Answer([ErrorFrame(code, 'касса не справилась').encode()]),
        );

        await expectLater(
          cartOver(wire).addByBarcode(_terminal, '111', m('k1')),
          throwsA(isA<WireRefusal>().having((r) => r.code, 'code', code)),
          reason:
              'беда самой кассы приезжает по проводу названным отказом — на '
              'кассе то же событие доходит до экрана сырым исключением. '
              'Расхождение honest и записано в докстринге `_named`; правка, '
              'которая его снимет, обязана покрасить эту пробу',
        );
        expect(
          wire.sent,
          hasLength(1),
          reason:
              'обработчик, упавший на этой команде, упадёт на ней и во '
              'второй раз — повторять нечего',
        );
      });
    }
  });

  group('сторож наивного вызывающего (assert в очереди)', () {
    // Круг правки 2. `assert` срезается в релизе и краснеет под
    // `flutter test`: ошибка не в кассе и не в проводе, а в том, кто зовёт
    // контракт, и видна она только тому, кто пишет экран.
    test('две команды одного чека от одного снимка — красное', () async {
      final wire = Wire()..hold = true;
      final cart = cartOver(wire);

      final first = cart.addByBarcode(_terminal, '111', m('k1'));
      // Метка первой команды проставляется **синхронно**, в самом вызове —
      // так что сторожу есть с чем сравнивать уже здесь (измерено кругом
      // правки 3; прежний комментарий утверждал обратное по рассуждению).
      // `pumpEventQueue` нужен только затем, чтобы в конце пробы было что
      // отпускать: до него команда до подставной кассы не доехала.
      await pumpEventQueue();

      expect(
        // Замыкание **не отдаёт фьючерс наружу**: верни его — и `throwsA`
        // станет ждать команду, которую держит провод, а снятый сторож
        // покрасил бы пробу таймаутом в тридцать секунд вместо названного
        // отказа. Следующий разбор принял бы такую красноту за мерцание
        // (круг правки 3).
        () {
          cart.addByBarcode(_terminal, '222', m('k2'));
        },
        throwsA(isA<AssertionError>()),
        reason:
            'ровно наивный вызывающий: касса применит первую и ответит на '
            'вторую cart_stale',
      );

      wire.releaseAll();
      await first;
    });

    test('та же версия после погашенной предыдущей — законно', () async {
      // Отказ версию **не** поднимает, значит шаг назад после него законен.
      // Сравнение поэтому идёт только с непогашенной командой.
      final wire = Wire();
      final cart = cartOver(wire);

      await cart.addByBarcode(_terminal, '111', m('k1'));
      await cart.addByBarcode(_terminal, '222', m('k2'));

      expect(wire.sent, hasLength(2));
    });

    test(
      'два холодных start подряд — законно, версии там не сверяют',
      () async {
        // Условие, которого не было в брифе круга правки и которое нашлось
        // проверкой: `start` с `receiptNo == null` означает «не знаю, что у
        // меня в работе», и касса версию у него не сверяет вовсе. Без этого
        // условия сторож красил бы две вкладки, зовущие `start` первым делом,
        // — совершенно законный вызов.
        final wire = Wire()..hold = true;
        final cart = cartOver(wire);

        final first = cart.start(
          terminalId: _terminal,
          wholesale: false,
          meta: m('k1', receiptNo: null),
        );
        await pumpEventQueue();

        late final Future<CartView> second;
        expect(
          // Тот же приём, что и у красной пробы: фьючерс наружу не отдаём.
          () {
            second = cart.start(
              terminalId: _terminal,
              wholesale: false,
              meta: m('k2', receiptNo: null),
            );
          },
          returnsNormally,
        );

        wire.releaseAll();
        await pumpEventQueue();
        wire.releaseAll();
        await Future.wait([first, second]);
      },
    );

    test('одна версия у РАЗНЫХ чеков — законно, это два счётчика', () async {
      final wire = Wire()..hold = true;
      final cart = cartOver(wire);

      final first = cart.addByBarcode(_terminal, '111', m('k1', receiptNo: 41));
      await pumpEventQueue();

      late final Future<CartView> second;
      expect(
        () {
          second = cart.addByBarcode(_terminal, '222', m('k2', receiptNo: 77));
        },
        returnsNormally,
        reason:
            'версии разных чеков — два разных счётчика, совпадение чисел '
            'ничего не значит',
      );

      // Вторая стоит в очереди за первой: отпускать надо дважды.
      wire.releaseAll();
      await pumpEventQueue();
      wire.releaseAll();
      await Future.wait([first, second]);
    });
  });

  group('пределы сторожа: что он пропускает по построению', () {
    test(
      'два terminalId из одной вкладки бьют в одну корзину мимо сторожа',
      () async {
        // Круг правки 3, дыра F1 — и она концептуальная, а не мелкая.
        // `terminalId` на провод не уезжает вовсе (проба «ни одна команда не
        // кладёт terminalId в тело»), корзину касса берёт из сеанса. Значит
        // два вызова с разными именами мест из одной вкладки меняют **одну**
        // корзину, а сторож видит две очереди и две метки — и молчит.
        //
        // Проба закрепляет это как **известный предел**, а не как свойство:
        // деление по рабочему месту верно для экрана (у вкладки место одно и
        // оно из сеанса) и опоры на проводе не имеет. Закрывает дыру не
        // сторож, а контракт — см. `_notFromTheSameSnapshot`.
        final wire = Wire()..hold = true;
        final cart = cartOver(wire);

        final mine = cart.addByBarcode(_terminal, '111', m('k1'));
        await pumpEventQueue();

        expect(
          () {
            cart.addByBarcode(_otherTerminal, '222', m('k2'));
          },
          returnsNormally,
          reason:
              'сторож поймал команду соседнего рабочего места — значит он '
              'перестал делиться по terminalId, и проба «очередь на рабочее '
              'место» больше не описывает продукт',
        );

        wire.releaseAll();
        await pumpEventQueue();
        wire.releaseAll();
        await mine;
      },
    );

    test('первая команда после холодного start сторожу не видна', () async {
      // Дыра F3: в метке `start` номер чека пуст, и условие 3 пропускает не
      // только сам `start`, но и следующую за ним команду — самую частую в
      // чеке. Ровно в одну команду, дальше сторож работает.
      final wire = Wire()..hold = true;
      final cart = cartOver(wire);

      final started = cart.start(
        terminalId: _terminal,
        wholesale: false,
        meta: m('k1', receiptNo: null),
      );
      await pumpEventQueue();

      late final Future<CartView> scan;
      expect(
        () {
          scan = cart.addByBarcode(_terminal, '111', m('k2', baseVersion: 0));
        },
        returnsNormally,
        reason: 'дыра F3 закрылась — предел надо переписать, а не радоваться',
      );

      wire.releaseAll();
      await pumpEventQueue();
      wire.releaseAll();
      await Future.wait([started, scan]);
    });
  });

  group('начало чека: опт — это два кадра', () {
    test('розничный чек начинается одним кадром', () async {
      final wire = Wire();
      final cart = cartOver(wire);

      await cart.start(
        terminalId: _terminal,
        wholesale: false,
        meta: m('k1', receiptNo: null),
      );

      expect(wire.sent.map((r) => r.op), [SaleOps.start.name]);
    });

    test('оптовый чек — sale.start, затем sale.setWholesale', () async {
      // `sale.start` признака опта не несёт вовсе: он был обходом права
      // (`SaleOps.start`, круг правки 1 задачи 10). Значит опт с браузера —
      // два кадра, и второй идёт под своим правом.
      final wire = Wire(
        replyTo: (request) => Answer([
          okCart(
            version: 3,
            wholesale: request.op == SaleOps.setWholesale.name,
          ),
        ]),
      );
      final cart = cartOver(wire);

      final started = await cart.start(
        terminalId: _terminal,
        wholesale: true,
        meta: m('k1', receiptNo: null),
      );

      expect(wire.sent.map((r) => r.op), [
        SaleOps.start.name,
        SaleOps.setWholesale.name,
      ]);
      expect(started.wholesale, isTrue, reason: 'режим рисуется по снимку');
      expect(wire.sent[1].body['wholesale'], isTrue);
    });

    test('второй кадр идёт своим ключом и версией из первого ответа', () async {
      // Тот же ключ на обоих кадрах означал бы, что касса приняла второй за
      // повтор первого: слот повтора один на чек (`Sales.lastCommandKey`), и
      // переключение опта молча не применилось бы вовсе.
      final wire = Wire(
        replyTo: (request) => Answer([
          okCart(
            version: 3,
            wholesale: request.op == SaleOps.setWholesale.name,
          ),
        ]),
      );
      final cart = cartOver(wire);

      await cart.start(
        terminalId: _terminal,
        wholesale: true,
        meta: m('k1', receiptNo: null),
      );

      expect(
        wire.sent[1].body['key'],
        isNot(wire.sent[0].body['key']),
        reason: 'касса приняла бы переключение опта за повтор начала',
      );
      expect(
        wire.sent[1].body['baseVersion'],
        3,
        reason: 'версия второго кадра — из ответа на первый, а не из метки',
      );
      expect(wire.sent[1].body['receiptNo'], 41);
    });

    test('между двумя кадрами начала свой скан не влезает', () async {
      // Щель, названная в `SaleOps.start`: строка, легшая между кадрами,
      // остаётся по рознице, а снимок смеси цен не помечает ничем.
      final wire = Wire(
        replyTo: (request) => Answer([
          okCart(
            version: 3,
            wholesale: request.op == SaleOps.setWholesale.name,
          ),
        ]),
      )..hold = true;
      final cart = cartOver(wire);

      final started = cart.start(
        terminalId: _terminal,
        wholesale: true,
        meta: m('k1', receiptNo: null),
      );
      final scan = cart.addByBarcode(_terminal, '111', m('k2', baseVersion: 3));

      await pumpEventQueue();
      expect(wire.sent.map((r) => r.op), [SaleOps.start.name]);

      wire.releaseFirst();
      await pumpEventQueue();
      expect(wire.sent.map((r) => r.op), [
        SaleOps.start.name,
        SaleOps.setWholesale.name,
      ], reason: 'скан лёг между началом чека и переключением опта');

      wire.releaseAll();
      await pumpEventQueue();
      wire.releaseAll();
      await Future.wait([started, scan]);
    });

    test('отказ второго кадра выносится наверх, а не глотается', () async {
      // Для самообслуживания и беспилотного режима отказ по `op.editPrice` —
      // законный исход (`PointModePermissions.effective` отбирает правку
      // цены). Проглоти его — и экран покажет опт, которого нет.
      final wire = Wire(
        replyTo: (request) => request.op == SaleOps.setWholesale.name
            ? Answer([
                const ErrorFrame(
                  'forbidden',
                  'нет права op.edit_price',
                ).encode(),
              ])
            : Answer([okCart()]),
      );
      final cart = cartOver(wire);

      await expectLater(
        cart.start(
          terminalId: _terminal,
          wholesale: true,
          meta: m('k1', receiptNo: null),
        ),
        throwsA(isA<WireRefusal>().having((r) => r.code, 'code', 'forbidden')),
      );

      expect(
        wire.sent.where((r) => r.op == SaleOps.start.name),
        hasLength(1),
        reason:
            'повторено начало чека вместо переключения — завёлся бы '
            'второй чек',
      );
    });

    test('возобновление уже оптового чека второго кадра не шлёт', () async {
      // Начало чека — это ещё и возобновление. Чек, который уже оптовый,
      // переключать не за чем: команда сожгла бы слот повтора и подняла
      // версию, обесценив чужие команды в полёте.
      final wire = Wire(replyTo: (_) => Answer([okCart(wholesale: true)]));
      final cart = cartOver(wire);

      await cart.start(
        terminalId: _terminal,
        wholesale: true,
        meta: m('k1', receiptNo: null),
      );

      expect(wire.sent.map((r) => r.op), [SaleOps.start.name]);
    });
  });

  group('контракт целиком', () {
    /// Закрытая таблица: операция каталога → вызов контракта, который её
    /// порождает. Метод, забытый реализацией, до сборки не доживает (Dart
    /// требует реализовать интерфейс); ловится здесь другое — метод,
    /// зовущий **чужую** операцию копипастой, и операция каталога, до
    /// которой не дотягивается ни один метод.
    final invocations = <String, Future<void> Function(WtCartService cart)>{
      SaleOps.start.name: (cart) =>
          cart.start(terminalId: _terminal, wholesale: false, meta: m('k')),
      SaleOps.cart.name: (cart) => cart.watch(_terminal).first,
      SaleOps.deferredList.name: (cart) =>
          cart.watchDeferred(by: fullDiscountAuthority).first,
      SaleOps.search.name: (cart) => cart.search('мол'),
      SaleOps.addByBarcode.name: (cart) =>
          cart.addByBarcode(_terminal, '4870001234567', m('k')),
      SaleOps.addProduct.name: (cart) =>
          cart.addProduct(_terminal, 100, d('2.5'), m('k')),
      SaleOps.setQuantity.name: (cart) =>
          cart.setQuantity(_terminal, 'l1', d('3'), m('k')),
      SaleOps.increment.name: (cart) => cart.increment(_terminal, 'l1', m('k')),
      SaleOps.decrement.name: (cart) => cart.decrement(_terminal, 'l1', m('k')),
      SaleOps.setDiscountPercent.name: (cart) => cart.setDiscountPercent(
        _terminal,
        'l1',
        d('10'),
        m('k'),
        by: fullDiscountAuthority,
      ),
      SaleOps.setDiscountAmount.name: (cart) => cart.setDiscountAmount(
        _terminal,
        'l1',
        d('50'),
        m('k'),
        by: fullDiscountAuthority,
      ),
      SaleOps.updatePrice.name: (cart) => cart.updatePrice(
        _terminal,
        'l1',
        d('499.99'),
        m('k'),
        by: fullDiscountAuthority,
      ),
      SaleOps.setMark.name: (cart) =>
          cart.setMark(_terminal, 'l1', '0104870', m('k')),
      SaleOps.removeLine.name: (cart) =>
          cart.removeLine(_terminal, 'l1', m('k')),
      SaleOps.clear.name: (cart) => cart.clear(_terminal, m('k')),
      SaleOps.defer.name: (cart) => cart.defer(_terminal, m('k'), by: fullDiscountAuthority),
      SaleOps.loadDeferred.name: (cart) =>
          cart.loadDeferred(_terminal, 55, m('k'), by: fullDiscountAuthority),
      SaleOps.setAgent.name: (cart) => cart.setAgent(_terminal, 3, m('k')),
      SaleOps.setWholesale.name: (cart) =>
          cart.setWholesale(_terminal, true, m('k'), by: fullDiscountAuthority),
    };

    /// Отличительные поля каждой операции: тело, собранное копипастой
    /// соседки, теряет своё поле и красит именно эту строку.
    const distinctive = <String, List<String>>{
      'sale.addByBarcode': ['barcode'],
      'sale.addProduct': ['productId', 'quantity'],
      'sale.setQuantity': ['lineId', 'quantity'],
      'sale.increment': ['lineId'],
      'sale.decrement': ['lineId'],
      'sale.setDiscountPercent': ['lineId', 'percent'],
      'sale.setDiscountAmount': ['lineId', 'amount'],
      'sale.updatePrice': ['lineId', 'price'],
      'sale.setMark': ['lineId', 'mark'],
      'sale.removeLine': ['lineId'],
      'sale.loadDeferred': ['deferredReceiptNo'],
      'sale.setAgent': ['agentId'],
      'sale.setWholesale': ['wholesale'],
      'sale.search': ['query'],
    };

    test('таблица накрывает весь каталог продажи, кроме пробы провода', () {
      // `sale.editTerms` — не метод корзины, а договор условий правки строки
      // (`SaleEditTermsReader`, задача 44); его накрывает
      // `wt_sale_route_test.dart`, группа «скидка с терминала».
      final catalog = SaleOps.all
          .map((op) => op.name)
          .where((name) => name != SaleOps.salePing.name)
          .where((name) => name != SaleOps.editTerms.name)
          // Задача 45: быстрые товары — договор `QuickProductCatalog`, не
          // корзины; его накрывает `wt_quick_product_catalog_test.dart`.
          .where((name) => name != SaleOps.quickCategories.name)
          .where((name) => name != SaleOps.quickItems.name)
          .toSet();

      expect(
        invocations.keys.toSet(),
        catalog,
        reason:
            'операция каталога, до которой не дотягивается ни один метод '
            'контракта, — это команда, которую браузерный терминал послать '
            'не может вовсе',
      );
    });

    for (final entry in invocations.entries) {
      test('${entry.key} — своя операция и свои доводы', () async {
        final wire = Wire(
          replyTo: (request) => switch (request.op) {
            'sale.cart' => Answer([updateCart()]),
            'sale.deferredList' => Answer([
              const UpdateFrame({deferredListKey: []}).encode(),
            ]),
            'sale.search' => Answer([
              const OkFrame({searchResultsKey: []}).encode(),
            ]),
            _ => Answer([okCart()]),
          },
        );

        await entry.value(cartOver(wire));

        expect(wire.sent.map((r) => r.op), [entry.key]);
        for (final field in distinctive[entry.key] ?? const <String>[]) {
          expect(
            wire.sent.single.body.containsKey(field),
            isTrue,
            reason: '${entry.key} уехала без своего поля $field',
          );
        }
      });
    }

    test('ни одна команда не кладёт terminalId в тело', () async {
      // Касса **отвергает** кадр с названным рабочим местом
      // (`CartService`, правило 1; `sale_operations_test.dart`). Терминал,
      // положивший его «для верности», получил бы отказ на каждой команде.
      for (final entry in invocations.entries) {
        final wire = Wire(
          replyTo: (request) => switch (request.op) {
            'sale.cart' => Answer([updateCart()]),
            'sale.deferredList' => Answer([
              const UpdateFrame({deferredListKey: []}).encode(),
            ]),
            'sale.search' => Answer([
              const OkFrame({searchResultsKey: []}).encode(),
            ]),
            _ => Answer([okCart()]),
          },
        );

        await entry.value(cartOver(wire));

        expect(
          wire.sent.single.body.containsKey('terminalId'),
          isFalse,
          reason: '${entry.key} назвала рабочее место в теле',
        );
      }
    });

    test('деньги пересекают провод строкой, никогда числом', () async {
      // I159. Проверяется на настоящих кадрах: числовое `quantity` здесь
      // означало бы `double` на проводе и потерю точности молча.
      const moneyKeys = ['quantity', 'percent', 'amount', 'price'];
      for (final entry in invocations.entries) {
        final wire = Wire(
          replyTo: (request) => switch (request.op) {
            'sale.cart' => Answer([updateCart()]),
            'sale.deferredList' => Answer([
              const UpdateFrame({deferredListKey: []}).encode(),
            ]),
            'sale.search' => Answer([
              const OkFrame({searchResultsKey: []}).encode(),
            ]),
            _ => Answer([okCart()]),
          },
        );

        await entry.value(cartOver(wire));

        // Кадр берётся уже закодированным: смотрим на то, что реально
        // уехало строкой JSON, а не на карту до кодирования.
        final body =
            (jsonDecode(wire.sent.single.encode())
                    as Map<String, Object?>)['body']!
                as Map<String, Object?>;
        for (final key in moneyKeys) {
          if (!body.containsKey(key)) continue;
          expect(
            body[key],
            isA<String>(),
            reason: '${entry.key}: денежное поле $key уехало числом',
          );
        }
      }
    });

    test('цена, которую double передал бы неверно, доезжает точной', () async {
      // Шестое значение правила `qa-depth`: без него проба прошла бы и на
      // `double`, то есть не проверяла бы ничего из того, ради чего заведён
      // `Decimal` (I159). Здесь оба рода потери сразу: сумма 0.1+0.2, которую
      // double показывает как 0.30000000000000004, и число за пределами
      // точности double (2^53 + 1).
      for (final money in ['0.3', '9007199254740993.001', '0.0005']) {
        final wire = Wire();
        await cartOver(wire).updatePrice(
          _terminal,
          'l1',
          Decimal.parse(money),
          m('k'),
          by: fullDiscountAuthority,
        );

        final body =
            (jsonDecode(wire.sent.single.encode())
                    as Map<String, Object?>)['body']!
                as Map<String, Object?>;
        expect(
          body['price'],
          money,
          reason:
              'цена $money доехала как ${body['price']} — через double '
              'проехала бы ровно так',
        );
      }

      // И контрольный: та же сумма, посчитанная сложением, а не разобранная
      // из строки. `double` дал бы здесь 0.30000000000000004.
      final wire = Wire();
      await cartOver(wire).updatePrice(
        _terminal,
        'l1',
        Decimal.parse('0.1') + Decimal.parse('0.2'),
        m('k'),
        by: fullDiscountAuthority,
      );
      expect(wire.sent.single.body['price'], '0.3');
    });

    // Проба «деньги собирает каталог, а не файл терминала руками» жила
    // здесь и снята кругом правки 1. Она читала **один** файл —
    // `wt_cart_service.dart`, — то есть охраняла уже своё собственное
    // обоснование и оставляла дыру ровно там, где её открыл бы следующий
    // файл `lib/web/`. Вместо неё расширена область настоящего сторожа:
    // `_wireDirs` в `test/architecture/money_over_wire_test.dart` теперь
    // включает `lib/web` целиком, и обход этого каталога закреплён там же
    // поимённо.
  });

  /// Обе половины провода торцами: настоящая база drift, настоящие
  /// `TillOperations` со сторожем прав, настоящий `TillWire` — и
  /// [WtCartService] поверх настоящего `WtDispatcher`. Подставлен один QUIC:
  /// нативной библиотеки под `flutter test` нет вовсе.
  ///
  /// **Зачем это сверх проб на подставном проводе.** Те доказывают форму
  /// кадра. Здесь доказывается то, на чём стоит весь повтор: касса помнит
  /// ключ и на повтор **не кладёт вторую строку**. До этой группы это было
  /// обещанием контракта, а не измерением со стороны терминала — то есть
  /// ровно тем родом «сделано», ради которого написан `anti-gaps`.
  group('петля: терминал против настоящей кассы', () {
    late AppDatabase db;
    late Loopback loop;
    late TillWire wire;
    late WtCartService cart;

    /// Та же корзина, что стоит под кассой, — чтобы сравнивать две
    /// реализации одного контракта напрямую, а не по докстрингам.
    late LocalCartService local;

    /// Та же касса, но провод переставляет одновременные команды местами —
    /// как настоящий QUIC. См. [Jittered].
    late WtCartService jittery;

    const barcode = '4870001234567';
    const cashier = 4;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      loop = Loopback();

      // Касса названа, кассир заведён, смена открыта — без этого не
      // начинается ни один чек (`SaleInitiationUseCase`), а сторож провода
      // отвечает «касса не настроена».
      await db
          .into(db.thisPosEntries)
          .insert(
            const ThisPosEntriesCompanion(
              id: Value(1),
              cashBoxName: Value('Касса-петля'),
              // Правка цены **включена** настройкой кассы: с 2026-09-19 опт
              // закрыт ею на обоих входах, и без этого все оптовые пробы
              // ниже краснели бы по чужой причине — отказом настройки
              // вместо отказа права.
              editPrice: Value(true),
            ),
          );
      await db
          .into(db.users)
          .insert(
            const UsersCompanion(id: Value(cashier), name: Value('Айгуль')),
          );
      await db
          .into(db.shifts)
          .insert(
            ShiftsCompanion(
              userId: Value(cashier),
              openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
              isOpened: Value(true),
              isSynced: Value(false),
            ),
          );
      // Каталог, а не одна строка: без записей, которые **не** должны
      // попасть в выдачу, поиск не отличает «нашёл нужное» от «вернул всё»
      // (`qa-depth`, правило нуля). Имена в трёх языках — казахская и
      // киргизская кириллица ловит сравнение строк, невидимое на латинице.
      // Цена `499.995` — та, где направление округления видно.
      var ucode = 100;
      for (final (name, code, price) in [
        ('Молоко', barcode, '500'),
        ('Кефир', '4870007654321', '499.995'),
        ('Дүкен нан', '4870001111111', '0.0005'),
        ('Ысык-Көл суу', '4870002222222', '1234567890123.123'),
      ]) {
        await db
            .into(db.productInfos)
            .insert(
              ProductInfosCompanion.insert(
                ucode: Value(ucode),
                barcode: int.parse(code),
                name: name,
                type: 0,
                measure: 0,
                quantity: Value(d('100')),
              ),
            );
        await db
            .into(db.productPrices)
            .insert(
              ProductPricesCompanion.insert(
                ucode: Value(ucode),
                barcode: int.parse(code),
                sellingPrice: Value(d(price)),
              ),
            );
        ucode += 100;
      }

      final logger = Talker();
      final sessions = SessionRegistry();
      final invites = PairingInvites();
      final operations = TillOperations(
        db: db,
        bootstrap: NoopBootstrap(),
        setup: NoopSetupRepository(),
        terminals: LocalTerminalRepository(db),
        invites: invites,
        deviceBindings: NoopDeviceBindingRepository(),
        auth: LocalAuthRepository(
          db: db,
          sessions: sessions,
          throttle: LoginThrottle(),
        ),
        cart: local = LocalCartService(
          db: db,
          logger: logger,
          initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
          deferred: DeferredSaleServiceImpl(db: db, logger: logger),
          rounding: SaleRoundOptionUseCaseImpl(),
          findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
          searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
        ),
      );
      final session = sessions.mint(
        userId: cashier,
        name: 'Айгуль',
        role: 'cashier',
        // Ровно право продажи. Скидка сюда не входит намеренно: на ней
        // проверяется отказ настоящего сторожа.
        permissions: const {PermissionKeys.navSale},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: true,
        terminalId: 1,
      );
      wire = TillWire(
        loop,
        operations.askHandlers,
        watchHandlers: operations.watchHandlers,
        runHandlers: operations.runHandlers,
        guard: wireGuardForTill(
          db: db,
          access: {for (final op in TillOps.all) op.name: op.access},
          sessions: sessions,
        ),
      )..start();

      final browser = WtDispatcher(loop, tokens: FakeTokens(session.token));
      // Рабочее место заводится **настоящим путём** — тем же кадром, каким
      // это делает браузерная вкладка. Была `terminals.selfEnsure`;
      // задача 19 вырезала оттуда запись в `_sessionTerminals` (она
      // сажала любую сессию на строку самой кассы, без кода и без
      // секрета), и путь вкладки — `terminals.register` с одноразовым
      // кодом привязки. Без места касса не знает, чья корзина.
      await browser.ask<TerminalRegisterRequest, TerminalEnrollment>(
        TillOps.terminalRegister,
        (name: 'Вкладка', code: invites.mint().code),
      );
      cart = WtCartService(browser);
      // Та же касса через провод, переставляющий одновременные команды
      // местами, — так ведёт себя настоящий QUIC (см. [Jittered]).
      jittery = WtCartService(
        WtDispatcher(Jittered(loop), tokens: FakeTokens(session.token)),
      );
    });

    tearDown(() async {
      await wire.stop();
      await loop.dispose();
      await db.close();
    });

    Future<int> lines() async =>
        (await db.select(db.saleProducts).get()).length;

    test('скан с браузера кладёт строку в базу кассы', () async {
      final started = await cart.start(
        terminalId: 1,
        wholesale: false,
        meta: m('k1', receiptNo: null),
      );

      final after = await cart.addByBarcode(
        1,
        barcode,
        CartCommandMeta(
          key: 'k2',
          baseVersion: started.version,
          receiptNo: started.receiptNo,
        ),
      );

      expect(after.lines, hasLength(1));
      expect(after.lines.single.name, 'Молоко');
      expect(after.lines.single.price, d('500'));
      expect(await lines(), 1, reason: 'строка не доехала до базы кассы');
    });

    test('десять сканов ПРИМЕНЯЮТСЯ, а не только уходят по порядку', () async {
      // Круг правки 1. Проба на подставном проводе доказывала порядок
      // отправки и молчала о применении: там на любой запрос отвечают
      // постоянной версией, и сверять метки некому. Здесь касса настоящая, и
      // измеряется то, что обещает строка приёмки плана, — **применяются**.
      //
      // Кассир сканирует десять раз, не дожидаясь ни одного ответа. Версии
      // предсказаны: очередь гарантирует, что команды применятся по одной и
      // подряд, значит i-я считается от `started.version + i`. Наивный
      // вызывающий, взявший версию из одного снимка на все десять, теряет
      // девять сканов — измерено этой же пробой с наивными метками:
      // исходы `[1, cart_stale ×9]`, в базе одна единица вместо десяти
      // (см. обязанность вызывающего в докстринге `WtCartService`).
      final started = await cart.start(
        terminalId: 1,
        wholesale: false,
        meta: m('k0', receiptNo: null),
      );

      final answers = await Future.wait([
        for (var i = 0; i < 10; i++)
          cart.addByBarcode(
            1,
            barcode,
            CartCommandMeta(
              key: 'скан-$i',
              baseVersion: started.version + i,
              receiptNo: started.receiptNo,
            ),
          ),
      ]);

      expect(answers.map((v) => v.version), [
        for (var i = 1; i <= 10; i++) started.version + i,
      ], reason: 'версии не идут подряд — команда потерялась или обогнала');

      final rows = await db.select(db.saleProducts).get();
      expect(rows, hasLength(1), reason: 'один товар — одна строка чека');
      expect(
        rows.single.quantity,
        d('10'),
        reason:
            'до кассы доехало ${rows.single.quantity} единиц из десяти — '
            'очередь дала порядок, но команды не применились',
      );
      expect(answers.last.lines.single.quantity, d('10'));
    });

    test('десять сканов ПРИМЕНЯЮТСЯ и на проводе, который их путает', () async {
      // Круг правки 1, вторая находка. Проба выше зелена и **без очереди**:
      // петля отдаёт кадры кассе в том порядке, в каком вызван
      // `finishSending`, то есть сохраняет порядок сама. Значит она мерит
      // применение, но не мерит очередь — тот же класс ловушки, что
      // сериализация транзакций drift.
      //
      // Здесь провод порядка не даёт (см. [Jittered]): чем позже открыт
      // поток, тем раньше он доезжает. С очередью переставлять нечего — в
      // полёте всегда одна команда. Без очереди девять сканов из десяти
      // приходят от устаревшей версии и теряются.
      final started = await jittery.start(
        terminalId: 1,
        wholesale: false,
        meta: m('k0', receiptNo: null),
      );

      final answers = await Future.wait([
        for (var i = 0; i < 10; i++)
          jittery.addByBarcode(
            1,
            barcode,
            CartCommandMeta(
              key: 'путаный-$i',
              baseVersion: started.version + i,
              receiptNo: started.receiptNo,
            ),
          ),
      ]);

      expect(answers.map((v) => v.version), [
        for (var i = 1; i <= 10; i++) started.version + i,
      ]);
      final rows = await db.select(db.saleProducts).get();
      expect(
        rows.single.quantity,
        d('10'),
        reason:
            'до кассы доехало ${rows.single.quantity} единиц из десяти — '
            'провод переставил команды, и очередь этого не удержала',
      );
    });

    test('повтор тем же ключом второй строки не кладёт', () async {
      // То, на чём стоит весь повтор этой задачи. Проверяется со стороны
      // терминала, а не рассуждением о том, что касса помнит ключ.
      final started = await cart.start(
        terminalId: 1,
        wholesale: false,
        meta: m('k1', receiptNo: null),
      );
      final meta = CartCommandMeta(
        key: 'один-и-тот-же',
        baseVersion: started.version,
        receiptNo: started.receiptNo,
      );

      final first = await cart.addByBarcode(1, barcode, meta);
      final repeated = await cart.addByBarcode(1, barcode, meta);

      expect(await lines(), 1, reason: 'повтор скана удвоил строку в чеке');
      expect(repeated.version, first.version);
      expect(repeated.lines.single.quantity, first.lines.single.quantity);
    });

    test('отказ настоящего сторожа доезжает WireRefusal', () async {
      // Сеанс без `op.sell_discount`. Отказ приходит **от кассы**, минуя
      // экран, и тем же типом, каким его бросает кассовая реализация, —
      // иначе экран поймал бы причину на кассе и пропустил по проводу.
      final started = await cart.start(
        terminalId: 1,
        wholesale: false,
        meta: m('k1', receiptNo: null),
      );
      final added = await cart.addByBarcode(
        1,
        barcode,
        CartCommandMeta(
          key: 'k2',
          baseVersion: started.version,
          receiptNo: started.receiptNo,
        ),
      );

      await expectLater(
        cart.setDiscountPercent(
          1,
          added.lines.single.id,
          d('10'),
          CartCommandMeta(
            key: 'k3',
            baseVersion: added.version,
            receiptNo: added.receiptNo,
          ),
          by: fullDiscountAuthority,
        ),
        throwsA(isA<WireRefusal>().having((r) => r.code, 'code', 'forbidden')),
      );
    });

    test('устаревшая версия отвергается названным отказом', () async {
      // I161, вторая линия обороны: очередь держит порядок, а версия ловит
      // то, что очередь удержать не может, — соседнюю вкладку того же места.
      final started = await cart.start(
        terminalId: 1,
        wholesale: false,
        meta: m('k1', receiptNo: null),
      );
      await cart.addByBarcode(
        1,
        barcode,
        CartCommandMeta(
          key: 'k2',
          baseVersion: started.version,
          receiptNo: started.receiptNo,
        ),
      );

      await expectLater(
        cart.addByBarcode(
          1,
          barcode,
          CartCommandMeta(
            key: 'k3',
            baseVersion: started.version,
            receiptNo: started.receiptNo,
          ),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', cartStaleCode),
        ),
      );
      expect(await lines(), 1);
    });

    test('опт: у двух реализаций одного контракта разные права', () async {
      // Круг правки 1. В докстринге это стояло как «законный исход», а на
      // деле это **расхождение прав** — то есть место, где «экран не
      // различает реализаций» неправда, и знать об этом надо до задачи 8.
      //
      // Сеанс ниже несёт ровно `nav.sale`.
      final onTill = await local.start(
        terminalId: 2,
        wholesale: true,
        meta: m('касса', receiptNo: null),
      );
      expect(
        onTill.wholesale,
        isTrue,
        reason: 'на кассе опт открывается без единого ПРАВА (настройка есть)',
      );

      await expectLater(
        cart.start(
          terminalId: 1,
          wholesale: true,
          meta: m('браузер', receiptNo: null),
        ),
        throwsA(isA<WireRefusal>().having((r) => r.code, 'code', 'forbidden')),
        reason:
            'по проводу опт это отдельная операция под `op.editPrice` — '
            'задача 10 сняла довод у sale.start как обход права',
      );
    });

    test('опт закрыт настройкой кассы и на кассовом входе тоже', () async {
      // Дорожка 2026-09-19 закрыла опт настройкой «правка цены» на **обоих**
      // входах. Раньше выключенная настройка держала правку цены строки, но
      // оптовый прейскурант мимо неё открывался целиком — то есть настройка
      // отвечала «нет» на вопрос, который её не спрашивали.
      await db
          .update(db.thisPosEntries)
          .write(const ThisPosEntriesCompanion(editPrice: Value(false)));

      await expectLater(
        local.start(
          terminalId: 2,
          wholesale: true,
          meta: m('касса', receiptNo: null),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', cartDeniedPolicyCode),
        ),
      );
    });

    test('поиск отдаёт нужное, а не всё подряд', () async {
      // Правило `qa-depth`, самый пропускаемый пункт: без записей, которые
      // **не должны** попасть в выдачу, проба не отличает «нашёл нужное» от
      // «вернул всё». В каталоге кассы четыре товара, из них подходит один.
      final found = await cart.search('Мол');

      expect(found, hasLength(1), reason: 'выдача принесла лишнее');
      expect(found.single.name, 'Молоко');
    });

    test('поиск по казахскому имени находит его, а не соседей', () async {
      // Казахская кириллица (`ү`, `қ`) ловит ошибки сравнения строк,
      // невидимые на латинице и на русском.
      final found = await cart.search('Дүкен');

      expect(found.map((r) => r.name), ['Дүкен нан']);
    });
  });
}
