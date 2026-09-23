/// Каждый поставляемый налоговый пресет разбирается и даёт обещанную ставку.
///
/// # Зачем
///
/// Пресеты — файлы, которые кладут без правки кода. Значит, ошибку в них
/// некому поймать компилятором: опечатка в доле доедет до кассы и станет
/// чеком с неверным налогом.
///
/// # Читаются НАСТОЯЩИЕ файлы и считает НАСТОЯЩИЙ движок
///
/// Сторож ходит в `assets/tax_presets/`, а не разбирает выдуманный в пробе
/// json: проба на своём примере доказывала бы, что разборщик умеет читать
/// правильный пресет, — но не то, что правильны поставляемые.
///
/// Ставку он не складывает сам, а спрашивает у `resolveTax`. Сложить доли
/// в пробе значило бы повторить в ней ту самую арифметику, которую она
/// проверяет: пресет с правилом на категорию, которого движок не применит,
/// прошёл бы такую проверку насквозь.
library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/tax/tax_preset.dart';
import 'package:telepos/domain/tax/tax_resolution.dart';

void main() {
  final dir = Directory('assets/tax_presets');

  List<File> presetFiles() => dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  Map<String, Object?> read(File f) =>
      json.decode(f.readAsStringSync()) as Map<String, Object?>;

  test('пресеты вообще есть — сторож смотрит не в пустоту', () {
    expect(
      dir.existsSync(),
      isTrue,
      reason: 'каталог пресетов исчез; сторож без файлов зелен всегда',
    );
    expect(presetFiles(), isNotEmpty, reason: 'ни одного пресета');
  });

  test('движок выводит из пресета ровно обещанную ставку', () {
    for (final file in presetFiles()) {
      final preset = TaxPreset.fromJson(read(file));
      final resolved = preset.resolveFor(null);

      expect(
        resolved.totalRatePercent,
        preset.expectedStandardRatePercent,
        reason:
            '${file.path}: пресет обещает '
            '${preset.expectedStandardRatePercent}%, а движок выводит из '
            'него ${resolved.totalRatePercent}%. Обещание сверяют с '
            'источником глазами; расхождение здесь значит, что в дереве '
            'юрисдикций ошибка',
      );
    }
  });

  test('каждый пресет назван источником и датой', () {
    for (final file in presetFiles()) {
      final preset = TaxPreset.fromJson(read(file));
      expect(
        preset.source,
        isNotEmpty,
        reason:
            '${file.path}: без ссылки на источник пресет непроверяем — '
            'непонятно, устарел он или нет и где смотреть правду',
      );
      expect(
        preset.validFrom,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
        reason:
            '${file.path}: дата начала действия обязана быть в виде '
            'ГГГГ-ММ-ДД. Ставки меняются по датам — в Колорадо дважды в год',
      );
    }
  });

  test('идентификаторы пресетов не повторяются', () {
    final ids = presetFiles().map((f) => read(f)['id']).toList();
    expect(
      ids.toSet(),
      hasLength(ids.length),
      reason: 'два пресета с одним id — второй молча заменит первый',
    );
  });

  test('иерархия для выбора: страна → штат → город', () {
    final denver = TaxPreset.fromJson(
      read(File('assets/tax_presets/us-co-denver.json')),
    );
    expect(denver.countryCode, 'US');
    expect(
      denver.region,
      'CO',
      reason:
          'без штата пресет не встанет во второй уровень выбора, и '
          'пользователю придётся искать Денвер среди всех городов мира',
    );
    expect(denver.city, 'Denver');
  });

  test('Денвер: еда для дома облагается городом, но не штатом', () {
    final denver = TaxPreset.fromJson(
      read(File('assets/tax_presets/us-co-denver.json')),
    );
    final food = denver.resolveFor('food-home');

    expect(
      food.totalRatePercent,
      Decimal.parse('6.25'),
      reason:
          'штат освободил еду, город и спецрайоны — нет; это и есть '
          'самоуправление, ради которого вся модель переделана',
    );
    expect(
      food.shares.map((s) => s.name),
      isNot(contains('CO State')),
      reason: 'штат не облагает вовсе — печатать его нулём значит соврать',
    );
  });

  group('разборщик отказывает на плохом пресете', () {
    Map<String, Object?> good() => {
      'id': 'probe',
      'title': 'Probe',
      'countryCode': 'US',
      'taxTreatment': 'exclusive',
      'hasFiscalisation': false,
      'currencySymbol': r'$',
      'currencyBeforeAmount': true,
      'expectedStandardRatePercent': '9.15',
      'categories': [
        {'code': 'standard', 'title': 'Standard', 'isDefault': true},
      ],
      'jurisdictions': [
        {
          'code': 'state',
          'name': 'State',
          'level': 1,
          'parent': null,
          'rules': [
            {'category': null, 'kind': 'taxed', 'ratePercent': '2.90'},
          ],
        },
        {
          'code': 'city',
          'name': 'City',
          'level': 3,
          'parent': 'state',
          'tillLocation': true,
          'rules': [
            {'category': null, 'kind': 'taxed', 'ratePercent': '6.25'},
          ],
        },
      ],
      'validFrom': '2026-01-01',
      'source': 'проба',
    };

    test('сам образец исправен — иначе отказы ничего не доказывают', () {
      final preset = TaxPreset.fromJson(good());
      expect(
        preset.resolveFor(null).totalRatePercent,
        Decimal.parse('9.15'),
      );
    });

    test('ставка числом, а не строкой', () {
      // Числа JSON — двоичные double. Разрешить их значит внести потерю
      // точности в ставку налога.
      final bad = good();
      (bad['jurisdictions']! as List).first as Map<String, Object?>
        ..['rules'] = [
          {'category': null, 'kind': 'taxed', 'ratePercent': 2.90},
        ];
      expect(() => TaxPreset.fromJson(bad), throwsFormatException);
    });

    test('правило ссылается на несуществующую категорию', () {
      final bad = good();
      ((bad['jurisdictions']! as List).first as Map<String, Object?>)['rules'] =
          [
            {'category': 'food-home', 'kind': 'exempt', 'ratePercent': '0'},
          ];
      expect(
        () => TaxPreset.fromJson(bad),
        throwsFormatException,
        reason:
            'молча пропустить значит обложить категорию по общей ставке — '
            'а заводили её ровно затем, чтобы этого не было',
      );
    });

    test('родителя нет в пресете', () {
      final bad = good();
      ((bad['jurisdictions']! as List).last
              as Map<String, Object?>)['parent'] =
          'nowhere';
      expect(() => TaxPreset.fromJson(bad), throwsFormatException);
    });

    test('ни одна юрисдикция не отмечена как место кассы', () {
      final bad = good();
      for (final j in bad['jurisdictions']! as List) {
        (j as Map<String, Object?>)['tillLocation'] = false;
      }
      expect(
        () => TaxPreset.fromJson(bad),
        throwsFormatException,
        reason: 'такой пресет заводит ставки и не применяет ни одной',
      );
    });

    test('категорий по умолчанию не одна', () {
      final bad = good()
        ..['categories'] = [
          {'code': 'a', 'title': 'A', 'isDefault': true},
          {'code': 'b', 'title': 'B', 'isDefault': true},
        ];
      expect(() => TaxPreset.fromJson(bad), throwsFormatException);
    });

    test('неизвестный вид правила', () {
      final bad = good();
      ((bad['jurisdictions']! as List).first as Map<String, Object?>)['rules'] =
          [
            {'category': null, 'kind': 'maybe', 'ratePercent': '2.90'},
          ];
      expect(() => TaxPreset.fromJson(bad), throwsFormatException);
    });

    test('неизвестный уклад', () {
      final bad = good()..['taxTreatment'] = 'whatever';
      expect(() => TaxPreset.fromJson(bad), throwsFormatException);
    });

    test('нет источника', () {
      final bad = good()..remove('source');
      expect(() => TaxPreset.fromJson(bad), throwsFormatException);
    });

    test('противоречивое правило: освобождено по ненулевой ставке', () {
      final bad = good();
      ((bad['jurisdictions']! as List).first as Map<String, Object?>)['rules'] =
          [
            {'category': null, 'kind': 'exempt', 'ratePercent': '2.90'},
          ];
      expect(
        () => TaxPreset.fromJson(bad),
        throwsArgumentError,
        reason: '«освобождено по ставке 2,9 %» истолковать нельзя',
      );
    });
  });

  test('вид правила по умолчанию — обложение, а не освобождение', () {
    // Умолчание выбрано в сторону «облагается»: пропущенное поле не должно
    // молча выводить товар из налоговой базы.
    final rule = TaxPreset.fromJson({
      'id': 'p',
      'title': 'P',
      'countryCode': 'US',
      'taxTreatment': 'exclusive',
      'currencySymbol': r'$',
      'expectedStandardRatePercent': '5',
      'categories': <Object?>[],
      'jurisdictions': [
        {
          'code': 'c',
          'name': 'C',
          'level': 0,
          'parent': null,
          'tillLocation': true,
          'rules': [
            {'category': null, 'ratePercent': '5'},
          ],
        },
      ],
      'validFrom': '2026-01-01',
      'source': 'проба',
    }).jurisdictions.first.rules.first;

    expect(rule.kind, TaxRuleKind.taxed);
  });
}
