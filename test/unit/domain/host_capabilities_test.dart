import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/host/host_capabilities.dart';

void main() {
  test('браузер не управляет машиной, но настраивает устройства кассы', () {
    const c = HostCapabilities.browser;
    expect(c.managesNetwork, isFalse, reason: 'сеть настраивает ОС клиента');
    expect(c.canInstallDrivers, isFalse);
    expect(c.controlsDisplay, isFalse);
    expect(c.managesTime, isFalse);
    expect(c.ownsData, isFalse);
    expect(c.ownsDevices, isFalse, reason: 'устройства не его, а кассы');
    expect(c.servesTerminals, isFalse);
  });

  test('десктоп владеет данными и устройствами, но не машиной', () {
    const c = HostCapabilities.desktop;
    expect(c.ownsData, isTrue);
    expect(c.ownsDevices, isTrue);
    expect(c.managesNetwork, isFalse, reason: 'сеть настраивает Windows/macOS');
    expect(c.canInstallDrivers, isFalse);
    expect(c.controlsDisplay, isFalse, reason: 'экран не в нашей власти на десктопе');
    expect(c.managesTime, isFalse, reason: 'источник времени — ОС клиента, не мы');
    expect(c.servesTerminals, isTrue, reason: 'десктоп тоже раздаёт API другим терминалам');
  });

  test('устройство-приложение управляет машиной целиком', () {
    const c = HostCapabilities.appliance;
    expect(c.managesNetwork, isTrue);
    expect(c.canInstallDrivers, isTrue);
    expect(c.controlsDisplay, isTrue);
    expect(c.managesTime, isTrue);
    expect(c.ownsData, isTrue);
    expect(c.ownsDevices, isTrue);
    expect(c.servesTerminals, isTrue, reason: 'приложение тоже раздаёт API другим терминалам');
  });

  test('сервер владеет данными, раздаёт терминалам и не имеет устройств', () {
    const c = HostCapabilities.server;
    expect(c.ownsData, isTrue);
    expect(c.servesTerminals, isTrue);
    expect(c.ownsDevices, isFalse);
  });

  // Раньше здесь была проверка «роль хоста не выводится из возможностей»:
  // `HostCapabilities.appliance.toString().toLowerCase()` не содержит
  // 'kiosk'. У класса нет собственного toString(), поэтому Dart возвращает
  // "Instance of 'HostCapabilities'" независимо от полей и от их значений —
  // проверка не падает почти ни для какого класса и не различает "роль не
  // выводится" от "роль выводится, просто не в toString()". Сделать её
  // содержательной без dart:mirrors (в проекте не используется — несовместим
  // с web/AOT сборками) нельзя: HostCapabilities — плоский набор из семи
  // bool-полей без методов, которые могли бы "спросить" роль. Инвариант И9
  // ("экран спрашивает возможность, а не роль") в данном случае — свойство
  // API-поверхности класса, а не значения, которое можно проверить в рантайме;
  // он проверяется тем, что ни один экран не импортирует и не сравнивает
  // строковое имя роли (обзор кода/architecture-тест), а не тестом на этом
  // файле. Тест удалён, а не переписан на заведомо зелёную проверку.
}
