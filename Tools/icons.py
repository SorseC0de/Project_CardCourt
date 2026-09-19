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
import copy
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


def export_scale(path: pathlib.Path) -> float:
    """**Affinity sometimes exports at a print DPI**, the whole drawing wrapped in one uniform
    scale: Snow Ball It came out at 300 (×4.16667). A box shared across files is scaled by it."""
    kids = [kid for kid in ET.fromstring(path.read_text()) if kid.tag != SVG + "defs"]
    if len(kids) == 1 and kids[0].tag == SVG + "g":
        a, b, c, d, e, f = matrix(kids[0])
        if a == d and b == c == e == f == 0:
            return a
    return 1


def canvas_matrices(path: pathlib.Path) -> list:
    """Every element with a transform of its own, placed in canvas units: the file's
    coordinates with any export scale taken back off."""
    scale = export_scale(path)
    found = []

    def walk(node, up):
        here = times(up, matrix(node))
        if node.get("transform"):
            found.append(tuple(v / scale for v in here))
        for kid in node:
            walk(kid, here)

    walk(ET.fromstring(path.read_text()), (1, 0, 0, 1, 0, 0))
    return found


def frames_along(path: pathlib.Path, reference, left: float, top: float):
    """How many frames along a ball's canvas sits: where its copy of the subject's ball stands
    against the subject's own, in steps of the frame's offset. None if no copy is full size."""
    if reference is None:
        return None
    for m in canvas_matrices(path):
        if all(abs(x - y) < 1e-3 for x, y in zip(m[:4], reference[:4])):
            reads = {round((m[4] - reference[4]) / -left)} if abs(left) >= 1 else set()
            if abs(top) >= 1:
                reads.add(round((m[5] - reference[5]) / -top))
            if not reads:
                return 0
            return reads.pop() if len(reads) == 1 else None
    return None


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


def viewbox(left: float, top: float, side: float, scale: float = 1) -> str:
    return f'viewBox="{n(left * scale)} {n(top * scale)} {n(side * scale)} {n(side * scale)}"'


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

    left, top, side = cx - MARGIN * r, cy - MARGIN * r, 2 * MARGIN * r
    box = viewbox(left, top, side)

    # anything reaching past the canvas would be cut off at that framing
    edge = max(abs(whole[0] - cx), abs(whole[1] - cy), abs(whole[2] - cx), abs(whole[3] - cy))
    if edge > MARGIN * r + 0.5:
        print(f"  ! {path.name} spills to {edge / r:.2f} radii, past the "
              f"{MARGIN} the canvas holds", file=sys.stderr)

    # **Every layer of this type takes the plate's box**, so they line up by being drawn
    # at the same size in the same place. The subject shares the plate's canvas, so it takes
    # the box at its own export scale; a whole drawing was made on a canvas of its own.
    unit = export_scale(path)
    for part in ("back", "front", "whole"):
        if part not in parts:
            continue
        scale = export_scale(parts[part]) / unit if part == "front" else 1
        if frame(parts[part], viewbox(left, top, side, scale)):
            moved += 1
    boxes[name] = (left / unit, top / unit, side / unit)
    print(f"{name:16} circle ({cx:.1f}, {cy:.1f}) r {r:.1f}  "
          f"{'+'.join(sorted(parts))}   {box}")

# **Drawings that are not type icons**, trimmed to their own ink the way they were before
# Affinity wrote the artboard back out — with half the widest stroke kept, so no edge line
# is cut.
# **Move_meter** is the Move subject with the two leading dashes cut off it: the HUD
# draws those three as pips instead, so the drawing has to start where its long bar
# does. See `TravelMeter`.
TRIMMED = ("ISO_Court", "ISO_Court_v2", "CardCourt_Ball", "Shot_Icon", "Dunk_Icon",
           "Move_meter")


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

# **The ball icons**: each Variaball's own drawing, its ball copied from the Variaball subject,
# so every ball stands in the plate at one size and spills out of it the way it was drawn.
#
# **A canvas opened from a framed export sits one frame along**: Affinity puts the viewBox's
# corner at the canvas's, so the drawing moves by the frame's offset. The first balls were drawn
# on the framed Variaball icon, one frame along; ball_template.aftemplate was opened from a
# framed ball, two. Each ball's copy of the subject's ball says which, and it is framed back.
BALL_TEMPLATE_FRAMES = 2
# A ball whose copy of the subject's ball was resized can't be read, so it is named here.
BALL_FRAMES = {"handball": 1}
subject = layers.get("Variaball", {}).get("front")
if "Variaball" in boxes and subject:
    left, top, side = boxes["Variaball"]
    reference = next((m for m in canvas_matrices(subject) if m != (1, 0, 0, 1, 0, 0)), None)
    for path in sorted((root / ICONS / "Balls").glob("*.svg")):
        frames, how = frames_along(path, reference, left, top), "read"
        if frames is None and path.stem in BALL_FRAMES:
            frames, how = BALL_FRAMES[path.stem], "named"
        if frames is None:
            frames, how = BALL_TEMPLATE_FRAMES, "template"
        box = viewbox((1 - frames) * left, (1 - frames) * top, side, export_scale(path))
        if frame(path, box):
            moved += 1
        print(f"{'Balls/' + path.stem:18} {frames} frame(s) along, {how:8}  {box}")

