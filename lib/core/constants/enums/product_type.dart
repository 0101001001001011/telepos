/// Род товара. Индекс члена лежит на диске (`product_infos.type`): новые
/// члены — только в конец.
enum ProductType {
  normal,
  weight,
  inner,
  package,
  service,
  consumable,
  dish,

  /// Подарочный сертификат **как товар** — то, что покупают, а не то, чем
  /// платят (решение заказчика 2026-09-14, A1). Признак позиции, по которому
  /// касса решает, уходит ли строка в фискальный чек продажи: настройка
  /// `FiscalOffsetSettings.fiscalizeCertificateSale`, по умолчанию выкл.
  giftCertificate,
}
