import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Фиксирует пройденный мастер на кассе — по проводу.
///
/// Весь черновик едет одним обменом, потому что фиксация — одна транзакция.
/// Разбив её на обмен за шаг, обрыв сети оставил бы кассу со счетами и без
/// пользователей: такая касса не может ни принять деньги, ни быть
/// донастроенной.
class WtSetupRepository implements SetupRepository {
  const WtSetupRepository(this._wire);

  final WtDispatcher _wire;

  @override
  Future<void> completeSetup(SetupDraft draft) async {
    // Отказ пробрасывается, а не сворачивается в значение: мастер настройки
    // обязан остаться на месте и назвать причину. Тихо «завершившийся» мастер
    // над незафиксированной кассой — худший из возможных исходов.
    final bool committed;
    try {
      committed = await _wire.ask(TillOps.setupComplete, draft);
    } on WtProtocolError catch (error) {
      throw StateError('setup_not_committed: ${error.code} — ${error.detail}');
    }
    if (!committed) {
      throw StateError('setup_not_committed: касса не подтвердила фиксацию');
    }
  }
}
