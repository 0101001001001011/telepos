import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The SharedPreferences key `hardware_settings_screen.dart` saves the
/// graphic-customer-screen choice under.
///
/// Deliberately not `hardware_settings` — that installation-wide blob is
/// retired. This lives in `lib/core/settings/`, not next to
/// `CustomerWindowService` under `lib/hardware/`, so presentation can depend
/// on it without importing hardware directly (И5) — the same reason
/// `scroll_assist_settings.dart` lives here rather than beside the code it
/// configures. Public so both the writer
/// (`hardware_settings_screen.dart`) and every reader (`lib/main.dart`) get
/// the key from one place, instead of each hand-rolling their own copy of
/// it the way the old `hardware_settings` blob's readers did.
const kCustomerScreenPrefsKey = 'customer_display_window';

/// Whether the graphic customer screen should open on startup, and on which
/// monitor.
///
/// Not a device binding: this is a window this same process opens on
/// another display, not a peripheral with a device profile — see the
/// comment above where `hardware_settings_screen.dart` saves this.
class CustomerScreenChoice {
  const CustomerScreenChoice({required this.enabled, required this.monitor});

  /// Disabled default used whenever nothing has been saved yet, or the
  /// saved value can't be parsed. Never let a malformed preference open an
  /// unwanted window on a live till (И30).
  static const disabled = CustomerScreenChoice(enabled: false, monitor: 1);

  final bool enabled;
  final int monitor;

  /// Reads the choice `hardware_settings_screen.dart` last saved.
  ///
  /// The single parsing path for [kCustomerScreenPrefsKey] — both
  /// `lib/main.dart` (decides whether to open the window on startup) and the
  /// settings screen itself (repopulates the form) call this instead of each
  /// hand-rolling their own `jsonDecode`.
  static CustomerScreenChoice read(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(kCustomerScreenPrefsKey);
      if (raw == null) return disabled;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return CustomerScreenChoice(
        enabled: data['enabled'] as bool? ?? false,
        monitor: data['monitor'] as int? ?? 1,
      );
    } catch (_) {
      return disabled;
    }
  }
}
