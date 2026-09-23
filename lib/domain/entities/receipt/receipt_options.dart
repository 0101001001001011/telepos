import 'dart:convert';

import 'package:telepos/domain/entities/receipt/receipt_text_block.dart';

export 'package:telepos/domain/entities/receipt/receipt_text_block.dart';

/// Ширина ленты чекового принтера и число колонок моноширинного шрифта A.
///
/// 58 мм — 384 точки, 32 символа; 80 мм — 576 точек, 48 символов (XPrinter
/// XP-80, Epson TM-T88, Posiflex PP8000 — `printer_profiles.dart`).
///
/// **Не часть шаблона чека.** Откуда берётся — `ReceiptPaperWidthSource`.
enum ReceiptPaperWidth {
  mm58(58, 32),

  mm80(80, 48);

  const ReceiptPaperWidth(this.mm, this.charWidth);

  final int mm;

  final int charWidth;

  static ReceiptPaperWidth fromMm(int? mm) =>
      mm == 80 ? ReceiptPaperWidth.mm80 : ReceiptPaperWidth.mm58;
}

/// Шаблон чека кассы: что оператор **может** настроить.
///
/// ## Шапка и подвал
///
/// Свободный многострочный текст каждый ([ReceiptTextBlock]) — маркетинг,
/// благодарность, контакты. Шапка печатается **выше** обязательной части
/// чека, подвал — **ниже**, после фискального блока и QR.
///
/// ## Чего шаблон не может
///
/// Убрать или сломать обязательные и фискальные реквизиты: номер чека, итог,
/// оплаты, НДС плательщика, БИН/ИИН, фискальный признак, ссылку проверки и QR.
/// Переключатели `showBin`, `showVat`, `showQr`, стоявшие здесь до правки,
/// делали ровно это — фискальный чек без QR и без НДС печатался одной
/// галочкой. Их ключи в сохранённых шаблонах больше не читаются.
class ReceiptOptions {
  const ReceiptOptions({
    this.showLogo = false,
    this.header = const ReceiptTextBlock(),
    this.footer,
    this.showAddress = true,
    this.showCashier = true,
    this.showItemNumbers = false,
  });

  /// Подвал в ТРЁХ состояниях, а не в двух.
  ///
  /// * `null` — **не задан**. Печать ставит благодарность на языке чека.
  /// * пустой блок — **стёрт нарочно**. Не печатается ничего.
  /// * непустой — своё, печатается как есть.
  ///
  /// # Почему не просто строка с умолчанием
  ///
  /// Умолчанием здесь лежала русская константа «Спасибо за покупку!», и
  /// она печаталась на чеке любого языка: американский чек кончался
  /// по-русски. Измерено на дубле урока 1.3, 2026-09-21.
  ///
  /// Перевести её здесь нельзя: это `const` в слое сущностей, словаря ему
  /// взять неоткуда. Первая правка сделала умолчание пустым — и слила два
  /// состояния в одно: владелец, стёрший подвал нарочно, снова получал
  /// благодарность. Разводит их `null`.

  final bool showLogo;

  final ReceiptTextBlock header;

  final ReceiptTextBlock? footer;

  final bool showAddress;

  final bool showCashier;

  final bool showItemNumbers;

  ReceiptOptions copyWith({
    bool? showLogo,
    ReceiptTextBlock? header,
    ReceiptTextBlock? footer,
    bool clearFooter = false,
    bool? showAddress,
    bool? showCashier,
    bool? showItemNumbers,
  }) {
    return ReceiptOptions(
      showLogo: showLogo ?? this.showLogo,
      header: header ?? this.header,
      footer: clearFooter ? null : (footer ?? this.footer),
      showAddress: showAddress ?? this.showAddress,
      showCashier: showCashier ?? this.showCashier,
      showItemNumbers: showItemNumbers ?? this.showItemNumbers,
    );
  }

  Map<String, dynamic> toJson() => {
    'showLogo': showLogo,
    'header': header.toJson(),
    // Незаданный подвал ключа не получает — так его и прочитают обратно
    // как незаданный. Записать пустой блок значило бы превратить «не
    // трогали» в «стёрли».
    if (footer != null) 'footer': footer!.toJson(),
    'showAddress': showAddress,
    'showCashier': showCashier,
    'showItemNumbers': showItemNumbers,
  };

  /// Разбор сохранённого шаблона.
  ///
  /// Шаблоны до правки хранили шапку одной строкой `headerText`, подвал —
  /// строкой `footerText` и списком `extraFooterLines`. Они читаются в блоки
  /// по центру — так они и печатались, — ничего не теряя. Ключи `paperWidth`
  /// (ширина — свойство принтера) и `showBin`/`showVat`/`showQr` (шаблон не
  /// убирает реквизиты) не читаются.
  factory ReceiptOptions.fromJson(Map<String, dynamic> json) {
    final rawHeader = json['header'];
    final rawFooter = json['footer'];
    return ReceiptOptions(
      showLogo: json['showLogo'] as bool? ?? false,
      header: rawHeader is Map
          ? ReceiptTextBlock.fromJson(Map<String, dynamic>.from(rawHeader))
          : ReceiptTextBlock(text: json['headerText'] as String? ?? ''),
      footer: rawFooter is Map
          ? ReceiptTextBlock.fromJson(Map<String, dynamic>.from(rawFooter))
          : _legacyFooter(json),
      showAddress: json['showAddress'] as bool? ?? true,
      showCashier: json['showCashier'] as bool? ?? true,
      showItemNumbers: json['showItemNumbers'] as bool? ?? false,
    );
  }

  /// Подвал старого шаблона. `null` — ключа не было вовсе.
  ///
  /// Разница существенна: шаблон без ключа подвал не задавал, и печать
  /// поставит благодарность на своём языке. Шаблон с пустым `footerText`
  /// подвал **стёр**, и печатать нечего.
  static ReceiptTextBlock? _legacyFooter(Map<String, dynamic> json) {
    final extra =
        (json['extraFooterLines'] as List?)?.map((e) => e.toString()) ??
        const <String>[];

    if (!json.containsKey('footerText')) {
      final tail = extra.where((l) => l.trim().isNotEmpty).toList();
      return tail.isEmpty ? null : ReceiptTextBlock(text: tail.join('\n'));
    }

    final main = json['footerText'] as String? ?? '';
    return ReceiptTextBlock(
      text: [main, ...extra].where((l) => l.trim().isNotEmpty).join('\n'),
    );
  }

  static ReceiptOptions decode(String optionsJson) {
    try {
      final raw = jsonDecode(optionsJson);
      if (raw is! Map) return const ReceiptOptions();
      return ReceiptOptions.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return const ReceiptOptions();
    }
  }

  String encode() => jsonEncode(toJson());

  static const ReceiptOptions kzDefault = ReceiptOptions();
}
