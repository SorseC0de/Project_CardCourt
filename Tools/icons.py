#!/usr/bin/env python3
"""Frames the full-colour type icons on one circle, and snaps their colours.

**A type is drawn in two layers.** `X_plate.svg` is everything behind the name banner —
the circle and what stands in it — and `X_subject.svg` is what is printed over the banner,
the ball on a Pass, the ankle on a Move. The two are exported from one canvas, so the
plate's circle frames **both**: the subject is never measured on its own, because a ball
on its own has no circle to be measured against.

A type with no `_subject` is drawn whole in `X_Icon_new.svg` and framed by itself.

A drawing that is not a type icon at all — the court the Varenas are printed on — has no
circle to be framed by. It is named in `TRIMMED` and trimmed to its own ink instead.

Run it after any re-export. **Affinity writes the artboard back out as the viewBox**, so
an icon saved again loses its framing and reads a different size to the other eight —
which is the whole thing this fixes.

Two passes over `_Graphic Assets/Vectors/*_Icon_new.svg`:

  1. Measure the backdrop circle — the first shape in the file — and set the viewBox so
     it lands centred at a radius of 0.4 of the canvas side. See `_Design/type-icons.md`.
  2. Snap any fill within `TOLERANCE` of a palette colour to that colour exactly. Affinity
     rounds; a colour six points out is a decision and is left alone and reported.

    ./Tools/icons.py

Measures rather than reformats: the geometry is read with a parser and the file is edited
by hand on the two things that change, so the drawing comes back to Affinity as it left.
"""
import math
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

ICONS = "_Graphic Assets/Vectors/Card Icons"
SOURCE = "ProjectCardCourt/View/CardArt.swift"

MARGIN = 1.25       # half the canvas, in radii — the circle is 80% of the side
TOLERANCE = 6       # how far off a palette colour still counts as rounding
SVG = "{http://www.w3.org/2000/svg}"
DRAWN = {SVG + t for t in ("path", "circle", "ellipse", "rect", "polygon")}

# Pure black and white are honorary palette members: UI, and the whites inside a drawing.
HONORARY = {"#000000", "#FFFFFF"}


def matrix(node) -> tuple:
    """The element's own transform. Affinity only ever writes `matrix(...)`."""
    got = re.match(r"matrix\(([-\d.eE,\s]+)\)", node.get("transform", "") or "")
    if not got:
        return (1, 0, 0, 1, 0, 0)
    a, b, c, d, e, f = (float(v) for v in re.split(r"[,\s]+", got.group(1).strip()))
    return (a, b, c, d, e, f)


def times(m, n) -> tuple:
    """`m` applied after `n`, both as SVG's six numbers."""
    a, b, c, d, e, f = m
    A, B, C, D, E, F = n
    return (a * A + c * B, b * A + d * B,
            a * C + c * D, b * C + d * D,
            a * E + c * F + e, b * E + d * F + f)


def apply(m, x, y) -> tuple:
    a, b, c, d, e, f = m
    return (a * x + c * y + e, b * x + d * y + f)


def points(node) -> list:
    """Every on-curve point and control point, as cubic segments of four points each."""
    if node.tag == SVG + "circle":
        cx, cy = float(node.get("cx", 0)), float(node.get("cy", 0))
        r = float(node.get("r", 0))
        k = r * 0.5522847498
        ring = [(cx, cy - r), (cx + k, cy - r), (cx + r, cy - k), (cx + r, cy),
                (cx + r, cy + k), (cx + k, cy + r), (cx, cy + r), (cx - k, cy + r),
                (cx - r, cy + k), (cx - r, cy), (cx - r, cy - k), (cx - k, cy - r)]
        return [ring[i:i + 4] for i in (0, 3, 6)] + [[ring[9], ring[10], ring[11], ring[0]]]

    d = node.get("d")
    if not d:
        return []
    out, here, start = [], (0.0, 0.0), (0.0, 0.0)
    for letter, body in re.findall(r"([MmLlCcZz])([^MmLlCcZz]*)", d):
        nums = [float(v) for v in re.findall(r"-?\d*\.?\d+(?:[eE][-+]?\d+)?", body)]
        rel = letter.islower()
        if letter in "Zz":
            here = start
        elif letter in "Mm":
            for i in range(0, len(nums) - 1, 2):
                p = (here[0] + nums[i], here[1] + nums[i + 1]) if rel else (nums[i], nums[i + 1])
                if i == 0:
                    start = p
                else:
                    out.append([here, here, p, p])
                here = p
        elif letter in "Ll":
            for i in range(0, len(nums) - 1, 2):
                p = (here[0] + nums[i], here[1] + nums[i + 1]) if rel else (nums[i], nums[i + 1])
                out.append([here, here, p, p])
                here = p
        else:
            for i in range(0, len(nums) - 5, 6):
                trio = [(here[0] + nums[i + j], here[1] + nums[i + j + 1]) if rel
                        else (nums[i + j], nums[i + j + 1]) for j in (0, 2, 4)]
                out.append([here] + trio)
                here = trio[-1]
    return out


