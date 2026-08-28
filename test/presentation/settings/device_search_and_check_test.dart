import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/printer_settings_screen.dart';

/// Plan 2b, task 3 — the point of the whole plan: the two contracts finally
/// have a reader in the interface. These tests press the buttons.
///
/// They deliberately go through the *real* screen (`PrinterSettingsScreen` →
/// `DeviceBindingEditor`) over the real `LocalDeviceBindingRepository` and a
/// real in-memory drift database, with only `DeviceDiscovery`/`DeviceCheck`
/// faked — those two are the things whose answers a test must be able to
/// choose. A test that only proved the button exists would prove nothing;
/// each of these asserts on what the operator ends up seeing or on what got
/// written.

class _FakeTerminalRepository implements TerminalRepository {
  _FakeTerminalRepository(this.terminalId);

  final int terminalId;

  @override
  Future<Terminal> self() async =>
      Terminal(id: terminalId, name: 'Касса-1', pointMode: PointMode.cashier);

  @override
  Future<List<Terminal>> list() => throw UnimplementedError();

  // Подписок этот экран не заводит: свой терминал он спрашивает один раз при
  // открытии. Бросают по той же причине, что и остальные члены — случайная
  // новая зависимость обязана падать громко, а не возвращать правдоподобное.
  @override
  Stream<List<Terminal>> watchAll() => throw UnimplementedError();

  @override
  Stream<Terminal?> watchSelf() => throw UnimplementedError();

  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) => throw UnimplementedError();

  @override
  Future<Terminal> resume({required int terminalId, required String secret}) =>
      throw UnimplementedError();

  @override
  Future<void> rename(int terminalId, String name) => throw UnimplementedError();

  @override
  Future<void> delete(int terminalId) => throw UnimplementedError();
}

/// Answers with whatever the test decided this search should find — the one
/// thing a UI test cannot get from real hardware.
class _ScriptedDiscovery implements DeviceDiscovery {
  _ScriptedDiscovery(this.result);

  final DeviceDiscoveryResult result;

  /// Recorded so a test can prove the button asked about the *right* class,
  /// not merely that it asked something.
  final asked = <DeviceClass>[];

  @override
  Future<DeviceDiscoveryResult> find(DeviceClass deviceClass) async {
    asked.add(deviceClass);
    return result;
  }
}

/// Returns a queue of outcomes, one per press, so a single test can show two
/// different reasons in sequence on the same screen.
class _ScriptedCheck implements DeviceCheck {
  _ScriptedCheck(this._outcomes);

  final List<DeviceCheckOutcome> _outcomes;
  int _index = 0;

  @override
  Future<DeviceCheckOutcome> check({
    required int terminalId,
    required DeviceClass deviceClass,
  }) async {
    final outcome = _outcomes[_index.clamp(0, _outcomes.length - 1)];
    _index++;
    return outcome;
  }
}

