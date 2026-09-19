import 'dart:math';

import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';

Future<void> generateSeedData(AppDatabase db) async {
  final random = Random(42);

  print('[Seed] Starting seed data generation...');
  final sw = Stopwatch()..start();

  print('[Seed] Reading existing data...');

  final thisPosRows = await db
      .customSelect('SELECT id FROM this_pos_entries LIMIT 1')
      .get();
  final int posId = thisPosRows.isNotEmpty
      ? (thisPosRows.first.read<int?>('id') ?? 1)
      : 1;

  final userRows = await db.customSelect('SELECT id FROM users').get();
  final List<int> userIds = userRows.map((r) => r.read<int>('id')).toList();
  if (userIds.isEmpty) {
    print('[Seed] No users found. Aborting seed.');
    return;
  }

  final accountRows = await db
      .customSelect('SELECT id, type FROM accounts')
      .get();
  int? posAccountId;
  int? bankAccountId;
  for (final row in accountRows) {
    final t = row.read<int>('type');
    if (t == 0 && posAccountId == null) posAccountId = row.read<int>('id');
    if (t == 1 && bankAccountId == null) bankAccountId = row.read<int>('id');
  }
  if (posAccountId == null && accountRows.isNotEmpty) {
    posAccountId = accountRows.first.read<int>('id');
  }
  if (bankAccountId == null) {
    bankAccountId = posAccountId ?? 1;
  }
  posAccountId ??= 1;

  final productRows = await db
      .customSelect(
        'SELECT pi.ucode, pi.barcode, pi.category_id, pi.measure, '
        'pp.selling_price '
        'FROM product_infos pi '
        'LEFT JOIN product_prices pp ON pi.ucode = pp.ucode '
        'WHERE pi.is_deleted = 0',
      )
      .get();

  final List<_ProductInfo> products = productRows.map((r) {
    return _ProductInfo(
      ucode: r.read<int>('ucode'),
      barcode: r.read<int>('barcode'),
      categoryId: r.read<int?>('category_id'),
      measure: r.read<int>('measure'),
      sellingPrice: r.read<double?>('selling_price') ?? 500.0,
    );
  }).toList();

  if (products.isEmpty) {
    print('[Seed] No products found. Creating base catalog...');
    final baseProducts = <List<dynamic>>[
      [1001, 1001, 'Хлеб белый', 0, 0, 180.0],
      [1002, 1002, 'Молоко 1л', 0, 2, 450.0],
      [1003, 1003, 'Яйца (10 шт)', 0, 0, 550.0],
      [1004, 1004, 'Сахар 1кг', 0, 1, 380.0],
      [1005, 1005, 'Масло подсолн. 1л', 0, 2, 650.0],
      [1006, 1006, 'Рис 1кг', 0, 1, 420.0],
      [1007, 1007, 'Макароны 500г', 0, 1, 250.0],
      [1008, 1008, 'Чай Липтон 100п', 0, 0, 1200.0],
      [1009, 1009, 'Кофе раств. 100г', 0, 1, 1800.0],
      [1010, 1010, 'Колбаса докторская', 1, 1, 2500.0],
      [1011, 1011, 'Сыр Голландский', 1, 1, 3200.0],
      [1012, 1012, 'Курица охлажд.', 1, 1, 1400.0],
      [1013, 1013, 'Говядина', 1, 1, 3800.0],
      [1014, 1014, 'Картофель', 1, 1, 180.0],
      [1015, 1015, 'Лук репчатый', 1, 1, 150.0],
      [1016, 1016, 'Морковь', 1, 1, 200.0],
      [1017, 1017, 'Помидоры', 1, 1, 500.0],
      [1018, 1018, 'Вода Бонаква 0.5', 0, 0, 200.0],
      [1019, 1019, 'Сок Добрый 1л', 0, 0, 650.0],
      [1020, 1020, 'Шоколад Алёнка', 0, 0, 350.0],
    ];
    for (final bp in baseProducts) {
      await db.customStatement(
        'INSERT OR IGNORE INTO product_infos (ucode, barcode, name, type, measure, quantity, is_deleted) '
        'VALUES (?, ?, ?, ?, ?, 100.0, 0)',
        [bp[0], bp[1], bp[2], bp[3], bp[4]],
      );
      await db.customStatement(
        'INSERT OR IGNORE INTO product_prices (ucode, barcode, selling_price, wholesale_price) '
        'VALUES (?, ?, ?, ?)',
        [bp[0], bp[1], bp[5], (bp[5] as double) * 0.65],
      );
      products.add(
        _ProductInfo(
          ucode: bp[0] as int,
          barcode: bp[1] as int,
          categoryId: null,
          measure: bp[4] as int,
          sellingPrice: bp[5] as double,
        ),
      );
    }
    print('[Seed] Created ${baseProducts.length} base products');
  }

  print(
    '[Seed] Found: ${userIds.length} users, ${products.length} products, '
    'posId=$posId, posAccount=$posAccountId, bankAccount=$bankAccountId',
  );

  await db.transaction(() async {
    print('[Seed] Generating agents...');

    final supplierNames = [
      'Алматы-Продукт',
      'ТОО Каспий',
      'ИП Сериков',
      'Mega Trade',
      'Астана Логистика',
      'Fresh Market',
      'ТехноПоставка',
      'Green Valley',
      'East Supply',
      'Центр Опт',
    ];

    final customerNames = [
      'Серик Алиев',
      'Айгуль Нурланова',
      'Болат Касымов',
      'Динара Жумабаева',
      'Ерлан Токтаров',
      'Мадина Бекова',
      'Нурсултан Ахметов',
      'Гульнара Сейтова',
      'Асхат Муратов',
      'Жанна Омарова',
      'Тимур Сагинов',
      'Алия Искакова',
      'Дамир Баймуратов',
      'Камила Нурпеисова',
      'Рустам Жаксылыков',
      'Сауле Темирбаева',
      'Арман Калиев',
      'Лаура Мусина',
      'Бакытжан Сулейменов',
      'Назгуль Абдрахманова',
    ];

    final maxAgentRow = await db
        .customSelect('SELECT MAX(local_id) as max_id FROM agents')
        .getSingle();
    int agentLocalId = (maxAgentRow.read<int?>('max_id') ?? 0) + 1;

    final List<int> supplierLocalIds = [];
    final List<int> customerLocalIds = [];

    final now = DateTime(2026, 3, 22).millisecondsSinceEpoch ~/ 1000;

    for (var i = 0; i < supplierNames.length; i++) {
      final phone = 77010000000 + random.nextInt(9999999);
      await db.customStatement(
        'INSERT OR IGNORE INTO agents (local_id, type, name, phone, is_deleted, state, edit_time) '
        'VALUES (?, 0, ?, ?, 0, 3, ?)',
        [agentLocalId, supplierNames[i], phone, now],
      );
      supplierLocalIds.add(agentLocalId);
      agentLocalId++;
    }

    for (var i = 0; i < customerNames.length; i++) {
      final phone = 77020000000 + random.nextInt(9999999);
      await db.customStatement(
        'INSERT OR IGNORE INTO agents (local_id, type, name, phone, is_deleted, state, edit_time) '
        'VALUES (?, 1, ?, ?, 0, 3, ?)',
        [agentLocalId, customerNames[i], phone, now],
      );
      customerLocalIds.add(agentLocalId);
      agentLocalId++;
    }

    print(
      '[Seed] Created ${supplierNames.length} suppliers + '
      '${customerNames.length} customers',
    );

    print('[Seed] Generating shifts...');

    final startDate = DateTime(2025, 4, 1);
    final endDate = DateTime(2026, 3, 22);
    int dayCount = endDate.difference(startDate).inDays;

    final maxShiftRow = await db
        .customSelect('SELECT MAX(id) as max_id FROM shifts')
        .getSingle();
    int shiftId = (maxShiftRow.read<int?>('max_id') ?? 0) + 1;
    final List<DateTime> shiftDates = [];

    for (var d = 0; d < dayCount; d++) {
      final date = startDate.add(Duration(days: d));
      final userId = userIds[d % userIds.length];
      final openTime =
          DateTime(
            date.year,
            date.month,
            date.day,
            9,
            0,
          ).millisecondsSinceEpoch ~/
          1000;
      final closeTime =
          DateTime(
            date.year,
            date.month,
            date.day,
            21,
            0,
          ).millisecondsSinceEpoch ~/
          1000;
      final cashOnClose = 50000.0 + random.nextInt(200000);

      await db.customStatement(
        'INSERT OR IGNORE INTO shifts (id, user_id, open_time, is_opened, close_time, '
        'cash_in_pos_on_shift_close, is_synced) '
        'VALUES (?, ?, ?, 0, ?, ?, 1)',
        [shiftId, userId, openTime, closeTime, cashOnClose],
      );
      shiftDates.add(date);
      shiftId++;
    }

    print('[Seed] Created $dayCount shifts');

    print('[Seed] Generating sales...');

    final maxReceiptRow = await db
        .customSelect(
          'SELECT MAX(receipt_no) as max_rn FROM sales WHERE pos_id = ?',
          variables: [Variable.withInt(posId)],
        )
        .getSingle();
    int receiptNo = max((maxReceiptRow.read<int?>('max_rn') ?? 0) + 1, 10000);

    int totalSales = 0;
    int totalSaleProducts = 0;
    int totalPayments = 0;

    for (var d = 0; d < dayCount; d++) {
      final date = shiftDates[d];
      final isWeekend = date.weekday >= 6;
      final month = date.month;

      double seasonalMult = 1.0;
      if (month == 12) seasonalMult = 1.3;
      if (month == 1 || month == 2) seasonalMult = 0.8;

      int baseSales = isWeekend
          ? 25 + random.nextInt(16)
          : 15 + random.nextInt(11);
      int salesForDay = (baseSales * seasonalMult).round();

      for (var s = 0; s < salesForDay; s++) {
        final userId = userIds[random.nextInt(userIds.length)];

        final hour = _pickHour(random);
        final minute = random.nextInt(60);
        final saleTime =
            DateTime(
              date.year,
              date.month,
              date.day,
              hour,
              minute,
            ).millisecondsSinceEpoch ~/
            1000;

        final numProducts = 2 + random.nextInt(4);
        double saleAmount = 0.0;

        final saleState = random.nextDouble() < 0.9 ? 4 : 1;
        final isWholesale = random.nextDouble() < 0.05;
        final hasCustomer = random.nextDouble() < 0.3;
        final customerLocalId = hasCustomer
            ? customerLocalIds[random.nextInt(customerLocalIds.length)]
            : null;

        final pickedProducts = <_ProductInfo>[];
        final usedUcodes = <int>{};
        for (var p = 0; p < numProducts; p++) {
          _ProductInfo prod;
          int attempts = 0;
          do {
            prod = products[random.nextInt(products.length)];
            attempts++;
          } while (usedUcodes.contains(prod.ucode) && attempts < 20);
          if (usedUcodes.contains(prod.ucode)) continue;
          usedUcodes.add(prod.ucode);
          pickedProducts.add(prod);
        }

        for (final prod in pickedProducts) {
          final isWeight = prod.measure == 1;
          double qty;
          if (isWeight) {
            qty = (0.1 + random.nextDouble() * 1.9);
            qty = (qty * 100).roundToDouble() / 100;
          } else {
            qty = (1 + random.nextInt(5)).toDouble();
          }

          final price = prod.sellingPrice;
          final hasDiscount = random.nextDouble() < 0.2;
          final priceBefore = hasDiscount
              ? (price * 1.1 * 1000).roundToDouble() / 1000
              : price;
          final lineAmount = (qty * price * 1000).roundToDouble() / 1000;
          saleAmount += lineAmount;

          await db.customStatement(
            'INSERT OR IGNORE INTO sale_products '
            '(receipt_no, pos_id, ucode, barcode, category_id, quantity, price, price_before) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [
              receiptNo,
              posId,
              prod.ucode,
              prod.barcode,
              prod.categoryId,
              qty,
              price,
              priceBefore,
            ],
          );
          totalSaleProducts++;
        }

        saleAmount = (saleAmount * 1000).roundToDouble() / 1000;

        // `terminal_id` — явный `NULL`, не умолчание колонки: демо-продажи
        // рождаются сразу в `state` 1/4 (`saleState` выше, никогда 0), и
        // владельца по правилу смысла `Sales.terminalId` не несут — но
        // правило требует решения на каждую запись `state`, не молчаливого
        // совпадения с умолчанием (`sale_state_owner_guard_test.dart`).
        await db.customStatement(
          'INSERT OR IGNORE INTO sales '
          '(receipt_no, pos_id, user_id, amount, time, state, is_wholesale, '
          'customer_local_id, is_ofd, terminal_id) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, NULL)',
          [
            receiptNo,
            posId,
            userId,
            saleAmount,
            saleTime,
            saleState,
            isWholesale ? 1 : 0,
            customerLocalId,
          ],
        );
        totalSales++;

        final paymentRoll = random.nextDouble();
        if (paymentRoll < 0.65) {
          await db.customStatement(
            'INSERT OR IGNORE INTO payments '
            '(user_id, receipt_no, pos_id, payee_account_id, amount, time, state) '
            'VALUES (?, ?, ?, ?, ?, ?, ?)',
            [userId, receiptNo, posId, posAccountId, saleAmount, saleTime, 3],
          );
          totalPayments++;
        } else if (paymentRoll < 0.95) {
          await db.customStatement(
            'INSERT OR IGNORE INTO payments '
            '(user_id, receipt_no, pos_id, payee_account_id, amount, time, state) '
            'VALUES (?, ?, ?, ?, ?, ?, ?)',
            [userId, receiptNo, posId, bankAccountId, saleAmount, saleTime, 3],
          );
          totalPayments++;
        } else {
          final cashPart = (saleAmount * 0.5 * 1000).roundToDouble() / 1000;
          final cardPart =
              (saleAmount * 1000).roundToDouble() / 1000 - cashPart;
          await db.customStatement(
            'INSERT OR IGNORE INTO payments '
            '(user_id, receipt_no, pos_id, payee_account_id, amount, time, state) '
            'VALUES (?, ?, ?, ?, ?, ?, ?)',
            [userId, receiptNo, posId, posAccountId, cashPart, saleTime, 3],
          );
          await db.customStatement(
            'INSERT OR IGNORE INTO payments '
            '(user_id, receipt_no, pos_id, payee_account_id, amount, time, state) '
            'VALUES (?, ?, ?, ?, ?, ?, ?)',
            [userId, receiptNo, posId, bankAccountId, cardPart, saleTime, 3],
          );
          totalPayments += 2;
        }

        receiptNo++;
      }

      if (d > 0 && d % 30 == 0) {
        print(
          '[Seed] Generating sales... $totalSales so far (day $d/$dayCount)',
        );
      }
    }

    print(
      '[Seed] Created $totalSales sales, $totalSaleProducts sale products, '
      '$totalPayments payments',
    );

    print('[Seed] Generating supplies...');

    final maxSupplyRow = await db
        .customSelect('SELECT MAX(id) as max_id FROM supplies')
        .getSingle();
    int supplyId = (maxSupplyRow.read<int?>('max_id') ?? 0) + 1;

    int totalSupplies = 0;
    int totalSupplyProducts = 0;

    for (var w = 0; w < 52; w++) {
      final dayOffset = w * 7 + random.nextInt(3);
      if (dayOffset >= dayCount) break;

      final date = startDate.add(Duration(days: dayOffset));
      final supplyTime =
          DateTime(
            date.year,
            date.month,
            date.day,
            10,
            0,
          ).millisecondsSinceEpoch ~/
          1000;
      final userId = userIds[random.nextInt(userIds.length)];
      final supplierId =
          supplierLocalIds[random.nextInt(supplierLocalIds.length)];

      final numProducts = 3 + random.nextInt(6);
      double supplyAmount = 0.0;

      final usedUcodes = <int>{};
      final supplyProducts = <List<dynamic>>[];

      for (var p = 0; p < numProducts && p < products.length; p++) {
        _ProductInfo prod;
        int attempts = 0;
        do {
          prod = products[random.nextInt(products.length)];
          attempts++;
        } while (usedUcodes.contains(prod.ucode) && attempts < 30);
        if (usedUcodes.contains(prod.ucode)) continue;
        usedUcodes.add(prod.ucode);

        final qty = (10 + random.nextInt(91)).toDouble();
        final costPrice =
            (prod.sellingPrice * 0.6 * 1000).roundToDouble() / 1000;
        final lineAmount = (qty * costPrice * 1000).roundToDouble() / 1000;
        supplyAmount += lineAmount;

        supplyProducts.add([supplyId, prod.ucode, qty, costPrice, lineAmount]);
      }

      supplyAmount = (supplyAmount * 1000).roundToDouble() / 1000;

      await db.customStatement(
        'INSERT OR IGNORE INTO supplies '
        '(id, operation_type, user_id, supplier_id, edit_time, amount, '
        'payment_type, account_id, payment, state) '
        'VALUES (?, 0, ?, ?, ?, ?, 0, ?, ?, 3)',
        [
          supplyId,
          userId,
          supplierId,
          supplyTime,
          supplyAmount,
          posAccountId,
          supplyAmount,
        ],
      );

      for (final sp in supplyProducts) {
        await db.customStatement(
          'INSERT OR IGNORE INTO supply_products (supply_id, ucode, quantity, price, amount) '
          'VALUES (?, ?, ?, ?, ?)',
          sp,
        );
        await db.customStatement(
          'UPDATE product_prices SET wholesale_price = ? WHERE ucode = ? AND (wholesale_price IS NULL OR wholesale_price = 0)',
          [sp[3], sp[1]],
        );
        totalSupplyProducts++;
      }

      supplyId++;
      totalSupplies++;
    }

    print(
      '[Seed] Created $totalSupplies supplies, '
      '$totalSupplyProducts supply products',
    );

    print('[Seed] Generating movements...');

    final maxMovementRow = await db
        .customSelect('SELECT MAX(id) as max_id FROM movements')
        .getSingle();
    int movementId = (maxMovementRow.read<int?>('max_id') ?? 0) + 1;

    int totalMovements = 0;
    int totalMovementProducts = 0;

    final locations = [
      'Основной склад',
      'Торговый зал',
      'Холодильник',
      'Витрина',
      'Склад №2',
      'Подсобка',
      'Склад напитков',
    ];

    for (var w = 0; w < 52; w++) {
      final movementsPerWeek = 1 + random.nextInt(3);
      for (var m = 0; m < movementsPerWeek; m++) {
        final dayOffset = w * 7 + random.nextInt(7);
        if (dayOffset >= dayCount) break;

        final date = startDate.add(Duration(days: dayOffset));
        final moveTime =
            DateTime(
              date.year,
              date.month,
              date.day,
              8 + random.nextInt(10),
              random.nextInt(60),
            ).millisecondsSinceEpoch ~/
            1000;
        final userId = userIds[random.nextInt(userIds.length)];

        final fromIdx = random.nextInt(locations.length);
        int toIdx;
        do {
          toIdx = random.nextInt(locations.length);
        } while (toIdx == fromIdx);

        final numProducts = 2 + random.nextInt(5);
        double moveAmount = 0.0;
        final usedUcodesM = <int>{};
        final moveProducts = <List<dynamic>>[];

        for (var p = 0; p < numProducts && p < products.length; p++) {
          _ProductInfo prod;
          int attempts = 0;
          do {
            prod = products[random.nextInt(products.length)];
            attempts++;
          } while (usedUcodesM.contains(prod.ucode) && attempts < 30);
          if (usedUcodesM.contains(prod.ucode)) continue;
          usedUcodesM.add(prod.ucode);

          final qty = (1 + random.nextInt(20)).toDouble();
          final price = prod.sellingPrice;
          final lineAmount = (qty * price * 1000).roundToDouble() / 1000;
          moveAmount += lineAmount;

          moveProducts.add([movementId, prod.ucode, qty, price, lineAmount]);
        }

        moveAmount = (moveAmount * 1000).roundToDouble() / 1000;

        await db.customStatement(
          'INSERT OR IGNORE INTO movements '
          '(id, user_id, edit_time, amount, comment, from_location, to_location, state, status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, 3, 0)',
          [
            movementId,
            userId,
            moveTime,
            moveAmount,
            'Перемещение товаров',
            locations[fromIdx],
            locations[toIdx],
          ],
        );

        for (final mp in moveProducts) {
          await db.customStatement(
            'INSERT OR IGNORE INTO movement_products (movement_id, ucode, quantity, price, amount) '
            'VALUES (?, ?, ?, ?, ?)',
            mp,
          );
          totalMovementProducts++;
        }

        movementId++;
        totalMovements++;
      }
    }

    print(
      '[Seed] Created $totalMovements movements, '
      '$totalMovementProducts movement products',
    );

    print('[Seed] Generating supplier returns...');

    final maxReturnRow = await db
        .customSelect('SELECT MAX(id) as max_id FROM supplier_returns')
        .getSingle();
    int returnId = (maxReturnRow.read<int?>('max_id') ?? 0) + 1;

    int totalReturns = 0;
    int totalReturnProducts = 0;

    final returnReasons = [
      'Брак',
      'Истёк срок годности',
      'Пересорт',
      'Повреждённая упаковка',
      'Не соответствует заказу',
      'Излишки',
    ];

    for (var w = 0; w < 52; w += 2) {
      final dayOffset = w * 7 + random.nextInt(7);
      if (dayOffset >= dayCount) break;

      final date = startDate.add(Duration(days: dayOffset));
      final returnTime =
          DateTime(
            date.year,
            date.month,
            date.day,
            11 + random.nextInt(6),
            random.nextInt(60),
          ).millisecondsSinceEpoch ~/
          1000;
      final userId = userIds[random.nextInt(userIds.length)];
      final supplierId =
          supplierLocalIds[random.nextInt(supplierLocalIds.length)];
      final reason = returnReasons[random.nextInt(returnReasons.length)];

      final numProducts = 1 + random.nextInt(4);
      double returnAmount = 0.0;
      final usedUcodesR = <int>{};
      final retProducts = <List<dynamic>>[];

      for (var p = 0; p < numProducts && p < products.length; p++) {
        _ProductInfo prod;
        int attempts = 0;
        do {
          prod = products[random.nextInt(products.length)];
          attempts++;
        } while (usedUcodesR.contains(prod.ucode) && attempts < 30);
        if (usedUcodesR.contains(prod.ucode)) continue;
        usedUcodesR.add(prod.ucode);

        final qty = (1 + random.nextInt(10)).toDouble();
        final costPrice =
            (prod.sellingPrice * 0.6 * 1000).roundToDouble() / 1000;
        final lineAmount = (qty * costPrice * 1000).roundToDouble() / 1000;
        returnAmount += lineAmount;

        retProducts.add([returnId, prod.ucode, qty, costPrice, lineAmount]);
      }

      returnAmount = (returnAmount * 1000).roundToDouble() / 1000;

      await db.customStatement(
        'INSERT OR IGNORE INTO supplier_returns '
        '(id, user_id, supplier_id, edit_time, amount, account_id, comment, state, status) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, 3, 0)',
        [
          returnId,
          userId,
          supplierId,
          returnTime,
          returnAmount,
          posAccountId,
          reason,
        ],
      );

      for (final rp in retProducts) {
        await db.customStatement(
          'INSERT OR IGNORE INTO supplier_return_products '
          '(supplier_return_id, ucode, quantity, price, amount) '
          'VALUES (?, ?, ?, ?, ?)',
          rp,
        );
        totalReturnProducts++;
      }

      returnId++;
      totalReturns++;
    }

    print(
      '[Seed] Created $totalReturns supplier returns, '
      '$totalReturnProducts return products',
    );

    print('[Seed] Generating cash operations...');

    int totalCashOps = 0;
    final cashOpNotes = {
      0: ['Внесение наличных', 'Размен', 'Пополнение кассы'],
      1: [
        'Аренда',
        'Коммунальные услуги',
        'Зарплата',
        'Канцтовары',
        'Уборка',
        'Доставка',
        'Ремонт оборудования',
        'Связь/Интернет',
      ],
      2: ['Изъятие выручки', 'Дивиденды'],
    };

    for (var i = 0; i < 100; i++) {
      final dayOffset = random.nextInt(dayCount);
      final date = startDate.add(Duration(days: dayOffset));
      final opTime =
          DateTime(
            date.year,
            date.month,
            date.day,
            11 + random.nextInt(8),
            random.nextInt(60),
          ).millisecondsSinceEpoch ~/
          1000;
      final userId = userIds[random.nextInt(userIds.length)];

      int opType;
      double amount;
      final roll = random.nextDouble();
      if (roll < 0.2) {
        opType = 0;
        amount = (50000 + random.nextInt(150001)).toDouble();
      } else if (roll < 0.9) {
        opType = 1;
        amount = (5000 + random.nextInt(45001)).toDouble();
      } else {
        opType = 2;
        amount = (100000 + random.nextInt(400001)).toDouble();
      }

      final notes = cashOpNotes[opType]!;
      final note = notes[random.nextInt(notes.length)];

      await db.customStatement(
        'INSERT OR IGNORE INTO cash_operations '
        '(amount, account_id, type, user_id, note, doc_time, state) '
        'VALUES (?, ?, ?, ?, ?, ?, 3)',
        [amount, posAccountId, opType, userId, note, opTime],
      );
      totalCashOps++;
    }

    print('[Seed] Created $totalCashOps cash operations');

    print('[Seed] Generating refunds...');

    final int refundCount = (totalSales * 0.03).round();

    final int firstReceipt = receiptNo - totalSales;
    int totalRefunds = 0;
    int totalRefundProducts = 0;
    int totalRefundPayments = 0;

    final refundedReceipts = <int>{};

    for (var i = 0; i < refundCount; i++) {
      int refReceipt;
      int attempts = 0;
      do {
        refReceipt = firstReceipt + random.nextInt(totalSales);
        attempts++;
      } while (refundedReceipts.contains(refReceipt) && attempts < 50);
      if (refundedReceipts.contains(refReceipt)) continue;
      refundedReceipts.add(refReceipt);

      final saleRows = await db
          .customSelect(
            'SELECT amount, user_id, time FROM sales '
            'WHERE receipt_no = ? AND pos_id = ?',
            variables: [Variable.withInt(refReceipt), Variable.withInt(posId)],
          )
          .get();
      if (saleRows.isEmpty) continue;

      final saleAmount = saleRows.first.read<double>('amount');
      final saleUserId = saleRows.first.read<int>('user_id');
      final saleTime = saleRows.first.read<int>('time');

      final refundTime = saleTime + (86400 * (1 + random.nextInt(3)));

      await db.customStatement(
        'INSERT OR IGNORE INTO refunds '
        '(sale_receipt_no, sale_pos_id, user_id, amount, time, state, is_ofd) '
        'VALUES (?, ?, ?, ?, ?, 3, 0)',
        [refReceipt, posId, saleUserId, saleAmount, refundTime],
      );

      final refundIdRow = await db
          .customSelect('SELECT last_insert_rowid() as rid')
          .getSingle();
      final refundLocalId = refundIdRow.read<int>('rid');

      final spRows = await db
          .customSelect(
            'SELECT ucode, price, quantity FROM sale_products '
            'WHERE receipt_no = ? AND pos_id = ?',
            variables: [Variable.withInt(refReceipt), Variable.withInt(posId)],
          )
          .get();

      for (final sp in spRows) {
        await db.customStatement(
          'INSERT OR IGNORE INTO refund_products '
          '(refund_local_id, ucode, price, quantity) '
          'VALUES (?, ?, ?, ?)',
          [
            refundLocalId,
            sp.read<int>('ucode'),
            sp.read<double>('price'),
            sp.read<double>('quantity'),
          ],
        );
        totalRefundProducts++;
      }

      await db.customStatement(
        'INSERT OR IGNORE INTO payments '
        '(user_id, refund_local_id, payee_account_id, amount, time, state) '
        'VALUES (?, ?, ?, ?, ?, 3)',
        [saleUserId, refundLocalId, posAccountId, saleAmount, refundTime],
      );
      totalRefundPayments++;
      totalRefunds++;
    }

    print(
      '[Seed] Created $totalRefunds refunds, $totalRefundProducts refund products, '
      '$totalRefundPayments refund payments',
    );

    print('[Seed] Generating service orders...');

    final deviceDescriptions = [
      'iPhone 14',
      'iPhone 15 Pro',
      'Samsung S23',
      'Samsung S24 Ultra',
      'MacBook Pro 14"',
      'MacBook Air M2',
      'Стиральная машина LG',
      'Стиральная машина Samsung',
      'Пальто женское',
      'Куртка зимняя',
      'Ковёр 3x4',
      'Ковёр 2x3',
      'Кроссовки Nike',
      'Кроссовки Adidas',
      'Пуховик',
      'Костюм деловой',
    ];

    final complaints = [
      'Не включается',
      'Разбит экран',
      'Не заряжается',
      'Зависает при работе',
      'Пятна на ткани',
      'Требуется химчистка',
      'Глубокая чистка',
      'Замена молнии',
      'Не отжимает',
      'Протечка воды',
      'Шум при работе',
      'Ошибка на дисплее',
    ];

    final markDescriptions = [
      'Диагностика',
      'Замена экрана',
      'Чистка',
      'Тестирование',
      'Замена батареи',
      'Замена разъёма',
      'Пропитка ткани',
      'Глажка',
      'Сушка',
      'Упаковка',
    ];

    int totalOrders = 0;
    int totalMarks = 0;

    for (var i = 0; i < 100; i++) {
      final dayOffset = random.nextInt(dayCount);
      final date = startDate.add(Duration(days: dayOffset));
      final intakeTime =
          DateTime(
            date.year,
            date.month,
            date.day,
            9 + random.nextInt(10),
            random.nextInt(60),
          ).millisecondsSinceEpoch ~/
          1000;
      final userId = userIds[random.nextInt(userIds.length)];
      final clientId =
          customerLocalIds[random.nextInt(customerLocalIds.length)];

      final statusRoll = random.nextDouble();
      int status;
      if (statusRoll < 0.1) {
        status = 0;
      } else if (statusRoll < 0.2) {
        status = 1;
      } else if (statusRoll < 0.3) {
        status = 2;
      } else {
        status = 3;
      }

      final device =
          deviceDescriptions[random.nextInt(deviceDescriptions.length)];
      final complaint = complaints[random.nextInt(complaints.length)];
      final orderNumber =
          'SO-${date.year}${date.month.toString().padLeft(2, '0')}'
          '${date.day.toString().padLeft(2, '0')}-${(i + 1).toString().padLeft(3, '0')}';
      final estimatedAmount = (5000 + random.nextInt(45001)).toDouble();
      final estimatedCompletion = intakeTime + 86400 * (1 + random.nextInt(5));
      final finalAmount = status >= 2 ? estimatedAmount : null;
      final serialNumber =
          'SN${random.nextInt(999999999).toString().padLeft(9, '0')}';

      await db.customStatement(
        'INSERT OR IGNORE INTO service_orders '
        '(order_number, status, user_id, client_agent_id, '
        'device_description, serial_number, complaint, '
        'intake_time, estimated_completion_time, estimated_amount, final_amount) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          orderNumber,
          status,
          userId,
          clientId,
          device,
          serialNumber,
          complaint,
          intakeTime,
          estimatedCompletion,
          estimatedAmount,
          finalAmount,
        ],
      );

      final orderIdRow = await db
          .customSelect('SELECT last_insert_rowid() as oid')
          .getSingle();
      final orderId = orderIdRow.read<int>('oid');

      final numMarks = 2 + random.nextInt(3);
      for (var m = 0; m < numMarks; m++) {
        final markType = random.nextInt(5);
        final desc = markDescriptions[random.nextInt(markDescriptions.length)];
        final cost = (1000 + random.nextInt(19001)).toDouble();
        final markTime = intakeTime + 3600 * (m + 1);

        await db.customStatement(
          'INSERT OR IGNORE INTO service_marks '
          '(service_order_id, description, mark_type, user_id, cost, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [orderId, desc, markType, userId, cost, markTime],
        );
        totalMarks++;
      }

      totalOrders++;
    }

    print(
      '[Seed] Created $totalOrders service orders, $totalMarks service marks',
    );

    print('[Seed] Generating restaurant data...');

    final existingCat100 = await db
        .customSelect('SELECT COUNT(*) as cnt FROM categories WHERE id = 100')
        .getSingle();
    if (existingCat100.read<int>('cnt') == 0) {
      final catNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final restaurantCategories = [
        [100, null, 'Ресторан'],
        [101, 100, 'Закуски'],
        [102, 100, 'Салаты'],
        [103, 100, 'Супы'],
        [104, 100, 'Основные блюда'],
        [105, 100, 'Гарниры'],
        [106, 100, 'Десерты'],
        [107, 100, 'Напитки'],
        [108, 100, 'Коктейли'],
      ];
      for (final cat in restaurantCategories) {
        await db.customStatement(
          'INSERT OR IGNORE INTO categories (id, parent_id, name, create_time) '
          'VALUES (?, ?, ?, ?)',
          [cat[0], cat[1], cat[2], catNow],
        );
      }
      print(
        '[Seed] Created ${restaurantCategories.length} restaurant categories',
      );
    }

    final existingTables = await db
        .customSelect('SELECT COUNT(*) as cnt FROM restaurant_tables')
        .getSingle();
    if (existingTables.read<int>('cnt') == 0) {
      for (var i = 1; i <= 8; i++) {
        await db.customStatement(
          'INSERT OR IGNORE INTO restaurant_tables (name, capacity, status, zone, is_active, sort_order) '
          'VALUES (?, 4, 0, ?, 1, ?)',
          ['$i', 'Основной зал', i],
        );
      }
      for (var i = 1; i <= 4; i++) {
        await db.customStatement(
          'INSERT OR IGNORE INTO restaurant_tables (name, capacity, status, zone, is_active, sort_order) '
          'VALUES (?, 6, 0, ?, 1, ?)',
          ['T$i', 'Терраса', 8 + i],
        );
      }
      for (var i = 1; i <= 3; i++) {
        await db.customStatement(
          'INSERT OR IGNORE INTO restaurant_tables (name, capacity, status, zone, is_active, sort_order) '
          'VALUES (?, 2, 0, ?, 1, ?)',
          ['V$i', 'VIP', 12 + i],
        );
      }
      print('[Seed] Created 15 restaurant tables');
    }

    final ingredientProducts = <List<dynamic>>[
      [80001, 80001, 'Мука', null, 1, 1, 200.0],
      [80002, 80002, 'Масло растительное', null, 1, 2, 600.0],
      [80003, 80003, 'Соль', null, 1, 1, 100.0],
      [80004, 80004, 'Перец чёрный', null, 1, 1, 1500.0],
      [80005, 80005, 'Сахар', null, 1, 1, 350.0],
      [80006, 80006, 'Лук репчатый', null, 1, 1, 150.0],
      [80007, 80007, 'Чеснок', null, 1, 1, 800.0],
      [80008, 80008, 'Томаты', null, 1, 1, 400.0],
      [80009, 80009, 'Огурцы', null, 1, 1, 300.0],
      [80010, 80010, 'Картофель', null, 1, 1, 120.0],
      [80011, 80011, 'Морковь', null, 1, 1, 150.0],
      [80012, 80012, 'Капуста', null, 1, 1, 100.0],
      [80013, 80013, 'Говядина', null, 1, 1, 3500.0],
      [80014, 80014, 'Свинина', null, 1, 1, 2500.0],
      [80015, 80015, 'Курица', null, 1, 1, 1200.0],
      [80016, 80016, 'Рыба', null, 1, 1, 2800.0],
      [80017, 80017, 'Рис', null, 1, 1, 400.0],
      [80018, 80018, 'Макароны', null, 1, 1, 300.0],
      [80019, 80019, 'Яйца', null, 1, 0, 50.0],
      [80020, 80020, 'Молоко', null, 1, 2, 350.0],
      [80021, 80021, 'Сметана', null, 1, 1, 500.0],
      [80022, 80022, 'Сыр', null, 1, 1, 3000.0],
      [80023, 80023, 'Масло сливочное', null, 1, 1, 1200.0],
      [80024, 80024, 'Сливки', null, 1, 2, 800.0],
      [80025, 80025, 'Хлеб', null, 1, 0, 150.0],
      [80026, 80026, 'Листья салата', null, 1, 1, 1500.0],
      [80027, 80027, 'Кофе зерно', null, 1, 1, 5000.0],
      [80028, 80028, 'Чай листовой', null, 1, 1, 3000.0],
      [80029, 80029, 'Лимон', null, 1, 1, 800.0],
      [80030, 80030, 'Мёд', null, 1, 1, 2500.0],
    ];

    final existingIngredient = await db
        .customSelect(
          'SELECT COUNT(*) as cnt FROM product_infos WHERE ucode = 80001',
        )
        .getSingle();
    if (existingIngredient.read<int>('cnt') == 0) {
      for (final ip in ingredientProducts) {
        await db.customStatement(
          'INSERT OR IGNORE INTO product_infos (ucode, barcode, name, category_id, type, measure, quantity, is_deleted) '
          'VALUES (?, ?, ?, ?, ?, ?, 100.0, 0)',
          [ip[0], ip[1], ip[2], ip[3], ip[4], ip[5]],
        );
        final wholesalePrice = ip[6] as double;
        final sellingPrice = wholesalePrice * 1.5;
        await db.customStatement(
          'INSERT OR IGNORE INTO product_prices (ucode, barcode, selling_price, wholesale_price) '
          'VALUES (?, ?, ?, ?)',
          [ip[0], ip[1], sellingPrice, wholesalePrice],
        );
      }
      print('[Seed] Created ${ingredientProducts.length} ingredient products');
    }

    final dishProducts = <List<dynamic>>[
      [90001, 90001, 'Брускетта с томатами', 101, 1800.0],
      [90002, 90002, 'Сырная тарелка', 101, 3500.0],
      [90003, 90003, 'Хумус с лавашом', 101, 1500.0],
      [90004, 90004, 'Цезарь с курицей', 102, 2800.0],
      [90005, 90005, 'Греческий салат', 102, 2200.0],
      [90006, 90006, 'Оливье', 102, 1800.0],
      [90007, 90007, 'Борщ', 103, 1500.0],
      [90008, 90008, 'Том Ям', 103, 3200.0],
      [90009, 90009, 'Крем-суп грибной', 103, 2000.0],
      [90010, 90010, 'Стейк рибай', 104, 8500.0],
      [90011, 90011, 'Плов', 104, 2500.0],
      [90012, 90012, 'Бешбармак', 104, 3500.0],
      [90013, 90013, 'Лагман', 104, 2200.0],
      [90014, 90014, 'Паста Карбонара', 104, 3000.0],
      [90015, 90015, 'Бургер классический', 104, 2800.0],
      [90016, 90016, 'Картофель фри', 105, 800.0],
      [90017, 90017, 'Рис отварной', 105, 500.0],
      [90018, 90018, 'Овощи гриль', 105, 1200.0],
      [90019, 90019, 'Тирамису', 106, 2500.0],
      [90020, 90020, 'Чизкейк', 106, 2200.0],
      [90021, 90021, 'Мороженое (3 шарика)', 106, 1500.0],
      [90022, 90022, 'Чай', 107, 500.0],
      [90023, 90023, 'Кофе Американо', 107, 800.0],
      [90024, 90024, 'Кофе Латте', 107, 1200.0],
      [90025, 90025, 'Лимонад', 107, 900.0],
      [90026, 90026, 'Сок свежевыжатый', 107, 1500.0],
      [90027, 90027, 'Вода', 107, 400.0],
      [90028, 90028, 'Пиво (0.5л)', 107, 1500.0],
      [90029, 90029, 'Вино (бокал)', 107, 2500.0],
    ];

    final existingDish = await db
        .customSelect(
          'SELECT COUNT(*) as cnt FROM product_infos WHERE ucode = 90001',
        )
        .getSingle();
    if (existingDish.read<int>('cnt') == 0) {
      for (final dp in dishProducts) {
        await db.customStatement(
          'INSERT OR IGNORE INTO product_infos (ucode, barcode, name, category_id, type, measure, quantity, is_deleted) '
          'VALUES (?, ?, ?, ?, 6, 0, 0.0, 0)',
          [dp[0], dp[1], dp[2], dp[3]],
        );
        final sellPrice = dp[4] as double;
        final costPrice = sellPrice * 0.33;
        await db.customStatement(
          'INSERT OR IGNORE INTO product_prices (ucode, barcode, selling_price, wholesale_price) '
          'VALUES (?, ?, ?, ?)',
          [dp[0], dp[1], sellPrice, costPrice],
        );
      }
      print('[Seed] Created ${dishProducts.length} dish products');

      final qpNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final menuCategories = <List<dynamic>>[
        [null, null, 'Закуски', 1],
        [null, null, 'Салаты', 2],
        [null, null, 'Супы', 3],
        [null, null, 'Основные блюда', 4],
        [null, null, 'Гарниры', 5],
        [null, null, 'Десерты', 6],
        [null, null, 'Напитки', 7],
      ];

      final categoryIds = <String, int>{};
      for (final cat in menuCategories) {
        await db.customStatement(
          'INSERT OR IGNORE INTO quick_products (parent_id, ucode, name, order_name, is_active, edit_time) '
          'VALUES (?, ?, ?, ?, 1, ?)',
          [cat[0], cat[1], cat[2], cat[3], qpNow],
        );
        final idRow = await db
            .customSelect(
              'SELECT id FROM quick_products WHERE name = ? AND parent_id IS NULL',
              variables: [Variable.withString(cat[2] as String)],
            )
            .getSingleOrNull();
        if (idRow != null) {
          categoryIds[cat[2] as String] = idRow.read<int>('id');
        }
      }

      final categoryMapping = <int, String>{
        101: 'Закуски',
        102: 'Салаты',
        103: 'Супы',
        104: 'Основные блюда',
        105: 'Гарниры',
        106: 'Десерты',
        107: 'Напитки',
      };

      int orderIdx = 1;
      for (final dp in dishProducts) {
        final catId = dp[3] as int;
        final catName = categoryMapping[catId];
        final parentQpId = catName != null ? categoryIds[catName] : null;
        if (parentQpId == null) continue;

        await db.customStatement(
          'INSERT OR IGNORE INTO quick_products (parent_id, ucode, name, order_name, is_active, edit_time) '
          'VALUES (?, ?, ?, ?, 1, ?)',
          [parentQpId, dp[0], dp[2], orderIdx++, qpNow],
        );
      }

      print(
        '[Seed] Created ${menuCategories.length} menu categories + '
        '${dishProducts.length} menu items in quick_products',
      );
    }

    final existingModGroups = await db
        .customSelect('SELECT COUNT(*) as cnt FROM modifier_groups')
        .getSingle();
    if (existingModGroups.read<int>('cnt') == 0) {
      await db.customStatement(
        'INSERT INTO modifier_groups (dish_ucode, name, modifier_type, min_selection, max_selection, sort_order, is_required, is_active) '
        'VALUES (NULL, ?, 0, 1, 1, 1, 1, 1)',
        ['Размер порции'],
      );
      final g1Row = await db
          .customSelect('SELECT last_insert_rowid() as id')
          .getSingle();
      final g1 = g1Row.read<int>('id');
      for (final opt in <List<dynamic>>[
        ['Маленькая (-30%)', -0.3, 1, false],
        ['Стандартная', 0.0, 2, true],
        ['Большая (+50%)', 0.5, 3, false],
      ]) {
        await db.customStatement(
          'INSERT INTO modifier_options (group_id, name, price_adjustment, sort_order, is_available, is_default) '
          'VALUES (?, ?, ?, ?, 1, ?)',
          [g1, opt[0], opt[1], opt[2], (opt[3] as bool) ? 1 : 0],
        );
      }

      await db.customStatement(
        'INSERT INTO modifier_groups (dish_ucode, name, modifier_type, min_selection, max_selection, sort_order, is_required, is_active) '
        'VALUES (90010, ?, 0, 1, 1, 2, 1, 1)',
        ['Степень прожарки'],
      );
      final g2Row = await db
          .customSelect('SELECT last_insert_rowid() as id')
          .getSingle();
      final g2 = g2Row.read<int>('id');
      for (final opt in <List<dynamic>>[
        ['Rare', 0.0, 1, false],
        ['Medium', 0.0, 2, true],
        ['Well Done', 0.0, 3, false],
      ]) {
        await db.customStatement(
          'INSERT INTO modifier_options (group_id, name, price_adjustment, sort_order, is_available, is_default) '
          'VALUES (?, ?, ?, ?, 1, ?)',
          [g2, opt[0], opt[1], opt[2], (opt[3] as bool) ? 1 : 0],
        );
      }

      await db.customStatement(
        'INSERT INTO modifier_groups (dish_ucode, name, modifier_type, min_selection, max_selection, sort_order, is_required, is_active) '
        'VALUES (NULL, ?, 1, 0, 2, 3, 0, 1)',
        ['Соус'],
      );
      final g3Row = await db
          .customSelect('SELECT last_insert_rowid() as id')
          .getSingle();
      final g3 = g3Row.read<int>('id');
      for (final opt in <List<dynamic>>[
        ['Кетчуп', 100.0, 1],
        ['Майонез', 100.0, 2],
        ['Чесночный', 150.0, 3],
        ['Сырный', 200.0, 4],
        ['Без соуса', 0.0, 5],
      ]) {
        await db.customStatement(
          'INSERT INTO modifier_options (group_id, name, price_adjustment, sort_order, is_available, is_default) '
          'VALUES (?, ?, ?, ?, 1, 0)',
          [g3, opt[0], opt[1], opt[2]],
        );
      }

      await db.customStatement(
        'INSERT INTO modifier_groups (dish_ucode, name, modifier_type, min_selection, max_selection, sort_order, is_required, is_active) '
        'VALUES (NULL, ?, 1, 0, 3, 4, 0, 1)',
        ['Дополнительно'],
      );
      final g4Row = await db
          .customSelect('SELECT last_insert_rowid() as id')
          .getSingle();
      final g4 = g4Row.read<int>('id');
      for (final opt in <List<dynamic>>[
        ['Сыр', 300.0, 1],
        ['Бекон', 400.0, 2],
        ['Яйцо', 200.0, 3],
        ['Халапеньо', 150.0, 4],
        ['Зелень', 0.0, 5],
      ]) {
        await db.customStatement(
          'INSERT INTO modifier_options (group_id, name, price_adjustment, sort_order, is_available, is_default) '
          'VALUES (?, ?, ?, ?, 1, 0)',
          [g4, opt[0], opt[1], opt[2]],
        );
      }

      await db.customStatement(
        'INSERT INTO modifier_groups (dish_ucode, name, modifier_type, min_selection, max_selection, sort_order, is_required, is_active) '
        'VALUES (NULL, ?, 0, 0, 1, 5, 0, 1)',
        ['Гарнир'],
      );
      final g5Row = await db
          .customSelect('SELECT last_insert_rowid() as id')
          .getSingle();
      final g5 = g5Row.read<int>('id');
      for (final opt in <List<dynamic>>[
        ['Рис', 0.0, 1, true],
        ['Картофель фри', 200.0, 2, false],
        ['Овощи гриль', 300.0, 3, false],
        ['Без гарнира', 0.0, 4, false],
      ]) {
        await db.customStatement(
          'INSERT INTO modifier_options (group_id, name, price_adjustment, sort_order, is_available, is_default) '
          'VALUES (?, ?, ?, ?, 1, ?)',
          [g5, opt[0], opt[1], opt[2], (opt[3] as bool) ? 1 : 0],
        );
      }

      print('[Seed] Created 5 modifier groups with options');
    }

    final existingDishIngr = await db
        .customSelect('SELECT COUNT(*) as cnt FROM dish_ingredients')
        .getSingle();
    if (existingDishIngr.read<int>('cnt') == 0) {
      final borshchIngredients = <List<dynamic>>[
        [90007, 80013, 2.0, 1.24, 26.0, 38.0, 250.0, 26.0, 18.0, 0.0],
        [90007, 80012, 0.5, 0.36, 20.0, 10.0, 28.0, 1.8, 0.1, 4.7],
        [90007, 80010, 1.0, 0.73, 25.0, 3.0, 77.0, 2.0, 0.4, 16.3],
        [90007, 80011, 0.3, 0.228, 20.0, 5.0, 32.0, 1.3, 0.1, 6.9],
        [90007, 80006, 0.3, 0.222, 16.0, 26.0, 41.0, 1.1, 0.1, 8.2],
        [90007, 80008, 0.3, 0.243, 15.0, 10.0, 20.0, 0.9, 0.2, 3.9],
        [90007, 80021, 0.2, 0.2, 0.0, 0.0, 115.0, 2.6, 10.0, 3.6],
        [90007, 80003, 0.03, 0.03, 0.0, 0.0, null, null, null, null],
      ];

      final steakIngredients = <List<dynamic>>[
        [90010, 80013, 0.4, 0.248, 26.0, 38.0, 250.0, 26.0, 18.0, 0.0],
        [90010, 80002, 0.03, 0.03, 0.0, 0.0, 899.0, 0.0, 99.9, 0.0],
        [90010, 80003, 0.005, 0.005, 0.0, 0.0, null, null, null, null],
        [90010, 80004, 0.002, 0.002, 0.0, 0.0, null, null, null, null],
        [90010, 80023, 0.02, 0.02, 0.0, 0.0, 748.0, 0.5, 82.5, 0.8],
        [90010, 80007, 0.01, 0.01, 0.0, 0.0, 149.0, 6.5, 0.5, 29.9],
      ];

      final plovIngredients = <List<dynamic>>[
        [90011, 80013, 2.0, 1.24, 26.0, 38.0, 250.0, 26.0, 18.0, 0.0],
        [90011, 80017, 1.5, 1.5, 0.0, 0.0, 130.0, 2.7, 0.3, 28.2],
        [90011, 80011, 0.5, 0.38, 20.0, 5.0, 32.0, 1.3, 0.1, 6.9],
        [90011, 80006, 0.4, 0.296, 16.0, 26.0, 41.0, 1.1, 0.1, 8.2],
        [90011, 80002, 0.3, 0.3, 0.0, 0.0, 899.0, 0.0, 99.9, 0.0],
        [90011, 80007, 0.03, 0.03, 0.0, 0.0, 149.0, 6.5, 0.5, 29.9],
        [90011, 80003, 0.03, 0.03, 0.0, 0.0, null, null, null, null],
      ];

      final beshbarmakIngredients = <List<dynamic>>[
        [90012, 80013, 2.5, 1.55, 26.0, 38.0, 250.0, 26.0, 18.0, 0.0],
        [90012, 80001, 0.8, 0.8, 0.0, 0.0, 364.0, 9.2, 1.2, 74.9],
        [90012, 80019, 4.0, 4.0, 0.0, 0.0, 157.0, 12.7, 10.9, 0.7],
        [90012, 80006, 0.5, 0.37, 16.0, 26.0, 41.0, 1.1, 0.1, 8.2],
        [90012, 80003, 0.04, 0.04, 0.0, 0.0, null, null, null, null],
        [90012, 80004, 0.005, 0.005, 0.0, 0.0, null, null, null, null],
      ];

      final carbonaraIngredients = <List<dynamic>>[
        [90014, 80018, 0.2, 0.2, 0.0, 0.0, 371.0, 13.0, 1.5, 70.5],
        [90014, 80014, 0.1, 0.062, 26.0, 38.0, 242.0, 19.4, 17.8, 0.0],
        [90014, 80022, 0.04, 0.04, 0.0, 0.0, 364.0, 23.0, 30.0, 0.0],
        [90014, 80024, 0.05, 0.05, 0.0, 0.0, 205.0, 2.5, 20.0, 3.4],
        [90014, 80019, 2.0, 2.0, 0.0, 0.0, 157.0, 12.7, 10.9, 0.7],
        [90014, 80003, 0.003, 0.003, 0.0, 0.0, null, null, null, null],
      ];

      final caesarIngredients = <List<dynamic>>[
        [90004, 80015, 0.2, 0.124, 26.0, 38.0, 165.0, 31.0, 3.6, 0.0],
        [90004, 80026, 0.1, 0.08, 20.0, 0.0, 14.0, 1.4, 0.2, 1.8],
        [90004, 80022, 0.04, 0.04, 0.0, 0.0, 364.0, 23.0, 30.0, 0.0],
        [90004, 80025, 0.06, 0.06, 0.0, 0.0, 265.0, 9.2, 3.2, 49.1],
        [90004, 80019, 1.0, 1.0, 0.0, 0.0, 157.0, 12.7, 10.9, 0.7],
        [90004, 80002, 0.02, 0.02, 0.0, 0.0, 899.0, 0.0, 99.9, 0.0],
      ];

      final allIngredients = [
        ...borshchIngredients,
        ...steakIngredients,
        ...plovIngredients,
        ...beshbarmakIngredients,
        ...carbonaraIngredients,
        ...caesarIngredients,
      ];

      final abbreviatedIngredients = <List<dynamic>>[
        [90001, 80025, 0.15, 0.15, 0.0, 0.0, null, null, null, null],
        [90001, 80008, 0.1, 0.085, 15.0, 0.0, null, null, null, null],
        [90001, 80022, 0.03, 0.03, 0.0, 0.0, null, null, null, null],
        [90002, 80022, 0.25, 0.25, 0.0, 0.0, null, null, null, null],
        [90002, 80030, 0.03, 0.03, 0.0, 0.0, null, null, null, null],
        [90003, 80002, 0.05, 0.05, 0.0, 0.0, null, null, null, null],
        [90003, 80007, 0.01, 0.01, 0.0, 0.0, null, null, null, null],
        [90003, 80029, 0.02, 0.02, 0.0, 0.0, null, null, null, null],
        [90005, 80008, 0.15, 0.128, 15.0, 0.0, null, null, null, null],
        [90005, 80009, 0.15, 0.12, 20.0, 0.0, null, null, null, null],
        [90005, 80022, 0.08, 0.08, 0.0, 0.0, null, null, null, null],
        [90006, 80010, 0.2, 0.15, 25.0, 3.0, null, null, null, null],
        [90006, 80011, 0.1, 0.076, 20.0, 5.0, null, null, null, null],
        [90006, 80019, 3.0, 3.0, 0.0, 0.0, null, null, null, null],
        [90006, 80021, 0.05, 0.05, 0.0, 0.0, null, null, null, null],
        [90008, 80016, 0.2, 0.16, 20.0, 0.0, null, null, null, null],
        [90008, 80029, 0.03, 0.03, 0.0, 0.0, null, null, null, null],
        [90008, 80024, 0.05, 0.05, 0.0, 0.0, null, null, null, null],
        [90009, 80024, 0.1, 0.1, 0.0, 0.0, null, null, null, null],
        [90009, 80006, 0.1, 0.074, 16.0, 26.0, null, null, null, null],
        [90009, 80023, 0.03, 0.03, 0.0, 0.0, null, null, null, null],
        [90013, 80013, 0.2, 0.124, 26.0, 38.0, null, null, null, null],
        [90013, 80018, 0.2, 0.2, 0.0, 0.0, null, null, null, null],
        [90013, 80008, 0.1, 0.085, 15.0, 10.0, null, null, null, null],
        [90013, 80006, 0.1, 0.074, 16.0, 26.0, null, null, null, null],
        [90015, 80013, 0.2, 0.124, 26.0, 38.0, null, null, null, null],
        [90015, 80025, 0.1, 0.1, 0.0, 0.0, null, null, null, null],
        [90015, 80026, 0.03, 0.024, 20.0, 0.0, null, null, null, null],
        [90016, 80010, 0.3, 0.225, 25.0, 0.0, null, null, null, null],
        [90016, 80002, 0.1, 0.1, 0.0, 0.0, null, null, null, null],
        [90017, 80017, 0.15, 0.15, 0.0, 0.0, null, null, null, null],
        [90017, 80003, 0.003, 0.003, 0.0, 0.0, null, null, null, null],
        [90018, 80008, 0.1, 0.085, 15.0, 10.0, null, null, null, null],
        [90018, 80009, 0.1, 0.08, 20.0, 0.0, null, null, null, null],
        [90018, 80002, 0.02, 0.02, 0.0, 0.0, null, null, null, null],
        [90019, 80022, 0.08, 0.08, 0.0, 0.0, null, null, null, null],
        [90019, 80027, 0.02, 0.02, 0.0, 0.0, null, null, null, null],
        [90019, 80019, 3.0, 3.0, 0.0, 0.0, null, null, null, null],
        [90020, 80022, 0.15, 0.15, 0.0, 0.0, null, null, null, null],
        [90020, 80023, 0.05, 0.05, 0.0, 0.0, null, null, null, null],
        [90020, 80005, 0.04, 0.04, 0.0, 0.0, null, null, null, null],
        [90021, 80020, 0.2, 0.2, 0.0, 0.0, null, null, null, null],
        [90021, 80024, 0.1, 0.1, 0.0, 0.0, null, null, null, null],
        [90021, 80005, 0.05, 0.05, 0.0, 0.0, null, null, null, null],
        [90022, 80028, 0.005, 0.005, 0.0, 0.0, null, null, null, null],
        [90022, 80005, 0.01, 0.01, 0.0, 0.0, null, null, null, null],
        [90023, 80027, 0.018, 0.018, 0.0, 0.0, null, null, null, null],
        [90024, 80027, 0.018, 0.018, 0.0, 0.0, null, null, null, null],
        [90024, 80020, 0.2, 0.2, 0.0, 0.0, null, null, null, null],
        [90025, 80029, 0.05, 0.05, 0.0, 0.0, null, null, null, null],
        [90025, 80005, 0.03, 0.03, 0.0, 0.0, null, null, null, null],
        [90026, 80029, 0.15, 0.15, 0.0, 0.0, null, null, null, null],
      ];

      allIngredients.addAll(abbreviatedIngredients);

      int sortIdx = 0;
      for (final ing in allIngredients) {
        await db.customStatement(
          'INSERT OR IGNORE INTO dish_ingredients '
          '(dish_ucode, ingredient_ucode, gross_quantity, net_quantity, '
          'cold_loss_percent, hot_loss_percent, calories, proteins, fats, carbs, '
          'season_coefficient, sort_order) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1.0, ?)',
          [...ing, sortIdx],
        );
        sortIdx++;
      }
      print('[Seed] Created ${allIngredients.length} dish ingredients');
    }

    final existingGost = await db
        .customSelect('SELECT COUNT(*) as cnt FROM gost_loss_norms')
        .getSingle();
    if (existingGost.read<int>('cnt') == 0) {
      final gostNorms = <List<dynamic>>[
        ['Картофель', 25.0, 3.0, 2],
        ['Картофель (зима)', 30.0, 3.0, 1],
        ['Морковь', 20.0, 5.0, 2],
        ['Морковь (зима)', 25.0, 5.0, 1],
        ['Свёкла', 20.0, 5.0, 0],
        ['Капуста белокочанная', 20.0, 10.0, 0],
        ['Лук репчатый', 16.0, 26.0, 0],
        ['Чеснок', 22.0, 0.0, 0],
        ['Томаты свежие', 15.0, 10.0, 0],
        ['Огурцы свежие', 20.0, 0.0, 0],
        ['Говядина (1 кат.)', 26.0, 38.0, 0],
        ['Свинина (мясная)', 15.0, 40.0, 0],
        ['Курица', 26.0, 28.0, 0],
        ['Рыба (средняя)', 35.0, 18.0, 0],
        ['Яйца', 12.5, 8.0, 0],
        ['Мука пшеничная', 1.0, 0.0, 0],
        ['Рис', 0.0, 0.0, 0],
        ['Макаронные изделия', 0.0, 0.0, 0],
        ['Масло сливочное', 0.0, 0.0, 0],
        ['Сыр твёрдый', 6.0, 0.0, 0],
        ['Молоко', 0.0, 0.0, 0],
        ['Сметана', 0.0, 0.0, 0],
      ];
      for (final gn in gostNorms) {
        await db.customStatement(
          'INSERT OR IGNORE INTO gost_loss_norms (product_name, cold_loss_percent, hot_loss_percent, season) '
          'VALUES (?, ?, ?, ?)',
          gn,
        );
      }
      print('[Seed] Created ${gostNorms.length} GOST loss norms');
    }

    final existingRestOrders = await db
        .customSelect('SELECT COUNT(*) as cnt FROM restaurant_orders')
        .getSingle();
    if (existingRestOrders.read<int>('cnt') == 0) {
      final tableRows = await db
          .customSelect('SELECT id, zone FROM restaurant_tables')
          .get();
      final List<int> tableIds = tableRows
          .map((r) => r.read<int>('id'))
          .toList();

      final linkableSales = await db
          .customSelect(
            'SELECT receipt_no, pos_id, amount, user_id, time FROM sales '
            'WHERE state = 4 '
            'ORDER BY time DESC LIMIT 250',
          )
          .get();

      int totalRestOrders = 0;
      for (var i = 0; i < 200 && i < linkableSales.length; i++) {
        final sale = linkableSales[i];
        final saleReceiptNo = sale.read<int>('receipt_no');
        final salePosId = sale.read<int>('pos_id');
        final saleAmount = sale.read<double>('amount');
        final saleUserId = sale.read<int>('user_id');
        final saleTime = sale.read<int>('time');

        final typeRoll = random.nextDouble();
        int orderType;
        int? tableId;
        String? deliveryAddress;
        String? deliveryPhone;

        if (typeRoll < 0.7) {
          orderType = 0;
          tableId = tableIds[random.nextInt(tableIds.length)];
        } else if (typeRoll < 0.9) {
          orderType = 1;
        } else {
          orderType = 2;
          deliveryAddress =
              'ул. ${['Абая', 'Назарбаева', 'Толе Би', 'Достык', 'Сатпаева', 'Жандосова', 'Тимирязева', 'Манаса', 'Розыбакиева', 'Гагарина'][random.nextInt(10)]}, д. ${1 + random.nextInt(200)}';
          deliveryPhone = '7701${(1000000 + random.nextInt(8999999))}';
        }

        final partySize = 1 + random.nextInt(6);

        final hasTips = random.nextDouble() < 0.4;
        final tips = hasTips
            ? (saleAmount * (0.05 + random.nextDouble() * 0.10) * 100)
                      .roundToDouble() /
                  100
            : 0.0;

        final closeTime = saleTime + 1800 + random.nextInt(5400);

        await db.customStatement(
          'INSERT OR IGNORE INTO restaurant_orders '
          '(table_id, receipt_no, pos_id, party_size, order_type, open_time, close_time, '
          'waiter_id, tips, delivery_address, delivery_phone, note) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            tableId,
            saleReceiptNo,
            salePosId,
            partySize,
            orderType,
            saleTime,
            closeTime,
            saleUserId,
            tips,
            deliveryAddress,
            deliveryPhone,
            null,
          ],
        );
        await db.customStatement(
          'UPDATE sales SET order_type = ? WHERE receipt_no = ? AND pos_id = ?',
          [orderType, saleReceiptNo, salePosId],
        );

        final dishUcodes = <int>[
          90001,
          90002,
          90003,
          90004,
          90005,
          90006,
          90007,
          90008,
          90009,
          90010,
          90011,
          90012,
          90013,
          90014,
          90015,
          90016,
          90017,
          90018,
          90019,
          90020,
          90021,
          90022,
          90023,
          90024,
          90025,
          90026,
          90027,
          90028,
          90029,
        ];
        final dishPrices = <int, double>{
          90001: 1800,
          90002: 3500,
          90003: 1500,
          90004: 2800,
          90005: 2200,
          90006: 1800,
          90007: 1500,
          90008: 3200,
          90009: 2000,
          90010: 8500,
          90011: 2500,
          90012: 3500,
          90013: 2200,
          90014: 3000,
          90015: 2800,
          90016: 800,
          90017: 500,
          90018: 1200,
          90019: 2500,
          90020: 2200,
          90021: 1500,
          90022: 500,
          90023: 800,
          90024: 1200,
          90025: 900,
          90026: 1500,
          90027: 400,
          90028: 1500,
          90029: 2500,
        };
        final numDishes = 1 + random.nextInt(3);
        for (var d = 0; d < numDishes; d++) {
          final dishUcode = dishUcodes[random.nextInt(dishUcodes.length)];
          final dishPrice = dishPrices[dishUcode] ?? 1500.0;
          final qty = 1.0;
          await db.customStatement(
            'INSERT OR IGNORE INTO sale_products (receipt_no, pos_id, ucode, barcode, category_id, quantity, price, price_before) '
            'VALUES (?, ?, ?, ?, NULL, ?, ?, ?)',
            [
              saleReceiptNo,
              salePosId,
              dishUcode,
              dishUcode,
              qty,
              dishPrice,
              dishPrice,
            ],
          );
        }

        totalRestOrders++;
      }
      print(
        '[Seed] Created $totalRestOrders restaurant orders (with dish sales)',
      );
    }

    final existingServiceProd = await db
        .customSelect(
          'SELECT COUNT(*) as cnt FROM product_infos WHERE ucode = 85001',
        )
        .getSingle();
    if (existingServiceProd.read<int>('cnt') == 0) {
      final serviceProducts = <List<dynamic>>[
        [85001, 85001, 'Замена экрана', 15000.0],
        [85002, 85002, 'Замена батареи', 8000.0],
        [85003, 85003, 'Чистка ноутбука', 5000.0],
        [85004, 85004, 'Химчистка пальто', 3000.0],
        [85005, 85005, 'Стирка постельного', 1500.0],
        [85006, 85006, 'Глажка рубашки', 500.0],
        [85007, 85007, 'Ремонт обуви', 2000.0],
        [85008, 85008, 'Диагностика', 2000.0],
      ];

      for (final sp in serviceProducts) {
        await db.customStatement(
          'INSERT OR IGNORE INTO product_infos (ucode, barcode, name, category_id, type, measure, quantity, is_deleted) '
          'VALUES (?, ?, ?, NULL, 4, 0, 0.0, 0)',
          [sp[0], sp[1], sp[2]],
        );
        await db.customStatement(
          'INSERT OR IGNORE INTO product_prices (ucode, barcode, selling_price) '
          'VALUES (?, ?, ?)',
          [sp[0], sp[1], sp[3]],
        );
      }

      final serviceTypeEntries = <List<dynamic>>[
        [85001, 60, 30, true],
        [85002, 30, 30, true],
        [85003, 45, 7, true],
        [85004, 1440, 0, false],
        [85005, 180, 0, false],
        [85006, 30, 0, false],
        [85007, 120, 14, false],
        [85008, 30, 0, true],
      ];
      for (final st in serviceTypeEntries) {
        await db.customStatement(
          'INSERT OR IGNORE INTO service_types (product_ucode, estimated_duration_minutes, warranty_days, requires_device, is_active) '
          'VALUES (?, ?, ?, ?, 1)',
          [st[0], st[1], st[2], st[3] == true ? 1 : 0],
        );
      }

      final consumableProducts = <List<dynamic>>[
        [85010, 85010, 'Экран (запчасть)', 8000.0],
        [85011, 85011, 'Клей B7000', 500.0],
        [85012, 85012, 'Салфетки (уп.)', 200.0],
        [85013, 85013, 'Батарея (запчасть)', 3000.0],
        [85014, 85014, 'Термопаста', 800.0],
        [85015, 85015, 'Растворитель', 600.0],
        [85016, 85016, 'Порошок стиральный', 400.0],
        [85017, 85017, 'Клей обувной', 350.0],
        [85018, 85018, 'Подошва (запчасть)', 1500.0],
      ];
      for (final cp in consumableProducts) {
        await db.customStatement(
          'INSERT OR IGNORE INTO product_infos (ucode, barcode, name, category_id, type, measure, quantity, is_deleted) '
          'VALUES (?, ?, ?, NULL, 5, 0, 50.0, 0)',
          [cp[0], cp[1], cp[2]],
        );
        final wprice = cp[3] as double;
        await db.customStatement(
          'INSERT OR IGNORE INTO product_prices (ucode, barcode, selling_price, wholesale_price) '
          'VALUES (?, ?, ?, ?)',
          [cp[0], cp[1], wprice * 1.3, wprice],
        );
      }

      final consumableLinks = <List<dynamic>>[
        [85001, 85010, 1.0],
        [85001, 85011, 1.0],
        [85001, 85012, 2.0],
        [85002, 85013, 1.0],
        [85003, 85014, 1.0],
        [85003, 85012, 3.0],
        [85004, 85015, 0.5],
        [85005, 85016, 0.3],
        [85007, 85017, 1.0],
        [85007, 85018, 1.0],
      ];
      for (final cl in consumableLinks) {
        await db.customStatement(
          'INSERT OR IGNORE INTO service_consumables (service_product_ucode, consumable_ucode, quantity) '
          'VALUES (?, ?, ?)',
          cl,
        );
      }

      print(
        '[Seed] Created ${serviceProducts.length} service products, '
        '${serviceTypeEntries.length} service types, '
        '${consumableProducts.length} consumables, '
        '${consumableLinks.length} consumable links',
      );
    }
  });

  sw.stop();
  print('[Seed] Done! Total time: ${sw.elapsedMilliseconds}ms');
}

