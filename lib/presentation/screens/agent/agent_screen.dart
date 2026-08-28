import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/agent/agent_controller.dart';
import 'package:telepos/presentation/screens/agent/widgets/add_customer_dialog.dart';
import 'package:telepos/presentation/screens/agent/widgets/agent_details_dialog.dart';
import 'package:telepos/presentation/screens/agent/widgets/agent_search_bar.dart';
import 'package:telepos/presentation/screens/agent/widgets/agent_table.dart';

class AgentScreen extends ConsumerWidget {
  const AgentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentSearchProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (screenWidth >= 900) {
      return _DesktopLayout(state: state);
    } else if (screenWidth >= 600) {
      return _TabletLayout(state: state);
    } else {
      return _MobileLayout(state: state);
    }
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout({required this.state});

  final AgentSearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const AgentSearchBar(),

          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(context, ref),
                  Expanded(
                    child: state.filteredItems.isEmpty
                        ? _buildEmptyState()
                        : AgentTable(
                            items: state.filteredItems,
                            onSelect: (agent) =>
                                showAgentDetailsDialog(context, agent),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Text(
            state.agentType == AgentType.customer
                ? l10n.agentClients
                : l10n.agentSuppliers,
            style: AppTextStyles.h3,
          ),
          const SizedBox(width: 16),
          if (state.items.isNotEmpty)
            Text(
              l10n.agentFoundCount(state.filteredItems.length),
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.person_add, size: 18),
            label: Text(l10n.globalAdd),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: 16),
              Text(
                state.searchQuery.isEmpty
                    ? l10n.agentEnterNameOrPhoneToSearch
                    : l10n.agentNotFound,
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog<AgentItem>(
      context: context,
      builder: (context) => const AddCustomerDialog(),
    );
  }
}

class _TabletLayout extends ConsumerWidget {
  const _TabletLayout({required this.state});

  final AgentSearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const AgentSearchBar(compact: true),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: state.filteredItems.isEmpty
                  ? _buildEmptyState()
                  : AgentTable(
                      items: state.filteredItems,
                      compact: true,
                      onSelect: (agent) =>
                          showAgentDetailsDialog(context, agent),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add, color: AppColors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 48,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: 12),
              Text(
                state.searchQuery.isEmpty
                    ? l10n.agentSearchClients
                    : l10n.agentNotFoundShort,
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog<AgentItem>(
      context: context,
      builder: (context) => const AddCustomerDialog(),
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({required this.state});

  final AgentSearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(agentSearchProvider.notifier);

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.agentClients),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => notifier.toggleShowOnlyWithDebt(),
            icon: Icon(
              state.showOnlyWithDebt
                  ? Icons.money_off
                  : Icons.money_off_outlined,
              color: state.showOnlyWithDebt
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
            tooltip: l10n.agentOnlyWithDebt,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) => notifier.search(value),
              decoration: InputDecoration(
                hintText: l10n.agentSearchByNameOrPhone,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: context.semantic.canvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.filteredItems.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.filteredItems.length,
                    itemBuilder: (context, index) {
                      final agent = state.filteredItems[index];
                      return _AgentCard(agent: agent);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddScreen(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add, color: AppColors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 48,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: 12),
              Text(
                state.searchQuery.isEmpty
                    ? l10n.agentEnterNameOrPhone
                    : l10n.agentNotFound,
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<AgentItem>(
        builder: (context) => const AddCustomerScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});

  final AgentItem agent;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: agent.hasDebt
                    ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  agent.name.isNotEmpty ? agent.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: agent.hasDebt
                        ? Theme.of(context).colorScheme.error
                        : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (agent.phone != null)
                      Text(
                        agent.formattedPhone,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    agent.balance.toStringAsFixed(2),
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: agent.hasDebt
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (agent.lastOperationDate != null)
                    Text(
                      _formatDate(agent.lastOperationDate!),
                      style: AppTextStyles.body.copyWith(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d.$m.${date.year}';
  }

  void _onTap(BuildContext context) {
    showAgentDetailsDialog(context, agent);
  }
}

class AddCustomerScreen extends ConsumerWidget {
  const AddCustomerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addCustomerProvider);
    final notifier = ref.read(addCustomerProvider.notifier);

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.agentNewCustomer),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              onChanged: notifier.setName,
              decoration: InputDecoration(
                labelText: l10n.agentNameRequired,
                hintText: l10n.agentEnterCustomerName,
                errorText: state.nameError != null
                    ? ErrorLocalizer.localize(context, state.nameError!)
                    : null,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            TextField(
              onChanged: notifier.setPhone,
              decoration: InputDecoration(
                labelText: l10n.agentPhone,
                hintText: '+7 (XXX) XXX-XX-XX',
                errorText: state.phoneError != null
                    ? ErrorLocalizer.localize(context, state.phoneError!)
                    : null,
                prefixIcon: const Icon(Icons.phone),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            TextField(
              onChanged: notifier.setBin,
              decoration: InputDecoration(
                labelText: l10n.agentIin,
                hintText: l10n.agentBinHint,
                errorText: state.binError != null
                    ? ErrorLocalizer.localize(context, state.binError!)
                    : null,
                prefixIcon: const Icon(Icons.badge),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 12,
            ),
            const SizedBox(height: 24),

            if (state.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ErrorLocalizer.localize(context, state.error!),
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),

            ElevatedButton(
              onPressed: state.isLoading || !state.isValid
                  ? null
                  : () async {
                      final result = await notifier.save();
                      if (result != null && context.mounted) {
                        Navigator.of(context).pop(result);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(l10n.globalSave),
            ),
          ],
        ),
      ),
    );
  }
}
