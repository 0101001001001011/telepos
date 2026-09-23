import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/platform/local_file.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';
import 'package:telepos/presentation/screens/catalog/dialogs/dish_calculation_dialog.dart';

class ProductFormResult {
  const ProductFormResult({
    required this.name,
    this.barcode,
    required this.type,
    required this.measure,
    required this.sellingPrice,
    this.wholesalePrice,
    this.categoryId,
    this.description,
    this.imagePath,
    this.vatRate,
    this.taxCategoryId,
    this.ntin,
    this.isMarkable = false,
    this.brand,
    this.manufacturer,
    this.countryOfOrigin,
  });

  final String name;
  final int? barcode;
  final int type;
  final int measure;
  final Decimal sellingPrice;
  final Decimal? wholesalePrice;
  final int? categoryId;
  final String? description;
  final String? imagePath;

  final int? vatRate;

  /// Налоговая категория: по ней выводится ставка позиции в чеке.
  ///
  /// Отдельно от [vatRate] намеренно. [vatRate] — целое число для ЭСФ,
  /// один вход, одна страна. Категория — то, из чего движок выводит
  /// ставку по юрисдикции и дате: в Денвере еда для дома облагается
  /// городом и освобождена штатом, и целым числом это не выражается.
  final int? taxCategoryId;

  final String? ntin;

  final bool isMarkable;

  final String? brand;

  final String? manufacturer;

