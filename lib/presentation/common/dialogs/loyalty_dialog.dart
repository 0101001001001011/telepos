import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/currency_service.dart';
import 'package:telepos/l10n/app_localizations.dart';

class LoyaltyResult {
  const LoyaltyResult({
    required this.phone,
    required this.bonusToUse,
    this.agentId,
  });

  final String phone;
  final Decimal bonusToUse;
  final int? agentId;
}

class LoyaltyDialog extends StatefulWidget {
  const LoyaltyDialog({
    super.key,
    this.initialPhone,
    this.availableBonus,
    this.maxBonusPercent = 100,
  });

  final String? initialPhone;
  final Decimal? availableBonus;
  final int maxBonusPercent;

  static Future<LoyaltyResult?> show({
    required BuildContext context,
    String? initialPhone,
    Decimal? availableBonus,
    int maxBonusPercent = 100,
  }) {
    return showDialog<LoyaltyResult>(
      context: context,
      builder: (context) => LoyaltyDialog(
        initialPhone: initialPhone,
        availableBonus: availableBonus,
        maxBonusPercent: maxBonusPercent,
      ),
    );
  }

  @override
  State<LoyaltyDialog> createState() => _LoyaltyDialogState();
}

class _LoyaltyDialogState extends State<LoyaltyDialog> {
  final _phoneController = TextEditingController();
  final _bonusController = TextEditingController();

  int _step = 0;
  String? _errorText;
  Decimal _availableBonus = Decimal.zero;
  int? _agentId;
  String? _agentName;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
    if (widget.availableBonus != null) {
      _availableBonus = widget.availableBonus!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  Future<void> _searchAgent() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.length < 10) {
      setState(
        () => _errorText = AppLocalizations.of(context)!.enterValidPhone,
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _errorText = null;
    });

    try {
      final db = GetIt.I<AppDatabase>();
      final phoneInt = int.tryParse(phone);

      Agent? agent;
      if (phoneInt != null) {
        agent = await db.agentDao.findByPhoneAndType(phoneInt, 1);
        agent ??= await db.agentDao.findByPhone(phoneInt);
      }

      if (!mounted) return;

      if (agent == null) {
        setState(() {
          _isSearching = false;
          _errorText = AppLocalizations.of(context)!.agentNotFound;
        });
        return;
      }

      Decimal bonus = Decimal.zero;
      if (agent.cashbackAccountId != null) {
        final account = await db.accountDao.findById(agent.cashbackAccountId!);
        if (account != null && account.value != null) {
          bonus = account.value!;
        }
      }

      if (!mounted) return;

      setState(() {
        _step = 1;
        _agentId = agent!.localId;
        _agentName = agent.name;
        _availableBonus = bonus;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorText = e.toString();
      });
    }
  }

  void _submit() {
    final bonusText = _bonusController.text;
    Decimal bonusToUse = Decimal.zero;

    if (bonusText.isNotEmpty) {
      try {
        bonusToUse = Decimal.parse(bonusText.replaceAll(',', '.'));
        if (bonusToUse > _availableBonus) {
          setState(
            () =>
                _errorText = AppLocalizations.of(context)!.insufficientBonuses,
          );
          return;
        }
        if (bonusToUse < Decimal.zero) {
          setState(
            () => _errorText = AppLocalizations.of(context)!.enterValidNumber,
          );
          return;
        }
      } catch (_) {
        setState(
          () => _errorText = AppLocalizations.of(context)!.enterValidNumber,
        );
        return;
      }
    }

    Navigator.of(context).pop(
      LoyaltyResult(
        phone: _phoneController.text,
        bonusToUse: bonusToUse,
        agentId: _agentId,
      ),
    );
  }

  String get _currencySymbol => GetIt.I<CurrencyService>().symbol;

  String _formatMoney(Decimal value) {
    return '${value.toStringAsFixed(0)} $_currencySymbol';
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    AppLocalizations.of(context)!.bonusProgram,
                    style: AppTextStyles.h3,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_step == 0) _buildPhoneStep(),
              if (_step == 1) _buildBonusStep(),

              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: context.styles.caption.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (_step > 0) {
                          setState(() {
                            _step--;
                            _errorText = null;
                          });
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(
                        _step > 0
                            ? AppLocalizations.of(context)!.globalBack
                            : AppLocalizations.of(context)!.globalCancel,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSearching
                          ? null
                          : _step == 0
                          ? _searchAgent
                          : _submit,
                      child: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _step == 1
                                  ? AppLocalizations.of(context)!.discountApply
                                  : AppLocalizations.of(context)!.globalNext,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      children: [
        Text(
          AppLocalizations.of(context)!.enterPhone,
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          autofocus: true,
          keyboardType: TextInputType.phone,
          textAlign: TextAlign.center,
          style: AppTextStyles.h3,
          decoration: InputDecoration(
            hintText: '+7 (XXX) XXX-XX-XX',
            prefixIcon: const Icon(Icons.phone),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (_) => _searchAgent(),
        ),
      ],
    );
  }

  Widget _buildBonusStep() {
    return Column(
      children: [
        if (_agentName != null) ...[
          Text(
            _agentName!,
            style: AppTextStyles.h3.copyWith(color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.availableBonuses,
                style: AppTextStyles.body,
              ),
              Text(
                _formatMoney(_availableBonus),
                style: AppTextStyles.h3.copyWith(color: AppColors.success),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _bonusController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: AppTextStyles.h2,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.useBonuses,
            hintText: '0',
            suffixText: _currencySymbol,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.maxBonusPercent(widget.maxBonusPercent),
          style: context.styles.caption,
        ),
      ],
    );
  }
}
