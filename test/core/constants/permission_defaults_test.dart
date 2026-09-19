// Закрепляет раскладку PermissionKeys.roleDefaults поимённо: набор ключей
// для каждой роли сравнивается с независимо написанным литералом ниже, а не
// с самим собой и не со счётом ключей. Перенос одного ключа из роли в роль
// (например: `navReports` из administrator в cashier) меняет только
// исходную карту — литерал в тесте не сдвигается вслед за ним — и тест
// краснеет именно на той роли, у которой изменился состав.
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/constants/permission_keys.dart';

void main() {
  group('PermissionKeys.roleDefaults — состав', () {
    test('определены умолчания ровно для всех четырёх ролей', () {
      expect(
        PermissionKeys.roleDefaults.keys.toSet(),
        UserRole.values.toSet(),
      );
    });

    test('owner получает весь словарь целиком', () {
      expect(
        PermissionKeys.roleDefaults[UserRole.owner],
        PermissionKeys.allPermissions,
      );
    });

    test(
      'administrator получает всё, кроме settings.users — поимённо',
      () {
        final expected = PermissionKeys.allPermissions.difference({
          PermissionKeys.settingsUsers,
        });

        expect(PermissionKeys.roleDefaults[UserRole.administrator], expected);

        // Пригвождено явно, а не только через разницу множеств: если
        // settings.users однажды окажется у администратора, эта строка
        // покраснеет даже если кто-то одновременно подправит `expected`
        // выше.
        expect(
          PermissionKeys.roleDefaults[UserRole.administrator],
          isNot(contains(PermissionKeys.settingsUsers)),
        );
      },
    );

    test('user получает только history и catalog — самый узкий набор', () {
      expect(
        PermissionKeys.roleDefaults[UserRole.user],
        <String>{PermissionKeys.navHistory, PermissionKeys.navCatalog},
      );
    });

    test('cashier получает ровно торговлю и смену во всех режимах', () {
      const expectedCashier = <String>{
        PermissionKeys.navSale,
        PermissionKeys.navRefund,
        PermissionKeys.navShift,
        PermissionKeys.navHistory,
        PermissionKeys.navCatalog,
        PermissionKeys.navCashOperation,
        PermissionKeys.navTables,
        PermissionKeys.navOrders,
        PermissionKeys.navServiceQueue,
        PermissionKeys.navServiceIntake,
        PermissionKeys.opSellDiscount,
        PermissionKeys.opSellDebt,
        PermissionKeys.opCashInOut,
        PermissionKeys.opDeferSale,
        PermissionKeys.opRefund,
        // Задача 24: погашение рассрочки. Деньги по договору приносят на
        // кассу, и принимать их некому, кроме кассира. Список здесь
        // выписан **независимо**, а не собран из `roleDefaults`, — потому
        // покраснение при добавлении ключа и есть смысл этой пробы.
        PermissionKeys.opCreditRepay,
      };

      expect(PermissionKeys.roleDefaults[UserRole.cashier], expectedCashier);
    });

    test('ни один settings.* ключ не достаётся кассиру — это и есть смысл задачи', () {
      final cashierSettings = PermissionKeys
          .roleDefaults[UserRole.cashier]!
          .where((k) => k.startsWith('settings.'));

      expect(cashierSettings, isEmpty);
    });

    test(
      'кассиру не достаются operations отмены/обнала без следа — '
      'ради них и существует роль-супервизор',
      () {
        final cashierOps = PermissionKeys.roleDefaults[UserRole.cashier]!;

        expect(cashierOps, isNot(contains(PermissionKeys.opEditPrice)));
        expect(cashierOps, isNot(contains(PermissionKeys.opCancelPayment)));
        expect(
          cashierOps,
          isNot(contains(PermissionKeys.opRefundWithoutReceipt)),
        );
      },
    );

    test(
      'администратору и владельцу operations отмены/обнала достаются — '
      'они и есть та роль-супервизор',
      () {
        for (final role in [UserRole.owner, UserRole.administrator]) {
          final ops = PermissionKeys.roleDefaults[role]!;
          expect(
            ops,
            containsAll([
              PermissionKeys.opEditPrice,
              PermissionKeys.opCancelPayment,
              PermissionKeys.opRefundWithoutReceipt,
            ]),
            reason: '$role должен авторизовывать операции поверх кассира',
          );
        }
      },
    );

    test(
      'кассиру не достаются agent/supply/reports/sync — это не торговля',
      () {
        final cashier = PermissionKeys.roleDefaults[UserRole.cashier]!;

        expect(cashier, isNot(contains(PermissionKeys.navAgent)));
        expect(cashier, isNot(contains(PermissionKeys.navSupply)));
        expect(cashier, isNot(contains(PermissionKeys.navReports)));
        expect(cashier, isNot(contains(PermissionKeys.navSync)));
        expect(cashier, isNot(contains(PermissionKeys.navSettings)));
      },
    );

    test('каждая роль получает подмножество всего словаря', () {
      for (final entry in PermissionKeys.roleDefaults.entries) {
        expect(
          PermissionKeys.allPermissions.containsAll(entry.value),
          isTrue,
          reason: '${entry.key} содержит ключ, которого нет в allPermissions',
        );
      }
    });

    test(
      'ни одна не-владельческая роль не шире, чем администратор (кроме '
      'settings.users, который у него единственного и отнят)',
      () {
        final adminPlusUsers = PermissionKeys.roleDefaults[
              UserRole.administrator]!
          .union({PermissionKeys.settingsUsers});

        for (final role in [UserRole.user, UserRole.cashier]) {
          final theirs = PermissionKeys.roleDefaults[role]!;
          expect(
            adminPlusUsers.containsAll(theirs),
            isTrue,
            reason: '$role содержит ключ шире, чем у administrator',
          );
        }
      },
    );
  });
}
