// Задача 5 (`.superpowers/sdd/2026-08-21-security-debt-closure/task-5-brief.md`):
// терминал отличает истёкший сеанс от обрыва связи и **уходит на вход сам**,
// без единого нажатия. Задача 4 завела `SessionLost` и разбор кодов сторожа
// (`WireDenied.unauthorized` -> `SessionLost`, `forbidden` -> рядовой отказ,
// `lib/web/wt_dispatcher.dart`); эта задача доводит обе стороны — живую
// подписку на сеанс и общую реакцию на `SessionLost` — до конца.
//
// Два круга правил здесь важны одинаково:
//
// 1. `watchSession(token).first` (было) читал сеанс один раз на подъёме и
//    отменял подписку. `authSession` — push от кассы (докстринг
//    `TillOps.authSession`, `lib/domain/wire/till_ops.dart`): касса,
//    погасившая или отозвавшая сеанс, обязана сказать об этом сама. Разовое
//    чтение эту половину не использовало вовсе.
// 2. `forbidden` не имеет права уводить на вход: у кассира с живым сеансом,
//    которому просто не хватает права, вход заново даст тот же отказ —
//    круг, найденный и закрытый задачей 4
//    (`lib/domain/wire/session_lost.dart`, докстринг).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/session_token_storage.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/terminal/terminal_secret_storage.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:telepos/web/wt_device_check.dart';

import '../../web/support/fake_dispatcher.dart';
import 'support/fakes.dart';
import 'package:telepos/domain/shift/shift_status.dart';

AuthSession _session(String token, {DateTime? expiresAt}) => AuthSession(
  token: token,
  userId: 9,
  name: 'Данара',
  role: 'cashier',
  permissions: const {'nav.sale'},
  operatingMode: 0,
  pointMode: 'cashier',
  shift: ShiftStatus.open,
  issuedAt: DateTime.now().subtract(const Duration(minutes: 5)),
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 25)),
  terminalId: 1,
);

