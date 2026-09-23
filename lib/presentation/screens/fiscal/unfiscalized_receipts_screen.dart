import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_failure_reason.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/fiscal_reason_text.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/fiscal/widgets/orphan_qr_money_panel.dart';

/// **Один** экран нефискализованных чеков — по образцу `EsfOutboxScreen`.
///
/// # Что здесь показано и откуда оно берётся
///
/// Источник списка — **очередь фискализации** (`FiscalQueueEntries`,
/// строки со статусом `failed`), а не колонка исхода в `Sales`. Колонка
/// (задача 14) станет правдой **на чеке**, но источником списка не будет:
/// она появляется позже этого экрана, а очередь миграции не требует вовсе.
///
/// # Две кнопки, обе названные
///
/// * **Повторить** — отправляет **сохранённый документ** нынешним
///   провайдером, тем же `ExternalCheckNumber`. Пересборки запроса из базы
///   чека здесь нет и быть не может: она уехала бы с другим ключом, и на
///   одну продажу приехали бы два фискальных документа.
/// * **Списать** — помечает строку разобранной, **с обязательными
///   причиной и именем**. Строка при этом не удаляется: тихой чистки у
///   этой очереди нет.
///
/// Строки, записанные до задачи 11, несут записку вместо документа и чужой
/// ключ. Повторять их нечем — у таких показана названная причина и
/// **только** кнопка «Списать».
///
/// # Чего этот экран НЕ делает
///
/// Не заводит автоматического повтора. `network` и `tokenExpired` и так
/// встают в очередь как `pending` и подбираются `replay()`; всё остальное
/// — нетранзиентный отказ, который слепым повтором не лечится, а лечится
/// человеком, сначала исправившим причину.
final unfiscalizedQueueProvider =
    FutureProvider.autoDispose<List<FiscalQueueEntry>>((ref) async {
      final store = GetIt.I<FiscalQueueStore>();
      return store.failed();
    });

class UnfiscalizedReceiptsScreen extends ConsumerWidget {
  const UnfiscalizedReceiptsScreen({super.key});

  /// Нынешний провайдер — собранный из нынешних настроек, а не тот, что
  /// отказал. В этом и смысл ручного повтора: человек сначала правит
  /// причину (учётные данные, адрес, разблокированная касса), и повтор
  /// обязан пойти через исправленное.
  static Future<OfflineQueueingProvider?> resolveProvider() async {
    if (!GetIt.I.isRegistered<FiscalProviderRegistry>() ||
        !GetIt.I.isRegistered<FiscalSettingsSource>()) {
      return null;
    }
    final settings = await GetIt.I<FiscalSettingsSource>().load();
    final provider = GetIt.I<FiscalProviderRegistry>().resolve(settings);
    return provider is OfflineQueueingProvider ? provider : null;
  }

  Future<void> _retry(
    BuildContext context,
    WidgetRef ref,
    FiscalQueueEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final provider = await resolveProvider();
    if (provider == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.unfiscalizedNoOperator)),
      );
      return;
    }
    final result = await provider.retryFailed(entry);
    ref.invalidate(unfiscalizedQueueProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? l10n.unfiscalizedRetryDone(result.fiscalSign ?? '')
              // Фраза — словарём по коду отказа, а не `errorMessage`:
              // тот написан по-русски провайдером и оператором.
              : l10n.unfiscalizedRetryFailed(
                  fiscalReasonText(
                    l10n,
                    FiscalFailureReason.fromResult(result).encode(),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _writeOff(
    BuildContext context,
    WidgetRef ref,
    FiscalQueueEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final by = ref.read(userNameProvider) ?? '';
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _WriteOffDialog(by: by),
    );
    if (reason == null || reason.trim().isEmpty) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final provider = await resolveProvider();
    if (provider == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.unfiscalizedNoOperator)),
      );
      return;
    }
    await provider.writeOffFailed(
      entry,
      by: by.isEmpty ? l10n.unfiscalizedUnknownUser : by,
      reason: reason,
    );
    ref.invalidate(unfiscalizedQueueProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.unfiscalizedWriteOffDone)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final entriesAsync = ref.watch(unfiscalizedQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.unfiscalizedTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      // **Деньги без чека — над списком и вне его** (задача 22).
      //
      // Вне `entriesAsync.when` намеренно: очередь фискализации и
      // намерения QR — два разных источника одной беды («деньги взяты,
      // документа нет»), и пустая очередь **не значит**, что разбирать
      // нечего. Положи панель внутрь ветки `data`, и оплаченное намерение
      // стало бы невидимым ровно тогда, когда все чеки фискализованы, —
      // то есть в самом обычном случае.
      body: Column(
        children: [
          const OrphanQrMoneyPanel(),
          Expanded(child: _queueBody(context, ref, l10n, entriesAsync)),
        ],
      ),
    );
  }

  Widget _queueBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<List<FiscalQueueEntry>> entriesAsync,
  ) {
    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.unfiscalizedEmpty,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.unfiscalizedEmptyHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _UnfiscalizedTile(
            entry: entries[i],
            onRetry: () => _retry(context, ref, entries[i]),
            onWriteOff: () => _writeOff(context, ref, entries[i]),
          ),
        );
      },
    );
  }
}

