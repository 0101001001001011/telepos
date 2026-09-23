/// `Escape` закрывает выдачу поиска — приёмка 2026-09-17.
///
/// # Зачем отдельный выход, если выдача и так закрывается сама
///
/// Потому что все прочие выходы из неё — **добавление товара**. Кассир,
/// открывший выдачу по ошибке (набрал не то, промахнулся по полю), мог
/// закрыть её только очисткой поля крестиком в самом поле: одно нажатие,
/// но целиться в него надо мимо открытого списка, который занимает до 300
/// точек под полем. Живьём это и привело к лишней позиции в чеке —
/// открытый список ловил следующее нажатие.
///
/// Проба смотрит на **увиденное кассиром**: строка товара в дереве
/// виджетов, а не вызов метода контроллера. Вызов — способ, а способ можно
/// поменять; список под полем — требование.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/sale/widgets/product_search.dart';

import '../../../helpers/mock_providers.dart';

/// Касса, у которой выдача действительно закрывается по пустому запросу —
/// как у настоящей (`SaleNotifier.search`, ветка `query.isEmpty`).
///
/// Подделка, у которой `search` не делает ничего (умолчание
/// `MockSaleNotifier`), зеленела бы на любом коде: список в состоянии
/// остался бы на месте и проба мерила бы саму подделку.
class _SearchingSaleNotifier extends MockSaleNotifier {
  _SearchingSaleNotifier(super.state);

  final queries = <String>[];

  @override
  Future<void> search(String query) async {
    queries.add(query);
    if (query.isEmpty) {
      state = state.copyWith(searchQuery: '', searchResults: []);
    } else {
      state = state.copyWith(searchQuery: query);
    }
  }
}

void main() {
  late SharedPreferences prefs;
  late _SearchingSaleNotifier notifier;

  final found = ProductSearchResult(
    id: 1001,
    barcode: '4607001234567',
    name: 'Молоко 1л',
    price: Decimal.parse('450'),
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() {
    notifier = _SearchingSaleNotifier(
      SaleState(searchQuery: 'Молоко', searchResults: [found]),
    );
  });

  tearDown(GetIt.I.reset);

  Future<void> pumpSearch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saleControllerProvider.overrideWith(() => notifier),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          locale: const Locale('ru'),
          home: const Scaffold(body: ProductSearch(autofocus: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Escape закрывает выдачу поиска и чистит поле', (tester) async {
    await pumpSearch(tester);

    expect(
      find.text('Молоко 1л'),
      findsOneWidget,
      reason: 'контрольный случай: выдача открыта — есть что закрывать',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
      find.text('Молоко 1л'),
      findsNothing,
      reason:
          'ESCAPE НЕ ЗАКРЫЛ ВЫДАЧУ. Открытый список остаётся под пальцем '
          'кассира и ловит следующее нажатие — привязка `Escape` стоит в '
          '`product_search.dart`, вокруг поля.',
    );
    expect(
      notifier.queries,
      contains(''),
      reason:
          'выдача закрыта показом, но состояние кассы не очищено — '
          'следующий кадр откроет её снова',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
      reason:
          'поле осталось набранным — тем же ходом, что и при добавлении '
          'товара по клику, оно обязано очиститься',
    );
  });
}
