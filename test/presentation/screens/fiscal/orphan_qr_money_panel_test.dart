library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/fiscal/unfiscalized_receipts_screen.dart';

/// **Деньги без чека видны на экране разбора** — задача 22, шаг 3.
///
/// # Главное, что здесь проверяется, и почему это не косметика
///
/// Что панель видна **при пустой очереди фискализации**. Это не мелочь
/// расположения виджета, а весь смысл: очередь и намерения — два разных
/// источника одной беды, и самый обычный случай — фискализация в порядке,
/// а деньги QR повисли. Панель, живущая внутри ветки `data` списка, стала
/// бы невидимой ровно тогда, когда она нужнее всего.
///
/// # Почему настоящая база, а не подделка провайдера
///
/// Панель читает `AppDatabase.paymentIntentDao.orphanMoney()`, то есть
/// **запрос по двум полям** (`status = paid` И `settled_at IS NULL`).
/// Подделка над панелью проверяла бы панель; настоящая база проверяет
/// запрос, а запрос здесь и есть утверждение — «оплачено, а чека нет».
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<FiscalQueueStore>(InMemoryFiscalQueueStore());
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  Widget host() => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      locale: const Locale('ru'),
      home: const UnfiscalizedReceiptsScreen(),
    ),
  );

  Future<int> intent({
    required String key,
    required String amount,
    String? paid,
    QrIntentStatus status = QrIntentStatus.paid,
    bool abandoned = false,
    bool settled = false,
  }) async {
    final (row, _) = await db.paymentIntentDao.claim(
      intentKey: key,
      providerCode: 'sbp_emul',
      amount: Decimal.parse(amount),
      createdAt: DateTime.now(),
    );
    await db.paymentIntentDao.applyState(
      id: row.id,
      status: status,
      paidAmount: Decimal.parse(paid ?? amount),
      confirmedAt: DateTime.now(),
      countConfirmation: status == QrIntentStatus.paid,
    );
    if (abandoned) {
      await db.paymentIntentDao.markAbandoned(row.id, DateTime.now());
    }
    if (settled) {
      await db.paymentIntentDao.markSettled(
        id: row.id,
        receiptNo: 42,
        at: DateTime.now(),
      );
    }
    return row.id;
  }

  testWidgets('пустая очередь НЕ прячет деньги без чека', (tester) async {
    await intent(key: 'q-visible', amount: '1500');

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.text('Деньги без чека'),
      findsOneWidget,
      reason:
          'очередь фискализации пуста, и это самый обычный случай: панель, '
          'спрятанная за списком, была бы невидима именно тогда, когда '
          'нужна',
    );
    expect(find.textContaining('q-visible'), findsOneWidget);
    expect(
      find.textContaining('1500'),
      findsOneWidget,
      reason: 'сумма названа числом, а не «есть неразобранные»',
    );
    expect(
      find.textContaining('sbp_emul'),
      findsOneWidget,
      reason: 'провайдер назван: разбирать придётся у него',
    );
  });

  testWidgets('разобранное намерение с экрана уходит', (tester) async {
    await intent(key: 'q-done', amount: '900', settled: true);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.text('Деньги без чека'),
      findsNothing,
      reason:
          'деньги в чеке — разбирать нечего. Панель, показывающая всё '
          'оплаченное, была бы зелена и когда всё давно закрыто',
    );
  });

  testWidgets('неоплаченное намерение здесь не показывается', (tester) async {
    await intent(
      key: 'q-pending',
      amount: '900',
      status: QrIntentStatus.pending,
    );

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.text('Деньги без чека'),
      findsNothing,
      reason: 'денег ещё нет — и разбирать нечего',
    );
  });

  testWidgets('оплата после сдачи названа словами, а не выведена', (
    tester,
  ) async {
    await intent(key: 'q-late', amount: '700', abandoned: true);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('после того, как касса перестала ждать'),
      findsOneWidget,
      reason:
          'это ДРУГАЯ беда, чем «чек не закрыли»: покупатель уже ушёл, и '
          'кассир обязан прочитать это, а не догадаться по времени',
    );
  });

  testWidgets('несобранная касса НЕ выглядит как разобранная', (tester) async {
    // База не зарегистрирована. Первая редакция отвечала здесь пустым
    // списком, и экран говорил ровно то же, что при полном порядке, —
    // ничего. Правдоподобное значение, возвращённое молча: деньги
    // покупателя исчезли бы с экрана без единого слова.
    await GetIt.I.reset();
    GetIt.I.registerSingleton<FiscalQueueStore>(InMemoryFiscalQueueStore());
    addTearDown(() {
      GetIt.I.allowReassignment = true;
      GetIt.I.registerSingleton<AppDatabase>(db);
    });

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('база кассы не зарегистрирована'),
      findsOneWidget,
      reason:
          '«спросить не удалось» — не то же самое, что «разбирать нечего», '
          'и молчание здесь было бы вторым способом потерять деньги',
    );
  });

  testWidgets('частичная оплата показывает оба числа', (tester) async {
    await intent(key: 'q-part', amount: '1000', paid: '400');

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('400'),
      findsWidgets,
      reason: 'сколько пришло',
    );
    expect(
      find.textContaining('1000'),
      findsWidgets,
      reason:
          'и сколько просили: одно число без другого не даёт разобрать '
          'недостачу',
    );
  });
}
