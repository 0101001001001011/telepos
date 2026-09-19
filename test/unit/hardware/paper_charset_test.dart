import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/hardware/paper_charset.dart';

/// Таблица знаков бумаги: полнота, обратимость и названные замены.
///
/// ## Чем эта проба краснеет
///
/// * убрать любую строку из `_cp866High`/`_cp1251High` — падает «все 128
///   позиций различны» и «туда-обратно»;
/// * перепутать две позиции местами — падает «туда-обратно» на конкретном
///   байте, с именем байта в сообщении;
/// * вернуть `₸ → 'T'` (как делал удалённый второй кодировщик) — падает
///   «тенге печатается сокращением, а не выдуманной буквой»;
/// * убрать `₸` из замен вовсе — падает «у знака тенге есть замена»;
/// * убрать казахскую букву из таблицы замен — падает список «вопросов не
///   остаётся».
///
/// ## Чего это НЕ доказывает
///
/// Ничего о том, что нарисует настоящий принтер: здесь сверяются байты и их
/// чтение, а не бумага.
void main() {
  group('CP866 — полная таблица', () {
    test('128 позиций старшей половины, все разные', () {
      final seen = <String, int>{};
      for (var b = 0x80; b <= 0xFF; b++) {
        final ch = decodePaperByte(b, PaperCharset.cp866);
        expect(
          ch,
          isNot('?'),
          reason: 'байт 0x${b.toRadixString(16)} не назван в таблице',
        );
        expect(
          seen[ch],
          isNull,
          reason:
              'знак «$ch» стоит и на 0x${seen[ch]?.toRadixString(16)}, '
              'и на 0x${b.toRadixString(16)}',
        );
        seen[ch] = b;
      }
      expect(seen.length, 128);
    });

    test('туда-обратно: байт → знак → байт', () {
      for (var b = 0x80; b <= 0xFF; b++) {
        final ch = decodePaperByte(b, PaperCharset.cp866);
        // `0xFF` — неразрывный пробел, он заменяется всегда (см.
        // alwaysReplaced), поэтому обратно приходит обычный пробел.
        if (b == 0xFF) {
          expect(encodePaper(ch, PaperCharset.cp866), [0x20]);
          continue;
        }
        expect(
          encodePaper(ch, PaperCharset.cp866),
          [b],
          reason: 'знак «$ch» не вернулся в 0x${b.toRadixString(16)}',
        );
      }
    });

    test('русские буквы, Ё и № — на своих местах', () {
      expect(encodePaper('АЯ', PaperCharset.cp866), [0x80, 0x9F]);
      expect(encodePaper('ая', PaperCharset.cp866), [0xA0, 0xEF]);
      expect(encodePaper('Ёё', PaperCharset.cp866), [0xF0, 0xF1]);
      expect(encodePaper('№', PaperCharset.cp866), [0xFC]);
      expect(encodePaper('°', PaperCharset.cp866), [0xF8]);
    });
  });

  group('Windows-1251 — полная таблица', () {
    test('единственная пустая позиция — 0x98', () {
      final empty = <int>[];
      for (var b = 0x80; b <= 0xFF; b++) {
        if (decodePaperByte(b, PaperCharset.windows1251) == '?') empty.add(b);
      }
      expect(empty, [0x98]);
    });

    test('туда-обратно, кроме всегда заменяемых', () {
      for (var b = 0x80; b <= 0xFF; b++) {
        if (b == 0x98) continue;
        final ch = decodePaperByte(b, PaperCharset.windows1251);
        if (alwaysReplaced.containsKey(ch.runes.first)) continue;
        expect(
          encodePaper(ch, PaperCharset.windows1251),
          [b],
          reason: 'знак «$ch» не вернулся в 0x${b.toRadixString(16)}',
        );
      }
    });

    test('«ёлочки» и «і» страница берёт сама — замены не нужны', () {
      expect(encodePaper('«»', PaperCharset.windows1251), [0xAB, 0xBB]);
      expect(encodePaper('Іі', PaperCharset.windows1251), [0xB2, 0xB3]);
    });
  });

  group('казахские буквы', () {
    const kazakh = 'ӘәҒғҚқҢңӨөҰұҮүҺһІі';

    test('на чеке CP866 выходят русской основой, а не вопросами', () {
      expect(paperText(kazakh, PaperCharset.cp866), 'АаГгКкНнОоУуУуХхИи');
      expect(unrepresentableRunes(kazakh, PaperCharset.cp866), isEmpty);
    });

    test('длина не меняется — разметка колонок не съезжает', () {
      expect(paperText(kazakh, PaperCharset.cp866).length, kazakh.length);
    });

    test('на этикетке CP1251 «і» доживает целой', () {
      expect(paperText('Сүті', PaperCharset.windows1251), 'Сутi'.replaceAll('i', 'і'));
    });

    test('слово целиком: Сәлем → Салем', () {
      expect(paperText('Сәлем', PaperCharset.cp866), 'Салем');
    });
  });

  group('знак тенге', () {
    test('печатается сокращением, а не выдуманной буквой', () {
      expect(paperText('100 ₸', PaperCharset.cp866), '100 тг');
      expect(paperText('100 ₸', PaperCharset.windows1251), '100 тг');
    });

    test('у знака тенге есть замена, вопроса не остаётся', () {
      expect(unrepresentableRunes('₸', PaperCharset.cp866), isEmpty);
      expect(unrepresentableRunes('₸', PaperCharset.windows1251), isEmpty);
    });

    test('байты — кириллические «т» и «г» своей страницы', () {
      expect(encodePaper('₸', PaperCharset.cp866), [0xE2, 0xA3]);
      expect(encodePaper('₸', PaperCharset.windows1251), [0xF2, 0xE3]);
    });
  });

  group('невидимые знаки', () {
    test('неразрывный пробел становится пробелом, а не заливкой', () {
      expect(encodePaper('1 234', PaperCharset.cp866), [
        0x31, 0x20, 0x32, 0x33, 0x34, //
      ]);
      expect(encodePaper('1 234', PaperCharset.windows1251), [
        0x31, 0x20, 0x32, 0x33, 0x34, //
      ]);
    });

    test('мягкий перенос и пробел нулевой ширины исчезают', () {
      expect(encodePaper('хле­б​', PaperCharset.cp866).length, 4);
    });
  });

  group('то, чему замены нет', () {
    test('остаётся вопросом и названо', () {
      expect(paperText('日', PaperCharset.cp866), '?');
      expect(unrepresentableRunes('日本', PaperCharset.cp866), {0x65E5, 0x672C});
    });
  });
}
