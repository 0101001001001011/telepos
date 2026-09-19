import 'package:decimal/decimal.dart';

import 'package:telepos/domain/shift/shift_desk.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Смена с браузерного терминала — решение заказчика 2026-09-18.
///
/// # Что здесь закрыто
///
/// Замерено живьём в тот же день: смена старше суток запирает продажу окном
/// «Смена открыта более 24 часов. Продажа заблокирована. **Закройте смену на
/// кассе** и откройте новую». С планшета закрыть смену было нечем — окно
/// честно называло стену стеной. Плюс к этому дом терминала показывал «Смена
/// открыта» зелёным значком и при просроченной смене: состояние приезжало
/// один раз, в `AuthSession` при входе, и не менялось больше ничем.
///
/// # Арифметики здесь нет ни строки, и это главное свойство
///
/// Ни «должно быть», ни расхождения, ни возраста смены этот файл не считает.
/// Он **отправляет одно число — сколько человек насчитал в ящике** — и
/// показывает то, что посчитала касса.
///
/// Разбор, почему именно так, — в докстринге
/// `lib/domain/shift/shift_desk.dart`. Коротко: пересчёт денег — физический
/// замер, которого нет ни в одном журнале, и знает его только человек у
/// ящика. Всё остальное — арифметика над журналом кассы, и второй бухгалтер
/// разошёлся бы с первым на первой же правке. Вкладке, которой позволено
/// назвать системный итог, ничего не стоило бы закрыть смену на числе,
/// которого никто не считал: расхождение вышло бы нулевым по построению.
///
/// Возраст смены — тот же довод в малом: [ShiftDeskView.overAge] приходит с
/// кассы готовым, а не вычитается здесь из времени открытия. Предел (сутки,
/// сравнение `>=`) живёт в `ShiftAgeRule`, которым касса **запирает
/// продажу**; посчитай вкладка возраст сама, значок говорил бы одно, а
/// продажа — другое.
///
/// # Кассира эта половина не называет
///
/// [open] несёт только деньги. На кого открыть смену, решает касса по
/// сеансу (И162): именем смены подписан Z-отчёт и вся её выручка, и поле
/// «кассир» в кадре означало бы смену на чужое имя одной правкой тела.
class WtShiftDesk implements ShiftDeskRepository {
  const WtShiftDesk(this._wire);

  final WtDispatcher _wire;

  /// Отказ провода становится [WireRefusal] **с тем же кодом** — тем же
  /// приёмом, что у `WtQrProviderSetup` и `WtReceiptTemplateSetup`.
  Future<T> _named<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }

  @override
  Stream<ShiftDeskView> watch() => _wire.watch(TillOps.shiftState, null);

  @override
  Future<void> close({Decimal? counted}) =>
      _named(() => _wire.ask(TillOps.shiftClose, counted));

  @override
  Future<void> open({Decimal? openingCash}) =>
      _named(() => _wire.ask(TillOps.shiftOpen, openingCash));
}
