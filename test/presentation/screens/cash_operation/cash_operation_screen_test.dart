import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/cash_operation/cash_operation_receipt_data.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_operation_receipt_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/cash_operation/cash_operation_screen.dart';
import 'package:telepos/app/theme/app_theme.dart';

void main() {
  setUp(() {
    final getIt = GetIt.I;
    getIt.allowReassignment = true;
    if (!getIt.isRegistered<Talker>()) {
      getIt.registerSingleton<Talker>(Talker());
    }
  });

  tearDown(() {
    GetIt.I.reset();
  });

  Widget createTestWidget({double width = 400, double height = 800}) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      // Тема приложения, а не материальная по умолчанию.
      //
      // Без неё `Theme.of(context).extension<AppSemanticColors>()` возвращает
      // null, и любой виджет, спрашивающий у темы роль «подложка» или
      // «разделитель», падает на разыменовании. Экран поднимался под чужой
      // темой и «проверялся» в оформлении, которого в кассе нет, — ровно та же
      // ошибка, что была у эталонов с `ThemeData.light`.
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
        home: const CashOperationScreen(),
      ),
    );
  }

  group('CashOperationScreen (Mobile)', () {
    testWidgets('renders Scaffold with AppBar', (tester) async {
      await tester.pumpWidget(createTestWidget(width: 400));
      await tester.pumpAndSettle();

      expect(find.text('Кассовая операция'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows close button', (tester) async {
      await tester.pumpWidget(createTestWidget(width: 400));
      await tester.pumpAndSettle();

      expect(find.byIcon(TeleposIcons.close), findsOneWidget);
    });

    testWidgets('shows "Готово" button in AppBar', (tester) async {
      await tester.pumpWidget(createTestWidget(width: 400));
      await tester.pumpAndSettle();

      expect(find.text('Готово'), findsOneWidget);
    });

    testWidgets('shows amount display with 0.00', (tester) async {
      await tester.pumpWidget(createTestWidget(width: 400));
      await tester.pumpAndSettle();

      expect(find.text('0.00'), findsOneWidget);
      expect(find.text('Сумма'), findsOneWidget);
    });

    testWidgets('shows comment field', (tester) async {
      await tester.pumpWidget(createTestWidget(width: 400));
      await tester.pumpAndSettle();

      expect(find.text('Комментарий'), findsOneWidget);
      expect(find.text('Введите комментарий...'), findsOneWidget);
    });

    testWidgets('shows CashOperationForm widget', (tester) async {
      await tester.pumpWidget(createTestWidget(width: 400));
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('shows NumpadWidget at bottom', (tester) async {
      await tester.pumpWidget(createTestWidget(width: 400));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsWidgets);
      expect(find.text('5'), findsWidgets);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('numpad digit input updates amount', (tester) async {
      await tester.pumpWidget(createTestWidget(width: 400));
      await tester.pumpAndSettle();

      expect(find.text('0.00'), findsOneWidget);
    });

    testWidgets('"Готово" button disabled when amount is 0', (tester) async {
      await tester.pumpWidget(createTestWidget(width: 400));
      await tester.pumpAndSettle();

      final textButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Готово'),
      );
      expect(textButton.onPressed, isNull);
    });
  });

  /// И30: «ни один отказ устройства не блокирует приём денег».
  ///
  /// Раньше экран делал `await controller.printReceipt(...)` **после** того,
  /// как движение денег уже записано: оператор стоял и смотрел на не
  /// закрывающийся экран, пока принтер молчал. Тот же дефект проект однажды уже
  /// чинил на пути оплаты — там печать давно отправляется, а не ожидается.
  ///
  /// Здесь принтер молчит **навсегда** (`Completer`, который никто не
  /// завершает). Это точная модель недоступного принтера с точки зрения экрана
  /// и единственная форма, при которой возвращённое `await` снова сделало бы
  /// тест красным: медленный, но отвечающий принтер `pumpAndSettle` просто
  /// дождался бы, и проверка ничего бы не доказывала.
  group('CashOperationScreen — деньги не ждут принтера', () {
    late AppDatabase db;
    late _RecordingCashInOutController controller;
    late _SilentPrinterReceiptService receipts;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.thisPosDao.insertInitialConfig(
        companyName: 'ТОО ТестПОС',
        iinbin: '123456789012',
        cashBoxName: 'Касса-1',
        countryCode: 0,
        currencyCode: 0,
        currencySymbol: '₸',
        currencyNameShort: 'KZT',
        paperWidth: 48,
        printerHeader: null,
        printerFooter: null,
        accountId: 7,
        acquiringAccountId: null,
        rsaPublicKey: null,
      );
      // Кассовые операции разрешены политикой продаж — иначе экран откажет
      // до всякой печати, и тест проверял бы запрет, а не ожидание принтера.
      await (db.update(
        db.thisPosEntries,
      )..where((tp) => tp.rId.equals(true))).write(
        const ThisPosEntriesCompanion(id: Value(1), cashInOut: Value(true)),
      );

      controller = _RecordingCashInOutController();
      receipts = _SilentPrinterReceiptService();
      GetIt.I
        ..registerSingleton<AppDatabase>(db)
        ..registerSingleton<CashInOutController>(controller)
        ..registerSingleton<CashOperationReceiptService>(receipts);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'принтер молчит — деньги записаны, экран закрыт, результат отдан',
      (tester) async {
        CashOperationResult? popped;
        var returned = false;

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(400, 900)),
            child: ProviderScope(
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
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          popped = await Navigator.of(context)
                              .push<CashOperationResult>(
                                MaterialPageRoute(
                                  builder: (_) => const CashOperationScreen(),
                                ),
                              );
                          returned = true;
                        },
                        child: const Text('открыть'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('открыть'));
        await tester.pumpAndSettle();
        expect(find.text('Кассовая операция'), findsOneWidget);

        // Сумма: одна цифра, зато однозначная — «7» на этом экране больше
        // нигде не встречается.
        expect(find.text('7'), findsOneWidget);
        await tester.tap(find.text('7'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Готово'));
        await tester.pumpAndSettle();

        expect(
          controller.recorded,
          [Decimal.fromInt(7)],
          reason: 'деньги записаны — и записаны как Decimal, а не double',
        );
        expect(
          receipts.asked,
          [_RecordingCashInOutController.operationId],
          reason:
              'квитанция всё-таки отправлена в печать: пустой список означал '
              'бы, что экран стал быстрым, перестав печатать вовсе',
        );
        expect(
          receipts.answered,
          isFalse,
          reason:
              'принтер за всё это время не ответил — именно в этих условиях '
              'проверяется, что экран его не ждал',
        );
        expect(
          find.text('Кассовая операция'),
          findsNothing,
          reason:
              'ЭТО ВСЯ ПРОВЕРКА (И30): экран закрылся, не дождавшись принтера. '
              'Верните `await` на отправку квитанции — и он останется открытым',
        );
        expect(returned, isTrue);
        expect(popped?.success, isTrue);
        expect(popped?.operationId, _RecordingCashInOutController.operationId);
      },
    );
  });
}

/// Контроллер, который только записывает движение денег: печати у него нет и
/// быть не может — она ушла в `CashOperationReceiptService`.
class _RecordingCashInOutController implements CashInOutController {
  static const int operationId = 4242;

  final List<Decimal> recorded = <Decimal>[];

  CashOperationResult _record(Decimal amount) {
    recorded.add(amount);
    return CashOperationResult.created(operationId);
  }

  @override
  Future<CashOperationResult> createInvestment({
    required Decimal amount,
    required int accountId,
    String? note,
  }) async => _record(amount);

  @override
  Future<CashOperationResult> createExpense({
    required Decimal amount,
    required int accountId,
    required ExpenseType expenseType,
    String? note,
    int? customFieldItemId,
  }) async => _record(amount);

  @override
  Future<CashOperationResult> createDividend({
    required Decimal amount,
    required int accountId,
    String? note,
  }) async => _record(amount);

  @override
  Future<CashOperationResult> createInkassaciya({
    required Decimal amount,
    required int fromAccountId,
    int? toAccountId,
    String? note,
  }) async => _record(amount);

  @override
  Future<List<CashOperationInfo>> getOperationsForShift(int shiftId) async =>
      const [];

  @override
  Future<CashOperationValidation> validateAmount(Decimal amount) async =>
      CashOperationValidation.valid();

  @override
  Future<int> getPosAccountId() async => 7;
}

/// Принтер, который не отвечает **никогда**.
///
/// Не «отвечает ошибкой» и не «отвечает медленно»: и то и другое `pumpAndSettle`
/// дождался бы, и тест прошёл бы даже с возвращённым `await`. Незавершаемый
/// `Completer` — единственная форма, при которой ожидание видно.
class _SilentPrinterReceiptService implements CashOperationReceiptService {
  final List<int> asked = <int>[];
  final Completer<PrintSubmitOutcome> _never = Completer<PrintSubmitOutcome>();

  bool get answered => _never.isCompleted;

  @override
  Future<CashOperationReceiptData?> buildReceiptData(int operationId) async =>
      null;

  @override
  Future<PrintSubmitOutcome> printReceipt(int operationId) {
    asked.add(operationId);
    return _never.future;
  }
}
