import 'dart:async';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTroubleKind;
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/payment/widgets/account_selector.dart';
import 'package:telepos/presentation/screens/payment/widgets/denomination_grid.dart';
import 'package:telepos/presentation/screens/payment/widgets/iin_input.dart';
import 'package:telepos/presentation/screens/payment/widgets/loyalty_panel.dart';
import 'package:telepos/presentation/screens/payment/widgets/offsets_panel.dart';
import 'package:telepos/presentation/screens/payment/widgets/payment_amount_panel.dart';
import 'package:telepos/presentation/screens/payment/widgets/qr_panel.dart';
import 'package:telepos/presentation/common/widgets/keyboards/payment_num_pad.dart';
import 'package:telepos/presentation/screens/payment/widgets/payment_type_selector.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({this.amount, this.isRefund = false, super.key});

  final Decimal? amount;

  final bool isRefund;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  /// Свой `ScaffoldMessenger` экрана оплаты — для **отказов**.
  ///
  /// # Дефект живой приёмки браузерного терминала (2026-09-13)
  ///
  /// «Рассрочка» без покупателя → «Оплатить» → отказ появился внизу окна, на
  /// затемнении, частично под карточкой — кассир его почти не видел.
  ///
  /// Измерено стендом: полосу показывал **корневой** `ScaffoldMessenger`
  /// (`MaterialApp` над навигатором, один на все маршруты), а рисовал её
  /// `Scaffold` настольной раскладки — растянутый **на всё окно**, с фоном
  /// `AppColors.modalOverlay`. Карточка оплаты — лишь `Center` в его теле, и
  /// полоса ложилась к низу окна: вне карточки, на затемнение и — на окне
  /// 1920×937 — прямо на кнопку «Оплатить».
  ///
  /// # Как устроено теперь
  ///
  /// Настольная раскладка держит этот `ScaffoldMessenger` и свой `Scaffold`
  /// **внутри карточки**, с подвалом как `bottomNavigationBar`: отказ
  /// показывается в карточке, над «Оплатить». Планшетная и узкая — вокруг
  /// своего `Scaffold`, там он и так на всё окно. Отказы из виджетов
  /// раскладки (`PaymentTypeSelector`, панели зачётов и QR) находят этот
  /// `ScaffoldMessenger` сами — по своему контексту; отказы, которые
  /// показывает само состояние (`_refusalMessenger`), — через ключ: контекст
  /// состояния стоит **над** раскладкой и нашёл бы корневой.
  ///
  /// # Чего сюда не переносится
  ///
  /// Сообщения **об успехе** и о бедах железа (`_onPaymentRecorded`). Они
  /// показываются перед уходом с экрана и читаются уже на продаже, а этот
  /// `ScaffoldMessenger` уходит вместе с маршрутом. Они по-прежнему берут
  /// корневой — `ScaffoldMessenger.of(context)` контекста состояния.
  final _refusals = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final Decimal amount = widget.amount ?? ref.read(saleTotalProvider);
      ref.read(paymentControllerProvider.notifier).initialize(amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    ref.listen<PaymentState>(paymentControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error && mounted) {
        // Новый отказ **вытесняет** прежнюю полосу, а не ждёт в очереди за
        // ней: приёмка 2026-09-17 видела ответ кассы с опозданием на
        // секунды — кассир успевал нажать ещё раз.
        _refusalMessenger()
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              // Ключ, а не фраза, — так здесь было до задачи 23: экран
              // печатал `PaymentState.error` сырьём, и `ErrorLocalizer` во
              // всём каталоге оплаты не звался ни разу. Регресса задача не
              // внесла, но и заголовок её («на его языке») на этом пути не
              // выполнялся: `PaymentNotifier.processPayment` кладёт сюда
              // `saleController.error`, то есть с задачи 23 — именно ключ
              // отказа кассы, и кассир читал бы `error.shift_not_open`
              // буквально во всех пяти локалях.
              content: Text(ErrorLocalizer.localize(context, next.error!)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
      }
    });

    if (isDesktop) {
      // Настольная держит `_refusals` сама — внутри карточки.
      return _DesktopLayout(
        refusals: _refusals,
        isRefund: widget.isRefund,
        onComplete: _handleComplete,
        onCancel: _handleCancel,
      );
    }

    if (isTablet) {
      return ScaffoldMessenger(
        key: _refusals,
        child: _TabletLayout(
          isRefund: widget.isRefund,
          onComplete: _handleComplete,
          onCancel: _handleCancel,
        ),
      );
    }

    return ScaffoldMessenger(
      key: _refusals,
      child: _MobileLayout(
        isRefund: widget.isRefund,
        onComplete: _handleComplete,
        onCancel: _handleCancel,
      ),
    );
  }

  Future<void> _handleComplete() async {
    final notifier = ref.read(paymentControllerProvider.notifier);
    final preState = ref.read(paymentControllerProvider);

    if (preState.isProcessing) return;
    // **Признак обработки ставится до всего остального** (круг правки 5).
    // Он стоял только перед `processPayment`, то есть кнопка жила весь
    // обмен с устройством, а сторож строкой выше читал тот же ложный
    // признак: два нажатия подряд давали **два настоящих списания**
    // (`terminal.calls == [50000, 50000]`). Круг 3 поднял цену — эквайринг
    // зовётся теперь и в смешанной оплате, и в долге.
    //
    // Кнопка гаснет тем же признаком (`PaymentState.canComplete`), так что
    // защита двойная: и виджет, и сторож.
    notifier.setProcessing(true);
    var popped = false;
    try {
      await _handleCompleteInner(notifier, preState, () => popped = true);
    } finally {
      if (!popped && mounted) notifier.setProcessing(false);
    }
  }

  Future<void> _handleCompleteInner(
    PaymentNotifier notifier,
    PaymentState preState,
    void Function() markPopped,
  ) async {
    // **Предел, названный замером (круг правки 4):** `widget.isRefund`
    // нигде в дереве не выставляется в истину — `PaymentScreen` заводится
    // только из продажи (`sale_screen.dart`), возврат ходит своим экраном.
    // То есть условие ниже сегодня ничего не охраняет, и ветка возврата
    // этого экрана — мёртвая. Не снята: возврат оплаченного картой чека
    // рано или поздно придёт сюда же, и снять условие сейчас значит
    // завести дефект тогда.
    //
    // Эквайринг зовётся при **любой** безналичной части, а не только при
    // чистой карте (круг правки 3 задачи 14). Касса требует
    // доказательства проведения на всю безналичную часть, и пока экран
    // звал терминал только для карты, смешанная оплата и долг с картой на
    // кассе с привязанным Kaspi отвергались `card_charge_unproven` — то
    // есть не работали вовсе.
    if (!widget.isRefund && preState.cardPortion > Decimal.zero) {
      final terminalResult = await notifier.chargeCardViaTerminal(
        preState.cardPortion,
      );

      if (terminalResult.isDeclined) {
        if (mounted) {
          _refusalMessenger()
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                // Через словарь, как `PaymentState.error` выше: отказ кассы
                // приходит ключом (`PaymentNotifier.chargeCardViaTerminal`).
                // Текст отказа от самого устройства словарь не узнаёт и
                // возвращает как есть — он и так написан для человека.
                content: Text(
                  terminalResult.message == null
                      ? AppLocalizations.of(context)!.kaspiNoConnection
                      : ErrorLocalizer.localize(
                          context,
                          terminalResult.message!,
                        ),
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
        }
        return;
      }
    }

    final success = await notifier.processPayment();

    if (success && mounted) {
      // Признак уже поднят в `_handleComplete` — здесь он держится до
      // ухода с экрана, чтобы кнопка не ожила между записью денег и
      // навигацией.
      await _onPaymentRecorded(notifier, notifier.lastOutcome);
      markPopped();
    }
  }

  /// Оплата записана — сказать кассиру и уйти с экрана.
  ///
  /// # Чего здесь больше нет (задача 16)
  ///
  /// Печати чека и денежного ящика. Оба жили тут — `_printSaleReceipt`
  /// собирал чек из состояния экрана и звал очередь печати,
  /// `_openCashDrawer` открывал ящик через последовательный порт с
  /// запасным путём через принтер. Оба ушли на кассу
  /// (`LocalPaymentService`), и это не перестановка ради порядка:
  /// решение заказчика №1 говорит, что терминал продаёт полностью, но
  /// **железо и база остаются кассой**, а у вкладки браузера нет ни
  /// принтера, ни ящика, ни `AppDatabase`, из которого этот экран читал
  /// реквизиты чека.
  ///
  /// Правило «оплата не ждёт железа» переехало вместе с ними и стало
  /// строже: касса отправляет печать, а не ожидает её, потому что по
  /// проводу к задержке принтера прибавилась бы ещё и сеть.
  ///
  /// # Что здесь вернулось (круг правки 1)
  ///
  /// Первая редакция задачи 16 унесла вместе с печатью **и сигнал о её
  /// отказе**: оранжевое «Ошибка печати» показывалось и при отказе
  /// очереди, и при исключении, а после переноса не осталось ничего,
  /// кроме строки в журнале. Это была не «названная граница», а снятая
  /// обратная связь. Сигнал возвращён и остался тем же по виду —
  /// оранжевый снек на том же `ScaffoldMessenger`.
  ///
  /// Порядок сохранён от прежнего кода: сообщение берётся **до** ухода
  /// с экрана, а `ScaffoldMessenger` живёт выше маршрута и переживает
  /// его. Ожидание бед железа уходит `unawaited` — оплата их не ждёт, их
  /// ждёт только снек.
  Future<void> _onPaymentRecorded(
    PaymentNotifier notifier,
    SaleOutcome? outcome,
  ) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    // Красный — **роль из темы**, а не константа: `AppColors.error`
    // одинаков в светлой и тёмной, и в ночной теме полоса вышла бы
    // нечитаемой. Сторож `no_baked_theme_colors_test` это и поймал.
    final errorColor = Theme.of(context).colorScheme.error;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.isRefund ? l10n.refundSuccess : l10n.paymentSuccessMessage,
        ),
        backgroundColor: AppColors.success,
      ),
    );

    // Деньги взяты, чек не фискален. Не отказ оплаты — предупреждение:
    // разбор решения в докстринге `SaleOutcome.fiscal`.
    if (outcome != null && outcome.fiscal.isFailed) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.paymentNotFiscalized),
          backgroundColor: AppColors.warning,
        ),
      );
    }

    // Касса собрана без узла фискализации (задача 5) — **красная полоса**,
    // и на каждой продаже.
    //
    // Разница с `operatorAbsent` здесь и есть весь смысл разделения:
    //
    // * ненастроенный оператор — **выбор владельца**, положение штатное, и
    //   окно на каждой продаже кассир отучится замечать за день. Его место
    //   — строка в подвале чека (`noFiscalDocumentReason`), а на этом
    //   экране он не показывается вовсе;
    // * отсутствующий узел — **сломанная сборка**. Никто её не выбирал,
    //   настройками она не лечится, и молчать о ней нельзя: касса берёт
    //   деньги и не может выдать документ ни одному чеку.
    if (outcome != null && outcome.fiscal.isModuleAbsent) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.paymentFiscalModuleAbsent),
          backgroundColor: errorColor,
        ),
      );
    }

    if (outcome != null) {
      unawaited(
        _reportHardwareTroubles(notifier, outcome.receiptNo, messenger, {
          CompletionTroubleKind.print: l10n.printerPrintError,
          CompletionTroubleKind.drawer: l10n.cashDrawerOpenError,
        }),
      );
    }

    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go(AppRoutes.sale);
    }
  }

  /// Оранжевый снек о том, что железо не сработало, — после успеха
  /// оплаты и уже без экрана.
  ///
  /// **Заголовок берётся по виду беды** (круг правки 2). Первая редакция
  /// подписывала «Ошибкой печати» всё подряд, и отказ ящика читался как
  /// «Ошибка печати: денежный ящик не открылся» — сообщение, которое
  /// само себе противоречит.
  Future<void> _reportHardwareTroubles(
    PaymentNotifier notifier,
    int receiptNo,
    ScaffoldMessengerState messenger,
    Map<CompletionTroubleKind, String> titles,
  ) async {
    try {
      final troubles = await notifier.hardwareTroubles(receiptNo);
      for (final trouble in troubles) {
        final title = titles[trouble.kind];
        messenger.showSnackBar(
          SnackBar(
            // Заголовок — словарный, подпись — причина сверх него: «бумаги
            // нет», «порт занят». Выбрасывать её нельзя, она и говорит
            // кассиру, что делать.
            //
            // Пустая подпись означает «сверх заголовка сказать нечего»:
            // касса отказала ящиком чисто, без причины. Прежде там стоял
            // дословный повтор заголовка ПО-РУССКИ, и на английской кассе
            // выходило «Cash drawer did not open: денежный ящик не
            // открылся» — поймано пробным проходом главы 7.
            content: Text(
              title == null
                  ? trouble.message
                  : (trouble.message.isEmpty
                        ? title
                        : '$title: ${trouble.message}'),
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (_) {
      // Спросить не удалось — оплата от этого не становится неудачной, и
      // ронять снек-сообщение поверх ушедшего экрана незачем.
    }
  }

  /// Куда показывать отказ оплаты — см. [_refusals].
  ///
  /// Корневой — только до первой сборки раскладки, когда ключ ещё не
  /// привязан; отказов в этот миг не бывает, но упасть здесь хуже, чем
  /// показать не там.
  ScaffoldMessengerState _refusalMessenger() =>
      _refusals.currentState ?? ScaffoldMessenger.of(context);

  void _handleCancel() {
    if (context.canPop()) {
      context.pop(false);
    } else {
      context.go(AppRoutes.sale);
    }
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout({
    required this.refusals,
    required this.isRefund,
    required this.onComplete,
    required this.onCancel,
  });

  /// `ScaffoldMessenger` отказов — ставится внутрь карточки
  /// (`_PaymentScreenState._refusals`).
  final GlobalKey<ScaffoldMessengerState> refusals;

  final bool isRefund;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(paymentControllerProvider);

    final screenSize = MediaQuery.sizeOf(context);
    final screenH = screenSize.height;
    final cardMaxH = screenH >= 900
        ? (screenH - 48 > 920 ? 920.0 : screenH - 48)
        : math.min(768.0, screenH - 32);
    final cardWidth = math.min(780.0, screenSize.width - 48);

    return Scaffold(
      backgroundColor: AppColors.modalOverlay,
      body: Center(
        child: Container(
          key: const Key('payment_card'),
          width: cardWidth,
          constraints: BoxConstraints(maxHeight: cardMaxH),
          margin: const EdgeInsets.all(AppTheme.spacingLarge),
          // Полоса отказа живёт теперь внутри карточки — скругление обязано
          // резать и её.
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.semantic.canvas,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          // Отказы — в карточке, над подвалом (`_PaymentScreenState._refusals`).
          //
          // Отступы окна снимаются: карточка стоит посреди внешнего
          // `Scaffold`, который их уже учёл, и второй учёт сдвинул бы подвал.
          // Клавиатуру по той же причине отрабатывает внешний, а не этот.
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            removeTop: true,
            removeRight: true,
            removeBottom: true,
            child: ScaffoldMessenger(
              key: refusals,
              child: Scaffold(
                backgroundColor: context.semantic.canvas,
                resizeToAvoidBottomInset: false,
                body: Column(
                  children: [
                    _Header(
                      title: isRefund ? l10n.refundTitle : l10n.paymentTitle,
                      amount: state.totalAmount,
                      color: isRefund ? AppColors.warning : AppColors.primary,
                      onClose: onCancel,
                    ),

                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacing),
                              child: Column(
                                children: [
                                  const PaymentTypeSelector(),
                                  const SizedBox(height: AppTheme.spacing),
                                  const PaymentAmountPanel(),
                                  const SizedBox(height: AppTheme.spacing),
                                  if (state.paymentType != PaymentType.card)
                                    const Expanded(child: _PaymentInputTabs())
                                  else
                                    const Spacer(),
                                ],
                              ),
                            ),
                          ),

                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(AppTheme.spacing),
                              child: Column(
                                children: [
                                  const AccountSelector(),
                                  const SizedBox(height: AppTheme.spacing),
                                  const LoyaltyPanel(),
                                  const SizedBox(height: AppTheme.spacing),
                                  // Вход в зачёты — сразу под покупателем:
                                  // аванс принадлежит тому, кого нашла панель
                                  // лояльности, и читать их кассир должен
                                  // подряд.
                                  //
                                  // QR — первым из зачётов после бонуса, в том
                                  // же порядке, в каком их раскладывает касса
                                  // (`OffsetChain`): бонус → QR → сертификат →
                                  // аванс.
                                  const QrPanel(),
                                  const SizedBox(height: AppTheme.spacing),
                                  const PrepaymentPanel(),
                                  const SizedBox(height: AppTheme.spacing),
                                  const CertificatePanel(),
                                  const SizedBox(height: AppTheme.spacing),
                                  const IinInput(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Подвал — `bottomNavigationBar`, а не последний ребёнок
                // колонки: плавающую полосу `Scaffold` ставит **над** ним,
                // и отказ не ложится на «Оплатить».
                bottomNavigationBar: _Footer(
                  canComplete: state.canComplete,
                  isProcessing: state.isProcessing,
                  isRefund: isRefund,
                  onComplete: onComplete,
                  onCancel: onCancel,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabletLayout extends ConsumerWidget {
  const _TabletLayout({
    required this.isRefund,
    required this.onComplete,
    required this.onCancel,
  });

  final bool isRefund;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(paymentControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isRefund ? l10n.refundTitle : l10n.paymentTitle),
        backgroundColor: isRefund ? AppColors.warning : AppColors.primary,
        foregroundColor: isRefund ? AppColors.black : AppColors.white,
        leading: IconButton(
          icon: const Icon(TeleposIcons.close),
          onPressed: onCancel,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
            child: Center(
              child: Text(
                '${state.totalAmount}',
                style: AppTextStyles.h2.copyWith(
                  color: isRefund ? AppColors.black : AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing),
              child: Column(
                children: [
                  const PaymentTypeSelector(),
                  const SizedBox(height: AppTheme.spacing),
                  const PaymentAmountPanel(),
                  const SizedBox(height: AppTheme.spacing),
                  if (state.paymentType != PaymentType.card)
                    const Expanded(child: _PaymentInputTabs())
                  else
                    const Spacer(),
                ],
              ),
            ),
          ),

          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacing),
              child: Column(
                children: [
                  const AccountSelector(),
                  const SizedBox(height: AppTheme.spacing),
                  const LoyaltyPanel(),
                  const SizedBox(height: AppTheme.spacing),
                  const QrPanel(),
                  const SizedBox(height: AppTheme.spacing),
                  const PrepaymentPanel(),
                  const SizedBox(height: AppTheme.spacing),
                  const CertificatePanel(),
                  const SizedBox(height: AppTheme.spacing),
                  const IinInput(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _Footer(
        canComplete: state.canComplete,
        isProcessing: state.isProcessing,
        isRefund: isRefund,
        onComplete: onComplete,
        onCancel: onCancel,
      ),
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({
    required this.isRefund,
    required this.onComplete,
    required this.onCancel,
  });

  final bool isRefund;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(paymentControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isRefund ? l10n.refundTitle : l10n.paymentTitle),
            Text(
              '${state.totalAmount}',
              style: context.styles.caption.copyWith(
                color: isRefund
                    ? AppColors.black.withValues(alpha: 0.7)
                    : AppColors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        backgroundColor: isRefund ? AppColors.warning : AppColors.primary,
        foregroundColor: isRefund ? AppColors.black : AppColors.white,
        leading: IconButton(
          icon: const Icon(TeleposIcons.close),
          onPressed: onCancel,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          children: [
            const PaymentTypeSelector(),
            const SizedBox(height: AppTheme.spacing),
            const PaymentAmountPanel(),
            const SizedBox(height: AppTheme.spacing),
            const DenominationRow(),
            const SizedBox(height: AppTheme.spacing),
            const AccountSelector(),
            const SizedBox(height: AppTheme.spacing),
            const LoyaltyPanelCompact(),
            const SizedBox(height: AppTheme.spacing),
            const OffsetsPanelCompact(),
            const SizedBox(height: AppTheme.spacing),
            const IinInputCompact(),
            if (state.paymentType != PaymentType.card) ...[
              const SizedBox(height: AppTheme.spacing),
              const _PaymentNumPadSection(),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _FooterCompact(
        canComplete: state.canComplete,
        isProcessing: state.isProcessing,
        change: state.change,
        isRefund: isRefund,
        onComplete: onComplete,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.amount,
    required this.color,
    required this.onClose,
  });

  final String title;
  final Decimal amount;
  final Color color;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.borderRadiusLarge),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(TeleposIcons.close),
            color: AppColors.white,
          ),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.h2.copyWith(color: AppColors.white)),
          const Spacer(),
          Text(
            '$amount',
            style: AppTextStyles.h1.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.canComplete,
    required this.isProcessing,
    required this.isRefund,
    required this.onComplete,
    required this.onCancel,
  });

  final bool canComplete;
  final bool isProcessing;
  final bool isRefund;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.borderRadiusLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isProcessing ? null : onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing),
              ),
              child: Text(l10n.globalCancel),
            ),
          ),
          const SizedBox(width: AppTheme.spacing),

          Expanded(
            flex: 2,
            child: ElevatedButton(
              // Ключ заведён кругом правки 3: без него проба «эквайринг
              // зовётся при смешанной оплате» пришлось бы писать поверх
              // контракта, а расхождение было именно между экраном и
              // контрактом — такая проба его снова не увидела бы.
              key: const Key('payment_complete'),
              onPressed: canComplete && !isProcessing ? onComplete : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRefund
                    ? AppColors.warning
                    : AppColors.success,
                foregroundColor: isRefund ? AppColors.black : AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing),
                disabledBackgroundColor: context.semantic.canvas,
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isRefund
                          ? l10n.paymentRefundButton
                          : l10n.paymentPayButton,
                      style: AppTextStyles.h3.copyWith(
                        color: isRefund ? AppColors.black : AppColors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentInputTabs extends StatelessWidget {
  const _PaymentInputTabs();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payments_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text(l10n.paymentDenominations),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.dialpad, size: 18),
                      const SizedBox(width: 6),
                      Text(l10n.paymentNumpad),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          const Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(child: DenominationGrid()),
                SingleChildScrollView(child: _PaymentNumPadSection()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentNumPadSection extends ConsumerWidget {
  const _PaymentNumPadSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activeInput = ref.watch(
      paymentControllerProvider.select((s) => s.activeInput),
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dialpad,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(l10n.paymentNumpad, style: AppTextStyles.h3),
              const Spacer(),
              Text(
                activeInput == PaymentInputField.cash
                    ? l10n.paymentTypeCash
                    : l10n.paymentTypeCard,
                style: context.styles.caption.copyWith(
                  color: activeInput == PaymentInputField.cash
                      ? AppColors.paymentCash
                      : AppColors.paymentCard,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing),
          Center(
            child: CompactPaymentNumPad(
              onKeyPressed: (key) =>
                  ref.read(paymentControllerProvider.notifier).numpadKey(key),
              onBackspace: () => ref
                  .read(paymentControllerProvider.notifier)
                  .numpadBackspace(),
              onClear: () =>
                  ref.read(paymentControllerProvider.notifier).numpadClear(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterCompact extends StatelessWidget {
  const _FooterCompact({
    required this.canComplete,
    required this.isProcessing,
    required this.change,
    required this.isRefund,
    required this.onComplete,
  });

  final bool canComplete;
  final bool isProcessing;
  final Decimal change;
  final bool isRefund;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (change > Decimal.zero)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.paymentChangeLabel}:',
                      style: context.styles.caption,
                    ),
                    Text(
                      '$change',
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              flex: change > Decimal.zero ? 1 : 2,
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  key: const Key('payment_complete'),
                  onPressed: canComplete && !isProcessing ? onComplete : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRefund
                        ? AppColors.warning
                        : AppColors.success,
                    foregroundColor: isRefund
                        ? AppColors.black
                        : AppColors.white,
                    disabledBackgroundColor: context.semantic.canvas,
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isRefund
                              ? l10n.paymentRefundButton
                              : l10n.paymentPayButton,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
