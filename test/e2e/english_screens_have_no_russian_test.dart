/// В английском языке на экране не должно оставаться русских слов.
///
/// # Почему эта проверка смотрит на экран, а не в исходник
///
/// Поиск кириллицы по `lib/presentation` даёт 612 совпадений, и почти все —
/// не дефект: записи в журнал, тексты `assert`, символ киргизского сома `с`,
/// мёртвые запасные значения вида `l10n?.helpTips ?? 'Советы'`, которые
/// никогда не доезжают до экрана, потому что словарь на месте. Сторож по
/// исходнику краснел бы на всём этом и был бы снят на второй неделе.
///
/// Поэтому меряется то, что человек видит: приложение поднимается на
/// английском, обходит каждый маршрут и собирает текст всех виджетов `Text`.
/// Кириллица в собранном — дефект по определению, без оговорок и списков
/// исключений.
///
/// # Почему данные переводятся
///
/// Затравка стенда русская (товары, склады, контрагенты). Это данные
/// магазина, а не интерфейс: их никто не переводит, и на них сторож обязан
/// молчать. Поэтому затравка переписывается на английский целиком — всё, что
/// осталось кириллицей после этого, пришло из кода.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';

import 'support/harness.dart';

/// Весь кириллический блок Unicode, а не только русские буквы: казахская `қ`
/// и киргизская `ү` попались бы мимо диапазона `а-я`.
final _cyrillic = RegExp('[Ѐ-ӿ]');

/// Названия языков в самих этих языках — «Русский», «Қазақша», «Кыргызча».
///
/// Кириллица здесь не дефект, а единственный правильный вид: список языков
/// во всём мире пишут на языке, который предлагают, иначе выбрать свой
/// сможет только тот, кто уже читает по-английски. Исключение сделано не
/// перечнем слов, а по самому источнику — добавится язык, и сторож узнает
/// о нём сам.
final _endonyms = {
  for (final locale in AppLocale.values) locale.nativeName,
};

/// Подсказка кнопки выбора языка — «Language / Язык / Тіл».
///
/// Она трёхъязычна намеренно и по той же причине, что и список языков:
/// человек, который не читает по-английски, должен найти эту кнопку, не
/// умея прочесть ничего вокруг. Исключение снова сделано по источнику —
/// берётся само значение из английского словаря, а не переписанная строка,
/// так что правка текста подсказки сторожа не сломает.
final _languageTooltip = lookupAppLocalizations(
  const Locale('en'),
).languageSwitcherTooltip;

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    await _seedInEnglish(h.db);
  });
  tearDownAll(() => h.tearDown());

  /// Маршруты те же, что метёт `ui_tour_test`, — список один на два сторожа
  /// расходиться не должен.
  const routes = <String>[
    '/sale',
    '/payment',
    '/refund',
    '/shift',
    '/history',
    '/catalog',
    '/reports',
    '/agent',
    '/supply',
    '/stock-registry',
    '/movement',
    '/supplier-return',
    '/cash-operation',
    '/writeoff',
    '/inventory',
    '/sync',
    '/additional',
    '/tables',
    '/orders',
    '/service-queue',
    '/service-intake',
    '/service-catalog',
    '/wms',
    '/wms-warehouses',
    '/wms-batches',
    '/wms-serials',
    '/wms-cell-stock',
    '/wms-claims',
    '/wms-marking',
    '/wms-settings',
    '/transport-settings',
    '/printer-settings',
    '/fiscal-settings',
    '/tax-settings',
    '/restaurant-settings',
    '/hardware-settings',
    '/appliance-settings',
    '/accounts-settings',
    '/user-management',
    '/telegram-settings',
    '/settings',
    '/markup-settings',
    '/credit-contracts',
    '/supplier-order',
    '/promotions',
    '/diagnostics',
  ];

  Future<void> render(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Собирает видимый текст экрана.
  ///
  /// Берётся `data` и `textSpan`, потому что половина заголовков в приложении
  /// построена через `Text.rich`.
  ///
  /// Подсказки (`Tooltip`) собираются отдельно и по делу: они **не** виджеты
  /// `Text`, пока их не вызвали наведением, и первая редакция этого сторожа
  /// их не видела вовсе. Четыре русских подсказки в отчётах («Обновить»,
  /// «Экспорт», «Экспорт CSV») пережили зелёный прогон и нашлись чтением —
  /// ровно тот случай, ради которого сторожа и проверяют на слепоту.
  List<String> visibleText(WidgetTester tester) {
    final out = <String>[];
    for (final element in find.byType(Text).evaluate()) {
      final widget = element.widget as Text;
      final data = widget.data ?? widget.textSpan?.toPlainText();
      if (data != null && data.trim().isNotEmpty) out.add(data);
    }
    for (final element in find.byType(Tooltip).evaluate()) {
      final message = (element.widget as Tooltip).message;
      if (message != null && message.trim().isNotEmpty) out.add(message);
    }
    return out;
  }

  testWidgets('ни один экран по-английски не показывает русских слов', (
    tester,
  ) async {
    await h.pumpApp(tester, locale: 'en');
    await tester.pump(const Duration(seconds: 1));
    await render(tester);

    final offences = <String, Set<String>>{};

    void collect(String where) {
      for (final text in visibleText(tester)) {
        if (_endonyms.contains(text.trim())) continue;
        if (text.trim() == _languageTooltip) continue;
        if (_cyrillic.hasMatch(text)) {
          offences.putIfAbsent(where, () => <String>{}).add(text.trim());
        }
      }
    }

    collect('01 login');

    await h.loginAsCashier(tester);
    await render(tester);
    collect('02 home');

    for (final route in routes) {
      h.router!.go(route);
      await render(tester);
      tester.takeException();
      collect(route);
    }

    if (offences.isNotEmpty) {
      final buffer = StringBuffer()
        ..writeln('Русский текст на английском интерфейсе:')
        ..writeln();
      var total = 0;
      for (final entry in offences.entries) {
        buffer.writeln('  ${entry.key}');
        for (final text in entry.value) {
          total++;
          final oneLine = text.replaceAll('\n', ' ');
          buffer.writeln(
            '    • ${oneLine.length > 90 ? '${oneLine.substring(0, 90)}…' : oneLine}',
          );
        }
      }
      buffer
        ..writeln()
        ..writeln('Всего $total на ${offences.length} экранах.');
      fail(buffer.toString());
    }
  });
}

/// Переписывает затравку на английский: всё, что останется кириллицей после
/// этого, пришло из кода, а не из базы магазина.
Future<void> _seedInEnglish(AppDatabase db) async {
  await db
      .update(db.thisPosEntries)
      .write(
        const ThisPosEntriesCompanion(
          companyName: Value('Northwind'),
          cashBoxName: Value('Till-1'),
        ),
      );
  await db.update(db.users).write(const UsersCompanion(name: Value('Demo')));
  await db
      .update(db.categories)
      .write(const CategoriesCompanion(name: Value('Groceries')));
  await db
      .update(db.productInfos)
      .write(const ProductInfosCompanion(name: Value('Sample product')));
  await db
      .update(db.accounts)
      .write(const AccountsCompanion(name: Value('Cash')));
}
