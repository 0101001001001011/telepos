/// Каждая модель устройства и каждый её параметр называются по-английски,
/// когда интерфейс английский.
///
/// # Зачем отдельный сторож
///
/// `deviceProfileTitle` на неизвестный идентификатор возвращает то, что
/// несёт сам профиль, — и это правильно: профиль, появившийся раньше своего
/// ключа, обязан показаться хоть как-то, а не пустой строкой. Но у запасного
/// пути есть цена: **добавит кто-нибудь модель с русским названием — и она
/// молча просочится на английский экран**, потому что ничего не сломается.
///
/// Здесь запасной путь и ловится. Сторож идёт по НАСТОЯЩЕМУ каталогу, а не
/// по списку, переписанному рядом: список рядом разошёлся бы с каталогом в
/// первый же день и перестал бы что-либо доказывать.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/device_profile_label.dart';

final _cyrillic = RegExp('[Ѐ-ӿ]');

void main() {
  test('английские подписи моделей и параметров не содержат кириллицы', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    // Каталог отдаёт профили по классам — обходим все классы, чтобы не
    // держать рядом второй список, который разойдётся с настоящим.
    final catalog = BuiltinDeviceProfileCatalog();
    final profiles = <DeviceProfile>[
      for (final deviceClass in DeviceClass.values)
        ...catalog.forClass(deviceClass),
    ];

    expect(
      profiles.length,
      greaterThanOrEqualTo(15),
      reason:
          'каталог подозрительно мал: сторож, которому нечего читать, зелен '
          'по недосмотру, а не по делу',
    );

    final offences = <String>[];
    for (final profile in profiles) {
      final title = deviceProfileTitle(profile, l10n);
      if (_cyrillic.hasMatch(title)) {
        offences.add('  профиль ${profile.id}: "$title"');
      }
      for (final param in profile.connectionParams) {
        final text = deviceParamDescription(profile, param, l10n);
        if (_cyrillic.hasMatch(text)) {
          offences.add('  параметр ${profile.id}/${param.key}: "$text"');
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason:
          'эти подписи доедут до человека, выбравшего английский. Заведите '
          'ключ в словаре и впишите его в deviceProfileTitle / '
          'deviceParamDescription, а не исключение здесь:\n'
          '${offences.join('\n')}',
    );
  });
}
