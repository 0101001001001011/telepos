import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// Последние совершённые чеки — подсказка диалогу «возврат по чеку».
///
/// # Зачем контракт ради списка
///
/// `ReceiptInputDialog` показывал последние тридцать чеков, читая
/// `saleDao.findRecentCompleted` **прямо из виджета**. Это работало на кассе
/// и делало диалог непереносимым: база тянет `dart:ffi`, и веб-сборка на нём
/// не компилировалась. Контракт разрывает эту связь, а кто его исполняет —
/// решает точка входа.
///
/// # Честно о том, чего сегодня нет
///
/// **Реализации по проводу у этого контракта нет.** Своей операции в
/// каталоге `RefundOps` (задача 19, шесть операций) список последних чеков не
/// получил, и заводить седьмую задачей 20 значило бы менять каталог в обход
/// задачи, которая его закрыла. Поэтому в браузерном терминале контракт
/// **не зарегистрирован**, диалог спрашивает его через
/// `GetIt.I.isRegistered` и без него показывает «последних чеков нет», а не
/// падает и не врёт.
///
/// Кассир на планшете при этом не заперт: номер чека вводится с цифровой
/// клавиатуры, и возврат по нему работает целиком. Пропадает подсказка, а не
/// возможность. Недостающая операция названа задаче 21 (живые сценарии) —
/// именно там станет видно, насколько она нужна.
abstract interface class RecentReceipts {
  /// Последние совершённые чеки, новыми вперёд.
  Future<List<RecentReceipt>> recent({int limit});
}

/// Одна строка подсказки. Ровно то, что показывает диалог, — не строка
/// таблицы `Sales`: чек в подсказке это номер, время и сумма.
@immutable
class RecentReceipt {
  const RecentReceipt({
    required this.receiptNo,
    required this.posId,
    required this.time,
    required this.amount,
  });

  final int receiptNo;

  final int posId;

  /// Время чека в секундах эпохи — тем же числом, каким его хранит `Sales`.
  final int time;

  /// Сумма чека. `Decimal` P18,S3, никогда `double` (И159).
  final Decimal amount;

  @override
  bool operator ==(Object other) =>
      other is RecentReceipt &&
      other.receiptNo == receiptNo &&
      other.posId == posId &&
      other.time == time &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(receiptNo, posId, time, amount);
}
