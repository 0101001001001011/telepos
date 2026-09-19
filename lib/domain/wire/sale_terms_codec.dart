/// Кодек условий правки строки (`SaleEditTerms`) — ответ операции
/// `sale.editTerms`.
///
/// Проценты предела — десятичные, как и деньги: строкой через [wireMoney] и
/// обратно `Decimal.parse` (I159). `double` здесь дал бы предел «14.999999»
/// ровно там, где касса откажет на «15.000001».
library;

import 'package:decimal/decimal.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/wire/wire_money.dart';

Map<String, Object?> saleEditTermsToWireJson(SaleEditTerms terms) => {
  'editPrice': terms.policy.editPrice,
  'sellInDiscount': terms.policy.sellInDiscount,
  'maxPercent': wireMoney(terms.cap.maxPercent),
  // Порог подтверждения старшего есть не у всякой роли. Отсутствие ключа —
  // «не требуется»; форма `if … case` — та же, что у `stock` в
  // `cart_codec.dart`: значение, если оно есть, проходит **только** дверью
  // `wireMoney(...)` (сторож `money_over_wire_test.dart` не принимает
  // условного выражения вокруг двери).
  if (terms.cap.approvalAbove case final approvalAbove?)
    'approvalAbove': wireMoney(approvalAbove),
  'capSource': terms.cap.source,
  'currencySymbol': terms.currencySymbol,
};

/// Разбор строгий: кадр без поля — не «умолчание», а чужая форма ответа, и
/// придуманный предел здесь был бы обещанием, которого касса не давала.
SaleEditTerms saleEditTermsFromWireJson(Map<String, Object?> json) {
  final approvalAbove = json['approvalAbove'];
  return SaleEditTerms(
    policy: SalePolicy(
      editPrice: json['editPrice']! as bool,
      sellInDiscount: json['sellInDiscount']! as bool,
    ),
    cap: DiscountCap(
      maxPercent: Decimal.parse(json['maxPercent']! as String),
      approvalAbove: approvalAbove == null
          ? null
          : Decimal.parse(approvalAbove as String),
      source: json['capSource']! as String,
    ),
    currencySymbol: json['currencySymbol']! as String,
  );
}
