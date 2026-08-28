import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/main.dart' show resolveHostCapabilities;

void main() {
  tearDown(() => GetIt.I.reset());

  test('возможности разрешаются из контейнера и неизменяемы в процессе', () {
    GetIt.I.registerSingleton<HostCapabilities>(HostCapabilities.desktop);

    final first = GetIt.I<HostCapabilities>();
    final second = GetIt.I<HostCapabilities>();

    expect(first, same(second), reason: 'И10: роль не меняется во время работы');
    expect(first.ownsDevices, isTrue);
  });

  test('три нативные роли различимы, а не совпадают', () {
    // Тест только на «регистрация вернула значение» прошёл бы, даже если бы
    // все три облика разрешались в одну и ту же константу. Здесь проверяем,
    // что desktop, appliance и server — разные объекты и расходятся именно в
    // тех полях, которые их различают.
    expect(HostCapabilities.desktop, isNot(same(HostCapabilities.appliance)));
    expect(HostCapabilities.desktop, isNot(same(HostCapabilities.server)));
    expect(HostCapabilities.appliance, isNot(same(HostCapabilities.server)));

    // appliance управляет сетью машины целиком; desktop и server — нет.
    expect(HostCapabilities.appliance.managesNetwork, isTrue);
    expect(HostCapabilities.desktop.managesNetwork, isFalse);
    expect(HostCapabilities.server.managesNetwork, isFalse);

    // server владеет данными, но не устройствами; desktop и appliance
    // владеют и тем, и другим.
    expect(HostCapabilities.server.ownsDevices, isFalse);
    expect(HostCapabilities.desktop.ownsDevices, isTrue);
    expect(HostCapabilities.appliance.ownsDevices, isTrue);
  });

  group('resolveHostCapabilities (lib/main.dart)', () {
    // Эти тесты идут через ту же функцию разбора аргументов, которую
    // вызывает main() при регистрации в GetIt. Тест выше на «различимость
    // ролей» не заметил бы, если бы разбор --kiosk сломался и киоск-запуск
    // стал резолвиться в desktop — здесь именно этот путь и проверяется.
    test('без флагов — desktop', () {
      expect(resolveHostCapabilities([]), same(HostCapabilities.desktop));
    });

    test('--kiosk — appliance', () {
      expect(
        resolveHostCapabilities(['--kiosk']),
        same(HostCapabilities.appliance),
      );
    });

    test('--server — server', () {
      expect(
        resolveHostCapabilities(['--server']),
        same(HostCapabilities.server),
      );
    });

    test('--server побеждает --kiosk, если заданы оба', () {
      expect(
        resolveHostCapabilities(['--kiosk', '--server']),
        same(HostCapabilities.server),
      );
    });
  });
}
