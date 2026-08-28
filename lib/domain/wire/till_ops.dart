/// Каталог операций провода между кассой и терминалом.
///
/// Тридцать одно описание, и каждое — единственное место, где живёт форма
/// своего обмена. Оба конца собираются отсюда, поэтому разойтись молча они не
/// могут.
///
/// # Почему это каталог, а не список путей
///
/// До 2026-08-04 согласование концов держалось на строке пути в двух местах:
/// `api_server.dart` объявлял маршрут, `lib/web/*` набирал его вручную, и
/// расхождение обнаруживалось только в браузере — кодом 404. В тот день это
/// стоило белого экрана без единого слова, потому что 404 приходил страницей
/// HTML, а разбор ждал JSON.
///
/// # Девять из тридцати одной перестают быть вопросами
///
/// Семь подписок ([setupState], [terminalsList], [terminalSelf],
/// [deviceBindings], [authUsers], [authSession], [authSessions]) и две
/// длинных работы ([setupRestore], [setupLoadGlobalData]). Ровно это и
/// просили от смены транспорта: касса получает возможность заговорить
/// первой. Упавшая печать, появившееся устройство, смена, закрытая на другой
/// кассе, заведённый кассир, погашенный сеанс, отозванный сеанс соседа —
/// всё это доезжает в момент события, а не при следующем вопросе.
///
/// [authSessions] и [authSessionRevoke] — задача 19 закрытия долга
/// безопасности (2026-08-22): экран списка живых сеансов
/// (`sessions_screen.dart`) не имел вызывающего для отзыва — эти две
/// операции и есть недостающий путь. Не путать с отдельным, более старым
/// пробелом на ту же тему: `SessionRegistry.revokeAll()` существовал с
/// задачи 9, не звался ни одной строкой рабочего кода и снят задачей 21;
/// смена PIN и деактивация в `user_management_screen.dart` не ходят через
/// эти операции провода вовсе — они зовут `SessionRegistry.revokeForUser`
/// напрямую через get_it (тот же процесс кассы), сужая отзыв до сеансов
/// затронутого пользователя.
///
/// [networkStatus]/[networkWifiScan]/[networkWifiConnect]/
/// [networkWifiDisconnect]/[networkEthernetStatus]/[networkEthernetConfigure]
/// — задача «сетевые настройки по проводу» (спека 2026-08-24): последний
/// экран, отдававший в браузере заглушку. Все шесть — `Ask`: экран и так
/// опрашивает состояние раз в четыре секунды
/// (`network_settings_screen.dart`), подписка ему не нужна. `OpenAccess()` —
/// экран публичный и на десктопе (доступен с экрана входа и из мастера).
/// Bluetooth и точка доступа этой работой не переносятся — граница спеки,
/// докстринг `NetworkRepository` (`lib/domain/network/network_repository.dart`).
///
/// Род — это тип, а не поле: `Watch` нельзя присвоить туда, где ждут `Ask`,
/// и подписка не может проскочить в разряд вопросов молча. Сторож —
/// `test/domain/wire/till_ops_test.dart`.
///
/// # Разбор ответа не пишется здесь заново
///
/// Каждый `decode` зовёт готовую пару из соседних файлов —
/// `terminal_wire.dart`, `device_wire.dart`, `setup_state.dart`,
/// `setup_draft_json.dart`. Написать разбор здесь ещё раз значило бы завести
/// третьего читателя формы ровно после того, как второго свели с первым.
library;

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/auth/live_session.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/network/network_status.dart';
import 'package:telepos/domain/network/wifi_network.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_draft_json.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/auth_wire.dart';
import 'package:telepos/domain/wire/device_wire.dart';
import 'package:telepos/domain/wire/network_wire.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/domain/wire/terminal_wire.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_op.dart';

/// Запрос на сохранение одной привязки устройства.
///
/// Запись, а не два отдельных довода: терминал и привязка едут вместе, и
/// перепутать их местами при вызове нечем.
typedef DeviceBindingSaveRequest = ({int terminalId, DeviceBinding binding});

/// Запрос на переименование терминала.
typedef TerminalRenameRequest = ({int terminalId, String name});

/// Запрос на возврат уже заведённого терминала по секрету — задача 5 плана
/// «знакомство терминала с кассой», шаг 2 спеки.
typedef TerminalResumeRequest = ({int terminalId, String secret});

