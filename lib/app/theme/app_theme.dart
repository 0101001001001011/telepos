import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/app_typography.dart';

/// Сборка темы. Единственное место, где решается, как выглядит контрол.
///
/// Настроено столько под-тем, сколько нужно, чтобы экрану **нечего было
/// доопределять**: кнопки, поля, карточки, строки списка, переключатели,
/// разделители, диалоги, прогресс, чипы, снекбары, шторки, таблицы, вкладки.
/// Пока хоть одна не настроена, экран стилизует её сам, и стиль снова
/// расползается по формам — ровно то, из чего этот редизайн вытаскивает.
///
/// Светлая и тёмная собираются одним [_build]: две отдельные сборки
/// расходятся, и расхождение обнаруживается через полгода на экране, который
/// в тёмной никто не открывал.
class AppTheme {
  AppTheme._();

  // Величины, на которые ссылается остальное приложение: `AppTheme.spacing`
  // встречается 189 раз, `borderRadius` — 105. Имена оставлены, но источник
  // значения теперь один — AppTokens.
  static const double minButtonSize = AppTokens.space48;
  static const double buttonHeight = AppTokens.space48;
  static const double buttonHeightLarge = AppTokens.rowHeightTouch + 4;
  static const double borderRadius = AppTokens.radiusChip;
  static const double borderRadiusSmall = AppTokens.space4;
  static const double borderRadiusLarge = AppTokens.radiusSection;
  static const double spacing = AppTokens.space16;
  static const double spacingSmall = AppTokens.space8;
  static const double spacingLarge = AppTokens.space24;

  static ThemeData get light => _build(
    brightness: Brightness.light,
    scheme: const ColorScheme.light(
      primary: AppColors.tgBlue,
      onPrimary: AppColors.tgSheet,
      secondary: AppColors.tgBlue,
      onSecondary: AppColors.tgSheet,
      error: AppColors.tgRed,
      onError: AppColors.tgSheet,
      surface: AppColors.tgSheet,
      onSurface: AppColors.tgInk,
      onSurfaceVariant: AppColors.tgMuted,
      outline: AppColors.tgHairline,
      outlineVariant: AppColors.tgHairline,
    ),
    canvas: AppColors.tgCanvas,
    semantic: const AppSemanticColors(
      success: AppColors.tgGreen,
      warning: AppColors.tgAmber,
      canvas: AppColors.tgCanvas,
      hairline: AppColors.tgHairline,
      accentFill: AppColors.tgBlueText,
    ),
  );

