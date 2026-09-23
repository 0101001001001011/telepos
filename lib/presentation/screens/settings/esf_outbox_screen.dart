import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/data/esf/esf_outbox_store.dart';
import 'package:telepos/data/esf/esf_settings_store.dart';
import 'package:telepos/data/esf/offline_esf_provider.dart';
import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_provider_registry.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/till_money.dart';

final esfOutboxProvider = FutureProvider<List<EsfOutboxEntry>>((ref) async {
  final store = GetIt.I<EsfOutboxStore>();
  return store.all();
});

class EsfOutboxScreen extends ConsumerWidget {
  const EsfOutboxScreen({super.key});

  Future<void> _retryAll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final settings = GetIt.I<EsfSettingsStore>().load();
    final provider = GetIt.I<EsfProviderRegistry>().resolve(settings);
    if (provider is! OfflineEsfProvider) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.esfSettingsEcpHint)));
      return;
    }
    final report = await provider.replay();
    if (!context.mounted) return;
    ref.invalidate(esfOutboxProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.esfOutboxRetryDone(
            report.delivered,
            report.remaining,
            report.failed,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final entriesAsync = ref.watch(esfOutboxProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.esfOutboxTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            key: const ValueKey('esf-retry-all'),
            tooltip: l10n.esfOutboxRetryAll,
            icon: const Icon(Icons.replay),
            onPressed: () => _retryAll(context, ref),
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.esfOutboxEmpty,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.esfOutboxEmptyHint,
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
            itemBuilder: (context, i) => _EsfTile(entry: entries[i]),
          );
        },
      ),
    );
  }
}

class _EsfTile extends StatelessWidget {
  const _EsfTile({required this.entry});

  final EsfOutboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inv = entry.invoice;
    final (label, color) = _statusStyle(context, entry.status, l10n);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  inv.accountingNumber.isNotEmpty
                      ? inv.accountingNumber
                      : inv.idempotencyKey,
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${inv.buyer.name} · ${inv.buyer.binIin}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${inv.totalWithVat} ${tillCurrencySymbol()} · ${l10n.esfOutboxAttempts(entry.attempts)}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (inv.isRegistered) ...[
            const SizedBox(height: 2),
            Text(
              l10n.esfOutboxRegNumber(inv.registrationNumber!),
              style: const TextStyle(fontSize: 12, color: AppColors.success),
            ),
          ],
          if (entry.lastError != null) ...[
            const SizedBox(height: 4),
            Text(
              entry.lastError!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  (String, Color) _statusStyle(
    BuildContext context,
    EsfStatus status,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case EsfStatus.draft:
        return (
          l10n.esfOutboxStatusDraft,
          Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case EsfStatus.queued:
        return (l10n.esfOutboxStatusQueued, AppColors.warning);
      case EsfStatus.submitted:
        return (l10n.esfOutboxStatusSubmitted, AppColors.info);
      case EsfStatus.delivered:
        return (l10n.esfOutboxStatusDelivered, AppColors.success);
      case EsfStatus.rejected:
        return (
          l10n.esfOutboxStatusRejected,
          Theme.of(context).colorScheme.error,
        );
      case EsfStatus.revoked:
        return (
          l10n.esfOutboxStatusRevoked,
          Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case EsfStatus.error:
        return (l10n.esfOutboxStatusError, Theme.of(context).colorScheme.error);
    }
  }
}
