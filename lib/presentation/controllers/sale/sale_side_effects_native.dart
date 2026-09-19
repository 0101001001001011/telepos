import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:telepos/presentation/controllers/app/stock_revision.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

/// Кассовая половина шва — см. докстринг `sale_side_effects.dart`.
///
/// Здесь живут те самые импорты, из-за которых экран продажи тянул базу
/// кассы одним прыжком. Файл компилируется только там, где эти четыре
/// экрана существуют.
///
/// Имя типа базы в комментариях этого каталога не пишется намеренно:
/// сторож `test/architecture/sale_layering_test.dart` читает файл текстом
/// и не отличает код от докстринга — он сам называет это своим вторым
/// пределом и просит переписать комментарий.

/// Смена перечиталась: начало чека могло её открыть.
void refreshShiftAfterSaleStart(Ref ref) {
  ref.invalidate(shiftControllerProvider);
}

/// Продажа завершена — перечитывается всё, чью правду она изменила: смена
/// (деньги в кассе), история (новый чек), каталог и остатки (списанный
/// товар).
///
/// Каталог и остатки — **счётчиком** (`StockRevision`, задача 36), а не
/// `invalidate`: на тот же счётчик подписана выдача поиска экрана продажи,
/// которой прежние четыре строки не касались вовсе, и его же поднимают
/// инвентаризация и перемещение. Одна дорога на «остатки изменились», а не
/// две параллельных.
void refreshAfterSaleCompleted(Ref ref) {
  ref.invalidate(shiftControllerProvider);
  ref.invalidate(historyControllerProvider);
  ref.read(stockRevisionProvider.notifier).bump();
}
