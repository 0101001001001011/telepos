"""Generates the TelePOS icon set: FLUX -> ComfyUI matte -> vector -> icon font.

Why a font and not PNGs. An icon lives at 20-24 logical pixels, where per-pixel
crispness is the whole game. A raster downsampled from a 1024-pixel generation
is soft at exactly the size it is looked at, and softness at 24 px is the most
legible signal of "cheap" an interface has. A font is what Material Icons are:
outlines, crisp at any size and any DPI, tinted by the theme rather than baked.

Stages, each inspectable on disk:
  1. generate/   1024x1024 from FLUX on the local ComfyUI
  2. mask/       the black-and-white matte, cut in ComfyUI, not here
  3. svg/        traced outlines
  4. font/       one TTF, one codepoint per icon

Usage:
    python tools/icon_pipeline.py generate            # stage 1 (+2)
    python tools/icon_pipeline.py sheet               # look at 20/24/48 px
    python tools/icon_pipeline.py trace               # stage 3
    python tools/icon_pipeline.py font                # stage 4
    python tools/icon_pipeline.py all
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
import time
import urllib.parse
import urllib.request

# Python printing Cyrillic into a cp1252 console dies AFTER the files are
# already written, which reads as a failure and is not one.
sys.stdout.reconfigure(encoding="utf-8")

HOST = "192.168.1.205:8188"
OUT = pathlib.Path("build/icons")

# ---------------------------------------------------------------------------
# Подсказка. Всё, что здесь написано, стоило измеренных попыток — см. историю
# ниже, она объясняет ПОЧЕМУ формулировки именно такие.
#
# 1. НАЗВАНИЕ ПРЕДМЕТА НЕ ПИШЕТСЯ ВООБЩЕ. Слово «чек» включает у FLUX
#    фотографический навык, и он рисует фотографию бумажки с печатью — какими
#    бы словами про «плоско» и «двухцветно» её ни обкладывали. Пять попыток
#    ушло на борьбу со словом, шестая победила его отсутствием: иконка
#    описывается ТОЛЬКО геометрией — прямоугольник, диск, полоса, кольцо.
# 2. ВНУТРЕННЯЯ ДЕТАЛЬ ОБЯЗАНА БЫТЬ НАЗВАНА ВНУТРЕННЕЙ. «Три белые полосы
#    поперёк» разрезали фигуру на три отдельных куска. Нужно «полоса короче
#    ширины фигуры и плавает внутри, слева и справа остаётся чёрное поле».
# 3. ЧИСЛО — ЭТО НИЖНЯЯ ГРАНИЦА, А НЕ ЦЕЛЬ. «Шесть строк» дали одиннадцать.
#    Проси меньше, чем хочешь, и крупнее, чем кажется нужным.
#    ИЗМЕРЕНО ЗАНОВО 2026-08-27, и это правило дороже остальных: описания
#    волны 1 просили детали «заметно короче радиуса», то есть МЕЛКИЕ, — и
#    четыре иконки из четырёх вышли сплошными пятнами, деталь не прорезалась
#    вовсе. Та же иконка с «полоса шириной в пятую часть диска» прорезалась с
#    первого раза и читается на 20 px. Толщина внутренней детали — не вкус, а
#    условие того, что она вообще появится.
# 5. НАПРАВЛЕНИЕ НАДО ЗАПРЕЩАТЬ, А НЕ ТОЛЬКО ЗАДАВАТЬ. «Полоса от центра
#    вверх» дала полосу через ВЕСЬ диск: модель дорисовала зеркальную половину
#    сама. Нужна отдельная фраза «ниже центра только чёрное».
# 6. ОДНА ИКОНКА ЗА ЗАХОД (`--only <имя>`). Волна 1 гналась пачкой в 23 и
#    показала ошибку описаний только на контактном листе, когда GPU уже отработал
#    четыре иконки впустую. По одной ошибка видна на первой.
# 7. ВЫРЕЗ ОПИСЫВАЕТСЯ ОДНОЙ СВЯЗНОЙ ФИГУРОЙ, А НЕ СПИСКОМ ЧАСТЕЙ. «Полоса
#    вверх и полоса вправо» дали то полосу через весь диск, то мусор: модель
#    собирает части как умеет. «Одна белая Г-образная выемка: длинный рукав
#    вверх, короткий вправо, соединённые под прямым углом» — вышло с первого
#    раза и читается на 20 px. Измерено на `shift`, три захода.
# 11. ТОНКИЙ ДИАГОНАЛЬНЫЙ ОТРОСТОК НЕ ПРИСТАВЛЯЕТСЯ. Два предмета из волны 2
#    отпали по одной причине: ручка лупы к кольцу (`search`, два захода) и
#    остриё карандаша к стволу (`edit`, три захода). Модель рисует главную
#    фигуру и на этом останавливается — так же, как не сделала наконечники у
#    `sync`. Приём «ствол плюс наконечник», которым взялась стрелка `refund`,
#    здесь не спасает: у стрелки оба конца толстые, а у лупы и карандаша
#    отросток тоньше основной фигуры. Такие предметы остаются на Material —
#    это дешевле трёх заходов, и спека такую границу предусматривает.
# 10. НАКЛОН ЗАДАЁТСЯ КОНЦАМИ, А НЕ СЛОВОМ «НАИСКОСЬ». «Две полосы, крестом
#    посередине наискось» дали ПРЯМОЙ крест у всех трёх вариантов — и он вдобавок
#    совпал с `add`. «Первая от верхнего левого угла кадра к нижнему правому,
#    вторая от верхнего правого к нижнему левому» — косой крест с первого раза,
#    тоже у всех трёх. Углы кадра модель понимает, наречия — нет.
# 9. ТРЕУГОЛЬНИК СМОТРИТ ВВЕРХ, И ПЕРЕСПОРИТЬ ЭТО НЕ УДАЛОСЬ. Два захода на
#    `history`: «два треугольника, оба смотрят влево» и, следом, описание
#    геометрией без слова о направлении — «прямая сторона справа, острый угол
#    слева». Оба раза вышли треугольники ОСТРИЁМ ВВЕРХ, шесть вариантов из
#    шести. При этом стрелка со стволом (`refund`) влево вышла с первого раза.
#    Вывод: направление держится, когда у фигуры есть ствол, и не держится у
#    одинокого треугольника. Нужен либо ствол, либо фигура без направления.
# 8. ОТРИЦАНИЕ НЕ РАБОТАЕТ, А ВРЕДИТ. Попытка запретить зеркало словами «ниже
#    центра только чёрное» убила деталь у двух вариантов из трёх: на «только
#    чёрное» модель отвечает заливкой. Форму задаёт описание фигуры, а не
#    запрет того, чего быть не должно.
# 4. СЛОВО «ТЕКСТ» ЗАСТАВЛЯЕТ ПИСАТЬ ТЕКСТ. На одной из попыток на чеке
#    оказался читаемый абзац прозы. Только «полоса», «брусок», «щель».
# ---------------------------------------------------------------------------

STYLE = (
    "flat two-tone graphic, pure black on a pure white background, no other "
    "tone, no shading, no shadow, seen straight on, centred with a generous "
    "margin"
)

# Отрицательная подсказка НЕ РАБОТАЕТ и оставлена пустой намеренно.
# flux-dev семплится на cfg = 1.0, а в формуле guidance при cfg = 1 негатив
# сокращается тождественно. Всё, что было написано в прежнем NEGATIVE —
# «no gradient, no grey, no shadow» — не влияло ни на один пиксель. Поэтому
# все ограничения переехали в положительную подсказку как утверждения.
NEGATIVE = ""

# Порог чернил: светлее 25 % серого — это уже не чернила.
#
# Не произвол. FLUX рисует внутреннюю деталь СРЕДНЕ-СЕРОЙ (замерено: медиана
# промежуточных пикселей 0.50-0.58), а само тело фигуры — почти чёрным (0.00
# -0.15). Прежний порог 0.5 попадал ровно в середину серого, и одна и та же
# подсказка на трёх зёрнах давала то иконку с прорезями, то сплошное пятно —
# орлянка. Порог 0.25 разводит эти две моды с запасом в обе стороны.
#
# Ставится он в ComfyUI (узел ThresholdMask), а не здесь: заказчик просил
# снимать фон на сервере. Побочная выгода — картинка, нарисованная целиком
# серой, даёт пустую маску, то есть отказывается молча притвориться иконкой.
INK = 0.75  # порог по маске «чернил» = 1 − 0.25 яркости

# Мастер настройки говорит этими словами. Ничего декоративного: каждая иконка
# называет то, о чём человека спрашивают. Описания — геометрия, см. выше.
ICONS: dict[str, str] = {
    # ── Волна 1: левая колонка ──────────────────────────────────────────────
    #
    # Двадцать три глифа на двадцать четыре назначения: `warehouse` берут два
    # (`/wms` и `/stock-registry`), и это одно понятие, а не два похожих.
    #
    # Пара «контур/заливка» НЕ рисуется, и это решение, а не экономия.
    # `TgNavRow` уже красит выбранную строку синей плашкой
    # (`context.semantic.accentFill`) — ровно как левая колонка Telegram
    # Desktop. Заливка иконки поверх плашки означала бы два признака выбора
    # разом, а контур — вдвое больше глифов и вдвое больше риска: тонкая
    # линия трассируется хуже сплошной заливки.
    #
    # Описания подчиняются правилам вверху файла: предмет не назван ни разу,
    # внутренняя деталь названа внутренней, число — нижняя граница.

    # /sale
    "sale": (
        "a solid black shape: a wide trapezoid, wider at the top than at the "
        "bottom, standing above two small black discs set apart from each "
        "other, and a short straight bar rising from the trapezoid's upper "
        "left corner and bending to the left"
    ),
    # /refund
    "refund": (
        "a solid black square with rounded corners. one wide white arrow is "
        "cut out of it as a single connected shape: a straight shaft lying "
        "across the middle from right to left, ending on the left in a "
        "triangular head that is wider than the shaft. the arrow is about one "
        "fifth as tall as the square and a broad black band surrounds it on "
        "every side"
    ),
    # /shift
    "shift": (
        "a solid black disc with one wide white L-shaped notch cut out of "
        "it. the notch is one connected white shape: a long arm rising from "
        "the middle of the disc towards the top, and a shorter arm reaching "
        "from the middle towards the right side, joined at a right angle in "
        "the middle. the notch is about one fifth as wide as the disc and a "
        "broad black band surrounds it on every side"
    ),
    # /history
    "history": (
        "a solid black disc with one wide white wedge cut out of it, like a "
        "single slice taken away. the wedge starts at the exact centre and "
        "opens towards the upper right, reaching the rim. the rest of the "
        "disc stays solid black"
    ),
    # /tables
    "tables": (
        "a solid black shape: one wide flat slab lying horizontally, and "
        "beneath it two short straight legs dropping down, one near each end, "
        "with white between the legs"
    ),
    # /orders
    "orders": (
        "a black rectangle standing upright whose bottom edge is cut into "
        "three shallow triangular teeth. punched out of it in white are two "
        "short horizontal bars, one above the other, each much shorter than "
        "the rectangle is wide and floating clear of the left and right edges"
    ),
    # /service-queue
    "serviceQueue": (
        "three thick solid black bars lying horizontally, one above another, "
        "separated by white gaps. each bar is about one fifth as tall as the "
        "whole picture, so every bar is chunky rather than thin. the top bar "
        "is the shortest and the bottom bar is the longest"
    ),
    # /service-intake
    "serviceIntake": (
        "a black rectangle standing upright with rounded corners, and one "
        "small black tab sitting centred on its top edge. one thick white "
        "check mark is cut out of the middle of the rectangle as a single "
        "connected shape: a short arm going down to the right and a longer "
        "arm rising from it. the check mark is about one fifth as wide as "
        "the rectangle and black remains all around it"
    ),
    # /wms и /stock-registry
    "warehouse": (
        "a solid black shape: a wide low rectangle with a flat top, and above "
        "it a broad shallow triangle spanning the whole width. punched out of "
        "the rectangle in white are two small squares side by side, floating "
        "clear of every edge"
    ),
    # /wms-warehouses
    "warehouses": (
        "two solid black rectangles standing side by side on flat ground, the "
        "left one lower and narrower than the right, separated by a thin "
        "white gap. punched out of each rectangle in white are two small "
        "squares, floating clear of the edges"
    ),
    # /wms-batches
    "batches": (
        "three solid black diamonds of the same width, stacked one above "
        "another with thin white gaps between them"
    ),
    # /wms-serials
    "serials": (
        "a solid black square. one large white square is cut out of its "
        "upper left part, and inside that white square sits one smaller "
        "solid black square, so the shape reads as a square ring around a "
        "black core. the white square is about one third as wide as the "
        "whole shape, and the rest of the picture stays solid black"
    ),
    # /wms-cell-stock
    "cellStock": (
        "four solid black squares of equal size arranged in two rows of two, "
        "separated by thin white gaps"
    ),
    # /wms-claims
    "claims": (
        "a solid black triangle standing on its flat base with rounded "
        "corners. punched out of it in white is one straight upright bar in "
        "the middle and, below the bar, one separate round dot. both float "
        "clear of every edge"
    ),
    # /wms-marking
    "marking": (
        "four thick black L-shaped corner pieces, one in each corner of the "
        "picture. each corner piece is about one third as long as the side "
        "of the picture and as chunky as a finger, so none of them is thin. "
        "a wide white cross-shaped gap separates them, leaving the middle of "
        "every side and the centre white"
    ),
    # /wms-settings
    "wmsSettings": (
        "three thick solid black bars lying horizontally, one above another, "
        "separated by white gaps. each bar is about one fifth as tall as the "
        "whole picture, so every bar is chunky rather than thin. on each bar "
        "sits one solid black disc that is clearly taller than the bar is "
        "thick, and each disc sits at a different place along its own bar"
    ),
    # /agent — описание взято из прежнего набора, оно себя показало
    "agent": (
        "two solid black shapes standing side by side, almost touching. each "
        "shape is a small circle sitting above a wide dome. the left shape is "
        "a little smaller and set a little lower than the right one. a thin "
        "white gap separates the two shapes"
    ),
    # /supply
    "supply": (
        "one wide solid black tray at the bottom, shaped like a shallow "
        "open box. above it floats one thick black arrow made of a straight "
        "upright shaft with a wide triangular head at its lower end, so the "
        "arrow narrows downward towards the tray. a white gap separates the "
        "arrow from the tray"
    ),
    # /cash-operation
    "cashOperation": (
        "a solid black rectangle with rounded corners, wider than it is "
        "tall. one large white circle is cut out of it near the right side. "
        "the circle is about one third as tall as the rectangle, and a broad "
        "black band remains all around it"
    ),
    # /settings
    "settings": (
        "a solid black disc with six broad blunt teeth spaced evenly around "
        "its rim. punched out of its centre in white is one round hole, well "
        "clear of the teeth"
    ),
    # /catalog
    "catalog": (
        "two solid black rectangles standing side by side like the two "
        "halves of an open book, each one taller than it is wide, separated "
        "by a wide white gap running from top to bottom between them. the "
        "gap is about one fifth as wide as the whole picture"
    ),
    # /reports
    "reports": (
        "three solid black bars standing upright on one common flat baseline, "
        "separated by thin white gaps. the left bar is the shortest, the "
        "middle bar is the tallest"
    ),
    # /sync
    "sync": (
        "a thick black ring broken by two white gaps on opposite sides. at "
        "each break one end of the ring widens into a small triangle pointing "
        "along the ring"
    ),

    # ── Волна 2: действия ───────────────────────────────────────────────────
    #
    # Тринадцать форм на 380 обращений из 1512 (25 %). Отбор — по частоте
    # (`git grep -oE "Icons\\.[a-z_0-9]+" lib/presentation`), но не слепо:
    # часть частых уже закрыта волной 1 и новой формы не требует —
    # `sync`/`refresh` одно кольцо, `receipt_long` (28 обращений) это `orders`,
    # `inventory_2` это `warehouse`, `assignment_return` это `refund`.
    #
    # Все описания написаны сразу по правилам 3, 7, 8, 9: толщина названа
    # долей, вырез — одной связной фигурой, отрицаний нет, направление задано
    # стволом, а не словом.

    "add": (
        "one thick solid black plus sign standing alone on white: a wide "
        "upright bar crossed by a wide horizontal bar of the same width, "
        "joined in the middle as one connected shape. each bar is about one "
        "fifth as wide as the whole picture"
    ),
    "close": (
        "one thick solid black X standing alone on white. it is made of two "
        "wide bars: the first runs from the top left corner of the picture "
        "down to the bottom right corner, the second runs from the top right "
        "corner down to the bottom left corner. they cross in the middle and "
        "form one connected shape. each bar is about one fifth as wide as "
        "the whole picture"
    ),
    # search НЕ РИСУЕТСЯ, и это предел конвейера, а не описания.
    #
    # Два захода, шесть вариантов из шести: кольцо выходит чистым, а ручка к
    # нему не пристаёт — ни «полоса от нижнего правого края кольца вниз», ни
    # та же полоса, привязанная к углу кадра (приём, которым взялся косой
    # крест в `close`). Модель рисует кольцо и на этом останавливается; тот же
    # отказ, что у наконечников `sync`.
    #
    # Лупа — символ, которому замены нет: любая другая геометрия читалась бы
    # хуже Material. Поэтому здесь Material и остаётся. Это ровно та граница,
    # которую спека называет промежуточным состоянием: `TeleposIcons` для
    # нарисованного, `Icons.*` для остального.
    # chevronRight НЕ РИСУЕТСЯ — третий предмет того же класса, см. правило 11.
    # Один заход дал букву «P», зигзаг и сплошной треугольник остриём влево.
    # Галочка-стрелка это две диагонали, сходящиеся в точку, и модель их не
    # держит так же, как не держала ручку лупы и остриё карандаша.
    "checkCircle": (
        "a solid black disc with one thick white check mark cut out of its "
        "middle as a single connected shape: a short arm going down to the "
        "right and a longer arm rising from it. the check mark is about one "
        "fifth as wide as the disc and a broad black band surrounds it"
    ),
    "info": (
        "a solid black disc. two separate white shapes are cut out of it: "
        "near the top one small round dot, and below the dot one wide "
        "upright bar that is about three times as tall as the dot is wide. "
        "the bar is about one fifth as wide as the disc. a narrow black gap "
        "separates the dot from the bar, and black surrounds both"
    ),
    "check": (
        "one thick solid black check mark standing alone on white as a "
        "single connected shape: a short arm going down to the right and a "
        "longer arm rising from it. the mark is about one fifth as wide as "
        "the whole picture"
    ),
    "error": (
        "a solid black disc. cut out of its middle in white as two separate "
        "shapes: one wide upright bar in the upper part, and below it one "
        "round dot. both are about one fifth as wide as the disc and black "
        "remains all around them"
    ),
    "delete": (
        "one solid black container shaped like a bucket that narrows towards "
        "the bottom, with one wide black bar lying across above it like a "
        "lid, and a narrow white gap between the lid and the bucket. cut out "
        "of the bucket in white are two upright slots, each about one fifth "
        "as wide as the bucket"
    ),
    "save": (
        "a solid black square with rounded corners. cut out of its lower "
        "half in white is one wide rectangle that touches neither side, and "
        "cut out of its upper half is one narrower white rectangle. both "
        "float clear of the edges and of each other"
    ),
    # edit НЕ РИСУЕТСЯ — тот же предел, что у `search`, см. правило 11.
    #
    # Три захода: «полоса наискось с острым концом» дала тонкий штрих,
    # «от угла к углу, вчетверо толще» — горизонтальные обрубки, «ствол плюс
    # наконечник» (приём, которым взялась стрелка `refund`) — снова тонкий
    # штрих. Карандаш остаётся Material.
    "lock": (
        "a solid black rectangle with rounded corners in the lower half, "
        "and above it one thick black arch that rises from the top of the "
        "rectangle and comes back down to it, leaving white inside the arch. "
        "the arch is narrower than the rectangle and about one fifth as "
        "thick as the whole picture"
    ),
    "person": (
        "one solid black shape standing alone: a circle sitting above a wide "
        "dome, with a narrow white gap between them. the dome is about twice "
        "as wide as the circle"
    ),
}

# Какой вариант из сгенерированных пошёл в шрифт. Записано здесь, а не забыто
# в аргументах командной строки: без этого пересборка шрифта из тех же файлов
# даёт другой набор глифов, и «воспроизводимый конвейер» становится словами.
#
# Выбрано глазами по `build/icons/sheet.png` — контактному листу на 20/24/48
PICKS: dict[str, int] = {
    # Заполняется глазами по `build/icons/sheet.png` — контактному листу на
    # 20/24/48 px. Смотреть надо на 20: иконка, приемлемая в полный размер,
    # на рабочем бывает бесформенным пятном. Ноль значит «вариант не
    # выбирали», а не «первый хорош».
    "sale": 1,  # тележка с ручкой и колёсами; #0 и #2 бесформенны
    "refund": 1,  # стрелка влево; #0 и #2 смотрят вправо — обратный смысл
    "shift": 0,  # чёткая «Г» из стрелок, читается на 20 px
    # Геометрия сменена 2026-08-28 дважды. Часы остались у `shift`: две
    # иконки-часы в одной колонке на 20 px неразличимы. Стрелки влево
    # отпали по правилу 9 — треугольник упрямо смотрит вверх. Диск с
    # вырезанным сектором направления не имеет вовсе и вышел с первого раза.
    "history": 1,  # чистый вырез; #0 почти пуст, у #2 сектор съел половину
    "tables": 0,  # ножки видны на 20 px; у #1 истончаются, у #2 сливаются
    "orders": 2,  # строки читаются на 20 px; #0 и #1 там сплошное пятно
    "serviceQueue": 2,  # ровные края; у #0 и #1 полосы рваные
    "serviceIntake": 2,  # с язычком и жирной галкой; #1 тонок и пропадает
    "warehouse": 1,  # просветы видны на 20 px; крыша не прорезалась ни у кого
    "warehouses": 1,  # пара блоков чиста; окна не прорезались — снова мелки
    "batches": 2,  # ромбы крупнее всех; у #0 они тают на 20 px
    "serials": 0,  # кольцо с ядром; у #1 ядро — точка, #2 сплошной
    "cellStock": 0,  # квадраты крупнее всех; все три чисты, выбран по размеру
    "claims": 2,  # знак прорезался целиком; у #0 и #1 деталь мельчает
    "marking": 1,  # уголки сканера чисты; #0 и #2 закруглены в лепестки
    "wmsSettings": 2,  # полосы с ползунками; у #1 полосы пропали, остались точки
    "agent": 2,  # две фигуры различимы на 20 px; у #0 и #1 слиплись в холм
    "supply": 2,  # стрелка жирнее всех, на 20 px не тает; направление держит ствол
    "cashOperation": 0,  # кружок целиком внутри; у #1 и #2 он вырезан из края
    "settings": 2,  # отверстие видно на 20 px; у #0 центр залит, #1 рваный
    "catalog": 1,  # ровные половины и чёткий просвет; у #0 и #2 края рваные
    "reports": 0,  # высоты разные, читается графиком; у #2 все равны
    "sync": 0,  # кольцо толще всех; наконечники не сформировались ни у кого

    # ── Волна 2 ──
    "add": 0,  # плотный, руки ровные; #1 тоньше и на 20 px слабее
    "close": 0,  # плотнее прочих; косой крест дался только через углы кадра
    "checkCircle": 0,  # галка крупнее; у #2 диск в лишнем ореоле
    "info": 2,  # точка и ножка; у #1 вышли две ножки, у #0 слиплись
    "check": 1,  # жирная; #0 почти прозрачна, #2 тоньше
    "error": 0,  # знак крупнее; у #2 точка почти сливается с ножкой
    "delete": 0,  # крышка и прорези видны; у #2 нет ни того, ни другого
    "save": 1,  # видны и шторка, и наклейка; у #0 только вырез угла
    "lock": 0,  # дужка отделена; у #1 слилась с корпусом, у #2 нет корпуса
    "person": 1,  # голова отделена от плеч; у #2 они слиты
}


def workflow(subject: str, seed: int) -> dict:
    """FLUX -> матовка -> двухцветная маска. Одна очередь, два выхода.

    Фон снимается ЗДЕСЬ, на сервере, узлами `LoadBackgroundRemovalModel` +
    `RemoveBackground` (BiRefNet) — они входят в поставку ComfyUI 0.28, ставить
    ничего не пришлось. Подробности матовки — в `matte_graph`.
    """
    return {
        "1": {
            "class_type": "UNETLoader",
            "inputs": {
                "unet_name": "flux1-dev-fp8.safetensors",
                "weight_dtype": "fp8_e4m3fn",
            },
        },
        "2": {
            "class_type": "DualCLIPLoader",
            "inputs": {
                "clip_name1": "t5xxl_fp16.safetensors",
                "clip_name2": "clip_l.safetensors",
                "type": "flux",
            },
        },
        "3": {
            "class_type": "VAELoader",
            "inputs": {"vae_name": "flux1-dev-ae.safetensors"},
        },
        "4": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["2", 0], "text": f"{subject}. {STYLE}"},
        },
        "5": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["2", 0], "text": NEGATIVE},
        },
        "6": {
            "class_type": "FluxGuidance",
            "inputs": {"conditioning": ["4", 0], "guidance": 3.5},
        },
        "7": {
            "class_type": "EmptySD3LatentImage",
            "inputs": {"width": 1024, "height": 1024, "batch_size": 1},
        },
        "8": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["1", 0],
                "positive": ["6", 0],
                "negative": ["5", 0],
                "latent_image": ["7", 0],
                "seed": seed,
                "steps": 24,
                # flux-dev берёт силу из FluxGuidance, поэтому cfg = 1.
                # Ценой этого негатив не действует — см. NEGATIVE.
                "cfg": 1.0,
                "sampler_name": "euler",
                "scheduler": "simple",
                "denoise": 1.0,
            },
        },
        "9": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["8", 0], "vae": ["3", 0]},
        },
        # Оригинал сохраняется тоже: когда маска пуста, посмотреть надо на то,
        # что нарисовалось, а не гадать.
        "10": {
            "class_type": "SaveImage",
            "inputs": {"images": ["9", 0], "filename_prefix": "telepos_icon"},
        },
        **matte_graph("9"),
    }


def matte_graph(image_node: str) -> dict:
    """Узлы, вырезающие двухцветную маску из готовой картинки.

    Вынесены отдельно, потому что применяются дважды: сразу после генерации и
    заново поверх уже сохранённых картинок (стадия `rematte`). Правка матовки
    не должна стоить ещё одного часа на видеокарте.

    BiRefNet спрашивается ДВАЖДЫ — о картинке и о её инверсии, — а ответы
    складываются. Причина измерена, а не выдумана.

    BiRefNet выбирает предмет по заметности, а не по тону, и на плоской
    двухцветной графике полярность у него плавает. На иконке «чёрный диск с
    вырезанным белым вопросительным знаком» он объявил предметом ЗНАК, а диск
    — фоном: пересечение с чернилами дало ровно ноль, две иконки из шести
    пришли пустыми. Инверсия чинит эти две и ломает другую: замерено, доля
    чернил, накрытых матовкой,

        иконка      обычная  инверсия  объединение
        help_0         0.0%    100.0%      100.0%
        help_2       100.0%    100.0%      100.0%
        country_0     91.4%     28.5%       92.1%

    Ни одна полярность не годится сама по себе. Объединение годится, и не по
    везению: оно МОНОТОННО — может только добавить площади предмета, но не
    отнять. Чтобы матовка снова съела фигуру, ошибиться должны обе полярности
    сразу. Логическое «или» здесь не годится (оно двоичит по `> 0`, а мягкая
    матовка почти везде чуть больше нуля); складываем с насыщением.
    """
    return {
        "11": {
            "class_type": "LoadBackgroundRemovalModel",
            "inputs": {"bg_removal_name": "birefnet.safetensors"},
        },
        "19": {"class_type": "ImageInvert", "inputs": {"image": [image_node, 0]}},
        "12": {
            "class_type": "RemoveBackground",
            "inputs": {"bg_removal_model": ["11", 0], "image": [image_node, 0]},
        },
        "20": {
            "class_type": "RemoveBackground",
            "inputs": {"bg_removal_model": ["11", 0], "image": ["19", 0]},
        },
        "21": {
            "class_type": "MaskComposite",
            "inputs": {
                "destination": ["12", 0],
                "source": ["20", 0],
                "x": 0,
                "y": 0,
                "operation": "add",
            },
        },
        "13": {
            "class_type": "ImageToMask",
            "inputs": {"image": [image_node, 0], "channel": "red"},
        },
        "14": {"class_type": "InvertMask", "inputs": {"mask": ["13", 0]}},
        # Пересечение, а не замена. BiRefNet отдаёт СИЛУЭТ предмета целиком и
        # залил бы внутренние прорези, без которых иконка — пятно. Умножение
        # оставляет только тёмное внутри предмета, то есть настоящие чернила.
        "15": {
            "class_type": "MaskComposite",
            "inputs": {
                "destination": ["14", 0],
                "source": ["21", 0],
                "x": 0,
                "y": 0,
                "operation": "multiply",
            },
        },
        "16": {
            "class_type": "ThresholdMask",
            "inputs": {"mask": ["15", 0], "value": INK},
        },
        "17": {"class_type": "MaskToImage", "inputs": {"mask": ["16", 0]}},
        "18": {
            "class_type": "SaveImage",
            "inputs": {"images": ["17", 0], "filename_prefix": "telepos_mask"},
        },
    }


def upload(path: pathlib.Path) -> str:
    """Кладёт картинку во входные ComfyUI, чтобы её мог взять LoadImage."""
    import uuid

    boundary = uuid.uuid4().hex
    body = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="image"; '
        f'filename="{path.name}"\r\nContent-Type: image/png\r\n\r\n'
    ).encode()
    body += path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(
        f"http://{HOST}/upload/image",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.load(resp)["name"]


def rematte(names: list[str], variants: int) -> None:
    """Пересчитывает маски поверх уже сгенерированных картинок."""
    (OUT / "mask").mkdir(parents=True, exist_ok=True)
    for name in names:
        for variant in range(variants):
            src = OUT / "generate" / f"{name}_{variant}.png"
            if not src.exists():
                continue
            wf = {"1": {"class_type": "LoadImage", "inputs": {"image": upload(src)}}}
            wf.update(matte_graph("1"))
            outputs = wait(submit(wf))
            for image in outputs.get("18", {}).get("images", []):
                (OUT / "mask" / f"{name}_{variant}.png").write_bytes(fetch(image))
            print(f"  {name} #{variant}")


def _retrying(what: str, call, *, attempts: int = 12, pause: int = 15):
    """Повторяет сетевой вызов к ComfyUI, переживая обрыв связи.

    Обрыв — не отказ сервера, и это измерено 2026-08-27: три прогона подряд
    упали на `WinError 10060`, при этом `/system_stats` тем же curl отвечал
    сразу. Связь до машины моргает, генерация при этом идёт.

    Повтор заведён общим, а не по месту, и это вторая правка того же дня:
    первая закрыла только опрос истории — и следующий прогон упал на
    скачивании. Три вызова из трёх ходят по одной и той же сети, и чинить их
    порознь значит чинить трижды.

    # ДИАГНОЗ ИСПРАВЛЕН 2026-08-27, и прежний был неверен.
    #
    # Сначала это читалось как обрыв связи: `WinError 10060`, четыре прогона
    # подряд упали. Лечили повтором — не помогло, и правильно, что не
    # помогло. Измерение поставило диагноз заново: `curl` с ожиданием 90 с
    # получает `HTTP 200` за **9.9 секунды**, а TCP-соединение на порт
    # проходит мгновенно. То есть машина на месте и отвечает — она **занята
    # генерацией**, и HTTP ждёт своей очереди за GPU.
    #
    # Значит лечение — не «повторить», а «подождать». Таймауты подняты до
    # 180 с (опрос, отправка) и 300 с (скачивание кадра): при прежних 30 с
    # опрос успевал упасть раньше, чем сервер успевал ответить, и повтор
    # честно повторял то же самое падение.
    #
    # Повтор оставлен: он дешёв и закрывает настоящее моргание, если оно
    # когда-нибудь случится. Но он был лекарством не от той болезни.
    """
    last = None
    for attempt in range(1, attempts + 1):
        try:
            return call()
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last = error
            if attempt == attempts:
                break
            print(f"    {what}: связь моргнула ({attempt}/{attempts}), "
                  f"повтор через {pause} с")
            time.sleep(pause)
    raise RuntimeError(f"{what}: ComfyUI не отвечает {attempts} раз подряд: {last}")


def submit(wf: dict) -> str:
    body = json.dumps({"prompt": wf}).encode()
    req = urllib.request.Request(
        f"http://{HOST}/prompt",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    def once() -> str:
        with urllib.request.urlopen(req, timeout=180) as resp:
            return json.load(resp)["prompt_id"]

    return _retrying("отправка задания", once)


def wait(prompt_id: str, timeout: int = 900) -> dict:
    """Ждёт результата, переживая обрыв связи.

    Обрыв здесь — не отказ сервера, и это измерено 2026-08-27: два прогона
    подряд упали на `WinError 10060` посреди набора, при этом
    `/system_stats` тем же curl отвечал сразу. То есть связь моргает, а
    генерация идёт. Без повтора один моргнувший опрос выбрасывал прогон
    целиком — двадцать минут работы GPU и все уже нарисованные иконки
    сохранялись, но набор считался неудавшимся, и продолжать приходилось
    руками.

    Повтор именно здесь, а не вокруг всего прогона: задание уже принято
    сервером, `prompt_id` на руках, и опросить его можно снова. Повторять
    отправку было бы другим делом — она поставила бы в очередь второе
    задание.
    """
    deadline = time.time() + timeout

    def poll() -> dict:
        with urllib.request.urlopen(
            f"http://{HOST}/history/{prompt_id}", timeout=180
        ) as resp:
            return json.load(resp)

    while time.time() < deadline:
        history = _retrying("опрос истории", poll)
        if prompt_id in history:
            entry = history[prompt_id]
            if entry.get("status", {}).get("status_str") == "error":
                raise RuntimeError(json.dumps(entry["status"])[:2000])
            return entry["outputs"]
        time.sleep(3)
    raise TimeoutError(f"ComfyUI did not answer in {timeout}s")


def fetch(image: dict) -> bytes:
    query = urllib.parse.urlencode(
        {
            "filename": image["filename"],
            "subfolder": image.get("subfolder", ""),
            "type": image.get("type", "output"),
        }
    )
    def once() -> bytes:
        with urllib.request.urlopen(
            f"http://{HOST}/view?{query}", timeout=300
        ) as r:
            return r.read()

    return _retrying("скачивание кадра", once)


def generate(names: list[str], variants: int) -> None:
    (OUT / "generate").mkdir(parents=True, exist_ok=True)
    (OUT / "mask").mkdir(parents=True, exist_ok=True)
    for name in names:
        subject = ICONS[name]
        for variant in range(variants):
            # Выводится, а не случайно: отвергнутый вариант остаётся
            # воспроизводимым. hash() в Python солится от запуска к запуску,
            # поэтому зерно считается из самих букв.
            seed = (abs(hash_stable(f"{name}/{variant}"))) % (2**31)
            outputs = wait(submit(workflow(subject, seed)))
            for node, folder in (("10", "generate"), ("18", "mask")):
                for image in outputs.get(node, {}).get("images", []):
                    path = OUT / folder / f"{name}_{variant}.png"
                    path.write_bytes(fetch(image))
            print(f"  {name} #{variant} seed={seed}")


def hash_stable(text: str) -> int:
    """Стабильное между запусками зерно. `hash()` для этого не годится: он
    солится PYTHONHASHSEED, и «воспроизводимый вариант» после перезапуска
    оказывается другой картинкой."""
    value = 2166136261
    for byte in text.encode():
        value = ((value ^ byte) * 16777619) & 0xFFFFFFFF
    return value


def sheet(names: list[str], variants: int) -> None:
    """Контактный лист на 20/24/48 px — единственный честный способ выбрать.

    Смотреть надо на 20, а не на 1024: из трёх пробных иконок первого захода
    `fiscal` выглядела приемлемо в полном размере и была бесформенным пятном
    в рабочем.
    """
    from PIL import Image, ImageDraw

    sizes = (20, 24, 48)
    row_h, label_w = 62, 108
    rows = [(n, v) for n in names for v in range(variants)]
    img = Image.new("RGB", (label_w + 130, row_h * len(rows) + 8), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    for row, (name, variant) in enumerate(rows):
        y = row * row_h + 4
        draw.text((4, y + 20), f"{name} #{variant}", fill=(0, 0, 0))
        path = OUT / "mask" / f"{name}_{variant}.png"
        if not path.exists():
            continue
        # маска — белые чернила на чёрном; переворачиваем, чтобы читалась
        # как иконка, а не как негатив
        src = Image.open(path).convert("L").point(lambda v: 255 - v)
        x = label_w
        for size in sizes:
            img.paste(src.resize((size, size), Image.LANCZOS), (x, y + (48 - size) // 2))
            x += size + 12
    out = OUT / "sheet.png"
    img.save(out)
    print(f"  {out}: {len(rows)} rows")


def trace(names: list[str]) -> None:
    from PIL import Image
    import numpy as np
    import potrace

    (OUT / "svg").mkdir(parents=True, exist_ok=True)

    for name in names:
        variant = PICKS.get(name, 0)
        src = OUT / "mask" / f"{name}_{variant}.png"
        if not src.exists():
            print(f"  {name}: no {src}")
            continue

        image = Image.open(src).convert("L")
        # Уменьшается перед трассировкой, и это не срезание угла. Даже по
        # чистой маске potrace идёт за каждым зубчиком края и превращает одну
        # гладкую кривую в десятки отрезков — замерено 4.3 КБ пути на
        # вопросительный знак, который Material рисует примерно за 300 байт.
        # У иконки нет детали, которой нужны 1024 пикселя.
        image = image.resize((256, 256), Image.LANCZOS)
        array = np.array(image)
        # Маска пришла из ComfyUI уже двухцветной: белое — чернила. Здесь
        # только читаем её, а не решаем заново, где чернила.
        mask = array > 128

        share = mask.mean()
        # Отказ вместо пустого глифа. Пустой глиф не падает, не ругается и
        # выглядит на экране как квадрат — то есть врёт молча и до самого
        # прода. Порог снизу ловит съеденную матовку и целиком серую
        # генерацию; сверху — залитый фон, когда фигура заняла всё поле.
        if share < 0.03:
            print(f"  {name} #{variant}: ПУСТО ({share * 100:.1f} % чернил). "
                  f"Матовка съела фигуру либо FLUX нарисовал всё серым — "
                  f"смотреть generate/{name}_{variant}.png")
            continue
        if share > 0.85:
            print(f"  {name} #{variant}: ЗАЛИТО ({share * 100:.1f} % чернил). "
                  f"Фигура заняла весь кадр — перегенерировать")
            continue

        # Инвертируется на входе. Замерено на заведомом квадрате: potracer
        # трассирует область FALSE, поэтому маска, отданная как есть, делает
        # фигурой фон и выдаёт внешней границей рамку всего изображения —
        # глиф тогда рисуется сплошным блоком с вырезанной из него иконкой.
        bitmap = potrace.Bitmap(~mask)
        path = bitmap.trace(turdsize=16, alphamax=1.0)

        # potracer отдаёт точки с .x/.y, а не кортежи.
        parts: list[str] = []
        contours = 0
        for curve in path:
            contours += 1
            start = curve.start_point
            parts.append(f"M {start.x:.2f} {start.y:.2f}")
            for segment in curve:
                end = segment.end_point
                if segment.is_corner:
                    c = segment.c
                    parts.append(f"L {c.x:.2f} {c.y:.2f} L {end.x:.2f} {end.y:.2f}")
                else:
                    c1, c2 = segment.c1, segment.c2
                    parts.append(
                        f"C {c1.x:.2f} {c1.y:.2f} {c2.x:.2f} {c2.y:.2f} "
                        f"{end.x:.2f} {end.y:.2f}"
                    )
            parts.append("Z")

        d = " ".join(parts)
        svg = (
            '<svg xmlns="http://www.w3.org/2000/svg" '
            f'viewBox="0 0 {image.width} {image.height}">'
            f'<path d="{d}" fill="black" fill-rule="evenodd"/></svg>'
        )
        (OUT / "svg" / f"{name}.svg").write_text(svg, encoding="utf-8")
        print(
            f"  {name} #{variant}: {contours} contours, {len(d)} bytes of path, "
            f"{share * 100:.0f}% ink"
        )


# Private Use Area, чтобы ни одна кодовая точка не столкнулась с настоящим
# текстом. Порядок задан ICONS, поэтому иконка, добавленная в конец, никогда
# не сдвигает существующую — сдвинутая кодовая точка молча перенаправила бы
# каждое место использования.
FIRST_CODEPOINT = 0xE000


def build_font(names: list[str]) -> None:
    """Собирает контуры в один TTF — так же, как поставляются Material Icons."""
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.cu2quPen import Cu2QuPen
    from fontTools.pens.reverseContourPen import ReverseContourPen
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from fontTools.svgLib.path import SVGPath

    (OUT / "font").mkdir(parents=True, exist_ok=True)
    upm = 1024

    order = [n for n in ICONS if n in names]
    missing = [n for n in order if not (OUT / "svg" / f"{n}.svg").exists()]
    if missing:
        print(f"  no traced outline for: {missing}")
        order = [n for n in order if n not in missing]
    if not order:
        print("  nothing to build")
        return

    glyph_names = [".notdef"] + [f"icon_{n}" for n in order]
    glyphs, metrics, cmap = {}, {}, {}

    pen = TTGlyphPen(None)
    glyphs[".notdef"] = pen.glyph()
    metrics[".notdef"] = (upm, 0)

    # Кодовая точка считается от места в ICONS, а не от места в отобранном
    # списке. Иначе одна не обведённая иконка сдвигает КАЖДУЮ следующую, и
    # обещание «добавленная в конец никогда не двигает существующие»
    # нарушается ровно тогда, когда что-то не получилось, — то есть в самый
    # неподходящий момент и молча.
    slot = {name: index for index, name in enumerate(ICONS)}

    for name in order:
        # Контур обведён в координатах маски, а это не em. Чтение viewBox
        # вместо предположения о нём означает, что смена разрешения трассировки
        # никогда не сожмёт молча каждый глиф в угол.
        svg_text = (OUT / "svg" / f"{name}.svg").read_text(encoding="utf-8")
        box = float(svg_text.split('viewBox="0 0 ')[1].split(" ")[0])
        scale = upm / box

        pen = TTGlyphPen(None)
        # Разворот, потому что potrace обходит контуры в обратную сторону от
        # той, которой заливает TrueType. SVG замазывает это через
        # fill-rule="evenodd"; шрифт не может — он заливает по ненулевому
        # числу оборотов и ничем иным. Ошибись здесь — и глиф нарисуется
        # сплошным блоком с вырезанной из него иконкой, ровно как в первой
        # сборке.
        reverser = ReverseContourPen(pen)
        # TrueType хранит квадратики; SVG отдаёт кубики. Cu2QuPen переводит на
        # входе — без него fontTools отказывает глифу целиком, а не кладёт
        # что-то тихо неправильное, и это правильный отказ.
        converter = Cu2QuPen(reverser, max_err=1.0)
        # SVG — с осью Y вниз, шрифт — вверх, поэтому контур переворачивается
        # и поднимается на em. Без этого каждый глиф рисуется вверх ногами и
        # ниже базовой линии, что выглядит как провал трассировки и им не
        # является.
        svg = SVGPath(
            str(OUT / "svg" / f"{name}.svg"),
            transform=(scale, 0, 0, -scale, 0, upm),
        )
        svg.draw(converter)
        glyph_name = f"icon_{name}"
        glyphs[glyph_name] = pen.glyph()
        metrics[glyph_name] = (upm, 0)
        cmap[FIRST_CODEPOINT + slot[name]] = glyph_name

    builder = FontBuilder(upm, isTTF=True)
    builder.setupGlyphOrder(glyph_names)
    builder.setupCharacterMap(cmap)
    builder.setupGlyf(glyphs)
    builder.setupHorizontalMetrics(metrics)
    builder.setupHorizontalHeader(ascent=upm, descent=0)
    builder.setupNameTable(
        {
            "familyName": "TeleposIcons",
            "styleName": "Regular",
            "psName": "TeleposIcons-Regular",
            "version": "1.0",
            "copyright": "Generated by tools/icon_pipeline.py",
        }
    )
    builder.setupOS2(sTypoAscender=upm, usWinAscent=upm, usWinDescent=0)
    builder.setupPost()
    # Время создания прибивается к нулю эпохи шрифтов, а не берётся из часов.
    # Иначе один и тот же набор контуров даёт каждый раз ДРУГИЕ байты, файл
    # лежит в репозитории, и любая пересборка показывает изменение там, где
    # ничего не менялось. Отличие было замерено: пересборка из тех же масок
    # расходилась на 67-м байте, ровно в `head.modified`.
    builder.font["head"].created = 0
    builder.font["head"].modified = 0
    out = OUT / "font" / "TeleposIcons.ttf"
    builder.save(str(out))

    print(f"  {out}: {len(order)} glyphs, {out.stat().st_size} bytes")
    for name in order:
        print(f"    U+{FIRST_CODEPOINT + slot[name]:04X}  {name}")


DART_OUT = pathlib.Path("lib/app/theme/telepos_icons.dart")


def emit_dart() -> None:
    """Пишет дартовые константы из того же ICONS, из которого собран шрифт.

    Руками этот список не ведётся намеренно. Кодовая точка, разъехавшаяся с
    шрифтом, не падает и не ругается — она рисует ЧУЖУЮ иконку либо пустой
    квадрат, и заметить это можно только глазами на конкретном экране. Один
    источник правды снимает вопрос целиком.
    """
    lines = [
        "// СГЕНЕРИРОВАНО tools/icon_pipeline.py — править руками нечего.",
        "//",
        "// Кодовые точки идут от места в словаре ICONS конвейера, поэтому",
        "// иконка, добавленная в конец, не сдвигает ни одной существующей.",
        "",
        "import 'package:flutter/widgets.dart';",
        "",
        "/// Собственный набор иконок мастера настройки.",
        "///",
        "/// Не Material Icons: набор рисуется в ComfyUI и доводится до шрифта",
        "/// (`tools/icon_pipeline.py`), потому что растр, ужатый с генерации",
        "/// 1024, мягок ровно на тех 20–24 px, где на него смотрят.",
        "class TeleposIcons {",
        "  TeleposIcons._();",
        "",
        "  /// Имя семейства из pubspec.yaml.",
        "  static const String family = 'TeleposIcons';",
        "",
    ]
    for index, name in enumerate(ICONS):
        camel = "".join(
            part if i == 0 else part.capitalize()
            for i, part in enumerate(name.split("_"))
        )
        lines.append(
            f"  static const IconData {camel} = "
            f"IconData(0x{FIRST_CODEPOINT + index:04X}, fontFamily: family);"
        )
    lines += [
        "",
        "  /// Весь набор, в порядке кодовых точек. Нужен проверкам: тест,",
        "  /// перечисляющий иконки своим списком, молчит ровно про ту, что в",
        "  /// него забыли добавить.",
        "  static const Map<String, IconData> all = <String, IconData>{",
    ]
    for name in ICONS:
        camel = "".join(
            part if i == 0 else part.capitalize()
            for i, part in enumerate(name.split("_"))
        )
        lines.append(f"    '{name}': {camel},")
    lines += ["  };", "}", ""]
    DART_OUT.parent.mkdir(parents=True, exist_ok=True)
    DART_OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"  {DART_OUT}: {len(ICONS)} констант")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "stage",
        choices=["generate", "rematte", "sheet", "trace", "font", "dart", "all"],
    )
    parser.add_argument("--only", default="", help="comma-separated icon names")
    parser.add_argument("--variants", type=int, default=3)
    args = parser.parse_args()

    names = [n for n in args.only.split(",") if n] or list(ICONS)
    unknown = [n for n in names if n not in ICONS]
    if unknown:
        print(f"unknown icons: {unknown}", file=sys.stderr)
        return 1

    if args.stage in ("generate", "all"):
        generate(names, args.variants)
    if args.stage == "rematte":
        rematte(names, args.variants)
    if args.stage in ("sheet", "all"):
        sheet(names, args.variants)
    if args.stage in ("trace", "all"):
        trace(names)
    if args.stage in ("font", "all"):
        build_font(names)
    if args.stage in ("dart", "all"):
        emit_dart()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
