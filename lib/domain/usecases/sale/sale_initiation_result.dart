import 'package:telepos/domain/entities/sale/sale_entity.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Результат `SaleInitiationUseCase.initiate()`.
///
/// Ровно одно из полей не `null`: `sale` — чек начат или продолжен,
/// `refusal` — начать нельзя, и названа причина. Это тот же приём, что и у
/// провода в целом (`WireRefusal`, I144): отказ — значение, которое
/// вызывающий обязан посмотреть, а не исключение, которое можно забыть
/// поймать. Круг правки 1 (задача 5): раньше `initiate()` был
/// `Future<dynamic>`, и это обесценивало саму идею — компилятор не заставлял
/// ни одного вызывающего посмотреть на `refusal`; `Future<SaleInitiationResult>`
/// делает отказ видимым в сигнатуре.
///
/// [sale] — `SaleEntity?` (круг правки 2), не `Sale` и не `dynamic`.
/// `Sale` — drift-тип, домену его знать нельзя
/// (`test/architecture/layering_test.dart` запрещает `package:telepos/data/`
/// и `package:drift/` в `lib/domain`), но `dynamic` был неправильным лечением
/// того же диагноза: он снимал именно ту проверку, ради которой затевалась
/// вся правка — `result.sale.receiptNo` компилировался безусловно, без
/// проверки на `null`. У домена уже есть доменная сущность для ровно этого
/// случая — `SaleEntity` (`lib/domain/entities/sale/sale_entity.dart`) с
/// `receiptNo`/`posId`, которые и читает `sale_controller.dart`; реализация
/// (`SaleInitiationUseCaseImpl`, слой данных) оборачивает `Sale` через
/// `SaleMapper.fromDrift()`, которым уже пользуются другие юзкейсы.
class SaleInitiationResult {
  const SaleInitiationResult.success(SaleEntity this.sale) : refusal = null;

  const SaleInitiationResult.refused(WireRefusal this.refusal) : sale = null;

  /// Чек, если начат заново или продолжен уже открытый. `null` при отказе.
  final SaleEntity? sale;

  /// Причина, по которой чек не начат. `null` при успехе.
  final WireRefusal? refusal;
}