  /// Тёмная тема — не «светлая с другим фоном».
  ///
  /// Акцент здесь другой ([AppColors.tgBlueDark]) и текст на акценте другой
  /// (тёмный, а не белый). Оба различия измерены, а не выбраны:
  ///
  /// * дневной #3390EC на секции #2C2C2C — **4.22:1** при пороге AA 4.5:1,
  ///   то есть ссылки и подписи акцентом порога не брали;
  /// * белый на дневном #3390EC — **3.31:1**, то есть подпись кнопки «Далее»
  ///   не брала порога тоже. Прежний комментарий в [_build] утверждал, что в
  ///   тёмной теме ограничение «снимается само». Это неправда: фон вокруг
  ///   кнопки к контрасту подписи НА кнопке отношения не имеет, а заливка и
  ///   подпись были те же самые, что в светлой.
  ///
  /// Стало: заливка #6AB3F3, подпись [AppColors.tgInk] — **8.40:1**.
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scheme: const ColorScheme.dark(
      primary: AppColors.tgBlueDark,
      // Тёмный текст на светлом синем. В тёмной теме это не инверсия ради
      // инверсии: акцент здесь светлее фона, и белым по нему писать нечем.
      onPrimary: AppColors.tgInk,
      secondary: AppColors.tgBlueDark,
      onSecondary: AppColors.tgInk,
      error: AppColors.tgRedDark,
      onError: AppColors.tgInk,
      surface: AppColors.tgDarkSheet,
      onSurface: AppColors.tgDarkInk,
      onSurfaceVariant: AppColors.tgDarkMuted,
      outline: AppColors.tgDarkHairline,
      outlineVariant: AppColors.tgDarkHairline,
    ),
    canvas: AppColors.tgDarkCanvas,
    semantic: const AppSemanticColors(
      success: AppColors.tgGreen,
      warning: AppColors.tgAmber,
      canvas: AppColors.tgDarkCanvas,
      hairline: AppColors.tgDarkHairline,
      // Заливка акцентом под текст — та же, что у кнопки: измерено 8.40:1
      // против 3.31:1 у дневного синего. Роль вынесена наружу потому, что до
      // неё это знание было локальной переменной внутри `_build` и всякий, кто
      // заливал акцентом что-то своё, брал tgBlue и терял контраст.
      accentFill: AppColors.tgBlueDark,
    ),
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color canvas,
    required AppSemanticColors semantic,
  }) {
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusControl),
    );
    final sectionShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusSection),
    );

    // Цвет акцента, пригодный под ТЕКСТ, — и он разный в двух темах.
    //
    // Светлая: белый на tgBlue даёт 3.31:1 при пороге AA 4.5:1, поэтому
    // заливка кнопки берёт текстовый синий #1E75BB (4.86:1).
    //
    // Тёмная: раньше здесь стоял тот же tgBlue с оговоркой «в тёмной теме
    // ограничение снимается само». Оно не снимается — фон вокруг кнопки не
    // влияет на контраст подписи внутри неё, — и сверх того tgBlue как ТЕКСТ
    // на тёмной секции давал 4.22:1, то есть тоже не проходил. Берётся
    // tgBlueDark: как текст на секции 6.22:1, как заливка под tgInk 8.40:1.
    final onFill = brightness == Brightness.light
        ? AppColors.tgBlueText
        : AppColors.tgBlueDark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: AppTypography.family,
      textTheme: AppTypography.textTheme,
      extensions: <ThemeExtension<dynamic>>[semantic],

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        // Material 3 подмешивает акцент в поверхность по высоте. У плоской
        // темы высоты нет, а подмешивание осталось бы и красило белое в
        // голубоватое при прокрутке.
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Полоса 54, а не материальные 56, и задано это здесь, а не в
        // оболочке: шапка есть у сорока экранов вне `AdaptiveScaffold`, и
        // высота, выставленная в одном месте, оставила бы остальные на чужом
        // ритме.
        toolbarHeight: AppTokens.appBarHeight,
        titleTextStyle: AppTypography.title.copyWith(color: scheme.onSurface),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: onFill,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: semantic.hairline,
          disabledForegroundColor: scheme.onSurfaceVariant,
          elevation: 0,
          shadowColor: Colors.transparent,
          // Порог доступности, а не предпочтение. 48 — это минимум, ниже
          // которого палец промахивается; 52 из WizardActions — высота
          // главной кнопки мастера, и задавать её всем кнопкам
          // приложения значит ломать плотные диалоги. Измерено: с 52
          // переполнялась строка действий в user_management_screen.
          // Size(0, 48), а НЕ Size.fromHeight(48): последний задаёт
          // ширину бесконечной, и тогда каждая кнопка приложения
          // требует бесконечной ширины — в Row это не переполнение,
          // а ошибка компоновки. Тема задаёт только нижний порог
          // высоты; ширину решает место, где кнопка стоит.
          minimumSize: const Size(0, AppTokens.space48),
          shape: controlShape,
          // height: 1 — подпись кнопки однострочна, и абзацный
          // интерлиньяж 22/16 там ничего не выравнивает, а только
          // прибавляет контролу высоты. Измерено: с ним кнопка
          // перерастала 48 и переполняла строку действий в диалоге.
          textStyle: AppTypography.bodyStrong.copyWith(height: 1),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onFill,
          side: BorderSide(color: semantic.hairline),
          elevation: 0,
          // Порог доступности, а не предпочтение. 48 — это минимум, ниже
          // которого палец промахивается; 52 из WizardActions — высота
          // главной кнопки мастера, и задавать её всем кнопкам
          // приложения значит ломать плотные диалоги. Измерено: с 52
          // переполнялась строка действий в user_management_screen.
          // Size(0, 48), а НЕ Size.fromHeight(48): последний задаёт
          // ширину бесконечной, и тогда каждая кнопка приложения
          // требует бесконечной ширины — в Row это не переполнение,
          // а ошибка компоновки. Тема задаёт только нижний порог
          // высоты; ширину решает место, где кнопка стоит.
          minimumSize: const Size(0, AppTokens.space48),
          shape: controlShape,
          // height: 1 — подпись кнопки однострочна, и абзацный
          // интерлиньяж 22/16 там ничего не выравнивает, а только
          // прибавляет контролу высоты. Измерено: с ним кнопка
          // перерастала 48 и переполняла строку действий в диалоге.
          textStyle: AppTypography.bodyStrong.copyWith(height: 1),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: onFill,
          minimumSize: const Size(
            AppTokens.rowHeightPointer,
            AppTokens.rowHeightPointer,
          ),
          shape: controlShape,
          // height: 1 — подпись кнопки однострочна, и абзацный
          // интерлиньяж 22/16 там ничего не выравнивает, а только
          // прибавляет контролу высоты. Измерено: с ним кнопка
          // перерастала 48 и переполняла строку действий в диалоге.
          textStyle: AppTypography.bodyStrong.copyWith(height: 1),
        ),
      ),

      // Поле ввода — строка списка, а не прямоугольник в рамке. Границу задаёт
      // секция; рамка вокруг каждого поля внутри неё давала два прямоугольника
      // там, где нужен один, и была половиной ощущения «дёшево».
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        hintStyle: AppTypography.body.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: AppTypography.body.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: AppTypography.label.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        errorStyle: AppTypography.label.copyWith(color: scheme.error),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: sectionShape,
      ),

      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppTokens.space12,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
        ),
        titleTextStyle: AppTypography.body.copyWith(color: scheme.onSurface),
        subtitleTextStyle: AppTypography.label.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        iconColor: scheme.onSurfaceVariant,
      ),

      switchTheme: SwitchThemeData(
        // Бегунок белый в ОБЕИХ темах, и берётся он из палитры, а не из
        // `scheme.onPrimary`. Раньше стоял onPrimary — в светлой теме это тот
        // же белый, и подмена не была видна; в тёмной onPrimary стал тёмным
        // (текст на светлом синем), и бегунок вместе с ним превратился бы в
        // чёрную точку на зелёной дорожке. Роль «текст на акценте» и роль
        // «бегунок переключателя» совпали случайно, а не по смыслу.
        thumbColor: const WidgetStatePropertyAll(AppColors.tgSheet),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? semantic.success
              : semantic.hairline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // Толщина нулевая намеренно: настоящая берётся из
      // AppTokens.hairlineOf(context), потому что зависит от плотности экрана,
      // а тема плотности не знает и не должна её угадывать.
      dividerTheme: DividerThemeData(
        color: semantic.hairline,
        space: 0,
        thickness: 0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: sectionShape,
        titleTextStyle: AppTypography.title.copyWith(color: scheme.onSurface),
        contentTextStyle: AppTypography.body.copyWith(color: scheme.onSurface),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: semantic.hairline,
        circularTrackColor: semantic.hairline,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: semantic.canvas,
        selectedColor: scheme.primary,
        side: BorderSide.none,
        labelStyle: AppTypography.label.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: AppTypography.label.copyWith(
          color: scheme.onPrimary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space12,
          vertical: AppTokens.space8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.onSurface,
        contentTextStyle: AppTypography.body.copyWith(color: scheme.surface),
        elevation: 0,
        shape: controlShape,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusSection),
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: onFill,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),

      dataTableTheme: DataTableThemeData(
        headingTextStyle: AppTypography.label.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        dataTextStyle: AppTypography.body.copyWith(color: scheme.onSurface),
        headingRowColor: WidgetStatePropertyAll(semantic.canvas),
        dividerThickness: 0,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: onFill,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: semantic.hairline,
        labelStyle: AppTypography.bodyStrong,
        unselectedLabelStyle: AppTypography.body,
      ),

      // Подпись под иконкой в боковом рельсе — своя роль, и она компактнее
      // label. Без этого рельс переполняется: с `labelType: all` подпись есть
      // у каждого пункта, а явный интерлиньяж прибавляет к каждой по паре
      // пикселей — измерено, 8 пикселей переполнения на восьми пунктах.
      //
      // Правка здесь, а не в adaptive_scaffold: высота подписи — это стиль, и
      // жить он обязан в теме.
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: semantic.canvas,
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 24,
        ),
        selectedLabelTextStyle: AppTypography.label.copyWith(
          fontSize: 11,
          height: 1.1,
          color: scheme.primary,
        ),
        unselectedLabelTextStyle: AppTypography.label.copyWith(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: semantic.canvas,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.label.copyWith(fontSize: 11, height: 1.1),
        ),
      ),

      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
    );
  }
}

