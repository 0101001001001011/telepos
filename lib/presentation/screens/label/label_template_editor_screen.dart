import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/hardware/label_printer/label_printer_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/label/label_preview.dart';
import 'package:telepos/presentation/screens/label/label_template_codec.dart';

class LabelTemplateEditorArgs {
  const LabelTemplateEditorArgs({this.templateId});
  final int? templateId;
}

class LabelTemplateEditorScreen extends StatefulWidget {
  const LabelTemplateEditorScreen({required this.args, super.key});

  final LabelTemplateEditorArgs args;

  @override
  State<LabelTemplateEditorScreen> createState() =>
      _LabelTemplateEditorScreenState();
}

class _LabelTemplateEditorScreenState extends State<LabelTemplateEditorScreen> {
  final _nameController = TextEditingController();
  final _widthController = TextEditingController(text: '58');
  final _heightController = TextEditingController(text: '40');
  List<LabelField> _fields = [];
  bool _isDefault = false;
  bool _isLoading = true;

  int get _widthMm => int.tryParse(_widthController.text.trim()) ?? 58;
  int get _heightMm => int.tryParse(_heightController.text.trim()) ?? 40;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.args.templateId;
    if (id == null) {
      setState(() {
        _fields = [
          const LabelField(
            kind: LabelFieldKind.name,
            x: 20,
            y: 20,
            fontSize: 28,
            bold: true,
          ),
          const LabelField(
            kind: LabelFieldKind.price,
            x: 20,
            y: 70,
            fontSize: 48,
            bold: true,
          ),
          const LabelField(kind: LabelFieldKind.barcode, x: 20, y: 130),
        ];
        _isLoading = false;
      });
      return;
    }
    try {
      final t = await GetIt.I<AppDatabase>().labelTemplateDao.getById(id);
      if (!mounted) return;
      setState(() {
        if (t != null) {
          _nameController.text = t.name;
          _widthController.text = t.widthMm.toString();
          _heightController.text = t.heightMm.toString();
          _fields = LabelTemplateCodec.decode(t.fieldsJson);
          _isDefault = t.isDefault;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.labelTemplateNameRequired),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final dao = GetIt.I<AppDatabase>().labelTemplateDao;
    final companion = LabelTemplatesCompanion(
      name: Value(name),
      widthMm: Value(_widthMm),
      heightMm: Value(_heightMm),
      fieldsJson: Value(LabelTemplateCodec.encode(_fields)),
      isDefault: Value(_isDefault),
    );

    try {
      if (widget.args.templateId == null) {
        await dao.insertTemplate(companion);
      } else {
        await dao.updateTemplate(widget.args.templateId!, companion);
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

  void _addField() {
    setState(() {
      _fields = [
        ..._fields,
        const LabelField(kind: LabelFieldKind.text, x: 20, y: 20, fontSize: 24),
      ];
    });
  }

  void _removeField(int index) {
    setState(() => _fields = [..._fields]..removeAt(index));
  }

  void _updateField(int index, LabelField updated) {
    setState(() {
      final copy = [..._fields];
      copy[index] = updated;
      _fields = copy;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.of(context).size.width >= 900;

    final form = _buildForm(l10n);
    final preview = _buildPreviewPanel(l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.args.templateId == null
              ? l10n.labelTemplateNew
              : l10n.labelTemplateEdit,
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
          : isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: form),
                SizedBox(
                  width: 380,
                  child: Container(
                    color: context.semantic.canvas,
                    child: preview,
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    color: context.semantic.canvas,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: preview,
                  ),
                  form,
                ],
              ),
            ),
    );
  }

  Widget _buildPreviewPanel(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.labelTemplatePreview,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          LabelPreview(
            fields: _fields,
            widthMm: _widthMm,
            heightMm: _heightMm,
            data: sampleLabelData(),
          ),
        ],
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
            labelText: l10n.labelTemplateName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _widthController,
                decoration: InputDecoration(
                  labelText: l10n.labelPrinterWidthMm,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _heightController,
                decoration: InputDecoration(
                  labelText: l10n.labelPrinterHeightMm,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              l10n.labelTemplateFields,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addField,
              icon: const Icon(TeleposIcons.add, size: 18),
              label: Text(l10n.labelTemplateAddField),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_fields.length, (i) => _buildFieldEditor(l10n, i)),
        if (_fields.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.labelTemplateNoFields,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFieldEditor(AppLocalizations l10n, int index) {
    final f = _fields[index];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<LabelFieldKind>(
                    value: f.kind,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: l10n.labelFieldKind,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    items: LabelFieldKind.values
                        .map(
                          (k) => DropdownMenuItem(
                            value: k,
                            child: Text(_kindLabel(l10n, k)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _updateField(index, f.copyWith(kind: v));
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    TeleposIcons.delete,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  onPressed: () => _removeField(index),
                  tooltip: l10n.globalDelete,
                ),
              ],
            ),
            if (f.kind == LabelFieldKind.text) ...[
              const SizedBox(height: 8),
              TextFormField(
                initialValue: f.text ?? '',
                decoration: InputDecoration(
                  labelText: l10n.labelFieldText,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => _updateField(index, f.copyWith(text: v)),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _nudgeRow(
                    label: 'X',
                    value: f.x,
                    onChanged: (v) =>
                        _updateField(index, f.copyWith(x: v.clamp(0, 2000))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _nudgeRow(
                    label: 'Y',
                    value: f.y,
                    onChanged: (v) =>
                        _updateField(index, f.copyWith(y: v.clamp(0, 2000))),
                  ),
                ),
              ],
            ),
            if (f.kind != LabelFieldKind.barcode) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _nudgeRow(
                      label: l10n.labelFieldFontSize,
                      value: f.fontSize,
                      step: 2,
                      onChanged: (v) => _updateField(
                        index,
                        f.copyWith(fontSize: v.clamp(8, 96)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: f.bold,
                          onChanged: (v) =>
                              _updateField(index, f.copyWith(bold: v ?? false)),
                        ),
                        Text(l10n.labelFieldBold),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nudgeRow({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int step = 5,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: () => onChanged(value - step),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: () => onChanged(value + step),
        ),
      ],
    );
  }

  String _kindLabel(AppLocalizations l10n, LabelFieldKind kind) {
    return switch (kind) {
      LabelFieldKind.name => l10n.labelFieldKindName,
      LabelFieldKind.price => l10n.labelFieldKindPrice,
      LabelFieldKind.barcode => l10n.labelFieldKindBarcode,
      LabelFieldKind.sku => l10n.labelFieldKindSku,
      LabelFieldKind.date => l10n.labelFieldKindDate,
      LabelFieldKind.text => l10n.labelFieldKindText,
    };
  }
}
