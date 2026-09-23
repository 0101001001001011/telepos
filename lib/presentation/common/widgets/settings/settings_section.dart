import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/app_typography.dart';

/// Сгруппированный блок в духе Telegram.
///
/// Подпись сверху, скруглённая поверхность, строки, разделённые линией в один
/// физический пиксель. После последней строки разделителя нет — это то, чем
/// сгруппированный список отличается от таблицы.
///
/// [header] — единственный заголовок, который в мастере вообще остался.
/// Заголовков по центру больше нет ни на одном шаге, где заполняют поля: их
/// работу выполняют эта подпись и название шага в шапке.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.children,
    this.header,
    this.footer,
    super.key,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = AppTokens.hairlineOf(context);

    // Пустая группа с подписью — это СООБЩЕНИЕ, и рисовать его надо в
    // карточке.
    //
    // До этой правки `children: const []` давал карточку нулевой высоты, и
    // текст подписи повисал голой серой строкой в воздухе — без блока, без
    // оформления, не как всё остальное на экране. Так выглядели шаги
    // «Фискализация» и «Терминалы» на американской кассе: всё, что видел
    // человек, — строчка «Fiscalization is not required for your country»
    // посреди пустоты. Заметил заказчик, глядя на экран, 2026-09-21.
    //
    // Чиним здесь, а не в двух шагах: пустая группа встретится снова, и
    // следующий раз никто не вспомнит, что её надо обойти.
    final emptyWithMessage = children.isEmpty && footer != null;

    final rows = <Widget>[];
    if (emptyWithMessage) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space16,
            vertical: AppTokens.space16,
          ),
          child: Text(
            footer!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          Divider(
            height: hairline,
            thickness: hairline,
            indent: AppTokens.space16,
            endIndent: 0,
            color: theme.colorScheme.outlineVariant,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Подпись группы — своя роль `sectionHeader`, а не `bodySmall`.
        //
        // По размеру они сейчас совпадают (13/400), и подмена ничего бы не
        // изменила на экране сегодня. Но `bodySmall` — это подпись СТРОКИ, и
        // однажды её понадобится подвинуть; тогда вместе с подписями строк
        // молча поедут и все заголовки групп. Роли разные, потому что работа
        // разная: одна называет группу, другая поясняет строку.
        //
        // Отступ слева тот же, что внутри строки секции (space16), — подпись
        // стоит ровно над названием первой строки, а не левее её.
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppTokens.space16,
              right: AppTokens.space16,
              bottom: AppTokens.space8,
            ),
            child: Text(
              header!,
              style: AppTypography.sectionHeader.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Material(
          color: theme.colorScheme.surface,
          elevation: 0,
          borderRadius: BorderRadius.circular(AppTokens.radiusSection),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
        // Подпись под карточкой — только когда строки есть. Иначе она уже
        // нарисована ВНУТРИ, и повторять её значит сказать дважды.
        if (footer != null && !emptyWithMessage)
          Padding(
            padding: const EdgeInsets.only(
              left: AppTokens.space16,
              right: AppTokens.space16,
              top: AppTokens.space8,
            ),
            child: Text(
              footer!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
