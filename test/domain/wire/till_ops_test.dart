import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/network/network_status.dart';
import 'package:telepos/domain/network/wifi_network.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/wire/auth_wire.dart';
import 'package:telepos/domain/wire/network_wire.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/domain/wire/terminal_wire.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_op.dart';

void main() {
  group('род операции', () {
    test('семь операций — подписки, и это цель всей смены транспорта', () {
      // Перестать спрашивать — единственная выгода, ради которой менялся
      // транспорт. Тест краснеет, если кто-то вернёт подписку в разряд
      // вопросов: состояние, которое приходится перезапрашивать, доезжает
      // не в момент события, а при следующем вопросе. auth.users и
      // auth.session — подписки по той же причине: заведённый кассир и
      // погашенный сеанс обязаны дойти в момент события, а не при
      // следующем вопросе экрана входа. auth.sessions (задача 19 закрытия
      // долга безопасности) — седьмая: чужой вход и чужой отзыв обязаны
      // дойти до экрана списка сеансов тем же путём.
      const watches = <WireOp<Object?, Object?>>[
        TillOps.setupState,
        TillOps.terminalsList,
        TillOps.terminalSelf,
        TillOps.deviceBindings,
        TillOps.authUsers,
        TillOps.authSession,
        TillOps.authSessions,
      ];

      for (final op in watches) {
        expect(op, isA<Watch>(), reason: '${op.name} обязана быть подпиской');
      }

      expect(
        TillOps.all.whereType<Watch>().toSet(),
        watches.toSet(),
        reason:
            'подписок ровно семь и ровно эти: новая подписка добавляется '
            'сюда сознательно, а не проскакивает мимо счёта',
      );
    });

    test('две операции — длинная работа с ходом выполнения', () {
      // Восстановление из копии и загрузка данных организации идут минутами.
      // До провода канала для хода выполнения не было вовсе, и код честно
      // писал о себе, что придумывать промежуточные числа отказывается.
      expect(TillOps.setupRestore, isA<Run>());
      expect(TillOps.setupLoadGlobalData, isA<Run>());

      expect(
        TillOps.all.whereType<Run>().toSet(),
        {TillOps.setupRestore, TillOps.setupLoadGlobalData},
        reason: 'длинных работ ровно две',
      );
    });

    test('девять операций из тридцати одной перестали быть вопросами', () {
      // Ровно это и просили от смены транспорта. Четыре подписки плюс две
      // длинных работы — те самые шесть из спеки; auth.users и auth.session
      // добавили ещё две подписки — те самые восемь. auth.sessions (задача
      // 19 закрытия долга безопасности) добавила девятую. Остальные
      // двадцать две остаются вопросами, потому что вопросами и являются:
      // заведение, возврат по секрету, переименование и удаление терминала,
      // поиск устройства и его проверка, вход/выход, отзыв чужого сеанса, а
      // теперь и шесть сетевых операций (задача «сетевые настройки по
      // проводу», спека 2026-08-24) — это действия, а не состояния, за
      // которыми следят: экран и так опрашивает сеть раз в четыре секунды.
      // `terminals.resume` (задача 5 плана «знакомство терминала с кассой»)
      // — вопрос, а не подписка: она отвечает один раз и закрывается, тем
      // же родом, что и `terminals.register`, рядом с которым заведена.
      expect(TillOps.all, hasLength(31));
      expect(TillOps.all.whereType<Ask>(), hasLength(22));
      expect(TillOps.all.where((op) => op is! Ask), hasLength(9));
    });
  });

  group('имена', () {
    test('имена операций уникальны', () {
      // Два описания под одним именем — молчаливая подмена обработчика:
      // касса ищет обработчик по имени и найдёт тот, что зарегистрирован
      // последним, ничего не сказав про первый.
      final names = TillOps.all.map((op) => op.name).toList();
      expect(names.toSet(), hasLength(names.length), reason: '$names');
    });

    test('в имени операции нет косой черты', () {
      // Маршрутов больше нет, есть операции. Косая черта означала бы, что
      // путь URL просочился обратно под видом имени, — а вместе с ним и
      // согласование концов по строке, которое стоило белого экрана
      // 2026-08-04.
      for (final op in TillOps.all) {
        expect(
          op.name.contains('/'),
          isFalse,
          reason: '${op.name} — это путь, а не имя операции',
        );
      }
    });

    test('каждая объявленная операция входит в TillOps.all', () {
      // Иначе проверки уникальности и косой черты доказывают что-то только
      // про подмножество, а операция, забытая в списке, тихо от них уходит.
      const declared = <WireOp<Object?, Object?>>[
        TillOps.startupBoot,
        TillOps.setupFirstLaunch,
        TillOps.setupState,
        TillOps.setupBackups,
        TillOps.setupRestore,
        TillOps.setupLoadGlobalData,
        TillOps.setupNewPos,
        TillOps.setupComplete,
        TillOps.terminalsList,
        TillOps.terminalSelf,
        TillOps.deviceBindings,
        TillOps.deviceBindingSave,
        TillOps.terminalRename,
        TillOps.terminalRegister,
        TillOps.terminalResume,
        TillOps.terminalDelete,
        TillOps.terminalSelfEnsure,
        TillOps.deviceDiscovery,
        TillOps.deviceCheck,
        TillOps.authUsers,
        TillOps.authLogin,
        TillOps.authLogout,
        TillOps.authSession,
        TillOps.authSessions,
        TillOps.authSessionRevoke,
        TillOps.networkStatus,
        TillOps.networkWifiScan,
        TillOps.networkWifiConnect,
        TillOps.networkWifiDisconnect,
        TillOps.networkEthernetStatus,
        TillOps.networkEthernetConfigure,
      ];

      expect(TillOps.all.toSet(), declared.toSet());
    });

    test('каждый метод каждого договора имеет свою операцию', () {
      // Договор, у которого на проводе нет одного метода, — это биндинг,
      // отказывающий в одном месте из четырёх, и узнать об этом можно только
      // нажав кнопку. Здесь перечислено то, что браузерные репозитории
      // обязаны уметь; забытая операция краснеет тут, а не в поле.
      final names = TillOps.all.map((op) => op.name).toSet();

      expect(names, containsAll(<String>[
        'terminals.list', // TerminalRepository.list / watchAll
        'terminals.self', // .watchSelf — наблюдение, строки не заводит
        'terminals.selfEnsure', // .self — заводит, если терминала ещё нет
        'terminals.register', // .register
        'terminals.resume', // .resume — задача 5, возврат по секрету
        'terminals.rename', // .rename
        'terminals.delete', // .delete
        'terminals.deviceBindings', // DeviceBindingRepository.forTerminal
        'terminals.deviceBindingSave', // .save
        'terminals.deviceDiscovery', // DeviceDiscovery.find
        'terminals.deviceCheck', // DeviceCheck.check
      ]));
    });
  });

  group('разбор ответа', () {
    test('список терминалов разбирается той же парой, что его и пишет', () {
      // Операция не заводит третьего читателя формы: её `decode` зовёт
      // `terminalFromWireJson` — ту же половину пары, которой касса пишет
      // ответ. Иначе каталог операций стал бы ровно тем расхождением,
      // ради устранения которого пары и сводились.
      const terminal = Terminal(
        id: 3,
        name: 'Касса-3',
        pointMode: PointMode.kitchen,
      );

      final decoded = TillOps.terminalsList.decode({
        'terminals': [terminalToWireJson(terminal)],
      });

      expect(decoded, hasLength(1));
      expect(decoded.single.id, 3);
      expect(decoded.single.pointMode, PointMode.kitchen);
    });

    test('привязки устройств разбираются той же парой', () {
      const binding = DeviceBinding(
        deviceClass: DeviceClass.scale,
        profileId: 'cas_er_plus',
        parameters: {'comPort': 'COM3'},
        enabled: false,
      );

      final decoded = TillOps.deviceBindings.decode({
        'bindings': [deviceBindingToWireJson(binding)],
      });

      expect(decoded.single.deviceClass, DeviceClass.scale);
      expect(decoded.single.enabled, isFalse);
    });

    test('состояние установки разбирается той же парой', () {
      final decoded = TillOps.setupState.decode(
        setupStateToWireJson(
          const SetupState(configured: true, hasUsers: true),
        ),
      );

      expect(decoded.configured, isTrue);
      expect(decoded.hasUsers, isTrue);
    });

    test('отсутствие собственного терминала — null, а не выдуманный', () {
      // Свежая установка мастер настройки ещё не проходила, и настоящего
      // имени кассы нет. `TerminalRepository.self()` отказывается его
      // выдумывать; провод обязан отказываться так же.
      expect(TillOps.terminalSelf.decode(const {}), isNull);
    });

    test('нераспознанное имя состояния загрузки не угадывается', () {
      // Касса новее терминала — обычное состояние при обновлении по одной
      // машине. Худшее, что можно сделать, — выдать неизвестный отказ за
      // `success`.
      expect(
        TillOps.startupBoot.decode(const {'status': 'quantumFailure'}),
        AppInitStatus.databaseFailure,
      );
      expect(
        TillOps.startupBoot.decode(const {'status': 'success'}),
        AppInitStatus.success,
      );
    });

    test('нераспознанный итог первого запуска не угадывается', () {
      expect(
        TillOps.setupFirstLaunch.decode(const {'result': 'quantumMode'}),
        FirstLaunchResult.offlineMode,
      );
    });

    test('список сеансов разбирается той же парой, что его и пишет', () {
      // Задача 19 закрытия долга безопасности. Токена в форме нет — см.
      // докстринг `LiveSession`/`liveSessionToWireJson`.
      final decoded = TillOps.authSessions.decode({
        'sessions': [
          liveSessionToWireJson((
            terminalId: 5,
            userId: 7,
            name: 'Айгуль',
            role: 'cashier',
            issuedAt: DateTime.utc(2026, 8, 22, 10),
            expiresAt: DateTime.utc(2026, 8, 22, 10, 30),
          )),
        ],
      });

      expect(decoded, hasLength(1));
      expect(decoded.single.terminalId, 5);
      expect(decoded.single.userId, 7);
      expect(decoded.single.name, 'Айгуль');
      // Токена в записи нет структурно — `LiveSession` его не несёт полем,
      // а не полагается на то, что вызывающий код не прочитает то, что
      // забыл проверить. Отдельной проверки на рантайме это не требует:
      // код, обратившийся к `.token`, не скомпилировался бы вовсе.
    });
  });

  group('запрос', () {
    test('восстановление шлёт идентификатор сообщения, а не всю копию', () {
      // Копия у кассы уже есть — она её и нашла. Слать её обратно означало
      // бы гонять мегабайты по проводу ради одного числа.
      final body = TillOps.setupRestore.encode(
        FoundBackup(
          posKey: 'k',
          posName: 'p',
          organizationName: 'o',
          createdAt: DateTime.utc(2026, 8, 4),
          messageId: 77,
          checksum: 'c',
          sizeBytes: 1,
        ),
      );

      expect(body, {'messageId': 77});
    });

    test('сохранение привязки несёт терминал и саму привязку', () {
      const binding = DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: 'generic_escpos',
      );

      final body = TillOps.deviceBindingSave.encode(
        (terminalId: 5, binding: binding),
      );

      expect(body['terminalId'], 5);
      expect(
        body['binding'],
        deviceBindingToWireJson(binding),
        reason: 'форма привязки — общая пара, а не четвёртая рукописная копия',
      );
    });

    test('переименование несёт терминал и имя', () {
      final body = TillOps.terminalRename.encode(
        (terminalId: 5, name: 'Касса у входа'),
      );

      expect(body, {'terminalId': 5, 'name': 'Касса у входа'});
    });

    test('привязки устройств спрашиваются про конкретный терминал', () {
      expect(TillOps.deviceBindings.encode(9), {'terminalId': 9});
    });

    test('отзыв сеанса называет терминал, не токен', () {
      // Задача 19 закрытия долга безопасности: тело отзыва пишет тот, кто
      // отзывает чужой сеанс, а токена у него на руках нет — экран списка
      // сеансов его и не показывает.
      expect(TillOps.authSessionRevoke.encode(5), {'terminalId': 5});
    });

    test('возврат по секрету несёт терминал и секрет — задача 5', () {
      final body = TillOps.terminalResume.encode((
        terminalId: 5,
        secret: 'секрет-предъявленный-вкладкой',
      ));

      expect(body, {
        'terminalId': 5,
        'secret': 'секрет-предъявленный-вкладкой',
      });
    });
  });

  group('сеть кассы — задача «сетевые настройки по проводу», 2026-08-24', () {
    test('состояние сети разбирается той же парой, что его и пишет', () {
      const status = NetworkStatus(
        wifiConnected: true,
        wifiSsid: 'Магазин-1',
        wifiSignal: 71,
        ethernetConnected: false,
        ethernetInterface: null,
        internet: true,
      );

      final decoded = TillOps.networkStatus.decode(
        networkStatusToWireJson(status),
      );

      expect(decoded.wifiConnected, isTrue);
      expect(decoded.wifiSsid, 'Магазин-1');
      expect(decoded.wifiSignal, 71);
      expect(decoded.ethernetConnected, isFalse);
      expect(decoded.internet, isTrue);
    });

    test('список сетей Wi-Fi разбирается той же парой', () {
      const network = WifiNetwork(ssid: 'Кафе', signal: 55, security: 'WPA2');

      final decoded = TillOps.networkWifiScan.decode({
        'networks': [wifiNetworkToWireJson(network)],
      });

      expect(decoded, hasLength(1));
      expect(decoded.single.ssid, 'Кафе');
      expect(decoded.single.isSecured, isTrue);
    });

    test('подключение к Wi-Fi несёт ssid и пароль, только если он есть', () {
      expect(
        TillOps.networkWifiConnect.encode((ssid: 'Кафе', password: 'секрет')),
        {'ssid': 'Кафе', 'password': 'секрет'},
      );
      expect(
        TillOps.networkWifiConnect.encode((ssid: 'Открытая', password: null)),
        {'ssid': 'Открытая'},
        reason: 'открытая сеть — без ключа `password` вовсе, не с пустой строкой',
      );
    });

    test('исход подключения разбирается из success/message', () {
      final decoded = TillOps.networkWifiConnect.decode({
        'success': true,
        'message': 'подключено',
      });
      expect(decoded.success, isTrue);
      expect(decoded.message, 'подключено');
    });

    test('отключение Wi-Fi разбирается как ok', () {
      expect(TillOps.networkWifiDisconnect.decode(const {'ok': true}), isTrue);
      expect(TillOps.networkWifiDisconnect.decode(const {}), isFalse);
    });

    test(
      'настройка Ethernet едет одним методом на оба режима, DHCP без лишних полей',
      () {
        expect(
          TillOps.networkEthernetConfigure.encode((
            iface: 'eth0',
            mode: 'dhcp',
            ipCidr: null,
            gateway: null,
            dns: null,
          )),
          {'iface': 'eth0', 'mode': 'dhcp'},
        );
      },
    );

    test('настройка Ethernet статикой несёт адрес, шлюз и DNS', () {
      expect(
        TillOps.networkEthernetConfigure.encode((
          iface: 'eth0',
          mode: 'static',
          ipCidr: '192.168.1.50/24',
          gateway: '192.168.1.1',
          dns: '8.8.8.8',
        )),
        {
          'iface': 'eth0',
          'mode': 'static',
          'ipCidr': '192.168.1.50/24',
          'gateway': '192.168.1.1',
          'dns': '8.8.8.8',
        },
      );
    });

    test('исход настройки Ethernet разбирается из success/mode', () {
      final decoded = TillOps.networkEthernetConfigure.decode({
        'success': true,
        'mode': 'static',
      });
      expect(decoded.success, isTrue);
      expect(decoded.mode, 'static');
    });

    test(
      'подробности проводного интерфейса едут как пришли, без собственной '
      'модели',
      () {
        // Форма варьируется по тому, что вернул `ip -j addr show` на кассе
        // (докстринг `NetworkRepository.ethernetStatus`) — разбор не сужает
        // её, только возвращает тело кадра как есть.
        final decoded = TillOps.networkEthernetStatus.decode({
          'interfaces': [
            {'ifname': 'eth0'},
          ],
        });
        expect(decoded['interfaces'], hasLength(1));
      },
    );

    test('все шесть сетевых операций объявлены OpenAccess', () {
      // Экран публичный и на десктопе (доступен с экрана входа и из
      // мастера) — граница спеки 2026-08-24.
      for (final op in const [
        'network.status',
        'network.wifiScan',
        'network.wifiConnect',
        'network.wifiDisconnect',
        'network.ethernetStatus',
        'network.ethernetConfigure',
      ]) {
        final found = TillOps.all.firstWhere((o) => o.name == op);
        expect(found.access, isA<OpenAccess>(), reason: op);
        expect(found, isA<Ask>(), reason: '$op обязана быть вопросом, не подпиской');
      }
    });
  });

  group('разбор ответа: возврат по секрету — задача 5', () {
    test('терминал разбирается той же парой, что и terminals.list/self', () {
      final decoded = TillOps.terminalResume.decode({
        'terminal': {'id': 5, 'name': 'Касса у входа', 'pointMode': 'cashier'},
      });

      expect(decoded.id, 5);
      expect(decoded.name, 'Касса у входа');
      expect(decoded.pointMode, PointMode.cashier);
    });

    test('отсутствующий терминал в ответе — StateError, не null', () {
      // В отличие от `terminals.self`: заведение либо состоялось (терминал
      // в ответе), либо касса отказала кадром отказа раньше, чем разбор
      // сюда дошёл — третьего исхода «завёлся, но неизвестно как» нет.
      expect(
        () => TillOps.terminalResume.decode(const {}),
        throwsA(isA<StateError>()),
      );
    });
  });
}
