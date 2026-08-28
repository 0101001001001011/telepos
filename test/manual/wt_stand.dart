/// Стенд для сквозной проверки провода в настоящем браузере на **отдельном
/// устройстве** (задача 18 плана
/// `docs/internal/superpowers/plans/2026-08-04-webtransport-browser-terminal.md`).
///
/// # Зачем отдельная программа, а не запуск кассы
///
/// Настоящая касса открывает базу магазина —
/// `%APPDATA%\TelePOS\TelePOS\db\store.db`, — и подменить этот путь переменной
/// окружения нельзя: `path_provider` на Windows берёт его через
/// `SHGetKnownFolderPath`, а не из `APPDATA` (измерено 2026-08-05: касса,
/// запущенная с подменённым `APPDATA`, открыла настоящую базу). Проверять
/// провод на работающем магазине — значит писать в него из проверки, и цена
/// ошибки здесь не «красный набор», а испорченные данные заказчика.
///
/// Поэтому стенд держит базу **в памяти**: `NativeDatabase.memory()`. Файла
/// нет вовсе, портить нечего.
///
/// # Что здесь настоящее, а что подставное
///
/// Настоящие: `AppDatabase` со всеми миграциями, `LocalSetupRepository`,
/// `LocalTerminalRepository`, `LocalDeviceBindingRepository`, **`ApiServer`**
/// со своим TLS и выдачей корня по коду привязки, `TillOperations` (их строит
/// сам `ApiServer`), `TillWire`, `TillAnnouncement` и `startWebTransport` с
/// настоящим листом от `rk_pki` и настоящим слушателем QUIC от `rk_quic`. То
/// есть весь кассовый конец провода — тот самый код, который поднимает
/// `lib/main.dart`, и поднимается он здесь теми же вызовами и с теми же
/// значениями.
///
/// Подставные ровно два, и оба — не про провод:
///
/// * [_StandBootstrap] — подъём кассы. Настоящий (`AppDomainDelegate`) тянет
///   граф DI Flutter, которого у голого процесса Dart нет; тот же приём уже
///   применён в `bin/telepos_backend.dart`.
/// * [_StandFirstLaunch] — первый запуск. Настоящий ходит в Telegram за
///   копиями. Стенд отвечает `newPosNoBackups`, и это не выдумка результата:
///   у базы в памяти копий действительно нет.
///
/// # Почему страница отдаётся по HTTPS и на всех адресах обоих семейств
///
/// До 2026-08-05 стенд отдавал страницу по обычному HTTP и слушал петлю, и
/// проверял тем самым только петлю. `WebTransport` в браузере помечен
/// `[SecureContext]`: на `http://127.0.0.1` конструктор есть по исключению для
/// петли, на `http://192.168.1.210:8787` его **нет вовсе**. Значит зелёный
/// проход на петле ничего не говорил о работе с отдельного устройства — там
/// включается совсем другая ветка условий.
///
/// Поэтому стенд теперь поднимает ровно то, что поднимает касса: `ApiServer` с
/// `scope: ListenScope.everywhere`, TLS-контекстом от `pageSecurityContext` и
/// `publicHost: '<имя>.local'`. Отката на HTTP нет и здесь — он выглядел бы как
/// работающая касса при сломанном проводе.
///
/// `everywhere` — это оба семейства адресов, а не `0.0.0.0`, как стояло до
/// 2026-08-06. Одного IPv4 не хватает: Windows разрешает `localhost` и имя
/// машины сначала в IPv6, и браузер уходил туда, где никто не слушал. Стенд с
/// одним IPv4 при этом выглядел исправным, потому что проверяли его `curl`, а
/// `curl` выбирает семейство иначе.
///
/// # Почему терминал может идти и по имени, и по адресу
///
/// До 2026-08-05 лист выписывался только с именами (`localhost`,
/// `<имя>.local`), и это было не решение, а нехватка: `iPAddress` появился в
/// `rk_pki` только в 0.4.0. Стенд поэтому проверял ровно один путь — через
/// mDNS, — а второй падал по устройству, а не из-за ошибки в проводе.
///
/// Теперь лист выписывается и на адреса (`certificateAddresses`), и стенд
/// печатает содержимое SAN. Это и есть проверка запасного пути: `curl -k
/// https://<адрес>:<порт>/` должен отдать страницу без единой записи в
/// `/etc/hosts`. В сетях, где режут многоадресную рассылку — а это измерено у
/// заказчика 2026-08-05, запрос mDNS уходил и назад не приходило ничего, —
/// адрес остаётся единственным работающим путём.
///
/// # Управление состоянием снаружи
///
/// Отдельный слушатель на **петле** — `TELEPOS_STAND_CONTROL`, по умолчанию
/// 8799. Он не часть провода и намеренно не виден сети: его дело — изменить
/// состояние кассы, **не трогая браузер**, а без такой возможности проверить
/// цель всей работы («касса говорит первой») нечем. Изменение, вызванное самим
/// браузером, доказывало бы только вопрос-ответ.
///
/// Добавить эти пути в `ApiServer` значило бы проверять не тот сервер, который
/// уедет заказчику, поэтому они живут на своём сокете.
///
/// * `GET /stand/terminal?name=…` — завести терминал.
/// * `GET /stand/state` — терминалы и число живых подписок провода.
/// * `GET /stand/configure?company=…&cashbox=…` — назвать магазин и кассу
///   (нужно и для `SetupState.configured`, и отдельно — для входа, см.
///   следующий раздел).
/// * `GET /stand/seed-cashiers` — завести двух кассиров с известными PIN, см.
///   раздел после следующего.
/// * `GET /stand/invite` — намять код привязки, которым терминал заберёт корень.
///
/// # `stand/configure` задаёт и `cashbox` — иначе вход отказывает не тем
///
/// `SetupState.configured` (`setup_state_source.dart`) смотрит только на
/// `ThisPos.companyName` — это то, что мастер настройки пишет первым, и
/// единственное, что `stand/configure` заполняло до живой проверки браузером
/// (найдено ею же 2026-08-21): страница с непустым `companyName` и заведённым
/// кассиром доходит до `#/login`, экран входа честно показывает кассиров, но
/// сам вход отказывает — не PIN-ом, а раньше: «касса не настроена». Причина —
/// отдельная проверка, ничего общего с `SetupState` не имеющая:
/// `TerminalRepositoryLocal.self()` (`terminal_repository_local.dart:39-52`)
/// требует непустое `ThisPos.cashBoxName` и осознанно отказывается выдумывать
/// имя-плейсхолдер — `ensureSelf()` потом нашёл бы выдуманную строку и
/// никогда не заменил бы её на настоящую. Экран входа зовёт `self()`, чтобы
/// узнать личность терминала (см. довод задачи 11 в `progress.md` про
/// ленивое добывание), и без `cashBoxName` эта проверка отказывает раньше,
/// чем PIN вообще спрашивается.
///
/// Поэтому `stand/configure` теперь пишет и `cash_box_name` — с тем же
/// умолчанием (`'POS'`), что берёт мастер настройки, если поле не задано
/// (`setup_repository_local.dart`, `cashBoxName = ... : 'POS'`). Больше
/// `SetupState` не выдумывается: `hasUsers`/`configured` остаются ровно тем,
/// чем были, — стенд не притворяется пройденным мастером целиком, только
/// снимает конкретный отказ, за которым нет ни одной цифры PIN.
///
/// # Кассиры для входа заводятся командой, а не сами по себе
///
/// База в памяти пуста, а входить на ней не на кого: `Users` — таблица,
/// которую наполняет только мастер настройки (`LocalSetupRepository`) или
/// экран управления кассирами, и стенд до задачи 13б не звал ни то, ни
/// другое. Автоматически завести кассиров при подъёме было бы проще одним
/// вызовом раньше в файле, но это стёрло бы саму проверку, ради которой
/// существует `watchActiveUsers()` (`user_dao.dart`): «заведённый на кассе
/// пользователь обязан появиться на терминале в момент заведения, а не
/// когда экран догадается перечитать список». Если кассир уже лежит в базе
/// до того, как открылась страница, эта проверка не проверена — экран мог
/// бы читать список один раз при загрузке и всё равно показать его. Тот же
/// довод уже применён к `stand/configure`: и там состояние меняет отдельная
/// команда на петле, а не подъём стенда, — здесь то же решение для второй
/// половины `SetupState` (`hasUsers`).
///
/// Значит правильный порядок проверки — открыть браузер **раньше**, чем
/// звать `stand/seed-cashiers`, и увидеть, что кассиры появляются на экране
/// живьём, без перезагрузки страницы.
///
/// # Почему это `flutter test`, а не `dart run`
///
/// Измерено 2026-08-05: голый процесс Dart не собирается вовсе —
/// `LocalSetupRepository` тянет `LocalProperties`, тот `shared_preferences`,
/// тот `package:flutter`, а `dart:ui` на этой платформе не существует. (Тем же
/// дефектом, судя по цепочке, болен и `bin/telepos_backend.dart`.) `flutter
/// test` запускает `flutter_tester` — Dart VM с `dart:ui`, `dart:io` и
/// `dart:ffi` разом, — и это ровно то, что стенду нужно: он одновременно
/// открывает сокеты, грузит две нативных библиотеки и строит репозитории
/// кассы.
///
/// Тег `manual` в `dart_test.yaml` пропускает стенд в обычном наборе: он не
/// заканчивается никогда, и попав в набор — повесил бы его.
///
/// # Запуск
///
/// ```
/// PATH=<каталог с rk_quic.dll, rk_pki.dll, sqlite3.dll>;$PATH \
/// TELEPOS_STAND_WEB=build/web TELEPOS_STAND_PORT=8787 \
///   flutter test --tags manual --run-skipped test/manual/wt_stand.dart
/// ```
///
/// Нативные библиотеки берутся из сборки кассы
/// (`build/windows/x64/runner/Release`): ни `flutter test`, ни `dart run`
/// нативную часть плагина не собирают, и взяться ей рядом со стендом неоткуда.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:talker/talker.dart';