/// Запрос на заведение нового терминала — задача 6 плана «знакомство
/// терминала с кассой», шаг 3 спеки. `code` — код привязки (`PairingInvites`,
/// `/terminal-pairing`), обязателен и тратится ровно один раз: обработчик
/// (`TillOperations.askHandlers[terminalRegister.name]`,
/// `lib/backend/till_operations.dart`) отказывает без него или на потраченном
/// — сторож (`wire_guard.dart`, [EnrolmentAccess]) его не проверяет.
typedef TerminalRegisterRequest = ({String name, String code});

/// Запрос на проверку устройства терминала.
typedef DeviceCheckRequest = ({int terminalId, DeviceClass deviceClass});

/// Запрос на подключение к сети Wi-Fi — задача «сетевые настройки по
/// проводу». `password` — `null`/пусто для открытой сети.
typedef WifiConnectRequest = ({String ssid, String? password});

/// Запрос на настройку проводного интерфейса — задача «сетевые настройки по
/// проводу». `mode` — `'dhcp'`/`'static'`; `ipCidr`/`gateway`/`dns`
/// осмыслены только при `mode == 'static'`, тем же приёмом, каким уже жил
/// `SysdClient.ethernetConfigureDhcp`/`ethernetConfigureStatic` до переноса
/// на провод — один метод демона (`network.ethernet_configure`) на оба
/// режима.
typedef EthernetConfigureRequest = ({
  String iface,
  String mode,
  String? ipCidr,
  String? gateway,
  String? dns,
});

abstract final class TillOps {
  /// Чем закончился подъём кассы. Однократно на старте — спрашивать это
  /// подпиской нечего: подъём случается один раз до того, как страница
  /// вообще загрузилась.
  static const startupBoot = Ask<void, AppInitStatus>(
    'startup.boot',
    access: OpenAccess(),
    encode: _nothing,
    decode: _decodeBootStatus,
  );

  /// Чем оказался первый запуск установки. Тоже однократно.
  static const setupFirstLaunch = Ask<void, FirstLaunchResult>(
    'setup.firstLaunch',
    access: OpenAccess(),
    encode: _nothing,
    decode: _decodeFirstLaunch,
  );

  /// Состояние установки: пройден ли мастер, есть ли пользователи.
  ///
  /// **Подписка.** По HTTP это спрашивалось дважды за один экран — отдельно
  /// `isConfigured()`, отдельно `hasUsers()`, — и всё равно опаздывало:
  /// пользователь, заведённый на кассе, доезжал до терминала при следующем
  /// вопросе, а не в момент, когда его завели.
  static const setupState = Watch<void, SetupState>(
    'setup.state',
    access: OpenAccess(),
    encode: _nothing,
    decode: _decodeSetupState,
  );

  /// Резервные копии, из которых можно восстановиться. Список на один экран
  /// мастера: он открывается, оператор выбирает, экран закрывается.
  static const setupBackups = Ask<void, List<FoundBackup>>(
    'setup.backups',
    access: SetupOnlyAccess(),
    encode: _nothing,
    decode: _decodeBackups,
  );

  /// Восстановление из копии.
  ///
  /// **Длинная работа.** Идёт минутами, и до провода канала для хода
  /// выполнения не было вовсе: `http_first_launch_repository.dart` писал о
  /// себе, что придумывать промежуточные числа отказывается, и двигал полосу
  /// с 0.1 сразу на 1.0.
  ///
  /// Едет один идентификатор сообщения, а не вся копия: копию нашла сама
  /// касса, она у неё уже есть.
  static const setupRestore = Run<FoundBackup, bool>(
    'setup.restore',
    access: SetupOnlyAccess(),
    encode: _encodeRestore,
    decode: _decodeOk,
  );

  /// Загрузка общих данных организации на кассу, вступающую в существующую
  /// организацию. **Длинная работа** по той же причине, что [setupRestore].
  static const setupLoadGlobalData = Run<void, bool>(
    'setup.loadGlobalData',
    access: SetupOnlyAccess(),
    encode: _nothing,
    decode: _decodeOk,
  );

  /// Завести эту кассу с нуля вместо восстановления. Отдаёт её ключ.
  static const setupNewPos = Ask<void, String>(
    'setup.newPos',
    access: SetupOnlyAccess(),
    encode: _nothing,
    decode: _decodePosKey,
  );

  /// Зафиксировать пройденный мастер целиком.
  ///
  /// Весь черновик едет одним обменом, потому что фиксация — одна
  /// транзакция: разбив её на обмен за шаг, обрыв сети оставил бы кассу со
  /// счетами и без пользователей — такая касса не может ни принять деньги,
  /// ни быть донастроенной.
  static const setupComplete = Ask<SetupDraft, bool>(
    'setup.complete',
    access: SetupOnlyAccess(),
    encode: _encodeDraft,
    decode: _decodeOk,
  );

