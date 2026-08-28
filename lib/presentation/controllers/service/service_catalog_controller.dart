import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/service/service_type_entity.dart';
import 'package:telepos/domain/usecases/product/create_product_info_use_case.dart';
import 'package:telepos/domain/usecases/product/create_product_price_use_case.dart';
import 'package:telepos/domain/usecases/service/manage_service_types_use_case.dart';

@immutable
class ServiceCatalogItem {
  const ServiceCatalogItem({
    this.serviceType,
    required this.productUcode,
    required this.name,
    required this.price,
    this.isQuick = false,
  });

  final ServiceTypeEntity? serviceType;
  final int productUcode;
  final String name;
  final Decimal price;
  final bool isQuick;

  int? get id => serviceType?.id;
  int? get estimatedDurationMinutes => serviceType?.estimatedDurationMinutes;
  int? get warrantyDays => serviceType?.warrantyDays;
  bool get requiresDevice => serviceType?.requiresDevice ?? false;
  bool get isActive => serviceType?.isActive ?? true;
  bool get hasMetadata => serviceType != null;
}

@immutable
class ProductSearchItem {
  const ProductSearchItem({
    required this.ucode,
    required this.name,
    required this.price,
  });

  final int ucode;
  final String name;
  final Decimal price;
}

@immutable
class ServiceCatalogState {
  const ServiceCatalogState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ServiceCatalogItem> items;
  final bool isLoading;
  final String? error;

  bool get hasError => error != null;
  bool get isEmpty => items.isEmpty && !isLoading;

  ServiceCatalogState copyWith({
    List<ServiceCatalogItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ServiceCatalogState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ServiceCatalogNotifier extends Notifier<ServiceCatalogState> {
  Talker get _logger => GetIt.I<Talker>();
  AppDatabase get _db => GetIt.I<AppDatabase>();
  ManageServiceTypesUseCase get _manageUseCase =>
      GetIt.I<ManageServiceTypesUseCase>();

  @override
  ServiceCatalogState build() {
    Future.microtask(loadServiceTypes);
    return const ServiceCatalogState();
  }

  Future<void> loadServiceTypes() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final products = await _db.productInfoDao.findAll(
        type: 4,
        includeDeleted: false,
        limit: 1000,
        offset: 0,
      );

      final items = <ServiceCatalogItem>[];

      for (final p in products) {
        final priceRow = await _db.productPriceDao.findByUcode(p.ucode);
        final serviceType = await _db.serviceTypeDao.findByProductUcode(
          p.ucode,
        );
        final quickProduct = await _db.quickProductDao.findByUcode(p.ucode);

        items.add(
          ServiceCatalogItem(
            serviceType: serviceType != null
                ? ServiceTypeEntity(
                    id: serviceType.id,
                    productUcode: serviceType.productUcode,
                    estimatedDurationMinutes:
                        serviceType.estimatedDurationMinutes,
                    warrantyDays: serviceType.warrantyDays,
                    requiresDevice: serviceType.requiresDevice,
                    isActive: serviceType.isActive,
                  )
                : null,
            productUcode: p.ucode,
            name: p.name,
            price: priceRow?.sellingPrice ?? Decimal.zero,
            isQuick: quickProduct != null,
          ),
        );
      }

      state = state.copyWith(items: items, isLoading: false);
      _logger.debug('Loaded ${items.length} service catalog items');
    } catch (e) {
      _logger.error('Failed to load service catalog: $e');
      state = state.copyWith(isLoading: false, error: 'error.load_failed');
    }
  }

  Future<bool> createServiceProduct({
    required String name,
    required Decimal price,
    int? estimatedDurationMinutes,
    int? warrantyDays,
    bool requiresDevice = false,
  }) async {
    try {
      final createProductInfo = GetIt.I<CreateProductInfoUseCase>();
      final createProductPrice = GetIt.I<CreateProductPriceUseCase>();

      final barcode = await createProductInfo.generateBarcode();
      final ucode = await createProductInfo.create(
        barcode: barcode,
        name: name,
        type: 4,
        measure: 0,
      );

      await createProductPrice.create(
        ucode: ucode,
        barcode: barcode,
        sellingPrice: price,
      );

      if (estimatedDurationMinutes != null ||
          warrantyDays != null ||
          requiresDevice) {
        await _manageUseCase.create(
          productUcode: ucode,
          estimatedDurationMinutes: estimatedDurationMinutes,
          warrantyDays: warrantyDays,
          requiresDevice: requiresDevice,
        );
      }

      await loadServiceTypes();
      return true;
    } catch (e) {
      _logger.error('Failed to create service product: $e');
      state = state.copyWith(error: 'error.save_failed');
      return false;
    }
  }

  Future<bool> updateServiceMeta({
    required int productUcode,
    int? estimatedDurationMinutes,
    int? warrantyDays,
    bool requiresDevice = false,
  }) async {
    try {
      final existing = await _db.serviceTypeDao.findByProductUcode(
        productUcode,
      );
      if (existing != null) {
        await _manageUseCase.update(
          ServiceTypeEntity(
            id: existing.id,
            productUcode: productUcode,
            estimatedDurationMinutes: estimatedDurationMinutes,
            warrantyDays: warrantyDays,
            requiresDevice: requiresDevice,
          ),
        );
      } else {
        await _manageUseCase.create(
          productUcode: productUcode,
          estimatedDurationMinutes: estimatedDurationMinutes,
          warrantyDays: warrantyDays,
          requiresDevice: requiresDevice,
        );
      }
      await loadServiceTypes();
      return true;
    } catch (e) {
      _logger.error('Failed to update service meta: $e');
      state = state.copyWith(error: 'error.save_failed');
      return false;
    }
  }

  Future<bool> deleteService(int ucode) async {
    try {
      await _db.productInfoDao.softDelete(ucode);
      await loadServiceTypes();
      return true;
    } catch (e) {
      _logger.error('Failed to delete service: $e');
      state = state.copyWith(error: 'error.delete_failed');
      return false;
    }
  }

  Future<bool> toggleQuick(int ucode, String name) async {
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
      await loadServiceTypes();
      return true;
    } catch (e) {
      _logger.error('Failed to toggle quick: $e');
      return false;
    }
  }

