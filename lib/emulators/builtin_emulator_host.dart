import 'dart:io';

import 'package:talker/talker.dart';

import 'package:telepos/core/settings/builtin_emulator_settings.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/emulators/escpos/emulator.dart';
import 'package:telepos/emulators/escpos/faults.dart';
import 'package:telepos/emulators/sbp/emulator.dart';
import 'package:telepos/emulators/serial/emulator.dart';
import 'package:telepos/emulators/webkassa/emulator.dart';
import 'package:telepos/emulators/webkassa/state.dart';

/// Адрес, по которому встроенный эмулятор слушает **на самом деле**.
///
/// Именно «на самом деле», а не «должен бы»: умолчание 9100 занимают чаще, чем
/// кажется — на машине разработки его держит `dart devtools` неделями
/// (измерено, `test/emulators/README.md`). Экран обязан показывать тот порт,
/// который получился, иначе кассир впишет в привязку число, которого никто не
/// слушает, и будет чинить несуществующий отказ.
class BuiltinEmulatorAddress {
  /// Прибор, к которому касса идёт по сети: принтер, терминал оплаты.
  const BuiltinEmulatorAddress.socket({
    required String this.host,
    required int this.port,
    required int this.controlPort,
  }) : path = null;

  /// Прибор на последовательном порту. Его «адрес» — путь, и с 2026-09-19 им
  /// может быть обычный файл: касса приняла путь как порт
  /// (`serial_port_path.dart`), и виртуальный COM ставить больше не нужно.
  const BuiltinEmulatorAddress.file(String this.path)
    : host = null,
      port = null,
      controlPort = null;

  final String? host;
  final int? port;

  /// Пульт `/_emul/*`: отказы, состояние, журнал, дверь остановки. Есть
  /// только у сетевых приборов — последовательному пультом служит сам экран
  /// настроек эмуляторов.
  final int? controlPort;

  /// Путь порта у последовательного прибора.
  final String? path;

  /// То, что вписывается в привязку прибора.
  String get bindingValue => path ?? '$host';

  /// Адрес для полей, где ждут **ссылку**, а не пару «узел, порт».
  ///
  /// Таких полей в кассе два, и оба не привязки прибора: «Адрес сервера»
  /// фискальных настроек и `QrProviderSettings.baseUrl` у провайдера QR.
  /// Собирается здесь, а не на экране, по тому же доводу, по которому здесь
  /// живёт [bindingValue]: два места, собирающих один адрес, расходятся молча,
  /// и расхождение выглядит как неисправная служба.
  ///
  /// `null` у последовательного прибора: ссылки у файла-порта нет.
  String? get baseUrl => path != null ? null : 'http://$host:$port';

  @override
  String toString() => path ?? '$host:$port (пульт $controlPort)';
}

/// Почему держатель отказался поднять прибор.
///
/// Перечисление, а не строка: причину показывает экран, и он обязан сказать её
/// на языке кассира. Текст из `lib/` в интерфейс не годится — словарей пять.
enum BuiltinEmulatorRefusalReason {
  /// Касса боевая: вписаны реквизиты оператора и не объявлен испытательный
  /// режим. Решение заказчика 2026-09-19.
  liveTill,

  /// Фискальных настроек держателю не дали, и доказать, что касса не боевая,
  /// нечем. Отказ **по умолчанию**: неизвестность здесь обязана читаться как
  /// «боевая», иначе забытая проводка в одной точке входа тихо открывает
  /// эмулятор ОФД на настоящей кассе.
  settingsUnknown,
}

/// Отказ поднять встроенный эмулятор — с названной причиной.
///
/// Причина обязательна и в journal, и в исключении: отказ без причины кассир
/// читает как поломку кассы и идёт чинить не то.
class BuiltinEmulatorRefused implements Exception {
  const BuiltinEmulatorRefused(this.kind, this.reason, this.explanation);

  final BuiltinEmulatorKind kind;
  final BuiltinEmulatorRefusalReason reason;

  /// Дословный довод для журнала кассы и для разработчика.
  final String explanation;

  @override
  String toString() =>
      'встроенный эмулятор ${kind.name} не поднят: $explanation';
}

