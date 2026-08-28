import 'package:decimal/decimal.dart';

abstract mixin class Markable {
  String get name;

  Decimal get quantity;

  set quantity(Decimal value);

  void addMark(String mark);

  List<String> get marks;

  set marks(List<String> value);
}
