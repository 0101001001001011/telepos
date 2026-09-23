/// Мастер спрашивает про тот налог, который есть в стране.
///
/// # Что измерено
///
/// Пробный проход мастера 2026-09-21: американскому магазину третьим шагом
/// задавался вопрос «Плательщик НДС?» — «НДС не применяется», «НДС будет
/// показан на чеках». В США НДС нет вовсе.
///
/// Заказчик предупреждал об этом до съёмки: «про VAT к примеру не во всех
/// штатах они на ценниках это печатают».
///
/// # Проверяется свойство, а не список стран
///
/// Слова разводятся по `TaxTreatment`, и проба ходит по НАСТОЯЩЕМУ
/// `CountryCode.values`: добавят страну с налогом сверх цены — она попадёт
/// под проверку сама.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/tax_step_words.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  List<String> allWords(TaxStepWords w) => [
    w.stepTitle,
    w.payerTitle,
    w.payerSubtitle,
    w.payerDescription,
    w.nonPayerTitle,
    w.nonPayerSubtitle,
    w.nonPayerDescription,
  ];

  test('там, где налог сверх цены, слова «НДС» нет нигде', () {
    for (final country in CountryCode.values) {
      if (country.taxTreatment != TaxTreatment.exclusive) continue;

      final words = allWords(TaxStepWords.of(country, en));
      final offenders = words
          .where((w) => w.toLowerCase().contains('vat'))
          .toList();

      expect(
        offenders,
        isEmpty,
        reason:
            '${country.name}: уклад «налог сверх цены», а мастер говорит про '
            'НДС:\n${offenders.join('\n')}',
      );
      expect(
        words.any((w) => w.toLowerCase().contains('sales tax')),
        isTrue,
        reason:
            '${country.name}: про налог с продаж не сказано ни слова — '
            'значит слова просто убрали, а не заменили',
      );
    }
  });

  test('там, где налог в цене, шаг остался про НДС', () {
    // Обратная сторона: правка не имеет права сменить вопрос кассам СНГ и
    // ЕС, где НДС — настоящее понятие и стоит в законе.
    for (final country in CountryCode.values) {
      if (country.taxTreatment == TaxTreatment.exclusive) continue;

      final words = allWords(TaxStepWords.of(country, en));
      expect(
        words.any((w) => w.toLowerCase().contains('vat')),
        isTrue,
        reason: '${country.name}: уклад «налог в цене», а про НДС ни слова',
      );
    }
  });

  test('у страны с налогом сверх цены ставка НЕ называется числом', () {
    // В США она складывается из долей штата, округа, города и спецрайонов
    // и зависит от категории товара. Любое одно число здесь — неправда.
    final us = TaxStepWords.of(CountryCode.usd, en);
    expect(
      allWords(us).any((w) => RegExp(r'\d+\s*%').hasMatch(w)),
      isFalse,
      reason:
          'мастер назвал ставку числом там, где она складывается из долей — '
          'покупатель увидит на чеке другое',
    );
  });

  test('страна не выбрана — мастер выглядит как прежде', () {
    final none = TaxStepWords.of(null, en);
    expect(
      none.stepTitle,
      en.setupStepVat,
      reason:
          'до выбора страны менять вопрос незачем: так мастер выглядел '
          'всегда, и лишнее движение на первом экране только пугает',
    );
  });

  test('во всех пяти языках слова непусты', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final country in CountryCode.values) {
        for (final word in allWords(TaxStepWords.of(country, l10n))) {
          expect(
            word.trim(),
            isNotEmpty,
            reason: '${locale.languageCode}/${country.name}: пустое слово',
          );
        }
      }
    }
  });
}
