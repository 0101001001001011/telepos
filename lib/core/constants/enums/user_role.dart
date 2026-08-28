enum UserRole {
  owner,

  administrator,

  user,

  cashier;

  static UserRole fromIndex(int index) {
    if (index >= 0 && index < UserRole.values.length) {
      return UserRole.values[index];
    }
    return UserRole.cashier;
  }

  String get displayName {
    return switch (this) {
      UserRole.owner => 'Владелец',
      UserRole.administrator => 'Администратор',
      UserRole.user => 'Пользователь',
      UserRole.cashier => 'Кассир',
    };
  }
}
