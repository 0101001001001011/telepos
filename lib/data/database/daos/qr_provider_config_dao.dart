import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/qr_provider_tables.dart';
import 'package:telepos/domain/payment/qr_provider_settings.dart';

part 'qr_provider_config_dao.g.dart';

/// Настройка провайдера QR/СБП — чтение и запись одной строки.
///
/// **Читатель у неё должен быть один** — `QrPaymentDesk`. Экран настройки
/// пишет и читает, чтобы показать «ключ задан»; провод не читает вовсе.
/// Сторож исходника (`qr_secret_never_reaches_terminal_test`) краснеет на
/// втором читателе в `lib/backend/`, `lib/domain/wire/` и `lib/web/`.
@DriftAccessor(tables: [QrProviderConfigs])
class QrProviderConfigDao extends DatabaseAccessor<AppDatabase>
    with _$QrProviderConfigDaoMixin {
  QrProviderConfigDao(super.db);

  static const _rowId = 1;

  /// Настройка кассы. `null` — провайдер не заведён.
  Future<QrProviderSettings?> read() async {
    final row = await (select(
      qrProviderConfigs,
    )..where((c) => c.id.equals(_rowId))).getSingleOrNull();
    if (row == null) return null;
    final key = row.apiKey;
    return QrProviderSettings(
      baseUrl: row.baseUrl,
      code: row.providerCode,
      // Пустая строка ключа — «ключа нет», а не ключ из пустоты:
      // `Bearer ` без значения провайдер прочёл бы как отказ в доступе, и
      // беда называлась бы неверно.
      apiKey: key == null || key.isEmpty ? null : key,
      patience: Duration(seconds: row.patienceSeconds),
    );
  }

  Future<void> save(QrProviderSettings settings, {required DateTime at}) =>
      into(qrProviderConfigs).insertOnConflictUpdate(
        QrProviderConfigsCompanion.insert(
          id: const Value(_rowId),
          baseUrl: settings.baseUrl.trim(),
          providerCode: settings.code.trim(),
          apiKey: Value(settings.apiKey),
          patienceSeconds: Value(settings.patience.inSeconds),
          updatedAt: at.millisecondsSinceEpoch,
        ),
      );

  /// Снять настройку. Намерения, заведённые с ней, остаются в
  /// `payment_intents` — разбирать их станет нечем, и кассир об этом
  /// узнает отказом `qr_not_configured`, а не молчанием.
  Future<void> clear() =>
      (delete(qrProviderConfigs)..where((c) => c.id.equals(_rowId))).go();
}
