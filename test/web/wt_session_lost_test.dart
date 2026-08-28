/// `SessionLost` — истёкший или отозванный сеанс терминала, отличимый от
/// обрыва связи, от отказа по данным и (круг правок 1) от нехватки права.
///
/// Три операции здесь требуют сеанса (`SessionAccess` в `till_ops.dart`):
/// проверка устройства, привязка устройства, переименование терминала.
/// Касса, у которой сторож отказал по причине сеанса (`WireGuard.check`),
/// до задачи 4 отвечала `ErrorFrame('unauthorized', …)` — тем же кодом, каким
/// она отвечала бы на любую другую причину `WireDenied`. Первый круг этой
/// задачи завёл `SessionLost`, ни один из трёх биндингов код не разбирал:
/// `WtDeviceCheck` ловил `on Object` и выдавал тот же текст, что при обрыве
/// связи; `WtDeviceBindingRepository` превращал его в «касса отклонила
/// привязку» — отказ по данным.
///
/// Второй круг обнаружил следствие первого: код `unauthorized` нёс не только
/// «сеанс истёк», но и «прав не хватает» — `WireGuard.check` отвечала им на
/// обе причины одинаково. Кассир с живым сеансом без права `settings.hardware`
/// получил бы `SessionLost`, вошёл бы заново той же учёткой и упёрся бы в тот
/// же отказ — круг, а не починка. Ответ — разбор на кассе
/// (`WireDenied.code`, `lib/domain/wire/wire_guard.dart`): `unauthorized`
/// остаётся сеансовым и уходит в `SessionLost`, `forbidden` — рядовой отказ
/// операции, идёт прежним путём `WtProtocolError`. Третья группа файла — тест
/// именно на это: `forbidden` не должен давать `SessionLost` нигде из трёх
/// мест первой группы.
///
/// Вторая группа — противовес первой: обрыв связи (не отвечающая касса)
/// обязан по-прежнему давать прежний исход, а не `SessionLost`. Без него
/// сужение `catch` могло бы проглотить обычные отказы вместе с сеансовым.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_device_binding_repository.dart';
import 'package:telepos/web/wt_device_check.dart';
import 'package:telepos/web/wt_device_discovery.dart';
import 'package:telepos/web/wt_terminal_repository.dart';

import 'support/fake_dispatcher.dart';

const _unauthorized =
    '{"ok":false,"code":"unauthorized",'
    '"detail":"terminals.deviceCheck: сеанс неизвестен или истёк"}';

const _forbidden =
    '{"ok":false,"code":"forbidden",'
    '"detail":"terminals.deviceCheck: нет права settings.hardware"}';

void main() {
  group('unauthorized становится SessionLost', () {
    test(
      'проверка устройства бросает SessionLost, а не «прочий отказ»',
      () async {
        await expectLater(
          WtDeviceCheck(
            answering(_unauthorized),
          ).check(terminalId: 1, deviceClass: DeviceClass.receiptPrinter),
          throwsA(isA<SessionLost>()),
        );
      },
    );

    test(
      'привязка устройства бросает SessionLost, а не «касса отклонила»',
      () async {
        await expectLater(
          WtDeviceBindingRepository(
            answering(_unauthorized),
          ).save(1, _binding()),
          throwsA(isA<SessionLost>()),
        );
      },
    );

    test('переименование терминала бросает SessionLost', () async {
      await expectLater(
        WtTerminalRepository(answering(_unauthorized)).rename(1, 'Касса-2'),
        throwsA(isA<SessionLost>()),
      );
    });

    // Пункт 4 второго круга разбора (2026-08-21): пятое место одной и той же
    // болезни — поиск устройств не был задет ни первым кругом задачи 4, ни
    // первой волной, и до этого теста поиска устройств не было ни в одном
    // файле вовсе.
    test(
      'поиск устройств бросает SessionLost, а не «спросить не удалось»',
      () async {
        await expectLater(
          WtDeviceDiscovery(
            answering(_unauthorized),
            BuiltinDeviceProfileCatalog(),
          ).find(DeviceClass.receiptPrinter),
          throwsA(isA<SessionLost>()),
        );
      },
    );
  });

  group('обрыв связи — прежний исход, не SessionLost', () {
    test(
      'проверка устройства при недостижимой кассе остаётся исходом',
      () async {
        final outcome = await WtDeviceCheck(
          dispatcherThatRefuses(),
        ).check(terminalId: 1, deviceClass: DeviceClass.receiptPrinter);

        expect(outcome.reason, DeviceCheckReason.unexpectedError);
        expect(outcome.message, isNotEmpty);
      },
    );

    test(
      'привязка устройства при отказе кассы остаётся ArgumentError',
      () async {
        await expectLater(
          WtDeviceBindingRepository(
            dispatcherThatRefuses(),
          ).save(1, _binding()),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group(
    'forbidden остаётся отказом операции, а не SessionLost — круг правок 1',
    () {
      // Ровно тот случай, ради которого второй круг: живой сеанс, которому
      // не хватает права. Вход заново его не лечит — уводить на экран входа
      // по этому коду означало бы гонять кассира по кругу.

      test('проверка устройства: forbidden остаётся WtProtocolError через '
          'DeviceCheckOutcome.unexpectedError, а не SessionLost', () async {
        final outcome = await WtDeviceCheck(
          answering(_forbidden),
        ).check(terminalId: 1, deviceClass: DeviceClass.receiptPrinter);

        expect(outcome.reason, DeviceCheckReason.unexpectedError);
        expect(outcome.message, contains('forbidden'));
      });

      test('привязка устройства: forbidden остаётся «касса отклонила», '
          'а не SessionLost', () async {
        await expectLater(
          WtDeviceBindingRepository(answering(_forbidden)).save(1, _binding()),
          throwsA(
            isA<ArgumentError>().having(
              (e) => '$e',
              'сообщение',
              contains('forbidden'),
            ),
          ),
        );
      });

      test(
        'поиск устройств: forbidden остаётся failedSources, не SessionLost',
        () async {
          final result = await WtDeviceDiscovery(
            answering(_forbidden),
            BuiltinDeviceProfileCatalog(),
          ).find(DeviceClass.receiptPrinter);

          expect(result.candidates, isEmpty);
          expect(result.failedSources, isNotEmpty);
        },
      );

      test(
        'переименование терминала: forbidden остаётся WtProtocolError',
        () async {
          await expectLater(
            WtTerminalRepository(answering(_forbidden)).rename(1, 'Касса-2'),
            throwsA(
              isA<WtProtocolError>().having((e) => e.code, 'code', 'forbidden'),
            ),
          );
        },
      );
    },
  );
}

DeviceBinding _binding() => const DeviceBinding(
  deviceClass: DeviceClass.receiptPrinter,
  profileId: 'demo-profile',
);
