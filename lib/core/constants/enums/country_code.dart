import 'package:telepos/core/constants/enums/tax_treatment.dart';

import 'package:telepos/core/constants/enums/currency.dart';
import 'package:telepos/core/constants/enums/national_system.dart';
import 'package:telepos/domain/setup/setup_draft.dart';

enum CountryCode {
  kzt(
    banknotes: [200, 500, 1000, 2000, 5000, 10000, 20000],
    headerCode: '77',
    phoneMask: '+7 (7##) ### ## ##',
    currencySymbol: '₸',
    currencyName: 'Казахстанский тенге',
    currencyShort: 'KZT',
    countryName: 'Казахстан',
    countryNameEn: 'Kazakhstan',
    taxIdLabel: 'БИН/ИИН',
    taxIdHint: '123456789012',
    taxIdLength: 12,
    language: 'kk',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.kzt,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.webkassa,
    isoCode: 'KZ',
    dateFormat: 'dd.MM.yyyy',
    nationalSystems: {
      NationalSystem.electronicInvoice,
      NationalSystem.goodsNote,
      NationalSystem.transportWaybill,
      NationalSystem.productMarking,
      NationalSystem.taxForms,
    },
  ),

  rub(
    banknotes: [50, 100, 200, 500, 1000, 2000, 5000],
    headerCode: '7',
    phoneMask: '+7 (###) ### ## ##',
    currencySymbol: '₽',
    currencyName: 'Российский рубль',
    currencyShort: 'RUB',
    countryName: 'Россия',
    countryNameEn: 'Russia',
    taxIdLabel: 'ИНН',
    taxIdHint: '1234567890',
    taxIdLength: 10,
    language: 'ru',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.rub,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.ofd,
    isoCode: 'RU',
    dateFormat: 'dd.MM.yyyy',
  ),

  kgs(
    banknotes: [20, 50, 100, 200, 500, 1000, 5000],
    headerCode: '996',
    phoneMask: '+996 (###) ## ## ##',
    currencySymbol: 'сом',
    currencyName: 'Кыргызский сом',
    currencyShort: 'KGS',
    countryName: 'Кыргызстан',
    countryNameEn: 'Kyrgyzstan',
    taxIdLabel: 'ИНН',
    taxIdHint: '12345678901234',
    taxIdLength: 14,
    language: 'ky',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.kgs,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.ofd,
    isoCode: 'KG',
    dateFormat: 'dd.MM.yyyy',
  ),

  uzs(
    banknotes: [1000, 5000, 10000, 20000, 50000, 100000, 200000],
    headerCode: '998',
    phoneMask: '+998 (##) #### ###',
    currencySymbol: 'сўм',
    currencyName: 'Узбекский сум',
    currencyShort: 'UZS',
    countryName: 'Узбекистан',
    countryNameEn: 'Uzbekistan',
    taxIdLabel: 'СТИР/ИНН',
    taxIdHint: '123456789',
    taxIdLength: 9,
    language: 'uz',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    currencyAfterAmount: true,
    decimalDigits: 0,
    defaultCurrency: Currency.uzs,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.ofd,
    isoCode: 'UZ',
    dateFormat: 'dd.MM.yyyy',
  ),

  usd(
    banknotes: [1, 5, 10, 20, 50, 100],
    headerCode: '1',
    phoneMask: '+1 (###) ### ####',
    currencySymbol: '\$',
    currencyName: 'US Dollar',
    currencyShort: 'USD',
    countryName: 'США',
    countryNameEn: 'United States',
    taxIdLabel: 'EIN/TIN',
    taxIdHint: '12-3456789',
    taxIdLength: 9,
    language: 'en',
    decimalSeparator: '.',
    thousandSeparator: ',',
    currencyAfterAmount: false,
    decimalDigits: 2,
    defaultCurrency: Currency.usd,
    taxTreatment: TaxTreatment.exclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'US',
    dateFormat: 'M/d/yyyy',
  ),

