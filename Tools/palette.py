#!/usr/bin/env python3
"""Draws the palette as an SVG, read straight off `CardArt.swift`.

Generated rather than drawn, because three separate colours have already drifted between
the code and the artwork — a sheet anybody has to keep up by hand is a fourth waiting to
happen. Run it again whenever the palette moves.

    ./Tools/palette.py
"""
import pathlib
import re
import sys

SOURCE = "ProjectCardCourt/View/CardArt.swift"
OUT = "_Graphic Assets/Vectors/CardCourt_Palette.svg"

# Grouped rather than gridded: cool, warm, the grounds and inks, then the ones a card
# reaches for on purpose. A ragged last row reads better than a colour in the wrong family.
ROWS = [
    ["navy", "darkBlue", "blue", "lightBlue", "teal"],
    ["orange", "gold", "sand", "tan", "brown"],
    ["black", "gray", "cloud"],
    ["red", "green", "magenta", "purple"],
]

DIAMETER = 132
GAP = 20
MARGIN = 28
LABEL = 26          # room under each circle for its name


def palette(root: pathlib.Path) -> dict[str, str]:
    text = (root / SOURCE).read_text()
    found = re.findall(
        r"static let (\w+)\s*= Color\(red: 0x(\w\w) / 255, "
        r"green: 0x(\w\w) / 255, blue: 0x(\w\w) / 255\)", text)
    return {name: (r + g + b).upper() for name, r, g, b in found}


def readable_on(hexcode: str) -> str:
    """Ink that can be read on this ground.

    Off relative luminance rather than off the raw channels: a saturated gold and a
    saturated blue can share a channel average and not share a legibility.
    """
    def channel(c: float) -> float:
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(int(hexcode[i:i + 2], 16)) for i in (0, 2, 4))
    luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return "#1C3261" if luminance > 0.30 else "#FFFFFF"


def draw(colours: dict[str, str]) -> str:
    across = max(len(row) for row in ROWS)
    width = MARGIN * 2 + across * DIAMETER + (across - 1) * GAP
    height = MARGIN * 2 + len(ROWS) * (DIAMETER + LABEL) + (len(ROWS) - 1) * GAP
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">',
        f'  <rect width="{width}" height="{height}" fill="#FFFFFF"/>',
    ]
    for down, row in enumerate(ROWS):
        top = MARGIN + down * (DIAMETER + LABEL + GAP)
        for along, name in enumerate(row):
            code = colours.get(name)
            if code is None:
                print(f"  ! {name} is not in {SOURCE}", file=sys.stderr)
                continue
            left = MARGIN + along * (DIAMETER + GAP)
            middle = left + DIAMETER / 2
            out += [
                f'  <circle cx="{middle}" cy="{top + DIAMETER / 2}" r="{DIAMETER / 2}" '
                f'fill="#{code}"/>',
                f'  <text x="{middle}" y="{top + DIAMETER / 2 + 6}" '
                f'text-anchor="middle" font-family="Menlo, monospace" font-size="19" '
                f'font-weight="600" fill="{readable_on(code)}">#{code}</text>',
                f'  <text x="{middle}" y="{top + DIAMETER + 19}" text-anchor="middle" '
                f'font-family="Helvetica, Arial, sans-serif" font-size="15" '
                f'fill="#1C3261">{name}</text>',
            ]
    out.append("</svg>")
    return "\n".join(out) + "\n"


root = pathlib.Path(__file__).resolve().parent.parent
colours = palette(root)
listed = {name for row in ROWS for name in row}
for name in colours:
    if name not in listed:
        print(f"  ! {name} is in the palette but not on the sheet", file=sys.stderr)
(root / OUT).write_text(draw(colours))
print(f"{len(listed)} swatches → {OUT}")
