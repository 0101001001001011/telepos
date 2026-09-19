import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/print/receipt_paper_width_source.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';

/// Ширина ленты из привязки чекового принтера этой кассы — см.
/// [ReceiptPaperWidthSource] и [receiptPaperWidthOf].
///
/// Зависимости можно не передавать: тогда они берутся из DI **в момент
/// печати**. Так служба печати, собранная до того, как мастер создал терминал
/// и привязки, всё равно читает то, что есть сейчас, а не то, что было при её
/// сборке.
///
/// Отказ чтения — не отказ печати (И30): чек выходит на узкой ленте, причина
/// уходит в журнал.
class BoundReceiptPaperWidth implements ReceiptPaperWidthSource {
  BoundReceiptPaperWidth({
    TerminalRepository? terminals,
    DeviceBindingRepository? bindings,
    DeviceProfileCatalog? catalog,
    Talker? logger,
  }) : _terminals = terminals,
       _bindings = bindings,
       _catalog = catalog,
       _logger = logger;

  final TerminalRepository? _terminals;
  final DeviceBindingRepository? _bindings;
  final DeviceProfileCatalog? _catalog;
  final Talker? _logger;

  @override
  Future<ReceiptPaperWidth> current() async {
    final getIt = GetIt.I;
    final terminals =
        _terminals ??
        (getIt.isRegistered<TerminalRepository>()
            ? getIt<TerminalRepository>()
            : null);
    final bindings =
        _bindings ??
        (getIt.isRegistered<DeviceBindingRepository>()
            ? getIt<DeviceBindingRepository>()
            : null);
    final catalog =
        _catalog ??
        (getIt.isRegistered<DeviceProfileCatalog>()
            ? getIt<DeviceProfileCatalog>()
            : null);
    if (terminals == null || bindings == null || catalog == null) {
      return ReceiptPaperWidth.mm58;
    }
    try {
      final self = await terminals.self();
      return receiptPaperWidthOf(await bindings.forTerminal(self.id), catalog);
    } on InstallationNotConfiguredException {
      return ReceiptPaperWidth.mm58;
    } catch (e) {
      _logger?.warning(
        '[ReceiptPaperWidth] ширина ленты не прочитана, чек выйдет на 58 мм: $e',
      );
      return ReceiptPaperWidth.mm58;
    }
  }
}
