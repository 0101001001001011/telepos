import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/core/settings/scroll_assist_settings.dart';

class ScrollAssist extends ConsumerStatefulWidget {
  const ScrollAssist({
    super.key,
    required this.controller,
    required this.child,
    this.alignment = Alignment.bottomRight,
    this.padding = const EdgeInsets.only(right: 12, bottom: 12),
  });

  final ScrollController controller;

  final Widget child;

  final AlignmentGeometry alignment;

  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<ScrollAssist> createState() => _ScrollAssistState();
}

class _ScrollAssistState extends ConsumerState<ScrollAssist> {
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(covariant ScrollAssist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !widget.controller.hasClients) return;
    final pos = widget.controller.position;
    final canUp = pos.pixels > pos.minScrollExtent + 1;
    final canDown = pos.pixels < pos.maxScrollExtent - 1;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  void _scrollBy(int direction) {
    if (!widget.controller.hasClients) return;
    final pos = widget.controller.position;
    final delta = pos.viewportDimension * 0.8 * direction;
    final target = (pos.pixels + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    widget.controller.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(scrollAssistEnabledProvider);

    final showOverlay = enabled && (_canScrollUp || _canScrollDown);

    return Stack(
      children: [
        widget.child,
        if (showOverlay)
          Positioned.fill(
            child: Align(
              alignment: widget.alignment,
              child: Padding(
                padding: widget.padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AssistButton(
                      icon: Icons.keyboard_arrow_up,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).nextPageTooltip,
                      enabled: _canScrollUp,
                      onTap: () => _scrollBy(-1),
                    ),
                    const SizedBox(height: 8),
                    _AssistButton(
                      icon: Icons.keyboard_arrow_down,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).previousPageTooltip,
                      enabled: _canScrollDown,
                      onTap: () => _scrollBy(1),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AssistButton extends StatelessWidget {
  const _AssistButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 0.78 : 0.30,
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: AppColors.white, size: 30),
          ),
        ),
      ),
    );
  }
}
