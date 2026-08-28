import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/help/help_button.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/common/widgets/language_switcher.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:telepos/presentation/screens/auth/widgets/pin_display.dart';
import 'package:telepos/presentation/screens/auth/widgets/pin_keypad.dart';
import 'package:telepos/presentation/screens/auth/widgets/user_selector.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(loginControllerProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final notifier = ref.read(loginControllerProvider.notifier);
    final state = ref.read(loginControllerProvider);

    if (state.selectedUser != null && state.userHasNoPassword) return;

    final key = event.logicalKey;

    if (key.keyId >= LogicalKeyboardKey.digit0.keyId &&
        key.keyId <= LogicalKeyboardKey.digit9.keyId) {
      final digit = (key.keyId - LogicalKeyboardKey.digit0.keyId).toString();
      notifier.addDigit(digit);
      return;
    }

    if (key.keyId >= LogicalKeyboardKey.numpad0.keyId &&
        key.keyId <= LogicalKeyboardKey.numpad9.keyId) {
      final digit = (key.keyId - LogicalKeyboardKey.numpad0.keyId).toString();
      notifier.addDigit(digit);
      return;
    }

    if (key == LogicalKeyboardKey.backspace) {
      notifier.removeDigit();
      return;
    }

    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.escape) {
      notifier.clearPin();
      return;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      notifier.attemptLogin();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final layoutType = Breakpoints.of(context);
    final orientation = MediaQuery.orientationOf(context);

    ref.listen<LoginState>(loginControllerProvider, (prev, next) {
      if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
        final route = ref
            .read(loginControllerProvider.notifier)
            .getPostLoginRoute();
        context.go(route);
      }
    });

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.needsEnrolmentCode
                  ? const _EnrolmentGate()
                  : _buildContent(layoutType, orientation, state),
              Positioned(
                top: 4,
                right: 4,
                child: HelpButton(
                  screenId: 'login',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.push(AppRoutes.networkSettings),
                      icon: const Icon(Icons.wifi, size: 20),
                      label: Text(AppLocalizations.of(context)!.navNetwork),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    LanguageSwitcher(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    LayoutType layoutType,
    Orientation orientation,
    LoginState state,
  ) {
    final isLandscape = orientation == Orientation.landscape;
    final isWide = layoutType.isDesktop || (layoutType.isTablet && isLandscape);

    if (isWide) {
      return _DesktopLoginLayout(state: state);
    } else {
      return _MobileLoginLayout(state: state);
    }
  }
}

class _DesktopLoginLayout extends ConsumerWidget {
  const _DesktopLoginLayout({required this.state});

  final LoginState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(loginControllerProvider.notifier);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        margin: const EdgeInsets.all(AppTheme.spacingLarge),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    if (state.sessionEndedReason != null) ...[
                      const SizedBox(height: AppTheme.spacing),
                      _SessionEndedBanner(reasonKey: state.sessionEndedReason!),
                    ],
                    const SizedBox(height: AppTheme.spacingLarge),

                    Expanded(
                      child: UserSelector(
                        users: state.users,
                        selectedUser: state.selectedUser,
                        onUserSelected: notifier.selectUser,
                      ),
                    ),

                    if (state.selectedUser != null && state.userHasNoPassword)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spacing),
                        child: _buildLoginButton(context, notifier, state),
                      ),

                    if (state.selectedUser != null) ...[
                      const SizedBox(height: AppTheme.spacing),
                      _buildShiftStatus(context, state),
                    ],
                  ],
                ),
              ),
            ),

            const VerticalDivider(width: 1, thickness: 1),

            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingLarge),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PinDisplayLarge(
                        enteredCount: state.enteredPin.length,
                        maxLength: LoginState.minPinLength,
                        errorMessage: state.error != null
                            ? ErrorLocalizer.localize(context, state.error!)
                            : null,
                      ),
                      const SizedBox(height: AppTheme.spacingLarge),

                      PinKeypad(
                        onKeyPressed: notifier.addDigit,
                        onBackspace: notifier.removeDigit,
                        onClear: notifier.clearPin,
                        enabled:
                            !(state.selectedUser != null &&
                                state.userHasNoPassword),
                      ),

                      if (state.selectedUser != null &&
                          !state.userHasNoPassword &&
                          state.isPinComplete) ...[
                        const SizedBox(height: AppTheme.spacing),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: notifier.attemptLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.white,
                              minimumSize: const Size(
                                double.infinity,
                                AppTheme.buttonHeight,
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.loginEnter,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.point_of_sale,
                color: AppColors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.loginEnterSystem,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginButton(
    BuildContext context,
    LoginNotifier notifier,
    LoginState state,
  ) {
    return ElevatedButton(
      onPressed: state.selectedUser != null ? notifier.attemptLogin : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, AppTheme.buttonHeightLarge),
      ),
      child: Text(AppLocalizations.of(context)!.loginWithoutPin),
    );
  }

  Widget _buildShiftStatus(BuildContext context, LoginState state) {
    final isOpened = state.isShiftOpened;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: isOpened
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        border: Border.all(
          color: isOpened ? AppColors.success : AppColors.warning,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpened ? Icons.lock_open : TeleposIcons.lock,
            size: 16,
            color: isOpened ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 8),
          Text(
            isOpened
                ? AppLocalizations.of(context)!.loginShiftOpen
                : AppLocalizations.of(context)!.loginShiftClosed,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isOpened ? AppColors.success : AppColors.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLoginLayout extends ConsumerWidget {
  const _MobileLoginLayout({required this.state});

  final LoginState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(loginControllerProvider.notifier);

    return Column(
      children: [
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacing),
            child: Column(
              children: [
                const SizedBox(height: AppTheme.spacing),

                _buildLogo(context),
                if (state.sessionEndedReason != null) ...[
                  const SizedBox(height: AppTheme.spacing),
                  _SessionEndedBanner(reasonKey: state.sessionEndedReason!),
                ],
                const SizedBox(height: AppTheme.spacingLarge),

                UserSelectorCompact(
                  users: state.users,
                  selectedUser: state.selectedUser,
                  onUserSelected: notifier.selectUser,
                ),
                const SizedBox(height: AppTheme.spacing),

                if (!(state.selectedUser != null && state.userHasNoPassword))
                  PinDisplay(
                    length: state.enteredPin.length,
                    enteredCount: state.enteredPin.length,
                    maxLength: LoginState.minPinLength,
                    hasError: state.hasError,
                  ),

                if (state.hasError) ...[
                  const SizedBox(height: AppTheme.spacingSmall),
                  Text(
                    ErrorLocalizer.localize(context, state.error!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                if (state.selectedUser != null) ...[
                  const SizedBox(height: AppTheme.spacing),
                  _buildShiftStatus(context, state),
                ],

                if (state.selectedUser != null && state.userHasNoPassword) ...[
                  const SizedBox(height: AppTheme.spacing),
                  ElevatedButton(
                    onPressed: notifier.attemptLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size(
                        double.infinity,
                        AppTheme.buttonHeight,
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.loginEnter),
                  ),
                ],
              ],
            ),
          ),
        ),

        if (!(state.selectedUser != null && state.userHasNoPassword))
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing,
              vertical: AppTheme.spacingSmall,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PinKeypadCompact(
                    onKeyPressed: notifier.addDigit,
                    onBackspace: notifier.removeDigit,
                    onClear: notifier.clearPin,
                    enabled: true,
                  ),

                  if (state.isPinComplete) ...[
                    const SizedBox(height: AppTheme.spacingSmall),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: notifier.attemptLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          minimumSize: const Size(
                            double.infinity,
                            AppTheme.buttonHeight,
                          ),
                        ),
                        child: Text(AppLocalizations.of(context)!.loginEnter),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.point_of_sale,
            color: AppColors.white,
            size: 48,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context)!.appName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          AppLocalizations.of(context)!.loginEnterSystem,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildShiftStatus(BuildContext context, LoginState state) {
    final isOpened = state.isShiftOpened;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: isOpened
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        border: Border.all(
          color: isOpened ? AppColors.success : AppColors.warning,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpened ? Icons.lock_open : TeleposIcons.lock,
            size: 16,
            color: isOpened ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 8),
          Text(
            isOpened
                ? AppLocalizations.of(context)!.loginShiftOpen
                : AppLocalizations.of(context)!.loginShiftClosed,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isOpened ? AppColors.success : AppColors.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Форма ввода кода привязки — замещает выбор кассира и PIN-панель целиком,
/// пока `LoginState.needsEnrolmentCode` истинно.
///
/// # Почему форма на этом же экране, а не отдельный маршрут или диалог
///
/// Три способа обсуждались (задача 7 плана «знакомство терминала с кассой»,
/// разбор блокера): отдельный экран (`GoRoute`), шаг перед входом
/// (отдельный `GoRoute`, к которому вела бы `redirect`), диалог поверх
/// `LoginScreen`. Выбран четвёртый вариант, буквально не заводящий
/// четвёртого способа навигации, — состояние того же `/login`, тем же
/// приёмом, каким этот экран уже переключает содержимое на
/// `state.isLoading` (`Center(CircularProgressIndicator())` вместо
/// `_buildContent`) и показывает `state.sessionEndedReason` баннером поверх
/// обычной формы. Отдельный маршрут добавил бы третий путь редиректа
/// вдобавок к `redirect` мастера настройки и входа (`setup_router.dart`) —
/// разбираться, что произошло, если человек обновит страницу посреди ввода
/// кода (сам код при этом никуда не делся бы: он живёт в `PairingInvites`
/// на кассе, а не в состоянии этого экрана). Диалог поверх формы был бы
/// лишним: под ним всё равно нечего показывать — выбор кассира без
/// заведённого терминала бессмыслен, а не просто заслонён.
///
/// # Четыре случая, которые видит человек
///
/// Управляются одним и тем же `state.needsEnrolmentCode`, но текст `state
/// .error` над полем разный:
/// - **новое устройство** — `state.error == null`, нейтральная подсказка
///   («это устройство ещё не привязано…»);
/// - **старое устройство без секрета** (терминал удалили на кассе, секрет
///   испорчен, или заведён до миграции v35→v36) — `error.terminal_secret_invalid`,
///   а не общее «попробуйте ещё раз» (пункт 7 брифа задачи 7);
/// - **неверный код** — `error.pairing_code_invalid` после нажатия
///   «Привязать» с кодом, который касса не признала (просрочен, потрачен,
///   выдуман);
/// - **обрыв провода на попытке `resume()`** (сеть моргнула, касса не
///   ответила) — `error.auth_unknown`, а не тот же нейтральный текст, что и
///   у настоящего нового устройства (БЛОКЕР пункта 4 финальной волны правок,
///   2026-08-24, `login_controller.dart`, `_resolveTerminalId`): секрет в
///   [_secretStore] цел и хранилище не тронуто, следующая попытка снова
///   предъявит его первым — человек, поверивший нейтральному тексту и
///   введший код вручную, сжёг бы годный одноразовый код и завёл вторую
///   строку терминала при живом секрете.
///
/// Форма ничего не решает сама — весь разбор причины сделан заранее,
/// `login_controller.dart`, `_resolveTerminalId`.
class _EnrolmentGate extends ConsumerStatefulWidget {
  const _EnrolmentGate();

  @override
  ConsumerState<_EnrolmentGate> createState() => _EnrolmentGateState();
}

class _EnrolmentGateState extends ConsumerState<_EnrolmentGate> {
  late final TextEditingController _controller;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(loginControllerProvider).enrolmentCode,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(loginControllerProvider.notifier);
    setState(() => _submitting = true);
    try {
      await notifier.submitEnrolmentCode();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(loginControllerProvider);

    // Код одноразовый на настоящей кассе: отказ или успех очищает
    // `state.enrolmentCode` (`login_controller.dart`), и поле обязано
    // очиститься следом, а не показывать значение, которого уже нет в
    // состоянии — иначе человек видел бы старый (уже отвергнутый) код,
    // как будто он всё ещё там.
    if (_controller.text != state.enrolmentCode) {
      _controller.text = state.enrolmentCode;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.link, size: 40, color: AppColors.primary),
              const SizedBox(height: AppTheme.spacing),
              Text(
                l10n.enrolTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                l10n.enrolInstructions,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLarge),
              TextField(
                key: const ValueKey('enrol-code-field'),
                controller: _controller,
                autofocus: true,
                enabled: !_submitting,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
                decoration: InputDecoration(
                  labelText: l10n.enrolCodeLabel,
                  // Цвет каждому состоянию рамки отдельно — тем же приёмом,
                  // что в общем `LimitedTextField`
                  // (`common/widgets/inputs/limited_text_field.dart:113-125`).
                  //
                  // Голый `OutlineInputBorder()` здесь не «забывал цвет», а
                  // выходил из темы: `AppTheme.inputDecorationTheme`
                  // (`app_theme.dart:230-246`) нарочно ставит
                  // `InputBorder.none` всем шести границам, поэтому взять
                  // цвет было неоткуда и `BorderSide()` давал умолчание —
                  // **чёрную** линию, невидимую на тёмном фоне. Поле было
                  // рабочим, но границы не видно; найдено живой проверкой
                  // 2026-08-24.
                  //
                  // Цвета из `colorScheme`, а не из констант `AppColors`:
                  // константы одинаковы в обеих темах, и та же правка через
                  // них вернула бы ту же болезнь другой стороной (см. пункт
                  // карты про 203 запечённых тёмных цвета).
                  //
                  // Рамка спокойного состояния — `primary`, а НЕ `outline`, и
                  // это измерено, а не выбрано на глаз. Контраст с
                  // поверхностью (порог WCAG 1.4.11 для границ элементов —
                  // 3:1):
                  //
                  // | что                       | светлая | тёмная |
                  // |---------------------------|---------|--------|
                  // | `outline` (волосяная)     |   1.26  |  1.23  |
                  // | чёрная (было, умолчание)  |  21.0   |  1.5   |
                  // | `primary`                 |   3.31  |  6.22  |
                  //
                  // Волосяная линия темы порог не берёт нигде — она заведена
                  // разделять строки внутри секции, а не очерчивать
                  // единственное поле на экране-гейте. Чёрная брала порог
                  // только на светлой, и это тот самый дефект. `primary`
                  // берёт обе — и это же делает общий `LimitedTextField`.
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                      width: 2,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  errorText: state.error != null
                      ? ErrorLocalizer.localize(context, state.error!)
                      : null,
                  // `errorMaxLines` не задан по умолчанию нигде — ни в
                  // `InputDecoration`, ни в `AppTheme.inputDecorationTheme`
                  // (`app_theme.dart`) — а по умолчанию (`null`) это
                  // задокументированное поведение самого `InputDecorator`:
                  // мягкий перенос строки обрезается многоточием на первой
                  // строке (докстринг `InputDecoration.errorMaxLines` во
                  // Flutter SDK, `input_decorator.dart`). Обе причины гейта
                  // («старое устройство без секрета», «неверный код») — по
                  // два предложения, шире одной строки на ширине этого поля
                  // (420 минус отступы), и вторая (инструктивная) половина
                  // обрезалась молча — измерено живой проверкой 2026-08-24,
                  // зумом на скриншоте. Число строк — не цвет и не размер
                  // шрифта (те берутся из темы), это предел переноса; 6 —
                  // не круглое число для вида, а измеренный минимум:
                  // узбекский перевод (самый длинный из пяти) на узкой
                  // ширине поля укладывается ровно в 6 строк, 5 всё ещё
                  // обрезает (см. тест на пяти языках и двух ширинах —
                  // `test/presentation/screens/auth/login_screen_test.dart`).
                  errorMaxLines: 6,
                ),
                onChanged: (value) => ref
                    .read(loginControllerProvider.notifier)
                    .updateEnrolmentCode(value),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppTheme.spacing),
              SizedBox(
                height: AppTheme.buttonHeight,
                child: ElevatedButton(
                  key: const ValueKey('enrol-submit'),
                  onPressed:
                      !_submitting && state.enrolmentCode.trim().isNotEmpty
                      ? _submit
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text(l10n.enrolSubmit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Причина, по которой экран входа открылся сам — не по нажатию «Выйти».
///
/// Круг правок 1 (задача 5): до него `LoginState.sessionEndedReason` было
/// заведено и локализовано (`error.session_expired`/`error.session_ended`,
/// `ErrorLocalizer`), но ни один экран его не читал — человек, которого
/// выбросило, видел обычную пустую форму входа и не мог отличить «сеанс
/// истёк», «его отозвали» и «я сам вышел».
///
/// Цвет — только из `Theme.of(context).colorScheme`: `errorContainer`/
/// `onErrorContainer`, ни одной константы `AppColors.*`. Экран вокруг это
/// правило уже нарушает (`AppColors.primary`, `.textSecondary`, …) —
/// известный долг, задокументированный в самом `AppColors`
/// («Новый код обращается к `Theme.of(context)`, а не сюда»), но новый код
/// не имеет права его продолжать.
class _SessionEndedBanner extends StatelessWidget {
  const _SessionEndedBanner({required this.reasonKey});

  /// Ключ `ErrorLocalizer` — `error.session_expired`, если есть прямая
  /// улика, что срок прошёл (включая улику, пережившую F5 — второй круг
  /// задачи 7, пункт 6, 2026-08-21), или `error.session_ended`, если улики
  /// нет: отзыв владельцем и выметание по бездействию до истечения срока в
  /// данных неразличимы, и выдумывать различие, которого там нет, эта
  /// правка не пытается. Оба решаются одним местом — докстринг
  /// `LoginState.sessionEndedReason` — а не «`null` от кассы всегда значит
  /// одно и то же», как было верно только до пункта 6.
  final String reasonKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            TeleposIcons.info,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ErrorLocalizer.localize(context, reasonKey),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