  tmt(
    banknotes: [1, 5, 10, 20, 50, 100, 500],
    headerCode: '993',
    phoneMask: '+993 (##) ## ## ##',
    currencySymbol: 'TMT',
    currencyName: 'Туркменский манат',
    currencyShort: 'TMT',
    countryName: 'Туркменистан',
    countryNameEn: 'Turkmenistan',
    taxIdLabel: 'ИНН',
    taxIdHint: '123456789012',
    taxIdLength: 12,
    language: 'tk',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.tmt,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.ofd,
    isoCode: 'TM',
    dateFormat: 'dd.MM.yyyy',
  ),

  deu(
    banknotes: [5, 10, 20, 50, 100, 200, 500],
    headerCode: '49',
    phoneMask: '+49 ### #######',
    currencySymbol: '€',
    currencyName: 'Евро',
    currencyShort: 'EUR',
    countryName: 'Германия',
    countryNameEn: 'Germany',
    taxIdLabel: 'USt-IdNr',
    taxIdHint: '123456789',
    taxIdLength: 9,
    taxIdIsNumeric: true,
    language: 'de',
    decimalSeparator: ',',
    thousandSeparator: '.',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.eur,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'DE',
    dateFormat: 'dd.MM.yyyy',
  ),

  fra(
    banknotes: [5, 10, 20, 50, 100, 200, 500],
    headerCode: '33',
    phoneMask: '+33 # ## ## ## ##',
    currencySymbol: '€',
    currencyName: 'Евро',
    currencyShort: 'EUR',
    countryName: 'Франция',
    countryNameEn: 'France',
    taxIdLabel: 'TVA',
    taxIdHint: '12345678901',
    taxIdLength: 11,
    taxIdIsNumeric: true,
    language: 'fr',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.eur,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'FR',
    dateFormat: 'dd/MM/yyyy',
  ),

  esp(
    banknotes: [5, 10, 20, 50, 100, 200, 500],
    headerCode: '34',
    phoneMask: '+34 ### ### ###',
    currencySymbol: '€',
    currencyName: 'Евро',
    currencyShort: 'EUR',
    countryName: 'Испания',
    countryNameEn: 'Spain',
    taxIdLabel: 'NIF',
    taxIdHint: '123456789',
    taxIdLength: 9,
    taxIdIsNumeric: true,
    language: 'es',
    decimalSeparator: ',',
    thousandSeparator: '.',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.eur,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'ES',
    dateFormat: 'dd/MM/yyyy',
  ),

  ita(
    banknotes: [5, 10, 20, 50, 100, 200, 500],
    headerCode: '39',
    phoneMask: '+39 ### ### ####',
    currencySymbol: '€',
    currencyName: 'Евро',
    currencyShort: 'EUR',
    countryName: 'Италия',
    countryNameEn: 'Italy',
    taxIdLabel: 'P.IVA',
    taxIdHint: '12345678901',
    taxIdLength: 11,
    taxIdIsNumeric: true,
    language: 'it',
    decimalSeparator: ',',
    thousandSeparator: '.',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.eur,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'IT',
    dateFormat: 'dd/MM/yyyy',
  ),

  gbr(
    banknotes: [5, 10, 20, 50],
    headerCode: '44',
    phoneMask: '+44 #### ######',
    currencySymbol: '£',
    currencyName: 'Фунт стерлингов',
    currencyShort: 'GBP',
    countryName: 'Великобритания',
    countryNameEn: 'United Kingdom',
    taxIdLabel: 'VAT No',
    taxIdHint: '123456789',
    taxIdLength: 9,
    taxIdIsNumeric: true,
    language: 'en',
    decimalSeparator: '.',
    thousandSeparator: ',',
    currencyAfterAmount: false,
    decimalDigits: 2,
    defaultCurrency: Currency.gbp,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'GB',
    dateFormat: 'dd/MM/yyyy',
  ),

  pol(
    banknotes: [10, 20, 50, 100, 200, 500],
    headerCode: '48',
    phoneMask: '+48 ### ### ###',
    currencySymbol: 'zł',
    currencyName: 'Польский злотый',
    currencyShort: 'PLN',
    countryName: 'Польша',
    countryNameEn: 'Poland',
    taxIdLabel: 'NIP',
    taxIdHint: '1234567890',
    taxIdLength: 10,
    taxIdIsNumeric: true,
    language: 'pl',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.pln,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'PL',
    dateFormat: 'dd.MM.yyyy',
  ),

