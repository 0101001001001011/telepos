/// Виртуальные профили — **третий** и самый дорогой из трёх механизмов
/// подстановки, и потому самый узкий.
///
/// Три механизма, ни одного нового:
///
/// 1. **Адресом.** Всё, у чего есть поле адреса на экране настроек:
///    фискальный оператор (`baseUrl`), чековый принтер и этикеточник
///    (`ipAddress`/`port`), терминал оплаты Kaspi (`ipAddress`/`port`).
///    Правок в `lib/` — ноль.
/// 2. **Петлёй операционной системы.** Всё, что говорит по COM-порту: весы,
///    дисплей покупателя. com0com на Windows, `socat -d -d pty,raw pty,raw`
///    на Linux. Правок в `lib/` — ноль.
/// 3. **Виртуальным профилем — то есть здесь.** Только два семейства из
///    семи, у которых нет ни адреса, ни порта: HID-сканер (его находит сама
///    операционная система) и печать через спулер (принтер выбирается по
///    имени очереди печати, и подставить туда нечего).
///
/// **Правило, из-за которого этот файл так мал: эмулируется зависимость, а
/// не наш адаптер.** Точка подстановки — самая дальняя от нашего кода.
/// Подставить свой класс в реестр там, где есть адрес, значило бы снять с
/// проверки как раз то, что вероятнее всего сломано: сборку запроса, разбор
/// кодов отказа, повторную авторизацию, обёртку очереди. Каждый профиль,
/// добавленный сюда сверх этих двух, — признак, что кто-то пошёл лёгким
/// путём. На это стоит сторож (`test/emulators/emulated_profiles_test.dart`).
///
/// # Чего этот каталог НЕ доказывает
///
/// * **Что чек напечатан.** Спулерный эмулятор пишет байты в файл; бумаги
///   здесь нет, и «печать прошла» означает «файл записан».
/// * **Что сканер прочитал штрихкод.** Эмулятор отдаёт строку, которую ему
///   назвали; ни оптики, ни декодера символогии здесь нет.
/// * **Что настоящий прибор ведёт себя так же.** Своего верного числа у
///   эмулятора нет ни одного.
/// * **Что этот код выброшен из магазинного бинарника.** Это утверждение о
///   компиляторе; оно измерено отдельно и записано в
///   `docs/internal/testing-notes.md`, раздел «Виртуальные профили и AOT».
library;

import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';

/// Идентификатор виртуального профиля HID-сканера.
const String kEmulatedScannerProfileId = 'emul.scanner.hid';

/// Идентификатор виртуального профиля печати через спулер.
const String kEmulatedSpoolerProfileId = 'emul.printer.spooler';

/// Ключ параметра привязки: файл, через который идёт разговор с эмулятором.
///
/// Для сканера — файл, **из** которого читаются штрихкоды (одна строка —
/// один скан); для спулера — файл, **в** который пишутся байты ESC/POS.
const String kEmulatedFileParam = 'emulFile';

/// Ключ параметра привязки: заставить эмулятор отказать.
///
/// Эмулятор, который не умеет отказать, бесполезен: ветка отказа
/// недостижима, и её сторожа зелены впустую.
const String kEmulatedRefuseParam = 'emulRefuse';

class EmulatedDeviceProfileCatalog implements DeviceProfileCatalog {
  const EmulatedDeviceProfileCatalog();

  static const List<DeviceProfile> _profiles = <DeviceProfile>[
    DeviceProfile(
      id: kEmulatedScannerProfileId,
      deviceClass: DeviceClass.scanner,
      title: 'Эмулятор HID-сканера (файл)',
      protocol: DeviceProtocol.emulated,
      capabilities: DeviceCapabilities(
        barcodeSymbologies: ['EAN13', 'EAN8', 'CODE128'],
      ),
      connectionParams: [
        DeviceConnectionParam(
          key: kEmulatedFileParam,
          isRequired: true,
          description:
              'Файл, из которого читаются штрихкоды: одна строка — один скан',
        ),
        DeviceConnectionParam(
          key: kEmulatedRefuseParam,
          isRequired: false,
          description:
              'Причина отказа: notFound — файла нет, unreadable — читать '
              'нельзя. Пусто — эмулятор работает',
        ),
      ],
    ),
    DeviceProfile(
      id: kEmulatedSpoolerProfileId,
      deviceClass: DeviceClass.receiptPrinter,
      title: 'Эмулятор печати через спулер (файл)',
      protocol: DeviceProtocol.emulated,
      capabilities: DeviceCapabilities(
        paperWidthsMm: [58, 80],
        canCutPaper: true,
        codePages: ['CP866'],
        // Ящик через принтер: команда `ESC p` уходит в тот же файл, и её
        // видно глазом — ровно то, что делает настоящий принтер с кик-портом.
        supportsOpenDrawer: true,
      ),
      connectionParams: [
        DeviceConnectionParam(
          key: kEmulatedFileParam,
          isRequired: true,
          description: 'Файл, в который пишутся байты ESC/POS',
        ),
        DeviceConnectionParam(
          key: kEmulatedRefuseParam,
          isRequired: false,
          description:
              'Причина отказа: offline — не подключается, outOfPaper — нет '
              'бумаги, coverOpen — крышка открыта, throws — исключение из '
              'драйвера. Пусто — эмулятор печатает',
        ),
      ],
    ),
  ];

  @override
  List<DeviceProfile> forClass(DeviceClass deviceClass) => _profiles
      .where((p) => p.deviceClass == deviceClass)
      .toList(growable: false);

  @override
  DeviceProfile? byId(String id) {
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }
}
