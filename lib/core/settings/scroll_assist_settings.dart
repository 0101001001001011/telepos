import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/core/locale/locale_provider.dart';

const String kScrollAssistPrefKey = 'ui_scroll_assist_enabled';

const bool kScrollAssistDefault = true;

final scrollAssistEnabledProvider =
    NotifierProvider<ScrollAssistNotifier, bool>(ScrollAssistNotifier.new);

class ScrollAssistNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(kScrollAssistPrefKey) ?? kScrollAssistDefault;
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> set(bool value) async {
    if (state == value) return;
    state = value;
    await _prefs.setBool(kScrollAssistPrefKey, value);
  }

  Future<void> toggle() => set(!state);
}
