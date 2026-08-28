class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException($code): $message';
}

class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code = 'DATABASE_ERROR',
    super.cause,
    super.stackTrace,
  });
}

class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.cause,
    super.stackTrace,
  });
}

class HardwareException extends AppException {
  const HardwareException({
    required super.message,
    super.code = 'HARDWARE_ERROR',
    super.cause,
    super.stackTrace,
  });
}

class ConfigException extends AppException {
  const ConfigException({
    required super.message,
    super.code = 'CONFIG_ERROR',
    super.cause,
    super.stackTrace,
  });
}
