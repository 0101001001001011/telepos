class CustomerDisplayConfig {
  const CustomerDisplayConfig({
    this.enabled = false,
    this.model = DisplayModel.led8,
    this.port,
    this.baudRate = 9600,
  });

  final bool enabled;

  final DisplayModel model;

  final String? port;

  final int baudRate;

  factory CustomerDisplayConfig.fromMap(Map<String, dynamic> map) {
    return CustomerDisplayConfig(
      enabled: map['enabled'] == 'true' || map['enabled'] == true,
      model: DisplayModel.fromCode(
        int.tryParse(map['model']?.toString() ?? '1') ?? 1,
      ),
      port: map['port'] as String?,
      baudRate: int.tryParse(map['baudRate']?.toString() ?? '9600') ?? 9600,
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled.toString(),
    'model': model.code.toString(),
    'port': port,
    'baudRate': baudRate.toString(),
  };

  CustomerDisplayConfig copyWith({
    bool? enabled,
    DisplayModel? model,
    String? port,
    int? baudRate,
  }) {
    return CustomerDisplayConfig(
      enabled: enabled ?? this.enabled,
      model: model ?? this.model,
      port: port ?? this.port,
      baudRate: baudRate ?? this.baudRate,
    );
  }
}

enum DisplayModel {
  led8(1, 'LED 8', 8),

  vfd20(2, 'VFD 20x2', 20);

  const DisplayModel(this.code, this.label, this.chars);

  final int code;

  final String label;

  final int chars;

  static DisplayModel fromCode(int code) {
    return DisplayModel.values.firstWhere(
      (m) => m.code == code,
      orElse: () => DisplayModel.led8,
    );
  }
}
