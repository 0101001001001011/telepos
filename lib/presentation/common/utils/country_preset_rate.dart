import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/domain/tax/country_rate_hint.dart';

/// Общая ставка страны — из НАБОРА, а не из числа в коде.
///
/// # Зачем провайдер, а не поле перечисления
///
/// У `CountryCode` было поле `vatRate`. Поменяй закон ставку — и мастер
/// называл бы старую, пока не выйдет сборка; заказчик назвал это прямо
/// 2026-09-22: «вдруг завтра поменяют и сделают 18 %, и всё, работа кассы
/// встанет тогда в России».
///
/// Набор лежит файлом (`assets/tax_presets/*.json`), правится без сборки и
/// применяется в настройку, где владелец меняет его как угодно.
///
/// # Почему `null` — законный ответ
///
/// Набора может не быть (США: ставка задаётся городом), он может ещё не
/// прочитаться. Мастер тогда честно говорит, что ставку назовёт настройка.
/// Назвать наугад хуже, чем не назвать: цифру в мастере читают как обещание.
final countryStandardRateProvider =
    FutureProvider.family<String?, CountryCode?>((ref, country) async {
      if (country == null) return null;
      // Договор, а не каталог наборов: каталог живёт в слое данных, и
      // тянуть его в презентацию значит нарушить И5 и сломать браузерную
      // сборку, у которой ресурсов кассы нет вовсе. Обе беды первая
      // редакция и получила — сторожа поймали каждую.
      if (!GetIt.I.isRegistered<CountryRateHint>()) return null;
      return GetIt.I<CountryRateHint>().standardRatePercent(country.isoCode);
    });
