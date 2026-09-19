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
/// * `GET /stand/configure?company=…&cashbox=…&pos=…` — назвать магазин, кассу
///   и её номер (нужно и для `SetupState.configured`, и отдельно — для входа,
///   см. следующий раздел; номер — для всего, что знает про деньги).
/// * `GET /stand/seed-cashiers` — завести двух кассиров с известными PIN, см.
///   раздел после следующего.
/// * `GET /stand/invite` — намять код привязки, которым терминал заберёт корень.
/// * `GET /stand/seed-product?ucode=…&price=…` — завести товар с ценой; нужен
///   живой проверке возврата без чека (`refund.addProduct` берёт цену из
///   каталога).
/// * `GET /stand/print-duplicate?receiptNo=…&posId=…` — напечатать дубликат
///   чека из истории тем же составителем и той же службой, какими печатает
///   касса. Нужна для сверки лент 58/80 мм одним и тем же чеком.
/// * `GET /stand/printer?address=…&port=…&width=58|80` — привязать чековый
///   принтер кассы к эмулятору ESC/POS и собрать по привязке драйвер. Без
///   этой двери печать отвечает «на этом терминале не настроен чековый
///   принтер»: экран настроек оборудования настраивает рабочее место
///   терминала, а принтер привязан к **кассе**.
/// * `GET /stand/open-shift?hoursAgo=…` — открыть смену; без неё
///   `refund.complete` отказывает `shift_not_open`. `hoursAgo=25` открывает
///   её задним числом — иначе просроченная смена (`ShiftAgeRule`, сутки)
///   недостижима вовсе.
/// * `GET /stand/close-shift` — закрыть открытую смену: вторая половина
///   пути «закройте смену на кассе».
/// * `GET /stand/seed-cash-account` — денежный счёт кассы и ссылка на него.
///   Без него возврат завершается успешно, но **денег не двигает**: «платежей
///   0» (находка живого прогона 2026-09-06, см. докстринг у самой команды).
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
/// # …и свой номер кассы — иначе не работает ничто, знающее про деньги
///
/// Третье поле, `this_pos_entries.id`, добавлено живой проверкой возврата
/// 2026-09-06. Оно было пусто на стенде всегда, а `ThisPosDao.requireId`
/// на пустом бросает `TillNotConfigured` — политика «ноль не подставляется
/// нигде». Значит **любая** операция провода, знающая про деньги, отвечала
/// здесь `till_not_configured`: все шесть возврата
/// (`LocalRefundService._posId`) и корзина (`LocalCartService._posId`, тот
/// же приём). Продать или вернуть на стенде было нельзя никогда — и
/// заметить это можно было только позвав операцию, ровно как и обрезанную
/// сборку кассы.
///
/// Значение по умолчанию `1` — не выдумка: его же подставляет мастер
/// настройки (`ThisPosDao.insertInitialConfig`, `int posId = 1`).
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

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show InsertMode, Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:rk_pki/rk_pki.dart' as rk_pki;
import 'package:rk_quic/rk_quic.dart' as rk_quic;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:talker/talker.dart';

import 'package:telepos/backend/api_server.dart';
import 'package:telepos/backend/bundle_caching.dart';
import 'package:telepos/data/repositories/scanner_rules_repository_impl.dart';
import 'package:telepos/data/repositories/batch_repository_impl.dart';
import 'package:telepos/data/repositories/wms_config_repository_impl.dart';
import 'package:telepos/data/sale/local_expiry_warning.dart';
import 'package:telepos/data/stock/local_stock_changes.dart';
import 'package:telepos/data/usecases/wms/batch_tracking_use_case_impl.dart';
import 'package:telepos/data/usecases/wms/wms_config_use_case_impl.dart';
import 'package:telepos/data/sale/local_quick_product_catalog.dart';
import 'package:telepos/backend/certificate_throttle.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/net/listen_scope.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/network/network_repository_local.dart';
import 'package:telepos/data/pki/certificate_addresses.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart'
    show FiscalQueueStore, OfflineQueueingProvider;
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/data/pki/till_certificates.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_service_impl.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/data/discount/local_discount_policy.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_sale_edit_terms.dart';
import 'package:telepos/data/services/currency_service_impl.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/payment/local_certificate_slip_reprinter.dart';
import 'package:telepos/data/usecases/payment/customer_payment_use_case_impl.dart';
import 'package:telepos/data/payment/qr_payment_desk.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/refund/local_refund_service.dart';
import 'package:telepos/data/refund/local_refund_tender_gateway.dart';
import 'package:telepos/data/setup/setup_repository_local.dart';
import 'package:telepos/app/di/hardware_module.dart'
    show buildReceiptPrinterManager;
import 'package:telepos/app/di/print_module.dart' show registerPrintQueue;
import 'package:telepos/data/diagnostics/local_hardware_diagnostics.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/data/sale/sale_receipt_composer.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/print/receipt_paper_width_source.dart'
    show paperWidthOptionKey;
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_announcement.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/transport/webtransport_endpoint.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/can_sale_be_refunded_use_case_impl.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show PaymentService, PaymentType;
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/payment_intent.dart' show QrIntentStatus;
import 'package:telepos/domain/payment/payment_kind.dart'
    show SystemPaymentKindIds, SystemPaymentKinds;
import 'package:telepos/domain/payment/qr_provider_settings.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain
    show Terminal;
import 'package:telepos/domain/terminal/terminal.dart'
    show paymentTypesFromNames;
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/core/net/till_network_name.dart';

import 'stand_hardware_recorder.dart';
import 'support/stand_ports.dart';

