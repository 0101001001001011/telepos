@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';
import 'package:telepos/app/theme/telepos_icons.dart';

const _blue = Color(0xFF1E88E5);
const _bg = Color(0xFFF4F6F8);

void main() {
  group('Product Doc Goldens (desktop)', () {
    testWidgets('main menu', (t) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        t,
        const _MainMenuMock(),
        'doc_main_menu',
      );
    });
    testWidgets('catalog', (t) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        t,
        const _CatalogMock(),
        'doc_catalog',
      );
    });
    testWidgets('restaurant tables', (t) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        t,
        const _RestaurantTablesMock(),
        'doc_restaurant_tables',
      );
    });
    testWidgets('wms dashboard', (t) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        t,
        const _WmsDashboardMock(),
        'doc_wms_dashboard',
      );
    });
    testWidgets('service queue', (t) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        t,
        const _ServiceQueueMock(),
        'doc_service_queue',
      );
    });
    testWidgets('reports', (t) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        t,
        const _ReportsMock(),
        'doc_reports',
      );
    });
    testWidgets('fiscal settings', (t) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        t,
        const _FiscalSettingsMock(),
        'doc_fiscal_settings',
      );
    });
    testWidgets('cash operations', (t) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        t,
        const _CashOpsMock(),
        'doc_cash_ops',
      );
    });
    testWidgets('customers', (t) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        t,
        const _CustomersMock(),
        'doc_customers',
      );
    });
    testWidgets('supply', (t) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        t,
        const _SupplyMock(),
        'doc_supply',
      );
    });
    testWidgets('users', (t) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        t,
        const _UsersMock(),
        'doc_users',
      );
    });
    testWidgets('inventory', (t) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        t,
        const _InventoryMock(),
        'doc_inventory',
      );
    });
  });
}

class _NavRail extends StatelessWidget {
  const _NavRail({required this.activeLabel});
  final String activeLabel;

