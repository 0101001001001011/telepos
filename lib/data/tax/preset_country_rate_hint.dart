import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:telepos/data/tax/tax_preset_catalog.dart';
import 'package:telepos/domain/tax/country_rate_hint.dart';

/// Подсказка ставки — из поставляемых наборов.
class PresetCountryRateHint implements CountryRateHint {
  const PresetCountryRateHint({AssetBundle? bundle}) : _bundle = bundle;

  final AssetBundle? _bundle;

  @override
  Future<String?> standardRatePercent(String isoCode) async {
    try {
      final catalog = await TaxPresetCatalog.load(_bundle ?? rootBundle);
      final matching = catalog.matching(countryCode: isoCode);
      // Ровно один набор на страну. Несколько — это города США, и общей
      // ставки там нет: назвать одну из них значило бы назвать чужую.
      if (matching.length != 1) return null;
      return matching.single.expectedStandardRatePercent?.toString();
    } on Object catch (_) {
      return null;
    }
  }
}
