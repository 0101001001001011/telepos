import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/keyboards/num_pad.dart';

class ReceiptInputResult {
  const ReceiptInputResult({required this.receiptNo, required this.posId});

  final int receiptNo;
  final int posId;
}

class ReceiptInputDialog extends StatefulWidget {
  const ReceiptInputDialog({
    this.availablePosIds = const [1],
    this.posNames = const {1: 'Касса-1'},
    super.key,
  });

  final List<int> availablePosIds;
  final Map<int, String> posNames;

  static Future<ReceiptInputResult?> show(
    BuildContext context, {
    List<int> availablePosIds = const [1],
    Map<int, String> posNames = const {1: 'Касса-1'},
  }) {
    return showDialog<ReceiptInputResult>(
      context: context,
      builder: (context) => ReceiptInputDialog(
        availablePosIds: availablePosIds,
        posNames: posNames,
      ),
    );
  }

  @override
  State<ReceiptInputDialog> createState() => _ReceiptInputDialogState();
}

class _ReceiptInputDialogState extends State<ReceiptInputDialog> {
  final _receiptController = TextEditingController();
  late int _selectedPosId;
  String? _error;
  List<Sale> _recent = const [];
  bool _loadingRecent = true;

  @override
  void initState() {
    super.initState();
    _selectedPosId = widget.availablePosIds.first;
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final recent = await db.saleDao.findRecentCompleted(limit: 30);
      if (mounted)
        setState(() {
          _recent = recent;
          _loadingRecent = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  String _fmtTime(int unixSec) {
    final dt = DateTime.fromMillisecondsSinceEpoch(unixSec * 1000);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  void dispose() {
    _receiptController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final receiptNo = int.tryParse(_receiptController.text);
    if (receiptNo == null || receiptNo <= 0) {
      setState(() {
        _error = l10n.receiptInputInvalid;
      });
      return;
    }

    Navigator.of(
      context,
    ).pop(ReceiptInputResult(receiptNo: receiptNo, posId: _selectedPosId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long, color: AppColors.warning),
          const SizedBox(width: 12),
          Text(l10n.receiptInputTitle),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _receiptController,
                readOnly: true,
                showCursor: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.receiptInputNumber,
                  hintText: l10n.receiptInputNumberHint,
                  prefixIcon: const Icon(Icons.tag),
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              NumPad(
                buttonSize: 48,
                spacing: 6,
                onKeyPressed: (d) {
                  _receiptController.text += d;
                  if (_error != null) setState(() => _error = null);
                },
                onBackspace: () {
                  final t = _receiptController.text;
                  if (t.isNotEmpty) {
                    _receiptController.text = t.substring(0, t.length - 1);
                  }
                },
                onClear: () => _receiptController.clear(),
                onEnter: _submit,
              ),

              const SizedBox(height: AppTheme.spacing),
              Text(l10n.receiptInputRecent, style: context.styles.caption),
              const SizedBox(height: AppTheme.spacingSmall),
              SizedBox(
                width: 360,
                height: math.min(
                  180.0,
                  MediaQuery.sizeOf(context).height * 0.3,
                ),
                child: _loadingRecent
                    ? const Center(child: CircularProgressIndicator())
                    : _recent.isEmpty
                    ? Center(
                        child: Text(
                          l10n.receiptInputNoRecent,
                          style: context.styles.caption,
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _recent.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = _recent[i];
                          return ListTile(
                            leading: const Icon(
                              Icons.receipt_long_outlined,
                              color: AppColors.warning,
                            ),
                            title: Text('№ ${s.receiptNo}'),
                            subtitle: Text(_fmtTime(s.time)),
                            trailing: Text(
                              '${s.amount} ₸',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(
                              ReceiptInputResult(
                                receiptNo: s.receiptNo,
                                posId: s.posId,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              if (widget.availablePosIds.length > 1) ...[
                const SizedBox(height: AppTheme.spacing),
                Text(l10n.receiptInputPos, style: context.styles.caption),
                const SizedBox(height: AppTheme.spacingSmall),
                Wrap(
                  spacing: AppTheme.spacingSmall,
                  children: widget.availablePosIds.map((posId) {
                    final isSelected = posId == _selectedPosId;
                    return ChoiceChip(
                      label: Text(widget.posNames[posId] ?? 'POS-$posId'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedPosId = posId;
                          });
                        }
                      },
                      selectedColor: AppColors.warning,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.black
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.search),
          label: Text(l10n.receiptInputFind),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: AppColors.black,
          ),
        ),
      ],
    );
  }
}