# **The ball in play**: each drawing's ball on its own, without the aura behind it, trimmed to
# itself — what the game draws in place of the plain ball while that Variaball is out.
#
# The ball is the group the subject's ball was copied into, found by its transform, deepest
# first. Where the group holding it also holds the aura it is named here instead, as the
# child indices from the root.
BALL_GROUPS = {"blazeball": (0, 0, 1), "snowball": (0, 0, 0),
               # Its crimson panel and highlights sit beside the ball's group, not in it.
               "medicineball": (0,)}
# Pieces of the aura drawn inside the ball's own group, taken out by the same indices.
BALL_DROPPED = {"rechargerock": [(0, 8, 4)], "heroball": [(0, 0, 0, 0)]}
# Balls with nothing of their own to put in play, and why.
BALL_SKIPPED = {"brandnewball": "the plain ball, with the Gold Swishbone's shine",
                "variaball": "never stays in play"}
ASSETS = root / "ProjectCardCourt/Assets.xcassets"
INKS = root / "ProjectCardCourt/Art/BallSpriteInks.swift"
PIXELS = root / "ProjectCardCourt/Art/PaletteFX.swift"

for name in ("", "xlink", "serif"):
    ET.register_namespace(name, {"": "http://www.w3.org/2000/svg",
                                 "xlink": "http://www.w3.org/1999/xlink",
                                 "serif": "http://www.serif.com/"}[name])


def ball_trail(path: pathlib.Path, reference):
    """Where the ball is: the named group, or the deepest copy of the subject's ball."""
    if path.stem in BALL_GROUPS:
        return BALL_GROUPS[path.stem]
    scale = export_scale(path)
    found = ()

    def walk(node, up, trail):
        nonlocal found
        here = times(up, matrix(node))
        if node.get("transform") and reference is not None:
            m = tuple(v / scale for v in here)
            if all(abs(x - y) < 1e-3 for x, y in zip(m[:4], reference[:4])):
                if len(trail) >= len(found):
                    found = tuple(trail)
        for i, kid in enumerate(node):
            walk(kid, here, trail + [i])

    walk(ET.fromstring(path.read_text()), (1, 0, 0, 1, 0, 0), [])
    return found


def cut_out(path: pathlib.Path, trail) -> str:
    """The ball alone: its group, inside copies of the groups that held it, trimmed square."""
    source = ET.fromstring(path.read_text())
    # Last first, so taking one out never moves the index of another under the same group.
    for gone in sorted(BALL_DROPPED.get(path.stem, []), reverse=True):
        parent = source
        for step in gone[:-1]:
            parent = list(parent)[step]
        parent.remove(list(parent)[gone[-1]])
    out = ET.Element(source.tag, {k: v for k, v in source.attrib.items() if k != "viewBox"})
    for defs in source.iter(SVG + "defs"):
        out.append(copy.deepcopy(defs))
    # Every group on the way down keeps its own transform and style.
    node, holder = source, out
    for depth, step in enumerate(trail):
        node = list(node)[step]
        if depth == len(trail) - 1:
            holder.append(copy.deepcopy(node))
        else:
            holder = ET.SubElement(holder, node.tag,
                                   {k: v for k, v in node.attrib.items()
                                    if k in ("transform", "style")})
    if not trail:
        for kid in source:
            if kid.tag != SVG + "defs":
                out.append(copy.deepcopy(kid))
    text = ET.tostring(out, encoding="unicode")
    x0, y0, x1, y1 = ink(text)
    own = max(x1 - x0, y1 - y0)
    # **Framed on the plain ball's side**, so a ball drawn smaller — Handball — is drawn
    # smaller in the game too. Never tighter than the ball itself, or its edge is cut.
    plain = BALL_SIDE * export_scale(path)
    side = max(own, plain)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    box = f'viewBox="{n(cx - side / 2)} {n(cy - side / 2)} {n(side)} {n(side)}"'
    return text.replace("<svg ", f"<svg {box} ", 1), own / plain


