// СГЕНЕРИРОВАНО tools/icon_pipeline.py — править руками нечего.
//
// Кодовые точки идут от места в словаре ICONS конвейера, поэтому
// иконка, добавленная в конец, не сдвигает ни одной существующей.

import 'package:flutter/widgets.dart';

/// Собственный набор иконок мастера настройки.
///
/// Не Material Icons: набор рисуется в ComfyUI и доводится до шрифта
/// (`tools/icon_pipeline.py`), потому что растр, ужатый с генерации
/// 1024, мягок ровно на тех 20–24 px, где на него смотрят.
class TeleposIcons {
  TeleposIcons._();

  /// Имя семейства из pubspec.yaml.
  static const String family = 'TeleposIcons';

  static const IconData sale = IconData(0xE000, fontFamily: family);
  static const IconData refund = IconData(0xE001, fontFamily: family);
  static const IconData shift = IconData(0xE002, fontFamily: family);
  static const IconData history = IconData(0xE003, fontFamily: family);
  static const IconData tables = IconData(0xE004, fontFamily: family);
  static const IconData orders = IconData(0xE005, fontFamily: family);
  static const IconData serviceQueue = IconData(0xE006, fontFamily: family);
  static const IconData serviceIntake = IconData(0xE007, fontFamily: family);
  static const IconData warehouse = IconData(0xE008, fontFamily: family);
  static const IconData warehouses = IconData(0xE009, fontFamily: family);
  static const IconData batches = IconData(0xE00A, fontFamily: family);
  static const IconData serials = IconData(0xE00B, fontFamily: family);
  static const IconData cellStock = IconData(0xE00C, fontFamily: family);
  static const IconData claims = IconData(0xE00D, fontFamily: family);
  static const IconData marking = IconData(0xE00E, fontFamily: family);
  static const IconData wmsSettings = IconData(0xE00F, fontFamily: family);
  static const IconData agent = IconData(0xE010, fontFamily: family);
  static const IconData supply = IconData(0xE011, fontFamily: family);
  static const IconData cashOperation = IconData(0xE012, fontFamily: family);
  static const IconData settings = IconData(0xE013, fontFamily: family);
  static const IconData catalog = IconData(0xE014, fontFamily: family);
  static const IconData reports = IconData(0xE015, fontFamily: family);
  static const IconData sync = IconData(0xE016, fontFamily: family);
  static const IconData add = IconData(0xE017, fontFamily: family);
  static const IconData close = IconData(0xE018, fontFamily: family);
  static const IconData checkCircle = IconData(0xE019, fontFamily: family);
  static const IconData info = IconData(0xE01A, fontFamily: family);
  static const IconData check = IconData(0xE01B, fontFamily: family);
  static const IconData error = IconData(0xE01C, fontFamily: family);
  static const IconData delete = IconData(0xE01D, fontFamily: family);
  static const IconData save = IconData(0xE01E, fontFamily: family);
  static const IconData lock = IconData(0xE01F, fontFamily: family);
  static const IconData person = IconData(0xE020, fontFamily: family);

  /// Весь набор, в порядке кодовых точек. Нужен проверкам: тест,
  /// перечисляющий иконки своим списком, молчит ровно про ту, что в
  /// него забыли добавить.
  static const Map<String, IconData> all = <String, IconData>{
    'sale': sale,
    'refund': refund,
    'shift': shift,
    'history': history,
    'tables': tables,
    'orders': orders,
    'serviceQueue': serviceQueue,
    'serviceIntake': serviceIntake,
    'warehouse': warehouse,
    'warehouses': warehouses,
    'batches': batches,
    'serials': serials,
    'cellStock': cellStock,
    'claims': claims,
    'marking': marking,
    'wmsSettings': wmsSettings,
    'agent': agent,
    'supply': supply,
    'cashOperation': cashOperation,
    'settings': settings,
    'catalog': catalog,
    'reports': reports,
    'sync': sync,
    'add': add,
    'close': close,
    'checkCircle': checkCircle,
    'info': info,
    'check': check,
    'error': error,
    'delete': delete,
    'save': save,
    'lock': lock,
    'person': person,
  };
}
