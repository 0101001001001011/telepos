/// Место сеанса и место сессии — круг правки 3 задачи 19, находки C1 и C2.
///
/// **C1: «место» существовало в двух разных смыслах.** Гашение при выдаче
/// сеанса (круг 2) смотрит на место, привязанное к токену **в момент
/// входа**; ключ черновика возврата — на место, привязанное к QUIC-сессии
/// **сейчас**. `terminals.resume` и `terminals.selfEnsure` переставляют
/// второе на живой сессии, токен при этом не перевыписывается, и гашение
/// проходит мимо:
///
/// ```
/// младший регистрирует место B, входит (в токене B)
/// младший зовёт resume(A) — место сессии стало A, токен по-прежнему про B
/// старший входит на A → гасит сеансы с terminalId == A, а у младшего B → ЖИВ
/// старший заводит безчековый черновик на A
/// младший своим токеном: addProduct → Ok, complete → Ok, касса 0 → −500
/// ```
///
/// Лечится не третьей заплатой, а сторожем: **место в сеансе обязано
/// совпадать с местом, привязанным к сессии сейчас**, для всех операций,
/// которым нужен сеанс. Сменил рабочее место — представься заново.
///
/// **C2: вход по проводу выбивал кассира с экрана самой кассы.** Десктопная
/// касса выписывает сеанс на свой терминал (`isSelf`), а
/// `terminals.selfEnsure` открыт, кода привязки не спрашивает и отдаёт **ту
/// же строку**. После круга 2 любая вкладка в сети, войдя одним
/// действительным PIN-ом, гасила сеанс кассира за самой кассой — и могла
/// повторять это сколько угодно.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';

import '../data/transport/fake_quic_server.dart';

const _seniorId = 1;
const _juniorId = 2;

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

