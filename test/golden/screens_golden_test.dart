@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';
import 'package:telepos/app/theme/telepos_icons.dart';

void main() {
  group('Golden Tests - Login Screen', () {
    testWidgets('login screen - mobile', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        const _MockLoginScreen(),
        'login_screen',
      );
    });

    testWidgets('login screen - tablet', (tester) async {
      await GoldenTestHelpers.matchGoldenTablet(
        tester,
        const _MockLoginScreen(),
        'login_screen',
      );
    });

    testWidgets('login screen - desktop', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        const _MockLoginScreen(),
        'login_screen',
      );
    });
  });

  group('Golden Tests - Sale Screen', () {
    testWidgets('sale screen empty - mobile', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        const _MockSaleScreen(isEmpty: true),
        'sale_screen_empty',
      );
    });

    testWidgets('sale screen empty - tablet', (tester) async {
      await GoldenTestHelpers.matchGoldenTablet(
        tester,
        const _MockSaleScreen(isEmpty: true),
        'sale_screen_empty',
      );
    });

    testWidgets('sale screen empty - desktop', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        const _MockSaleScreen(isEmpty: true),
        'sale_screen_empty',
      );
    });

    testWidgets('sale screen with items - mobile', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        const _MockSaleScreen(isEmpty: false),
        'sale_screen_items',
      );
    });

    testWidgets('sale screen with items - tablet', (tester) async {
      await GoldenTestHelpers.matchGoldenTablet(
        tester,
        const _MockSaleScreen(isEmpty: false),
        'sale_screen_items',
      );
    });

    testWidgets('sale screen with items - desktop', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        const _MockSaleScreen(isEmpty: false),
        'sale_screen_items',
      );
    });
  });

  group('Golden Tests - Payment Screen', () {
    testWidgets('payment screen cash - mobile', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        const _MockPaymentScreen(paymentType: 'cash'),
        'payment_screen_cash',
      );
    });

    testWidgets('payment screen cash - tablet', (tester) async {
      await GoldenTestHelpers.matchGoldenTablet(
        tester,
        const _MockPaymentScreen(paymentType: 'cash'),
        'payment_screen_cash',
      );
    });

    testWidgets('payment screen cash - desktop', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        const _MockPaymentScreen(paymentType: 'cash'),
        'payment_screen_cash',
      );
    });

    testWidgets('payment screen card - mobile', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        const _MockPaymentScreen(paymentType: 'card'),
        'payment_screen_card',
      );
    });

    testWidgets('payment screen card - desktop', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        const _MockPaymentScreen(paymentType: 'card'),
        'payment_screen_card',
      );
    });
  });

  group('Golden Tests - Refund Screen', () {
    testWidgets('refund screen search - mobile', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        const _MockRefundScreen(hasItems: false),
        'refund_screen_search',
      );
    });

    testWidgets('refund screen search - tablet', (tester) async {
      await GoldenTestHelpers.matchGoldenTablet(
        tester,
        const _MockRefundScreen(hasItems: false),
        'refund_screen_search',
      );
    });

    testWidgets('refund screen search - desktop', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        const _MockRefundScreen(hasItems: false),
        'refund_screen_search',
      );
    });

    testWidgets('refund screen with items - mobile', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        const _MockRefundScreen(hasItems: true),
        'refund_screen_items',
      );
    });

    testWidgets('refund screen with items - tablet', (tester) async {
      await GoldenTestHelpers.matchGoldenTablet(
        tester,
        const _MockRefundScreen(hasItems: true),
        'refund_screen_items',
      );
    });

    testWidgets('refund screen with items - desktop', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        const _MockRefundScreen(hasItems: true),
        'refund_screen_items',
      );
    });
  });

  group('Golden Tests - Shift Screen', () {
    testWidgets('shift screen closed - mobile', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        const _MockShiftScreen(isOpen: false),
        'shift_screen_closed',
      );
    });

    testWidgets('shift screen closed - tablet', (tester) async {
      await GoldenTestHelpers.matchGoldenTablet(
        tester,
        const _MockShiftScreen(isOpen: false),
        'shift_screen_closed',
      );
    });

    testWidgets('shift screen closed - desktop', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        const _MockShiftScreen(isOpen: false),
        'shift_screen_closed',
      );
    });

    testWidgets('shift screen open - mobile', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        const _MockShiftScreen(isOpen: true),
        'shift_screen_open',
      );
    });

    testWidgets('shift screen open - tablet', (tester) async {
      await GoldenTestHelpers.matchGoldenTablet(
        tester,
        const _MockShiftScreen(isOpen: true),
        'shift_screen_open',
      );
    });

    testWidgets('shift screen open - desktop', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        const _MockShiftScreen(isOpen: true),
        'shift_screen_open',
      );
    });
  });

  group('Golden Tests - History Screen', () {
    testWidgets('history screen empty - mobile', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        const _MockHistoryScreen(isEmpty: true),
        'history_screen_empty',
      );
    });

    testWidgets('history screen empty - tablet', (tester) async {
      await GoldenTestHelpers.matchGoldenTablet(
        tester,
        const _MockHistoryScreen(isEmpty: true),
        'history_screen_empty',
      );
    });

    testWidgets('history screen empty - desktop', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        const _MockHistoryScreen(isEmpty: true),
        'history_screen_empty',
      );
    });

    testWidgets('history screen with data - mobile', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        const _MockHistoryScreen(isEmpty: false),
        'history_screen_data',
      );
    });

    testWidgets('history screen with data - tablet', (tester) async {
      await GoldenTestHelpers.matchGoldenTablet(
        tester,
        const _MockHistoryScreen(isEmpty: false),
        'history_screen_data',
      );
    });

    testWidgets('history screen with data - desktop', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        const _MockHistoryScreen(isEmpty: false),
        'history_screen_data',
      );
    });
  });
}

