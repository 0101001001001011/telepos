import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:get_it/get_it.dart';
import 'package:telepos/backend/api_server.dart';
import 'package:telepos/backend/api_server_reachability.dart';
import 'package:telepos/backend/certificate_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/backend/web_bundle.dart';
import 'package:telepos/core/net/listen_scope.dart';
import 'package:telepos/core/net/till_network_name.dart';
import 'package:telepos/core/settings/terminal_service_settings.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/device/device_check_local.dart';
import 'package:telepos/data/payment/qr_payment_desk.dart';
import 'package:telepos/data/device/device_discovery_local.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/usecases/payment/customer_payment_use_case.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/network/network_repository.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/sale/expiry_warning.dart';
import 'package:telepos/domain/stock/stock_changes.dart';
import 'package:telepos/domain/sale/quick_product_catalog.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/hardware/cash_drawer/cash_drawer_service.dart';
import 'package:telepos/hardware/label_printer/label_printer_service.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/scales/scales_service.dart';
import 'package:telepos/app/config/mobile_config.dart';
import 'package:telepos/app/config/window_config.dart';
import 'package:telepos/app/di/service_locator.dart';
import 'package:telepos/app/router/app_router.dart';
import 'package:telepos/app/telepos_app.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/domain/services/currency_service.dart';
import 'package:telepos/core/logging/app_logger.dart';
import 'package:telepos/data/logging/syslog_log_sink.dart';
import 'package:telepos/data/pki/certificate_address_watch.dart';
import 'package:telepos/data/pki/certificate_addresses.dart';
import 'package:telepos/data/pki/root_trust_sync.dart';
import 'package:telepos/data/pki/till_certificates.dart';
import 'package:telepos/data/transport/host_addresses.dart';
import 'package:telepos/data/transport/till_announcement.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/transport/webtransport_endpoint.dart';
import 'package:telepos/core/platform/platform_info.dart';
import 'package:telepos/core/settings/customer_screen_settings.dart';
import 'package:telepos/hardware/display/customer_window_service.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/customer_display/customer_display_screen.dart';
import 'package:telepos/presentation/screens/customer_display/customer_display_window.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/logging/app_talker.dart';

/// Run without showing the desktop window: `telepos.exe --headless`.
///
/// TelePOS is one application, not a client and a server. This process owns the
/// database, the hardware and the local API whether or not it draws anything —
/// headless only means its interface is a browser instead of this window.
///
/// A command-line flag rather than a compile-time define, so one build serves
/// both modes and the native runner can read the same flag: it has to skip
/// showing the window in the first place, since hiding it afterwards still
/// flashes a black square. See windows/runner/main.cpp.
bool _headless = false;

/// Where the built browser bundle lives, from `--web-dir=<path>`.
///
/// A command-line argument, not a compile-time define: the point of the browser
/// binding is a short debugging loop, and rebuilding the whole desktop app to
/// point it at a freshly built bundle is not short.
///
/// Переопределение, а не единственный источник: ярлык из меню «Пуск» аргументов
/// не несёт, и установленная касса обязана находить бандл сама. Где именно —
/// решает [resolveWebBundle].
String? _webDir;

/// Which capabilities a launch declares, from its command-line arguments.
///
/// A named pure function instead of an inline ternary at the registration
/// call site, so a broken flag check fails a fast unit test instead of only
/// showing up on a real kiosk at runtime (I10). The single source of the
/// `--kiosk`/`--server` decision — [main] does not re-check the raw flags
/// anywhere else, so there is exactly one place this decision is made.
@visibleForTesting
HostCapabilities resolveHostCapabilities(List<String> args) {
  final serverRole = args.contains('--server');
  final kiosk = args.contains('--kiosk');
  return serverRole
      ? HostCapabilities.server
      : kiosk
      ? HostCapabilities.appliance
      : HostCapabilities.desktop;
}

Talker _createLogger(String logDirectory) {
  return AppLogger.create(
    isProduction: kReleaseMode,
    logDirectory: logDirectory,
  );
}

/// Opens the RFC 5424 sink and says, in the local log, what it got.
///
/// Never throws: [openTeleposSyslogSink] answers with a value in every case,
/// including "there is no native library here". A till whose sink did not
/// open behaves exactly as it did before this existed — the file log is
/// unchanged and nothing else in the application asks about it.
Future<void> _attachSyslogSink(String logDirectory) async {
  try {
    final sink = await openTeleposSyslogSink(logDirectory: logDirectory);
    final delivering = AppLogger.attachSink(sink);
    if (delivering) {
      talker.info('Syslog sink open (RFC 5424); spool under $logDirectory');
    } else {
      talker.info('Syslog sink off: ${sink.unavailableReason}');
    }
  } catch (e) {
    talker.info('Syslog sink off: $e');
  }
}

