import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';

/// Единая реакция на [SessionLost], пойманный любой операцией провода,
/// вызванной из экрана настроек оборудования/печати — п.1 финальной волны
/// закрытия долга безопасности (2026-08-22).
///
/// # Пять копий, дословно совпадавших до этой правки
///
/// `hardware_settings_screen.dart` держал её дважды — `_handleSessionLost`
/// (катчи в `_loadBindings`/`_saveBindings`) и `_onSessionLost` (катчи в
/// `_runCheck`/`_search`) — плюс по одной копии в
/// `printer_settings_screen.dart`, `label_printer_settings_screen.dart` и
/// `print_price_tag_dialog.dart`. Тело у всех пяти было одинаковым: погасить
/// сеанс тем же путём, каким [LoginNotifier.sessionLost] уже гасит его для
/// живой подписки, и увести со сломанного экрана на вход, не дожидаясь, пока
/// это сделает `routerProvider`'s `redirect` (`app_router.dart`).
///
/// `sessions_controller.dart` (`SessionsController.revoke`/`.load`) — шестой
/// случай того же приёма, но не экранный: контроллер завёлся позже этих
/// пяти и не получил копию — четыре круга правок до него молча предполагали,
/// что переводить сюда некому, потому что копий было пять, а не одно место.
/// У контроллера нет `BuildContext` (это `Notifier`, не виджет), поэтому он
/// зовёт `LoginNotifier.sessionLost` напрямую через `ref` и полагается на
/// тот же `redirect`, а не на эту функцию — она для виджетов, где есть
/// `context`.
///
/// # `ProviderScope.containerOf`, а не захваченный `ref`
///
/// Часть вызывающих — `ConsumerState` (`ref.read` дал бы то же самое), часть
/// — плоский `State` без `ref` вовсе (`hardware_settings_screen.dart`'s
/// `_onSessionLost` и `print_price_tag_dialog.dart`, оба переиспользуют
/// `DeviceBindingEditor`/остаются плоскими намеренно — см. их докстринги).
/// Один путь через `context` работает для обоих без развилки на вызывающей
/// стороне и устраняет саму возможность разойтись, как разошлись эти пять
/// копий до этой правки.
void handleSessionLost(BuildContext context, SessionLost error) {
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(loginControllerProvider.notifier).sessionLost(error);
  if (context.mounted) context.go(AppRoutes.login);
}
