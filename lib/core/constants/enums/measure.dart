enum Measure {
  piece('шт'),

  kg('кг'),

  liter('литр'),

  meter('метр');

  const Measure(this.unit);

  final String unit;
}
