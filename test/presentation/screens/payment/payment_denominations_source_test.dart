/// Раскладка номиналов приходит **от кассы**, а не выдумывается экраном —
/// задача 17.
///
/// # Зачем эта проба существует
///
/// Найдена проходом `anti-gaps` уже после переезда, и это ровно тот класс
/// дефекта, ради которого он и заведён: `denominationsProvider` сменил
/// источник данных — `GetIt.I<AppDatabase>()` на `StartupStateRepository`, —
/// и **ни один тест дерева не утверждал, что он возвращает**. Из 3573 проб
/// имя провайдера встречалось ровно в одном месте — в комментарии сторожа
/// слоёв.
///
/// Сторож `browser_routes_test.dart` доказывает только отсутствие базы в
/// замыкании импортов. Он остался бы зелёным в мире, где тело провайдера
/// заменили на `return _getDenominationsForCountry(null)`: базы нет, экран
/// собирается, номиналы у всех стран одинаковые и неправильные у четырёх из
/// пяти. Заглушка, молча возвращающая правдоподобное значение, — то самое,
/// чем была потеряна интеграция ОФД.
///
/// # Почему проверяются две страны, а не одна
///
/// Проба на одну страну зелена и тогда, когда страна не читается вовсе:
/// умолчание случайно совпало бы с ожиданием. Здесь сравниваются два
/// **разных** ответа, и первое, что утверждается, — что они вообще разные.
/// Иначе всё, что ниже, ничего не значит.
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

/// Касса, отвечающая на `setup.state`.
///
/// Считает подписки и отписки: `watch().first` обязан снять подписку, а не
/// оставить экран оплаты висеть на потоке кассы до конца работы вкладки.
class _FakeStartupState implements StartupStateRepository {
  _FakeStartupState(this.countryCode);

  final int? countryCode;

  /// Касса отказала — провод лёг, кассы нет, операция вернула отказ.
  bool fail = false;

  int watched = 0;
  int cancelled = 0;

  @override
  Stream<SetupState> watch() {
    watched++;
    late final StreamController<SetupState> controller;
    controller = StreamController<SetupState>(
      onListen: () {
        if (fail) {
          controller.addError(StateError('касса не ответила'));
        } else {
          controller.add(
            SetupState(
              configured: true,
              hasUsers: true,
              companyName: 'Магазин',
              cashBoxName: 'POS',
              countryCode: countryCode,
            ),
          );
        }
      },
      onCancel: () => cancelled++,
    );
    return controller.stream;
  }
}

void main() {
  late _FakeStartupState setup;

  Future<List<Decimal>> denominationsFor(
    int? country, {
    bool fail = false,
  }) async {
    if (!isLoggerReady) installLogger(Talker());
    setup = _FakeStartupState(country)..fail = fail;
    if (GetIt.I.isRegistered<StartupStateRepository>()) {
      GetIt.I.unregister<StartupStateRepository>();
    }
    GetIt.I.registerSingleton<StartupStateRepository>(setup);
    final container = ProviderContainer();
    addTearDown(() {
      container.dispose();
      if (GetIt.I.isRegistered<StartupStateRepository>()) {
        GetIt.I.unregister<StartupStateRepository>();
      }
    });
    return container.read(denominationsProvider.future);
  }

  group('раскладка номиналов — свойство кассы, а не экрана', () {
    test(
      'две страны дают разные раскладки — иначе проверки ниже пусты',
      () async {
        final kz = await denominationsFor(0);
        final ru = await denominationsFor(1);

        expect(
          kz,
          isNotEmpty,
          reason: 'пустая раскладка сделала бы любое сравнение ниже верным',
        );
        expect(
          kz,
          isNot(equals(ru)),
          reason:
              'Раскладки двух стран совпали. Значит либо страна не читается '
              'вовсе, либо таблица номиналов одна на всех — и тогда проверка '
              '«читаем страну» ничего не проверяет.',
        );
      },
    );

    test('номиналы берутся из ответа кассы, а не из умолчания', () async {
      // Индекс 3 выбран нарочно: его раскладка (1000…200000) не совпадает ни
      // с умолчанием, ни с соседями ни одним числом, поэтому «случайно
      // угадать» её нельзя.
      final uz = await denominationsFor(3);

      expect(
        uz.first,
        Decimal.fromInt(1000),
        reason: 'младший номинал страны 3 — 1000',
      );
      expect(
        uz.last,
        Decimal.fromInt(200000),
        reason: 'старший номинал страны 3 — 200000',
      );
      expect(
        setup.watched,
        1,
        reason:
            'провайдер обязан спросить кассу — ровно один раз за построение, '
            'а не на каждый кадр',
      );
    });

    test('подписка снимается: `watch().first`, а не вечный поток', () async {
      await denominationsFor(0);

      expect(
        setup.cancelled,
        1,
        reason:
            'Экран оплаты, оставивший подписку `setup.state` открытой, копит '
            'их по одной на каждый вход. Договор разрешает `watch().first` '
            'именно потому, что подписка при этом снимается.',
      );
    });

    test('касса не ответила — умолчание, а не пустой экран', () async {
      final onRefusal = await denominationsFor(1, fail: true);
      final byDefault = await denominationsFor(null);

      expect(
        onRefusal,
        isNotEmpty,
        reason:
            'Раскладка номиналов — удобство, и экран оплаты не имеет права '
            'не открыться из-за неё. Пустой список — это шесть пустых кнопок '
            'вместо подсказки.',
      );
      expect(
        onRefusal,
        equals(byDefault),
        reason:
            'Отказ обязан дать то же, что и «страна не задана», — а не '
            'раскладку страны 1, которую спрашивали и не получили.',
      );
    });

    test('неизвестный индекс страны не роняет экран', () async {
      // Мастер настройки пишет индекс `CountryCode`, а список стран растёт.
      // Касса на версию новее пришлёт индекс, которого этот экран не знает.
      final unknown = await denominationsFor(99);
      final byDefault = await denominationsFor(null);

      expect(unknown, equals(byDefault));
    });
  });
}
