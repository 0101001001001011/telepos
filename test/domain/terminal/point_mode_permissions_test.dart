import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/terminal/point_mode_permissions.dart';
import 'package:telepos/domain/terminal/terminal.dart';

void main() {
  group('PointModePermissions', () {
    test('у каждого режима объявлен свой набор запретов', () {
      // Забытый режим — это режим без ограничений, то есть самый опасный из
      // возможных. Тест краснеет на добавление нового члена PointMode.
      for (final mode in PointMode.values) {
        expect(
          () => PointModePermissions.deniedFor(mode),
          returnsNormally,
          reason: 'режим ${mode.name} не объявлен',
        );
      }
    });

    test('касса кассира не отнимает ничего', () {
      expect(PointModePermissions.deniedFor(PointMode.cashier), isEmpty);
    });

    test('самообслуживание отнимает деньги и настройки даже у владельца', () {
      final effective = PointModePermissions.effective(
        ofRole: PermissionKeys.allPermissions,
        at: PointMode.selfService,
      );

      expect(effective, isNot(contains(PermissionKeys.opCashInOut)));
      expect(effective, isNot(contains(PermissionKeys.opSellDebt)));
      expect(effective, isNot(contains(PermissionKeys.opRefundWithoutReceipt)));
      expect(effective, isNot(contains(PermissionKeys.navSettings)));
      expect(effective, isNot(contains(PermissionKeys.settingsUsers)));

      // И при этом продавать — можно: терминал самообслуживания для этого и
      // существует.
      expect(effective, contains(PermissionKeys.navSale));
    });

    test('пересечение только сужает, никогда не добавляет', () {
      // Роль даёт набор прав, режим отнимает часть. Результат должен быть
      // ровно разностью, а не объединением: difference(), а не union().
      // Проверяем через режим с непустым набором запретов.
      final ofRole = const {PermissionKeys.navSale, PermissionKeys.navRefund};
      final denied = PointModePermissions.deniedFor(PointMode.selfService);

      final effective = PointModePermissions.effective(
        ofRole: ofRole,
        at: PointMode.selfService,
      );

      // Роль даёт {navSale, navRefund}, selfService отнимает navRefund.
      // В итоге должно остаться только {navSale}.
      expect(effective, {PermissionKeys.navSale});

      // И не должно быть ничего из запретов режима.
      for (final deny in denied) {
        expect(effective, isNot(contains(deny)));
      }
    });

    test('запрет режима сильнее права роли', () {
      final effective = PointModePermissions.effective(
        ofRole: const {PermissionKeys.opCashInOut},
        at: PointMode.selfService,
      );

      expect(effective, isEmpty);
    });
  });
}