  /// Все терминалы этой кассы. **Подписка:** появившийся терминал виден
  /// сразу, а не когда экран догадается перечитать список.
  static const terminalsList = Watch<void, List<Terminal>>(
    'terminals.list',
    access: SessionAccess(),
    encode: _nothing,
    decode: _decodeTerminals,
  );

  /// Терминал, за которым сидит этот браузер. **Подписка:** переименование
  /// доезжает без вопроса.
  ///
  /// `null` — свежая установка, мастер настройки ещё не проходил и
  /// настоящего имени у кассы нет. `TerminalRepository.self()` отказывается
  /// его выдумывать, и провод отказывается так же.
  static const terminalSelf = Watch<void, Terminal?>(
    'terminals.self',
    access: OpenAccess(),
    encode: _nothing,
    decode: _decodeTerminalSelf,
  );

  /// Терминал этого браузера — **с заведением**, если его ещё нет.
  ///
  /// Отдельная операция от [terminalSelf], и это не дублирование: они делают
  /// разное. [terminalSelf] наблюдает и не имеет права менять то, за чем
  /// наблюдает — иначе открытая вкладка заводила бы строку в базе. Эта
  /// спрашивают, чтобы **действовать** от имени терминала (напечатать чек,
  /// провести оплату), и терминал для этого обязан существовать.
  ///
  /// До провода то же самое делал `GET /api/terminals/self`: он звал
  /// `TerminalRepository.self()`, который заводит строку при первом обращении.
  /// Свести обе к наблюдению значило бы, что на свежей кассе браузер никогда
  /// не получит своего терминала.
  ///
  /// `null` в ответе — мастер настройки ещё не проходил, настоящего имени
  /// кассы нет, и выдумывать его отказываются обе стороны. Приходит значением,
  /// а не кодом отказа, потому что различать это состояние по тексту ошибки
  /// пришлось бы строкой.
  static const terminalSelfEnsure = Ask<void, Terminal?>(
    'terminals.selfEnsure',
    access: OpenAccess(),
    encode: _nothing,
    decode: _decodeTerminalSelf,
  );

  /// Привязки устройств терминала — включая выключенные: экран настроек
  /// должен видеть выключенное устройство, чтобы включить его обратно, не
  /// потеряв параметры.
  ///
  /// **Подписка:** устройство появилось или отвалилось — видно сразу.
  ///
  /// `ownTerminal: TerminalOwnership.same` — задача 10 закрытия долга: до неё
  /// любая живая вкладка могла подписаться на привязки **чужого** терминала,
  /// подставив его `terminalId`.
  ///
  /// `needs: PermissionKeys.settingsHardware` — правка 2 волны закрытия
  /// долга безопасности (2026-08-22). До неё эта операция была единственной
  /// в своей четвёрке ([deviceBindingSave], [terminalRename], [deviceCheck])
  /// без права вовсе: любой живой сеанс, даже без `settings.hardware` (у
  /// рядового кассира его обычно и нет), мог читать, какие устройства
  /// привязаны к терминалу — не изменить, но узнать, что за принтер и ящик
  /// стоят у кассы. Соседи по группе `ownTerminal.same` право уже несли,
  /// эта — нет, без единой причины, названной в коде: расхождение нашлось
  /// разбором, а не сломанным тестом. `WireGuard.check` проверяет `needs`
  /// раньше `ownTerminal` (`wire_guard.dart`), так что для чужого терминала
  /// без права отказ идёт кодом `forbidden`, а не `cannot_delete_self`-стилем.
  ///
  /// Экрана это не ломает: единственный подписчик в браузере —
  /// `hardware_settings_screen.dart`, а маршрут `/hardware-settings`
  /// (`setup_router.dart`) уже отказывает в переходе вошедшему без
  /// `settings.hardware` до того, как экран успел бы подписаться.
  static const deviceBindings = Watch<int, List<DeviceBinding>>(
    'terminals.deviceBindings',
    access: SessionAccess(
      needs: PermissionKeys.settingsHardware,
      ownTerminal: TerminalOwnership.same,
    ),
    encode: _encodeTerminalId,
    decode: _decodeBindings,
  );

  /// Сохранить одну привязку устройства.
  ///
  /// Имя — `Save`, а не `Add`: `DeviceBindingRepository.save` **заменяет**
  /// существующую привязку того же класса устройства на этом терминале, а не
  /// добавляет вторую строку. Имя `Add` обещало бы накопление.
  ///
  /// `ownTerminal: TerminalOwnership.same` — задача 10 закрытия долга: до неё
  /// кассир с правом `settings.hardware` мог переписать привязку устройства
  /// чужого терминала, подставив его `terminalId` в тело.
  static const deviceBindingSave = Ask<DeviceBindingSaveRequest, bool>(
    'terminals.deviceBindingSave',
    access: SessionAccess(
      needs: PermissionKeys.settingsHardware,
      ownTerminal: TerminalOwnership.same,
    ),
    encode: _encodeBindingSave,
    decode: _decodeOk,
  );

