/// Отказ кассы виден словами, а не вечным спиннером.
///
/// # Чем это оплачено
///
/// Живая приёмка 2026-09-19, планшет против настоящей кассы. Вкладка
/// «Принтер» крутила спиннер бесконечно. Причина лежала в ошибке потока:
/// касса бросала `UnimplementedError` (пробел стенда — у его принтера не был
/// поднят `currentPaperWidth`, который `watchPrinter` спрашивает **до
/// первого кадра**). Вкладка эту ошибку молча проглатывала: ветвь
/// `snapshot.data == null` верна и когда кадра ещё нет, и когда его уже не
/// будет, — два противоположных состояния под одним видом.
///
/// Цена ровно та, что в пункте 4 списка провалов приёмки
/// (`2026-09-19-diagnostics-acceptance.md`): пустота вместо ответа там, где
/// ответ есть. Наладчик читает спиннер как «сейчас придёт» и ждёт минуту,
/// вместо того чтобы прочитать причину и пойти её чинить.
///
/// # Чего эта проба НЕ доказывает
///
/// Что текст причины понятен человеку: сюда доезжает `toString()` ошибки
/// кассы, и он технический. Требование здесь слабее и важнее — **отказ
/// обязан быть отличим от ожидания**. Перевод причин в человеческие слова
/// живёт у словаря отказов провода и мерится своими пробами.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/diagnostics/display_diagnostics_tab.dart';
import 'package:telepos/presentation/screens/diagnostics/drawer_diagnostics_tab.dart';
import 'package:telepos/presentation/screens/diagnostics/printer_diagnostics_tab.dart';
import 'package:telepos/presentation/screens/diagnostics/scales_diagnostics_tab.dart';

void main() {
  tearDown(() => GetIt.I.reset());

  /// Касса, отказывающая на любой вопрос диагностики.
  ///
  /// Именно `Stream.error`, а не пустой поток: пустой поток проверял бы
  /// ожидание, а предмет здесь — **отказ**.
  void bindRefusing() {
    GetIt.I.registerSingleton<HardwareDiagnosticsRepository>(
      _RefusingDiagnostics(),
    );
  }

  Future<void> mount(WidgetTester tester, Widget tab) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: tab),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (name, tab) in <(String, Widget)>[
    ('принтер', const PrinterDiagnosticsTab()),
    ('ящик', const DrawerDiagnosticsTab()),
    ('весы', const ScalesDiagnosticsTab()),
    ('дисплей', const DisplayDiagnosticsTab()),
  ]) {
    testWidgets('$name: отказ кассы назван, а не показан спиннером', (
      tester,
    ) async {
      bindRefusing();
      await mount(tester, tab);

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason:
            'спиннер после отказа — обещание кадра, которого уже не будет; '
            'наладчик ждёт вместо того, чтобы читать причину',
      );
      expect(
        find.textContaining('не ответила'),
        findsOneWidget,
        reason: 'отказ обязан быть назван словами',
      );
      expect(
        find.textContaining('порт принтера занят'),
        findsOneWidget,
        reason: 'и вместе с причиной, а не общим «ошибка»',
      );
    });
  }
}

/// Порт диагностики, который на всё отвечает отказом.
class _RefusingDiagnostics implements HardwareDiagnosticsRepository {
  static const _why = 'порт принтера занят';

  @override
  Stream<PrinterDiagnosticsView> watchPrinter() =>
      Stream.error(StateError(_why));

  @override
  Stream<DrawerDiagnosticsView> watchDrawer() => Stream.error(StateError(_why));

  @override
  Stream<DisplayDiagnosticsView> watchDisplay() =>
      Stream.error(StateError(_why));

  @override
  Stream<ScalesDiagnosticsView> watchScales() => Stream.error(StateError(_why));

  @override
  Future<FiscalDiagnosticsView> fiscal() => Future.error(StateError(_why));
}
