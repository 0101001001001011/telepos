/// Два предиката экрана оплаты, и они **про разное**.
///
/// # Ловушка, записанная здесь до задачи 14, и как она сработала
///
/// Этот файл живёт с корневого коммита, и в нём стояла проба с именем
/// «`isProcessing=true` ОБНУЛЯЕТ `canComplete` (ловушка premature-lock)» и
/// доводом «именно поэтому `_handleComplete` **не должен** ставить
/// `setProcessing(true)` до `processPayment`». То есть ловушка была
/// **описана в дереве заранее**.
///
/// Круг правки 5 задачи 14 сделал ровно то, что здесь запрещалось — поставил
/// признак обработки первой строкой обработчика нажатия, ради защиты от
/// двойного нажатия, — и **эта проба осталась зелёной**: она проверяла
/// геттер, а не связку геттера с вызывающим. Десктопная касса перестала
/// проводить оплату вовсе, и нашли это сквозные сценарии соседней задачи, а
/// не сторож, написанный ровно про этот случай.
///
/// **Урок, ради которого файл переписан, а не подправлен:** запрет,
/// сформулированный в `reason:`, не сторожит ничего — он живёт в тексте,
/// который никто не исполняет. Сторожить можно только утверждение о коде.
///
/// # Что теперь правда
///
/// Признак обработки ставится **первой строкой** `_handleComplete`, и это
/// намеренно: без него кнопка живёт весь обмен с платёжным терминалом, и
/// два нажатия дают два настоящих списания. Запрет снят не потому, что
/// ловушка выдумана, а потому, что убрана её причина: два условия разведены
/// по смыслу.
///
/// - [PaymentState.amountCovered] — **деньги сходятся**. Свойство операции;
///   его и спрашивает `PaymentNotifier.processPayment` на входе.
/// - [PaymentState.canComplete] — **кнопку можно нажать**: деньги сходятся
///   **и** оплата ещё не идёт. Свойство экрана; его читает виджет кнопки.
///
/// Смешение этих двух и было дефектом: операция спрашивала экранный
/// предикат, то есть отбивала собственное первое нажатие.
///
/// Связку с настоящим вызывающим этот файл по-прежнему не проверяет и не
/// может: он про чистые предикаты. Её проверяет
/// `payment_complete_button_test.dart` — настоящий экран, настоящий
/// контроллер, нажатие через `_handleComplete`.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

