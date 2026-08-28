class EsutdDefaults {
  EsutdDefaults._();

  static const String apiUrl = 'https://esutd.gov.kz/api';

  static const int defaultTokenTtlSeconds = 86400;
}

class EsutdSettings {
  const EsutdSettings({
    this.email,
    this.password,
    this.apiUrl,
    this.enabled = false,
    this.rememberMe = false,
    this.authCookies,
    this.authObtainedAtMs,
    this.tokenTtl = const Duration(
      seconds: EsutdDefaults.defaultTokenTtlSeconds,
    ),
  });

  final String? email;

  final String? password;

  final String? apiUrl;

  final bool enabled;

  final bool rememberMe;

  final String? authCookies;

  final int? authObtainedAtMs;

  final Duration tokenTtl;

  bool get isActive =>
      enabled &&
      (email != null && email!.isNotEmpty) &&
      (password != null && password!.isNotEmpty);

  String get resolvedApiUrl =>
      (apiUrl != null && apiUrl!.isNotEmpty) ? apiUrl! : EsutdDefaults.apiUrl;

  bool get hasValidSession {
    if (authCookies == null || authCookies!.isEmpty) return false;
    if (authObtainedAtMs == null) return true;
    final age = DateTime.now().millisecondsSinceEpoch - authObtainedAtMs!;
    return age < tokenTtl.inMilliseconds;
  }

  EsutdSettings copyWith({
    String? email,
    String? password,
    String? apiUrl,
    bool? enabled,
    bool? rememberMe,
    String? authCookies,
    int? authObtainedAtMs,
    Duration? tokenTtl,
  }) {
    return EsutdSettings(
      email: email ?? this.email,
      password: password ?? this.password,
      apiUrl: apiUrl ?? this.apiUrl,
      enabled: enabled ?? this.enabled,
      rememberMe: rememberMe ?? this.rememberMe,
      authCookies: authCookies ?? this.authCookies,
      authObtainedAtMs: authObtainedAtMs ?? this.authObtainedAtMs,
      tokenTtl: tokenTtl ?? this.tokenTtl,
    );
  }

  EsutdSettings withoutSession() => EsutdSettings(
    email: email,
    password: password,
    apiUrl: apiUrl,
    enabled: enabled,
    rememberMe: rememberMe,
    tokenTtl: tokenTtl,
  );

  Map<String, dynamic> toJson() => {
    if (email != null) 'email': email,
    if (password != null) 'password': password,
    if (apiUrl != null) 'apiUrl': apiUrl,
    'enabled': enabled,
    'rememberMe': rememberMe,
    if (authCookies != null) 'authCookies': authCookies,
    if (authObtainedAtMs != null) 'authObtainedAtMs': authObtainedAtMs,
    'tokenTtlSeconds': tokenTtl.inSeconds,
  };

  factory EsutdSettings.fromJson(Map<String, dynamic> json) => EsutdSettings(
    email: json['email'] as String?,
    password: json['password'] as String?,
    apiUrl: json['apiUrl'] as String?,
    enabled: json['enabled'] as bool? ?? false,
    rememberMe: json['rememberMe'] as bool? ?? false,
    authCookies: json['authCookies'] as String?,
    authObtainedAtMs: json['authObtainedAtMs'] as int?,
    tokenTtl: json['tokenTtlSeconds'] != null
        ? Duration(seconds: json['tokenTtlSeconds'] as int)
        : const Duration(seconds: EsutdDefaults.defaultTokenTtlSeconds),
  );

  factory EsutdSettings.disabled() => const EsutdSettings();
}
