/// Экран входа сообщает кассе, кто вошёл, — решение заказчика 2026-09-15.
///
/// Замок перебора сертификатов на кассе считает по кассиру
/// (`ThrottledPaymentService`), а кассира берёт у `CashierOnDuty`. Пишет его
/// только экран входа: сеанс живёт в его памяти и контейнеру не виден. Не
/// впиши экран кассира — замок отказывает `unauthorized` каждому; не сотри
/// на выходе — следующий кассир упирался бы в счёт предыдущего.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/cashier_on_duty.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';

import 'support/fakes.dart';
import 'package:telepos/domain/shift/shift_status.dart';

AuthSession _session(int userId) => AuthSession(
  token: 't-$userId',
  userId: userId,
  name: 'Кассир $userId',
  role: 'cashier',
  permissions: const {'nav.sale'},
  operatingMode: 0,
  pointMode: 'cashier',
  shift: ShiftStatus.open,
  issuedAt: DateTime(2026, 9, 15),
  expiresAt: DateTime(2026, 9, 16),
  terminalId: 1,
);

void main() {
  late CashierOnDutyHolder cashier;

  setUp(() {
    final getIt = GetIt.instance;
    getIt.registerSingleton<TerminalIdentity>(FakeTerminalIdentity());
    getIt.registerSingleton<HostCapabilities>(HostCapabilities.desktop);
    cashier = CashierOnDutyHolder();
    getIt.registerSingleton<CashierOnDutyHolder>(cashier);
  });

  tearDown(() => GetIt.instance.reset());

  Future<LoginNotifier> signIn(ProviderContainer container) async {
    final notifier = container.read(loginControllerProvider.notifier);
    notifier.initialize();
    await Future<void>.delayed(Duration.zero);
    for (final digit in ['1', '2', '3', '4']) {
      notifier.addDigit(digit);
    }
    await notifier.pendingVerification;
    expect(
      container.read(loginControllerProvider).isAuthenticated,
      isTrue,
      reason: 'подготовка: сеанс принят',
    );
    return notifier;
  }

  test('вход вписывает кассира, выход стирает', () async {
    GetIt.instance.registerSingleton<AuthRepository>(
      FakeAuthRepository(_session(7)),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(cashier.userId, isNull, reason: 'до входа кассира нет');
    final notifier = await signIn(container);
    expect(cashier.userId, 7);

    await notifier.logout();
    expect(
      cashier.userId,
      isNull,
      reason: 'следующий кассир не имеет права упираться в чужой счёт',
    );
  });
}
