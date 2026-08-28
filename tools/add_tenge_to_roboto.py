"""Adds the tenge sign U+20B8 to the bundled Roboto faces.

Roboto does not contain the tenge sign. Neither the build shipped in Flutter's
artifact cache nor the current release from Google has it -- verified by
reading the cmap of both. The till prints it next to every price in Kazakhstan,
which is the only market this product has ever been tested in, so a missing
glyph is a tofu box on the largest number on the sale screen.

The glyph is not imported from another typeface. It is COMPOSED from Roboto's
own capital T, so the stroke weight, the bar thickness, the stem width and the
side bearings are the ones this face already uses -- for every weight, without
tuning. Only the proportion between the two bars is borrowed, from Inter, which
does have the sign: its gap is 0.72 of the bar thickness and its stem stops
flush with the top of the lower bar.

Roboto is licensed under the SIL OFL with NO reserved font name, so a modified
version may keep the family name. The modification is recorded in the name
table so the derived file is not mistaken for the original.

Run from the repository root after replacing the Roboto files:

    python tools/add_tenge_to_roboto.py

It is idempotent: a face that already has the glyph is left alone.
"""

from __future__ import annotations

import sys
from pathlib import Path

from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

FACES = [
    "assets/fonts/Roboto-Regular.ttf",
    "assets/fonts/Roboto-Medium.ttf",
    "assets/fonts/Roboto-Bold.ttf",
]

TENGE = 0x20B8
GLYPH_NAME = "uni20B8"

# Read off Inter, which draws the sign: gap between the bars divided by bar
# thickness. Everything else comes from the face being patched.
GAP_RATIO = 120 / 167


def measure_t(font: TTFont) -> dict[str, float]:
    """Reads the geometry of capital T out of the face itself."""
    cmap = font.getBestCmap()
    name = cmap[ord("T")]
    pen = RecordingPen()
    font.getGlyphSet()[name].draw(pen)

    points = [pt for op, args in pen.value if op == "lineTo" or op == "moveTo"
              for pt in args]
    if len(points) != 8:
        raise SystemExit(
            f"T in this face is not the plain 8-point outline this script "
            f"knows how to read ({len(points)} points). Inspect it by hand."
        )

    xs = sorted({x for x, _ in points})
    ys = sorted({y for _, y in points})
    if len(xs) != 4 or len(ys) != 3:
        raise SystemExit(f"unexpected T outline: xs={xs} ys={ys}")

    bar_left, stem_left, stem_right, bar_right = xs
    _baseline, bar_bottom, cap_height = ys

    return {
        "bar_left": bar_left,
        "bar_right": bar_right,
        "stem_left": stem_left,
        "stem_right": stem_right,
        "bar_bottom": bar_bottom,
        "cap_height": cap_height,
        "thickness": cap_height - bar_bottom,
        "advance": font["hmtx"][name][0],
    }


def draw_tenge(m: dict[str, float]) -> TTGlyphPen:
    gap = round(m["thickness"] * GAP_RATIO)
    lower_top = m["bar_bottom"] - gap
    lower_bottom = lower_top - m["thickness"]

    pen = TTGlyphPen(None)

    def rect(x0: float, y0: float, x1: float, y1: float) -> None:
        pen.moveTo((x1, y1))
        pen.lineTo((x1, y0))
        pen.lineTo((x0, y0))
        pen.lineTo((x0, y1))
        pen.closePath()

    # Stem stops flush with the top of the lower bar, as Inter draws it.
    rect(m["stem_left"], 0, m["stem_right"], lower_top)
    rect(m["bar_left"], lower_bottom, m["bar_right"], lower_top)
    rect(m["bar_left"], m["bar_bottom"], m["bar_right"], m["cap_height"])
    return pen


def patch(path: Path) -> str:
    font = TTFont(path)
    if TENGE in font.getBestCmap():
        return f"{path.name}: already has U+20B8, left alone"

    m = measure_t(font)
    glyf = font["glyf"]
    glyf[GLYPH_NAME] = draw_tenge(m).glyph()
    font["hmtx"][GLYPH_NAME] = (int(m["advance"]), int(m["bar_left"]))

    for table in font["cmap"].tables:
        if table.isUnicode():
            table.cmap[TENGE] = GLYPH_NAME

    order = font.getGlyphOrder()
    if GLYPH_NAME not in order:
        font.setGlyphOrder(list(order) + [GLYPH_NAME])

    # Say plainly that this file is not the original.
    for record in font["name"].names:
        if record.nameID == 10:  # Description
            record.string = (
                "Modified: U+20B8 TENGE SIGN composed from this face's own "
                "capital T. See tools/add_tenge_to_roboto.py."
            )
            break
    else:
        font["name"].setName(
            "Modified: U+20B8 TENGE SIGN composed from this face's own "
            "capital T. See tools/add_tenge_to_roboto.py.",
            10, 3, 1, 0x409,
        )

    font.save(path)
    return (
        f"{path.name}: added U+20B8 "
        f"(thickness {m['thickness']:.0f}, gap {m['thickness'] * GAP_RATIO:.0f})"
    )


def main() -> int:
    for face in FACES:
        path = Path(face)
        if not path.exists():
            print(f"{face}: missing", file=sys.stderr)
            return 1
        print(patch(path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
