import 'package:meta/meta.dart';

/// Кассир, каким его видит экран входа.
///
/// # Чего здесь нет и почему
///
/// Здесь **нет хэша пароля**, и это главное свойство типа, а не упущение. До
/// 2026-08-20 экран входа тянул `passwordEnc` каждого кассира в своё состояние
/// (`login_controller.dart:192`) и перебирал PIN у себя. Пока проверка жила на
/// той же машине, что и база, это было расточительно; на проводе это стало бы
/// рассылкой хэшей всех кассиров в браузер.
///
/// [hasPin] — единственное, что экрану нужно знать о пароле: показывать ли
/// клавиатуру вообще.
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.role,
    required this.hasPin,
  });

  final int id;

  final String name;

  /// Имя роли для показа, а не индекс: индекс — дело кассы.
  final String role;

  /// Заведён ли PIN. Кассир без PIN входит без клавиатуры.
  final bool hasPin;

  @override
  String toString() => 'AuthUser(id: $id, name: $name, role: $role, hasPin: $hasPin)';
}
