library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/presentation/controllers/refund/refund_controller.dart';

import '../helpers/helpers.dart';
import 'test_utils.dart';

void main() {
  group('Refund Cycle Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = createTestContainer();
    });

    tearDown(() {
      container.dispose();
      tearDownTestDependencies();
    });

    test('complete refund cycle - by receipt', () async {
      final refundNotifier = container.read(refundControllerProvider.notifier);

      refundNotifier.setMode(RefundMode.byReceipt);
      var refundState = container.read(refundControllerProvider);
      expect(refundState.mode, equals(RefundMode.byReceipt));

      await refundNotifier.loadReceipt(12345, 1);
      refundState = container.read(refundControllerProvider);

      expect(refundState.receiptInfo, isNotNull);
      expect(refundState.receiptInfo?.receiptNo, equals(12345));
      expect(refundState.items, isNotEmpty);

      expect(refundState.allSelected, isTrue);
      expect(refundState.canRefund, isTrue);

      final refundTotal = refundState.selectedTotal;
      expect(refundTotal, greaterThan(Decimal.zero));

      final result = await refundNotifier.processRefund();
      expect(result, isTrue);

      refundNotifier.clear();
      refundState = container.read(refundControllerProvider);
      expect(refundState.items, isEmpty);
    });

    test('partial refund - select specific items', () async {
      final refundNotifier = container.read(refundControllerProvider.notifier);

      await refundNotifier.loadReceipt(12345, 1);
      var refundState = container.read(refundControllerProvider);

      refundNotifier.deselectAll();
      refundState = container.read(refundControllerProvider);
      expect(refundState.noneSelected, isTrue);
      expect(refundState.canRefund, isFalse);

      if (refundState.items.isNotEmpty) {
        refundNotifier.toggleItemSelection(refundState.items.first.id);
        refundState = container.read(refundControllerProvider);

        expect(refundState.selectedCount, equals(1));
        expect(refundState.canRefund, isTrue);
        expect(refundState.selectedTotal, lessThan(refundState.total));
      }
    });

    test('refund with quantity adjustment', () async {
      final refundNotifier = container.read(refundControllerProvider.notifier);

      await refundNotifier.loadReceipt(12345, 1);
      var refundState = container.read(refundControllerProvider);

      if (refundState.items.isNotEmpty) {
        final firstItem = refundState.items.first;
        final originalQuantity = firstItem.quantity;
        final originalTotal = refundState.selectedTotal;

        if (originalQuantity > Decimal.one) {
          refundNotifier.updateQuantity(firstItem.id, Decimal.one);
          refundState = container.read(refundControllerProvider);

          final updatedItem = refundState.items.first;
          expect(updatedItem.quantity, equals(Decimal.one));
          expect(refundState.selectedTotal, lessThan(originalTotal));
        }
      }
    });

    test('refund without receipt - manual entry', () async {
      final refundNotifier = container.read(refundControllerProvider.notifier);

      refundNotifier.setMode(RefundMode.withoutReceipt);
      var refundState = container.read(refundControllerProvider);
      expect(refundState.mode, equals(RefundMode.withoutReceipt));

      await refundNotifier.search('Молоко');
      await Future.delayed(const Duration(milliseconds: 500));
      refundState = container.read(refundControllerProvider);
      expect(refundState.searchResults, isNotEmpty);

      refundNotifier.addProduct(refundState.searchResults.first);
      refundState = container.read(refundControllerProvider);
      expect(refundState.items.length, equals(1));
      expect(refundState.items.first.isSelected, isTrue);

      await refundNotifier.search('Хлеб');
      await Future.delayed(const Duration(milliseconds: 500));
      refundState = container.read(refundControllerProvider);
      if (refundState.searchResults.isNotEmpty) {
        refundNotifier.addProduct(refundState.searchResults.first);
        refundState = container.read(refundControllerProvider);
        expect(refundState.items.length, equals(2));
      }

      expect(refundState.canRefund, isTrue);
      final result = await refundNotifier.processRefund();
      expect(result, isTrue);
    });

    test('set refund reason', () async {
      final refundNotifier = container.read(refundControllerProvider.notifier);

      await refundNotifier.loadReceipt(12345, 1);
      var refundState = container.read(refundControllerProvider);

      if (refundState.items.isNotEmpty) {
        final firstItem = refundState.items.first;

        refundNotifier.setReason(firstItem.id, RefundReason.defective);
        refundState = container.read(refundControllerProvider);

        final updatedItem = refundState.items.first;
        expect(updatedItem.reason, equals(RefundReason.defective));
      }
    });

    test('remove item from refund', () async {
      final refundNotifier = container.read(refundControllerProvider.notifier);

      await refundNotifier.loadReceipt(12345, 1);
      var refundState = container.read(refundControllerProvider);
      final initialCount = refundState.items.length;

      if (refundState.items.isNotEmpty) {
        final firstItemId = refundState.items.first.id;

        refundNotifier.removeItem(firstItemId);
        refundState = container.read(refundControllerProvider);

        expect(refundState.items.length, equals(initialCount - 1));
      }
    });

    test('select all / deselect all', () async {
      final refundNotifier = container.read(refundControllerProvider.notifier);

      await refundNotifier.loadReceipt(12345, 1);
      var refundState = container.read(refundControllerProvider);

      expect(refundState.allSelected, isTrue);

      refundNotifier.deselectAll();
      refundState = container.read(refundControllerProvider);
      expect(refundState.noneSelected, isTrue);
      expect(refundState.selectedTotal, equals(Decimal.zero));

      refundNotifier.selectAll();
      refundState = container.read(refundControllerProvider);
      expect(refundState.allSelected, isTrue);
      expect(refundState.selectedTotal, greaterThan(Decimal.zero));
    });

    test('quantity cannot exceed max from receipt', () async {
      final refundNotifier = container.read(refundControllerProvider.notifier);

      await refundNotifier.loadReceipt(12345, 1);
      var refundState = container.read(refundControllerProvider);

      if (refundState.items.isNotEmpty) {
        final firstItem = refundState.items.first;
        final maxQuantity = firstItem.maxQuantity;

        refundNotifier.updateQuantity(
          firstItem.id,
          maxQuantity + Decimal.fromInt(10),
        );
        refundState = container.read(refundControllerProvider);

        final updatedItem = refundState.items.first;
        expect(updatedItem.quantity, equals(maxQuantity));
      }
    });

    test('removing quantity to zero removes item', () async {
      final refundNotifier = container.read(refundControllerProvider.notifier);

      await refundNotifier.loadReceipt(12345, 1);
      var refundState = container.read(refundControllerProvider);
      final initialCount = refundState.items.length;

      if (refundState.items.isNotEmpty) {
        final firstItemId = refundState.items.first.id;

        refundNotifier.updateQuantity(firstItemId, Decimal.zero);
        refundState = container.read(refundControllerProvider);

        expect(refundState.items.length, equals(initialCount - 1));
      }
    });

    testWidgets('refund screen UI flow', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const TestApp(child: Scaffold(body: _TestRefundFlow())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Введите номер чека'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('receipt_input')), '12345');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('search_receipt_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsWidgets);

      expect(find.byKey(const Key('refund_btn')), findsOneWidget);
    });
  });
}

