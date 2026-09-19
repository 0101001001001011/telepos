/// Сторожа встроенного эмулятора — не о том, что он работает, а о том, что он
/// **не подменяет продукт**.
///
/// Эмулятор ценен ровно тем, чего он НЕ делает. Поднятый сокет проверяет весь
/// путь кассы: разбор адреса, соединение, кадры ESC/POS, опрос `DLE EOT`,
/// очередь печати, разбор ответа. Подставленный класс драйвера не проверяет
/// ничего из этого — и выглядит точно так же зелено. Отличить одно от другого
/// глазами нельзя, поэтому здесь сторожа.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/di/device_catalog_module.dart';
import 'package:telepos/app/di/hardware_module.dart';
import 'package:telepos/core/settings/builtin_emulator_settings.dart';
import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/emulators/builtin_emulator_host.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';

/// Настоящий `HttpClient` вместо подмены испытательного стенда.
///
/// Измерено 2026-09-19 и стоило часа: под `TestWidgetsFlutterBinding`
/// глобально подменён `HttpClient`, и он отвечает **HTTP 400 на всё**, не
/// выходя в сеть. Проба без этой обёртки падала с «Некорректный ответ WebKassa
/// (HTTP 400)» при исправном эмуляторе — то есть мерила стенд, а не продукт;
/// тот же эмулятор из файла без виджет-привязки отвечал токеном.
///
/// Обёртка `HttpOverrides.runZoned(createHttpClient: (c) => HttpClient(...))`
/// на это не годится и была проверена: внутри своей же зоны `HttpClient()`
/// снова попадает в подмену, и проба падает `StackOverflowError`. Наследник
/// без переопределений отдаёт настоящую реализацию из `super`.
class _RealHttpClient extends HttpOverrides {}

