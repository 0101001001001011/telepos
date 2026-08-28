import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/mixins/barcode_scanner_mixin.dart';
import 'package:telepos/presentation/controllers/agent/agent_controller.dart';
import 'package:telepos/presentation/controllers/supply/supply_controller.dart';
import 'package:telepos/presentation/screens/agent/widgets/add_customer_dialog.dart';

class SupplyForm extends ConsumerStatefulWidget {
  const SupplyForm({super.key});

  @override
  ConsumerState<SupplyForm> createState() => _SupplyFormState();
}

class _SupplyFormState extends ConsumerState<SupplyForm>
    with BarcodeScannerMixin {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();

  bool _serialTracking = false;

  @override
  void initState() {
    super.initState();
    initBarcodeScanner();
    _loadSerialTracking();
  }

  Future<void> _loadSerialTracking() async {
    final enabled = await ref
        .read(supplyControllerProvider.notifier)
        .isSerialTrackingEnabled();
    if (mounted) setState(() => _serialTracking = enabled);
  }

  @override
  void dispose() {
    disposeBarcodeScanner();
    _commentController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  void onBarcodeScanned(String barcode) {
    ref.read(supplyControllerProvider.notifier).addByBarcode(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplyControllerProvider);
    final controller = ref.read(supplyControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSupplierSelector(state, controller),
        const SizedBox(height: 16),

        _buildPaymentTypeSelector(state, controller),
        const SizedBox(height: 16),

        if (state.paymentType == SupplyPaymentType.fullSupply) ...[
          _buildAccountSelector(state, controller),
          const SizedBox(height: 16),
        ],

        _buildBarcodeInput(controller),
        const SizedBox(height: 16),

        if (state.products.isNotEmpty) ...[
          _buildProductsList(state, controller),
          const SizedBox(height: 16),
        ],

        _buildCommentField(state, controller),
      ],
    );
  }

  Widget _buildSupplierSelector(SupplyState state, SupplyNotifier controller) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.supplySupplierRequired,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showSupplierDialog(controller),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.supplierName ?? l10n.supplySelectSupplier,
                    style: TextStyle(
                      fontSize: 15,
                      color: state.supplierId == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTypeSelector(
    SupplyState state,
    SupplyNotifier controller,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.supplyPaymentType,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _PaymentTypeOption(
                title: l10n.supplyFullPayment,
                subtitle: l10n.supplyAccountDebit,
                icon: Icons.payments,
                isSelected: state.paymentType == SupplyPaymentType.fullSupply,
                onTap: () =>
                    controller.setPaymentType(SupplyPaymentType.fullSupply),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PaymentTypeOption(
                title: l10n.supplyConsignment,
                subtitle: l10n.supplyDeferredPayment,
                icon: Icons.schedule,
                isSelected: state.paymentType == SupplyPaymentType.consignment,
                onTap: () =>
                    controller.setPaymentType(SupplyPaymentType.consignment),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountSelector(SupplyState state, SupplyNotifier controller) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.supplyPaymentAccountRequired,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showAccountDialog(controller),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.accountName ?? l10n.supplySelectAccount,
                    style: TextStyle(
                      fontSize: 15,
                      color: state.accountId == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeInput(SupplyNotifier controller) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.supplyAddProduct,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  hintText: l10n.supplyBarcodeOrSku,
                  prefixIcon: const Icon(Icons.qr_code),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (value) => _onBarcodeEntered(controller, value),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () =>
                  _onBarcodeEntered(controller, _barcodeController.text),
              icon: const Icon(TeleposIcons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductsList(SupplyState state, SupplyNotifier controller) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.supplyProductsCount(state.productCount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              l10n.supplyAmountValue(
                state.totalAmount?.toStringAsFixed(2) ?? '0.00',
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.products.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = state.products[index];
              return _ProductListItem(
                product: product,
                onEdit: () => _showEditProductDialog(controller, product),
                onDelete: () => controller.removeProduct(product.ucode),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommentField(SupplyState state, SupplyNotifier controller) {
    final l10n = AppLocalizations.of(context)!;

    if (_commentController.text != state.comment) {
      _commentController.text = state.comment;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.supplyComment,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _commentController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l10n.supplyCommentHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          onChanged: controller.setComment,
        ),
      ],
    );
  }

  Future<void> _showSupplierDialog(SupplyNotifier controller) async {
    final suppliers = await controller.getSuppliers();

    if (!mounted) return;

    final selected = await showDialog<SupplierItem>(
      context: context,
      builder: (context) => _SupplierSelectDialog(suppliers: suppliers),
    );

    if (selected != null) {
      controller.selectSupplier(selected.id);
    }
  }

  Future<void> _showAccountDialog(SupplyNotifier controller) async {
    final accounts = await controller.getAccounts();

    if (!mounted) return;

    final selected = await showDialog<AccountItem>(
      context: context,
      builder: (context) => _AccountSelectDialog(accounts: accounts),
    );

    if (selected != null) {
      controller.selectAccount(selected.id);
    }
  }

  Future<void> _onBarcodeEntered(
    SupplyNotifier controller,
    String barcode,
  ) async {
    if (barcode.isEmpty) return;

    final product = await controller.findProductByBarcode(barcode);

    if (product == null) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.supplyProductNotFound),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final result = await showDialog<_AddProductResult>(
      context: context,
      builder: (context) =>
          _AddProductDialog(product: product, serialTracking: _serialTracking),
    );

    if (result != null) {
      controller.addProduct(
        ucode: product.ucode,
        quantity: result.quantity,
        price: result.price,
        serialNumbers: result.serialNumbers,
      );
      _barcodeController.clear();
    }
  }

  Future<void> _showEditProductDialog(
    SupplyNotifier controller,
    SupplyProductInfo product,
  ) async {
    final result = await showDialog<_AddProductResult>(
      context: context,
      builder: (context) =>
          _EditProductDialog(product: product, serialTracking: _serialTracking),
    );

    if (result != null) {
      controller.updateProduct(
        ucode: product.ucode,
        quantity: result.quantity,
        price: result.price,
        serialNumbers: result.serialNumbers,
      );
    }
  }
}

class _PaymentTypeOption extends StatelessWidget {
  const _PaymentTypeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? selectedSurfaceOf(context) : Colors.transparent,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductListItem extends StatelessWidget {
  const _ProductListItem({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final SupplyProductInfo product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName ??
                      l10n.supplyProductNumber(product.ucode.toString()),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.quantity} × ${product.price.toStringAsFixed(2)} = ${product.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: selectedSurfaceOf(context),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onEdit,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.edit, size: 24, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onDelete,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.delete,
                  size: 24,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierSelectDialog extends StatefulWidget {
  const _SupplierSelectDialog({required this.suppliers});

  final List<SupplierItem> suppliers;

  @override
  State<_SupplierSelectDialog> createState() => _SupplierSelectDialogState();
}

class _SupplierSelectDialogState extends State<_SupplierSelectDialog> {
  late List<SupplierItem> _suppliers;

  @override
  void initState() {
    super.initState();
    _suppliers = List.from(widget.suppliers);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.supplySelectSupplierTitle)),
          IconButton(
            icon: const Icon(TeleposIcons.add, color: AppColors.primary),
            tooltip: '${l10n.globalNew} ${l10n.agentTypeSupplier}',
            onPressed: () async {
              final result = await showDialog<AgentItem>(
                context: context,
                builder: (_) =>
                    const AddCustomerDialog(initialType: AgentType.supplier),
              );
              if (result != null) {
                final newSupplier = SupplierItem(
                  id: result.localId,
                  name: result.name,
                  phone: result.phone,
                );
                setState(() => _suppliers.add(newSupplier));
                if (context.mounted) {
                  Navigator.of(context).pop(newSupplier);
                }
              }
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        height: 400,
        child: _suppliers.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.supplySuppliersNotFound),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await showDialog<AgentItem>(
                          context: context,
                          builder: (_) => const AddCustomerDialog(
                            initialType: AgentType.supplier,
                          ),
                        );
                        if (result != null && context.mounted) {
                          Navigator.of(context).pop(
                            SupplierItem(
                              id: result.localId,
                              name: result.name,
                              phone: result.phone,
                            ),
                          );
                        }
                      },
                      icon: const Icon(TeleposIcons.add),
                      label: Text(
                        '${l10n.globalNew} ${l10n.agentTypeSupplier}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = _suppliers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.local_shipping,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(supplier.name),
                    subtitle: supplier.phone != null
                        ? Text(supplier.phone!)
                        : null,
                    onTap: () => Navigator.of(context).pop(supplier),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
      ],
    );
  }
}

class _AccountSelectDialog extends StatelessWidget {
  const _AccountSelectDialog({required this.accounts});

  final List<AccountItem> accounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.supplySelectAccountTitle),
      content: SizedBox(
        width: 300,
        height: 300,
        child: accounts.isEmpty
            ? Center(child: Text(l10n.supplyAccountsNotFound))
            : ListView.builder(
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  return ListTile(
                    title: Text(account.name),
                    subtitle: Text(
                      l10n.supplyAccountBalance(
                        account.balance.toStringAsFixed(2),
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(account),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
      ],
    );
  }
}

class _AddProductResult {
  const _AddProductResult({
    required this.quantity,
    required this.price,
    this.serialNumbers,
  });

  final Decimal quantity;
  final Decimal price;

  final List<String>? serialNumbers;
}

class _SerialNumbersInput extends StatefulWidget {
  const _SerialNumbersInput({
    required this.expectedCount,
    required this.serials,
    required this.onChanged,
  });

  final int expectedCount;

  final List<String> serials;

  final ValueChanged<List<String>> onChanged;

  @override
  State<_SerialNumbersInput> createState() => _SerialNumbersInputState();
}

class _SerialNumbersInputState extends State<_SerialNumbersInput> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _addSerial() {
    final value = _ctrl.text.trim();
    if (value.isEmpty) return;
    if (widget.serials.contains(value)) {
      _ctrl.clear();
      _focus.requestFocus();
      return;
    }
    final updated = [...widget.serials, value];
    widget.onChanged(updated);
    _ctrl.clear();
    _focus.requestFocus();
  }

  void _removeSerial(int index) {
    final updated = [...widget.serials]..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = widget.serials.length;
    final mismatch = count != widget.expectedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.qr_code_2, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              l10n.supplySerialNumbers,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              l10n.supplySerialCount(count, widget.expectedCount),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: mismatch ? AppColors.warning : AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.supplySerialHint,
                  prefixIcon: const Icon(Icons.tag, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _addSerial(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addSerial,
              icon: const Icon(TeleposIcons.add),
              tooltip: l10n.globalAdd,
            ),
          ],
        ),
        if (widget.serials.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < widget.serials.length; i++)
                Chip(
                  label: Text(
                    widget.serials[i],
                    style: const TextStyle(fontSize: 12),
                  ),
                  onDeleted: () => _removeSerial(i),
                  deleteIcon: const Icon(TeleposIcons.close, size: 16),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        if (mismatch) ...[
          const SizedBox(height: 6),
          Text(
            l10n.supplySerialMismatch,
            style: const TextStyle(fontSize: 11, color: AppColors.warning),
          ),
        ],
      ],
    );
  }
}

class _AddProductDialog extends StatefulWidget {
  const _AddProductDialog({required this.product, this.serialTracking = false});

  final ProductSearchResult product;

  final bool serialTracking;

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  String _quantity = '1';
  String _price = '';
  _ActiveField _activeField = _ActiveField.quantity;
  List<String> _serials = const [];

  @override
  void initState() {
    super.initState();
    _price = widget.product.price.toStringAsFixed(2);
  }

  int get _expectedSerialCount => (Decimal.tryParse(_quantity) ?? Decimal.zero)
      .truncate()
      .toBigInt()
      .toInt();

  String get _activeValue =>
      _activeField == _ActiveField.quantity ? _quantity : _price;

  set _activeValue(String v) {
    if (_activeField == _ActiveField.quantity) {
      _quantity = v;
    } else {
      _price = v;
    }
  }

  void _onDigit(String d) => setState(() {
    _activeValue = _activeValue == '0' ? d : _activeValue + d;
  });

  void _onDot() => setState(() {
    if (!_activeValue.contains('.')) {
      _activeValue = _activeValue.isEmpty ? '0.' : '${_activeValue}.';
    }
  });

  void _onBackspace() => setState(() {
    if (_activeValue.isNotEmpty) {
      _activeValue = _activeValue.substring(0, _activeValue.length - 1);
    }
    if (_activeValue.isEmpty) _activeValue = '0';
  });

  void _onClear() => setState(() => _activeValue = '0');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      child: Container(
        width: 340,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - 80,
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.product.name,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              _buildFieldSelector(l10n),
              const SizedBox(height: 16),
              if (widget.serialTracking) ...[
                _SerialNumbersInput(
                  expectedCount: _expectedSerialCount,
                  serials: _serials,
                  onChanged: (v) => setState(() => _serials = v),
                ),
                const SizedBox(height: 16),
              ],
              _buildCalcGrid(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldSelector(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: _FieldDisplay(
            label: l10n.globalQuantity,
            value: _quantity,
            isActive: _activeField == _ActiveField.quantity,
            onTap: () => setState(() => _activeField = _ActiveField.quantity),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FieldDisplay(
            label: l10n.supplyPurchasePrice,
            value: _price,
            isActive: _activeField == _ActiveField.price,
            onTap: () => setState(() => _activeField = _ActiveField.price),
          ),
        ),
      ],
    );
  }

  Widget _buildCalcGrid(AppLocalizations l10n) {
    return _SupplyCalcKeypad(
      onDigit: _onDigit,
      onDot: _onDot,
      onBackspace: _onBackspace,
      onClear: _onClear,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () {
        final quantity = Decimal.tryParse(_quantity);
        final price = Decimal.tryParse(_price);
        if (quantity == null || quantity <= Decimal.zero) return;
        if (price == null || price < Decimal.zero) return;
        Navigator.of(context).pop(
          _AddProductResult(
            quantity: quantity,
            price: price,
            serialNumbers: widget.serialTracking && _serials.isNotEmpty
                ? _serials
                : null,
          ),
        );
      },
      confirmLabel: l10n.globalAdd,
    );
  }
}

class _EditProductDialog extends StatefulWidget {
  const _EditProductDialog({
    required this.product,
    this.serialTracking = false,
  });

  final SupplyProductInfo product;

  final bool serialTracking;

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  String _quantity = '';
  String _price = '';
  _ActiveField _activeField = _ActiveField.quantity;
  List<String> _serials = const [];

  @override
  void initState() {
    super.initState();
    _quantity = widget.product.quantity.toString();
    _price = widget.product.price.toStringAsFixed(2);
    _serials = widget.product.serialNumbers ?? const [];
  }

  int get _expectedSerialCount => (Decimal.tryParse(_quantity) ?? Decimal.zero)
      .truncate()
      .toBigInt()
      .toInt();

  String get _activeValue =>
      _activeField == _ActiveField.quantity ? _quantity : _price;

  set _activeValue(String v) {
    if (_activeField == _ActiveField.quantity) {
      _quantity = v;
    } else {
      _price = v;
    }
  }

  void _onDigit(String d) => setState(() {
    _activeValue = _activeValue == '0' ? d : _activeValue + d;
  });

  void _onDot() => setState(() {
    if (!_activeValue.contains('.')) {
      _activeValue = _activeValue.isEmpty ? '0.' : '${_activeValue}.';
    }
  });

  void _onBackspace() => setState(() {
    if (_activeValue.isNotEmpty) {
      _activeValue = _activeValue.substring(0, _activeValue.length - 1);
    }
    if (_activeValue.isEmpty) _activeValue = '0';
  });

  void _onClear() => setState(() => _activeValue = '0');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      child: Container(
        width: 340,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - 80,
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.product.productName ??
                    l10n.supplyProductNumber(widget.product.ucode.toString()),
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _FieldDisplay(
                      label: l10n.globalQuantity,
                      value: _quantity,
                      isActive: _activeField == _ActiveField.quantity,
                      onTap: () =>
                          setState(() => _activeField = _ActiveField.quantity),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FieldDisplay(
                      label: l10n.supplyPurchasePrice,
                      value: _price,
                      isActive: _activeField == _ActiveField.price,
                      onTap: () =>
                          setState(() => _activeField = _ActiveField.price),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.serialTracking) ...[
                _SerialNumbersInput(
                  expectedCount: _expectedSerialCount,
                  serials: _serials,
                  onChanged: (v) => setState(() => _serials = v),
                ),
                const SizedBox(height: 16),
              ],
              _SupplyCalcKeypad(
                onDigit: _onDigit,
                onDot: _onDot,
                onBackspace: _onBackspace,
                onClear: _onClear,
                onCancel: () => Navigator.of(context).pop(),
                onConfirm: () {
                  final quantity = Decimal.tryParse(_quantity);
                  final price = Decimal.tryParse(_price);
                  if (quantity == null || quantity <= Decimal.zero) return;
                  if (price == null || price < Decimal.zero) return;
                  Navigator.of(context).pop(
                    _AddProductResult(
                      quantity: quantity,
                      price: price,
                      serialNumbers:
                          widget.serialTracking && _serials.isNotEmpty
                          ? _serials
                          : null,
                    ),
                  );
                },
                confirmLabel: l10n.globalSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ActiveField { quantity, price }

class _FieldDisplay extends StatelessWidget {
  const _FieldDisplay({
    required this.label,
    required this.value,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? selectedSurfaceOf(context)
              : context.semantic.canvas,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? '0' : value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplyCalcKeypad extends StatelessWidget {
  const _SupplyCalcKeypad({
    required this.onDigit,
    required this.onDot,
    required this.onBackspace,
    required this.onClear,
    required this.onCancel,
    required this.onConfirm,
    required this.confirmLabel,
  });

  final void Function(String) onDigit;
  final VoidCallback onDot;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(context, ['7', '8', '9', 'C']),
        const SizedBox(height: 6),
        _row(context, ['4', '5', '6', '⌫']),
        const SizedBox(height: 6),
        _row(context, ['1', '2', '3', '.']),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(flex: 2, child: _btn(context, '0', () => onDigit('0'))),
            const SizedBox(width: 6),
            Expanded(
              child: _btn(
                context,
                AppLocalizations.of(context)!.globalCancel,
                onCancel,
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _btn(
                context,
                confirmLabel,
                onConfirm,
                fontSize: 13,
                bg: AppColors.primary,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // [context] прокинут: метод передаёт его дальше в `_btn`.
  Widget _row(BuildContext context, List<String> keys) {
    return Row(
      children: keys.asMap().entries.map((e) {
        final key = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key > 0 ? 6 : 0),
            child: _btn(
              context,
              key,
              () {
                switch (key) {
                  case 'C':
                    onClear();
                  case '⌫':
                    onBackspace();
                  case '.':
                    onDot();
                  default:
                    onDigit(key);
                }
              },
              color: (key == 'C' || key == '⌫')
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  // [context] прокинут явно: подложка клавиши берётся ролью темы, а роль
  // без контекста не достать. Пока цвет был константой, метод обходился.
  Widget _btn(
    BuildContext context,
    String label,
    VoidCallback onTap, {
    Color? color,
    Color? bg,
    double? fontSize,
  }) {
    return Material(
      color: bg ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize ?? 20,
              fontWeight: FontWeight.w600,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