/// Именованные стили, на которые ссылается остальное приложение.
///
/// Остаются ради сотни мест использования, но перестают быть вторым
/// источником стиля: каждый производен от [AppTypography], и правка там
/// доходит сюда сама.
///
/// **Цвета здесь нет ни в одном стиле, и это главное свойство класса.**
///
/// До 2026-08-04 каждый стиль запекал `color: AppColors.textPrimary` — цвет
/// светлой темы, константу. Пока тёмной темы не существовало, разницы не было
/// видно; с её подключением все 559 обращений в 87 файлах стали красить текст
/// дневными чернилами #111114 по ночной секции #2C2C2C. Это **1.17:1** при
/// пороге AA 4.5:1 — не «плохо читается», а не видно вовсе.
///
/// Стиль без цвета берёт его из `DefaultTextStyle`, а тот — из
/// `textTheme.bodyMedium`, куда `ThemeData` подставляет `colorScheme.onSurface`.
/// Измерено пробой: светлая отдаёт #111114, тёмная #FFFFFF. То есть роль
/// «основной текст» тема разрешает сама, и запекать её было не нужно ни дня.
///
/// Стили, у которых цвет **несёт смысл** (приглушённость), сюда не входят: они
/// живут в [AppTextStylesOf] и требуют контекста, см. `context.styles`.
class AppTextStyles {
  AppTextStyles._();

