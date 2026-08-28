import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';

class ModalDialog extends StatelessWidget {
  const ModalDialog({
    super.key,
    required this.child,
    this.title,
    this.titleWidget,
    this.actions,
    this.width,
    this.maxWidth = 500,
    this.padding = const EdgeInsets.all(24),
    this.showCloseButton = true,
    this.barrierDismissible = true,
  });

  final Widget child;

  final String? title;

  final Widget? titleWidget;

  final List<Widget>? actions;

  final double? width;

  final double maxWidth;

  final EdgeInsets padding;

  final bool showCloseButton;

  final bool barrierDismissible;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width ?? maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || titleWidget != null || showCloseButton)
              _buildHeader(context),

            Flexible(
              child: SingleChildScrollView(padding: padding, child: child),
            ),

            if (actions != null && actions!.isNotEmpty) _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.semantic.canvas)),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                titleWidget ??
                (title != null
                    ? Text(title!, style: AppTextStyles.h3)
                    : const SizedBox.shrink()),
          ),
          if (showCloseButton)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(TeleposIcons.close),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.semantic.canvas)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: actions!
            .map(
              (action) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: action,
              ),
            )
            .toList(),
      ),
    );
  }
}
