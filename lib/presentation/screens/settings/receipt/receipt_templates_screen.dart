import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/receipt/receipt_template_setup.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/sale/sale_refusal_keys.dart';
import 'package:telepos/presentation/screens/settings/receipt/receipt_template_editor_screen.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Список шаблонов чека — один экран на кассу и на браузерный терминал.
///
/// # Базы здесь больше нет
///
/// До 2026-09-18 этот экран звал `GetIt.I<AppDatabase>().receiptTemplateDao`
/// прямо из `_load`, `_select` и `_delete`. В браузер он из-за этого не
/// собирался вовсе: `lib/data/` тянет `dart:ffi` через `package:sqlite3`, и
/// сторож `browser_routes_test` запрещает этот каталог в замыкании
/// браузерной сборки по построению.
///
/// Теперь между экраном и базой стоит доменный порт
/// ([ReceiptTemplateSetupRepository]), у которого две реализации — кассовая
/// (`LocalReceiptTemplateSetup`) и проводная (`WtReceiptTemplateSetup`).
/// Какая из них лежит в контейнере, решает точка входа сборки; экран
/// различить их не может ничем.
///
/// [homeRoute] — куда уходить стрелке «назад», когда уходить некуда: вкладка
/// браузера открывается прямо по адресу, стека переходов у неё нет, и
/// `context.pop()` в ней не делает ничего. Тот же приём и тот же довод, что у
/// `QrPaymentSetupScreen`; дом у двух таблиц разный, поэтому его называет
/// **таблица маршрутов**, а не экран.
class ReceiptTemplatesScreen extends StatefulWidget {
  const ReceiptTemplatesScreen({super.key, this.homeRoute});

  /// `null` — только `pop`, и это верно для десктопа: туда приходят
  /// `context.push` из хаба настроек, то есть стек есть всегда.
  final String? homeRoute;

  @override
  State<ReceiptTemplatesScreen> createState() => _ReceiptTemplatesScreenState();
}

class _ReceiptTemplatesScreenState extends State<ReceiptTemplatesScreen> {
  List<ReceiptTemplateRow> _templates = const [];
  bool _isLoading = true;

  /// Порт может быть не привязан вовсе — сборка без него честно говорит об
  /// этом словами, а не пустым списком: пустой список означает «шаблонов
  /// нет», и владелец завёл бы второй поверх невидимого первого.
  ReceiptTemplateSetupRepository? get _repo =>
      GetIt.I.isRegistered<ReceiptTemplateSetupRepository>()
      ? GetIt.I<ReceiptTemplateSetupRepository>()
      : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = _repo;
    if (repo == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final catalog = await repo.read();
      if (!mounted) return;
      setState(() {
        _templates = catalog.templates;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack(_reason(e), error: true);
    }
  }

  /// Назад — в стек, а при пустом стеке в дом сборки (докстринг виджета).
  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final home = widget.homeRoute;
    if (home != null) context.go(home);
  }

  /// Отказ кассы — **фразой своего языка по коду**, а не текстом исключения.
  ///
  /// Названный отказ ([WireRefusal]) идёт тем же путём, каким его берут все
  /// экраны: `saleRefusalErrorKeyOf` → [ErrorLocalizer]. Всё прочее (обрыв
  /// провода без кода, падение обработчика) — `safeErrorText`: выдумывать
  /// коду имя нельзя, а `'$e'` в браузере показывает `minified:du`, что уже
  /// измерено живой приёмкой 2026-09-13.
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

  /// Переход на правку — **по константе маршрута**, а не склейкой текущего
  /// адреса с `/edit`.
  ///
  /// Прежде здесь стояло `'${GoRouterState.of(context).uri.path}/edit'`, и в
  /// браузерной таблице это дало бы адрес, которого в ней нет, — сторож
  /// `browser_routes_test` не увидел бы такого перехода вовсе (он ищет
  /// `context.go/push` по константе или по литералу пути), а кассир получил
  /// бы «Page Not Found: GoException». Константу сторож видит.
  Future<void> _openEditor(ReceiptTemplateRow? row) async {
    final changed = await context.push<bool>(
      AppRoutes.receiptTemplateEdit,
      extra: ReceiptTemplateEditorArgs(templateId: row?.id),
    );
    if (changed == true) await _load();
  }

  Future<void> _select(ReceiptTemplateRow row) async {
    final repo = _repo;
    if (repo == null) return;
    try {
      await repo.select(row.id);
    } catch (e) {
      if (mounted) _snack(_reason(e), error: true);
      return;
    }
    await _load();
  }

  Future<void> _delete(ReceiptTemplateRow row) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.receiptTemplateDeleteTitle),
        content: Text(l10n.receiptTemplateDeleteConfirm(row.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.globalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.globalDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = _repo;
    if (repo == null) return;
    try {
      await repo.remove(row.id);
    } catch (e) {
      if (mounted) _snack(_reason(e), error: true);
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.receiptTemplatesTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.globalBack,
          onPressed: _goBack,
        ),
      ),
      floatingActionButton: _repo == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(null),
              icon: const Icon(TeleposIcons.add),
              label: Text(l10n.receiptTemplateNew),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
      body: _repo == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.errorReceiptTemplatesUnavailable,
                  key: const Key('receipt_templates_unavailable'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
          ? Center(child: Text(l10n.receiptTemplatesEmpty))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _templates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final t = _templates[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: ListTile(
                    leading: IconButton(
                      icon: Icon(
                        t.selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: t.selected
                            ? AppColors.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      tooltip: l10n.receiptTemplateMakeActive,
                      onPressed: t.selected ? null : () => _select(t),
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(t.name)),
                        if (t.builtIn) ...[
                          const SizedBox(width: 8),
                          _badge(l10n.receiptTemplateBuiltIn),
                        ],
                        if (t.selected) ...[
                          const SizedBox(width: 8),
                          _badge(
                            l10n.receiptTemplateActive,
                            color: selectedSurfaceOf(context),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _openEditor(t),
                          tooltip: l10n.globalEdit,
                        ),
                        if (!t.builtIn)
                          IconButton(
                            icon: Icon(
                              TeleposIcons.delete,
                              size: 20,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => _delete(t),
                            tooltip: l10n.globalDelete,
                          ),
                      ],
                    ),
                    onTap: () => _openEditor(t),
                  ),
                );
              },
            ),
    );
  }

  Widget _badge(String text, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color ?? context.semantic.canvas,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