import '../helpers/discount_authority.dart';

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
  // Один журнал на весь стенд — тот же экземпляр уезжает в `SecurityJournal`
  // ниже, в корзину и в возврат: два `Talker` значили бы два потока записей
  // об одной кассе. Обе ветви завели его своей строкой в разных местах
  // функции; при слиянии остался один, самый ранний.
  final logger = Talker();
  final journal = SecurityJournal(db.securityEventDao, logger: logger);

  // Один реестр на весь стенд: его же читает `WireGuard` ниже. Второй
  // экземпляр значил бы, что провод проверяет сеансы там, где `LocalAuthRepository`
  // их не заводит, — и настоящий вход на стенде отказывал бы «сеанс неизвестен».
  final sessions = SessionRegistry(journal: journal);

  // Возврат — задача 19 плана «Продажа с браузерного терминала». Собирается
  // здесь **из тех же трёх юзкейсов**, что и `service_locator.dart`
  // (`LocalRefundService(db, logger, initiation, refunds, canBeRefunded)`),
  // а не подставным двойником: стенд обязан поднимать ту же кассу, что и
  // `lib/main.dart`, иначе живая проверка меряет обрезок.
  //
  // Довод «голый Dart не соберёт `LocalRefundService`», записанный в
  // докстринге довода `refund:` у `ApiServer`, верен для
  // `bin/telepos_backend.dart` и **неверен** для стенда: все три юзкейса
  // просят ровно `AppDatabase` и `Talker`, и оба здесь уже есть. Проверено
  // чтением их конструкторов, а не предположено.
  //
  // `RefundProductService` в `GetIt` — не удобство стенда, а сегодняшняя
  // форма продукта: `RefundUseCaseImpl.complete` достаёт его из `GetIt`
  // сам (`refund_use_case_impl.dart`), и без регистрации завершение
  // возврата упало бы внутри транзакции. Тем же приёмом и по тому же
  // доводу это делает `test/backend/refund_shift_change_test.dart`.
  GetIt.I.registerSingleton<RefundProductService>(
    RefundProductServiceImpl(db: db, logger: logger),
  );
  // Каталог профилей и привязки устройств — переменными: их же читает дверь
  // принтера (`stand/printer`) и ширина ленты при каждой печати.
  final deviceCatalog = BuiltinDeviceProfileCatalog();
  final deviceBindings = LocalDeviceBindingRepository(db, deviceCatalog);

  // Дорога байтов чека к принтеру — та же, что на кассе, и собрана теми же
  // вызовами, что `service_locator.dart`.
  //
  // # Почему это пришлось собирать явно
  //
  // Продукт ищет здесь всё в `GetIt`, и ищет **в момент печати**:
  // `PrintSubmission.identify` спрашивает `TerminalRepository` и
  // `AppDatabase` (терминал, касса и смена — владельцы задания, И29),
  // `ReceiptPrintServiceImpl` берёт шаблон из `AppDatabase`, а ширину —
  // из привязки принтера через `TerminalRepository` +
  // `DeviceBindingRepository` + `DeviceProfileCatalog`. Без регистраций
  // печать не падала бы: `identify` бросил бы, и чек стал бы `rejected` с
  // причиной «некому сказать, с какого терминала задание». То есть стенд
  // снова показал бы правдоподобный ответ вместо чека.
  //
  // `PrinterManager` здесь не регистрируется: его строит дверь
  // `stand/printer` из привязки — ровно как `hardware_module.dart` строит
  // его из привязки, прочитанной при старте кассы. До двери принтера у
  // стенда нет, и очередь честно отвечает «на этом терминале не настроен
  // чековый принтер».
  GetIt.I
    ..registerSingleton<AppDatabase>(db)
    ..registerSingleton<Talker>(logger)
    ..registerSingleton<TerminalRepository>(terminals)
    ..registerSingleton<DeviceBindingRepository>(deviceBindings)
    ..registerSingleton<DeviceProfileCatalog>(deviceCatalog);
  registerPrintQueue(GetIt.I);

  // Железо кассы — записывающими заглушками, а не `null`. Довод целиком —
  // в докстринге `stand_hardware_recorder.dart`; коротко: при `null` касса
  // выходит из фискализации, печати и ящика **молча**, и продажа выглядит
  // напечатанной и фискализованной, не напечатав ничего. Заглушки не
  // фискализуют — но они записывают, **чем** касса позвала свой порт, и
  // подмену чека тогда видно.
  //
  // Печать с 2026-09-18 — исключение и настоящая: журнал стенда стоит
  // **поверх** `ReceiptPrintServiceImpl`, и байты уходят в эмулятор ESC/POS
  // по адресу из привязки. Довод — в докстринге [RecordingPrinter].
  final hardware = StandHardwareJournal();
  final standPrinter = RecordingPrinter(
    hardware,
    inner: ReceiptPrintServiceImpl(logger: logger),
  );

  // Выпускающий сертификаты — переменной, а не выражением внутри `ApiServer`:
  // его же зовёт `stand/seed-certificate` на петле. Второй экземпляр не
  // сломал бы ничего (своего состояния у него нет), но искать потом, какой
  // из двух выписал бумажку, — работа на пустом месте.
  //
  // Слипы — тем же доводом, что в `service_locator.dart`: без него выпуск не
  // печатает ничего (приёмка 2026-09-17, `RecordingCertificateSlipPrinter`).
  final standSlips = RecordingCertificateSlipPrinter(hardware);
  final standCertificates = LocalCertificateIssuer(
    db: db,
    logger: logger,
    slips: standSlips,
  );

  // Фискальный порт стенда: запись довода ВСЕГДА, настоящий оператор — по
  // команде. Довод — в докстринге [StandFiscalPort].
  final standFiscalQueue = RecordingFiscalQueueStore(hardware);
  final standFiscal = StandFiscalPort(
    journal: hardware,
    db: db,
    logger: logger,
    queue: standFiscalQueue,
  );

  final refund = LocalRefundService(
    db: db,
    logger: logger,
    initiation: RefundInitiationUseCaseImpl(db: db, logger: logger),
    // Шлюз безнала и слипы — теми же доводами, что `service_locator.dart`:
    // без шлюза возврат карты и QR «вернуть нечем», без слипов новая бумажка
    // не выходит на бумагу.
    refunds: RefundUseCaseImpl(
      db: db,
      logger: logger,
      // Фискальный возврат — тем же портом стенда, каким фискализуется
      // продажа ниже (`fiscal: standFiscal` у `LocalPaymentService`): журнал
      // стенда обязан показывать, **чем** касса позвала оператора на
      // возврате. Приёмка 2026-09-17: довода не существовало, возврат искал
      // службу в `GetIt`, не находил и молча обходился без документа.
      fiscal: standFiscal,
      tenders: LocalRefundTenderGateway(
        db: db,
        logger: logger,
        qr: QrPaymentDesk(db: db, logger: logger),
      ),
      slips: standSlips,
    ),
    canBeRefunded: CanSaleBeRefundedUseCaseImpl(db: db, logger: logger),
    // Ящик — тем же записывающим портом, что у оплаты ниже: приёмка
    // 2026-09-17 нашла по журналу стенда, что после возврата с наличной
    // частью `paymentDrawerPort` не появляется вовсе, — и это был дефект
    // продукта, а не стенда. Запись в журнале теперь и есть доказательство.
    drawer: () => recordingDrawer(hardware),
    // Свой узкий контракт кассы, а не метод принтера продажи, — так же, как
    // собирает его боевой DI.
    printer: RecordingRefundPrinter(hardware),
  );

  // Корзина стенда — переменной, а не выражением внутри `ApiServer`: её же
  // читает подготовка чека для оплаты ниже, и второй экземпляр значил бы
  // вторую цепочку уведомлений об одном чеке (докстринг `TillOperations._cart`).
  final standCart = LocalCartService(
    db: db,
    logger: logger,
    initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
    deferred: DeferredSaleServiceImpl(db: db, logger: logger),
    rounding: SaleRoundOptionUseCaseImpl(),
    findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
    searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
  );

  // Раскладка оплаты — переменной, а не выражением внутри `ApiServer`: её
  // род проверяет `_assertStandHoldsQrSetup` ниже, а `ApiServer` оплату
  // наружу не отдаёт вовсе.
  // Один счётчик ревизии остатков на стенд — пункт 12 ревизии 2026-09-19.
  // Его поднимает оплата, его же отдаёт подписка `stock.revision`.
  final standStockChanges = LocalStockChanges();

  final standPayments = LocalPaymentService(
    db: db,
    checkout: LocalSaleCheckoutService(db: db, cart: standCart, logger: logger),
    sale: SaleUseCaseImpl(db: db, logger: logger),
    logger: logger,
    fiscal: standFiscal,
    // Достижима только по отказу оператора — см. `stand/hardware-mode`.
    fiscalQueue: standFiscalQueue,
    printer: standPrinter,
    // Свой довод `drawer`, а не `standPrinter.openCashDrawer`: касса зовёт
    // именно его, и перепутанная сборка видна только по тому, какая из двух
    // записей появилась в журнале.
    drawer: () => recordingDrawer(hardware),
    stockChanges: standStockChanges,
  );

  final server = ApiServer(
    db: db,
    bootstrap: _StandBootstrap(db),
    setup: LocalSetupRepository(db),
    terminals: terminals,
    // Тот же экземпляр, что читает ширину ленты при печати, — не второй
    // рядом: привязка, сохранённая дверью принтера, обязана быть видна
    // экрану настроек оборудования по проводу, и наоборот.
    deviceBindings: deviceBindings,
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
    // Тот же реестр, что и `sessionAdmin`/`auth` выше — ровно то, что делает
    // `main.dart` (`terminalSessions: GetIt.I<SessionRegistry>()`). Без него
    // уборка неиспользуемых строк `terminals` на стенде не работала вовсе и
    // молча: `_pruneUnusedTerminals` выходит первой же строкой при
    // `_sessions == null`. Отсюда и запись 2026-08-24 про «стенд копит
    // терминалы между сценариями» (`testing-notes.md`) — её причиной был не
    // продукт, а недособранный стенд.
    terminalSessions: sessions,
    firstLaunch: _StandFirstLaunch(),
    // Железа у голого процесса Dart нет, и операции поиска/проверки отвечают
    // названной причиной, а не выдумывают пустой результат.
    deviceDiscovery: null,
    deviceCheck: null,
    // Настоящий `NetworkRepositoryLocal`, тот же класс, что резолвит
    // `main.dart` из get_it. На обычной Windows демона `telepos-sysd` нет, и
    // операции `network.*` отказывают **изнутри репозитория** — «демон не
    // найден», продуктовый ответ, ровно тот же, что увидит кассир. До этой
    // правки стенд передавал `null`, и они отказывали `no_network_module` —
    // отказ **сборки стенда**, которого на настоящей кассе не бывает
    // никогда. Разница видна только тому, кто читает причину, и именно
    // поэтому её никто не видел.
    network: NetworkRepositoryLocal(),
    // Шесть операций возврата. Собран выше — см. довод там.
    refund: refund,
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
    // Корзина — задача 13. Без неё все двадцать операций `sale.*` отвечали бы
    // «нет службы», и живая проверка мерила бы обрезок кассы, а не кассу:
    // ровно та беда, которую ветвь стенда нашла на возврате
    // (`docs/internal/superpowers/reports/2026-09-06-browser-terminal-sale/
    // task-stand-report.md`, раздел 1). Собрана теми же пятью юзкейсами,
    // что
    // и боевой DI (`service_locator.dart:788`), а не подделками — иначе стенд
    // проверял бы сам себя.
    cart: standCart,
    // Условия правки строки — задача 44, по требованию того же сторожа:
    // без них `sale.editTerms` отвечала бы на стенде `no_sale_module`, и
    // живая проверка скидки с терминала мерила бы обрезок кассы.
    // Быстрые товары и правила сканера — задача 45, по требованию того же
    // сторожа `stand_matches_till_test`: без них сетка и сканер на стенде
    // отвечали бы `no_sale_module`.
    quickProducts: LocalQuickProductCatalog(db: db),
    scannerRules: LocalScannerRulesRepository(db),
    // «Партия просрочена?» — пункт 11 ревизии 2026-09-19, по требованию того
    // же сторожа `stand_matches_till_test`. Без неё `sale.expiryWarning`
    // отвечала бы на стенде `no_sale_module`, и живая проверка
    // предупреждения о просрочке мерила бы обрезок кассы. Собрана теми же
    // двумя юзкейсами, что и боевой DI, а не подделками.
    expiryWarning: LocalExpiryWarning(
      batches: BatchTrackingUseCaseImpl(BatchRepositoryImpl(db)),
      wmsConfig: WmsConfigUseCaseImpl(WmsConfigRepositoryImpl(db)),
    ),
    // «Остатки изменились» — пункт 12 ревизии 2026-09-19, по требованию
    // того же сторожа. **Тот же экземпляр**, что отдан `LocalPaymentService`
    // ниже: два завели бы на стенде две ревизии остатков, и живая проверка
    // «продал с планшета — обновилось на соседнем экране» мерила бы
    // тишину, а не починку.
    stockChanges: standStockChanges,
    editTerms: LocalSaleEditTerms(
      db: db,
      discountPolicy: LocalDiscountPolicy(db),
      currency: CurrencyServiceImpl(db: db, logger: logger),
      logger: logger,
    ),
    // Оплата — задача 14. Дописана при слиянии, и **по требованию сторожа**,
    // а не по памяти: `stand_matches_till_test` сверяет доводы `ApiServer` у
    // стенда и у `main.dart` и назвал `payments` поимённо. Без неё пять
    // денежных операций отвечали бы на стенде `payments_unavailable`, и
    // живая проверка оплаты мерила бы обрезок кассы — ровно та беда, ради
    // которой сторож заведён.
    //
    // Собрана теми же двумя обязательными доводами, что и боевой DI
    // (`service_locator.dart`): подготовка чека над **той же** корзиной и
    // `SaleUseCase`.
    //
    // **Четыре необязательных подняты записывающими заглушками** (задача 21,
    // сценарий 6). Прежде здесь стояло «на стенде не поднимаются: железа и
    // оператора здесь нет» — и это было правдой про железо, но неправдой про
    // проверку: при `null` все три ветки завершения оплаты выходят молча, и
    // продажа с терминала выглядела бы напечатанной и фискализованной,
    // ничего не напечатав. Наблюдать сценарий 6 было нечем, а засчитать его
    // «по отсутствию ошибки» — худший исход приёмки.
    //
    // Заглушки не печатают и не фискализуют. Они записывают довод — номер
    // чека, кассу, сумму, состав, разбивку по видам оплаты, — то есть
    // доказывают ровно решение заказчика №1: касса собрала верный документ
    // и отдала его своему порту. Чего они не доказывают, названо в
    // докстринге `stand_hardware_recorder.dart` вслух.
    //
    // Бонусы и смена остаются `null`: они не про железо и в сценарии 6 не
    // участвуют.
    payments: standPayments,
    // Выпуск подарочных сертификатов — задача 21. Настоящий
    // `LocalCertificateIssuer` над той же базой, что и всё остальное на
    // стенде: подделывать тут нечего — внешнего собеседника у сертификата
    // нет, а обязательство он берёт на кассу, которая здесь и стоит.
    certificates: standCertificates,
    // Приём аванса покупателя — требование заказчика 2026-09-18. Настоящий
    // `CustomerPaymentUseCaseImpl` над той же базой и тем же фискальным
    // портом, что и всё остальное на стенде: подделывать здесь нечего, а
    // подделка сняла бы ровно то, ради чего живая проверка и ставится —
    // чек аванса уходит через тот же порт, что чек продажи.
    //
    // Тот же экземпляр, что и `certificates` строкой выше, переменной не
    // делается: своего состояния у юзкейса нет, второго читателя на стенде
    // у него тоже нет.
    prepaymentIntake: CustomerPaymentUseCaseImpl(
      db: db,
      logger: logger,
      fiscal: standFiscal,
    ),
    // Выдача аванса деньгами — решение заказчика 2026-09-18, вторая половина
    // того же экрана. Настоящий юзкейс, по тем же доводам, что у приёма
    // строкой выше; **свой экземпляр** здесь заводить не нужно и нечем —
    // своего состояния у юзкейса нет, память заявок живёт в базе, а база
    // одна на стенд. Без этой строки кассир на стенде принял бы аванс и
    // получил бы `prepayment_refund_unavailable` на попытке его вернуть, то
    // есть живая проверка мерила бы обрезок кассы.
    prepaymentRefund: CustomerPaymentUseCaseImpl(
      db: db,
      logger: logger,
      fiscal: standFiscal,
    ),
    // Повтор печати слипа — решение заказчика 2026-09-18. Над **тем же**
    // `standCertificates` и **тем же** `standSlips`, что стоят выше: вторая
    // копия печатала бы во вторую очередь, и живая проверка «слип не вышел,
    // жму повтор» мерила бы тишину.
    certificateSlips: LocalCertificateSlipReprinter(
      certificates: standCertificates,
      slips: standSlips,
    ),
    // Диагностика оборудования с планшета — план 2026-09-19. Настоящая
    // `LocalHardwareDiagnostics` над **теми же** очередью печати, службой
    // печати, базой и очередью фискализации, что стоят на этом стенде, а не
    // вторая копия: копия читала бы вторую очередь, и вкладка показывала бы
    // пустоту при печатающем эмуляторе — то есть живая проверка мерила бы
    // обрезок кассы.
    //
    // Очередь берётся из `GetIt`, куда её кладёт `registerPrintQueue` выше —
    // ровно тем же выражением, каким её берёт боевой DI
    // (`service_locator.dart`). Служба печати — `standPrinter`, тот самый
    // журнал поверх `ReceiptPrintServiceImpl`, которым стенд и печатает:
    // ширина ленты, на которой собран текст чека в диагностике, обязана быть
    // той же, на которой он вышел из эмулятора.
    diagnostics: _TracingDiagnostics(
      LocalHardwareDiagnostics(
        terminals: terminals,
        queue: GetIt.I<PrintQueue>(),
        printer: standPrinter,
        db: db,
        fiscalQueue: standFiscalQueue,
      ),
    ),
    // Пункт 5 A7 (2026-09-15): замок перебора сертификатов с тем же журналом
    // безопасности, что у кассы, — живая приёмка 2026-09-13 нашла, что
    // срабатывание не оставляло следа, и дверь `stand/security-events`
    // обязана его показать.
    certificateThrottle: CertificateThrottle(
      onLocked: certificateLockJournalHandler(journal),
    ),
  );

  // **До** первого сокета и до первого кадра: недособранная касса обязана не
  // подняться, а не отвечать «нет службы». Довод — в докстринге функции.
  _assertStandIsWholeTill(server);
  _assertStandHoldsQrSetup(standPayments);

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
  // **«То же, чем проверяет главная касса» — это утверждение, и оно уже
  // однажды перестало быть правдой молча.** Круг правки 3 задачи 19 завёл у
  // `wireGuardForTill` необязательный довод `boundTerminalId` (сверка «место
  // сеанса совпадает с местом сессии сейчас»), `main.dart` его передаёт, а
  // этот вызов — нет: сторож на стенде просто перестал делать одну из своих
  // сверок, ничего при этом не сообщив. Живая проверка мерила бы кассу без
  // охранной правки.
  //
  // Поэтому утверждение теперь сторожит набор, а не комментарий:
  // `test/architecture/stand_matches_till_test.dart` сверяет доводы **обоих**
  // вызовов с объявлением функции и краснеет на первом же расхождении. Ветвь
  // возвратов в эту ещё не влита, так что здесь параметров три и все три
  // названы; **при слиянии проверка потребует дописать новый сюда**, и это
  // не забывчивость, а условие.
  final guard = wireGuardForTill(
    db: db,
    access: server.access,
    sessions: sessions,
    // Дописано в день слияния, и **по условию сборки, а не по памяти**:
    // сторож `stand_matches_till_test` сверяет доводы обоих вызовов с
    // объявлением функции и назвал `boundTerminalId` поимённо. Ветвь задачи
    // 19 завела его на кассе (сверка «место сеанса совпадает с местом
    // сессии сейчас»); без этой строки стенд поднимал бы сторожа слабее
    // продуктового, и живая проверка мерила бы кассу без охранной правки.
    boundTerminalId: server.operations.terminalForSessionKey,
  );
  // Тот же обработчик, что и `main.dart`: отказ сторожа пишет запись в
  // журнал, не только в консоль стенда. Без него живая проверка «отказ
  // сторожа оставил запись» проверяла бы стенд, а не проверенный код.
  final onDenied = buildWireDeniedJournalHandler(
    journal: journal,
    resolveTerminal: server.operations.terminalForSessionKey,
  );
  List<TillWire> buildWires(WebTransportEndpoint endpoint) => [
    for (final quic in endpoint.servers)
      TillWire(
        quic,
        server.operations.askHandlers,
        watchHandlers: server.operations.watchHandlers,
        runHandlers: server.operations.runHandlers,
        guard: guard,
        onDenied: onDenied,
      )..start(),
  ];

  // Изменяемый держатель, а не `final wire`, — ради задачи 21, сценария 3
  // («обрыв Wi-Fi посреди набора»). Стенд живёт на петле, и рвать там нечего:
  // Wi-Fi у 127.0.0.1 нет, а выключение настоящего адаптера у заказчика
  // оборвало бы вместе с проверкой и его рабочий браузер. Единственный
  // обрыв, который здесь и достижим, и обратим, — **закрыть слушатель QUIC
  // кассы**. С точки зрения страницы это неотличимо: кадры перестают
  // доходить, сессия гаснет по тайм-ауту простоя, экран обязан назвать
  // состояние сам.
  //
  // Восстановление — на **том же** порту (`port: quicPort` ниже) и с тем же
  // листом: страница получила номер порта и отпечаток один раз, при загрузке
  // документа (`window.TELEPOS_WT_PORT`), и другой номер она бы не узнала.
  // Проверка «после возврата корзина та же» тогда провалилась бы по причине,
  // не имеющей отношения к продукту.
  final standWire = _StandWire(wt, buildWires(wt));
  final quicPort = wt.port;

  /// Опустить слушатель QUIC — «сеть пропала».
  Future<String> wireDown() async {
    if (!standWire.isUp) return 'уже опущен';
    for (final w in standWire.wires) {
      await w.stop();
    }
    await standWire.endpoint.stop();
    standWire.wires = const [];
    stdout.writeln('[стенд] провод ОПУЩЕН: слушатель QUIC закрыт');
    return 'опущен';
  }

  /// Поднять его обратно на том же порту — «сеть вернулась».
  Future<String> wireUp() async {
    if (standWire.isUp) return 'уже поднят';
    final again = await startWebTransport(
      credential: leaf,
      scope: ListenScope.everywhere,
      port: quicPort,
    );
    if (again is WebTransportUnavailable) {
      stdout.writeln('[стенд] провод НЕ поднялся: ${again.reason}');
      return 'не поднялся: ${again.reason}';
    }
    final endpoint = again as WebTransportEndpoint;
    // Другой номер порта страница не узнает: он уехал в документ один раз,
    // при загрузке. Молча оставить такой слушатель значило бы показать
    // «корзина не вернулась» дефектом продукта, которым он не является.
    if (endpoint.port != quicPort) {
      await endpoint.stop();
      stdout.writeln(
        '[стенд] провод НЕ поднялся: система дала порт ${endpoint.port} '
        'вместо $quicPort — страница о нём не знает',
      );
      return 'не поднялся: порт ${endpoint.port} вместо $quicPort';
    }
    standWire
      ..endpoint = endpoint
      ..wires = buildWires(endpoint);
    stdout.writeln('[стенд] провод ПОДНЯТ обратно на udp/$quicPort');
    return 'поднят';
  }

  final announced = await TillAnnouncement.start(
    name: name,
    httpsPort: server.boundPort!,
    quicPort: wt.port,
    addresses: addresses,
  );

  // Вторая дверь к той же странице — по **обычному HTTP на петле**.
  //
  // # Зачем, если HTTPS уже есть
  //
  // Лист стенда самоподписанный, и браузер показывает страницу-предупреждение.
  // Плагин отладки к ней **не подключается вовсе** («Cannot attach to this
  // target»): ни снимка, ни клика, ни чтения. То есть живая проверка через
  // плагин по `https://` невозможна ни на каком порту — измерено
  // координатором 2026-09-07.
  //
  // # Почему это не откат на HTTP и почему `ApiServer` по-прежнему прав
  //
  // `ApiServer.start` отказывается отдавать страницу без сертификата, и
  // отказывается **осознанно**: браузер не даёт `WebTransport` на
  // незащищённой странице, и молчаливый откат выглядел бы как работающая
  // касса со сломанным проводом. Это верно для кассы, которую открывают
  // **по сети**, и остаётся верным — здесь не изменено ни строки.
  //
  // Петля — исключение по правилам самих браузеров: `http://127.0.0.1` и
  // `http://localhost` считаются потенциально доверенным происхождением, то
  // есть **защищённым контекстом**, и `WebTransport` там доступен наравне с
  // HTTPS. Сама сессия провода идёт по QUIC с `serverCertificateHashes`
  // (`wt_session.dart`: хост берётся из `Uri.base.host`, порт и отпечаток —
  // из документа) и от схемы страницы не зависит вовсе.
  //
  // Поэтому дверь заведена **в стенде, а не в кассе**, и только на петле:
  // за пределами `127.0.0.1`/`::1` она была бы ровно тем отказом без
  // объяснения, который `ApiServer` и запрещает.
  //
  // Проверка прав здесь не повторяется (`ApiSecurity` не подключён): она
  // живёт на проводе, а не на раздатчике файлов, и бандл — те же байты, что
  // отдаёт HTTPS-дверь рядом.
  // Умолчание не садится на порт управления — разбор в `stand_ports.dart`.
  final httpPort = standPlainHttpPort(
    page: httpsPort,
    control: controlPort,
    explicit: env['TELEPOS_STAND_HTTP'],
  );
  final files = createStaticHandler(webDir, defaultDocument: 'index.html');
  // Задача 42: тот же кэш, что у кассы (`ApiServer._frontendHandler`), —
  // именно на стенде вкладка и держала прежний бандл.
  final bundle = cachingBundle(files);
  Future<Response> plainPage(Request request) async {
    final isDocument =
        request.url.path.isEmpty || request.url.path.endsWith('.html');
    if (!isDocument) return bundle(request);
    final response = await files(
      request.change(headers: {HttpHeaders.ifModifiedSinceHeader: null}),
    );
    if (response.statusCode != 200) return response;
    // Те же три величины, что кладёт в документ `ApiServer._frontendHandler`.
    // `TELEPOS_TOKEN` пуст: единственным его читателем был снятый `ApiClient`,
    // и `lib/web/` не спрашивает его ни строкой — кладётся ради формы
    // документа, чтобы страница отличалась от кассовой ровно схемой.
    final html = await response.readAsString();
    final injected = html.replaceFirst(
      '<head>',
      '<head>\n  <script>window.TELEPOS_TOKEN = "";'
          ' window.TELEPOS_WT_PORT = ${wt.port};'
          ' window.TELEPOS_WT_CERT_SHA256 = '
          '"${wt.certificateFingerprintSha256}";</script>',
    );
    return Response.ok(
      injected,
      headers: {
        'content-type': 'text/html; charset=utf-8',
        HttpHeaders.cacheControlHeader: kDocumentCacheControl,
      },
    );
  }

  final plainServers = <HttpServer>[];
  for (final address in [
    InternetAddress.loopbackIPv4,
    InternetAddress.loopbackIPv6,
  ]) {
    try {
      plainServers.add(await shelf_io.serve(plainPage, address, httpPort));
    } on Object catch (error) {
      stdout.writeln('[стенд] http-дверь ${address.address}: $error');
    }
  }

  final control = await shelf_io.serve(
    _standControl(
      terminals,
      standWire,
      server,
      db,
      sessions,
      wireDown,
      wireUp,
      hardware,
      standCertificates,
      standFiscal,
      deviceCatalog,
      deviceBindings,
      logger,
      standPrinter,
    ),
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
    ..writeln(
      '[стенд] страница-http '
      '${plainServers.isEmpty ? "НЕ ПОДНЯЛАСЬ" : "http://127.0.0.1:$httpPort/"}'
      ' (та же страница без предупреждения о сертификате; петля — '
      'защищённый контекст, WebTransport доступен)',
    )
    ..writeln(
      '[стенд] управление http://127.0.0.1:${control.port}/stand/state',
    );

  // Какой именно нативный файл говорит по проводу — печатается всегда, а не
  // вспоминается. Довод — в докстринге функции.
  _reportNativeLibraries();

  stdout
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

/// Необязательные сотрудники кассы, которых у стенда нет **осознанно**, — и
/// единственные, которых ему позволено не иметь.
///
/// Обе записи — про железо, которого у процесса `flutter_tester` физически
/// нет: он не собирает ни одного драйвера. Всё остальное, что умеет
/// настоящая касса, стенд обязан уметь тоже, иначе живая проверка меряет не
/// тот продукт.
///
/// Список **не расширять «чтобы завелось»**. Запись здесь — это заявление
/// «на стенде эта операция не проверяется никогда»; каждая новая обязана
/// нести довод не хуже, чем у этих двух.
const _standAbsentByDesign = <String>{'deviceDiscovery', 'deviceCheck'};

/// Стенд обязан быть той же кассой, что и приложение, — и доказывать это при
/// подъёме.
///
/// # Почему это существует
///
/// `ApiServer` принимает восемь необязательных сотрудников, и каждый
/// пропущенный превращает свою операцию в вежливый отказ («нет службы»),
/// неотличимый на вид от рабочего ответа. Стенд от кассы расходился этим уже
/// **дважды**, и оба раза расхождение нашла не сборка и не набор, а человек,
/// пришедший проверять совсем другое:
///
/// * 2026-08-22 — не отдавался `SessionAdmin`: `auth.sessions`/
///   `auth.sessionRevoke` отказывали `no_session_registry` независимо от
///   права и сеанса (запись в `testing-notes.md`, раздел задачи 22);
/// * 2026-09-06 — не отдавались `refund`, `network` и `terminalSessions`:
///   **шести операций возврата на стенде не существовало вовсе**, и охранная
///   правка задачи 19 была проверена только набором.
///
/// Общее у обоих — не забывчивость, а форма: отсутствие сотрудника
/// **наблюдаемо только тем, кто позовёт операцию и прочитает причину**.
/// Пока это так, третий случай — вопрос времени.
///
/// # Что делает эта проверка
///
/// Сверяет то, чего у собранной кассы **нет** ([TillOperations.absentCollaborators]),
/// с тем, чего у стенда нет **осознанно** ([_standAbsentByDesign]), и падает
/// на любом расхождении, в обе стороны:
///
/// * лишнее отсутствие — стенд недособран (сегодняшний дефект);
/// * исчезнувшее отсутствие — сотрудника завели, а объяснение осталось;
///   значит запись в списке выше врёт, и её надо снять.
///
/// Падает **при подъёме**, до первого сокета: недособранный стенд не имеет
/// права выглядеть работающим ни одной секунды. Это ровно то, чего требует
/// правило проекта «проверка обязана краснеть»: цена ошибки здесь — не
/// красный набор, а зелёный отчёт о живой проверке, которой не было.
///
/// # Чем это НЕ является
///
/// Проверка ловит пропущенного сотрудника из тех, что `TillOperations` о
/// себе рассказывает. Довод, **который она не закрывает**: новый
/// необязательный довод `ApiServer`, не попавший в `absentCollaborators`,
/// ей не виден. Эту вторую половину сторожит уже набор —
/// `test/architecture/stand_matches_till_test.dart` сверяет **имена
/// доводов** в `lib/main.dart` и в этом файле по исходнику. Ни одна из двух
/// не заменяет другую: первая говорит про поднятую кассу, вторая — про
/// текст, которым её собирают.
void _assertStandIsWholeTill(ApiServer server) {
  final absent = server.operations.absentCollaborators;
  final unexplained = absent.difference(_standAbsentByDesign);
  final vanished = _standAbsentByDesign.difference(absent);

  if (unexplained.isEmpty && vanished.isEmpty) {
    stdout.writeln(
      '[стенд] касса      полная; нет только ${_standAbsentByDesign.join(", ")} '
      '(железа у процесса нет)',
    );
    return;
  }

  final complaints = <String>[
    if (unexplained.isNotEmpty)
      'стенд собран без ${unexplained.join(", ")} — эти операции отвечали бы '
          '«нет службы» вместо работы, и живая проверка мерила бы обрезок '
          'кассы, а не кассу. Собери их в этом файле рядом с остальными или, '
          'если проверять их на стенде действительно нельзя, добавь в '
          '_standAbsentByDesign с доводом',
    if (vanished.isNotEmpty)
      '_standAbsentByDesign называет ${vanished.join(", ")} отсутствующими, а '
          'они у кассы есть — снять запись',
  ];
  fail('[стенд] касса собрана не как в приложении: ${complaints.join("; ")}');
}

/// Настройка провайдера QR у стенда есть — проверено родом, а не верой.
///
/// # Слепое пятно, которое это закрывает
///
/// Порт настройки QR касса снимает **с раскладки оплаты**:
/// `TillOperations._requireQrProviderSetup` спрашивает у неё род
/// `QrProviderSetupHost` и при отсутствии честно отказывает
/// `qr_setup_unavailable`. Решение верное (разбор — в его докстринге), но у
/// него есть цена: **способность не видна ни одному сторожу**.
///
/// * `absentCollaborators` перечисляет необязательных сотрудников
///   `ApiServer`, а настройка QR не сотрудник — она свойство уже переданной
///   оплаты, и в этот список не попадает;
/// * `stand_matches_till_test` сверяет **имена доводов** `ApiServer` у
///   `lib/main.dart` и у этого файла — довод `payments:` назван в обоих, и
///   сверка молчит, какой бы класс за ним ни стоял.
///
/// Значит сборка стенда с раскладкой оплаты, этого рода не объявившей, дала
/// бы живую проверку, на которой настройка QR отвечает «эта касса не держит
/// настройки» — и выглядело бы это дефектом продукта, а не обрезком стенда.
/// Ровно этот класс ошибки стенд уже допускал дважды
/// ([_assertStandIsWholeTill]).
///
/// Проверка **родом объекта, а не текстом исходника**: разрешительный сторож
/// по тексту («в файле есть `LocalPaymentService`») зелен и тогда, когда
/// класс переименовали или способность с него сняли.
void _assertStandHoldsQrSetup(PaymentService payments) {
  if (payments is QrProviderSetupHost) {
    stdout.writeln('[стенд] настройка QR  порт есть у раскладки оплаты');
    return;
  }
  fail(
    '[стенд] раскладка оплаты не объявляет QrProviderSetupHost: настройка '
    'провайдера QR отвечала бы «эта касса не держит настройки провайдера QR», '
    'и живая проверка шага 12 мерила бы обрезок стенда, а не кассу',
  );
}

/// Требование к версии пакета [name] — прямо из `pubspec.yaml`.
///
/// `null` — файла нет или пакет в нём не назван; тогда строка печатает
/// прочерк, а не выдумывает число.
String? _pubspecConstraintFor(String name) {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) return null;
  for (final line in file.readAsLinesSync()) {
    final match = RegExp('^\\s+$name:\\s*(\\S+)\\s*\$').firstMatch(line);
    if (match != null) return match.group(1);
  }
  return null;
}

