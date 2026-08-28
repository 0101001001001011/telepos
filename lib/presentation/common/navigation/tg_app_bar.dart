import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_tokens.dart';

/// Шапка оболочки: полоса 54 без тени, волосок снизу.
///
/// Внутри остаётся `AppBar`, и это не половинчатость. Собственная полоса
/// пришлось бы заново написать: безопасную зону сверху, кнопку шторки, кнопку
/// «назад» с её семантикой, `AnimatedTheme` под системную строку состояния и
/// раскладку `actions` с учётом подсказок. Переписанное повторило бы это с
/// ошибками. Материальным `AppBar` делали тень, подмешивание акцента и высота
/// 56 — они сняты в теме; здесь добавляется единственное, чего тема задать не
/// может.
///
/// Волосок задаётся **здесь, а не в теме**, потому что его толщина — один
/// физический пиксель, то есть зависит от `devicePixelRatio` экрана.
/// `ThemeData` строится без контекста и плотности не знает; угадать её значило
/// бы получить линию в два пикселя на половине касс.
class TgAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TgAppBar({required this.title, this.actions, super.key});

  final Widget title;

  final List<Widget>? actions;

  /// Высота **без** безопасной зоны: `Scaffold` прибавляет её сам, а `AppBar`
  /// сам её и вычитает. Отдать сюда высоту вместе с зоной значило бы вычесть
  /// её дважды и получить полосу тем ниже, чем толще вырез.
  @override
  Size get preferredSize => const Size.fromHeight(AppTokens.appBarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      actions: actions,
      shape: Border(
        bottom: BorderSide(
          color: context.semantic.hairline,
          width: AppTokens.hairlineOf(context),
        ),
      ),
    );
  }
}
