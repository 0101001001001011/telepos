/// Каталог поставляемых налоговых пресетов и трёхуровневый выбор по нему.
///
/// # Зачем три уровня
///
/// Решение заказчика 2026-09-21: «надо дробно для США и подобных: при
/// выборе становятся доступны штат и город».
///
/// Дробность не украшение. Налог в США задаётся городом, и список из всех
/// городов мира в одном выпадающем поле неработоспособен: пресетов для
/// одних только штатов с самоуправлением — тысячи.
///
/// # Читается манифест, а не список в коде
///
/// Файлы перечисляет `AssetManifest`. Держать их список в коде значило бы
/// завести второй источник правды: положили пресет в каталог — и он не
/// виден, потому что забыли строку. Ровно того, ради чего пресеты и
/// заводились, не вышло бы.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:telepos/domain/tax/tax_preset.dart';

/// Где в каталоге живут пресеты.
const String kTaxPresetsDir = 'assets/tax_presets/';

/// Поставляемые пресеты, сгруппированные для выбора.
class TaxPresetCatalog {
  const TaxPresetCatalog(this.presets);

  final List<TaxPreset> presets;

  /// Прочитанный каталог. Читается один раз за запуск.
  static Future<TaxPresetCatalog>? _cached;

  /// Читает все пресеты из пакета — **один раз за запуск**.
  ///
  /// # Почему один раз
  ///
  /// Пресеты запечены в пакет и за время работы не меняются. Перечитывать
  /// манифест и разбирать json при каждом открытии экрана — работа, у
  /// которой не может быть нового результата.
  ///
  /// # Чего эта память НЕ чинит
  ///
  /// В пробах повторное открытие экрана зависало, и сначала показалось, что
  /// причина здесь. Это было свойство способа замера: `testWidgets` гоняет
  /// тело в поддельных часах, и future, созданный в зоне одной пробы, не
  /// доставляет колбэк в зоне следующей. Своя память ровно так же попадает
  /// под это, поэтому пробам дан [resetCache]. В бою зона одна, и зависания
  /// не было никогда.
  ///
  /// Испорченный файл **роняет загрузку с именем файла**, а не пропускается.
  /// Пропустить значило бы показать пользователю список, в котором молча нет
  /// его штата, и он решил бы, что штат не поддержан.
  static Future<TaxPresetCatalog> load(AssetBundle bundle) =>
      _cached ??= _read(bundle);

  /// Забыть прочитанное. Только для проб, которые кладут свои файлы.
  @visibleForTesting
  static void resetCache() => _cached = null;

  static Future<TaxPresetCatalog> _read(AssetBundle bundle) async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final paths =
        manifest
            .listAssets()
            .where((p) => p.startsWith(kTaxPresetsDir) && p.endsWith('.json'))
            .toList()
          ..sort();

    final presets = <TaxPreset>[];
    for (final path in paths) {
      try {
        presets.add(
          TaxPreset.fromJson(
            json.decode(await bundle.loadString(path)) as Map<String, Object?>,
          ),
        );
      } on Exception catch (e) {
        throw FormatException('Пресет «$path» не читается: $e');
      }
    }
    return TaxPresetCatalog(presets);
  }

  /// Первый уровень: коды стран, по алфавиту.
  List<String> countries() =>
      (presets.map((p) => p.countryCode).toSet().toList()..sort());

  /// Второй уровень: регионы страны.
  ///
  /// Пусто — у страны один пресет на всю себя, и второй уровень показывать
  /// незачем. Так живёт Казахстан: ставка НДС одна на страну.
  List<String> regions(String countryCode) =>
      (presets
          .where((p) => p.countryCode == countryCode && p.region != null)
          .map((p) => p.region!)
          .toSet()
          .toList()
        ..sort());

  /// Третий уровень: города региона.
  List<String> cities(String countryCode, String region) =>
      (presets
          .where(
            (p) =>
                p.countryCode == countryCode &&
                p.region == region &&
                p.city != null,
          )
          .map((p) => p.city!)
          .toSet()
          .toList()
        ..sort());

  /// Пресеты, подходящие под выбор.
  ///
  /// Чем точнее выбор, тем уже список. Незаданный уровень не сужает: выбрал
  /// страну — видно всё, что в ней есть.
  List<TaxPreset> matching({
    required String countryCode,
    String? region,
    String? city,
  }) => presets
      .where(
        (p) =>
            p.countryCode == countryCode &&
            (region == null || p.region == region) &&
            (city == null || p.city == city),
      )
      .toList();

  TaxPreset? byId(String id) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}
