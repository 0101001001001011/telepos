library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/fiscal/unfiscalized_receipts_screen.dart';

/// Экран нефискализованных чеков — задача 11.
///
/// # Что здесь доказывается
///
/// Три вещи, каждая — решение задачи, а не косметика:
///
/// 1. **Строка старого вида не предлагает повтора.** Повторять её нечем;
///    предложить кнопку значило бы обещать лечение, которого нет, и —
///    хуже — при чужом ключе получить второй документ на одну продажу.
/// 2. **Списание требует причины.** Кнопка подтверждения не включается,
///    пока поле пусто: безымянное и беспричинное списание неотличимо от
///    тихой чистки.
/// 3. **Списанная строка не исчезает** и не предлагает больше ничего.
///
/// Экран берёт очередь через `GetIt`, поэтому здесь стоит настоящий
/// `InMemoryFiscalQueueStore`, а не заглушка над экраном: список приходит
/// из того же чтения `failed()`, каким его читает касса.
void main() {
  late InMemoryFiscalQueueStore store;

  setUp(() {
    store = InMemoryFiscalQueueStore();
    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<FiscalQueueStore>(store);
  });

  tearDown(() => GetIt.I.reset());

  Widget host({Locale locale = const Locale('ru')}) => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      locale: locale,
      home: const UnfiscalizedReceiptsScreen(),
    ),
  );

  FiscalQueueEntry withDocument({String key = 'sale-4242-1'}) =>
      FiscalQueueEntry(
        idempotencyKey: key,
        opType: FiscalQueueOp.sale,
        payload: {
          'idempotencyKey': key,
          'localOperationId': 4242,
          'positions': [
            {'name': 'Хлеб', 'quantity': '1', 'price': '500'},
          ],
          'payments': [
            {'kind': 'cash', 'amount': '500'},
          ],
        },
        occurredAt: DateTime.now(),
        status: FiscalQueueStatus.failed,
        lastError: 'Неверный логин или пароль',
      );

  /// Как строка выглядела **до** задачи 11: свой ключ, записка вместо
  /// документа.
  FiscalQueueEntry legacy() => FiscalQueueEntry(
    idempotencyKey: 'sale-unfiscalized:1-777',
    opType: FiscalQueueOp.sale,
    payload: {'receiptNo': 777, 'posId': 1, 'amount': '500'},
    occurredAt: DateTime.now(),
    status: FiscalQueueStatus.failed,
    lastError: 'Касса заблокирована',
  );

  group('причина — фразой словаря, а не текстом data-слоя', () {
    FiscalQueueEntry coded(String stored) =>
        withDocument()..lastError = stored;

    testWidgets('русский интерфейс: код → русская фраза, кода на экране нет', (
      tester,
    ) async {
      await store.enqueue(coded('fiscal(cashboxBlocked)'));
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final shown = tester
          .widget<Text>(find.byKey(const ValueKey('unfiscalized-reason')))
          .data;
      expect(shown, 'Касса заблокирована оператором');
      expect(find.textContaining('fiscal('), findsNothing);
    });

    testWidgets('английский интерфейс: та же строка — английская фраза', (
      tester,
    ) async {
      await store.enqueue(coded('fiscal(operatorUnavailable#503)'));
      await tester.pumpWidget(host(locale: const Locale('en')));
      await tester.pumpAndSettle();

      final shown = tester
          .widget<Text>(find.byKey(const ValueKey('unfiscalized-reason')))
          .data;
      expect(shown, 'The fiscal operator is unavailable (code 503)');
      expect(shown, isNot(matches(RegExp('[А-Яа-я]'))));
    });

    testWidgets('строка, записанная до перевода, не теряет причину', (
      tester,
    ) async {
      await store.enqueue(coded('Касса заблокирована'));
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('записана до перевода: Касса заблокирована'),
        findsOneWidget,
      );
    });
  });

  testWidgets('пустая очередь — экран говорит это словами', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Все чеки фискализованы'), findsOneWidget);
    expect(find.byKey(const ValueKey('unfiscalized-retry')), findsNothing);
  });

  testWidgets('строка с документом предлагает и повтор, и списание', (
    tester,
  ) async {
    await store.enqueue(withDocument());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Чек №4242'), findsOneWidget);
    expect(find.byKey(const ValueKey('unfiscalized-retry')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('unfiscalized-write-off')),
      findsOneWidget,
    );
  });

  testWidgets(
    'строка СТАРОГО вида повтора не предлагает — и называет почему',
    (tester) async {
      await store.enqueue(legacy());
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('unfiscalized-retry')),
        findsNothing,
        reason:
            'повторять нечем: в строке записка, а ключ чужой — повтор дал бы '
            'второй фискальный документ на одну продажу',
      );
      expect(
        find.byKey(const ValueKey('unfiscalized-write-off')),
        findsOneWidget,
      );
      expect(find.textContaining('повторять нечем'), findsOneWidget);
      expect(find.text('Чек №777'), findsOneWidget);
    },
  );

  testWidgets('списание без причины подтвердить нельзя', (tester) async {
    await store.enqueue(withDocument());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('unfiscalized-write-off')));
    await tester.pumpAndSettle();

    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('unfiscalized-write-off-confirm')),
    );
    expect(
      confirm.onPressed,
      isNull,
      reason: 'пустая причина — списание неотличимо от тихой чистки',
    );

    await tester.enterText(
      find.byKey(const ValueKey('unfiscalized-write-off-reason')),
      'оператор отозвал кассу, чек проведён вручную',
    );
    await tester.pumpAndSettle();

    final filled = tester.widget<FilledButton>(
      find.byKey(const ValueKey('unfiscalized-write-off-confirm')),
    );
    expect(filled.onPressed, isNotNull);
  });

  testWidgets('пробелы причиной не считаются', (tester) async {
    await store.enqueue(withDocument());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('unfiscalized-write-off')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('unfiscalized-write-off-reason')),
      '   ',
    );
    await tester.pumpAndSettle();

    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('unfiscalized-write-off-confirm')),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets('списанная строка остаётся, но кнопок больше не предлагает', (
    tester,
  ) async {
    final entry = withDocument();
    entry.payload[FiscalQueueEntry.kWriteOffKey] = const {
      'at': '2026-09-08T10:00:00.000',
      'by': 'Айгуль',
      'reason': 'проведён вручную по бумажному чеку',
    };
    await store.enqueue(entry);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Чек №4242'), findsOneWidget, reason: 'не удалена');
    expect(find.textContaining('Списал Айгуль'), findsOneWidget);
    expect(find.byKey(const ValueKey('unfiscalized-retry')), findsNothing);
    expect(find.byKey(const ValueKey('unfiscalized-write-off')), findsNothing);
    expect(
      await store.failedCount(),
      0,
      reason: 'разобранная строка не зовёт человека второй раз',
    );
  });

  testWidgets('строка старше 72 часов помечена просроченной', (tester) async {
    final stale = withDocument(key: 'sale-9001-1');
    await store.enqueue(
      FiscalQueueEntry(
        idempotencyKey: 'sale-9001-1',
        opType: FiscalQueueOp.sale,
        payload: stale.payload,
        occurredAt: DateTime.now().subtract(const Duration(hours: 100)),
        status: FiscalQueueStatus.failed,
        lastError: 'Касса заблокирована',
      ),
    );

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Просрочено окно 72 ч'), findsOneWidget);
  });
}
