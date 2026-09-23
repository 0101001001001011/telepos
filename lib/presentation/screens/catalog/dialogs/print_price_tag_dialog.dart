import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/services/currency_service.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/hardware/label_printer/label_printer_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/session_lost_handler.dart';
import 'package:telepos/presentation/screens/label/label_preview.dart';
import 'package:telepos/presentation/screens/label/label_template_codec.dart';
import 'package:telepos/presentation/common/utils/till_money.dart';

class PriceTagProduct {
  const PriceTagProduct({
    required this.name,
    required this.barcode,
    required this.price,
    this.sku,
  });

  final String name;
  final String barcode;
  final Decimal price;
  final String? sku;
}

class PrintPriceTagDialog extends StatefulWidget {
  const PrintPriceTagDialog({required this.products, super.key});

  final List<PriceTagProduct> products;

  static Future<void> show(
    BuildContext context, {
    required List<PriceTagProduct> products,
  }) {
    return showDialog(
      context: context,
      builder: (_) => PrintPriceTagDialog(products: products),
    );
  }

  @override
  State<PrintPriceTagDialog> createState() => _PrintPriceTagDialogState();
}

class _PrintPriceTagDialogState extends State<PrintPriceTagDialog> {
  List<LabelTemplate> _templates = const [];
  LabelTemplate? _selected;
  int _copies = 1;
  bool _isLoading = true;
  bool _isPrinting = false;
  String? _result;
  bool _resultOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dao = GetIt.I<AppDatabase>().labelTemplateDao;
      await dao.seedDefaults();
      final list = await dao.getAll();
      if (!mounted) return;
      setState(() {
        _templates = list;
        _selected = list.isNotEmpty ? list.first : null;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _print() async {
    final l10n = AppLocalizations.of(context)!;
    final template = _selected;
    if (template == null) return;

    setState(() {
      _isPrinting = true;
      _result = null;
    });

    Talker? logger;
    try {
      logger = GetIt.I<Talker>();
    } catch (_) {}

    // Reads the label-printer *binding* through the domain contract
    // (`DeviceBindingRepository`) rather than the retired
    // `ThisPosEntries.labelPrinterConnectionType`/`labelPrinterAddress`/
    // `labelPrinterPort`/`labelPrinterLanguage` columns — those columns'
    // only writer, `ThisPosDao.updateLabelPrinter`, had zero call sites left
    // (final review finding C4): this dialog was a reader pointing at
    // something dead. `DeviceBindingRepository`/`DeviceProfileCatalog` are
    // both `lib/domain`, so this presentation file still reaches them
    // through a contract, never through `lib/data`.
    DeviceBinding? labelBinding;
    try {
      labelBinding = await _findLabelPrinterBinding();
    } on SessionLost catch (error) {
      // Found while fixing task 1 of the phase-2 fix wave (which caught
      // `SessionLost` in `hardware_settings_screen.dart`), applied here for
      // symmetry, not because this path is live — see `_findLabelPrinterBinding`
      // below for why nothing can throw `SessionLost` through this dialog
      // today.
      handleSessionLost(context, error);
      return;
    }
    if (labelBinding == null) {
      setState(() {
        _isPrinting = false;
        _resultOk = false;
        _result = l10n.labelPrinterNotConfigured;
      });
      return;
    }

    final host = labelBinding.parameters['ipAddress']?.trim();
    final port = int.tryParse(labelBinding.parameters['port'] ?? '');
    final widthMm = int.tryParse(labelBinding.options['paperWidthMm'] ?? '');
    final heightMm = int.tryParse(labelBinding.options['labelHeightMm'] ?? '');

    if (host == null || host.isEmpty) {
      setState(() {
        _isPrinting = false;
        _resultOk = false;
        _result = l10n.labelPrinterNotConfigured;
      });
      return;
    }

    final service = LabelPrinterService(
      logger: logger,
      host: host,
      port: port ?? 9100,
      language: _languageFor(labelBinding),
      labelWidthMm: widthMm ?? template.widthMm,
      labelHeightMm: heightMm ?? template.heightMm,
    );

    final fields = LabelTemplateCodec.decode(template.fieldsJson);
    String currency = tillCurrencySymbol();
    try {
      currency = GetIt.I<CurrencyService>().symbol;
    } catch (_) {}

    int printed = 0;
    String? lastError;
    try {
      for (final p in widget.products) {
        final res = await service.printTemplate(
          fields: fields,
          widthMm: template.widthMm,
          heightMm: template.heightMm,
          copies: _copies,
          data: LabelData(
            name: p.name,
            barcode: p.barcode,
            price: p.price,
            currencySymbol: currency,
            sku: p.sku,
            date: _today(),
          ),
        );
        if (res.success) {
          printed++;
        } else {
          lastError = res.errorMessage;
        }
      }
    } catch (e) {
      lastError = '$e';
    } finally {
      await service.disconnect();
    }

    if (!mounted) return;
    setState(() {
      _isPrinting = false;
      _resultOk = printed > 0 && lastError == null;
      _result = lastError != null
          ? (lastError)
          : l10n.labelPrintedCount(printed);
    });
  }

  /// This terminal's enabled `labelPrinter` binding, or `null` if none is
  /// configured (or more than one is — [singleEnabledBindingOfClass] refuses
  /// to guess, same rule as `hardware_module.dart`).
  Future<DeviceBinding?> _findLabelPrinterBinding() async {
    try {
      final terminal = await GetIt.I<TerminalRepository>().self();
      final bindings = await GetIt.I<DeviceBindingRepository>().forTerminal(
        terminal.id,
      );
      return singleEnabledBindingOfClass(bindings, DeviceClass.labelPrinter);
    } on SessionLost {
      // Left uncaught on purpose: the caller ([_print]) tells it apart from
      // "nothing configured" and takes the operator to login instead of
      // showing `labelPrinterNotConfigured` for an ended session.
      //
      // Not a live gap today (corrected 2026-08-21, second round of the fix
      // wave — the first round's report described this rethrow as closing an
      // active defect, which overstated it). `SessionLost` is thrown by
      // exactly one implementation in the whole repository —
      // `WtDispatcher._errorFor` (`lib/web/wt_dispatcher.dart`) — and only
      // the browser binding ever wires a `WtDeviceBindingRepository`/
      // `WtTerminalRepository` behind the `GetIt` lookups above
      // (`lib/web/main_web.dart`). The browser binding's route table is
      // `createSetupRouter()` (`lib/app/router/setup_router.dart`), and it
      // does not import `catalog_screen.dart` — the only place this dialog
      // is opened from — at all, let alone route to it. On desktop,
      // `GetIt.I<DeviceBindingRepository>()`/`GetIt.I<TerminalRepository>()`
      // resolve to local, in-process bindings that never throw `SessionLost`
      // in the first place. So this rethrow cannot fire today on either
      // binding — it is here for when the catalog moves onto the wire, so
      // that migration does not have to remember to add it from scratch.
      rethrow;
    } catch (_) {
      return null;
    }
  }

  LabelLanguage _languageFor(DeviceBinding binding) {
    final profile = GetIt.I<DeviceProfileCatalog>().byId(binding.profileId);
    return switch (profile?.protocol) {
      DeviceProtocol.epl => LabelLanguage.epl,
      _ => LabelLanguage.zpl,
    };
  }

  String _today() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.day)}.${two(now.month)}.${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final single = widget.products.length == 1;

    return AlertDialog(
      title: Text(
        single
            ? l10n.labelPrintTitle
            : l10n.labelPrintBulkTitle(widget.products.length),
      ),
      content: SizedBox(
        width: 360,
        child: _isLoading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_templates.isEmpty)
                      Text(l10n.labelTemplatesEmpty)
                    else ...[
                      Text(
                        l10n.labelPrintChooseTemplate,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<LabelTemplate>(
                        value: _selected,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: _templates
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  '${t.name}  (${t.widthMm}×${t.heightMm})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selected = v),
                      ),
                      const SizedBox(height: 16),
                      if (single && _selected != null) ...[
                        LabelPreview(
                          fields: LabelTemplateCodec.decode(
                            _selected!.fieldsJson,
                          ),
                          widthMm: _selected!.widthMm,
                          heightMm: _selected!.heightMm,
                          data: LabelData(
                            name: widget.products.first.name,
                            barcode: widget.products.first.barcode,
                            price: widget.products.first.price,
                            sku: widget.products.first.sku,
                            date: _today(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          Text(l10n.labelPrintCopies),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _copies > 1
                                ? () => setState(() => _copies--)
                                : null,
                          ),
                          Text(
                            '$_copies',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _copies < 99
                                ? () => setState(() => _copies++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                    if (_result != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _resultOk
                              ? AppColors.success.withValues(alpha: 0.1)
                              : Theme.of(
                                  context,
                                ).colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _resultOk
                                  ? TeleposIcons.checkCircle
                                  : TeleposIcons.error,
                              size: 18,
                              color: _resultOk
                                  ? AppColors.success
                                  : Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_result!)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalClose),
        ),
        FilledButton.icon(
          onPressed: (_isPrinting || _selected == null) ? null : _print,
          icon: _isPrinting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.print),
          label: Text(l10n.labelPrintAction),
        ),
      ],
    );
  }
}