int _pickHour(Random random) {
  final weights = <int, int>{
    9: 3,
    10: 5,
    11: 7,
    12: 12,
    13: 12,
    14: 8,
    15: 6,
    16: 6,
    17: 8,
    18: 12,
    19: 12,
    20: 8,
  };
  final totalWeight = weights.values.fold(0, (a, b) => a + b);
  var roll = random.nextInt(totalWeight);
  for (final entry in weights.entries) {
    roll -= entry.value;
    if (roll < 0) return entry.key;
  }
  return 12;
}

class _ProductInfo {
  final int ucode;
  final int barcode;
  final int? categoryId;
  final int measure;
  final double sellingPrice;

  const _ProductInfo({
    required this.ucode,
    required this.barcode,
    required this.categoryId,
    required this.measure,
    required this.sellingPrice,
  });
}

bool _seeded = false;

Future<bool> seedIfNeeded(AppDatabase db) async {
  if (_seeded) return false;
  try {
    final count = await db
        .customSelect('SELECT COUNT(*) as cnt FROM sales')
        .getSingle();
    if (count.read<int>('cnt') > 100) {
      _seeded = true;
      return false;
    }
    print('[Seed] Starting seed generation...');
    await generateSeedData(db);
    _seeded = true;

    final verification = await verifySeedData(db);
    print('[Seed] === VERIFICATION ===');
    for (final entry in verification.entries) {
      print('[Seed]   ${entry.key}: ${entry.value}');
    }
    print('[Seed] Seed generation complete!');
    return true;
  } catch (e, st) {
    print('[Seed] Error during seeding: $e');
    print('[Seed] Stack trace: $st');
    return false;
  }
}