  /// Переименовать терминал.
  ///
  /// `ownTerminal: TerminalOwnership.same` — задача 10 закрытия долга: до неё
  /// кассир с правом `settings.hardware` мог переименовать чужой терминал,
  /// подставив его `terminalId` в тело.
  static const terminalRename = Ask<TerminalRenameRequest, bool>(
    'terminals.rename',
    access: SessionAccess(
      needs: PermissionKeys.settingsHardware,
      ownTerminal: TerminalOwnership.same,
    ),
    encode: _encodeRename,
    decode: _decodeOk,
  );

  /// Завести новый терминал по имени и коду привязки. Отдаёт
  /// [TerminalEnrollment] — терминал и его секрет (задача 4 плана «знакомство
  /// терминала с кассой», шаг 2 спеки): секрет едет в ответе значением ровно
  /// этот единственный раз, и это единственная операция провода, которой это
  /// разрешено — [terminalToWireJson] (`terminalsList`/`terminalSelf`/…)
  /// секрета не несёт структурно.
  ///
  /// В таблице спеки этой строки нет, и её отсутствие было бы дырой:
  /// `TerminalRepository.register` — часть договора, а договор, у которого на
  /// проводе нет одного метода, — это биндинг, отказывающий в одном месте из
  /// четырёх, и узнать об этом можно только нажав кнопку.
  ///
  /// `access: EnrolmentAccess()` — задача 6 плана «знакомство терминала с
  /// кассой» (шаг 3 спеки): до неё была `OpenAccess()`, и заводила терминал
  /// любому, кто дотянулся до кассы по QUIC, без единого довода — потолок в
  /// 200 терминалов (`LocalTerminalRepository.maxTerminals`) был достижим
  /// неаутентифицированно. Теперь запрос обязан нести действующий, ещё не
  /// потраченный код привязки (`TerminalRegisterRequest.code`) — сторож его
  /// не проверяет (докстринг [EnrolmentAccess]), проверяет обработчик
  /// (`TillOperations.askHandlers[terminalRegister.name]`).
  static const terminalRegister = Ask<TerminalRegisterRequest, TerminalEnrollment>(
    'terminals.register',
    access: EnrolmentAccess(),
    encode: _encodeRegister,
    decode: _decodeTerminalEnrollment,
  );

  /// Вернуть уже заведённый терминал на новую QUIC-сессию, предъявив его
  /// секрет — задача 5 плана «знакомство терминала с кассой» (шаг 2 спеки).
  /// Полный договор — докстринг `TerminalRepository.resume`.
  ///
  /// `access: OpenAccess()` — сторож не требует сеанса: операция зовётся
  /// раньше `auth.login`, до которого сеанса ещё нет, и её защита не в
  /// требовании сеанса, а в самом секрете, доводе запроса
  /// (`LocalTerminalRepository.resume`/[TerminalSecret.matches]). Той же
  /// природы, что и [terminalRegister] был до задачи 6 — но не той же формы:
  /// [terminalRegister] с задачи 6 несёт [EnrolmentAccess], потому что его
  /// довод (код привязки) сторож не в состоянии проверить сам (докстринг
  /// [EnrolmentAccess]), а секрет [terminalResume] сторожу и не нужно
  /// проверять — он даже не смотрит в тело, кроме факта, что тело есть.
  static const terminalResume = Ask<TerminalResumeRequest, Terminal>(
    'terminals.resume',
    access: OpenAccess(),
    encode: _encodeResume,
    decode: _decodeTerminalResume,
  );

