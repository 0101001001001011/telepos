@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/domain/esf/esf_provider_registry.dart';
import 'package:telepos/domain/esf/esf_settings.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_provider.dart';
import 'package:telepos/domain/ismpt/ismpt_provider_registry.dart';
import 'package:telepos/domain/snt/snt_provider_registry.dart';
import 'package:telepos/domain/snt/snt_settings.dart';

import '../e2e/support/harness.dart';

/// # Сторож реестров внешних поставщиков
///
/// Задача 4 плана `2026-09-07-sale-completeness.md`.
///
/// ## Почему реестры, а не список контрактов
///
/// Список контрактов пишется рукой, и новый контракт, в него не внесённый,
/// оставит сторожа зелёным навсегда. Поэтому проверяется **множество**:
/// перечисление реестра обходится целиком, и каждое его значение обязано либо
/// иметь строителя, либо — если это нулевое значение, «интеграции нет» —
/// отвечать отказом (`Refusing*`), а не молчаливой заглушкой.
///
/// Сам список реестров тоже пишется рукой ([_expectedRegistryClasses]) — и
/// именно поэтому он сверяется с деревом: проба «реестры в дереве совпадают со списком сторожа» находит
/// реестры **по устройству класса** (карта `_builders` плюс `resolve`), а не по
/// имени файла, и требует, чтобы найденное совпало со списком. Пятый реестр,
/// заведённый и не внесённый сюда, красит сторожа, а не проходит мимо него.
///
/// Измерено 2026-09-07: обход читает **4 реестра, 10 значений перечислений,
/// 6 строителей**. Числа здесь ради того, чтобы обвал обхода был виден глазом:
/// сторож, у которого их станет вдвое меньше, всё равно останется зелёным по
/// каждому отдельному условию.
///
/// ## Чего сторож НЕ доказывает
///
/// Он не доказывает, что **эмулятор существует**. Эмулятор — это адрес
/// (`baseUrl` в настройках), а не класс, и из исходника не виден: реестр знает
/// только, что для `webkassa` есть строитель, но не знает, на какой сервер тот
/// пойдёт. Третья реализация — то, что по адресу кто-то отвечает, — проверяется
/// сторожем эмулятора (задача 1) и таблицей достижимости (задача 20).
///
/// Он не доказывает и того, что строитель отдаёт **работающего** поставщика:
/// проверяется тип возврата, а не поведение. Поведение — предмет задач яруса 2.
///
/// Он обходит граф **кассы** (`configureDependencies`), а не браузерного
/// терминала: в `lib/web/main_web.dart` этих реестров нет вовсе и быть не
/// должно — фискализация живёт на кассе, а терминал спрашивает её по проводу.
/// Измерено: `grep ProviderRegistry lib/web/main_web.dart` не находит ничего.
///
/// ## Две известные подделки, от которых сторож защищён
///
/// 1. **Пустой обход даёт пустой список нарушителей.** Сторож, ничего не
///    нашедший, зелен по недосмотру. Поэтому всё прочитанное считается, и
///    каждый счёт обязан быть больше нуля: реестры, значения, строители.
///    Само лекарство проверено: проба «проверка краснеет на пустом реестре» прогоняет ту же
///    проверяющую функцию по **пустому** реестру и требует, чтобы она бросила.
/// 2. **Образец не ловит то, что ищет.** Разбор устройства класса —
///    поиск по тексту, а такой поиск умеет молча не находить ничего.
///    Поэтому проба «реестры в дереве совпадают со списком сторожа» сверяет найденное с точным
///    множеством, а не только с «не пусто».
const _expectedRegistryClasses = <String>{
  'FiscalProviderRegistry',
  'EsfProviderRegistry',
  'IsMptProviderRegistry',
  'SntProviderRegistry',
};

/// Один реестр глазами сторожа.
///
/// [zero] — значение «интеграции нет». Оно единственное, для которого
/// отсутствие строителя законно, и ровно поэтому для него проверяется не
/// наличие строителя, а **тип ответа**: касса обязана отказать вслух, а не
/// вернуть заглушку, печатающую «фискализовано».
typedef _RegistryUnderGuard = ({
  String className,
  List<Enum> values,
  Enum zero,
  bool Function(Enum value) isRegistered,
  Object Function(Enum value) resolve,
});

