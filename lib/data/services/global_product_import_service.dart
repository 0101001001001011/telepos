import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/category_dao.dart';
import 'package:telepos/data/database/daos/global_product_dao.dart';
import 'package:telepos/data/database/daos/product_info_dao.dart';
import 'package:telepos/data/database/daos/product_price_dao.dart';

class GlobalProductImportService {
  GlobalProductImportService(
    this._dao,
    this._categoryDao,
    this._productInfoDao,
    this._productPriceDao,
  );

  final GlobalProductDao _dao;
  final CategoryDao _categoryDao;
  final ProductInfoDao _productInfoDao;
  final ProductPriceDao _productPriceDao;

  static const int _batchSize = 1000;

  static const String _catalogFileName = 'global_product.json';

  static const String _assetPath = 'assets/data/$_catalogFileName';

  static const int _minExpectedProducts = 100000;

  Future<bool> needsImport() async {
    final globalCount = await _dao.count();
    if (globalCount < _minExpectedProducts) return true;

    final infoCount = await _productInfoDao.count();
    if (infoCount < _minExpectedProducts) return true;

    return false;
  }

  Future<int> import({
    void Function(double progress, String message)? onProgress,
    String? fromFile,
  }) async {
    onProgress?.call(0.0, 'Проверка каталога...');

    if (!await needsImport()) {
      final count = await _dao.count();
      onProgress?.call(1.0, 'Каталог уже загружен: $count товаров');
      return count;
    }

    final globalCount = await _dao.count();
    if (globalCount >= _minExpectedProducts) {
      final infoCount = await _productInfoDao.count();
      if (infoCount < _minExpectedProducts) {
        onProgress?.call(0.5, 'Восстановление каталога товаров...');
        try {
          final jsonString = await _loadJson(fromFile);
          final products = await _parseJsonInIsolate(jsonString);
          await _productPriceDao.deleteAll();
          await _productInfoDao.deleteAll();
          await _populateProductInfos(products, onProgress);
          onProgress?.call(1.0, 'Каталог восстановлен: $globalCount товаров');
          return globalCount;
        } catch (e) {
          onProgress?.call(0.0, 'Ошибка восстановления: ${safeErrorText(e)}');
        }
      }
    }

    final existingCount = await _dao.count();
    if (existingCount > 0) {
      onProgress?.call(0.02, 'Очистка незавершённого импорта...');
      await _productPriceDao.deleteAll();
      await _productInfoDao.deleteAll();
      await _dao.deleteAll();
    }

    onProgress?.call(0.05, 'Загрузка JSON...');

    String jsonString;
    try {
      jsonString = await _loadJson(fromFile);
    } catch (e) {
      onProgress?.call(0.0, 'Ошибка загрузки: ${safeErrorText(e)}');
      rethrow;
    }

    onProgress?.call(0.1, 'Парсинг JSON...');

    final List<Map<String, dynamic>> products;
    try {
      products = await _parseJsonInIsolate(jsonString);
    } catch (e) {
      onProgress?.call(0.0, 'Ошибка парсинга: ${safeErrorText(e)}');
      rethrow;
    }

    final totalProducts = products.length;
    onProgress?.call(0.15, 'Найдено $totalProducts товаров');

    onProgress?.call(0.17, 'Создание категорий...');
    await _createCategoriesFromProducts(products);

    onProgress?.call(0.2, 'Импорт товаров...');

    int imported = 0;
    final batches = (totalProducts / _batchSize).ceil();

    for (int i = 0; i < batches; i++) {
      final start = i * _batchSize;
      final end = (start + _batchSize).clamp(0, totalProducts);
      final batch = products.sublist(start, end);

      final companions = _convertBatch(batch);

      await _dao.insertBulk(companions);

      imported += companions.length;

      final progress = 0.2 + (0.75 * imported / totalProducts);
      onProgress?.call(progress, 'Импорт: $imported / $totalProducts');

      await Future.delayed(Duration.zero);
    }

    onProgress?.call(0.95, 'Создание каталога товаров...');
    await _populateProductInfos(products, onProgress);

    onProgress?.call(1.0, 'Импорт завершён: $imported товаров');
    return imported;
  }

