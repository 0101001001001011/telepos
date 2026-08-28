/// Браузерные репозитории поверх провода — то, что проверяется без кассы.
///
/// Здесь подставлен диспетчер, а не транспорт: проверяется поведение
/// репозитория на каждый род ответа кассы, включая те, которые касса даёт
/// редко и в неудачный момент. Сквозная проверка с настоящей кассой живёт в
/// `wt_till_speaks_first_test.dart` — она про другое, про цель работы.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_app_bootstrap.dart';
import 'package:telepos/web/wt_device_check.dart';
import 'package:telepos/web/wt_device_discovery.dart';
import 'package:telepos/web/wt_first_launch_repository.dart';
import 'package:telepos/web/wt_setup_repository.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_terminal_repository.dart';

import 'support/fake_dispatcher.dart';

void main() {
  group('подъём кассы', () {
    test('недостижимая касса — названное состояние, а не белый экран', () async {
      // Правило, подтверждённое 2026-08-04 трижды за один день: отказ приходит
      // значением (И144). Заставка обязана сказать, что кассы нет.
      final said = <String>[];
      final status = await WtAppBootstrap(dispatcherThatRefuses())
          .start(onProgress: (_, text) => said.add(text));

      expect(status, AppInitStatus.databaseFailure);
      expect(
        said.last,
        contains('no_session'),
        reason: 'причина обязана дойти до экрана, а не остаться в логе',
      );
    });

    test('успех кассы доезжает как есть', () async {
      final status = await WtAppBootstrap(
        answering('{"ok":true,"body":{"status":"success"}}'),
      ).start(onProgress: (_, _) {});

      expect(status, AppInitStatus.success);
    });
  });

  group('первый запуск', () {
    test('недостижимая касса — офлайн, а не падение', () async {
      final repo = WtFirstLaunchRepository(dispatcherThatRefuses());

      expect(await repo.determineResult(), FirstLaunchResult.offlineMode);
      expect(await repo.findAvailableBackups(), isEmpty);
    });

    test('восстановление отдаёт ход выполнения несколькими числами', () async {
      // Ровно то, чего не было: предшественник этого файла двигал полосу с
      // 0.1 сразу на 1.0 и писал о себе, что придумывать промежуточные числа
      // отказывается.
      final seen = <double>[];
      final repo = WtFirstLaunchRepository(
        answering(
          '{"kind":"progress","value":0.2,"text":"Скачиваем"}',
          '{"kind":"progress","value":0.6,"text":"Разворачиваем"}',
          '{"kind":"progress","value":0.9,"text":"Проверяем"}',
          '{"kind":"done","body":{"ok":true}}',
        ),
      );

      final ok = await repo.restoreFromBackup(
        _backup(42),
        onProgress: (value, _) => seen.add(value),
      );

      expect(ok, isTrue);
      expect(seen, [0.2, 0.6, 0.9], reason: 'не только начало и конец');
    });

    test('оборванная работа не выдаётся за завершённую', () async {
      // «Готово» здесь означает целый магазин. Восстановление, оборванное на
      // середине, обязано остаться оборванным: выдать незавершённое за
      // завершённое дороже, чем показать отказ.
      final seen = <String>[];
      final ok = await WtFirstLaunchRepository(
        answering('{"kind":"progress","value":0.5,"text":"Разворачиваем"}'),
      ).restoreFromBackup(_backup(1), onProgress: (_, text) => seen.add(text));

      expect(ok, isFalse);
      expect(seen.last, contains('run_incomplete'));
    });

    test('касса, отказавшая посреди работы, называет причину', () async {
      final seen = <String>[];
      final ok = await WtFirstLaunchRepository(
        answering(
          '{"kind":"progress","value":0.3,"text":"Скачиваем"}',
          '{"ok":false,"code":"run_failed","detail":"копии нет"}',
        ),
      ).loadGlobalData(onProgress: (_, text) => seen.add(text));

      expect(ok, isFalse);
      expect(seen.last, contains('run_failed'));
    });

    test('заведение точки отказывает громко, а не пустым ключом', () async {
      // Пустой ключ выглядел бы как заведённая касса, у которой он почему-то
      // пуст, и обнаружилось бы это на первой синхронизации.
      await expectLater(
        WtFirstLaunchRepository(dispatcherThatRefuses()).startNewPos(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('фиксация мастера', () {
    test('касса не подтвердила — мастер остаётся на месте', () async {
      // Тихо «завершившийся» мастер над незафиксированной кассой — худший из
      // возможных исходов: оператор уходит работать на кассу без счетов.
      await expectLater(
        WtSetupRepository(answering('{"ok":true,"body":{"ok":false}}'))
            .completeSetup(_draft()),
        throwsA(isA<StateError>()),
      );
    });

    test('отказ провода тоже не считается фиксацией', () async {
      await expectLater(
        WtSetupRepository(dispatcherThatRefuses()).completeSetup(_draft()),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('терминалы', () {
    test('свой терминал: его отсутствие — названный отказ, а не null', () async {
      // `self()` спрашивают, чтобы действовать от имени терминала. Действовать
      // от имени несуществующего нельзя, и локальный биндинг отказывает так же.
      // Касса отвечает `terminal: null` — значением, потому что «мастер ещё не
      // проходил» это состояние, а не поломка, — и превращает его в отказ
      // именно этот биндинг.
      await expectLater(
        WtTerminalRepository(
          answering('{"ok":true,"body":{"terminal":null}}'),
        ).self(),
        throwsA(isA<InstallationNotConfiguredException>()),
      );
    });

    test('одноразовое чтение берёт первое значение подписки', () async {
      final terminals = await WtTerminalRepository(
        answering(
          '{"kind":"update","body":{"terminals":'
          '[{"id":7,"name":"Касса-7","pointMode":"cashier"}]}}',
        ),
      ).list();

      expect(terminals.single.id, 7);
    });

    // Пункт 7 фазы 3/4 закрытия долга: касса отвечает `terminal_limit_reached`
    // кадром отказа (`WtProtocolError` по проводу) — `register()` обязан
    // перевести его в `WireRefusal` с тем же кодом, тем же типом, каким
    // десктопный `LocalTerminalRepository.register()` бросает его напрямую.
    // Без перевода `login_controller.dart` не смог бы поймать один и тот же
    // смысл одним `catch` для обеих платформ.
    test(
      'register: потолок терминалов переводится в WireRefusal, не остаётся '
      'WtProtocolError',
      () async {
        await expectLater(
          WtTerminalRepository(
            answering(
              '{"ok":false,"code":"terminal_limit_reached",'
              '"detail":"на этой кассе уже заведено 200 терминалов"}',
            ),
          ).register(name: 'Терминал сверх потолка'),
          throwsA(
            isA<WireRefusal>().having(
              (e) => e.code,
              'code',
              'terminal_limit_reached',
            ),
          ),
        );
      },
    );

    test(
      'register: прочие отказы остаются WtProtocolError, не подделываются '
      'под WireRefusal',
      () async {
        await expectLater(
          WtTerminalRepository(
            answering('{"ok":false,"code":"bad_request","detail":"имя обязательно"}'),
          ).register(name: ''),
          throwsA(isA<WtProtocolError>()),
        );
      },
    );

    // Задача 5 плана «знакомство терминала с кассой» (шаг 2 спеки): тот же
    // приём перевода, что и у register/terminal_limit_reached выше — только
    // для второго кода отказа, который может дать эта операция.
    test('resume: касса вернула тот же терминал', () async {
      final terminal = await WtTerminalRepository(
        answering(
          '{"ok":true,"body":{"terminal":'
          '{"id":99,"name":"Терминал у окна","pointMode":"selfService"}}}',
        ),
      ).resume(terminalId: 99, secret: 'секрет-предъявленный-вкладкой');

      expect(terminal.id, 99);
    });

    test(
      'resume: чужой/испорченный секрет переводится в WireRefusal, не '
      'остаётся WtProtocolError',
      () async {
        await expectLater(
          WtTerminalRepository(
            answering(
              '{"ok":false,"code":"terminal_secret_invalid",'
              '"detail":"терминал не найден или предъявленный секрет не '
              'подходит"}',
            ),
          ).resume(terminalId: 99, secret: 'чужой-секрет'),
          throwsA(
            isA<WireRefusal>().having(
              (e) => e.code,
              'code',
              'terminal_secret_invalid',
            ),
          ),
        );
      },
    );

    test(
      'resume: прочие отказы остаются WtProtocolError, не подделываются под '
      'WireRefusal',
      () async {
        await expectLater(
          WtTerminalRepository(
            answering('{"ok":false,"code":"bad_request","detail":"terminalId обязателен"}'),
          ).resume(terminalId: 99, secret: 'что-нибудь'),
          throwsA(isA<WtProtocolError>()),
        );
      },
    );
  });

  group('устройства', () {
    test('не смогли спросить кассу — это не «ничего не нашлось»', () async {
      // Ради этого различия в контракте и появился `failedSources`: пустой
      // список означал бы «на кассе искренне нет устройств».
      final result = await WtDeviceDiscovery(
        dispatcherThatRefuses(),
        BuiltinDeviceProfileCatalog(),
      ).find(DeviceClass.receiptPrinter);

      expect(result.candidates, isEmpty);
      expect(
        result.failedSources,
        isNotEmpty,
        reason: 'терминал обязан сказать, чего именно он не смог спросить',
      );
    });

    test('проверка устройства при недостижимой кассе — исход, а не краш', () async {
      final outcome = await WtDeviceCheck(
        dispatcherThatRefuses(),
      ).check(terminalId: 1, deviceClass: DeviceClass.receiptPrinter);

      expect(outcome.reason, DeviceCheckReason.unexpectedError);
      expect(outcome.message, isNotEmpty);
    });
  });
}

/// Черновик мастера настройки. Содержимое здесь не проверяется — проверяется
/// то, что делает репозиторий с ответом кассы.
SetupDraft _draft() => const SetupDraft(
  countryIndex: 0,
  operatingModeIndex: 0,
  organization: OrganizationInfo(companyName: 'ТОО Ромашка'),
  posConfig: PosConfigInfo(cashBoxName: 'Касса-1'),
  fiscalConfig: FiscalConfigInfo(),
  businessRules: BusinessRulesConfigInfo(),
  equipment: EquipmentConfigInfo(),
  paymentTerminal: PaymentTerminalConfigInfo(),
  employees: [],
  firstUser: EmployeeInfo(),
);

FoundBackup _backup(int messageId) => FoundBackup(
  posKey: 'k',
  posName: 'p',
  organizationName: 'o',
  createdAt: DateTime.utc(2026, 8, 5),
  messageId: messageId,
  checksum: 'c',
  sizeBytes: 1,
);
