import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/core/net/loopback.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/diagnostics/display_diagnostics_tab.dart';
import 'package:telepos/presentation/screens/diagnostics/drawer_diagnostics_tab.dart';
import 'package:telepos/presentation/screens/diagnostics/fiscal_diagnostics_tab.dart';
import 'package:telepos/presentation/screens/diagnostics/payment_diagnostics_tab.dart';
import 'package:telepos/presentation/screens/diagnostics/printer_diagnostics_tab.dart';
import 'package:telepos/presentation/screens/diagnostics/scales_diagnostics_tab.dart';

/// Диагностика оборудования: что касса **на самом деле** отправила приборам.
///
/// # Почему один экран, а не кнопка на каждом экране настроек
///
/// Требование заказчика 2026-09-19: «при запуске чтобы можно было всё реально
/// продиагностировать и понять, что всё работает». Вопрос у наладчика один и
/// тот же — «что ушло в прибор» — и задаёт он его подряд про все приборы, а
/// не про один. Разложенный по семи экранам настроек, этот ответ каждый раз
/// приходилось бы искать заново.
///
/// # Пометка эмулятора — по адресу привязки, а не по выключателю
///
/// Плашка «за этим портом эмулятор» зажигается, когда привязка принтера
/// смотрит на **петлю**. Не когда включён встроенный эмулятор: касса, чья
/// привязка направлена на эмулятор, запущенный руками из командной строки,
/// ничем не отличается — и обязана быть помечена так же. Состояние
/// выключателя тут не источник правды, а привязка — источник.
///
/// Сам вопрос «это петля?» экран **задаёт**, а не отвечает на него:
/// [isLoopbackHost] — единственное место, где он разобран (I170). До правки
/// 2026-09-19 здесь жила своя копия на четыре строки, и она уже разошлась с
/// общей: `[::1]` в скобках из URL и адрес с пробелом по краям общая считает
/// петлёй, а копия — нет. Расхождение молчаливое: «плашка не зажглась»
/// выглядит как исправная касса.
///
/// # Чего этот экран НЕ доказывает
///
/// Что чек вышел на бумаге. Он показывает байты, ушедшие в порт, и ответ
/// прибора — всё, что кассе вообще известно. Соленоида ящика и бумаги в
/// лотке касса не видит ни в каком режиме, и делать вид, что видит, было бы
/// хуже молчания.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  /// Терминал и признак «привязка смотрит на петлю» — одним запросом, потому
  /// что оба нужны до первой отрисовки вкладок.
  Future<(int, bool)> _context() async {
    final terminal = await GetIt.I<TerminalRepository>().self();
    final bindings = await GetIt.I<DeviceBindingRepository>().forTerminal(
      terminal.id,
    );
    DeviceBinding? printer;
    for (final binding in bindings) {
      if (binding.deviceClass == DeviceClass.receiptPrinter) printer = binding;
    }
    final address = printer?.parameters['ipAddress'];
    return (terminal.id, address != null && isLoopbackHost(address));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<(int, bool)>(
      future: _context(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.diagnosticsTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        // Рабочее место вкладке больше не называется: чьи задания показывать,
        // решает **касса по себе** — с тех пор, как между вкладкой и очередью
        // печати встал порт `HardwareDiagnosticsRepository` (план
        // `2026-09-19-hardware-diagnostics.md`, пункт «достижимость с
        // браузерного терминала»). Значение здесь по-прежнему считается: оно
        // нужно, чтобы найти привязку принтера для плашки эмулятора.
        final (_, onLoopback) = data;

        return DefaultTabController(
          length: 6,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.diagnosticsTitle),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              bottom: TabBar(
                tabs: [
                  Tab(
                    key: const ValueKey('diagnostics-tab-printer'),
                    text: l10n.diagnosticsTabPrinter,
                  ),
                  Tab(
                    key: const ValueKey('diagnostics-tab-drawer'),
                    text: l10n.diagnosticsTabDrawer,
                  ),
                  Tab(
                    key: const ValueKey('diagnostics-tab-scales'),
                    text: l10n.diagnosticsTabScales,
                  ),
                  Tab(
                    key: const ValueKey('diagnostics-tab-display'),
                    text: l10n.diagnosticsTabDisplay,
                  ),
                  Tab(
                    key: const ValueKey('diagnostics-tab-fiscal'),
                    text: l10n.diagnosticsTabFiscal,
                  ),
                  Tab(
                    key: const ValueKey('diagnostics-tab-payment'),
                    text: l10n.diagnosticsTabPayment,
                  ),
                ],
              ),
            ),
            body: Column(
              children: [
                if (onLoopback)
                  Container(
                    key: const ValueKey('diagnostics-emulator-banner'),
                    width: double.infinity,
                    color: AppColors.warning.withValues(alpha: 0.16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.developer_board,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l10n.diagnosticsEmulatorBanner)),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      const PrinterDiagnosticsTab(),
                      // Ящик сразу за принтером: на большинстве касс он и
                      // висит на принтере, и вопрос к ним общий.
                      const DrawerDiagnosticsTab(),
                      const ScalesDiagnosticsTab(),
                      const DisplayDiagnosticsTab(),
                      const FiscalDiagnosticsTab(),
                      // Оплата последней: её пометка эмулятора — своя, по
                      // адресу провайдера, и к привязке принтера над
                      // вкладками отношения не имеет.
                      const PaymentDiagnosticsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
