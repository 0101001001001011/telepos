import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/terminal/device_binding.dart';

/// Builds a parameter map that satisfies every *required* connection
/// parameter [profile] declares, so a positive-path test can validate a
/// binding without needing to know each profile's specific keys.
Map<String, String> _validParamsFor(DeviceProfile profile) => {
  for (final param in profile.connectionParams)
    if (param.isRequired) param.key: 'test-value',
};

void main() {
  test('профиль описывает модель, привязка — экземпляр', () {
    final catalog = BuiltinDeviceProfileCatalog();
    final escPos = catalog
        .forClass(DeviceClass.receiptPrinter)
        .firstWhere((p) => p.protocol == DeviceProtocol.escPos);

    expect(escPos.capabilities.paperWidthsMm, isNotEmpty);
    expect(
      escPos.toString(),
      isNot(contains('192.168')),
      reason: 'адрес принадлежит экземпляру, в профиле его быть не может',
    );
  });

  test('привязка отвергает профиль чужого класса', () {
    final catalog = BuiltinDeviceProfileCatalog();
    final scaleProfile = catalog.forClass(DeviceClass.scale).first;

    expect(
      () => DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: scaleProfile.id,
        parameters: _validParamsFor(scaleProfile),
      ).validateAgainst(catalog),
      throwsA(isA<ArgumentError>()),
      reason: 'весы, привязанные как принтер чеков, — молчаливо неверная настройка',
    );
  });

  test('неизвестный профиль отвергается, а не подменяется похожим', () {
    final catalog = BuiltinDeviceProfileCatalog();
    expect(catalog.byId('нет-такого'), isNull);
    expect(
      () => DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: 'нет-такого',
      ).validateAgainst(catalog),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('поставляемый набор покрывает каждый класс', () {
    final catalog = BuiltinDeviceProfileCatalog();
    for (final cls in DeviceClass.values) {
      expect(
        catalog.forClass(cls),
        isNotEmpty,
        reason: 'класс $cls без профилей делает устройство ненастраиваемым',
      );
    }

    // Fix round 3: "at least one profile" is not the same claim as "every
    // connection kind this product actually supports is reachable". Round 1
    // added a camera scanner but silently left the serial scanner —
    // ScannerMode.serialPort
    // (lib/presentation/common/mixins/barcode_scanner_mixin.dart) — with
    // nowhere to bind, and "поставляемый набор покрывает каждый класс" kept
    // passing throughout because it only ever checked non-emptiness. This is
    // the test that would have caught it from the start: every connection
    // kind the product supports today must have a scanner profile using it.
    // (Task 5(c) fix round 1 found that ScannerMode.serialPort has never
    // actually been reachable end to end even with a binding present —
    // BarcodeScannerMixin._attachIfKeyboardWedge returns early for any mode
    // other than keyboardWedge — a separate, still-open gap from the one
    // this test guards, which is only about a profile existing to bind to.)
    final scannerProtocols = catalog
        .forClass(DeviceClass.scanner)
        .map((p) => p.protocol)
        .toSet();
    expect(
      scannerProtocols,
      containsAll(<DeviceProtocol>[
        DeviceProtocol.hidKeyboard,
        DeviceProtocol.serialScanner,
        DeviceProtocol.cameraScan,
      ]),
      reason:
          'сканер настраиваемого класса всё ещё не значит настраиваемый '
          'сканер каждого вида подключения, который продукт умеет сегодня',
    );
  });

  // Below: tests beyond the brief's four, closing gaps the brief's set
  // leaves open (qa-depth / anti-gaps).

  test('forClass не возвращает профили других классов', () {
    // A `forClass` that ignored its argument and returned the whole catalog
    // would still pass "покрывает каждый класс" above — that test only
    // checks non-emptiness. This is the test that would catch it: every
    // profile handed back for `scale` must actually be a scale profile.
    final catalog = BuiltinDeviceProfileCatalog();
    for (final cls in DeviceClass.values) {
      final profiles = catalog.forClass(cls);
      expect(
        profiles.every((p) => p.deviceClass == cls),
        isTrue,
        reason: 'forClass($cls) вернул профиль другого класса',
      );
    }
  });

  test('несколько классов имеют больше одного профиля', () {
    // If every class had exactly one profile, "forClass returns everything"
    // and "forClass returns the right thing" would be indistinguishable by
    // length alone. At least the printer classes must offer a real choice.
    final catalog = BuiltinDeviceProfileCatalog();
    expect(catalog.forClass(DeviceClass.receiptPrinter).length, greaterThan(1));
    expect(catalog.forClass(DeviceClass.scale).length, greaterThan(1));
  });

  test('привязка на верный профиль своего класса проходит проверку', () {
    // The negative-path tests above (wrong class, unknown id) are only
    // convincing if the positive path does not also throw for some
    // unrelated reason. Every built-in profile must validate cleanly when
    // bound under its own class, given values for whatever it requires.
    final catalog = BuiltinDeviceProfileCatalog();
    for (final cls in DeviceClass.values) {
      for (final profile in catalog.forClass(cls)) {
        expect(
          () => DeviceBinding(
            deviceClass: cls,
            profileId: profile.id,
            parameters: _validParamsFor(profile),
          ).validateAgainst(catalog),
          returnsNormally,
          reason: '${profile.id} должен проходить проверку под своим классом',
        );
      }
    }
  });

  test('кириллица в названии профиля не повреждается', () {
    // Guards against mojibake / lossy encoding round-trips in the built-in
    // data literal itself, per the qa-depth seed-data requirement.
    final catalog = BuiltinDeviceProfileCatalog();
    final printer = catalog.byId('printer.escpos.80mm');
    expect(printer, isNotNull);
    expect(printer!.title, 'Чековый принтер ESC/POS 80 мм');
    expect(printer.title.runes, contains('в'.runes.first));
  });

  test('byId возвращает именно запрошенный профиль, а не первый попавшийся', () {
    // Distinguishes a correct-by-construction byId from one that ignores its
    // argument and returns catalog.first (or forClass(...).first) for any
    // id, known or not — the exact substitution failure mode the plan warns
    // against, made explicit rather than only implied by the "unknown id"
    // test.
    final catalog = BuiltinDeviceProfileCatalog();
    final all = DeviceClass.values.expand(catalog.forClass).toList();
    expect(all.length, greaterThan(1));
    for (final profile in all) {
      expect(catalog.byId(profile.id)!.id, profile.id);
    }
  });

  // Fix round 1 (И141/И142): the profile declares connection parameters,
  // the binding supplies values for them, and validation checks both
  // directions — nothing required is missing, nothing supplied is
  // unrecognised.

  test('привязка без обязательного параметра отвергается с указанием его имени', () {
    final catalog = BuiltinDeviceProfileCatalog();
    final scale = catalog.byId('scale.cas.pd2')!;
    // Precondition for the test to mean anything: the profile must actually
    // require something, or omitting it proves nothing.
    expect(scale.connectionParams.any((p) => p.isRequired), isTrue);

    expect(
      () => DeviceBinding(
        deviceClass: DeviceClass.scale,
        profileId: scale.id,
        // comPort omitted entirely.
      ).validateAgainst(catalog),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.toString(),
          'сообщение об ошибке',
          contains('comPort'),
        ),
      ),
      reason: 'весы без COM-порта — не настроенное устройство, а угадывание',
    );

    // A blank value is the same failure as an absent one — И141 says
    // "без объявленного параметра", and an empty string supplies nothing.
    expect(
      () => DeviceBinding(
        deviceClass: DeviceClass.scale,
        profileId: scale.id,
        parameters: const {'comPort': '   '},
      ).validateAgainst(catalog),
      throwsA(isA<ArgumentError>()),
      reason: 'пустая строка — не значение параметра',
    );
  });

  test('привязка с непредусмотренным параметром отвергается с указанием его имени', () {
    final catalog = BuiltinDeviceProfileCatalog();
    final scale = catalog.byId('scale.cas.pd2')!;

    expect(
      () => DeviceBinding(
        deviceClass: DeviceClass.scale,
        profileId: scale.id,
        parameters: const {'comPort': 'COM3', 'kaspiIp': '192.168.1.100'},
      ).validateAgainst(catalog),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.toString(),
          'сообщение об ошибке',
          contains('kaspiIp'),
        ),
      ),
      reason:
          'молча отброшенный параметр — то, как устройство начинает '
          'разговаривать не туда',
    );
  });

  test(
    'платёжный терминал объявляет больше одного параметра, '
    'привязка со всеми значениями проходит проверку',
    () {
      // This is the case that proves a single `address: String?` field was
      // insufficient: Kaspi needs both a host and a port.
      final catalog = BuiltinDeviceProfileCatalog();
      final kaspi = catalog.byId('payment.kaspi.pos')!;
      expect(kaspi.connectionParams.length, greaterThan(1));

      expect(
        () => DeviceBinding(
          deviceClass: DeviceClass.paymentTerminal,
          profileId: kaspi.id,
          parameters: const {'ipAddress': '192.168.1.50', 'port': '8888'},
        ).validateAgainst(catalog),
        returnsNormally,
      );

      // And the same profile still refuses a binding missing just one of
      // its two required parameters — "more than one" must mean each one
      // is actually enforced, not that the count merely looks right.
      expect(
        () => DeviceBinding(
          deviceClass: DeviceClass.paymentTerminal,
          profileId: kaspi.id,
          parameters: const {'ipAddress': '192.168.1.50'},
        ).validateAgainst(catalog),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test(
    'серийное устройство с ровно одним параметром работает на обеих '
    'границах диапазона',
    () {
      final catalog = BuiltinDeviceProfileCatalog();
      final scale = catalog.byId('scale.cas.pd2')!;
      expect(scale.connectionParams.length, 1);

      expect(
        () => DeviceBinding(
          deviceClass: DeviceClass.scale,
          profileId: scale.id,
          parameters: const {'comPort': 'COM3'},
        ).validateAgainst(catalog),
        returnsNormally,
      );
      expect(
        () => DeviceBinding(
          deviceClass: DeviceClass.scale,
          profileId: scale.id,
        ).validateAgainst(catalog),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test('профиль без параметров соединения принимает пустую привязку', () {
    // The zero end of the range: a USB HID scanner declares nothing, and an
    // empty parameter map must validate — there is nothing to be missing.
    final catalog = BuiltinDeviceProfileCatalog();
    final scanner = catalog.byId('scanner.usb.hid')!;
    expect(scanner.connectionParams, isEmpty);

    expect(
      () => DeviceBinding(
        deviceClass: DeviceClass.scanner,
        profileId: scanner.id,
      ).validateAgainst(catalog),
      returnsNormally,
    );
  });

  test('камера объявлена как отдельный протокол сканера', () {
    // Fix round 1, Fix 3: hidKeyboard cannot honestly describe software
    // reading the host's camera. Confirms the built-in catalog actually
    // ships a profile using the dedicated protocol, not just that the enum
    // value exists.
    final catalog = BuiltinDeviceProfileCatalog();
    final cameraProfiles = catalog
        .forClass(DeviceClass.scanner)
        .where((p) => p.protocol == DeviceProtocol.cameraScan);
    expect(cameraProfiles, isNotEmpty);
  });

  // Fix round 2: operator-selectable options (paper width and anything of
  // the same shape later) — declared by the profile, chosen on the binding,
  // kept apart from connection parameters because a connection detail and
  // an installed-configuration choice are not the same fact.

  test('привязка с допустимым значением опции проходит проверку', () {
    final catalog = BuiltinDeviceProfileCatalog();
    final printer = catalog.byId('printer.escpos.80mm')!;
    expect(
      printer.options.singleWhere((o) => o.key == 'paperWidthMm').allowedValues,
      containsAll(['58', '80']),
    );

    expect(
      () => DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: printer.id,
        parameters: _validParamsFor(printer),
        options: const {'paperWidthMm': '80'},
      ).validateAgainst(catalog),
      returnsNormally,
    );
  });

  test(
    'привязка с недопустимым значением опции отвергается с указанием '
    'опции и значения',
    () {
      final catalog = BuiltinDeviceProfileCatalog();
      // This model supports only 58mm — the exact "must not silently
      // accept the wrong width" case from the brief.
      final printer = catalog.byId('printer.escpos.58mm-compact')!;
      expect(
        printer.options.singleWhere((o) => o.key == 'paperWidthMm').allowedValues,
        ['58'],
      );

      expect(
        () => DeviceBinding(
          deviceClass: DeviceClass.receiptPrinter,
          profileId: printer.id,
          parameters: _validParamsFor(printer),
          options: const {'paperWidthMm': '80'},
        ).validateAgainst(catalog),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'сообщение об ошибке',
            allOf(contains('paperWidthMm'), contains('80')),
          ),
        ),
        reason: 'принтер на 58мм, тихо принявший 80 — чек выйдет не тем',
      );
    },
  );

  test(
    'printer.escpos.58mm-compact declares an optional port param, same as '
    'the 80mm profile (task 5 of plan 2b, debt d)',
    () {
      // Before this fix, this profile declared only `ipAddress` — a binding
      // to it could never carry a non-default TCP port, unlike its 80mm
      // sibling. Unreachable today (nothing binds to it via discovery yet),
      // but a real inconsistency between two profiles of the same
      // networked-ESC/POS shape.
      final catalog = BuiltinDeviceProfileCatalog();
      final printer80 = catalog.byId('printer.escpos.80mm')!;
      final printer58 = catalog.byId('printer.escpos.58mm-compact')!;

      expect(
        printer58.connectionParams.any((p) => p.key == 'port'),
        isTrue,
        reason: 'the 58mm-compact profile must be able to carry a port, '
            'exactly like the 80mm profile does',
      );
      final port80 = printer80.connectionParams.singleWhere((p) => p.key == 'port');
      final port58 = printer58.connectionParams.singleWhere((p) => p.key == 'port');
      expect(port58.isRequired, port80.isRequired);
    },
  );

  test('привязка с необъявленной опцией отвергается с указанием её имени', () {
    final catalog = BuiltinDeviceProfileCatalog();
    final scale = catalog.byId('scale.cas.pd2')!; // declares no options
    expect(scale.options, isEmpty);

    expect(
      () => DeviceBinding(
        deviceClass: DeviceClass.scale,
        profileId: scale.id,
        parameters: _validParamsFor(scale),
        options: const {'paperWidthMm': '80'},
      ).validateAgainst(catalog),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.toString(),
          'сообщение об ошибке',
          contains('paperWidthMm'),
        ),
      ),
    );
  });

  test('профиль без опций принимает привязку без опций', () {
    // The common case must not require ceremony: most classes have nothing
    // for an operator to choose among, and leaving `options` unset must not
    // be treated as leaving something required unfilled.
    final catalog = BuiltinDeviceProfileCatalog();
    final scale = catalog.byId('scale.cas.pd2')!;
    expect(scale.options, isEmpty);

    expect(
      () => DeviceBinding(
        deviceClass: DeviceClass.scale,
        profileId: scale.id,
        parameters: _validParamsFor(scale),
      ).validateAgainst(catalog),
      returnsNormally,
    );
  });

  test(
    'поддерживаемые ширины читаются из одного места: options выводится из '
    'capabilities, а не хранится второй раз',
    () {
      // DeviceProfile has no `options:` constructor parameter at all —
      // `options` is a getter computed from `capabilities.paperWidthsMm`.
      // That makes a second, independently hand-typed list a compile-time
      // impossibility at any DeviceProfile(...) call site, not merely a
      // discipline this test enforces. What the test *can* show is that the
      // getter actually tracks capabilities rather than being frozen: two
      // profiles with different paperWidthsMm get different options.
      const narrow = DeviceProfile(
        id: 'test.printer.narrow',
        deviceClass: DeviceClass.receiptPrinter,
        title: 'Test Narrow',
        protocol: DeviceProtocol.escPos,
        capabilities: DeviceCapabilities(paperWidthsMm: [44]),
      );
      const wide = DeviceProfile(
        id: 'test.printer.wide',
        deviceClass: DeviceClass.receiptPrinter,
        title: 'Test Wide',
        protocol: DeviceProtocol.escPos,
        capabilities: DeviceCapabilities(paperWidthsMm: [58, 80, 112]),
      );

      expect(
        narrow.options.singleWhere((o) => o.key == 'paperWidthMm').allowedValues,
        ['44'],
      );
      expect(
        wide.options.singleWhere((o) => o.key == 'paperWidthMm').allowedValues,
        ['58', '80', '112'],
      );

      // And across the whole built-in catalog: wherever the option is
      // present, it is always exactly capabilities.paperWidthsMm restated
      // as strings — never a value that merely happens to agree today.
      final catalog = BuiltinDeviceProfileCatalog();
      for (final cls in DeviceClass.values) {
        for (final profile in catalog.forClass(cls)) {
          final widthOptions = profile.options.where(
            (o) => o.key == 'paperWidthMm',
          );
          if (profile.capabilities.paperWidthsMm.isEmpty) {
            expect(widthOptions, isEmpty);
          } else {
            expect(
              widthOptions.single.allowedValues,
              profile.capabilities.paperWidthsMm
                  .map((mm) => mm.toString())
                  .toList(),
            );
          }
        }
      }
    },
  );

  test(
    'labelHeightMm — the same computed-option shape as paperWidthMm, added '
    'while closing the "labelHeightMm: 40 hardcoded" review finding',
    () {
      const withHeights = DeviceProfile(
        id: 'test.label.tall',
        deviceClass: DeviceClass.labelPrinter,
        title: 'Test Tall Label',
        protocol: DeviceProtocol.zpl,
        capabilities: DeviceCapabilities(labelHeightsMm: [30, 60, 90]),
      );
      const withoutHeights = DeviceProfile(
        id: 'test.label.no-height',
        deviceClass: DeviceClass.labelPrinter,
        title: 'Test No Height',
        protocol: DeviceProtocol.zpl,
      );

      expect(
        withHeights.options.singleWhere((o) => o.key == 'labelHeightMm').allowedValues,
        ['30', '60', '90'],
      );
      expect(
        withoutHeights.options.where((o) => o.key == 'labelHeightMm'),
        isEmpty,
        reason: 'no labelHeightsMm declared — no option should appear at all',
      );

      // A binding may choose an allowed height and must be refused an
      // unlisted one — same rule as paperWidthMm, proven independently here
      // rather than assumed by analogy.
      final catalog = _SingleProfileCatalog(withHeights);
      expect(
        () => const DeviceBinding(
          deviceClass: DeviceClass.labelPrinter,
          profileId: 'test.label.tall',
          options: {'labelHeightMm': '60'},
        ).validateAgainst(catalog),
        returnsNormally,
      );
      expect(
        () => const DeviceBinding(
          deviceClass: DeviceClass.labelPrinter,
          profileId: 'test.label.tall',
          options: {'labelHeightMm': '999'},
        ).validateAgainst(catalog),
        throwsA(isA<ArgumentError>()),
        reason: 'a height the model does not list must not be silently accepted',
      );

      // Real catalogue profiles actually declare it, not just the test's
      // own synthetic profile above.
      final real = BuiltinDeviceProfileCatalog();
      final zpl104 = real.byId('printer.label.zpl.104mm')!;
      expect(zpl104.capabilities.labelHeightsMm, isNotEmpty);
      expect(
        zpl104.options.singleWhere((o) => o.key == 'labelHeightMm').allowedValues,
        zpl104.capabilities.labelHeightsMm.map((mm) => mm.toString()).toList(),
      );
    },
  );
}

class _SingleProfileCatalog implements DeviceProfileCatalog {
  const _SingleProfileCatalog(this._profile);

  final DeviceProfile _profile;

  @override
  DeviceProfile? byId(String id) => id == _profile.id ? _profile : null;

  @override
  List<DeviceProfile> forClass(DeviceClass deviceClass) =>
      _profile.deviceClass == deviceClass ? [_profile] : const [];
}
