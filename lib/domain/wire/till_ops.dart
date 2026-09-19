/// Каталог операций провода между кассой и терминалом.
///
/// Пятьдесят одно описание, и каждое — единственное место, где живёт форма
/// своего обмена. Оба конца собираются отсюда, поэтому разойтись молча они не
/// могут.
///
/// **Последние двадцать объявлены не здесь, а в `SaleOps`**
/// (`lib/domain/wire/sale_ops.dart`): `sale.ping` завела задача 1 плана
/// «Продажа с браузерного терминала» (2026-09-06), остальные девятнадцать —
/// задача 9 того же плана, по одной на каждый метод контракта `CartService`.
/// У продажи свой файл-каталог, но входят они в [all] наравне с остальными,
/// через `...SaleOps.all` — единый список не имеет права знать о делении на
/// файлы, иначе сторож провода (`wire_guard.dart`) видел бы только часть
/// операций, а `ApiServer.access` знал бы права только части.
///
/// # Почему это каталог, а не список путей
///
/// До 2026-08-04 согласование концов держалось на строке пути в двух местах:
/// `api_server.dart` объявлял маршрут, `lib/web/*` набирал его вручную, и
/// расхождение обнаруживалось только в браузере — кодом 404. В тот день это
/// стоило белого экрана без единого слова, потому что 404 приходил страницей
/// HTML, а разбор ждал JSON.
///
/// # Одиннадцать из пятидесяти одной перестают быть вопросами
///
/// Девять подписок ([setupState], [terminalsList], [terminalSelf],
/// [deviceBindings], [authUsers], [authSession], [authSessions],
/// [SaleOps.cart], [SaleOps.deferredList]) и две длинных работы
/// ([setupRestore], [setupLoadGlobalData]). Ровно это и просили от смены
/// транспорта: касса получает возможность заговорить первой. Упавшая печать,
/// появившееся устройство, смена, закрытая на другой кассе, заведённый
/// кассир, погашенный сеанс, отозванный сеанс соседа, корзина, изменённая
/// соседней вкладкой, чек, поднятый из общего пула соседом, — всё это
/// доезжает в момент события, а не при следующем вопросе.
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

import 'package:decimal/decimal.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/auth/live_session.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/network/network_status.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/network/wifi_network.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/domain/receipt/receipt_template_setup.dart';
import 'package:telepos/domain/shift/shift_desk.dart';
import 'package:telepos/domain/wire/wire_money.dart';
import 'package:telepos/domain/sale/payment_service.dart';
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
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/refund_ops.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/domain/wire/scanner_rules_codec.dart';
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

/// Запрос на смену набора разрешённых видов оплаты — задача 15 плана
/// «продажа с браузерного терминала», решение заказчика №5.
///
/// Пустое множество — законное значение и означает «все виды», а не «ни
/// одного» (докстринг `Terminal.allowedPaymentTypes`).
typedef TerminalPaymentTypesRequest = ({
  int terminalId,
  Set<PaymentType> types,
});

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

/// Заявка на запись настройки провайдера QR — решение заказчика 2026-09-18.
///
/// Один в один доводы [QrProviderSetupRepository.save], и это не совпадение,
/// а требование: браузерная половина — вторая реализация **того же** порта, и
/// поле, потерянное между ними, означало бы настройку, которую с кассы задать
/// можно, а с планшета нет.
///
/// `newApiKey` — единственное поле каталога, несущее секрет, и едет оно
/// только **от вкладки к кассе**. Пустое или `null` значит «прежний ключ
/// остаётся»: экран ключа не знает и вернуть его не может, поэтому
/// пересохранение адреса не имеет права молча стереть ключ. Стирание —
/// отдельное намерение `clearApiKey`, а не пустая строка: «не набирал» и
/// «сотри» обязаны различаться.
typedef QrProviderSaveAsk = ({
  String baseUrl,
  String code,
  Duration patience,
  String? newApiKey,
  bool clearApiKey,
});

