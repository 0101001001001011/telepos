import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/receipt/receipt_template_sample.dart';

class ReceiptTemplateEditorArgs {
  const ReceiptTemplateEditorArgs({this.templateId});
  final int? templateId;
}

class ReceiptTemplateEditorScreen extends StatefulWidget {
  const ReceiptTemplateEditorScreen({required this.args, super.key});

  final ReceiptTemplateEditorArgs args;

  @override
  State<ReceiptTemplateEditorScreen> createState() =>
      _ReceiptTemplateEditorScreenState();
}

class _ReceiptTemplateEditorScreenState
    extends State<ReceiptTemplateEditorScreen> {
  final _nameController = TextEditingController();
  final _headerController = TextEditingController();
  final _footerController = TextEditingController();
  final _extraFooterController = TextEditingController();

  ReceiptOptions _options = const ReceiptOptions();
  bool _isDefault = false;
  bool _isLoading = true;
  bool _isPrinting = false;

  String _storeName = '';
  String _posName = 'POS';
  String? _binIin;
  String? _address;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headerController.dispose();
    _footerController.dispose();
    _extraFooterController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = GetIt.I<AppDatabase>();
    try {
      final pos = await db.thisPosDao.get();
      _storeName = pos?.companyName ?? '';
      _posName = pos?.cashBoxName ?? 'POS';
      _binIin = pos?.iinbin;
    } catch (_) {}

    if (widget.args.templateId != null) {
      final t = await db.receiptTemplateDao.getById(widget.args.templateId!);
      if (t != null) {
        _nameController.text = t.name;
        _isDefault = t.isDefault;
        _options = ReceiptOptions.decode(t.optionsJson);
      }
    } else {
      _nameController.text = '';
      _options = const ReceiptOptions();
    }
    _headerController.text = _options.headerText ?? '';
    _footerController.text = _options.footerText;
    _extraFooterController.text = _options.extraFooterLines.join('\n');

    if (mounted) setState(() => _isLoading = false);
  }

  ReceiptOptions get _currentOptions {
    final extra = _extraFooterController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final header = _headerController.text.trim();
    return _options.copyWith(
      headerText: header.isEmpty ? null : header,
      footerText: _footerController.text,
      extraFooterLines: extra,
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.receiptTemplateNameRequired),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    final db = GetIt.I<AppDatabase>();
    final entry = ReceiptTemplatesCompanion(
      name: Value(name),
      optionsJson: Value(_currentOptions.encode()),
      isDefault: Value(_isDefault),
    );
    try {
      if (widget.args.templateId != null) {
        await db.receiptTemplateDao.updateTemplate(
          widget.args.templateId!,
          entry,
        );
      } else {
        await db.receiptTemplateDao.insertTemplate(entry);
      }
      if (GetIt.I.isRegistered<ReceiptPrintService>()) {
        GetIt.I<ReceiptPrintService>().invalidateReceiptOptionsCache();
      }
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _testPrint() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isPrinting = true);
    var ok = false;
    try {
      if (GetIt.I.isRegistered<ReceiptPrintService>()) {
        final svc = GetIt.I<ReceiptPrintService>();
        final sample = sampleSaleReceiptData(
          storeName: _storeName,
          posName: _posName,
          binIin: _binIin,
          address: _address,
        );
        // Пробная печать — отдельный метод: у образца фиксированный
        // `receiptNo`, и через `printSaleReceipt` он столкнулся бы по
        // идентификатору с настоящим чеком того же номера — один из двух не
        // напечатался бы. См. `ReceiptPrintService.printSampleReceipt`.
        ok = !(await svc.printSampleReceipt(sample)).isRejected;
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _isPrinting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.receiptTemplateTestPrintOk
              : l10n.receiptTemplateTestPrintFail,
        ),
        backgroundColor: ok ? AppColors.success : AppColors.warning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.args.templateId == null
              ? l10n.receiptTemplateNew
              : l10n.receiptTemplateEdit,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(TeleposIcons.save, color: Colors.white),
            label: Text(
              l10n.globalSave,
              style: const TextStyle(color: Colors.white),
            ),
            onPressed: _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final form = _buildForm(l10n);
                final preview = _buildPreview(l10n);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: form),
                      SizedBox(width: 380, child: preview),
                    ],
                  );
                }
                return ListView(children: [form, preview]);
              },
            ),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.receiptTemplateName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(l10n.receiptTemplatePaperWidth),
        SegmentedButton<ReceiptPaperWidth>(
          segments: const [
            ButtonSegment(value: ReceiptPaperWidth.mm58, label: Text('58 мм')),
            ButtonSegment(value: ReceiptPaperWidth.mm80, label: Text('80 мм')),
          ],
          selected: {_options.paperWidth},
          onSelectionChanged: (s) =>
              setState(() => _options = _options.copyWith(paperWidth: s.first)),
        ),
        const SizedBox(height: 16),
        _sectionTitle(l10n.receiptTemplateContent),
        _switch(
          l10n.receiptTemplateShowBin,
          _options.showBin,
          (v) => _options = _options.copyWith(showBin: v),
        ),
        _switch(
          l10n.receiptTemplateShowAddress,
          _options.showAddress,
          (v) => _options = _options.copyWith(showAddress: v),
        ),
        _switch(
          l10n.receiptTemplateShowCashier,
          _options.showCashier,
          (v) => _options = _options.copyWith(showCashier: v),
        ),
        _switch(
          l10n.receiptTemplateShowVat,
          _options.showVat,
          (v) => _options = _options.copyWith(showVat: v),
        ),
        _switch(
          l10n.receiptTemplateShowQr,
          _options.showQr,
          (v) => _options = _options.copyWith(showQr: v),
        ),
        _switch(
          l10n.receiptTemplateShowItemNumbers,
          _options.showItemNumbers,
          (v) => _options = _options.copyWith(showItemNumbers: v),
        ),
        const SizedBox(height: 16),
        _sectionTitle(l10n.receiptTemplateHeaderFooter),
        TextField(
          controller: _headerController,
          decoration: InputDecoration(
            labelText: l10n.receiptTemplateHeaderText,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _footerController,
          decoration: InputDecoration(
            labelText: l10n.receiptTemplateFooterText,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _extraFooterController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.receiptTemplateExtraFooter,
            helperText: l10n.receiptTemplateExtraFooterHint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPreview(AppLocalizations l10n) {
    String previewText = '';
    if (GetIt.I.isRegistered<ReceiptPrintService>()) {
      final svc = GetIt.I<ReceiptPrintService>();
      final sample = sampleSaleReceiptData(
        storeName: _storeName,
        posName: _posName,
        binIin: _binIin,
        address: _address,
      );
      previewText = svc.renderSalePreviewText(sample, _currentOptions);
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(l10n.receiptTemplatePreview),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              previewText,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.3,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isPrinting ? null : _testPrint,
            icon: _isPrinting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print),
            label: Text(l10n.receiptTemplateTestPrint),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _switch(String label, bool value, void Function(bool) apply) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: value,
      onChanged: (v) => setState(() => apply(v)),
    );
  }
}
