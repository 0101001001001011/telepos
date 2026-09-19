/// Запуск эмулятора фискального оператора WebKassa **из командной строки**.
///
/// # Почему сам эмулятор живёт в `lib/`, а запуск — здесь
///
/// Решение заказчика 2026-09-19: эмулятор обязан быть встроен в приложение,
/// чтобы для диагностики и проверки шаблона чека ничего не доставляли. Класс
/// [WebKassaEmulator] поэтому переехал в
/// `lib/emulators/webkassa/emulator.dart` — он часть продукта, и его поднимает
/// `BuiltinEmulatorHost` по решению оператора.
///
/// **Правило раздела при этом не нарушено.** Оно требует, чтобы точка
/// подстановки была самой дальней — **сетью**, а не интерфейсом над
/// провайдером; отдельный процесс был способом этого добиться, а не целью.
/// Эмулятор внутри приложения открывает настоящий сервер HTTP, и касса идёт к
/// нему своим `WebKassaApiClient`, своим конвертом, своим разбором ответа и
/// своей очередью.
///
/// Этот файл остаётся затем, что запуск отдельным процессом никуда не делся:
/// им пользуются живые прогоны (`--tags live`) и ручные проверки, и ни один из
/// них не изменился ни строкой. **Одна реализация, два вызывающих.**
///
/// # Чего этот запуск НЕ доказывает
///
/// Оговорки самого эмулятора перечислены там, где он живёт
/// (`lib/emulators/webkassa/emulator.dart`), и они здесь в силе целиком —
/// прежде всего та, что настоящая WebKassa о поведении этого прибора не
/// знает ничего. К ним эта дверь добавляет свою: **успешный запуск отсюда
/// ничего не говорит о встроенном выключателе** и, главное, **обходит запрет
/// на боевой кассе**. Запрет живёт на двери `BuiltinEmulatorHost.start`, а
/// командная строка в неё не стучится: она поднимает сервер сама. Это не
/// дыра, а разные пользователи — сюда ходит разработчик, а не кассир, и
/// направить кассу на этот адрес всё равно надо руками.
///
/// # Запуск
///
/// ```
/// dart run test/emulators/webkassa/emulator.dart \
///     --port 8085 --host 127.0.0.1 \
///     --cashbox SWK00000001 --reg-number 000000000001 \
///     --login emul --password emul \
///     --token-ttl 30s --vat off
/// ```
///
/// `--host 0.0.0.0` — когда касса на другой машине. TLS не нужен: сюда ходит
/// **касса**, а не страница браузера, поэтому требование защищённого
/// происхождения для `WebTransport` сюда не относится.
///
/// # Ограничение, а не пожелание
///
/// Файл запускается `dart run`, а не под `flutter_tester`, поэтому
/// **`package:flutter` здесь запрещён**. `bin/telepos_backend.dart` под
/// `dart run` уже не собирается именно потому, что через `LocalProperties`
/// притянул `dart:ui`. Сторож на это — в `emulator_test.dart`.
library;

import 'dart:io';

import 'package:telepos/emulators/webkassa/emulator.dart';
import 'package:telepos/emulators/webkassa/state.dart';

// Прежние читатели просили класс и состояние отсюда — пересылка оставлена,
// чтобы живые прогоны и стенды не менялись ни строкой.
export 'package:telepos/emulators/webkassa/emulator.dart';


Future<void> main(List<String> argv) async {
  final args = _parse(argv);
  if (args.containsKey('help')) {
    stdout.writeln(_usage);
    return;
  }

  final host = args['host'] ?? '127.0.0.1';
  final port = int.parse(args['port'] ?? '8085');
  final cashbox = args['cashbox'] ?? 'SWK00000001';
  final regNumber = args['reg-number'] ?? '000000000001';
  final ttl = _duration(args['token-ttl'] ?? '30s');
  final vat = VatMode.values.firstWhere(
    (m) => m.name == (args['vat'] ?? 'off'),
    orElse: () => VatMode.off,
  );

  final now = DateTime.now();
  final state = EmulatorState(
    cashboxes: {
      cashbox: EmulatedCashbox(
        uniqueNumber: cashbox,
        registrationNumber: regNumber,
        now: now,
      ),
    },
    login: args['login'] ?? 'emul',
    password: args['password'] ?? 'emul',
    tokenTtl: ttl,
    vat: vat,
  );

  final emulator = WebKassaEmulator(state: state);
  await emulator.start(host, port);

  final shown = host == '0.0.0.0' ? await _firstIPv4() : host;
  stdout
    ..writeln('Эмулятор WebKassa поднят.')
    ..writeln('')
    ..writeln('  Адрес сервера (вписать на экране фискальных настроек):')
    ..writeln('      http://$shown:$port')
    ..writeln('  Пульт:  http://$shown:$port/_emul/state')
    ..writeln('  Журнал: http://$shown:$port/_emul/journal')
    ..writeln('  Стоп:   curl -X POST http://$shown:$port/_emul/stop')
    ..writeln('')
    ..writeln('  Касса   $cashbox / рег. $regNumber')
    ..writeln('  Логин   ${state.login} / пароль ${state.password}')
    ..writeln('  Токен   ${ttl.inSeconds} с   НДС ${vat.name}')
    ..writeln('')
    ..writeln('  ВНИМАНИЕ. Адрес не подхватится, пока на экране фискальных')
    ..writeln(
      '  настроек не выбран оператор WebKassa: StoreFiscalSettingsSource',
    )
    ..writeln('  отдаёт настройки из prefs только при operatorType != none,')
    ..writeln(
      '  иначе падает на ThisPosFiscalSettingsSource с адресом из ThisPos.',
    )
    ..writeln(
      '  И второе: заполненное поле «локальный модуль» перебивает адрес',
    )
    ..writeln('  сервера — WebKassaProvider._baseUrl смотрит на него первым.')
    ..writeln('');

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln(
      '\nЭмулятор остановлен. Записей в журнале: '
      '${state.journal.length}.',
    );
    await emulator.stop();
    exit(0);
  });
}

const String _usage = '''
Эмулятор фискального оператора WebKassa.

  --host        127.0.0.1 | 0.0.0.0   (умолч. 127.0.0.1)
  --port        8085
  --cashbox     SWK00000001    заводской номер (CashboxUniqueNumber)
  --reg-number  000000000001   регистрационный номер
  --login       emul           верный логин; иной даёт код 1
  --password    emul           верный пароль; иной даёт код 1
  --token-ttl   30s            срок токена; истёкший даёт код 3
  --vat         off|included|added   сверять ли поле Tax
  --help
''';

Map<String, String> _parse(List<String> argv) {
  final out = <String, String>{};
  for (var i = 0; i < argv.length; i++) {
    final a = argv[i];
    if (!a.startsWith('--')) continue;
    final name = a.substring(2);
    if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
      out[name] = argv[i + 1];
      i++;
    } else {
      out[name] = 'true';
    }
  }
  return out;
}

Duration _duration(String raw) {
  final m = RegExp(r'^(\d+)(ms|s|m|h)?$').firstMatch(raw.trim());
  if (m == null) return const Duration(seconds: 30);
  final n = int.parse(m.group(1)!);
  switch (m.group(2)) {
    case 'ms':
      return Duration(milliseconds: n);
    case 'm':
      return Duration(minutes: n);
    case 'h':
      return Duration(hours: n);
    default:
      return Duration(seconds: n);
  }
}

Future<String> _firstIPv4() async {
  try {
    final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
  } catch (_) {}
  return '0.0.0.0';
}