def pixel_palette() -> dict:
    found = re.findall(r"static let (\w+) = Color\(hex: 0x(\w{6})\)", PIXELS.read_text())
    return {"#" + code.upper(): name for name, code in found}


def fill_of(node, inherited):
    """The fill a node paints in, as `#RRGGBB`: its own, or the one it inherits. None for none."""
    got = re.search(r"fill\s*:\s*([^;]+)", node.get("style", "") or "")
    value = got.group(1).strip() if got else node.get("fill")
    if value is None:
        return inherited
    if re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
        return value.upper()
    rgb = re.fullmatch(r"rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)", value)
    if rgb:
        return "#%02X%02X%02X" % tuple(int(v) for v in rgb.groups())
    return None if value == "none" else inherited


def outlines(node, m) -> list:
    """A shape's edges as closed rings of points, its curves flattened."""
    if node.tag in (SVG + "circle", SVG + "ellipse"):
        cx, cy = float(node.get("cx", 0)), float(node.get("cy", 0))
        rx = float(node.get("rx", node.get("r", 0)))
        ry = float(node.get("ry", node.get("r", 0)))
        return [[apply(m, cx + rx * math.cos(k * math.pi / 16), cy + ry * math.sin(k * math.pi / 16))
                 for k in range(32)]]
    d = node.get("d")
    if not d:
        return []
    rings, ring, here, start = [], [], (0.0, 0.0), (0.0, 0.0)
    for letter, body in re.findall(r"([MmLlCcZz])([^MmLlCcZz]*)", d):
        nums = [float(v) for v in re.findall(r"-?\d*\.?\d+(?:[eE][-+]?\d+)?", body)]
        rel = letter.islower()
        if letter in "Zz":
            if ring:
                rings.append(ring)
            ring, here = [], start
        elif letter in "MmLl":
            for i in range(0, len(nums) - 1, 2):
                p = (here[0] + nums[i], here[1] + nums[i + 1]) if rel else (nums[i], nums[i + 1])
                if letter in "Mm" and i == 0:
                    if ring:
                        rings.append(ring)
                    ring, start = [p], p
                else:
                    ring.append(p)
                here = p
        else:
            for i in range(0, len(nums) - 5, 6):
                a, b, c = [(here[0] + nums[i + j], here[1] + nums[i + j + 1]) if rel
                           else (nums[i + j], nums[i + j + 1]) for j in (0, 2, 4)]
                for step in range(1, 7):
                    t = step / 6
                    u = 1 - t
                    ring.append(tuple(u ** 3 * h + 3 * u * u * t * p + 3 * u * t * t * q + t ** 3 * e
                                      for h, p, q, e in zip(here, a, b, c)))
                here = c
    if ring:
        rings.append(ring)
    return [[apply(m, *p) for p in r] for r in rings if len(r) > 2]


def inside(x: float, y: float, rings: list) -> bool:
    """Nonzero winding, which is how the drawings are filled."""
    wind = 0
    for ring in rings:
        for (x0, y0), (x1, y1) in zip(ring, ring[1:] + ring[:1]):
            side = (x1 - x0) * (y - y0) - (x - x0) * (y1 - y0)
            if y0 <= y < y1 and side > 0:
                wind += 1
            elif y1 <= y < y0 and side < 0:
                wind -= 1
    return wind != 0


def ball_inks(text: str) -> tuple:
    """The drawing's body — the colour that shows over most of it — and the most-seen colour
    lighter than that, each as the nearest Zuphy32 entry.

    **What shows, not what is drawn.** A ball is laid over a dark disc and crossed by seams,
    so counting shapes by size crowns the disc. The ball is sampled on a grid instead, and
    each point takes the colour of the topmost shape over it."""
    tree = ET.fromstring(text)
    shapes = []
    stack = [(tree, (1, 0, 0, 1, 0, 0), None)]
    while stack:
        node, up, fill = stack.pop(0)
        here = times(up, matrix(node))
        fill = fill_of(node, fill)
        if node.tag in DRAWN and fill:
            rings = outlines(node, here)
            if rings:
                xs = [p[0] for r in rings for p in r]
                ys = [p[1] for r in rings for p in r]
                shapes.append((fill, rings, (min(xs), min(ys), max(xs), max(ys))))
        stack = [(kid, here, fill) for kid in node] + stack
    x0, y0, x1, y1 = ink(text)
    seen: dict[str, int] = {}
    grid = 40
    for i in range(grid):
        for j in range(grid):
            x = x0 + (i + 0.5) * (x1 - x0) / grid
            y = y0 + (j + 0.5) * (y1 - y0) / grid
            for fill, rings, (bx0, by0, bx1, by1) in reversed(shapes):
                if bx0 <= x <= bx1 and by0 <= y <= by1 and inside(x, y, rings):
                    seen[fill] = seen.get(fill, 0) + 1
                    break
    body = max(seen, key=seen.get)
    bright = lambda code: sum(channels(code))
    lighter = [c for c in seen if bright(c) > bright(body)]
    light = max(lighter, key=seen.get) if lighter else body
    pixels = pixel_palette()
    body_name = nearest(body, pixels)[1]
    rest = {c: name for c, name in pixels.items() if name != body_name}
    light_name = nearest(light, rest if light == body or nearest(light, pixels)[1] == body_name
                         else pixels)[1]
    return body_name, light_name