  /// Удалить терминал безвозвратно — задача 8 закрытия долга. До неё
  /// `TerminalDao` не имел ни одного способа убрать строку, а задача 7
  /// (потолок в 200 заведённых терминалов) прямо назвала это недостающим
  /// следующим шагом: настоящий магазин, упёршийся в потолок, не имел
  /// штатного пути освободить место.
  ///
  /// Привязки устройств удалённого терминала уходят вместе с ним —
  /// `TerminalDao.remove` каскадом, не сиротами.
  ///
  /// Терминал, которым касса пользуется сама (`isSelf`), удалить нельзя —
  /// `LocalTerminalRepository.delete` отказывает раньше, чем дело доходит до
  /// обработчика, кодом `WireRefusal('cannot_delete_self', …)` — этот путь не
  /// про сеанс вкладки вовсе, он живой и в обход провода.
  ///
  /// `ownTerminal: TerminalOwnership.different` — задача 10 закрытия долга.
  /// До неё запрет «не удаляй себя» был *истолкован* как «терминал самой
  /// кассы» (`isSelf` выше), потому что сеанс не нёс `terminalId` и сверить
  /// было не с чем; с `AuthSession.terminalId` (задача 9) появился настоящий
  /// смысл — «терминал, под которым сидит сама вызывающая вкладка», — и
  /// сторож сверяет его сам, тем же кодом `cannot_delete_self`
  /// (`wire_guard.dart`).
  static const terminalDelete = Ask<int, bool>(
    'terminals.delete',
    access: SessionAccess(
      needs: PermissionKeys.settingsHardware,
      ownTerminal: TerminalOwnership.different,
    ),
    encode: _encodeTerminalId,
    decode: _decodeOk,
  );

  /// Что касса нашла у себя по этому классу устройств.
  ///
  /// **Вопрос, а не подписка,** и это не упущение: перечисление портов,
  /// сокетов и спулера — работа, которую касса начинает по нажатию кнопки
  /// «искать», а не держит запущенной. Подписка означала бы, что открытый
  /// экран настроек непрерывно опрашивает железо.
  static const deviceDiscovery = Ask<DeviceClass, DeviceDiscoveryResult>(
    'terminals.deviceDiscovery',
    access: SessionAccess(needs: PermissionKeys.settingsHardware),
    encode: _encodeDeviceClass,
    decode: _decodeDiscovery,
  );

  /// Проверить устройство терминала. Тоже действие: проверка печатает
  /// пробный чек и открывает денежный ящик.
  ///
  /// `ownTerminal: TerminalOwnership.same` — задача 10 закрытия долга: до неё
  /// это и была та самая дыра, ради которой она заведена — кассир с правом
  /// `settings.hardware` мог напечатать пробный чек и открыть денежный ящик
  /// **чужого** терминала, подставив его `terminalId` в тело.
  static const deviceCheck = Ask<DeviceCheckRequest, DeviceCheckOutcome>(
    'terminals.deviceCheck',
    access: SessionAccess(
      needs: PermissionKeys.settingsHardware,
      ownTerminal: TerminalOwnership.same,
    ),
    encode: _encodeDeviceCheck,
    decode: _decodeCheckOutcome,
  );

  /// Кассиры, которых показывает экран входа. **Подписка:** заведённый на
  /// кассе пользователь появляется на терминале в момент заведения, а не
  /// когда экран догадается перечитать список.
  ///
  /// Хэшей здесь нет и быть не может: см. `AuthUser`.
  static const authUsers = Watch<void, List<AuthUser>>(
    'auth.users',
    access: OpenAccess(),
    encode: _nothing,
    decode: _decodeAuthUsers,
  );

  /// Проверить PIN. **Вопрос:** обмен разовый, и держать поток открытым после
  /// ответа незачем.
  ///
  /// PIN уезжает на кассу, а не хэши в браузер. Это и есть смысл всей работы.
  static const authLogin = Ask<AuthAttempt, AuthOutcome>(
    'auth.login',
    access: OpenAccess(),
    encode: _encodeAuthAttempt,
    decode: _decodeAuthOutcome,
  );

  /// Погасить сеанс.
  static const authLogout = Ask<String, bool>(
    'auth.logout',
    access: OpenAccess(),
    encode: _encodeToken,
    decode: _decodeOk,
  );

  /// Следить за сеансом. **Подписка:** касса, погасившая сеанс, обязана
  /// сказать об этом сама — иначе терминал узнает об отзыве прав в тот
  /// момент, когда попробует ими воспользоваться.
  static const authSession = Watch<String, AuthSession?>(
    'auth.session',
    access: OpenAccess(),
    encode: _encodeToken,
    decode: _decodeAuthSession,
  );

  /// Живые сеансы этой кассы — задача 19 закрытия долга безопасности.
  ///
  /// `needs: PermissionKeys.settingsUsers`, не `settingsHardware`: это тот
  /// же периметр, что и у `/auth-settings` (задача 18) — «кто и как входит
  /// в кассу», не «что к ней подключено». Обоснование — докстринг
  /// `SessionAdmin` (`lib/domain/auth/session_admin.dart`).
  ///
  /// **Подписка**, не вопрос: экран списка сеансов обязан увидеть чужой
  /// вход и чужой отзыв в момент события — тем же доводом, что уже привёл
  /// [authUsers]/[authSession] в разряд подписок, а не по новой причине.
  ///
  /// Токена в ответе нет — см. докстринг [LiveSession] и
  /// [liveSessionToWireJson]: список читает не хозяин сеанса, а тот, кто
  /// решает его отозвать.
  static const authSessions = Watch<void, List<LiveSession>>(
    'auth.sessions',
    access: SessionAccess(needs: PermissionKeys.settingsUsers),
    encode: _nothing,
    decode: _decodeLiveSessions,
  );

