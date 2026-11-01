import json
import math
import os
import sys

import cairosvg
from PIL import Image, ImageChops, ImageDraw, ImageFilter
from shapely import affinity
from shapely.geometry import LineString, Point, box
from shapely.ops import unary_union

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
SIZE = 1024
TOP = (24, 200, 255)
MID = (40, 110, 255)
BOTTOM = (138, 52, 250)


def arc(center, radius, start, end, width, steps=64):
    cx, cy = center
    points = []
    for i in range(steps + 1):
        a = math.radians(start + (end - start) * i / steps)
        points.append((cx + radius * math.cos(a), cy + radius * math.sin(a)))
    return LineString(points).buffer(width / 2, cap_style="round", join_style="round", resolution=32)


def build():
    head = Point(0, -170).buffer(172, resolution=96)
    handle = LineString([(0, -60), (0, 330)]).buffer(84, cap_style="round", resolution=48)
    slot = unary_union([box(-64, -420, 64, -170), Point(0, -170).buffer(64, resolution=64)])
    wrench = unary_union([head, handle]).difference(slot)
    waves = unary_union([
        arc((0, -230), 168, -132, -48, 58),
        arc((0, -230), 262, -128, -52, 58),
    ])
    wrench = affinity.rotate(wrench, 40, origin=(0, 0))
    waves = affinity.rotate(waves, 40, origin=(0, 0))
    both = unary_union([wrench, waves])
    minx, miny, maxx, maxy = both.bounds
    scale = 640 / max(maxx - minx, maxy - miny)
    cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
    def place(geom):
        g = affinity.translate(geom, -cx, -cy)
        g = affinity.scale(g, scale, scale, origin=(0, 0))
        return affinity.translate(g, SIZE / 2, SIZE / 2 + 8)
    return place(wrench), place(waves)


def path_data(geom):
    polys = getattr(geom, "geoms", [geom])
    parts = []
    for poly in polys:
        for ring in [poly.exterior, *poly.interiors]:
            coords = list(ring.coords)
            parts.append("M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in coords) + " Z")
    return " ".join(parts)


def svg(geom, color="#FFFFFF", opacity=1.0):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
        f'<path d="{path_data(geom)}" fill="{color}" fill-opacity="{opacity}" fill-rule="evenodd"/></svg>'
    )


def color(rgb):
    return "srgb:" + ",".join(f"{c / 255:.5f}" for c in rgb) + ",1.00000"


def layer_image(svg_text):
    data = cairosvg.svg2png(bytestring=svg_text.encode(), output_width=SIZE, output_height=SIZE)
    from io import BytesIO
    return Image.open(BytesIO(data)).convert("RGBA")


def background():
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x * 0.35 + y * 0.65) / SIZE
            if t < 0.5:
                a, b, k = TOP, MID, t / 0.5
            else:
                a, b, k = MID, BOTTOM, (t - 0.5) / 0.5
            px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))
    return img.convert("RGBA")


def glass(mask, tint_alpha):
    alpha = mask.split()[3]
    body = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    grad = Image.linear_gradient("L").resize((SIZE, SIZE))
    fill = Image.merge("RGBA", (
        Image.new("L", (SIZE, SIZE), 255),
        Image.new("L", (SIZE, SIZE), 255),
        Image.new("L", (SIZE, SIZE), 255),
        grad.point(lambda v: int(tint_alpha - v * 0.08)),
    ))
    body = Image.composite(fill, body, alpha)
    edge = ImageChops.subtract(alpha, alpha.filter(ImageFilter.MinFilter(9)))
    shifted = ImageChops.offset(alpha, 6, 8)
    rim = ImageChops.multiply(edge, ImageChops.invert(shifted))
    rim = rim.filter(ImageFilter.GaussianBlur(1.2))
    highlight = Image.merge("RGBA", (Image.new("L", (SIZE, SIZE), 255),) * 3 + (rim,))
    body.alpha_composite(highlight)
    return body


def shadow(mask, opacity):
    alpha = mask.split()[3].point(lambda v: int(v * opacity))
    layer = Image.merge("RGBA", (Image.new("L", (SIZE, SIZE), 20), Image.new("L", (SIZE, SIZE), 10), Image.new("L", (SIZE, SIZE), 70), alpha))
    layer = ImageChops.offset(layer, 0, 22).filter(ImageFilter.GaussianBlur(26))
    return layer


wrench, waves = build()
wrench_svg = svg(wrench)
waves_svg = svg(waves)

icon_dir = os.path.join(ROOT, "BlueTools", "AppIcon.icon")
os.makedirs(os.path.join(icon_dir, "Assets"), exist_ok=True)
open(os.path.join(icon_dir, "Assets", "wrench.svg"), "w").write(wrench_svg)
open(os.path.join(icon_dir, "Assets", "waves.svg"), "w").write(waves_svg)
doc = {
    "fill": {
        "linear-gradient": [color(TOP), color(BOTTOM)],
        "orientation": {"start": {"x": 0.3, "y": 0.0}, "stop": {"x": 0.7, "y": 1.0}},
    },
    "groups": [
        {
            "layers": [{"image-name": "waves.svg", "name": "waves", "glass": True, "opacity": 0.85}],
            "shadow": {"kind": "neutral", "opacity": 0.5},
            "translucency": {"enabled": True, "value": 0.35},
        },
        {
            "layers": [{"image-name": "wrench.svg", "name": "wrench", "glass": True}],
            "shadow": {"kind": "neutral", "opacity": 0.5},
            "translucency": {"enabled": True, "value": 0.2},
        },
    ],
    "supported-platforms": {"squares": "shared"},
}
with open(os.path.join(icon_dir, "icon.json"), "w") as handle:
    json.dump(doc, handle, indent=2)

wrench_mask = layer_image(wrench_svg)
waves_mask = layer_image(waves_svg)
out = background()
out.alpha_composite(shadow(wrench_mask, 0.45))
out.alpha_composite(shadow(waves_mask, 0.35))
out.alpha_composite(glass(waves_mask, 225))
out.alpha_composite(glass(wrench_mask, 252))
out.convert("RGB").save(os.path.join(ROOT, "BlueTools", "Assets.xcassets", "AppIcon.appiconset", "icon.png"))
