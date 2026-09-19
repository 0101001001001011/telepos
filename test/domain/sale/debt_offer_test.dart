import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/sale/debt_offer.dart';

/// Тройное условие кнопки «В долг» — задача 16.
///
/// Проба брифа в его настоящем виде: **таблица**, а не четыре теста, —
/// потому что утверждение здесь одно и оно про совпадение всех условий
/// сразу. Отдельные тесты на каждую строку прошли бы и в мире, где две
/// проверки перепутаны местами.
void main() {
  group('«В долг» предлагается тогда и только тогда, когда сошлись все', () {
    test('перебор всех сочетаний тумблера кассы и права кассира', () {
      const cases = <({bool? sellInDebt, bool permitted, DebtOffer expected})>[
        // Сошлось всё — и только здесь.
        (sellInDebt: true, permitted: true, expected: DebtOffer.available),
        // Право есть, кредита на кассе нет.
        (sellInDebt: false, permitted: true, expected: DebtOffer.notSoldHere),
        // Кредит есть, права нет.
        (sellInDebt: true, permitted: false, expected: DebtOffer.notPermitted),
        // Нет ни того, ни другого: **место отвечает раньше человека**.
        // «У вас нет права» на кассе без кредита — неправда, и кассир
        // пошёл бы добиваться права, которое ничего не изменит.
        (sellInDebt: false, permitted: false, expected: DebtOffer.notSoldHere),
        // Ответа кассы ещё нет — это не «нельзя», это «не знаем».
        (sellInDebt: null, permitted: true, expected: DebtOffer.unknown),
        (sellInDebt: null, permitted: false, expected: DebtOffer.unknown),
      ];

      for (final c in cases) {
        expect(
          debtOfferOf(sellInDebt: c.sellInDebt, permitted: c.permitted),
          c.expected,
          reason: '$c',
        );
      }
    });

    test('доступен ровно один случай из шести', () {
      // Страховка от вырождения: функция, отвечающая `available` всегда,
      // прошла бы первую пробу только по одной строке — а эта краснеет
      // на любом расширении разрешённого.
      var available = 0;
      for (final sell in <bool?>[null, false, true]) {
        for (final permitted in [false, true]) {
          if (debtOfferOf(sellInDebt: sell, permitted: permitted) ==
              DebtOffer.available) {
            available++;
          }
        }
      }
      expect(available, 1);
    });
  });

  group('причина называется своя, а не «нельзя»', () {
    test('три причины отказа различимы между собой', () {
      // Один код на три беды отправил бы кассира не туда: тумблер
      // меняется в настройках кассы, право — у администратора, а
      // молчание кассы не лечится ни тем, ни другим.
      final reasons = {
        debtOfferOf(sellInDebt: false, permitted: true),
        debtOfferOf(sellInDebt: true, permitted: false),
        debtOfferOf(sellInDebt: null, permitted: true),
      };
      expect(reasons, hasLength(3));
      expect(reasons, isNot(contains(DebtOffer.available)));
    });
  });
}
