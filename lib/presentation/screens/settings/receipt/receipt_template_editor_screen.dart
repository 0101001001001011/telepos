import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/receipt/receipt_template_setup.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/sale/sale_refusal_keys.dart';
import 'package:telepos/app/theme/app_typography.dart';

class ReceiptTemplateEditorArgs {
  const ReceiptTemplateEditorArgs({this.templateId});
  final int? templateId;
}

/// Шаблон чека кассы: шапка и подвал свободным текстом, их оформление и
/// предпросмотр. Один экран на кассу и на браузерный терминал.
///
/// ## Где хранится и почему на кассе
///
/// Шаблон лежит в `ReceiptTemplates` базы **кассы** — той, что печатает. Чек
/// с браузерного терминала печатает касса (`LocalPaymentService` с её
/// `ReceiptPrintService`), значит и шаблон у него тот же. Разные кассы одного
/// магазина могут стоять с разными принтерами и разным текстом — «акция
/// только на этой точке» — и настройка магазина это бы запретила.
///
/// ## Базы здесь больше нет
///
/// До 2026-09-18 экран звал `GetIt.I<AppDatabase>()` из `_load`, `_save` и
/// `_buildPreview`, и в браузер не собирался вовсе. Теперь между ним и базой
/// стоит доменный порт [ReceiptTemplateSetupRepository] с двумя реализациями
/// — кассовой и проводной; какая лежит в контейнере, решает точка входа
/// сборки.
///
/// ## Предпросмотр — это бумага, и он стал асинхронным именно ради этого
///
/// Текст в рамке — **те же байты ESC/POS**, что уйдут в принтер, разобранные
/// в текст. Собирает их касса, одной-единственной на всё дерево функцией
/// (`ReceiptPrintService.renderSalePreviewText`), и отдаёт сюда готовой
/// строкой. Здесь нет ни ширины ленты в расчётах, ни выравнивания, ни
/// кодовой страницы — показывается то, что сказала касса.
///
/// Цена названа вслух: до этой правки предпросмотр строился прямо в `build`,
/// синхронным вызовом. По проводу синхронного вызова не бывает, и экран,
/// оставшийся синхронным, был бы экраном **только для кассы** — то есть
/// пробел остался бы ровно там, где его закрывали. Поэтому текст
/// пересобирается [_previewDebounce] после последней правки и живёт в
/// [_preview].
///
/// Задержка — не украшение: предпросмотр спрашивается у кассы по проводу, и
/// вопрос на каждую нажатую клавишу означал бы десяток кадров на слово. При
/// этом «показать чуть позже» здесь безвредно, а «показать не то» — нет:
/// пока ответ в пути, в рамке стоит **прежний** текст, а не пустота, — иначе
/// поле мигало бы белым на каждой букве.
///
/// Разбор, почему текст считает касса, а не вкладка из присланных байтов, — в
/// докстринге `lib/domain/receipt/receipt_template_setup.dart`.
class ReceiptTemplateEditorScreen extends StatefulWidget {
  const ReceiptTemplateEditorScreen({
    required this.args,
    super.key,
    this.homeRoute,
  });

  final ReceiptTemplateEditorArgs args;

  /// Куда уйти по стрелке «назад», если возвращаться некуда (вкладка,
  /// открытая прямо по адресу). Тот же приём и довод, что у
  /// `QrPaymentSetupScreen`.
  final String? homeRoute;

  @override
  State<ReceiptTemplateEditorScreen> createState() =>
      _ReceiptTemplateEditorScreenState();
}

