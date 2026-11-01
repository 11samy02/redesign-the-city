"""Building blocks for the event and penalty card pictures (see gen_cards.py).

A card picture is a 256x256 scene in the style of the game's tiles: a rim in the card's colour, a soft
backdrop, and on it the real tile illustrations (assets/tiles) and UI icons (assets/ui) next to small hand-drawn props.
Everything is plain shapes, gradients and groups, because Godot's SVG import ignores <text> and filters.
"""
import math
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join(ROOT, "assets", "tiles")
UI = os.path.join(ROOT, "assets", "ui")

INK = "#243447"
WHITE = "#F6F2E8"
PAPER = "#FBF7EA"
PAPER_D = "#E6DCC2"
LINE = "#B3A78A"
GOLD = "#F4BD35"
GOLD_D = "#B9810F"
RED = "#D4493A"
GREEN = "#4FA04C"
BLUE = "#3F7CC0"
WOOD = "#B07C47"
STEEL = "#9AA6B5"
ORANGE = "#F08A2E"
YELLOW = "#F7CB45"
DARK = "#34455A"
SKIN = "#F1C9A0"


def mix(hex_color, amount, toward="#FFFFFF"):
    a = [int(hex_color[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(toward[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02X%02X%02X" % tuple(round(a[i] + (b[i] - a[i]) * amount) for i in range(3))


def edge(fill):
    """The outline colour that goes with a fill: the same hue, darker."""
    if not fill.startswith("#"):
        return INK
    return mix(fill, 0.5, "#1B2733")


# ---------------------------------------------------------------- shapes with a matching outline

def path(d, fill="none", sw=3, line=None):
    stroke = f' stroke="{line or edge(fill)}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"' if sw and fill != "none" else (
        f' stroke="{line or INK}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"' if sw else "")
    return f'<path d="{d}" fill="{fill}"{stroke}/>'


def rect(x, y, w, h, r, fill, sw=3, line=None):
    s = f' stroke="{line or edge(fill)}" stroke-width="{sw}"' if sw else ""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"{s}/>'


def circle(cx, cy, r, fill, sw=3, line=None):
    s = f' stroke="{line or edge(fill)}" stroke-width="{sw}"' if sw else ""
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"{s}/>'


def ellipse(cx, cy, rx, ry, fill, sw=3, line=None):
    s = f' stroke="{line or edge(fill)}" stroke-width="{sw}"' if sw else ""
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}"{s}/>'


def poly(pts, fill, sw=3, line=None):
    s = f' stroke="{line or edge(fill)}" stroke-width="{sw}" stroke-linejoin="round"' if sw else ""
    return f'<polygon points="{" ".join(f"{x:g},{y:g}" for x, y in pts)}" fill="{fill}"{s}/>'


def line(x1, y1, x2, y2, sw=3, color=INK, cap="round"):
    if not sw:
        return ""
    return f'<path d="M{x1} {y1} L{x2} {y2}" fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="{cap}"/>'


def stroke_path(d, sw=4, color=INK, dash=None):
    extra = f' stroke-dasharray="{dash}"' if dash else ""
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"{extra}/>'


def shine(d, opacity=0.4):
    """A soft white highlight laid on top of a shape."""
    return f'<path d="{d}" fill="#FFFFFF" opacity="{opacity}"/>'


def group(body, x=0, y=0, s=1.0, r=0):
    return f'<g transform="translate({x:g} {y:g}) rotate({r:g}) scale({s:g})">{body}</g>'


def star_pts(cx, cy, r, inner=0.5, points=5):
    pts = []
    for k in range(points * 2):
        a = -math.pi / 2 + k * math.pi / points
        rr = r if k % 2 == 0 else r * inner
        pts.append((round(cx + rr * math.cos(a), 1), round(cy + rr * math.sin(a), 1)))
    return pts


# ---------------------------------------------------------------- embedded game art

_counter = [0]
_cache = {}


def _inner(path_):
    if path_ not in _cache:
        text = open(path_, encoding="utf-8").read().strip()
        size = float(re.search(r'viewBox="0 0 ([\d.]+)', text).group(1))
        inner = re.sub(r"^<svg[^>]*>", "", text, count=1)
        inner = inner[:inner.rindex("</svg>")]
        _cache[path_] = (inner, size)
    return _cache[path_]


def _embed(path_, x, y, s, r, shadow, tone):
    inner, size = _inner(path_)
    _counter[0] += 1
    pre = f"e{_counter[0]}_"
    for ident in set(re.findall(r'\bid="([^"]+)"', inner)):
        inner = inner.replace(f'id="{ident}"', f'id="{pre}{ident}"').replace(f"url(#{ident})", f"url(#{pre}{ident})")
    half = size / 2
    body = ""
    if shadow:
        body += f'<g transform="translate({x + 5 * s:g} {y + 8 * s:g}) rotate({r:g}) scale({s:g}) translate({-half:g} {-half:g})"><rect x="4" y="6" width="{size - 8:g}" height="{size - 8:g}" rx="{size * 0.11:g}" fill="#1B2733" opacity="0.28"/></g>'
    body += f'<g transform="translate({x:g} {y:g}) rotate({r:g}) scale({s:g}) translate({-half:g} {-half:g})">{inner}'
    if tone == "ghost":
        body += f'<rect x="3" y="3" width="{size - 6:g}" height="{size - 6:g}" rx="{size * 0.11:g}" fill="#F1EBDD" opacity="0.66"/>'
    elif tone == "night":
        body += f'<rect x="3" y="3" width="{size - 6:g}" height="{size - 6:g}" rx="{size * 0.11:g}" fill="#14213A" opacity="0.58"/>'
    elif tone == "warm":
        body += f'<rect x="3" y="3" width="{size - 6:g}" height="{size - 6:g}" rx="{size * 0.11:g}" fill="#F08A2E" opacity="0.22"/>'
    body += "</g>"
    return body


def tile(name, x, y, s=0.55, r=0, shadow=True, tone=None):
    return _embed(os.path.join(TILES, name + ".svg"), x, y, s, r, shadow, tone)


def ui(name, x, y, s=1.0, r=0):
    return _embed(os.path.join(UI, name + ".svg"), x, y, s, r, False, None)


# ---------------------------------------------------------------- the picture frame

class Pal:
    def __init__(self, tint):
        self.A = tint
        self.M = mix(tint, 0.45)
        self.L = mix(tint, 0.8)
        self.D = mix(tint, 0.45, "#1B2733")


def scene(tint, mood, body):
    """Wraps `body` in the tile-style frame. mood: gain (warm rays), loss (darker, vignette) or choice."""
    if mood == "loss":
        top, bottom = mix(tint, 0.3, "#1B2733"), mix(tint, 0.62)
    else:
        top, bottom = mix(tint, 0.5), mix(tint, 0.86)
    defs = (f'<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>'
            '<radialGradient id="vig" cx="0.5" cy="0.5" r="0.75"><stop offset="0.55" stop-color="#000000" stop-opacity="0"/><stop offset="1" stop-color="#0A1020" stop-opacity="0.38"/></radialGradient>'
            '<radialGradient id="glow" cx="0.5" cy="0.45" r="0.6"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.55"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>'
            '<clipPath id="inner"><rect x="10" y="10" width="236" height="236" rx="22"/></clipPath>')
    back = f'<rect x="3" y="3" width="250" height="250" rx="28" fill="{mix(tint, 0.1, "#1B2733")}"/>'
    back += '<rect x="10" y="10" width="236" height="236" rx="22" fill="url(#bg)"/>'
    layers = ""
    if mood == "gain":
        rays = ""
        for k in range(14):
            a0 = k * 2 * math.pi / 14
            a1 = a0 + math.pi / 14
            rays += f'<polygon points="128,122 {128 + 300 * math.cos(a0):.0f},{122 + 300 * math.sin(a0):.0f} {128 + 300 * math.cos(a1):.0f},{122 + 300 * math.sin(a1):.0f}" fill="#FFFFFF" opacity="0.2"/>'
        layers += rays
    if mood in ("gain", "choice"):
        layers += '<rect x="10" y="10" width="236" height="236" fill="url(#glow)"/>'
    if mood == "loss":
        layers += '<rect x="10" y="10" width="236" height="236" fill="url(#vig)"/>'
    layers += '<ellipse cx="128" cy="214" rx="104" ry="20" fill="#1B2733" opacity="0.16"/>'
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">'
        f'<defs>{defs}</defs>{back}<g clip-path="url(#inner)">{layers}{body}</g>'
        '<rect x="11.5" y="11.5" width="233" height="233" rx="21" fill="none" stroke="#FFFFFF" stroke-opacity="0.3" stroke-width="3"/></svg>\n'
    )