import 'package:telepos/backend/api_server.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/net/listen_scope.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/pki/certificate_addresses.dart';
import 'package:telepos/data/pki/till_certificates.dart';
import 'package:telepos/data/setup/setup_repository_local.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_announcement.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/transport/webtransport_endpoint.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/core/net/till_network_name.dart';

/// Имя и PIN кассира, чей вход проверяется набором цифр — и чей PIN,
/// набранный неверно, обязан отказать названной причиной, а не тишиной.
const _cashierWithPinName = 'Кассир С PIN';
const _cashierWithPin = '1234';

/// Имя кассира, чей вход проверяется без единой набранной цифры — кнопкой
/// «Войти без PIN». Эта ветка `LocalAuthRepository.login()` терялась при
/// переезде проверки на кассу и была восстановлена только задачей 13а,
/// найдена через тот же стенд (см. `progress.md` в директории задачи), так
/// что живая проверка этого кассира — не формальность.
const _cashierNoPinName = 'Кассир Без PIN';

/// Кассир для задачи 8: право `settings.hardware` у него отнято явной
/// записью в `UserPermissions`, а не отсутствием роли-владельца. Без него
/// главное доказательство работы («касса отказывает по праву, а не по
/// экрану») нечем проверить живьём: оба кассира из `seed-cashiers` не имеют
/// строк в `UserPermissions` вовсе, а `UserPermissionDao.getAllowedKeys`
/// на пустом наборе строк возвращает **все** права — значит оба уже
/// авторизованы на `deviceCheck`, и отличить отказ по праву от отказа по
/// сеансу через них нельзя. Отдельная команда, а не третий в
/// `seed-cashiers`, — по тому же доводу, что уже применён к этому файлу:
/// заводить фикстуру, которую не проверяет ни один из путей `seed-cashiers`,
/// значило бы засорять список кассиров на обычном экране входа.
const _restrictedCashierName = 'Кассир Без Права На Оборудование';
const _restrictedCashierPin = '9999';

