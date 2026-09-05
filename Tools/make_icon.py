"""Draws the AMS PARA app icon: the four PARA buckets as a 2x2 grid,
the first one ticked off, on a deep green ground."""
from PIL import Image, ImageDraw

SS = 4  # supersampling factor

INK_TOP = (48, 55, 61)       # slate ground, so all four hues read clearly
INK_BOTTOM = (20, 24, 27)
# Projects green, Areas pink, Resources blue, Archive grey: the app's own palette
TILES = ((95, 191, 146), (240, 127, 178), (111, 174, 232), (154, 154, 162))
CHECK_INK = (20, 24, 27)

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

def draw_art(size):
    """The grid of four tiles, drawn on a transparent layer of `size`."""
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