void main() {
  late AppDatabase db;
  late FakeQuicServer server;
  late SessionRegistry sessions;
  late PairingInvites invites;
  late TillOperations operations;
  late TillWire wire;
  var streamId = 4;

  /// Один обмен и **его** первый кадр.
  ///
  /// Не `sentFrames.last`: подписка (`terminals.list`) остаётся живой и
  /// дописывает свои кадры после, так что «последний» принадлежал бы уже не
  /// этому вызову. Отсчёт от длины до обмена — то же, что делает
  /// `till_watch_test.dart`, когда считает кадры подписки.
  Future<WireFrame> call(
    String op,
    Map<String, Object?> body, {
    String? token,
    int sessionId = 1,
  }) async {
    final before = server.sentFrames.length;
    server.emitStreamOpened(sessionId: sessionId, streamId: ++streamId);
    server.emitStreamData(
      sessionId: sessionId,
      streamId: streamId,
      message: jsonEncode({
        'op': op,
        'body': body,
        if (token != null) 'token': token,
      }),
    );
    server.emitStreamClosed(sessionId: sessionId, streamId: streamId);
    // Ждём кадр СВОЕГО обмена, а не фиксированное число оборотов цикла:
    // настоящий вход считает PBKDF2 и отвечает не на первом обороте, а
    // подписка рядом дописывает свои кадры не по нашему поводу.
    for (var i = 0; i < 200 && server.sentFrames.length <= before; i++) {
      // Не микрозадача: настоящий вход считает PBKDF2 и отвечает через
      // настоящее время, а не через оборот цикла (тот же приём и та же
      // причина, что у `terminal_login_session_binding_test.dart`).
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      server.sentFrames.length,
      greaterThan(before),
      reason: 'касса не ответила на $op',
    );
    return WireFrame.decode(server.sentFrames[before]);
  }

  Future<int> registerTerminal({int sessionId = 1, String name = 'Планшет'}) =>
      call(
        TillOps.terminalRegister.name,
        {'name': name, 'code': invites.mint().code},
        sessionId: sessionId,
      ).then((f) => ((f as OkFrame).body['terminal']! as Map)['id']! as int);

  Future<String> loginAs(int userId, {int sessionId = 1}) async {
    final frame = await call(TillOps.authLogin.name, {
      'pin': '1234',
      'userId': userId,
    }, sessionId: sessionId);
    final body = (frame as OkFrame).body;
    expect(body['ok'], isTrue, reason: 'вход $userId: $body');
    return (body['session']! as Map)['token']! as String;
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeQuicServer();
    sessions = SessionRegistry();
    invites = PairingInvites();
    streamId = 4;

    // Касса настроена: `terminals.selfEnsure` обязан отдавать настоящую
    // строку, а не `null`, — иначе проба C2 мерила бы ненастроенную кассу.
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            cashBoxName: Value('Касса-1'),
          ),
        );
    await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');

    for (final name in const ['Старший', 'Младший']) {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              name: Value(name),
              role: const Value(3),
              status: const Value('active'),
              passwordEnc: Value(PinCredential.create('1234')),
            ),
          );
    }

    operations = TillOperations(
      db: db,
      bootstrap: _NoopBootstrap(),
      setup: _NoopSetup(),
      terminals: LocalTerminalRepository(db),
      deviceBindings: LocalDeviceBindingRepository(
        db,
        BuiltinDeviceProfileCatalog(),
      ),
      // Настоящий вход, а не подделка: правка C2 живёт в
      // `LocalAuthRepository._issue` (там читается `isSelf` терминала), и
      // подделка, зовущая `mint` мимо неё, проверяла бы не то место.
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
      ),
      invites: invites,
    );

    wire = TillWire(
      server,
      operations.askHandlers,
      watchHandlers: operations.watchHandlers,
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: sessions,
        boundTerminalId: operations.terminalForSessionKey,
      ),
    )..start();
  });

  tearDown(() async {
    await wire.stop();
    await server.dispose();
    await db.close();
  });

  group('C1: место сеанса обязано совпадать с местом сессии', () {
    test(
      'возобновление чужого места после входа делает токен непригодным',
      () async {
        // Вкладка младшего заводит своё место B и входит на нём.
        final b = await registerTerminal(name: 'Место Б');
        final junior = await loginAs(_juniorId);
        expect(
          await call(TillOps.terminalsList.name, const {}, token: junior),
          isA<UpdateFrame>(),
          reason: 'до подмены токен обязан работать — иначе проба пуста',
        );

        // Заводим чужое место A и берём его секрет — так же, как это делает
        // соседняя вкладка, у которой оно своё.
        final registered =
            (await call(TillOps.terminalRegister.name, {
                  'name': 'Место А',
                  'code': invites.mint().code,
                }, sessionId: 2))
                as OkFrame;
        final a = (registered.body['terminal']! as Map)['id']! as int;
        final secret = registered.body['secret']! as String;
        expect(a, isNot(b));

        // Та же живая сессия младшего переставляет своё место на A. Операция
        // открытая, сеанса не требует, токен не перевыписывается.
        expect(
          await call(TillOps.terminalResume.name, {
            'terminalId': a,
            'secret': secret,
          }, token: junior),
          isA<OkFrame>(),
        );

        // Прежний токен младшего больше не годится: в нём место B, а сессия
        // сидит на A.
        final frame = await call(
          TillOps.terminalsList.name,
          const {},
          token: junior,
        );
        expect(frame, isA<ErrorFrame>());
        expect((frame as ErrorFrame).code, 'terminal_changed');
      },
    );

    test('заведение нового места после входа — тем же правилом, без кода '
        'привязки не обойти', () async {
      await registerTerminal(name: 'Место Б');
      final junior = await loginAs(_juniorId);

      // Второе заведение на той же сессии переставляет место.
      await registerTerminal(name: 'Место В');

      final frame = await call(
        TillOps.terminalsList.name,
        const {},
        token: junior,
      );
      expect(frame, isA<ErrorFrame>());
      expect((frame as ErrorFrame).code, 'terminal_changed');
    });

    test('обычный порядок вкладки не задет: привязка до входа', () async {
      // Обратная сторона. Без неё правка вырождалась бы в «после входа
      // ничего нельзя», и первый же честный кассир получил бы отказ.
      final terminalId = await registerTerminal();
      final token = await loginAs(_seniorId);

      expect(
        await call(TillOps.terminalsList.name, const {}, token: token),
        isA<UpdateFrame>(),
      );
      expect(operations.terminalForSessionKey(1), terminalId);
    });

    test('экраны настроек оборудования не выбивают кассира: selfEnsure '
        'места не трогает', () async {
      // Четыре экрана настроек зовут `TerminalRepository.self()` на живой
      // сессии — в браузере это `terminals.selfEnsure`. Круг 3 лечил это
      // `putIfAbsent`, круг 4 вырезал запись целиком (блокер 1), и путь
      // остаётся целым по более сильной причине: переставлять привязку этой
      // операции больше нечем.
      final tab = await registerTerminal();
      final token = await loginAs(_seniorId);

      final self =
          (await call(TillOps.terminalSelfEnsure.name, const {}, token: token))
              as OkFrame;
      final selfId = (self.body['terminal']! as Map)['id']! as int;
      expect(selfId, isNot(tab), reason: 'касса и вкладка — разные строки');

      expect(
        operations.terminalForSessionKey(1),
        tab,
        reason: 'привязка сессии осталась на месте вкладки',
      );
      expect(
        await call(TillOps.terminalsList.name, const {}, token: token),
        isA<UpdateFrame>(),
        reason: 'кассир остался в системе после открытия настроек',
      );
    });

    test(
      'selfEnsure места не привязывает вовсе, и войти по нему нельзя',
      () async {
        // Круг правки 4, блокер 1: привязка здесь и была причиной. Она
        // открывала строку самой кассы любой сессии — `selfEnsure` не
        // спрашивает ни кода привязки, ни секрета, — и на этой строке
        // оказывались вдвоём, с общим черновиком возврата.
        final frame =
            (await call(TillOps.terminalSelfEnsure.name, const {})) as OkFrame;

        expect(
          frame.body['terminal'],
          isNotNull,
          reason: 'сам ответ прежний — операция отвечает про терминал кассы',
        );
        expect(
          operations.terminalForSessionKey(1),
          isNull,
          reason: 'но местом сессии он больше не становится',
        );

        // Следствие названо прямо: без register/resume войти по проводу
        // теперь нельзя вовсе.
        final login =
            (await call(TillOps.authLogin.name, {
                  'pin': '1234',
                  'userId': _seniorId,
                }))
                as ErrorFrame;
        expect(login.code, 'unknown_terminal');
      },
    );

    test('F5: восстановленный токен на новой сессии не отвергается', () async {
      // Круг правки 4, блокер 2. Вкладка, пережившая F5, поднимается с
      // восстановленным токеном на НОВОЙ QUIC-сессии и места до первой
      // команды не называет: `_restoreSession` заводит только подписку
      // `auth.session`, а она `OpenAccess`. Круг 3 отказывал и здесь, то есть
      // обычная перезагрузка страницы ломала вкладку целиком.
      await registerTerminal();
      final token = await loginAs(_seniorId);

      final frame = await call(
        TillOps.terminalsList.name,
        const {},
        token: token,
        sessionId:
            9, // новая сессия: та, что была, закрылась вместе со вкладкой
      );

      expect(operations.terminalForSessionKey(9), isNull);
      expect(
        frame,
        isA<UpdateFrame>(),
        reason:
            '«сессия ещё не назвала места» — законное состояние, а не '
            'расхождение: перепривязка расхождение, отсутствие привязки нет',
      );
    });
  });

  group('C2: вкладка в сети не трогает кассира за экраном кассы', () {
    test('на строку кассы по проводу войти нельзя, и сеанс её цел', () async {
      // Круг правки 3 закрывал это исключением `isSelf` из гашения — и тем
      // же движением возвращал на строку кассы двух человек сразу (блокер 1
      // круга 4). Круг 4 вырезал причину: `selfEnsure` места не привязывает,
      // поэтому вкладка не может ни войти на эту строку, ни, значит, кого-то
      // с неё выбить. Исключений в гашении больше нет.
      final selfId = (await db.terminalDao.self())!.id;
      final deskToken = sessions
          .mint(
            userId: _seniorId,
            name: 'Кассир за кассой',
            role: 'cashier',
            permissions: const {PermissionKeys.opRefund},
            operatingMode: 0,
            pointMode: 'cashier',
            shiftOpen: true,
            terminalId: selfId,
          )
          .token;

      await call(TillOps.terminalSelfEnsure.name, const {}, sessionId: 3);
      final login =
          (await call(TillOps.authLogin.name, {
                'pin': '1234',
                'userId': _juniorId,
              }, sessionId: 3))
              as ErrorFrame;

      expect(login.code, 'unknown_terminal');
      expect(
        sessions.sessionFor(deskToken),
        isNotNull,
        reason: 'кассира за кассой никто не выбил',
      );
    });

    test('на обычном рабочем месте гашение по-прежнему работает — круг 2 не '
        'отменён', () async {
      // Иначе исключение для терминала кассы выродилось бы в «не гасить
      // никогда», и находка круга 2 вернулась бы молча.
      final terminalId = await registerTerminal();
      final first = await loginAs(_seniorId);
      expect(sessions.sessionFor(first), isNotNull);

      await loginAs(_juniorId);

      expect(sessions.sessionFor(first), isNull);
      expect(operations.terminalForSessionKey(1), terminalId);
    });
  });
}
