import 'package:telepos/domain/ismpt/ismpt_provider_registry.dart';

class IsMptSettings {
  const IsMptSettings({this.backend = IsMptBackend.none, this.enabled = false});

  final IsMptBackend backend;

  final bool enabled;

  bool get isActive => enabled && backend != IsMptBackend.none;

  IsMptBackend get resolvedBackend => enabled ? backend : IsMptBackend.none;

  IsMptSettings copyWith({IsMptBackend? backend, bool? enabled}) {
    return IsMptSettings(
      backend: backend ?? this.backend,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'backend': backend.value,
    'enabled': enabled,
  };

  factory IsMptSettings.fromJson(Map<String, dynamic> json) => IsMptSettings(
    backend: IsMptBackend.fromValue(json['backend'] as int? ?? 0),
    enabled: json['enabled'] as bool? ?? false,
  );

  factory IsMptSettings.disabled() => const IsMptSettings();
}
