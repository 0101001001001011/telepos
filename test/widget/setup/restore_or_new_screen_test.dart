import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_tile.dart';
import 'package:telepos/presentation/screens/setup/restore_or_new_screen.dart';

class _FakeFirstLaunch implements FirstLaunchRepository {
  _FakeFirstLaunch(this._backups);

  final List<FoundBackup> _backups;

  @override
  Future<List<FoundBackup>> findAvailableBackups() async => _backups;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

FoundBackup _backup(String posName) => FoundBackup(
  posKey: posName,
  posName: posName,
  organizationName: 'ТОО Ромашка',
  createdAt: DateTime(2026, 8, 4, 12, 30),
  messageId: 1,
  checksum: 'deadbeef',
  sizeBytes: 1024 * 1024,
);

Future<void> _pump(WidgetTester tester, List<FoundBackup> backups) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final getIt = GetIt.instance;
  if (getIt.isRegistered<FirstLaunchRepository>()) {
    getIt.unregister<FirstLaunchRepository>();
  }
  getIt.registerSingleton<FirstLaunchRepository>(_FakeFirstLaunch(backups));
  addTearDown(() => GetIt.instance.reset());

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: const RestoreOrNewScreen(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('найденные копии показаны сгруппированным списком', (
    tester,
  ) async {
    await _pump(tester, [_backup('Касса 1'), _backup('Касса 2')]);

    expect(find.byType(SettingsSection), findsWidgets);
    expect(find.byType(SettingsTile), findsNWidgets(2));
    expect(find.text('Касса 1'), findsOneWidget);
    expect(find.text('Касса 2'), findsOneWidget);
  });

  testWidgets('карточек с тенью на первом экране больше нет', (tester) async {
    // Это первый экран, который видит человек на новой кассе. Карточка с
    // рамкой и тенью здесь задавала тон всему остальному.
    await _pump(tester, [_backup('Касса 1')]);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('когда копий нет, экран говорит об этом и предлагает новую', (
    tester,
  ) async {
    await _pump(tester, []);

    expect(find.byType(SettingsTile), findsNothing);
    expect(find.text('Бэкапы не найдены'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('AppTheme.light применяется к экрану целиком', (tester) async {
    await _pump(tester, [_backup('Касса 1')]);

    // Экран не перекрашивает фон под себя: это делает тема, и потому
    // остальные экраны выглядят так же.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNull, reason: 'фон задаёт тема');
  });
}