class _MockLoginScreen extends StatelessWidget {
  const _MockLoginScreen();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isWide ? 800 : double.infinity,
              maxHeight: isWide ? 500 : double.infinity,
            ),
            margin: EdgeInsets.all(isWide ? 32 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isWide
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildUserList(),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPinDisplay(),
                const SizedBox(height: 24),
                _buildNumpad(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildUserList(),
                const SizedBox(height: 16),
                _buildPinDisplay(),
              ],
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(8),
          child: _buildNumpad(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.point_of_sale, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TelePOS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text('Вход в систему', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildUserList() {
    return Column(
      children: [
        _buildUserTile('Иванов И.И.', true),
        _buildUserTile('Петров П.П.', false),
        _buildUserTile('Сидоров С.С.', false),
      ],
    );
  }

  Widget _buildUserTile(String name, bool selected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Colors.blue : Colors.grey.shade300,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: selected ? Colors.blue : Colors.grey,
          child: Text(name[0], style: const TextStyle(color: Colors.white)),
        ),
        title: Text(name),
        trailing: selected
            ? const Icon(TeleposIcons.checkCircle, color: Colors.blue)
            : null,
      ),
    );
  }

  Widget _buildPinDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final filled = index < 2;
        return Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.blue : Colors.transparent,
            border: Border.all(color: Colors.blue, width: 2),
          ),
        );
      }),
    );
  }

  Widget _buildNumpad() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      childAspectRatio: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 1; i <= 9; i++) _buildNumpadKey('$i'),
        _buildNumpadKey('C', color: Colors.orange),
        _buildNumpadKey('0'),
        _buildNumpadKey('⌫', color: Colors.red),
      ],
    );
  }

  Widget _buildNumpadKey(String label, {Color? color}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black,
          ),
        ),
      ),
    );
  }
}

