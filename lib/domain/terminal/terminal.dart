import 'package:meta/meta.dart';

/// Кто и как пользуется терминалом. Свойство терминала, а не сборки: один и тот
/// же файл на двух машинах даёт кассира и самообслуживание.
/// См. docs/system-architecture.md, И32.
enum PointMode { cashier, selfService, unattended, kitchen }

/// Рабочее место: экран, руки оператора, свой комплект устройств.
///
/// Устройства терминала больше не поле здесь — раньше это был плоский набор
/// (`printerType`, `printerAddress`, `scannerType`, `scalePort`,
/// `scaleBaudRate`, `drawerViaPrinter`, `displayPort`, `TerminalDevices`),
/// который допускал максимум один принтер одного протокола на терминал.
/// Устройства терминала — это [DeviceBinding]
/// (`lib/domain/terminal/device_binding.dart`), и читаются/пишутся через
/// отдельный контракт, [DeviceBindingRepository]
/// (`lib/domain/terminal/device_binding_repository.dart`) — не метод здесь,
/// потому что `TerminalRepository` уже имеет два биндинга
/// (`LocalTerminalRepository`, `HttpTerminalRepository`), и оба реализуют
/// `implements`, которое не наследует тело метода: новый абстрактный метод
/// здесь сломал бы компиляцию того биндинга, который его ещё не реализует, в
/// файле, которым владеет другая задача. См. доку на
/// `DeviceBindingRepository` для полного обоснования (план 2, задача 4).
@immutable
class Terminal {
  const Terminal({
    required this.id,
    required this.name,
    required this.pointMode,
  });

  final int id;
  final String name;
  final PointMode pointMode;
}