  /// Погасить сеанс конкретного терминала — задача 19 закрытия долга
  /// безопасности.
  ///
  /// По `terminalId`, не по токену: тело этой операции пишет тот, кто
  /// отзывает чужой сеанс, а не его хозяин, и токена у него на руках нет —
  /// список ([authSessions]) его и не показывает. `ownTerminal` здесь не
  /// заведён нарочно: это ровно противоположность его смысла у
  /// `deviceCheck`/`terminalRename` — операция обязана уметь нацелиться на
  /// **чужой** терминал, в этом её единственная польза.
  static const authSessionRevoke = Ask<int, bool>(
    'auth.sessionRevoke',
    access: SessionAccess(needs: PermissionKeys.settingsUsers),
    encode: _encodeTerminalId,
    decode: _decodeOk,
  );

  /// Сеть кассы: подключён ли Wi-Fi, к какой сети, есть ли кабель, есть ли
  /// интернет. Задача «сетевые настройки по проводу» (спека 2026-08-24) —
  /// последний экран, отдававший в браузере заглушку.
  ///
  /// **Вопрос, а не подписка:** экран и так опрашивает раз в четыре секунды
  /// (`network_settings_screen.dart`), заводить ради него ещё и подписку —
  /// лишний род обмена там, где хватает опроса.
  ///
  /// `access: OpenAccess()` — экран публичный и на десктопе (доступен с
  /// экрана входа и из мастера), значит и на проводе прав не требует.
  /// Прецеденты — `startup.boot`, `auth.users`.
  static const networkStatus = Ask<void, NetworkStatus>(
    'network.status',
    access: OpenAccess(),
    encode: _nothing,
    decode: _decodeNetworkStatus,
  );

  /// Сети Wi-Fi, видимые прямо сейчас. Вопрос по нажатию «Поиск» — тем же
  /// приёмом, что и [deviceDiscovery]: перечисление — работа по кнопке, а не
  /// состояние, за которым следят.
  static const networkWifiScan = Ask<void, List<WifiNetwork>>(
    'network.wifiScan',
    access: OpenAccess(),
    encode: _nothing,
    decode: _decodeWifiScan,
  );

  /// Подключиться к сети Wi-Fi.
  static const networkWifiConnect =
      Ask<WifiConnectRequest, ({bool success, String message})>(
        'network.wifiConnect',
        access: OpenAccess(),
        encode: _encodeWifiConnect,
        decode: _decodeSuccessMessage,
      );

  /// Отключиться от текущей сети Wi-Fi.
  static const networkWifiDisconnect = Ask<void, bool>(
    'network.wifiDisconnect',
    access: OpenAccess(),
    encode: _nothing,
    decode: _decodeOk,
  );

  /// Подробности проводного интерфейса — форма едет как пришла с кассы, без
  /// собственной модели (докстринг `NetworkRepository.ethernetStatus`).
  static const networkEthernetStatus = Ask<void, Map<String, dynamic>>(
    'network.ethernetStatus',
    access: OpenAccess(),
    encode: _nothing,
    decode: _decodeEthernetStatus,
  );

  /// Настроить проводной интерфейс — DHCP или статический адрес, один метод
  /// демона на оба режима (докстринг [EthernetConfigureRequest]).
  static const networkEthernetConfigure =
      Ask<EthernetConfigureRequest, ({bool success, String mode})>(
        'network.ethernetConfigure',
        access: OpenAccess(),
        encode: _encodeEthernetConfigure,
        decode: _decodeSuccessMode,
      );

