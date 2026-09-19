/// Экран настройки оплаты по QR — пункт 8 C (2026-09-15).
///
/// Главное утверждение — про ключ: сохранённый ключ **не появляется на
/// экране ни в каком виде**, а введённый уходит в порт и не остаётся в поле.
/// Подделка порта держит ключ у себя и отдаёт экрану только `keySet`, ровно
/// как `QrPaymentDesk`; проба ищет ключ во всём дереве виджетов, включая
/// содержимое полей ввода.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/l10n/app_localizations_ru.dart';
import 'package:telepos/presentation/screens/settings/qr_payment_setup_screen.dart';

const _secret = 'sk-live-SECRET-42';

class _Port implements QrProviderSetupRepository {
  String baseUrl = 'https://sbp.bank/api';
  String code = 'sbp_bank';
  String? key = _secret;
  Duration patience = const Duration(seconds: 180);
  bool kindActive = false;
  bool configured = true;
  final saves = <({String? newApiKey, bool clearApiKey})>[];

  /// Чем касса отвечает на чтение и на запись. `null` — согласилась.
  ///
  /// С 2026-09-18 под портом может стоять провод, и `WireRefusal` — ровно то,
  /// чем отвечает **обе** его реализации: кассовая стойка бросает его сама,
  /// браузерная переводит в него отказ кадра с тем же кодом.
  WireRefusal? readRefusal;
  WireRefusal? saveRefusal;

  @override
  Future<QrProviderView> read() async {
    final refusal = readRefusal;
    if (refusal != null) throw refusal;
    return QrProviderView(
      configured: configured,
      baseUrl: baseUrl,
      code: code,
      keySet: key != null,
      patience: patience,
      kindActive: kindActive,
    );
  }

  @override
  Future<void> save({
    required String baseUrl,
    required String code,
    required Duration patience,
    String? newApiKey,
    bool clearApiKey = false,
  }) async {
    final refusal = saveRefusal;
    if (refusal != null) throw refusal;
    saves.add((newApiKey: newApiKey, clearApiKey: clearApiKey));
    this.baseUrl = baseUrl.trim();
    this.code = code.trim();
    this.patience = patience;
    final typed = newApiKey?.trim() ?? '';
    key = clearApiKey ? null : (typed.isNotEmpty ? typed : key);
    configured = true;
  }

  @override
  Future<void> clear() async => configured = false;

