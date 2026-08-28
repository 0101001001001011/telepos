import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/wire/terminal_wire.dart';

/// Круговые тесты сведённых пар — читателя и писателя одной формы.
///
/// До 2026-08-04 каждая форма была написана дважды: читатель в `lib/web/`,
/// писатель в `lib/backend/terminal_routes.dart`, и в комментарии рядом с
/// писателем было прямо записано, что согласие между ними доказывает
/// круговой тест, а не общая реализация. Теперь реализация общая, и согласие
/// структурное. Тесты при этом остаются: они проверяют, что пара не теряет
/// поля сама по себе — это по-прежнему осмысленно и ловится только кругом.
void main() {
  group('Terminal', () {
    test('терминал переживает круг туда-обратно без потери полей', () {
      const terminal = Terminal(
        id: 42,
        name: 'Касса у входа',
        pointMode: PointMode.selfService,
      );

      final decoded = terminalFromWireJson(terminalToWireJson(terminal));

      expect(decoded.id, terminal.id);
      expect(decoded.name, terminal.name);
      expect(decoded.pointMode, terminal.pointMode);
    });

    test('каждый PointMode едет по имени, а не по индексу', () {
      // Индекс меняет смысл в тот момент, когда в перечисление вставили
      // новый член, — а режим точки решает вопрос прав доступа.
      for (final mode in PointMode.values) {
        final decoded = terminalFromWireJson(
          terminalToWireJson(Terminal(id: 1, name: 'x', pointMode: mode)),
        );
        expect(decoded.pointMode, mode);
      }
    });

    test('нераспознанное имя режима отвергается, а не угадывается', () {
      expect(
        () => terminalFromWireJson(const {
          'id': 1,
          'name': 'x',
          'pointMode': 'quantumMode',
        }),
        throwsStateError,
      );
    });
  });

  group('DeviceBinding', () {
    test('привязка переживает круг туда-обратно, включая обе сумки строк', () {
      // `parameters` и `options` — намеренно разные сумки: первая про то,
      // как дотянуться до устройства, вторая про выбор оператора среди
      // допустимых. Круг обязан сохранить обе, иначе выключенный принтер
      // вернётся с чужой шириной ленты.
      const binding = DeviceBinding(
        deviceClass: DeviceClass.labelPrinter,
        profileId: 'zebra_zd230',
        parameters: {'ipAddress': '192.168.1.50', 'port': '9100'},
        options: {'paperWidthMm': '58'},
        enabled: false,
      );

      final decoded = deviceBindingFromWireJson(
        deviceBindingToWireJson(binding),
        terminalId: 7,
      );

      expect(decoded.deviceClass, binding.deviceClass);
      expect(decoded.profileId, binding.profileId);
      expect(decoded.parameters, binding.parameters);
      expect(decoded.options, binding.options);
      expect(
        decoded.enabled,
        binding.enabled,
        reason:
            'выключенная привязка обязана вернуться выключенной: '
            'умолчание true молча включило бы устройство обратно',
      );
    });

    test('каждый DeviceClass едет по имени', () {
      for (final deviceClass in DeviceClass.values) {
        final decoded = deviceBindingFromWireJson(
          deviceBindingToWireJson(
            DeviceBinding(deviceClass: deviceClass, profileId: 'p'),
          ),
          terminalId: 1,
        );
        expect(decoded.deviceClass, deviceClass);
      }
    });

    test('нераспознанное имя класса устройства отвергается', () {
      expect(
        () => deviceBindingFromWireJson(const {
          'deviceClass': 'quantumRadio',
          'profileId': 'p',
        }, terminalId: 1),
        throwsStateError,
      );
    });
  });
}
