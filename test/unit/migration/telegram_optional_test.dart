import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/app/config/local_properties.dart';

void main() {
  group('LocalProperties.telegramEnabled', () {
    late LocalProperties props;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      props = LocalProperties.forTesting(prefs);
    });

    test('defaults to false (Telegram disabled by default)', () {
      expect(props.telegramEnabled, false);
    });

    test('can be enabled', () {
      props.telegramEnabled = true;
      expect(props.telegramEnabled, true);
    });

    test('can be disabled after enabling', () {
      props.telegramEnabled = true;
      props.telegramEnabled = false;
      expect(props.telegramEnabled, false);
    });

    test('persists across LocalProperties instances', () async {
      props.telegramEnabled = true;

      final prefs = await SharedPreferences.getInstance();
      final newProps = LocalProperties.forTesting(prefs);
      expect(newProps.telegramEnabled, true);
    });

    test('clear() resets telegramEnabled', () async {
      props.telegramEnabled = true;
      await props.clear();
      expect(props.telegramEnabled, false);
    });
  });

  group('LocalProperties.prefs getter', () {
    test('exposes SharedPreferences for external use', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final props = LocalProperties.forTesting(prefs);

      expect(props.prefs, same(prefs));
    });
  });
}
