import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';

/// Поле ввода как строка списка.
///
/// Название слева, значение справа — рамки вокруг поля нет: границу уже задаёт
/// секция, и вторая рамка внутри неё читается как нагромождение.
///
/// Объяснений у поля три уровня, и они независимы: подпись строки называет
/// поле, [helper] всегда виден под ним и говорит формат, [explanation] лежит
/// за нажимаемой иконкой и говорит цену ошибки. Третий уровень заводится не у
/// каждого поля, а там, где человек может ошибиться молча — иначе иконки
/// перестают что-либо значить.
class SettingsFieldTile extends StatefulWidget {
  SettingsFieldTile({
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.metrics,
    this.hint,
    this.helper,
    this.explanation,
    this.errorText,
    this.keyboardType,
    this.formatters,
    this.obscure = false,
    this.maxLines = 1,
    this.required = false,
    super.key,
  }) : assert(
         explanation == null || explanation.trim().isNotEmpty,
         'Иконка, открывающая пустоту, хуже её отсутствия: человек нажимает, '
         'не получает ничего и перестаёт нажимать вообще.',
       );

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final WizardMetrics metrics;
  final String? hint;

  /// Постоянная подсказка под полем: формат, единицы, пример.
  final String? helper;

  /// Объяснение по требованию. Заводит иконку рядом с подписью строки.
  final String? explanation;

  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final bool obscure;
  final int maxLines;

  /// Без этого поля шаг не пускает дальше.
  ///
  /// Признак обязательности пережил перевёрстку намеренно: в форме, где часть
  /// полей необязательна, человек иначе не отличает одни от других и упирается
  /// в погашенную кнопку «Далее», не понимая почему.
  final bool required;

  @override
  State<SettingsFieldTile> createState() => _SettingsFieldTileState();
}

class _SettingsFieldTileState extends State<SettingsFieldTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasProblem = widget.errorText != null;
    final metrics = widget.metrics;
    final explanation = widget.explanation;

    // Под курсором объяснение показывает тултип: он привычен настольному
    // интерфейсу и не занимает места. На сенсоре наведения не существует
    // вовсе, поэтому там иконка раскрывает текст в потоке секции — модальное
    // окно ради одной фразы прервало бы заполнение формы.
    Widget? hintIcon;
    if (explanation != null) {
      hintIcon = metrics.showHover
          // Под курсором это не кнопка, а надписанная иконка. IconButton с
          // onPressed: null выглядел бы выключенным — тот самый серый цвет,
          // которым интерфейс говорит «сюда нельзя», хотя навести можно и
          // нужно.
          ? Tooltip(
              message: explanation,
              child: Padding(
                padding: const EdgeInsets.only(left: AppTokens.space4),
                child: Icon(
                  Icons.help_outline,
                  size: AppTokens.iconSizeHint,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : IconButton(
              icon: const Icon(Icons.help_outline),
              iconSize: AppTokens.iconSizeHint,
              visualDensity: VisualDensity.compact,
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: () => setState(() => _expanded = !_expanded),
            );
    }

    final showExpanded = explanation != null && _expanded && !metrics.showHover;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: metrics.rowHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.label,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      // Отметка обязательности — отдельный виджет, а не часть
                      // подписи. Text.rich не заполняет `data`, и подпись
                      // после склейки перестаёт находиться по тексту — как
                      // тестами, так и всем, что читает дерево.
                      if (widget.required)
                        Text(
                          ' *',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      if (hintIcon != null) hintIcon,
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: widget.controller,
                    onChanged: widget.onChanged,
                    keyboardType: widget.keyboardType,
                    inputFormatters: widget.formatters,
                    obscureText: widget.obscure,
                    maxLines: widget.obscure ? 1 : widget.maxLines,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(hintText: widget.hint),
                  ),
                ),
              ],
            ),
            // Ошибка вытесняет постоянную подсказку, а не встаёт рядом: две
            // строки под полем соревнуются за внимание, и читают обычно ту,
            // что не про ошибку.
            if (widget.helper != null && !hasProblem)
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.space4),
                child: Text(
                  widget.helper!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (hasProblem)
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.space4),
                child: Text(
                  widget.errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            // Раскрытое объяснение — третий уровень, он не отменяет второго:
            // «12 цифр» остаётся, когда раскрыто, зачем эти цифры нужны.
            if (showExpanded)
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.space8),
                child: Text(
                  explanation,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