  tur(
    banknotes: [5, 10, 20, 50, 100, 200],
    headerCode: '90',
    phoneMask: '+90 ### ### ## ##',
    currencySymbol: '₺',
    currencyName: 'Турецкая лира',
    currencyShort: 'TRY',
    countryName: 'Турция',
    countryNameEn: 'Türkiye',
    taxIdLabel: 'VKN',
    taxIdHint: '1234567890',
    taxIdLength: 10,
    taxIdIsNumeric: true,
    language: 'tr',
    decimalSeparator: ',',
    thousandSeparator: '.',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.tryy,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'TR',
    dateFormat: 'dd.MM.yyyy',
  ),

  chn(
    banknotes: [1, 5, 10, 20, 50, 100],
    headerCode: '86',
    phoneMask: '+86 ### #### ####',
    currencySymbol: '¥',
    currencyName: 'Китайский юань',
    currencyShort: 'CNY',
    countryName: 'Китай',
    countryNameEn: 'China',
    taxIdLabel: '统一社会信用代码',
    taxIdHint: '91310000MA1K35630X',
    taxIdLength: 18,
    taxIdIsNumeric: false,
    language: 'zh',
    decimalSeparator: '.',
    thousandSeparator: ',',
    currencyAfterAmount: false,
    decimalDigits: 2,
    defaultCurrency: Currency.cny,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'CN',
    dateFormat: 'yyyy-MM-dd',
  ),

  jpn(
    banknotes: [1000, 2000, 5000, 10000],
    headerCode: '81',
    phoneMask: '+81 ## #### ####',
    currencySymbol: '¥',
    currencyName: 'Японская иена',
    currencyShort: 'JPY',
    countryName: 'Япония',
    countryNameEn: 'Japan',
    taxIdLabel: '法人番号',
    taxIdHint: '1234567890123',
    taxIdLength: 13,
    taxIdIsNumeric: true,
    language: 'ja',
    decimalSeparator: '.',
    thousandSeparator: ',',
    currencyAfterAmount: false,
    decimalDigits: 0,
    defaultCurrency: Currency.jpy,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'JP',
    dateFormat: 'yyyy/MM/dd',
  ),

  kor(
    banknotes: [1000, 5000, 10000, 50000],
    headerCode: '82',
    phoneMask: '+82 ## #### ####',
    currencySymbol: '₩',
    currencyName: 'Южнокорейская вона',
    currencyShort: 'KRW',
    countryName: 'Южная Корея',
    countryNameEn: 'South Korea',
    taxIdLabel: '사업자등록번호',
    taxIdHint: '1234567890',
    taxIdLength: 10,
    taxIdIsNumeric: true,
    language: 'ko',
    decimalSeparator: '.',
    thousandSeparator: ',',
    currencyAfterAmount: false,
    decimalDigits: 0,
    defaultCurrency: Currency.krw,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'KR',
    dateFormat: 'yyyy-MM-dd',
  ),

  are(
    banknotes: [5, 10, 20, 50, 100, 200, 500, 1000],
    headerCode: '971',
    phoneMask: '+971 ## ### ####',
    currencySymbol: 'د.إ',
    currencyName: 'Дирхам ОАЭ',
    currencyShort: 'AED',
    countryName: 'ОАЭ',
    countryNameEn: 'United Arab Emirates',
    taxIdLabel: 'TRN',
    taxIdHint: '100123456700003',
    taxIdLength: 15,
    taxIdIsNumeric: true,
    language: 'ar',
    decimalSeparator: '.',
    thousandSeparator: ',',
    currencyAfterAmount: false,
    decimalDigits: 2,
    defaultCurrency: Currency.aed,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'AE',
    dateFormat: 'dd/MM/yyyy',
  ),

