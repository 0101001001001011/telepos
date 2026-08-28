import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/core/settings/customer_screen_settings.dart';

/// `CustomerScreenChoice.read` is the single parsing path
/// `lib/main.dart`'s `_maybeOpenCustomerScreen` and
/// `hardware_settings_screen.dart`'s `_loadSettings` both call — this is the
/// regression-guard for the till startup behaviour: a saved, enabled choice
/// must yield the configured monitor, and nothing enabled must yield no
/// window at all. See the task-4/task-5 report: before this fix,
/// `_maybeOpenCustomerScreen` read the retired `hardware_settings` blob
/// instead of `kCustomerScreenPrefsKey`, so a till configured for a customer
/// display silently stopped opening it.
void main() {
  group('CustomerScreenChoice.read (lib/core/settings)', () {
    test('ничего не сохранено — выключено, монитор по умолчанию 1', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final choice = CustomerScreenChoice.read(prefs);

      expect(choice.enabled, isFalse);
      expect(choice.monitor, 1);
    });

    test('включено и указан монитор — оба поля доходят до читателя', () async {
      SharedPreferences.setMockInitialValues({
        kCustomerScreenPrefsKey: jsonEncode({'enabled': true, 'monitor': 2}),
      });
      final prefs = await SharedPreferences.getInstance();

      final choice = CustomerScreenChoice.read(prefs);

      expect(choice.enabled, isTrue);
      expect(choice.monitor, 2);
    });

    test('выключено явно — монитор не должен открываться, даже если задан',
        () async {
      SharedPreferences.setMockInitialValues({
        kCustomerScreenPrefsKey: jsonEncode({'enabled': false, 'monitor': 3}),
      });
      final prefs = await SharedPreferences.getInstance();

      final choice = CustomerScreenChoice.read(prefs);

      expect(choice.enabled, isFalse);
    });

    test('битый JSON в значении — деградирует к выключенному, а не падает',
        () async {
      SharedPreferences.setMockInitialValues({
        kCustomerScreenPrefsKey: 'not json',
      });
      final prefs = await SharedPreferences.getInstance();

      final choice = CustomerScreenChoice.read(prefs);

      expect(choice.enabled, isFalse);
      expect(choice.monitor, 1);
    });

    test('старый ключ hardware_settings больше не читается для этого выбора',
        () async {
      // Регрессия, которую чинит эта задача: до фикса main.dart читал именно
      // этот, ретированный ключ под другими именами полей
      // (customerScreenEnabled/customerScreenMonitor). Он больше не должен
      // влиять на CustomerScreenChoice вовсе.
      SharedPreferences.setMockInitialValues({
        'hardware_settings': jsonEncode({
          'customerScreenEnabled': true,
          'customerScreenMonitor': 2,
        }),
      });
      final prefs = await SharedPreferences.getInstance();

      final choice = CustomerScreenChoice.read(prefs);

      expect(choice.enabled, isFalse);
      expect(choice.monitor, 1);
    });
  });
}