/// Печатает, **какой именно** нативный файл будет говорить по проводу.
///
/// Мера против ловушки, стоившей целого прогона живой проверки 2026-08-06 и
/// объяснившей задним числом ещё один, 2026-08-24: `rk_*.dll` берётся из
/// каталога сборки кассы, каталог этот — артефакт последней
/// `flutter build windows` и может быть сколь угодно старым. Тогда там лежал
/// `rk_quic` 0.2.0 при влитой 0.2.1, IPv4 молчал, и найденное записали как
/// дефект продукта. Правило «сверять дату библиотеки перед живой проверкой»
/// с тех пор есть, но выполнял его человек, помнящий о нём, — то есть не
/// выполнял.
///
/// Печатается путь, размер и дата файла, а у `rk_quic` — ещё и версия,
/// **которую называет сама библиотека** (`probeNativeLibrary().version`), а
/// не объявленная в pubspec. Расхождение этих двух и есть протухшая сборка.
/// У `rk_pki` наружу отдан только признак работоспособности нативной части
/// (`hasNativeCrypto`) — версию она не экспортирует, поэтому там остаются
/// дата и размер файла.
void _reportNativeLibraries() {
  for (final name in _nativeLibraryFileNames) {
    final file = _findOnPath(name);
    final where = file == null
        ? 'НЕ НАЙДЕНА в PATH'
        : '${file.path} '
              '(${file.statSync().size} б, '
              '${file.lastModifiedSync().toIso8601String()})';
    stdout.writeln('[стенд] нативная   $name → $where');
  }

  final quic = rk_quic.probeNativeLibrary();
  stdout.writeln(
    '[стенд] rk_quic    библиотека называет себя ${quic.version ?? "—"} '
    '(исход ${quic.outcome.name}, путь ${quic.path ?? "—"}); '
    // Спрошено у `pubspec.yaml`, а не вписано числом: литерал здесь уже
    // соврал — стоял `^0.2.0` при поднятой до `^0.2.2` зависимости, и
    // строка, которую читают ровно затем, чтобы поймать расхождение версий,
    // сама стала его источником.
    'pubspec просит ${_pubspecConstraintFor('rk_quic') ?? "—"}',
  );
  stdout.writeln(
    '[стенд] rk_pki     нативная часть '
    '${rk_pki.hasNativeCrypto ? "отвечает" : "НЕ ОТВЕЧАЕТ"}; '
    'пакет объявляет ${rk_pki.rkPkiVersion}',
  );
}

