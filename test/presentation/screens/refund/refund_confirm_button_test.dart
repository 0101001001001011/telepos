import 'dart:async';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTrouble;
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/refund/refund_screen.dart';

import '../../auth/support/fakes.dart';

/// Кнопка возврата обязана либо отдать деньги, либо сказать, почему нет.
///
/// # Что это стоило: четвёртый дефект того же класса
///
/// Живой прогон 2026-09-07, шаг 9. Кассир жмёт «ВОЗВРАТ», подтверждает —
/// **и не происходит ничего**: диалог закрылся, черновик на месте, к
/// возврату по-прежнему 1000, ни «Возврат успешно проведён», ни отказа, ни
/// полосы. В консоли **пусто**. Загрузка того же чека заново показала полные
/// две единицы — значит и на кассе возврата не было: товар не поехал,
/// деньги не двинулись.
///
/// Три предыдущих дефекта задачи были того же рода — «Ошибка сохранения:
/// SessionLost» говорила неправду, «Нет товаров» выдавало молчание за
/// ответ, — но этот хуже обоих: **кнопка денег не делает ничего и не
/// сообщает ничего**. Кассир нажмёт ещё раз, и ещё, и будет прав.
///
/// # Почему ни одна из 1022 проб этого не увидела
///
/// Потому что ни одна не жмёт «Подтвердить» на **смонтированном** экране.
/// `refund_cycle_test` зовёт `processRefund()` у контроллера напрямую — то
/// есть проверяет всё, кроме той половины, где живёт обработчик кнопки.
/// Здесь проба ведёт настоящий экран через настоящее нажатие и проверяет
/// **не состояние экрана, а дошли ли деньги до контракта**.
class _RecordingRefunds implements RefundService {
  _RecordingRefunds({this.refusal});

  /// Чем ответит касса на завершение. `null` — успехом.
  final WireRefusal? refusal;

  /// Сколько раз завершение доехало до кассы.
  int completeCalls = 0;

  @override
  Stream<RefundView> watch(int terminalId) => Stream.value(
    RefundView(
      posId: 1,
      terminalId: terminalId,
      version: 3,
      draftNo: 1,
      saleReceiptNo: 5001,
      salePosId: 1,
      lines: [
        RefundLine(
          id: '11',
          productId: 100,
          name: 'Молоко 3.2%',
          quantity: Decimal.fromInt(2),
          price: Decimal.fromInt(500),
          maxQuantity: Decimal.fromInt(2),
        ),
      ],
    ),
  );

  @override
  Future<RefundView> loadReceipt(
    int terminalId,
    int receiptNo,
    int posId,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundView> startWithoutReceipt(
    int terminalId,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundOutcome> complete(int terminalId, CartCommandMeta meta) async {
    completeCalls++;
    final denial = refusal;
    if (denial != null) throw denial;
    return RefundOutcome(
      refundLocalId: 7,
      amount: Decimal.fromInt(1000),
      lineCount: 1,
      paymentCount: 1,
      saleReceiptNo: 5001,
      salePosId: 1,
    );
  }

  @override
  Future<void> abandon(int terminalId) async {}

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int refundLocalId,
  ) async => const [];
}

Widget _app() => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const Scaffold(body: RefundScreen()),
  ),
);