void main() {
  late AppDatabase db;
  late int terminalId;
  late DeviceBindingRepository repo;

  const profileId = 'printer.escpos.80mm';
  const profileTitle = 'Чековый принтер ESC/POS 80 мм';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final terminal = await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    terminalId = terminal.id;
    repo = LocalDeviceBindingRepository(db, BuiltinDeviceProfileCatalog());

    await GetIt.I.reset();
    GetIt.I.registerSingleton<DeviceProfileCatalog>(
      BuiltinDeviceProfileCatalog(),
    );
    GetIt.I.registerSingleton<DeviceBindingRepository>(repo);
    GetIt.I.registerSingleton<TerminalRepository>(
      _FakeTerminalRepository(terminalId),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ru'),
    home: const PrinterSettingsScreen(),
  );

  /// Opens the screen and gets as far as "a profile is chosen", which is
  /// where both buttons appear.
  ///
  /// The surface is enlarged past the 800×600 default because the check
  /// button sits below a full profile form; the default viewport pushes it
  /// off-screen and `tap()` then silently misses.
  Future<void> openWithProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(profileTitle));
    await tester.pumpAndSettle();
  }

  /// Scrolls a control into view before pressing it — a miss caused by the
  /// button being below the fold reads exactly like "the button did nothing".
  Future<void> press(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  group('«искать» — DeviceDiscovery has a reader', () {
    testWidgets(
      'choosing a candidate fills the connection-parameter field, and saving '
      'writes that value into the binding',
      (tester) async {
        final discovery = _ScriptedDiscovery(
          const DeviceDiscoveryResult(
            candidates: [
              DeviceCandidate(
                source: DeviceDiscoverySource.network,
                title: 'Сетевой адрес 192.168.1.50:9100',
                parameters: {'ipAddress': '192.168.1.50', 'port': '9100'},
              ),
              DeviceCandidate(
                source: DeviceDiscoverySource.network,
                title: 'Сетевой адрес 192.168.1.77:9100',
                parameters: {'ipAddress': '192.168.1.77', 'port': '9100'},
              ),
            ],
          ),
        );
        GetIt.I.registerSingleton<DeviceDiscovery>(discovery);

        await openWithProfile(tester);

        await press(tester, const Key('search_${profileId}_ipAddress'));

        // Both candidates offered — the operator chooses, discovery does not.
        expect(find.byKey(const Key('candidate_192.168.1.50')), findsOneWidget);
        expect(find.byKey(const Key('candidate_192.168.1.77')), findsOneWidget);

        await tester.tap(find.byKey(const Key('candidate_192.168.1.77')));
        await tester.pumpAndSettle();

        final field = tester.widget<TextField>(
          find.byKey(const Key('param_${profileId}_ipAddress')),
        );
        expect(
          field.controller!.text,
          '192.168.1.77',
          reason: 'the chosen candidate must land in the field itself, not '
              'only in the draft behind it',
        );

        expect(
          discovery.asked,
          [DeviceClass.receiptPrinter],
          reason: 'the search must be for this section\'s device class',
        );

        // Still not a binding until the operator saves — and then it is the
        // chosen value that is saved, not the first candidate found.
        expect(await repo.forTerminal(terminalId), isEmpty);
        await tester.tap(find.byIcon(TeleposIcons.save));
        await tester.pumpAndSettle();
        final saved = await repo.forTerminal(terminalId);
        expect(saved, hasLength(1));
        expect(saved.single.parameters['ipAddress'], '192.168.1.77');
      },
    );

    testWidgets(
      'a source that could not be searched is reported, and is NOT reported '
      'as "everything was searched and nothing is attached"',
      (tester) async {
        GetIt.I.registerSingleton<DeviceDiscovery>(
          _ScriptedDiscovery(
            const DeviceDiscoveryResult(
              failedSources: {DeviceDiscoverySource.network},
            ),
          ),
        );

        await openWithProfile(tester);
        await press(tester, const Key('search_${profileId}_ipAddress'));

        final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

        expect(
          find.byKey(const Key('discovery_failed_sources')),
          findsOneWidget,
          reason: 'a failed source must be visible, not swallowed',
        );
        expect(
          find.text(l10n.deviceSearchFailedSources(l10n.deviceSourceNetwork)),
          findsOneWidget,
          reason: 'the operator must be told WHICH source failed',
        );
        expect(
          find.text(l10n.deviceSearchEmpty),
          findsNothing,
          reason: 'claiming every source was searched when one failed is the '
              'exact defect failedSources exists to prevent',
        );
      },
    );

    testWidgets(
      'a genuinely complete search that found nothing says so, and shows no '
      'failed-source line',
      (tester) async {
        GetIt.I.registerSingleton<DeviceDiscovery>(
          _ScriptedDiscovery(const DeviceDiscoveryResult()),
        );

        await openWithProfile(tester);
        await press(tester, const Key('search_${profileId}_ipAddress'));

        final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

        expect(find.text(l10n.deviceSearchEmpty), findsOneWidget);
        expect(find.byKey(const Key('discovery_failed_sources')), findsNothing);
      },
    );

    testWidgets(
      'candidates that carry no value for this field are not offered as if '
      'they did',
      (tester) async {
        GetIt.I.registerSingleton<DeviceDiscovery>(
          _ScriptedDiscovery(
            const DeviceDiscoveryResult(
              candidates: [
                DeviceCandidate(
                  source: DeviceDiscoverySource.serialPort,
                  title: 'Последовательный порт COM3',
                  parameters: {'comPort': 'COM3'},
                ),
              ],
            ),
          ),
        );

        await openWithProfile(tester);
        await press(tester, const Key('search_${profileId}_ipAddress'));

        final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
        expect(find.text(l10n.deviceSearchNoValueForField), findsOneWidget);
        expect(
          find.text(l10n.deviceSearchEmpty),
          findsNothing,
          reason: '"nothing found" would be false — something was found',
        );
      },
    );
  });

  group('«проверить устройство» — DeviceCheck has a reader', () {
    testWidgets(
      'two different reasons produce two different messages on screen, as '
      'text rather than a tick or a cross',
      (tester) async {
        GetIt.I.registerSingleton<DeviceCheck>(
          _ScriptedCheck([
            DeviceCheckOutcome.driverNotLive(DeviceClass.receiptPrinter),
            DeviceCheckOutcome.deviceRefused('Нет бумаги в принтере'),
          ]),
        );

        await openWithProfile(tester);
        final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

        await press(tester, const Key('device_check_button'));

        expect(
          find.text(l10n.deviceCheckReasonDriverNotLive),
          findsOneWidget,
          reason:
              'driverNotLive is advice — "there is nothing here to check '
              'with", not "check the cable"',
        );
        expect(
          // The outcome's own words, deliberately not a phrase the standing
          // notice beside the button also contains: after finding I2 that
          // notice mentions restarting too, so matching on "перезапустите"
          // would pass without the outcome being rendered at all.
          find.textContaining('эта сборка не может с ним работать'),
          findsOneWidget,
          reason: "the contract's own message must be shown, not replaced",
        );
        expect(find.text(l10n.deviceCheckReasonDeviceRefused), findsNothing);

        await press(tester, const Key('device_check_button'));

        expect(find.text(l10n.deviceCheckReasonDeviceRefused), findsOneWidget);
        expect(find.text('Нет бумаги в принтере'), findsOneWidget);
        expect(
          find.text(l10n.deviceCheckReasonDriverNotLive),
          findsNothing,
          reason: 'the previous outcome must be replaced, not accumulated',
        );
      },
    );

    testWidgets(
      'notConfigured and connectionFailed are distinguishable — the two an '
      'operator would act on most differently',
      (tester) async {
        GetIt.I.registerSingleton<DeviceCheck>(
          _ScriptedCheck([
            DeviceCheckOutcome.notConfigured(DeviceClass.receiptPrinter),
            DeviceCheckOutcome.connectionFailed(
              'Не удалось подключиться к принтеру чеков',
            ),
          ]),
        );

        await openWithProfile(tester);
        final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

        await press(tester, const Key('device_check_button'));
        expect(find.text(l10n.deviceCheckReasonNotConfigured), findsOneWidget);

        await press(tester, const Key('device_check_button'));
        expect(
          find.text(l10n.deviceCheckReasonConnectionFailed),
          findsOneWidget,
        );
        expect(
          find.text(l10n.deviceCheckReasonNotConfigured),
          findsNothing,
          reason: '"nothing is bound" and "nothing answered" send an operator '
              'to two different places',
        );
      },
    );

    testWidgets('a successful check reports success, also as text', (
      tester,
    ) async {
      GetIt.I.registerSingleton<DeviceCheck>(
        _ScriptedCheck([DeviceCheckOutcome.ok('Пробный чек напечатан')]),
      );

      await openWithProfile(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

      await press(tester, const Key('device_check_button'));

      expect(find.text(l10n.deviceCheckReasonOk), findsOneWidget);
      expect(find.text('Пробный чек напечатан'), findsOneWidget);
    });
  });
}
