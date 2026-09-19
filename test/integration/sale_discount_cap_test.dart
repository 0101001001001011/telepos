library;

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_refusal_keys.dart';

import 'test_utils.dart';

/// Задачи 18 и 44: откуда экран берёт предел скидки.
///
/// Проба нужна отдельно от экранных: те подменяют сам `SaleNotifier`
/// (`MockSaleNotifier`), то есть проверяют, что экран **показывает** то, что
/// ему дали, — и не касаются того, что даёт настоящий контроллер.
///
/// **Вторая проба до задачи 44 утверждала обратное.** Она требовала, чтобы
/// контроллер без `DiscountPolicy` в контейнере отвечал «сто процентов,
/// предел не прочитан» — правдоподобным телом для браузера, где читателя
/// предела не было, а кнопку прятали. Теперь условия читает касса
/// (`SaleEditTermsReader`, по проводу — `sale.editTerms`), и нечитаемые
/// условия — это отказ словами, а не выдуманный предел.
class _RecordingReader implements SaleEditTermsReader {
  _RecordingReader(this._answer);

  final Future<SaleEditTerms> Function() _answer;
  DiscountAuthority? askedBy;

  @override
  Future<SaleEditTerms> read({required DiscountAuthority by}) {
    askedBy = by;
    return _answer();
  }
}

void main() {
  late ProviderContainer container;

  void bind(SaleEditTermsReader reader) {
    if (GetIt.I.isRegistered<SaleEditTermsReader>()) {
      GetIt.I.unregister<SaleEditTermsReader>();
    }
    GetIt.I.registerSingleton<SaleEditTermsReader>(reader);
  }

  setUp(() {
    container = createTestContainer();
  });

  tearDown(() {
    container.dispose();
    tearDownTestDependencies();
  });

  test(
    'условия спрашиваются с полномочиями вошедшего и доезжают без правки',
    () async {
      final reader = _RecordingReader(
        () async => SaleEditTerms(
          policy: const SalePolicy(editPrice: false, sellInDiscount: true),
          cap: DiscountCap(
            maxPercent: Decimal.fromInt(15),
            approvalAbove: Decimal.fromInt(10),
            source: 'предел роли «Кассир»',
          ),
          currencySymbol: 'сом',
        ),
      );
      bind(reader);

      final notifier = container.read(saleControllerProvider.notifier);
      final terms = await notifier.editTerms();

      expect(
        reader.askedBy?.roleIndex,
        0,
        reason:
            'роль вошедшего — из AppState (_TestAppStateNotifier: владелец), '
            'а не выдуманная экраном',
      );
      expect(terms, isNotNull);
      expect(terms!.cap.maxPercent, Decimal.fromInt(15));
      expect(terms.cap.approvalAbove, Decimal.fromInt(10));
      expect(
        terms.cap.source,
        'предел роли «Кассир»',
        reason:
            'слова про то, чей это предел, доезжают до кассира без правки: '
            'отказ, не назвавший, кто запретил, отправляет его искать наугад',
      );
      expect(terms.policy.editPrice, isFalse);
      expect(terms.policy.sellInDiscount, isTrue);
      expect(terms.currencySymbol, 'сом');
    },
  );

  test(
    'условия не прочитаны — null и причина словами, а не «сто процентов»',
    () async {
      const refusal = WireRefusal(
        'no_sale_module',
        'эта касса не умеет вести продажу',
      );
      bind(_RecordingReader(() async => throw refusal));

      final notifier = container.read(saleControllerProvider.notifier);
      final terms = await notifier.editTerms();

      expect(
        terms,
        isNull,
        reason:
            'диалог без условий не открывается: предел, которого касса не '
            'давала, хуже закрытого диалога',
      );
      expect(
        container.read(saleControllerProvider).error,
        saleRefusalErrorKeyOf(refusal),
        reason: 'причина обязана лечь в состояние экрана названной (И144)',
      );
    },
  );
}
