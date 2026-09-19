/// Каталог операций возврата — задача 19 плана «Продажа с браузерного
/// терминала».
///
/// Здесь проверяется то, ради чего задача существует: **два ключа `op.*`
/// впервые получили читателя**, и возврат без чека проверяется своим ключом,
/// а не общим. Раскладка прав закреплена закрытой таблицей поимённо, а не
/// счётом: операция, унаследовавшая право соседки копипастой, обязана красить
/// свою строку, а не проходить по числу.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/refund_codec.dart';
import 'package:telepos/domain/wire/refund_ops.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_op.dart';

const _meta = CartCommandMeta(key: 'k1', baseVersion: 4, receiptNo: 12);

void main() {
  group('права — то, ради чего задача существует', () {
    test('раскладка прав закрыта поимённо', () {
      // Закрытая таблица, а не счёт. `startWithoutReceipt` стоит под своим
      // ключом; остальные пять — под `op.refund`.
      const expected = <String, String>{
        'refund.view': PermissionKeys.opRefund,
        'refund.loadReceipt': PermissionKeys.opRefund,
        'refund.startWithoutReceipt': PermissionKeys.opRefundWithoutReceipt,
        'refund.addProduct': PermissionKeys.opRefund,
        'refund.setLine': PermissionKeys.opRefund,
        'refund.complete': PermissionKeys.opRefund,
        'refund.troubles': PermissionKeys.opRefund,
      };

      final actual = {
        for (final op in RefundOps.all)
          op.name: (op.access as SessionAccess).needs,
      };

      expect(actual, expected);
    });

    test('возврат без чека — единственный читатель op.refundWithoutReceipt во '
        'всём каталоге провода', () {
      // Свести его с `loadReceipt` в одну команду значило бы, что это
      // право проверить **нечем**: сторож смотрит на имя операции, а не на
      // содержимое тела. Проверяется по всему `TillOps.all`, а не по
      // `RefundOps.all`: соседняя ветвь, приписавшая этот ключ своей
      // операции, обязана краснеть здесь.
      final readers = TillOps.all
          .where(
            (op) =>
                op.access is SessionAccess &&
                (op.access as SessionAccess).needs ==
                    PermissionKeys.opRefundWithoutReceipt,
          )
          .map((op) => op.name)
          .toSet();

      expect(readers, {'refund.startWithoutReceipt'});
    });

    test('ни одна операция возврата не открыта и не требует чужого права', () {
      for (final op in RefundOps.all) {
        final access = op.access;
        expect(
          access,
          isA<SessionAccess>(),
          reason: '${op.name} обязана требовать сеанса',
        );
        expect(
          (access as SessionAccess).needs,
          anyOf(PermissionKeys.opRefund, PermissionKeys.opRefundWithoutReceipt),
          reason:
              '${op.name}: возврат — операция с деньгами, право у неё своё, '
              'а не унаследованное от соседней подсистемы',
        );
      }
    });
  });

  group('каталог', () {
    test('семь операций, и это именно они', () {
      // Шесть, а не пять из наброска: `refund.setLine` завёл круг правки 1
      // задачи 18 — без неё выделение строк не доезжает до кассы вовсе,
      // потому что `addProduct` в возврате по чеку отказывает всегда.
      expect(RefundOps.all.map((op) => op.name).toList(), [
        'refund.view',
        'refund.loadReceipt',
        'refund.startWithoutReceipt',
        'refund.addProduct',
        'refund.setLine',
        'refund.complete',
        // Седьмая — приёмка 2026-09-17: беда ящика после возврата с
        // наличной частью обязана доехать до кассира браузерного терминала.
        'refund.troubles',
      ]);
    });

    test(
      'каждая объявленная операция входит в RefundOps.all и в TillOps.all',
      () {
        // Иначе сторож провода (`wire_guard.dart`) видел бы часть операций, а
        // проверки уникальности имени и рода доказывали бы что-то только про
        // подмножество. `declared` — шесть явных констант, а не производная от
        // самого списка: тавтологии здесь нет.
        const declared = <WireOp<Object?, Object?>>[
          RefundOps.view,
          RefundOps.loadReceipt,
          RefundOps.startWithoutReceipt,
          RefundOps.addProduct,
          RefundOps.setLine,
          RefundOps.complete,
          RefundOps.troubles,
        ];

        expect(RefundOps.all.toSet(), declared.toSet());
        expect(TillOps.all.toSet(), containsAll(declared));
      },
    );

    test('черновик — подписка, остальные шесть — вопросы', () {
      // Касса говорит первой: черновик живёт на ней, и экран обязан увидеть
      // его изменение в момент изменения, а не при следующем вопросе.
      expect(RefundOps.view, isA<Watch>());
      expect(RefundOps.all.whereType<Watch>().toSet(), {
        RefundOps.view,
      }, reason: 'подписка у возврата ровно одна');
      expect(RefundOps.all.whereType<Ask>(), hasLength(6));
    });

    test('имена возврата не сталкиваются ни с одним именем каталога', () {
      final names = TillOps.all.map((op) => op.name).toList();
      expect(names.toSet(), hasLength(names.length), reason: '$names');
    });
  });

  group('тела', () {
    test('ни одна из шести не кладёт terminalId в тело', () {
      // Контракт возврата требует ОТВЕРГАТЬ кадр, в котором имя рабочего
      // места названо: холодный вызов с чужим именем отдавал бы чужой
      // черновик. Значит и класть его сюда нельзя — иначе касса отказывала бы
      // каждой собственной команде.
      final bodies = <String, Map<String, Object?>>{
        RefundOps.view.name: RefundOps.view.encode(null),
        RefundOps.loadReceipt.name: RefundOps.loadReceipt.encode(
          const ReceiptKey(receiptNo: 501, posId: 7, meta: _meta),
        ),
        RefundOps.startWithoutReceipt.name: RefundOps.startWithoutReceipt
            .encode(_meta),
        RefundOps.addProduct.name: RefundOps.addProduct.encode(
          RefundLineRequest(productId: 3, quantity: Decimal.one, meta: _meta),
        ),
        RefundOps.setLine.name: RefundOps.setLine.encode(
          RefundLineQuantity(lineId: '17', quantity: Decimal.zero, meta: _meta),
        ),
        RefundOps.complete.name: RefundOps.complete.encode(_meta),
        RefundOps.troubles.name: RefundOps.troubles.encode(9),
      };

      for (final entry in bodies.entries) {
        expect(
          entry.value.containsKey('terminalId'),
          isFalse,
          reason:
              '${entry.key}: имя рабочего места в теле — то, что контракт '
              'требует ОТВЕРГАТЬ',
        );
      }
    });

    test('метка команды едет с каждой изменяющей командой', () {
      // Пять из шести меняют черновик, и у каждой обязаны быть ключ повтора,
      // версия и номер черновика — иначе повтор после обрыва удвоил бы
      // работу, а запоздавшая команда легла бы в чужой черновик.
      final bodies = <String, Map<String, Object?>>{
        RefundOps.loadReceipt.name: RefundOps.loadReceipt.encode(
          const ReceiptKey(receiptNo: 501, posId: 7, meta: _meta),
        ),
        RefundOps.startWithoutReceipt.name: RefundOps.startWithoutReceipt
            .encode(_meta),
        RefundOps.addProduct.name: RefundOps.addProduct.encode(
          RefundLineRequest(productId: 3, quantity: Decimal.one, meta: _meta),
        ),
        RefundOps.setLine.name: RefundOps.setLine.encode(
          RefundLineQuantity(lineId: '17', quantity: Decimal.zero, meta: _meta),
        ),
        RefundOps.complete.name: RefundOps.complete.encode(_meta),
      };

      for (final entry in bodies.entries) {
        expect(
          refundCommandMetaFromWireJson(entry.value),
          _meta,
          reason: entry.key,
        );
      }
    });

    test('подписка на черновик доводов не несёт — пустое тело', () {
      expect(RefundOps.view.encode(null), isEmpty);
    });
  });

  group('разбор ответа', () {
    test('снимок разбирается той же парой, что его и пишет', () {
      // `decode` операции зовёт готовую половину пары, а не пишет разбор
      // заново: иначе каталог стал бы вторым читателем формы.
      final view = RefundView(
        posId: 1,
        terminalId: 7,
        version: 3,
        draftNo: 12,
        saleReceiptNo: 501,
        salePosId: 1,
        lines: [
          RefundLine(
            id: '17',
            productId: 3,
            name: 'Молоко 3.2%',
            quantity: Decimal.parse('2.5'),
            price: Decimal.parse('97.125'),
            maxQuantity: Decimal.parse('4'),
            barcode: '4870001234567',
          ),
        ],
      );

      for (final op in <WireOp<Object?, RefundView>>[
        RefundOps.view,
        RefundOps.loadReceipt,
        RefundOps.startWithoutReceipt,
        RefundOps.addProduct,
        RefundOps.setLine,
      ]) {
        expect(op.decode(refundViewToWireJson(view)), view, reason: op.name);
      }
    });

    test('исход завершения разбирается той же парой', () {
      final outcome = RefundOutcome(
        refundLocalId: 9,
        amount: Decimal.parse('390.5'),
        lineCount: 2,
        paymentCount: 3,
        saleReceiptNo: 501,
        salePosId: 1,
      );

      expect(
        RefundOps.complete.decode(refundOutcomeToWireJson(outcome)),
        outcome,
      );
    });
  });
}
