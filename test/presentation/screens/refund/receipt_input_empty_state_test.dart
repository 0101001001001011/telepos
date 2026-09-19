/// Диалог ввода чека различает «чеков нет» и «спросить кассу нечем».
///
/// # Что здесь на самом деле проверяется
///
/// Не текст. Проверяется, что **пустой список не превращается в утверждение
/// о данных магазина**. До живой приёмки задачи 21 (2026-09-07) диалог знал
/// одну пустоту: `RecentReceipts` в браузере не зарегистрирован
/// (`main_web.dart` — снято намеренно, своей операции провода нет), список
/// приезжал пустым, и на экран печаталось «Чеков пока нет».
///
/// Кассир с бумажным чеком на руках читает это как «продажа не записалась»
/// и делает неверное следующее действие: возврат **без** чека вместо
/// возврата по чеку, или эскалацию несуществующей потери. Скрытая кнопка
/// учит «здесь этого нет»; ложный пустой список учит «твои данные пропали»
/// — и это хуже.
///
/// Поэтому обе пробы ниже парные: одна утверждает, что честная строка
/// появилась, вторая — что **прежняя при этом не появилась**. Без второй
/// починка «показывать обе строки разом» прошла бы зелёной, оставив ложное
/// утверждение на экране.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/refund/widgets/receipt_input_dialog.dart';

void main() {
  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required bool recentAvailable,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        // Диалог тянет семантические цвета темы приложения — без неё
        // `NumPad` внутри него падает на пустом расширении темы.
        theme: AppTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru'), Locale('en')],
        locale: const Locale('ru'),
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: ReceiptInputDialog(recentAvailable: recentAvailable),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('спросить нечем — диалог говорит именно это', (tester) async {
    final l10n = await pump(tester, recentAvailable: false);

    expect(
      find.text(l10n.receiptInputRecentUnavailable),
      findsOneWidget,
      reason:
          'терминал не умеет спросить кассу о последних чеках — это надо '
          'сказать, а не выдать за отсутствие чеков у магазина',
    );
    expect(
      find.text(l10n.receiptInputNoRecent),
      findsNothing,
      reason:
          'утверждение «чеков пока нет» здесь ложное: сколько их у магазина, '
          'этот терминал не знает и знать не может',
    );
  });

  testWidgets('спросить есть чем, а чеков нет — прежняя строка', (
    tester,
  ) async {
    final l10n = await pump(tester, recentAvailable: true);

    expect(
      find.text(l10n.receiptInputNoRecent),
      findsOneWidget,
      reason:
          'касса ответила пустым списком — вот это и есть честное «чеков '
          'пока нет», и оно обязано остаться',
    );
    expect(find.text(l10n.receiptInputRecentUnavailable), findsNothing);
  });

  test('две пустоты — разные строки во всех пяти локалях', () async {
    // Сторож против починки, которая завела бы второй ключ с тем же текстом:
    // на экране это было бы неотличимо, а значит не починкой.
    for (final locale in const [
      Locale('ru'),
      Locale('en'),
      Locale('kk'),
      Locale('ky'),
      Locale('uz'),
    ]) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(
        l10n.receiptInputRecentUnavailable,
        isNot(l10n.receiptInputNoRecent),
        reason: 'локаль ${locale.languageCode}',
      );
      expect(
        l10n.receiptInputRecentUnavailable.trim(),
        isNotEmpty,
        reason: 'локаль ${locale.languageCode} осталась без перевода',
      );
    }
  });
}