class _MockSaleScreen extends StatelessWidget {
  const _MockSaleScreen({required this.isEmpty});

  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1200;
    final isTablet = width >= 600 && width < 1200;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Продажа'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isDesktop
          ? _buildDesktopLayout()
          : isTablet
          ? _buildTabletLayout()
          : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _buildSearchBar(),
                const SizedBox(height: 16),
                Expanded(child: _buildItemsTable()),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(child: _buildActionButtons()),
                const SizedBox(height: 16),
                _buildTotalPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 65,
            child: Column(
              children: [
                _buildSearchBar(),
                const SizedBox(height: 16),
                Expanded(child: _buildItemsTable()),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 35,
            child: Column(
              children: [
                _buildTotalPanel(),
                const SizedBox(height: 16),
                Expanded(child: _buildActionButtons()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(16), child: _buildSearchBar()),
        Expanded(child: isEmpty ? _buildEmptyState() : _buildItemsList()),
        _buildMobileTotalPanel(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Поиск товара...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: const Icon(Icons.qr_code_scanner),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildItemsTable() {
    if (isEmpty) return _buildEmptyState();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Товар',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Кол-во',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Цена',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Сумма',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildTableRow('Молоко 1л', '2', '450', '900', true),
                _buildTableRow('Хлеб белый', '1', '180', '180', false),
                _buildTableRow('Сахар 1кг', '3', '520', '1560', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    String name,
    String qty,
    String price,
    String total,
    bool selected,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(name)),
          Expanded(child: Text(qty, textAlign: TextAlign.center)),
          Expanded(child: Text(price)),
          Expanded(
            child: Text(
              total,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView(
      children: [
        _buildListItem('Молоко 1л', '2 x 450', '900', true),
        _buildListItem('Хлеб белый', '1 x 180', '180', false),
        _buildListItem('Сахар 1кг', '3 x 520', '1560', false),
      ],
    );
  }

  Widget _buildListItem(
    String name,
    String details,
    String total,
    bool selected,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? Colors.blue.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: selected ? Border.all(color: Colors.blue) : null,
      ),
      child: ListTile(
        title: Text(name),
        subtitle: Text(details),
        trailing: Text(
          '$total ₸',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Корзина пуста',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте товары для продажи',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      children: [
        _buildActionButton(Icons.grid_view, 'Товары'),
        _buildActionButton(Icons.numbers, 'Кол-во'),
        _buildActionButton(Icons.edit, 'Редакт.'),
        _buildActionButton(Icons.pause, 'Отложить'),
        _buildActionButton(Icons.qr_code, 'Маркировка'),
        _buildActionButton(Icons.percent, 'Скидка'),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTotalPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildTotalRow('Подитого', '2640'),
          _buildTotalRow('Скидка', '0'),
          const Divider(),
          _buildTotalRow('ИТОГО', '2640', isTotal: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isEmpty ? null : () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'К ОПЛАТЕ',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTotalPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ИТОГО', style: TextStyle(color: Colors.grey)),
                Text(
                  isEmpty ? '0 ₸' : '2640 ₸',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isEmpty ? null : () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'К ОПЛАТЕ',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 18 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$value ₸',
            style: TextStyle(
              fontSize: isTotal ? 24 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockPaymentScreen extends StatelessWidget {
  const _MockPaymentScreen({required this.paymentType});

  final String paymentType;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1200;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Оплата'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _buildPaymentTypeSelector(),
                const SizedBox(height: 16),
                Expanded(child: _buildDenominationGrid()),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildAmountPanel(),
                const SizedBox(height: 16),
                Expanded(child: _buildNumpad()),
                const SizedBox(height: 16),
                _buildConfirmButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildPaymentTypeSelector(),
        ),
        _buildAmountPanel(),
        const Divider(),
        if (paymentType == 'cash')
          Expanded(child: _buildDenominationGrid())
        else
          Expanded(child: _buildCardPaymentInfo()),
        _buildConfirmButton(),
      ],
    );
  }

  Widget _buildPaymentTypeSelector() {
    return Row(
      children: [
        _buildPaymentTypeButton(
          'Наличные',
          Icons.payments,
          paymentType == 'cash',
        ),
        const SizedBox(width: 8),
        _buildPaymentTypeButton(
          'Карта',
          Icons.credit_card,
          paymentType == 'card',
        ),
        const SizedBox(width: 8),
        _buildPaymentTypeButton(
          'Смешанная',
          Icons.sync_alt,
          paymentType == 'mixed',
        ),
      ],
    );
  }

  Widget _buildPaymentTypeButton(String label, IconData icon, bool selected) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildAmountRow('К оплате', '2640'),
          _buildAmountRow('Получено', paymentType == 'cash' ? '3000' : '2640'),
          const Divider(),
          _buildAmountRow(
            'Сдача',
            paymentType == 'cash' ? '360' : '0',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? Colors.green : Colors.black,
            ),
          ),
          Text(
            '$value ₸',
            style: TextStyle(
              fontSize: isTotal ? 24 : 18,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDenominationGrid() {
    final denominations = [200, 500, 1000, 2000, 5000, 10000, 20000];

    return GridView.count(
      crossAxisCount: 4,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: denominations.map((d) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              '$d',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCardPaymentInfo() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.credit_card, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Приложите карту к терминалу',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'или вставьте в слот',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        shrinkWrap: true,
        children: [
          for (var i = 1; i <= 9; i++) _buildNumpadKey('$i'),
          _buildNumpadKey('C'),
          _buildNumpadKey('0'),
          _buildNumpadKey('⌫'),
        ],
      ),
    );
  }

  Widget _buildNumpadKey(String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'ОПЛАТИТЬ',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _MockRefundScreen extends StatelessWidget {
  const _MockRefundScreen({required this.hasItems});

  final bool hasItems;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1200;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Возврат'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _buildModeSelector(),
                const SizedBox(height: 16),
                if (!hasItems) _buildReceiptSearch(),
                if (hasItems) Expanded(child: _buildItemsTable()),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                if (hasItems) _buildReceiptInfo(),
                const Spacer(),
                _buildTotalPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(16), child: _buildModeSelector()),
        if (!hasItems)
          Expanded(child: _buildReceiptSearch())
        else ...[
          _buildReceiptInfo(),
          Expanded(child: _buildItemsList()),
        ],
        _buildTotalPanel(),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt, color: Colors.white, size: 20),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'По чеку',
                    style: TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit, color: Colors.grey, size: 20),
                SizedBox(width: 4),
                Flexible(
                  child: Text('Без чека', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptSearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Введите номер чека', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: TextField(
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '000000',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.search),
            label: const Text('Найти'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Чек #12345',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Касса-1 • 09.02.2026 14:30',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView(
        children: [
          _buildRefundItem('Молоко 1л', '2 x 450', '900', true),
          _buildRefundItem('Хлеб белый', '1 x 180', '180', true),
          _buildRefundItem('Сахар 1кг', '1 x 420', '420', false),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildRefundItem('Молоко 1л', '2 x 450', '900', true),
        _buildRefundItem('Хлеб белый', '1 x 180', '180', true),
        _buildRefundItem('Сахар 1кг', '1 x 420', '420', false),
      ],
    );
  }

  Widget _buildRefundItem(
    String name,
    String details,
    String total,
    bool selected,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.orange.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Colors.orange : Colors.grey.shade300,
        ),
      ),
      child: ListTile(
        leading: Checkbox(
          value: selected,
          activeColor: Colors.orange,
          onChanged: (_) {},
        ),
        title: Text(name),
        subtitle: Text(details),
        trailing: Text(
          '$total ₸',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTotalPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text('К возврату', overflow: TextOverflow.ellipsis),
              ),
              Text(
                hasItems ? '1080 ₸' : '0 ₸',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: hasItems ? () {} : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text(
                'ОФОРМИТЬ ВОЗВРАТ',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockShiftScreen extends StatelessWidget {
  const _MockShiftScreen({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final isTablet = width >= 600 && width < 900;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(isOpen ? 'Закрытие смены' : 'Открытие смены'),
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
      body: isDesktop
          ? _buildDesktopLayout()
          : isTablet
          ? _buildTabletLayout()
          : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildTabBar(),
              Expanded(child: _buildBillsTab()),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 320,
          child: Column(
            children: [
              Expanded(child: _buildInfoPanel()),
              const Divider(height: 1),
              _buildActions(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      children: [
        _buildTabBar(),
        Expanded(child: _buildBillsTab()),
        _buildCompactInfo(),
        _buildActions(),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatusCard(),
          if (isOpen) ...[const SizedBox(height: 16), _buildBillsCard()],
          const SizedBox(height: 16),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: const Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Купюры'),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calculate, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Сумма', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Операции', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBillRow(20000, 0),
          _buildBillRow(10000, 1),
          _buildBillRow(5000, 2),
          _buildBillRow(2000, 0),
          _buildBillRow(1000, 5),
          _buildBillRow(500, 4),
          _buildBillRow(200, 10),
        ],
      ),
    );
  }

  Widget _buildBillRow(int denomination, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$denomination ₸',
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () {},
            iconSize: 20,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(TeleposIcons.add),
            onPressed: () {},
            iconSize: 20,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${denomination * count} ₸',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOpen
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  isOpen ? Icons.lock_open : Icons.lock,
                  color: isOpen ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOpen ? 'Смена открыта' : 'Смена закрыта',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isOpen)
                      const Text(
                        'с 09:00 09.02.2026',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (isOpen) ...[
            const SizedBox(height: 24),
            _buildInfoRow('Кассир', 'Иванов И.И.'),
            _buildInfoRow('По системе', '25000 ₸'),
            _buildInfoRow('Введено', '27000 ₸'),
            const Divider(),
            _buildInfoRow('Разница', '+2000 ₸', isPositive: true),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPositive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isOpen ? Icons.lock_open : Icons.lock,
                color: isOpen ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(isOpen ? 'Смена открыта' : 'Смена закрыта'),
            ],
          ),
          if (isOpen)
            const Text(
              'Разница: +2000 ₸',
              style: TextStyle(color: Colors.green),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    isOpen ? Icons.lock_open : Icons.lock,
                    color: isOpen ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOpen ? 'Смена открыта' : 'Смена закрыта',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isOpen)
                        const Text(
                          'с 09:00 09.02.2026',
                          style: TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillsCard() {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.payments, color: Colors.purple),
        title: const Text('Пересчёт по купюрам'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildBillRow(10000, 2),
                _buildBillRow(5000, 1),
                _buildBillRow(1000, 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (isOpen) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.print),
                label: const Text('X-отчёт'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.lock),
                label: const Text('Закрыть смену'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.lock_open),
                label: const Text('Открыть смену'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
        ],
      ),
    );
  }
}

class _MockHistoryScreen extends StatelessWidget {
  const _MockHistoryScreen({required this.isEmpty});

  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1200;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('История'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        _buildFilters(),
        Expanded(child: isEmpty ? _buildEmptyState() : _buildTable()),
        _buildPagination(),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildFilters(),
        Expanded(child: isEmpty ? _buildEmptyState() : _buildList()),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.calendar_today, size: 20),
                SizedBox(width: 8),
                Text('09.02.2026'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    '№',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Дата/Время',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Тип',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Сумма',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Оплата',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildTableRow(
                  '12345',
                  '09.02 14:30',
                  'Продажа',
                  '2640',
                  'Наличные',
                ),
                _buildTableRow(
                  '12344',
                  '09.02 13:15',
                  'Продажа',
                  '1580',
                  'Карта',
                ),
                _buildTableRow(
                  '12343',
                  '09.02 11:45',
                  'Возврат',
                  '-450',
                  'Наличные',
                ),
                _buildTableRow(
                  '12342',
                  '09.02 10:30',
                  'Продажа',
                  '3200',
                  'Смешанная',
                ),
                _buildTableRow(
                  '12341',
                  '09.02 09:15',
                  'Продажа',
                  '890',
                  'Наличные',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    String no,
    String date,
    String type,
    String amount,
    String payment,
  ) {
    final isRefund = type == 'Возврат';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(no)),
          Expanded(child: Text(date)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isRefund
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: isRefund ? Colors.orange : Colors.green,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$amount ₸',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isRefund ? Colors.orange : Colors.black,
              ),
            ),
          ),
          Expanded(child: Text(payment)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildListItem('12345', '09.02 14:30', 'Продажа', '2640', 'Наличные'),
        _buildListItem('12344', '09.02 13:15', 'Продажа', '1580', 'Карта'),
        _buildListItem('12343', '09.02 11:45', 'Возврат', '-450', 'Наличные'),
        _buildListItem('12342', '09.02 10:30', 'Продажа', '3200', 'Смешанная'),
        _buildListItem('12341', '09.02 09:15', 'Продажа', '890', 'Наличные'),
      ],
    );
  }

  Widget _buildListItem(
    String no,
    String date,
    String type,
    String amount,
    String payment,
  ) {
    final isRefund = type == 'Возврат';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isRefund
                ? Colors.orange.withValues(alpha: 0.1)
                : Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isRefund ? Icons.undo : Icons.shopping_cart,
            color: isRefund ? Colors.orange : Colors.green,
          ),
        ),
        title: Text('Чек #$no'),
        subtitle: Text('$date • $payment'),
        trailing: Text(
          '$amount ₸',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isRefund ? Colors.orange : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'История пуста',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Здесь будут отображаться продажи и возвраты',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {}),
          const Text('Страница 1 из 10'),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {}),
        ],
      ),
    );
  }
}
