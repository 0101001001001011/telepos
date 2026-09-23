import 'package:drift/drift.dart';

/// Настройка провайдера QR/СБП — схема v46.
///
/// **Одна строка на кассу** (`id = 1`): провайдер у кассы один, и второй
/// строке не было бы читателя. Разбор, почему своя таблица, а не колонки
/// `ThisPosEntries`, и кто её читает — в докстринге доменного
/// `QrProviderSettings`.
///
/// [apiKey] хранится открытым текстом, как `ThisPosEntries.webkassaToken`:
/// шифровать его ключом, лежащим рядом в той же установке, значило бы
/// изображать защиту. Настоящая граница здесь другая — ключ **не покидает
/// кассу** ни одним ответом провода, и это сторожится пробой.
@DataClassName('QrProviderConfigEntry')
class QrProviderConfigs extends Table {
  IntColumn get id => integer()();

  /// Адрес провайдера.
  TextColumn get baseUrl => text().withLength(min: 1, max: 512)();

  /// Короткое имя провайдера — уезжает в `Payments.providerCode`.
  TextColumn get providerCode => text().withLength(min: 1, max: 64)();

  /// Секрет провайдера. `NULL` — провайдер ключа не требует.
  TextColumn get apiKey => text().nullable()();

  /// Сколько касса ждёт покупателя, секундами.
  IntColumn get patienceSeconds => integer().withDefault(const Constant(180))();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
