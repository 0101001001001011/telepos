import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/hardware_settings_screen.dart';

/// Plan 2, task 4 — И31: the fields a device section renders must come
/// from the chosen [DeviceProfile]'s declaration, never a hardcoded list
/// per model. qa-depth seed: three profiles of the *same* class with
/// genuinely different declared parameters/options, so "rendered the right
/// profile's fields" is distinguishable from "rendered something".
void main() {
  const profileA = DeviceProfile(
    id: 'test.profile.a',
    deviceClass: DeviceClass.scale,
    title: 'Весы модель А',
    protocol: DeviceProtocol.casScale,
    connectionParams: [
      DeviceConnectionParam(
        key: 'comPort',
        isRequired: true,
        description: 'COM-порт весов A',
      ),
    ],
  );
  const profileB = DeviceProfile(
    id: 'test.profile.b',
    deviceClass: DeviceClass.scale,
    title: 'Весы модель Б',
    protocol: DeviceProtocol.casScale,
    connectionParams: [
      DeviceConnectionParam(
        key: 'ipAddress',
        isRequired: true,
        description: 'IP-адрес весов Б',
      ),
      DeviceConnectionParam(
        key: 'port',
        isRequired: false,
        description: 'Порт весов Б',
      ),
    ],
  );
  const profileC = DeviceProfile(
    id: 'test.profile.c',
    deviceClass: DeviceClass.scale,
    title: 'Весы модель В',
    protocol: DeviceProtocol.casScale,
    capabilities: DeviceCapabilities(paperWidthsMm: [58, 80]),
    connectionParams: [
      DeviceConnectionParam(
        key: 'comPort',
        isRequired: true,
        description: 'COM-порт весов В',
      ),
    ],
  );
  const allProfiles = [profileA, profileB, profileC];

  // Localisation delegates are not optional here any more (plan 2b, task 3):
  // the editor's «искать»/«проверить устройство» buttons take their labels
  // from `AppLocalizations`, so a host without the delegates renders nothing
  // at all rather than rendering unlocalised text.
  Widget host(
    DeviceBindingDraft draft, {
    List<DeviceProfile> profiles = allProfiles,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Scaffold(
        body: DeviceBindingEditor(
          title: 'Тест',
          icon: Icons.scale,
          profiles: profiles,
          draft: draft,
          onChanged: () {},
        ),
      ),
    );
  }

  testWidgets("choosing profile A renders profile A's field, not profile B's", (
    tester,
  ) async {
    final draft = DeviceBindingDraft(deviceClass: DeviceClass.scale)
      ..enabled = true;
    await tester.pumpWidget(host(draft));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Весы модель А'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('param_test.profile.a_comPort')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('param_test.profile.b_ipAddress')),
      findsNothing,
    );
  });

  testWidgets(
    'switching from profile A to profile B changes the rendered fields',
    (tester) async {
      final draft = DeviceBindingDraft(deviceClass: DeviceClass.scale)
        ..enabled = true;
      await tester.pumpWidget(host(draft));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Весы модель А'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('param_test.profile.a_comPort')),
        findsOneWidget,
      );

      await tester.tap(find.text('Весы модель Б'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('param_test.profile.a_comPort')),
        findsNothing,
        reason: "profile A's field must not linger after switching",
      );
      expect(
        find.byKey(const Key('param_test.profile.b_ipAddress')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('param_test.profile.b_port')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a profile with options renders the option chips; one without does not',
    (tester) async {
      final draft = DeviceBindingDraft(deviceClass: DeviceClass.scale)
        ..enabled = true;
      await tester.pumpWidget(host(draft));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Весы модель А')); // no options declared
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('option_test.profile.c_paperWidthMm_58')),
        findsNothing,
      );

      await tester.tap(
        find.text('Весы модель В'),
      ); // options: paperWidthMm 58/80
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('option_test.profile.c_paperWidthMm_58')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('option_test.profile.c_paperWidthMm_80')),
        findsOneWidget,
      );
    },
  );

  testWidgets('typing into a parameter field writes it into the draft', (
    tester,
  ) async {
    final draft = DeviceBindingDraft(deviceClass: DeviceClass.scale)
      ..enabled = true;
    await tester.pumpWidget(host(draft));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Весы модель А'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('param_test.profile.a_comPort')),
      'COM9',
    );
    await tester.pumpAndSettle();

    expect(draft.profileId, 'test.profile.a');
    expect(draft.parameters['comPort'], 'COM9');
  });

  testWidgets('disabling the device hides the profile picker entirely', (
    tester,
  ) async {
    final draft = DeviceBindingDraft(deviceClass: DeviceClass.scale)
      ..enabled = true
      ..profileId = 'test.profile.a';
    await tester.pumpWidget(host(draft));
    await tester.pumpAndSettle();
    expect(find.text('Весы модель А'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Весы модель А'), findsNothing);
    expect(find.text('Устройство отключено.'), findsOneWidget);
    expect(
      draft.enabled,
      isFalse,
      reason: 'the switch must actually flip the draft, not just repaint',
    );
  });
}
