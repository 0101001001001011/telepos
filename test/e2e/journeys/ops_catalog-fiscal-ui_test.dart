library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/create_product_info_use_case.dart';
import 'package:telepos/domain/usecases/product/product_info_and_price_edition_use_case.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUp(() => h.setUp());
  tearDown(() => h.tearDown());

  test('catalog fiscal attributes: vatRate/ntin/isMarkable persist on create, '
      'survive edits, and can be changed/cleared on edit', () async {
    final db = h.db;
    GetIt.I.registerSingleton<AppDatabase>(db);

    final create = GetIt.I<CreateProductInfoUseCase>();
    final edit = GetIt.I<ProductInfoAndPriceEditionUseCase>();

    final ucode = await create.create(
      barcode: 4609001,
      name: 'Сигареты Marlboro',
      type: 0,
      measure: 0,
      categoryId: 1,
      vatRate: 12,
      ntin: '04600000000017',
      isMarkable: true,
    );

    final created = await db.productInfoDao.findByUcode(ucode);
    expect(created, isNotNull, reason: 'product row must exist');
    expect(created!.vatRate, 12, reason: 'НДС rate persisted');
    expect(created.ntin, '04600000000017', reason: 'НКТ (NTIN) persisted');
    expect(created.isMarkable, isTrue, reason: 'markable flag persisted');
    expect(created.name, 'Сигареты Marlboro');
    expect(created.barcode, 4609001);
    expect(created.type, 0);
    expect(created.measure, 0);
    expect(created.isDeleted, isFalse);

    await edit.edit(ucode: ucode, userId: 1, name: 'Сигареты Marlboro Gold');
    final afterRename = await db.productInfoDao.findByUcode(ucode);
    expect(afterRename!.name, 'Сигареты Marlboro Gold');
    expect(afterRename.vatRate, 12, reason: 'НДС unchanged by rename');
    expect(afterRename.ntin, '04600000000017', reason: 'НКТ unchanged');
    expect(afterRename.isMarkable, isTrue, reason: 'markable unchanged');

    await edit.edit(
      ucode: ucode,
      userId: 1,
      vatRate: null,
      vatRateSet: true,
      ntin: '04600000000888',
      isMarkable: false,
    );
    final afterEdit = await db.productInfoDao.findByUcode(ucode);
    expect(afterEdit!.vatRate, isNull, reason: 'НДС cleared to «без НДС»');
    expect(afterEdit.ntin, '04600000000888', reason: 'НКТ updated');
    expect(afterEdit.isMarkable, isFalse, reason: 'markable turned off');
    expect(afterEdit.name, 'Сигареты Marlboro Gold');

    await edit.edit(ucode: ucode, userId: 1, isMarkable: true);
    final afterToggle = await db.productInfoDao.findByUcode(ucode);
    expect(afterToggle!.isMarkable, isTrue, reason: 'markable toggled back on');
    expect(
      afterToggle.vatRate,
      isNull,
      reason: 'vatRate untouched when vatRateSet omitted',
    );
    expect(afterToggle.ntin, '04600000000888', reason: 'НКТ untouched');

    final plainUcode = await create.create(
      barcode: 4609002,
      name: 'Хлеб ржаной',
      type: 0,
      measure: 0,
    );
    final plain = await db.productInfoDao.findByUcode(plainUcode);
    expect(plain!.vatRate, isNull, reason: 'no НДС unless specified');
    expect(plain.ntin, isNull, reason: 'no НКТ unless specified');
    expect(
      plain.isMarkable,
      isFalse,
      reason: 'never markable by default (safety)',
    );

    await db.productInfoDao.updateFiscalAttributes(
      plainUcode,
      vatRate: 0,
      vatRateSet: true,
      ntin: '04600000000999',
      isMarkable: true,
    );
    final plainUpdated = await db.productInfoDao.findByUcode(plainUcode);
    expect(plainUpdated!.vatRate, 0, reason: 'DAO set НДС 0%');
    expect(plainUpdated.ntin, '04600000000999');
    expect(plainUpdated.isMarkable, isTrue);
  });
}
