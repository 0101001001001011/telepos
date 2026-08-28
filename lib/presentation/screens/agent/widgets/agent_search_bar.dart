import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/agent/agent_controller.dart';

class AgentSearchBar extends ConsumerStatefulWidget {
  const AgentSearchBar({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<AgentSearchBar> createState() => _AgentSearchBarState();
}

class _AgentSearchBarState extends ConsumerState<AgentSearchBar> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(agentSearchProvider);
      if (state.items.isEmpty && state.searchQuery.isEmpty) {
        ref.read(agentSearchProvider.notifier).search('');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentSearchProvider);
    final notifier = ref.read(agentSearchProvider.notifier);

    if (widget.compact) {
      return _buildCompactLayout(state, notifier);
    }

    return _buildFullLayout(state, notifier);
  }

  Widget _buildFullLayout(
    AgentSearchState state,
    AgentSearchNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          SegmentedButton<AgentType>(
            segments: [
              ButtonSegment(
                value: AgentType.customer,
                icon: const Icon(TeleposIcons.person, size: 18),
                label: Text(l10n.agentClients),
              ),
              ButtonSegment(
                value: AgentType.supplier,
                icon: const Icon(Icons.store, size: 18),
                label: Text(l10n.agentSuppliers),
              ),
            ],
            selected: {state.agentType},
            onSelectionChanged: (set) {
              notifier.setAgentType(set.first);
            },
          ),
          const SizedBox(width: 16),

          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: (value) => notifier.search(value),
              decoration: InputDecoration(
                hintText: l10n.agentSearchByNameOrPhone,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(TeleposIcons.close),
                        onPressed: () {
                          _controller.clear();
                          notifier.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),

          FilterChip(
            label: Text(l10n.agentWithDebt),
            selected: state.showOnlyWithDebt,
            onSelected: (_) => notifier.toggleShowOnlyWithDebt(),
            avatar: Icon(
              Icons.money_off,
              size: 18,
              color: state.showOnlyWithDebt
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            selectedColor: Theme.of(
              context,
            ).colorScheme.error.withValues(alpha: 0.1),
            checkmarkColor: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(
    AgentSearchState state,
    AgentSearchNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          PopupMenuButton<AgentType>(
            icon: Icon(
              state.agentType == AgentType.customer
                  ? TeleposIcons.person
                  : Icons.store,
            ),
            tooltip: l10n.agentTypeTooltip,
            onSelected: notifier.setAgentType,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: AgentType.customer,
                child: Row(
                  children: [
                    const Icon(TeleposIcons.person, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.agentClients),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AgentType.supplier,
                child: Row(
                  children: [
                    const Icon(Icons.store, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.agentSuppliers),
                  ],
                ),
              ),
            ],
          ),

          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _controller,
                onChanged: (value) => notifier.search(value),
                decoration: InputDecoration(
                  hintText: l10n.agentSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: context.semantic.canvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ),

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
    );
  }
}
