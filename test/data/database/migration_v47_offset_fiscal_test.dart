/// Миграция v46→v47: сертификат и аванс в фискальном документе.
///
/// Три настройки кассы, колонка «чем принят аванс» и поправка посевной
/// трактовки двух системных видов. Проверяется **работой**: чтение настроек
/// DAO, запись и перечтение, строка справочника до и после.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/payment/payment_kind.dart';

void main() {
  /// База «как на v46»: схема нынешняя без четырёх колонок v47, посевная
  /// трактовка двух видов — `cash`, трактовка оператора у бонуса — своя.
  Future<AppDatabase> openFromV46({String certificateTreatment = 'cash'}) async {
    final probe = AppDatabase.forTesting(NativeDatabase.memory());
    final ddl =
        (await probe
                .customSelect(
                  'SELECT sql FROM sqlite_master '
                  "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'",
                )
                .get())
            .map((r) => r.read<String>('sql'))
            .toList();
    await probe.close();

    final raw = sqlite3.sqlite3.openInMemory();
    for (final statement in ddl) {
      raw.execute(statement);
    }
    for (final column in const [
      'fiscalize_certificate_sale',
      'offset_fiscal_layout',
      'fiscalize_prepayment_receipt',
    ]) {
      raw.execute('ALTER TABLE this_pos_entries DROP COLUMN $column');
    }
    raw.execute('ALTER TABLE cash_operations DROP COLUMN kind_id');
    raw.execute(
      'INSERT INTO this_pos_entries (r_id, id, company_name) '
      "VALUES (1, 1, 'ТОО Ромашка')",
    );
    raw.execute(
      "INSERT INTO payment_kinds (id, code, name, settlement, fiscal_treatment, "
      'is_system, is_active) VALUES '
      "(5, 'certificate', 'Сертификат', 1, '$certificateTreatment', 1, 0), "
      "(7, 'prepayment', 'Предоплата', 1, 'cash', 1, 0), "
      "(1, 'cash', 'Наличные', 0, 'cash', 1, 1)",
    );
    raw.execute('PRAGMA user_version = 46');
    return AppDatabase.forTesting(NativeDatabase.opened(raw));
  }

  Future<String> treatmentOf(AppDatabase db, int id) async => (await db
          .customSelect(
            'SELECT fiscal_treatment FROM payment_kinds WHERE id = $id',
          )
          .getSingle())
      .read<String>('fiscal_treatment');

  test('свежая база: версия схемы — текущая, умолчания поставки', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO this_pos_entries (r_id, id) VALUES (1, 1)",
    );
    expect(
      await db.thisPosDao.offsetFiscalSettings(),
      FiscalOffsetSettings.defaults,
    );
    expect(FiscalOffsetSettings.defaults.fiscalizeCertificateSale, isFalse);
    expect(FiscalOffsetSettings.defaults.offsetLayout, OffsetFiscalLayout.discount);
    expect(FiscalOffsetSettings.defaults.fiscalizePrepaymentReceipt, isTrue);
  });

  test('база v46 доезжает до v47: умолчания, запись и перечтение', () async {
    final db = await openFromV46();
    addTearDown(db.close);

    expect(
      await db.thisPosDao.offsetFiscalSettings(),
      FiscalOffsetSettings.defaults,
      reason: 'существующая касса получает умолчания заказчика',
    );

    const chosen = FiscalOffsetSettings(
      fiscalizeCertificateSale: true,
      offsetLayout: OffsetFiscalLayout.surchargeOnly,
      fiscalizePrepaymentReceipt: false,
    );
    expect(await db.thisPosDao.saveOffsetFiscalSettings(chosen), 1);
    expect(await db.thisPosDao.offsetFiscalSettings(), chosen);

    // Колонка «чем принят аванс» пишется и читается.
    await db.customStatement(
      'INSERT INTO cash_operations (amount, type, kind_id) VALUES (700, 0, 2)',
    );
    final row = await db.select(db.cashOperations).getSingle();
    expect(row.kindId, SystemPaymentKindIds.card);
  });

  test('посевная трактовка `cash` у сертификата и предоплаты сменилась, '
      'чужие строки не тронуты', () async {
    final db = await openFromV46();
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get(); // миграция идёт при открытии

    expect(
      await treatmentOf(db, SystemPaymentKindIds.certificate),
      FiscalTreatment.offsetNotFiscal.code,
    );
    expect(
      await treatmentOf(db, SystemPaymentKindIds.prepayment),
      FiscalTreatment.offsetNotFiscal.code,
    );
    expect(
      await treatmentOf(db, SystemPaymentKindIds.cash),
      'cash',
      reason: 'наличные — не зачёт; условие шага узкое',
    );
  });

  test('трактовку, выбранную оператором, шаг не переписывает', () async {
    final db = await openFromV46(certificateTreatment: 'notAPayment');
    addTearDown(db.close);
    expect(
      await treatmentOf(db, SystemPaymentKindIds.certificate),
      'notAPayment',
    );
  });
}
