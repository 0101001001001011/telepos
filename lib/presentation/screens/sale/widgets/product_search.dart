import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/platform/platform_info.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/keyboards/virtual_keyboard.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

class ProductSearch extends ConsumerStatefulWidget {
  const ProductSearch({this.autofocus = false, super.key});

  final bool autofocus;

  @override
  ConsumerState<ProductSearch> createState() => _ProductSearchState();
}

class _ProductSearchState extends ConsumerState<ProductSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showKeyboard = false;

  bool get _isDesktopPos => !kIsWeb && PlatformInfo.isDesktop;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onVirtualKey(String key) {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(selection.start, selection.end, key);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + key.length),
    );
    ref.read(saleControllerProvider.notifier).search(newText);
  }

  void _onVirtualBackspace() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.start == 0 && selection.end == 0) return;

    final start = selection.start == selection.end
        ? selection.start - 1
        : selection.start;
    final newText = text.replaceRange(start, selection.end, '');
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start),
    );
    ref.read(saleControllerProvider.notifier).search(newText);
  }

  void _onVirtualEnter() {
    final state = ref.read(saleControllerProvider);
    if (state.searchResults.isNotEmpty) {
      ref
          .read(saleControllerProvider.notifier)
          .addProduct(state.searchResults.first);
      _controller.clear();
      ref.read(saleControllerProvider.notifier).search('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(saleControllerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          readOnly: _isDesktopPos && _showKeyboard,
          showCursor: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchProductHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isDesktopPos)
                  IconButton(
                    icon: Icon(
                      _showKeyboard ? Icons.keyboard_hide : Icons.keyboard,
                      color: _showKeyboard
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    tooltip: _showKeyboard
                        ? AppLocalizations.of(context)!.keyboardHide
                        : AppLocalizations.of(context)!.keyboardShow,
                    onPressed: () {
                      setState(() => _showKeyboard = !_showKeyboard);
                      if (_showKeyboard) _focusNode.requestFocus();
                    },
                  ),
                if (state.searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(TeleposIcons.close),
                    onPressed: () {
                      _controller.clear();
                      ref.read(saleControllerProvider.notifier).search('');
                    },
                  ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
          ),
          onChanged: (value) {
            ref.read(saleControllerProvider.notifier).search(value);
          },
          onSubmitted: (value) async {
            if (value.isEmpty) return;

            final notifier = ref.read(saleControllerProvider.notifier);
            final currentState = ref.read(saleControllerProvider);

            if (currentState.searchResults.isNotEmpty) {
              notifier.addProduct(currentState.searchResults.first);
              _controller.clear();
              notifier.search('');
              _focusNode.requestFocus();
              return;
            }

            final found = await notifier.addByBarcode(value);
            if (found) {
              _controller.clear();
              notifier.search('');
            }
            _focusNode.requestFocus();
          },
          onTap: () {
            if (_isDesktopPos && !_showKeyboard) {
              setState(() => _showKeyboard = true);
            }
          },
        ),

        if (state.isSearching)
          const Padding(
            padding: EdgeInsets.all(AppTheme.spacing),
            child: CircularProgressIndicator(),
          )
        else if (state.searchResults.isNotEmpty)
          _SearchResults(
            results: state.searchResults,
            onSelect: (product) {
              ref.read(saleControllerProvider.notifier).addProduct(product);
              _controller.clear();
              ref.read(saleControllerProvider.notifier).search('');
              _focusNode.requestFocus();
            },
          ),

        if (_showKeyboard)
          VirtualKeyboard(
            onKeyPressed: _onVirtualKey,
            onBackspace: _onVirtualBackspace,
            onEnter: _onVirtualEnter,
            onClose: () => setState(() => _showKeyboard = false),
          ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.onSelect});

  final List<ProductSearchResult> results;
  final void Function(ProductSearchResult) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = results[index];
          return _SearchResultItem(
            product: product,
            onTap: () => onSelect(product),
          );
        },
      ),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  const _SearchResultItem({required this.product, required this.onTap});

  final ProductSearchResult product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing,
          vertical: AppTheme.spacingSmall,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selectedSurfaceOf(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.barcode != null)
                    Text(product.barcode!, style: context.styles.barcode),
                ],
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${product.price}', style: AppTextStyles.priceItem),
                if (product.stock != null)
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.remainingStock(product.stock.toString()),
                    style: context.styles.caption.copyWith(
                      color: product.stock! > Decimal.zero
                          ? AppColors.success
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
