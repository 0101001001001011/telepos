import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

class DecimalConverter extends TypeConverter<Decimal, double> {
  const DecimalConverter();

  @override
  Decimal fromSql(double fromDb) {
    return Decimal.parse(fromDb.toString());
  }

  @override
  double toSql(Decimal value) {
    return value.toDouble();
  }
}