class _UnfiscalizedTile extends StatelessWidget {
  const _UnfiscalizedTile({
    required this.entry,
    required this.onRetry,
    required this.onWriteOff,
  });

  final FiscalQueueEntry entry;
  final VoidCallback onRetry;
  final VoidCallback onWriteOff;

  /// Номер чека, по которому человек находит продажу. Берётся из
  /// документа; у строк старого вида — из записки.
  int? get _receiptNo {
    final fromDocument = entry.payload['localOperationId'];
    if (fromDocument is int) return fromDocument;
    final fromNote = entry.payload['receiptNo'];
    return fromNote is int ? fromNote : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final age = DateTime.now().difference(entry.occurredAt);
    final overdue = age > kOfflineFiscalWindow;
    final writeOff = entry.writeOff;
    final receiptNo = _receiptNo;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: overdue && writeOff == null ? scheme.error : scheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  receiptNo == null
                      ? entry.idempotencyKey
                      : l10n.unfiscalizedReceiptNo(receiptNo),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (overdue ? scheme.error : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  overdue
                      ? l10n.unfiscalizedOverdue
                      : l10n.unfiscalizedAgeHours(age.inHours),
                  style: TextStyle(
                    color: overdue ? scheme.error : AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.idempotencyKey,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (entry.lastError != null) ...[
            const SizedBox(height: 4),
            Text(
              // Код причины из data-слоя → фраза словаря текущей локали.
              fiscalReasonText(l10n, entry.lastError),
              key: const ValueKey('unfiscalized-reason'),
              style: TextStyle(fontSize: 12, color: scheme.error),
            ),
          ],
          if (!entry.carriesDocument) ...[
            const SizedBox(height: 4),
            Text(
              l10n.unfiscalizedNoDocument,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          if (writeOff != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.unfiscalizedWrittenOff(writeOff.by, writeOff.reason),
              style: const TextStyle(fontSize: 12, color: AppColors.success),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (entry.carriesDocument && writeOff == null)
                TextButton.icon(
                  key: const ValueKey('unfiscalized-retry'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.replay, size: 18),
                  label: Text(l10n.unfiscalizedRetry),
                ),
              if (writeOff == null)
                TextButton.icon(
                  key: const ValueKey('unfiscalized-write-off'),
                  onPressed: onWriteOff,
                  icon: const Icon(Icons.playlist_remove, size: 18),
                  label: Text(l10n.unfiscalizedWriteOff),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Причина обязательна: кнопка подтверждения не включается, пока поле
/// пусто. Безымянное и беспричинное списание неотличимо от тихой чистки —
/// а именно её здесь и не должно быть.
class _WriteOffDialog extends StatefulWidget {
  const _WriteOffDialog({required this.by});

  final String by;

  @override
  State<_WriteOffDialog> createState() => _WriteOffDialogState();
}

class _WriteOffDialogState extends State<_WriteOffDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filled = _controller.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(l10n.unfiscalizedWriteOffTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.unfiscalizedWriteOffBy(
              widget.by.isEmpty ? l10n.unfiscalizedUnknownUser : widget.by,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('unfiscalized-write-off-reason'),
            controller: _controller,
            autofocus: true,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.unfiscalizedWriteOffReason,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
        FilledButton(
          key: const ValueKey('unfiscalized-write-off-confirm'),
          onPressed: filled
              ? () => Navigator.of(context).pop(_controller.text)
              : null,
          child: Text(l10n.unfiscalizedWriteOff),
        ),
      ],
    );
  }
}
