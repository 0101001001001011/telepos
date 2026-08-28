/// PBKDF2-строка вида, которую `PinCredential` кладёт в
/// `Users.password_enc` (`pbkdf2$sha256$<iterations>$<salt>$<key>`,
/// `lib/core/security/pin_credential.dart`).
///
/// Три теста доказывают, что настоящий `SqliteException` с этой строкой в
/// параметрах не долетает наружу текстом, и до правки задачи 9 (волна
/// правок фазы 1) каждый заводил её заново дословно:
/// `test/core/errors/safe_error_text_test.dart` (сама функция),
/// `test/data/transport/till_wire_safe_error_test.dart` (провод),
/// `test/presentation/setup/initial_setup_no_secret_test.dart` (мастер
/// настройки). Один литерал — здесь.
library;

const testPbkdf2PinHash =
    r'pbkdf2$sha256$10000$c2FsdHNhbHRzYWx0c2FsdA==$'
    r'ZGVyaXZlZGRlcml2ZWRkZXJpdmVkZGVyaXZlZA==';
