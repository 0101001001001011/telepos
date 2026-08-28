import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Первый запуск установки — по проводу.
///
/// # Что здесь изменилось по существу, а не по транспорту
///
/// Восстановление из копии и загрузка данных организации идут **минутами**, и
/// до провода канала для хода выполнения не существовало: предшественник этого
/// файла честно писал о себе, что придумывать промежуточные числа отказывается,
/// и двигал полосу с 0.1 сразу на 1.0. Теперь это `run` — последовательность
/// кадров хода выполнения и один завершающий, — и [BootProgress] получает
/// столько чисел, сколько их есть у кассы.
///
/// # Почему оборванная работа не считается удачной
///
/// `RunProgress.isDone` приходит только с завершающим кадром. Работа,
/// оборванная на середине, этого кадра не шлёт вовсе, и здесь она становится
/// `false`: «готово» означает целый магазин, и выдать незавершённое
/// восстановление за завершённое дороже, чем показать отказ.
class WtFirstLaunchRepository implements FirstLaunchRepository {
  const WtFirstLaunchRepository(this._wire);

  final WtDispatcher _wire;

  @override
  Future<FirstLaunchResult> determineResult() async {
    try {
      return await _wire.ask(TillOps.setupFirstLaunch, null);
    } on WtProtocolError {
      // Недостижимая касса — факт о развёртывании, а не исключительная
      // ситуация: продолжать без неё терминал всё равно не может, и увидеть он
      // должен названный экран, а не пустоту (И144).
      return FirstLaunchResult.offlineMode;
    }
  }

  @override
  Future<List<FoundBackup>> findAvailableBackups() async {
    try {
      return await _wire.ask(TillOps.setupBackups, null);
    } on WtProtocolError {
      // «Копий не нашлось» и «спросить было некого» для этого экрана одно и то
      // же: предложить нечего.
      return const [];
    }
  }

  @override
  Future<bool> restoreFromBackup(
    FoundBackup backup,
    {BootProgress? onProgress}
  ) => _drive(_wire.run(TillOps.setupRestore, backup), onProgress);

  @override
  Future<bool> loadGlobalData({BootProgress? onProgress}) =>
      _drive(_wire.run(TillOps.setupLoadGlobalData, null), onProgress);

  @override
  Future<String> startNewPos() async {
    try {
      return await _wire.ask(TillOps.setupNewPos, null);
    } on WtProtocolError catch (error) {
      // Здесь отказ **не** сворачивается в значение, в отличие от чтений выше:
      // пустой ключ выглядел бы как заведённая касса, у которой ключ почему-то
      // пуст, и обнаружилось бы это на первой синхронизации.
      throw StateError('касса не завела новую точку: ${error.code}');
    }
  }

  /// Прогоняет длинную работу, пересказывая её ход в [BootProgress].
  Future<bool> _drive(
    Stream<RunProgress<bool>> work,
    BootProgress? onProgress,
  ) async {
    var finished = false;
    var result = false;
    try {
      await for (final step in work) {
        if (step.isDone) {
          finished = true;
          result = step.done ?? false;
        } else {
          onProgress?.call(step.value ?? 0, step.text ?? '');
        }
      }
    } on WtProtocolError catch (error) {
      // Причина обязана дойти до полосы: остановившаяся молча полоса
      // неотличима от зависшей кассы.
      onProgress?.call(0, 'Ошибка: ${error.code}');
      return false;
    }
    // Поток кончился, не сказав «готово», — работа оборвана, а не сделана.
    return finished && result;
  }
}