  /// Все операции провода.
  ///
  /// Список ведётся руками, и это не недосмотр: в Dart нет способа перечислить
  /// объявленные константы класса без зеркал, а зеркала запрещены в сборке
  /// под браузер. Забытая здесь операция уходит от проверок уникальности имени
  /// и рода — поэтому `till_ops_test.dart` отдельно сверяет этот список с
  /// поимённым перечислением всех тридцати одной.
  static const all = <WireOp<Object?, Object?>>[
    startupBoot,
    setupFirstLaunch,
    setupState,
    setupBackups,
    setupRestore,
    setupLoadGlobalData,
    setupNewPos,
    setupComplete,
    terminalsList,
    terminalSelf,
    deviceBindings,
    deviceBindingSave,
    terminalRename,
    terminalRegister,
    terminalResume,
    terminalDelete,
    terminalSelfEnsure,
    deviceDiscovery,
    deviceCheck,
    authUsers,
    authLogin,
    authLogout,
    authSession,
    authSessions,
    authSessionRevoke,
    networkStatus,
    networkWifiScan,
    networkWifiConnect,
    networkWifiDisconnect,
    networkEthernetStatus,
    networkEthernetConfigure,
  ];
}

// --- Кодирование запросов ------------------------------------------------

/// Обмен без доводов. Пустое тело, а не отсутствие тела: кадр обязан быть
/// разбираемым одним и тем же способом независимо от того, есть ли в нём что
/// сказать.
Map<String, Object?> _nothing(void _) => const {};

Map<String, Object?> _encodeRestore(FoundBackup backup) => {
  'messageId': backup.messageId,
};

Map<String, Object?> _encodeDraft(SetupDraft draft) => draft.toJson();

Map<String, Object?> _encodeTerminalId(int terminalId) => {
  'terminalId': terminalId,
};

Map<String, Object?> _encodeBindingSave(DeviceBindingSaveRequest request) => {
  'terminalId': request.terminalId,
  'binding': deviceBindingToWireJson(request.binding),
};

Map<String, Object?> _encodeRename(TerminalRenameRequest request) => {
  'terminalId': request.terminalId,
  'name': request.name,
};

Map<String, Object?> _encodeRegister(TerminalRegisterRequest request) => {
  'name': request.name,
  'code': request.code,
};

Map<String, Object?> _encodeResume(TerminalResumeRequest request) => {
  'terminalId': request.terminalId,
  'secret': request.secret,
};

/// Класс устройства едет **по имени**, никогда по индексу: вставка нового
/// члена в перечисление иначе поменяла бы смысл уже написанного кадра, а этот
/// довод решает, чьё железо касса пойдёт искать.
Map<String, Object?> _encodeDeviceClass(DeviceClass deviceClass) => {
  'deviceClass': deviceClass.name,
};

Map<String, Object?> _encodeDeviceCheck(DeviceCheckRequest request) => {
  'terminalId': request.terminalId,
  'deviceClass': request.deviceClass.name,
};

Map<String, Object?> _encodeAuthAttempt(AuthAttempt attempt) => {
  'pin': attempt.pin,
  'terminalId': attempt.terminalId,
  'userId': attempt.userId,
};

Map<String, Object?> _encodeToken(String token) => {'token': token};

Map<String, Object?> _encodeWifiConnect(WifiConnectRequest request) => {
  'ssid': request.ssid,
  if (request.password != null && request.password!.isNotEmpty)
    'password': request.password,
};

Map<String, Object?> _encodeEthernetConfigure(
  EthernetConfigureRequest request,
) => {
  'iface': request.iface,
  'mode': request.mode,
  if (request.ipCidr != null) 'ipCidr': request.ipCidr,
  if (request.gateway != null) 'gateway': request.gateway,
  if (request.dns != null) 'dns': request.dns,
};

// --- Разбор ответов ------------------------------------------------------

/// Итог действия. Отсутствие `ok` — это «нет», а не «да»: умолчание обязано
/// быть тем, которое ничего не утверждает.
bool _decodeOk(Map<String, Object?> body) => body['ok'] == true;

/// Нераспознанное имя состояния подъёма читается как [AppInitStatus.databaseFailure].
///
/// Не `success`: касса новее терминала — обычное состояние при обновлении по
/// одной машине, и выдать неизвестный отказ за успех значило бы пустить
/// оператора работать на кассе, которая не поднялась.
AppInitStatus _decodeBootStatus(Map<String, Object?> body) {
  final name = body['status'];
  for (final status in AppInitStatus.values) {
    if (status.name == name) return status;
  }
  return AppInitStatus.databaseFailure;
}

/// Нераспознанный итог первого запуска — [FirstLaunchResult.offlineMode]:
/// продолжать без кассы терминал всё равно не может, и увидеть он должен
/// названный экран, а не пустоту.
FirstLaunchResult _decodeFirstLaunch(Map<String, Object?> body) {
  final name = body['result'];
  for (final result in FirstLaunchResult.values) {
    if (result.name == name) return result;
  }
  return FirstLaunchResult.offlineMode;
}

SetupState _decodeSetupState(Map<String, Object?> body) =>
    setupStateFromWireJson(body);

