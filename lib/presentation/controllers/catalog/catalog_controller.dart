import 'package:telepos/core/platform/local_file.dart';

import 'package:decimal/decimal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/create_product_info_use_case.dart';
import 'package:telepos/domain/usecases/product/create_product_price_use_case.dart';
import 'package:telepos/domain/usecases/product/product_info_and_price_edition_use_case.dart';
import 'package:telepos/domain/usecases/product/restore_product_info_use_case.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';

@immutable
class CatalogItem {
  const CatalogItem({
    required this.ucode,
    required this.name,
    required this.barcode,
    required this.type,
    required this.measure,
    required this.sellingPrice,
    this.wholesalePrice,
    this.quantity,
    this.categoryId,
    this.description,
    this.imagePath,
    this.isQuickProduct = false,
    this.isDeleted = false,
    this.vatRate,
    this.ntin,
    this.isMarkable = false,
    this.brand,
    this.manufacturer,
    this.countryOfOrigin,
  });

  final int ucode;
  final String name;
  final int barcode;
  final int type;
  final int measure;
  final Decimal sellingPrice;
  final Decimal? wholesalePrice;
  final Decimal? quantity;
  final int? categoryId;
  final String? description;
  final String? imagePath;
  final bool isQuickProduct;
  final bool isDeleted;

  final int? vatRate;

  final String? ntin;

  final bool isMarkable;

  final String? brand;

  final String? manufacturer;

  final String? countryOfOrigin;

  String get typeName => switch (type) {
    0 => 'normal',
    1 => 'weight',
    2 => 'inner',
    3 => 'package',
    4 => 'service',
    5 => 'consumable',
    6 => 'dish',
    _ => 'unknown',
  };
}

@immutable
class CategoryInfo {
  const CategoryInfo({
    required this.id,
    required this.name,
    this.parentId,
    this.childCount = 0,
    this.productCount = 0,
  });

  final int id;
  final String name;
  final int? parentId;
  final int childCount;
  final int productCount;
}

@immutable
class ImportResult {
  const ImportResult({
    this.imported = 0,
    this.updated = 0,
    this.skipped = 0,
    this.errors = const [],
  });

  final int imported;
  final int updated;
  final int skipped;
  final List<String> errors;

  int get total => imported + updated + skipped;
}

@immutable
class CatalogState {
  const CatalogState({
    this.items = const [],
    this.categories = const [],
    this.selectedCategoryId,
    this.selectedType,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
    this.totalCount = 0,
    this.currentPage = 0,
    this.includeDeleted = false,
    this.sortColumn = 'name',
    this.sortAscending = true,
    this.columnFilters = const {},
  });

  final List<CatalogItem> items;
  final List<CategoryInfo> categories;
  final int? selectedCategoryId;
  final int? selectedType;
  final String searchQuery;
  final bool isLoading;
  final String? error;
  final int totalCount;
  final int currentPage;
  final bool includeDeleted;
  final String sortColumn;
  final bool sortAscending;
  final Map<String, String> columnFilters;

  static const int pageSize = 50;

  int get totalPages => (totalCount / pageSize).ceil();
  bool get hasNextPage => currentPage < totalPages - 1;
  bool get hasPrevPage => currentPage > 0;

  List<CatalogItem> get filteredItems {
    var result = List<CatalogItem>.from(items);

    for (final entry in columnFilters.entries) {
      final filter = entry.value.toLowerCase().trim();
      if (filter.isEmpty) continue;

      result = result.where((item) {
        return switch (entry.key) {
          'name' => item.name.toLowerCase().contains(filter),
          'barcode' => '${item.barcode}'.contains(filter),
          'type' => item.typeName.toLowerCase().contains(filter),
          'price' => '${item.sellingPrice}'.contains(filter),
          'quantity' => '${item.quantity ?? 0}'.contains(filter),
          _ => true,
        };
      }).toList();
    }

    result.sort((a, b) {
      int cmp;
      switch (sortColumn) {
        case 'name':
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'barcode':
          cmp = a.barcode.compareTo(b.barcode);
        case 'type':
          cmp = a.type.compareTo(b.type);
        case 'price':
          cmp = a.sellingPrice.compareTo(b.sellingPrice);
        case 'quantity':
          final aq = a.quantity ?? Decimal.zero;
          final bq = b.quantity ?? Decimal.zero;
          cmp = aq.compareTo(bq);
        default:
          cmp = 0;
      }
      return sortAscending ? cmp : -cmp;
    });

    return result;
  }

