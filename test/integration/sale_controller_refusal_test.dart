library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:telepos/domain/usecases/sale/sale_initiation_result.dart';
import 'package:telepos/domain/usecases/sale/sale_initiation_use_case.dart';
import 'package:drift/drift.dart' show Value;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

import 'test_utils.dart';

/// Круг правки 1 задачи 5.
///
/// Достижимость отказа `shift_not_open` доказана на уровне юзкейса, на
/// настоящей базе (`test/data/usecases/sale/shift_required_test.dart`). Но
/// путь «юзкейс → контроллер → состояние экрана → кассир» не был проверен
/// нигде: подделка в `test_utils.dart` всегда отвечала успехом, и ни один
/// тест не видел, что кассир получит названную причину, а не пустоту. Этот
/// файл переключает подделку на отказ и проверяет, что `SaleController`
/// кладёт в `state.error` названную причину, а не молчит.
///
/// **Задача 23 изменила форму причины, не её наличие.** До неё в состояние
/// уезжал `error.save_failed:<русский текст отказа>` — фраза, написанная
/// внутри кассы по-русски и пришитая к коду ошибки; кассир с казахским
/// интерфейсом читал именно её. Теперь уезжает ключ `error.shift_not_open`,
/// под которым лежит фраза во всех пяти локалях. Поэтому проверка спрашивает
/// ключ, а не подстроку русского текста: подстрока была симптомом дефекта,
/// а не требованием.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = createTestContainer();
  });

  tearDown(() {
    container.dispose();
    tearDownTestDependencies();
  });

  test(
    'отказ юзкейса кладёт в состояние экрана названную причину, не пустоту',
    () async {
      const refusal = WireRefusal(
        'shift_not_open',
        'смена не открыта — откройте её на кассе',
      );
      final mockInit =
          GetIt.I<SaleInitiationUseCase>() as MockSaleInitiationUseCase;
      when(
        () => mockInit.initiate(
          terminalId: any(named: 'terminalId'),
          isWholesale: any(named: 'isWholesale'),
        ),
      ).thenAnswer((_) async => const SaleInitiationResult.refused(refusal));

      final notifier = container.read(saleControllerProvider.notifier);
      await notifier.startNewSale();

      final state = container.read(saleControllerProvider);
      expect(
        state.error,
        equals('error.shift_not_open'),
        reason:
            'кассир обязан увидеть названную причину отказа '
            '(${refusal.code}), а не пустоту и не общее "что-то пошло не так"',
      );
      expect(
        state.error,
        isNot(contains(refusal.message)),
        reason:
            'русский текст отказа в состоянии экрана — это и есть дефект '
            'задачи 23: он не переводится и уезжает кассиру как есть',
      );
      expect(
        state.receiptNo,
        isNull,
        reason: 'отказ — не половинчатый успех, чек не должен считаться начатым',
      );
    },
  );

  test(
    'тот же отказ второй раз подряд — снова изменение состояния, а не тишина',
    () async {
      final notifier = container.read(saleControllerProvider.notifier);
      await notifier.startNewSale();
      // Чек начат, подписка на корзину отдала первый снимок — дальше
      // состояние меняют только вызовы ниже.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        container.read(saleControllerProvider).error,
        isNull,
        reason: 'предусловие: начатый чек не несёт отказа',
      );

      // Строки с таким идентификатором в чеке нет — корзина отвечает
      // `line_not_found` сколько угодно раз подряд. Кассир, дважды нажавший
      // «удалить» на строке, которой уже нет, — обычное дело.
      notifier.selectItem('нет-такой-строки');

      final seen = <String?>[];
      container.listen<String?>(
        saleControllerProvider.select((s) => s.error),
        (_, next) => seen.add(next),
      );

      await notifier.removeSelectedItem();
      expect(
        seen,
        equals(<String?>['error.line_not_found']),
        reason: 'первый отказ обязан доехать до состояния экрана',
      );

      seen.clear();
      await notifier.removeSelectedItem();

      // Экран показывает отказ по **изменению** `SaleState.error`
      // (`ref.listen` в `sale_screen.dart`), и одинаковое значение
      // изменением не считается. Без промежуточного ноля второй такой же
      // отказ не доехал бы вовсе: кассир нажал ту же кнопку и не получил
      // ответа. Ноль и значение пишутся одним синхронным шагом —
      // `SaleController._emitError`.
      expect(
        seen,
        equals(<String?>[null, 'error.line_not_found']),
        reason:
            'Тот же отказ второй раз подряд не стал изменением состояния — '
            'экран о нём не узнает. Механизм — `SaleController._emitError`.',
      );
    },
  );

  test(
    'снимок подписки на корзину не снимает отказ из состояния',
    () async {
      final notifier = container.read(saleControllerProvider.notifier);
      await notifier.startNewSale();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      notifier.selectItem('нет-такой-строки');
      await notifier.removeSelectedItem();
      expect(
        container.read(saleControllerProvider).error,
        'error.line_not_found',
        reason: 'предусловие: отказ лежит в состоянии',
      );

      // Чужая запись в `sales` — не команда кассира. Так пишут сервисный
      // сбор ресторана, вторая вкладка того же терминала и браузерный
      // терминал (докстринг `SaleController._listenToCart` перечисляет всех
      // троих). Подписка отдаёт снимок, экран его применяет.
      final db = cartDb;
      await (db.update(db.sales)
            ..where((t) => t.receiptNo.equals(1)))
          .write(const SalesCompanion(storeId: Value(77)));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        container.read(saleControllerProvider).error,
        'error.line_not_found',
        reason:
            'Отказ снят из состояния без единой команды кассира — одной '
            'чужой записью в базу. Снимать отказ имеет право удавшаяся '
            'команда (`_applyView`), но не снимок подписки: подписка не '
            'спрашивала кассу ни о чём.',
      );
    },
  );

  test(
    'удавшаяся команда отказ снимает — вторая половина того же механизма',
    () async {
      // Круг правки 3: сторож на `keepError` был односторонним. Проба выше
      // ловит «подписка не имеет права гасить причину», но `keepError = true`
      // **по умолчанию** — то есть удавшаяся команда тоже перестаёт гасить —
      // оставляла зелёными и 230 проб, и 228 сквозных. Механизм двусторонний,
      // и сторожить его надо с обеих сторон.
      final notifier = container.read(saleControllerProvider.notifier);
      await notifier.startNewSale();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      notifier.selectItem('нет-такой-строки');
      await notifier.removeSelectedItem();
      expect(
        container.read(saleControllerProvider).error,
        'error.line_not_found',
        reason: 'предусловие: отказ лежит в состоянии',
      );

      // Команда, которая проходит **и не гасит ошибку сама**. `clearSale`
      // для этого не годится: она первым делом пишет `clearError: true`
      // своей рукой, и проба на ней зеленела бы и с обратной диверсией —
      // измерено кругом правки 3. `toggleMode` идёт голым `_command`, и
      // единственный, кто может снять причину, — `_applyView`.
      //
      // С 2026-09-19 `toggleMode` проходит только на кассе с включённой
      // правкой цены: опт закрыт этой настройкой на обоих входах. Без
      // строки ниже команда перестаёт быть удавшейся, и проба про механизм
      // гашения краснела бы по чужой причине — отказом настройки.
      await cartDb
          .update(cartDb.thisPosEntries)
          .write(const ThisPosEntriesCompanion(editPrice: Value(true)));

      await notifier.toggleMode();

      expect(
        container.read(saleControllerProvider).error,
        isNull,
        reason:
            'Удавшаяся команда оставила на экране причину отказа предыдущей. '
            'Кассир видит «строки нет» над чеком, который только что успешно '
            'очистился, и не понимает, к чему это относится.',
      );
    },
  );
}
