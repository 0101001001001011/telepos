/// Кодеки возврата — задача 19 плана «Продажа с браузерного терминала».
///
/// Проверяется не «пара что-то вернула», а то, что обе половины читают одну
/// форму: круговой обмен сверяет **объект целиком** (типы возврата умеют
/// сравнение по значению с задачи 18), а не пять полей руками. Разница
/// измерена кругом правки 1 задачи 9: там кодек, прибитый к `measure: 0`,
/// прошёл 171 зелёный тест ровно потому, что проба сверяла поля поимённо и
/// про два из них не знала.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/refund_codec.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

const _meta = CartCommandMeta(key: 'k1', baseVersion: 4, receiptNo: 12);

RefundLine _line({Decimal? maxQuantity}) => RefundLine(
  id: '17',
  productId: 3,
  name: 'Молоко 3.2%',
  quantity: Decimal.parse('2.5'),
  price: Decimal.parse('97.125'),
  maxQuantity: maxQuantity,
  barcode: '4870001234567',
);

void main() {
  group('метка команды', () {
    test('едет плоско и разбирается той же парой', () {
      expect(
        refundCommandMetaFromWireJson(refundCommandMetaToWireJson(_meta)),
        _meta,
      );
    });

    test('пустой номер черновика кладётся ключом, а не пропуском', () {
      // `null` здесь — утверждение «черновика у меня нет», а не «поле
      // забыли». Отличать одно от другого по отсутствию ключа — тот самый
      // молчаливый путь, которого контракт требует избегать.
      const noDraft = CartCommandMeta(
        key: 'k',
        baseVersion: 0,
        receiptNo: null,
      );
      final body = refundCommandMetaToWireJson(noDraft);

      expect(body.containsKey('receiptNo'), isTrue);
      expect(body['receiptNo'], isNull);
      expect(refundCommandMetaFromWireJson(body), noDraft);
    });
  });

  group('тела запросов', () {
    test('запрос чека разбирается той же парой — объект целиком', () {
      const request = ReceiptKey(receiptNo: 501, posId: 7, meta: _meta);

      expect(receiptKeyFromWireJson(receiptKeyToWireJson(request)), request);
    });

    test('номер чека продажи и номер черновика не затирают друг друга', () {
      // Ловушка, закрытая именем, а не комментарием: `CartCommandMeta
      // .receiptNo` в возврате несёт номер ЧЕРНОВИКА, а метка едет плоско,
      // в том же теле. Положи номер возвращаемого чека тем же именем — и
      // одно затрёт другое на месте, смотря по порядку слияния карт. Та же
      // ловушка и то же лечение, что у `deferredReceiptNo` в каталоге
      // продажи.
      const request = ReceiptKey(receiptNo: 501, posId: 7, meta: _meta);
      final body = receiptKeyToWireJson(request);

      expect(body['saleReceiptNo'], 501, reason: 'чек продажи');
      expect(body['receiptNo'], 12, reason: 'номер черновика из метки');
      expect(
        body['saleReceiptNo'] == body['receiptNo'],
        isFalse,
        reason:
            'два разных числа обязаны ехать под двумя разными именами — '
            'иначе касса получит одно вместо другого и не заметит',
      );
    });

    test('запрос строки по товару разбирается той же парой', () {
      final request = RefundLineRequest(
        productId: 3,
        quantity: Decimal.parse('1.5'),
        meta: _meta,
      );

      expect(
        refundLineRequestFromWireJson(refundLineRequestToWireJson(request)),
        request,
      );
    });

    test('запрос количества строки разбирается той же парой', () {
      final request = RefundLineQuantity(
        lineId: '17',
        quantity: Decimal.zero,
        meta: _meta,
      );

      expect(
        refundLineQuantityFromWireJson(refundLineQuantityToWireJson(request)),
        request,
      );
    });
  });

  group('снимок черновика', () {
    test('разбирается той же парой — объект целиком, включая строки', () {
      final view = RefundView(
        posId: 1,
        terminalId: 7,
        version: 3,
        draftNo: 12,
        saleReceiptNo: 501,
        salePosId: 1,
        lines: [_line(maxQuantity: Decimal.parse('4'))],
      );

      expect(refundViewFromWireJson(refundViewToWireJson(view)), view);
    });

    test('«черновика нет» — законный снимок, а не пустое тело', () {
      // Ровно то, ради чего тела собираются парами: снимок с версией ноль и
      // пустым списком строк — честный ответ «рабочее место возврат не
      // начинало», и опечатка в имени поля дала бы его вместо настоящего
      // черновика, ничем не отличимо.
      const empty = RefundView(posId: 1, terminalId: 7, version: 0, lines: []);

      final decoded = refundViewFromWireJson(refundViewToWireJson(empty));

      expect(decoded, empty);
      expect(decoded.started, isFalse);
      expect(decoded.byReceipt, isFalse);
    });

    test('потолка нет — ключа maxQuantity нет вовсе, а не null под ключом', () {
      // Возврат без чека: потолка нет, потому что нет и чека, с которым
      // сверяться. Здесь `null` и отсутствие ключа значат одно и то же — в
      // отличие от `receiptNo` метки, — поэтому ключ условный: значение под
      // ним обязано быть буквальным вызовом двери денег, а тернарный выбор
      // сторож красит нарочно.
      final body = refundLineToWireJson(_line());

      expect(body.containsKey('maxQuantity'), isFalse);
      expect(refundLineFromWireJson(body).maxQuantity, isNull);
    });

    test('деньги едут строкой, никогда числом — I159', () {
      final body = refundViewToWireJson(
        RefundView(
          posId: 1,
          terminalId: 7,
          version: 1,
          draftNo: 1,
          lines: [_line(maxQuantity: Decimal.parse('4'))],
        ),
      );
      final line = (body['lines']! as List).single as Map<String, Object?>;

      for (final entry in <String, Object?>{
        'total': body['total'],
        'line.quantity': line['quantity'],
        'line.price': line['price'],
        'line.maxQuantity': line['maxQuantity'],
        'line.total': line['total'],
      }.entries) {
        expect(entry.value, isA<String>(), reason: entry.key);
      }

      // Разряды не срезаются по дороге: 2.5 × 97.125 — это 242.8125, и
      // печатается оно целиком (дверь `wireMoney` ничего не округляет,
      // докстринг `wire_money.dart`).
      expect(line['price'], '97.125');
      expect(line['total'], '242.8125');
    });

    test('деньги числом с провода не принимаются вовсе — отказом', () {
      // `5.1` от `double` потеряло бы точность до того, как попало в разбор,
      // и принять его значило бы узаконить потерю.
      expect(
        () => refundLineFromWireJson(const {
          'id': '1',
          'productId': 3,
          'name': 'Молоко',
          'quantity': 2.5,
          'price': '100',
        }),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
        ),
      );
    });
  });

  // Круг правки 1: разбор был мягким и читал мусор нулём. Для двух команд
  // это прямо неверно — у `refund.addProduct` и `refund.setLine` **ноль сам
  // по себе законная команда «снять строку»**, так что испорченный кадр
  // превращался не в отказ, а в другую законную команду, и терминал узнал бы
  // об этом только по исчезнувшей строке.
  group('строгий разбор тел: мусор — отказ, а не другая команда', () {
    Matcher badRequest(String field) => throwsA(
      isA<WireRefusal>()
          .having((r) => r.code, 'code', 'bad_request')
          .having((r) => r.message, 'message', contains(field)),
    );

    test('количество числом — отказ, а не ноль («снять строку»)', () {
      expect(
        () => refundLineQuantityFromWireJson(const {
          'lineId': '17',
          'quantity': 5,
          'key': 'k',
          'baseVersion': 0,
        }),
        badRequest('quantity'),
      );
      expect(
        () => refundLineRequestFromWireJson(const {
          'productId': 3,
          'quantity': 5.0,
          'key': 'k',
          'baseVersion': 0,
        }),
        badRequest('quantity'),
      );
    });

    test('неразбираемая строка количества — тоже отказ', () {
      expect(
        () => refundLineRequestFromWireJson(const {
          'productId': 3,
          'quantity': 'два',
          'key': 'k',
          'baseVersion': 0,
        }),
        badRequest('quantity'),
      );
    });

    test('ноль строкой по-прежнему проходит — это законная команда', () {
      // Обратная половина: без неё правка вырождается в «не принимать ноль
      // никогда», а ноль — единственный способ снять строку.
      final request = refundLineQuantityFromWireJson(const {
        'lineId': '17',
        'quantity': '0',
        'key': 'k',
        'baseVersion': 0,
        'receiptNo': 12,
      });

      expect(request.quantity, Decimal.zero);
      expect(request.lineId, '17');
    });

    test('метка команды разбирается строго', () {
      // Пустой ключ и нулевая версия — законные значения, а не умолчание для
      // пропущенного поля: ноль и есть базовая версия свежего черновика.
      expect(
        () => refundCommandMetaFromWireJson(const {'baseVersion': 0}),
        badRequest('key'),
      );
      expect(
        () => refundCommandMetaFromWireJson(const {'key': 'k'}),
        badRequest('baseVersion'),
      );
      expect(
        () =>
            refundCommandMetaFromWireJson(const {'key': 'k', 'baseVersion': 0}),
        returnsNormally,
        reason: 'номер черновика необязателен — null там утверждение',
      );
      expect(
        () => refundCommandMetaFromWireJson(const {
          'key': 'k',
          'baseVersion': 0,
          'receiptNo': 'двенадцать',
        }),
        badRequest('receiptNo'),
        reason: 'пропуск и мусор под ключом — разные вещи',
      );
    });

    test('штрихкод строки — тем же правилом, что и всё остальное', () {
      // Круг правки 2: он оставался на сыром `as String?`, и число под ним
      // доезжало именем типа, а не названным отказом — ровно тот механизм,
      // взамен которого весь строгий разбор и делался.
      Map<String, Object?> lineWith(Object? barcode) => {
        'id': '1',
        'productId': 3,
        'name': 'Молоко',
        'quantity': '1',
        'price': '100',
        'barcode': barcode,
      };

      expect(
        () => refundLineFromWireJson(lineWith(4870001)),
        badRequest('barcode'),
      );
      expect(refundLineFromWireJson(lineWith(null)).barcode, isNull);
      expect(refundLineFromWireJson(lineWith('4870001')).barcode, '4870001');
    });

    test('пропуск — значение, мусор — отказ: одно правило на весь файл', () {
      // Круг правки 2: до него `maxQuantity` читался через `containsKey`, и
      // явный `'maxQuantity': null` был отказом, тогда как явный
      // `'receiptNo': null` рядом — значением. Одно правило, два прочтения.
      Map<String, Object?> lineWith(Object? maxQuantity) => {
        'id': '1',
        'productId': 3,
        'name': 'Молоко',
        'quantity': '1',
        'price': '100',
        'maxQuantity': maxQuantity,
      };

      expect(refundLineFromWireJson(lineWith(null)).maxQuantity, isNull);
      expect(
        refundLineFromWireJson(lineWith('4')).maxQuantity,
        Decimal.parse('4'),
      );
      expect(
        () => refundLineFromWireJson(lineWith(4)),
        badRequest('maxQuantity'),
      );

      // И та же пара на необязательном целом — чтобы правило читалось как
      // общее, а не как совпадение у одного поля.
      expect(
        refundCommandMetaFromWireJson(const {
          'key': 'k',
          'baseVersion': 0,
          'receiptNo': null,
        }).receiptNo,
        isNull,
      );
    });

    test('список строк — тоже строго, и пустота не подменяет мусор', () {
      // Круг правки 3: последние сырые приведения файла. Не-список глотался
      // пустотой, а снимок без строк — законный снимок, значит испорченный
      // кадр читался бы как «черновик пуст». Не-объект внутри ронял
      // `TypeError` с именем типа.
      Map<String, Object?> viewWith(Object? lines) => {
        'posId': 1,
        'terminalId': 7,
        'version': 0,
        'lines': lines,
      };

      expect(
        () => refundViewFromWireJson(viewWith('нет')),
        badRequest('lines'),
      );
      expect(() => refundViewFromWireJson(viewWith(null)), badRequest('lines'));
      expect(
        () => refundViewFromWireJson(viewWith(const [1, 2])),
        badRequest('lines'),
      );
      expect(refundViewFromWireJson(viewWith(const [])).lines, isEmpty);
    });

    test('кадр без номера чека отказывает на границе, а не «чеком №0»', () {
      // До правки умолчание в ноль отправляло в контракт «чек №0», и он
      // отказывался там чужим кодом `receipt_not_found` — причина называлась
      // не та, что была на самом деле.
      expect(
        () => receiptKeyFromWireJson(const {
          'salePosId': 1,
          'key': 'k',
          'baseVersion': 0,
        }),
        badRequest('saleReceiptNo'),
      );
    });
  });

  group('исход', () {
    test('разбирается той же парой — объект целиком', () {
      final outcome = RefundOutcome(
        refundLocalId: 9,
        amount: Decimal.parse('390.5'),
        lineCount: 2,
        paymentCount: 3,
        saleReceiptNo: 501,
        salePosId: 1,
      );

      expect(
        refundOutcomeFromWireJson(refundOutcomeToWireJson(outcome)),
        outcome,
      );
    });

    test('возврат без чека — оба номера пусты, но исход полон', () {
      final outcome = RefundOutcome(
        refundLocalId: 9,
        amount: Decimal.parse('100'),
        lineCount: 1,
        paymentCount: 1,
      );

      final decoded = refundOutcomeFromWireJson(
        refundOutcomeToWireJson(outcome),
      );

      expect(decoded, outcome);
      expect(decoded.saleReceiptNo, isNull);
    });
  });
}
