import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/customer_display/customer_display_data.dart';

final storeNameProvider = FutureProvider<String>((ref) async {
  try {
    final pos = await GetIt.I<AppDatabase>().thisPosDao.get();
    final name = pos?.companyName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
  } catch (_) {}
  return 'TelePOS';
});

CustomerDisplayData customerDataFromSale(SaleState state) =>
    CustomerDisplayData(
      lines: state.items
          .map(
            (it) => CustomerDisplayLine(
              name: it.name,
              quantity: it.quantity,
              total: it.total,
              discount: it.discount,
            ),
          )
          .toList(),
      subtotal: state.subtotal,
      totalDiscount: state.totalDiscount,
      total: state.total,
    );

class CustomerDisplayScreen extends ConsumerWidget {
  const CustomerDisplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleControllerProvider);
    final storeName = ref.watch(storeNameProvider).asData?.value ?? 'TelePOS';
    return CustomerDisplayView(
      data: customerDataFromSale(state),
      storeName: storeName,
    );
  }
}

class CustomerDisplayView extends StatelessWidget {
  const CustomerDisplayView({
    required this.data,
    required this.storeName,
    super.key,
  });

  final CustomerDisplayData data;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final hasItems = !data.isEmpty;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E3B36), Color(0xFF14524A), Color(0xFF1ABC9C)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(storeName: storeName),
              Expanded(child: hasItems ? _Cart(data: data) : const _Welcome()),
              if (hasItems) _TotalBar(data: data),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.storeName});
  final String storeName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              storeName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: Colors.white,
              size: 64,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Добро пожаловать!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Мы рады видеть вас',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cart extends StatelessWidget {
  const _Cart({required this.data});
  final CustomerDisplayData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Expanded(flex: 5, child: Text('Товар', style: _th())),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Кол-во',
                    style: _th(),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Сумма',
                    style: _th(),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: data.lines.length,
              separatorBuilder: (_, __) => Divider(
                color: Colors.white.withValues(alpha: 0.08),
                height: 1,
              ),
              itemBuilder: (context, i) => _CartRow(line: data.lines[i]),
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle _th() => TextStyle(
    color: Colors.white.withValues(alpha: 0.7),
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}

class _CartRow extends StatelessWidget {
  const _CartRow({required this.line});
  final CustomerDisplayLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (line.discount > Decimal.zero)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line.isFree
                          ? 'Акция · бесплатно'
                          : 'Скидка −${line.discount} ₸',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${line.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${line.total} ₸',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.data});
  final CustomerDisplayData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (data.totalDiscount > Decimal.zero) ...[
            _line(
              'Сумма',
              '${data.subtotal} ₸',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            _line(
              'Скидка',
              '−${data.totalDiscount} ₸',
              color: Theme.of(context).colorScheme.error,
            ),
            const Divider(height: 20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ИТОГО',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${data.total} ₸',
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {required Color color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: color)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
