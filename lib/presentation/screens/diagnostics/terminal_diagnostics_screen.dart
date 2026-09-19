import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/diagnostics/display_diagnostics_tab.dart';
import 'package:telepos/presentation/screens/diagnostics/drawer_diagnostics_tab.dart';
import 'package:telepos/presentation/screens/diagnostics/fiscal_diagnostics_tab.dart';
import 'package:telepos/presentation/screens/diagnostics/printer_diagnostics_tab.dart';
import 'package:telepos/presentation/screens/diagnostics/scales_diagnostics_tab.dart';

/// Диагностика оборудования кассы, открытая **с планшета** — пункт
/// «Достижимость с браузерного терминала» плана
/// `docs/internal/superpowers/plans/2026-09-19-hardware-diagnostics.md`.
///
/// # Почему экран свой, а не кассовый `DiagnosticsScreen`
///
/// Разница не в оформлении и не в осторожности — она **измерена**:
///
/// 1. **`dart:io`.** `DiagnosticsScreen` считает плашку «за этим портом
///    эмулятор» по адресу привязки принтера и разбирает его
///    `InternetAddress.tryParse(...).isLoopback`. `dart:io` в браузерной
///    сборке нет вовсе — сторож `browser_routes_test` красит такой импорт в
///    замыкании таблицы маршрутов, а `flutter build web` просто не
///    собирается. Перенести разбор адреса в чистый Dart можно, но это правка
///    кассового экрана ради браузерного — и **вторым** вычислением петли,
///    рядом с существующим, чего этот проект не делает;
/// 2. **вкладка, которой здесь нет.** «Оплата» читает намерения по коду из
///    базы кассы (`AppDatabase`) и адрес провайдера у стойки оплаты; на
///    провод она пока не вынесена. Её отсутствие здесь — названная граница
///    работы, а не забытая вкладка.
///
///    Ящик, весы и дисплей покупателя **были** в этом же списке до пункта 4
///    плана и закрыты им: все три едут своими подписками провода
///    (`diagnostics.drawer`, `diagnostics.display`, `diagnostics.scales`), и
///    вкладки у них — те же файлы, что на кассе;
/// 3. **выход.** У браузерной таблицы нет ни оболочки, ни стека переходов:
///    вкладку открывают прямо по адресу, и `context.pop()` в ней не делает
///    ничего. Шапка здесь уводит на дом терминала — тем же приёмом, что у
///    `/refund` и `/prepayment` в `setup_router.dart`.
///
/// # Вкладки при этом — ТЕ ЖЕ, и это главное
///
/// [PrinterDiagnosticsTab], [DrawerDiagnosticsTab], [ScalesDiagnosticsTab],
/// [DisplayDiagnosticsTab] и [FiscalDiagnosticsTab] — те самые файлы, что
/// стоят на кассе. Второй, «браузерной», копии вкладки не заведено нарочно:
/// две похожих вкладки расходятся молча, и первым это увидел бы наладчик, у
/// которого экран кассы и экран планшета показывают разное про один и тот же
/// чек. Различие между поверхностями целиком в том, какая реализация порта
/// `HardwareDiagnosticsRepository` лежит в контейнере — кассовая или
/// проводная.
///
/// # Порядок вкладок тот же, что на кассе, и это не мелочь
///
/// Принтер, ящик, весы, дисплей, оператор — как в `DiagnosticsScreen`.
/// Наладчик ходит по ним подряд и на двух поверхностях в один день; порядок,
/// переставленный «как удобнее здесь», стоил бы ему поиска вкладки на
/// каждом переходе.
///
/// # Чего этот экран НЕ показывает
///
/// Плашки эмулятора (см. пункт 1 выше) и вкладки оплаты (пункт 2). Названо
/// вслух, потому что отсутствие вкладки на экране диагностики человек читает
/// как «у этой кассы такого прибора нет», а это неправда.
class TerminalDiagnosticsScreen extends StatelessWidget {
  const TerminalDiagnosticsScreen({required this.homeRoute, super.key});

  /// Куда уходить стрелке «назад».
  ///
  /// Называет **таблица**, а не экран: у десктопной таблицы дом другой, и
  /// `/terminal-home` в ней не объявлен вовсе. Тот же приём, что у
  /// `ReceiptTemplatesScreen` и `TerminalShiftScreen`.
  final String homeRoute;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.diagnosticsTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.globalBack,
            onPressed: () => context.go(homeRoute),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                key: const ValueKey('terminal-diagnostics-tab-printer'),
                text: l10n.diagnosticsTabPrinter,
              ),
              Tab(
                key: const ValueKey('terminal-diagnostics-tab-drawer'),
                text: l10n.diagnosticsTabDrawer,
              ),
              Tab(
                key: const ValueKey('terminal-diagnostics-tab-scales'),
                text: l10n.diagnosticsTabScales,
              ),
              Tab(
                key: const ValueKey('terminal-diagnostics-tab-display'),
                text: l10n.diagnosticsTabDisplay,
              ),
              Tab(
                key: const ValueKey('terminal-diagnostics-tab-fiscal'),
                text: l10n.diagnosticsTabFiscal,
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PrinterDiagnosticsTab(),
            DrawerDiagnosticsTab(),
            ScalesDiagnosticsTab(),
            DisplayDiagnosticsTab(),
            FiscalDiagnosticsTab(),
          ],
        ),
      ),
    );
  }
}
