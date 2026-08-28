import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/l10n/app_localizations.dart';

final _accountsProvider = FutureProvider<List<Account>>((ref) async {
  final db = GetIt.I<AppDatabase>();
  return db.accountDao.findAll();
});

class AccountsSettingsScreen extends ConsumerWidget {
  const AccountsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accountsAsync = ref.watch(_accountsProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountsSettingsTitle),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(TeleposIcons.add),
            tooltip: l10n.accountsSettingsAdd,
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 64,
                    color: AppColors.textDisabled,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.accountsSettingsEmpty,
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(TeleposIcons.add),
                    label: Text(l10n.accountsSettingsAdd),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: 16,
            ),
            itemCount: accounts.length + 1,
            itemBuilder: (context, index) {
              if (index == accounts.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(TeleposIcons.add),
                    label: Text(l10n.accountsSettingsAdd),
                  ),
                );
              }

              final account = accounts[index];
              final typeName = _getTypeName(account.type, l10n);
              final balance = account.value ?? Decimal.zero;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getTypeColor(
                      context,
                      account.type,
                    ).withValues(alpha: 0.1),
                    child: Icon(
                      _getTypeIcon(account.type),
                      color: _getTypeColor(context, account.type),
                    ),
                  ),
                  title: Text(account.name ?? 'Account #${account.id}'),
                  subtitle: Text(
                    '$typeName  •  ${l10n.accountsSettingsBalance}: $balance',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (account.visibleToPos == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.accountsSettingsVisible,
                            style: context.styles.caption.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (account.type != AccountType.pos &&
                          account.type != AccountType.teleposMain &&
                          account.type != AccountType.teleposBonus)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () =>
                              _showEditDialog(context, ref, account),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getTypeName(int type, AppLocalizations l10n) {
    return switch (type) {
      0 => l10n.accountsSettingsTypePOS,
      1 => l10n.accountsSettingsTypeBank,
      2 => l10n.accountsSettingsTypeCash,
      5 => l10n.accountsSettingsTypeSystem,
      6 => l10n.accountsSettingsTypeBonus,
      _ => l10n.accountsSettingsTypeOther,
    };
  }

  Color _getTypeColor(BuildContext context, int type) {
    return switch (type) {
      0 => AppColors.success,
      1 => AppColors.paymentCard,
      2 => AppColors.warning,
      5 => AppColors.info,
      6 => AppColors.primary,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  IconData _getTypeIcon(int type) {
    return switch (type) {
      0 => Icons.point_of_sale,
      1 => Icons.credit_card,
      2 => Icons.payments,
      5 => Icons.hub,
      6 => Icons.card_giftcard,
      _ => Icons.account_balance,
    };
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final result = await _AccountFormDialog.show(context);
    if (result == null) return;

    final db = GetIt.I<AppDatabase>();
    final id = await db.accountDao.getNextId();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await db.accountDao.insertAccount(
      AccountsCompanion(
        id: Value(id),
        type: Value(result.type),
        name: Value(result.name),
        value: Value(Decimal.zero),
        visibleToPos: Value(result.visibleToPos),
        updateTime: Value(now),
      ),
    );

    ref.invalidate(_accountsProvider);
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final result = await _AccountFormDialog.show(
      context,
      name: account.name,
      type: account.type,
      visibleToPos: account.visibleToPos ?? false,
    );
    if (result == null) return;

    final db = GetIt.I<AppDatabase>();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await (db.update(db.accounts)..where((a) => a.id.equals(account.id))).write(
      AccountsCompanion(
        name: Value(result.name),
        type: Value(result.type),
        visibleToPos: Value(result.visibleToPos),
        updateTime: Value(now),
      ),
    );

    ref.invalidate(_accountsProvider);
  }
}

class _AccountFormResult {
  const _AccountFormResult({
    required this.name,
    required this.type,
    required this.visibleToPos,
  });
  final String name;
  final int type;
  final bool visibleToPos;
}

class _AccountFormDialog extends StatefulWidget {
  const _AccountFormDialog({this.name, this.type, this.visibleToPos = true});

  final String? name;
  final int? type;
  final bool visibleToPos;

  static Future<_AccountFormResult?> show(
    BuildContext context, {
    String? name,
    int? type,
    bool visibleToPos = true,
  }) {
    return showDialog<_AccountFormResult>(
      context: context,
      builder: (_) => _AccountFormDialog(
        name: name,
        type: type,
        visibleToPos: visibleToPos,
      ),
    );
  }

  @override
  State<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<_AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _selectedType;
  late bool _visibleToPos;

  bool get isEditing => widget.name != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name ?? '');
    _selectedType = widget.type ?? AccountType.customBank;
    _visibleToPos = widget.visibleToPos;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(
        isEditing ? l10n.accountsSettingsEdit : l10n.accountsSettingsAdd,
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.accountsSettingsName,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.label),
                ),
                autofocus: !isEditing,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.catalogNameRequired
                    : null,
              ),
              const SizedBox(height: AppTheme.spacing),
              DropdownButtonFormField<int>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: l10n.accountsSettingsType,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: [
                  DropdownMenuItem(
                    value: AccountType.customBank,
                    child: Text(l10n.accountsSettingsTypeBank),
                  ),
                  DropdownMenuItem(
                    value: AccountType.customCash,
                    child: Text(l10n.accountsSettingsTypeCash),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedType = v);
                },
              ),
              const SizedBox(height: AppTheme.spacing),
              SwitchListTile(
                title: Text(l10n.accountsSettingsVisibleToPos),
                value: _visibleToPos,
                onChanged: (v) => setState(() => _visibleToPos = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
          child: Text(l10n.globalSave),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _AccountFormResult(
        name: _nameController.text.trim(),
        type: _selectedType,
        visibleToPos: _visibleToPos,
      ),
    );
  }
}