/// Читает реестры из **собранного графа** (`configureDependencies`), а не из
/// собранных руками экземпляров: строки `..register(...)` живут в
/// `service_locator.dart`, и сторож обязан видеть именно их. Реестр, собранный
/// в тесте, проверял бы тест.
List<_RegistryUnderGuard> _registriesFromGraph() {
  final fiscal = GetIt.I<FiscalProviderRegistry>();
  final esf = GetIt.I<EsfProviderRegistry>();
  final ismpt = GetIt.I<IsMptProviderRegistry>();
  final snt = GetIt.I<SntProviderRegistry>();
  return [
    (
      className: 'FiscalProviderRegistry',
      values: FiscalOperatorType.values,
      zero: FiscalOperatorType.none,
      isRegistered: (v) => fiscal.isRegistered(v as FiscalOperatorType),
      resolve: (v) =>
          fiscal.resolve(FiscalSettings(operatorType: v as FiscalOperatorType)),
    ),
    (
      className: 'EsfProviderRegistry',
      values: EsfOperatorType.values,
      zero: EsfOperatorType.none,
      isRegistered: (v) => esf.isRegistered(v as EsfOperatorType),
      // `enabled: true` намеренно: без него `isEnabled` ложен для любого
      // значения, и отказ приходил бы от выключателя, а не от нулевого
      // значения — сторож проверял бы не то, что написано.
      resolve: (v) => esf.resolve(
        EsfSettings(operatorType: v as EsfOperatorType, enabled: true),
      ),
    ),
    (
      className: 'IsMptProviderRegistry',
      values: IsMptBackend.values,
      zero: IsMptBackend.none,
      isRegistered: (v) => ismpt.isRegistered(v as IsMptBackend),
      resolve: (v) => ismpt.resolve(v as IsMptBackend),
    ),
    (
      className: 'SntProviderRegistry',
      values: SntProviderType.values,
      zero: SntProviderType.none,
      isRegistered: (v) => snt.isRegistered(v as SntProviderType),
      // `enabled: true` — по той же причине, что и у ЭСФ: `isActive`
      // складывается из выключателя и типа, и без этого отказ приходил бы от
      // выключателя.
      resolve: (v) => snt.resolve(
        SntSettings(providerType: v as SntProviderType, enabled: true),
      ),
    ),
  ];
}

/// Счёт того, что сторож фактически прочитал. Пустой обход обязан быть виден.
class _Tally {
  int registries = 0;
  int values = 0;
  int builders = 0;
}

/// Проверка одного реестра. Вынесена отдельно, чтобы её саму можно было
/// проверить на подделке (проба «проверка краснеет на пустом реестре»): проверяющая функция,
/// которую никто не заставлял краснеть, — такое же обещание, как и любое
/// другое.
void _checkRegistry(_RegistryUnderGuard r, _Tally tally) {
  tally.registries++;

  final registered = r.values.where(r.isRegistered).toList();
  expect(
    registered,
    isNotEmpty,
    reason:
        '${r.className}: ни одного строителя — пустое множество проходит '
        'любую проверку молча',
  );
  tally.builders += registered.length;

  for (final value in r.values) {
    tally.values++;
    final where = '${r.className}.${value.name}';
    if (value == r.zero) {
      expect(
        r.isRegistered(value),
        isFalse,
        reason:
            '$where — нулевое значение со строителем: строитель мёртв '
            '(resolve отвечает отказом раньше), и его наличие — обещание, '
            'которого никто не исполняет',
      );
      expect(
        r.resolve(value).runtimeType.toString(),
        startsWith('Refusing'),
        reason:
            '$where — «интеграции нет» обязано быть отказом вслух, а не '
            'заглушкой, отвечающей «сделано»',
      );
    } else {
      expect(
        r.isRegistered(value),
        isTrue,
        reason:
            '$where — значение перечисления без строителя: на его месте молча '
            'встаёт отказ, а настройка кассы предлагает этот пункт как рабочий',
      );
      expect(
        r.resolve(value).runtimeType.toString(),
        isNot(startsWith('Refusing')),
        reason:
            '$where — строитель есть, а resolve всё равно отказывает: '
            'регистрация ничего не значит',
      );
    }
  }
}

/// Разбирает `lib/` и возвращает имена классов, устроенных как реестр:
/// карта `_builders` плюс `resolve`. Именно устройство, а не имя файла и не
/// суффикс `Registry`: `SessionRegistry`, `ChannelRegistry`, `DownloadRegistry`
/// носят то же слово в имени и реестрами поставщиков не являются.
Set<String> _registryClassesInTree() {
  final found = <String>{};
  final classDecl = RegExp(r'(?:^|\n)class\s+([A-Za-z0-9_]+)');
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final content = entity.readAsStringSync();
    if (!content.contains('_builders')) continue;
    final decls = classDecl.allMatches(content).toList();
    for (var i = 0; i < decls.length; i++) {
      final start = decls[i].start;
      final end = i + 1 < decls.length ? decls[i + 1].start : content.length;
      final body = content.substring(start, end);
      if (body.contains('_builders') && body.contains('resolve(')) {
        found.add(decls[i].group(1)!);
      }
    }
  }
  return found;
}