/// Перепроверка «второго порядка» закрытия долга безопасности (2026-08-22):
/// `settings.users` отнято явной строкой — отдельно от
/// `_restrictedCashierName` выше, у которого отнято `settings.hardware`.
/// `/sessions` (коммит `a9cb0a3`) заведён под `settings.users`
/// (`permission_keys.dart:336`), а не под `settings.hardware` — проверка
/// гейта не тем правом доказала бы не то же самое.
const _noUsersCashierName = 'Кассир Без Права На Сеансы';
const _noUsersCashierPin = '5555';

void main() {
  test(
    'стенд провода: касса в памяти, HTTPS на сети, слушатель QUIC и mDNS',
    _runStand,
    // Стенд не заканчивается: он живёт, пока в него смотрит браузер.
    timeout: Timeout.none,
    tags: 'manual',
  );
}

Future<void> _runStand() async {
  final env = Platform.environment;
  final httpsPort = int.tryParse(env['TELEPOS_STAND_PORT'] ?? '') ?? 8787;
  final controlPort = int.tryParse(env['TELEPOS_STAND_CONTROL'] ?? '') ?? 8799;
  final webDir = env['TELEPOS_STAND_WEB'] ?? 'build/web';

  // База в памяти. Ни одного файла — см. доку файла о том, почему это не
  // удобство, а условие задачи.
  final db = AppDatabase(NativeDatabase.memory());

  final terminals = LocalTerminalRepository(db);

  // Хранилище сертификатов — во временном каталоге: удостоверяющий центр
  // стенда не имеет права попасть в тот же каталог, что у настоящей кассы,
  // иначе стенд перевыпустил бы её лист.
  final pkiDir = Directory.systemTemp.createTempSync('telepos-wt-stand-pki');
  final opened = await TillCertificates.open(
    storeDirectory: pkiDir.path,
    installationId: 'wt-stand',
    machineId: Platform.localHostname,
  );
  if (opened is CertificateUnavailable) {
    fail('[стенд] сертификата нет: ${opened.reason}');
  }
  final certificates = opened as TillCertificates;

  // Имя берётся тем же вызовом, что у кассы: имя в листе, имя в объявлении и
  // имя в документе обязаны быть одним значением, а не тремя совпадающими.
  final name = tillNetworkName();

  // Адреса берутся тем же вызовом, что у кассы, и по той же причине, что имя:
  // адрес в листе и адрес в объявлении обязаны быть одним значением. Список
  // считается один раз и уходит в оба места.
  final addresses = await certificateAddresses();

  final credential = await certificates.webTransportCredential(
    dnsNames: <String>['localhost', '$name.local'],
    ipAddresses: addresses,
  );
  if (credential is CertificateUnavailable) {
    fail('[стенд] лист не выписан: ${credential.reason}');
  }
  final leaf = credential as WebTransportCredential;

  final root = await certificates.authorityRootPem();

  // Широко, а не петля: терминал — отдельное устройство, и слушателя на
  // 127.0.0.1 он не достанет. Стережёт этот сокет не адрес, а сертификат.
  //
  // `everywhere`, а не `0.0.0.0`: имена машины разрешаются СНАЧАЛА в IPv6, и
  // на Windows `localhost` — это `::1`. Слушатель только на IPv4 при этом
  // молчит, и браузер получает QUIC_NETWORK_IDLE_TIMEOUT с нулём
  // расшифрованных пакетов — то есть он слал и не получил ничего. Измерено
  // 2026-08-06: по адресу IPv4 сессия поднимается, по имени и по localhost —
  // нет.
  final endpoint = await startWebTransport(
    credential: leaf,
    scope: ListenScope.everywhere,
  );
  if (endpoint is WebTransportUnavailable) {
    fail('[стенд] слушатель QUIC не поднялся: ${endpoint.reason}');
  }
  final wt = endpoint as WebTransportEndpoint;

  // Журнал событий безопасности — задача 22 закрытия долга безопасности:
  // до этой правки стенд не заводил `SecurityJournal` вовсе, и живая
  // проверка «отказ сторожа оставляет запись» не могла бы состояться —
  // `SessionRegistry`/`LocalAuthRepository`/`TillWire.onDenied` просто не
  // на что было бы записывать. Тот же класс, что и `main.dart`
  // (`getIt<SecurityJournal>()`), собранный тем же вызовом.
  final journal = SecurityJournal(db.securityEventDao, logger: Talker());

  // Один реестр на весь стенд: его же читает `WireGuard` ниже. Второй
  // экземпляр значил бы, что провод проверяет сеансы там, где `LocalAuthRepository`
  // их не заводит, — и настоящий вход на стенде отказывал бы «сеанс неизвестен».
  final sessions = SessionRegistry(journal: journal);

  final server = ApiServer(
    db: db,
    bootstrap: _StandBootstrap(db),
    setup: LocalSetupRepository(db),
    terminals: terminals,
    deviceBindings: LocalDeviceBindingRepository(
      db,
      BuiltinDeviceProfileCatalog(),
    ),
    // Настоящий `LocalAuthRepository`, как и весь остальной кассовый конец
    // этого стенда — база в памяти пуста, так что срок бездействия остаётся
    // умолчанием `SessionRegistry` (`ThisPosDao.authSettings` отдало бы то же
    // самое 30 минут для установки, где ещё не было мастера).
    auth: LocalAuthRepository(
      db: db,
      sessions: sessions,
      throttle: LoginThrottle(),
      securityJournal: journal,
    ),
    // Задача 22 закрытия долга безопасности (живая проверка): до этой правки
    // стенд не отдавал `SessionAdmin` вовсе, и `auth.sessions`/
    // `auth.sessionRevoke` отказывали `no_session_registry` независимо от
    // права и сеанса — `TillOperations._requireSessionAdmin()` бросает
    // раньше, чем дело доходит до самого отзыва (`till_operations.dart`).
    // Найдено этой же живой проверкой (пункт 2 брифа не мог бы состояться
    // без него): `main.dart` передаёт `sessionAdmin: GetIt.I<SessionRegistry>()`,
    // стенд — нет, хотя `SessionRegistry` этот контракт уже реализует
    // (`implements ... SessionAdmin`).
    sessionAdmin: sessions,
    firstLaunch: _StandFirstLaunch(),
    // Железа у голого процесса Dart нет, и операции поиска/проверки отвечают
    // названной причиной, а не выдумывают пустой результат.
    deviceDiscovery: null,
    deviceCheck: null,
    port: httpsPort,
    // `everywhere`, а не `0.0.0.0`, по той же причине, что и у слушателя QUIC:
    // имена машины и `localhost` на Windows разрешаются СНАЧАЛА в IPv6, и
    // сервер на одном IPv4 туда просто не отвечает. Дефект парный — измерено
    // 2026-08-06: сперва молчал QUIC, а после его починки перестала
    // открываться и сама страница, потому что она слушала так же узко.
    scope: ListenScope.everywhere,
    publicHost: '$name.local',
    frontendDirectory: webDir,
    webTransportPort: wt.port,
    webTransportFingerprintSha256: wt.certificateFingerprintSha256,
    rootCertificatePem: root is String ? root : null,
    // Пункт 3 волны правок «касса говорит, что набирать» (2026-08-23):
    // `invites` стал обязательным доводом — сам список этому стенду не
    // важен, только код по `server.invites.mint()` ниже, из того же
    // экземпляра, что проверяет `/ca.crt`.
    invites: PairingInvites(),
  );

  final context = pageSecurityContext(leaf);
  if (context is CertificateUnavailable) {
    fail('[стенд] TLS для страницы нет: ${context.reason}');
  }
  final started = await server.start(context: context as SecurityContext);
  if (started is ApiServerUnavailable) {
    fail('[стенд] страница не поднялась: ${started.reason}');
  }

  // Кассовая половина провода — над операциями самого сервера, а не над вторым
  // набором репозиториев: второй набор был бы второй кассой внутри этой.
  // По проводу на каждый слушатель: провод держит один `QuicServer` и на нём
  // же отвечает. При `everywhere` слушатель один, но перебор — то, что не даёт
  // стенду молча отвечать на половине сокетов, если область слушания поменяют.
  // То же, чем главная касса проверяет провод (`lib/main.dart`): второй
  // сервер, который отвечал бы без проверки, доказывал бы, что проверка не
  // на проводе, а в одной точке его сборки, — и в этом весь смысл того, что
  // сторож живёт внутри `TillWire`, а не декоратором над картами.
  final guard = wireGuardForTill(
    db: db,
    access: server.access,
    sessions: sessions,
  );
  // Тот же обработчик, что и `main.dart`: отказ сторожа пишет запись в
  // журнал, не только в консоль стенда. Без него живая проверка «отказ
  // сторожа оставил запись» проверяла бы стенд, а не проверенный код.
  final onDenied = buildWireDeniedJournalHandler(
    journal: journal,
    resolveTerminal: server.operations.terminalForSessionKey,
  );
  final wires = [
    for (final quic in wt.servers)
      TillWire(
        quic,
        server.operations.askHandlers,
        watchHandlers: server.operations.watchHandlers,
        runHandlers: server.operations.runHandlers,
        guard: guard,
        onDenied: onDenied,
      )..start(),
  ];
  final wire = wires.first;

  final announced = await TillAnnouncement.start(
    name: name,
    httpsPort: server.boundPort!,
    quicPort: wt.port,
    addresses: addresses,
  );

  final control = await shelf_io.serve(
    _standControl(terminals, wire, server, db, sessions),
    InternetAddress.loopbackIPv4,
    controlPort,
  );

  stdout
    ..writeln('[стенд] страница   $started')
    // Из самих сокетов, а не из строки. Прежняя строка была написана руками,
    // говорила «0.0.0.0» и продолжала это говорить после того, как слушатель
    // переехал на `::` — то есть врала ровно про ту величину, ради которой её
    // и читают.
    ..writeln(
      '[стенд] слушает    '
      '${server.listeningOn.join(", ")} (порт ${server.boundPort})',
    )
    ..writeln('[стенд] бандл      $webDir')
    ..writeln(
      '[стенд] QUIC       udp/${wt.port} на ${wt.servers.length} сокете(ах)',
    )
    ..writeln('[стенд] отпечаток  ${wt.certificateFingerprintSha256}')
    ..writeln('[стенд] лист до    ${wt.certificateExpiry.toIso8601String()}')
    // Из выписанного листа, а не из того, что просили: расхождение между
    // «просили» и «выписано» — единственное, ради чего эта строка нужна.
    ..writeln('[стенд] SAN листа  ${leaf.subjectAltNames}')
    ..writeln('[стенд] объявлено  ${addresses.join(", ")}')
    ..writeln(
      '[стенд] mDNS       '
      '${announced is TillAnnouncement ? announced.hostName : announced}',
    )
    ..writeln('[стенд] корень     ${root is String ? "есть" : root}')
    ..writeln('[стенд] управление http://127.0.0.1:${control.port}/stand/state')
    ..writeln('[стенд] готов')
    // Инструкция человеку, который проверяет вход, — печатается, чтобы
    // проверяющий не открывал этот файл: адрес, кассиры и ожидаемый
    // результат уже здесь. Порядок шагов 2 и 3 нарочно такой (браузер
    // открывается ДО seed-cashiers): иначе никто не увидит, появляются ли
    // кассиры на экране входа сами, без перезагрузки, — см. доку файла о
    // том, зачем seed-cashiers — команда, а не часть подъёма.
    ..writeln('[стенд]')
    ..writeln('[стенд] === проверка входа живьём ===')
    ..writeln(
      '[стенд] 1. настроить магазин И кассу (если ещё не настроены) — без '
      '"cashbox" вход откажет раньше PIN: curl -k '
      '"http://127.0.0.1:${control.port}/stand/configure?company=Магазин&cashbox=POS"',
    )
    ..writeln(
      '[стенд] 2. открыть в браузере https://$name.local:${server.boundPort}/ '
      '(или https://<адрес>:${server.boundPort}/ — адреса выше) — ДО шага 3. '
      'Сертификат самоподписанный: браузер спросит, продолжить ли — да.',
    )
    ..writeln(
      '[стенд] 3. завести кассиров: curl -k '
      '"http://127.0.0.1:${control.port}/stand/seed-cashiers" — оба должны '
      'появиться на уже открытом экране входа сами, без обновления страницы',
    )
    ..writeln(
      '[стенд] 4. кассир «$_cashierWithPinName», PIN $_cashierWithPin — '
      'верный PIN обязан пустить на дом терминала; любой другой PIN обязан '
      'назвать причину «неверный PIN», а не промолчать и не зависнуть',
    )
    ..writeln(
      '[стенд] 5. кассир «$_cashierNoPinName» — выбрать его и войти, не '
      'набрав ни одной цифры («Войти без PIN»): обязан пустить без пароля',
    )
    ..writeln(
      '[стенд] неверный PIN — это ответ кассы: экран остаётся на /login и '
      'называет причину. Если вместо этого страница вовсе не открылась, '
      'зависла без ответа или показала ошибку сети — это обрыв провода '
      '(TLS/QUIC), а не отказ входа, и это другая, более серьёзная находка.',
    );

  // Не заканчивается по своей воле: стенд живёт, пока его не остановят снаружи.
  // `Completer`, который никто не завершает, — самый честный способ это
  // сказать; `Future.delayed` на большое число врал бы о существовании предела.
  await Completer<void>().future;
}