/// Заявка на запись шаблона чека — решение заказчика 2026-09-18.
///
/// Один в один доводы [ReceiptTemplateSetupRepository.save]. Признака
/// «встроенный» здесь нет **полем**, и это не потеря при переносе: разбор — в
/// докстринге порта, коротко — единственным способом его поменять стала бы
/// как раз эта поездка.
typedef ReceiptTemplateSaveAsk = ({int? id, String name, String optionsJson});

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

  /// Назначить рабочему месту набор разрешённых видов оплаты — задача 15,
  /// решение заказчика №5.
  ///
  /// Право и владение — те же, что у [terminalRename]: `settings.hardware`
  /// плюс `ownTerminal: TerminalOwnership.same`. Это **настройка рабочего
  /// места**, ровно как его имя и его устройства, и правится она там же, где
  /// они, — на экране настроек своего терминала.
  ///
  /// **Чего эта операция не делает: она не является защитой от кассира.**
  /// Владелец сеанса с правом `settings.hardware` может снять запрет с
  /// собственного рабочего места — ровно как может переименовать его или
  /// перепривязать принтер. Защита, которую даёт задача 15, — другая: экран,
  /// **не имеющий** этого права (а у рядового кассира его и нет), не может
  /// обойти запрет ни подделкой кадра оплаты, ни спрятанной кнопкой, потому
  /// что вид оплаты проверяет касса (`LocalPaymentService`), а не вкладка.
  static const terminalSetPaymentTypes = Ask<TerminalPaymentTypesRequest, bool>(
    'terminals.setPaymentTypes',
    access: SessionAccess(
      needs: PermissionKeys.settingsHardware,
      ownTerminal: TerminalOwnership.same,
    ),
    encode: _encodePaymentTypes,
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
  static const terminalRegister =
      Ask<TerminalRegisterRequest, TerminalEnrollment>(
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

  /// Правила чтения штрихкода этой кассы — задача 45.
  ///
  /// Их применяет `BarcodeScannerMixin` к каждому скану на продаже и возврате,
  /// в том числе в браузере: длины кода и зазор между символами — правила
  /// клавиатурного сканера, а не устройства кассы. До задачи 45 браузер их не
  /// читал вовсе и молча брал зашитые.
  ///
  /// Право — **любой сеанс** ([SessionAccess] без `needs`): правила нужны и
  /// экрану продажи (`nav.sale`), и экрану возврата (`nav.refund`), тайны в
  /// них нет, а запрет по одному из двух прав оставил бы второй экран на
  /// зашитых правилах — тем же молчанием.
  static const scannerRules = Ask<void, ScannerRules>(
    'scanner.rules',
    access: SessionAccess(),
    encode: _nothing,
    decode: scannerRulesFromWireJson,
  );

  /// Записать правила чтения штрихкода — пункт 11 ревизии 2026-09-19,
  /// решение заказчика 2026-09-18 («в браузере должно работать то же, что в
  /// приложении»).
  ///
  /// # Что было
  ///
  /// [scannerRules] отдавала правила и только. Кассир за планшетом видел
  /// длины кода и зазор между символами на экране «Оборудование» ровно до
  /// тех пор, пока не пробовал их **задать**: секция говорила
  /// `scannerRulesUnavailable` — «здесь их не настроить». Владелец, у
  /// которого вместо кассы планшет, не мог настроить сканер ничем.
  ///
  /// # Право — `settings.hardware`, существующее
  ///
  /// Тот же ключ, что у маршрута `/hardware-settings`
  /// (`PermissionKeys.routeToPermissionKey`), то есть ровно то право, каким
  /// заперт экран, где эти поля стоят. Своего ключа не заводится по тому же
  /// доводу, что у настройки QR выше: новый ключ без шага миграции тихо не
  /// достаётся ни одному существующему пользователю.
  ///
  /// **Не путать с правом чтения.** [scannerRules] открыта любому сеансу
  /// нарочно: её просит `BarcodeScannerMixin` на продаже и на возврате, и
  /// тайны в длинах кода нет. Запись — настройка кассы, и её периметр
  /// другой: правило длины, заданное мимо наладчика, молча отбрасывает
  /// сканы на **всех** рабочих местах.
  ///
  /// # Почему запись целиком, а не по полю
  ///
  /// Тем же доводом, что и у `ScannerRulesRepository.save`: годность —
  /// свойство тройки (min ≤ max), а не каждого значения по отдельности.
  /// Операция «задать только максимум» позволила бы пройти через негодное
  /// промежуточное состояние и записать его.
  ///
  /// Отказ негодной тройки приходит **значением** — `bad_request` с
  /// текстом от `ScannerRules`, а не падением обработчика: проверку делает
  /// конструктор `ScannerRules` при разборе кадра, до того как что-либо
  /// будет записано.
  static const scannerRulesSave = Ask<ScannerRules, bool>(
    'scanner.saveRules',
    access: SessionAccess(needs: PermissionKeys.settingsHardware),
    encode: scannerRulesToWireJson,
    decode: _decodeOk,
  );

  /// Просрочена ли партия, которой ушёл бы этот товар — пункт 11 ревизии
  /// 2026-09-19.
  ///
  /// Экран продажи спрашивает это **после** того, как строка встала в чек, и
  /// показывает жёлтый снекбар с именем товара. До этой операции вопрос
  /// задавался напрямую `BatchTrackingUseCase` в контейнере, которого в
  /// браузере нет: кассир за планшетом пробивал просроченный товар молча.
  ///
  /// Право — `nav.sale`: спрашивает только экран продажи, и спрашивает про
  /// товар, который кассир **уже** положил в чек. Ответ — одно «да/нет» про
  /// срок годности; тайны в нём нет, но и открывать вопрос без сеанса
  /// незачем, а `nav.sale` у того, кто ведёт чек, есть по построению.
  ///
  /// Разбор, почему это отдельная операция, а не поле в `CartView`, — в
  /// докстринге `ExpiryWarningReader`; коротко: предупреждение относится к
  /// действию кассира, а не к состоянию чека, и поле снимка потухло бы на
  /// первом обновлении подписки `sale.cart`.
  ///
  /// **Имя начинается на `sale.`, а объявление живёт здесь, а не в
  /// `SaleOps`** — и это решение, а не недосмотр. `SaleOps` собран по
  /// правилу «одна операция на метод контракта `CartService`»
  /// (докстринг там, и `sale_ops_access_test` сверяет их поимённо); эта
  /// операция методом корзины не является и не должна им становиться —
  /// иначе правило превратилось бы в «что угодно про продажу». Обработчик
  /// при этом лежит в карте продажи — там же, где `scanner.rules`, и по
  /// тому же поводу: общий запрет называть рабочее место в теле.
  static const saleExpiryWarning = Ask<int, bool>(
    'sale.expiryWarning',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeProductId,
    decode: _decodeExpired,
  );

  /// Остатки кассы изменились — пункт 12 ревизии 2026-09-19.
  ///
  /// **Подписка, а не вопрос, и это не оформление.** Вкладку держат
  /// открытой всю смену, а остаток написан в каждой строке выдачи поиска
  /// экрана продажи и в каталоге. Вопрос был бы верен ровно в миг
  /// постройки экрана — то есть ровно тогда, когда он и так верен, — и
  /// продажа, проведённая соседним рабочим местом, не доехала бы никуда.
  /// Это и есть то, ради чего менялся транспорт: касса говорит первой.
  ///
  /// Первый кадр несёт текущий номер ревизии, дальнейшие — изменения.
  /// Номер сам по себе не значит ничего: подписанный перечитывает свой
  /// остаток обычным путём (докстринг `StockChanges`).
  ///
  /// Право — **любой сеанс** ([SessionAccess] без `needs`), тем же
  /// доводом, что у [scannerRules]: сообщение нужно и экрану продажи
  /// (`nav.sale`), и каталогу (`nav.catalog`), а несёт оно одно число без
  /// единого сведения о товаре, деньгах или покупателе. Запрет по одному
  /// из прав оставил бы второй экран с устаревшей цифрой — тем же
  /// молчанием, ради снятия которого подписка заведена.
  ///
  /// Рабочее место в теле не называется: остаток — свойство кассы, а не
  /// стойки.
  static const stockRevision = Watch<void, int>(
    'stock.revision',
    access: SessionAccess(),
    encode: _nothing,
    decode: _decodeRevision,
  );

  // ── настройка оплаты по QR ─────────────────────────────────────────────
  //
  // Решение заказчика 2026-09-18, дословно: «это не граница, а пробел — в
  // браузере должно работать то же, что в приложении». Экран настройки QR
  // (пункт 8 C) жил только на кассе, и владелец, у которого вместо кассы
  // планшет, включить оплату по QR не мог ничем: строку
  // `qr_provider_configs` писала либо десктопная сборка, либо дверь стенда.
  //
  // # Ключ провайдера едет только внутрь
  //
  // Это главное свойство всей четвёрки, и держится оно **формой ответа**, а
  // не бдительностью: ответ — `QrProviderView`, у которого поля ключа нет
  // вовсе (докстринг `qr_provider_setup.dart`). Утечке неоткуда взяться:
  // нечего класть. Сторож — `test/backend/qr_setup_secret_test.dart`, он
  // пишет ключ с браузера и просматривает каждый кадр, отправленный кассой
  // терминалу.
  //
  // # Право — `settings.accounts`, существующее
  //
  // Тот же ключ, что у маршрута `/qr-provider-settings`
  // (`PermissionKeys.routeToPermissionKey`), и тот же довод: провайдер
  // решает, куда уходят деньги покупателя, — периметр счетов кассы. Своего
  // ключа не заводится: новый без шага миграции тихо не достаётся ни одному
  // существующему пользователю (докстринг `PermissionKeys.allPermissions`,
  // «Правило на будущее»), а миграции у этой работы нет.
  //
  // Право **постоянно** и не зависит от тела: тела, при котором правка
  // адреса провайдера была бы безобидна, не существует.
  //
  // # Почему четыре операции, а не одна с режимом
  //
  // По одной на метод контракта `QrProviderSetupRepository` — тем же
  // правилом, каким собраны `terminals.*`: договор, у которого на проводе
  // нет одного метода, отказывает в одном месте из четырёх, и узнать об
  // этом можно только нажав кнопку. Режим в теле сделал бы разбор кадра
  // развилкой, а право — зависящим от поля.

  /// Что экран знает о настройке QR. **Ключа в ответе нет** — его нет в
  /// [QrProviderView].
  static const qrProviderSettings = Ask<void, QrProviderView>(
    'qr.providerSettings',
    access: SessionAccess(needs: PermissionKeys.settingsAccounts),
    encode: _nothing,
    decode: qrProviderViewFromWireJson,
  );

  /// Записать адрес, имя, терпение — и, если набран, новый ключ.
  ///
  /// Единственная операция каталога, которой ключ провайдера вообще
  /// доверяется, и едет он **только в этом направлении**: из вкладки на
  /// кассу. Обратно не возвращается ничем — ответ пуст по форме.
  static const qrProviderSave = Ask<QrProviderSaveAsk, bool>(
    'qr.providerSave',
    access: SessionAccess(needs: PermissionKeys.settingsAccounts),
    encode: _encodeQrProviderSave,
    decode: _decodeOk,
  );

  /// Снять настройку целиком — касса перестаёт показывать коды.
  static const qrProviderClear = Ask<void, bool>(
    'qr.providerClear',
    access: SessionAccess(needs: PermissionKeys.settingsAccounts),
    encode: _nothing,
    decode: _decodeOk,
  );

  /// Включить или выключить вид оплаты QR в справочнике.
  ///
  /// Отдельной операцией, а не полем сохранения: выключатель — единственное
  /// действие экрана, которое кассир делает **не заполнив форму**, и
  /// пришивать его к сохранению значило бы требовать адреса ради того, чтобы
  /// выключить вид оплаты.
  static const qrProviderKind = Ask<bool, bool>(
    'qr.providerKind',
    access: SessionAccess(needs: PermissionKeys.settingsAccounts),
    encode: _encodeQrKindActive,
    decode: _decodeOk,
  );

  // ── шаблон чека ────────────────────────────────────────────────────────
  //
  // Решение заказчика 2026-09-18: «это не граница, а пробел — в браузере
  // должно работать то же, что в приложении». Шапка, подвал и содержимое
  // чека правились только на кассе: оба экрана шаблона ходили в
  // `AppDatabase` напрямую, а `lib/data/` в браузерную сборку не собирается
  // вовсе (сторож `browser_routes_test`).
  //
  // # Предпросмотр — операция провода, а не работа вкладки
  //
  // Это главное свойство всей пятёрки, и оно объясняется целиком в
  // докстринге `receipt_template_setup.dart`. Коротко: текст чека на экране
  // рождается **в одном месте на всё дерево** —
  // `ReceiptPrintService.renderSalePreviewText`, которая собирает настоящий
  // поток ESC/POS тем же кодом, каким печатает, и разбирает его обратно.
  // Вкладка получает готовую строку и о раскладке не знает ничего: ни
  // ширины ленты, ни выравнивания, ни кодовой страницы. Вторая раскладка в
  // браузере уже была бы третьей в дереве, а расхождение двух первых стоило
  // круга правок (докстринг `escpos_text_preview.dart`).
  //
  // # Право — `settings.printer`, существующее
  //
  // Тот же ключ, что у `/printer-settings`, и тот же довод: ширину ленты, на
  // которой собран предпросмотр, задаёт именно тот экран, и шаблон без неё
  // не имеет смысла — «узкий чек при выбранном широком» и был тем дефектом.
  // Своего ключа не заводится: новый без шага миграции тихо не достаётся ни
  // одному существующему пользователю (докстринг
  // `PermissionKeys.allPermissions`, «Правило на будущее»), а миграции у
  // этой работы нет. Кассиру ни один `settings.*` не достаётся по
  // умолчанию — и это верно: текст чека магазина не рядовое действие у кассы.
  //
  // # Почему пять операций, а не одна с режимом
  //
  // По одной на метод контракта `ReceiptTemplateSetupRepository`, тем же
  // правилом, каким собраны `qr.*` и `terminals.*`: договор, у которого на
  // проводе нет одного метода, отказывает в одном месте из пяти, и узнать об
  // этом можно только нажав кнопку.

  /// Список шаблонов и ширина ленты привязанного принтера.
  static const receiptTemplates = Ask<void, ReceiptTemplateCatalog>(
    'receipt.templates',
    access: SessionAccess(needs: PermissionKeys.settingsPrinter),
    encode: _nothing,
    decode: receiptTemplateCatalogFromWireJson,
  );

  /// Записать шаблон: новый (`id == null`) или правку существующего.
  static const receiptTemplateSave = Ask<ReceiptTemplateSaveAsk, bool>(
    'receipt.templateSave',
    access: SessionAccess(needs: PermissionKeys.settingsPrinter),
    encode: _encodeReceiptTemplateSave,
    decode: _decodeOk,
  );

  /// Печатать этим шаблоном.
  static const receiptTemplateSelect = Ask<int, bool>(
    'receipt.templateSelect',
    access: SessionAccess(needs: PermissionKeys.settingsPrinter),
    encode: _encodeReceiptTemplateId,
    decode: _decodeOk,
  );

  /// Удалить шаблон. Встроенный не удаляется — запрет держит касса.
  static const receiptTemplateDelete = Ask<int, bool>(
    'receipt.templateDelete',
    access: SessionAccess(needs: PermissionKeys.settingsPrinter),
    encode: _encodeReceiptTemplateId,
    decode: _decodeOk,
  );

  /// Предпросмотр черновика — **те же байты, что уйдут в принтер**,
  /// разобранные кассой в текст.
  ///
  /// Ответ — строка, а не байты и не разобранная настройка. Разбор, почему
  /// именно так, — в докстринге `receipt_template_setup.dart`; сторож —
  /// `test/backend/receipt_template_op_test.dart`.
  static const receiptTemplatePreview = Ask<String, String>(
    'receipt.templatePreview',
    access: SessionAccess(needs: PermissionKeys.settingsPrinter),
    encode: _encodeReceiptTemplateOptions,
    decode: receiptTemplatePreviewFromWireJson,
  );

  /// Пробная печать образца на принтере кассы.
  ///
  /// Черновика не несёт: кассовая кнопка печатала **выбранный сохранённый**
  /// шаблон и до этой работы (докстринг
  /// `ReceiptTemplateSetupRepository.testPrint`). Дать вкладке печатать
  /// черновик значило бы сделать браузер способнее кассы.
  static const receiptTemplateTestPrint = Ask<void, bool>(
    'receipt.templateTestPrint',
    access: SessionAccess(needs: PermissionKeys.settingsPrinter),
    encode: _nothing,
    decode: _decodeOk,
  );

  // ── смена ──────────────────────────────────────────────────────────────
  //
  // Решение заказчика 2026-09-18. Замерено живьём в тот же день: смена
  // старше суток запирает продажу окном «Смена открыта более 24 часов.
  // Продажа заблокирована. Закройте смену на кассе и откройте новую», а с
  // планшета закрыть смену было нечем — путь упирался в стену. Вторая
  // половина того же пробела: дом терминала показывал «Смена открыта»
  // зелёным значком и при просроченной смене, потому что состояние смены
  // приезжало один раз, в `AuthSession` при входе, и больше не менялось
  // ничем: ни одной операции провода про смену в каталоге не было.
  //
  // # Состояние — подписка, а не вопрос
  //
  // Это и есть починка значка. Вопрос был бы верен ровно в тот миг, когда
  // строится экран, а вкладку держат открытой всю смену: касса закрыла бы
  // смену, а на планшете значок остался бы зелёным до перезагрузки
  // страницы. Источник — `AppDatabase.tableUpdates`, тот же, которым уже
  // живут девять подписок каталога.
  //
  // # Что вкладка вправе задать, а что считает касса
  //
  // Разбор целиком — в докстринге `lib/domain/shift/shift_desk.dart`.
  // Коротко: вкладка задаёт **одно число — сколько человек насчитал в
  // ящике**, потому что это физический замер, которого нет ни в одном
  // журнале. Всё остальное — системный итог, «должно быть», расхождение,
  // время закрытия, уточнённое время открытия, Z-отчёт, список
  // нефискализованных чеков — арифметика над журналом кассы, и считает её
  // касса. Вкладке, которой позволено назвать системный итог, ничего не
  // стоило бы закрыть смену на числе, которого никто не считал: расхождение
  // вышло бы нулевым по построению.
  //
  // Деньги едут **строкой** (`wireMoney`, I159), и `null` значит «не
  // считали», а не ноль: ноль в ящике — законный результат пересчёта.
  //
  // # Право — `nav.shift`, существующее
  //
  // Тот же ключ, что у `/shift` — экрана, который эти операции и переносят.
  // Кассиру он достаётся по умолчанию ([roleDefaults]), и это верно:
  // закрыть свою смену — рядовое действие у кассы, ради которого кассир не
  // должен искать администратора. Своего ключа не заводится: новый без шага
  // миграции тихо не достаётся ни одному существующему пользователю.
  //
  // Кассира, на которого открывается смена, операции **не возят**: его
  // берёт обработчик из `AuthSession` (И162).

  /// Состояние смены кассы — сейчас и при каждом изменении.
  static const shiftState = Watch<void, ShiftDeskView>(
    'shift.state',
    access: SessionAccess(needs: PermissionKeys.navShift),
    encode: _nothing,
    decode: shiftDeskViewFromWireJson,
  );

  /// Закрыть смену. Тело несёт пересчитанные деньги — или не несёт ничего.
  static const shiftClose = Ask<Decimal?, bool>(
    'shift.close',
    access: SessionAccess(needs: PermissionKeys.navShift),
    encode: _encodeShiftCounted,
    decode: _decodeOk,
  );

  /// Открыть смену. Тело несёт деньги, положенные в ящик на начало.
  static const shiftOpen = Ask<Decimal?, bool>(
    'shift.open',
    access: SessionAccess(needs: PermissionKeys.navShift),
    encode: _encodeShiftCounted,
    decode: _decodeOk,
  );

  // ── диагностика оборудования ──────────────────────────────────────────
  //
  // Пункт «Достижимость с браузерного терминала» плана
  // `2026-09-19-hardware-diagnostics.md` и решение заказчика 2026-09-18: «в
  // браузере должно работать то же, что в приложении». Экран диагностики
  // был только на кассе — вкладки читали `PrintQueue`, `AppDatabase` и
  // `FiscalQueueStore` напрямую, а три из четырёх договоров живут в
  // `lib/data/` и `lib/hardware/`, то есть в браузер не собираются вовсе.
  //
  // # Две операции, а не одна с режимом
  //
  // По одной на метод порта `HardwareDiagnosticsRepository`, тем же
  // правилом, каким собраны `qr.*`, `receipt.*` и `shift.*`. Причём **род у
  // них разный**, и это не мелочь оформления: принтер — подписка, оператор
  // — вопрос, и род здесь тип, а не поле, так что перепутать их при вызове
  // нечем.
  //
  // # Почему принтер — подписка
  //
  // Наладчик держит вкладку открытой и печатает пробный чек с соседнего
  // экрана. Вопрос был бы верен ровно в миг постройки экрана: пробный чек
  // не появился бы на нём вовсе, и вкладка отвечала бы «касса ничего не
  // печатала» сразу после печати. Источник у подписки уже есть —
  // `PrintQueue.watch()`, тот самый, которым живёт кассовая вкладка.
  //
  // # Почему оператор — вопрос
  //
  // У очереди фискализации сигнала изменения нет, и заводить его ради
  // экрана, который наладчик и так обновляет потягиванием вниз, значило бы
  // строить подписку под поверхность, а не под событие. Кассовая вкладка
  // устроена вопросом с первого дня.
  //
  // # Тела у обеих пустые, и это решение
  //
  // Рабочего места операции не возят. Вопрос вкладки — «что отправила
  // **эта касса**», и отвечает касса по себе (`TerminalRepository.self`).
  // Прими операция чужой `terminalId` с планшета, вкладка читала бы чеки
  // соседнего рабочего места (И29: у задания есть владелец — терминал и
  // касса), а право `settings.hardware` этого не закрывает: оно про
  // настройку своего оборудования, а не про чужие чеки.
  //
  // # Право — `settings.hardware`, существующее
  //
  // Тот же ключ, что у маршрута `/diagnostics` на кассе, у
  // `/hardware-settings` и у `/emulator-settings`. Экран показывает
  // внутренности настройки оборудования, а не операцию кассира. Своего
  // ключа не заводится по тому же доводу, что у соседей: новый без шага
  // миграции тихо не достаётся ни одному существующему пользователю
  // (докстринг `PermissionKeys.allPermissions`, «Правило на будущее»), а
  // миграции у этой работы нет.

  /// Задания печати этой кассы — сейчас и при каждом изменении.
  ///
  /// Чек едет **готовым текстом**, а не байтами: разбирает его касса своим
  /// единственным разборщиком. Разбор, почему именно так, — в докстринге
  /// `lib/domain/diagnostics/hardware_diagnostics.dart`.
  static const diagnosticsPrinter = Watch<void, PrinterDiagnosticsView>(
    'diagnostics.printer',
    access: SessionAccess(needs: PermissionKeys.settingsHardware),
    encode: _nothing,
    decode: printerDiagnosticsFromWireJson,
  );

  /// Обмен с фискальным оператором: принятые документы и очередь.
  static const diagnosticsFiscal = Ask<void, FiscalDiagnosticsView>(
    'diagnostics.fiscal',
    access: SessionAccess(needs: PermissionKeys.settingsHardware),
    encode: _nothing,
    decode: fiscalDiagnosticsFromWireJson,
  );

  // ── ящик, дисплей, весы (пункт 4 того же плана) ────────────────────────
  //
  // Три вкладки, которых на планшете не было вовсе. Право, пустое тело и
  // запрет называть рабочее место — те же, что у двух операций выше; ниже
  // только то, что у этих троих своё.
  //
  // # Все три — подписки, и у каждой довод свой
  //
  // У ящика и дисплея довод принтера дословно: наладчик держит вкладку
  // открытой и **жмёт кнопку на кассе** — импульс и строка обязаны появиться
  // в момент события, а не при следующем вопросе. Сигнал у кассы уже есть
  // (`CashDrawerJournal.watch`, `CustomerDisplayJournal.watch`), заводить под
  // эти подписки не пришлось ничего — тем они и отличаются от фискальной
  // очереди, где сигнала нет и подписку строили бы ради экрана.
  //
  // У весов довод **другой и сильнее**: вопрос здесь неверен по предмету.
  // Вкладка весов существует затем, чтобы наладчик положил груз на чашу и
  // увидел, как число едет; вопрос показал бы одно застывшее число.
  //
  // # Но у весов данные — поток, и потому касса их прореживает
  //
  // `ScalesService` опрашивает порт каждые 200 мс. Кадр на каждое показание
  // означал бы поток ради вкладки, которую смотрят минуту. Прореживает
  // **касса, до провода**, двумя правилами: не повторяться (неподвижные весы
  // шлют одно и то же бесконечно — с этим правилом простой стоит ноль
  // кадров) и не чаще окна, с обязательной досылкой последнего. Разбор
  // решения целиком — в докстринге
  // `HardwareDiagnosticsRepository.watchScales`.
  //
  // Прореживание живёт на кассе, а не здесь и не во вкладке, по тому же
  // правилу, что текст чека: по проводу едет готовое значение, а не сырьё.

  /// Импульсы денежного ящика этой кассы — сейчас и при каждом новом.
  static const diagnosticsDrawer = Watch<void, DrawerDiagnosticsView>(
    'diagnostics.drawer',
    access: SessionAccess(needs: PermissionKeys.settingsHardware),
    encode: _nothing,
    decode: drawerDiagnosticsFromWireJson,
  );

  /// Строки, ушедшие на дисплей покупателя, и то, что на стекле сейчас.
  static const diagnosticsDisplay = Watch<void, DisplayDiagnosticsView>(
    'diagnostics.display',
    access: SessionAccess(needs: PermissionKeys.settingsHardware),
    encode: _nothing,
    decode: displayDiagnosticsFromWireJson,
  );

  /// Показание весов живьём — кадрами, прореженными кассой.
  static const diagnosticsScales = Watch<void, ScalesDiagnosticsView>(
    'diagnostics.scales',
    access: SessionAccess(needs: PermissionKeys.settingsHardware),
    encode: _nothing,
    decode: scalesDiagnosticsFromWireJson,
  );

  /// Все операции провода.
  ///
  /// Список ведётся руками, и это не недосмотр: в Dart нет способа перечислить
  /// объявленные константы класса без зеркал, а зеркала запрещены в сборке
  /// под браузер. Забытая здесь операция уходит от проверок уникальности имени
  /// и рода — поэтому `till_ops_test.dart` отдельно сверяет этот список с
  /// поимённым перечислением всех тридцати двух.
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
    terminalSetPaymentTypes,
    terminalRegister,
    terminalResume,
    terminalDelete,
    terminalSelfEnsure,
    deviceDiscovery,
    deviceCheck,
    scannerRules,
    // Пункт 11 ревизии 2026-09-19: правила сканера с планшета не только
    // читаются, а просроченная партия называется и в браузере.
    scannerRulesSave,
    saleExpiryWarning,
    // Пункт 12 ревизии 2026-09-19: остаток соседнего рабочего места
    // перестаёт устаревать молча.
    stockRevision,
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
    // Настройка оплаты по QR из браузера — решение заказчика 2026-09-18.
    qrProviderSettings,
    qrProviderSave,
    qrProviderClear,
    qrProviderKind,
    // Шаблон чека из браузера — решение заказчика 2026-09-18.
    receiptTemplates,
    receiptTemplateSave,
    receiptTemplateSelect,
    receiptTemplateDelete,
    receiptTemplatePreview,
    receiptTemplateTestPrint,
    // Смена с браузерного терминала — решение заказчика 2026-09-18.
    shiftState,
    shiftClose,
    shiftOpen,
    // Диагностика оборудования с планшета — пункт «Достижимость с
    // браузерного терминала» плана 2026-09-19.
    diagnosticsPrinter,
    diagnosticsFiscal,
    // Пункт 4 того же плана: ящик, дисплей покупателя и весы. До них на
    // планшете этих вкладок не было вовсе.
    diagnosticsDrawer,
    diagnosticsDisplay,
    diagnosticsScales,
    ...SaleOps.all,
    ...PayOps.all,
    // Задача 19 плана «Продажа с браузерного терминала»: шесть операций
    // возврата, у каждой своё имя в словаре доступа — иначе два ключа
    // `op.refund`/`op.refundWithoutReceipt` проверять было бы нечем
    // (докстринг `RefundOps`). Входят одной строкой по тому же правилу, что
    // и `SaleOps.all`: единый список не имеет права знать о делении на
    // файлы, иначе сторож провода видел бы только часть операций.
    ...RefundOps.all,
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

/// Тем же именем поля и тем же списком имён, что и в [terminalToWireJson]
/// (`terminal_wire.dart`): запрос и ответ говорят об одном наборе одними
/// словами, иначе согласие двух форм пришлось бы доказывать тестом вместо
/// того, чтобы читать его глазами.
Map<String, Object?> _encodePaymentTypes(TerminalPaymentTypesRequest request) =>
    {
      'terminalId': request.terminalId,
      'allowedPaymentTypes': paymentTypeNames(request.types),
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

/// Настройка провайдера в кадре заявки.
///
/// Терпение — секундами целым числом, а не `Duration.toString()`: разбор
/// текста «0:03:00.000000» на той стороне был бы вторым местом, где живёт
/// форма, и первая же смена локали или формата сломала бы его молча.
Map<String, Object?> _encodeQrProviderSave(QrProviderSaveAsk ask) => {
  'baseUrl': ask.baseUrl,
  'code': ask.code,
  'patienceSeconds': ask.patience.inSeconds,
  // Ключ кладётся **только когда кассир его набрал** — тем же приёмом и по
  // тому же доводу, что ПИН сертификата: пустая строка в кадре и «не
  // набирали» означают разное, и касса обязана различать их, чтобы
  // пересохранение адреса не стирало прежний ключ.
  if (ask.newApiKey != null && ask.newApiKey!.isNotEmpty)
    'newApiKey': ask.newApiKey,
  // Стирание кладётся только когда его просили: `false` в кадре ничего не
  // сообщает, а отсутствие ключа читается умолчанием на той стороне.
  if (ask.clearApiKey) 'clearApiKey': true,
};

/// Заявка из тела кадра — читается **снисходительно**.
///
/// Не-строка в адресе или мусор в секундах — кадр, собранный мимо экрана, и
/// честный ответ ему даёт касса: пустой адрес делает настройку неполной
/// (`QrProviderView.configured == false`), а не роняет обработчик `TypeError`
/// ом, уехавшим на провод именем типа (I144).
///
/// Терпение вне разумных границ обрезается **здесь, а не на экране**: экран
/// границы проверяет, чтобы избавить от круга, но запрет обязан держать
/// касса — кадр можно собрать и без экрана. Ноль секунд означал бы код,
/// который умирает раньше, чем покупатель откроет банк.
QrProviderSaveAsk qrProviderSaveFromWireJson(Map<String, Object?> json) => (
  baseUrl: switch (json['baseUrl']) {
    final String value => value.trim(),
    _ => '',
  },
  code: switch (json['code']) {
    final String value => value.trim(),
    _ => '',
  },
  patience: Duration(
    seconds: switch (json['patienceSeconds']) {
      final num value
          when value >= qrPatienceMinSeconds && value <= qrPatienceMaxSeconds =>
        value.toInt(),
      _ => qrPatienceDefaultSeconds,
    },
  ),
  newApiKey: switch (json['newApiKey']) {
    final String value when value.trim().isNotEmpty => value.trim(),
    _ => null,
  },
  clearApiKey: json['clearApiKey'] == true,
);

/// Границы терпения — **одни на экран и на кассу**.
///
/// Объявлены здесь, а не в контроллере экрана, ровно потому, что проверяют их
/// оба: контроллер — чтобы не платить круг за заведомый отказ, касса — чтобы
/// запрет держался и для кадра, собранного мимо экрана. Два набора чисел
/// разошлись бы на первой же правке.
const qrPatienceMinSeconds = 30;
const qrPatienceMaxSeconds = 1800;
const qrPatienceDefaultSeconds = 180;

Map<String, Object?> _encodeQrKindActive(bool active) => {'active': active};

/// Включение вида оплаты из тела кадра. Отсутствие поля — `false`: умолчание
/// обязано быть тем, которое ничего не включает.
bool qrKindActiveFromWireJson(Map<String, Object?> json) =>
    json['active'] == true;

// --- Смена ----------------------------------------------------------------

/// Пересчитанные деньги в кадре — **строкой и только когда их считали**.
///
/// Деньги строкой — правило I159 (`wireMoney`, единственная дверь). Ключ
/// **отсутствует**, когда считать никто не садился: `null` в значении читался
/// бы так же, но говорил бы, что вкладка про пересчёт думала, а
/// снисходительный разбор на приёме обязан отличать «не назвали» от
/// «назвали мусором». Класть сюда `'0'` было бы прямой ошибкой: ноль в ящике
/// — законный результат пересчёта, и подменить им «не считали» значит
/// записать недостачу на всю выручку смены.
Map<String, Object?> _encodeShiftCounted(Decimal? counted) => {
  if (counted != null) 'counted': wireMoney(counted),
};

/// Пересчитанные деньги из тела кадра — читается **снисходительно**.
///
/// Не-строка, пустая строка и не-число читаются как «не считали», а не как
/// ноль: кадр, собранный мимо экрана, не имеет права записать недостачу на
/// всю выручку смены тем, что в поле оказался мусор. Тот же довод, что у
/// `qrProviderSaveFromWireJson`, только цена ошибки здесь денежная.
///
/// Число, а не строка (`{'counted': 1234.5}`), — тоже «не считали»: деньги
/// по проводу едут строкой, и принять `double` значило бы завести вторую,
/// теряющую точность дверь рядом с единственной разрешённой (I159).
Decimal? shiftCountedFromWireJson(Map<String, Object?> json) =>
    switch (json['counted']) {
      final String value when value.trim().isNotEmpty => Decimal.tryParse(
        value.trim(),
      ),
      _ => null,
    };

/// Состояние смены в кадре ответа.
Map<String, Object?> shiftDeskViewToWireJson(ShiftDeskView view) => {
  'open': view.open,
  'overAge': view.overAge,
  if (view.openedAtSeconds != null) 'openedAtSeconds': view.openedAtSeconds,
  if (view.cashierName != null) 'cashierName': view.cashierName,
  'openingCash': wireMoney(view.openingCash),
  'systemTotal': wireMoney(view.systemTotal),
  'expectedCash': wireMoney(view.expectedCash),
  'unfinishedSales': view.unfinishedSales,
  'unfiscalizedCount': view.unfiscalizedCount,
  'unfiscalizedReceipts': view.unfiscalizedReceipts,
};

/// Разбор состояния смены.
///
/// Усечённый кадр читается **закрытой сменой**, а не открытой: умолчание
/// обязано быть тем, которое ничего не утверждает. Ошибись оно в другую
/// сторону, и вкладка на потерянном поле рисовала бы зелёный значок «смена
/// открыта» — ровно тот дефект, ради которого эта операция и заведена.
///
/// `openedAtSeconds` — **секунды**, и имя поля названо так нарочно: ошибка в
/// единицах уже стоила получаса разбора, а при множителе в тысячу
/// просроченная смена выглядела бы свежей.
ShiftDeskView shiftDeskViewFromWireJson(Map<String, Object?> json) =>
    ShiftDeskView(
      open: json['open'] == true,
      // Возраст **не пересчитывается здесь из `openedAtSeconds`**, а
      // читается тем, что сказала касса: предел (сутки, сравнение `>=`)
      // живёт в `ShiftAgeRule`, и второй счёт возраста в браузере разошёлся
      // бы с тем, которым касса запирает продажу, — значок говорил бы одно,
      // а продажа другое.
      overAge: json['overAge'] == true,
      openedAtSeconds: switch (json['openedAtSeconds']) {
        final int value when value > 0 => value,
        _ => null,
      },
      cashierName: switch (json['cashierName']) {
        final String value when value.isNotEmpty => value,
        _ => null,
      },
      openingCash: _money(json['openingCash']),
      systemTotal: _money(json['systemTotal']),
      expectedCash: _money(json['expectedCash']),
      unfinishedSales: switch (json['unfinishedSales']) {
        final int value when value > 0 => value,
        _ => 0,
      },
      unfiscalizedCount: switch (json['unfiscalizedCount']) {
        final int value when value > 0 => value,
        _ => 0,
      },
      unfiscalizedReceipts: switch (json['unfiscalizedReceipts']) {
        final List<Object?> rows => [
          for (final row in rows)
            if (row is int) row,
        ],
        _ => const [],
      },
    );

/// Деньги из кадра. Потерянное или испорченное поле — ноль: показать нечего,
/// и это честнее выдуманного числа. Экран при этом не молчит — рядом стоит
/// `open == false`, то есть «смены нет», и чисел он не рисует вовсе.
Decimal _money(Object? raw) => switch (raw) {
  final String value => Decimal.tryParse(value) ?? Decimal.zero,
  _ => Decimal.zero,
};

// --- Шаблон чека ----------------------------------------------------------

Map<String, Object?> _encodeReceiptTemplateSave(ReceiptTemplateSaveAsk ask) => {
  // `id` кладётся только у правки: отсутствие поля и есть «новый шаблон», а
  // `null` в кадре читалось бы тем же, но говорило бы, что вкладка про `id`
  // думала. Разница не косметическая — снисходительный разбор ниже
  // обязан отличать «не назвали» от «назвали мусором».
  if (ask.id != null) 'id': ask.id,
  'name': ask.name,
  'optionsJson': ask.optionsJson,
};

/// Заявка из тела кадра — читается **снисходительно**.
///
/// Тот же довод, что у `qrProviderSaveFromWireJson`: кадр можно собрать и
/// мимо экрана, и не-строка в имени — это заявка, а не повод уронить
/// обработчик `TypeError`-ом, уехавшим на провод именем типа (I144).
///
/// Пустое имя **не** подменяется здесь умолчанием: запрет на безымянный
/// шаблон держит обработчик кассы названным отказом, а не тихая подстановка
/// «Без названия». Владелец обязан узнать, что шаблон не записан, — иначе он
/// уйдёт с экрана, считая чек настроенным.
ReceiptTemplateSaveAsk receiptTemplateSaveFromWireJson(
  Map<String, Object?> json,
) => (
  id: switch (json['id']) {
    final int value when value > 0 => value,
    _ => null,
  },
  name: switch (json['name']) {
    final String value => value.trim(),
    _ => '',
  },
  // Мусор вместо настройки читается пустой строкой, а `ReceiptOptions.decode`
  // на ней отдаёт умолчание — то же, что видит новый шаблон. Уронить
  // обработчик было бы хуже: кадр пришёл, ответить на него надо.
  optionsJson: switch (json['optionsJson']) {
    final String value => value,
    _ => '',
  },
);

Map<String, Object?> _encodeReceiptTemplateId(int id) => {'id': id};

/// Идентификатор из тела кадра. Мусор и отсутствие читаются нулём, а строки с
/// таким `id` не бывает: и выбор, и удаление окажутся ничем не сделавшими
/// запросами, а не обработчиком, упавшим на приведении типа.
int receiptTemplateIdFromWireJson(Map<String, Object?> json) =>
    switch (json['id']) {
      final int value => value,
      _ => 0,
    };

Map<String, Object?> _encodeReceiptTemplateOptions(String optionsJson) => {
  'optionsJson': optionsJson,
};

String receiptTemplateOptionsFromWireJson(Map<String, Object?> json) =>
    switch (json['optionsJson']) {
      final String value => value,
      _ => '',
    };

/// Список шаблонов в кадре ответа.
///
/// Разобранной настройки (`ReceiptOptions`) здесь нет: по проводу едет ровно
/// то, что лежит в колонке, а разбор — дело экрана. Разбери его порт или
/// кодек, у формы хранения появился бы второй читатель, отстающий на одну
/// правку.
Map<String, Object?> receiptTemplateCatalogToWireJson(
  ReceiptTemplateCatalog catalog,
) => {
  'paperWidthMm': catalog.paperWidthMm,
  'templates': [
    for (final row in catalog.templates)
      {
        'id': row.id,
        'name': row.name,
        'builtIn': row.builtIn,
        'selected': row.selected,
        'optionsJson': row.optionsJson,
      },
  ],
};

/// Разбор списка. Усечённый кадр не роняет вкладку: она покажет пустой
/// список — то же, что показала бы для кассы без единого шаблона.
ReceiptTemplateCatalog receiptTemplateCatalogFromWireJson(
  Map<String, Object?> json,
) => ReceiptTemplateCatalog(
  // Ширина ленты умолчанием **58 мм**, а не 80: узкая лента — та, на которой
  // текст переносится раньше. Ошибись умолчание в другую сторону, и
  // предпросмотр на потерянном поле показывал бы строки шире, чем выйдет из
  // принтера, — то самое расхождение «экран не то, что бумага», ради
  // которого всё это устроено.
  paperWidthMm: switch (json['paperWidthMm']) {
    final int value when value == 80 => 80,
    _ => 58,
  },
  templates: switch (json['templates']) {
    final List<Object?> rows => [
      for (final row in rows)
        if (row is Map<String, Object?>)
          ReceiptTemplateRow(
            id: switch (row['id']) {
              final int value => value,
              _ => 0,
            },
            name: switch (row['name']) {
              final String value => value,
              _ => '',
            },
            builtIn: row['builtIn'] == true,
            selected: row['selected'] == true,
            optionsJson: switch (row['optionsJson']) {
              final String value => value,
              _ => '',
            },
          ),
    ],
    _ => const [],
  },
);

/// Предпросмотр в кадре ответа — **готовый текст**, собранный кассой.
Map<String, Object?> receiptTemplatePreviewToWireJson(String text) => {
  'preview': text,
};

/// Разбор предпросмотра. Потерянное поле читается пустой строкой: экран
/// покажет пустую рамку, а не строку «null» поверх белого поля чека.
String receiptTemplatePreviewFromWireJson(Map<String, Object?> json) =>
    switch (json['preview']) {
      final String value => value,
      _ => '',
    };

/// Настройка QR в кадре ответа — **без ключа, и класть его сюда нечего**.
///
/// [QrProviderView] поля ключа не имеет вовсе (докстринг
/// `qr_provider_setup.dart`), поэтому утечке неоткуда взяться: это свойство
/// формы, а не внимательности пишущего. Единственное, что касса говорит о
/// ключе, — `keySet`: заведён или нет.
Map<String, Object?> qrProviderViewToWireJson(QrProviderView view) => {
  'configured': view.configured,
  'baseUrl': view.baseUrl,
  'code': view.code,
  'keySet': view.keySet,
  'patienceSeconds': view.patience.inSeconds,
  'kindActive': view.kindActive,
};

/// Разбор ответа. Усечённый кадр не роняет вкладку: она покажет настройку
/// незаведённой — то же, что показала бы для пустой кассы.
QrProviderView qrProviderViewFromWireJson(Map<String, Object?> json) =>
    QrProviderView(
      configured: json['configured'] == true,
      baseUrl: switch (json['baseUrl']) {
        final String value => value,
        _ => '',
      },
      code: switch (json['code']) {
        final String value => value,
        _ => '',
      },
      keySet: json['keySet'] == true,
      patience: Duration(
        seconds: switch (json['patienceSeconds']) {
          final num value when value > 0 => value.toInt(),
          _ => qrPatienceDefaultSeconds,
        },
      ),
      kindActive: json['kindActive'] == true,
    );

// --- Разбор ответов ------------------------------------------------------

/// Итог действия. Отсутствие `ok` — это «нет», а не «да»: умолчание обязано
/// быть тем, которое ничего не утверждает.
bool _decodeOk(Map<String, Object?> body) => body['ok'] == true;

Map<String, Object?> _encodeProductId(int productId) => {
  'productId': productId,
};

/// Нераспознанное тело читается как «не просрочено», и это решение, а не
/// небрежность: предупреждение — не запрет, и выдумать его на непонятном
/// ответе значило бы учить кассира не верить жёлтому снекбару.
bool _decodeExpired(Map<String, Object?> body) => body['expired'] == true;

/// Номер ревизии остатков. Отсутствие поля — отказ разбора, а не ноль:
/// «касса прислала кадр без номера» и «номер ноль» — разные вещи, и
/// вторая означает свежую кассу, на которой остаток ещё не двигали.
int _decodeRevision(Map<String, Object?> body) {
  final value = body['revision'];
  if (value is int) return value;
  throw FormatException('stock.revision: нет поля revision — $body');
}

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
    _objectList(body['sessions']).map(liveSessionFromWireJson).toList();

NetworkStatus _decodeNetworkStatus(Map<String, Object?> body) =>
    networkStatusFromWireJson(body);

List<WifiNetwork> _decodeWifiScan(Map<String, Object?> body) =>
    _objectList(body['networks']).map(wifiNetworkFromWireJson).toList();

({bool success, String message}) _decodeSuccessMessage(
  Map<String, Object?> body,
) => (
  success: body['success'] == true,
  message: (body['message'] ?? '') as String,
);

/// Форма `network.ethernetStatus` варьируется по тому, что вернул `ip -j addr
/// show` на кассе (докстринг `NetworkRepository.ethernetStatus`) — тело
/// кадра и есть ответ, разбор не сужает его до собственной модели.
Map<String, dynamic> _decodeEthernetStatus(Map<String, Object?> body) => body;

({bool success, String mode}) _decodeSuccessMode(Map<String, Object?> body) =>
    (success: body['success'] == true, mode: (body['mode'] ?? '') as String);

// --- Диагностика оборудования --------------------------------------------
//
// Пункт «Достижимость с браузерного терминала» плана 2026-09-19.
//
// # Чего в этих кадрах нет ни байта — и это главное свойство
//
// Байтов ESC/POS. Чек едет **готовым текстом**: его разобрала касса своим
// единственным разборщиком, и во второй половине провода раскладки чека нет
// вовсе. Разбор, почему так, — в докстринге
// `lib/domain/diagnostics/hardware_diagnostics.dart`; цена того, что было бы
// наоборот, записана в докстринге `escpos_text_preview.dart`.
//
// # Состояние задания едет ИМЕНЕМ, а не номером
//
// Глобальное правило проекта (докстринг `PrintJobState`): индекс сломался бы
// от вставки нового состояния в середину перечисления, и сломался бы молча.

/// Задания печати в кадре подписки.
Map<String, Object?> printerDiagnosticsToWireJson(
  PrinterDiagnosticsView view,
) => {
  'available': view.available,
  'jobs': [
    for (final job in view.jobs)
      {
        'id': job.id,
        'state': job.state.name,
        'attempts': job.attempts,
        'createdAt': job.createdAt.toIso8601String(),
        'failureReason': job.failureReason,
        'text': job.text,
      },
  ],
};

/// Разбор заданий печати.
///
/// Состояние ищется **строго по имени** (`PrintJobState.values.byName`), без
/// подстановки умолчания, и это решение: имя, которого нет в перечислении,
/// означало бы кассу новее вкладки, а такого не бывает по построению —
/// страницу и бандл вкладка берёт у **той же кассы**, к которой потом
/// подключается (`ApiServer._frontendHandler`). Подставь разбор здесь «ждёт
/// очереди» на неизвестное имя, вкладка показывала бы правдоподобно-неверное
/// состояние вместо того, чтобы назвать беду.
PrinterDiagnosticsView printerDiagnosticsFromWireJson(
  Map<String, Object?> json,
) => PrinterDiagnosticsView(
  available: json['available'] == true,
  jobs: switch (json['jobs']) {
    final List<Object?> rows => [
      for (final row in rows.whereType<Map<String, Object?>>())
        PrintJobDiagnostics(
          id: (row['id'] ?? '') as String,
          state: PrintJobState.values.byName((row['state'] ?? '') as String),
          attempts: switch (row['attempts']) {
            final int value => value,
            _ => 0,
          },
          createdAt:
              DateTime.tryParse((row['createdAt'] ?? '') as String) ??
              DateTime.fromMillisecondsSinceEpoch(0),
          failureReason: row['failureReason'] as String?,
          text: (row['text'] ?? '') as String,
        ),
    ],
    _ => const [],
  },
);

/// Обмен с фискальным оператором в кадре ответа.
Map<String, Object?> fiscalDiagnosticsToWireJson(FiscalDiagnosticsView view) =>
    {
      'configured': view.configured,
      'accepted': [
        for (final doc in view.accepted)
          {
            'fiscalNo': doc.fiscalNo,
            'operatorReceiptNo': doc.operatorReceiptNo,
            'receiptNo': doc.receiptNo,
            'offline': doc.offline,
          },
      ],
      'queued': [
        for (final doc in view.queued)
          {
            'idempotencyKey': doc.idempotencyKey,
            'opType': doc.opType,
            'attempts': doc.attempts,
            'failed': doc.failed,
            'lastError': doc.lastError,
            // Тело запроса — строкой, уже с отступами. Не вложенным объектом:
            // касса форматирует его ровно так, как этот текст будут сверять с
            // тем, что ждёт оператор, и второй форматировщик во вкладке
            // разошёлся бы с первым на первой же правке.
            'payloadJson': doc.payloadJson,
          },
      ],
      // Признак «за адресом эмулятор» считает КАССА: вкладка одна на обе
      // поверхности, а разбор адреса требует `dart:io`, которого в браузерной
      // сборке нет. Довод целиком — на `FiscalDiagnosticsView.onLoopback`.
      'onLoopback': view.onLoopback,
    };

// --- Ящик, дисплей, весы --------------------------------------------------
//
// Пункт 4 того же плана. Три правила, общие на все три кадра:
//
// 1. **перечни едут именами**, а не номерами — общее правило проекта
//    (докстринг `PrintJobState`): индекс сломался бы от вставки значения в
//    середину, и сломался бы молча;
// 2. **разбор имени строгий**, без подстановки умолчания, тем же доводом,
//    что у состояния задания печати: страницу и бандл вкладка берёт у той же
//    кассы, к которой подключается, и имени, которого нет в перечне, взяться
//    неоткуда. Подставь разбор умолчание, наладчик увидел бы правдоподобное
//    неверное слово вместо названной беды;
// 3. **готовые значения, а не сырьё.** Вес едет строкой с тремя знаками,
//    сумма на дисплее — той записью, что ушла в порт, статус весов —
//    разобранным. Второй разборщик на планшете разошёлся бы с первым молча —
//    то же решение, по которому чек едет текстом.

/// Импульсы ящика в кадре подписки.
Map<String, Object?> drawerDiagnosticsToWireJson(DrawerDiagnosticsView view) =>
    {
      'available': view.available,
      'kicks': [
        for (final kick in view.kicks)
          {
            'at': kick.at.toIso8601String(),
            'path': kick.path.name,
            // `accepted`, а не `opened`: обратной связи от соленоида нет ни на
            // одном пути, и имя поля на проводе обязано говорить это же.
            'accepted': kick.accepted,
            'note': kick.note,
          },
      ],
    };

/// Разбор импульсов ящика.
DrawerDiagnosticsView drawerDiagnosticsFromWireJson(
  Map<String, Object?> json,
) => DrawerDiagnosticsView(
  available: json['available'] == true,
  kicks: switch (json['kicks']) {
    final List<Object?> rows => [
      for (final row in rows.whereType<Map<String, Object?>>())
        DrawerKickDiagnostics(
          at:
              DateTime.tryParse((row['at'] ?? '') as String) ??
              DateTime.fromMillisecondsSinceEpoch(0),
          path: DrawerKickPath.values.byName((row['path'] ?? '') as String),
          accepted: row['accepted'] == true,
          note: row['note'] as String?,
        ),
    ],
    _ => const [],
  },
);

/// Строки дисплея покупателя в кадре подписки.
Map<String, Object?> displayDiagnosticsToWireJson(
  DisplayDiagnosticsView view,
) => {
  'available': view.available,
  'lines': [for (final line in view.lines) _displayLineToWireJson(line)],
  // «Что на стекле сейчас» едет **отдельным полем**, а не вычисляется
  // вкладкой обходом списка: правило «последняя принятая» живёт одно, у
  // журнала кассы. Посчитай его принимающая половина сама, правило оказалось
  // бы в двух местах и разошлось бы на первой же правке.
  'current': view.current == null
      ? null
      : _displayLineToWireJson(view.current!),
};

Map<String, Object?> _displayLineToWireJson(DisplayLineDiagnostics line) => {
  'at': line.at.toIso8601String(),
  'kind': line.kind.name,
  'text': line.text,
  'refusal': line.refusal,
};

DisplayLineDiagnostics _displayLineFromWireJson(Map<String, Object?> row) =>
    DisplayLineDiagnostics(
      at:
          DateTime.tryParse((row['at'] ?? '') as String) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      kind: DisplayCallKind.values.byName((row['kind'] ?? '') as String),
      text: (row['text'] ?? '') as String,
      refusal: row['refusal'] as String?,
    );

/// Разбор строк дисплея.
DisplayDiagnosticsView displayDiagnosticsFromWireJson(
  Map<String, Object?> json,
) => DisplayDiagnosticsView(
  available: json['available'] == true,
  lines: switch (json['lines']) {
    final List<Object?> rows => [
      for (final row in rows.whereType<Map<String, Object?>>())
        _displayLineFromWireJson(row),
    ],
    _ => const [],
  },
  current: switch (json['current']) {
    final Map<String, Object?> row => _displayLineFromWireJson(row),
    _ => null,
  },
);

/// Показание весов в кадре подписки.
///
/// Кадр приходит **прореженным**: касса не шлёт ни повторов, ни чаще одного
/// в окно. Разбор решения — в докстринге
/// `HardwareDiagnosticsRepository.watchScales`; здесь важно одно следствие:
/// по частоте этих кадров **нельзя** судить о частоте ответов прибора.
Map<String, Object?> scalesDiagnosticsToWireJson(ScalesDiagnosticsView view) =>
    {
      'bound': view.bound,
      'port': view.port,
      'baudRate': view.baudRate,
      'protocol': view.protocol,
      'connected': view.connected,
      'reading': view.reading == null
          ? null
          : {
              // Строкой с тремя знаками, уже приготовленной кассой: число на
              // проводе означало бы, что принимающая половина выбирает формат
              // показа, — а `Decimal` печатает 1.250 как «1.25», и разрешение
              // прибора терялось бы молча.
              'weight': view.reading!.weight,
              'unit': view.reading!.unit,
              'status': view.reading!.status.name,
              'errorMessage': view.reading!.errorMessage,
            },
    };

/// Разбор показания весов.
ScalesDiagnosticsView scalesDiagnosticsFromWireJson(
  Map<String, Object?> json,
) => ScalesDiagnosticsView(
  bound: json['bound'] == true,
  port: json['port'] as String?,
  baudRate: switch (json['baudRate']) {
    final int value => value,
    _ => 0,
  },
  protocol: (json['protocol'] ?? '') as String,
  connected: json['connected'] == true,
  reading: switch (json['reading']) {
    final Map<String, Object?> row => ScalesReadingDiagnostics(
      weight: (row['weight'] ?? '') as String,
      unit: (row['unit'] ?? '') as String,
      status: ScalesReadingStatus.values.byName(
        (row['status'] ?? '') as String,
      ),
      errorMessage: row['errorMessage'] as String?,
    ),
    _ => null,
  },
);

/// Разбор обмена с оператором.
FiscalDiagnosticsView fiscalDiagnosticsFromWireJson(
  Map<String, Object?> json,
) => FiscalDiagnosticsView(
  configured: json['configured'] == true,
  onLoopback: json['onLoopback'] == true,
  accepted: switch (json['accepted']) {
    final List<Object?> rows => [
      for (final row in rows.whereType<Map<String, Object?>>())
        FiscalAcceptedDocument(
          fiscalNo: row['fiscalNo'] as String?,
          operatorReceiptNo: row['operatorReceiptNo'] as String?,
          receiptNo: row['receiptNo'] as String?,
          offline: row['offline'] == true,
        ),
    ],
    _ => const [],
  },
  queued: switch (json['queued']) {
    final List<Object?> rows => [
      for (final row in rows.whereType<Map<String, Object?>>())
        FiscalQueuedDocument(
          idempotencyKey: (row['idempotencyKey'] ?? '') as String,
          opType: (row['opType'] ?? '') as String,
          attempts: switch (row['attempts']) {
            final int value => value,
            _ => 0,
          },
          failed: row['failed'] == true,
          lastError: row['lastError'] as String?,
          payloadJson: (row['payloadJson'] ?? '') as String,
        ),
    ],
    _ => const [],
  },
);
