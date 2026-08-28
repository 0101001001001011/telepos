/// Подделка входа для тестов, которым нужен обязательный `auth`
/// у `TillOperations`/`ApiServer`, но не его поведение.
///
/// До этой правки один и тот же класс был скопирован **четырежды**:
/// `api_server_root_ca_test.dart`, `api_server_tls_test.dart` и
/// `till_operations_test.dart` — побайтово одинаково (в последнем даже без
/// подчёркивания перед именем, то есть им и собирались делиться), и
/// `api_server_listen_scope_test.dart` — с тем же смыслом на других потоках
/// (`Stream.empty()` вместо никогда не завершающегося `async*`).
///
/// Поведение логики входа этот класс не проверяет ни в одном из четырёх мест
/// — см. `till_operations_auth_test.dart`, где логику входа зовёт настоящий
/// `LocalAuthRepository` поверх базы в памяти.
library;

import 'dart:async';

import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/auth_user.dart';

class NoopAuth implements AuthRepository {
  @override
  Stream<List<AuthUser>> watchUsers() async* {
    yield const [];
    await Completer<void>().future;
  }

  @override
  Future<AuthOutcome> login(AuthAttempt attempt) async =>
      const AuthRejection(AuthRejectionReason.wrongPin);

  @override
  Future<void> logout(String token) async {}

  @override
  Stream<AuthSession?> watchSession(String token) async* {
    yield null;
    await Completer<void>().future;
  }
}