  // h1 и h2 больше не крупнее title, и это не упущение.
  //
  // Они выводились из роли `display`, которой не стало 2026-08-04: заголовков
  // крупнее двадцати в приложении не остаётся. Имена сохранены, чтобы не
  // переписывать сорок экранов разом, но обе роли теперь различаются весом и
  // цветом, а не кеглем.
  static final TextStyle h1 = AppTypography.title;
  static final TextStyle h2 = AppTypography.title.copyWith(
    fontWeight: FontWeight.w400,
  );
  static final TextStyle h3 = AppTypography.title.copyWith(
    fontSize: 18,
    height: 24 / 18,
  );

  static final TextStyle body = AppTypography.body.copyWith(
    fontSize: 14,
    height: 20 / 14,
  );
  static final TextStyle button = AppTypography.bodyStrong.copyWith(
    fontSize: 14,
    height: 20 / 14,
  );

  static final TextStyle tableCell = AppTypography.body.copyWith(
    fontSize: 14,
    height: 20 / 14,
  );

  static final TextStyle priceTotal = AppTypography.money.copyWith(
    fontSize: 32,
    height: 38 / 32,
  );
  static final TextStyle priceItem = AppTypography.money.copyWith(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w500,
  );

  static final TextStyle productName = AppTypography.bodyStrong;

