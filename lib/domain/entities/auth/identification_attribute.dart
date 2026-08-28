class IdentificationAttribute {
  IdentificationAttribute(String code)
    : assert(code.length >= 5),
      _code = code,
      userId = int.parse(code.substring(4)),
      password = _restorePassword(code.substring(0, 4));

  final String _code;

  final int userId;

  final String password;

  String get code => _code;

  static bool isValid(String code) => RegExp(r'^\d{5,}$').hasMatch(code);

  static String _restorePassword(String changedPassword) {
    final buffer = StringBuffer();
    for (final codeUnit in changedPassword.codeUnits) {
      var operand = (codeUnit - 49) % 10;
      while (operand % 3 != 0) {
        operand += 10;
      }
      buffer.writeCharCode(operand ~/ 3 + 48);
    }
    return buffer.toString();
  }
}
