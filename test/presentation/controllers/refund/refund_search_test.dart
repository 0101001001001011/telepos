import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';

/// Задача 18: поиск товара в возврате идёт через контракт, а не мимо него.
///
/// Настоящая база и настоящий `LocalCartService` под контрактом — подделка
/// доказала бы, что контроллер зовёт то, что мы велели ему звать, а доказать
/// надо другое: что кассир **находит товар по части имени**. Прежний код звал
/// `SearchProductInfoUseCase.search` сырой строкой, а тот ведёт к
/// `name.like(namePart)` без единого `%` — то есть поиск в возврате работал
/// только по точному имени целиком.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());

    await db
        .into(db.thisPosEntries)
        .insert(const ThisPosEntriesCompanion(id: Value(1)));
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: 4870001234567,
            name: 'Молоко 3.2%',
            type: 0,
            measure: 0,
            quantity: Value(Decimal.fromInt(10)),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(100),
            barcode: 4870001234567,
            sellingPrice: Value(Decimal.fromInt(500)),
          ),
        );

    final logger = Talker();
    // Контроллер возврата с задачи 20 пишет в общий журнал дерева
    // (`app_talker`) — например, когда рабочее место не разрешилось. Это
    // `late`-поле точки входа, и без установки любой такой путь падает
    // `LateInitializationError` вместо предупреждения.
    app_log.installLogger(logger);
    await GetIt.I.reset();
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<Talker>(logger);
    GetIt.I.registerSingleton<CartService>(
      LocalCartService(
        db: db,
        logger: logger,
        initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
        deferred: DeferredSaleServiceImpl(db: db, logger: logger),
        rounding: SaleRoundOptionUseCaseImpl(),
        findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
        searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
      ),
    );

    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await GetIt.I.reset();
    await db.close();
  });

  Future<RefundState> searchFor(String query) async {
    final notifier = container.read(refundControllerProvider.notifier);
    await notifier.search(query);
    // Задержка ввода экрана — 300 мс; ждём её и ответ.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return container.read(refundControllerProvider);
  }

  test(
    'товар находится по части имени, а не только по имени целиком',
    () async {
      final state = await searchFor('Молок');

      expect(
        state.searchResults.map((r) => r.name),
        contains('Молоко 3.2%'),
        reason: 'поиск в возврате не находит товар по части имени',
      );
      expect(state.isSearching, isFalse);
    },
  );

  test('найденный товар приходит с ценой продажи', () async {
    final state = await searchFor('Молок');

    expect(state.searchResults, isNotEmpty);
    expect(state.searchResults.first.id, 100);
    expect(state.searchResults.first.price, Decimal.fromInt(500));
    expect(state.searchResults.first.barcode, '4870001234567');
  });

  test('пустой запрос очищает список, не ходя в кассу', () async {
    final notifier = container.read(refundControllerProvider.notifier);
    await notifier.search('');
    final state = container.read(refundControllerProvider);

    expect(state.searchResults, isEmpty);
    expect(state.isSearching, isFalse);
    expect(state.searchQuery, isEmpty);
  });
}