def write_if_changed(target: pathlib.Path, text: str) -> bool:
    if target.exists() and target.read_text() == text:
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text)
    return True


def json_contents(filename: str) -> str:
    return ('{\n  "images" : [\n    {\n      "filename" : "%s",\n      "idiom" : "universal"\n'
            '    }\n  ],\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  },\n'
            '  "properties" : {\n    "preserves-vector-representation" : true,\n'
            '    "template-rendering-intent" : "original"\n  }\n}\n') % filename


INKS_TEMPLATE = """import SwiftUI

/// **The pixel ball's two colours, per Variaball in play.** `body` takes the sheet's
/// `ballShade`, which is most of the ball, and `light` its `ball`.
///
/// Listed by `Tools/icons.py` for any ball not yet here, off the nearest Zuphy32 entries
/// to the drawing's own body and highlight — and **never rewritten once listed**, so a
/// correction made on `BallBench` stays made.
enum BallSpriteInks {
    static let byBall: [String: (body: Color, light: Color)] = [
ROWS
    ]
}
"""


SIZES = root / "ProjectCardCourt/Art/BallSizes.swift"
SIZES_TEMPLATE = """import CoreGraphics

/// **How big each ball in play is against the plain one**, for the pixel ball — the drawings
/// already carry it, framed on the plain ball's side. Only the ones that differ are listed.
///
/// Written by `Tools/icons.py` on every run; measured off the drawings, so edit those.
enum BallSizes {
    static let share: [String: CGFloat] = TABLE
}
"""

if "Variaball" in boxes and subject:
    plain_ball = root / ICONS / "Balls" / "variaball.svg"
    edges = ink(plain_ball.read_text())
    BALL_SIDE = max(edges[2] - edges[0], edges[3] - edges[1]) / export_scale(plain_ball)
    sizes: dict[str, float] = {}
    ids = {svg.stem: folder.name[len("Ball-"): -len(".imageset")]
           for folder in ASSETS.glob("Ball-*.imageset") for svg in folder.glob("*.svg")}
    # **Never rewritten once listed**: an entry here may have been corrected on the bench.
    listed = {card: (body, light) for card, body, light in re.findall(
        r'"([\w-]+)": \(body: PixelPalette\.(\w+), light: PixelPalette\.(\w+)\)',
        INKS.read_text())} if INKS.exists() else {}
    added = []
    for path in sorted((root / ICONS / "Balls").glob("*.svg")):
        if path.stem in BALL_SKIPPED:
            print(f"{'in play/' + path.stem:18} skipped: {BALL_SKIPPED[path.stem]}")
            continue
        card = ids.get(path.stem)
        if card is None:
            print(f"  ! {path.name} has no Ball- asset to name its card", file=sys.stderr)
            continue
        trail = ball_trail(path, reference)
        text, sizes[card] = cut_out(path, trail)
        folder = ASSETS / f"BallInPlay-{card}.imageset"
        if write_if_changed(folder / path.name, text):
            moved += 1
        write_if_changed(folder / "Contents.json", json_contents(path.name))
        if card not in listed:
            listed[card] = ball_inks(text)
            added.append(card)
        print(f"{'in play/' + path.stem:18} group {list(trail)}  size {sizes[card]:.2f}  "
              f"sprite {listed[card][0]} over {listed[card][1]}{'  (new)' if card in added else ''}")
    differ = [(card, share) for card, share in sorted(sizes.items()) if abs(share - 1) > 0.02]
    table = ("[\n" + "\n".join(f'        "{card}": {share:.2f},' for card, share in differ)
             + "\n    ]") if differ else "[:]"
    write_if_changed(SIZES, SIZES_TEMPLATE.replace("TABLE", table))
    if added or not INKS.exists():
        rows = "\n".join(f'        "{card}": (body: PixelPalette.{b}, light: PixelPalette.{l}),'
                         for card, (b, l) in sorted(listed.items()))
        write_if_changed(INKS, INKS_TEMPLATE.replace("ROWS", rows))

print(f"\n{moved} file(s) rewritten, {snapped} fill(s) snapped to the palette")
