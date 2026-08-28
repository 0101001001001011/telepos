import 'dart:async';

import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';

class SuggestionItem<T> {
  const SuggestionItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
  });

  final T value;

  final String label;

  final String? subtitle;

  final Widget? leading;
}

class AutoSuggestionField<T> extends StatefulWidget {
  const AutoSuggestionField({
    super.key,
    required this.onSearch,
    required this.onSelected,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.debounceMs = 300,
    this.minChars = 1,
    this.maxSuggestions = 10,
    this.emptyMessage,
    this.loadingWidget,
    this.enabled = true,
    this.autofocus = false,
  });

  final Future<List<SuggestionItem<T>>> Function(String query) onSearch;

  final ValueChanged<SuggestionItem<T>> onSelected;

  final TextEditingController? controller;

  final String? label;

  final String? hint;

  final IconData? prefixIcon;

  final int debounceMs;

  final int minChars;

  final int maxSuggestions;

  final String? emptyMessage;

  final Widget? loadingWidget;

  final bool enabled;

  final bool autofocus;

  @override
  State<AutoSuggestionField<T>> createState() => _AutoSuggestionFieldState<T>();
}

class _AutoSuggestionFieldState<T> extends State<AutoSuggestionField<T>> {
  late TextEditingController _controller;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();

  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;

  List<SuggestionItem<T>> _suggestions = [];
  bool _isLoading = false;
  bool _showOverlay = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _hideOverlay();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideOverlay();
    }
  }

  void _onTextChanged(String value) {
    if (value.length < widget.minChars) {
      _hideOverlay();
      return;
    }

    if (value == _lastQuery) return;
    _lastQuery = value;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: widget.debounceMs), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    _showOverlayIfNeeded();

    try {
      final results = await widget.onSearch(query);
      if (!mounted) return;

      setState(() {
        _suggestions = results.take(widget.maxSuggestions).toList();
        _isLoading = false;
      });
      _updateOverlay();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _updateOverlay();
    }
  }

  void _showOverlayIfNeeded() {
    if (_showOverlay) return;
    _showOverlay = true;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _showOverlay = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _onSuggestionSelected(SuggestionItem<T> item) {
    _controller.text = item.label;
    _hideOverlay();
    widget.onSelected(item);
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.semantic.canvas),
              ),
              child: _buildSuggestionsList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child:
              widget.loadingWidget ??
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.emptyMessage ?? AppLocalizations.of(context)!.nothingFound,
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _suggestions[index];
        return _SuggestionTile<T>(
          item: item,
          query: _lastQuery,
          onTap: () => _onSuggestionSelected(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        onChanged: _onTextChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon)
              : null,
          suffixIcon: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.borderPrimary),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile<T> extends StatelessWidget {
  const _SuggestionTile({
    required this.item,
    required this.query,
    required this.onTap,
  });

  final SuggestionItem<T> item;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (item.leading != null) ...[
              item.leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightedText(
                    text: item.label,
                    query: query,
                    style: AppTextStyles.body,
                    highlightStyle: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (item.subtitle != null)
                    Text(item.subtitle!, style: context.styles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightStyle,
  });

  final String text;
  final String query;
  final TextStyle style;
  final TextStyle highlightStyle;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(text, style: style);
    }

    return RichText(
      text: TextSpan(
        children: [
          if (index > 0) TextSpan(text: text.substring(0, index), style: style),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: highlightStyle,
          ),
          if (index + query.length < text.length)
            TextSpan(text: text.substring(index + query.length), style: style),
        ],
      ),
    );
  }
}