/// Держатель встроенных эмуляторов: поднимает сокет по решению оператора и
/// гасит его по отмене решения.
///
/// # Чего он НЕ делает, и это главное
///
/// Он **не трогает контейнер зависимостей**. Ни включение, ни выключение не
/// меняют ни одного класса драйвера: касса как ходила к принтеру своим
/// `WifiPrinterManager` по адресу привязки, так и ходит. Эмулятор — это адрес,
/// на который можно направить привязку, и ничего больше.
///
/// Так устроено не ради красоты. Правило раздела эмуляторов требует, чтобы
/// точка подстановки была самой дальней — сетью (`test/emulators/README.md`).
/// Подставь мы здесь свой `PrinterManager`, и «работает на эмуляторе»
/// перестало бы говорить хоть что-то о работе на железе: из проверки выпали бы
/// разбор адреса, сокет, кадры ESC/POS, опрос `DLE EOT`, очередь печати и
/// разбор результата — то есть ровно то, что вероятнее всего сломано.
///
/// Сторож этого — `builtin_emulator_guards_test.dart`: при включённом
/// эмуляторе зарегистрирован **тот же** класс драйвера, что и без него.
///
/// # Фискальный оператор: единственный прибор с запретом
///
/// Эмуляторы железа доступны всегда — в худшем случае чек уйдёт в окно вместо
/// бумаги, и это видно в ту же секунду. С оператором иначе: касса,
/// «фискализующая» в подделку, выглядит работающей и выдаёт покупателю бумажку
/// без документа.
///
/// Решение заказчика 2026-09-19: **включать только пока касса не боевая**, и
/// «не боевая» определяется данными, а не намерением —
/// [FiscalSettings.allowsEmulatedOperator]. Проверка стоит на двери [start],
/// а не на экране: восстановление после перезагрузки идёт мимо экрана и
/// обязано упираться в тот же отказ. Включение и выключение пишутся в журнал
/// кассы предупреждением, а не сообщением: это событие меняет смысл всех
/// последующих чеков.
///
/// # Петля, и только петля
///
/// Слушается `127.0.0.1`. Эмулятор — измерительный прибор этой машины, а не
/// прибор магазина: касса с соседнего стола, направленная на него, печатала бы
/// в чужое окно. `docs/system-architecture.md`, раздел 16: новая установка не
/// открывает наружу ничего.
class BuiltinEmulatorHost {
  BuiltinEmulatorHost({
    Talker? logger,
    Map<BuiltinEmulatorKind, (int, int)>? portRanges,
    Future<FiscalSettings> Function()? fiscalSettings,
  }) : _logger = logger,
       _portRange = portRanges ?? defaultPortRanges,
       _fiscalSettings = fiscalSettings;

  final Talker? _logger;

  /// Откуда держатель узнаёт, боевая ли касса.
  ///
  /// Замыкание, а не `FiscalSettingsSource` из контейнера: держателю запрещено
  /// трогать контейнер зависимостей вовсе (сторож
  /// `builtin_emulator_guards_test.dart` читает его исходник на `GetIt`), и
  /// запрет этот стоит того, чтобы проводку делал тот, кто собирает граф.
  ///
  /// `null` означает «не дали», и это **отказ**, а не разрешение: см.
  /// [BuiltinEmulatorRefusalReason.settingsUnknown].
  final Future<FiscalSettings> Function()? _fiscalSettings;

  /// Диапазоны портов этого держателя.
  ///
  /// Задаётся снаружи не ради тестов, а потому что 9100 — величина внешнего
  /// мира: у кассы он может быть занят чем угодно, вплоть до другой копии
  /// кассы. Проба, дерущаяся с машиной за фиксированный номер, меряет машину,
  /// а не продукт: `dart devtools` держал 9100 на машине разработки в тот
  /// самый час, когда писались эти строки (PID 30044, измерено `netstat`).
  final Map<BuiltinEmulatorKind, (int, int)> _portRange;

  final Map<BuiltinEmulatorKind, _Running> _running = {};

