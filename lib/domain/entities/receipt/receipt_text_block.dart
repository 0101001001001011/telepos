/// Выравнивание строки чека — ровно три значения команды `ESC a`.
enum ReceiptTextAlign { left, center, right }

/// Свободный текст шапки или подвала чека: маркетинг, благодарность, контакты,
/// сайт, соцсети — сколько угодно строк, одно оформление на блок.
///
/// ## Чего шаблон сделать не может
///
/// Блок — **текст**, а не байты. Управляющие символы (`ESC`, `GS`, `DLE` и
/// прочие ниже пробела) из него вынимаются: вставленный из буфера обмена
/// `ESC i` отрезал бы чек посреди фискального блока, `ESC t` сменил бы кодовую
/// страницу обязательной части. Перевод строки — единственный управляющий
/// символ, который оператор пишет намеренно, и он делит блок на строки.
///
/// Оформление блока (выравнивание, жирный, двойной размер) построитель
/// снимает сразу после блока, до первой обязательной строки
/// (`ReceiptBuilder.addTextBlock`).
class ReceiptTextBlock {
  const ReceiptTextBlock({
    this.text = '',
    this.align = ReceiptTextAlign.center,
    this.bold = false,
    this.doubleSize = false,
  });

  final String text;

  final ReceiptTextAlign align;

  final bool bold;

  /// Двойная ширина и высота (`GS ! 0x11`) — вдвое меньше колонок.
  final bool doubleSize;

  /// Строки блока, как их напечатает принтер до переноса: без управляющих
  /// символов, без пустых строк по краям. Пустые строки **внутри** — абзацы
  /// оператора — остаются.
  List<String> get lines {
    final cleaned = StringBuffer();
    for (final unit in text.replaceAll('\r\n', '\n').codeUnits) {
      if (unit == 0x0A) {
        cleaned.writeCharCode(unit);
      } else if (unit == 0x09) {
        cleaned.write(' ');
      } else if (unit < 0x20 || unit == 0x7F) {
        continue;
      } else {
        cleaned.writeCharCode(unit);
      }
    }
    final all = cleaned
        .toString()
        .split('\n')
        .map((l) => l.trimRight())
        .toList();
    var start = 0;
    var end = all.length;
    while (start < end && all[start].trim().isEmpty) {
      start++;
    }
    while (end > start && all[end - 1].trim().isEmpty) {
      end--;
    }
    return all.sublist(start, end);
  }

  bool get isEmpty => lines.isEmpty;

  ReceiptTextBlock copyWith({
    String? text,
    ReceiptTextAlign? align,
    bool? bold,
    bool? doubleSize,
  }) => ReceiptTextBlock(
    text: text ?? this.text,
    align: align ?? this.align,
    bold: bold ?? this.bold,
    doubleSize: doubleSize ?? this.doubleSize,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'align': align.name,
    'bold': bold,
    'doubleSize': doubleSize,
  };

  /// Разбор сохранённого блока. Неизвестное выравнивание — по центру, как у
  /// блока по умолчанию: записано более новой сборкой, и угадывать иначе
  /// значило бы выдумать.
  static ReceiptTextBlock fromJson(Map<String, dynamic> json) {
    final alignName = json['align'] as String?;
    return ReceiptTextBlock(
      text: json['text'] as String? ?? '',
      align: ReceiptTextAlign.values.firstWhere(
        (a) => a.name == alignName,
        orElse: () => ReceiptTextAlign.center,
      ),
      bold: json['bold'] as bool? ?? false,
      doubleSize: json['doubleSize'] as bool? ?? false,
    );
  }
}
