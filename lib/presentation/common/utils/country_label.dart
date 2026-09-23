/// Названия стран и валют — на языке интерфейса.
///
/// # Почему не в самом перечислении
///
/// `CountryCode` живёт в `lib/core` и языка интерфейса не знает. До этой
/// правки оно везло готовые русские слова, и первый же экран мастера
/// показывал иностранцу «Казахстан · Казахстанский тенге», «США»,
/// «Туркменистан» — по-русски, на английском интерфейсе. Измерено пробным
/// проходом мастера 2026-09-21.
///
/// Поле `countryNameEn` в перечислении при этом БЫЛО и не звалось ниоткуда:
/// кто-то это предвидел, но до экрана оно не доехало.
///
/// Здесь по **устойчивому значению перечисления** выбирается ключ словаря —
/// тем же приёмом, что у названий моделей устройств
/// (`device_profile_label.dart`). Идентификатор менять нельзя, слово рядом
/// с ним — можно и нужно.
library;

import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Название страны на языке интерфейса.
String countryTitle(CountryCode country, AppLocalizations l10n) =>
    switch (country) {
      CountryCode.kzt => l10n.countryKz,
      CountryCode.rub => l10n.countryRu,
      CountryCode.kgs => l10n.countryKg,
      CountryCode.uzs => l10n.countryUz,
      CountryCode.usd => l10n.countryUs,
      CountryCode.tmt => l10n.countryTm,
      CountryCode.deu => l10n.countryDeu,
      CountryCode.fra => l10n.countryFra,
      CountryCode.esp => l10n.countryEsp,
      CountryCode.ita => l10n.countryIta,
      CountryCode.gbr => l10n.countryGbr,
      CountryCode.pol => l10n.countryPol,
      CountryCode.tur => l10n.countryTur,
      CountryCode.chn => l10n.countryChn,
      CountryCode.jpn => l10n.countryJpn,
      CountryCode.kor => l10n.countryKor,
      CountryCode.are => l10n.countryAre,
      CountryCode.sau => l10n.countrySau,
      CountryCode.ind => l10n.countryInd,
      CountryCode.can => l10n.countryCan,
      CountryCode.aus => l10n.countryAus,
    };

/// Название валюты страны на языке интерфейса.
String currencyTitle(CountryCode country, AppLocalizations l10n) =>
    switch (country) {
      CountryCode.kzt => l10n.currencyKzt,
      CountryCode.rub => l10n.currencyRub,
      CountryCode.kgs => l10n.currencyKgs,
      CountryCode.uzs => l10n.currencyUzs,
      CountryCode.usd => l10n.currencyUsd,
      CountryCode.tmt => l10n.currencyTmt,
      CountryCode.deu => l10n.currencyDeu,
      CountryCode.fra => l10n.currencyFra,
      CountryCode.esp => l10n.currencyEsp,
      CountryCode.ita => l10n.currencyIta,
      CountryCode.gbr => l10n.currencyGbr,
      CountryCode.pol => l10n.currencyPol,
      CountryCode.tur => l10n.currencyTur,
      CountryCode.chn => l10n.currencyChn,
      CountryCode.jpn => l10n.currencyJpn,
      CountryCode.kor => l10n.currencyKor,
      CountryCode.are => l10n.currencyAre,
      CountryCode.sau => l10n.currencySau,
      CountryCode.ind => l10n.currencyInd,
      CountryCode.can => l10n.currencyCan,
      CountryCode.aus => l10n.currencyAus,
    };
