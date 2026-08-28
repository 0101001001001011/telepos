import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Символы удалённой подсистемы Go-бэкенда.
///
/// Проверка идёт по исходникам, а не через `GetIt`: как только тип удалён, на
/// него нельзя сослаться из теста, и `expect(() => getIt<T>(), throwsA(...))`
/// перестаёт компилироваться. Сторож на исходный код переживает удаление
/// самого типа — а именно это и надо удержать.
const _forbidden = [
  'BackendAuthRepository',
  'BackendOrganizationRepository',
  'BackendAuthResult',
  'BackendUser',
  'BackendOrganization',
  'BackendEmployee',
  'GoBackendConfig',
];

void main() {
  test('подсистемы Go-бэкенда в приложении не осталось', () {
    final offenders = <String>[];

    for (final root in ['lib', 'test']) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // Этот файл перечисляет запрещённые имена по долгу службы.
        if (entity.path.endsWith('no_go_backend_test.dart')) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final symbol in _forbidden) {
            if (lines[i].contains(symbol)) {
              offenders.add('${entity.path}:${i + 1} — $symbol');
            }
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Go-бэкенд удалён вместе с серверами, к которым ходил. '
          'Осталось:\n${offenders.join('\n')}',
    );
  });

  test('файлов подсистемы не существует', () {
    const removed = [
      'lib/data/datasources/remote/go_backend_config.dart',
      'lib/data/repositories/backend_auth_repository_impl.dart',
      'lib/data/repositories/backend_organization_repository_impl.dart',
      'lib/domain/repositories/backend_auth_repository.dart',
      'lib/domain/repositories/backend_organization_repository.dart',
    ];

    for (final path in removed) {
      expect(
        File(path).existsSync(),
        isFalse,
        reason: '$path должен был быть удалён вместе с подсистемой',
      );
    }
  });
}