void main() {
  PaymentState cashReady() => PaymentState(
    totalAmount: Decimal.parse('1000'),
    paymentType: PaymentType.cash,
    cashReceived: Decimal.parse('1000'),
  );

  test('валидная наличная оплата готова к завершению', () {
    expect(cashReady().canComplete, isTrue);
    expect(cashReady().amountCovered, isTrue);
  });

  test('идущая оплата гасит кнопку и НЕ трогает достаточность денег', () {
    // Прежде здесь стоял запрет «`_handleComplete` не должен ставить
    // `setProcessing(true)` до `processPayment`» — и он не сторожил
    // ничего: круг правки 5 сделал именно это, а проба осталась зелёной.
    //
    // Утверждение, которое сторожит: признак обработки принадлежит
    // **кнопке** и не имеет права трогать ответ на вопрос «денег
    // хватает». Слипнутся обратно — операция снова начнёт отбивать
    // собственное первое нажатие.
    final busy = cashReady().copyWith(isProcessing: true);

    expect(busy.canComplete, isFalse, reason: 'кнопка обязана погаснуть');
    expect(
      busy.amountCovered,
      isTrue,
      reason:
          'достаточность денег не зависит от того, идёт ли оплата: на этом '
          'предикате операция решает, входить ли ей в работу',
    );
  });

  test('карта: кнопка гаснет, достаточность остаётся', () {
    final card = PaymentState(
      totalAmount: Decimal.parse('500'),
      paymentType: PaymentType.card,
    );
    expect(card.canComplete, isTrue);
    expect(card.copyWith(isProcessing: true).canComplete, isFalse);
    expect(card.copyWith(isProcessing: true).amountCovered, isTrue);
  });

  test('недобор наличных не даёт завершить — обоим предикатам', () {
    // Страховка от вырождения: разведены **условия**, а не отменено одно
    // из них. Недобор обязан гасить и кнопку, и вход в операцию.
    final short = PaymentState(
      totalAmount: Decimal.parse('1000'),
      paymentType: PaymentType.cash,
      cashReceived: Decimal.parse('900'),
    );
    expect(short.canComplete, isFalse);
    expect(short.amountCovered, isFalse);
  });

  group('смешанная оплата — единственная ветка с арифметикой', () {
    // **Она была не покрыта ничем.** `amountCovered` встречался в наборе
    // только здесь и только для `cash`, `card` и `debt`: подмена
    // `case PaymentType.mixed: return true;` оставляла зелёными и
    // `test/presentation/` (631), и `test/integration/` вместе с
    // `test/domain/usecases/payment/` (167).
    //
    // Денег это не теряет — касса отбивает своим отказом по
    // недостаточности, — но первый эшелон молчал, а последствие ложится
    // ровно в тот сценарий, который чинил круг правки 4: карта проведена,
    // касса отказала, проведение осталось непогашенным.
    PaymentState mixed({
      required String cash,
      required String card,
      String total = '1000',
      String bonus = '0',
    }) => PaymentState(
      totalAmount: Decimal.parse(total),
      paymentType: PaymentType.mixed,
      cashReceived: Decimal.parse(cash),
      cardAmount: Decimal.parse(card),
      bonusToUse: Decimal.parse(bonus),
    );

    test('наличные и карта вместе покрывают чек', () {
      expect(mixed(cash: '600', card: '400').amountCovered, isTrue);
    });

    test('ровно сумма чека — покрывает', () {
      // Правило нуля: граница включается. Иначе «больше» и «ровно»
      // отвергались бы вместе, и кассир, набравший точную сумму, упирался
      // бы в погашенную кнопку.
      expect(mixed(cash: '1000', card: '0').amountCovered, isTrue);
      expect(mixed(cash: '0', card: '1000').amountCovered, isTrue);
      expect(mixed(cash: '999.999', card: '0.001').amountCovered, isTrue);
    });

    test('на одну тысячную меньше — не покрывает', () {
      // Страховка от вырождения: ветка отвечает **не** «всегда да».
      expect(mixed(cash: '600', card: '399.999').amountCovered, isFalse);
      expect(mixed(cash: '0', card: '0').amountCovered, isFalse);
    });

    test('бонус уменьшает то, что надо покрыть', () {
      // `amountToPay = totalAmount - bonusToUse`, и потолок бонуса ставит
      // касса. Здесь проверяется, что ветка считает **от суммы к оплате**,
      // а не от итога чека.
      expect(
        mixed(cash: '400', card: '200', bonus: '400').amountCovered,
        isTrue,
      );
      expect(
        mixed(cash: '400', card: '100', bonus: '400').amountCovered,
        isFalse,
      );
    });

    test('идущая оплата гасит кнопку, достаточность не трогает', () {
      // То же разделение труда, что и у прочих веток: признак обработки
      // принадлежит кнопке.
      final busy = mixed(cash: '600', card: '400').copyWith(isProcessing: true);
      expect(busy.canComplete, isFalse);
      expect(busy.amountCovered, isTrue);
    });
  });

  test('долг доступен всегда — остаток и есть смысл операции', () {
    // Право на продажу в долг проверяет касса до вызова обработчика
    // (I44, I162), а не спрятанная кнопка.
    final debt = PaymentState(
      totalAmount: Decimal.parse('1000'),
      paymentType: PaymentType.debt,
    );
    expect(debt.amountCovered, isTrue);
    expect(debt.canComplete, isTrue);
  });
}