void main() {
  setUp(() {
    app_log.installLogger(Talker());
    GetIt.I
      ..registerSingleton<TerminalIdentity>(FakeTerminalIdentity())
      ..registerSingleton<TerminalRepository>(
        FakeTerminalRepository(
          self: () async => const Terminal(
            id: 1,
            name: 'Планшет',
            pointMode: PointMode.cashier,
          ),
        ),
      );
  });

  tearDown(() async => GetIt.I.reset());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Ведёт экран ровно тем путём, каким идёт палец: «ВОЗВРАТ» →
  /// «Подтвердить».
  Future<void> pressRefund(WidgetTester tester) async {
    final button = find.text('ВОЗВРАТ');
    expect(
      button,
      findsWidgets,
      reason: 'подготовка: кнопка возврата на экране',
    );
    await tester.tap(button.first);
    await settle(tester);

    expect(
      find.text('Подтвердите возврат'),
      findsOneWidget,
      reason: 'деньги отдаются только по явному подтверждению',
    );
    await tester.tap(find.text('Подтвердить'));
    await settle(tester);
  }

  // Три раскладки, а не одна: живой прогон шёл в окне браузера, и какая
  // раскладка там была — не гадать, а проверить все. У настольной и
  // планшетной кнопка возврата приходит из `RefundActionButtons`, у
  // мобильной — из компактной панели итога, и это **разные** пути к одному
  // обработчику.
  for (final layout in const [
    (name: 'настольная', size: Size(1600, 1000)),
    (name: 'планшетная', size: Size(1000, 1400)),
    (name: 'мобильная', size: Size(500, 900)),
  ]) {
    testWidgets('подтверждение доводит возврат до кассы (${layout.name})', (
      tester,
    ) async {
      tester.view.physicalSize = layout.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final refunds = _RecordingRefunds();
      GetIt.I.registerSingleton<RefundService>(refunds);

      await tester.pumpWidget(_app());
      await settle(tester);

      await pressRefund(tester);

      expect(
        refunds.completeCalls,
        1,
        reason:
            'кнопка денег обязана дойти до кассы. Живой прогон: нажатие не '
            'делало НИЧЕГО и не говорило НИЧЕГО — ни успеха, ни отказа, ни '
            'строки в консоли, а чек оставался непогашенным',
      );
    });
  }

  testWidgets('успех виден кассиру, а не только кассе', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    GetIt.I.registerSingleton<RefundService>(_RecordingRefunds());

    await tester.pumpWidget(_app());
    await settle(tester);
    await pressRefund(tester);

    expect(
      find.text('Возврат успешно проведён'),
      findsWidgets,
      reason: 'молчание после отданных денег неотличимо от бездействия',
    );
  });

  testWidgets('отказ кассы на завершении виден кассиру', (tester) async {
    // Половина, которой не хватало больше всего: если касса **отказала**,
    // кассир обязан прочитать причину, а не смотреть на невредимый черновик
    // и гадать, нажалась ли кнопка.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    GetIt.I.registerSingleton<RefundService>(
      _RecordingRefunds(
        refusal: const WireRefusal(
          'shift_not_open',
          'смена не открыта — возврат не оформить',
        ),
      ),
    );

    await tester.pumpWidget(_app());
    await settle(tester);
    await pressRefund(tester);

    expect(
      find.textContaining('Смена не открыта. Откройте смену на кассе.'),
      findsOneWidget,
      reason: 'отказ кассы обязан доехать словами (И144)',
    );
    expect(find.text('Возврат успешно проведён'), findsNothing);
  });

  testWidgets('второй такой же отказ показывается снова, а не глотается', (
    tester,
  ) async {
    // Кассир жмёт кнопку ещё раз — та же неисправность даёт **дословно
    // одинаковый** текст. Экран слушал `error` и молчал, когда
    // `next == previous`: полоса показывалась один раз, дальше нажатие
    // выглядело как бездействие. Ровно тот дефект, который задача чинила
    // трижды, только с другой стороны — и ровно та картина, которую нашёл
    // живой прогон на шаге 9.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    GetIt.I.registerSingleton<RefundService>(
      _RecordingRefunds(
        refusal: const WireRefusal(
          'shift_not_open',
          'смена не открыта — возврат не оформить',
        ),
      ),
    );

    await tester.pumpWidget(_app());
    await settle(tester);

    await pressRefund(tester);
    expect(
      find.textContaining('Смена не открыта. Откройте смену на кассе.'),
      findsOneWidget,
    );

    // Полоса уходит сама; кассир жмёт второй раз.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(
      find.textContaining('Смена не открыта. Откройте смену на кассе.'),
      findsNothing,
      reason: 'подготовка: первая полоса погасла сама',
    );

    await pressRefund(tester);

    expect(
      find.textContaining('Смена не открыта. Откройте смену на кассе.'),
      findsOneWidget,
      reason:
          'второе нажатие на ту же неисправность обязано ответить тем же '
          'текстом, а не молчанием: молчание кассир читает как «кнопка не '
          'сработала» и жмёт ещё',
    );
  });

  testWidgets('пропавший черновик отвечает словами, а не тишиной', (
    tester,
  ) async {
    // **Третий путь к молчанию.** `processRefund` начинался с немого
    // `if (!state.canRefund) return false;` — единственного выхода всего
    // пути подтверждения, не производившего **ничего**: ни команды, ни
    // успеха, ни отказа, ни строки в журнале. Кассир жмёт «Подтвердить»,
    // диалог закрывается, и всё.
    //
    // Достижимо не только «сам снял выделение»: снимки приходят подпиской
    // **пока диалог открыт**, и черновик может пропасть на кассе — вход
    // другого кассира, вторая вкладка, второе рабочее место.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final refunds = _VanishingDraft();
    GetIt.I.registerSingleton<RefundService>(refunds);

    await tester.pumpWidget(_app());
    await settle(tester);

    await tester.tap(find.text('ВОЗВРАТ').first);
    await settle(tester);
    expect(find.text('Подтвердите возврат'), findsOneWidget);

    // Пока диалог открыт, касса забывает черновик.
    refunds.forgetDraft(1);
    await settle(tester);

    await tester.tap(find.text('Подтвердить'));
    await settle(tester);

    expect(
      refunds.completeCalls,
      0,
      reason: 'возвращать нечего — команду слать не за чем',
    );
    expect(
      find.textContaining('Черновик изменился — возвращать нечего'),
      findsOneWidget,
      reason:
          'кассир нажал кнопку денег: молчание он читает как «не сработало» '
          'и жмёт ещё, а на деле возвращать было нечего',
    );
  });
}

