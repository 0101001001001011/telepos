import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';

/// Страна этой кассы — одним местом на всю презентацию.
///
/// # Зачем
///
/// 2026-09-22 выяснилось, что страну у кассы не спрашивал почти никто.
/// Четыре казахстанские государственные системы — ЭСФ, СНТ, ЕСУТД, ИС МПТ —
/// и вкладка отчётов с формами 910 и 300 стояли в меню на кассе ЛЮБОЙ
/// страны: владелец магазина в США, Германии или Корее видел пять входов в
/// казахстанский документооборот.
///
/// # Почему через `StartupStateRepository`, а не из базы
///
/// Тем же путём, что номиналы купюр (`billDenominationsProvider`): договор
/// работает и в браузере, у которого базы нет. Спрашивать `AppDatabase`
/// напрямую значило бы закрыть эти экраны для браузерного терминала.
///
/// Отказ даёт Казахстан умолчанием, а не пустоту: касса, которую ещё не
/// настроили, ведёт себя как прежде, а не теряет половину меню.
final tillCountryProvider = FutureProvider<CountryCode>((ref) async {
  try {
    final setup = await GetIt.I<StartupStateRepository>().watch().first;
    return countryOf(setup.countryCode);
  } on Object catch (e) {
    talker.warning('Country unavailable, default KZ: $e');
    return countryOf(null);
  }
});

/// Страна по её номеру в базе; `null` и мусор читаются как Казахстан.
CountryCode countryOf(int? index) =>
    (index != null && index >= 0 && index < CountryCode.values.length)
    ? CountryCode.values[index]
    : CountryCode.kzt;