  CatalogState copyWith({
    List<CatalogItem>? items,
    List<CategoryInfo>? categories,
    int? selectedCategoryId,
    int? selectedType,
    String? searchQuery,
    bool? isLoading,
    String? error,
    int? totalCount,
    int? currentPage,
    bool? includeDeleted,
    bool clearCategoryFilter = false,
    bool clearTypeFilter = false,
    bool clearError = false,
    String? sortColumn,
    bool? sortAscending,
    Map<String, String>? columnFilters,
  }) => CatalogState(
    items: items ?? this.items,
    categories: categories ?? this.categories,
    selectedCategoryId: clearCategoryFilter
        ? null
        : (selectedCategoryId ?? this.selectedCategoryId),
    selectedType: clearTypeFilter ? null : (selectedType ?? this.selectedType),
    searchQuery: searchQuery ?? this.searchQuery,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    totalCount: totalCount ?? this.totalCount,
    currentPage: currentPage ?? this.currentPage,
    includeDeleted: includeDeleted ?? this.includeDeleted,
    sortColumn: sortColumn ?? this.sortColumn,
    sortAscending: sortAscending ?? this.sortAscending,
    columnFilters: columnFilters ?? this.columnFilters,
  );
}

final catalogControllerProvider =
    NotifierProvider<CatalogNotifier, CatalogState>(CatalogNotifier.new);

class CatalogNotifier extends Notifier<CatalogState> {
  late AppDatabase _db;
  late CreateProductInfoUseCase _createProductInfo;
  late CreateProductPriceUseCase _createProductPrice;
  late ProductInfoAndPriceEditionUseCase _editProduct;
  late RestoreProductInfoUseCase _restoreProduct;

  int get _currentUserId => ref.read(currentUserIdProvider) ?? 0;

  @override
  CatalogState build() {
    _db = GetIt.I<AppDatabase>();
    _createProductInfo = GetIt.I<CreateProductInfoUseCase>();
    _createProductPrice = GetIt.I<CreateProductPriceUseCase>();
    _editProduct = GetIt.I<ProductInfoAndPriceEditionUseCase>();
    _restoreProduct = GetIt.I<RestoreProductInfoUseCase>();

    Future.microtask(() => loadProducts());
    return const CatalogState(isLoading: true);
  }

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final query = state.searchQuery.trim();

      List<ProductInfo> products;
      int totalCount;

      if (query.isNotEmpty) {
        products = await _db.productInfoDao.findByNamePart('%$query%');

        if (products.isEmpty) {
          final barcodeInt = int.tryParse(query);
          if (barcodeInt != null) {
            final byBarcode = await _db.productInfoDao.findByBarcode(query);
            if (byBarcode != null) products = [byBarcode];
          }
        }

        if (state.selectedType != null) {
          products = products
              .where((p) => p.type == state.selectedType)
              .toList();
        }
        if (!state.includeDeleted) {
          products = products.where((p) => !p.isDeleted).toList();
        }

        totalCount = products.length;
        final offset = state.currentPage * CatalogState.pageSize;
        if (offset < products.length) {
          products = products.sublist(
            offset,
            (offset + CatalogState.pageSize).clamp(0, products.length),
          );
        } else {
          products = [];
        }
      } else {
        totalCount = await _db.productInfoDao.countFiltered(
          type: state.selectedType,
          categoryId: state.selectedCategoryId,
          includeDeleted: state.includeDeleted,
        );

        products = await _db.productInfoDao.findAll(
          type: state.selectedType,
          categoryId: state.selectedCategoryId,
          includeDeleted: state.includeDeleted,
          limit: CatalogState.pageSize,
          offset: state.currentPage * CatalogState.pageSize,
        );
      }

      final items = <CatalogItem>[];
      for (final product in products) {
        final price = await _db.productPriceDao.findByUcode(product.ucode);
        final quickProduct = await _db.quickProductDao.findByUcode(
          product.ucode,
        );

        items.add(
          CatalogItem(
            ucode: product.ucode,
            name: product.name,
            barcode: product.barcode,
            type: product.type,
            measure: product.measure,
            sellingPrice: price?.sellingPrice ?? Decimal.zero,
            wholesalePrice: price?.wholesalePrice,
            quantity: product.quantity,
            categoryId: product.categoryId,
            description: product.description,
            imagePath: product.imagePath,
            isQuickProduct: quickProduct != null,
            isDeleted: product.isDeleted,
            vatRate: product.vatRate,
            ntin: product.ntin,
            isMarkable: product.isMarkable,
            brand: product.brand,
            manufacturer: product.manufacturer,
            countryOfOrigin: product.countryOfOrigin,
          ),
        );
      }

      final categories = await _loadCategories();

