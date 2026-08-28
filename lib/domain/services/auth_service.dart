abstract class AuthService {
  Future<bool> authenticate(String key);

  Future<bool> hasKey();

  Future<bool> hasToken();

  Future<String?> getToken();

  Future<String?> getKey();

  /// Whether [pin] proves the caller is user [userId].
  ///
  /// `false` for a user who has no PIN stored: there is nothing to prove
  /// anything against, and answering `true` there is exactly the hole this
  /// contract used to have. A caller that wants to allow a PIN-less user in
  /// has to say so itself, in its own code, where the reader can see it.
  ///
  /// A correct PIN checked against a record written before the PBKDF2 scheme
  /// also rewrites that record in the current scheme, so each user upgrades
  /// once, silently, on a successful check.
  Future<bool> verifyUserPin(String pin, int userId);
}

class AuthorizationFailed implements Exception {
  const AuthorizationFailed([this.message]);

  final String? message;

  @override
  String toString() =>
      'AuthorizationFailed${message != null ? ': $message' : ''}';
}
