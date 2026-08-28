class WarehouseEntity {
  const WarehouseEntity({
    this.id,
    this.code,
    this.name,
    this.address,
    this.isActive,
    this.isDefault,
    this.state,
    this.editTime,
  });

  final int? id;

  final String? code;

  final String? name;

  final String? address;

  final bool? isActive;

  final bool? isDefault;

  final int? state;

  final int? editTime;

  WarehouseEntity copyWith({
    int? id,
    String? code,
    String? name,
    String? address,
    bool? isActive,
    bool? isDefault,
    int? state,
    int? editTime,
  }) {
    return WarehouseEntity(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      state: state ?? this.state,
      editTime: editTime ?? this.editTime,
    );
  }
}
