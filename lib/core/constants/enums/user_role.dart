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

  // `displayName` здесь БЫЛ и возвращал русские слова. Подпись для
  // человека давно переехала в `presentation/common/utils/role_label.dart`,
  // но геттер остался — и его звали ещё в двух местах, где слову не место:
  //
  // * `LocalAuthRepository` выписывал им РОЛЬ СЕАНСА, а провод сличал её с
  //   устойчивым ключом (`r.name == session.role`). Совпадения не бывало
  //   никогда, `DiscountAuthority.roleIndex` выходил −1, и предел скидки,
  //   заданный роли, на браузерном терминале не действовал;
  // * экран входа сличал имя роли с русским словом, компенсируя первое.
  //
  // По проводу и в базе едет ключ (`cashier`), слово выбирается при показе.
}