Future<Map<String, int>> verifySeedData(AppDatabase db) async {
  final tables = [
    'sales',
    'sale_products',
    'payments',
    'refunds',
    'shifts',
    'agents',
    'supplies',
    'supply_products',
    'movements',
    'movement_products',
    'supplier_returns',
    'supplier_return_products',
    'cash_operations',
    'categories',
    'product_infos',
    'product_prices',
    'service_orders',
    'service_marks',
    'service_types',
    'service_consumables',
    'restaurant_tables',
    'restaurant_orders',
    'dish_ingredients',
    'gost_loss_norms',
  ];

  final result = <String, int>{};
  for (final table in tables) {
    try {
      final row = await db
          .customSelect('SELECT COUNT(*) as cnt FROM $table')
          .getSingle();
      result[table] = row.read<int>('cnt');
    } catch (_) {
      result[table] = -1;
    }
  }
  return result;
}

Future<void> clearAllDemoData(AppDatabase db) async {
  print('[Seed] Clearing all demo data...');

  await db.transaction(() async {
    final tables = [
      'dish_ingredients',
      'dish_recipe_versions',
      'dish_photos',
      'gost_loss_norms',
      'service_marks',
      'service_order_photos',
      'service_consumables',
      'service_types',
      'service_orders',
      'guest_splits',
      'restaurant_orders',
      'restaurant_tables',
      'refund_products',
      'refunds',
      'payments',
      'sale_products',
      'sales',
      'supplier_return_products',
      'supplier_returns',
      'movement_products',
      'movements',
      'supply_products',
      'supplies',
      'cash_operations',
      'writeoff_products',
      'writeoffs',
      'inventory_products',
      'inventories',
      'quick_products',
      'package_products',
      'product_prices',
      'product_infos',
      'categories',
      'agents',
      'shifts',
    ];

    for (final table in tables) {
      try {
        await db.customStatement('DELETE FROM $table');
      } catch (e) {
        print('[Seed] Skip table $table: $e');
      }
    }
  });

  _seeded = false;
  print('[Seed] All demo data cleared.');
}