void main() {
  final h = E2eHarness();

  group('сторож реестров внешних поставщиков', () {
    setUp(() => h.setUp(seedData: false));
    tearDown(() => h.tearDown());

    test('каждое значение имеет строителя, нулевое отвечает отказом', () {
      final registries = _registriesFromGraph();
      final tally = _Tally();
      for (final r in registries) {
        _checkRegistry(r, tally);
      }

      // Лекарство от первой подделки: обход, ничего не прочитавший, обязан
      // краснеть, а не радовать пустым списком нарушителей.
      expect(
        tally.registries,
        greaterThan(0),
        reason: 'ни одного реестра не обойдено — сторож зелен по недосмотру',
      );
      expect(
        tally.registries,
        _expectedRegistryClasses.length,
        reason: 'обойдены не все реестры, объявленные в дереве',
      );
      expect(
        tally.values,
        greaterThan(0),
        reason: 'ни одного значения не прочитано',
      );
      expect(
        tally.builders,
        greaterThan(0),
        reason: 'ни одного строителя не найдено',
      );
      // Обход обязан быть полным: счёт значений — сумма по перечислениям.
      expect(
        tally.values,
        registries.fold<int>(0, (s, r) => s + r.values.length),
        reason: 'обойдены не все значения перечислений',
      );
    });

    test('граф отдаёт ровно те реестры, что объявлены в дереве', () {
      expect(
        _registriesFromGraph().map((r) => r.className).toSet(),
        _expectedRegistryClasses,
      );
    });
  });

  // Ниже — проверки самого сторожа. Графа не требуют.

  test('реестры в дереве совпадают со списком сторожа', () {
    final inTree = _registryClassesInTree();
    // Разбор по тексту умеет молча не находить ничего: без этой строки пустое
    // множество «совпало бы» с чем угодно, если бы сверка была нестрогой.
    expect(
      inTree,
      isNotEmpty,
      reason: 'разбор lib/ не нашёл ни одного реестра — образец не ловит',
    );
    expect(
      inTree,
      _expectedRegistryClasses,
      reason:
          'реестр, заведённый в дереве и не внесённый в _expectedRegistryClasses'
          ', остался бы без сторожа; лишнее имя — сторож охраняет то, чего нет',
    );
  });

  test('проверка краснеет на пустом реестре', () {
    final empty = FiscalProviderRegistry();
    expect(
      () => _checkRegistry((
        className: 'FiscalProviderRegistry(пустой)',
        values: FiscalOperatorType.values,
        zero: FiscalOperatorType.none,
        isRegistered: (v) => empty.isRegistered(v as FiscalOperatorType),
        resolve: (v) => empty.resolve(
          FiscalSettings(operatorType: v as FiscalOperatorType),
        ),
      ), _Tally()),
      throwsA(isA<TestFailure>()),
      reason: 'пустой реестр обязан краснеть, а не проходить молча',
    );
  });

  test('проверка краснеет на потерянной регистрации', () {
    // Ровно диверсия из плана: одна строка `..register(...)` убрана.
    final partial = FiscalProviderRegistry()
      ..register(
        FiscalOperatorType.webkassa,
        (s) => const _StubFiscalProvider(),
      );
    expect(
      () => _checkRegistry((
        className: 'FiscalProviderRegistry(без kassa24)',
        values: FiscalOperatorType.values,
        zero: FiscalOperatorType.none,
        isRegistered: (v) => partial.isRegistered(v as FiscalOperatorType),
        resolve: (v) => partial.resolve(
          FiscalSettings(operatorType: v as FiscalOperatorType),
        ),
      ), _Tally()),
      throwsA(
        isA<TestFailure>().having(
          (e) => e.message,
          'message',
          contains('directOfd'),
        ),
      ),
      reason:
          'сторож обязан не только покраснеть, но и назвать значение, '
          'оставшееся без строителя',
    );
  });
}

/// Заглушка для проверки самого сторожа: нужна только тем, что её имя **не**
/// начинается с `Refusing`, то есть выглядит как настоящий поставщик. В граф не
/// попадает. Поведение наследуется от отказывающего — оно здесь не при чём.
class _StubFiscalProvider extends RefusingFiscalProvider {
  const _StubFiscalProvider();
}
