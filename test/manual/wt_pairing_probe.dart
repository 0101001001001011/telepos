/// Живая проверка задачи 3 работы «знакомство терминала с кассой»
/// (`.superpowers/sdd/2026-08-23-terminal-enrolment/task-3-brief.md`).
///
/// # Чем это отличается от существующих тестов
///
/// `test/presentation/screens/settings/terminal_pairing_screen_test.dart`
/// уже доказывает, что щелчок по кнопке доходит до настоящего
/// `PairingInvites` (не мока) — щелчок там настоящий, `tester.tap()` бьёт по
/// отрисованному дереву, а не зовёт метод контроллера напрямую. Чего этот
/// тест доказать не может: что код, показанный экраном, действительно
/// принимает **настоящий `ApiServer`**, поднятый на настоящей сети, и что
/// байты, которые он отдаёт по этому коду, — это корень **этой** кассы, а не
/// что-нибудь похожее.
///
/// Этот щуп соединяет оба конца в одном процессе `flutter_tester` (тем же
/// приёмом, что и `wt_stand.dart`): один и тот же экземпляр `PairingInvites`
/// зарегистрирован в `GetIt` (как делает `main.dart`) и передан в `ApiServer`
/// (как делает `main.dart`) — второго списка кодов здесь нет, ровно как и в
/// продакшене. Экран мятит код настоящим щелчком; отдельный `HttpClient`,
/// говорящий по TCP на LAN-адрес этой машины (не на петлю — «другое
/// устройство» из брифа), скачивает по нему корень настоящим HTTPS-запросом.
///
/// # Как проверен срок жизни кода без ожидания 15 минут
///
/// Подмена часов: `PairingInvites` принимает `clock: DateTime Function()`
/// (`lib/backend/pairing_invites.dart:44-49`) — это не тестовая дыра, добавленная
/// щупом, а параметр конструктора, уже существующий в рабочем коде. Здесь он
/// замкнут на переменную `_clockOffset`, которую щуп двигает на 16 минут
/// вперёд **после** того, как код уже помечен просроченным способом,
/// доступным только из этого процесса, — сама проверка просрочки идёт через
/// настоящий HTTP-запрос к настоящему `/ca.crt`, только время для
/// `PairingInvites` — не системные часы. Прямого вызова `redeem()` в обход
/// HTTP здесь нет.
///
/// # Что здесь настоящее, а что нет
///
/// Настоящие: `AppDatabase` (в памяти), `TillCertificates`/`rk_pki` —
/// собственный корень и лист этого запуска, `ApiServer` со своим TLS и
/// `/ca.crt`, `TerminalPairingScreen` — тот же виджет, что видит оператор,
/// `PairingInvites` — тот же класс, тот же экземпляр по обе стороны провода.
/// Подставные: подъём кассы (`_ProbeBootstrap`) и первый запуск
/// (`_ProbeFirstLaunch`) — тем же приёмом и по тем же причинам, что и в
/// `wt_stand.dart` (см. его докстринг); ни экрана, ни `/ca.crt` они не
/// касаются.
///
/// # Две ловушки `testWidgets`, измеренные на этом же щупе
///
/// **Поддельные часы.** `testWidgets` по умолчанию гонит тело теста в зоне с
/// поддельным временем (`pump(duration)` иначе не мог бы идти без настоящего
/// ожидания). Настоящий FFI-вызов в `rk_pki` под этой зоной не завершался
/// никогда — измерено здесь: щуп висел ровно на `webTransportCredential` до
/// принудительного таймаута. Лечится `tester.runAsync(...)`, который выполняет
/// колбэк вне поддельной зоны, в настоящем цикле событий; всё, что трогает
/// `rk_pki`, сокеты или `HttpClient`, обёрнуто им ниже.
///
/// **Подменённый `HttpOverrides`.** `TestWidgetsFlutterBinding` также
/// подменяет `HttpOverrides.global` так, что любой `HttpClient` в наборе
/// тестов отвечает 400 и в сеть не ходит вовсе — измерено здесь же: без
/// явного сброса на `null` все ответы `/ca.crt` были 400 независимо от кода
/// привязки, то есть проверка молчала бы о том, что действительно проверяет.
/// Снимается перед настоящими запросами и возвращается сразу после них.
///
/// # Запуск
///
/// ```
/// PATH=<каталог с rk_pki.dll, sqlite3.dll>;$PATH \
///   flutter test --tags manual --run-skipped test/manual/wt_pairing_probe.dart
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/backend/api_server.dart';
import 'package:telepos/backend/certificate_throttle.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/net/listen_scope.dart';
import 'package:telepos/core/net/till_network_name.dart';
import 'package:telepos/core/settings/terminal_service_settings.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/pki/till_certificates.dart';
import 'package:telepos/data/setup/setup_repository_local.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/terminal_pairing_screen.dart';

