library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';

void main() {
  testWidgets('previously-unmapped error keys now localize (ru)', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    String loc(String k) => ErrorLocalizer.localize(ctx, k);

    final stock = loc('error.insufficient_stock:Молоко');
    expect(stock, contains('Молоко'));
    expect(stock, isNot(contains('error.insufficient_stock')));

    final mark = loc('error.mark_required:Сигареты');
    expect(mark, contains('Сигареты'));
    expect(mark, isNot(contains('error.mark_required')));

    for (final k in const [
      'error.order_not_found',
      'error.serial_not_found',
      'error.receipt_failed',
      'error.delete_failed',
      'error.cancel_failed',
      'error.shift_zreport_failed',
      'error.transition_failed',
    ]) {
      final r = loc(k);
      expect(r.isNotEmpty, isTrue, reason: '$k empty');
      expect(
        r,
        isNot(startsWith('error.')),
        reason: '$k did not localize, got "$r"',
      );
    }

    final incomplete = loc('error.setup_incomplete:организация, касса');
    expect(incomplete, contains('организация'));
    expect(incomplete, isNot(startsWith('error.')));

    // `error.too_many_attempts` — покрывавший его блок — удалён во втором
    // круге задачи 7 (2026-08-21): ключ разбирал `AuthRejectionReason
    // .tooManyAttempts`, а та причина отказа ушла вместе с пределом
    // одновременных ожиданий, который её единственный порождал
    // (`login_throttle.dart`).
  });
}
