/// Слова налогового шага мастера — по укладу страны, а не по её названию.
///
/// # Что измерено
///
/// Пробный проход мастера 2026-09-21: американскому магазину третьим шагом
/// задавался вопрос «Плательщик НДС?» с вариантами «НДС не применяется» и
/// пояснением «НДС будет показан на чеках». В США НДС нет вовсе — там налог
/// с продаж, и он устроен иначе: добавляется сверх ценника и складывается
/// из долей юрисдикций.
///
/// Заказчик говорил об этом ещё 2026-09-21, до съёмки: «про VAT к примеру
/// не во всех штатах они на ценниках это печатают».
///
/// # Разводится по УКЛАДУ, а не по списку стран
///
/// `TaxTreatment.exclusive` — налог сверх цены, и это ровно то свойство,
/// из-за которого слова другие. Список стран пришлось бы дополнять при
/// каждой новой, а уклад у неё уже объявлен.
library;

import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Слова налогового шага для страны.
class TaxStepWords {
  const TaxStepWords({
    required this.stepTitle,
    required this.payerTitle,
    required this.payerSubtitle,
    required this.payerDescription,
    required this.nonPayerTitle,
    required this.nonPayerSubtitle,
    required this.nonPayerDescription,
  });

  /// Слова для страны. `null` — страна ещё не выбрана, берётся НДС: так
  /// мастер выглядел всегда, и менять его до выбора незачем.
  ///
  /// # Откуда ставка
  ///
  /// [standardRatePercent] приходит из НАБОРА страны
  /// (`assets/tax_presets/*.json`), а не из перечисления. Здесь стояло
  /// `country.vatRate` — число, зашитое в код: поменяй закон ставку, и
  /// мастер называл бы старую, пока не выйдет сборка.
  ///
  /// Не задана — мастер честно говорит, что ставку назовёт настройка.
  /// Назвать наугад хуже, чем не назвать: цифру в мастере читают как
  /// обещание.
  factory TaxStepWords.of(
    CountryCode? country,
    AppLocalizations l10n, {
    String? standardRatePercent,
  }) {
    final salesTax = country?.taxTreatment == TaxTreatment.exclusive;
    if (!salesTax) {
      final rate = standardRatePercent;
      return TaxStepWords(
        stepTitle: l10n.setupStepVat,
        payerTitle: l10n.setupVatPayerTitle,
        payerSubtitle: (rate != null && rate.isNotEmpty)
            ? l10n.setupVatPayerRate(rate)
            : l10n.setupVatPayerRateUnknown,
        payerDescription: l10n.setupVatPayerDescription,
        nonPayerTitle: l10n.setupVatNonPayerTitle,
        nonPayerSubtitle: l10n.setupVatNonPayerSubtitle,
        nonPayerDescription: l10n.setupVatNonPayerDescription,
      );
    }

    return TaxStepWords(
      stepTitle: l10n.setupStepSalesTax,
      payerTitle: l10n.setupSalesTaxPayerTitle,
      // Ставки здесь не называются НИ ОДНОЙ цифрой намеренно: в США она
      // складывается из долей штата, округа, города и спецрайонов и зависит
      // от категории товара. Любое одно число тут было бы неправдой.
      payerSubtitle: l10n.setupSalesTaxPayerSubtitle,
      payerDescription: l10n.setupSalesTaxPayerDescription,
      nonPayerTitle: l10n.setupSalesTaxNonPayerTitle,
      nonPayerSubtitle: l10n.setupSalesTaxNonPayerSubtitle,
      nonPayerDescription: l10n.setupSalesTaxNonPayerDescription,
    );
  }

  final String stepTitle;
  final String payerTitle;
  final String payerSubtitle;
  final String payerDescription;
  final String nonPayerTitle;
  final String nonPayerSubtitle;
  final String nonPayerDescription;
}
