import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';

class DialogBreakpoints {
  DialogBreakpoints._();

  static const double mobile = 600;

  static const double tablet = 900;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobile && width < tablet;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;
}

class AdaptiveDialog {
  AdaptiveDialog._();

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    bool barrierDismissible = true,
    double? maxWidth,
    bool useRootNavigator = true,
  }) {
    if (DialogBreakpoints.isMobile(context)) {
      return showGeneralDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenDialog(title: title, child: builder(context));
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        useRootNavigator: useRootNavigator,
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = DialogBreakpoints.isTablet(context)
        ? screenWidth * 0.8
        : (maxWidth ?? 500.0);

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: builder(context),
        ),
      ),
    );
  }

  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    double? maxWidth,
  }) {
    if (DialogBreakpoints.isMobile(context)) {
      return showModalBottomSheet<T>(
        context: context,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) =>
            _AdaptiveBottomSheet(title: title, child: builder(context)),
      );
    }

    return show<T>(
      context: context,
      builder: builder,
      title: title,
      maxWidth: maxWidth ?? 400,
    );
  }

  static Future<T?> showOptions<T>({
    required BuildContext context,
    required String title,
    required List<AdaptiveOption<T>> options,
    T? selectedValue,
  }) {
    if (DialogBreakpoints.isMobile(context)) {
      return showModalBottomSheet<T>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => _OptionsBottomSheet<T>(
          title: title,
          options: options,
          selectedValue: selectedValue,
        ),
      );
    }

    return showDialog<T>(
      context: context,
      builder: (context) => _OptionsDialog<T>(
        title: title,
        options: options,
        selectedValue: selectedValue,
      ),
    );
  }

  static Future<bool> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final effectiveConfirm = confirmText ?? l10n.globalYes;
    final effectiveCancel = cancelText ?? l10n.globalNo;

    if (DialogBreakpoints.isMobile(context)) {
      final result = await showModalBottomSheet<bool>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => _ConfirmationBottomSheet(
          title: title,
          message: message,
          confirmText: effectiveConfirm,
          cancelText: effectiveCancel,
          isDestructive: isDestructive,
        ),
      );
      return result ?? false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(effectiveCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text(effectiveConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class AdaptiveOption<T> {
  const AdaptiveOption({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
    this.isDestructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? subtitle;
  final bool isDestructive;
}

class _FullscreenDialog extends StatelessWidget {
  const _FullscreenDialog({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(
              title: Text(title!),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(TeleposIcons.close),
              ),
            )
          : null,
      body: SafeArea(child: child),
    );
  }
}

class _AdaptiveBottomSheet extends StatelessWidget {
  const _AdaptiveBottomSheet({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: context.semantic.canvas,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(title!, style: AppTextStyles.h3),
            ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class _OptionsBottomSheet<T> extends StatelessWidget {
  const _OptionsBottomSheet({
    required this.title,
    required this.options,
    this.selectedValue,
  });

  final String title;
  final List<AdaptiveOption<T>> options;
  final T? selectedValue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: context.semantic.canvas,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(title, style: AppTextStyles.h3),
          ),
          const Divider(),
          ...options.map(
            (option) => ListTile(
              leading: option.icon != null
                  ? Icon(
                      option.icon,
                      color: option.isDestructive
                          ? Theme.of(context).colorScheme.error
                          : null,
                    )
                  : null,
              title: Text(
                option.label,
                style: TextStyle(
                  color: option.isDestructive
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
              subtitle: option.subtitle != null ? Text(option.subtitle!) : null,
              trailing: option.value == selectedValue
                  ? const Icon(TeleposIcons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(option.value),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OptionsDialog<T> extends StatelessWidget {
  const _OptionsDialog({
    required this.title,
    required this.options,
    this.selectedValue,
  });

  final String title;
  final List<AdaptiveOption<T>> options;
  final T? selectedValue;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(title, style: AppTextStyles.h3),
            ),
            const Divider(height: 1),
            ...options.map(
              (option) => ListTile(
                leading: option.icon != null
                    ? Icon(
                        option.icon,
                        color: option.isDestructive
                            ? Theme.of(context).colorScheme.error
                            : null,
                      )
                    : null,
                title: Text(
                  option.label,
                  style: TextStyle(
                    color: option.isDestructive
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                subtitle: option.subtitle != null
                    ? Text(option.subtitle!)
                    : null,
                trailing: option.value == selectedValue
                    ? const Icon(TeleposIcons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(option.value),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationBottomSheet extends StatelessWidget {
  const _ConfirmationBottomSheet({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.isDestructive,
  });

  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.semantic.canvas,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(title, style: AppTextStyles.h3),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: isDestructive
                        ? ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          )
                        : null,
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