String _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final up = dir.parent;
    if (up.path == dir.path) throw StateError('корень репозитория не найден');
    dir = up;
  }
  return dir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = _repoRoot();

  group('Встроенный эмулятор не подменяет драйвер', () {
    test('адрес эмулятора даёт тот же класс, что адрес настоящего принтера', () async {
      final host = BuiltinEmulatorHost(
        portRanges: {BuiltinEmulatorKind.receiptPrinter: (18640, 18649)},
      );
      addTearDown(host.stopAll);
      final address = await host.start(BuiltinEmulatorKind.receiptPrinter);

      DeviceBinding bindingTo(String ip, int port) => DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: 'printer.escpos.80mm',
        parameters: {'ipAddress': ip, 'port': '$port'},
      );

      final logger = Talker();
      final onEmulator = buildReceiptPrinterManager(
        bindingTo(address.host!, address.port!),
        logger,
      );
      final onIron = buildReceiptPrinterManager(
        bindingTo('192.168.1.50', 9100),
        logger,
      );

      expect(
        onEmulator.runtimeType,
        onIron.runtimeType,
        reason:
            'если эмулятор получает свой класс драйвера, «работает на '
            'эмуляторе» перестаёт говорить что-либо о работе на железе',
      );
      expect(
        onEmulator,
        isA<WifiPrinterManager>(),
        reason: 'сетевой принтер идёт сокетом — и к эмулятору тоже',
      );
    });

    test('держатель не касается контейнера зависимостей', () {
      // Без комментариев: запрет на ЗАВИСИМОСТЬ, а не на упоминание. Сам
      // докстринг держателя объясняет, почему он не подставляет
      // `PrinterManager`, — и это ровно то, что мы хотим там читать.
      final source = File('$root/lib/emulators/builtin_emulator_host.dart')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      for (final forbidden in const [
        'GetIt',
        'registerSingleton',
        'registerFactory',
        'PrinterManager',
        'DeviceBindingRepository',
        // Фискальная половина того же запрета. `FiscalSettings` держателю
        // читать можно — это **данные** о кассе, по которым он решает, не
        // боевая ли она. А вот подставить провайдера значило бы снять с
        // проверки сборку конверта, карту кодов и очередь — то есть ровно то,
        // что вероятнее всего сломано.
        'FiscalProvider',
        'WebKassaProvider',
        'FiscalSettingsSource',
        // То же самое для оплаты по коду: держатель открывает сокет и
        // называет адрес. Тронув путь оплаты, он перестал бы быть
        // измерительным прибором.
        'QrPaymentProvider',
        'QrPaymentCoordinator',
        'QrPaymentDesk',
        'QrProviderSettings',
        'QrProviderSetupRepository',
      ]) {
        expect(
          source,
          isNot(contains(forbidden)),
          reason:
              'держатель поднимает сокет и только. Тронув «$forbidden», он '
              'перестаёт быть измерительным прибором и становится заглушкой',
        );
      }
    });

    test('путь оплаты по коду не знает, что за адресом эмулятор', () {
      // Тот же сторож, что у драйвера принтера, только для оплаты: там
      // проверяется, что адрес эмулятора даёт **тот же класс**, здесь — что
      // адрес вообще не участвует в выборе поведения. Ветка «если петля» в
      // пути оплаты означала бы, что «оплата по QR работает на эмуляторе»
      // перестало говорить что-либо о работе с настоящим провайдером: из
      // проверки выпали бы сборка запроса, разбор ответа, тайм-аут и разбор
      // обрыва — то есть ровно то, что вероятнее всего сломано.
      for (final path in const [
        'lib/data/payment/http_qr_payment_provider.dart',
        'lib/data/payment/qr_payment_desk.dart',
        'lib/data/payment/qr_payment_coordinator.dart',
      ]) {
        final code = File('$root/$path')
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .where((l) => !l.trimLeft().startsWith('///'))
            .join('\n');
        for (final forbidden in const [
          '127.0.0.1',
          'localhost',
          'isLoopback',
          'SbpEmulator',
          'BuiltinEmulator',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason:
                '$path: подобие провайдера отличается от настоящего ТОЛЬКО '
                'адресом. Упомянув «$forbidden», путь оплаты заводит вторую '
                'дорогу, которая выглядит работающей и расходится с первой '
                'молча',
          );
        }
      }
    });

    test('решение оператора не сливается с флагом сборки', () {
      // Разные риски и потому разные механизмы: флаг сборки убирает из AOT
      // ПОДСТАВНЫЕ КЛАССЫ (виртуальные профили, спулер, сканер), а настройка
      // включает СОКЕТ, который ничего не подменяет. Слить их — значит либо
      // вернуть подставные классы в магазинную сборку, либо отобрать у
      // заказчика встроенный эмулятор, ради которого всё затевалось.
      final catalogModule = File(
        '$root/lib/app/di/device_catalog_module.dart',
      ).readAsStringSync();
      expect(
        catalogModule,
        contains("const bool kEmulatorsEnabled = bool.fromEnvironment("),
        reason:
            'величина обязана остаться константой времени компиляции: на этом '
            'держится выпадение подставных классов из магазинной сборки',
      );

      for (final path in const [
        'lib/emulators/builtin_emulator_host.dart',
        'lib/core/settings/builtin_emulator_settings.dart',
      ]) {
        final source = File('$root/$path').readAsStringSync();
        final code = source
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('///'))
            .join('\n');
        expect(
          code,
          isNot(contains('kEmulatorsEnabled')),
          reason:
              '$path: встроенный эмулятор не читает флаг сборки и не зависит '
              'от него — иначе в обычной сборке его не будет',
        );
      }

      expect(
        kEmulatorsEnabled,
        isA<bool>(),
        reason: 'ссылка на величину, чтобы сторож ломался при переименовании',
      );
    });
  });

  group('Эмулятор ОФД: запрет на боевой кассе', () {
    /// Окно портов этой группы. Своё, а не боевое 8085: на машине разработки
    /// его занимает эмулятор, запущенный руками из командной строки, — и
    /// проба мерила бы машину.
    const from = 18680;
    const to = 18689;

    BuiltinEmulatorHost hostFor(FiscalSettings settings, {Talker? logger}) =>
        BuiltinEmulatorHost(
          logger: logger,
          portRanges: {BuiltinEmulatorKind.fiscalOperator: (from, to)},
          fiscalSettings: () async => settings,
        );

    /// Слушает ли **хоть кто-нибудь** в окне этой группы.
    ///
    /// Отказ метода `start` сам по себе ничего не доказывает: он совместим с
    /// поднятым и брошенным сокетом. Доказательство — что порт молчит.
    Future<bool> anythingListening() async {
      for (var port = from; port <= to; port++) {
        try {
          final socket = await Socket.connect(
            '127.0.0.1',
            port,
            timeout: const Duration(milliseconds: 300),
          );
          socket.destroy();
          return true;
        } on SocketException {
          continue;
        }
      }
      return false;
    }

    test('боевые реквизиты — отказ с названной причиной, и сокет не поднят', () async {
      final host = hostFor(
        FiscalSettings(
          operatorType: FiscalOperatorType.webkassa,
          testMode: false,
          registrationNumber: '000000000001',
          cashboxUniqueNumber: 'SWK00000001',
        ),
      );
      addTearDown(host.stopAll);

      await expectLater(
        host.start(BuiltinEmulatorKind.fiscalOperator),
        throwsA(
          isA<BuiltinEmulatorRefused>()
              .having(
                (e) => e.reason,
                'причина',
                BuiltinEmulatorRefusalReason.liveTill,
              )
              .having(
                (e) => e.explanation,
                'довод',
                allOf(contains('боевая'), contains('000000000001')),
              ),
        ),
        reason:
            'отказ без названной причины кассир читает как поломку кассы и '
            'идёт чинить не то',
      );

      expect(host.isRunning(BuiltinEmulatorKind.fiscalOperator), isFalse);
      expect(
        await anythingListening(),
        isFalse,
        reason:
            'брошенное исключение совместимо с поднятым сокетом. Доказывает '
            'запрет только молчащий порт',
      );
    });

    test('заполнена половина реквизитов — касса всё равно боевая', () async {
      // Граница названа нарочно: кассу с одним заполненным номером уже
      // знакомили с оператором, и чеки она шлёт. Требовать оба номера значило
      // бы открыть эмулятор ОФД ровно на таких кассах.
      final host = hostFor(
        FiscalSettings(
          operatorType: FiscalOperatorType.webkassa,
          testMode: false,
          registrationNumber: '000000000001',
        ),
      );
      addTearDown(host.stopAll);

      final refusal = await host.refusalFor(
        BuiltinEmulatorKind.fiscalOperator,
      );
      expect(refusal?.reason, BuiltinEmulatorRefusalReason.liveTill);
    });

    test('настроек не дали — тоже отказ: неизвестность читается как «боевая»', () async {
      final host = BuiltinEmulatorHost(
        portRanges: {BuiltinEmulatorKind.fiscalOperator: (from, to)},
      );
      addTearDown(host.stopAll);

      final refusal = await host.refusalFor(
        BuiltinEmulatorKind.fiscalOperator,
      );
      expect(
        refusal?.reason,
        BuiltinEmulatorRefusalReason.settingsUnknown,
        reason:
            'забытая проводка в одной точке входа иначе тихо открывает '
            'эмулятор ОФД на настоящей кассе',
      );
    });

    test('испытательный режим и пустые реквизиты — поднимается', () async {
      for (final settings in [
        FiscalSettings(
          operatorType: FiscalOperatorType.webkassa,
          testMode: true,
          registrationNumber: '000000000001',
          cashboxUniqueNumber: 'SWK00000001',
        ),
        FiscalSettings(
          operatorType: FiscalOperatorType.webkassa,
          testMode: false,
        ),
      ]) {
        final host = hostFor(settings);
        addTearDown(host.stopAll);
        final address = await host.start(BuiltinEmulatorKind.fiscalOperator);
        expect(address.baseUrl, startsWith('http://127.0.0.1:'));
        await host.stopAll();
      }
    });

    test('включение и выключение остаются в журнале кассы', () async {
      // Это событие меняет смысл всех последующих чеков. Запись в журнале —
      // единственное, что останется от него завтра, когда спросят, настоящий
      // ли был тот чек. Пара нужна целиком: без «погашен» окно в журнале
      // остаётся открытым до конца файла.
      final talker = Talker();
      final host = hostFor(
        FiscalSettings(operatorType: FiscalOperatorType.webkassa),
        logger: talker,
      );
      addTearDown(host.stopAll);

      await host.start(BuiltinEmulatorKind.fiscalOperator);
      await host.stop(BuiltinEmulatorKind.fiscalOperator);

      final lines = [for (final e in talker.history) e.displayMessage];
      expect(
        lines.where((l) => l.contains('ФИСКАЛЬНЫЙ ОПЕРАТОР поднят')),
        hasLength(1),
      );
      expect(
        lines.where((l) => l.contains('ФИСКАЛЬНЫЙ ОПЕРАТОР погашен')),
        hasLength(1),
      );
      expect(
        lines.firstWhere((l) => l.contains('поднят')),
        contains('НЕ являются фискальными'),
        reason:
            'запись без этого слова через полгода читается как «оператор '
            'настроен», то есть ровно наоборот',
      );
    });

    test('отказ во включении тоже попадает в журнал', () async {
      final talker = Talker();
      final host = hostFor(
        FiscalSettings(
          operatorType: FiscalOperatorType.webkassa,
          testMode: false,
          cashboxUniqueNumber: 'SWK00000001',
        ),
        logger: talker,
      );
      addTearDown(host.stopAll);

      await expectLater(
        host.start(BuiltinEmulatorKind.fiscalOperator),
        throwsA(isA<BuiltinEmulatorRefused>()),
      );
      expect(
        [
          for (final e in talker.history) e.displayMessage,
        ].where((l) => l.contains('не поднят')),
        isNotEmpty,
        reason:
            'попытка включить эмулятор ОФД на боевой кассе — сама по себе '
            'событие: она означает, что кто-то этого хотел',
      );
    });

    test('встроенный эмулятор ОФД не подменяет провайдера продукта', () async {
      // Тот же довод, что у принтера строкой выше: точка подстановки — сеть.
      // Здесь это доказывается делом, а не сравнением имён классов: до
      // эмулятора доходит НАСТОЯЩИЙ `WebKassaProvider` с настоящим
      // `WebKassaApiClient` и настоящим сокетом, и токен он получает своим
      // разбором ответа.
      final host = hostFor(
        FiscalSettings(operatorType: FiscalOperatorType.webkassa),
      );
      addTearDown(host.stopAll);
      final address = await host.start(BuiltinEmulatorKind.fiscalOperator);

      final settings = FiscalSettings(
        operatorType: FiscalOperatorType.webkassa,
        testMode: true,
        baseUrl: address.baseUrl,
        login: BuiltinEmulatorHost.fiscalLogin,
        password: BuiltinEmulatorHost.fiscalPassword,
        cashboxUniqueNumber: BuiltinEmulatorHost.fiscalCashbox,
        // Продуктовый `validateConfig` требует ключ интегратора и без него не
        // выходит в сеть вовсе. Эмулятор ключ не проверяет — проверяет его
        // наша касса, и это ровно то, ради чего здесь продуктовый провайдер.
        apiKey: BuiltinEmulatorHost.fiscalApiKey,
      );
      final logger = Talker(settings: TalkerSettings(enabled: false));
      final provider = WebKassaProvider(
        settings: settings,
        logger: logger,
        client: WebKassaApiClient(
          baseUrl: settings.baseUrl!,
          apiKey: settings.apiKey,
          logger: logger,
        ),
      );
      addTearDown(provider.dispose);

      // `HttpOverrides.runZoned` с настоящим клиентом — не украшение.
      // Измерено 2026-09-19: под `TestWidgetsFlutterBinding` глобально
      // подменён `HttpClient`, и он отвечает **HTTP 400 на всё**, не выходя
      // в сеть. Проба без этой обёртки падала с «Некорректный ответ WebKassa
      // (HTTP 400)» при исправном эмуляторе — то есть мерила подмену
      // испытательного стенда, а не продукт. Тот же эмулятор из файла без
      // виджет-привязки отвечал токеном.
      final auth = await HttpOverrides.runWithHttpOverrides(
        () => provider.authorize(settings),
        _RealHttpClient(),
      );
      expect(
        auth.success,
        isTrue,
        reason:
            'если сюда не доходит продуктовый провайдер, «работает на '
            'эмуляторе» перестаёт говорить что-либо о работе с оператором: '
            'из проверки выпадают конверт, карта кодов и очередь',
      );
    });
  });
}
