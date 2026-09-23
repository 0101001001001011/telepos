/// Настоящий курсор в кадре: ведётся к цели, а не появляется на ней.
///
/// # Зачем
///
/// Правила съёмки (`docs/video-production.md`, раздел 7) требуют
/// человеческого темпа: «курсор ведётся к цели, а не телепортируется; пауза
/// в полсекунды перед нажатием и после». Сценарная дорожка нажимает
/// программно (`tester.tap`) и физическую мышь не двигает вовсе — в записи
/// курсора не было ни одного кадра, только круги Material на месте нажатия.
///
/// # Почему нажатие всё равно остаётся программным
///
/// Курсор здесь — **только для кадра**. Само нажатие делает `tester.tap`, и
/// это не перестраховка: настоящий клик мышью пошёл бы в то окно, которое в
/// этот момент сверху, и любое движение человека за машиной испортило бы
/// дубль молча. Программное нажатие попадает туда, куда сказано, независимо
/// от того, что творится на рабочем столе. Курсор при этом стоит ровно там,
/// куда пришло нажатие, — зритель видит согласованную картину.
///
/// # Цена
///
/// Физическая мышь на время дубля занята: курсор прыгает по экрану. Решение
/// заказчика 2026-09-21 — так и снимать.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Point extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

typedef _SetCursorPosC = Int32 Function(Int32 x, Int32 y);
typedef _SetCursorPosDart = int Function(int x, int y);

typedef _GetCursorPosC = Int32 Function(Pointer<_Point> p);
typedef _GetCursorPosDart = int Function(Pointer<_Point> p);

typedef _ClientToScreenC = Int32 Function(IntPtr hwnd, Pointer<_Point> p);
typedef _ClientToScreenDart = int Function(int hwnd, Pointer<_Point> p);

typedef _FindWindowC = IntPtr Function(Pointer<Utf16> cls, Pointer<Utf16> name);
typedef _FindWindowDart = int Function(Pointer<Utf16> cls, Pointer<Utf16> name);

/// Водит системный курсор по экрану, оставаясь безвредным вне Windows.
///
/// На других платформах и при незаданном окне все действия превращаются в
/// пустые: дорожка должна оставаться запускаемой как обычная проверка, а не
/// падать оттого, что её гоняют не под запись.
class CursorDriver {
  CursorDriver._(this._hwnd, this._setPos, this._getPos, this._toScreen);

  final int _hwnd;
  final _SetCursorPosDart _setPos;
  final _GetCursorPosDart _getPos;
  final _ClientToScreenDart _toScreen;

  /// Ищет окно приложения по заголовку. `null` — курсор не водится.
  static CursorDriver? attach(String windowTitle) {
    if (!Platform.isWindows) return null;
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final findWindow = user32
          .lookupFunction<_FindWindowC, _FindWindowDart>('FindWindowW');
      final name = windowTitle.toNativeUtf16();
      final hwnd = findWindow(nullptr, name);
      calloc.free(name);
      if (hwnd == 0) return null;
      return CursorDriver._(
        hwnd,
        user32.lookupFunction<_SetCursorPosC, _SetCursorPosDart>(
          'SetCursorPos',
        ),
        user32.lookupFunction<_GetCursorPosC, _GetCursorPosDart>(
          'GetCursorPos',
        ),
        user32.lookupFunction<_ClientToScreenC, _ClientToScreenDart>(
          'ClientToScreen',
        ),
      );
    } on Object {
      // Не нашли — снимаем без курсора. Ронять дубль из-за указки нельзя:
      // картинка без курсора всё ещё картинка, а упавший прогон — ничто.
      return null;
    }
  }

  ({int x, int y}) _current() {
    final p = calloc<_Point>();
    try {
      _getPos(p);
      return (x: p.ref.x, y: p.ref.y);
    } finally {
      calloc.free(p);
    }
  }

  /// Переводит точку внутри окна в координаты экрана.
  ///
  /// Логические пиксели Flutter умножаются на плотность: на экране с
  /// масштабом 125% курсор иначе уезжал бы на четверть кадра левее и выше
  /// цели, причём тем сильнее, чем дальше от левого верхнего угла.
  ({int x, int y}) _toScreenPoint(Offset local, double pixelRatio) {
    final p = calloc<_Point>();
    try {
      p.ref.x = (local.dx * pixelRatio).round();
      p.ref.y = (local.dy * pixelRatio).round();
      _toScreen(_hwnd, p);
      return (x: p.ref.x, y: p.ref.y);
    } finally {
      calloc.free(p);
    }
  }

  /// Ведёт курсор к точке за [duration], продолжая рисовать кадры.
  ///
  /// Замедление к концу (`easeOutCubic`) — не украшение: равномерное
  /// движение с мгновенной остановкой читается механически, а взгляд
  /// зрителя должен успеть догнать указку до нажатия.
  Future<void> moveTo(
    WidgetTester tester,
    Offset local, {
    Duration duration = const Duration(milliseconds: 650),
  }) async {
    final target = _toScreenPoint(local, tester.view.devicePixelRatio);
    final from = _current();
    final steps = math.max(2, duration.inMilliseconds ~/ 16);

    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final eased = 1 - math.pow(1 - t, 3).toDouble();
      _setPos(
        (from.x + (target.x - from.x) * eased).round(),
        (from.y + (target.y - from.y) * eased).round(),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    _setPos(target.x, target.y);
  }
}