void main() {
  late FakeAuthRepository auth;
  late FakeSessionTokenStorage tokenStore;

  setUp(() {
    final getIt = GetIt.instance;
    auth = FakeAuthRepository();
    tokenStore = FakeSessionTokenStorage()
      ..write('tok-live', DateTime.now().add(const Duration(minutes: 30)));

    getIt
      ..registerSingleton<TerminalIdentity>(FakeTerminalIdentity())
      ..registerSingleton<HostCapabilities>(HostCapabilities.browser)
      // Пункт 2 фазы 3/4 закрытия долга: браузер больше не находит
      // `terminalId` в `TerminalIdentity` — каждая сессия обязана предъявить
      // себя кассе заново (`login_controller.dart`, `_resolveTerminalId`).
      // С задачи 7 плана «знакомство терминала с кассой» (разбор блокера)
      // это означает `resume()` по сохранённому секрету, а не голый
      // `register()`: с задачи 6 регистрация без кода привязки, которого
      // этому файлу спрашивать не о чем, всегда отказывает
      // `pairing_code_invalid`. Секрет предъявлен заранее — тем же приёмом,
      // каким настоящая вкладка переживает F5 (`terminal_repository.dart`,
      // докстринг `resume`), — файл проверяет отзыв/истечение сеанса, а не
      // само заведение терминала, и его дело не мешать.
      ..registerSingleton<TerminalSecretStorage>(
        FakeTerminalSecretStorage()
          ..write(1, FakeTerminalRepository.fakeSecret),
      )
      ..registerSingleton<TerminalRepository>(
        FakeTerminalRepository(
          resume: (terminalId, secret) async => const Terminal(
            id: 1,
            name: 'Терминал у кассы',
            pointMode: PointMode.cashier,
          ),
        ),
      )
      ..registerSingleton<AuthRepository>(auth)
      ..registerSingleton<SessionTokenStorage>(tokenStore);
  });

  tearDown(() => GetIt.instance.reset());

  group('живая подписка на сеанс', () {
    test('сеанс отзывается на кассе → нотифаер сам уходит на «не вошёл», '
        'причина названа, токен вычищен — без единого вызова со стороны '
        'интерфейса', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      // Первое событие — сеанс жив, как при обычном подъёме вкладки.
      auth.pushSession('tok-live', _session('tok-live'));
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(loginControllerProvider).isAuthenticated,
        isTrue,
        reason: 'сеанс обязан был приняться — иначе тест ни о чём не судит',
      );

      // Второе событие на ТОЙ ЖЕ подписке — касса отозвала сеанс. Красный
      // без правки: старый `.first` отменял подписку сразу после первого
      // значения, и это событие никто бы не услышал.
      auth.pushSession('tok-live', null);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(loginControllerProvider).isAuthenticated,
        isFalse,
        reason: 'отозванный сеанс обязан вывести из «вошёл» сам',
      );
      expect(
        container.read(loginControllerProvider).sessionEndedReason,
        'error.session_ended',
        reason:
            'касса ответила null — отозван владельцем или выметен по '
            'бездействию, различить эти два случая отсюда нечем, и '
            'выдумывать различие, которого нет в данных, не стоит',
      );
      expect(container.read(appStateProvider).isLoggedIn, isFalse);
      expect(
        tokenStore.read(),
        isNull,
        reason: 'токен без сеанса за ним — риск, а не информация',
      );
    });

    test(
      'сеанс истекает во время подписки (expiresAt в прошлом) — тот же исход',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(loginControllerProvider.notifier);
        notifier.initialize();
        await Future<void>.delayed(Duration.zero);

        auth.pushSession('tok-live', _session('tok-live'));
        await Future<void>.delayed(Duration.zero);
        expect(container.read(loginControllerProvider).isAuthenticated, isTrue);

        // Касса когда-нибудь могла бы снова отдать неотфильтрованную запись
        // (докстринг `_restoreSession`/`_endSession`) — клиент обязан
        // проверить `expiresAt` сам, а не только принять `null`.
        auth.pushSession(
          'tok-live',
          _session(
            'tok-live',
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(loginControllerProvider).isAuthenticated,
          isFalse,
        );
        expect(
          container.read(loginControllerProvider).sessionEndedReason,
          'error.session_expired',
          reason:
              'здесь у клиента есть прямая улика — `expiresAt` в прошлом, а '
              'не только молчание кассы, — и причина обязана назвать именно '
              'это, а не общее «сеанс завершён»',
        );
        expect(tokenStore.read(), isNull);
      },
    );

    // Пере-ревью финального разбора фазы 2, пункт 3: `SessionRegistry.watch`
    // на настоящей кассе никогда не отдаёт запись с `expiresAt` в прошлом —
    // первой строкой она чистит просроченное (`lib/backend/session_registry.dart`).
    // Значит `error.session_expired` из теста выше недостижим против настоящей
    // кассы вовсе: касса истечения по бездействию отвечает `null`, тем же
    // кадром, каким отвечает и на отзыв владельцем. До правки оба случая
    // назывались одним и тем же `error.session_ended` — экран приписывал
    // кассе действие («сеанс завершён на кассе»), которого она в этом, самом
    // частом случае, не совершала.
    test('null от кассы после честного истечения срока — session_expired, а не '
        'session_ended', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      // Срок — считаные миллисекунды: достаточно короткий, чтобы честно
      // пройти его в реальном времени теста, не подделывая часы контроллера
      // (в `LoginNotifier` часы не инъецируемы, и это тест, а не сама
      // кассовая логика счёта срока).
      auth.pushSession(
        'tok-live',
        _session(
          'tok-live',
          expiresAt: DateTime.now().add(const Duration(milliseconds: 30)),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(loginControllerProvider).isAuthenticated,
        isTrue,
        reason: 'сеанс обязан был приняться — иначе тест ни о чём не судит',
      );

      // Ждём честного прохождения срока.
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Касса отвечает `null` — не записью с `expiresAt` в прошлом, ровно
      // так, как отвечает настоящий `SessionRegistry.watch`.
      auth.pushSession('tok-live', null);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(loginControllerProvider).isAuthenticated, isFalse);
      expect(
        container.read(loginControllerProvider).sessionEndedReason,
        'error.session_expired',
        reason:
            'у клиента есть прямая улика — последний известный expiresAt в '
            'прошлом, а не только молчание кассы, — красный без правки: '
            'до неё `null` от кассы всегда назывался `error.session_ended`, '
            'даже когда срок явно истёк',
      );
      expect(tokenStore.read(), isNull);
    });
  });

  // Пере-ревью финального разбора фазы 2, пункт 2: `_restoreSession` заводит
  // живую подписку только там, где есть что восстанавливать
  // (`_tokenStore.read() != null`) — до этой правки `_onSession`, которым
  // `_verifyPin` разбирает успешный вход PIN-ом, писала токен в хранилище, но
  // подписку не заводила вовсе. Все четыре теста группы выше кладут токен в
  // хранилище ДО `initialize()`, то есть идут путём F5-восстановления, — этот
  // путь никто из них не проверяет.
  group('вход PIN-ом заводит подписку сам, не только F5-восстановление', () {
    test('вошёл PIN-ом → касса отозвала сеанс → вкладка на входе, без единой '
        'перезагрузки', () async {
      // Свежая вкладка: токен читается пустым в момент `initialize()` —
      // `setUp()` кладёт 'tok-live' заранее ровно для теста, а этому нужен
      // самый первый заход, где восстанавливать нечего.
      final freshTokenStore = FakeSessionTokenStorage();
      GetIt.instance
        ..unregister<SessionTokenStorage>()
        ..registerSingleton<SessionTokenStorage>(freshTokenStore);

      final freshSession = _session('tok-fresh');
      final freshAuth = FakeAuthRepository(freshSession);
      GetIt.instance
        ..unregister<AuthRepository>()
        ..registerSingleton<AuthRepository>(freshAuth);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(
        freshTokenStore.read(),
        isNull,
        reason: 'предпосылка — вкладка свежая, восстанавливать нечего',
      );

      // Шесть цифр — дальше набирать некуда, проверяется без debounce
      // (см. докстринг `_scheduleVerify`): быстрее и не зависит от
      // реального времени.
      for (final digit in ['1', '2', '3', '4', '5', '6']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      expect(
        container.read(loginControllerProvider).isAuthenticated,
        isTrue,
        reason: 'вход обязан был состояться — иначе тест ни о чём не судит',
      );
      expect(freshTokenStore.read(), 'tok-fresh');

      // Касса отзывает только что выписанный сеанс — не через
      // восстановление, а через ту же подписку, которую вход PIN-ом обязан
      // завести сам. Красный без правки: до неё это событие никто бы не
      // услышал — вкладка осталась бы «вошедшей» до следующей перезагрузки.
      freshAuth.pushSession('tok-fresh', null);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(loginControllerProvider).isAuthenticated,
        isFalse,
        reason:
            'подписка, заведённая после входа PIN-ом, обязана довести '
            'отзыв до вкладки без единой перезагрузки',
      );
      expect(
        container.read(loginControllerProvider).sessionEndedReason,
        'error.session_ended',
      );
      expect(freshTokenStore.read(), isNull);
    });
  });

  group('SessionLost из операции', () {
    test('SessionLost, пойманный любой операцией, даёт тот же исход, что живая '
        'подписка', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      auth.pushSession('tok-live', _session('tok-live'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(loginControllerProvider).isAuthenticated, isTrue);

      // Не через живую подписку вовсе — прямой вызов реакции, как это
      // сделал бы экран, поймавший `SessionLost` из `DeviceCheck`,
      // `DeviceBindingRepository` или `TerminalRepository`
      // (`lib/web/wt_device_check.dart` и соседи, задача 4).
      notifier.sessionLost(
        const SessionLost('terminals.rename: сеанс неизвестен или истёк'),
      );

      expect(container.read(loginControllerProvider).isAuthenticated, isFalse);
      expect(
        container.read(loginControllerProvider).sessionEndedReason,
        'error.session_ended',
        reason:
            '`WireDenied.unauthorized` — «токена нет, или сеанс по нему '
            'неизвестен/истёк» одним кодом, без более точной причины '
            '(докстринг `wire_guard.dart`); текст `error.detail` не '
            'разбирается — канал текста исключения закрыт задачей 2б',
      );
      expect(container.read(appStateProvider).isLoggedIn, isFalse);
      expect(tokenStore.read(), isNull);
    });

    test('forbidden с настоящей кассы не уводит на вход — вошедший остаётся '
        'вошедшим', () async {
      // Настоящий провод (`fake_dispatcher.dart`, тот же стенд, каким
      // задача 4 доказала `test/web/wt_session_lost_test.dart`), а не
      // фабрикованный `SessionLost` вручную: код `forbidden` обязан не
      // дойти до `LoginNotifier` вовсе, а не быть отфильтрован дисциплиной
      // вызывающего.
      const forbiddenFrame =
          '{"ok":false,"code":"forbidden",'
          '"detail":"terminals.deviceCheck: нет права settings.hardware"}';

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      auth.pushSession('tok-live', _session('tok-live'));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(loginControllerProvider).isAuthenticated,
        isTrue,
        reason: 'сеанс обязан был приняться — иначе тест ни о чём не судит',
      );

      // Операция экрана настроек, которой не хватает права — тот самый
      // случай из докстринга `SessionLost`, ради которого код сторожа
      // разделили на `unauthorized`/`forbidden` (задача 4).
      final outcome = await WtDeviceCheck(
        answering(forbiddenFrame),
      ).check(terminalId: 1, deviceClass: DeviceClass.receiptPrinter);

      expect(
        outcome.reason,
        DeviceCheckReason.unexpectedError,
        reason: 'forbidden не бросает SessionLost — он остаётся исходом',
      );

      // Главное утверждение: экран не имеет ЧЕГО передать в `sessionLost`
      // (сигнатура требует `SessionLost`, а не `WtProtocolError`), и
      // состояние нотифаера, который уже держал живой сеанс, не тронуто ни
      // одним байтом.
      expect(
        container.read(loginControllerProvider).isAuthenticated,
        isTrue,
        reason: 'нехватка права не имеет права выкинуть на вход',
      );
      expect(
        container.read(loginControllerProvider).sessionEndedReason,
        isNull,
        reason: 'причины «сеанс кончился» здесь нет и не может быть',
      );
      expect(container.read(appStateProvider).isLoggedIn, isTrue);
      expect(
        tokenStore.read(),
        isNotNull,
        reason: 'токен живого сеанса не тронут отказом по праву',
      );
    });
  });
}