void main(List<String> args) {
  _headless = args.contains('--headless');
  _webDir = args
      .where((a) => a.startsWith('--web-dir='))
      .map((a) => a.substring('--web-dir='.length))
      .firstOrNull;

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      if (WindowConfig.isDesktop) {
        try {
          final wc = await WindowController.fromCurrentEngine().timeout(
            const Duration(seconds: 2),
          );
          if (wc.arguments.contains(kCustomerDisplayBusinessId)) {
            await runCustomerDisplayWindow(wc);
            return;
          }
        } catch (_) {}
      }

      String logDirectory = '';
      if (!kIsWeb) {
        if (kReleaseMode) {
          final appDir = await getApplicationSupportDirectory();
          logDirectory = '${appDir.path}${Platform.pathSeparator}logs';
        } else {
          logDirectory =
              '${Directory.current.path}${Platform.pathSeparator}logs';
        }
      }

      installLogger(_createLogger(logDirectory));
      talker.info('TelePOS starting on ${PlatformInfo.name}...');

      // Not awaited, on purpose. Opening the syslog sink starts an isolate and
      // loads a native library; a till must not wait on a log transport to
      // come up, and must start normally when it never does. Whichever way it
      // goes, the answer lands in the local file.
      if (!kIsWeb) {
        unawaited(_attachSyslogSink(logDirectory));
      }

      if (WindowConfig.isDesktop) {
        final isUnique = await WindowConfig.acquireSingleInstanceLock();
        if (!isUnique) {
          talker.error('Another instance of TelePOS is already running');
          return;
        }
      }

      if (WindowConfig.isDesktop) {
        // Headless has no window to size, centre or title — the native runner
        // never shows one. Asking window_manager to configure it anyway is at
        // best pointless and at worst brings the window back.
        if (_headless) {
          talker.info('Headless — no window; the interface is a browser');
        } else {
          await WindowConfig.init(isProduction: false);
          talker.info('Desktop window configured');
        }

        if (kReleaseMode) {
          await AppLogger.redirectStdStreams(logDirectory: logDirectory);
          talker.info('Stdout/stderr redirected to logs/');
        }
      }

      if (MobileConfig.isMobile) {
        await MobileConfig.init();
        talker.info('Mobile platform configured');
      }

      await configureDependencies(logger: talker);
      talker.info('DI configured');

      // Повтор очереди фискализации — сразу и кругом, а не один раз при
      // подъёме: чек, легший в очередь днём, иначе ждал перезапуска кассы.
      // Здесь, а не в `configureDependencies`: тот же граф собирает сквозной
      // стенд набора, и периодический таймер ему не нужен.
      startFiscalReplay();

      // Пункт 6 брифа закрытия долга безопасности (2026-08-22): журналу не
      // было ни одного читателя — findAll/firstBrokenLinkId не звала ни
      // одна строка `lib/`, проверка И67 в продукте не выполнялась никогда.
      // Минимум, названный брифом: проверка на подъёме кассы, с записью
      // результата. `terminalId` — тот же `self()`-приём, что у
      // `_recordUserSecurityEvent` (`user_management_screen.dart`): на
      // первом запуске (мастер настройки ещё не проходил) отдаёт `0`,
      // сентинел, не настоящий id.
      unawaited(
        checkSecurityJournalIntegrityAtBoot(
          dao: GetIt.I<AppDatabase>().securityEventDao,
          journal: GetIt.I<SecurityJournal>(),
          terminalId:
              (await GetIt.I<AppDatabase>().terminalDao.self())?.id ?? 0,
          logger: talker,
        ),
      );

      // Разбор намерений QR при подъёме — **до** первого чека. «Касса
      // перезагрузилась, пока покупатель платил» — не экзотика, а вечер
      // пятницы: подтверждение лежит у провайдера и узнаётся только
      // вопросом. Заодно отменяются коды, чьё терпение вышло без
      // присмотра (вкладка закрылась посреди ожидания). Не ожидается: без
      // связи с провайдером касса обязана подняться, а неразобранное
      // останется неразобранным до следующего круга, а не пропадёт.
      if (GetIt.I.isRegistered<QrPaymentDesk>()) {
        unawaited(
          GetIt.I<QrPaymentDesk>().reconcile().then(
            (orphans) => talker.info(
              'QR: boot reconcile, orphan money ${orphans.length}',
            ),
            onError: (Object e) => talker.warning(
              'QR: boot reconcile failed: ${safeErrorText(e)}',
            ),
          ),
        );
      }

      // The image declares itself here and does not change afterwards (I10).
      // --kiosk means our image, where the machine is entirely ours; --server
      // means the data role with no devices. resolveHostCapabilities is the
      // single source of this decision — nothing here re-checks the raw
      // `--kiosk`/`--server` flags on the side, so there is exactly one
      // place this decision is made and tested, and the log line below is
      // derived from its result rather than from a second, separately
      // parsed copy of the same flags.
      final hostCapabilities = resolveHostCapabilities(args);
      final hostImage = identical(hostCapabilities, HostCapabilities.appliance)
          ? 'appliance'
          : identical(hostCapabilities, HostCapabilities.server)
          ? 'server'
          : 'desktop';
      talker.info('Host image: $hostImage');
      GetIt.I.registerSingleton<HostCapabilities>(hostCapabilities);

      FlutterError.onError = (details) {
        talker.error(details.exceptionAsString(), details.stack);
      };

      final prefs = await SharedPreferences.getInstance();

      // Локальный сервер поднимается ВСЕГДА, и это правка, а не мелочь.
      //
      // Здесь стояло `const bool.fromEnvironment('TELEPOS_API') || _headless`,
      // и `TELEPOS_API` не задавалась нигде: ни в сборке, ни в CI, ни в
      // установщике. Значит у обычной кассы не поднимался сервер, а вместе с
      // ним не выписывался и корень магазина — он создаётся при первом
      // открытии хранилища сертификатов. Установщик, который умеет поставить
      // корень в доверенные пользователя, находил пустой каталог.
      //
      // Требование к корню — предсказуемость: он выписывается либо всегда,
      // либо никогда, но не «иногда, смотря какой флаг». Поэтому подъём здесь
      // безусловен, а решение о безопасности отделено от него и живёт в
      // области прослушивания: касса, которой оператор не поручал обслуживать
      // терминалы, поднимается на петле и порт в сеть не открывает.
      //
      // `_headless` перестал включать сам сервер — тот поднимается и без него,
      // — но остался заявлением о том, кого этот запуск обслуживает: у процесса
      // без окна интерфейс не здесь, и слушать одну петлю ему незачем. Почему
      // это не обход правила «сознательное включение владельцем» — на
      // `TerminalServiceChoice.resolve`.
      final terminalService = TerminalServiceChoice.resolve(
        prefs,
        headless: _headless,
      );
      await _startLocalApi(terminalService);

      // Встроенные эмуляторы — после сервера и до окна: привязка прибора
      // пережила перезагрузку, а сокет нет, и касса не должна начинать утро
      // с адреса, которого никто не слушает.
      await startBuiltinEmulators(prefs);

      talker.info('TelePOS ready, launching app');

      runApp(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          // Headless still runs an app: this process owns the database and the
          // devices, and a Flutter engine with nothing running would tear them
          // down. It draws nothing, because nobody is looking at this window.
          child: _headless
              ? const SizedBox.shrink()
              : const AppRestarter(child: NativeAppShell()),
        ),
      );
    },
    (error, stackTrace) {
      talker.handle(error, stackTrace, 'Uncaught error');
    },
  );
}

