/// Окно покупателя не тянется к настройкам кассы.
///
/// # Что измерено 2026-09-22
///
/// Окно покупателя живёт в ОТДЕЛЬНОМ движке (`desktop_multi_window`): у него
/// свой `ProviderContainer`, без подмен, и пустой `GetIt`. Значит
/// `sharedPreferencesProvider` там бросает по объявлению, а `localeProvider`
/// тянет его первой же строкой.
///
/// Первая правка локализации так и сделала — позвала `localeProvider` — и
/// уронила бы окно покупателя на первом кадре. Проба этого не увидела,
/// потому что рисовала `CustomerDisplayView` напрямую: экран, а не ОКНО.
/// Среда была добрее продукта.
///
/// Всё, что окно знает о мире — язык, валюту, имя магазина, — оно получает
/// проводом. Этот сторож читает исходник окна и не зависит от того, дошла ли
/// до него какая-нибудь проба.
library;

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/presentation/screens/customer_display/customer_display_data.dart';

void main() {
  final window = File(
    'lib/presentation/screens/customer_display/customer_display_window.dart',
  );

  /// Имена, которых во втором движке НЕТ, и довод для каждого.
  const forbidden = <String, String>{
    'localeProvider':
        'тянет sharedPreferencesProvider, а тот объявлен бросающим, пока его '
        'не подменят в ProviderScope — в окне его подменять некому',
    'sharedPreferencesProvider':
        'объявлен бросающим до подмены; в окне подмены нет',
    'GetIt':
        'граф служб собирается точкой входа кассы; во втором движке он пуст',
    'AppDatabase': 'базы кассы у окна нет и быть не должно',
  };

  test('сторож смотрит не в пустоту: окно на месте', () {
    expect(window.existsSync(), isTrue, reason: 'файл окна не найден');
    expect(
      window.readAsStringSync(),
      contains('runCustomerDisplayWindow'),
      reason: 'это не тот файл',
    );
  });

  test('окно не зовёт ничего, чего во втором движке нет', () {
    final lines = window.readAsLinesSync();
    final offenders = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//')) continue;
      for (final entry in forbidden.entries) {
        if (!line.contains(entry.key)) continue;
        offenders.add('строка ${i + 1}: «${entry.key}» — ${entry.value}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'окно покупателя упадёт на первом кадре, и ни одна проба, рисующая '
          'ЭКРАН, этого не покажет:\n${offenders.join('\n')}',
    );
  });

  test('язык и валюта едут проводом', () {
    final text = window.readAsStringSync();
    expect(
      text,
      contains("args['languageCode']"),
      reason: 'окно не читает язык из доводов — говорить с покупателем нечем',
    );
    expect(
      text,
      contains("args['currencySymbol']"),
      reason: 'окно не читает валюту из доводов — деньги будут без знака',
    );
  });

  test('провод везёт валюту и язык, а не теряет их', () {
    // Круговой оборот здесь же, рядом со сторожем: поле, выпавшее из
    // `toJson`, вернулось бы пустым, и окно молча показало бы голые числа.
    final data = CustomerDisplayData(
      total: Decimal.fromInt(7),
      currencySymbol: r'$',
      languageCode: 'en',
    );
    final back = CustomerDisplayData.fromJson(data.toJson());
    expect(back.currencySymbol, r'$');
    expect(back.languageCode, 'en');
  });

  test('знака валюты нет — число печатается голым', () {
    final data = CustomerDisplayData(total: Decimal.fromInt(7));
    expect(data.money(Decimal.fromInt(7)), '7');
    expect(data.money(Decimal.fromInt(7)), isNot(contains('₸')));
  });
}