  Future<String> _loadJson(String? filePath) async {
    if (filePath != null) {
      final file = File(filePath);
      if (await file.exists()) {
        return file.readAsString();
      }
      throw FileSystemException('Файл не найден', filePath);
    }

    if (!kIsWeb) {
      try {
        final byteData = await rootBundle.load(_assetPath);
        return utf8.decode(byteData.buffer.asUint8List());
      } catch (_) {}
    }

    if (!kIsWeb) {
      final paths = await _getSearchPaths();
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) {
          return file.readAsString();
        }
      }
    }

    throw Exception(
      'Каталог товаров не найден. '
      'Поместите $_catalogFileName в assets/data/ или docs/products/',
    );
  }

  Future<List<String>> _getSearchPaths() async {
    final paths = <String>[];

    paths.add('docs/products/$_catalogFileName');
    paths.add('assets/data/$_catalogFileName');

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      paths.add(p.join(docsDir.path, 'telepos', _catalogFileName));
    } catch (_) {}

    try {
      final supportDir = await getApplicationSupportDirectory();
      paths.add(p.join(supportDir.path, _catalogFileName));
    } catch (_) {}

    return paths;
  }

  Future<List<Map<String, dynamic>>> _parseJsonInIsolate(
    String jsonString,
  ) async {
    if (kIsWeb) {
      final decoded = jsonDecode(jsonString);
      return List<Map<String, dynamic>>.from(decoded as List);
    }

    return compute(_parseJson, jsonString);
  }

  static List<Map<String, dynamic>> _parseJson(String jsonString) {
    final decoded = jsonDecode(jsonString);
    return List<Map<String, dynamic>>.from(decoded as List);
  }

  List<GlobalProductsCompanion> _convertBatch(
    List<Map<String, dynamic>> batch,
  ) {
    return batch
        .map((json) {
          final codeValue = json['code'];
          final int code;
          if (codeValue is int) {
            code = codeValue;
          } else if (codeValue is String) {
            code = int.tryParse(codeValue) ?? 0;
          } else {
            code = 0;
          }

          final arrivalCost = _parseDecimal(json['arrivalCost']);
          final sellingPrice = _parseDecimal(json['sellingPrice']);

          final editTimeStr = json['editTime'] as String?;
          final editTime = editTimeStr != null
              ? DateTime.tryParse(editTimeStr) ?? DateTime.now()
              : DateTime.now();

          final categoryId = json['categoryId'] as int?;

          return GlobalProductsCompanion(
            code: Value(code),
            name: Value(json['name'] as String? ?? 'Без названия'),
            arrivalCost: Value(arrivalCost),
            sellingPrice: Value(sellingPrice),
            editTime: Value(editTime),
            categoryId: categoryId != null && categoryId > 0
                ? Value(categoryId)
                : const Value.absent(),
          );
        })
        .where((c) => c.code.value > 0)
        .toList();
  }

  Future<void> _createCategoriesFromProducts(
    List<Map<String, dynamic>> products,
  ) async {
    final categoryIds = <int>{};
    for (final p in products) {
      final cid = p['categoryId'] as int?;
      if (cid != null && cid > 0) {
        categoryIds.add(cid);
      }
    }

    if (categoryIds.isEmpty) return;

    final now = DateTime.now();
    for (final id in categoryIds) {
      await _categoryDao.upsertCategory(id: id, createTime: now);
    }
  }

  Future<void> _populateProductInfos(
    List<Map<String, dynamic>> products,
    void Function(double progress, String message)? onProgress,
  ) async {
    if (await _productInfoDao.hasAny()) return;

    final now = DateTime.now();
    int ucode = 2000000001;
    int processed = 0;
    final total = products.length;

    final infoBatch = <ProductInfosCompanion>[];
    final priceBatch = <ProductPricesCompanion>[];

    for (final json in products) {
      final codeValue = json['code'];
      final int code;
      if (codeValue is int) {
        code = codeValue;
      } else if (codeValue is String) {
        code = int.tryParse(codeValue) ?? 0;
      } else {
        code = 0;
      }
      if (code <= 0) continue;

      final categoryId = json['categoryId'] as int?;
      final sellingPrice = _parseDecimal(json['sellingPrice']);
      final arrivalCost = _parseDecimal(json['arrivalCost']);

      infoBatch.add(
        ProductInfosCompanion(
          ucode: Value(ucode),
          barcode: Value(code),
          name: Value(json['name'] as String? ?? 'Без названия'),
          categoryId: categoryId != null && categoryId > 0
              ? Value(categoryId)
              : const Value.absent(),
          type: const Value(0),
          measure: const Value(0),
          isDeleted: const Value(true),
          localEditTime: Value(now),
        ),
      );

      priceBatch.add(
        ProductPricesCompanion(
          ucode: Value(ucode),
          barcode: Value(code),
          sellingPrice: Value(sellingPrice),
          wholesalePrice: Value(arrivalCost),
          editTime: Value(now),
        ),
      );

      ucode++;
      processed++;

      if (infoBatch.length >= _batchSize) {
        await _productInfoDao.insertBulk(infoBatch);
        await _productPriceDao.insertBulk(priceBatch);
        infoBatch.clear();
        priceBatch.clear();

        final progress = 0.95 + (0.04 * processed / total);
        onProgress?.call(progress, 'Каталог: $processed / $total');
        await Future.delayed(Duration.zero);
      }
    }

    if (infoBatch.isNotEmpty) {
      await _productInfoDao.insertBulk(infoBatch);
      await _productPriceDao.insertBulk(priceBatch);
    }
  }

  Decimal _parseDecimal(dynamic value) {
    if (value == null) return Decimal.zero;
    if (value is int) return Decimal.fromInt(value);
    if (value is double) return Decimal.parse(value.toStringAsFixed(3));
    if (value is String) return Decimal.tryParse(value) ?? Decimal.zero;
    return Decimal.zero;
  }

  Future<int> reimport({
    void Function(double progress, String message)? onProgress,
    String? fromFile,
  }) async {
    onProgress?.call(0.0, 'Очистка каталога...');
    await _productPriceDao.deleteAll();
    await _productInfoDao.deleteAll();
    await _dao.deleteAll();
    return import(onProgress: onProgress, fromFile: fromFile);
  }
}
