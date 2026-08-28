import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';

enum InformationType {
  info(TeleposIcons.info, AppColors.info),

  success(TeleposIcons.checkCircle, AppColors.success),

  warning(Icons.warning_amber_outlined, AppColors.warning),

  // Константа, а не `colorScheme.error`: это поле `enum`, оно вычисляется до
  // того, как появится хоть какой-нибудь `BuildContext`. Роль темы сюда
  // подставить нечем — и обходить это глобальным навигатором значило бы
  // завести вторую правду о цвете. Лечится тем, что цвет перестанет быть
  // полем перечисления и станет свойством виджета, — отдельная правка.
  error(TeleposIcons.error, AppColors.error);

  const InformationType(this.icon, this.color);

  final IconData icon;
  final Color color;
}

class InformationDialog extends StatelessWidget {
  const InformationDialog({
    super.key,
    required this.message,
    this.title,
    this.type = InformationType.info,
    this.buttonText,
    this.onPressed,
  });

  final String message;

  final String? title;

  final InformationType type;

  final String? buttonText;

  final VoidCallback? onPressed;

  static Future<void> show({
    required BuildContext context,
    required String message,
    String? title,
    InformationType type = InformationType.info,
    String? buttonText,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => InformationDialog(
        message: message,
        title: title,
        type: type,
        buttonText: buttonText,
      ),
    );
  }

  static Future<void> showSuccess({
    required BuildContext context,
    required String message,
    String? title,
  }) {
    return show(
      context: context,
      message: message,
      title: title ?? AppLocalizations.of(context)!.globalSuccess,
      type: InformationType.success,
    );
  }

  static Future<void> showError({
    required BuildContext context,
    required String message,
    String? title,
  }) {
    return show(
      context: context,
      message: message,
      title: title ?? AppLocalizations.of(context)!.globalError,
      type: InformationType.error,
    );
  }

  static Future<void> showWarning({
    required BuildContext context,
    required String message,
    String? title,
  }) {
    return show(
      context: context,
      message: message,
      title: title ?? AppLocalizations.of(context)!.globalWarning,
      type: InformationType.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(type.icon, size: 32, color: type.color),
              ),
              const SizedBox(height: 16),

              if (title != null) ...[
                Text(
                  title!,
                  style: AppTextStyles.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],

              Text(
                message,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onPressed?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: type.color,
                    foregroundColor: AppColors.white,
                  ),
                  child: Text(
                    buttonText ?? AppLocalizations.of(context)!.globalOk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
