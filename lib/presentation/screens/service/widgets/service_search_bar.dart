import 'dart:async';

import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ServiceSearchBar extends StatefulWidget {
  const ServiceSearchBar({
    required this.onSearch,
    this.onScanQr,
    this.initialQuery = '',
    super.key,
  });

  final ValueChanged<String> onSearch;
  final VoidCallback? onScanQr;
  final String initialQuery;

  @override
  State<ServiceSearchBar> createState() => _ServiceSearchBarState();
}

class _ServiceSearchBarState extends State<ServiceSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onSearch(value.trim());
    });
  }

  void _clear() {
    _controller.clear();
    setState(() {});
    _debounce?.cancel();
    widget.onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: l10n.serviceQueueSearch,
                  hintStyle: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(TeleposIcons.close, size: 18),
                          onPressed: _clear,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          if (widget.onScanQr != null) ...[
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.qr_code_scanner,
                  color: AppColors.primary,
                ),
                onPressed: widget.onScanQr,
                tooltip: l10n.svcQr,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
