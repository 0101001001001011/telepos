/// Выдачу аванса и повтор печати слипа с планшета можно **дойти и нажать** —
/// решение заказчика 2026-09-18.
///
/// # Почему одной пробы провода мало
///
/// `test/backend/prepayment_refund_permissions_test.dart` доказывает, что
/// `pay.prepaymentRefund` работает и что право её охраняет **достижимо**.
/// Она не доказывает, что кассир может ею воспользоваться: операция
/// `pay.certificateIssue` прожила полтора месяца написанной, охраняемой и не
/// вызываемой ниоткуда, и набор всё это время был зелёным.
///
/// Здесь по исходникам сверяются звенья цепочки, каждое из которых рвётся
/// молча:
///
/// 1. **точка входа привязывает порт** — без строки экран не найдёт
///    реализацию в контейнере и упадёт резолвом `GetIt` на первом нажатии;
/// 2. **экран зовёт порт**, а не соседний: приём и выдача — разные
///    контракты, и вызвать приём на кнопке «Выдать» значило бы принять
///    деньги там, где их просили отдать;
/// 3. **направление переключается**, то есть кнопка вообще существует.
///
/// # Чего эта проба НЕ доказывает
///
/// - **Что выдача с планшета действительно снимает деньги со счёта.** Это
///   доказывают пробы операции; здесь сверяются только звенья достижимости,
///   и ни одно из них не исполняется.
/// - **Что ключ повтора обнуляется при смене направления.** Это доказывает
///   `prepayment_intake_screen_test.dart` — поведением, а не текстом.
@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _entry = 'lib/web/main_web.dart';
const _screen =
    'lib/presentation/screens/prepayment/prepayment_intake_screen.dart';
const _certScreen =
    'lib/presentation/screens/certificate/certificate_issue_screen.dart';

/// Комментарии не считаются: ссылка в докстринге ничего не привязывает и
/// никуда не ведёт. Ровно на этом сторожа исходника и слепнут.
String _code(String path) {
  final file = File(path);
  if (!file.existsSync()) fail('сторож смотрит в несуществующий файл $path');
  return file
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
}

void main() {
  test('точка входа браузера привязывает выдачу аванса', () {
    final source = _code(_entry);
    expect(
      source,
      contains('registerLazySingleton<PrepaymentRefundService>'),
      reason:
          'Без этой строки экран выдачи падает резолвом `GetIt` на первом '
          'нажатии, а операция `pay.prepaymentRefund` остаётся мёртвым '
          'кодом — ровно тем, каким полтора месяца был `pay.certificateIssue`.',
    );
    expect(
      source,
      contains('WtPrepaymentRefundService('),
      reason:
          'выдача обязана быть проводной: `CustomerPaymentUseCase` в браузере '
          'не компилируется вовсе (drift, фискальный узел), а любая третья '
          'реализация здесь — второй путь к деньгам кассы',
    );
  });

  test('точка входа браузера привязывает повтор печати слипа', () {
    final source = _code(_entry);
    expect(
      source,
      contains('registerLazySingleton<CertificateSlipReprinter>'),
      reason:
          'до 2026-09-18 экран выпуска в браузере говорил «слип напечатать '
          'нечем» и был прав: порта не стояло. Без этой строки он снова прав.',
    );
    expect(source, contains('WtCertificateSlipReprinter('));
  });

  test('экран приёма зовёт выдачу своим контрактом, а не приёмом', () {
    final source = _code(_screen);
    expect(
      source,
      contains('GetIt.I<PrepaymentRefundService>()'),
      reason: 'порт выдачи не резолвится — кнопка «Выдать» не работает',
    );
    expect(
      source,
      contains('payOutPrepayment('),
      reason:
          'кнопка «Выдать» обязана звать выдачу: вызов `acceptPrepayment` на '
          'ней принял бы деньги там, где их просили отдать',
    );
    // Страховка от вырождения: приём обязан остаться на месте. Экран, в
    // котором выдача заменила приём, прошёл бы обе проверки выше.
    expect(source, contains('acceptPrepayment('));
  });

  test('на экране есть чем переключить направление', () {
    final source = _code(_screen);
    expect(
      source,
      contains("ValueKey('prepayment-direction')"),
      reason:
          'без переключателя выдача недостижима так же, как была бы '
          'недостижима без маршрута: код есть, нажать нечем',
    );
  });

  test('экран выпуска печатает слип через порт, а не двумя шагами сам', () {
    final source = _code(_certScreen);
    expect(
      source,
      contains('GetIt.I<CertificateSlipReprinter>()'),
      reason:
          'связка «найти бумажку + напечатать слип» обязана жить за портом: '
          'во вкладке второй такой связки быть не может — она печатала бы '
          'обязательство магазина по своим полям',
    );
    expect(
      source,
      isNot(contains('GetIt.I<CertificateSlipPrinter>()')),
      reason:
          'прямой вызов порта печати из экрана — это и есть та связка, '
          'которую вкладка повторить не может',
    );
  });
}
