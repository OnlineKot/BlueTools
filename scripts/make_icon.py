import json
import math
import os
import sys
from io import BytesIO

import cairosvg
from PIL import Image, ImageChops, ImageFilter
from shapely import affinity
from shapely.geometry import LineString
from shapely.ops import unary_union

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
SIZE = 1024
BACKGROUND = (10, 124, 255)


def stroke(points, width):
    return LineString(points).buffer(width / 2, cap_style="round", join_style="round", resolution=32)


def arc(center, radius, start, end, width):
    cx, cy = center
    points = []
    for i in range(97):
        angle = math.radians(start + (end - start) * i / 96)
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return stroke(points, width)


def build():
    cx, cy, h, w = 0.0, 0.0, 470.0, 66.0
    r = h * 0.25
    top, bottom = (cx, cy - h / 2), (cx, cy + h / 2)
    rune = unary_union([
        stroke([top, bottom], w),
        stroke([(cx - r, cy + h / 4), (cx + r, cy - h / 4), top], w),
        stroke([(cx - r, cy - h / 4), (cx + r, cy + h / 4), bottom], w),
    ])
    near = arc((cx, cy), 250, -40, 40, 50)
    far = arc((cx, cy), 360, -36, 36, 50)
    rune, near, far = (affinity.scale(g, 0.86, 0.86, origin=(0, 0)) for g in (rune, near, far))
    minx, miny, maxx, maxy = unary_union([rune, near, far]).bounds
    dx = SIZE / 2 - (minx + maxx) / 2
    dy = SIZE / 2 - (miny + maxy) / 2
    move = lambda g: affinity.translate(g, dx, dy)
    return move(rune), move(near), move(far)


def path_data(geom):
    parts = []
    for poly in getattr(geom, "geoms", [geom]):
        for ring in [poly.exterior, *poly.interiors]:
            parts.append("M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in ring.coords) + " Z")
    return " ".join(parts)


def svg(geom):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
        f'<path d="{path_data(geom)}" fill="#FFFFFF" fill-rule="evenodd"/></svg>'
    )


def mask(svg_text):
    data = cairosvg.svg2png(bytestring=svg_text.encode(), output_width=SIZE, output_height=SIZE)
    return Image.open(BytesIO(data)).convert("RGBA").split()[3]


def color(rgb):
    return "srgb:" + ",".join(f"{c / 255:.5f}" for c in rgb) + ",1.00000"


def solid(rgb):
    return {"linear-gradient": [color(rgb), color(rgb)], "orientation": {"start": {"x": 0.5, "y": 0.0}, "stop": {"x": 0.5, "y": 1.0}}}


def white(alpha, opacity):
    full = Image.new("L", (SIZE, SIZE), 255)
    return Image.merge("RGBA", (full, full, full, alpha.point(lambda v: int(v * opacity))))


def shadow(alpha, strength):
    layer = Image.merge("RGBA", (
        Image.new("L", (SIZE, SIZE), 0),
        Image.new("L", (SIZE, SIZE), 30),
        Image.new("L", (SIZE, SIZE), 90),
        alpha.point(lambda v: int(v * strength)),
    ))
    return ImageChops.offset(layer, 0, 10).filter(ImageFilter.GaussianBlur(14))


rune, near, far = build()
files = {"rune.svg": svg(rune), "near.svg": svg(near), "far.svg": svg(far)}

icon_dir = os.path.join(ROOT, "BlueTools", "AppIcon.icon")
assets = os.path.join(icon_dir, "Assets")
os.makedirs(assets, exist_ok=True)
for name in os.listdir(assets):
    os.remove(os.path.join(assets, name))
for name, text in files.items():
    with open(os.path.join(assets, name), "w") as handle:
        handle.write(text)

doc = {
    "fill": solid(BACKGROUND),
    "groups": [
        {
            "layers": [{"image-name": "rune.svg", "name": "rune", "glass": True}],
            "shadow": {"kind": "neutral", "opacity": 0.5},
            "translucency": {"enabled": True, "value": 0.1},
        },
        {
            "layers": [
                {"image-name": "near.svg", "name": "near", "glass": True, "opacity": 0.75},
                {"image-name": "far.svg", "name": "far", "glass": True, "opacity": 0.45},
            ],
            "shadow": {"kind": "neutral", "opacity": 0.3},
            "translucency": {"enabled": True, "value": 0.4},
        },
    ],
    "supported-platforms": {"squares": "shared"},
}
with open(os.path.join(icon_dir, "icon.json"), "w") as handle:
    json.dump(doc, handle, indent=2)

rune_a, near_a, far_a = (mask(files[n]) for n in ("rune.svg", "near.svg", "far.svg"))
out = Image.new("RGBA", (SIZE, SIZE), BACKGROUND + (255,))
out.alpha_composite(shadow(rune_a, 0.25))
out.alpha_composite(white(far_a, 0.45))
out.alpha_composite(white(near_a, 0.75))
out.alpha_composite(white(rune_a, 1.0))
out.convert("RGB").save(os.path.join(ROOT, "BlueTools", "Assets.xcassets", "AppIcon.appiconset", "icon.png"))