class _ReceiptTemplateEditorScreenState
    extends State<ReceiptTemplateEditorScreen> {
  /// Сколько молчания после последней правки перед вопросом к кассе.
  ///
  /// Число выбрано как «быстрее, чем человек успевает заметить, и реже, чем
  /// он печатает»: при 200 знаках в минуту между буквами ~300 мс, и слово
  /// уезжает одним кадром, а не восемью.
  static const _previewDebounce = Duration(milliseconds: 350);

  final _nameController = TextEditingController();
  final _headerController = TextEditingController();
  final _footerController = TextEditingController();

  ReceiptOptions _options = const ReceiptOptions();

  /// Ширина ленты привязанного принтера — её называет касса, экран только
  /// показывает (докстринг `ReceiptPaperWidth`: ширина — свойство принтера,
  /// а не шаблона).
  int _paperWidthMm = 58;
  bool _isLoading = true;
  bool _isPrinting = false;

  /// Текст предпросмотра, каким его в последний раз собрала касса.
  String _preview = '';
  Timer? _previewTimer;

  /// Номер последнего заказанного предпросмотра.
  ///
  /// Ответы приходят по проводу и могут разойтись во времени: заказ №2 может
  /// вернуться раньше заказа №3. Без этого счётчика в рамку лёг бы ответ,
  /// пришедший последним, а не заказанный последним, — то есть предпросмотр
  /// **предыдущей** редакции шапки. Сравнивать тексты бесполезно: они
  /// законно бывают одинаковыми.
  int _previewTicket = 0;

  ReceiptTemplateSetupRepository? get _repo =>
      GetIt.I.isRegistered<ReceiptTemplateSetupRepository>()
      ? GetIt.I<ReceiptTemplateSetupRepository>()
      : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _nameController.dispose();
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = _repo;
    if (repo == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final catalog = await repo.read();
      _paperWidthMm = catalog.paperWidthMm;
      final id = widget.args.templateId;
      if (id != null) {
        for (final row in catalog.templates) {
          if (row.id != id) continue;
          _nameController.text = row.name;
          _options = ReceiptOptions.decode(row.optionsJson);
          break;
        }
      } else {
        _nameController.text = '';
        _options = const ReceiptOptions();
      }
    } catch (e) {
      if (mounted) _snack(_reason(e), error: true);
    }
    _headerController.text = _options.header.text;
    // Незаданный подвал показывается тем, что напечатается, — иначе
    // владелец видит пустое поле и не понимает, откуда на чеке слова.
    _footerController.text =
        _options.footer?.text ??
        AppLocalizations.of(context)!.receiptLabelThankYou;
    if (!mounted) return;
    setState(() => _isLoading = false);
    // Первый предпросмотр — **сразу**, без задержки: экран открывают, чтобы
    // увидеть чек, и триста миллисекунд пустой рамки на входе выглядят
    // поломкой, а не бережливостью.
    unawaited(_refreshPreview());
  }

  ReceiptOptions get _currentOptions => _options.copyWith(
    header: _options.header.copyWith(text: _headerController.text),
    footer: (_options.footer ?? const ReceiptTextBlock()).copyWith(
      text: _footerController.text,
    ),
  );

  /// Правка формы: перерисовать сейчас, спросить чек потом.
  void _touched(void Function() apply) {
    setState(apply);
    _previewTimer?.cancel();
    _previewTimer = Timer(_previewDebounce, () => unawaited(_refreshPreview()));
  }

  /// Спросить у кассы, как черновик выглядит на бумаге.
  ///
  /// Отказ сюда не кричит снекбаром: предпросмотр пересобирается на каждую
  /// правку, и оборванный провод дал бы кассиру красную полосу на каждой
  /// букве. В рамке остаётся прежний текст — а о беде он узнает от
  /// сохранения, которое отказ показывает.
  Future<void> _refreshPreview() async {
    final repo = _repo;
    if (repo == null) return;
    final ticket = ++_previewTicket;
    final String text;
    try {
      text = await repo.preview(_currentOptions.encode());
    } catch (_) {
      return;
    }
    if (!mounted || ticket != _previewTicket) return;
    setState(() => _preview = text);
  }

  /// Отказ кассы — фразой своего языка по коду (разбор — в
  /// `receipt_templates_screen.dart`, тот же приём).
  String _reason(Object error) {
    if (error is WireRefusal) {
      return ErrorLocalizer.localize(context, saleRefusalErrorKeyOf(error));
    }
    return safeErrorText(error);
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? Theme.of(context).colorScheme.error
            : AppColors.success,
      ),
    );
  }

  void _goBack([bool? changed]) {
    if (context.canPop()) {
      context.pop(changed);
      return;
    }
    final home = widget.homeRoute;
    if (home != null) context.go(home);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    // Проверка **и здесь, и на кассе**: экран избавляет от круга по проводу,
    // касса держит запрет для кадра, собранного мимо экрана
    // (`receipt_template_nameless`).
    if (name.isEmpty) {
      _snack(l10n.receiptTemplateNameRequired, error: true);
      return;
    }
    final repo = _repo;
    if (repo == null) return;
    try {
      await repo.save(
        id: widget.args.templateId,
        name: name,
        optionsJson: _currentOptions.encode(),
      );
    } catch (e) {
      if (mounted) _snack(_reason(e), error: true);
      return;
    }
    if (mounted) _goBack(true);
  }

  Future<void> _testPrint() async {
    final l10n = AppLocalizations.of(context)!;
    final repo = _repo;
    if (repo == null) return;
    setState(() => _isPrinting = true);
    var ok = false;
    try {
      ok = await repo.testPrint();
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
          tooltip: l10n.globalBack,
          onPressed: () => _goBack(),
        ),
        actions: [
          if (_repo != null)
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
      body: _repo == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.errorReceiptTemplatesUnavailable,
                  key: const Key('receipt_template_unavailable'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildForm(l10n)),
                      SizedBox(
                        width: 420,
                        child: SingleChildScrollView(
                          child: _buildPreview(l10n),
                        ),
                      ),
                    ],
                  );
                }
                return ListView(
                  children: [
                    _buildForm(l10n, scrollable: false),
                    _buildPreview(l10n),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildForm(AppLocalizations l10n, {bool scrollable = true}) {
    final children = <Widget>[
      TextField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: l10n.receiptTemplateName,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      _sectionTitle(l10n.receiptTemplatePaperWidth),
      // Ширина ленты — свойство принтера, не шаблона: выбирается на экране
      // «Настройки принтера», здесь только показывается.
      Text(
        l10n.globalMillimetres('$_paperWidthMm'),
        key: const Key('receipt_template_paper_width'),
      ),
      Text(
        l10n.receiptTemplatePaperWidthHint,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      _sectionTitle(l10n.receiptTemplateHeaderFooter),
      _blockEditor(
        l10n,
        fieldKey: const Key('receipt_template_header'),
        label: l10n.receiptTemplateHeaderText,
        hint: l10n.receiptTemplateHeaderHint,
        controller: _headerController,
        block: _options.header,
        onStyle: (b) => _options = _options.copyWith(header: b),
      ),
      const SizedBox(height: 12),
      Text(
        l10n.receiptTemplateMandatoryNote,
        key: const Key('receipt_template_mandatory_note'),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 12),
      _blockEditor(
        l10n,
        fieldKey: const Key('receipt_template_footer'),
        label: l10n.receiptTemplateFooterText,
        hint: l10n.receiptTemplateFooterHint,
        controller: _footerController,
        block: _options.footer ?? const ReceiptTextBlock(),
        onStyle: (b) => _options = _options.copyWith(footer: b),
      ),
      const SizedBox(height: 16),
      _sectionTitle(l10n.receiptTemplateContent),
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
        l10n.receiptTemplateShowItemNumbers,
        _options.showItemNumbers,
        (v) => _options = _options.copyWith(showItemNumbers: v),
      ),
      const SizedBox(height: 24),
    ];
    if (!scrollable) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }

  /// Поле блока и его оформление. Текст берётся из [controller] при каждой
  /// перерисовке ([_currentOptions]), оформление — из [block].
  Widget _blockEditor(
    AppLocalizations l10n, {
    required Key fieldKey,
    required String label,
    required String hint,
    required TextEditingController controller,
    required ReceiptTextBlock block,
    required void Function(ReceiptTextBlock) onStyle,
  }) {
    final keyName = (fieldKey as ValueKey<String>).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: fieldKey,
          controller: controller,
          minLines: 2,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: label,
            helperText: hint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _touched(() {}),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<ReceiptTextAlign>(
              key: Key('${keyName}_align'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ReceiptTextAlign.left,
                  icon: const Icon(Icons.format_align_left),
                  tooltip: l10n.receiptTemplateAlignLeft,
                ),
                ButtonSegment(
                  value: ReceiptTextAlign.center,
                  icon: const Icon(Icons.format_align_center),
                  tooltip: l10n.receiptTemplateAlignCenter,
                ),
                ButtonSegment(
                  value: ReceiptTextAlign.right,
                  icon: const Icon(Icons.format_align_right),
                  tooltip: l10n.receiptTemplateAlignRight,
                ),
              ],
              selected: {block.align},
              onSelectionChanged: (s) =>
                  _touched(() => onStyle(block.copyWith(align: s.first))),
            ),
            FilterChip(
              key: Key('${keyName}_bold'),
              label: Text(l10n.receiptTemplateBold),
              selected: block.bold,
              onSelected: (v) =>
                  _touched(() => onStyle(block.copyWith(bold: v))),
            ),
            FilterChip(
              key: Key('${keyName}_double'),
              label: Text(l10n.receiptTemplateDoubleSize),
              selected: block.doubleSize,
              onSelected: (v) =>
                  _touched(() => onStyle(block.copyWith(doubleSize: v))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreview(AppLocalizations l10n) {
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                _preview,
                key: const Key('receipt_template_preview'),
                style: const TextStyle(
                  fontFamily: AppTypography.familyMono,
                  fontSize: 11,
                  height: 1.3,
                  color: Colors.black,
                ),
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
      onChanged: (v) => _touched(() => apply(v)),
    );
  }
}
