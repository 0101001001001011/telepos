/// Перенос строки чека **по словам** под число колонок ленты.
///
/// Жадный: в строку кладётся столько слов, сколько помещается. Слово длиннее
/// ширины (ссылка, длинный артикул) режется по колонкам — иначе принтер
/// перенёс бы его сам, в произвольном месте и без выравнивания, или
/// построитель обрезал бы хвост, как обрезал ссылку проверки чека до этой
/// правки.
///
/// Пробелы между словами схлопываются в один: на ленте в 32 колонки выравнивать
/// пробелами бессмысленно, для этого есть `ESC a`. Пустая строка остаётся одной
/// пустой строкой — абзац, отбитый оператором, и есть абзац.
List<String> wrapReceiptLine(String line, int width) {
  if (width <= 0) return [line];
  final words = line.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return [''];

  final result = <String>[];
  var current = '';

  void placeAlone(String word) {
    var rest = word;
    while (rest.length > width) {
      result.add(rest.substring(0, width));
      rest = rest.substring(width);
    }
    current = rest;
  }

  for (final word in words) {
    if (current.isEmpty) {
      placeAlone(word);
    } else if (current.length + 1 + word.length <= width) {
      current = '$current $word';
    } else {
      result.add(current);
      placeAlone(word);
    }
  }
  if (current.isNotEmpty) result.add(current);
  return result;
}
