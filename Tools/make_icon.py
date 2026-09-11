"""Draws the app icon: the four PARA buckets as a 2x2 grid, the first one ticked
off, inside the gold goals frame, inside a white frame with a star on its top edge.

Run with `python3 Tools/make_icon.py` from the repo root; it writes every size the
asset catalogue asks for. This script *is* the icon — if it stops reproducing what
ships, the next change to the icon starts from guesswork (which is what happened
between builds 111 and 129, when the gold frame was added by a one-off script and
never written back here).
"""
import math
from PIL import Image, ImageDraw

SS = 4  # supersampling factor

INK_TOP = (48, 55, 61)       # slate ground, so all four hues read clearly
INK_BOTTOM = (20, 24, 27)
# Projects green, Areas pink, Resources blue, Archive grey: the app's own palette
TILES = ((95, 191, 146), (240, 127, 178), (111, 174, 232), (154, 154, 162))
CHECK_INK = (20, 24, 27)
GOLD = (229, 190, 85)        # the Goals colour, #E5BE55
WHITE = (255, 255, 255)

# Every measurement is a fraction of the art's own side, so the full-bleed iOS
# tile and the smaller macOS squircle draw the same picture.
GOLD_INSET, GOLD_LINE, GOLD_RADIUS = 0.1748, 0.0215, 0.1459   # radius is of the frame's side
WHITE_INSET, WHITE_LINE = 0.115, 0.0175
STAR_RADIUS, STAR_WAIST, STAR_SIT = 0.050, 0.42, 0.55  # sit: how far the centre rides above the line


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def gradient(size):
    g = Image.new("RGB", (1, size))
    px = g.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        px[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(INK_TOP, INK_BOTTOM))
    return g.resize((size, size), Image.BICUBIC)


def star_points(cx, cy, outer, inner, points=5):
    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        angle = -math.pi / 2 + i * math.pi / points
        pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    return pts


def draw_art(size):
    """The grid, the two frames and the star, on a transparent layer of `size`."""
    art = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(art)
    margin = size * 0.235
    gap = size * 0.052
    cell = (size - 2 * margin - gap) / 2
    radius = cell * 0.26
    for i, colour in enumerate(TILES):
        col, row = i % 2, i // 2
        x = margin + col * (cell + gap)
        y = margin + row * (cell + gap)
        d.rounded_rectangle([x, y, x + cell, y + cell], radius=radius, fill=colour + (255,))
    # tick on the first tile
    x0, y0 = margin, margin
    w = cell
    pts = [(x0 + w * 0.24, y0 + w * 0.52),
           (x0 + w * 0.44, y0 + w * 0.71),
           (x0 + w * 0.78, y0 + w * 0.30)]
    d.line(pts, fill=CHECK_INK + (255,), width=max(int(w * 0.13), 1), joint="curve")

    # the gold goals frame: everything inside it serves the goals around it
    gi = size * GOLD_INSET
    gside = size - 2 * gi
    d.rounded_rectangle([gi, gi, size - gi, size - gi], radius=gside * GOLD_RADIUS,
                        outline=GOLD + (255,), width=max(round(size * GOLD_LINE), 1))

    # the white frame outside it, drawn parallel, with the star on its top edge
    wi = size * WHITE_INSET
    wline = max(round(size * WHITE_LINE), 1)
    d.rounded_rectangle([wi, wi, size - wi, size - wi],
                        radius=gside * GOLD_RADIUS + (gi - wi),
                        outline=WHITE + (255,), width=wline)
    outer = size * STAR_RADIUS
    d.polygon(star_points(size / 2, wi + wline / 2 - outer * STAR_SIT, outer, outer * STAR_WAIST),
              fill=WHITE + (255,))
    return art


def render(size, rounded):
    """rounded=True gives the macOS squircle with padding; False is a full-bleed iOS tile."""
    big = size * SS
    if rounded:
        inset = round(big * 0.095)
        side = big - 2 * inset
        base = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        tile = gradient(side).convert("RGBA")
        tile.putalpha(rounded_mask(side, round(side * 0.225)))
        tile.alpha_composite(draw_art(side))
        base.alpha_composite(tile, (inset, inset))
    else:
        base = gradient(big).convert("RGBA")
        base.alpha_composite(draw_art(big))
    return base.resize((size, size), Image.LANCZOS)


OUT = "App/AMSPara/Assets.xcassets/AppIcon.appiconset"
for s in (16, 32, 64, 128, 256, 512, 1024):
    render(s, rounded=True).save(f"{OUT}/icon-mac-{s}.png")
render(1024, rounded=False).convert("RGB").save(f"{OUT}/icon-ios-1024.png")
print("icons written")