List<FoundBackup> _decodeBackups(Map<String, Object?> body) =>
    _objectList(body['backups']).map(FoundBackup.fromJson).toList();

String _decodePosKey(Map<String, Object?> body) =>
    body['posKey'] as String? ?? '';

List<Terminal> _decodeTerminals(Map<String, Object?> body) =>
    _objectList(body['terminals']).map(terminalFromWireJson).toList();

Terminal? _decodeTerminalSelf(Map<String, Object?> body) {
  final raw = body['terminal'];
  return raw is Map<String, dynamic> ? terminalFromWireJson(raw) : null;
}

/// Заведённый терминал и его секрет, которые обязаны быть в ответе.
///
/// В отличие от [_decodeTerminalSelf], `null`/отсутствующий терминал здесь не
/// значение, а отказ: заведение либо состоялось, либо нет, и «завёлся, но
/// какой — неизвестно» третьим исходом быть не может. Разбор —
/// [terminalEnrollmentFromWireJson] (`terminal_wire.dart`), не пишется здесь
/// заново — см. докстринг библиотеки.
TerminalEnrollment _decodeTerminalEnrollment(Map<String, Object?> body) =>
    terminalEnrollmentFromWireJson(body);

/// Терминал, возвращённый предъявлением секрета — обязан быть в ответе,
/// той же формой, что и [_decodeTerminalEnrollment]: касса либо признала
/// секрет и вернула терминал, либо отказала ([WireRefusal]) до этой точки
/// разбора, третьего исхода нет.
Terminal _decodeTerminalResume(Map<String, Object?> body) {
  final raw = body['terminal'];
  if (raw is! Map<String, dynamic>) {
    throw StateError('касса не прислала возвращённый терминал');
  }
  return terminalFromWireJson(raw);
}

DeviceDiscoveryResult _decodeDiscovery(Map<String, Object?> body) =>
    deviceDiscoveryResultFromWireJson(body);

DeviceCheckOutcome _decodeCheckOutcome(Map<String, Object?> body) =>
    deviceCheckOutcomeFromWireJson(body);

List<DeviceBinding> _decodeBindings(Map<String, Object?> body) {
  // `terminalId` едет в ответе, а не берётся из запроса: он нужен только
  // тексту отказа при нераспознанном классе устройства, и брать его из
  // запроса значило бы, что ответ на чужой терминал назовёт свой.
  final terminalId = body['terminalId'] as int? ?? 0;
  return _objectList(body['bindings'])
      .map((raw) => deviceBindingFromWireJson(raw, terminalId: terminalId))
      .toList();
}

/// Список объектов из того, что пришло на его месте. Не-список — пусто:
/// «ничего не пришло» и «пришло не то» для списка одно и то же — показывать
/// нечего, и отказ уже назван кадром, а не этим разбором.
List<Map<String, dynamic>> _objectList(Object? raw) =>
    raw is List ? raw.whereType<Map<String, dynamic>>().toList() : const [];

List<AuthUser> _decodeAuthUsers(Map<String, Object?> body) => [
  for (final raw in (body['users'] as List? ?? const []))
    authUserFromWireJson((raw as Map).cast<String, Object?>()),
];

AuthOutcome _decodeAuthOutcome(Map<String, Object?> body) =>
    authOutcomeFromWireJson(body);

AuthSession? _decodeAuthSession(Map<String, Object?> body) =>
    authSessionFromWireJson((body['session'] as Map?)?.cast<String, Object?>());

List<LiveSession> _decodeLiveSessions(Map<String, Object?> body) =>
    _objectList(
      body['sessions'],
    ).map(liveSessionFromWireJson).toList();

NetworkStatus _decodeNetworkStatus(Map<String, Object?> body) =>
    networkStatusFromWireJson(body);

List<WifiNetwork> _decodeWifiScan(Map<String, Object?> body) =>
    _objectList(body['networks']).map(wifiNetworkFromWireJson).toList();

({bool success, String message}) _decodeSuccessMessage(
  Map<String, Object?> body,
) => (success: body['success'] == true, message: (body['message'] ?? '') as String);

/// Форма `network.ethernetStatus` варьируется по тому, что вернул `ip -j addr
/// show` на кассе (докстринг `NetworkRepository.ethernetStatus`) — тело
/// кадра и есть ответ, разбор не сужает его до собственной модели.
Map<String, dynamic> _decodeEthernetStatus(Map<String, Object?> body) => body;

({bool success, String mode}) _decodeSuccessMode(Map<String, Object?> body) =>
    (success: body['success'] == true, mode: (body['mode'] ?? '') as String);