/// Управление стендом: изменить состояние кассы, не трогая браузер.
///
/// Отдельный слушатель на петле, а не путь в `ApiServer`: сервер страницы
/// обязан остаться ровно тем, что уедет заказчику, и добавить в него путь ради
/// проверки значило бы проверять не его.
Handler _standControl(
  TerminalRepository terminals,
  TillWire wire,
  ApiServer server,
  AppDatabase db,
  SessionRegistry sessions,
) {
  return (Request request) async {
    switch (request.url.path) {
      case 'stand/terminal':
        // Задача 6 плана «знакомство терминала с кассой»: этот вызов не
        // проходит по проводу — `terminals` здесь `LocalTerminalRepository`
        // напрямую (тем же приёмом, что и десктопная касса), а гейт
        // `EnrolmentAccess`/код привязки живёт в `TillOperations`, которую
        // этот путь целиком минует. Код здесь поэтому не нужен и не
        // передаётся — тем же обоснованием, каким `self()` его не спрашивает
        // никогда.
        final name = request.url.queryParameters['name'] ?? 'Терминал';
        final terminal = (await terminals.register(name: name)).terminal;
        stdout.writeln('[стенд] заведён терминал #${terminal.id} «$name»');
        return _json({'id': terminal.id, 'name': terminal.name});

      case 'stand/state':
        final rows = await terminals.list();
        return _json({
          'terminals': [
            for (final t in rows) {'id': t.id, 'name': t.name},
          ],
          // Число живых подписок — наблюдаемая величина самого провода:
          // подписка, пережившая свой экран, иначе не видна ничем.
          'liveSubscriptions': wire.liveSubscriptions,
        });

      // Меняет то, на что подписан экран мастера: `setup.state` собирается из
      // `ThisPosEntries` и `Users` (см. `watchSetupStateOf`), и завести
      // терминал его не трогает. `updates:` здесь обязателен — без него drift
      // не подаст сигнал, подписка промолчит, и «касса говорит первой»
      // осталось бы непроверенным по причине, не имеющей отношения к проводу.
      //
      // `cash_box_name` пишется тем же вызовом, что и `company_name`, хотя
      // `SetupState` его не читает вовсе. Читает его отдельно
      // `TerminalRepositoryLocal.self()` — и без него живая проверка входа
      // 2026-08-21 упёрлась в отказ «касса не настроена» раньше, чем
      // спрашивался PIN, при полностью «настроенном» по `SetupState`
      // состоянии. См. докстринг файла, раздел про `cashbox`, — там разобрано
      // подробно, почему это не то же самое требование.
      case 'stand/configure':
        final company = request.url.queryParameters['company'] ?? 'Магазин';
        final cashbox = request.url.queryParameters['cashbox'] ?? 'POS';
        final changed = await db.customUpdate(
          'UPDATE this_pos_entries '
          'SET company_name = ?, cash_box_name = ? WHERE r_id = 1',
          variables: [
            Variable.withString(company),
            Variable.withString(cashbox),
          ],
          updates: {db.thisPosEntries},
        );
        if (changed == 0) {
          await db.customInsert(
            'INSERT INTO this_pos_entries (r_id, company_name, cash_box_name) '
            'VALUES (1, ?, ?)',
            variables: [
              Variable.withString(company),
              Variable.withString(cashbox),
            ],
            updates: {db.thisPosEntries},
          );
        }
        stdout.writeln(
          '[стенд] касса настроена: магазин «$company», касса «$cashbox»',
        );
        return _json({'companyName': company, 'cashBoxName': cashbox});

      // Заводит ровно тех двух кассиров, что нужны для проверки входа —
      // не больше: третий (например, владелец с полным набором прав) не
      // нужен ни одному из двух путей, которые нужно пройти живьём (задача
      // 13б), а заводить фикстуру, которую никто не проверит, значило бы
      // засорять список кассиров на экране входа.
      //
      // Пароль заводится тем же вызовом, что и рабочий код
      // (`PinCredential.create` — см. `setup_repository_local.dart` и
      // `user_management_screen.dart`), а не руками собранной строкой: иначе
      // проверка PIN проверяла бы свой собственный формат, а не формат,
      // который реально пишет касса.
      case 'stand/seed-cashiers':
        final withPinId = await db.userDao.createCashier(
          name: _cashierWithPinName,
          passwordEnc: PinCredential.create(_cashierWithPin),
        );
        final noPinId = await db.userDao.createCashier(
          name: _cashierNoPinName,
          passwordEnc: null,
        );
        // Задача 14: `createCashier` не пишет ни одной строки прав, и до
        // переворота (задача 16) пустая таблица читается как «разрешено
        // всё» — то, чем оба кассира здесь исправно и были. После
        // переворота то же самое пустое множество читалось бы как
        // «разрешено ничего», и `stand/seed-restricted-cashier` перестал бы
        // что-либо доказывать (см. докстринг `_restrictedCashierName`):
        // его отказ на `deviceCheck` стал бы неотличим от отказа обоих
        // кассиров здесь. Оба заводятся тем же вызовом, что и рабочий код
        // (`setPermissions`), с полным набором — это и есть «обычный» их
        // роли из письма задачи: доступно всё, включая `settings.hardware`,
        // в отличие от `_restrictedCashierName` ниже.
        await db.userPermissionDao.setPermissions(withPinId, {
          for (final key in PermissionKeys.allPermissions) key: true,
        });
        await db.userPermissionDao.setPermissions(noPinId, {
          for (final key in PermissionKeys.allPermissions) key: true,
        });
        stdout.writeln(
          '[стенд] заведены кассиры: '
          '#$withPinId «$_cashierWithPinName» (PIN $_cashierWithPin), '
          '#$noPinId «$_cashierNoPinName» (без PIN)',
        );
        return _json({
          'withPin': {
            'id': withPinId,
            'name': _cashierWithPinName,
            'pin': _cashierWithPin,
          },
          'noPin': {'id': noPinId, 'name': _cashierNoPinName},
        });

      // Задача 8 (живая проверка авторизации): кассир с явно отнятым
      // `settings.hardware`. Отдельная команда — см. докстринг
      // `_restrictedCashierName` о том, почему не третья строка в
      // `seed-cashiers`.
      case 'stand/seed-restricted-cashier':
        final id = await db.userDao.createCashier(
          name: _restrictedCashierName,
          passwordEnc: PinCredential.create(_restrictedCashierPin),
        );
        // Задача 14: одна строка `settingsHardware = false` доказывала
        // «отказ по праву» только пока пустая таблица читалась как
        // «разрешено всё» (единственная строка тогда неявно оставляла
        // разрешёнными все остальные ключи). После переворота (задача 16)
        // это чтение меняется, и то же единственное «false» перестало бы
        // отличаться от кассира вовсе без строк — оба получили бы отказ на
        // любом праве, а не именно на `settings.hardware`. Поэтому здесь
        // явно заводится полный набор минус один ключ — тем же вызовом
        // (`setPermissions`), что и рабочий код, — а не запись в обход
        // таблицы.
        await db.userPermissionDao.setPermissions(id, {
          for (final key in PermissionKeys.allPermissions)
            key: key != PermissionKeys.settingsHardware,
        });
        stdout.writeln(
          '[стенд] заведён кассир без права: '
          '#$id «$_restrictedCashierName» (PIN $_restrictedCashierPin, '
          'settings.hardware = false)',
        );
        return _json({
          'id': id,
          'name': _restrictedCashierName,
          'pin': _restrictedCashierPin,
          'deniedPermission': PermissionKeys.settingsHardware,
        });

      // Перепроверка «второго порядка» закрытия долга безопасности
      // (2026-08-22): кассир с явно отнятым `settings.users`, отдельная
      // команда по тому же доводу, что и `stand/seed-restricted-cashier` —
      // см. докстринг `_noUsersCashierName`.
      case 'stand/seed-no-users-cashier':
        final noUsersId = await db.userDao.createCashier(
          name: _noUsersCashierName,
          passwordEnc: PinCredential.create(_noUsersCashierPin),
        );
        await db.userPermissionDao.setPermissions(noUsersId, {
          for (final key in PermissionKeys.allPermissions)
            key: key != PermissionKeys.settingsUsers,
        });
        stdout.writeln(
          '[стенд] заведён кассир без права: '
          '#$noUsersId «$_noUsersCashierName» (PIN $_noUsersCashierPin, '
          'settings.users = false)',
        );
        return _json({
          'id': noUsersId,
          'name': _noUsersCashierName,
          'pin': _noUsersCashierPin,
          'deniedPermission': PermissionKeys.settingsUsers,
        });

      // Задача 22 закрытия долга безопасности (живая проверка): срок
      // бездействия по умолчанию — 30 минут, живой проверке ждать их не
      // на чем. `SessionRegistry.idleTimeout` не `final` (тем же приёмом,
      // каким `AuthSettingsScreen` меняет его на настоящей кассе, см.
      // докстринг поля) — здесь та же мутация, только с петли, а не с
      // экрана. Действует немедленно на следующий `mint`/`lookup`.
      case 'stand/set-idle-seconds':
        final seconds =
            int.tryParse(request.url.queryParameters['value'] ?? '') ?? 1800;
        sessions.idleTimeout = Duration(seconds: seconds);
        stdout.writeln(
          '[стенд] срок бездействия сеанса выставлен: ${seconds}s',
        );
        return _json({'idleTimeoutSeconds': seconds});

      // Задача 22 закрытия долга безопасности (живая проверка): дословный
      // журнал безопасности — доказательство того, что отказ сторожа
      // оставил запись, и того, что в ней нет секрета, читается тем же
      // способом, каким его писал рабочий код (`SecurityEventDao.findAll`),
      // а не собранным заново разбором файла базы.
      case 'stand/security-events':
        final rows = await db.securityEventDao.findAll();
        return _json({
          'events': [
            for (final row in rows)
              {
                'id': row.id,
                'occurredAtEpochMs': row.occurredAtEpochMs,
                'userId': row.userId,
                'terminalId': row.terminalId,
                'eventType': row.eventType,
                'outcome': row.outcome,
                'correlationId': row.correlationId,
              },
          ],
        });

      case 'stand/invite':
        final invite = server.invites.mint();
        stdout.writeln('[стенд] код привязки ${invite.code}');
        return _json({
          'code': invite.code,
          'expiresAt': invite.expiresAt.toIso8601String(),
        });

      default:
        return Response.notFound('');
    }
  };
}