  static const _items = <(IconData, String)>[
    (Icons.point_of_sale, 'Продажа'),
    (Icons.assignment_return, 'Возврат'),
    (Icons.lock_clock, 'Смена'),
    (Icons.account_balance_wallet, 'Касса'),
    (Icons.history, 'История'),
    (Icons.inventory_2, 'Каталог'),
    (Icons.bar_chart, 'Отчёты'),
    (Icons.warehouse, 'Склад'),
    (Icons.build, 'Услуги'),
    (Icons.restaurant, 'Ресторан'),
    (Icons.people, 'Клиенты'),
    (Icons.settings, 'Настройки'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      color: const Color(0xFF13294B),
      child: Column(
        children: [
          const SizedBox(height: 18),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          const Text(
            'TelePOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _items.map((e) {
                final active = e.$2 == activeLabel;
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? _blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        e.$1,
                        color: active ? Colors.white : Colors.white60,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainMenuMock extends StatelessWidget {
  const _MainMenuMock();

  static const _tiles = <(IconData, String, String, Color)>[
    (Icons.point_of_sale, 'Продажа', 'Оформить чек', Color(0xFF2E7D32)),
    (Icons.assignment_return, 'Возврат', 'Возврат по чеку', Color(0xFFEF6C00)),
    (Icons.lock_clock, 'Смена', 'Открыта с 09:00', Color(0xFF6A1B9A)),
    (
      Icons.account_balance_wallet,
      'Касса',
      'Внесение / изъятие',
      Color(0xFF00838F),
    ),
    (Icons.inventory_2, 'Каталог', '1 248 товаров', _blue),
    (Icons.local_shipping, 'Поставка', 'Приёмка товара', Color(0xFF5D4037)),
    (Icons.bar_chart, 'Отчёты', 'Выручка и аналитика', Color(0xFF283593)),
    (Icons.warehouse, 'Склад', 'Ячейки, партии', Color(0xFF455A64)),
    (Icons.people, 'Клиенты', 'База и бонусы', Color(0xFFC2185B)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          const _NavRail(activeLabel: 'Продажа'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Главное меню',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      _statusPill(
                        Icons.wifi,
                        'В сети',
                        const Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 10),
                      _statusPill(Icons.lock_clock, 'Смена открыта', _blue),
                      const SizedBox(width: 10),
                      const CircleAvatar(
                        backgroundColor: _blue,
                        child: Text(
                          'ИИ',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Касса-1 · Магазин «Центральный»',
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      childAspectRatio: 2.1,
                      children: _tiles
                          .map((e) => _menuTile(e.$1, e.$2, e.$3, e.$4))
                          .toList(),
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

  Widget _statusPill(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );

  Widget _menuTile(IconData icon, String title, String sub, Color color) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CatalogMock extends StatelessWidget {
  const _CatalogMock();

  static const _cats = [
    'Все товары',
    'Молочные',
    'Хлеб и выпечка',
    'Бакалея',
    'Напитки',
    'Бытовая химия',
  ];
  static const _rows = <(String, String, String, String, String)>[
    (
      'Молоко «Простоквашино» 1 л',
      '4870123456789',
      'Молочные',
      '450 ₸',
      '128 шт',
    ),
    (
      'Хлеб белый нарезной',
      '4870987654321',
      'Хлеб и выпечка',
      '180 ₸',
      '46 шт',
    ),
    ('Сахар-песок 1 кг', '4870112233445', 'Бакалея', '520 ₸', '210 шт'),
    ('Масло сливочное 180 г', '4870555666777', 'Молочные', '890 ₸', '64 шт'),
    ('Вода «Тassay» 0,5 л', '4870888999000', 'Напитки', '160 ₸', '300 шт'),
    ('Чай чёрный 25 пак.', '4870223344556', 'Бакалея', '740 ₸', '88 шт'),
    ('Кофе растворимый 95 г', '4870667788990', 'Напитки', '2 150 ₸', '37 шт'),
    (
      'Печенье овсяное 300 г',
      '4870334455667',
      'Хлеб и выпечка',
      '420 ₸',
      '52 шт',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text('Каталог товаров'),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(TeleposIcons.add),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 230,
            color: Colors.white,
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Категории',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
                ..._cats.asMap().entries.map((e) {
                  final active = e.key == 0;
                  return Container(
                    color: active ? _blue.withValues(alpha: 0.08) : null,
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.folder,
                        color: active ? _blue : Colors.black38,
                        size: 20,
                      ),
                      title: Text(
                        e.value,
                        style: TextStyle(
                          color: active ? _blue : Colors.black87,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Поиск по названию или штрихкоду…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: const Icon(Icons.qr_code_scanner),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF3F7),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Expanded(
                                  flex: 4,
                                  child: Text('Наименование', style: _th),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text('Штрихкод', style: _th),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Категория', style: _th),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Цена', style: _th),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Остаток', style: _th),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(children: _rows.map(_row).toList()),
                          ),
                        ],
                      ),
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

  static const _th = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);

  Widget _row((String, String, String, String, String) r) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFEEEEEF))),
    ),
    child: Row(
      children: [
        Expanded(flex: 4, child: Text(r.$1)),
        Expanded(
          flex: 3,
          child: Text(
            r.$2,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            r.$3,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            r.$4,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            r.$5,
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RestaurantTablesMock extends StatelessWidget {
  const _RestaurantTablesMock();

  static const _tables = <(String, int, int, String, String)>[
    ('1', 4, 1, '25 мин', '8 400 ₸'),
    ('2', 2, 0, '', ''),
    ('3', 6, 1, '1ч 10м', '21 300 ₸'),
    ('4', 4, 2, '', ''),
    ('5', 2, 0, '', ''),
    ('6', 8, 1, '40 мин', '15 750 ₸'),
    ('7', 4, 3, '', ''),
    ('8', 2, 0, '', ''),
    ('9', 4, 1, '12 мин', '4 200 ₸'),
    ('10', 6, 0, '', ''),
  ];

  static const _bgDark = Color(0xFF1A1A2E);
  static const _panel = Color(0xFF16213E);

  Color _statColor(int s) => switch (s) {
    0 => const Color(0xFF43A047),
    1 => const Color(0xFFE53935),
    2 => const Color(0xFFF57C00),
    _ => const Color(0xFF616161),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Column(
        children: [
          Container(
            color: _panel,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.restaurant, color: _blue, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Зал · Основной',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _legend('Свободно', 4, _statColor(0)),
                _legend('Занято', 4, _statColor(1)),
                _legend('Бронь', 1, _statColor(2)),
                _legend('Уборка', 1, _statColor(3)),
              ],
            ),
          ),
          Container(
            color: _bgDark,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _zonePill('Все зоны', true),
                _zonePill('Основной зал', false),
                _zonePill('Терраса', false),
                _zonePill('VIP', false),
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: 5,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.05,
              children: _tables.map(_tableCard).toList(),
            ),
          ),
          Container(
            color: _panel,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: _bottomBtn(
                    Icons.shopping_bag_outlined,
                    'Новый — на вынос',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _bottomBtn(Icons.two_wheeler, 'Новый — доставка'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, int count, Color color) => Padding(
    padding: const EdgeInsets.only(left: 18),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label $count',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _zonePill(String label, bool active) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: BoxDecoration(
      color: active ? _blue : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: active ? _blue : Colors.white24),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: active ? Colors.white : Colors.white70,
        fontSize: 13,
        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
      ),
    ),
  );

  Widget _tableCard((String, int, int, String, String) t) {
    final color = _statColor(t.$3);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.85), color],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            t.$1,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline, size: 15, color: Colors.white70),
              const SizedBox(width: 3),
              Text(
                '${t.$2}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          if (t.$3 == 1) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                t.$4,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.$5,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (t.$3 == 2) ...[
            const SizedBox(height: 8),
            const Text(
              'Бронь',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
          if (t.$3 == 3) ...[
            const SizedBox(height: 8),
            const Text(
              'Уборка',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBtn(IconData icon, String label) => Container(
    height: 52,
    decoration: BoxDecoration(
      color: const Color(0xFF0A3D62),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _WmsDashboardMock extends StatelessWidget {
  const _WmsDashboardMock();

  static const _mods = <(IconData, String, String, Color, String?)>[
    (
      Icons.warehouse_outlined,
      'Склады',
      'Склады, зоны, ячейки',
      Color(0xFF1E88E5),
      '3',
    ),
    (
      Icons.inventory_2_outlined,
      'Партии',
      'Партионный учёт, сроки годности',
      Color(0xFFFB8C00),
      null,
    ),
    (
      Icons.inventory,
      'Остатки по ячейкам',
      'Размещение и отбор',
      Color(0xFF3949AB),
      null,
    ),
    (
      Icons.qr_code_2,
      'Серийный учёт',
      'Серийные номера',
      Color(0xFF00897B),
      null,
    ),
    (
      Icons.verified_outlined,
      'Маркировка',
      'Коды маркировки (Честный знак)',
      Color(0xFF8E24AA),
      null,
    ),
    (
      Icons.report_problem_outlined,
      'Рекламации',
      'Претензии и возвраты',
      Color(0xFFE53935),
      '2',
    ),
    (
      Icons.swap_horiz,
      'Перемещения',
      'Между складами и ячейками',
      Color(0xFF00838F),
      null,
    ),
    (
      Icons.tune,
      'Настройки WMS',
      'Конфигурация модулей',
      Color(0xFF607D8B),
      null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          const _NavRail(activeLabel: 'Склад'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.warehouse, size: 26),
                      SizedBox(width: 12),
                      Text(
                        'WMS — Управление складом',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Адресное хранение, партии, серийные номера и маркировка',
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      childAspectRatio: 1.25,
                      children: _mods.map(_card).toList(),
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

  Widget _card((IconData, String, String, Color, String?) m) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    padding: const EdgeInsets.all(18),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(m.$1, size: 38, color: m.$4),
        const SizedBox(height: 10),
        Text(
          m.$2,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          m.$3,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        if (m.$5 != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: m.$4.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              m.$5!,
              style: TextStyle(
                color: m.$4,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ServiceQueueMock extends StatelessWidget {
  const _ServiceQueueMock();

  static const _orders = <(String, String, int, String, String)>[
    ('SO-0231', 'Алиев Руслан · iPhone 13', 0, '14.06', '— ₸'),
    ('SO-0230', 'Ким Сергей · Ноутбук ASUS', 1, '13.06', '35 000 ₸'),
    ('SO-0229', 'ТОО «Астра» · Принтер HP', 1, '12.06', '12 500 ₸'),
    ('SO-0228', 'Нурлан О. · Samsung S22', 2, '11.06', '18 900 ₸'),
    ('SO-0227', 'Петрова А. · Часы Garmin', 2, '10.06', '7 400 ₸'),
    ('SO-0226', 'Жанна К. · Кофемашина', 0, '14.06', '— ₸'),
  ];

  (Color, String, IconData) _status(int s) => switch (s) {
    0 => (const Color(0xFF1E88E5), 'Приёмка', Icons.inbox),
    1 => (const Color(0xFFFB8C00), 'В работе', Icons.build),
    _ => (const Color(0xFF2E7D32), 'Готов', TeleposIcons.checkCircle),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          const _NavRail(activeLabel: 'Услуги'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Очередь заказ-нарядов',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.list_alt, size: 16),
                            label: const Text('Каталог услуг'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: () {},
                            icon: const Icon(TeleposIcons.add, size: 18),
                            label: const Text('Новый заказ'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _chip(Icons.folder_open, 'Активные', 2, _blue),
                          const SizedBox(width: 18),
                          _chip(
                            Icons.build,
                            'В работе',
                            2,
                            const Color(0xFFFB8C00),
                          ),
                          const SizedBox(width: 18),
                          _chip(
                            TeleposIcons.checkCircle,
                            'Готовы',
                            2,
                            const Color(0xFF2E7D32),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF3F7),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Expanded(flex: 2, child: Text('№', style: _th)),
                                Expanded(
                                  flex: 6,
                                  child: Text('Клиент / изделие', style: _th),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text('Статус', style: _th),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Срок', style: _th),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text('Сумма', style: _th),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              children: _orders.map(_row).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _th = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);

  Widget _chip(IconData icon, String label, int count, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 5),
      Text(
        '$count',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 15,
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
    ],
  );

  Widget _row((String, String, int, String, String) o) {
    final s = _status(o.$3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEF))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              o.$1,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 6, child: Text(o.$2)),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: s.$1.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.$3, size: 13, color: s.$1),
                    const SizedBox(width: 4),
                    Text(
                      s.$2,
                      style: TextStyle(
                        color: s.$1,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(o.$4, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              o.$5,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsMock extends StatelessWidget {
  const _ReportsMock();

  static const _tabs = <(IconData, String)>[
    (Icons.dashboard, 'Сводка'),
    (Icons.shopping_cart, 'Продажи'),
    (Icons.inventory, 'Товары'),
    (Icons.account_balance, 'Финансы'),
    (Icons.people, 'Клиенты'),
    (Icons.local_shipping, 'Поставщики'),
    (Icons.trending_up, 'Прогнозы'),
    (Icons.restaurant, 'Ресторан'),
    (Icons.receipt_long, 'Налоги / КГД'),
  ];

  static const _bars = [0.5, 0.7, 0.45, 0.85, 0.95, 0.6, 0.75];
  static const _days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 220,
            color: const Color(0xFF1E293B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: const [
                      Icon(Icons.bar_chart_rounded, color: _blue, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Аналитика',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF334155), height: 1),
                const SizedBox(height: 8),
                ..._tabs.asMap().entries.map((e) {
                  final active = e.key == 0;
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: active ? _blue.withValues(alpha: 0.15) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          e.value.$1,
                          size: 20,
                          color: active ? _blue : Colors.white60,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          e.value.$2,
                          style: TextStyle(
                            color: active ? _blue : Colors.white70,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: _bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 56,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        const Text(
                          'Отчёты · Сводка',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.calendar_today, size: 16),
                              SizedBox(width: 8),
                              Text('01.06 — 12.06.2026'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _kpi(
                                'Выручка',
                                '4 286 500 ₸',
                                '+12%',
                                const Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 16),
                              _kpi('Чеков', '1 842', '+5%', _blue),
                              const SizedBox(width: 16),
                              _kpi(
                                'Средний чек',
                                '2 327 ₸',
                                '+3%',
                                const Color(0xFF6A1B9A),
                              ),
                              const SizedBox(width: 16),
                              _kpi(
                                'Прибыль',
                                '1 057 200 ₸',
                                '+9%',
                                const Color(0xFFEF6C00),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Продажи по дням недели',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: List.generate(_bars.length, (
                                        i,
                                      ) {
                                        return Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Container(
                                                  height: 180 * _bars[i],
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                          begin: Alignment
                                                              .topCenter,
                                                          end: Alignment
                                                              .bottomCenter,
                                                          colors: [
                                                            _blue,
                                                            Color(0xFF64B5F6),
                                                          ],
                                                        ),
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                          top: Radius.circular(
                                                            6,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  _days[i],
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _kpi(String label, String value, String delta, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_upward, size: 12, color: color),
                    const SizedBox(width: 3),
                    Text(
                      delta,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _FiscalSettingsMock extends StatelessWidget {
  const _FiscalSettingsMock();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text('Фискализация (КГД РК)'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.verified, color: Color(0xFF2E7D32)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Касса зарегистрирована в ОФД. Статус: онлайн. Чеки уходят в КГД.',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _section('Оператор фискальных данных', [
                _field('Оператор (ОФД)', 'WebKassa', isDropdown: true),
                _field('БИН / ИНН организации', '012345678901'),
                _field('Заводской номер кассы', 'SWK00123456'),
                _field('Регистрационный номер', 'KZ-405-09-988421'),
              ]),
              const SizedBox(height: 16),
              _section('Налогообложение', [
                _field(
                  'Режим',
                  'Упрощённый (НДС не облагается)',
                  isDropdown: true,
                ),
                _field('Ставка НДС по умолчанию', '12%', isDropdown: true),
              ]),
              const SizedBox(height: 16),
              _section('Дополнительные подсистемы КГД', [
                _toggle('ЭСФ — электронные счёта-фактуры', true),
                _toggle('СНТ — сопроводительные накладные', true),
                _toggle('ИС МПТ — маркировка товаров', false),
              ]),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(TeleposIcons.save),
                  label: const Text(
                    'Сохранить настройки',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );

  Widget _field(String label, String value, {bool isDropdown = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            SizedBox(
              width: 240,
              child: Text(label, style: const TextStyle(color: Colors.black54)),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD9DEE3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (isDropdown)
                      const Icon(Icons.arrow_drop_down, color: Colors.black45),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _toggle(String label, bool on) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Container(
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: on ? const Color(0xFF2E7D32) : Colors.black26,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Align(
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CashOpsMock extends StatelessWidget {
  const _CashOpsMock();

  static const _ops = <(String, String, String, bool)>[
    (
      'Внесение — разменный фонд',
      'Кассир: Иванов И.И. · 09:02',
      '+20 000 ₸',
      true,
    ),
    (
      'Изъятие — инкассация',
      'Сдача выручки в банк · 13:15',
      '−150 000 ₸',
      false,
    ),
    ('Внесение — возврат сдачи', 'Корректировка · 14:40', '+1 500 ₸', true),
    ('Изъятие — расход', 'Покупка воды для зала · 16:05', '−3 200 ₸', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          const _NavRail(activeLabel: 'Касса'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Касса · денежные операции',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Наличные в кассе сейчас',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '268 300 ₸',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _bigBtn(TeleposIcons.add, 'Внесение', const Color(0xFF2E7D32)),
                      const SizedBox(width: 16),
                      _bigBtn(Icons.remove, 'Изъятие', const Color(0xFFEF6C00)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Операции за смену',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListView(children: _ops.map(_opRow).toList()),
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

  Widget _bigBtn(IconData icon, String label, Color color) => Container(
    width: 150,
    height: 92,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );

  Widget _opRow((String, String, String, bool) o) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFEEEEEF))),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (o.$4 ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00))
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            o.$4 ? Icons.arrow_downward : Icons.arrow_upward,
            color: o.$4 ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                o.$2,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          o.$3,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: o.$4 ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
          ),
        ),
      ],
    ),
  );
}

class _CustomersMock extends StatelessWidget {
  const _CustomersMock();

  static const _clients = <(String, String, String, String, bool)>[
    ('Алиев Руслан', '+7 701 234 56 78', '1 240 ₸', '186 500 ₸', true),
    ('Ким Сергей', '+7 707 555 11 22', '320 ₸', '54 200 ₸', false),
    ('Петрова Анна', '+7 705 888 99 00', '2 870 ₸', '412 900 ₸', false),
    ('ТОО «Астра»', '+7 727 300 40 50', '0 ₸', '1 240 000 ₸', false),
    ('Нурлан Омаров', '+7 700 111 22 33', '640 ₸', '98 700 ₸', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          const _NavRail(activeLabel: 'Клиенты'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Клиенты',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(TeleposIcons.add, size: 18),
                        label: const Text('Добавить клиента'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFF3F7),
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(14),
                                    ),
                                  ),
                                  child: Row(
                                    children: const [
                                      Expanded(
                                        flex: 4,
                                        child: Text('Клиент', style: _th),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text('Телефон', style: _th),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text('Бонусы', style: _th),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text('Покупки', style: _th),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView(
                                    children: _clients.map(_row).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: _blue,
                                      child: Text(
                                        'АР',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Алиев Руслан',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '+7 701 234 56 78',
                                          style: TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFC2185B,
                                    ).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Бонусный баланс',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        '1 240 ₸',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFC2185B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Последние покупки',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                _hist('Чек #12345', '09.06', '2 640 ₸'),
                                _hist('Чек #12180', '02.06', '5 120 ₸'),
                                _hist('Чек #11920', '28.05', '1 980 ₸'),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  static const _th = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);

  Widget _row((String, String, String, String, bool) c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: c.$5 ? _blue.withValues(alpha: 0.06) : null,
      border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEF))),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            c.$1,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            c.$2,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            c.$3,
            style: const TextStyle(
              color: Color(0xFFC2185B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            c.$4,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _hist(String no, String date, String sum) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        const Icon(Icons.receipt_long, size: 16, color: Colors.black38),
        const SizedBox(width: 8),
        Text(no),
        const Spacer(),
        Text(date, style: const TextStyle(color: Colors.black54)),
        const SizedBox(width: 14),
        Text(sum, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _SupplyMock extends StatelessWidget {
  const _SupplyMock();

  static const _rows = <(String, String, String, String)>[
    ('Молоко «Простоквашино» 1 л', '120 шт', '310 ₸', '37 200 ₸'),
    ('Хлеб белый нарезной', '80 шт', '120 ₸', '9 600 ₸'),
    ('Сахар-песок 1 кг', '200 шт', '380 ₸', '76 000 ₸'),
    ('Масло сливочное 180 г', '60 шт', '640 ₸', '38 400 ₸'),
    ('Чай чёрный 25 пак.', '50 шт', '520 ₸', '26 000 ₸'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text('Поставка · приёмка товара'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _info('Поставщик', 'ТОО «Бакалея-Опт»')),
                const SizedBox(width: 16),
                Expanded(child: _info('Накладная №', 'НК-004812')),
                const SizedBox(width: 16),
                Expanded(child: _info('Дата', '12.06.2026')),
                const SizedBox(width: 16),
                Expanded(child: _info('Склад', 'Основной')),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF3F7),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Expanded(flex: 5, child: Text('Товар', style: _th)),
                          Expanded(flex: 2, child: Text('Кол-во', style: _th)),
                          Expanded(
                            flex: 2,
                            child: Text('Цена закупки', style: _th),
                          ),
                          Expanded(flex: 2, child: Text('Сумма', style: _th)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(children: _rows.map(_row).toList()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Text(
                        'Итого по поставке:  ',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '187 200 ₸',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(TeleposIcons.check),
                    label: const Text(
                      'Провести приёмку',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _th = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);

  Widget _info(String label, String value) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    ),
  );

  Widget _row((String, String, String, String) r) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFEEEEEF))),
    ),
    child: Row(
      children: [
        Expanded(flex: 5, child: Text(r.$1)),
        Expanded(flex: 2, child: Text(r.$2)),
        Expanded(
          flex: 2,
          child: Text(r.$3, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          flex: 2,
          child: Text(
            r.$4,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _UsersMock extends StatelessWidget {
  const _UsersMock();

  static const _users = <(String, String, Color, bool)>[
    ('Иванов Иван', 'Администратор', Color(0xFF6A1B9A), true),
    ('Петров Пётр', 'Менеджер', Color(0xFF1E88E5), true),
    ('Сидорова Анна', 'Кассир', Color(0xFF2E7D32), true),
    ('Касымов Дамир', 'Кассир', Color(0xFF2E7D32), true),
    ('Алина Ж.', 'Кассир', Color(0xFF2E7D32), false),
  ];

  static const _perms = <(String, bool)>[
    ('Оформление продаж', true),
    ('Возвраты', true),
    ('Скидки вручную', false),
    ('Открытие / закрытие смены', true),
    ('Инкассация (изъятие денег)', false),
    ('Редактирование каталога и цен', false),
    ('Доступ к отчётам', true),
    ('Управление пользователями', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          const _NavRail(activeLabel: 'Настройки'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Пользователи и роли',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Права роли «Кассир»',
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListView(
                              children: _users.map(_userRow).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.shield_outlined,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Разрешения роли «Кассир»',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ..._perms.map(_permRow),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _userRow((String, String, Color, bool) u) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFEEEEEF))),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: u.$3.withValues(alpha: 0.15),
          child: Text(
            u.$1[0],
            style: TextStyle(color: u.$3, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: u.$3.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  u.$2,
                  style: TextStyle(
                    color: u.$3,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Icon(
          u.$4 ? TeleposIcons.checkCircle : Icons.cancel,
          color: u.$4 ? const Color(0xFF2E7D32) : Colors.black26,
          size: 18,
        ),
      ],
    ),
  );

  Widget _permRow((String, bool) p) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(
          p.$2 ? TeleposIcons.check : TeleposIcons.close,
          size: 18,
          color: p.$2 ? const Color(0xFF2E7D32) : Colors.black38,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            p.$1,
            style: TextStyle(color: p.$2 ? Colors.black87 : Colors.black45),
          ),
        ),
        Container(
          width: 42,
          height: 24,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: p.$2 ? const Color(0xFF2E7D32) : Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Align(
            alignment: p.$2 ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _InventoryMock extends StatelessWidget {
  const _InventoryMock();

  static const _rows = <(String, int, int)>[
    ('Молоко «Простоквашино» 1 л', 128, 128),
    ('Хлеб белый нарезной', 46, 44),
    ('Сахар-песок 1 кг', 210, 213),
    ('Масло сливочное 180 г', 64, 64),
    ('Чай чёрный 25 пак.', 88, 85),
    ('Кофе растворимый 95 г', 37, 37),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text('Инвентаризация'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _stat('Позиций пересчитано', '6 из 6', _blue)),
                const SizedBox(width: 16),
                Expanded(child: _stat('Совпало', '3', const Color(0xFF2E7D32))),
                const SizedBox(width: 16),
                Expanded(
                  child: _stat('Расхождений', '3', const Color(0xFFEF6C00)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                hintText: 'Сканируйте штрихкод или введите количество…',
                prefixIcon: const Icon(Icons.qr_code_scanner),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF3F7),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Expanded(flex: 5, child: Text('Товар', style: _th)),
                          Expanded(
                            flex: 2,
                            child: Text('По системе', style: _th),
                          ),
                          Expanded(flex: 2, child: Text('Факт', style: _th)),
                          Expanded(flex: 2, child: Text('Разница', style: _th)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(children: _rows.map(_row).toList()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _th = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);

  Widget _stat(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _row((String, int, int) r) {
    final diff = r.$3 - r.$2;
    final color = diff == 0
        ? const Color(0xFF2E7D32)
        : (diff > 0 ? _blue : const Color(0xFFE53935));
    final diffText = diff == 0 ? '0' : (diff > 0 ? '+$diff' : '$diff');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: diff == 0 ? null : color.withValues(alpha: 0.05),
        border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEF))),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(r.$1)),
          Expanded(
            flex: 2,
            child: Text(
              '${r.$2} шт',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${r.$3} шт',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              diffText,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