def span(a: float, b: float, c: float, d: float) -> tuple:
    """One axis of a cubic, exactly: the ends, plus wherever its slope turns."""
    lo, hi = min(a, d), max(a, d)
    A = -a + 3 * b - 3 * c + d
    B = 2 * (a - 2 * b + c)
    C = -a + b
    roots = []
    if abs(A) < 1e-12:
        if abs(B) > 1e-12:
            roots = [-C / B]
    else:
        under = B * B - 4 * A * C
        if under >= 0:
            roots = [(-B + s * math.sqrt(under)) / (2 * A) for s in (1, -1)]
    for t in roots:
        if 0 < t < 1:
            u = 1 - t
            v = (u ** 3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t ** 3 * d)
            lo, hi = min(lo, v), max(hi, v)
    return lo, hi


def bounds(node, m):
    got = None
    for seg in points(node):
        (x0, y0), (x1, y1), (x2, y2), (x3, y3) = [apply(m, *p) for p in seg]
        xa, xb = span(x0, x1, x2, x3)
        ya, yb = span(y0, y1, y2, y3)
        got = (xa, ya, xb, yb) if got is None else (
            min(got[0], xa), min(got[1], ya), max(got[2], xb), max(got[3], yb))
    return got


def measure(text: str) -> tuple:
    """The backdrop circle and everything drawn, in the file's own coordinates."""
    root = ET.fromstring(text)
    backdrop, whole = None, None
    stack = [(root, (1, 0, 0, 1, 0, 0))]
    while stack:
        node, up = stack.pop(0)
        here = times(up, matrix(node))
        if node.tag in DRAWN:
            box = bounds(node, here)
            if box:
                backdrop = backdrop or box
                whole = box if whole is None else (
                    min(whole[0], box[0]), min(whole[1], box[1]),
                    max(whole[2], box[2]), max(whole[3], box[3]))
        stack = [(kid, here) for kid in node] + stack
    return backdrop, whole


def palette(root: pathlib.Path) -> dict:
    text = (root / SOURCE).read_text()
    found = re.findall(
        r"static let (\w+)\s*= Color\(red: 0x(\w\w) / 255, "
        r"green: 0x(\w\w) / 255, blue: 0x(\w\w) / 255\)", text)
    known = {"#" + (r + g + b).upper(): name for name, r, g, b in found}
    known.update({"#000000": "black (pure)", "#FFFFFF": "white (pure)"})
    return known


def channels(code: str) -> tuple:
    return tuple(int(code[i:i + 2], 16) for i in (1, 3, 5))


def nearest(code: str, known: dict) -> tuple:
    best = min(known, key=lambda p: sum((x - y) ** 2 for x, y in zip(channels(code), channels(p))))
    off = math.dist(channels(code), channels(best))
    return best, known[best], off


def n(v: float) -> str:
    return f"{v:.4f}".rstrip("0").rstrip(".")


root = pathlib.Path(__file__).resolve().parent.parent
known = palette(root)
moved = snapped = 0

def frame(path: pathlib.Path, box: str) -> bool:
    """Writes one viewBox, and snaps every colour in the file. True if it changed."""
    was = path.read_text()
    text, hits = re.subn(r'viewBox="[^"]*"', box, was, count=1)
    if hits != 1:
        print(f"  ! {path.name} has no viewBox", file=sys.stderr)

    def snap(code: str) -> str:
        global snapped
        if code in known:
            return code
        best, name, off = nearest(code, known)
        if off > TOLERANCE:
            print(f"  ? {path.name}: {code} is {off:.0f} off {name}, left alone",
                  file=sys.stderr)
            return code
        snapped += 1
        return best

    text = re.sub(r"rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)",
                  lambda m: "rgb(%d,%d,%d)" % channels(
                      snap("#%02X%02X%02X" % tuple(int(v) for v in m.groups()))), text)
    text = re.sub(r"(fill|stroke|stop-color)(\s*[:=]\s*\"?)(#[0-9A-Fa-f]{6})",
                  lambda m: m.group(1) + m.group(2) + snap(m.group(3).upper()), text)
    if text == was:
        return False
    path.write_text(text)
    return True


# One entry per type: what is drawn behind the banner, and what is printed over it.
# Files exported under a second spelling of a type's name, and the type they belong to.
ALIASES = {"Variball": "Variaball"}

layers: dict[str, dict[str, pathlib.Path]] = {}
for path in sorted((root / ICONS).glob("*.svg")):
    for tail, part in (("_plate", "back"), ("_subject", "front"), ("_Icon_new", "whole")):
        if path.stem.endswith(tail):
            name = path.stem[: -len(tail)]
            layers.setdefault(ALIASES.get(name, name), {})[part] = path
            break

