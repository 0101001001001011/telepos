import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/entities/warranty/claim_entity.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/wms/claim_controller.dart';

class ClaimsScreen extends ConsumerStatefulWidget {
  const ClaimsScreen({super.key});

  @override
  ConsumerState<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends ConsumerState<ClaimsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(claimControllerProvider.notifier).loadAllClaims();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final claimState = ref.watch(claimControllerProvider);
    final layout = Breakpoints.of(context);

    if (claimState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorLocalizer.localize(context, claimState.error!)),
          ),
        );
      });
    }

    final allClaims = claimState.claims;
    final openClaims = allClaims.where((c) => c.status == 0).toList();
    final inProgressClaims = allClaims.where((c) => c.status == 1).toList();
    final resolvedClaims = allClaims.where((c) => c.status == 2).toList();

    if (layout.isDesktop) {
      return _buildDesktopLayout(
        claimState,
        openClaims,
        inProgressClaims,
        resolvedClaims,
      );
    }
    return _buildMobileLayout(
      claimState,
      openClaims,
      inProgressClaims,
      resolvedClaims,
    );
  }

  Widget _buildMobileLayout(
    ClaimState claimState,
    List<ClaimEntity> openClaims,
    List<ClaimEntity> inProgressClaims,
    List<ClaimEntity> resolvedClaims,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wmsClaims),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.wmsClaimTabOpen),
            Tab(text: l10n.wmsClaimTabInProgress),
            Tab(text: l10n.wmsClaimTabResolved),
          ],
        ),
        actions: [
          if (claimState.isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createClaim,
        child: const Icon(TeleposIcons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClaimList(openClaims, l10n.wmsNoOpenClaims),
          _buildClaimList(inProgressClaims, l10n.wmsNoInProgressClaims),
          _buildClaimList(resolvedClaims, l10n.wmsNoResolvedClaims),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    ClaimState claimState,
    List<ClaimEntity> openClaims,
    List<ClaimEntity> inProgressClaims,
    List<ClaimEntity> resolvedClaims,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.report_problem, size: 28),
              const SizedBox(width: 12),
              Text(
                l10n.wmsClaims,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (claimState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _createClaim,
                icon: const Icon(TeleposIcons.add),
                label: Text(l10n.wmsNewClaim),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 500,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: l10n.wmsClaimTabOpen),
                    Tab(text: l10n.wmsClaimTabInProgress),
                    Tab(text: l10n.wmsClaimTabResolved),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildClaimTable(openClaims, l10n.wmsNoOpenClaims),
                      _buildClaimTable(
                        inProgressClaims,
                        l10n.wmsNoInProgressClaims,
                      ),
                      _buildClaimTable(
                        resolvedClaims,
                        l10n.wmsNoResolvedClaims,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimList(List<ClaimEntity> claims, String emptyMessage) {
    if (claims.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              TeleposIcons.checkCircle,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: claims.length,
      itemBuilder: (context, index) => _buildClaimCard(claims[index]),
    );
  }

  Widget _buildClaimCard(ClaimEntity claim) {
    final l10n = AppLocalizations.of(context)!;
    final severityColor = _getSeverityColor(claim.severity ?? 0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: severityColor.withValues(alpha: 0.2),
          child: Icon(
            _getClaimTypeIcon(claim.claimType ?? 0),
            color: severityColor,
            size: 20,
          ),
        ),
        title: Text(claim.claimNumber ?? '-'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.wmsProductLabeled('${claim.ucode ?? '-'}')),
            const SizedBox(height: 2),
            Text(
              '${_getClaimTypeText(claim.claimType ?? 0)}  |  ${claim.createdAt != null ? _formatTimestamp(claim.createdAt!) : '-'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Chip(
          label: Text(
            _getSeverityText(claim.severity ?? 0),
            style: TextStyle(fontSize: 11, color: severityColor),
          ),
          backgroundColor: severityColor.withValues(alpha: 0.15),
          side: BorderSide.none,
          padding: EdgeInsets.zero,
        ),
        onTap: () => _openClaimDetail(claim),
      ),
    );
  }

  Widget _buildClaimTable(List<ClaimEntity> claims, String emptyMessage) {
    final l10n = AppLocalizations.of(context)!;
    if (claims.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.wmsNumber)),
          DataColumn(label: Text(l10n.wmsProduct)),
          DataColumn(label: Text(l10n.wmsType)),
          DataColumn(label: Text(l10n.wmsSeverity)),
          DataColumn(label: Text(l10n.wmsDate)),
          DataColumn(label: Text(l10n.wmsActions)),
        ],
        rows: claims.map((claim) {
          final severityColor = _getSeverityColor(claim.severity ?? 0);

          return DataRow(
            cells: [
              DataCell(Text(claim.claimNumber ?? '-')),
              DataCell(Text('${claim.ucode ?? '-'}')),
              DataCell(Text(_getClaimTypeText(claim.claimType ?? 0))),
              DataCell(
                Chip(
                  label: Text(
                    _getSeverityText(claim.severity ?? 0),
                    style: TextStyle(fontSize: 11, color: severityColor),
                  ),
                  backgroundColor: severityColor.withValues(alpha: 0.15),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                ),
              ),
              DataCell(
                Text(
                  claim.createdAt != null
                      ? _formatTimestamp(claim.createdAt!)
                      : '-',
                ),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => _openClaimDetail(claim),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getSeverityColor(int severity) {
    return switch (severity) {
      0 => Colors.blue,
      1 => Colors.orange,
      2 => Theme.of(context).colorScheme.error,
      3 => Colors.purple,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  String _getSeverityText(int severity) {
    final l10n = AppLocalizations.of(context)!;
    return switch (severity) {
      0 => l10n.wmsSeverityLow,
      1 => l10n.wmsSeverityMedium,
      2 => l10n.wmsSeverityHigh,
      3 => l10n.wmsSeverityCritical,
      _ => '-',
    };
  }

  IconData _getClaimTypeIcon(int type) {
    return switch (type) {
      0 => Icons.broken_image,
      1 => Icons.swap_horiz,
      2 => Icons.report,
      3 => Icons.warning,
      _ => Icons.report_problem,
    };
  }

  String _getClaimTypeText(int type) {
    final l10n = AppLocalizations.of(context)!;
    return switch (type) {
      0 => l10n.wmsClaimTypeDefect,
      1 => l10n.wmsClaimTypeMissort,
      2 => l10n.wmsClaimTypeShortage,
      3 => l10n.wmsClaimTypeDamage,
      _ => l10n.wmsClaimTypeOther,
    };
  }

  String _claimTypeCode(int type) {
    return switch (type) {
      0 => 'supplier_defect',
      1 => 'quality',
      2 => 'warranty',
      3 => 'transport_damage',
      _ => 'quality',
    };
  }

  String _severityCode(int severity) {
    return switch (severity) {
      0 => 'low',
      1 => 'medium',
      2 => 'high',
      3 => 'critical',
      _ => 'medium',
    };
  }

  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  void _createClaim() {
    final l10n = AppLocalizations.of(context)!;
    final descCtrl = TextEditingController();
    final ucodeCtrl = TextEditingController();
    int selectedType = 0;
    int selectedSeverity = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.wmsNewClaim),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ucodeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.wmsProductUcodeField,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedType,
                  decoration: InputDecoration(labelText: l10n.wmsType),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(l10n.wmsClaimTypeDefect),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(l10n.wmsClaimTypeMissort),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(l10n.wmsClaimTypeShortage),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(l10n.wmsClaimTypeDamage),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedType = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedSeverity,
                  decoration: InputDecoration(labelText: l10n.wmsSeverity),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(l10n.wmsSeverityLow),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(l10n.wmsSeverityMedium),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(l10n.wmsSeverityHigh),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(l10n.wmsSeverityCritical),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedSeverity = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.wmsProblemDescription,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.globalCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (descCtrl.text.isEmpty) return;
                Navigator.of(ctx).pop();
                final ucode = int.tryParse(ucodeCtrl.text.trim());
                final operatorId = ref.read(currentUserIdProvider) ?? 0;
                final result = await ref
                    .read(claimControllerProvider.notifier)
                    .createClaim(
                      claimType: _claimTypeCode(selectedType),
                      ucode: ucode,
                      operatorId: operatorId,
                      problemDescription: descCtrl.text.trim(),
                      severity: _severityCode(selectedSeverity),
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.success
                            ? l10n.wmsClaimCreated
                            : result.errorMessage ?? l10n.wmsError,
                      ),
                    ),
                  );
                }
              },
              child: Text(l10n.wmsCreate),
            ),
          ],
        ),
      ),
    );
  }

  void _openClaimDetail(ClaimEntity claim) {
    final l10n = AppLocalizations.of(context)!;
    if (claim.id != null) {
      ref.read(claimControllerProvider.notifier).selectClaim(claim.id!);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (ctx, ref, _) {
            final claimState = ref.watch(claimControllerProvider);
            final history = claimState.history;

            return AlertDialog(
              title: Text(l10n.wmsClaimTitle(claim.claimNumber ?? '-')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.wmsProductLabeled('${claim.ucode ?? '-'}')),
                    const SizedBox(height: 8),
                    Text(
                      l10n.wmsTypeLabeled(
                        _getClaimTypeText(claim.claimType ?? 0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.wmsSeverityLabeled(
                        _getSeverityText(claim.severity ?? 0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.wmsDateLabeled(
                        claim.createdAt != null
                            ? _formatTimestamp(claim.createdAt!)
                            : '-',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.wmsProblemDescriptionLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      claim.problemDescription?.isNotEmpty == true
                          ? claim.problemDescription!
                          : l10n.wmsNoDescription,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.wmsResolutionLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      claim.resolutionNotes?.isNotEmpty == true
                          ? claim.resolutionNotes!
                          : l10n.wmsNotSpecified,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.wmsHistoryLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (claimState.isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (history.isEmpty)
                      Text(
                        l10n.wmsNoRecords,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      ...history.map(
                        (h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${h.action ?? '-'} '
                            '${h.timestamp != null ? _formatTimestamp(h.timestamp!) : ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                if (claim.isOpen)
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _resolveClaim(claim);
                    },
                    child: Text(l10n.wmsResolve),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.globalClose),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _resolveClaim(ClaimEntity claim) {
    final l10n = AppLocalizations.of(context)!;
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wmsResolveClaimTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.wmsResolutionNotes),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.globalCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (claim.id == null) return;
              final result = await ref
                  .read(claimControllerProvider.notifier)
                  .resolveClaim(
                    claim.id!,
                    resolutionType: 'resolved',
                    notes: notesCtrl.text.trim(),
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success
                          ? l10n.wmsClaimResolved
                          : result.errorMessage ?? l10n.wmsError,
                    ),
                  ),
                );
              }
            },
            child: Text(l10n.wmsResolve),
          ),
        ],
      ),
    );
  }
}
