import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/data/esutd/esutd_service.dart';
import 'package:telepos/data/esutd/esutd_settings_store.dart';
import 'package:telepos/domain/esutd/esutd_models.dart';
import 'package:telepos/l10n/app_localizations.dart';

class EsutdDirectionNotifier extends Notifier<EsutdWaybillDirection> {
  @override
  EsutdWaybillDirection build() => EsutdWaybillDirection.inbound;

  void set(EsutdWaybillDirection direction) => state = direction;
}

final esutdDirectionProvider =
    NotifierProvider<EsutdDirectionNotifier, EsutdWaybillDirection>(
      EsutdDirectionNotifier.new,
    );

final esutdWaybillsProvider = FutureProvider<EsutdResult<List<EsutdWaybill>>>((
  ref,
) async {
  final direction = ref.watch(esutdDirectionProvider);
  return GetIt.I<EsutdService>().listWaybills(direction: direction);
});

class EsutdScreen extends ConsumerWidget {
  const EsutdScreen({super.key});

  Future<void> _openSettings(BuildContext context, WidgetRef ref) async {
    await context.push(AppRoutes.esutdSettings);
    if (!context.mounted) return;
    ref.invalidate(esutdWaybillsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final configured = GetIt.I<EsutdSettingsStore>().load().isActive;
    final direction = ref.watch(esutdDirectionProvider);
    final async = ref.watch(esutdWaybillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.esutdTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            key: const ValueKey('esutd-settings'),
            tooltip: l10n.esutdSettingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context, ref),
          ),
          IconButton(
            key: const ValueKey('esutd-refresh'),
            tooltip: l10n.esutdRefresh,
            icon: const Icon(Icons.sync),
            onPressed: () => ref.invalidate(esutdWaybillsProvider),
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
                    l10n.esutdNotConfigured,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      key: const ValueKey('esutd-configure'),
                      onPressed: () => _openSettings(context, ref),
                      icon: const Icon(Icons.settings, size: 18),
                      label: Text(l10n.esutdConfigure),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<EsutdWaybillDirection>(
              segments: [
                ButtonSegment(
                  value: EsutdWaybillDirection.inbound,
                  icon: const Icon(Icons.south_west, size: 16),
                  label: Text(l10n.esutdInbound),
                ),
                ButtonSegment(
                  value: EsutdWaybillDirection.outbound,
                  icon: const Icon(Icons.north_east, size: 16),
                  label: Text(l10n.esutdOutbound),
                ),
              ],
              selected: {direction},
              onSelectionChanged: (sel) =>
                  ref.read(esutdDirectionProvider.notifier).set(sel.first),
            ),
          ),
          Expanded(
            child: !configured
                ? Center(
                    child: Text(
                      l10n.esutdNotConfiguredShort,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : async.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (result) {
                      if (!result.success) {
                        return _ErrorView(
                          message: result.errorMessage ?? '—',
                          onRetry: () => ref.invalidate(esutdWaybillsProvider),
                        );
                      }
                      final docs = result.data ?? const [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                size: 64,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.esutdEmpty,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _WaybillTile(doc: docs[i], direction: direction),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.esutdRefresh),
          ),
        ],
      ),
    );
  }
}

class _WaybillTile extends StatelessWidget {
  const _WaybillTile({required this.doc, required this.direction});

  final EsutdWaybill doc;
  final EsutdWaybillDirection direction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final counterparty = direction == EsutdWaybillDirection.inbound
        ? (doc.createdOrganizationName ?? '—')
        : (doc.carrierOrganizationName ?? doc.carrierBin ?? '—');

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
                direction == EsutdWaybillDirection.inbound
                    ? Icons.south_west
                    : Icons.north_east,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.esutdWaybillNumber(doc.documentNumber),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  doc.status,
                  style: const TextStyle(
                    color: AppColors.info,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            counterparty,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (doc.createdDateTime != null) ...[
            const SizedBox(height: 2),
            Text(
              doc.createdDateTime!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            l10n.esutdCargoCount(doc.cargoCount),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
