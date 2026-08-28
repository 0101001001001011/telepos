"""Рисует картинки для мастера установки Windows.

Две штуки, размеры заданы WiX и менять их нельзя:

* `banner.bmp` — 493×58, верхняя полоса на всех страницах, кроме первой и
  последней. WiX пишет по ней ЧЁРНЫЙ текст слева, поэтому левая часть обязана
  остаться светлой, а знак уходит вправо.
* `dialog.bmp` — 493×312, фон первой и последней страниц. Текст WiX пишет
  справа от полосы шириной 164 точки, поэтому рисунок живёт в этой полосе, а
  всё правее — светлое поле под чужой текст.

Цвета взяты из самой иконки приложения (`assets/icons/telepos_icon_1024.png`),
а не подобраны на глаз: #35ACE0 по краям, #2AA2D5 к центру. Из-за этого мастер
и приложение выглядят одним продуктом, а не двумя.

Формат — 24-битный BMP без сжатия: WiX другого не берёт, а PNG молча не
подхватится.
"""
import io
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON = os.path.join(ROOT, 'assets', 'icons', 'telepos_icon_1024.png')
OUT = os.path.join(ROOT, 'installer', 'windows')

# Палитра иконки.
BLUE_EDGE = (0x35, 0xAC, 0xE0)
BLUE_DEEP = (0x1E, 0x86, 0xB8)
LIGHT = (0xFA, 0xFB, 0xFC)      # поле под чёрный текст WiX
HAIRLINE = (0xD9, 0xE2, 0xEB)

ART_W = 164                      # ширина полосы рисунка на первой странице


def _font(size, bold=False):
    """Системный шрифт Windows. Segoe UI — то же семейство, что в мастере."""
    names = (['segoeuib.ttf', 'seguisb.ttf'] if bold else ['segoeui.ttf'])
    for n in names:
        p = os.path.join(os.environ.get('WINDIR', r'C:\Windows'), 'Fonts', n)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def _vertical_gradient(size, top, bottom):
    w, h = size
    img = Image.new('RGB', (1, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px[0, y] = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return img.resize((w, h), Image.NEAREST)


def _icon(size):
    im = Image.open(ICON).convert('RGBA')
    return im.resize((size, size), Image.LANCZOS)


def make_dialog():
    """493×312 — фон приветствия и завершения."""
    w, h = 493, 312
    img = Image.new('RGB', (w, h), LIGHT)

    # Полоса рисунка слева: вертикальный градиент палитры иконки.
    strip = _vertical_gradient((ART_W, h), BLUE_EDGE, BLUE_DEEP)
    img.paste(strip, (0, 0))

    d = ImageDraw.Draw(img)

    # Волосяная линия по границе — та же, что делит колонки в самом приложении.
    d.line([(ART_W, 0), (ART_W, h)], fill=HAIRLINE, width=1)

    # Знак приложения. Не по центру полосы, а выше: под ним подпись.
    ic = _icon(88)
    img.paste(ic, ((ART_W - 88) // 2, 74), ic)

    d.text((ART_W // 2, 182), 'TelePOS', font=_font(20, bold=True),
           fill=(255, 255, 255), anchor='mm')
    d.text((ART_W // 2, 206), 'Telegram Point Of Sale', font=_font(10),
           fill=(0xD6, 0xEC, 0xF8), anchor='mm')

    # Внизу полосы — лицензия. Мелко, но она тут не для красоты: человек
    # видит её раньше, чем дойдёт до страницы соглашения.
    d.text((ART_W // 2, h - 22), 'GNU AGPL v3', font=_font(9),
           fill=(0xBF, 0xE1, 0xF5), anchor='mm')

    img.save(os.path.join(OUT, 'dialog.bmp'), 'BMP')
    return 'dialog.bmp', (w, h)


def make_banner():
    """493×58 — верхняя полоса. Текст WiX идёт слева, знак ставим справа."""
    w, h = 493, 58
    img = Image.new('RGB', (w, h), LIGHT)
    d = ImageDraw.Draw(img)

    # Синяя черта по низу — единственное, что отделяет полосу от страницы.
    d.rectangle([(0, h - 2), (w, h)], fill=BLUE_EDGE)

    ic = _icon(36)
    img.paste(ic, (w - 36 - 14, (h - 36) // 2 - 1), ic)

    img.save(os.path.join(OUT, 'banner.bmp'), 'BMP')
    return 'banner.bmp', (w, h)


if __name__ == '__main__':
    for name, size in (make_dialog(), make_banner()):
        p = os.path.join(OUT, name)
        print('%-12s %dx%d  %d байт' % (name, size[0], size[1],
                                        os.path.getsize(p)))