  Future<List<ProductSearchItem>> searchProducts(String query) async {
    try {
      final products = await _db.productInfoDao.findByNamePart('%$query%');
      final items = <ProductSearchItem>[];

      for (final p in products) {
        if (p.type != 4) continue;
        if (p.isDeleted) continue;
        final priceRow = await _db.productPriceDao.findByUcode(p.ucode);
        items.add(
          ProductSearchItem(
            ucode: p.ucode,
            name: p.name,
            price: priceRow?.sellingPrice ?? Decimal.zero,
          ),
        );
      }

      return items;
    } catch (e) {
      _logger.error('Failed to search products: $e');
      return [];
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<List<ConsumableRow>> loadConsumables(int serviceProductUcode) async {
    try {
      final rows = await _db.serviceConsumableDao.findByService(
        serviceProductUcode,
      );
      final result = <ConsumableRow>[];
      for (final row in rows) {
        final info = await _db.productInfoDao.findByUcode(row.consumableUcode);
        final price = await _db.productPriceDao.findByUcode(
          row.consumableUcode,
        );
        result.add(
          ConsumableRow(
            id: row.id,
            consumableUcode: row.consumableUcode,
            name: info?.name ?? 'N/A',
            price: price?.sellingPrice ?? Decimal.zero,
            quantity: row.quantity,
          ),
        );
      }
      return result;
    } catch (e) {
      _logger.error('Failed to load consumables: $e');
      return [];
    }
  }

  Future<bool> addConsumable({
    required int serviceProductUcode,
    required int consumableUcode,
    required Decimal quantity,
  }) async {
    try {
      await _db.serviceConsumableDao.insert(
        ServiceConsumablesCompanion(
          serviceProductUcode: Value(serviceProductUcode),
          consumableUcode: Value(consumableUcode),
          quantity: Value(quantity),
        ),
      );
      return true;
    } catch (e) {
      _logger.error('Failed to add consumable: $e');
      return false;
    }
  }

  Future<bool> removeConsumable(int id) async {
    try {
      await _db.serviceConsumableDao.deleteById(id);
      return true;
    } catch (e) {
      _logger.error('Failed to remove consumable: $e');
      return false;
    }
  }
}

class ConsumableRow {
  const ConsumableRow({
    required this.id,
    required this.consumableUcode,
    required this.name,
    required this.price,
    required this.quantity,
  });

  final int id;
  final int consumableUcode;
  final String name;
  final Decimal price;
  final Decimal quantity;

  Decimal get totalCost => price * quantity;
}

final serviceCatalogProvider =
    NotifierProvider<ServiceCatalogNotifier, ServiceCatalogState>(
      ServiceCatalogNotifier.new,
    );