      state = state.copyWith(
        items: items,
        categories: categories,
        totalCount: totalCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<CategoryInfo>> _loadCategories() async {
    final cats = await _db.categoryDao.findAll();
    final result = <CategoryInfo>[];
    for (final c in cats) {
      final count = await _db.productInfoDao.countFiltered(
        categoryId: c.id,
        includeDeleted: state.includeDeleted,
      );
      result.add(
        CategoryInfo(
          id: c.id,
          name: c.name ?? 'Category #${c.id}',
          parentId: c.parentId,
          productCount: count,
        ),
      );
    }
    return result;
  }

  Future<void> searchProducts(String query) async {
    state = state.copyWith(searchQuery: query, currentPage: 0);
    await loadProducts();
  }

  Future<void> filterByCategory(int? categoryId) async {
    if (categoryId == null) {
      state = state.copyWith(clearCategoryFilter: true, currentPage: 0);
    } else {
      state = state.copyWith(selectedCategoryId: categoryId, currentPage: 0);
    }
    await loadProducts();
  }

  Future<void> filterByType(int? type) async {
    if (type == null) {
      state = state.copyWith(clearTypeFilter: true, currentPage: 0);
    } else {
      state = state.copyWith(selectedType: type, currentPage: 0);
    }
    await loadProducts();
  }

  Future<void> toggleShowDeleted() async {
    state = state.copyWith(
      includeDeleted: !state.includeDeleted,
      currentPage: 0,
    );
    await loadProducts();
  }

  void sort(String column, bool ascending) {
    state = state.copyWith(sortColumn: column, sortAscending: ascending);
  }

  void setColumnFilter(String column, String value) {
    final filters = Map<String, String>.from(state.columnFilters);
    if (value.isEmpty) {
      filters.remove(column);
    } else {
      filters[column] = value;
    }
    state = state.copyWith(columnFilters: filters);
  }

  Future<bool> createProduct({
    required String name,
    int? barcode,
    required int type,
    int measure = 0,
    required Decimal sellingPrice,
    Decimal? wholesalePrice,
    int? categoryId,
    String? description,
    String? imagePath,
    int? vatRate,
    String? ntin,
    bool isMarkable = false,
    String? brand,
    String? manufacturer,
    String? countryOfOrigin,
  }) async {
    try {
      final generatedBarcode =
          barcode ?? await _createProductInfo.generateBarcode();
      final ucode = await _createProductInfo.create(
        barcode: generatedBarcode,
        name: name,
        type: type,
        measure: measure,
        categoryId: categoryId,
        description: description,
        imagePath: imagePath,
        vatRate: vatRate,
        ntin: ntin,
        isMarkable: isMarkable,
        brand: brand,
        manufacturer: manufacturer,
        countryOfOrigin: countryOfOrigin,
      );

      await _createProductPrice.create(
        ucode: ucode,
        barcode: generatedBarcode,
        sellingPrice: sellingPrice,
        wholesalePrice: wholesalePrice,
      );

      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> editProduct({
    required int ucode,
    String? name,
    Decimal? price,
    Decimal? wholesalePrice,
    int? categoryId,
    int? type,
    int? measure,
    String? description,
    String? imagePath,
    int? vatRate,
    bool vatRateSet = false,
    String? ntin,
    bool? isMarkable,
    String? brand,
    String? manufacturer,
    String? countryOfOrigin,
  }) async {
    try {
      final pos = await _db.thisPosDao.get();
      if (pos != null && !pos.editProduct) {
        state = state.copyWith(
          error:
              'Действие запрещено настройками POS (Настройки → Политика продаж)',
        );
        return false;
      }
      await _editProduct.edit(
        ucode: ucode,
        userId: _currentUserId,
        name: name,
        price: price,
        categoryId: categoryId,
        type: type,
        measure: measure,
        vatRate: vatRate,
        vatRateSet: vatRateSet,
        ntin: ntin,
        isMarkable: isMarkable,
        brand: brand,
        manufacturer: manufacturer,
        countryOfOrigin: countryOfOrigin,
      );

      if (description != null || imagePath != null) {
        await _db.productInfoDao.updateDescriptionAndImage(
          ucode,
          description: description,
          imagePath: imagePath,
        );
      }

      if (wholesalePrice != null) {
        final currentPrice = await _db.productPriceDao.findByUcode(ucode);
        if (currentPrice != null) {
          await _db.productPriceDao.updatePrices(
            ucode,
            price ?? currentPrice.sellingPrice ?? Decimal.zero,
            wholesalePrice,
          );
        }
      }

      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteProduct(int ucode) async {
    try {
      await _db.productInfoDao.softDelete(ucode);
      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> restoreProduct(int ucode) async {
    try {
      await _restoreProduct.restore(ucode, userId: _currentUserId);
      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> toggleQuickProduct(int ucode, String name) async {
    try {
      final existing = await _db.quickProductDao.findByUcode(ucode);
      if (existing != null) {
        await _db.quickProductDao.removeQuickProduct(existing.id);
      } else {
        await _db.quickProductDao.addQuickProduct(
          ucode: ucode,
          orderName: name,
        );
      }
      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<void> nextPage() async {
    if (state.hasNextPage) {
      state = state.copyWith(currentPage: state.currentPage + 1);
      await loadProducts();
    }
  }

  Future<void> prevPage() async {
    if (state.hasPrevPage) {
      state = state.copyWith(currentPage: state.currentPage - 1);
      await loadProducts();
    }
  }

  Future<void> goToPage(int page) async {
    final last = state.totalPages > 0 ? state.totalPages - 1 : 0;
    final target = page.clamp(0, last);
    if (target == state.currentPage) return;
    state = state.copyWith(currentPage: target);
    await loadProducts();
  }

  Future<void> firstPage() => goToPage(0);

  Future<void> lastPage() =>
      goToPage(state.totalPages > 0 ? state.totalPages - 1 : 0);

  Future<String?> exportCsv() async {
    try {
      final allProducts = await _db.productInfoDao.findAll(
        type: state.selectedType,
        categoryId: state.selectedCategoryId,
        includeDeleted: state.includeDeleted,
        limit: 100000,
        offset: 0,
      );

      final buffer = StringBuffer();
      buffer.writeln(
        'Name,Barcode,Type,Measure,SellingPrice,WholesalePrice,Quantity,CategoryId',
      );

      for (final product in allProducts) {
        final price = await _db.productPriceDao.findByUcode(product.ucode);
        final sellingPrice = price?.sellingPrice ?? Decimal.zero;
        final wholesalePrice = price?.wholesalePrice ?? Decimal.zero;
        final quantity = product.quantity ?? Decimal.zero;

        final name = _escapeCsvField(product.name);
        buffer.writeln(
          '$name,${product.barcode},${product.type},${product.measure},$sellingPrice,$wholesalePrice,$quantity,${product.categoryId ?? ''}',
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final filePath = '${dir.path}/catalog_export_$timestamp.csv';
      await writeLocalString(filePath, buffer.toString());

      return filePath;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  Future<ImportResult> importCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) {
        return const ImportResult();
      }

      final filePath = result.files.single.path;
      if (filePath == null) return const ImportResult();

      final content = await readLocalString(filePath);
      final lines = content
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();

      if (lines.length < 2) {
        return const ImportResult(
          errors: ['File is empty or has no data rows'],
        );
      }

      int imported = 0;
      int updated = 0;
      int skipped = 0;
      final errors = <String>[];

      for (int i = 1; i < lines.length; i++) {
        try {
          final fields = _parseCsvLine(lines[i]);
          if (fields.length < 5) {
            skipped++;
            errors.add('Row ${i + 1}: not enough columns');
            continue;
          }

          final name = fields[0].trim();
          final barcode = int.tryParse(fields[1].trim());
          final type = int.tryParse(fields[2].trim()) ?? 0;
          final measure = int.tryParse(fields[3].trim()) ?? 0;
          final sellingPrice =
              Decimal.tryParse(fields[4].trim()) ?? Decimal.zero;
          final wholesalePrice = fields.length > 5
              ? Decimal.tryParse(fields[5].trim())
              : null;
          final categoryId = fields.length > 7
              ? int.tryParse(fields[7].trim())
              : null;

          if (name.isEmpty || barcode == null) {
            skipped++;
            errors.add('Row ${i + 1}: invalid name or barcode');
            continue;
          }

          final existing = await _db.productInfoDao.findByBarcode('$barcode');

          if (existing != null) {
            final currentPrice = await _db.productPriceDao.findByUcode(
              existing.ucode,
            );
            if (currentPrice != null) {
              await _db.productPriceDao.updatePrices(
                existing.ucode,
                sellingPrice,
                wholesalePrice ?? Decimal.zero,
              );
            }
            updated++;
          } else {
            final ucode = await _createProductInfo.create(
              barcode: barcode,
              name: name,
              type: type,
              measure: measure,
              categoryId: categoryId,
            );

            await _createProductPrice.create(
              ucode: ucode,
              barcode: barcode,
              sellingPrice: sellingPrice,
              wholesalePrice: wholesalePrice,
            );
            imported++;
          }
        } catch (e) {
          skipped++;
          errors.add('Row ${i + 1}: $e');
        }
      }

      await loadProducts();

      return ImportResult(
        imported: imported,
        updated: updated,
        skipped: skipped,
        errors: errors,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return ImportResult(errors: [e.toString()]);
    }
  }

  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    fields.add(buffer.toString());
    return fields;
  }
}
