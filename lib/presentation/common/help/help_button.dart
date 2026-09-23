import 'package:flutter/material.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/help/help_dialog.dart';

class HelpButton extends StatelessWidget {
  const HelpButton({
    required this.screenId,
    this.color,
    this.iconSize,
    super.key,
  });

  final String screenId;

  final Color? color;

  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    // Словарь обязателен: `l10n?.… ?? 'Справка'` означал тихий русский
    // текст в сборке без делегатов. Ровно так экран покупателя год
    // печатал по-русски, и вскрылось это только правкой на нём.
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      icon: Icon(Icons.help_outline, color: color, size: iconSize),
      tooltip: l10n.helpTitle,
      onPressed: () => HelpDialog.show(context, screenId),
    );
  }
}
