/// Порядок стран НЕ переставляется: в базе лежит номер, а не имя.
///
/// # Чем это грозит
///
/// `this_pos_entries.country_code` хранит **индекс** значения
/// `CountryCode.values`. Переставить значения местами — значит молча сменить
/// страну у каждой работающей кассы: валюту на чеке, уклад налога, маску
/// номера налогоплательщика и номиналы купюр. Узнает об этом покупатель.
///
/// Дописывать в КОНЕЦ можно и нужно: 2026-09-22 так добавили пятнадцать
/// стран — евро, фунт, юань, иену, вону, дирхам и прочие.
///
/// # Почему сторож, а не комментарий
///
/// Комментарий читают те, кто и так осторожен. Алфавитный порядок в
/// перечислении выглядит безобидной уборкой — и ею бы однажды и
/// оказался.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';

void main() {
  /// Первые шесть значений — те, с которыми кассы уже работают.
  ///
  /// Список закрыт намеренно: он и есть то, что нельзя трогать. Новые
  /// страны дописываются ПОСЛЕ него и сюда не добавляются.
  const frozen = ['kzt', 'rub', 'kgs', 'uzs', 'usd', 'tmt'];

  test('первые шесть стран стоят на своих местах', () {
    for (var i = 0; i < frozen.length; i++) {
      expect(
        CountryCode.values[i].name,
        frozen[i],
        reason:
            'на месте $i теперь «${CountryCode.values[i].name}» вместо '
            '«${frozen[i]}». В базе кассы лежит ИНДЕКС, и эта перестановка '
            'сменила бы страну на каждой работающей кассе: валюту на чеке, '
            'уклад налога, маску номера и номиналы купюр',
      );
    }
  });

  test('стран стало больше, а не меньше', () {
    expect(
      CountryCode.values.length,
      greaterThanOrEqualTo(frozen.length),
      reason: 'страна исчезла из перечисления — касса с её индексом упадёт',
    );
  });

  test('у каждой страны есть купюры, и они по возрастанию', () {
    for (final country in CountryCode.values) {
      expect(
        country.banknotes,
        isNotEmpty,
        reason: '${country.name}: счётчик купюр покажет пустоту',
      );
      // Порядок — по ВОЗРАСТАНИЮ, как их видят кассиры сегодня: счётчик
      // купюр и раскладка на оплате обе начинают с мелкой. Первая редакция
      // этой пробы требовала обратного, и покраснела на живом списке
      // Казахстана — правило было моей выдумкой, а не правдой экрана.
      final sorted = [...country.banknotes]..sort();
      expect(
        country.banknotes,
        sorted,
        reason:
            '${country.name}: номиналы идут не по возрастанию — колонка в '
            'смене будет прыгать',
      );
    }
  });

  test('уклад налога назван у каждой страны и бывает обоих видов', () {
    final treatments = CountryCode.values.map((c) => c.taxTreatment).toSet();
    expect(
      treatments,
      contains(TaxTreatment.exclusive),
      reason:
          'ни одной страны с налогом сверх цены — значит США и Канада '
          'потеряли свой уклад, и чек там соберётся неверно',
    );
    expect(treatments, contains(TaxTreatment.inclusive));
  });

  test('номер налогоплательщика описан непротиворечиво', () {
    for (final country in CountryCode.values) {
      expect(
        country.taxIdLength,
        greaterThan(0),
        reason: '${country.name}: длина номера не задана',
      );
      expect(
        country.taxIdHint.trim(),
        isNotEmpty,
        reason: '${country.name}: без образца человек не поймёт, что вводить',
      );

      if (country.taxIdIsNumeric) {
        final digits = country.taxIdHint.replaceAll(RegExp('[^0-9]'), '');
        expect(
          digits.length,
          country.taxIdLength,
          reason:
              '${country.name}: в образце «${country.taxIdHint}» '
              '${digits.length} цифр, а длина объявлена '
              '${country.taxIdLength}. Человек введёт по образцу и получит '
              'отказ',
        );
      } else {
        expect(
          country.taxIdHint.length,
          country.taxIdLength,
          reason:
              '${country.name}: буквенно-цифровой номер меряется целиком, и '
              'образец обязан быть той же длины',
        );
      }
    }
  });
}