Response _json(Object body) => Response.ok(
  jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Подъём кассы для стенда: открыть базу и убедиться, что она отвечает.
///
/// Настоящий `AppDomainDelegate` тянет граф DI Flutter, которого у голого
/// процесса Dart нет. Отчитаться успехом за работу, которой не было, значило
/// бы соврать терминалу о состоянии кассы, поэтому здесь отчёт ровно о том,
/// что действительно проверено. Тот же приём — в `bin/telepos_backend.dart`.
class _StandBootstrap implements AppBootstrap {
  _StandBootstrap(this._db);

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

/// Первый запуск для стенда.
///
/// Копий действительно нет: база пустая и в памяти, транспорта Telegram у
/// голого процесса Dart тоже нет. `newPosNoBackups` — не выдумка удобного
/// ответа, а то, чем этот первый запуск и является; заставка на нём уходит в
/// мастер настройки, то есть на экран, который браузерная сборка умеет
/// показать.
class _StandFirstLaunch implements FirstLaunchRepository {
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
      throw StateError('у стенда нет копий, из которых можно восстановиться');

  @override
  Future<bool> loadGlobalData({BootProgress? onProgress}) async =>
      throw StateError('у стенда нет организации, данные которой можно взять');

  @override
  Future<String> startNewPos() async => 'stand-pos-key';
}
