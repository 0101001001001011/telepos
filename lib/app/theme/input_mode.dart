import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/config/local_properties.dart';

/// Чем пользователь попадает по интерфейсу.
///
/// Это **не** то же самое, что ширина экрана. Касса на Windows с сенсорным
/// монитором широкая, но пальцевая: строка высотой 44 px на ней приводит к
/// промахам. Поэтому размеры целей нажатия берутся отсюда, а ширина колонки —
/// из `LayoutType`.
enum InputMode { touch, pointer }

/// Значение по умолчанию. Веб на настольной ОС даёт `pointer`, веб на
/// Android — `touch`, потому что `defaultTargetPlatform` в браузере
/// возвращает операционную систему, а не «web».
InputMode inputModeForPlatform({required TargetPlatform platform}) {
  return switch (platform) {
    TargetPlatform.android || TargetPlatform.iOS => InputMode.touch,
    _ => InputMode.pointer,
  };
}

const String inputModePrefsKey = 'ui_input_mode';

class InputModeNotifier extends Notifier<InputMode> {
  @override
  InputMode build() {
    // Настройка живёт в SharedPreferences, а не в базе: она описывает
    // конкретный физический экран, а не магазин, и синхронизировать её между
    // кассами было бы вредно.
    //
    // Недоступность хранилища здесь — не ошибка, а обычное дело: экран может
    // строиться до того, как поднят граф зависимостей. Бросить отсюда значит
    // оставить человека перед пустым экраном из-за настройки размера строки,
    // поэтому непрочитанное значение молча уступает место платформенному.
    final stored = _readStored();
    if (stored != null) {
      for (final mode in InputMode.values) {
        if (mode.name == stored) return mode;
      }
    }
    return inputModeForPlatform(platform: defaultTargetPlatform);
  }

  String? _readStored() {
    if (!GetIt.instance.isRegistered<LocalProperties>()) return null;
    return GetIt.instance<LocalProperties>().prefs.getString(inputModePrefsKey);
  }

  /// Меняет режим ввода. Возвращает `false`, если сохранить не удалось —
  /// на экране режим при этом уже переключён, а после перезапуска вернётся
  /// прежний, и вызывающий обязан об этом сказать, а не промолчать.
  Future<bool> set(InputMode mode) async {
    state = mode;
    if (!GetIt.instance.isRegistered<LocalProperties>()) return false;
    await GetIt.instance<LocalProperties>().prefs.setString(
      inputModePrefsKey,
      mode.name,
    );
    return true;
  }
}

final inputModeProvider = NotifierProvider<InputModeNotifier, InputMode>(
  InputModeNotifier.new,
);