  sau(
    banknotes: [5, 10, 50, 100, 500],
    headerCode: '966',
    phoneMask: '+966 ## ### ####',
    currencySymbol: '﷼',
    currencyName: 'Саудовский риял',
    currencyShort: 'SAR',
    countryName: 'Саудовская Аравия',
    countryNameEn: 'Saudi Arabia',
    taxIdLabel: 'VAT No',
    taxIdHint: '300123456700003',
    taxIdLength: 15,
    taxIdIsNumeric: true,
    language: 'ar',
    decimalSeparator: '.',
    thousandSeparator: ',',
    currencyAfterAmount: false,
    decimalDigits: 2,
    defaultCurrency: Currency.sar,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'SA',
    dateFormat: 'dd/MM/yyyy',
  ),

  ind(
    banknotes: [10, 20, 50, 100, 200, 500],
    headerCode: '91',
    phoneMask: '+91 ##### #####',
    currencySymbol: '₹',
    currencyName: 'Индийская рупия',
    currencyShort: 'INR',
    countryName: 'Индия',
    countryNameEn: 'India',
    taxIdLabel: 'GSTIN',
    taxIdHint: '22AAAAA0000A1Z5',
    taxIdLength: 15,
    taxIdIsNumeric: false,
    language: 'hi',
    decimalSeparator: '.',
    thousandSeparator: ',',
    currencyAfterAmount: false,
    decimalDigits: 2,
    defaultCurrency: Currency.inr,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'IN',
    dateFormat: 'dd/MM/yyyy',
  ),

  can(
    banknotes: [5, 10, 20, 50, 100],
    headerCode: '1',
    phoneMask: '+1 (###) ### ####',
    currencySymbol: '\$',
    currencyName: 'Канадский доллар',
    currencyShort: 'CAD',
    countryName: 'Канада',
    countryNameEn: 'Canada',
    taxIdLabel: 'BN',
    taxIdHint: '123456789',
    taxIdLength: 9,
    taxIdIsNumeric: true,
    language: 'en',
    decimalSeparator: '.',
    thousandSeparator: ',',
    currencyAfterAmount: false,
    decimalDigits: 2,
    defaultCurrency: Currency.cad,
    taxTreatment: TaxTreatment.exclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'CA',
    dateFormat: 'yyyy-MM-dd',
  ),

  aus(
    banknotes: [5, 10, 20, 50, 100],
    headerCode: '61',
    phoneMask: '+61 # #### ####',
    currencySymbol: '\$',
    currencyName: 'Австралийский доллар',
    currencyShort: 'AUD',
    countryName: 'Австралия',
    countryNameEn: 'Australia',
    taxIdLabel: 'ABN',
    taxIdHint: '12345678901',
    taxIdLength: 11,
    taxIdIsNumeric: true,
    language: 'en',
    decimalSeparator: '.',
    thousandSeparator: ',',
    currencyAfterAmount: false,
    decimalDigits: 2,
    defaultCurrency: Currency.aud,
    taxTreatment: TaxTreatment.inclusive,
    fiscalProtocol: FiscalType.none,
    isoCode: 'AU',
    dateFormat: 'dd/MM/yyyy',
  );

  const CountryCode({
    required this.headerCode,
    required this.phoneMask,
    required this.currencySymbol,
    required this.currencyName,
    required this.currencyShort,
    required this.countryName,
    required this.countryNameEn,
    required this.taxIdLabel,
    required this.taxIdHint,
    required this.taxIdLength,
    required this.language,
    required this.decimalSeparator,
    required this.thousandSeparator,
    required this.currencyAfterAmount,
    required this.decimalDigits,
    required this.defaultCurrency,
    required this.banknotes,
    this.taxIdIsNumeric = true,
    required this.taxTreatment,
    required this.fiscalProtocol,
    required this.isoCode,
    required this.dateFormat,
    this.nationalSystems = const <NationalSystem>{},
  });

  /// Как налог относится к цене. См. [TaxTreatment]: для СНГ и ЕС он
  /// включён в цену, для США добавляется к подытогу.
  final TaxTreatment taxTreatment;