  static final TextStyle actionButton = AppTypography.bodyStrong;
  static final TextStyle numpadButton = AppTypography.money.copyWith(
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w500,
  );
  static final TextStyle tabLabel = AppTypography.bodyStrong.copyWith(
    fontSize: 14,
    height: 20 / 14,
  );
}

/// Стили, у которых цвет — часть смысла, а не оформления.
///
/// «Приглушённый» — это роль, а не цвет: в светлой теме #707579, в тёмной
/// #AAAAAA. Статическая константа роль выразить не может, поэтому эти четыре
/// стиля вынесены из [AppTextStyles] и требуют контекста.
///
/// Вынос, а не «оставить без цвета»: стиль без цвета получил бы `onSurface`,
/// то есть подпись стала бы неотличима от основного текста — регресс тихий,
/// заметный только глазом и только тому, кто открыл нужный экран. Компилятор
/// такого не пропускает: `AppTextStyles.caption` больше нет, и место, забывшее
/// про тему, не соберётся.
@immutable
class AppTextStylesOf {
  const AppTextStylesOf._(this._muted);

  /// `colorScheme.onSurfaceVariant` — роль «вторичный текст».
  final Color _muted;

  /// Подпись, подсказка, пояснение под строкой.
  TextStyle get caption => AppTypography.label.copyWith(
    fontSize: 12,
    height: 16 / 12,
    color: _muted,
  );

  /// Заголовок колонки таблицы.
  TextStyle get tableHeader => AppTypography.label.copyWith(
    fontSize: 12,
    height: 16 / 12,
    color: _muted,
  );

  /// Количество рядом с названием товара.
  TextStyle get productQuantity =>
      AppTypography.body.copyWith(fontSize: 14, height: 20 / 14, color: _muted);

  /// Штрихкод под названием товара.
  TextStyle get barcode =>
      AppTypography.mono.copyWith(fontSize: 12, height: 16 / 12, color: _muted);
}

/// Короткий доступ: `context.styles.caption`.
extension AppTextStylesContext on BuildContext {
  AppTextStylesOf get styles =>
      AppTextStylesOf._(Theme.of(this).colorScheme.onSurfaceVariant);
}

/// Заливка выбранной строки или карточки.
///
/// Заведена, потому что константы для этого не годятся, и это измерено, а не
/// предположено. Экран входа красил выбранного кассира в
/// `AppColors.primaryLighter` (#EAF3FD) — светло-голубую плашку, одинаковую в
/// обеих темах, — а подпись брал из темы. В светлой это давало 16.82:1, в
/// тёмной подпись становится белой и получается **1.12:1**: белым по
/// светло-голубому. Имя выбранного кассира не читалось вовсе, и заметить это
/// можно было только глазами на тёмной теме — набор такого не видит, потому
/// что константа сама по себе верна, неверно её сочетание с темой.
///
/// Тон, а не константа: `primary` у тем разный (#3390EC против #6AB3F3), и
/// та же доля поверх той же поверхности даёт в светлой ту же плашку, что была
/// (#E7F2FD против #EAF3FD — глазом не отличить, 16.62:1), а в тёмной —
/// синеватую тёмную (#333C44, 11.23:1).
///
/// 0.12 — доля Material для «выбранного» состояния
/// (`WidgetStateProperty` в `ButtonStyle`, `selectedTileColor` у `ListTile`
/// считаются от неё же), а не подобранное на глаз число.
Color selectedSurfaceOf(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Color.alphaBlend(
    scheme.primary.withValues(alpha: 0.12),
    scheme.surface,
  );
}