/// Касса, у которой черновик **пропадает, пока открыт диалог**.
///
/// Третий путь к молчанию, найденный разбором круга правки: `canRefund`
/// требует выделенного, а снимки приходят подпиской и во время диалога тоже.
/// Черновик забыт кассой (вход другого кассира), поднят второй вкладкой,
/// подхвачен вторым рабочим местом — и к моменту «Подтвердить» возвращать
/// нечего. Прежний код выходил из `processRefund` немым `return false`.
class _VanishingDraft implements RefundService {
  final _views = StreamController<RefundView>.broadcast();

  int completeCalls = 0;

  RefundView _full(int terminalId) => RefundView(
    posId: 1,
    terminalId: terminalId,
    version: 3,
    draftNo: 1,
    saleReceiptNo: 5001,
    salePosId: 1,
    lines: [
      RefundLine(
        id: '11',
        productId: 100,
        name: 'Молоко 3.2%',
        quantity: Decimal.fromInt(2),
        price: Decimal.fromInt(500),
        maxQuantity: Decimal.fromInt(2),
      ),
    ],
  );

  /// Касса забыла черновик — снимок приходит пустым.
  void forgetDraft(int terminalId) => _views.add(
    RefundView(posId: 1, terminalId: terminalId, version: 4, lines: const []),
  );

  @override
  Stream<RefundView> watch(int terminalId) async* {
    yield _full(terminalId);
    yield* _views.stream;
  }

  @override
  Future<RefundView> loadReceipt(
    int terminalId,
    int receiptNo,
    int posId,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundView> startWithoutReceipt(
    int terminalId,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundOutcome> complete(int terminalId, CartCommandMeta meta) async {
    completeCalls++;
    throw UnimplementedError();
  }

  @override
  Future<void> abandon(int terminalId) async {}

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int refundLocalId,
  ) async => const [];
}