void main() {
  testWidgets(
    'живая проверка привязки: экран мятит код настоящим щелчком, /ca.crt '
    'отдаёт корень этой кассы по сети, тратит код один раз и отказывает '
    'просроченному',
    _run,
    tags: 'manual',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Duration _clockOffset = Duration.zero;

Future<void> _run(WidgetTester tester) async {
  // ---- Подъём кассовой половины: та же сборка, что у wt_stand.dart. ----
  //
  // Всё это — вызовы в rk_pki (FFI, отдельный поток нативной библиотеки) и
  // настоящие сокеты. Обёрнуто в `tester.runAsync`: `testWidgets` по
  // умолчанию гонит тело теста в зоне с поддельными часами (нужна для
  // `pump(duration)` без настоящего ожидания), и настоящий FFI/сетевой код
  // под ней зависает насмерть — измерено здесь же: без `runAsync` щуп висел
  // до принудительного таймаута ровно на вызове `webTransportCredential`, ни
  // разу не завершившись. `runAsync` выполняет колбэк вне поддельной зоны, в
  // реальном цикле событий.
  late final AppDatabase db;
  late final String name;
  late final WebTransportCredential leaf;
  late final String root;
  late final PairingInvites invites;
  late final ApiServer server;
  late final String lanAddress;

  await tester.runAsync(() async {
    stdout.writeln('[щуп] checkpoint: db открыта');
    db = AppDatabase(NativeDatabase.memory());
    final pkiDir = Directory.systemTemp.createTempSync(
      'telepos-pairing-probe-pki',
    );
    stdout.writeln('[щуп] checkpoint: TillCertificates.open старт');
    final opened = await TillCertificates.open(
      storeDirectory: pkiDir.path,
      installationId: 'pairing-probe',
      machineId: Platform.localHostname,
    );
    if (opened is CertificateUnavailable) {
      fail('[щуп] сертификата нет: ${opened.reason}');
    }
    final certificates = opened as TillCertificates;

    name = tillNetworkName();
    stdout.writeln(
      '[щуп] checkpoint: TillCertificates.open готово, '
      'webTransportCredential старт',
    );
    final credential = await certificates.webTransportCredential(
      dnsNames: <String>['localhost', '$name.local'],
      ipAddresses: const <String>[],
    );
    if (credential is CertificateUnavailable) {
      fail('[щуп] лист не выписан: ${credential.reason}');
    }
    leaf = credential as WebTransportCredential;

    stdout.writeln(
      '[щуп] checkpoint: webTransportCredential готово, '
      'authorityRootPem старт',
    );
    final rootResult = await certificates.authorityRootPem();
    if (rootResult is! String) {
      fail('[щуп] корня нет: $rootResult');
    }
    root = rootResult;

    // Тот же экземпляр по обе стороны провода — ровно то, что main.dart
    // передаёт и в ApiServer(invites: ...), и на что смотрит экран через
    // GetIt.I<PairingInvites>().mint(). Часы подменены на переменную снаружи,
    // а не на системные — это и есть способ проверить просрочку без
    // ожидания.
    stdout.writeln('[щуп] checkpoint: authorityRootPem готово');
    invites = PairingInvites(clock: () => DateTime.now().add(_clockOffset));

    final journal = SecurityJournal(db.securityEventDao, logger: Talker());
    final sessions = SessionRegistry(journal: journal);

    stdout.writeln('[щуп] checkpoint: ApiServer конструктор старт');
    server = ApiServer(
      db: db,
      bootstrap: _ProbeBootstrap(db),
      setup: LocalSetupRepository(db),
      terminals: LocalTerminalRepository(db),
      deviceBindings: LocalDeviceBindingRepository(
        db,
        BuiltinDeviceProfileCatalog(),
      ),
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
        securityJournal: journal,
      ),
      sessionAdmin: sessions,
      firstLaunch: _ProbeFirstLaunch(),
      deviceDiscovery: null,
      deviceCheck: null,
      // Умолчание продакшена (`main.dart` порт не переопределяет) — экран
      // показывает адрес с этим портом жёстко
      // (`terminal_pairing_screen.dart:95`), и щуп обязан проверить именно
      // его, а не случайный свободный.
      port: 8787,
      scope: ListenScope.everywhere,
      publicHost: '$name.local',
      frontendDirectory: 'build/web',
      invites: invites,
      certificateThrottle: CertificateThrottle(),
      rootCertificatePem: root,
    );

    stdout.writeln('[щуп] checkpoint: ApiServer сконструирован');
    final context = pageSecurityContext(leaf);
    if (context is CertificateUnavailable) {
      fail('[щуп] TLS для страницы нет: ${context.reason}');
    }
    stdout.writeln('[щуп] checkpoint: server.start старт');
    final started = await server.start(context: context as SecurityContext);
    if (started is ApiServerUnavailable) {
      fail('[щуп] страница не поднялась: ${started.reason}');
    }
    stdout.writeln('[щуп] checkpoint: server.start готово: $started');

    // Адрес «другого устройства» — не петля: LAN-адрес этой машины, первый
    // из тех, что не 127.0.0.1/::1.
    stdout.writeln('[щуп] checkpoint: ищу LAN-адрес');
    final found = await _firstLanIPv4();
    if (found == null) {
      fail(
        '[щуп] на этой машине нет ни одного LAN-адреса IPv4 — нечем '
        'изобразить «другое устройство»',
      );
    }
    lanAddress = found;
    stdout.writeln(
      '[щуп] касса слушает ${server.listeningOn.join(", ")} (порт '
      '${server.boundPort}); буду ходить по $lanAddress',
    );
  });
  addTearDown(server.stop);

  // ---- Экран: настоящий виджет, настоящий щелчок. ----
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await TerminalServiceChoice.write(prefs, enabled: true);

  GetIt.I.allowReassignment = true;
  GetIt.I.registerSingleton<PairingInvites>(invites);
  addTearDown(GetIt.I.reset);

  Widget host(Widget child) => ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru')],
      locale: const Locale('ru'),
      home: child,
    ),
  );

  await tester.pumpWidget(host(const TerminalPairingScreen()));
  await tester.pumpAndSettle();

  expect(
    find.byKey(const ValueKey('pairing-mint')),
    findsOneWidget,
    reason: 'обслуживание включено — кнопка обязана быть на экране',
  );

  await tester.tap(find.byKey(const ValueKey('pairing-mint')));
  await tester.pumpAndSettle();

  final codeFinder = find.byKey(const ValueKey('pairing-code'));
  expect(codeFinder, findsOneWidget, reason: 'щелчок не показал код');
  final shownCode = tester.widget<SelectableText>(codeFinder).data!;

  final addressFinder = find.byKey(const ValueKey('pairing-address'));
  final addressText =
      (tester.widget<ListTile>(addressFinder).subtitle! as Text).data!;
  final expiresText = tester.widget<Text>(
    find.byKey(const ValueKey('pairing-expires')),
  );
  stdout.writeln('[щуп] экран показал код   $shownCode');
  stdout.writeln('[щуп] экран показал адрес $addressText');
  stdout.writeln('[щуп] экран показал срок  ${expiresText.data}');
  expect(
    addressText,
    contains('https://$name.local:8787'),
    reason:
        'адрес на экране не совпал с адресом, на котором реально '
        'слушает эта касса',
  );

  // Реальный HTTP/TLS поверх настоящих сокетов — снова вне поддельной зоны
  // `testWidgets`, той же причиной, что и подъём кассы выше.
  await tester.runAsync(() async {
    // `TestWidgetsFlutterBinding` подменяет `HttpOverrides.global` так, что
    // любой `HttpClient` в наборе тестов отвечает 400 и в сеть не ходит —
    // измерено здесь же: без этой строки все ответы ниже были 400 вместо
    // настоящих кодов кассы, независимо от кода привязки. Снимается ровно на
    // время настоящих запросов и возвращается сразу после них.
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;

    // ---- Пункт 2: по коду отдаётся корень — с другого адреса, по-настоящему.
    final client = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    final firstResponse = await _get(
      client,
      lanAddress,
      server.boundPort!,
      invite: shownCode,
    );
    expect(
      firstResponse.statusCode,
      200,
      reason: 'действительный код обязан отдать корень',
    );
    expect(
      firstResponse.headers.value('content-type'),
      'application/x-x509-ca-cert',
    );
    final downloadedPem = firstResponse.body;
    stdout.writeln(
      '[щуп] /ca.crt по коду -> ${firstResponse.statusCode}, '
      '${downloadedPem.length} байт',
    );

    // Главное доказательство пункта «это корень именно этой кассы», способ 1:
    // побайтовое совпадение с тем, что касса сама считает своим корнем
    // (тем же значением, что ушло в rootCertificatePem конструктора выше).
    expect(
      downloadedPem.trim(),
      root.trim(),
      reason: 'скачанный PEM не совпал байт-в-байт с корнем этой кассы',
    );

    // Способ 2, независимый от способа 1 и от самого приложения: настоящий
    // openssl проверяет, что скачанным корнем подтверждается подлинный лист
    // TLS этой же кассы (leaf.chainPem — тот самый сертификат, который сервер
    // только что предъявил в рукопожатии). Если бы /ca.crt отдавал случайный
    // PEM, эта проверка провалилась бы независимо от строкового совпадения
    // выше.
    final verify = await _verifyChainWithOpenssl(
      rootPem: downloadedPem,
      leafPem: leaf.chainPem,
    );
    stdout.writeln('[щуп] openssl verify -> $verify');
    expect(
      verify,
      contains('OK'),
      reason:
          'скачанный корень не подтверждает лист этой кассы — это не её '
          'корень (или openssl недоступен, см. вывод)',
    );

    // ---- Пункт 3: тот же код второй раз не работает. ----
    final secondResponse = await _get(
      client,
      lanAddress,
      server.boundPort!,
      invite: shownCode,
    );
    stdout.writeln('[щуп] тот же код повторно -> ${secondResponse.statusCode}');
    expect(secondResponse.statusCode, 403);
    expect(
      secondResponse.body,
      isNot(contains('BEGIN CERTIFICATE')),
      reason:
          'второй запрос с потраченным кодом не имеет права отдать '
          'корень',
    );

    // ---- Пункт 4: без кода вовсе. ----
    final noCodeResponse = await _get(client, lanAddress, server.boundPort!);
    stdout.writeln('[щуп] без кода -> ${noCodeResponse.statusCode}');
    expect(noCodeResponse.statusCode, 403);
    expect(noCodeResponse.body, isNot(contains('BEGIN CERTIFICATE')));

    // ---- Пункт 5: просроченный код, часы подменены, запрос настоящий. ----
    final expiringInvite = invites.mint();
    stdout.writeln(
      '[щуп] отдельный код для просрочки ${expiringInvite.code}, '
      'истекает ${expiringInvite.expiresAt}',
    );
    _clockOffset = const Duration(minutes: 16);
    final expiredResponse = await _get(
      client,
      lanAddress,
      server.boundPort!,
      invite: expiringInvite.code,
    );
    stdout.writeln(
      '[щуп] тот же код через 16 минут (часы подменены) -> '
      '${expiredResponse.statusCode}',
    );
    expect(expiredResponse.statusCode, 403);
    expect(expiredResponse.body, isNot(contains('BEGIN CERTIFICATE')));

    client.close();
    HttpOverrides.global = previousOverrides;
    stdout.writeln('[щуп] ГОТОВО — все пять пунктов проверены живьём');
  });
}

