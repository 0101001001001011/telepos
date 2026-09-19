import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';

import 'package:telepos/backend/api_server.dart';
import 'package:telepos/backend/certificate_throttle.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/setup/setup_repository_local.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';

/// Serves the TelePOS page on its own, without the desktop shell.
///
/// # Что оно уже не делает, и чем это заменено
///
/// Оно поднимает [ApiServer], а тот с 2026-08-05 отдаёт только страницу: все
/// четырнадцать маршрутов `/api/*` сняты, данные едут по WebTransport. Слушателя
/// QUIC этот процесс не поднимает — значит открытая им страница честно покажет
/// «сессии нет» и ничего больше. Для сквозной проверки провода в браузере есть
/// стенд `test/manual/wt_stand.dart`: он поднимает базу в памяти, `TillWire` и
/// настоящий слушатель QUIC рядом со страницей.
///
/// # И ещё: под `dart run` оно, судя по всему, не собирается
///
/// Измерено 2026-08-05 на однотипном файле: `LocalSetupRepository` тянет
/// `LocalProperties` → `shared_preferences` → `package:flutter` → `dart:ui`,
/// которого у голого процесса Dart нет. Записано здесь, а не исправлено:
/// чинить точку входа, у которой не осталось задачи, значит чинить не то.
///
/// # Почему теперь нужны `--cert` и `--key`
///
/// Страница отдаётся по HTTPS и только по нему: `WebTransport` в браузере
/// помечен `[SecureContext]`, и на незащищённой странице его конструктора нет
/// вовсе. Своего удостоверяющего центра у этого процесса нет — `rk_pki` живёт
/// в кассе, — поэтому лист сюда передают файлами. Без них процесс говорит, чего
/// ему не хватает, и заканчивается: подняться по обычному HTTP значило бы
/// отдать страницу, на которой провод не заработает никогда.
///
/// Usage:
///   dart run bin/telepos_backend.dart [--port 8787] [--db path] [--web dir]
///                                     --cert leaf.pem --key leaf.key
Future<void> main(List<String> args) async {
  final port = int.tryParse(_arg(args, '--port') ?? '') ?? 8787;
  final dbPath = _arg(args, '--db') ?? '.dev/telepos-dev.sqlite';
  final webDir = _arg(args, '--web') ?? 'build/web';
  final certPath = _arg(args, '--cert');
  final keyPath = _arg(args, '--key');
  final fresh = args.contains('--fresh');

  final context = _context(certPath, keyPath);
  if (context == null) {
    stderr.writeln(
      '[backend] нужны --cert и --key: страница отдаётся только по HTTPS, '
      'иначе браузер не даст WebTransport и провод не поднимется',
    );
    exit(2);
  }

  _bindSqlite();

  final file = File(dbPath);
  await file.parent.create(recursive: true);
  if (fresh && file.existsSync()) {
    file.deleteSync();
    stdout.writeln('[backend] removed existing database at $dbPath');
  }

  final db = AppDatabase(NativeDatabase(file));

  // Read once, here, at till assembly — same rule as `lib/main.dart`: the
  // idle timeout is a point setting, and re-reading it on every login would
  // change the lifetime of sessions already live. `SessionRegistry` and
  // `LoginThrottle` are built here rather than in DI because this entry
  // point has no DI at all — every other repository below is built the same
  // way, on the spot.
  final authSettings = await db.thisPosDao.authSettings();
  final auth = LocalAuthRepository(
    db: db,
    sessions: SessionRegistry(
      idleTimeout: Duration(minutes: authSettings.sessionIdleMinutes),
    ),
    throttle: LoginThrottle(),
  );

  final server = ApiServer(
    db: db,
    bootstrap: _DevBootstrap(db),
    setup: LocalSetupRepository(db),
    terminals: LocalTerminalRepository(db),
    // Коды привязки — чистый Dart, FFI им не нужен, поэтому здесь они
    // настоящие, а не отсутствующая возможность. Экземпляр заводится прямо
    // тут, а не берётся из GetIt, потому что этот процесс поднимает ровно
    // один `ApiServer`; в приложении он приходит доводом из графа зависимостей
    // именно затем, чтобы второй список нельзя было завести молчанием.
    invites: PairingInvites(),
    // Голый процесс без контейнера и без журнала — замок без записи; оплаты
    // здесь нет, и проверять сертификаты ему нечем (`payments_unavailable`).
    certificateThrottle: CertificateThrottle(),
    deviceBindings: LocalDeviceBindingRepository(
      db,
      BuiltinDeviceProfileCatalog(),
    ),
    auth: auth,
    // No Telegram transport in a plain Dart process, so no backups to offer.
    // The operations that need one refuse by name.
    firstLaunch: null,
    // No hardware in a plain Dart process either — DeviceDiscoveryLocal/
    // DeviceCheckLocal need flutter_libserialport/flutter_blue_plus/the
    // printer drivers, none of which this entry point builds. The two
    // operations that need them refuse by name instead of crashing or
    // inventing an empty result (план 2b, задача 4).
    deviceDiscovery: null,
    deviceCheck: null,
    // Задача «сетевые настройки по проводу» (спека 2026-08-24): тем же
    // приёмом, что deviceDiscovery/deviceCheck выше — `NetworkRepositoryLocal`
    // нужен только `dart:io`, но этот процесс не заводит DI-контейнер вовсе
    // (нет service_locator.dart), так что резолвить его неоткуда; операции
    // сети отказывают названной причиной вместо падения.
    network: null,
    port: port,
    frontendDirectory: webDir,
  );

  final started = await server.start(context: context);
  if (started is ApiServerUnavailable) {
    stderr.writeln('[backend] не поднялся: ${started.reason}');
    exit(1);
  }
  stdout.writeln('[backend] listening on $started');
  stdout.writeln('[backend] database $dbPath');
  stdout.writeln('[backend] frontend  $webDir');

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\n[backend] stopping');
    await server.stop();
    await db.close();
    exit(0);
  });
}

/// A plain Dart process does not get the sqlite3 library that
/// `sqlite3_flutter_libs` bundles into a Flutter build, so point the loader at
/// the copy that build produced.
void _bindSqlite() {
  if (!Platform.isWindows) return;

  const candidates = [
    'build/windows/x64/plugins/sqlite3_flutter_libs/Release/sqlite3.dll',
    'build/windows/x64/plugins/sqlite3_flutter_libs/Debug/sqlite3.dll',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) {
      open.overrideFor(
        OperatingSystem.windows,
        () => DynamicLibrary.open(File(path).absolute.path),
      );
      return;
    }
  }
  stderr.writeln(
    '[backend] sqlite3.dll not found — run `flutter build windows` once so '
    'the plugin produces it.',
  );
}

/// Читает лист из файлов. `null` — нечего читать или прочитанное отвергнуто.
SecurityContext? _context(String? certPath, String? keyPath) {
  if (certPath == null || keyPath == null) return null;
  try {
    return SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(certPath)
      ..usePrivateKey(keyPath);
  } on Object catch (error) {
    stderr.writeln('[backend] лист отвергнут слоем TLS: $error');
    return null;
  }
}

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}

/// Boot for the standalone dev backend: opens the database and checks it
/// answers, and nothing else.
///
/// The shipped product uses AppDomainDelegate, which also loads currency,
/// licence and background jobs — all of which need the Flutter DI graph this
/// process does not build. Reporting success here would claim work that did not
/// happen, so this reports only what it actually verified.
class _DevBootstrap implements AppBootstrap {
  _DevBootstrap(this._db);

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