  final String? countryOfOrigin;
}

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({this.item, super.key});

  final CatalogItem? item;

  static Future<ProductFormResult?> show(
    BuildContext context, {
    CatalogItem? item,
  }) {
    return showDialog<ProductFormResult>(
      context: context,
      builder: (context) => ProductFormDialog(item: item),
    );
  }

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _priceController;
  late final TextEditingController _wholesalePriceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _ntinController;
  late final TextEditingController _brandController;
  late final TextEditingController _manufacturerController;
  late final TextEditingController _countryController;
  late int _selectedType;
  late int _selectedMeasure;
  int? _selectedVatRate;
  int? _selectedTaxCategoryId;

  /// Заведённые налоговые категории. Пусто — налоги не настроены, и поле
  /// не показывается вовсе: выбор из ничего это вопрос без ответа.
  List<TaxCategory> _taxCategories = const [];

  bool _isMarkable = false;
  String? _imagePath;

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _barcodeController = TextEditingController(
      text: item != null ? '${item.barcode}' : '',
    );
    _priceController = TextEditingController(
      text: item != null ? '${item.sellingPrice}' : '',
    );
    _wholesalePriceController = TextEditingController(
      text: item?.wholesalePrice != null ? '${item!.wholesalePrice}' : '',
    );
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _ntinController = TextEditingController(text: item?.ntin ?? '');
    _brandController = TextEditingController(text: item?.brand ?? '');
    _manufacturerController = TextEditingController(
      text: item?.manufacturer ?? '',
    );
    _countryController = TextEditingController(
      text: item?.countryOfOrigin ?? '',
    );
    _selectedType = item?.type ?? 0;
    _selectedMeasure = item?.measure ?? 0;
    _selectedVatRate = item?.vatRate;
    _selectedTaxCategoryId = item?.taxCategoryId;
    // `addPostFrameCallback`, не `initState`: правило дерева — чтение базы
    // из `initState` роняет диалоги на `InheritedWidget`.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final categories = await GetIt.I<AppDatabase>().taxSettingsDao
          .allCategories();
      if (mounted) setState(() => _taxCategories = categories);
    });
    _isMarkable = item?.isMarkable ?? false;
    _imagePath = item?.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _wholesalePriceController.dispose();
    _descriptionController.dispose();
    _ntinController.dispose();
    _brandController.dispose();
    _manufacturerController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isService = _selectedType == 4 || _selectedType == 5;

    return AlertDialog(
      title: Text(isEditing ? l10n.catalogEditProduct : l10n.catalogAddProduct),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: _imagePath != null && localFileExists(_imagePath!)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: localImage(
                              _imagePath!,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 36,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.catalogImagePlaceholder,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing),

                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.catalogProductName,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.label),
                  ),
                  autofocus: !isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.catalogNameRequired
                      : null,
                ),
                const SizedBox(height: AppTheme.spacing),

                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: l10n.catalogDescription,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppTheme.spacing),

                DropdownButtonFormField<int>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: l10n.catalogType,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(l10n.catalogTypeNormal),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(l10n.catalogTypeWeight),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(l10n.catalogTypePackage),
                    ),
                    DropdownMenuItem(
                      value: 4,
                      child: Text(l10n.catalogTypeService),
                    ),
                    DropdownMenuItem(
                      value: 5,
                      child: Text(l10n.catalogTypeConsumable),
                    ),
                    DropdownMenuItem(
                      value: 6,
                      child: Text(l10n.catalogTypeDish),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedType = v);
                  },
                ),
                const SizedBox(height: AppTheme.spacing),

                if (!isService) ...[
                  TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: l10n.catalogBarcode,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.qr_code),
                      hintText: isEditing ? null : l10n.prodBarcodeAutoHint,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: AppTheme.spacing),
                ],

                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: l10n.catalogPrice,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return l10n.catalogPriceRequired;
                    final parsed = Decimal.tryParse(v.trim());
                    if (parsed == null || parsed <= Decimal.zero) {
                      return l10n.catalogPriceInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacing),

                TextFormField(
                  controller: _wholesalePriceController,
                  decoration: InputDecoration(
                    labelText: l10n.catalogWholesalePrice,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.money),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing),

                DropdownButtonFormField<int>(
                  value: _selectedMeasure,
                  decoration: InputDecoration(
                    labelText: l10n.catalogMeasure,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.straighten),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(l10n.catalogMeasurePiece),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(l10n.catalogMeasureKg),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(l10n.catalogMeasureLiter),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(l10n.catalogMeasureMeter),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedMeasure = v);
                  },
                ),
                const SizedBox(height: AppTheme.spacing),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      l10n.prodCatalogAttributes,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),

                TextFormField(
                  controller: _brandController,
                  decoration: InputDecoration(
                    labelText: l10n.prodBrand,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.branding_watermark),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppTheme.spacing),

                TextFormField(
                  controller: _manufacturerController,
                  decoration: InputDecoration(
                    labelText: l10n.prodManufacturer,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.factory),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppTheme.spacing),

                TextFormField(
                  controller: _countryController,
                  decoration: InputDecoration(
                    labelText: l10n.prodCountryOfOrigin,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.public),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppTheme.spacing),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      l10n.prodFiscalAttributes,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),

                DropdownButtonFormField<int?>(
                  value: _selectedVatRate,
                  decoration: InputDecoration(
                    labelText: l10n.prodVatRate,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.percent),
                  ),
                  items: [
                    const DropdownMenuItem(value: 12, child: Text('12%')),
                    const DropdownMenuItem(value: 0, child: Text('0%')),
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.prodVatNone),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedVatRate = v),
                ),
                const SizedBox(height: AppTheme.spacing),

                // Категория показывается, только когда налоги заведены:
                // выбор из пустого списка — вопрос без ответа, а для кассы
                // с одной ставкой на страну категория ничего не решает.
                //
                // Соседство со ставкой ЭСФ выше не дублирование: то целое
                // число для фискального оператора, одна страна и один
                // вход. Здесь — то, из чего движок выводит ставку по
                // юрисдикции и дате.
                if (_taxCategories.isNotEmpty) ...[
                  DropdownButtonFormField<int?>(
                    key: const ValueKey('product-tax-category'),
                    // Название категории задаёт пользователь, и длину его
                    // никто не ограничивает. Без `isExpanded` «Food for home
                    // consumption» разрывает карточку на 96 пикселей.
                    isExpanded: true,
                    initialValue:
                        _taxCategories.any(
                          (c) => c.id == _selectedTaxCategoryId,
                        )
                        ? _selectedTaxCategoryId
                        : null,
                    decoration: InputDecoration(
                      labelText: l10n.taxSettingsCategories,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.sell_outlined),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.prodVatNone),
                      ),
                      for (final category in _taxCategories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(
                            category.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedTaxCategoryId = v),
                  ),
                  const SizedBox(height: AppTheme.spacing),
                ],

                TextFormField(
                  controller: _ntinController,
                  decoration: InputDecoration(
                    labelText: l10n.prodNtin,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.prodMarkable),
                  secondary: const Icon(Icons.qr_code_2),
                  value: _isMarkable,
                  onChanged: (v) => setState(() => _isMarkable = v),
                ),

                if (_selectedType == 6 && isEditing) ...[
                  const SizedBox(height: AppTheme.spacing),
                  OutlinedButton.icon(
                    onPressed: () => DishCalculationDialog.show(
                      context,
                      dishUcode: widget.item!.ucode,
                      dishName: _nameController.text,
                    ),
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: Text(l10n.dishCalculation),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      foregroundColor: Colors.deepOrange,
                      side: BorderSide(
                        color: Colors.deepOrange.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context)!;
    final hasImage = _imagePath != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.catalogImageFromGallery),
              onTap: () => Navigator.of(sheetCtx).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.catalogImageFromCamera),
              onTap: () => Navigator.of(sheetCtx).pop('camera'),
            ),
            if (hasImage)
              ListTile(
                leading: Icon(
                  TeleposIcons.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l10n.catalogImageRemove,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.of(sheetCtx).pop('remove'),
              ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == 'remove') {
      setState(() => _imagePath = null);
      return;
    }

    final source = choice == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _imagePath = picked.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.catalogImagePickError)));
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final barcodeText = _barcodeController.text.trim();
    final wholesaleText = _wholesalePriceController.text.trim();
    final descriptionText = _descriptionController.text.trim();
    final ntinText = _ntinController.text.trim();
    final brandText = _brandController.text.trim();
    final manufacturerText = _manufacturerController.text.trim();
    final countryText = _countryController.text.trim();

    final result = ProductFormResult(
      name: _nameController.text.trim(),
      barcode: barcodeText.isNotEmpty ? int.tryParse(barcodeText) : null,
      type: _selectedType,
      measure: _selectedMeasure,
      sellingPrice:
          Decimal.tryParse(_priceController.text.trim()) ?? Decimal.zero,
      wholesalePrice: wholesaleText.isNotEmpty
          ? Decimal.tryParse(wholesaleText)
          : null,
      description: descriptionText.isNotEmpty ? descriptionText : null,
      imagePath: _imagePath,
      vatRate: _selectedVatRate,
      taxCategoryId: _selectedTaxCategoryId,
      ntin: ntinText.isNotEmpty ? ntinText : null,
      isMarkable: _isMarkable,
      brand: brandText.isNotEmpty ? brandText : null,
      manufacturer: manufacturerText.isNotEmpty ? manufacturerText : null,
      countryOfOrigin: countryText.isNotEmpty ? countryText : null,
    );

    Navigator.of(context).pop(result);
  }
}
