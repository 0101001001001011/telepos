import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/shift/shift_desk.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/sale/sale_refusal_keys.dart';

/// Смена на браузерном терминале: состояние, закрытие, открытие.
///
/// # Почему это **не** тот же экран, что на кассе
///
/// Правило «в браузере то же, что в приложении» здесь соблюдено по существу,
/// а не буквой, и разница названа вслух, а не спрятана.
///
/// Кассовый `ShiftScreen` — три вкладки поверх `ShiftNotifier`, который
/// читает `GetIt.I<AppDatabase>()` напрямую примерно в двадцати местах:
/// список кассовых операций, разбивка продаж по видам оплаты, пересчёт по
/// семи номиналам купюр, X- и Z-отчёты. Всё это — работа **у самой кассы**, с
/// её ящиком и её принтером, и переносить её целиком значило бы переписать
/// контроллер, у которого есть свой набор проб, — работой другого размера и
/// другого риска.
///
/// Перенесено то, чего не хватало для работы: **закрыть смену и открыть
/// новую**, и увидеть числа, по которым это решают. Числа приходят с кассы
/// готовыми; здесь нет ни одной денежной операции, кроме вычитания для
/// показа расхождения.
///
/// # Одно поле, потому что вкладка вправе задать одно число
///
/// Пересчитанные деньги — и больше ничего. Разбор целиком — в докстринге
/// `lib/domain/shift/shift_desk.dart`; коротко: это физический замер,
/// которого нет ни в одном журнале, а всё остальное касса считает сама, и
/// второй бухгалтер разошёлся бы с первым.
///
/// **Пустое поле означает «не считали», а не ноль.** Ноль в ящике — законный
/// и осмысленный результат пересчёта, и подменить им «не считали» значило бы
/// записать недостачу на всю выручку смены. Поэтому поле не заполняется
/// нулём при открытии экрана и не имеет умолчания.
///
/// Пересчёта по номиналам здесь нет намеренно: сумма номиналов — сложение,
/// сделанное вкладкой. Оно безобидно (складывается то, что человек только что
/// набрал, а не журнал кассы), но и не нужно: человек, считающий деньги,
/// складывает их так, как ему удобно, а касса обязана получить итог. На
/// кассе вкладка «Купюры» остаётся.
class TerminalShiftScreen extends StatefulWidget {
  const TerminalShiftScreen({super.key, this.homeRoute});

  /// Куда уйти по стрелке «назад», если возвращаться некуда. Тот же приём и
  /// довод, что у `QrPaymentSetupScreen`: вкладка открывается прямо по
  /// адресу, стека переходов у неё нет, и `pop()` не делает ничего.
  final String? homeRoute;

  @override
  State<TerminalShiftScreen> createState() => _TerminalShiftScreenState();
}

class _TerminalShiftScreenState extends State<TerminalShiftScreen> {
  final _counted = TextEditingController();
  bool _busy = false;

  ShiftDeskRepository? get _desk => GetIt.I.isRegistered<ShiftDeskRepository>()
      ? GetIt.I<ShiftDeskRepository>()
      : null;

  /// Подписка открывается **один раз**, а не в каждом `build`.
  ///
  /// Не гигиена: `watch()` — настоящая подписка на кассу
  /// (`TillOps.shiftState`), и поток, созданный заново на каждую
  /// перерисовку, означал бы новую подписку на каждую букву, набранную в
  /// поле суммы: `onChanged` там вызывает `setState`, чтобы пересчитать
  /// показ расхождения. Касса получала бы десяток подписок на один
  /// открытый экран, и снимал бы их только уход вкладки.
  late final Stream<ShiftDeskView>? _state = _desk?.watch();

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  /// Набранное в поле — или `null`, если не набирали.
  ///
  /// Мусор в поле тоже `null`, а не ноль: «набрал непонятное» ближе к «не
  /// считал», чем к «в ящике пусто». Клавиатура даёт точку и запятую в
  /// зависимости от раскладки, поэтому запятая приводится к точке — иначе
  /// «1000,50» стало бы «не считали» на ровном месте.
  Decimal? get _countedValue {
    final raw = _counted.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return Decimal.tryParse(raw);
  }

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

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final home = widget.homeRoute;
    if (home != null) context.go(home);
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    final desk = _desk;
    if (desk == null) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      // Поле чистится **только после успеха**: отказ оставляет набранное
      // число на месте, иначе кассир пересчитывал бы ящик заново из-за
      // оборванного провода.
      _counted.clear();
      _snack(done);
    } catch (e) {
      if (mounted) _snack(_reason(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final desk = _desk;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shiftDeskTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.globalBack,
          onPressed: _goBack,
        ),
      ),
      body: desk == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.errorShiftDeskUnavailable,
                  key: const Key('terminal_shift_unavailable'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : StreamBuilder<ShiftDeskView>(
              stream: _state,
              builder: (context, snapshot) {
                final view = snapshot.data;
                if (view == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _body(l10n, view);
              },
            ),
    );
  }

  Widget _body(AppLocalizations l10n, ShiftDeskView view) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (view.overAge)
          Card(
            key: const Key('terminal_shift_over_age'),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.shiftDeskOverAgeWarning,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (!view.open) ...[
          Text(l10n.shiftDeskNoShift, key: const Key('terminal_shift_closed')),
          const SizedBox(height: 16),
          TextField(
            key: const Key('terminal_shift_opening_cash'),
            controller: _counted,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.shiftDeskOpeningCashLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('terminal_shift_open'),
            onPressed: _busy
                ? null
                : () => _run(
                    () => _desk!.open(openingCash: _countedValue),
                    l10n.shiftDeskOpenedNow,
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
            child: Text(l10n.shiftOpen),
          ),
        ] else ...[
          _row(l10n.shiftCashierLabel, view.cashierName ?? l10n.shiftUnknown),
          if (view.openedAtSeconds != null)
            _row(
              '',
              l10n.shiftDeskOpenedAt(
                // Множитель 1000 — **только здесь, на показе**: касса возит
                // секунды (докстринг `ShiftDeskView.openedAtSeconds`).
                DateTime.fromMillisecondsSinceEpoch(
                  view.openedAtSeconds! * 1000,
                ).toString(),
              ),
            ),
          _row(l10n.shiftCashInDrawer, view.systemTotal.toString()),
          _row(l10n.shiftExpected, view.expectedCash.toString()),
          if (view.unfinishedSales > 0)
            _row('', l10n.shiftDeskUnfinishedCount(view.unfinishedSales)),
          if (view.unfiscalizedCount > 0)
            _row(
              '',
              l10n.shiftDeskUnfiscalizedCount(view.unfiscalizedCount),
              key: const Key('terminal_shift_unfiscalized'),
            ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('terminal_shift_counted'),
            controller: _counted,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.shiftDeskCountedLabel,
              helperText: l10n.shiftDeskCountedHint,
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          // Расхождение — **показ, а не запись**: записывает его касса, своей
          // же арифметикой, и это число здесь только затем, чтобы кассир
          // увидел, что закрывает. Совпадать они обязаны, и расходиться им
          // негде: «должно быть» пришло с кассы готовым, а вычитаемое
          // кассир набрал сам.
          if (_countedValue != null)
            _row(
              l10n.shiftDifference,
              (_countedValue! - view.expectedCash).toString(),
              key: const Key('terminal_shift_difference'),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('terminal_shift_close'),
            onPressed: _busy
                ? null
                : () => _run(
                    () => _desk!.close(counted: _countedValue),
                    l10n.shiftDeskClosedNow,
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
            child: Text(l10n.shiftClose),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String value, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