class _Response {
  const _Response(this.statusCode, this.body, this.headers);
  final int statusCode;
  final String body;
  final HttpHeaders headers;
}

Future<_Response> _get(
  HttpClient client,
  String host,
  int port, {
  String? invite,
}) async {
  final uri = Uri(
    scheme: 'https',
    host: host,
    port: port,
    path: 'ca.crt',
    queryParameters: invite == null ? null : {'invite': invite},
  );
  final request = await client.getUrl(uri);
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  return _Response(response.statusCode, body, response.headers);
}

Future<String?> _firstLanIPv4() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
    includeLinkLocal: false,
  );
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (!address.isLoopback) return address.address;
    }
  }
  return null;
}

/// Пишет обе PEM во временные файлы и зовёт настоящий `openssl verify`.
///
/// Не подменяет проверку своей — если `openssl` недоступен на машине,
/// возвращается строка с этим фактом дословно, а не выдуманное «OK».
Future<String> _verifyChainWithOpenssl({
  required String rootPem,
  required String leafPem,
}) async {
  final dir = Directory.systemTemp.createTempSync('telepos-pairing-verify');
  final rootFile = File('${dir.path}/root.pem')..writeAsStringSync(rootPem);
  final leafFile = File('${dir.path}/leaf.pem')..writeAsStringSync(leafPem);
  try {
    final result = await Process.run('openssl', [
      'verify',
      '-CAfile',
      rootFile.path,
      leafFile.path,
    ]);
    final out = '${result.stdout}'.trim();
    final err = '${result.stderr}'.trim();
    return [
      if (out.isNotEmpty) out,
      if (err.isNotEmpty) err,
      'exitCode=${result.exitCode}',
    ].join(' | ');
  } on ProcessException catch (e) {
    return 'openssl недоступен: $e';
  } finally {
    dir.deleteSync(recursive: true);
  }
}

class _ProbeBootstrap implements AppBootstrap {
  _ProbeBootstrap(this._db);
  final AppDatabase _db;

  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async {
    onProgress(0.5, 'Проверка базы данных...');
    try {
      await _db.customSelect('SELECT 1 AS test').getSingle();
    } catch (_) {
      return AppInitStatus.databaseFailure;
    }
    onProgress(1.0, 'Готово');
    return AppInitStatus.success;
  }
}

class _ProbeFirstLaunch implements FirstLaunchRepository {
  @override
  Future<FirstLaunchResult> determineResult() async =>
      FirstLaunchResult.newPosNoBackups;

  @override
  Future<List<FoundBackup>> findAvailableBackups() async => const [];

  @override
  Future<bool> restoreFromBackup(
    FoundBackup backup, {
    BootProgress? onProgress,
  }) async =>
      throw StateError('у щупа нет копий, из которых можно восстановиться');

  @override
  Future<bool> loadGlobalData({BootProgress? onProgress}) async =>
      throw StateError('у щупа нет организации, данные которой можно взять');

  @override
  Future<String> startNewPos() async => 'pairing-probe-pos-key';
}