/// Native wrapper around the shared [TelePosApp].
///
/// Holds what only a desktop till can do — driving a second monitor as a
/// customer display. The app root itself stays free of hardware so the browser
/// binding can run the very same screens; see docs/ARCHITECTURE.md.
class NativeAppShell extends ConsumerStatefulWidget {
  const NativeAppShell({super.key});

  @override
  ConsumerState<NativeAppShell> createState() => _NativeAppShellState();
}

class _NativeAppShellState extends ConsumerState<NativeAppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeOpenCustomerScreen());
    });
  }

  Future<void> _maybeOpenCustomerScreen() async {
    try {
      if (!WindowConfig.isDesktop) return;
      final prefs = ref.read(sharedPreferencesProvider);
      final choice = CustomerScreenChoice.read(prefs);
      if (!choice.enabled) return;
      final storeName = ref.read(storeNameProvider).asData?.value ?? 'TelePOS';
      await ref
          .read(customerWindowServiceProvider)
          .open(
            monitorIndex: choice.monitor,
            storeName: storeName,
            currencySymbol: _tillCurrencySymbol(),
            languageCode: ref.read(localeProvider).languageCode,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    ref.listen(saleControllerProvider, (prev, next) {
      ref
          .read(customerWindowServiceProvider)
          .push(
            customerDataFromSale(
              next,
              currencySymbol: _tillCurrencySymbol(),
              languageCode: ref.read(localeProvider).languageCode,
            ),
          );
    });

    return TelePosApp(router: router);
  }
}

/// Знак валюты кассы для окна покупателя.
///
/// Пустая строка, если касса ещё не настроена: окно тогда покажет голое
/// число. Выдуманный знак валюты на экране покупателя — заявление о цене.
String _tillCurrencySymbol() {
  if (!GetIt.I.isRegistered<CurrencyService>()) return '';
  try {
    return GetIt.I<CurrencyService>().symbol;
  } catch (_) {
    return '';
  }
}

/// The leaf both listeners present, or `null` with the reason in the log.
///
/// One leaf, asked for once, on purpose. The page carries the fingerprint of
/// the certificate the QUIC listener presents; if the two were asked for
/// separately a renewal landing between the calls would put one certificate on
/// the wire and another one's fingerprint into the page, and the browser would
/// refuse the session with neither side able to say why.
Future<_TillPki?> _tillLeaf() async {
  try {
    final directory = await getApplicationSupportDirectory();
    final storeDirectory = '${directory.path}${Platform.pathSeparator}pki';
    final opened = await TillCertificates.open(
      storeDirectory: storeDirectory,
      installationId: 'telepos',
      machineId: Platform.localHostname,
    );
    if (opened is CertificateUnavailable) {
      talker.info('No till certificate: ${opened.reason}');
      return null;
    }
    final certificates = opened as TillCertificates;

    final credential = await certificates.webTransportCredential(
      // `localhost` stays for the operator's own browser on this machine;
      // `<name>.local` is what a tablet resolves through the announcement.
      dnsNames: <String>['localhost', '${tillNetworkName()}.local'],
      // Адреса — не удобство, а единственный путь там, где режут многоадресную
      // рассылку. Измерено 2026-08-05 в сети заказчика: запрос mDNS уходил, и
      // назад не приходило ни одного пакета; терминал дошёл до кассы только
      // потому, что имя вписали в `/etc/hosts` руками. Правило выбора адресов
      // и его обоснование — в `certificateAddresses`.
      ipAddresses: await certificateAddresses(),
    );
    if (credential is CertificateUnavailable) {
      talker.info('No till certificate: ${credential.reason}');
      return null;
    }

    final leaf = credential as WebTransportCredential;

    // Что лист называет на самом деле — прочитанное из него, а не то, что мы
    // просили выписать. Строка нужна ровно на один вопрос: «почему не идёт по
    // адресу». Без неё ответ добывается `openssl x509 -text` на машине, где
    // `openssl` может и не стоять.
    talker.info('Till leaf SAN — ${leaf.subjectAltNames}');

    // The root travels with the leaf because both come from the same store and
    // asking twice, later, would open a second handle to it.
    final root = await certificates.authorityRootPem();
    if (root is CertificateUnavailable) {
      talker.info('No trust anchor to hand out: ${root.reason}');
    }

    return _TillPki(leaf, root is String ? root : null);
  } catch (e) {
    talker.info('No till certificate: $e');
    return null;
  }
}

/// What this machine's own PKI hands the rest of startup: the leaf both
/// listeners present, and the anchor a paired device installs.
///
/// One object rather than two calls, because they come out of one store and
/// must describe one installation: a page served under a leaf from one
/// authority while the tablet installed the root of another is a handshake
/// that fails with both halves looking correct in isolation.
class _TillPki {
  const _TillPki(this.leaf, this.rootPem);

  final WebTransportCredential leaf;

  /// `null` on a till whose authority has not been created yet. Then `/ca.crt`
  /// says so rather than serving nothing.
  final String? rootPem;
}

/// Brings up the QUIC listener with [leaf], or says why it did not.
///
/// Never throws and never stops startup. A till with no WebTransport is a till
/// no browser terminal can reach — the data routes are gone as of 2026-08-05
/// and there is no fallback by the customer's decision — but the desktop till
/// itself sells fine, and that is not a reason to refuse to open a shift. The
/// page such a till serves says why, on `WtUnavailableScreen`.
Future<WebTransportEndpoint?> _startWebTransport(
  WebTransportCredential leaf,
  ListenScope scope,
) async {
  try {
    // Область приходит снаружи, а не пишется здесь константой. `everywhere`
    // стояло тут безусловно, и это было верно ровно для той кассы, у которой
    // терминалы есть: слушателя на `127.0.0.1` отдельное устройство не
    // достанет. Но касса, которой обслуживать некого, открывала при этом порт
    // в сеть магазина без всякого решения оператора.
    //
    // Что стережёт этот сокет, когда он открыт, — не адрес, а сертификат:
    // сессию открывает только тот, кому лист этой кассы предъявлен и принят.
    // Адрес закрывает не подделку, а лишнюю поверхность.
    //
    // Область — перечисление, а не строка `'0.0.0.0'`: строка называла одно
    // семейство, а Windows разрешает `localhost` и имя машины сначала в IPv6,
    // и браузер разговаривал с адресом, на котором никто не слушал. См.
    // `ListenScope`.
    final endpoint = await startWebTransport(credential: leaf, scope: scope);
    if (endpoint is WebTransportUnavailable) {
      talker.info('WebTransport off: ${endpoint.reason}');
      return null;
    }

    final live = endpoint as WebTransportEndpoint;
    talker.info(
      'WebTransport on udp/${live.port}; certificate expires '
      '${live.certificateExpiry.toIso8601String()}',
    );
    // Empty in the ordinary case. A line here means one address family is not
    // served, and the terminal that fails is the one whose name resolved to it
    // — a symptom nobody would connect to this cause without being told.
    if (live.bindFailures.isNotEmpty) {
      talker.info('WebTransport not on: ${live.bindFailures.join('; ')}');
    }
    return live;
  } catch (e) {
    talker.info('WebTransport off: $e');
    return null;
  }
}

/// The TLS context the page is served under, or `null` with the reason logged.
///
/// Separate from [_tillLeaf] because the two fail differently and the log has
/// to tell them apart: "there is no certificate" is a PKI problem, "the TLS
/// layer refused this certificate" is a certificate problem, and one sentence
/// covering both would send whoever reads it to the wrong place.
SecurityContext? _pageContext(WebTransportCredential leaf) {
  final context = pageSecurityContext(leaf);
  if (context is CertificateUnavailable) {
    talker.info('No TLS for the page: ${context.reason}');
    return null;
  }
  return context as SecurityContext;
}

Future<void> _startLocalApi(TerminalServiceChoice terminalService) async {
  try {
    // Где взять страницу. Рабочий каталог установленной кассы — `C:\Program
    // Files\TelePOS`, никакого `build\web` там нет; установщик кладёт бандл
    // рядом с `telepos.exe`, и найти его касса обязана сама, без аргументов.
    // Переопределение остаётся: `--web-dir=` бьёт всё остальное.
    final bundle = resolveWebBundle(
      argument: _webDir,
      define: const String.fromEnvironment('TELEPOS_WEB_DIR'),
      executableDirectory: File(Platform.resolvedExecutable).parent.path,
    );

    // Решение оператора — в журнал, и до первого сокета. Строка отвечает на
    // единственный вопрос, который задают, когда терминал не открывается: эта
    // касса вообще кого-нибудь ждёт? Молчание здесь означало бы, что «порт
    // закрыт» и «сервер не поднялся» выглядят одинаково.
    final scope = terminalService.scope;
    talker.info(switch ((terminalService.enabled, _headless)) {
      // Причина названа, а не только итог: «слушаем все адреса» без неё
      // одинаково выглядит и у кассы, которой это поручил оператор, и у
      // службы без окна, — а чинят эти два состояния по-разному.
      (true, true) =>
        'Касса без окна: её интерфейс — браузер, слушаем все адреса '
            '(${scope.name})',
      (true, false) =>
        'Обслуживание браузерных терминалов включено оператором — слушаем '
            'все адреса (${scope.name})',
      (false, _) =>
        'Обслуживание браузерных терминалов выключено — слушаем только петлю '
            '(${scope.name}). Включается в «Настройки → Браузерные терминалы»',
    });

    // The certificate first: both listeners present it, and the HTTPS one
    // cannot come up at all without it.
    final pki = await _tillLeaf();

    // Корень выписан — попросим установщик начать ему доверять.
    //
    // Не ждём: `schtasks /Run` возвращается сразу, но сам вызов ходит в службу
    // планировщика, а касса не имеет права ждать чужую службу на пути к смене.
    // Ответ в любом случае уедет в журнал.
    if (pki?.rootPem != null) {
      unawaited(
        syncRootTrust().then(
          (outcome) => talker.info('Доверие корню: $outcome'),
        ),
      );
    }

    // WebTransport second, because the HTTPS server has to put its address and
    // certificate hash into the page it serves. If it does not come up, the
    // page is served without them and says so on screen — that is the whole
    // reason the fields are nullable rather than the server refusing to start:
    // a till that would not serve its own page could not even report why.
    final webTransport = pki == null
        ? null
        : await _startWebTransport(pki.leaf, scope);

    final server = ApiServer(
      db: GetIt.I<AppDatabase>(),
      bootstrap: GetIt.I<AppBootstrap>(),
      setup: GetIt.I<SetupRepository>(),
      terminals: GetIt.I<TerminalRepository>(),
      deviceBindings: GetIt.I<DeviceBindingRepository>(),
      // Один реестр сеансов на процесс (задача 9): `SessionRegistry` живёт в
      // get_it синглтоном, и это единственное место на десктопе, откуда
      // `ApiServer` берёт `AuthRepository` — второго вызова, который строил бы
      // ещё одну кассу входа рядом, в дереве нет.
      auth: GetIt.I<AuthRepository>(),
      // Довесок фазы 3/4 закрытия долга, часть Б: тот же синглтон
      // `SessionRegistry`, что несколькими строками выше пары `sessions:`
      // отдали `auth`/`guard` — уборка неиспользуемых терминалов спрашивает
      // про живой сеанс тот же реестр, а не заводит второй источник правды.
      terminalSessions: GetIt.I<SessionRegistry>(),
      // Задача 19 закрытия долга безопасности: тот же синглтон
      // `SessionRegistry`, что и `auth`/`terminalSessions` выше — экран
      // списка сеансов и его отзыв читают и гасят ровно те же живые
      // сеансы, что выдаёт вход.
      sessionAdmin: GetIt.I<SessionRegistry>(),
      // Задача 1 знакомства терминала с кассой: тот же синглтон get_it, что
      // экран кода привязки (следующая задача) мятит через
      // `GetIt.I<PairingInvites>().mint()` — не второй список. Второй список
      // означал бы код, потраченный на одном и оставшийся годным на другом;
      // см. докстринг у `invites` в `ApiServer` и у `PairingInvites` в
      // `pairing_invites.dart`.
      invites: GetIt.I<PairingInvites>(),
      // Задача 14 плана «Продажа с браузерного терминала»: та же кассовая
      // реализация, что стоит под экраном оплаты на десктопе
      // (`service_locator.dart`), а не вторая рядом — иначе повтор,
      // посчитанный памятью одной, был бы неизвестен другой.
      payments: GetIt.I.isRegistered<PaymentService>()
          ? GetIt.I<PaymentService>()
          : null,
      // Задача 21 плана «Полнота продажи»: та же кассовая реализация, что
      // зарегистрирована в контейнере, — резолвится, а не строится заново,
      // тем же приёмом и по тому же доводу, что `payments` выше.
      //
      // Своего состояния у выпускающего нет (счёт обязательства он ищет в
      // базе по роду, а не помнит), поэтому вторая копия не развела бы
      // обязательства по двум счетам — но она развела бы **источник
      // правды**: следующая правка, заведи она в нём память, сломала бы
      // ровно тот путь, который никто не проверяет.
      certificates: GetIt.I.isRegistered<CertificateIssuer>()
          ? GetIt.I<CertificateIssuer>()
          : null,
      // Решение заказчика 2026-09-18: повтор печати слипа с планшета. **Тот
      // же синглтон**, что стоит под кассовым экраном выпуска, — он держит
      // ту же очередь печати; вторая копия печатала бы во вторую очередь, то
      // есть в никуда.
      certificateSlips: GetIt.I.isRegistered<CertificateSlipReprinter>()
          ? GetIt.I<CertificateSlipReprinter>()
          : null,
      // Требование заказчика 2026-09-18: приём аванса с браузерного
      // терминала. Резолвится **тот же синглтон**, что стоит под кассовым
      // диалогом приёма (`CustomerPaymentUseCase` в `service_locator.dart`),
      // — он и есть `PrepaymentIntakeService`, потому что контракт объявлен
      // на самом юзкейсе. Строить вторую реализацию здесь значило бы завести
      // второй путь к деньгам: приём пишет три строки (счёт покупателя, счёт
      // кассы, проводку), и разойтись им негде, пока код один.
      prepaymentIntake: GetIt.I.isRegistered<CustomerPaymentUseCase>()
          ? GetIt.I<CustomerPaymentUseCase>()
          : null,
      // Решение заказчика 2026-09-18, вторая половина: выдача аванса
      // деньгами. **Тот же самый синглтон**, что строкой выше, и это не
      // копирование строки: `CustomerPaymentUseCase` объявлен реализующим
      // оба контракта сразу, и потому приём и выдача ходят в одну и ту же
      // память заявок и в одну и ту же базу. Две регистрации развели бы
      // ключи повторов по двум экземплярам.
      prepaymentRefund: GetIt.I.isRegistered<CustomerPaymentUseCase>()
          ? GetIt.I<CustomerPaymentUseCase>()
          : null,
      // Диагностика оборудования с планшета — план 2026-09-19. **Тот же
      // синглтон**, что стоит под кассовыми вкладками диагностики
      // (`service_locator.dart`), а не вторая копия: копия читала бы вторую
      // очередь печати, то есть показывала бы пустой экран при работающем
      // принтере.
      diagnostics: GetIt.I.isRegistered<HardwareDiagnosticsRepository>()
          ? GetIt.I<HardwareDiagnosticsRepository>()
          : null,
      // Пункт 5 A7 (2026-09-15): тот же замок перебора сертификатов, что
      // стоит под экраном оплаты кассы (`ThrottledPaymentService`,
      // `service_locator.dart`), — один счёт номера на кассу и провод, и
      // срабатывание пишется в журнал безопасности.
      certificateThrottle: GetIt.I<CertificateThrottle>(),
      // Absent on an installation with no Telegram transport — the offline
      // deployment. The endpoints that need it say so rather than pretending
      // there are no backups.
      firstLaunch: GetIt.I.isRegistered<FirstLaunchRepository>()
          ? GetIt.I<FirstLaunchRepository>()
          : null,
      // This machine physically has the devices — plan 2b, task 4: the
      // browser binding (lib/web/main_web.dart) only ever asks this one over
      // the wire, it never enumerates or checks anything itself.
      deviceDiscovery: _localDeviceDiscovery(),
      deviceCheck: _localDeviceCheck(),
      // Задача «сетевые настройки по проводу» (спека 2026-08-24): тем же
      // приёмом, что [_localDeviceDiscovery]/[_localDeviceCheck] выше —
      // резолвится из get_it, не строится заново, чтобы экран настроек и
      // операция провода делили одну реализацию.
      network: _localNetwork(),
      // Задача 10 плана «Продажа с браузерного терминала»: та же кассовая
      // корзина, что стоит под экраном продажи на десктопе
      // (`service_locator.dart` регистрирует `LocalCartService` синглтоном и
      // отдаёт его же под доменным типом), а не вторая рядом — иначе у
      // кассы было бы две корзины и две цепочки уведомлений об одном чеке.
      cart: GetIt.I.isRegistered<CartService>() ? GetIt.I<CartService>() : null,
      // Задача 44: условия правки строки для браузерного терминала — тот же
      // синглтон, что читает экран продажи на десктопе. Резолвится прямо, как
      // `refund` ниже: незаведённая привязка обязана падать при подъёме, а не
      // отказывать кассиру на первом «Редактировать».
      editTerms: GetIt.I<SaleEditTermsReader>(),
      // Задача 45: те же синглтоны, что читают сетка и сканер экрана продажи
      // на десктопе. Резолвятся прямо, как [editTerms]: незаведённая привязка
      // падает при подъёме, а не отказывает кассиру на первом нажатии.
      quickProducts: GetIt.I<QuickProductCatalog>(),
      // Пишущий синглтон (`LocalScannerRulesRepository`), а не читающий:
      // с пункта 11 ревизии 2026-09-19 касса ещё и **записывает** правила
      // по просьбе планшета. Это тот же экземпляр — читатель в
      // `service_locator.dart` зарегистрирован как ссылка на него.
      scannerRules: GetIt.I<ScannerRulesRepository>(),
      // Пункт 11 ревизии 2026-09-19: тот же синглтон, которым спрашивает
      // про партию экран продажи на десктопе. Резолвится прямо, как
      // [quickProducts]: незаведённая привязка обязана падать при подъёме.
      expiryWarning: GetIt.I<ExpiryWarningReader>(),
      // Пункт 12 ревизии 2026-09-19: тот же одиночка, что поднимает счётчик
      // экранов самой кассы. Один на процесс — иначе у кассы было бы две
      // ревизии остатков, и половина рабочих мест не узнавала бы об
      // изменении.
      stockChanges: GetIt.I<StockChanges>(),
      // Задача 19 плана «Продажа с браузерного терминала»: тот же синглтон
      // get_it, что резолвит экран возврата, — не вторая реализация рядом.
      // Резолвится **здесь**, при сборке кассы, а не лениво при первом
      // кадре: граф `LocalRefundService` собирается из трёх юзкейсов, и
      // несобираемость обязана падать при подъёме, где её видно, а не в
      // ответ на первую команду терминала.
      refund: GetIt.I<RefundService>(),
      frontendDirectory: switch (bundle) {
        WebBundleFound(:final directory) => directory,
        WebBundleMissing() => null,
      },
      // Отказ едет к браузеру целиком: страница, открытая на кассе без бандла,
      // назовёт все просмотренные места. Иначе единственным следом остаётся
      // 404, и искать по нему нечего.
      frontendUnavailableReason: switch (bundle) {
        WebBundleFound() => null,
        WebBundleMissing(:final describe) => describe,
      },
      // Та же область, что у слушателя QUIC, и это обязано быть одно значение,
      // а не два совпадающих. Пара уже ломалась порознь: сначала починили QUIC,
      // и тогда обнаружилось, что страница не открывается вовсе — `ERR_FAILED`
      // в браузере, — потому что этот сокет слушал так же узко. Терминалу
      // нужны оба: страницу он берёт здесь, сессию — там.
      scope: scope,
      // What the tablet typed, not what the socket bound. An address the
      // listener bound would tell the browser to open a session with
      // everything.
      publicHost: '${tillNetworkName()}.local',
      webTransportPort: webTransport?.port,
      webTransportFingerprintSha256: webTransport?.certificateFingerprintSha256,
      // Отдаётся только по коду привязки — см. `ApiServer._rootCertificate`.
      rootCertificatePem: pki?.rootPem,
    );
    // `null` when there is no leaf — and then the server refuses by name
    // rather than falling back to plain HTTP. The fallback would look like a
    // working till and a broken wire: the page opens, the screen draws, and
    // `new WebTransport(...)` is not a constructor, because the interface is
    // `[SecureContext]` and an unsecured page does not have it.
    final started = await server.start(
      context: pki == null ? null : _pageContext(pki.leaf),
    );
    if (started is ApiServerUnavailable) {
      talker.info('Local API off: ${started.reason}');
      // Явно, не полагаясь на умолчание синглтона: сервер не поднялся,
      // экран привязки не имеет права думать иначе.
      GetIt.I<ApiServerReachability>().markUnreachable();
      return;
    }
    // Найденный путь И то, откуда он взялся. Один только путь не отвечает на
    // вопрос, который задают, когда терминал показывает не то: касса взяла
    // бандл рядом с собой или подхватила чей-то из рабочего каталога?
    talker.info('Local API on $started (бандл: ${bundle.describe})');
    // Same reasoning as on the QUIC side: an address family that did not come
    // up is the difference between "the terminal cannot open the page" and a
    // cause somebody can act on.
    if (server.bindFailures.isNotEmpty) {
      talker.info('Local API not on: ${server.bindFailures.join('; ')}');
    }

    // Объявление — только у той кассы, которая действительно слушает сеть.
    //
    // Объявить себя по mDNS, слушая одну петлю, значило бы разослать по
    // магазину приглашение на адрес, где никто не ответит: планшет нашёл бы
    // `till-3.local`, открыл бы его и получил отказ соединения — то есть
    // симптом «сеть сломана» вместо верного «эту кассу не просили обслуживать
    // терминалы». Это же и вторая половина решения о поверхности: касса на
    // петле не сообщает сети о своём существовании.
    if (scope == ListenScope.everywhere) {
      await _announce(server, webTransport?.port);
      // Пункт 6 волны правок «касса говорит, что набирать» (2026-08-23):
      // тот же признак, что решает про mDNS двумя строками выше — сервер
      // поднят и виден за пределами этой машины, а не просто «какой-то
      // сокет открыт» (петля тоже сокет). `started` здесь — та же строка,
      // что вернул `server.start()`, `ApiServer.url` дальше не меняется.
      // Экран привязки (`TerminalPairingScreen`) читает это вместо
      // настройки `TerminalServiceChoice` — см. докстринг
      // `ApiServerReachability`, почему настройки для этого гейта мало.
      GetIt.I<ApiServerReachability>().markListening(started as String);
    } else {
      talker.info('mDNS не поднимаем: касса слушает петлю и объявлять нечего');
      // То же самое явно: сервер поднят, но только на петле — экрану
      // привязки нечего показывать, ровно как если бы он не поднялся вовсе.
      GetIt.I<ApiServerReachability>().markUnreachable();
    }

    if (pki != null) _watchAddresses(pki.leaf);

    // Кассовая половина провода поднимается над `server.operations` — одним
    // объектом, собранным из тех же репозиториев, что держит сервер страницы.
    // Собрать здесь второй набор значило бы завести вторую кассу внутри этой,
    // и первым бы сломался подъём, посчитанный дважды.
    //
    // Если WebTransport не поднялся, поднимать нечего. Браузерный терминал в
    // этом случае недоступен вовсе — запасного пути через HTTP больше нет, —
    // и причина уже записана в лог выше и уедет на экран отказа.
    if (webTransport != null) {
      // Один сторож на все слушатели этого запуска: словарь доступа, реестр
      // сеансов и состояние настройки не зависят от того, по какому семейству
      // адресов пришёл запрос.
      final guard = wireGuardForTill(
        db: GetIt.I<AppDatabase>(),
        access: server.access,
        // Один реестр сеансов на процесс (задача 9) — тот же синглтон, что
        // получил `AuthRepository` парой строк выше.
        sessions: GetIt.I<SessionRegistry>(),
        // Круг правки 3 задачи 19: сторож сверяет место сеанса с местом,
        // привязанным к этой QUIC-сессии сейчас. Карта привязок одна на
        // кассу и живёт в `TillOperations` — та же, из которой `auth.login`
        // берёт терминал, а не вторая рядом.
        boundTerminalId: server.operations.terminalForSessionKey,
      );
      // One wire per listener, because a wire holds a `QuicServer` and answers
      // on it: a session opened on the family this one is not bound to would
      // be heard by nobody. `everywhere` is a single socket, so this is one
      // wire in the deployment — the loop is what keeps the loopback scope,
      // where there are two, from silently answering on half of them.
      //
      // Устранено правкой 3 волны закрытия долга безопасности (2026-08-22)
      // (найдено, не устранено предыдущим кругом — пункт 2 фазы 3/4,
      // `TillOperations._sessionTerminals`): rk_quic назначает `sessionId`
      // независимым счётчиком **на каждый `QuicServer`**
      // (`rust/src/transport.rs`, `AtomicU64::new(1)` заводится внутри
      // функции подъёма листенера, не статикой процесса), а
      // `_sessionTerminals` — одна карта на все листенеры разом, потому что
      // `TillOperations` (и она сама) — одна на всё развёртывание. В
      // `loopback`-области (два листенера — IPv4- и IPv6-петля) `sessionId=1`
      // существовал независимо на обоих одновременно, и запись одного могла
      // перезаписать запись другого — та же подмена терминала, которую
      // закрывала задача 10. `listenerId: i` ниже — индекс в этом самом
      // цикле, и `TillWire` (`till_wire.dart`, `_sessionKey`) сдвигает его в
      // старшие биты составного ключа прежде, чем отдать `sessionId`
      // обработчикам и `onSessionClosed`: два листенера с одинаковым сырым
      // `sessionId` теперь дают разные ключи `_sessionTerminals`. В
      // `everywhere` (настоящее развёртывание, один сокет) цикл проходит один
      // раз, `listenerId` остаётся 0, и составной ключ равен сырому — ничего
      // не меняется там, где коллизии и так не было структурно.
      // Задача 21 закрытия долга безопасности: до неё отказ сторожа
      // (`WireDenied`) не оставлял ни единого следа в журнале событий
      // безопасности — см. докстринг `buildWireDeniedJournalHandler`
      // (`lib/backend/security_journal.dart`) про то, откуда он берёт
      // `terminalId` без сеанса.
      final onDenied = buildWireDeniedJournalHandler(
        journal: GetIt.I<SecurityJournal>(),
        resolveTerminal: server.operations.terminalForSessionKey,
      );
      for (final (i, quic) in webTransport.servers.indexed) {
        TillWire(
          quic,
          server.operations.askHandlers,
          watchHandlers: server.operations.watchHandlers,
          runHandlers: server.operations.runHandlers,
          guard: guard,
          // Пункт 2 фазы 3/4 закрытия долга: `TillOperations` держит карту
          // «сессия → терминал, который она завела» и обязана забыть запись,
          // когда сессия закрылась — иначе карта растёт без предела за весь
          // срок жизни кассы.
          onSessionClosed: server.operations.forgetSession,
          onDenied: onDenied,
          listenerId: i,
        ).start();
      }
      talker.info(
        'TillWire on udp/${webTransport.port} '
        '(${webTransport.servers.length} listener(s))',
      );
    }
  } catch (e, st) {
    talker.error('Local API failed to start (ignored)', e, st);
  }
}

/// Начинает следить за тем, не уехал ли адрес из-под выписанного листа.
///
/// Живёт до конца процесса и намеренно никем не останавливается: наблюдатель
/// привязан к листу, лист поднимается один раз за запуск, и остановить его
/// было бы нечему, кроме выхода. Один системный вызов в минуту.
///
/// Пишет `warning`, а не `info`: строка «касса отвечает на адресе, которого нет
/// в её сертификате» означает, что часть терминалов до кассы не дойдёт, и в
/// одном ряду с «mDNS поднялся» ей не место.
void _watchAddresses(WebTransportCredential leaf) {
  CertificateAddressWatch(
    certifiedAddresses: leaf.ipAddresses,
    onChange: (unnamed) {
      if (unnamed.isEmpty) {
        talker.info(
          'Адреса кассы снова покрыты сертификатом (${leaf.subjectAltNames})',
        );
        return;
      }
      talker.warning(
        'Адрес уехал: касса отвечает на ${unnamed.join(", ")}, а её лист '
        'называет ${leaf.subjectAltNames}. Рукопожатие по этим адресам не '
        'состоится — перезапуск кассы перевыпишет лист.',
      );
    },
  ).start();
}

/// Announces this till on the shop network, or says why it did not.
///
/// Failure here never stops the till and never stops the page: the
/// announcement is how a tablet *finds* this machine without anybody typing an
/// address. Where mDNS is filtered — which is a fair number of guest networks
/// — this goes nowhere, and the terminal is reached by address instead. That
/// is the whole reason the sentence goes into the log: a till that stopped
/// being findable looks exactly like a broken network, and gets searched for
/// in the wrong place.
Future<void> _announce(ApiServer server, int? quicPort) async {
  final port = server.boundPort;
  if (port == null) return;

  final outcome = await TillAnnouncement.start(
    name: tillNetworkName(),
    httpsPort: port,
    quicPort: quicPort,
    addresses: await localIPv4Addresses(),
  );
  if (outcome is AnnouncementUnavailable) {
    talker.info('mDNS off: ${outcome.reason}');
    return;
  }

  final announcement = outcome as TillAnnouncement;
  talker.info(
    'mDNS on: ${announcement.hostName} → :$port '
    '(${announcement.addresses.join(", ")})',
  );

  // The name after the probe, when it is not the name that was asked for.
  //
  // A warning rather than a line in the same info message, because it is not
  // information about this till — it is a statement that **another machine on
  // this network already answers to the name this one was configured with**. A
  // tablet looking for `till-3` reaches that other machine, and the operator
  // who set both up is the only person who can fix it.
  if (!announcement.usingRequestedName) {
    talker.warning(
      'mDNS name taken: another host on this network already answers to '
      '"${tillNetworkName()}", so this till announced itself as '
      '"${announcement.instanceName}" instead. A terminal looking for the '
      'configured name will reach the other machine — rename one of them.',
    );
  }
}

/// The till-side [DeviceDiscovery] the wire operation delegates to.
///
/// Resolved from get_it rather than constructed here (plan 2b, task 3): the
/// same interface is now registered in `configureDependencies` for the
/// settings screens' "искать" button, and building a second
/// `DeviceDiscoveryLocal` alongside it would be exactly the parallel path to
/// the same capability plan 2's lessons forbid. `null` (the operation refuses
/// by name and never crashes — see `TillOperations._requireDiscovery`) only if
/// the registration itself did not happen, which does not occur on a real
/// desktop boot; kept as a guard rather than an assumption.
DeviceDiscovery? _localDeviceDiscovery() =>
    GetIt.I.isRegistered<DeviceDiscovery>() ? GetIt.I<DeviceDiscovery>() : null;

/// The till-side [DeviceCheck] the wire operation delegates to — same
/// reasoning as [_localDeviceDiscovery].
///
/// `DeviceCheck` is registered as a *factory* (see `service_locator.dart`),
/// so this resolves one instance and [TillOperations] holds it for its
/// lifetime — identical to what this function did when it constructed one
/// itself, and unchanged in behaviour by the move.
DeviceCheck? _localDeviceCheck() =>
    GetIt.I.isRegistered<DeviceCheck>() ? GetIt.I<DeviceCheck>() : null;

/// The till-side [NetworkRepository] the six `network.*` wire operations
/// delegate to — задача «сетевые настройки по проводу» (спека 2026-08-24),
/// same reasoning as [_localDeviceDiscovery]/[_localDeviceCheck]: resolved
/// from get_it rather than constructed here, so the settings screen's own
/// controller (`network_controller.dart`) and this operation share one
/// `NetworkRepositoryLocal`, not two.
NetworkRepository? _localNetwork() => GetIt.I.isRegistered<NetworkRepository>()
    ? GetIt.I<NetworkRepository>()
    : null;