  @override
  Future<void> setKindActive(bool active) async => kindActive = active;
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const QrPaymentSetupScreen(),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Всё, что экран показывает словами: тексты и содержимое полей.
List<String> _everything(WidgetTester tester) => [
  for (final w in tester.widgetList<Text>(find.byType(Text))) w.data ?? '',
  for (final w in tester.widgetList<EditableText>(find.byType(EditableText)))
    w.controller.text,
];

void main() {
  setUp(() => app_log.installLogger(Talker()));
  tearDown(() async => GetIt.I.reset());

  testWidgets('сохранённый ключ не появляется на экране ни в каком виде', (
    tester,
  ) async {
    GetIt.I.registerSingleton<QrProviderSetupRepository>(_Port());
    await _pump(tester);

    expect(find.byKey(const Key('qr-settings-url')), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('qr-settings-url')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'https://sbp.bank/api',
      reason: 'подготовка: настройка до экрана доехала',
    );
    expect(
      _everything(tester).where((t) => t.contains(_secret)),
      isEmpty,
    );
    expect(find.text('Ключ сохранён. Введите новый, чтобы заменить'), findsOneWidget);
  });

  testWidgets('новый ключ уходит в порт, ввод скрыт, поле очищается', (
    tester,
  ) async {
    final port = _Port()..key = null;
    GetIt.I.registerSingleton<QrProviderSetupRepository>(port);
    await _pump(tester);

    final keyField = find.descendant(
      of: find.byKey(const Key('qr-settings-key')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(keyField).obscureText, isTrue);

    await tester.enterText(find.byKey(const Key('qr-settings-key')), 'новый-ключ');
    await tester.tap(find.byKey(const Key('qr-settings-save')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(port.saves.single.newApiKey, 'новый-ключ');
    expect(port.key, 'новый-ключ');
    expect(tester.widget<EditableText>(keyField).controller.text, isEmpty);
    expect(_everything(tester).where((t) => t.contains('новый-ключ')), isEmpty);
  });

  testWidgets('пересохранение без ввода ключа прежний ключ не трогает', (
    tester,
  ) async {
    final port = _Port();
    GetIt.I.registerSingleton<QrProviderSetupRepository>(port);
    await _pump(tester);

    await tester.enterText(
      find.byKey(const Key('qr-settings-url')),
      'https://другой.bank/api',
    );
    await tester.tap(find.byKey(const Key('qr-settings-save')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(port.key, _secret);
    expect(port.saves.single.clearApiKey, isFalse);
  });

  testWidgets('вид оплаты QR включается с этого экрана', (tester) async {
    final port = _Port();
    GetIt.I.registerSingleton<QrProviderSetupRepository>(port);
    await _pump(tester);

    await tester.tap(find.byKey(const Key('qr-settings-kind')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(port.kindActive, isTrue);
  });

  testWidgets('неверный адрес — отказ словами, в порт ничего не ушло', (
    tester,
  ) async {
    final port = _Port();
    GetIt.I.registerSingleton<QrProviderSetupRepository>(port);
    await _pump(tester);

    await tester.enterText(find.byKey(const Key('qr-settings-url')), 'sbp.bank');
    await tester.tap(find.byKey(const Key('qr-settings-save')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(port.saves, isEmpty);
    expect(
      find.text('Адрес должен начинаться с http:// или https://'),
      findsOneWidget,
    );
  });

  testWidgets('без порта в контейнере — «только на кассе»', (tester) async {
    // С 2026-09-18 это больше **не** «браузерный терминал»: у браузера порт
    // есть — `WtQrProviderSetup` поверх провода. Незаведённый порт стал тем,
    // чем и должен быть, — ошибкой сборки, а не режимом работы.
    await _pump(tester);
    expect(find.byKey(const Key('qr-settings-till-only')), findsOneWidget);
    expect(find.byKey(const Key('qr-settings-key')), findsNothing);
  });

  // ── названный отказ кассы (решение заказчика 2026-09-18) ───────────────
  //
  // С проводом под портом у чтения и записи появились **отказы с именами**:
  // нет права (`forbidden`), нет стойки (`qr_setup_unavailable`), оборвана
  // связь (`no_session`). Все они складывались бы в одну фразу «не удалось
  // сохранить», а отказ на чтении до этой правки не ловился вовсе — экран
  // крутил бы кружок вечно.

  testWidgets('отказ кассы на чтении — фраза словаря, а не «только на кассе»', (
    tester,
  ) async {
    final port = _Port()
      ..readRefusal = const WireRefusal(
        qrSetupUnavailableCode,
        'эта касса не держит настройки провайдера QR',
      );
    GetIt.I.registerSingleton<QrProviderSetupRepository>(port);
    await _pump(tester);

    final l10n = AppLocalizationsRu();
    expect(find.byKey(const Key('qr-settings-refused')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('qr-settings-refused'))).data,
      l10n.errorQrSetupUnavailable,
    );
    // Две причины — два разных слова. «Настройка делается на самой кассе»
    // здесь было бы ложью: на кассе владельцу откажут ровно так же.
    expect(find.byKey(const Key('qr-settings-till-only')), findsNothing);
    expect(
      _everything(tester).where(
        (t) => t.contains('эта касса не держит настройки провайдера QR'),
      ),
      isEmpty,
      reason: 'текст кассы написан по-русски внутри кассы и на экран не едет',
    );
  });

  testWidgets('отказ кассы при сохранении доезжает фразой по коду', (
    tester,
  ) async {
    final port = _Port();
    GetIt.I.registerSingleton<QrProviderSetupRepository>(port);
    await _pump(tester);

    port.saveRefusal = const WireRefusal(
      'forbidden',
      'операция требует settings.accounts',
    );
    await tester.tap(find.byKey(const Key('qr-settings-save')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final l10n = AppLocalizationsRu();
    expect(find.text(l10n.errorNotAllowed), findsOneWidget);
    expect(
      find.text(l10n.qrSettingsSaveFailed),
      findsNothing,
      reason:
          '«не удалось сохранить» на отказ по праву — это фраза, после '
          'которой владелец будет чинить не то',
    );
  });

  testWidgets('код, которого терминал не знает, не молчит', (tester) async {
    final port = _Port()
      ..readRefusal = const WireRefusal('zz_never_named', 'что-то случилось');
    GetIt.I.registerSingleton<QrProviderSetupRepository>(port);
    await _pump(tester);

    final shown = tester
        .widget<Text>(find.byKey(const Key('qr-settings-refused')))
        .data!;
    expect(shown, isNotEmpty);
    expect(
      shown,
      isNot(contains('что-то случилось')),
      reason: 'текст неизвестного кода на экран не едет (И144)',
    );
  });
}
