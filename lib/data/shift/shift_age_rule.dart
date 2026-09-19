import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show payShiftOverAgeCode;
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Потолок возраста смены — **правило кассы**, одно на начало чека и на
/// оплату (I1; задача 27 плана «Продажа с браузерного терминала»).
///
/// # Почему правило над базой, а не порт
///
/// До задачи 27 правило держали необязательный порт и клиент:
///
/// - `LocalPaymentService` получал `ShiftService?` доводом
///   (`service_locator.dart`: `isRegistered<ShiftService>() ? … : null`) и
///   начинал проверку с `if (shifts == null) return;` — касса, собранная без
///   порта, брала деньги в смене любого возраста;
/// - начало чека на кассе не проверялось вовсе; проверял экран
///   (`SaleNotifier._ensureShiftNotOverAge`), и в браузере, где `ShiftService`
///   не привязан, его `catch` возвращал `true`.
///
/// Оба пути сводились к «проверить нечем — значит можно». Смена лежит в той
/// же базе, что чек и деньги: проверить кассе есть чем **всегда**, и
/// необязательная зависимость здесь была только способом её забыть. Правило
/// строится службой изнутри из её же базы — отсутствовать ему негде.
///
/// # Предел, названный здесь: смена одна на кассу
///
/// Мерится **открытая смена кассы** (`ShiftDao.findOpenedShift`), а не смена
/// вошедшего кассира: в базе сегодня смена одна на кассу. Правило заказчика
/// «каждый кассир работает в своей смене» этим не выполнено и этой задачей
/// не решалось — это модель смены, а не проверка её возраста.
final class ShiftAgeRule {
  const ShiftAgeRule({
    required AppDatabase db,
    DateTime Function() clock = DateTime.now,
    this.maxAge = limit,
  }) : _db = db,
       _clock = clock;

  /// Сутки — граница прежней клиентской проверки
  /// (`ShiftServiceImpl.isShiftOverAge`), и сравнение то же: `>=`.
  static const limit = Duration(hours: 24);

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Duration maxAge;

  /// Открытая смена старше [maxAge].
  ///
  /// Открытой смены нет — «не старше»: это не пропуск проверки, а другой
  /// отказ, и называет его другое место (`shift_not_open`,
  /// `SaleInitiationUseCaseImpl`). Ошибка чтения базы не глотается.
  Future<bool> isOverAge() async {
    final shift = await _db.shiftDao.findOpenedShift();
    if (shift == null || !shift.isOpened) return false;
    final nowSec = _clock().millisecondsSinceEpoch ~/ 1000;
    return nowSec - shift.openTime >= maxAge.inSeconds;
  }

  /// Названный отказ [payShiftOverAgeCode], если смена старше [maxAge].
  Future<void> require() async {
    if (await isOverAge()) {
      throw const WireRefusal(
        payShiftOverAgeCode,
        'смена открыта более 24ч — закройте смену',
      );
    }
  }
}