  /// Государственные системы, с которыми касса умеет работать в этой
  /// стране.
  ///
  /// Пусто у всех, кроме Казахстана, и это говорит о НАС, а не о законе:
  /// электронная счёт-фактура есть и в ЕС, и в Турции, и в России — мы их
  /// не реализуем, а объявить значило бы соврать.
  ///
  /// До 2026-09-22 поля не было вовсе, и четыре казахстанские системы плюс
  /// вкладка отчётов «Tax / KZ» стояли в меню на кассе любой страны.
  final Set<NationalSystem> nationalSystems;

  // Здесь лежало поле `vatRate` — ставка налога числом, по одной на
  // страну. Снято 2026-09-22: ставка обязана НАСТРАИВАТЬСЯ.
  //
  // Заказчик: «вдруг завтра поменяют и сделают 18 %, и всё, работа кассы
  // встанет тогда в России». Одного числа к тому же не хватает: почти везде
  // есть пониженные ставки и нулевая, а поле знало только одну.
  //
  // Ставки живут в наборах (`assets/tax_presets/*.json`) — отправной точке,
  // которую мастер применяет в настройку кассы, а владелец правит как
  // угодно, не дожидаясь сборки.

  /// Как страна пишет дату: `dd.MM.yyyy`, `M/d/yyyy`, `yyyy/MM/dd`.
  ///
  /// # Почему это не хардкод в том смысле, в каком им была ставка
  ///
  /// Ставку меняет закон, и потому она обязана настраиваться. Порядок дня и
  /// месяца законом не меняется — это условие письма, соседнее с
  /// разделителями числа, которые лежат здесь же.
  ///
  /// # Что было
  ///
  /// Чек печатал `ДД.ММ.ГГГГ` всегда. Для американца «05.09.2026» — это
  /// девятое мая, а не пятое сентября: дата читается ДРУГИМ днём, и на чеке
  /// нет ничего, что сказало бы, какое прочтение верное.
  final String dateFormat;

  /// Двухбуквенный код страны (ISO 3166-1 alpha-2).
  ///
  /// # Зачем он, если есть имя значения
  ///
  /// Перечисление названо по ВАЛЮТЕ — `kzt`, `usd`, `deu`, — и это
  /// историческое: первые шесть значений хранятся в базе индексами, а имя
  /// `usd` для США читается как валюта, а не страна. По этому коду
  /// подбирается налоговый набор (`assets/tax_presets/*.json`), и держать
  /// сопоставление где-то ещё значило бы завести второй источник.
  final String isoCode;

  /// Каким протоколом касса фискализует чек в этой стране.
  ///
  /// # Почему протокол, а не признак «да/нет»
  ///
  /// Признак `hasFiscalisation` и выбор оператора в мастере были ДВУМЯ
  /// источниками и разошлись: девять стран объявляли фискализацию, а мастер
  /// предлагал оператора двум — Казахстану и России. Для Киргизии,
  /// Узбекистана, Туркмении, Польши, Турции, Китая и Саудовской Аравии чек
  /// печатал фискальный блок, которого никто не настраивал: обещание
  /// документа, которого нет (измерено 2026-09-22).
  ///
  /// # Что значит [FiscalType.none]
  ///
  /// Не «в стране нет фискализации», а «эта касса её там не умеет». В
  /// Польше, Турции, Китае и Саудовской Аравии она есть по закону — у нас
  /// нет её реализации, и печатать блок значило бы соврать покупателю.
  ///
  /// В СНГ протокол ОФД один на страны, операторы разные (решение
  /// заказчика 2026-09-15); Казахстан идёт своим — WebKassa.
  final FiscalType fiscalProtocol;

  /// Умеет ли касса фискализовать чек в этой стране.
  ///
  /// Выводится из [fiscalProtocol], а не хранится рядом: два поля об одном
  /// и том же однажды разошлись, и это стоило фискального блока на чеке
  /// семи стран.
  bool get hasFiscalisation => fiscalProtocol != FiscalType.none;

  final String headerCode;

  final String phoneMask;

  final String currencySymbol;

  final String currencyName;

