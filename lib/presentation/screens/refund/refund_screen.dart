import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/refund/recent_receipts.dart';
import 'package:telepos/domain/refund/refund_allocation.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/common/utils/session_lost_handler.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';
import 'package:telepos/presentation/screens/refund/widgets/receipt_input_dialog.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_action_buttons.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_items_list.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_items_table.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_mode_selector.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_total_panel.dart';

/// Возврат — тот же экран на кассе и на браузерном терминале.
///
/// Задача 20 плана «Продажа с браузерного терминала». До неё экран читал базу
/// в трёх местах: номер кассы для диалога чека, чек возврата на печать и
/// разнос суммы по счетам исходного чека. Ни одно из них не выполнимо в
/// браузере, и веб-сборка на этом экране не компилировалась.
///
/// Теперь возврат идёт через `RefundService` (контроллер), печать — забота
/// кассы (`LocalRefundService.complete` → `RefundReceiptPrinter`), а
/// подсказка «последние чеки» приходит через `RecentReceipts`, которого в
/// браузере пока нет — и экран говорит об этом списком «нет чеков», а не
/// отказом.
class RefundScreen extends ConsumerStatefulWidget {
  const RefundScreen({super.key});

  @override
  ConsumerState<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends ConsumerState<RefundScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Подписка на черновик поднимается **при каждом заходе**, а не один раз
    // за жизнь провайдера. Провайдер возврата живёт всю вкладку, и после
    // кончившегося сеанса его подписка оставалась мёртвой навсегда: кассир,
    // вошедший заново, видел снимок, снятый до отказа. `addPostFrameCallback`
    // — правило дерева: читать провайдер из `initState` напрямую нельзя.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(refundControllerProvider.notifier).ensureWatching());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Кончившийся сеанс уводит на вход — **до** показа любых ошибок.
    //
    // Единственная реакция на `SessionLost` в дереве (`handleSessionLost`):
    // погасить сеанс тем же путём, каким его гасит живая подписка, и уйти на
    // вход, не дожидаясь `redirect`. Тот же вызов стоит в
    // `hardware_settings_screen.dart` и `print_price_tag_dialog.dart`.
    //
    // Блокер круга правки: до этой строки контроллер превращал `SessionLost`
    // в `error.save_failed:SessionLost`, кассир читал имя типа исключения и
    // оставался на экране, где больше ничего не работало.
    ref.listen<SessionLost?>(
      refundControllerProvider.select((s) => s.sessionLost),
      (previous, next) {
        if (next == null || next == previous) return;
        if (!mounted) return;
        handleSessionLost(context, next);
      },
    );

