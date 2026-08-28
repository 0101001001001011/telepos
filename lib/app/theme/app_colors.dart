import 'dart:ui';

/// Единственное место в проекте, где живут цвета.
///
/// Значения — разбор светлой палитры Telegram Web/Desktop. Это не официальная
/// спецификация Telegram, а осознанный подбор под неё, и так честнее: обещать
/// точное совпадение с чужим продуктом мы не можем.
///
/// Старые имена (`primary`, `success`, `error`, …) сохранены как псевдонимы:
/// на них ссылается всё остальное приложение, и переименование ради
/// переименования потребовало бы править сотню экранов, ничего не дав.
/// Благодаря им смена палитры остаётся **одним коммитом**, а не проектом.
///
/// Новый код обращается к `Theme.of(context)`, а не сюда: цвет, взятый мимо
/// темы, нельзя подменить в тесте и нельзя перекрасить в тёмной.
class AppColors {
  AppColors._();

  // ── Палитра Telegram, светлая тема ──────────────────────────────────────

  /// Акцент: кнопки, ссылки, выбранное состояние, рамка фокуса.
  static const tgBlue = Color(0xFF3390EC);

  /// Нажатое состояние акцента.
  static const tgBluePressed = Color(0xFF2B7CD3);

  /// Акцент **под текстом и в тексте**.
  ///
  /// Второй синий заведён не для красоты. Измерено: белый на [tgBlue] даёт
  /// 3.31:1, и синий на белом — те же 3.31:1, а порог WCAG AA для обычного
  /// текста 4.5:1. Под него попадают кнопка «Далее», ссылки и подписи
  /// акцентом. Сам Telegram отгружает свой синий с белым текстом, то есть
  /// тоже не проходит; касса, в экран которой смотрят часами и не всегда при
  /// хорошем свете, такого себе позволить не может.
  ///
  /// Как **не-текстовый** элемент — заливка, рельс, галочка, рамка фокуса —
  /// [tgBlue] остаётся: там порог 3:1, и 3.31 его проходит. Поэтому цвета два
  /// и делятся они по назначению, а не по вкусу: #1E75BB даёт 4.86:1 и
  /// визуально почти неотличим на мелких элементах.
  static const tgBlueText = Color(0xFF1E75BB);

  /// Основной текст. Не чистый чёрный: на белом он звенит, и на кассе, где
  /// в экран смотрят часами, это заметно.
  static const tgInk = Color(0xFF111114);

  /// Вторичный текст, подписи секций, подсказки.
  static const tgMuted = Color(0xFF707579);

  /// Поверхность секции.
  static const tgSheet = Color(0xFFFFFFFF);

  /// Фон под секциями.
  static const tgCanvas = Color(0xFFF3F4F6);

  /// Разделитель. Толщина — один физический пиксель, см. `AppTokens`.
  static const tgHairline = Color(0xFFE5E5EA);

  /// Успех, подтверждение.
  static const tgGreen = Color(0xFF4FAE4E);

  /// Ошибка, разрушающее действие.
  static const tgRed = Color(0xFFDF3F40);

  /// Предупреждение.
  static const tgAmber = Color(0xFFF5A623);

  // ── Псевдонимы для остального приложения ────────────────────────────────
  //
  // До 2026-08-03 здесь стояла палитра Flat UI образца 2013 года: акцент
  // #1ABC9C, фон #C8C8C8, scaffold #EEEEEE. Имена остались, значения ушли.

  static const primary = tgBlue;
  static const primaryLight = Color(0xFFA8CDF5);
  static const primaryLighter = Color(0xFFEAF3FD);
  static const primaryAlt = tgBlue;
  static const primaryPressed = tgBluePressed;

  static const success = tgGreen;
  static const successAlt = tgGreen;
  static const successLight = Color(0xFFB6DEB5);

  static const warning = tgAmber;
  static const warningLight = Color(0xFFFDEBD0);
  static const warningAlt = tgAmber;
  static const warningGold = tgAmber;
  static const warningPressed = Color(0xFFE09420);

  static const error = tgRed;
  static const errorAlt = tgRed;
  static const errorLight = Color(0xFFF3B2B2);
  static const errorDark = Color(0xFF8E2828);
  static const errorPressed = Color(0xFFC63637);

  static const tabSale = tgGreen;
  static const tabRefund = tgAmber;
  static const tabShift = tgRed;
  static const tabHistory = tgBlue;

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const background = tgCanvas;
  static const surface = tgSheet;
  static const surfaceVariant = tgCanvas;
  static const textPrimary = tgInk;
  static const textSecondary = tgMuted;
  static const textHint = tgMuted;
  static const textDisabled = Color(0xFFB4B8BC);

  /// Текст акцентом — значит текстовый синий, см. [tgBlueText].
  static const textAccent = tgBlueText;

  static const grey = tgMuted;
  static const greyLight = tgCanvas;
  static const greyMedium = tgHairline;
  static const greyDark = Color(0xFF3C4043);
  static const greyButton = tgMuted;

  static const border = tgHairline;
  static const borderLight = tgHairline;
  static const borderPrimary = tgBlue;
  static const divider = tgHairline;

  static const modalOverlay = Color(0xA8000000);
  static const shadow = Color(0x40000000);
  static const shadowLight = Color(0x20000000);

  static const statusOnline = tgGreen;
  static const statusOffline = tgMuted;
  static const statusSync = tgBlue;

