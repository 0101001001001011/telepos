import 'dart:io' show HttpHeaders;

import 'package:shelf/shelf.dart';

/// Как браузер обязан обходиться с файлами бандла — задача 42.
///
/// # Почему `no-cache`, а не длинный кэш с хэшем в имени
///
/// Ни один файл сборки `flutter build web` не несёт хэша содержимого в имени:
/// `main.dart.js`, `flutter_bootstrap.js`, `assets/…`, `canvaskit/…` —
/// одинаковые адреса от сборки к сборке. Длинный кэш на них — это ровно
/// дефект, измеренный живой приёмкой 2026-09-07: пересобранный бандл
/// открытой вкладке не виден. А без `Cache-Control` вовсе браузер кэширует по
/// эвристике (доля возраста от `Last-Modified`) и **не спрашивает** кассу.
///
/// `no-cache` значит «храни, но перед использованием спроси»: вопрос стоит
/// одного `304` без тела, а после обновления кассы ответ — новый файл.
const kBundleCacheControl = 'no-cache';

/// Документ не хранится вовсе: он собирается на лету — в него впрыснуты
/// токен и отпечаток листа QUIC, — и проверять его нечем.
const kDocumentCacheControl = 'no-store';

/// Оборачивает статический раздатчик бандла: `no-cache` на каждый ответ и
/// своё сравнение `If-Modified-Since`.
///
/// # Почему сравнение своё — измерено
///
/// `shelf_static` 1.1.3 отвечает `304` сам, но его `toSecondResolution`
/// срезает миллисекунды и **оставляет микросекунды**. NTFS хранит время
/// файла с шагом 100 нс, поэтому на Windows — то есть на каждой кассе —
/// время файла всегда «позже» валидатора, и проверка никогда не отвечала
/// `304`: каждое открытие страницы под `no-cache` качало бы бандл целиком.
/// Поймано пробой `api_server_bundle_cache_test.dart` (200 вместо 304).
///
/// Здесь сравниваются два заголовка, оба с точностью до секунды:
/// `Last-Modified`, который раздатчик уже написал, и `If-Modified-Since`
/// запроса.
Handler cachingBundle(Handler files) => (Request request) async {
  final response = await files(request);
  final since = request.ifModifiedSince;
  final modified = response.lastModified;
  if (response.statusCode == 200 &&
      since != null &&
      modified != null &&
      !modified.isAfter(since)) {
    return Response.notModified(
      headers: {
        HttpHeaders.cacheControlHeader: kBundleCacheControl,
        HttpHeaders.lastModifiedHeader:
            response.headers[HttpHeaders.lastModifiedHeader]!,
      },
    );
  }
  return response.change(
    headers: {HttpHeaders.cacheControlHeader: kBundleCacheControl},
  );
};
