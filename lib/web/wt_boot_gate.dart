import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/theme/theme_mode_provider.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_unavailable_screen.dart';

/// Что показывать, пока сессии к кассе нет.
///
/// # Почему это отдельная створка, а не проверка внутри приложения
///
/// Без сессии показывать нечего: провод один, запасного пути через REST нет по
/// решению заказчика. Экран, поднявшийся без данных, был бы ровно тем белым
/// экраном, из-за которого всё это писалось, — только с рамкой и меню.
///
/// # Почему своя `MaterialApp`
///
/// `TelePosApp` — это маршрутизатор поверх привязанных договоров; поднимать его
/// ради одного экрана значило бы поднимать и маршруты, которым нечем работать.
/// Здесь нужна только тема, язык и один экран, и они здесь.
class WtBootGate extends ConsumerStatefulWidget {
  const WtBootGate({required this.link, required this.terminal, super.key});

  /// Опора, поднимающая и переподнимающая сессию.
  final WtLink link;

  /// Что показать, когда сессия есть.
  final Widget terminal;

  @override
  ConsumerState<WtBootGate> createState() => _WtBootGateState();
}

class _WtBootGateState extends ConsumerState<WtBootGate> {
  late Future<Object> _session = widget.link.session();

  void _retry() {
    // Тело блоком, а не стрелкой: стрелка вернула бы значение присваивания —
    // `Future`, — а `setState` такое отвергает во время выполнения. Поймано
    // набором 2026-08-05, статическим разбором не ловится.
    final next = widget.link.retry();
    setState(() {
      _session = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Waiting();
        }

        final outcome = snapshot.data;
        if (outcome is WtStreams) return widget.terminal;

        // `snapshot.error` не бывает по устройству `WtLink` — она отвечает
        // значением, — но если бы вдруг, молчать об этом нельзя.
        final reason = outcome is WtUnavailable
            ? outcome.reason
            : '${snapshot.error ?? 'причина не названа'}';

        return _Framed(
          child: WtUnavailableScreen(reason: reason, onRetry: _retry),
        );
      },
    );
  }
}

/// Подъём сессии — это рукопожатие QUIC, доли секунды. Ждать его молча белым
/// полем нельзя ровно по той же причине, по какой нельзя молчать об отказе.
class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return const _Framed(
      child: Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

/// Тема и язык вокруг одного экрана.
class _Framed extends ConsumerWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'TelePOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      supportedLocales: AppLocale.supportedLocales,
      locale: ref.watch(localeProvider).toLocale(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );
  }
}
