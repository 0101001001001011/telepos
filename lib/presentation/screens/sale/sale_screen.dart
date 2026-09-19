import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/presentation/common/mixins/barcode_scanner_mixin.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/sale/quick_product_catalog.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/dialogs/discount_dialog.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/sale/sale_hardware.dart';
import 'package:telepos/presentation/screens/sale/shift_close_place.dart';
import 'package:telepos/presentation/screens/sale/widgets/deferred_sales_dialog.dart';
import 'package:telepos/presentation/screens/sale/widgets/product_search.dart';
import 'package:telepos/presentation/screens/sale/widgets/quick_products_grid.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_action_buttons.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_items_list.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_items_table.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_total_panel.dart';

export 'package:telepos/presentation/screens/sale/shift_close_place.dart';

class SaleScreen extends ConsumerStatefulWidget {
  const SaleScreen({super.key, required this.shiftClose});

  /// Где закрывается смена старше суток — решает таблица маршрутов
  /// (задача 37, докстринг [ShiftClosePlace]).
  final ShiftClosePlace shiftClose;

  @override
  ConsumerState<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends ConsumerState<SaleScreen>
    with BarcodeScannerMixin {
  bool _showQuickProducts = false;

  late final SaleHardware _hardware;

  @override
  void initState() {
    super.initState();
    initBarcodeScanner();
    _hardware = SaleHardware();
    _hardware.showWelcomeOnDisplay();
  }

  @override
  void dispose() {
    disposeBarcodeScanner();
    _hardware.disposeDisplay();
    super.dispose();
  }

  @override
  void onBarcodeScanned(String barcode) {
    ref.read(saleControllerProvider.notifier).addByBarcode(barcode);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Decimal>(saleControllerProvider.select((s) => s.total), (
      previous,
      next,
    ) {
      if (next > Decimal.zero) {
        _hardware.showTotalOnDisplay(next);
      } else {
        _hardware.showWelcomeOnDisplay();
      }
    });

    // Отказ кассы обязан доехать до кассира названным (И144).
    //
    // **Что здесь было до задач 13 и 23.** Ровно ветка `kShiftOverAgeError`
    // и больше ничего. `SaleController` кладёт в `state.error` девять разных
    // ключей — `error.product_not_found:<штрихкод>`,
    // `error.till_not_configured`, `error.deferred_not_found`,
    // `error.receipt_empty`, `error.mark_required:…`,
    // `error.insufficient_stock:…`, `error.big_amount_blocked`,
    // `error.save_failed:…`, `error.search_failed:…` — и ни один из них не
    // был показан никому. Кассир видел, что ничего не произошло, и не знал
    // почему. На кассе это было плохо; на браузерном терминале, где к
    // причинам добавляются отказ права от кассы и обрыв провода, это делает
    // экран неотличимым от сломанного. Сторож словаря этого не видит по
    // построению: он доказывает, что перевод есть, а не что его показали
    // (проба — `test/presentation/screens/sale/
    // sale_refusal_reaches_screen_test.dart`).
    //
    // Перевод — `ErrorLocalizer`, тот же, которым пользуются транспорт и
    // экран агента: он разбирает `ключ:аргумент` и на неизвестный ключ
    // отдаёт сам ключ, а не пустую полосу.
    //
    // Ошибка **не сбрасывается** здесь после показа, и это не забывчивость.
    //
    // Довод задачи 23 был про соседа — `PaymentNotifier.processPayment`
    // читал `saleController.error` сразу после неудачного `completeSale`,
    // а `ref.listen` срабатывает синхронно, и сброс отсюда съел бы причину
    // раньше, чем её прочитают. **В слитом дереве этого читателя больше
    // нет**: задача 14 увела завершение оплаты за контракт
    // `PaymentService`, задача 9 удалила `SaleNotifier.completeSale`
    // вовсе, а отказ кассы кладёт в своё состояние
    // `PaymentNotifier._errorKeyOf`. Довод снят как неверный, а не оставлен
    // висеть — но решение он не держал один.
    //
    // Держит его второй: снимать отказ отсюда значило бы завести **третьего
    // снимателя**, а третий уже был измерен дефектом — см. `keepError` в
    // `SaleState.fromCart`. Законных двое, и этот слушатель не из них.
    // Первое —
    // **удавшаяся команда**: `_applyView` пересобирает состояние через
    // `SaleState.fromCart`, а тот переносит из прежнего лишь названные поля,
    // и `error` среди них нет. Второе — `_emitError`, который перед
    // повторением того же ключа пишет ноль тем же синхронным шагом; без
    // этого одинаковое значение не было бы изменением, и кассир, дважды
    // получивший тот же отказ, увидел бы его один раз.
    ref.listen<String?>(saleControllerProvider.select((s) => s.error), (
      previous,
      next,
    ) {
      if (next == kShiftOverAgeError) {
        if (previous != kShiftOverAgeError) _showShiftOverAgeDialog();
        return;
      }
      if (next == null || next == previous) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(ErrorLocalizer.localize(context, next)),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
    });

    ref.listen<String?>(saleControllerProvider.select((s) => s.warning), (
      previous,
      next,
    ) {
      if (next != null && next != previous) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.saleExpiredBatchWarning(next),
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(saleControllerProvider.notifier).clearWarning();
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;
    final isTablet = screenWidth >= 900 && screenWidth < 1200;

    if (isDesktop) {
      return _DesktopLayout(
        showQuickProducts: _showQuickProducts,
        onToggleQuickProducts: () {
          setState(() {
            _showQuickProducts = !_showQuickProducts;
          });
        },
        onPay: _handlePay,
        onQuantity: _showQuantityDialog,
        onEdit: _showEditDialog,
        onDefer: _handleDefer,
        onMark: _showMarkDialog,
        onWeigh: _handleWeigh,
        onPrintLabel: _handlePrintLabel,
        showWeigh: _hardware.isScalesConfigured,
        showPrintLabel: _hardware.isLabelPrinterConfigured,
      );
    }

    if (isTablet) {
      return _TabletLayout(
        showQuickProducts: _showQuickProducts,
        onToggleQuickProducts: () {
          setState(() {
            _showQuickProducts = !_showQuickProducts;
          });
        },
        onPay: _handlePay,
        onQuantity: _showQuantityDialog,
        onEdit: _showEditDialog,
        onDefer: _handleDefer,
        onMark: _showMarkDialog,
        onWeigh: _handleWeigh,
        onPrintLabel: _handlePrintLabel,
        showWeigh: _hardware.isScalesConfigured,
        showPrintLabel: _hardware.isLabelPrinterConfigured,
      );
    }

    return _MobileLayout(
      onPay: _handlePay,
      onQuickProducts: () => QuickProductsDialog.show(context),
      onQuantity: _showQuantityDialog,
      onEdit: _showEditDialog,
      onDefer: _handleDefer,
      onMark: _showMarkDialog,
      onWeigh: _handleWeigh,
      onPrintLabel: _handlePrintLabel,
      showWeigh: _hardware.isScalesConfigured,
      showPrintLabel: _hardware.isLabelPrinterConfigured,
    );
  }

  Future<void> _showShiftOverAgeDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final place = widget.shiftClose;
    final goToShift = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.shiftOverAgeTitle),
        // Задача 37: там, где экрана смены нет, — слова о том, где её
        // закрыть, и никакой кнопки перехода. Прежде кнопка «Закрыть смену»
        // в браузере вела в заглушку `/shift`.
        content: Text(switch (place) {
          ShiftCloseHere() => l10n.shiftOverAgeMessage,
          ShiftCloseAtTill() => l10n.shiftOverAgeCloseAtTill,
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.globalClose),
          ),
          if (place is ShiftCloseHere)
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.shiftClose),
            ),
        ],
      ),
    );
    if (goToShift != true || !mounted) return;
    if (place is ShiftCloseHere) place.open(context);
  }

  /// Уход на оплату — и полоса продажи уходит вместе с экраном.
  ///
  /// # Дефект живой приёмки браузерного терминала (2026-09-17)
  ///
  /// «Товар не найден» → полоса внизу (4 секунды) → «ОПЛАТИТЬ». Открылся
  /// экран оплаты, и **полоса осталась поверх него**, накрыв «Отмена» и
  /// «ОПЛАТИТЬ» карточки.
  ///
  /// Механизм тот же, что у дефекта самого экрана оплаты (докстринг
  /// `_PaymentScreenState._refusals`), только с другой стороны: полосу
  /// показывает **корневой** `ScaffoldMessenger` — один на все маршруты,
  /// стоящий над навигатором, — и переход на другой маршрут её не трогает.
  /// Полоса принадлежит экрану, которого кассир больше не видит.
  ///
  /// # Почему снятие здесь, а не свой `ScaffoldMessenger`, как у оплаты
  ///
  /// Потому что у экрана продажи **нет своего `Scaffold`**: он живёт телом
  /// `AdaptiveScaffold` оболочки (`app_router.dart`, `ShellRoute`), и
  /// `ScaffoldMessenger` без потомка-`Scaffold` полосу не покажет вовсе
  /// (утверждение в самом `ScaffoldMessengerState.showSnackBar`). Своя
  /// полоса потребовала бы завести здесь вложенный `Scaffold` — правку
  /// раскладки ради снятия одной полосы.
  ///
  /// # Почему снятия на уходе достаточно
  ///
  /// Вторая половина беды была бы «новый отказ продажи, пришедший, пока
  /// оплата открыта». Такого пути нет, и это измерено, а не предположено:
  /// пока открыт маршрут оплаты, `PaymentNotifier` зовёт у продажи ровно
  /// один метод — `currentTerminalId()` (`payment_controller.dart`, четыре
  /// места), а тот отказов не кладёт вовсе (`SaleNotifier._resolveTerminalId`
  /// молча возвращает `null`). Скан под диалогом до корзины тоже не доходит
  /// — его сторож стоит с приёмки 2026-09-07
  /// (`sale_scanner_under_dialog_test.dart`).
  ///
  /// `removeCurrentSnackBar`, а не `hideCurrentSnackBar`: вторая уводит
  /// полосу анимацией, и на время ухода она всё ещё лежит поверх
  /// открывающейся оплаты.
  Future<void> _handlePay() async {
    final state = ref.read(saleControllerProvider);
    if (state.isEmpty) return;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    final result = await context.push<bool>('/payment');

    if (result == true && mounted) {
      await ref.read(saleControllerProvider.notifier).startNewSale();
    }
  }

  Future<void> _handleWeigh() async {
    final state = ref.read(saleControllerProvider);
    if (state.selectedItem == null) return;

    if (!_hardware.isScalesConfigured) {
      _showQuantityDialog();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.saleWeighingPlaceItem),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final weight = await _hardware.readWeightKg();
    if (!mounted) return;

    if (weight != null && weight > Decimal.zero) {
      ref.read(saleControllerProvider.notifier).updateQuantity(weight);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.saleWeightKg('$weight')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.saleWeightReadFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _showQuantityDialog();
    }
  }

  Future<void> _handlePrintLabel() async {
    final state = ref.read(saleControllerProvider);
    final item = state.selectedItem;
    if (item == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    final error = await _hardware.printPriceLabel(
      productName: item.name,
      barcode: item.barcode ?? '',
      price: item.price,
    );
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? l10n.salePriceLabelSent),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showQuantityDialog() {
    final state = ref.read(saleControllerProvider);
    if (state.selectedItem == null) return;

    final l10n = AppLocalizations.of(context)!;
    final item = state.selectedItem!;

    showDialog(
      context: context,
      builder: (ctx) => _QuantityCalculatorDialog(
        title: '${l10n.globalQuantity}: ${item.name}',
        initialValue: item.quantity.toString(),
        onConfirm: (value) {
          final quantity = Decimal.tryParse(value);
          if (quantity != null && quantity > Decimal.zero) {
            ref.read(saleControllerProvider.notifier).updateQuantity(quantity);
          }
        },
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final state = ref.read(saleControllerProvider);
    if (state.selectedItem == null) return;

    final item = state.selectedItem!;
    // Настройки кассы, предел скидки роли и валюта — **одним ответом и до
    // открытия диалога** (задачи 18 и 44): кассир видит предел, не набрав
    // ни одной цифры, а на браузерном терминале это один круг по проводу.
    // `null` — не прочитано, и причина уже показана полосой отказа
    // (`SaleNotifier.editTerms`).
    final terms = await ref.read(saleControllerProvider.notifier).editTerms();
    if (terms == null || !mounted) return;
    final policy = terms.policy;
    // Приёмка 2026-09-17: окно правки открывалось кассиру без права на
    // скидку и обещало ему предел («до 100 %»), а запрет он узнавал только
    // после «Сохранить». Право читается из сеанса тем же путём, что у
    // кнопки «Отложенные» (`sale_action_buttons.dart`): поле скидки на
    // месте, заперто и называет причину. Цену такой кассир править может —
    // у неё своё право, поэтому окно не прячется целиком. Отказ кассы
    // (`WireGuard`, `DiscountAuthority`) остаётся защитой; это — вежливость.
    final canDiscount = ref.read(
      hasPermissionProvider(PermissionKeys.opSellDiscount),
    );

    void showBlocked() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Действие запрещено настройками POS (Настройки → Политика продаж)',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    showDialog<void>(
      context: context,
      builder: (_) => _EditItemDialog(
        itemName: item.name,
        price: item.price,
        discount: item.discount,
        subtotal: item.subtotal,
        cap: canDiscount ? terms.cap : null,
        canDiscount: canDiscount,
        currencySymbol: terms.currencySymbol,
        onSave: (price, discount) async {
          // Запрет снижения цены ниже каталожной решает **касса** на самой
          // команде (`LocalCartService._authorizePriceDecrease`, отказ
          // `denied_policy` с каталожной ценой в тексте) — на обоих фронтах.
          // Экранный предпросмотр через `KassaPriceDecreasingBlockedUseCase`
          // снят задачей 44: в браузере этой службы нет (бросок в обработчике
          // нажатия), а на кассе он был второй проверкой того же правила —
          // и сравнивал с розничной ценой там, где касса берёт оптовую.
          // Настройку кассы `editPrice` с задачи 9 ревизии 2026-09-19
          // проверяет **команда корзины** (`LocalCartService
          // ._requirePriceEditingEnabled`, отказ `denied_policy`) — на обоих
          // фронтах. До неё этот `if` был единственным её читателем во всём
          // дереве, и потому единственной защитой: с планшета цену правили
          // мимо настройки. Здесь он остался вежливостью — сказать «нельзя»
          // до отправки команды, а не после, — тем же видом, что и поле
          // скидки выше.
          if (price != null && price != item.price && !policy.editPrice) {
            showBlocked();
          } else if (price != null) {
            ref.read(saleControllerProvider.notifier).updatePrice(price);
          }

          // Задача 18: скидка приходит **с указанием, чем она задана**.
          //
          // До этого экран умел только сумму, и `setDiscountPercent`,
          // написанный со своим правом и своими пробами, не имел ни
          // одного вызывающего из интерфейса: кассир, вводя «10», имея в
          // виду проценты, отдавал десять тенге.
          //
          // Ноль — снятие скидки, а не уступка (тем же правилом, что и
          // касса: `LocalCartService._authorizeDiscount`), поэтому
          // выключенная политика «продажа со скидкой» его не блокирует —
          // иначе убрать скидку было бы нельзя ровно там, где её и
          // запретили.
          if (discount != null) {
            if (discount.value > Decimal.zero && !policy.sellInDiscount) {
              showBlocked();
            } else {
              final notifier = ref.read(saleControllerProvider.notifier);
              switch (discount.type) {
                case DiscountType.percent:
                  await notifier.setDiscountPercent(discount.value);
                case DiscountType.fixed:
                  await notifier.setDiscountAmount(discount.value);
              }
            }
          }
        },
      ),
    );
  }

  /// «Отложить» — задача 10 ревизии 2026-09-19.
  ///
  /// **Ответ дожидается, и сообщение об успехе зависит от него.** Прежняя
  /// редакция звала `deferSale()` не ожидая и показывала «Чек отложен»
  /// всегда: кассир без права `op.deferSale` получал отказ кассы
  /// (`LocalCartService.defer` его проверяет с задачи 28) — чек оставался в
  /// работе, — и тут же читал, что чек отложен. Два сообщения об одном
  /// событии, из которых верхнее врёт.
  ///
  /// Причину показывает общий слушатель `state.error` в [build] — тем же
  /// путём и тем же словарём, что и остальные девять отказов экрана. Своего
  /// текста здесь нет намеренно.
  Future<void> _handleDefer() async {
    final state = ref.read(saleControllerProvider);
    if (state.isEmpty) return;

    final held = await ref.read(saleControllerProvider.notifier).deferSale();
    if (!held || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.saleHeld),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMarkDialog() {
    final state = ref.read(saleControllerProvider);
    if (state.selectedItem == null) return;

    _showInputDialog(
      title: AppLocalizations.of(context)!.saleDataMatrix,
      initialValue: state.selectedItem!.mark ?? '',
      onSubmit: (value) {
        if (value.isNotEmpty) {
          ref.read(saleControllerProvider.notifier).setMark(value);
        }
      },
    );
  }

  void _showInputDialog({
    required String title,
    required String initialValue,
    required void Function(String) onSubmit,
  }) {
    final controller = TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
          ),
          onSubmitted: (value) {
            onSubmit(value);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.globalCancel),
          ),
          ElevatedButton(
            onPressed: () {
              onSubmit(controller.text);
              Navigator.of(context).pop();
            },
            child: Text(AppLocalizations.of(context)!.globalOk),
          ),
        ],
      ),
    ).then((_) {
      controller.dispose();
    });
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.showQuickProducts,
    required this.onToggleQuickProducts,
    required this.onPay,
    required this.onQuantity,
    required this.onEdit,
    required this.onDefer,
    required this.onMark,
    required this.onWeigh,
    required this.onPrintLabel,
    required this.showWeigh,
    required this.showPrintLabel,
  });

  final bool showQuickProducts;
  final VoidCallback onToggleQuickProducts;
  final VoidCallback onPay;
  final VoidCallback onQuantity;
  final VoidCallback onEdit;
  final VoidCallback onDefer;
  final VoidCallback onMark;
  final VoidCallback onWeigh;
  final VoidCallback onPrintLabel;
  final bool showWeigh;
  final bool showPrintLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                const ProductSearch(autofocus: true),
                const SizedBox(height: AppTheme.spacing),

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
                    child: const SaleItemsTable(),
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
                // `Flexible` + прокрутка — задача 13, «экранная клавиатура
                // не прячет итог». Правая колонка держит внизу две
                // **фиксированные** вещи: кнопку оплаты и панель итога.
                // Когда планшет поднимает клавиатуру, `Scaffold` отрезает
                // от высоты тела 300–340 точек; свободное место забирал
                // `Spacer`, а когда его не оставалось, переполнялся низ —
                // то есть итог, ради которого кассир на экран и смотрит.
                //
                // Теперь свободное место держит сама сетка действий
                // (`Expanded` + прокрутка), а не пустой `Spacer`: при
                // достатке места вид не меняется, при нехватке ужимается и
                // прокручивается сетка, а сумма остаётся на экране.
                //
                // **`Expanded`, а не `Flexible`, и это измерено живьём.**
                // Первая правка поставила `Flexible` рядом со `Spacer`. Оба
                // получают `flex: 1`, свободная высота делится пополам, а
                // `FlexFit.loose` разрешает быть **меньше** доли, но не
                // больше, — и живой прогон на 1024×768 показал сетку,
                // обрезанную на третьем ряду при пустой половине колонки
                // ниже. `Spacer` убран, `Expanded` забирает остаток целиком.
                Expanded(
                  child: SingleChildScrollView(
                    child: SaleActionButtons(
                      compact: showQuickProducts,
                      onQuickProducts: onToggleQuickProducts,
                      onDeferredList: () => _showDeferredDialog(context),
                      onQuantity: onQuantity,
                      onEdit: onEdit,
                      onDefer: onDefer,
                      onMark: onMark,
                      onWeigh: onWeigh,
                      onPrintLabel: onPrintLabel,
                      showWeigh: showWeigh,
                      showPrintLabel: showPrintLabel,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                if (showQuickProducts) ...[
                  Expanded(
                    child: QuickProductsGrid(
                      crossAxisCount: 3,
                      onClose: onToggleQuickProducts,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                _PayButtonLarge(onPressed: onPay),
                const SizedBox(height: 6),
                const SaleTotalPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _showDeferredDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const DeferredSalesDialog(),
    );
  }
}

/// Правка выбранной строки чека: цена и скидка.
///
/// # Задача 18: у скидки появился свой вход
///
/// Здесь стояли **два `TextField` подряд** — «Цена» и «Скидка», оба с
/// вольным текстом и `Decimal.tryParse` над ним. У поля скидки не было ни
/// единицы измерения, ни numpad, ни предела, ни различения процента и
/// суммы: кассир, набравший «10», имея в виду проценты, отдавал десять
/// тенге, и узнать об этом было неоткуда. Ровно поэтому
/// `SaleNotifier.setDiscountPercent` — написанный, с правом и с пробами —
/// не имел ни одного вызывающего из интерфейса.
///
/// Теперь скидка открывается [DiscountDialog]: переключатель «%/сумма»,
/// numpad, живой предпросмотр суммы и **предел роли, названный до ввода**.
/// Цена осталась здесь: у неё своё правило (запрет снижения — на кассе,
/// `denied_policy`) и свой отказ, и уносить её было бы вторым изменением под
/// видом одного.
///
/// # Как снимается скидка
///
/// Нулём. Ноль — снятие, а не уступка: так его понимает и касса
/// (`LocalCartService._authorizeDiscount`), поэтому он проходит и при
/// пределе ноль, и при выключенной политике «продажа со скидкой».
/// Закрытие [DiscountDialog] без ввода означает «ничего не менял» —
/// отличить «отменил» от «обнулил» иначе нечем.
class _EditItemDialog extends StatefulWidget {
  const _EditItemDialog({
    required this.itemName,
    required this.price,
    required this.discount,
    required this.subtotal,
    required this.cap,
    required this.canDiscount,
    required this.currencySymbol,
    required this.onSave,
  });

  final String itemName;
  final Decimal price;

  /// Скидка строки сейчас, в деньгах.
  final Decimal discount;

  /// Стоимость строки до скидки — то, от чего касса меряет предел.
  final Decimal subtotal;

  /// Предел скидки роли — из условий кассы (`SaleNotifier.editTerms`).
  final DiscountCap? cap;

  /// Есть ли у кассира право `op.sellDiscount`. Без него поле скидки
  /// заперто и называет причину, а [cap] не передаётся вовсе: предел,
  /// которым нельзя воспользоваться, — обещание, а не подсказка.
  final bool canDiscount;

  /// Валюта кассы — из тех же условий.
  final String currencySymbol;

  final void Function(Decimal? price, DiscountResult? discount) onSave;

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late final TextEditingController _priceController = TextEditingController(
    text: widget.price.toString(),
  );

  /// Скидка, назначенная в этом заходе. `null` — кассир её не трогал, и
  /// команда скидки не отправляется вовсе.
  DiscountResult? _discount;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _editDiscount() async {
    final result = await DiscountDialog.show(
      context: context,
      currentDiscount: _discount?.value,
      currentType: _discount?.type,
      cap: widget.cap,
      subtotal: widget.subtotal,
      currencySymbol: widget.currencySymbol,
    );
    if (result == null) return;
    setState(() => _discount = result);
  }

  /// Что написано в строке скидки — **и почему в процентах показана ещё и
  /// сумма**: предел кассир видит в процентах, а чек считает деньгами, и
  /// переводить одно в другое в уме ему не за что.
  String _discountText() {
    final chosen = _discount;
    if (chosen == null) return widget.discount.toString();
    if (chosen.type == DiscountType.percent) {
      return '${DiscountDialog.say(chosen.value)} % '
          '(${chosen.calculate(widget.subtotal)})';
    }
    return chosen.value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cap = widget.cap;
    final canDiscount = widget.canDiscount;

    return AlertDialog(
      title: Text('${l10n.globalEdit}: ${widget.itemName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _priceController,
            decoration: InputDecoration(
              labelText: l10n.globalPrice,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          InkWell(
            key: const Key('edit_item_discount'),
            onTap: canDiscount ? _editDiscount : null,
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.globalDiscount,
                // Предел виден и здесь, до открытия диалога: кассир
                // решает «стоит ли вообще», не открывая numpad.
                helperText: !canDiscount
                    ? l10n.saleDiscountNotPermitted
                    : cap == null
                    ? null
                    : l10n.discountLimitPercent(
                        DiscountDialog.say(cap.maxPercent),
                        cap.source,
                      ),
                helperMaxLines: canDiscount ? 2 : 4,
                enabled: canDiscount,
                suffixIcon: Icon(
                  canDiscount ? Icons.dialpad : Icons.lock_outline,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                ),
              ),
              child: Text(_discountText()),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(Decimal.tryParse(_priceController.text), _discount);
            Navigator.of(context).pop();
          },
          child: Text(l10n.globalSave),
        ),
      ],
    );
  }
}

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({
    required this.showQuickProducts,
    required this.onToggleQuickProducts,
    required this.onPay,
    required this.onQuantity,
    required this.onEdit,
    required this.onDefer,
    required this.onMark,
    required this.onWeigh,
    required this.onPrintLabel,
    required this.showWeigh,
    required this.showPrintLabel,
  });

  final bool showQuickProducts;
  final VoidCallback onToggleQuickProducts;
  final VoidCallback onPay;
  final VoidCallback onQuantity;
  final VoidCallback onEdit;
  final VoidCallback onDefer;
  final VoidCallback onMark;
  final VoidCallback onWeigh;
  final VoidCallback onPrintLabel;
  final bool showWeigh;
  final bool showPrintLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 65,
            child: Column(
              children: [
                const ProductSearch(autofocus: true),
                const SizedBox(height: AppTheme.spacing),

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
                    child: const SaleItemsTable(),
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
                // `Flexible` + прокрутка — задача 13, «экранная клавиатура
                // не прячет итог». Правая колонка держит внизу две
                // **фиксированные** вещи: кнопку оплаты и панель итога.
                // Когда планшет поднимает клавиатуру, `Scaffold` отрезает
                // от высоты тела 300–340 точек; свободное место забирал
                // `Spacer`, а когда его не оставалось, переполнялся низ —
                // то есть итог, ради которого кассир на экран и смотрит.
                //
                // Теперь свободное место держит сама сетка действий
                // (`Expanded` + прокрутка), а не пустой `Spacer`: при
                // достатке места вид не меняется, при нехватке ужимается и
                // прокручивается сетка, а сумма остаётся на экране.
                //
                // **`Expanded`, а не `Flexible`, и это измерено живьём.**
                // Первая правка поставила `Flexible` рядом со `Spacer`. Оба
                // получают `flex: 1`, свободная высота делится пополам, а
                // `FlexFit.loose` разрешает быть **меньше** доли, но не
                // больше, — и живой прогон на 1024×768 показал сетку,
                // обрезанную на третьем ряду при пустой половине колонки
                // ниже. `Spacer` убран, `Expanded` забирает остаток целиком.
                Expanded(
                  child: SingleChildScrollView(
                    child: SaleActionButtons(
                      compact: showQuickProducts,
                      onQuickProducts: onToggleQuickProducts,
                      onDeferredList: () =>
                          _DesktopLayout._showDeferredDialog(context),
                      onQuantity: onQuantity,
                      onEdit: onEdit,
                      onDefer: onDefer,
                      onMark: onMark,
                      onWeigh: onWeigh,
                      onPrintLabel: onPrintLabel,
                      showWeigh: showWeigh,
                      showPrintLabel: showPrintLabel,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                if (showQuickProducts) ...[
                  Expanded(
                    child: QuickProductsGrid(
                      crossAxisCount: 2,
                      onClose: onToggleQuickProducts,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                _PayButtonLarge(onPressed: onPay),
                const SizedBox(height: 6),
                const SaleTotalPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayButtonLarge extends ConsumerWidget {
  const _PayButtonLarge({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasItems = ref.watch(
      saleControllerProvider.select((s) => s.isNotEmpty),
    );
    final isEnabled = hasItems && onPressed != null;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: isEnabled ? AppColors.success : context.semantic.canvas,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payment,
                  size: 22,
                  color: isEnabled
                      ? AppColors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context)!.payBtn,
                  style: AppTextStyles.h3.copyWith(
                    color: isEnabled
                        ? AppColors.white
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.onPay,
    required this.onQuickProducts,
    required this.onQuantity,
    required this.onEdit,
    required this.onDefer,
    required this.onMark,
    required this.onWeigh,
    required this.onPrintLabel,
    required this.showWeigh,
    required this.showPrintLabel,
  });

  final VoidCallback onPay;
  final VoidCallback onQuickProducts;
  final VoidCallback onQuantity;
  final VoidCallback onEdit;
  final VoidCallback onDefer;
  final VoidCallback onMark;
  final VoidCallback onWeigh;
  final VoidCallback onPrintLabel;
  final bool showWeigh;
  final bool showPrintLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacing),
          child: const ProductSearch(),
        ),

        Expanded(
          child: Stack(
            children: [
              const SaleItemsList(),
              Positioned(
                right: AppTheme.spacing,
                bottom: AppTheme.spacing,
                child: SaleActionsFab(
                  onQuickProducts: onQuickProducts,
                  onQuantity: onQuantity,
                  onEdit: onEdit,
                  onDefer: onDefer,
                  onMark: onMark,
                  onWeigh: onWeigh,
                  onPrintLabel: onPrintLabel,
                  showWeigh: showWeigh,
                  showPrintLabel: showPrintLabel,
                ),
              ),
            ],
          ),
        ),

        SaleTotalPanel(compact: true, onPay: onPay),
      ],
    );
  }
}

class _QuantityCalculatorDialog extends StatefulWidget {
  const _QuantityCalculatorDialog({
    required this.title,
    required this.initialValue,
    required this.onConfirm,
  });

  final String title;
  final String initialValue;
  final void Function(String value) onConfirm;

  @override
  State<_QuantityCalculatorDialog> createState() =>
      _QuantityCalculatorDialogState();
}

class _QuantityCalculatorDialogState extends State<_QuantityCalculatorDialog> {
  String _display = '';

  @override
  void initState() {
    super.initState();
    _display = widget.initialValue;
  }

  void _onDigit(String digit) {
    setState(() {
      if (_display == '0') {
        _display = digit;
      } else {
        _display += digit;
      }
    });
  }

  void _onDot() {
    setState(() {
      if (!_display.contains('.')) {
        _display = _display.isEmpty ? '0.' : '$_display.';
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_display.isNotEmpty) {
        _display = _display.substring(0, _display.length - 1);
      }
      if (_display.isEmpty) _display = '0';
    });
  }

  void _onClear() {
    setState(() => _display = '0');
  }

  void _onConfirm() {
    widget.onConfirm(_display);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.semantic.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Text(
                _display.isEmpty ? '0' : _display,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(height: 16),

            _buildRow(['7', '8', '9', 'C']),
            const SizedBox(height: 6),
            _buildRow(['4', '5', '6', '⌫']),
            const SizedBox(height: 6),
            _buildRow(['1', '2', '3', '.']),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _CalcButton(label: '0', onTap: () => _onDigit('0')),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CalcButton(
                    label: l10n.globalCancel,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CalcButton(
                    label: 'OK',
                    backgroundColor: AppColors.primary,
                    color: Colors.white,
                    onTap: _onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      children: keys
          .map(
            (key) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: keys.indexOf(key) > 0 ? 6 : 0),
                child: _CalcButton(
                  label: key,
                  onTap: () {
                    switch (key) {
                      case 'C':
                        _onClear();
                      case '⌫':
                        _onBackspace();
                      case '.':
                        _onDot();
                      default:
                        _onDigit(key);
                    }
                  },
                  color: (key == 'C' || key == '⌫')
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CalcButton extends StatelessWidget {
  const _CalcButton({
    required this.label,
    required this.onTap,
    this.color,
    this.backgroundColor,
    this.fontSize,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color? backgroundColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize ?? 20,
              fontWeight: FontWeight.w600,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
