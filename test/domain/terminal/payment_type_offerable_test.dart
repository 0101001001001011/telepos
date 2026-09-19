import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/terminal/terminal.dart';

/// Что экрану **позволено предлагать** на рабочем месте с данным набором.
///
/// Отдельная от `Terminal.allows` функция и отдельная проба, потому что
/// вопросы разные. `allows` отвечает на вопрос кассы — «этот вид оплаты
/// разрешён?», и `mixed` для неё вид как вид. Экран же спрашивает другое:
/// «имеет ли смысл показывать кассиру эту кнопку», а смешанная кассой
/// проверяется **половинами** (`LocalPaymentService._plan` зовёт
/// `_requireAllowedTypes` с наличной и безналичной частями по отдельности),
/// и потому предлагать её честно можно ровно там, где разрешены обе.
///
/// Экран остаётся удобством: запрет держит касса (I162), и ни одна строка
/// здесь его не заменяет.
void main() {
  group('paymentTypeOfferable', () {
    test('пустой набор означает «все» — предлагается каждый вид', () {
      for (final type in PaymentType.values) {
        expect(
          paymentTypeOfferable(const {}, type),
          isTrue,
          reason: 'пустой набор обязан предлагать ${type.name}',
        );
      }
    });

    test('{card}: наличные не предлагаются, карта предлагается', () {
      expect(
        paymentTypeOfferable(const {PaymentType.card}, PaymentType.cash),
        isFalse,
      );
      expect(
        paymentTypeOfferable(const {PaymentType.card}, PaymentType.card),
        isTrue,
      );
    });

    test('{cash}: карта не предлагается', () {
      expect(
        paymentTypeOfferable(const {PaymentType.cash}, PaymentType.card),
        isFalse,
      );
      expect(
        paymentTypeOfferable(const {PaymentType.cash}, PaymentType.cash),
        isTrue,
      );
    });

    test('смешанная требует обе половины, а не одну', () {
      expect(
        paymentTypeOfferable(const {PaymentType.card}, PaymentType.mixed),
        isFalse,
        reason: 'наличную половину смешанной касса отвергнет',
      );
      expect(
        paymentTypeOfferable(const {PaymentType.cash}, PaymentType.mixed),
        isFalse,
        reason: 'безналичную половину смешанной касса отвергнет',
      );
      expect(
        paymentTypeOfferable(
          const {PaymentType.cash, PaymentType.card},
          PaymentType.mixed,
        ),
        isTrue,
      );
    });

    test('долг набором видов не сторожится — его сторожит право', () {
      // `tenderPaymentTypes` долга не содержит намеренно (докстринг там же):
      // `op.sellDebt` уже загораживает его, и второй механизм поверх первого
      // молча сузил бы то, чего никто не сужал. Экран обязан вести себя так
      // же, как касса, а касса долг по набору не проверяет вовсе.
      expect(
        paymentTypeOfferable(const {PaymentType.card}, PaymentType.debt),
        isTrue,
      );
    });
  });
}