class _TestRefundFlow extends ConsumerStatefulWidget {
  const _TestRefundFlow();

  @override
  ConsumerState<_TestRefundFlow> createState() => _TestRefundFlowState();
}

class _TestRefundFlowState extends ConsumerState<_TestRefundFlow> {
  final _receiptController = TextEditingController();

  @override
  void dispose() {
    _receiptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(refundControllerProvider);
    final notifier = ref.read(refundControllerProvider.notifier);

    return Column(
      children: [
        if (state.items.isEmpty) ...[
          const Text('Введите номер чека'),
          TextField(
            key: const Key('receipt_input'),
            controller: _receiptController,
            keyboardType: TextInputType.number,
          ),
          ElevatedButton(
            key: const Key('search_receipt_btn'),
            onPressed: () async {
              final receiptNo = int.tryParse(_receiptController.text);
              if (receiptNo != null) {
                await notifier.loadReceipt(receiptNo, 1);
              }
            },
            child: const Text('Найти чек'),
          ),
        ] else ...[
          Expanded(
            child: ListView.builder(
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final item = state.items[index];
                return ListTile(
                  leading: Checkbox(
                    value: item.isSelected,
                    onChanged: (_) => notifier.toggleItemSelection(item.id),
                  ),
                  title: Text(item.name),
                  subtitle: Text('${item.quantity} x ${item.price}'),
                  trailing: Text(item.total.toString()),
                );
              },
            ),
          ),
          Text('Итого: ${state.selectedTotal}'),
          ElevatedButton(
            key: const Key('refund_btn'),
            onPressed: state.canRefund ? () => notifier.processRefund() : null,
            child: const Text('Оформить возврат'),
          ),
        ],
      ],
    );
  }
}
