import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/data/snt/snt_service.dart';
import 'package:telepos/domain/snt/snt_models.dart';
import 'package:telepos/data/snt/snt_settings_store.dart';
import 'package:telepos/domain/snt/snt_store.dart';
import 'package:telepos/l10n/app_localizations.dart';

final sntDocumentsProvider = FutureProvider<List<SntDocument>>((ref) async {
  final store = GetIt.I<SntDocumentStore>();
  return store.list();
});

class SntScreen extends ConsumerWidget {
  const SntScreen({super.key});

  Future<void> _drain(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final report = await GetIt.I<SntService>().drainOutbox();
    if (!context.mounted) return;
    ref.invalidate(sntDocumentsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.sntDrainDone(report.submitted, report.remaining, report.failed),
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context, WidgetRef ref) async {
    await context.push(AppRoutes.sntSettings);
    if (!context.mounted) return;
    ref.invalidate(sntDocumentsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final docsAsync = ref.watch(sntDocumentsProvider);
    final configured = GetIt.I<SntSettingsStore>().load().isActive;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sntTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            key: const ValueKey('snt-settings'),
            tooltip: l10n.sntSettingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context, ref),
          ),
          IconButton(
            key: const ValueKey('snt-drain'),
            tooltip: l10n.sntRefresh,
            icon: const Icon(Icons.sync),
            onPressed: () => _drain(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!configured)
            Container(
              width: double.infinity,
              color: AppColors.warningLight,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.sntNotConfigured,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      key: const ValueKey('snt-configure'),
                      onPressed: () => _openSettings(context, ref),
                      icon: const Icon(Icons.settings, size: 18),
                      label: Text(l10n.sntConfigure),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: docsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.sntEmpty,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.sntEmptyHint,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _SntTile(doc: docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SntTile extends StatelessWidget {
  const _SntTile({required this.doc});

  final SntDocument doc;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = _statusStyle(context, doc.status, l10n);
    final dir = doc.direction == SntDirection.inbound
        ? l10n.sntDirectionInbound
        : l10n.sntDirectionOutbound;
    final counterparty = doc.direction == SntDirection.inbound
        ? doc.sender
        : doc.recipient;

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
              Icon(
                doc.direction == SntDirection.inbound
                    ? Icons.south_west
                    : Icons.north_east,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                dir,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
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
            '${counterparty.name ?? '—'} · ${counterparty.bin}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.sntLinesCount(doc.lines.length),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (doc.registrationNumber != null &&
              doc.registrationNumber!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              l10n.sntRegNumber(doc.registrationNumber!),
              style: const TextStyle(fontSize: 12, color: AppColors.success),
            ),
          ],
          if (doc.lastError != null) ...[
            const SizedBox(height: 4),
            Text(
              doc.lastError!,
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
    SntStatus status,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case SntStatus.draft:
        return (
          l10n.sntStatusDraft,
          Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case SntStatus.queued:
        return (l10n.sntStatusQueued, AppColors.warning);
      case SntStatus.registered:
        return (l10n.sntStatusRegistered, AppColors.info);
      case SntStatus.delivered:
        return (l10n.sntStatusDelivered, AppColors.info);
      case SntStatus.confirmed:
        return (l10n.sntStatusConfirmed, AppColors.success);
      case SntStatus.rejected:
        return (l10n.sntStatusRejected, Theme.of(context).colorScheme.error);
      case SntStatus.revoked:
        return (
          l10n.sntStatusRevoked,
          Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case SntStatus.annulled:
        return (
          l10n.sntStatusAnnulled,
          Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case SntStatus.failed:
        return (l10n.sntStatusFailed, Theme.of(context).colorScheme.error);
    }
  }
}
