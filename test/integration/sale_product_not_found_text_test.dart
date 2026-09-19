/// Ненайденный товар кассир читает одним предложением — приёмка 2026-09-17.
///
/// # Что видел кассир
///
/// «**Товар не найден**: товар со штрихкодом 4870000000103 **не найден**».
/// Фраза словаря (`errorProductNotFound` → «Товар не найден: {details}») и
/// текст кассы («товар со штрихкодом … не найден») говорили одно и то же
/// дважды; в казахском интерфейсе вторая половина к тому же оставалась
/// русской.
///
/// # Где была причина
///
/// Уговор карты отказов (`sale_refusal_keys.dart`, `withMessage: true`):
/// текст отказа — **довод словарной фразы**, а не готовое предложение. Так
/// сделаны соседи: `mark_required` и `insufficient_stock` шлют **имя
/// товара** (`local_sale_checkout_service.dart`). `product_not_found` из
/// корзины был единственным, кто слал целое предложение
/// (`local_cart_service.dart`).
///
/// # Почему проба идёт через настоящую кассу
///
/// Потому что дефект — в тексте, который пишет касса, а не в карте и не в
/// словаре. Проба, собравшая `WireRefusal` руками, доказывала бы своё
/// собственное представление о том, что касса шлёт, — а именно оно и было
/// неверным.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

import 'test_utils.dart';

/// Штрихкода нет ни у одного товара базы корзины (`testDomainProducts` —
/// 4607001234567…9).
const _unknown = '4870000000103';

void main() {
  testWidgets('ненайденный штрихкод доезжает до кассира одним предложением', (
    tester,
  ) async {
    final container = createTestContainer();
    addTearDown(container.dispose);
    addTearDown(tearDownTestDependencies);

    final notifier = container.read(saleControllerProvider.notifier);
    await notifier.startNewSale();

    final added = await notifier.addByBarcode(_unknown);
    expect(
      added,
      isFalse,
      reason: 'контрольный случай: касса действительно отказала',
    );

    final key = container.read(saleControllerProvider).error;
    expect(
      key,
      equals('error.product_not_found:$_unknown'),
      reason:
          'ДОВОДОМ СЛОВАРНОЙ ФРАЗЫ ЕДЕТ НЕ ШТРИХКОД, А ЦЕЛОЕ ПРЕДЛОЖЕНИЕ '
          'КАССЫ. Фраза «Товар не найден: {details}» подставит его внутрь '
          'себя и повторится. Текст отказа — `local_cart_service.dart`, '
          '`addByBarcode`.',
    );

    late BuildContext ctx;
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (c) {
            ctx = c;
            l10n = AppLocalizations.of(c)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shown = ErrorLocalizer.localize(ctx, key!);

    // Ожидаемое берётся у словаря, а не вписано сюда: проба утверждает, что
    // доводом фразы стал **штрихкод**, а не то, как именно звучит фраза.
    // Поправят формулировку — проба останется верной.
    expect(
      shown,
      equals(l10n.errorProductNotFound(_unknown)),
      reason: 'кассир читает не «Товар не найден: <штрихкод>», а что-то ещё',
    );
    expect(
      RegExp('не найден').allMatches(shown).length,
      equals(1),
      reason:
          'ФРАЗА ПОВТОРЯЕТ САМУ СЕБЯ: «$shown». Кассир читает «не найден» '
          'дважды в одном предложении.',
    );
  });
}