boxes: dict[str, tuple[float, float, float]] = {}
for name in sorted(layers):
    parts = layers[name]
    # The plate is what carries the circle. A type that was never split is framed by the
    # one drawing it has.
    path = parts.get("back") or parts.get("whole")
    if path is None:
        continue
    text = path.read_text()
    circle, whole = measure(text)
    if circle is None:
        print(f"  ! {path.name} draws nothing", file=sys.stderr)
        continue

    x0, y0, x1, y1 = circle
    cx, cy, r = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2
    if abs((y1 - y0) / 2 - r) > 0.5:
        print(f"  ! {path.name}: the shape at the back is not a circle "
              f"({x1 - x0:.1f} by {y1 - y0:.1f})", file=sys.stderr)

    box = (f'viewBox="{n(cx - MARGIN * r)} {n(cy - MARGIN * r)} '
           f'{n(2 * MARGIN * r)} {n(2 * MARGIN * r)}"')

    # anything reaching past the canvas would be cut off at that framing
    edge = max(abs(whole[0] - cx), abs(whole[1] - cy), abs(whole[2] - cx), abs(whole[3] - cy))
    if edge > MARGIN * r + 0.5:
        print(f"  ! {path.name} spills to {edge / r:.2f} radii, past the "
              f"{MARGIN} the canvas holds", file=sys.stderr)

    # **Every layer of this type takes the plate's box**, so they line up by being drawn
    # at the same size in the same place.
    for part in ("back", "front", "whole"):
        if part in parts and frame(parts[part], box):
            moved += 1
    boxes[name] = (cx - MARGIN * r, cy - MARGIN * r, 2 * MARGIN * r)
    print(f"{name:16} circle ({cx:.1f}, {cy:.1f}) r {r:.1f}  "
          f"{'+'.join(sorted(parts))}   {box}")

# **Drawings that are not type icons**, trimmed to their own ink the way they were before
# Affinity wrote the artboard back out — with half the widest stroke kept, so no edge line
# is cut.
TRIMMED = ("ISO_Court", "ISO_Court_v2", "CardCourt_Ball", "Shot_Icon", "Dunk_Icon")


def ink(text: str):
    """Everything that actually draws, a fill or a stroke, in the file's own coordinates."""
    def style(node, key):
        got = re.search(key + r"\s*:\s*([^;]+)", node.get("style", "") or "")
        return got.group(1).strip() if got else node.get(key)

    tree = ET.fromstring(text)
    got = None
    stack = [(tree, (1, 0, 0, 1, 0, 0), None, None)]
    while stack:
        node, up, fill, stroke = stack.pop(0)
        here = times(up, matrix(node))
        fill = style(node, "fill") or fill
        stroke = style(node, "stroke") or stroke
        if node.tag in DRAWN and (fill != "none" or (stroke or "none") != "none"):
            box = bounds(node, here)
            if box:
                got = box if got is None else (min(got[0], box[0]), min(got[1], box[1]),
                                               max(got[2], box[2]), max(got[3], box[3]))
        stack = [(kid, here, fill, stroke) for kid in node] + stack
    return got


for name in TRIMMED:
    path = root / ICONS / f"{name}.svg"
    if not path.exists():
        continue
    text = path.read_text()
    box = ink(text)
    if box is None:
        print(f"  ! {path.name} draws nothing", file=sys.stderr)
        continue
    half = max([float(w) for w in re.findall(r"stroke-width\s*:\s*([\d.]+)", text)] or [0]) / 2
    x0, y0, x1, y1 = box[0] - half, box[1] - half, box[2] + half, box[3] + half
    trim = f'viewBox="{n(x0)} {n(y0)} {n(x1 - x0)} {n(y1 - y0)}"'
    if frame(path, trim):
        moved += 1
    print(f"{name:16} trimmed to its ink   {trim}")

# **The ball icons**: each Variaball's own drawing, made on the Variaball plate's artboard so
# every ball stands in the plate at one size and spills out of it the way it was drawn. So they
# take the plate's box, as a subject layer would. Snow Ball It came out of Affinity on a 4022
# artboard rather than 966, so its box is scaled to match; re-exported at 966, drop the entry.
BALL_EXPORT_SCALE = {"snowball": 4022 / 966}
if "Variaball" in boxes:
    left, top, span = boxes["Variaball"]
    for path in sorted((root / ICONS / "Balls").glob("*.svg")):
        k = BALL_EXPORT_SCALE.get(path.stem, 1)
        box = f'viewBox="{n(left * k)} {n(top * k)} {n(span * k)} {n(span * k)}"'
        if frame(path, box):
            moved += 1
        print(f"{'Balls/' + path.stem:16} on the Variaball plate   {box}")

print(f"\n{moved} file(s) rewritten, {snapped} fill(s) snapped to the palette")
