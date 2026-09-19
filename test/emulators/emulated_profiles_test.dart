/// Сторожа виртуальных профилей — того **единственного** механизма из трёх,
/// который потребовал правок в `lib/`.
///
/// Два других механизма (адрес и петля ОС) правок не требуют вовсе, поэтому
/// и сторожей здесь на них нет: сторожить нечего.
///
/// Чего эти сторожа НЕ доказывают: что виртуальный профиль **выброшен** из
/// магазинного бинарника. Это утверждение о компиляторе, и проверяется оно
/// только замером — `docs/internal/testing-notes.md`, раздел «Виртуальные
/// профили и AOT».
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/device/composite_device_profile_catalog.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/emulators/emulated_device_profile_catalog.dart';

void main() {
  group('EmulatedDeviceProfileCatalog', () {
    final catalog = EmulatedDeviceProfileCatalog();

    test('покрывает ровно те два класса, у которых нет ни адреса, ни петли', () {
      final covered = <DeviceClass>{
        for (final c in DeviceClass.values)
          if (catalog.forClass(c).isNotEmpty) c,
      };

      expect(
        covered,
        {DeviceClass.scanner, DeviceClass.receiptPrinter},
        reason:
            'третий виртуальный профиль — это признак того, что кто-то '
            'эмулирует свой адаптер вместо зависимости: у весов, дисплея, '
            'этикеточника, ящика и терминала оплаты адрес или петля ЕСТЬ',
      );
    });

    test('каждый профиль объявляет protocol emulated и префикс emul.', () {
      final all = <DeviceProfile>[
        for (final c in DeviceClass.values) ...catalog.forClass(c),
      ];
      expect(all, isNotEmpty);
      for (final p in all) {
        expect(
          p.protocol,
          DeviceProtocol.emulated,
          reason: '${p.id}: иначе продукт примет эмулятор за настоящий прибор',
        );
        expect(
          p.id,
          startsWith('emul.'),
          reason:
              '${p.id}: оператор обязан отличить эмулятор от прибора в списке '
              'моделей одним взглядом',
        );
        expect(p.title.toLowerCase(), contains('эмул'), reason: p.id);
      }
    });

    test('идентификаторы не пересекаются со встроенным каталогом', () {
      final builtin = BuiltinDeviceProfileCatalog();
      for (final c in DeviceClass.values) {
        for (final p in catalog.forClass(c)) {
          expect(
            builtin.byId(p.id),
            isNull,
            reason:
                '${p.id} затенил бы настоящую модель: композит отдал бы '
                'эмулятор там, где привязка называла прибор',
          );
        }
      }
    });

    test('byId отдаёт null на чужой идентификатор, а не первый попавшийся', () {
      expect(catalog.byId('printer.escpos.80mm'), isNull);
      expect(catalog.byId(''), isNull);
    });
  });

  group('CompositeDeviceProfileCatalog', () {
    final composite = CompositeDeviceProfileCatalog([
      BuiltinDeviceProfileCatalog(),
      EmulatedDeviceProfileCatalog(),
    ]);
    final builtin = BuiltinDeviceProfileCatalog();

    test('forClass отдаёт объединение, не подменяя встроенные профили', () {
      for (final c in DeviceClass.values) {
        final ids = composite.forClass(c).map((p) => p.id).toList();
        for (final p in builtin.forClass(c)) {
          expect(ids, contains(p.id), reason: '${c.name}: потерян ${p.id}');
        }
      }
      expect(
        composite.forClass(DeviceClass.scanner).map((p) => p.id),
        contains('emul.scanner.hid'),
      );
    });

    test('byId находит профиль любого слагаемого', () {
      expect(composite.byId('printer.escpos.80mm'), isNotNull);
      expect(composite.byId('emul.scanner.hid'), isNotNull);
      expect(composite.byId('нет такого'), isNull);
    });

    test('первый слагаемый выигрывает при совпадении идентификаторов', () {
      // Не украшение: композит с обратным приоритетом дал бы эмулятор там,
      // где привязка называет настоящую модель, и это был бы не отказ, а
      // правдоподобно работающий прибор не той модели.
      final shadow = _OneProfileCatalog(
        DeviceProfile(
          id: 'printer.escpos.80mm',
          deviceClass: DeviceClass.receiptPrinter,
          title: 'Подмена',
          protocol: DeviceProtocol.emulated,
        ),
      );
      final c = CompositeDeviceProfileCatalog([builtin, shadow]);
      expect(c.byId('printer.escpos.80mm')!.title, isNot('Подмена'));
      expect(
        c.forClass(DeviceClass.receiptPrinter).where(
          (p) => p.id == 'printer.escpos.80mm',
        ),
        hasLength(1),
        reason: 'затенённый профиль не имеет права появиться в списке дважды',
      );
    });

    test('пустой композит — пустой каталог, а не исключение', () {
      final c = CompositeDeviceProfileCatalog(const []);
      expect(c.forClass(DeviceClass.scale), isEmpty);
      expect(c.byId('что угодно'), isNull);
    });
  });

  group('DeviceProtocol.emulated', () {
    test('объявлен и не сливается ни с одним настоящим протоколом', () {
      expect(DeviceProtocol.values, contains(DeviceProtocol.emulated));
      expect(
        DeviceProtocol.values.where((p) => p.name == 'emulated'),
        hasLength(1),
      );
    });
  });
}

class _OneProfileCatalog implements DeviceProfileCatalog {
  _OneProfileCatalog(this.profile);

  final DeviceProfile profile;

  @override
  List<DeviceProfile> forClass(DeviceClass deviceClass) =>
      profile.deviceClass == deviceClass ? [profile] : const [];

  @override
  DeviceProfile? byId(String id) => profile.id == id ? profile : null;
}