  /// Адрес поднятого прибора, либо `null`, если он погашен.
  BuiltinEmulatorAddress? addressOf(BuiltinEmulatorKind kind) =>
      _running[kind]?.address;

  bool isRunning(BuiltinEmulatorKind kind) => _running.containsKey(kind);

  /// Поднимает прибор и возвращает адрес, который получился.
  ///
  /// Повторный вызов на уже поднятом приборе — не ошибка и не перезапуск:
  /// возвращается тот же адрес. Перезапуск порвал бы соединение очереди печати
  /// ради ничего.
  Future<BuiltinEmulatorAddress> start(BuiltinEmulatorKind kind) async {
    final already = _running[kind];
    if (already != null) return already.address;

    // Дверь одна, и запрет стоит на ней, а не на экране. Экран показывает
    // причину заранее (той же [refusalFor]), но доказательством служит эта
    // строка: путь мимо экрана — восстановление после перезагрузки
    // (`startBuiltinEmulators`) — обязан упираться в тот же отказ.
    final refusal = await refusalFor(kind);
    if (refusal != null) {
      _logger?.warning('[эмулятор] $refusal');
      throw refusal;
    }

    return switch (kind) {
      BuiltinEmulatorKind.receiptPrinter => _startPrinter(kind),
      BuiltinEmulatorKind.scale => _startSerial(kind, role: 'scale'),
      BuiltinEmulatorKind.customerDisplay => _startSerial(
        kind,
        role: 'display',
      ),
      BuiltinEmulatorKind.fiscalOperator => _startFiscal(kind),
      BuiltinEmulatorKind.qrProvider => _startQrProvider(kind),
    };
  }

  /// Почему этот прибор поднять нельзя — или `null`, если можно.
  ///
  /// # Зачем это отдельно от [start]
  ///
  /// Чтобы экран мог **погасить выключатель заранее и назвать причину**, а не
  /// давать щёлкнуть и показывать отказ. Выключатель, который щёлкается и
  /// откатывается, читается как неисправность кассы.
  ///
  /// Двух источников правды это не заводит: [start] зовёт **эту же** функцию,
  /// а не повторяет условие. Диверсия проверена — снятый вызов из [start]
  /// красит сторожа «касса с боевыми реквизитами отказывает во включении».
  ///
  /// # Чего это НЕ проверяет
  ///
  /// Оно не смотрит, куда касса ходит сейчас: адрес эмулятора можно вписать в
  /// фискальные настройки руками, минуя выключатель, и такая касса отсюда
  /// выглядит обычной. Это ловит пометка по адресу оператора на вкладке
  /// диагностики — нарочно другим признаком.
  Future<BuiltinEmulatorRefused?> refusalFor(BuiltinEmulatorKind kind) async {
    if (kind != BuiltinEmulatorKind.fiscalOperator) return null;

    final read = _fiscalSettings;
    if (read == null) {
      return BuiltinEmulatorRefused(
        kind,
        BuiltinEmulatorRefusalReason.settingsUnknown,
        'фискальные настройки держателю не переданы, и доказать, что касса '
        'не боевая, нечем. Неизвестность здесь читается как «боевая»',
      );
    }

    // Отказ тем же ответом: не сумев прочитать настройки, мы не знаем о кассе
    // ничего — а это ровно тот случай, ради которого заведён settingsUnknown.
    final FiscalSettings settings;
    try {
      settings = await read();
    } on Object catch (e) {
      return BuiltinEmulatorRefused(
        kind,
        BuiltinEmulatorRefusalReason.settingsUnknown,
        'фискальные настройки не прочитались ($e); доказать, что касса не '
        'боевая, нечем',
      );
    }

    if (settings.allowsEmulatedOperator) return null;
    return BuiltinEmulatorRefused(
      kind,
      BuiltinEmulatorRefusalReason.liveTill,
      'касса боевая: испытательный режим выключен, а реквизиты оператора '
      'вписаны (регистрационный «${settings.registrationNumber ?? ''}», '
      'заводской «${settings.cashboxUniqueNumber ?? ''}»). Эмулятор ОФД на '
      'такой кассе запрещён решением заказчика 2026-09-19: чек, ушедший в '
      'подделку, выглядит настоящим, а документа покупателю не даёт',
    );
  }

