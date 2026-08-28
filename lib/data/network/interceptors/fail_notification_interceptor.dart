import 'request_interceptor.dart';

class FailNotificationInterceptor extends RequestInterceptor {
  FailNotificationInterceptor({
    this.showNotification,
    this.shouldNotify = _defaultShouldNotify,
    this.getErrorMessage = _defaultErrorMessage,
  });

  final void Function(String message, NotificationSeverity severity)?
  showNotification;

  final bool Function(NetworkError error) shouldNotify;

  final String Function(NetworkError error) getErrorMessage;

  @override
  String get name => 'FailNotificationInterceptor';

  @override
  int get priority => 200;

  @override
  Future<NetworkError> onError(NetworkError error) async {
    if (shouldNotify(error)) {
      final message = getErrorMessage(error);
      final severity = _getSeverity(error);

      showNotification?.call(message, severity);
    }

    return error;
  }

  NotificationSeverity _getSeverity(NetworkError error) {
    switch (error.type) {
      case NetworkErrorType.timeout:
        return NotificationSeverity.warning;
      case NetworkErrorType.connection:
        return NotificationSeverity.info;
      case NetworkErrorType.server:
        return NotificationSeverity.error;
      case NetworkErrorType.client:
        if (error.statusCode == 401 || error.statusCode == 403) {
          return NotificationSeverity.warning;
        }
        return NotificationSeverity.error;
      case NetworkErrorType.cancelled:
        return NotificationSeverity.info;
      case NetworkErrorType.parsing:
        return NotificationSeverity.error;
      case NetworkErrorType.unknown:
        return NotificationSeverity.error;
    }
  }

  static bool _defaultShouldNotify(NetworkError error) {
    if (error.type == NetworkErrorType.cancelled) {
      return false;
    }
    return true;
  }

  static String _defaultErrorMessage(NetworkError error) {
    switch (error.type) {
      case NetworkErrorType.timeout:
        return 'Превышено время ожидания. Проверьте соединение.';
      case NetworkErrorType.connection:
        return 'Нет соединения с сервером';
      case NetworkErrorType.server:
        return 'Ошибка сервера. Попробуйте позже.';
      case NetworkErrorType.client:
        if (error.statusCode == 401) {
          return 'Требуется авторизация';
        }
        if (error.statusCode == 403) {
          return 'Доступ запрещён';
        }
        if (error.statusCode == 404) {
          return 'Данные не найдены';
        }
        return 'Ошибка запроса';
      case NetworkErrorType.cancelled:
        return 'Запрос отменён';
      case NetworkErrorType.parsing:
        return 'Ошибка обработки данных';
      case NetworkErrorType.unknown:
        return 'Неизвестная ошибка';
    }
  }
}

enum NotificationSeverity { info, warning, error }

class FailNotificationConfig {
  const FailNotificationConfig({
    this.showOnTimeout = true,
    this.showOnConnection = true,
    this.showOnServer = true,
    this.showOnAuth = true,
    this.showOnClient = false,
    this.showOnUnknown = true,
    this.notificationDuration = const Duration(seconds: 3),
  });

  final bool showOnTimeout;
  final bool showOnConnection;
  final bool showOnServer;
  final bool showOnAuth;
  final bool showOnClient;
  final bool showOnUnknown;
  final Duration notificationDuration;

  bool Function(NetworkError) toShouldNotify() {
    return (error) {
      switch (error.type) {
        case NetworkErrorType.timeout:
          return showOnTimeout;
        case NetworkErrorType.connection:
          return showOnConnection;
        case NetworkErrorType.server:
          return showOnServer;
        case NetworkErrorType.client:
          if (error.statusCode == 401 || error.statusCode == 403) {
            return showOnAuth;
          }
          return showOnClient;
        case NetworkErrorType.cancelled:
          return false;
        case NetworkErrorType.parsing:
          return showOnUnknown;
        case NetworkErrorType.unknown:
          return showOnUnknown;
      }
    };
  }
}