  final String currencyShort;

  final String countryName;

  final String countryNameEn;

  final String taxIdLabel;

  final String taxIdHint;

  final int taxIdLength;

  final String language;

  final String decimalSeparator;

  final String thousandSeparator;

  final bool currencyAfterAmount;

  final int decimalDigits;

  final Currency defaultCurrency;

  /// Банкноты страны — те, что кассир держит в руках.
  ///
  /// # Почему здесь, а не в трёх местах
  ///
  /// До 2026-09-22 список жил трижды: константой `kBillDenominations` у
  /// счётчика купюр в смене, отдельным `switch` по стране у экрана оплаты и
  /// третьим набором у самой валюты (там он с монетами).
  ///
  /// Константа у смены не зависела от страны вовсе: на американской кассе
  /// кассир пересчитывал купюры 1000, 2000, 5000 и 10000, которых не
  /// существует, и не мог пересчитать доллар, пятёрку и двадцатку. Для
  /// Казахстана оба списка совпадали — оттого расхождение и жило незаметно.
  ///
  /// Монет здесь нет: вкладка зовётся «Купюры», и мелочь в ней считают не
  /// поштучно.
  final List<int> banknotes;

  /// Состоит ли номер налогоплательщика ТОЛЬКО из цифр.
  ///
  /// У БИН, ИНН и EIN — да. У индийского GSTIN и китайского единого кода —
  /// нет, там буквы вперемешку с цифрами. Поле управляет и проверкой длины,
  /// и тем, пускает ли поле ввода буквы: запрет букв там, где они законны,
  /// означает, что номер ввести нельзя вовсе.
  final bool taxIdIsNumeric;

  bool isValidTaxId(String taxId) {
    if (!taxIdIsNumeric) {
      // Буквенно-цифровой номер меряется целиком: вырезать из GSTIN цифры
      // и сравнить их число с длиной значило бы отвергать верный номер.
      return taxId.trim().length == taxIdLength;
    }
    final digitsOnly = taxId.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length == taxIdLength;
  }

  /// Ставит разделители так, как их печатают в этой стране.
  ///
  /// До 2026-09-21 этот метод не звал НИКТО: чек печатал «Business ID:
  /// 841234567» девятью голыми цифрами, и на американской ленте это
  /// читалось как чужой номер. Форматировщик всё это время был готов —
  /// его просто не спрашивали.
  String formatTaxId(String taxId) {
    final digitsOnly = taxId.replaceAll(RegExp(r'[^0-9]'), '');
    if (this == CountryCode.usd && digitsOnly.length == 9) {
      return '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2)}';
    }
    return digitsOnly;
  }

  String formatMoney(num amount, {bool showCurrency = true}) {
    final value = amount.toDouble();
    final fixed = value.toStringAsFixed(decimalDigits);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '';

    final buffer = StringBuffer();
    final isNegative = intPart.startsWith('-');
    final digits = isNegative ? intPart.substring(1) : intPart;

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(thousandSeparator);
      }
      buffer.write(digits[i]);
    }

    var formatted = isNegative ? '-${buffer.toString()}' : buffer.toString();

    if (decimalDigits > 0) {
      formatted =
          '$formatted$decimalSeparator${decPart.padRight(decimalDigits, '0')}';
    }

    if (!showCurrency) return formatted;

    if (currencyAfterAmount) {
      return '$formatted $currencySymbol';
    } else {
      return '$currencySymbol$formatted';
    }
  }

  String formatAmount(num amount) => formatMoney(amount, showCurrency: false);

  // Здесь были `calculateVatFromSum`, `addVat` и `removeVat` — три записи
  // формулы налога в `double`. Деньги в `double` запрещены правилом проекта
  // («Decimal, НИКОГДА не double»), и ни одну из трёх не звал никто.
  //
  // Снято 2026-09-22 вместе с ещё тремя записями той же формулы в
  // `DecimalUtil` и с `VatCalculator`. Всего их оказалось шесть, и каждая
  // округляла по-своему. Формула живёт в `lib/domain/tax/tax_amounts.dart`.
}
