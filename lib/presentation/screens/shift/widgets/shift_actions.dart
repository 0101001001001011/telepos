import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/config/background_task_manager.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/domain/services/currency_service.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/presentation/screens/settings/fiscal_correction_screen.dart';

DateTime? _lastZTapAt;
DateTime? _lastXTapAt;
const Duration _kReportTapDebounce = Duration(milliseconds: 1200);

class ShiftActions extends ConsumerWidget {
  const ShiftActions({super.key, required this.state, this.compact = false});

  final ShiftState state;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(shiftControllerProvider.notifier);

    if (compact) {
      return _buildCompactLayout(context, notifier);
    }

    return _buildFullLayout(context, notifier);
  }

  Future<void> _printZReport(
    BuildContext context,
    ShiftNotifier notifier,
  ) async {
    final now = DateTime.now();
    if (!BackgroundTaskManager.disabledForTests &&
        _lastZTapAt != null &&
        now.difference(_lastZTapAt!) < _kReportTapDebounce) {
      return;
    }
    _lastZTapAt = now;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await notifier.printZReport();

    // Кассир, закрывающий смену, узнаёт, что бумаги ещё нет, **из ответа на
    // своё нажатие**, а не открыв настройки принтера. Смена при этом ничего не
    // ждёт (И30): сообщение показывается по ответу очереди, а не по исходу
    // печати.
    final (
      String message,
      Color? background,
      Duration shown,
    ) = switch (outcome) {
      ZReportOutcome.queued => (
        l10n.shiftZReportQueued,
        AppColors.warning,
        // Дольше обычного: это сообщение говорит, что документа на бумаге
        // нет, и его нужно успеть прочитать.
        const Duration(seconds: 8),
      ),
      ZReportOutcome.alreadyQueued => (
        l10n.shiftZReportAlreadyQueued,
        null,
        const Duration(seconds: 4),
      ),
      ZReportOutcome.failed => (
        l10n.shiftZReportPrintFailed,
        Colors.red,
        const Duration(seconds: 6),
      ),
    };

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        duration: shown,
      ),
    );
  }

  Future<void> _runXReport(BuildContext context, ShiftNotifier notifier) async {
    final now = DateTime.now();
    if (!BackgroundTaskManager.disabledForTests &&
        _lastXTapAt != null &&
        now.difference(_lastXTapAt!) < _kReportTapDebounce) {
      return;
    }
    _lastXTapAt = now;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await notifier.runXReport();
    if (outcome.skipped) return;

    final String msg;
    final Color? color;
    if (outcome.printed) {
      final fiscal = outcome.fiscal?.result;
      if (fiscal != null &&
          fiscal.success &&
          (fiscal.queued || fiscal.offlineMode)) {
        msg = l10n.shiftXReportPrintedOffline;
        color = AppColors.warning;
      } else {
        msg = l10n.shiftXReportPrinted;
        color = null;
      }
    } else {
      msg = l10n.shiftXReportFailed;
      color = Colors.red;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Widget _buildFullLayout(BuildContext context, ShiftNotifier notifier) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.isOpen) ...[
            OutlinedButton.icon(
              onPressed: () => _printZReport(context, notifier),
              icon: const Icon(Icons.print_outlined),
              label: Text(l10n.shiftPrintZReport),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              key: const ValueKey('shift-xreport-button'),
              onPressed: () => _runXReport(context, notifier),
              icon: const Icon(Icons.summarize_outlined),
              label: Text(l10n.shiftXReport),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              key: const ValueKey('shift-correction-button'),
              onPressed: () => showFiscalCorrectionScreen(context),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(l10n.shiftCorrectionReceipt),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: state.canClose
                  ? () => _showCloseConfirmation(context, notifier)
                  : null,
              icon: const Icon(TeleposIcons.lock),
              label: Text(l10n.shiftClose),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                disabledBackgroundColor: context.semantic.canvas,
                disabledForegroundColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
              ),
            ),

            if (!state.canClose) ...[
              const SizedBox(height: 8),
              Text(
                state.activeSalesCount > 0 || state.pendingSalesCount > 0
                    ? l10n.shiftFinishAllSales
                    : l10n.shiftCannotClose,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ] else ...[
            ElevatedButton.icon(
              onPressed: () => _showOpenDialog(context, notifier),
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(l10n.shiftOpen),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context, ShiftNotifier notifier) {
    final l10n = AppLocalizations.of(context)!;

    if (state.isOpen) {
      return Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => _printZReport(context, notifier),
            icon: const Icon(Icons.print_outlined, size: 20),
            label: Text(l10n.shiftZReport),
          ),
          const SizedBox(width: 8),

          OutlinedButton.icon(
            key: const ValueKey('shift-xreport-button-compact'),
            onPressed: () => _runXReport(context, notifier),
            icon: const Icon(Icons.summarize_outlined, size: 20),
            label: Text(l10n.shiftXReport),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: ElevatedButton.icon(
              onPressed: state.canClose
                  ? () => _showCloseConfirmation(context, notifier)
                  : null,
              icon: const Icon(TeleposIcons.lock, size: 20),
              label: Text(l10n.shiftClose),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: context.semantic.canvas,
                disabledForegroundColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showOpenDialog(context, notifier),
          icon: const Icon(Icons.lock_open_outlined),
          label: Text(l10n.shiftOpen),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
    }
  }

  void _showOpenDialog(BuildContext context, ShiftNotifier notifier) {
    final controller = TextEditingController(text: '0');
    // Валюта кассы, а не тенге: здесь кассир вводит ДЕНЬГИ, и подпись у поля
    // — заявление о том, какие. До 2026-09-22 тут стояло зашитое «KZT» на
    // любой кассе любой страны.
    final currency = GetIt.I<CurrencyService>().code;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl10n.shiftOpeningShift),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dl10n.shiftEnterInitialAmount, style: AppTextStyles.body),
              const SizedBox(height: 16),
              TextField(
                // Ключ не украшение: окно открытия смены живёт поверх
                // экрана, у которого свои поля ввода (вкладка «Total»), и
                // `find.byType(TextField).first` попадает в них, а не сюда.
                // Съёмка главы 7 сняла так дубль, где сумма открытия не
                // ввелась: касса показала «Expected in register 3.50»
                // вместо 203.50, прямо против дорожки.
                key: const ValueKey('shift-opening-cash'),
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: '0.00',
                  suffixText: currency,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(dl10n.globalCancel),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                final amount = Decimal.tryParse(text) ?? Decimal.zero;
                Navigator.of(ctx).pop();
                notifier.openShift(amount);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
              ),
              child: Text(dl10n.shiftOpenAction),
            ),
          ],
        );
      },
    );
  }

  /// Сводка нефискализованных — из настоящей службы смены, а не из
  /// состояния экрана: экран о фискальной очереди ничего не знает.
  Future<UnfiscalizedAtClose> _unfiscalizedAtClose() async {
    if (!GetIt.I.isRegistered<ShiftService>()) return UnfiscalizedAtClose.empty;
    try {
      return await GetIt.I<ShiftService>().unfiscalizedAtClose();
    } catch (_) {
      return UnfiscalizedAtClose.empty;
    }
  }

  void _showCloseConfirmation(BuildContext context, ShiftNotifier notifier) {
    final hasDifference = state.hasDifference;
    final diff = state.difference;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl10n.shiftClosingShift),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDifference) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: AppColors.warning),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dl10n.shiftDiscrepancyFound,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              dl10n.shiftDifferenceAmount(
                                '${diff > Decimal.zero ? '+' : ''}${diff.toStringAsFixed(2)}',
                              ),
                              style: AppTextStyles.body.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Задача 11: смену с нефискализованными чеками закрыть
              // можно, но **не молча**. Число и номера называются здесь,
              // до нажатия, а не задним числом в журнале.
              //
              // Ревизия 2026-09-19 добавила вторую полосу — **ждущие**
              // документы. Это не та же беда: у них документа ещё нет, но
              // он будет. Важно другое — Z-отчёт их дожидается
              // (`ShiftService.onCloseShift`), и если связь не вернётся,
              // отчёт не уйдёт вовсе. Кассир узнаёт об этом до нажатия,
              // когда ещё может подождать сети, а не после.
              FutureBuilder<UnfiscalizedAtClose>(
                future: _unfiscalizedAtClose(),
                builder: (context, snapshot) {
                  final summary = snapshot.data;
                  if (summary == null || summary.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (summary.hasFailed)
                        _CloseNotice(
                          noticeKey: const ValueKey('shift-close-unfiscalized'),
                          icon: Icons.receipt_long_outlined,
                          color: Theme.of(context).colorScheme.error,
                          text: dl10n.unfiscalizedAtShiftClose(
                            summary.count,
                            summary.receiptNumbers.join(', '),
                          ),
                        ),
                      if (summary.onTheWay > 0)
                        _CloseNotice(
                          noticeKey: const ValueKey('shift-close-on-the-way'),
                          icon: Icons.cloud_upload_outlined,
                          color: AppColors.warning,
                          text: dl10n.documentsOnTheWayAtShiftClose(
                            summary.onTheWay,
                            summary.onTheWayReceipts.join(', '),
                          ),
                        ),
                    ],
                  );
                },
              ),
              Text(dl10n.shiftConfirmCloseQuestion, style: AppTextStyles.body),
              const SizedBox(height: 8),
              Text(
                dl10n.shiftFixedAmount(
                  // То же правило, каким живёт `LocalShiftDesk.close`:
                  // не считали — записывается ожидание. Стоял
                  // `systemTotal`, и окно называло сумму, отличную от
                  // той, что уходила в смену и в Z-отчёт.
                  '${(state.hasCounted ? state.enteredTotal : state.expectedCash).toStringAsFixed(2)} '
                  '${GetIt.I<CurrencyService>().symbol}',
                ),
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(dl10n.globalCancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                notifier.closeShift();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: hasDifference
                    ? AppColors.warning
                    : AppColors.primary,
                foregroundColor: AppColors.white,
              ),
              child: Text(
                hasDifference
                    ? dl10n.shiftCloseWithDiscrepancy
                    : dl10n.globalClose,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Полоса предупреждения в окне закрытия смены.
///
/// Заведена, когда полос стало две: одинаковая рамка, разные цвет, значок и
/// смысл. Переписывать рамку второй раз значило бы завести два внешних вида
/// у одного и того же предупреждения — они разошлись бы на первой правке.
class _CloseNotice extends StatelessWidget {
  const _CloseNotice({
    required this.noticeKey,
    required this.icon,
    required this.color,
    required this.text,
  });

  final Key noticeKey;
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        key: noticeKey,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: AppTextStyles.body)),
          ],
        ),
      ),
    );
  }
}
