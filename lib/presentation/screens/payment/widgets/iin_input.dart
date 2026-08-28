import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

class IinInput extends ConsumerStatefulWidget {
  const IinInput({super.key});

  @override
  ConsumerState<IinInput> createState() => _IinInputState();
}

class _IinInputState extends ConsumerState<IinInput> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _validateIin(String value) {
    if (value.isEmpty) return true;
    if (value.length != 12) return false;
    if (!RegExp(r'^\d{12}$').hasMatch(value)) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final iin = ref.watch(paymentControllerProvider.select((s) => s.iin));

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.paymentIinLabel,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSmall),

          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            decoration: InputDecoration(
              hintText: '123456789012',
              prefixIcon: const Icon(Icons.numbers),
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              suffixIcon: iin != null && iin.isNotEmpty
                  ? IconButton(
                      icon: const Icon(TeleposIcons.close),
                      onPressed: () {
                        _controller.clear();
                        ref
                            .read(paymentControllerProvider.notifier)
                            .setIin(null);
                        setState(() {
                          _error = null;
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              if (value.isEmpty) {
                ref.read(paymentControllerProvider.notifier).setIin(null);
                setState(() {
                  _error = null;
                });
                return;
              }

              if (value.length == 12) {
                if (_validateIin(value)) {
                  ref.read(paymentControllerProvider.notifier).setIin(value);
                  setState(() {
                    _error = null;
                  });
                } else {
                  setState(() {
                    _error = l10n.paymentIinInvalid;
                  });
                }
              } else {
                setState(() {
                  _error = null;
                });
              }
            },
          ),

          const SizedBox(height: AppTheme.spacingSmall),
          Text(l10n.paymentIinHint, style: context.styles.caption),
        ],
      ),
    );
  }
}

class IinInputCompact extends ConsumerStatefulWidget {
  const IinInputCompact({super.key});

  @override
  ConsumerState<IinInputCompact> createState() => _IinInputCompactState();
}

class _IinInputCompactState extends ConsumerState<IinInputCompact> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final iin = ref.watch(paymentControllerProvider.select((s) => s.iin));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing),
              child: Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      iin != null && iin.isNotEmpty
                          ? '${l10n.paymentIinShort}: $iin'
                          : l10n.paymentIinShort,
                      style: AppTextStyles.body.copyWith(
                        color: iin != null
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(AppTheme.spacing),
              child: IinInput(),
            ),
          ],
        ],
      ),
    );
  }
}