    // Отказ показывается **каждый раз**, даже если текст тот же.
    //
    // Держится это не здесь, а в `_enqueue`: общий ход **любой** команды
    // чистит `error` перед отправкой (`clearError: true`), поэтому
    // повторный отказ приходит как переход `null → текст`, а не
    // `текст → тот же текст`, который `next == previous` проглотил бы.
    // Два нажатия подряд на одну неисправность — обычное дело, и молчание
    // на втором кассир читает как «кнопка не сработала».
    //
    // Проба: «второй такой же отказ показывается снова, а не глотается»
    // (`refund_confirm_button_test.dart`); краснеет, если снять чистку.
    ref.listen<String?>(refundControllerProvider.select((s) => s.error), (
      previous,
      message,
    ) {
      if (message == null || message == previous) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_refundErrorMessage(context, message)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;
    final isTablet = screenWidth >= 900 && screenWidth < 1200;

    if (isDesktop) {
      return _DesktopLayout(
        searchController: _searchController,
        searchFocus: _searchFocus,
        onLoadReceipt: _showReceiptDialog,
        onSearch: _focusSearch,
        onQuantity: _showQuantityDialog,
        onRefund: _handleRefund,
      );
    }

    if (isTablet) {
      return _TabletLayout(
        searchController: _searchController,
        searchFocus: _searchFocus,
        onLoadReceipt: _showReceiptDialog,
        onSearch: _focusSearch,
        onQuantity: _showQuantityDialog,
        onRefund: _handleRefund,
      );
    }

    return _MobileLayout(
      searchController: _searchController,
      searchFocus: _searchFocus,
      onLoadReceipt: _showReceiptDialog,
      onRefund: _handleRefund,
    );
  }

  /// Отказ показывается **названным**.
  ///
  /// Прежний вид этой функции возвращал `l10n.globalError` — «Ошибка» — на
  /// всё, кроме двух случаев. Возврат при этом устроен так, что отказ в нём
  /// обычен по праву: количество больше проданного, чек уже возвращён,
  /// смена закрыта, прав на возврат без чека нет. Кассир видел одно слово и
  /// не знал, что делать; текст `WireRefusal` уже написан для человека и
  /// безопасен (И144), и теперь он доезжает.
  String _refundErrorMessage(BuildContext context, String error) {
    final l10n = AppLocalizations.of(context)!;
    final code = error.split(':').first;
    switch (code) {
      case 'error.receipt_not_found':
        return l10n.refundReceiptNotFound;
      case 'error.not_authorized':
        return l10n.refundErrorNotAuthenticated;
      default:
        return ErrorLocalizer.localize(context, error);
    }
  }

  void _showReceiptDialog() async {
    // Номер кассы приезжает **со снимком возврата**: `RefundView.posId` —
    // это касса, которая ведёт черновик, и спрашивать её отдельно незачем.
    // Прежний код брал его из базы и потому работал только на кассе.
    final posId = ref.read(refundControllerProvider).posId ?? 1;

    // Подсказка «последние чеки» — необязательная. На кассе контракт
    // зарегистрирован, в браузере (пока нет своей операции провода) — нет.
    //
    // **Нехватка едет в диалог отдельным доводом, а не пустым списком.**
    // До живой приёмки задачи 21 она приезжала пустотой, неотличимой от
    // «магазин сегодня не продавал», и диалог печатал «Чеков пока нет» —
    // утверждение о данных магазина вместо утверждения о переносе. Разбор
    // и цена ошибки — в докстринге `ReceiptInputDialog.recentAvailable`.
    //
    // Отказ **живого** контракта (`catch` ниже) считается тем же, чем и
    // отсутствие: спросить не вышло, а сколько чеков у магазина на самом
    // деле, мы по-прежнему не знаем. Соврать «ноль» здесь так же нельзя.
    var recentAvailable = GetIt.I.isRegistered<RecentReceipts>();
    var recent = const <RecentReceipt>[];
    if (recentAvailable) {
      try {
        recent = await GetIt.I<RecentReceipts>().recent(limit: 30);
      } catch (e) {
        talker.warning('Refund: recent receipts unavailable: $e');
        recentAvailable = false;
      }
    }

    if (!mounted) return;

    final result = await ReceiptInputDialog.show(
      context,
      availablePosIds: [posId],
      posNames: {posId: 'POS-$posId'},
      recent: recent,
      recentAvailable: recentAvailable,
    );

    if (result != null) {
      ref
          .read(refundControllerProvider.notifier)
          .loadReceipt(result.receiptNo, result.posId);
    }
  }

  void _focusSearch() {
    final notifier = ref.read(refundControllerProvider.notifier);
    if (ref.read(refundControllerProvider).mode != RefundMode.withoutReceipt) {
      notifier.setMode(RefundMode.withoutReceipt);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _showQuantityDialog() {
    final state = ref.read(refundControllerProvider);
    if (state.selectedItem == null) return;

    final item = state.selectedItem!;
    final controller = TextEditingController(text: '${item.quantity}');

    showDialog(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl10n.globalQuantity),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: AppTextStyles.productName),
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                dl10n.refundMaxQuantity('${item.maxQuantity}'),
                style: context.styles.caption,
              ),
              const SizedBox(height: AppTheme.spacing),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: dl10n.globalQuantity,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                ),
                onSubmitted: (value) {
                  _submitQuantity(item.id, value);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(dl10n.globalCancel),
            ),
            ElevatedButton(
              onPressed: () {
                _submitQuantity(item.id, controller.text);
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.black,
              ),
              child: Text(dl10n.globalOk),
            ),
          ],
        );
      },
    ).then((_) => controller.dispose());
  }

  void _submitQuantity(String itemId, String value) {
    final quantity = Decimal.tryParse(value);
    if (quantity != null) {
      ref
          .read(refundControllerProvider.notifier)
          .updateQuantity(itemId, quantity);
    }
  }

  void _handleRefund() async {
    final state = ref.read(refundControllerProvider);
    if (!state.canRefund) return;

    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl10n.refundConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dl10n.refundSelectedCount('${state.selectedCount}')),
              const SizedBox(height: 8),
              Text(
                dl10n.refundAmountValue('${state.selectedTotal}'),
                style: AppTextStyles.h3.copyWith(color: AppColors.warning),
              ),
              // Куда уйдут деньги — **до** нажатия (задача 26). Строки
              // считает касса той же раскладкой, которой проведёт возврат.
              if (state.destinations.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(dl10n.refundDestinationsTitle),
                const SizedBox(height: 4),
                for (final d in state.destinations)
                  Text(
                    '${refundRouteLabel(dl10n, d.route)}'
                    '${d.kindName == null ? '' : ' · ${d.kindName}'}'
                    '${d.detail == null ? '' : ' · ${d.detail}'}'
                    ' — ${d.amount}',
                    key: ValueKey('refund-destination-${d.route.code}'),
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(dl10n.globalCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.black,
              ),
              child: Text(dl10n.globalConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final success = await ref
          .read(refundControllerProvider.notifier)
          .processRefund();

      if (success && mounted) {
        // Чек печатает **касса**, на той же операции, которой отдала деньги
        // (`LocalRefundService.complete` → `RefundReceiptPrinter`). Экрану
        // печатать нечем: у браузерного терминала нет ни базы чека, ни
        // принтера кассы, а собирать чек по своему состоянию значило бы
        // завести второе мнение о том, что вернули.
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.refundSuccess),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(refundControllerProvider.notifier).clear();
        // Слип новой бумажки — отдельная строка и отдельный разговор: см.
        // [_reportSlipTroubles].
        unawaited(_reportSlipTroubles(messenger, l10n));
        unawaited(_reportHardwareTroubles(messenger, l10n));
      }
    }
  }

  /// Беда ящика после возврата — **называется кассиру**.
  ///
  /// Приёмка 2026-09-17: касса открывает ящик на возврате с наличной частью
  /// и помнит беду, если он не открылся, — но экран её не спрашивал. Кассир
  /// видел «Возврат проведён» и не знал, что ящик придётся открыть ключом.
  /// Предупреждение жёлтое, а не отказ: деньги по книгам выданы.
  Future<void> _reportHardwareTroubles(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
  ) async {
    try {
      final troubles = await ref
          .read(refundControllerProvider.notifier)
          .hardwareTroubles();
      for (final _ in troubles) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.cashDrawerOpenError),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (_) {
      // Вопрос о бедах — не часть возврата: возврат уже проведён, и отказ
      // этого вопроса не имеет права выглядеть отказом возврата.
    }
  }

  /// Беда печати слипа — **называется кассиру**, а не молчит в журнале.
  ///
  /// Возврат по сертификату выпускает покупателю **новую** бумажку (решение
  /// заказчика 2026-09-16, пункт 2), и её номер вида `<исходный>-R<возврат>`
  /// живёт только на слипе. Не напечатался слип — покупатель уходит с пустыми
  /// руками, имея на кассе годный сертификат, о котором он ничего не знает.
  /// Это ровно та беда железа, которую продажа называет кассиру после оплаты
  /// (`PaymentService.hardwareTroubles`), и здесь она называется так же.
  ///
  /// **Возврата это не отменяет**: деньги отданы, сертификат выпущен и годен.
  /// Поэтому предупреждение жёлтое и отдельное, а не отказ.
  ///
  /// Порт необязателен: у браузерного терминала его нет — там печатает касса,
  /// и беду видно на её экране очереди печати.
  Future<void> _reportSlipTroubles(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
  ) async {
    if (!GetIt.I.isRegistered<CertificateSlipPrinter>()) return;
    final slips = GetIt.I<CertificateSlipPrinter>();
    try {
      // Слип **отправляется, а не ожидается** самим возвратом, поэтому здесь
      // его отправку надо дождаться — иначе беда ещё не случилась, и экран
      // прочитал бы пустоту.
      await slips.pending;
    } catch (_) {
      // `printIssued` не бросает по контракту. Но если однажды бросит,
      // собранные до того беды всё равно обязаны дойти до кассира.
    }
    for (final trouble in slips.takeTroubles()) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.certificateSlipPrintFailed(trouble.number, trouble.message),
          ),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout({
    required this.searchController,
    required this.searchFocus,
    required this.onLoadReceipt,
    required this.onSearch,
    required this.onQuantity,
    required this.onRefund,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final VoidCallback onLoadReceipt;
  final VoidCallback onSearch;
  final VoidCallback onQuantity;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(refundControllerProvider);
    final isWithoutReceipt = state.mode == RefundMode.withoutReceipt;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                const RefundModeSelector(),
                const SizedBox(height: AppTheme.spacing),

                if (isWithoutReceipt) ...[
                  _SearchField(
                    controller: searchController,
                    focusNode: searchFocus,
                    onSearch: (query) {
                      ref.read(refundControllerProvider.notifier).search(query);
                    },
                    onSelect: (result) {
                      ref
                          .read(refundControllerProvider.notifier)
                          .addProduct(result);
                      searchController.clear();
                    },
                  ),
                  const SizedBox(height: AppTheme.spacing),
                ],

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadius,
                      ),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: const RefundItemsTable(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing),

          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(
                  child: RefundActionButtons(
                    onLoadReceipt: onLoadReceipt,
                    onSearch: onSearch,
                    onQuantity: onQuantity,
                    onRefund: onRefund,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing),

                const RefundTotalPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletLayout extends ConsumerWidget {
  const _TabletLayout({
    required this.searchController,
    required this.searchFocus,
    required this.onLoadReceipt,
    required this.onSearch,
    required this.onQuantity,
    required this.onRefund,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final VoidCallback onLoadReceipt;
  final VoidCallback onSearch;
  final VoidCallback onQuantity;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(refundControllerProvider);
    final isWithoutReceipt = state.mode == RefundMode.withoutReceipt;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 65,
            child: Column(
              children: [
                const RefundModeSelector(),
                const SizedBox(height: AppTheme.spacing),

                if (isWithoutReceipt) ...[
                  _SearchField(
                    controller: searchController,
                    focusNode: searchFocus,
                    onSearch: (query) {
                      ref.read(refundControllerProvider.notifier).search(query);
                    },
                    onSelect: (result) {
                      ref
                          .read(refundControllerProvider.notifier)
                          .addProduct(result);
                      searchController.clear();
                    },
                  ),
                  const SizedBox(height: AppTheme.spacing),
                ],

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadius,
                      ),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: const RefundItemsTable(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing),

          Expanded(
            flex: 35,
            child: Column(
              children: [
                const RefundTotalPanel(),
                const SizedBox(height: AppTheme.spacing),

                Expanded(
                  child: RefundActionButtons(
                    onLoadReceipt: onLoadReceipt,
                    onSearch: onSearch,
                    onQuantity: onQuantity,
                    onRefund: onRefund,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({
    required this.searchController,
    required this.searchFocus,
    required this.onLoadReceipt,
    required this.onRefund,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final VoidCallback onLoadReceipt;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(refundControllerProvider);
    final isWithoutReceipt = state.mode == RefundMode.withoutReceipt;
    final isByReceipt = state.mode == RefundMode.byReceipt;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacing),
          child: Column(
            children: [
              const RefundModeSelector(),
              const SizedBox(height: AppTheme.spacing),

              if (isByReceipt)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onLoadReceipt,
                    icon: const Icon(Icons.receipt_long),
                    label: Text(l10n.refundLoadReceipt),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: AppColors.black,
                    ),
                  ),
                ),

              if (isWithoutReceipt)
                _SearchField(
                  controller: searchController,
                  focusNode: searchFocus,
                  onSearch: (query) {
                    ref.read(refundControllerProvider.notifier).search(query);
                  },
                  onSelect: (result) {
                    ref
                        .read(refundControllerProvider.notifier)
                        .addProduct(result);
                    searchController.clear();
                  },
                ),
            ],
          ),
        ),

        const Expanded(child: RefundItemsList()),

        RefundTotalPanel(compact: true, onRefund: onRefund),
      ],
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField({
    required this.controller,
    required this.onSearch,
    required this.onSelect,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final void Function(String) onSearch;
  final void Function(RefundSearchResult) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(refundControllerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: l10n.refundSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: state.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(TeleposIcons.close),
                    onPressed: () {
                      controller.clear();
                      onSearch('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
          ),
          onChanged: onSearch,
        ),

        if (state.isSearching)
          const Padding(
            padding: EdgeInsets.all(AppTheme.spacing),
            child: CircularProgressIndicator(),
          )
        else if (state.searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: state.searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = state.searchResults[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                  title: Text(result.name),
                  subtitle: result.barcode != null
                      ? Text(result.barcode!)
                      : null,
                  trailing: Text(
                    '${result.price}',
                    style: AppTextStyles.priceItem,
                  ),
                  onTap: () => onSelect(result),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Как получатель денег возврата называется кассиру — задача 26.
///
/// `switch` исчерпывающий и без `default`: новый получатель сломает сборку
/// здесь, а не приедет на экран кодом.
String refundRouteLabel(AppLocalizations l10n, RefundRoute route) =>
    switch (route) {
      RefundRoute.drawer => l10n.refundRouteDrawer,
      RefundRoute.card => l10n.refundRouteCard,
      RefundRoute.manual => l10n.refundRouteManual,
      RefundRoute.provider => l10n.refundRouteProvider,
      RefundRoute.certificate => l10n.refundRouteCertificate,
      RefundRoute.advance => l10n.refundRouteAdvance,
      RefundRoute.bonus => l10n.refundRouteBonus,
      RefundRoute.debt => l10n.refundRouteDebt,
    };
