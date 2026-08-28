@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';

/// Проверяет две вещи, каждая из которых уже один раз обманула проект.
///
/// Первая: покрыта ли кириллица всех пяти поддерживаемых языков. Казахские
/// `әғқңөұүһі` и киргизские `ңөү` есть не в каждой гарнитуре, а «тофу»-квадрат
/// на экране кассы в Казахстане — не косметика.
///
/// Вторая: различимы ли 400, 500 и 700. До 2026-08-03 семейство `Roboto` в
/// pubspec было набором файлов DejaVu Sans с двумя начертаниями, а голден-конфиг
/// подставлял Arial, причём medium и bold брал из одного файла. Три веса были
/// неразличимы по построению, и именно поэтому никто не замечал, что половина
/// темы просит начертание, которого нет.
void main() {
  testWidgets('Roboto покрывает кириллицу и различает три веса', (
    tester,
  ) async {
    await GoldenTestHelpers.matchGoldenMobile(
      tester,
      const _FontSpecimen(),
      'font_coverage',
    );
  });
}

class _FontSpecimen extends StatelessWidget {
  const _FontSpecimen();

  static const _alphabets = <String, String>{
    'Казахский': 'ӘҒҚҢӨҰҮҺІ әғқңөұүһі',
    'Киргизский': 'ҢӨҮ ңөү',
    'Узбекский': 'ЎҚҒҲ ўқғҳ',
    'Русский': 'ЁЙЪЫЬЭЮЯ ёйъыьэюя',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final entry in _alphabets.entries) ...[
              Text(
                entry.key,
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 11),
              ),
              Text(
                entry.value,
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 20),
              ),
              const SizedBox(height: 10),
            ],
            // Валютные символы всех поддерживаемых стран — ровно те строки,
            // что лежат в CountryCode.currencySymbol. Тенге в Roboto нет и
            // никогда не было; он дописан в шрифт скриптом
            // tools/add_tenge_to_roboto.py, и если шрифт заменят, не прогнав
            // скрипт, тофу-квадрат появится здесь.
            const Text(
              'Валюты: ₸  ₽  сом  сўм  \$  TMT',
              style: TextStyle(fontFamily: 'Roboto', fontSize: 20),
            ),
            const SizedBox(height: 12),
            // Одна и та же строка тремя весами: если они совпадут пиксель в
            // пиксель, начертания не подхватились.
            for (final weight in [
              FontWeight.w400,
              FontWeight.w500,
              FontWeight.w700,
            ])
              Text(
                'Сумма 1 234 567,89 ₸  ${weight.value}',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: weight,
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Штрихкод 4870204012345',
              style: TextStyle(fontFamily: 'TeleposMono', fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
