import 'package:telepos/domain/startup/boot_stage.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Чем закончился подъём кассы — по проводу.
///
/// Ничего здесь не запускается. Касса поднялась задолго до того, как смогла
/// отдать эту страницу, поэтому браузер спрашивает, чем это кончилось, а не
/// делает это заново. Ход выполнения доводится до конца сразу: изображать
/// открытие базы, которой этот процесс не владеет, — ложь ценой в настоящую
/// секунду времени оператора.
class WtAppBootstrap implements AppBootstrap {
  const WtAppBootstrap(this._wire);

  final WtDispatcher _wire;

  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async {
    try {
      final status = await _wire.ask(TillOps.startupBoot, null);
      onProgress(1.0, BootStage.ready);
      return status;
    } on WtProtocolError catch (error) {
      // Отказ приходит значением (И144). Заставка обязана сказать оператору,
      // что кассы нет, а не остаться белым прямоугольником: за 2026-08-04 на
      // этом же месте найдено три дефекта, и каждый белил экран целиком.
      onProgress(1.0, BootStage.tillNotResponding, '${error.code}');
      return AppInitStatus.databaseFailure;
    }
  }
}
