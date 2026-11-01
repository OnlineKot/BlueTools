import json
import math
import os
import sys
from io import BytesIO

import cairosvg
from PIL import Image, ImageChops, ImageFilter
from shapely import affinity
from shapely.geometry import Point, Polygon
from shapely.ops import unary_union

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
SIZE = 1024
BACKGROUND = (12, 30, 44)
BEAM = (40, 200, 190)
TARGET = (90, 235, 190)


def sector(origin, radius, center, half, rounding):
    ox, oy = origin
    points = [origin]
    for i in range(97):
        angle = math.radians(center - half + 2 * half * i / 96)
        points.append((ox + radius * math.cos(angle), oy + radius * math.sin(angle)))
    shape = Polygon(points)
    return shape.buffer(-rounding, join_style="round").buffer(rounding, join_style="round")


def build():
    origin = (318, 712)
    angle = -45
    beam = sector(origin, 570, angle, 27, 30)
    core = sector(origin, 385, angle, 27, 26)
    target = Point(origin[0] + 470 * math.cos(math.radians(angle)), origin[1] + 470 * math.sin(math.radians(angle))).buffer(68, resolution=96)
    source = Point(origin).buffer(46, resolution=96)
    minx, miny, maxx, maxy = unary_union([beam, target, source]).bounds
    dx = SIZE / 2 - (minx + maxx) / 2
    dy = SIZE / 2 - (miny + maxy) / 2
    move = lambda g: affinity.translate(g, dx, dy)
    return move(beam), move(core), move(source), move(target)


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


def background():
    return Image.new("RGBA", (SIZE, SIZE), BACKGROUND + (255,))


def tinted(alpha, rgb, opacity):
    layer = glass_layer(alpha, opacity)
    colored = Image.new("RGBA", (SIZE, SIZE), rgb + (255,))
    colored.putalpha(layer.split()[3])
    rim = layer.copy()
    rim.putalpha(ImageChops.subtract(layer.split()[3], alpha.point(lambda v: int(v * opacity))))
    colored.alpha_composite(rim)
    return colored


def glass_layer(alpha, opacity):
    white = Image.new("L", (SIZE, SIZE), 255)
    body = Image.merge("RGBA", (white, white, white, alpha.point(lambda v: int(v * opacity))))
    inner = alpha.filter(ImageFilter.MinFilter(7))
    edge = ImageChops.subtract(alpha, inner)
    lit = ImageChops.multiply(edge, ImageChops.invert(ImageChops.offset(alpha, 5, 7)))
    rim = lit.filter(ImageFilter.GaussianBlur(1.0)).point(lambda v: int(v * 0.9))
    body.alpha_composite(Image.merge("RGBA", (white, white, white, rim)))
    return body


def shadow(alpha, strength):
    layer = Image.merge("RGBA", (
        Image.new("L", (SIZE, SIZE), 6),
        Image.new("L", (SIZE, SIZE), 40),
        Image.new("L", (SIZE, SIZE), 70),
        alpha.point(lambda v: int(v * strength)),
    ))
    return ImageChops.offset(layer, 0, 18).filter(ImageFilter.GaussianBlur(22))


beam, core, source, target = build()
files = {"beam.svg": svg(beam), "core.svg": svg(core), "source.svg": svg(source), "target.svg": svg(target)}

icon_dir = os.path.join(ROOT, "BlueTools", "AppIcon.icon")
assets = os.path.join(icon_dir, "Assets")
os.makedirs(assets, exist_ok=True)
for name in os.listdir(assets):
    os.remove(os.path.join(assets, name))
for name, text in files.items():
    with open(os.path.join(assets, name), "w") as handle:
        handle.write(text)


def solid(rgb):
    return {"linear-gradient": [color(rgb), color(rgb)], "orientation": {"start": {"x": 0.5, "y": 0.0}, "stop": {"x": 0.5, "y": 1.0}}}


doc = {
    "fill": solid(BACKGROUND),
    "groups": [
        {
            "layers": [
                {"image-name": "target.svg", "name": "target", "glass": True, "fill": solid(TARGET)},
                {"image-name": "source.svg", "name": "source", "glass": True},
            ],
            "shadow": {"kind": "layer-color", "opacity": 0.5},
            "translucency": {"enabled": True, "value": 0.1},
        },
        {
            "layers": [
                {"image-name": "core.svg", "name": "core", "glass": True, "fill": solid(BEAM), "opacity": 0.6},
                {"image-name": "beam.svg", "name": "beam", "glass": True, "fill": solid(BEAM), "opacity": 0.4},
            ],
            "shadow": {"kind": "layer-color", "opacity": 0.35},
            "translucency": {"enabled": True, "value": 0.5},
        },
    ],
    "supported-platforms": {"squares": "shared"},
}
with open(os.path.join(icon_dir, "icon.json"), "w") as handle:
    json.dump(doc, handle, indent=2)

beam_a, core_a, source_a, target_a = (mask(files[n]) for n in ("beam.svg", "core.svg", "source.svg", "target.svg"))
out = background()
out.alpha_composite(shadow(beam_a, 0.15))
out.alpha_composite(tinted(beam_a, BEAM, 0.35))
out.alpha_composite(tinted(core_a, BEAM, 0.35))
out.alpha_composite(shadow(source_a, 0.4))
out.alpha_composite(shadow(target_a, 0.4))
out.alpha_composite(glass_layer(source_a, 0.97))
out.alpha_composite(tinted(target_a, TARGET, 1.0))
out.convert("RGB").save(os.path.join(ROOT, "BlueTools", "Assets.xcassets", "AppIcon.appiconset", "icon.png"))