/// Имена файлов нативных библиотек этой платформы — те же три, которыми
/// живёт провод: QUIC, сертификаты и объявление в сети.
List<String> get _nativeLibraryFileNames {
  if (Platform.isWindows) {
    return const ['rk_quic.dll', 'rk_pki.dll', 'rk_mdns.dll'];
  }
  if (Platform.isMacOS) {
    return const ['librk_quic.dylib', 'librk_pki.dylib', 'librk_mdns.dylib'];
  }
  return const ['librk_quic.so', 'librk_pki.so', 'librk_mdns.so'];
}

/// Тот же поиск, что делает загрузчик ОС для `DynamicLibrary.open('имя')`:
/// рабочий каталог, затем записи `PATH`. Приблизительный нарочно — он не
/// заменяет загрузку, а объясняет её человеку.
File? _findOnPath(String fileName) {
  final places = <String>[
    Directory.current.path,
    ...(Platform.environment['PATH'] ?? '').split(
      Platform.isWindows ? ';' : ':',
    ),
  ];
  for (final place in places) {
    if (place.isEmpty) continue;
    final candidate = File('$place${Platform.pathSeparator}$fileName');
    if (candidate.existsSync()) return candidate;
  }
  return null;
}

/// Управление стендом: изменить состояние кассы, не трогая браузер.
///
/// Отдельный слушатель на петле, а не путь в `ApiServer`: сервер страницы
/// обязан остаться ровно тем, что уедет заказчику, и добавить в него путь ради
/// проверки значило бы проверять не его.
Handler _standControl(
  TerminalRepository terminals,
  _StandWire wire,
  ApiServer server,
  AppDatabase db,
  SessionRegistry sessions,
  Future<String> Function() wireDown,
  Future<String> Function() wireUp,
  StandHardwareJournal hardware,
  CertificateIssuer certificates,
  StandFiscalPort fiscal,
  DeviceProfileCatalog deviceCatalog,
  DeviceBindingRepository deviceBindings,
  Talker logger,
  ReceiptPrintService printer,
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
          // Поднят ли слушатель QUIC — то, что меняет `stand/wire`.
          'wireUp': wire.isUp,
        });

      // Задача 21, сценарий 1: номера чеков и владение корзинами.
      //
      // Номер чека на экране терминала не показывается нигде, а сценарий 1
      // требует убедиться, что два рабочих места набирают **разные** чеки и
      // что корзины не смешиваются. Журнал кассы печатает номер при заводе
      // чека (`SaleInitiation: created new sale receipt=…`), но **не
      // печатает владельца** — то есть доказывает половину.
      //
      // **`terminalId` пуст у всего, что не в работе, и это инвариант, а не
      // пропуск** (докстринг колонки `Sales.terminalId`): завершённый и
      // отложенный чеки владельца не имеют — они принадлежат смене и кассе,
      // а не набравшему их терминалу. Поэтому `terminalId: null` у чека в
      // состоянии 1 или 3 — правильный ответ, а не потерянная связь. У
      // сценария 2 это, наоборот, наблюдаемая величина: владелец обязан
      // исчезнуть в момент откладывания.
      case 'stand/sales':
        final wantState = int.tryParse(
          request.url.queryParameters['state'] ?? '',
        );
        final rows = await db.select(db.sales).get();
        // Строки читаются одним запросом и раскладываются в памяти:
        // `SaleProducts.receiptNo`/`posId` нулевые по объявлению, и запрос
        // с двумя `equals` на нулевых колонках drift не типизует. База
        // стенда мала, а разложить в Dart — честнее, чем городить
        // `equalsNullable` ради одной проверки.
        final allLines = await db.select(db.saleProducts).get();
        final out = <Map<String, Object?>>[];
        for (final sale in rows) {
          if (wantState != null && sale.state != wantState) continue;
          final lines = allLines.where(
            (l) => l.receiptNo == sale.receiptNo && l.posId == sale.posId,
          );
          final composed = <Map<String, Object?>>[];
          for (final line in lines) {
            // Имя — из каталога по коду товара: в строке чека его нет, а
            // без имени состав нечем сверить с тем, что видно на экране.
            final info = await db.productInfoDao.findByUcode(line.ucode);
            composed.add({
              'lineId': line.id,
              'ucode': line.ucode,
              'name': info?.name,
              'quantity': line.quantity.toString(),
              'price': line.price.toString(),
              'total': (line.quantity * line.price).toString(),
            });
          }
          out.add({
            'receiptNo': sale.receiptNo,
            'posId': sale.posId,
            'terminalId': sale.terminalId,
            'userId': sale.userId,
            'state': sale.state,
            'stateName': switch (sale.state) {
              0 => 'в работе',
              1 => 'завершён',
              3 => 'отложен',
              _ => 'состояние ${sale.state}',
            },
            'amount': sale.amount.toString(),
            'isWholesale': sale.isWholesale,
            'lines': composed,
          });
        }
        out.sort(
          (a, b) => (a['receiptNo']! as int).compareTo(b['receiptNo']! as int),
        );
        return _json({'sales': out});

      // Задача 21, сценарий 6: чем касса позвала своё железо.
      //
      // Читается тем же способом, каким писалось, — списком записей, а не
      // счётчиком: «позвана 1 раз» не отличает верный чек от чужого.
      // `?clear=1` чистит журнал, чтобы следующий сценарий не читал хвост
      // предыдущего.
      case 'stand/hardware':
        if (request.url.queryParameters['clear'] == '1') {
          final had = hardware.entries.length;
          hardware.clear();
          stdout.writeln('[стенд] журнал железа очищен ($had записей)');
          return _json({'cleared': had, 'entries': const []});
        }
        return _json({
          'modes': {
            'fiscal': hardware.fiscalMode.name,
            'printer': hardware.printerMode.name,
            'drawer': hardware.drawerMode.name,
          },
          'entries': hardware.entries,
        });

      // Чековый принтер кассы: привязка и драйвер по ней — решение
      // заказчика 2026-09-18 («эмулятор Принтера мы делали именно для
      // этого»).
      //
      // # Почему дверь, а не экран настроек оборудования
      //
      // Привязка принтера живёт у **кассы**, а не у браузерного терминала:
      // ширину ленты и адрес читает `hardware_module.dart` по
      // `terminals.self()`. С браузера этот экран сюда не дотягивается —
      // он настраивает своё рабочее место. Значит без двери стенд поднять
      // печать нечем, и это ровно тот случай, для которого пульт стенда и
      // заведён: изменить состояние кассы, не трогая браузер.
      //
      // # Подстановка адресом
      //
      // Профиль настоящий (`printer.escpos.80mm` допускает 58 и 80 мм),
      // адрес — эмулятора. Ни одного своего класса в дорогу байтов не
      // подставлено: `WifiPrinterManager`, кадры ESC/POS, опрос `DLE EOT`,
      // очередь и разбор исхода — всё продуктовое.
      //
      // `GET /stand/printer?address=127.0.0.1&port=8987&width=58|80`
      case 'stand/printer':
        final width = request.url.queryParameters['width'] ?? '80';
        final address =
            request.url.queryParameters['address']?.trim() ?? '127.0.0.1';
        final port = request.url.queryParameters['port']?.trim() ?? '9100';
        if (int.tryParse(port) == null) {
          return Response.badRequest(body: 'port=$port — не число');
        }
        // Профиль выбирается **шириной**, а не доводом: 58 мм умеют оба
        // профиля, 80 — только широкий, и ошибиться тут нечем.
        const profileId = 'printer.escpos.80mm';
        final binding = DeviceBinding(
          deviceClass: DeviceClass.receiptPrinter,
          profileId: profileId,
          parameters: {'ipAddress': address, 'port': port},
          options: {paperWidthOptionKey: width},
        );
        try {
          // Проверка профилем — до записи и до сборки драйвера: ширина,
          // которой профиль не допускает, обязана стать отказом здесь, а не
          // молчаливой узкой лентой на чеке.
          binding.validateAgainst(deviceCatalog);
        } on ArgumentError catch (e) {
          return Response.badRequest(body: 'привязка не годится: ${e.message}');
        }
        final domain.Terminal self;
        try {
          self = await terminals.self();
        } on Object catch (e) {
          return Response.badRequest(
            body: 'кассы ещё нет ($e) — сперва stand/configure',
          );
        }
        await deviceBindings.save(self.id, binding);
        // Драйвер — тем же построителем, что у кассы. Прежний снимается:
        // второй `PrinterManager` держал бы второй сокет к тому же порту, а
        // эмулятор, как и настоящий принтер, пускает одного.
        if (GetIt.I.isRegistered<PrinterManager>()) {
          await GetIt.I<PrinterManager>().disconnect();
          await GetIt.I.unregister<PrinterManager>();
        }
        GetIt.I.registerSingleton<PrinterManager>(
          buildReceiptPrinterManager(binding, logger),
        );
        stdout.writeln(
          '[стенд] принтер: $address:$port, лента $width мм, профиль '
          '$profileId, терминал ${self.id}',
        );
        return _json({
          'terminalId': self.id,
          'profileId': profileId,
          'address': address,
          'port': port,
          'paperWidthMm': width,
        });

      // Повторная печать чека из истории — тем же составителем и той же
      // службой, какими печатает касса.
      //
      // # Зачем дверь, если чек печатается сам при оплате
      //
      // Ширина ленты меняется привязкой и действует **со следующего чека**.
      // Сверить 58 и 80 мм продажами значит провести две продажи, а чтобы
      // сверять шапку, подвал или кодовую страницу — по продаже на каждую
      // правку. Дубликат печатает тот же документ той же дорогой, и сравнивать
      // становится что: один и тот же чек на двух лентах.
      //
      // Состава чека дверь **не собирает**: его собирает
      // `SaleReceiptComposer` — ровно тот же, которым пользуется
      // `LocalPaymentService`. Свой сбор здесь был бы второй копией правила,
      // и расходилась бы она молча.
      //
      // `GET /stand/print-duplicate?receiptNo=1&posId=1`
      case 'stand/print-duplicate':
        final receiptNo = int.tryParse(
          request.url.queryParameters['receiptNo'] ?? '',
        );
        if (receiptNo == null) {
          return Response.badRequest(body: 'нужен receiptNo=<номер чека>');
        }
        final posId =
            int.tryParse(request.url.queryParameters['posId'] ?? '') ?? 1;
        final data = await SaleReceiptComposer(
          db: db,
          logger: logger,
        ).compose(receiptNo: receiptNo, posId: posId);
        if (data == null) {
          return Response.notFound('чека $receiptNo на кассе $posId нет');
        }
        final outcome = await printer.printSaleDuplicate(data);
        stdout.writeln(
          '[стенд] дубликат чека $receiptNo: ${outcome.status.name} — '
          '${outcome.message}',
        );
        return _json({
          'receiptNo': receiptNo,
          'posId': posId,
          'status': outcome.status.name,
          'jobId': outcome.jobId,
          'message': outcome.message,
        });

      // Отказ портов по команде — иначе половина пути завершения оплаты
      // непроходима: ветка `_unfiscalized` («чек не фискализован — оплата
      // проведена», строка очереди бед) достижима только по отказу
      // оператора, а успешная заглушка её не проходит никогда.
      case 'stand/hardware-mode':
        StandHardwareMode? parse(String? raw) {
          if (raw == null || raw.isEmpty) return null;
          for (final mode in StandHardwareMode.values) {
            if (mode.name == raw) return mode;
          }
          return null;
        }

        final wanted = {
          'fiscal': request.url.queryParameters['fiscal'],
          'printer': request.url.queryParameters['printer'],
          'drawer': request.url.queryParameters['drawer'],
        }..removeWhere((_, value) => value == null || value.isEmpty);
        if (wanted.isEmpty) {
          return Response.badRequest(
            body:
                'нужен хотя бы один довод: fiscal|printer|drawer = '
                '${StandHardwareMode.values.map((m) => m.name).join("|")}',
          );
        }
        // Неизвестное имя — отказ, а не пропуск, по тому же доводу, что у
        // `stand/seed-cashier`: опечатка при пропуске оставила бы порт
        // исправным, и «касса назвала беду» прошло бы зелёным без беды.
        for (final entry in wanted.entries) {
          if (parse(entry.value) == null) {
            return Response.badRequest(
              body:
                  'неизвестный режим ${entry.key}=${entry.value}; можно '
                  '${StandHardwareMode.values.map((m) => m.name).join(", ")}',
            );
          }
        }
        for (final entry in wanted.entries) {
          final mode = parse(entry.value)!;
          switch (entry.key) {
            case 'fiscal':
              hardware.fiscalMode = mode;
            case 'printer':
              hardware.printerMode = mode;
            case 'drawer':
              hardware.drawerMode = mode;
          }
        }
        stdout.writeln(
          '[стенд] режим железа: оператор ${hardware.fiscalMode.name}, '
          'принтер ${hardware.printerMode.name}, '
          'ящик ${hardware.drawerMode.name}',
        );
        return _json({
          'fiscal': hardware.fiscalMode.name,
          'printer': hardware.printerMode.name,
          'drawer': hardware.drawerMode.name,
        });

      // Задача 21, сценарий 3: «обрыв Wi-Fi посреди набора».
      //
      // `state=down` закрывает слушатель QUIC кассы, `state=up` поднимает его
      // обратно на том же порту и с тем же листом. Довод, почему обрыв
      // изображается именно так, а не выключением адаптера, — у держателя
      // `standWire` в теле стенда.
      case 'stand/wire':
        final want = request.url.queryParameters['state'] ?? '';
        final String outcome;
        switch (want) {
          case 'down':
            outcome = await wireDown();
          case 'up':
            outcome = await wireUp();
          default:
            return Response.badRequest(body: 'нужен довод state=down|up');
        }
        return _json({'state': want, 'outcome': outcome, 'up': wire.isUp});

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
        // Свой номер кассы — **третье** поле, которого не хватало, и найдено
        // оно живой проверкой возврата 2026-09-06, а не чтением. `id` в
        // `this_pos_entries` пуст на стенде всегда, а `ThisPosDao.requireId`
        // на пустом бросает `TillNotConfigured` — политика «ноль не
        // подставляется нигде». Значит **любая** операция провода, знающая
        // про деньги, отвечала на стенде `till_not_configured`: не только
        // все шесть возврата (`LocalRefundService._posId`), но и корзина
        // (`LocalCartService._posId`, тот же приём). То есть продать или
        // вернуть на стенде было нельзя никогда, и увидеть это можно было
        // только позвав операцию — тот же род слепоты, что и обрезанная
        // сборка кассы выше.
        //
        // Записано двумя ветвями порознь и сведено слиянием: ветвь продажи
        // предсказала, что задача 13 упрётся в то же поле (`task-stand-
        // report.md`, находка Н3), ветвь стенда измерила это на возврате.
        //
        // Значение `1` — не выдумка стенда: ровно его подставляет мастер
        // настройки (`ThisPosDao.insertInitialConfig`, `int posId = 1`).
        final posId =
            int.tryParse(request.url.queryParameters['pos'] ?? '') ?? 1;
        final changed = await db.customUpdate(
          'UPDATE this_pos_entries '
          'SET company_name = ?, cash_box_name = ?, id = ? WHERE r_id = 1',
          variables: [
            Variable.withString(company),
            Variable.withString(cashbox),
            Variable.withInt(posId),
          ],
          updates: {db.thisPosEntries},
        );
        if (changed == 0) {
          await db.customInsert(
            'INSERT INTO this_pos_entries '
            '(r_id, company_name, cash_box_name, id) VALUES (1, ?, ?, ?)',
            variables: [
              Variable.withString(company),
              Variable.withString(cashbox),
              Variable.withInt(posId),
            ],
            updates: {db.thisPosEntries},
          );
        }
        stdout.writeln(
          '[стенд] касса настроена: магазин «$company», касса «$cashbox», '
          'номер кассы $posId',
        );
        return _json({
          'companyName': company,
          'cashBoxName': cashbox,
          'posId': posId,
        });

      // Товар с ценой — без него скан отвечает «товар не найден», а не кладёт
      // строку. `ProductInfos` требует непустой `barcode` (память проекта),
      // цена живёт отдельной строкой `ProductPrices`.
      // Товар нужен обеим живым проверкам: скан продажи иначе отвечает
      // «товар не найден», а `refund.addProduct` берёт из каталога цену
      // (`_catalogLine`, `local_refund_service.dart`). Ветвь возвратов
      // завела эту команду отдельно; при слиянии осталась одна — здешняя,
      // она принимает ещё и `name`.
      case 'stand/seed-product':
        final ucode =
            int.tryParse(request.url.queryParameters['ucode'] ?? '') ?? 100;
        final price = request.url.queryParameters['price'] ?? '500';
        final barcode =
            int.tryParse(request.url.queryParameters['barcode'] ?? '') ??
            4870001234567;
        final productName =
            request.url.queryParameters['name'] ?? 'Молоко 3.2%';
        await db
            .into(db.productInfos)
            .insert(
              ProductInfosCompanion.insert(
                ucode: Value(ucode),
                barcode: barcode,
                name: productName,
                type: 0,
                measure: 0,
                quantity: Value(Decimal.parse('100')),
              ),
            );
        await db
            .into(db.productPrices)
            .insert(
              ProductPricesCompanion.insert(
                ucode: Value(ucode),
                barcode: barcode,
                sellingPrice: Value(Decimal.parse(price)),
              ),
            );
        stdout.writeln(
          '[стенд] заведён товар #$ucode «$productName» по цене $price, '
          'штрихкод $barcode',
        );
        return _json({
          'ucode': ucode,
          'name': productName,
          'price': price,
          'barcode': barcode,
        });

      // Открытая смена. Без неё начало чека отказывает `shift_not_open`:
      // касса больше не открывает смену молча на выдуманного человека
      // (задача 6 плана, И158). Тем же кодом отказывает и `refund.complete`
      // (`local_refund_service.dart`) — ветвь возвратов завела эту же
      // команду своей строкой, и при слиянии осталась одна: здешняя, у неё
      // есть довод `user`. Отдельная команда, а не часть подъёма — «касса
      // без открытой смены» законное состояние, и отказ на нём тоже надо
      // уметь увидеть.
      // `hoursAgo=25` открывает смену задним числом — иначе шаг 10 приёмки
      // непроходим: `ShiftAgeRule` (сутки, `>=`) на смене, открытой
      // «сейчас», не срабатывает никогда, а часов у кассы не подменить.
      case 'stand/open-shift':
        final shiftUser =
            int.tryParse(request.url.queryParameters['user'] ?? '') ?? 1;
        final hoursAgo =
            int.tryParse(request.url.queryParameters['hoursAgo'] ?? '') ?? 0;
        // **Секунды, а не миллисекунды.** До 2026-09-18 здесь стояло
        // `millisecondsSinceEpoch`, и это был дефект стенда, а не мелочь:
        // касса пишет `~/ 1000` (`ShiftServiceImpl.onOpenShift`), и
        // `ShiftAgeRule` сравнивает секунды с секундами. Смена стенда
        // выглядела открытой на полвека вперёд, возраст выходил
        // отрицательным, и просроченная смена была недостижима **по
        // построению** — а выглядело бы это как «правило не работает».
        final openedAt =
            DateTime.now()
                .subtract(Duration(hours: hoursAgo))
                .millisecondsSinceEpoch ~/
            1000;
        final shiftId = await db.shiftDao.insertShift(
          ShiftsCompanion.insert(
            userId: shiftUser,
            openTime: openedAt,
            isOpened: true,
            isSynced: false,
          ),
        );
        stdout.writeln(
          '[стенд] открыта смена #$shiftId (кассир $shiftUser, открыта '
          '${hoursAgo == 0 ? "сейчас" : "$hoursAgo ч назад"})',
        );
        return _json({
          'shiftId': shiftId,
          'userId': shiftUser,
          'openTime': openedAt,
          'hoursAgo': hoursAgo,
        });

      // Закрыть открытую смену — вторая половина шага 10: диалог
      // просроченной смены ведёт кассира «закрыть смену на кассе», и без
      // этой двери путь упирается в стену.
      case 'stand/close-shift':
        final openShift = await db.shiftDao.findOpenedShift();
        if (openShift == null) {
          return Response.notFound('открытой смены нет');
        }
        await (db.update(db.shifts)
              ..where((sh) => sh.id.equals(openShift.id)))
            .write(
              ShiftsCompanion(
                isOpened: const Value(false),
                closeTime: Value(
                  DateTime.now().millisecondsSinceEpoch ~/ 1000,
                ),
              ),
            );
        stdout.writeln('[стенд] смена #${openShift.id} закрыта');
        return _json({'shiftId': openShift.id, 'closed': true});

      // Денежный счёт кассы и ссылка на него — то же, что делает мастер
      // настройки (`LocalSetupRepository.completeSetup`, шаг 3).
      case 'stand/seed-cash-account':
        const accountId = 1;
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: const Value(accountId),
                type: 0,
                value: Value(Decimal.zero),
              ),
            );
        await db.customUpdate(
          'UPDATE this_pos_entries SET account_id = ? WHERE r_id = 1',
          variables: [Variable.withInt(accountId)],
          updates: {db.thisPosEntries},
        );
        stdout.writeln('[стенд] заведён денежный счёт кассы #$accountId');
        return _json({'accountId': accountId});

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

      // Задача 21 (приёмка семи сценариев), сценарий 4: кассир с **названным
      // снаружи** отнятым правом.
      //
      // Три соседние команды выше заводят кассиров с заранее вписанными в
      // этот файл ключами (`settings.hardware`, `settings.users`). Сценарий 4
      // требует четвёртого — без `op.sellDiscount`, — и добавлять четвёртую
      // константу значило бы заводить пятую при следующем сценарии. Ключ
      // приходит доводом, а не именем в коде.
      //
      // **Неизвестный ключ — отказ, а не пропуск.** Опечатка в `deny=`
      // при молчаливом пропуске завела бы кассира с ПОЛНЫМ набором прав, и
      // сценарий «касса отказала по праву» прошёл бы зелёным, не проверив
      // ничего: отказа не было бы, потому что права были. Это ровно тот род
      // зелёного цвета, который означает «не смотрели туда».
      case 'stand/seed-cashier':
        final seedName =
            request.url.queryParameters['name'] ?? 'Кассир Без Права';
        final seedPin = request.url.queryParameters['pin'] ?? '1111';
        final denied = (request.url.queryParameters['deny'] ?? '')
            .split(',')
            .where((part) => part.isNotEmpty)
            .toSet();
        final unknown = denied.difference(PermissionKeys.allPermissions);
        if (unknown.isNotEmpty) {
          return Response.badRequest(
            body:
                'неизвестные ключи прав: ${unknown.join(", ")}. '
                'Отказываюсь заводить кассира с полным набором прав под '
                'видом ограниченного.',
          );
        }
        final seedId = await db.userDao.createCashier(
          name: seedName,
          passwordEnc: PinCredential.create(seedPin),
        );
        // Полный набор минус названные — тем же вызовом, что и рабочий код
        // (`setPermissions`), и по тому же доводу, что у
        // `stand/seed-restricted-cashier`: одна строка `false` при пустых
        // остальных не отличалась бы от кассира вовсе без строк.
        await db.userPermissionDao.setPermissions(seedId, {
          for (final key in PermissionKeys.allPermissions)
            key: !denied.contains(key),
        });
        stdout.writeln(
          '[стенд] заведён кассир #$seedId «$seedName» (PIN $seedPin), '
          'отнято: ${denied.isEmpty ? "ничего" : denied.join(", ")}',
        );
        return _json({
          'id': seedId,
          'name': seedName,
          'pin': seedPin,
          'deniedPermissions': denied.toList(),
        });

      // Задача 21, сценарий 5: рабочее место без права на наличные.
      //
      // Колонку `terminals.allowed_payment_types` (схема v38) на кассе пишет
      // ровно один код — `LocalTerminalRepository.setAllowedPaymentTypes`, —
      // и зовётся он здесь, а не запросом в обход: собственный `UPDATE`
      // прошёл бы мимо проверки «набор состоит из тендеров» и записал бы
      // `{mixed}`, от которого рабочее место немеет целиком. Тогда сценарий
      // 5 показал бы отказ, но не тот.
      //
      // Пустое `types` означает «все виды» (докстринг колонки) — то есть
      // этой же командой ограничение снимается обратно.
      case 'stand/terminal-payments':
        final targetId = int.tryParse(request.url.queryParameters['id'] ?? '');
        if (targetId == null) {
          return Response.badRequest(body: 'нужен довод id=<номер терминала>');
        }
        final rawTypes = (request.url.queryParameters['types'] ?? '')
            .split(',')
            .where((part) => part.isNotEmpty);
        final Set<PaymentType> types;
        try {
          // Тот же разбор, которым пользуется и провод, и хранение: второй
          // разбор того же формата был бы вторым ответом на вопрос «что
          // разрешено рабочему месту».
          types = paymentTypesFromNames(rawTypes, terminalId: targetId);
        } on StateError catch (error) {
          return Response.badRequest(body: '$error');
        }
        try {
          await terminals.setAllowedPaymentTypes(targetId, types);
        } on WireRefusal catch (refusal) {
          return Response.badRequest(
            body: '${refusal.code}: ${refusal.message}',
          );
        }
        stdout.writeln(
          '[стенд] терминалу #$targetId разрешены виды оплаты: '
          '${types.isEmpty ? "все" : types.map((t) => t.name).join(", ")}',
        );
        return _json({
          'terminalId': targetId,
          'allowedPaymentTypes': [for (final t in types) t.name],
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

      // Совершённый чек — то, без чего **главный сценарий задачи 20 не
      // проверяется живьём вовсе**.
      //
      // Возврат бывает по чеку и без чека. Без чека стенд проверить давал
      // (товар в каталоге), по чеку — нет: команды, заводящей проданный чек,
      // у стенда не было ни одной из двенадцати. Значит главный сценарий
      // возврата не проходил ни разу за всё существование стенда.
      //
      // Команда только **сеет данные** — `Sales`, `SaleProducts`, `Payments`
      // и снятый остаток, ровно то, что оставляет за собой настоящая
      // продажа, — и не трогает ни строки того кода кассы, который
      // проверяется.
      //
      // Соседние денежные команды (`seed-product`, `open-shift`,
      // `seed-cash-account`) живут на ветви стенда и при слиянии встанут
      // рядом; без них этот чек нечем оплатить и не с чего вернуть.
      case 'stand/seed-sale':
        final saleReceiptNo =
            int.tryParse(request.url.queryParameters['receipt'] ?? '') ?? 5001;
        final saleUcode =
            int.tryParse(request.url.queryParameters['ucode'] ?? '') ?? 100;
        final salePrice = Decimal.parse(
          request.url.queryParameters['price'] ?? '500',
        );
        final saleQuantity = Decimal.parse(
          request.url.queryParameters['quantity'] ?? '2',
        );
        final saleAmount = salePrice * saleQuantity;
        final saleTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        await db
            .into(db.sales)
            .insert(
              SalesCompanion.insert(
                receiptNo: saleReceiptNo,
                posId: 1,
                userId: 1,
                amount: saleAmount,
                time: saleTime,
                state: const Value(1),
              ),
            );
        await db
            .into(db.saleProducts)
            .insert(
              SaleProductsCompanion.insert(
                receiptNo: Value(saleReceiptNo),
                posId: const Value(1),
                ucode: saleUcode,
                quantity: saleQuantity,
                price: salePrice,
                priceBefore: salePrice,
              ),
            );
        await db
            .into(db.payments)
            .insert(
              PaymentsCompanion.insert(
                userId: 1,
                payeeAccountId: 1,
                amount: saleAmount,
                time: saleTime,
                receiptNo: Value(saleReceiptNo),
                posId: const Value(1),
                state: const Value(1),
              ),
            );
        // Продажа снимает товар с остатка — иначе «товар вернулся» нечем
        // отличить от «остаток не тронут».
        await db.productInfoDao.adjustQuantity(saleUcode, -saleQuantity);
        // Деньги за проданное лежат на счёте кассы: возврат обязан их снять.
        final cashBefore =
            (await db.accountDao.findById(1))?.value ?? Decimal.zero;
        await db.accountDao.updateBalance(1, cashBefore + saleAmount);

        stdout.writeln(
          '[стенд] заведён совершённый чек №$saleReceiptNo: '
          '$saleQuantity × $salePrice = $saleAmount, счёт кассы '
          '${cashBefore + saleAmount}',
        );
        return _json({
          'receiptNo': saleReceiptNo,
          'posId': 1,
          'amount': saleAmount.toString(),
          'cashAccount': (cashBefore + saleAmount).toString(),
        });

      // ── приёмка «полнота продажи»: виды оплаты ────────────────────────
      //
      // Восемь команд ниже заведены задачей 25 (живая приёмка). Общий довод
      // тот же, что у всех остальных: состояние кассы меняется **с петли**,
      // а не при подъёме, — иначе проверка «касса сказала первой» проверяет
      // не то. Каждая из них закрывает ровно одну причину, по которой вид
      // оплаты был бы недостижим с экрана.

      // Тумблеры мастера настройки. **Оба по умолчанию `false`**
      // (`this_pos_tables.dart`), и оба — не право и не разрешение места, а
      // свойство кассы:
      //
      // * `sell_in_debt` — без него кнопки «В долг» и «Рассрочка» гаснут, а
      //   кадр, собранный мимо экрана, получает `debt_not_sold_here`
      //   (`_requireDebtSoldHere`). Ровно это и случилось на приёмке
      //   2026-09-07: тумблер был выключен, и кнопка гасла.
      // * `sell_in_discount` — без него **любая** ручная скидка отказывает
      //   `denied_policy` РАНЬШЕ, чем предел роли вообще спрашивается
      //   (`_decideDiscount`), и «предел сработал» стало бы неотличимо от
      //   «скидки запрещены вовсе».
      case 'stand/sell-settings':
        bool? flag(String name) {
          final raw = request.url.queryParameters[name];
          if (raw == null || raw.isEmpty) return null;
          return raw == '1' || raw == 'true' || raw == 'on';
        }

        final debtFlag = flag('debt');
        final discountFlag = flag('discount');
        if (debtFlag == null && discountFlag == null) {
          return Response.badRequest(
            body: 'нужен хотя бы один довод: debt=1|0, discount=1|0',
          );
        }
        await db.customUpdate(
          'UPDATE this_pos_entries SET '
          'sell_in_debt = COALESCE(?, sell_in_debt), '
          'sell_in_discount = COALESCE(?, sell_in_discount) WHERE r_id = 1',
          variables: [
            debtFlag == null
                ? const Variable<int>(null)
                : Variable.withInt(debtFlag ? 1 : 0),
            discountFlag == null
                ? const Variable<int>(null)
                : Variable.withInt(discountFlag ? 1 : 0),
          ],
          updates: {db.thisPosEntries},
        );
        final posNow = await db.thisPosDao.get();
        stdout.writeln(
          '[стенд] тумблеры кассы: продажа в кредит '
          '${posNow?.sellInDebt}, ручная скидка ${posNow?.sellInDiscount}',
        );
        return _json({
          'sellInDebt': posNow?.sellInDebt,
          'sellInDiscount': posNow?.sellInDiscount,
        });

      // Включить системные виды оплаты, приезжающие **выключенными**.
      //
      // Это не украшение стенда, а единственный способ вообще увидеть
      // четыре вида: `certificate` (5), `qr` (6), `prepayment` (7) и
      // `installment` (8) заведены `isActive: false`
      // (`SystemPaymentKinds`), а `_plan` отказывает `payment_kind_inactive`
      // любой строке оплаты выключенного вида. То есть без этой команды
      // сертификат, QR, аванс и рассрочка отказывают **до** всякой
      // проверки денег, и отказ этот легко принять за дефект вида оплаты.
      //
      // Отдельная команда, а не часть подъёма, по общему доводу файла:
      // «вид выключен» — законное состояние кассы, и отказ на нём тоже надо
      // уметь увидеть.
      case 'stand/payment-kinds':
        const byName = <String, int>{
          'certificate': SystemPaymentKindIds.certificate,
          'qr': SystemPaymentKindIds.qr,
          'prepayment': SystemPaymentKindIds.prepayment,
          'installment': SystemPaymentKindIds.installment,
        };
        final rawOn = request.url.queryParameters['on'] ?? '';
        final wantedNames = rawOn == 'all'
            ? byName.keys.toSet()
            : rawOn.split(',').where((p) => p.isNotEmpty).toSet();
        if (wantedNames.isEmpty) {
          return Response.badRequest(
            body:
                'нужен довод on=all или on=${byName.keys.join(",")} '
                '(через запятую)',
          );
        }
        // Неизвестное имя — отказ, а не пропуск: опечатка при молчаливом
        // пропуске оставила бы вид выключенным, и «сертификат не проходит»
        // читалось бы дефектом продукта.
        final unknownKinds = wantedNames.difference(byName.keys.toSet());
        if (unknownKinds.isNotEmpty) {
          return Response.badRequest(
            body:
                'неизвестные виды: ${unknownKinds.join(", ")}; можно '
                '${byName.keys.join(", ")}',
          );
        }
        final offRaw = request.url.queryParameters['off'] ?? '';
        final offNames = offRaw
            .split(',')
            .where((p) => p.isNotEmpty && byName.containsKey(p))
            .toSet();
        for (final kindName in wantedNames) {
          await db.paymentKindDao.put(
            SystemPaymentKinds.byId(
              byName[kindName]!,
            ).copyWith(isActive: !offNames.contains(kindName)),
          );
        }
        stdout.writeln(
          '[стенд] виды оплаты включены: ${wantedNames.join(", ")}'
          '${offNames.isEmpty ? "" : "; выключены: ${offNames.join(", ")}"}',
        );
        return _json({
          'enabled': wantedNames.toList(),
          'disabled': offNames.toList(),
        });

      // Покупатель: бонусный счёт, расчётный счёт и аванс на нём.
      //
      // **Один агент, два счёта, и они разные по смыслу** — это и есть та
      // деталь, на которой ломается наивный засев:
      //
      // * `agents.cashback_account_id` → счёт рода `agentCashback` (4). Из
      //   него `findLoyalty` берёт остаток бонуса; заведи счёт другого
      //   рода — гашение бонуса пойдёт с обратным знаком
      //   (`AccountPosting.isRedemption`).
      // * `agents.main_account_id` → счёт рода `agentMain` (3). **Он же
      //   аванс, он же долг**: положительный остаток — деньги покупателя,
      //   лежащие у кассы (аванс), отрицательный — долг. Своей таблицы у
      //   аванса нет, и это не пропуск, а решение (спека, ярус 6).
      //
      // Без `main_account_id` долг и рассрочка отказывают
      // `debt_account_missing`, а аванс — `prepayment_account_missing`;
      // без `cashback_account_id` бонус отказывает `bonus_account_missing`.
      // Все три отказа приходят **после** выбора покупателя на экране, то
      // есть выглядят дефектом вида оплаты.
      //
      // Остаток пишется **прямо в `value` при вставке**, а не
      // `updateBalance`: у бонусных родов `updateBalance` бросает
      // `StateError` без `redemption: true` (`account_dao.dart`). Цена —
      // `BonusEntryDao.divergences()` увидит счёт разошедшимся с журналом
      // начислений; на оплату это не влияет, и здесь названо, чтобы не
      // искали дефект в сверке.
      case 'stand/seed-customer':
        final phoneRaw = (request.url.queryParameters['phone'] ?? '77011234567')
            .replaceAll(RegExp(r'\D'), '');
        final phone = int.tryParse(phoneRaw);
        if (phone == null) {
          return Response.badRequest(body: 'phone= должен быть числом');
        }
        // Второй агент с тем же телефоном сделал бы `findLoyalty`
        // бросающим (`getSingleOrNull`), а не отвечающим «нет такого», —
        // отказ, который читался бы дефектом поиска.
        if (await db.agentDao.findByPhone(phone) != null) {
          return Response.badRequest(
            body:
                'покупатель с телефоном $phone уже заведён; findByPhone '
                'у двоих бросает, а не отвечает «нет такого»',
          );
        }
        final customerName =
            request.url.queryParameters['name'] ?? 'Покупатель Бонусный';
        final bonus = Decimal.parse(
          request.url.queryParameters['bonus'] ?? '0',
        );
        final prepay = Decimal.parse(
          request.url.queryParameters['prepay'] ?? '0',
        );
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final customerId = await db
            .into(db.agents)
            .insert(
              AgentsCompanion.insert(
                // 1 — покупатель (`AgentDao.countCustomers` считает по нему).
                type: const Value(1),
                name: Value(customerName),
                phone: Value(phone),
                isDeleted: const Value(false),
                editTime: Value(nowSec),
              ),
            );
        // Отрицательные номера — соглашение самой кассы для счетов
        // контрагентов (`persist_agent_use_case_impl.dart` берёт `MIN(id)`
        // среди отрицательных и убавляет). Положительные заняты счетами
        // кассы (`AccountDao.getNextId()` — `MAX(id)+1`), и смешать их
        // значило бы однажды выдать кассе номер счёта покупателя.
        final mainAccountId = -(1000 + customerId * 2);
        final cashbackAccountId = -(1001 + customerId * 2);
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: Value(mainAccountId),
                type: AccountType.agentMain,
                name: Value('$customerName — расчётный'),
                value: Value(prepay),
                agentId: Value(customerId),
                // НЕ виден кассе: `accounts()` отдаёт только роды 0 и 1 с
                // `visible_to_pos = true`, и счёт покупателя в списке
                // «куда принять деньги» был бы прямой ошибкой учёта.
                visibleToPos: const Value(false),
                updateTime: Value(nowSec),
              ),
            );
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: Value(cashbackAccountId),
                type: AccountType.agentCashback,
                name: Value('$customerName — бонусный'),
                value: Value(bonus),
                agentId: Value(customerId),
                visibleToPos: const Value(false),
                updateTime: Value(nowSec),
              ),
            );
        await (db.update(
          db.agents,
        )..where((a) => a.localId.equals(customerId))).write(
          AgentsCompanion(
            mainAccountId: Value(mainAccountId),
            cashbackAccountId: Value(cashbackAccountId),
          ),
        );
        stdout.writeln(
          '[стенд] заведён покупатель #$customerId «$customerName», '
          'телефон $phone, бонус $bonus (счёт $cashbackAccountId), '
          'аванс $prepay (счёт $mainAccountId)',
        );
        return _json({
          'customerId': customerId,
          'name': customerName,
          'phone': phone,
          'bonus': bonus.toString(),
          'bonusAccountId': cashbackAccountId,
          'prepayment': prepay.toString(),
          'mainAccountId': mainAccountId,
        });

      // Счёт банка, видимый кассе, — для карты и QR.
      //
      // Без него касса **не падает**: `_bankAccountId` заводит счёт
      // эквайринга сама. Но заводит она его безымянным и в момент первой
      // оплаты, а экран оплаты показывает список счетов **до** неё, — то
      // есть кассиру выбирать не из чего, и «карта не предлагает счёт»
      // выглядит дефектом экрана.
      case 'stand/seed-bank-account':
        final bankId =
            int.tryParse(request.url.queryParameters['id'] ?? '') ?? 2;
        final bankName =
            request.url.queryParameters['name'] ?? 'Эквайринг (банк)';
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: Value(bankId),
                type: AccountType.customBank,
                name: Value(bankName),
                value: Value(Decimal.zero),
                // Единственная величина, ради которой команда существует:
                // `null` здесь читается как «скрыт», а не как «не задано».
                visibleToPos: const Value(true),
                updateTime: Value(
                  DateTime.now().millisecondsSinceEpoch ~/ 1000,
                ),
              ),
              mode: InsertMode.insertOrReplace,
            );
        stdout.writeln(
          '[стенд] заведён счёт банка #$bankId «$bankName» (виден кассе)',
        );
        return _json({'accountId': bankId, 'name': bankName});

      // Выпущенная бумажка — **настоящим выпускающим**, а не вставкой.
      //
      // Разница не косметическая: `issue` заводит счёт обязательства
      // (`certificateLiability`, род 8), проставляет `liability_account_id`
      // и проводит номинал по этому счёту одной транзакцией. Вставка руками
      // оставляет `liability_account_id` пустым, и гашение отказывает
      // `certificate_account_missing` — то есть сертификат, выглядящий
      // выпущенным, не гасится ничем.
      case 'stand/seed-certificate':
        final certNumber = request.url.queryParameters['number'] ?? 'ПС-0001';
        final nominal = Decimal.parse(
          request.url.queryParameters['nominal'] ?? '5000',
        );
        final certPin = request.url.queryParameters['pin'];
        final days = int.tryParse(request.url.queryParameters['days'] ?? '');
        try {
          final issued = await certificates.issue(
            by: fullDiscountAuthority,
            number: certNumber,
            nominal: nominal,
            pin: (certPin == null || certPin.isEmpty) ? null : certPin,
            // Секунды, а не миллисекунды: у сертификата время в секундах
            // (`gift_certificates.expires_at`), у намерения QR — в
            // миллисекундах. Перепутанный масштаб делает бумажку вечной.
            expiresAt: days == null
                ? null
                : DateTime.now()
                          .add(Duration(days: days))
                          .millisecondsSinceEpoch ~/
                      1000,
          );
          stdout.writeln(
            '[стенд] выпущен сертификат «${issued.number}» номиналом '
            '${issued.nominal}, остаток ${issued.balance}',
          );
          return _json({
            'number': issued.number,
            'nominal': issued.nominal.toString(),
            'balance': issued.balance.toString(),
            'status': issued.status.code,
            'pin': certPin,
          });
        } on WireRefusal catch (refusal) {
          return Response.badRequest(
            body: '${refusal.code}: ${refusal.message}',
          );
        }

      // Оплаченное намерение QR/СБП — деньги, которые провайдер уже
      // подтвердил и которые ждут, чтобы их зачли в чек.
      //
      // **Читать вместе с оговоркой ниже.** Довести намерение до `paid`
      // умеет только `QrPaymentCoordinator`, у которого в `lib/` нет ни
      // одного производителя, а `qrIntentKey` не попал в кодек провода
      // (`pay_ops.dart` говорит это прямо). То есть сегодня с браузерного
      // терминала этот засев зачесть **нечем**: он готовит состояние,
      // которое станет достижимым, когда починка кодека приедет.
      //
      // Три шага, а не одна вставка: ровно этими тремя вызовами прошёл бы
      // настоящий провайдер, и `confirmations`/`confirmed_at` иначе
      // остались бы пустыми, то есть «деньги без чека» и сверка читали бы
      // не то.
      case 'stand/seed-qr-intent':
        final intentKey =
            request.url.queryParameters['key'] ?? 'stand-qr-000001';
        final intentAmount = Decimal.parse(
          request.url.queryParameters['amount'] ?? '1000',
        );
        final providerCode =
            request.url.queryParameters['provider'] ?? 'sbp_stand';
        final existing = await db.paymentIntentDao.byKey(intentKey);
        if (existing != null) {
          return Response.badRequest(
            body:
                'намерение «$intentKey» уже заведено (состояние '
                '${existing.status.code}); возьми другой key=',
          );
        }
        final (intentRow, _) = await db.paymentIntentDao.claim(
          intentKey: intentKey,
          providerCode: providerCode,
          amount: intentAmount,
          createdAt: DateTime.now(),
        );
        await db.paymentIntentDao.attachProviderIntent(
          id: intentRow.id,
          providerIntentId: 'PRV-$intentKey',
          status: QrIntentStatus.pending,
          qrPayload: 'https://qr.stand/$intentKey',
        );
        await db.paymentIntentDao.applyState(
          id: intentRow.id,
          status: QrIntentStatus.paid,
          paidAmount: intentAmount,
          confirmedAt: DateTime.now(),
          countConfirmation: true,
        );
        stdout.writeln(
          '[стенд] заведено оплаченное намерение QR «$intentKey» на '
          '$intentAmount (провайдер $providerCode)',
        );
        return _json({
          'intentKey': intentKey,
          'intentId': intentRow.id,
          'amount': intentAmount.toString(),
          'status': QrIntentStatus.paid.code,
          'providerCode': providerCode,
        });

      // Провайдер QR/СБП кассы — адрес отдельного процесса эмулятора.
      //
      // `seed-qr-intent` выше заводит уже ОПЛАЧЕННОЕ намерение прямо в базе и
      // провайдера не зовёт вовсе: для «кассир нажал QR, покупатель заплатил
      // телефоном» его мало — `QrPaymentDesk` без строки `qr_provider_configs`
      // отказывает `qr_not_configured` раньше первого запроса. Эта дверь
      // пишет ту же строку, что экран настройки, тем же `save`, и касса
      // ходит к эмулятору **по адресу** — единственная точка подстановки,
      // которую признаёт эмулятор (`test/emulators/sbp/emulator.dart`).
      //
      // Без `url` дверь только читает. **Ключ не отдаётся ни в одном
      // ответе**, даже здесь, на петле: `keySet` — да/нет. Довод тот же, что у
      // `QrProviderSettings.toString`: ответ двери попадает в журнал приёмки,
      // а журнал уезжает дальше, чем петля.
      case 'stand/qr-provider':
        final qrUrl = request.url.queryParameters['url'];
        if (qrUrl != null) {
          if (qrUrl.trim().isEmpty) {
            await db.qrProviderConfigDao.clear();
            stdout.writeln('[стенд] провайдер QR снят');
          } else {
            final patienceRaw = request.url.queryParameters['patience'];
            final patienceSeconds = int.tryParse(patienceRaw ?? '');
            if (patienceRaw != null && patienceSeconds == null) {
              return Response.badRequest(
                body: 'patience=<секунды целым числом>, пришло «$patienceRaw»',
              );
            }
            final keyRaw = request.url.queryParameters['key'];
            await db.qrProviderConfigDao.save(
              QrProviderSettings(
                baseUrl: qrUrl,
                code: request.url.queryParameters['code'] ?? 'sbp_stand',
                apiKey: keyRaw == null || keyRaw.isEmpty ? null : keyRaw,
                patience: patienceSeconds == null
                    ? QrProviderSettings.defaultPatience
                    : Duration(seconds: patienceSeconds),
              ),
              at: DateTime.now(),
            );
          }
        }
        final qrSettings = await db.qrProviderConfigDao.read();
        if (qrUrl != null) {
          // `toString` ключа не печатает — см. докстринг настройки.
          stdout.writeln('[стенд] провайдер QR: ${qrSettings ?? "не заведён"}');
        }
        return _json({
          'configured': qrSettings != null,
          if (qrSettings != null) ...{
            'baseUrl': qrSettings.baseUrl,
            'code': qrSettings.code,
            'keySet': qrSettings.apiKey != null,
            'patienceSeconds': qrSettings.patience.inSeconds,
            'complete': qrSettings.isComplete,
          },
        });

      // Предел ручной скидки роли.
      //
      // Ключ таблицы — `UserRole.index`: 0 владелец, 1 администратор,
      // 2 пользователь, 3 кассир; `-1` — строка умолчания «все роли», её
      // кладёт миграция со ста процентами. Значит **два кассира одной роли
      // делят один предел**, и «упирающийся» с «не упирающимся» обязаны
      // быть разных ролей.
      //
      // `role` передаётся всегда и явно: в drift этот столбец —
      // необязательный псевдоним rowid, и пропуск молча завёл бы предел
      // роли 1, 2, 3… по счёту вставок. Кассир при этом остался бы со
      // стопроцентным умолчанием, а проверка «предел сработал» прошла бы
      // зелёной, ничего не проверив.
      case 'stand/discount-limit':
        final roleIndex = int.tryParse(
          request.url.queryParameters['role'] ?? '',
        );
        if (roleIndex == null) {
          return Response.badRequest(
            body:
                'нужен довод role=<число>: 0 владелец, 1 администратор, '
                '2 пользователь, 3 кассир, -1 умолчание «все роли»',
          );
        }
        final maxPercent = Decimal.parse(
          request.url.queryParameters['max'] ?? '100',
        );
        final approvalRaw = request.url.queryParameters['approval'];
        final approvalAbove = (approvalRaw == null || approvalRaw.isEmpty)
            ? null
            : Decimal.parse(approvalRaw);
        await db
            .into(db.discountLimits)
            .insertOnConflictUpdate(
              DiscountLimitsCompanion.insert(
                role: Value(roleIndex),
                maxPercentPerLine: Value(maxPercent),
                approvalAbovePercent: Value(approvalAbove),
              ),
            );
        stdout.writeln(
          '[стенд] предел скидки роли $roleIndex: $maxPercent %'
          '${approvalAbove == null ? "" : ", подтверждение выше $approvalAbove %"}',
        );
        return _json({
          'role': roleIndex,
          'maxPercentPerLine': maxPercent.toString(),
          'approvalAbovePercent': approvalAbove?.toString(),
        });

      // Роль заведённого человека.
      //
      // Нужна ровно затем, что **предел скидки принадлежит роли, а не
      // человеку**: `discount_limits.role` — это `UserRole.index`, и два
      // кассира одной роли делят один предел. А `UserDao.createCashier`
      // вписывает роль 3 (`cashier`) намертво — то есть все, кого умеет
      // завести стенд, попадают под одну строку предела, и «кассир,
      // упирающийся в предел» неотличим от «кассира с пределом».
      //
      // Роль читает сторож не из базы, а **из сеанса**
      // (`TillOperations._authorityOf` сверяет `session.role` с именами
      // `UserRole`), поэтому менять её надо ДО входа: у уже выписанного
      // сеанса роль прежняя, и правка выглядела бы не подействовавшей.
      case 'stand/set-user-role':
        final userIdRaw = int.tryParse(request.url.queryParameters['id'] ?? '');
        final roleRaw = request.url.queryParameters['role'] ?? '';
        if (userIdRaw == null) {
          return Response.badRequest(body: 'нужен довод id=<номер кассира>');
        }
        final role = UserRole.values
            .where((r) => r.name == roleRaw || '${r.index}' == roleRaw)
            .firstOrNull;
        // Неизвестное имя — отказ, а не пропуск: молча оставленная роль
        // `cashier` дала бы обоим кассирам один предел, и проверка «предел
        // роли различает людей» прошла бы зелёной, ничего не различив.
        if (role == null) {
          return Response.badRequest(
            body:
                'неизвестная роль «$roleRaw»; можно '
                '${UserRole.values.map((r) => "${r.name} (${r.index})").join(", ")}',
          );
        }
        final touched = await db.userDao.updateUser(
          userIdRaw,
          UsersCompanion(role: Value(role.index)),
        );
        if (touched == 0) {
          return Response.badRequest(body: 'кассира #$userIdRaw нет');
        }
        stdout.writeln(
          '[стенд] кассиру #$userIdRaw выставлена роль '
          '${role.name} (${role.index})',
        );
        return _json({
          'userId': userIdRaw,
          'role': role.name,
          'roleIndex': role.index,
        });

      // Куда касса шлёт фискальный документ.
      //
      // `operator=none` (умолчание стенда) — записывающая заглушка: журнал
      // портов есть, документа нет. `operator=webkassa&url=…` — настоящий
      // `WebKassaProvider` в той же обёртке, что и боевой DI; документы
      // становятся видны в журнале эмулятора.
      //
      // Довод, почему настройка живёт полем стенда, а не в prefs, — в
      // докстринге [StandFiscalPort].
      case 'stand/fiscal':
        final operatorRaw = request.url.queryParameters['operator'] ?? '';
        FiscalOperatorType? operatorType;
        for (final type in FiscalOperatorType.values) {
          if (type.name == operatorRaw) operatorType = type;
        }
        if (operatorType == null) {
          return Response.badRequest(
            body:
                'нужен довод operator=${FiscalOperatorType.values.map((t) => t.name).join("|")}',
          );
        }
        if (operatorType != FiscalOperatorType.none &&
            operatorType != FiscalOperatorType.webkassa) {
          return Response.badRequest(
            body:
                'стенд поднимает только webkassa (эмулятор есть только у '
                'неё) и none (заглушка); ${operatorType.name} не поднят',
          );
        }
        fiscal.settings = FiscalSettings(
          operatorType: operatorType,
          testMode: true,
          baseUrl: request.url.queryParameters['url'],
          // Пустая строка, а не `null`: заполненное поле «локальный модуль»
          // перебивает адрес сервера — `WebKassaProvider._baseUrl` смотрит
          // на него первым, и это уже стоило одного разбора.
          localModuleUrl: '',
          login: request.url.queryParameters['login'] ?? 'emul',
          password: request.url.queryParameters['password'] ?? 'emul',
          apiKey:
              request.url.queryParameters['apiKey'] ??
              'emulated-integrator-key',
          cashboxUniqueNumber:
              request.url.queryParameters['cashbox'] ?? 'SWK00000001',
          registrationNumber:
              request.url.queryParameters['reg'] ?? '000000000001',
        );
        stdout.writeln(
          '[стенд] фискальный оператор: ${operatorType.name}, адрес '
          '${fiscal.settings.resolvedBaseUrl ?? "—"}',
        );
        return _json({
          'operator': operatorType.name,
          'baseUrl': fiscal.settings.resolvedBaseUrl,
          'cashbox': fiscal.settings.cashboxUniqueNumber,
          'real': fiscal.isReal,
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

/// Кассовый конец провода, который можно опустить и поднять обратно.
///
/// Держатель, а не пара `final` переменных: `stand/wire` подменяет и
/// слушатель, и обёртки над ним разом, а управляющая дверь заведена раньше и
/// держит ссылку. Со свободными переменными она держала бы **старый**,
/// закрытый слушатель и отвечала бы про него — то есть врала бы ровно про ту
/// величину, ради которой её и читают (та же ошибка, что уже была измерена в
/// строке «слушает 0.0.0.0» этого файла).
class _StandWire {
  _StandWire(this.endpoint, this.wires);

  WebTransportEndpoint endpoint;
  List<TillWire> wires;

  bool get isUp => wires.isNotEmpty;

  /// Ноль при опущенном проводе — это правда, а не заглушка: подписок нет,
  /// потому что нет и слушателя.
  int get liveSubscriptions =>
      wires.isEmpty ? 0 : wires.first.liveSubscriptions;
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

/// Фискальный порт стенда: **запись всегда, настоящий оператор — по команде**.
///
/// # Зачем понадобился третий вариант
///
/// Их было два, и оба неполны для приёмки «полнота продажи»:
///
/// * [RecordingFiscalService] записывает, чем касса позвала порт, и ничего не
///   фискализует. Читаемый журнал есть, документа нет — увидеть чек глазами
///   негде.
/// * настоящий `FiscalServiceImpl` фискализует, но в журнал портов стенда не
///   пишет ни строки: порядок «оператор ответил раньше печати» перестал бы
///   быть наблюдаемым, а он — предмет проверки сценария 6.
///
/// Этот порт делает и то, и другое: **сначала запись довода в общий журнал**
/// (чем позвали), потом — вызов выбранного исполнителя, и **вторая запись с
/// исходом** (чем ответили). Ни одна из двух наблюдаемых величин не теряется.
///
/// # Чего он по-прежнему НЕ доказывает
///
/// С [settings] `operatorType: none` (умолчание) исполнитель — запись, и
/// действует ровно оговорка `stand_hardware_recorder.dart`: документа нет.
///
/// С настоящим оператором доказано, что **эта касса собрала документ и
/// оператор его принял**. Оператор здесь — эмулятор
/// (`test/emulators/webkassa/`), и от боевой WebKassa он отличается адресом;
/// «настоящая WebKassa ответила бы так же» этим не доказано и доказано быть
/// не может — докстринг эмулятора говорит то же самое.
///
/// # Почему настройки живут здесь, а не в `SharedPreferences`
///
/// Боевая касса берёт их `StoreFiscalSettingsSource` из prefs, и стенд мог бы
/// написать туда же. Но prefs у `flutter_test` — общий на процесс изменяемый
/// глобал, переживающий подъём: живая проверка тогда зависела бы от того, что
/// осталось от прошлого прогона. Здесь настройка — поле, меняемое одной
/// командой на петле, ровно тем же приёмом, каким стенд меняет всё остальное
/// состояние кассы.
class StandFiscalPort implements FiscalService {
  StandFiscalPort({
    required StandHardwareJournal journal,
    required AppDatabase db,
    required Talker logger,
    required FiscalQueueStore queue,
  }) : _journal = journal,
       _db = db,
       _logger = logger,
       _queue = queue,
       _recorder = RecordingFiscalService(journal);

  final StandHardwareJournal _journal;
  final AppDatabase _db;
  final Talker _logger;
  final FiscalQueueStore _queue;
  final RecordingFiscalService _recorder;

  /// Настройки оператора. `none` — исполнитель запись; иное — настоящий
  /// `FiscalServiceImpl` над тем же реестром провайдеров, что и боевой DI.
  FiscalSettings settings = FiscalSettings();

  bool get isReal => settings.operatorType != FiscalOperatorType.none;

  /// Собирается заново на каждый вызов, а не кэшируется: адрес меняется
  /// командой на петле, и кэш отвечал бы про прошлый адрес — ровно тот род
  /// лжи, ради снятия которого команда и заведена.
  FiscalService get _real => FiscalServiceImpl(
    db: _db,
    logger: _logger,
    settingsSource: _StandFiscalSettingsSource(() => settings),
    // Тот же реестр и та же обёртка, что и в `service_locator.dart`:
    // подменённая обёртка означала бы, что стенд меряет не тот путь.
    registry: FiscalProviderRegistry()
      ..register(
        FiscalOperatorType.webkassa,
        (s) => OfflineQueueingProvider(
          inner: WebKassaProvider(settings: s, logger: _logger),
          store: _queue,
          isReachable: () async => true,
        ),
      ),
  );

  @override
  Future<FiscalSettings> currentSettings() async => settings;

  /// Включён всегда — по тому же доводу, что у [RecordingFiscalService]:
  /// `false` увёл бы кассу мимо `fiscalizeSale` ещё до вызова, и путь снова
  /// оказался бы непройденным, только молча.
  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<FiscalResult> fiscalizeSale({
    required int saleReceiptNo,
    required int salePosId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
    String? customerBin,
  }) async {
    if (!isReal) {
      return _recorder.fiscalizeSale(
        saleReceiptNo: saleReceiptNo,
        salePosId: salePosId,
        amount: amount,
        cashAmount: cashAmount,
        cardAmount: cardAmount,
        mobileAmount: mobileAmount,
        bonusAmount: bonusAmount,
        offsetAmount: offsetAmount,
        offsetLayout: offsetLayout,
        excludeCertificatePositions: excludeCertificatePositions,
        customerBin: customerBin,
      );
    }
    _journal.record('fiscal', 'fiscalizeSale', {
      'receiptNo': saleReceiptNo,
      'posId': salePosId,
      'amount': amount.toString(),
      'cashAmount': cashAmount.toString(),
      'cardAmount': cardAmount.toString(),
      'mobileAmount': mobileAmount.toString(),
      'bonusAmount': bonusAmount.toString(),
      'offsetAmount': offsetAmount.toString(),
      'offsetLayout': offsetLayout.name,
      'excludeCertificatePositions': excludeCertificatePositions,
      // Сам ИИН/БИН не записывается — только то, был ли он назван: это
      // персональные данные, а журнал стенда читается и пересылается.
      'customerBinGiven': customerBin != null && customerBin.isNotEmpty,
      'operator': settings.operatorType.name,
      'baseUrl': settings.resolvedBaseUrl,
    });
    return _recordOutcome(
      'fiscalizeSale',
      () => _real.fiscalizeSale(
        saleReceiptNo: saleReceiptNo,
        salePosId: salePosId,
        amount: amount,
        cashAmount: cashAmount,
        cardAmount: cardAmount,
        mobileAmount: mobileAmount,
        bonusAmount: bonusAmount,
        offsetAmount: offsetAmount,
        offsetLayout: offsetLayout,
        excludeCertificatePositions: excludeCertificatePositions,
        customerBin: customerBin,
      ),
    );
  }

  @override
  Future<FiscalResult> fiscalizeRefund({
    required int refundLocalId,
    required int? originalSaleReceiptNo,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal creditAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
  }) async {
    if (!isReal) {
      return _recorder.fiscalizeRefund(
        refundLocalId: refundLocalId,
        originalSaleReceiptNo: originalSaleReceiptNo,
        amount: amount,
        cashAmount: cashAmount,
        cardAmount: cardAmount,
        mobileAmount: mobileAmount,
        bonusAmount: bonusAmount,
        creditAmount: creditAmount,
        offsetAmount: offsetAmount,
        offsetLayout: offsetLayout,
        excludeCertificatePositions: excludeCertificatePositions,
      );
    }
    _journal.record('fiscal', 'fiscalizeRefund', {
      'refundLocalId': refundLocalId,
      'originalSaleReceiptNo': originalSaleReceiptNo,
      'amount': amount.toString(),
      'cashAmount': cashAmount.toString(),
      'cardAmount': cardAmount.toString(),
      'mobileAmount': mobileAmount.toString(),
      'offsetAmount': offsetAmount.toString(),
      'operator': settings.operatorType.name,
      'baseUrl': settings.resolvedBaseUrl,
    });
    return _recordOutcome(
      'fiscalizeRefund',
      () => _real.fiscalizeRefund(
        refundLocalId: refundLocalId,
        originalSaleReceiptNo: originalSaleReceiptNo,
        amount: amount,
        cashAmount: cashAmount,
        cardAmount: cardAmount,
        mobileAmount: mobileAmount,
        bonusAmount: bonusAmount,
        creditAmount: creditAmount,
        offsetAmount: offsetAmount,
        offsetLayout: offsetLayout,
        excludeCertificatePositions: excludeCertificatePositions,
      ),
    );
  }

  @override
  Future<FiscalResult> fiscalizePrepayment({
    required int operationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  }) async {
    if (!isReal) {
      return _recorder.fiscalizePrepayment(
        operationId: operationId,
        amount: amount,
        paymentKind: paymentKind,
        positionName: positionName,
      );
    }
    _journal.record('fiscal', 'fiscalizePrepayment', {
      'operationId': operationId,
      'amount': amount.toString(),
      'paymentKind': paymentKind.name,
      'operator': settings.operatorType.name,
      'baseUrl': settings.resolvedBaseUrl,
    });
    return _recordOutcome(
      'fiscalizePrepayment',
      () => _real.fiscalizePrepayment(
        operationId: operationId,
        amount: amount,
        paymentKind: paymentKind,
        positionName: positionName,
      ),
    );
  }

  /// Исход настоящего оператора — второй записью, а не подменой первой.
  ///
  /// Отказ записывается и **пробрасывается дальше**: проглотить его значило
  /// бы сделать неотличимыми «оператор принял» и «оператор отказал», то есть
  /// ровно тот ложный зелёный, ради снятия которого заглушки и написаны.
  Future<FiscalResult> _recordOutcome(
    String call,
    Future<FiscalResult> Function() body,
  ) async {
    try {
      final result = await body();
      _journal.record('fiscal', '$call.ответ', {
        'success': result.success,
        'fiscalSign': result.fiscalSign,
        'errorCode': result.errorCode.name,
        'errorMessage': result.errorMessage,
      });
      return result;
    } on Object catch (error) {
      _journal.record('fiscal', '$call.бросил', {'error': '$error'});
      rethrow;
    }
  }

  /// Всё остальное — настоящему оператору, если он выбран, и громко, если
  /// нет: правдоподобный ответ на метод, о котором не спрашивали, был бы
  /// вторым изданием молчаливого `null`.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (isReal) return _real.noSuchMethod(invocation);
    return _recorder.noSuchMethod(invocation);
  }
}

/// Источник настроек, читающий **поле стенда**, а не хранилище.
///
/// Функция, а не значение: адрес меняется командой на петле, и захваченная
/// копия отвечала бы про адрес, который был при сборке.
class _StandFiscalSettingsSource implements FiscalSettingsSource {
  _StandFiscalSettingsSource(this._read);

  final FiscalSettings Function() _read;

  @override
  Future<FiscalSettings> load() async => _read();
}

/// Кто из пяти вкладок диагностики доехал, а кто нет.
///
/// Заведено живой приёмкой 2026-09-19: четыре вкладки из пяти показывали
/// вечный спиннер, и отличить «касса не ответила» от «кадр не разобрался»
/// было нечем — вкладка рисует спиннер и при ошибке потока тоже
/// (`snapshot.data == null`), то есть отказ выглядит ожиданием.
class _TracingDiagnostics implements HardwareDiagnosticsRepository {
  _TracingDiagnostics(this._inner);

  final HardwareDiagnosticsRepository _inner;

  Stream<T> _trace<T>(String name, Stream<T> Function() build) async* {
    _say('$name: подписка начата');
    try {
      var frames = 0;
      await for (final value in build()) {
        frames++;
        if (frames <= 2) _say('$name: кадр $frames');
        yield value;
      }
      _say('$name: поток закончился, кадров $frames');
    } on Object catch (error, stack) {
      _say('$name: БРОСИЛ $error');
      _say('\$name: \$stack');
      rethrow;
    }
  }

  static void _say(String line) {
    // ignore: avoid_print
    print('[диагностика] $line');
  }

  @override
  Stream<PrinterDiagnosticsView> watchPrinter() =>
      _trace('принтер', _inner.watchPrinter);

  @override
  Stream<DrawerDiagnosticsView> watchDrawer() =>
      _trace('ящик', _inner.watchDrawer);

  @override
  Stream<DisplayDiagnosticsView> watchDisplay() =>
      _trace('дисплей', _inner.watchDisplay);

  @override
  Stream<ScalesDiagnosticsView> watchScales() =>
      _trace('весы', _inner.watchScales);

  @override
  Future<FiscalDiagnosticsView> fiscal() async {
    _say('фискализация: вопрос задан');
    try {
      final v = await _inner.fiscal();
      _say('фискализация: ответ получен');
      return v;
    } on Object catch (error) {
      _say('фискализация: БРОСИЛ $error');
      rethrow;
    }
  }
}