  static const debtPositive = tgGreen;
  static const debtNegative = tgRed;

  static const paymentCash = tgGreen;
  static const paymentCard = tgBlue;
  static const paymentMixed = Color(0xFF8E7CC3);

  static const info = tgBlue;
  static const infoLight = Color(0xFFEAF3FD);

  // ── Палитра Telegram, тёмная тема ───────────────────────────────────────
  //
  // До 2026-08-04 здесь стояли синеватые нейтрали (#17212B / #1F2936 /
  // #2B3946). Они не были неправильными сами по себе — так выглядит схема
  // «Night» из Telegram Desktop, — но спека приложения называет другую, серую,
  // и держать в коде третью палитру, которой нет ни в одном согласованном
  // документе, значит гарантировать расхождение.
  //
  // Важнее другое: тёмная тема была подключена только 2026-08-04, то есть до
  // этой даты **ни одно из этих значений никто не видел на экране**. Ниже —
  // палитра из спеки, и каждое утверждение о её читаемости измерено числом в
  // `test/theme/app_colors_test.dart`, а не оценено на глаз.

  /// Фон под секциями.
  ///
  /// **Синеватый, а не серый — правка 2026-08-27 по замечанию заказчика.**
  /// Прежние значения (#212121 / #2C2C2C / #3A3A3A) — нейтральные серые
  /// Material, и рядом с ними стоял акцент #6AB3F3, взятый из ночной темы
  /// Telegram Desktop. То есть акцент был телеграмный, а поверхности вокруг
  /// него — нет, и тёмная тема не выглядела тем продуктом, о котором
  /// договаривались («Telegram light» в спеке — про светлую; тёмная обязана
  /// быть ночной темой того же Telegram, а не Material).
  ///
  /// Значения — палитра ночной темы Telegram Desktop. Контраст от этого
  /// вырос везде, потому что поверхности стали темнее: чернила 13.97 → 16.29,
  /// акцент 6.22 → 7.26, ошибка 5.03 → 5.87.
  static const tgDarkCanvas = Color(0xFF0E1621);

  /// Поверхность секции.
  static const tgDarkSheet = Color(0xFF17212B);

  /// Разделитель.
  static const tgDarkHairline = Color(0xFF232E3C);

  /// Основной текст. Здесь он чистый белый, в отличие от светлой темы, где
  /// чистый чёрный звенит: на тёмном фоне тот же приём даёт обратный
  /// результат — приглушённый белый выглядит выцветшим, а не спокойным.
  static const tgDarkInk = Color(0xFFFFFFFF);

  /// Вторичный текст, подписи секций, подсказки.
  ///
  /// Синеватый под стать поверхностям, но **не** телеграмный `#708499`: тот
  /// на новой секции даёт 4.23:1 при пороге 4.5:1, то есть подписи не
  /// проходили бы. Копировать палитру целиком нельзя — Telegram живёт со
  /// своими порогами, а здесь правило измерения. #94A6B8 даёт 6.52 на секции
  /// и 7.28 на холсте, то есть не хуже прежнего серого #AAAAAA (6.01/7.01) и
  /// при этом одного семейства с фоном.
  static const tgDarkMuted = Color(0xFF94A6B8);

  /// Акцент тёмной темы.
  ///
  /// Ночной акцент Telegram Desktop, и он же светлее дневного.
  ///
  /// **Довод изменился вместе с палитрой (2026-08-27), и это записано, а не
  /// подогнано.** Пока секция была серой #2C2C2C, дневной #3390EC давал на
  /// ней 4.22:1 при пороге 4.5 — то есть просто не проходил, и этого хватало
  /// как обоснования. На телеграмной секции #17212B тот же дневной даёт уже
  /// **4.92:1**, порог берёт, и прежний довод перестал быть верным.
  ///
  /// Ночной остаётся, но по двум другим причинам: он даёт **7.26:1** против
  /// 4.92 — разница не косметическая; и он и есть тот цвет, которым Telegram
  /// Desktop красит ночную тему, ради чего вся палитра и менялась.
  ///
  /// Второй синий, как в светлой теме, здесь не нужен: тот заводился ради
  /// белого текста на заливке, а в тёмной теме текст на заливке чёрный
  /// (см. `onPrimary` в `AppTheme.dark`) и даёт 8.40:1 без дополнительного
  /// оттенка.
  static const tgBlueDark = Color(0xFF6AB3F3);

  /// Ошибка в тёмной теме.
  ///
  /// Дневной #DF3F40 на серой секции давал 3.27:1 — ниже порога 4.5:1.
  /// Звёздочка обязательного поля и текст ошибки в тёмной теме читались хуже
  /// подписи рядом с ними. #FF6B6B на телеграмной секции #17212B даёт
  /// **5.87:1** (на прежней серой было 5.03).
  static const tgRedDark = Color(0xFFFF6B6B);

  // ── Псевдонимы тёмной темы ──────────────────────────────────────────────
  //
  // Имена, на которые ссылается остальное приложение. Как и в светлой части
  // файла: значения меняются одним коммитом, места использования не трогаются.

  static const darkBackground = tgDarkCanvas;
  static const darkSurface = tgDarkSheet;
  static const darkSurfaceVariant = tgDarkHairline;
  static const darkTextPrimary = tgDarkInk;
  static const darkTextSecondary = tgDarkMuted;
  static const darkBorder = tgDarkHairline;
}
