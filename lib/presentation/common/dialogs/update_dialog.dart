import 'dart:async';

import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';

enum UpdateAction { updateNow, postpone, skip }

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.currentVersion,
    required this.newVersion,
    this.releaseNotes,
    this.isRequired = false,
    this.countdownSeconds = 60,
    this.onUpdate,
  });

  final String currentVersion;
  final String newVersion;
  final String? releaseNotes;
  final bool isRequired;
  final int countdownSeconds;
  final VoidCallback? onUpdate;

  static Future<UpdateAction?> show({
    required BuildContext context,
    required String currentVersion,
    required String newVersion,
    String? releaseNotes,
    bool isRequired = false,
    int countdownSeconds = 60,
    VoidCallback? onUpdate,
  }) {
    return showDialog<UpdateAction>(
      context: context,
      barrierDismissible: !isRequired,
      builder: (context) => UpdateDialog(
        currentVersion: currentVersion,
        newVersion: newVersion,
        releaseNotes: releaseNotes,
        isRequired: isRequired,
        countdownSeconds: countdownSeconds,
        onUpdate: onUpdate,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  Timer? _timer;
  late int _countdown;
  bool _isUpdating = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _countdown = widget.countdownSeconds;

    if (widget.isRequired) {
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          timer.cancel();
          _startUpdate();
        }
      });
    });
  }

  void _startUpdate() {
    setState(() => _isUpdating = true);
    widget.onUpdate?.call();

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _progress += 0.02;
        if (_progress >= 1.0) {
          timer.cancel();
          Navigator.of(context).pop(UpdateAction.updateNow);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: _isUpdating
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(
                        Icons.system_update,
                        size: 36,
                        color: AppColors.primary,
                      ),
              ),
              const SizedBox(height: 16),

              Text(
                _isUpdating
                    ? l10n.updateDialogUpdating
                    : l10n.updateDialogAvailable,
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 8),

              if (!_isUpdating) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'v${widget.currentVersion}',
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16),
                    ),
                    Text(
                      'v${widget.newVersion}',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              if (_isUpdating) ...[
                const SizedBox(height: 16),
                // Дорожка не задаётся: её отдаёт `progressIndicatorTheme`
                // ролью `hairline` — тот же цвет в светлой, свой в тёмной.
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: context.styles.caption,
                ),
              ],

              if (widget.releaseNotes != null && !_isUpdating) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.semantic.canvas,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.releaseNotes!,
                      style: context.styles.caption,
                    ),
                  ),
                ),
              ],

              if (widget.isRequired && _countdown > 0 && !_isUpdating) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.updateDialogAutoUpdate(_countdown),
                    style: context.styles.caption.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],

              if (!_isUpdating) ...[
                const SizedBox(height: 24),

                if (widget.isRequired) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startUpdate,
                      child: Text(l10n.updateDialogUpdateNow),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(UpdateAction.postpone),
                          child: Text(l10n.updateDialogLater),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(UpdateAction.skip),
                          child: Text(l10n.updateDialogSkip),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _startUpdate,
                          child: Text(l10n.updateDialogUpdate),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