  /// Вес, который «лежит на чаше» встроенных весов.
  ///
  /// Пульт эмулятора, а не второй источник веса в кассе: число задаётся
  /// подставному прибору, и касса читает его своим `ScalesService` — своим
  /// разбором строки, своим опросом. Поле ввода веса на экране **диагностики**
  /// было бы совсем другим делом и потому там запрещено.
  void setScaleWeight(String weight, {bool stable = true}) {
    final running = _running[BuiltinEmulatorKind.scale];
    final emulator = running?.serial;
    if (emulator == null) return;
    emulator
      ..weight = weight
      ..stable = stable;
  }

  String? get scaleWeight =>
      _running[BuiltinEmulatorKind.scale]?.serial?.weight;

  Future<BuiltinEmulatorAddress> _startSerial(
    BuiltinEmulatorKind kind, {
    required String role,
  }) async {
    // Файл в системном временном каталоге, а не рядом с базой: это не данные
    // кассы, а провод подставного прибора. Переживать перезапуск ему незачем.
    final dir = await Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}telepos-emulators',
    ).create(recursive: true);
    final path = '${dir.path}${Platform.pathSeparator}${kind.name}.port';
    await File(path).writeAsBytes(const []);

    final emulator = SerialEmulator(
      portPath: path,
      role: role,
      echo: false,
      // Через файл двусторонний обмен не выходит: опрос кассы только читает.
      // Непрерывная выдача — повадка половины рыночных весов, см. `continuous`.
      continuous: true,
    );
    final refusal = await emulator.open();
    if (refusal != null) {
      throw StateError('встроенный эмулятор ${kind.name}: $refusal');
    }

    final address = BuiltinEmulatorAddress.file(path);
    _running[kind] = _Running.serial(emulator, address);
    _logger?.info(
      '[эмулятор] ${kind.name} поднят на $address — впишите этот путь в '
      'привязку прибора, иначе касса о нём не узнает',
    );
    return address;
  }

  /// Учётные данные встроенного эмулятора ОФД.
  ///
  /// Одни и те же, что у запуска из командной строки
  /// (`test/emulators/webkassa/emulator.dart`), и это не лень: кассир,
  /// переключившийся с внешнего эмулятора на встроенный, не должен править
  /// логин, пароль и заводской номер в фискальных настройках — иначе первый же
  /// чек упрётся в код 1 или 6 и будет выглядеть поломкой кассы.
  static const String fiscalLogin = 'emul';
  static const String fiscalPassword = 'emul';
  static const String fiscalCashbox = 'SWK00000001';

  /// Ключ интегратора. Эмулятор его **не проверяет**, а касса — проверяет:
  /// `WebKassaProvider.validateConfig` без ключа не выходит в сеть вовсе.
  /// Пустое поле здесь выглядело бы как «эмулятор не отвечает».
  static const String fiscalApiKey = 'emulated-integrator-key';

  /// Регистрационный номер, который эмулятор отдаёт в ответе.
  ///
  /// В фискальные настройки кассы он **не вписывается** — см. `_bindFiscal`
  /// на экране настроек эмуляторов: заполненный регистрационный номер и есть
  /// признак боевой кассы, и вписать его значило бы запереть выключатель
  /// собственным действием.
  static const String fiscalRegistrationNumber = '000000000001';

  Future<BuiltinEmulatorAddress> _startFiscal(BuiltinEmulatorKind kind) async {
    final emulator = WebKassaEmulator(
      state: EmulatorState(
        cashboxes: {
          fiscalCashbox: EmulatedCashbox(
            uniqueNumber: fiscalCashbox,
            registrationNumber: fiscalRegistrationNumber,
            now: DateTime.now(),
          ),
        },
        login: fiscalLogin,
        password: fiscalPassword,
        // Двенадцать часов, а не тридцать секунд командной строки. Короткий
        // срок там нужен нарочно — им проходят ветку перевыпуска токена. Здесь
        // прибор стоит у кассира весь день, и протухший токен посреди проверки
        // шаблона чека он прочитает как неисправность, а не как сценарий.
        // Ветка перевыпуска от этого не теряется: её проходит проба.
        tokenTtl: const Duration(hours: 12),
        // Налог не сверяется: `isVatPayer` живёт в фискальных настройках
        // кассы, а не здесь, и прибор, спорящий с настройкой, красит исправную
        // кассу. Сверку НДС проходит проба, где режим задают явно.
        vat: VatMode.off,
      ),
      // Журнал остаётся в состоянии прибора, а в консоль не печатается:
      // встроенный эмулятор живёт внутри приложения, и его вывод смешался бы
      // с журналом кассы, где его примут за обмен с настоящим оператором.
      echo: false,
    );

    final host = InternetAddress.loopbackIPv4.address;
    final port = await _bindInRange(
      kind,
      from: _portRange[kind]!.$1,
      to: _portRange[kind]!.$2,
      bind: (p) => emulator.start(host, p),
    );

    final address = BuiltinEmulatorAddress.socket(
      host: host,
      port: port,
      // Пульт у WebKassa живёт на том же сервере, что и боевые пути: `/_emul/*`
      // против `/api/v4/*`. Второго порта у него нет и заводить его незачем —
      // разделение путями здесь строже, чем у принтера, где боевой порт вообще
      // не говорит по HTTP.
      controlPort: port,
    );
    _running[kind] = _Running.fiscal(emulator, address);

    // Громче, чем у железа, и намеренно. Это событие меняет смысл всех
    // последующих чеков: с этой минуты «документ принят оператором» означает
    // «принят подделкой на этой же машине». Запись в журнале — единственное,
    // что останется от неё завтра.
    _logger?.warning(
      '[эмулятор] ФИСКАЛЬНЫЙ ОПЕРАТОР поднят на $address. Документы, '
      'отправленные по этому адресу, НЕ являются фискальными: признак выдаёт '
      'эта машина. Логин $fiscalLogin, касса $fiscalCashbox',
    );
    return address;
  }

  Future<BuiltinEmulatorAddress> _startPrinter(BuiltinEmulatorKind kind) async {
    final emulator = EscPosEmulator(faults: EmulatorFaults());
    final host = InternetAddress.loopbackIPv4.address;
    final port = await _bindInRange(
      kind,
      from: _portRange[kind]!.$1,
      to: _portRange[kind]!.$2,
      bind: (p) => emulator.start(host, p),
    );
    final control = await _bindInRange(
      kind,
      from: port + 10,
      to: _portRange[kind]!.$2 + 10,
      bind: (p) => emulator.startControl(host, p),
    );

    final address = BuiltinEmulatorAddress.socket(
      host: host,
      port: port,
      controlPort: control,
    );
    _running[kind] = _Running.printer(emulator, address);
    _logger?.info(
      '[эмулятор] ${kind.name} поднят на $address — впишите этот адрес в '
      'привязку прибора, иначе касса о нём не узнает',
    );
    return address;
  }

  /// Провайдер QR/СБП — тем же сокетом, что принтер, только HTTP.
  ///
  /// `echo: false`: у отдельного процесса журнал эмулятора и есть его окно, а
  /// внутри кассы это чужой поток вывода. Записи никуда не деваются — их
  /// отдаёт пульт `/_emul/journal`.
  Future<BuiltinEmulatorAddress> _startQrProvider(
    BuiltinEmulatorKind kind,
  ) async {
    final emulator = SbpEmulator(echo: false);
    final host = InternetAddress.loopbackIPv4.address;
    final port = await _bindInRange(
      kind,
      from: _portRange[kind]!.$1,
      to: _portRange[kind]!.$2,
      bind: (p) => emulator.start(host, p),
    );
    final control = await _bindInRange(
      kind,
      from: port + 10,
      to: _portRange[kind]!.$2 + 10,
      bind: (p) => emulator.startControl(host, p),
    );

    final address = BuiltinEmulatorAddress.socket(
      host: host,
      port: port,
      controlPort: control,
    );
    _running[kind] = _Running.qrProvider(emulator, address);
    _logger?.info(
      '[эмулятор] ${kind.name} поднят на $address — впишите http://$host:$port '
      'в настройку провайдера QR, иначе касса о нём не узнает',
    );
    return address;
  }

  /// Гасит прибор.
  ///
  /// Привязка при этом **не чистится**: касса, оставшаяся с адресом погашенного
  /// эмулятора, обязана честно сказать «принтер не отвечает», а не сделать вид,
  /// что прибора и не было. Молчаливая правка чужой настройки — это второй
  /// источник правды о том, куда касса ходит, а их не бывает двух.
  Future<void> stop(BuiltinEmulatorKind kind) async {
    final running = _running.remove(kind);
    if (running == null) return;
    await running.printer?.stop();
    await running.serial?.stop();
    await running.fiscal?.stop();
    if (kind == BuiltinEmulatorKind.fiscalOperator) {
      // Выключение записывается так же громко, как включение. Пара «включил —
      // выключил» в журнале и есть ответ на завтрашний вопрос «а этот чек
      // настоящий?»: без второй половины окно остаётся открытым до конца
      // журнала.
      _logger?.warning(
        '[эмулятор] ФИСКАЛЬНЫЙ ОПЕРАТОР погашен (${running.address}). Адрес в '
        'фискальных настройках не тронут: касса обязана честно сказать, что '
        'оператор не отвечает, а не сделать вид, что его и не было',
      );
      return;
    }
    await running.qrProvider?.stop();
    _logger?.info('[эмулятор] ${kind.name} погашен (${running.address})');
  }

  Future<void> stopAll() async {
    for (final kind in _running.keys.toList()) {
      await stop(kind);
    }
  }

  /// Диапазоны портов на прибор: первый свободный из своего.
  ///
  /// 9100 — обычный порт чекового принтера, и с него же начинается поиск:
  /// совпадение с привычным числом стоит того, чтобы кассиру не пришлось
  /// вчитываться. Настоящий сетевой принтер этому не мешает — он в сети
  /// магазина, а здесь петля.
  static const Map<BuiltinEmulatorKind, (int, int)> defaultPortRanges = {
    BuiltinEmulatorKind.receiptPrinter: (9100, 9109),
    // 8085 — то же число, с которого начинают README и запуск из командной
    // строки. Кассир, читавший один из них, узнаёт адрес, а не вчитывается.
    BuiltinEmulatorKind.fiscalOperator: (8085, 8094),
    // 8890 — тот же порт, с которого запускают эмулятор СБП руками
    // (`test/emulators/README.md`), и то же число написано в докстринге
    // `QrProviderSettings.baseUrl`. Совпадение нужно, чтобы вписанный когда-то
    // вручную адрес продолжал вести туда же, куда и встроенный.
    BuiltinEmulatorKind.qrProvider: (8890, 8899),
  };

  Future<int> _bindInRange(
    BuiltinEmulatorKind kind, {
    required int from,
    required int to,
    required Future<void> Function(int port) bind,
  }) async {
    SocketException? last;
    for (var port = from; port <= to; port++) {
      try {
        await bind(port);
        return port;
      } on SocketException catch (e) {
        last = e;
      }
    }
    throw StateError(
      'встроенный эмулятор ${kind.name}: в $from–$to нет свободного порта. '
      'Занявшего можно найти командой `netstat -ano | findstr :$from`. '
      'Последний отказ: $last',
    );
  }
}

class _Running {
  _Running.printer(EscPosEmulator this.printer, this.address)
    : serial = null,
      fiscal = null,
      qrProvider = null;
  _Running.serial(SerialEmulator this.serial, this.address)
    : printer = null,
      fiscal = null,
      qrProvider = null;
  _Running.fiscal(WebKassaEmulator this.fiscal, this.address)
    : printer = null,
      serial = null,
      qrProvider = null;
  _Running.qrProvider(SbpEmulator this.qrProvider, this.address)
    : printer = null,
      serial = null,
      fiscal = null;

  final EscPosEmulator? printer;
  final SerialEmulator? serial;
  final WebKassaEmulator? fiscal;
  final SbpEmulator? qrProvider;
  final BuiltinEmulatorAddress address;
}
