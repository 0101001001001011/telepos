/// Касса меряет смену, а не пишет «unknown».
///
/// # Что измерено 2026-09-21
///
/// Заказчик, глядя на экран входа сразу после мастера: «На экране ввода PIN
/// у нас надпись Shift: unknown».
///
/// Это слово разработчика там, где есть измеримый ответ. Докстрока самого
/// `ShiftStatus` говорит прямо: «Касса сама его не пишет никогда: она смену
/// измеряет и отвечает `open` или `closed`». Писала.
///
/// # Почему `unknown` всё-таки остаётся
///
/// Он заведён для браузерного терминала: там ответ про смену едет по
/// проводу, и до ответа честно сказать нечего. Проба держит обе стороны —
/// касса меряет, терминал без репозитория остаётся при «не знаю».
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/entities/shift/shift_entity.dart';
import 'package:telepos/domain/repositories/shift_repository.dart';
import 'package:telepos/domain/shift/shift_status.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';

/// Репозиторий смен, который отвечает заданным.
///
/// Остальные члены бросают: случайная новая зависимость обязана падать
/// громко, а не возвращать правдоподобное.
class _Shifts implements ShiftRepository {
  _Shifts(this._open);

  final ShiftEntity? _open;
  int asked = 0;

  @override
  Future<ShiftEntity?> findOpenedShift() async {
    asked++;
    return _open;
  }

  @override
  Future<ShiftEntity?> findById(int shiftId) => throw UnimplementedError();

  @override
  Future<int> openShift(int userId) => throw UnimplementedError();

  @override
  Future<void> closeShift(
    int shiftId, {
    required int closeTime,
    required int openTime,
    required Decimal cashInPos,
  }) => throw UnimplementedError();

  @override
  Future<ShiftEntity?> findLastClosed() => throw UnimplementedError();

  @override
  Future<void> markAsSynced(int shiftId) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'login не имеет права звать ${invocation.memberName} у смен',
  );
}

/// Репозиторий, который отказывает: значок смены не повод не пустить в кассу.
class _BrokenShifts extends _Shifts {
  _BrokenShifts() : super(null);

  @override
  Future<ShiftEntity?> findOpenedShift() async => throw StateError('база');
}

void main() {
  tearDown(() => GetIt.I.reset());

  test('репозиторий смен отвечает — это предпосылка проб', () async {
    final shifts = _Shifts(null);
    expect(await shifts.findOpenedShift(), isNull);
    expect(shifts.asked, 1);
  });

  test('смена измеряется и становится «закрыта», а не «не знаю»', () async {
    await GetIt.I.reset();
    final shifts = _Shifts(null);
    GetIt.I.registerSingleton<ShiftRepository>(shifts);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(loginControllerProvider.notifier);

    await notifier.measureShiftForTest();

    expect(
      container.read(loginControllerProvider).shift,
      ShiftStatus.closed,
      reason:
          'база под рукой, и ответ измерим. «Shift: unknown» на кассе — '
          'слово разработчика',
    );
    expect(shifts.asked, 1);
  });

  test('открытая смена узнаётся открытой', () async {
    await GetIt.I.reset();
    GetIt.I.registerSingleton<ShiftRepository>(
      _Shifts(
        ShiftEntity(
          id: 1,
          userId: 1,
          openTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          isOpened: true,
        ),
      ),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(loginControllerProvider.notifier);

    await notifier.measureShiftForTest();

    expect(container.read(loginControllerProvider).shift, ShiftStatus.open);
  });

  test(
    'без репозитория остаётся «не знаю» — это браузерный терминал',
    () async {
      await GetIt.I.reset();

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);

      await notifier.measureShiftForTest();

      expect(
        container.read(loginControllerProvider).shift,
        ShiftStatus.unknown,
        reason:
            'у терминала ответ едет по проводу, и до ответа честно сказать '
            'нечего. Соврать «закрыта» значило бы увести кассира не туда',
      );
    },
  );

  test('отказ базы не роняет вход', () async {
    await GetIt.I.reset();
    GetIt.I.registerSingleton<ShiftRepository>(_BrokenShifts());

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(loginControllerProvider.notifier);

    await notifier.measureShiftForTest();

    expect(
      container.read(loginControllerProvider).shift,
      ShiftStatus.unknown,
      reason: 'значок смены — не повод не пустить кассира в кассу',
    );
  });
}
