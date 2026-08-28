/// Кадры провода между кассой и терминалом.
///
/// # Разбор не бросает никогда
///
/// Это главное свойство файла, и оно взято из измерения. 2026-08-04 на HTTP
/// `jsonDecode` бросил `FormatException` над страницей 404, и она прошла мимо
/// всех `catch (ApiException)` в вызывающем коде: кассир увидел белый экран без
/// единого слова — ни причины, ни адреса, ни кода ответа. В тот день это
/// нашлось трижды подряд, потому что чинилось по одному звену, а звеньев было
/// три.
///
/// Здесь класс отказа закрыт **в самом разборе**, один раз, а не в каждом из
/// десяти мест, которые его зовут. Всё, что не разобралось, становится
/// [ErrorFrame] с названной причиной.
///
/// # Идентификаторов в кадре нет
///
/// Соответствие ответа запросу даёт сам двунаправленный поток: отвечать некуда,
/// кроме как в него. Поэтому книги учёта идентификаторов не заводится — её
/// нечем было бы проверить, и она была бы ещё одним местом, где два конца
/// расходятся молча.
library;

import 'dart:convert';

sealed class WireFrame {
  const WireFrame();

  /// Разбирает кадр. **Никогда не бросает.**
  ///
  /// На всё, что не является узнаваемым кадром, отвечает [ErrorFrame] с кодом
  /// `not_a_frame` и причиной внутри.
  static WireFrame decode(String utf8Text) {
    if (utf8Text.isEmpty) {
      return const ErrorFrame('not_a_frame', 'пустой кадр');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8Text);
    } on FormatException catch (e) {
      return ErrorFrame('not_a_frame', e.message);
    }

    if (decoded is! Map<String, Object?>) {
      // Массив или число на месте кадра означают, что отвечает не тот, кого
      // спрашивали: прокси, портал гостевого Wi-Fi, чужой сервис на порту.
      return ErrorFrame(
        'not_a_frame',
        'ожидался объект, пришло ${decoded.runtimeType}',
      );
    }

    if (decoded.containsKey('op')) {
      final op = decoded['op'];
      if (op is! String) {
        return const ErrorFrame('not_a_frame', 'имя операции не строка');
      }
      final token = decoded['token'];
      return RequestFrame(
        op,
        _bodyOf(decoded),
        // Не строка — значит не наш токен; молча проигнорировать безопаснее,
        // чем принять: проверка всё равно откажет по отсутствию сеанса.
        token: token is String ? token : null,
      );
    }

    if (decoded.containsKey('ok')) {
      if (decoded['ok'] == true) return OkFrame(_bodyOf(decoded));
      return ErrorFrame(
        decoded['code']?.toString() ?? 'failed',
        decoded['detail']?.toString() ?? '',
      );
    }

    switch (decoded['kind']) {
      case 'update':
        return UpdateFrame(_bodyOf(decoded));
      case 'progress':
        final raw = decoded['value'];
        if (raw is! num) {
          return const ErrorFrame('not_a_frame', 'ход выполнения не число');
        }
        final value = raw.toDouble();
        if (value < 0 || value > 1) {
          // Полоса, ушедшая за край, — признак того, что число придумали.
          // Лучше показать отказ, чем нарисовать девятьсот процентов.
          return ErrorFrame('not_a_frame', 'ход выполнения вне 0..1: $value');
        }
        return ProgressFrame(value, decoded['text']?.toString() ?? '');
      case 'done':
        return DoneFrame(_bodyOf(decoded));
    }

    // Касса новее терминала — обычное состояние при обновлении по одной
    // машине. Неизвестный кадр обязан быть виден: молчаливый пропуск оставил
    // бы обмен висеть в ожидании ответа, которого уже не будет.
    return const ErrorFrame('not_a_frame', 'род кадра не распознан');
  }

  static Map<String, Object?> _bodyOf(Map<String, Object?> frame) {
    final body = frame['body'];
    return body is Map<String, Object?> ? body : const {};
  }

  String encode();
}

/// Вопрос терминала: имя операции и её тело.
final class RequestFrame extends WireFrame {
  const RequestFrame(this.op, this.body, {this.token});

  final String op;
  final Map<String, Object?> body;

  /// Токен сеанса, если он у терминала есть.
  ///
  /// Конвертом, а не ключом в теле: тело принадлежит операции, и её кодировщик
  /// однажды положит туда ключ с тем же именем — молча. Конверт виден разбору
  /// и с доводами не смешивается.
  final String? token;

  @override
  String encode() =>
      jsonEncode({'op': op, 'body': body, if (token != null) 'token': token});
}

/// Ответ кассы на [RequestFrame].
final class OkFrame extends WireFrame {
  const OkFrame(this.body);

  final Map<String, Object?> body;

  @override
  String encode() => jsonEncode({'ok': true, 'body': body});
}

/// Отказ с названной причиной.
///
/// Код отделён от подробности намеренно: по коду отличают «нет такой операции»
/// от «обработчик упал», и это разные действия оператора.
final class ErrorFrame extends WireFrame {
  const ErrorFrame(this.code, this.detail);

  final String code;
  final String detail;

  @override
  String encode() => jsonEncode({'ok': false, 'code': code, 'detail': detail});

  @override
  String toString() => 'ErrorFrame($code: $detail)';
}

/// Изменение по подписке.
final class UpdateFrame extends WireFrame {
  const UpdateFrame(this.body);

  final Map<String, Object?> body;

  @override
  String encode() => jsonEncode({'kind': 'update', 'body': body});
}

/// Ход длинной работы. [value] — доля от нуля до единицы включительно.
final class ProgressFrame extends WireFrame {
  const ProgressFrame(this.value, this.text);

  final double value;
  final String text;

  @override
  String encode() =>
      jsonEncode({'kind': 'progress', 'value': value, 'text': text});
}

/// Завершение длинной работы.
///
/// Приходит **только** при успешном конце. Оборванная работа заканчивается
/// [ErrorFrame] без [DoneFrame]: «готово» здесь означает целый магазин, и
/// выдать незавершённое за завершённое дороже, чем показать отказ.
final class DoneFrame extends WireFrame {
  const DoneFrame(this.body);

  final Map<String, Object?> body;

  @override
  String encode() => jsonEncode({'kind': 'done', 'body': body});
}
