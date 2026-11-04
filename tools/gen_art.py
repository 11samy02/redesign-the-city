"""Generates every tile and UI SVG for Redesign the City.

Run from the project root:  python tools/gen_art.py
Tiles are 256x256 with an oblique (3/4) view for buildings and a top-down
view for ground, so road arms meet cleanly between neighbouring tiles.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join(ROOT, "assets", "tiles")
UI = os.path.join(ROOT, "assets", "ui")

# Palette
WHITE = "#F8F4EA"
WHITE_SIDE = "#D8CFBE"
WHITE_TOP = "#ECE5D6"
SHUTTER = "#2E6DA4"
SHUTTER_DARK = "#1F4E78"
GLASS = "#9CC9E8"
GLASS_DARK = "#5E93BD"
TERRACOTTA = "#C65A35"
TERRACOTTA_DARK = "#9A4226"
BOUG = "#D6337A"
BOUG_LIGHT = "#EE6AA5"
LEAF = "#5E9B3A"
LEAF_DARK = "#3F7228"
LEAF_LIGHT = "#86BE52"
OLIVE = "#93A86A"
OLIVE_DARK = "#6B7F48"
CYPRESS = "#2F5D34"
CYPRESS_LIGHT = "#457A45"
TRUNK = "#7A5536"
GOLD = "#F2B630"
INK = "#20313F"
SHADOW = "#1B2733"

CATEGORY = {
    "building": {"rim": "#A9603E", "g1": "#F1E6CD", "g2": "#E0CFAD", "line": "#D3C19C"},
    "amenity": {"rim": "#2A6496", "g1": "#ECE4D2", "g2": "#D9CCB2", "line": "#CBBC9E"},
    "green": {"rim": "#4C7F2B", "g1": "#A3D163", "g2": "#7FB346", "line": "#74A53F"},
    "road": {"rim": "#59616F", "g1": "#E0D6C1", "g2": "#CFC2A7", "line": "#BFB196"},
}


def svg(body, size=256, defs=""):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 {size} {size}"><defs>{defs}</defs>{body}</svg>\n'
    )


def lin(id_, c1, c2, x1=0, y1=0, x2=0, y2=1):
    return (
        f'<linearGradient id="{id_}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
        f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>'
    )


def rad(id_, c1, c2, cx=0.35, cy=0.3, r=0.75):
    return (
        f'<radialGradient id="{id_}" cx="{cx}" cy="{cy}" r="{r}">'
        f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></radialGradient>'
    )


def frame(cat, paving=True):
    """Tile base: rim, ground gradient, subtle paving joints, inner highlight."""
    c = CATEGORY[cat]
    defs = lin("ground", c["g1"], c["g2"])
    body = f'<rect x="3" y="3" width="250" height="250" rx="28" fill="{c["rim"]}"/>'
    body += '<rect x="10" y="10" width="236" height="236" rx="22" fill="url(#ground)"/>'
    if paving:
        lines = ""
        for i in range(1, 6):
            p = 10 + i * 236 / 6
            lines += f'<line x1="14" y1="{p:.1f}" x2="242" y2="{p:.1f}"/>'
            lines += f'<line x1="{p:.1f}" y1="14" x2="{p:.1f}" y2="242"/>'
        body += f'<g stroke="{c["line"]}" stroke-width="1.5" opacity="0.55">{lines}</g>'
    body += '<rect x="11.5" y="11.5" width="233" height="233" rx="21" fill="none" stroke="#FFFFFF" stroke-opacity="0.28" stroke-width="3"/>'
    return defs, body


def grass_tufts(points, color=LEAF_DARK):
    out = ""
    for x, y in points:
        out += (
            f'<path d="M{x-6} {y} q2 -9 4 -1 q1 -11 4 0 q2 -8 4 1" fill="none" stroke="{color}" '
            f'stroke-width="2.4" stroke-linecap="round" opacity="0.7"/>'
        )
    return out


def ground_shadow(points):
    pts = " ".join(f"{x},{y}" for x, y in points)
    return f'<polygon points="{pts}" fill="{SHADOW}" opacity="0.22"/>'


def box(x, y, w, h, dx, dy, front, side, top):
    """Oblique box: front face at (x,y,w,h), depth towards upper right."""
    return (
        f'<polygon points="{x+w},{y} {x+w+dx},{y-dy} {x+w+dx},{y+h-dy} {x+w},{y+h}" fill="{side}"/>'
        f'<polygon points="{x},{y} {x+dx},{y-dy} {x+w+dx},{y-dy} {x+w},{y}" fill="{top}"/>'
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{front}"/>'
    )


def window(x, y, w=22, h=28, shutters=True):
    out = ""
    if shutters:
        out += f'<rect x="{x-9}" y="{y}" width="8" height="{h}" rx="1.5" fill="{SHUTTER}"/>'
        out += f'<rect x="{x+w+1}" y="{y}" width="8" height="{h}" rx="1.5" fill="{SHUTTER}"/>'
        for k in range(3):
            yy = y + 6 + k * (h - 8) / 3
            out += f'<line x1="{x-8}" y1="{yy:.1f}" x2="{x-2}" y2="{yy:.1f}" stroke="{SHUTTER_DARK}" stroke-width="1.2"/>'
            out += f'<line x1="{x+w+2}" y1="{yy:.1f}" x2="{x+w+8}" y2="{yy:.1f}" stroke="{SHUTTER_DARK}" stroke-width="1.2"/>'
    out += f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="2" fill="url(#glass)"/>'
    out += f'<line x1="{x+w/2}" y1="{y}" x2="{x+w/2}" y2="{y+h}" stroke="{WHITE}" stroke-width="2"/>'
    out += f'<rect x="{x-2}" y="{y+h}" width="{w+4}" height="4" fill="{WHITE_SIDE}"/>'
    return out


def door(x, y, w=22, h=36, color=SHUTTER, arch=True):
    r = w / 2
    if arch:
        d = f"M{x} {y+h} V{y+r} A{r} {r} 0 0 1 {x+w} {y+r} V{y+h} Z"
    else:
        d = f"M{x} {y+h} V{y} H{x+w} V{y+h} Z"
    out = f'<path d="{d}" fill="{color}"/>'
    out += f'<line x1="{x+w/2}" y1="{y+(r if arch else 0)+2}" x2="{x+w/2}" y2="{y+h}" stroke="{SHUTTER_DARK}" stroke-width="1.5"/>'
    out += f'<circle cx="{x+w/2+4}" cy="{y+h*0.62}" r="1.8" fill="{GOLD}"/>'
    return out


def person(x, y, shirt, skin="#E8B48A", hair="#3B2A20", s=1.0):
    """Citizen figure standing with feet at (x, y)."""
    return (
        f'<g transform="translate({x} {y}) scale({s})">'
        f'<ellipse cx="2" cy="1" rx="10" ry="3.2" fill="{SHADOW}" opacity="0.3"/>'
        f'<rect x="-5.5" y="-14" width="4.5" height="14" rx="2" fill="{INK}"/>'
        f'<rect x="1" y="-14" width="4.5" height="14" rx="2" fill="{INK}"/>'
        f'<rect x="-8" y="-31" width="16" height="20" rx="7" fill="{shirt}"/>'
        f'<circle cx="0" cy="-38" r="7" fill="{skin}"/>'
        f'<path d="M-7 -39 a7 7 0 0 1 14 0 q-7 -4 -14 0z" fill="{hair}"/>'
        f"</g>"
    )


def bougainvillea(cx, cy, n=7, spread=14):
    import random
    rnd = random.Random(cx * 31 + cy)
    out = ""
    for _ in range(n):
        x = cx + rnd.uniform(-spread, spread)
        y = cy + rnd.uniform(-spread * 0.45, spread * 0.45)
        r = rnd.uniform(4, 7)
        col = BOUG if rnd.random() < 0.6 else BOUG_LIGHT
        out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{col}"/>'
    for _ in range(3):
        x = cx + rnd.uniform(-spread, spread)
        y = cy + rnd.uniform(-spread * 0.4, spread * 0.4)
        out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.5" fill="{LEAF}"/>'
    return out


def pot_plant(x, y):
    return (
        f'<ellipse cx="{x+2}" cy="{y+1}" rx="11" ry="3.5" fill="{SHADOW}" opacity="0.25"/>'
        f'<path d="M{x-8} {y-14} h16 l-3 14 h-10 z" fill="{TERRACOTTA}"/>'
        f'<rect x="{x-9}" y="{y-16}" width="18" height="4" rx="1.5" fill="{TERRACOTTA_DARK}"/>'
        f'<circle cx="{x-5}" cy="{y-21}" r="7" fill="{LEAF}"/><circle cx="{x+5}" cy="{y-22}" r="7" fill="{LEAF_LIGHT}"/>'
        f'<circle cx="{x}" cy="{y-28}" r="7" fill="{LEAF}"/>'
    )


def solar_heater(x, y):
    """Rooftop solar water heater: tilted panel plus white tank (very Cypriot)."""
    return (
        f'<polygon points="{x},{y} {x+30},{y} {x+38},{y-16} {x+8},{y-16}" fill="#26384A"/>'
        f'<g stroke="#5C7C99" stroke-width="1.2"><line x1="{x+10}" y1="{y}" x2="{x+18}" y2="{y-16}"/>'
        f'<line x1="{x+20}" y1="{y}" x2="{x+28}" y2="{y-16}"/></g>'
        f'<rect x="{x+6}" y="{y-28}" width="30" height="11" rx="5.5" fill="{WHITE}" stroke="{WHITE_SIDE}" stroke-width="1.5"/>'
    )


GLASS_DEFS = lin("glass", GLASS, GLASS_DARK)


# ---------------------------------------------------------------- buildings

def apartment_small():
    d, b = frame("building")
    d += GLASS_DEFS + lin("roof", "#D86B44", TERRACOTTA_DARK)
    b += ground_shadow([(76, 210), (196, 210), (222, 196), (198, 120)])
    b += box(64, 132, 112, 78, 22, 14, WHITE, WHITE_SIDE, WHITE_TOP)
    # pitched terracotta roof
    b += f'<polygon points="56,136 184,136 166,98 76,98" fill="url(#roof)"/>'
    b += f'<polygon points="184,136 206,122 188,86 166,98" fill="{TERRACOTTA_DARK}"/>'
    b += f'<polygon points="76,98 166,98 188,86 98,86" fill="#B04E2D"/>'
    for i in range(1, 4):
        y = 98 + i * 9.5
        b += f'<line x1="{76 - i*5}" y1="{y}" x2="{166 + i*5}" y2="{y}" stroke="{TERRACOTTA_DARK}" stroke-width="2" opacity="0.6"/>'
    b += door(80, 166, 24, 44)
    b += window(132, 156, 24, 28)
    b += bougainvillea(70, 140, 8, 14)
    b += pot_plant(54, 222)
    b += person(176, 226, "#E0533A")
    b += grass_tufts([(36, 60), (214, 52), (40, 112)])
    return svg(b, defs=d)


def apartment_medium():
    d, b = frame("building")
    d += GLASS_DEFS
    b += ground_shadow([(60, 214), (180, 214), (214, 194), (200, 86)])
    b += box(56, 92, 124, 122, 24, 15, WHITE, WHITE_SIDE, WHITE_TOP)
    # parapet + solar heater on the roof
    b += f'<polygon points="56,92 80,77 204,77 180,92" fill="none" stroke="{WHITE_SIDE}" stroke-width="3"/>'
    b += solar_heater(118, 86)
    # upper floor with balcony
    b += window(76, 104, 22, 30)
    b += window(138, 104, 22, 30)
    b += f'<rect x="60" y="138" width="116" height="5" fill="{WHITE_SIDE}"/>'
    rails = "".join(f'<line x1="{x}" y1="138" x2="{x}" y2="152" />' for x in range(64, 176, 8))
    b += f'<g stroke="{SHUTTER_DARK}" stroke-width="2">{rails}</g>'
    b += f'<line x1="60" y1="138" x2="176" y2="138" stroke="{SHUTTER_DARK}" stroke-width="3"/>'
    b += bougainvillea(70, 146, 8, 12)
    b += bougainvillea(164, 144, 6, 10)
    # ground floor
    b += door(106, 172, 24, 42)
    b += window(72, 174, 20, 26, shutters=False)
    b += window(146, 174, 20, 26, shutters=False)
    b += person(40, 230, "#3A8DDE")
    b += person(206, 232, "#F2B630", skin="#C98E66", hair="#1E1A17")
    b += pot_plant(188, 214)
    return svg(b, defs=d)


def apartment_large():
    d, b = frame("building")
    d += GLASS_DEFS
    front, side, top = "#F4E1C1", "#D7BE98", "#EBD7B5"
    b += ground_shadow([(48, 222), (168, 222), (216, 200), (196, 48)])
    b += box(48, 52, 124, 170, 26, 16, front, side, top)
    b += solar_heater(60, 46)
    b += solar_heater(118, 46)
    # four floors of windows with balconies
    for f, y in enumerate([62, 98, 134]):
        for x in [64, 101, 138]:
            b += f'<rect x="{x-2}" y="{y}" width="26" height="26" rx="2" fill="url(#glass)"/>'
            b += f'<line x1="{x+11}" y1="{y}" x2="{x+11}" y2="{y+26}" stroke="{front}" stroke-width="2"/>'
        b += f'<rect x="52" y="{y+26}" width="116" height="4" fill="{side}"/>'
        rails = "".join(f'<line x1="{x}" y1="{y+18}" x2="{x}" y2="{y+28}"/>' for x in range(56, 168, 7))
        b += f'<g stroke="{SHUTTER_DARK}" stroke-width="1.8">{rails}</g>'
        b += f'<line x1="52" y1="{y+18}" x2="168" y2="{y+18}" stroke="{SHUTTER_DARK}" stroke-width="2.5"/>'
    b += bougainvillea(62, 154, 7, 10)
    b += bougainvillea(156, 118, 6, 9)
    # glass entrance
    b += f'<rect x="92" y="176" width="36" height="46" rx="3" fill="{SHUTTER}"/>'
    b += f'<rect x="96" y="180" width="13" height="42" fill="url(#glass)"/><rect x="111" y="180" width="13" height="42" fill="url(#glass)"/>'
    b += f'<rect x="86" y="170" width="48" height="7" rx="2" fill="{TERRACOTTA}"/>'
    b += window(62, 182, 18, 24, shutters=False)
    b += window(142, 182, 18, 24, shutters=False)
    b += person(196, 232, "#8DBB3C")
    b += person(218, 222, "#A15CC9", skin="#D9A27A", hair="#6B3A1E", s=0.9)
    b += person(30, 232, "#E0533A", skin="#C98E66", hair="#1E1A17")
    return svg(b, defs=d)


# ---------------------------------------------------------------- amenities

def amenity_cafe():
    d, b = frame("amenity")
    d += GLASS_DEFS
    b += ground_shadow([(48, 172), (186, 172), (218, 152), (200, 92)])
    b += box(46, 96, 140, 76, 26, 16, WHITE, WHITE_SIDE, WHITE_TOP)
    # striped awning
    stripes = ""
    for i in range(10):
        col = SHUTTER if i % 2 == 0 else WHITE
        x = 40 + i * 15.2
        stripes += f'<polygon points="{x},108 {x+15.2},108 {x+15.2},126 {x},126" fill="{col}"/>'
    b += f'<polygon points="40,108 192,108 186,98 46,98" fill="{SHUTTER_DARK}"/>'
    b += stripes
    scallops = "".join(f'<circle cx="{40 + i*15.2 + 7.6:.1f}" cy="126" r="7.6" fill="{SHUTTER if i % 2 == 0 else WHITE}"/>' for i in range(10))
    b += scallops
    b += f'<rect x="58" y="138" width="44" height="34" rx="2" fill="url(#glass)"/>'
    b += f'<rect x="130" y="138" width="44" height="34" rx="2" fill="url(#glass)"/>'
    b += door(107, 136, 20, 36)
    # coffee cup sign
    b += f'<circle cx="116" cy="70" r="22" fill="{TERRACOTTA}" stroke="{WHITE}" stroke-width="4"/>'
    b += f'<path d="M104 64 h20 v8 a10 10 0 0 1 -20 0 z" fill="{WHITE}"/>'
    b += f'<path d="M124 66 a5 5 0 0 1 0 10" fill="none" stroke="{WHITE}" stroke-width="3"/>'
    b += f'<path d="M110 58 q-3 -5 0 -9 M116 58 q-3 -5 0 -9" fill="none" stroke="{WHITE}" stroke-width="2" stroke-linecap="round"/>'
    b += f'<line x1="116" y1="92" x2="116" y2="96" stroke="{INK}" stroke-width="2"/>'
    # tables with umbrellas
    for x, col in [(66, BOUG), (176, GOLD)]:
        b += f'<ellipse cx="{x+3}" cy="226" rx="24" ry="6" fill="{SHADOW}" opacity="0.25"/>'
        b += f'<line x1="{x}" y1="186" x2="{x}" y2="222" stroke="{INK}" stroke-width="2.5"/>'
        b += f'<ellipse cx="{x}" cy="214" rx="14" ry="4.5" fill="{WHITE}" stroke="{WHITE_SIDE}" stroke-width="2"/>'
        b += f'<path d="M{x-26} 192 Q{x} 168 {x+26} 192 Z" fill="{col}"/>'
        b += f'<path d="M{x-26} 192 Q{x-13} 186 {x} 192 Q{x+13} 186 {x+26} 192" fill="none" stroke="{WHITE}" stroke-width="2"/>'
        b += f'<rect x="{x-22}" y="210" width="7" height="12" rx="2" fill="{TERRACOTTA_DARK}"/>'
        b += f'<rect x="{x+15}" y="210" width="7" height="12" rx="2" fill="{TERRACOTTA_DARK}"/>'
    b += person(122, 232, "#E0533A", s=0.9)
    return svg(b, defs=d)


def amenity_clinic():
    d, b = frame("amenity")
    d += GLASS_DEFS
    b += ground_shadow([(54, 210), (186, 210), (218, 190), (204, 70)])
    b += box(54, 78, 132, 132, 24, 15, WHITE, WHITE_SIDE, WHITE_TOP)
    # green cross sign
    b += f'<rect x="96" y="40" width="48" height="48" rx="10" fill="{WHITE}" stroke="{WHITE_SIDE}" stroke-width="3"/>'
    b += f'<path d="M113 48 h14 v13 h13 v14 h-13 v13 h-14 v-13 h-13 v-14 h13z" fill="#2FA05A"/>'
    for x in [70, 104, 140]:
        b += f'<rect x="{x}" y="100" width="26" height="30" rx="2" fill="url(#glass)"/>'
        b += f'<rect x="{x-2}" y="130" width="30" height="4" fill="{WHITE_SIDE}"/>'
    b += f'<rect x="54" y="142" width="132" height="10" fill="#2FA05A"/>'
    # double doors and canopy
    b += f'<rect x="94" y="164" width="52" height="46" rx="3" fill="url(#glass)" stroke="{SHUTTER}" stroke-width="3"/>'
    b += f'<line x1="120" y1="164" x2="120" y2="210" stroke="{SHUTTER}" stroke-width="3"/>'
    b += f'<polygon points="86,160 154,160 162,152 94,152" fill="{SHUTTER}"/>'
    b += window(66, 168, 18, 24, shutters=False)
    b += window(158, 168, 18, 24, shutters=False)
    # ramp (accessibility)
    b += f'<polygon points="146,210 186,210 186,204 160,204" fill="{WHITE_SIDE}"/>'
    b += f'<rect x="28" y="216" width="40" height="7" rx="2" fill="{TRUNK}"/>'
    b += f'<rect x="32" y="222" width="4" height="8" fill="{INK}"/><rect x="60" y="222" width="4" height="8" fill="{INK}"/>'
    b += person(206, 232, "#3A8DDE", s=0.9)
    b += pot_plant(80, 232)
    return svg(b, defs=d)


def amenity_school():
    d, b = frame("amenity")
    d += GLASS_DEFS
    front, side, top = "#F0D58C", "#D4B567", "#E6C979"
    b += ground_shadow([(32, 186), (196, 186), (226, 168), (210, 100)])
    b += box(32, 104, 164, 82, 26, 16, front, side, top)
    # central bell gable
    b += f'<polygon points="92,104 92,72 114,50 136,72 136,104" fill="{front}"/>'
    b += f'<polygon points="88,74 114,46 140,74 136,78 114,54 92,78" fill="{TERRACOTTA}"/>'
    b += f'<circle cx="114" cy="80" r="11" fill="{WHITE}" stroke="{SHUTTER_DARK}" stroke-width="2.5"/>'
    b += f'<path d="M114 80 V73 M114 80 h6" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>'
    # pennant
    b += f'<line x1="214" y1="70" x2="214" y2="150" stroke="{INK}" stroke-width="2.5"/>'
    b += f'<polygon points="214,72 240,80 214,90" fill="{BOUG}"/>'
    for x in [44, 72, 146, 172]:
        b += f'<rect x="{x}" y="118" width="20" height="26" rx="2" fill="url(#glass)"/>'
        b += f'<line x1="{x}" y1="131" x2="{x+20}" y2="131" stroke="{front}" stroke-width="2"/>'
    b += door(102, 140, 24, 46, SHUTTER)
    b += f'<rect x="32" y="156" width="164" height="4" fill="{side}"/>'
    # hopscotch on the paving
    hs = ""
    for i, (x, y) in enumerate([(70, 210), (90, 210), (80, 196)]):
        hs += f'<rect x="{x}" y="{y}" width="18" height="13" fill="none" stroke="{WHITE}" stroke-width="2.5"/>'
    b += hs
    b += person(140, 232, "#E0533A", s=0.8)
    b += person(168, 228, "#8DBB3C", skin="#C98E66", hair="#1E1A17", s=0.8)
    b += person(196, 236, "#3A8DDE", s=0.8)
    return svg(b, defs=d)


def amenity_market():
    d, b = frame("amenity")
    b += ground_shadow([(36, 196), (206, 196), (228, 180), (214, 108)])
    # back wall of stall
    b += box(42, 104, 160, 74, 22, 14, WHITE, WHITE_SIDE, WHITE_TOP)
    stripes = ""
    for i in range(10):
        col = "#2FA05A" if i % 2 == 0 else WHITE
        x = 34 + i * 17.6
        stripes += f'<polygon points="{x},88 {x+17.6},88 {x+17.6},112 {x},112" fill="{col}"/>'
    b += f'<polygon points="34,88 210,88 226,76 50,76" fill="#23804A"/>'
    b += stripes
    b += "".join(f'<path d="M{34 + i*17.6:.1f} 112 q8.8 10 17.6 0" fill="{"#2FA05A" if i % 2 == 0 else WHITE}"/>' for i in range(10))
    b += f'<rect x="40" y="112" width="5" height="84" fill="{TRUNK}"/><rect x="200" y="112" width="5" height="84" fill="{TRUNK}"/>'
    # crates of produce
    def crate(x, y, fruit, dark, r=6.5):
        out = f'<rect x="{x}" y="{y}" width="46" height="26" rx="2" fill="#B07A45" stroke="#7A5232" stroke-width="2"/>'
        out += f'<line x1="{x}" y1="{y+13}" x2="{x+46}" y2="{y+13}" stroke="#7A5232" stroke-width="1.5"/>'
        for i in range(4):
            out += f'<circle cx="{x+7+i*10.7:.1f}" cy="{y-2}" r="{r}" fill="{fruit}" stroke="{dark}" stroke-width="1"/>'
        for i in range(3):
            out += f'<circle cx="{x+12+i*10.7:.1f}" cy="{y-9}" r="{r}" fill="{fruit}" stroke="{dark}" stroke-width="1"/>'
        return out
    b += crate(52, 160, "#F28C28", "#C66A12")
    b += crate(102, 160, "#F4D23C", "#C9A61C")
    b += crate(152, 160, "#D6403A", "#9E2A26")
    # watermelons + scale
    b += f'<ellipse cx="62" cy="214" rx="17" ry="12" fill="#3F8A3A" stroke="#2C6A2A" stroke-width="2"/>'
    b += f'<path d="M50 210 q12 -8 24 0 M48 216 q14 -8 28 0" fill="none" stroke="#79C060" stroke-width="2"/>'
    b += f'<ellipse cx="92" cy="220" rx="14" ry="10" fill="#3F8A3A" stroke="#2C6A2A" stroke-width="2"/>'
    b += f'<rect x="168" y="208" width="30" height="16" rx="3" fill="{SHUTTER}"/><circle cx="183" cy="204" r="9" fill="{WHITE}" stroke="{SHUTTER_DARK}" stroke-width="2"/>'
    b += person(134, 234, "#A15CC9", s=0.9)
    return svg(b, defs=d)


# ---------------------------------------------------------------- green

def round_tree(cx, cy, r, c1=LEAF, c2=LEAF_DARK, hl=LEAF_LIGHT):
    return (
        f'<ellipse cx="{cx+r*0.35}" cy="{cy+r*0.45}" rx="{r}" ry="{r*0.8}" fill="{SHADOW}" opacity="0.25"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{c2}"/>'
        f'<circle cx="{cx-r*0.12}" cy="{cy-r*0.12}" r="{r*0.84}" fill="{c1}"/>'
        f'<circle cx="{cx-r*0.32}" cy="{cy-r*0.34}" r="{r*0.38}" fill="{hl}"/>'
    )


def park():
    d, b = frame("green", paving=False)
    d += rad("water", "#9FDDF5", "#3C9BCB", 0.4, 0.35, 0.7)
    # winding paths
    b += f'<path d="M10 172 C70 160 92 128 128 128 C164 128 186 96 246 84" fill="none" stroke="#E6D7B6" stroke-width="22" stroke-linecap="round"/>'
    b += f'<path d="M128 10 C128 60 128 90 128 128 C128 170 110 200 96 246" fill="none" stroke="#E6D7B6" stroke-width="18" stroke-linecap="round"/>'
    # fountain
    b += f'<circle cx="128" cy="128" r="34" fill="#D2C4A4"/><circle cx="128" cy="128" r="27" fill="url(#water)"/>'
    b += f'<circle cx="128" cy="128" r="9" fill="#D2C4A4"/><circle cx="128" cy="124" r="5" fill="#BFE9F8"/>'
    b += f'<path d="M110 124 q6 -6 12 0 M134 136 q6 -6 12 0" stroke="#E8F7FD" stroke-width="2" fill="none"/>'
    # flower beds
    for cx, cy in [(64, 92), (196, 176)]:
        b += f'<ellipse cx="{cx}" cy="{cy}" rx="22" ry="13" fill="{LEAF_DARK}"/>'
        for i, (dx, dy) in enumerate([(-12, -3), (-4, 3), (5, -4), (13, 2), (0, -7), (-8, 6), (9, 6)]):
            col = [BOUG, GOLD, BOUG_LIGHT, "#F7F2E8"][i % 4]
            b += f'<circle cx="{cx+dx}" cy="{cy+dy}" r="3.6" fill="{col}"/>'
    # benches
    for x, y in [(160, 150), (70, 128)]:
        b += f'<rect x="{x}" y="{y}" width="30" height="7" rx="2" fill="{TRUNK}"/><rect x="{x}" y="{y-6}" width="30" height="4" rx="2" fill="#5C3F27"/>'
    # trees in the corners
    b += round_tree(52, 52, 26)
    b += round_tree(206, 46, 22, OLIVE, OLIVE_DARK, "#B6C68E")
    b += round_tree(46, 210, 24, OLIVE, OLIVE_DARK, "#B6C68E")
    b += round_tree(210, 214, 22)
    b += grass_tufts([(90, 40), (168, 70), (80, 176), (176, 230), (230, 128)])
    return svg(b, defs=d)


def trees():
    d, b = frame("green", paving=False)
    b += grass_tufts([(40, 60), (200, 40), (220, 140), (36, 160), (128, 236), (90, 110)])
    # cypress (tall, back)
    b += f'<ellipse cx="166" cy="134" rx="26" ry="8" fill="{SHADOW}" opacity="0.25"/>'
    b += f'<rect x="150" y="116" width="8" height="18" fill="{TRUNK}"/>'
    b += f'<path d="M154 22 C176 60 178 104 168 122 Q154 130 140 122 C130 104 132 60 154 22Z" fill="{CYPRESS}"/>'
    b += f'<path d="M154 30 C164 60 166 96 160 116" fill="none" stroke="{CYPRESS_LIGHT}" stroke-width="6" stroke-linecap="round"/>'
    # olive tree (left)
    b += f'<ellipse cx="80" cy="196" rx="44" ry="11" fill="{SHADOW}" opacity="0.25"/>'
    b += f'<path d="M74 196 C76 176 66 166 72 146 M78 196 C82 176 92 168 88 150" fill="none" stroke="{TRUNK}" stroke-width="8" stroke-linecap="round"/>'
    for cx, cy, r in [(56, 128, 26), (96, 120, 28), (76, 102, 26), (110, 146, 18), (44, 150, 18)]:
        b += f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{OLIVE_DARK}"/>'
    for cx, cy, r in [(54, 124, 20), (94, 116, 22), (74, 98, 20), (108, 142, 13), (44, 146, 13)]:
        b += f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{OLIVE}"/>'
    for cx, cy in [(68, 92), (88, 108), (50, 118)]:
        b += f'<circle cx="{cx}" cy="{cy}" r="7" fill="#B6C68E"/>'
    for cx, cy in [(62, 134), (100, 128), (84, 112)]:
        b += f'<ellipse cx="{cx}" cy="{cy}" rx="3" ry="4" fill="#3E3550"/>'
    # lemon tree (front right)
    b += f'<ellipse cx="184" cy="222" rx="34" ry="9" fill="{SHADOW}" opacity="0.25"/>'
    b += f'<rect x="176" y="190" width="9" height="32" rx="3" fill="{TRUNK}"/>'
    b += f'<circle cx="180" cy="174" r="34" fill="{LEAF_DARK}"/><circle cx="176" cy="170" r="29" fill="{LEAF}"/>'
    b += f'<circle cx="166" cy="158" r="11" fill="{LEAF_LIGHT}"/>'
    for cx, cy in [(164, 180), (190, 164), (196, 186), (176, 196), (184, 150)]:
        b += f'<ellipse cx="{cx}" cy="{cy}" rx="5" ry="6.5" fill="#F4D23C" stroke="#C9A61C" stroke-width="1"/>'
    return svg(b, defs=d)


# ---------------------------------------------------------------- roads

ROAD_W = 104
ASPHALT = "#4E5662"
ASPHALT_DARK = "#424955"
KERB = "#B7AA90"
MARK = "#F3E7C4"


# Street types: surface gradient, kerb, lane marking and how the dashes are drawn.
STREET_STYLES = {
    "road": {"asph": ("#56606C", "#48505B"), "kerb": KERB, "mark": MARK, "dash": "16 12", "width": 5},
    "shaded": {"asph": ("#56606C", "#48505B"), "kerb": KERB, "mark": MARK, "dash": "16 12", "width": 5},
    "pedestrian": {"asph": ("#E6D5AD", "#D4BF92"), "kerb": "#F6EEDC", "mark": "#B9A272", "dash": "0.1 14", "width": 6},
    "bike": {"asph": ("#4F906D", "#3E7A5A"), "kerb": KERB, "mark": "#F4F1E4", "dash": "16 12", "width": 4},
}


def bike_glyph(cx, cy):
    """Small white bicycle painted on the lane."""
    w = f'stroke="#F4F1E4" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"'
    return (
        f'<g {w} opacity="0.95"><circle cx="{cx-17}" cy="{cy+8}" r="10"/><circle cx="{cx+17}" cy="{cy+8}" r="10"/>'
        f'<path d="M{cx-17} {cy+8} L{cx-4} {cy-10} L{cx+10} {cy-10} L{cx+17} {cy+8} M{cx-4} {cy-10} L{cx+4} {cy+8} L{cx-17} {cy+8} M{cx+10} {cy-10} L{cx+8} {cy-16} L{cx+16} {cy-16}"/></g>'
    )


def bollards(mask, lo, hi):
    """Pedestrian street: a pair of posts at the edge of every open arm."""
    out = ""
    spots = []
    if mask & 1: spots += [(lo + 10, 20), (hi - 10, 20)]
    if mask & 4: spots += [(lo + 10, 236), (hi - 10, 236)]
    if mask & 2: spots += [(236, lo + 10), (236, hi - 10)]
    if mask & 8: spots += [(20, lo + 10), (20, hi - 10)]
    for x, y in spots:
        out += f'<circle cx="{x}" cy="{y+2}" r="7" fill="{SHADOW}" opacity="0.3"/><circle cx="{x}" cy="{y}" r="6.5" fill="#6B7380"/><circle cx="{x-1.5}" cy="{y-1.5}" r="3.5" fill="#A9B1BD"/>'
    return out


def canopy(cx, cy):
    """Tree crown spilling over the road edge, with a soft shadow on the surface."""
    return (
        f'<circle cx="{cx+6}" cy="{cy+8}" r="40" fill="{SHADOW}" opacity="0.22"/>'
        + round_tree(cx, cy, 38, LEAF, LEAF_DARK, LEAF_LIGHT)
        + f'<circle cx="{cx+10}" cy="{cy+8}" r="6" fill="{LEAF_LIGHT}" opacity="0.6"/>'
    )


def road(mask, style="road"):
    """mask bits: 1 = north, 2 = east, 4 = south, 8 = west."""
    st = STREET_STYLES[style]
    kerb, mark = st["kerb"], st["mark"]
    corners = [(42, 42), (214, 42), (42, 214), (214, 214)]
    d, b = frame("road")
    d = '<clipPath id="inner"><rect x="10" y="10" width="236" height="236" rx="22"/></clipPath>' + d
    d += lin("asph", *st["asph"])
    lo, hi = 128 - ROAD_W / 2, 128 + ROAD_W / 2
    arms = []
    if mask & 1: arms.append((lo, 3, ROAD_W, 125))
    if mask & 2: arms.append((128, lo, 125, ROAD_W))
    if mask & 4: arms.append((lo, 128, ROAD_W, 125))
    if mask & 8: arms.append((3, lo, 125, ROAD_W))
    # sidewalk planters at corners not touched by arms (the shaded street has trees there instead)
    if style != "shaded":
        for (cx, cy) in corners:
            b += f'<rect x="{cx-14}" y="{cy-14}" width="28" height="28" rx="6" fill="#C5B795"/>'
            b += f'<circle cx="{cx}" cy="{cy}" r="9" fill="{OLIVE_DARK}"/><circle cx="{cx-2}" cy="{cy-2}" r="6" fill="{OLIVE}"/>'
    # drawn last so crowns hang over the road
    overlay = "".join(canopy(cx, cy) for cx, cy in corners) if style == "shaded" else ""
    if mask == 0:
        b += '<g clip-path="url(#inner)">'
        b += f'<circle cx="128" cy="128" r="66" fill="{kerb}"/><circle cx="128" cy="128" r="60" fill="url(#asph)"/>'
        b += f'<circle cx="128" cy="128" r="24" fill="{LEAF}" stroke="{kerb}" stroke-width="5"/>'
        b += f'<circle cx="128" cy="128" r="42" fill="none" stroke="{mark}" stroke-width="3" stroke-dasharray="10 9"/>'
        return svg(b + overlay + "</g>", defs=d)
    # kerbs then asphalt, clipped to the tile so arms never spill over the rim
    b += '<g clip-path="url(#inner)">'
    for x, y, w, h in arms:
        b += f'<rect x="{x - (5 if w == ROAD_W else 0)}" y="{y - (5 if h == ROAD_W else 0)}" width="{w + (10 if w == ROAD_W else 0)}" height="{h + (10 if h == ROAD_W else 0)}" fill="{kerb}"/>'
    b += f'<rect x="{lo-5}" y="{lo-5}" width="{ROAD_W+10}" height="{ROAD_W+10}" rx="14" fill="{kerb}"/>'
    for x, y, w, h in arms:
        b += f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="url(#asph)"/>'
    b += f'<rect x="{lo}" y="{lo}" width="{ROAD_W}" height="{ROAD_W}" rx="10" fill="url(#asph)"/>'
    # centre line dashes on each arm; junctions get a zebra crossing per arm
    dash = f'stroke="{mark}" stroke-width="{st["width"]}" stroke-dasharray="{st["dash"]}" stroke-linecap="round"'
    count = bin(mask).count("1")
    near, far = (34, 222) if count > 2 else (128, 128)
    if mask & 1: b += f'<line x1="128" y1="10" x2="128" y2="{near}" {dash}/>'
    if mask & 4: b += f'<line x1="128" y1="246" x2="128" y2="{far}" {dash}/>'
    if mask & 2: b += f'<line x1="246" y1="128" x2="{far}" y2="128" {dash}/>'
    if mask & 8: b += f'<line x1="10" y1="128" x2="{near}" y2="128" {dash}/>'
    if count > 2 and style != "pedestrian":
        zebra = ""
        for i in range(6):
            o = lo + 8 + i * 16
            if mask & 1: zebra += f'<rect x="{o}" y="44" width="9" height="24" rx="1.5"/>'
            if mask & 4: zebra += f'<rect x="{o}" y="188" width="9" height="24" rx="1.5"/>'
            if mask & 2: zebra += f'<rect x="188" y="{o}" width="24" height="9" rx="1.5"/>'
            if mask & 8: zebra += f'<rect x="44" y="{o}" width="24" height="9" rx="1.5"/>'
        b += f'<g fill="{mark}" opacity="0.92">{zebra}</g>'
    if count == 1 and style in ("road", "shaded"):
        b += f'<circle cx="128" cy="128" r="10" fill="{mark}" opacity="0.9"/>'
    if style == "bike":
        b += bike_glyph(128, 128)
    if style == "pedestrian":
        b += bollards(mask, lo, hi)
    return svg(b + overlay + "</g>", defs=d)


def lot():
    """Empty building plot on a player's mat."""
    d = lin("dirt", "#D9C8A1", "#C7B286")
    b = '<rect x="6" y="6" width="244" height="244" rx="24" fill="url(#dirt)"/>'
    b += '<rect x="20" y="20" width="216" height="216" rx="16" fill="none" stroke="#A8936A" stroke-width="3" stroke-dasharray="14 10" opacity="0.7"/>'
    for x, y in [(30, 30), (226, 30), (30, 226), (226, 226)]:
        b += f'<rect x="{x-4}" y="{y-4}" width="8" height="8" rx="1.5" fill="{TERRACOTTA}"/>'
    import random
    rnd = random.Random(4)
    for _ in range(16):
        x, y = rnd.uniform(40, 216), rnd.uniform(40, 216)
        b += f'<ellipse cx="{x:.0f}" cy="{y:.0f}" rx="{rnd.uniform(2,5):.1f}" ry="{rnd.uniform(1.5,3.5):.1f}" fill="#B29C72" opacity="0.6"/>'
    b += grass_tufts([(60, 190), (190, 70), (170, 200)], OLIVE_DARK)
    return svg(b, defs=d)


def shade_edge():
    """Canopy shadow falling onto a road from its top edge. The game rotates it
    towards every side that has trees or a park, so shade points at its source."""
    import random
    rnd = random.Random(11)
    b = '<g fill="#0B4A3A" opacity="0.5">'
    b += '<rect x="0" y="0" width="256" height="34"/>'
    x = -12
    while x < 270:
        r = rnd.uniform(22, 32)
        b += f'<circle cx="{x:.0f}" cy="{30 + rnd.uniform(-4, 12):.0f}" r="{r:.0f}"/>'
        x += rnd.uniform(26, 36)
    b += "</g>"
    # single leaves drifting further onto the road
    for _ in range(7):
        lx, ly, a = rnd.uniform(20, 236), rnd.uniform(68, 104), rnd.uniform(0, 180)
        b += (f'<ellipse cx="{lx:.0f}" cy="{ly:.0f}" rx="9" ry="4.5" transform="rotate({a:.0f} {lx:.0f} {ly:.0f})" '
              f'fill="#0B4A3A" opacity="0.42"/>')
    # sun flecks through the canopy
    for _ in range(6):
        fx, fy = rnd.uniform(20, 236), rnd.uniform(10, 44)
        b += f'<ellipse cx="{fx:.0f}" cy="{fy:.0f}" rx="{rnd.uniform(4, 7):.1f}" ry="{rnd.uniform(2.5, 4):.1f}" fill="#FFF0B0" opacity="0.3"/>'
    return svg(b)


# ---------------------------------------------------------------- ui icons

def coin():
    d = rad("cg", "#FFE68A", "#E3A21E", 0.35, 0.3, 0.8)
    b = '<circle cx="34" cy="35" r="27" fill="#8A5A0C" opacity="0.35"/>'
    b += '<circle cx="32" cy="32" r="28" fill="#B9810F"/>'
    b += '<circle cx="32" cy="31" r="25" fill="url(#cg)"/>'
    b += '<circle cx="32" cy="31" r="18" fill="none" stroke="#C88A16" stroke-width="2.5"/>'
    # raised dotted ring and diamond
    import math
    for k in range(12):
        a = k * math.pi / 6
        b += f'<circle cx="{32 + 21.5*math.cos(a):.1f}" cy="{31 + 21.5*math.sin(a):.1f}" r="1.6" fill="#C88A16"/>'
    b += '<polygon points="32,19 41,31 32,43 23,31" fill="#E8A91F" stroke="#B9810F" stroke-width="2.2" stroke-linejoin="round"/>'
    b += '<polygon points="32,23 37,31 32,31" fill="#FFF0A8" opacity="0.8"/>'
    b += '<path d="M14 24 A20 20 0 0 1 30 12" fill="none" stroke="#FFF6C8" stroke-width="3" stroke-linecap="round" opacity="0.85"/>'
    return svg(b, 64, d)


def icon_citizen():
    b = '<circle cx="32" cy="17" r="11" fill="#EFE6D2"/>'
    b += '<path d="M12 58 v-10 a20 20 0 0 1 40 0 v10 z" fill="#EFE6D2"/>'
    return svg(b, 64)


def icon_pollution():
    b = '<g fill="#8C96A3"><circle cx="20" cy="38" r="12"/><circle cx="34" cy="28" r="15"/><circle cx="46" cy="40" r="11"/><rect x="14" y="38" width="38" height="13" rx="6.5"/></g>'
    b += '<g fill="#6B7684" opacity="0.8"><circle cx="30" cy="24" r="6"/><circle cx="42" cy="34" r="5"/><circle cx="20" cy="36" r="4"/></g>'
    b += '<path d="M10 58 h44" stroke="#6B7684" stroke-width="3" stroke-linecap="round" stroke-dasharray="6 5"/>'
    return svg(b, 64)


def icon_leaf():
    b = '<path d="M12 52 C10 26 28 10 54 10 C54 36 38 54 12 52Z" fill="#7FA33A"/>'
    b += '<path d="M14 50 C26 38 36 28 48 16" stroke="#C9E39A" stroke-width="3" fill="none" stroke-linecap="round"/>'
    return svg(b, 64)


def icon_sun():
    rays = "".join(
        f'<rect x="30" y="2" width="4" height="11" rx="2" fill="#F28C28" transform="rotate({a} 32 32)"/>'
        for a in range(0, 360, 45)
    )
    return svg(rays + '<circle cx="32" cy="32" r="14" fill="#F2B630"/><circle cx="28" cy="28" r="5" fill="#FFE68A"/>', 64)


def icon_bank():
    b = '<polygon points="32,6 58,20 6,20" fill="#F2B630"/>'
    b += '<rect x="8" y="20" width="48" height="5" fill="#C88A16"/>'
    b += "".join(f'<rect x="{x}" y="27" width="6" height="22" rx="1" fill="#EFE6D2"/>' for x in [12, 23, 35, 46])
    b += '<rect x="6" y="50" width="52" height="7" rx="2" fill="#C88A16"/>'
    return svg(b, 64)


def icon_route():
    b = '<path d="M14 50 C14 34 50 34 50 18" fill="none" stroke="#9CC9E8" stroke-width="6" stroke-linecap="round" stroke-dasharray="2 9"/>'
    b += '<circle cx="14" cy="50" r="7" fill="#3A8DDE"/>'
    b += '<path d="M50 6 a10 10 0 0 1 10 10 c0 8 -10 18 -10 18 s-10 -10 -10 -18 a10 10 0 0 1 10 -10z" fill="#E0533A"/><circle cx="50" cy="16" r="4" fill="#fff"/>'
    return svg(b, 64)


def icon_walk():
    b = '<circle cx="48" cy="14" r="9" fill="#F2B630"/>'
    b += '<circle cx="26" cy="12" r="6" fill="#EFE6D2"/>'
    b += '<path d="M26 20 L22 36 L30 44 L28 58 M22 36 L14 56 M24 24 L14 32 M26 24 L36 30" stroke="#EFE6D2" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
    b += '<path d="M40 50 q4 -6 0 -12 M48 52 q4 -6 0 -12" stroke="#E0533A" stroke-width="3" fill="none" stroke-linecap="round"/>'
    return svg(b, 64)


def icon_sprout():
    b = '<path d="M32 58 V30" stroke="#5E9B3A" stroke-width="5" stroke-linecap="round"/>'
    b += '<path d="M32 34 C18 34 10 24 10 12 C24 12 32 20 32 34Z" fill="#7FA33A"/>'
    b += '<path d="M32 30 C44 30 54 22 54 8 C40 8 32 16 32 30Z" fill="#86BE52"/>'
    b += '<rect x="16" y="54" width="32" height="6" rx="3" fill="#9A7A52"/>'
    return svg(b, 64)


def icon_trophy():
    d = lin("tg", "#FFE68A", "#E3A21E")
    b = '<path d="M14 10 h36 v12 a18 18 0 0 1 -36 0z" fill="url(#tg)"/>'
    b += '<path d="M14 14 h-6 a8 8 0 0 0 8 12 M50 14 h6 a8 8 0 0 1 -8 12" fill="none" stroke="#E3A21E" stroke-width="4"/>'
    b += '<rect x="28" y="38" width="8" height="10" fill="#C88A16"/><rect x="18" y="48" width="28" height="8" rx="2" fill="#B9810F"/>'
    b += '<path d="M22 16 v8" stroke="#FFF6C8" stroke-width="3" stroke-linecap="round"/>'
    return svg(b, 64, d)


def icon_crown():
    b = '<path d="M8 46 L12 18 L24 32 L32 12 L40 32 L52 18 L56 46 Z" fill="#F2B630" stroke="#B9810F" stroke-width="3" stroke-linejoin="round"/>'
    b += '<rect x="8" y="46" width="48" height="8" rx="2" fill="#E3A21E"/>'
    b += '<circle cx="32" cy="36" r="4" fill="#D6337A"/><circle cx="20" cy="40" r="3" fill="#3A8DDE"/><circle cx="44" cy="40" r="3" fill="#3A8DDE"/>'
    return svg(b, 64)


# ---------------------------------------------------------------- student housing and services

STUDENT_BLUE = "#4F8BEA"
STUDENT_DARK = "#2F63B8"
SANDSTONE = "#EADFC6"
SANDSTONE_SIDE = "#CDBF9F"
SANDSTONE_TOP = "#F4ECD8"


def mortarboard(cx, cy, s=1.0, col=INK, tassel=GOLD):
    """A graduation cap centred at (cx, cy)."""
    return (
        f'<g transform="translate({cx} {cy}) scale({s})">'
        f'<path d="M-14 6 v8 q14 7 28 0 v-8 l-14 6z" fill="{col}" opacity="0.85"/>'
        f'<polygon points="0,-12 -26,-1 0,10 26,-1" fill="{col}"/>'
        f'<line x1="22" y1="-1" x2="22" y2="14" stroke="{tassel}" stroke-width="2.4"/>'
        f'<circle cx="22" cy="16" r="3" fill="{tassel}"/>'
        f'</g>'
    )


def bicycle(x, y, s=1.0, col=BOUG):
    """A bicycle standing on the ground at (x, y), side view, about 44 wide."""
    return (
        f'<g transform="translate({x} {y}) scale({s})">'
        f'<ellipse cx="0" cy="1" rx="24" ry="3.5" fill="{SHADOW}" opacity="0.28"/>'
        f'<circle cx="-15" cy="-10" r="10" fill="none" stroke="{INK}" stroke-width="2.6"/>'
        f'<circle cx="15" cy="-10" r="10" fill="none" stroke="{INK}" stroke-width="2.6"/>'
        f'<path d="M-15 -10 L-3 -22 L10 -22 L15 -10 M-3 -22 L2 -10 L-15 -10 M10 -22 L8 -28 M4 -28 h8" fill="none" stroke="{col}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'
        f'<path d="M-6 -24 h8" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>'
        f'</g>'
    )


def book_stack(x, y, cols=(BOUG, SHUTTER, GOLD)):
    """A little stack of books, bottom-left at (x, y)."""
    out = ""
    for i, c in enumerate(cols):
        w = 30 - i * 3
        out += f'<rect x="{x + i}" y="{y - (i + 1) * 8}" width="{w}" height="8" rx="1.5" fill="{c}" stroke="{INK}" stroke-width="1" stroke-opacity="0.35"/>'
        out += f'<line x1="{x + i + 3}" y1="{y - i * 8 - 4}" x2="{x + i + w - 3}" y2="{y - i * 8 - 4}" stroke="{WHITE}" stroke-width="1.2" opacity="0.7"/>'
    return out


def student_small():
    d, b = frame("building")
    d += GLASS_DEFS
    b += ground_shadow([(60, 208), (180, 208), (210, 192), (196, 110)])
    b += box(60, 112, 112, 96, 22, 14, "#F2EEF8", "#CFC9DE", "#E6E0F0")
    b += f'<polygon points="56,114 172,114 194,100 78,100" fill="{STUDENT_BLUE}"/>'
    b += f'<polygon points="172,114 194,100 194,106 172,120" fill="{STUDENT_DARK}"/>'
    b += mortarboard(112, 76, 1.05, STUDENT_DARK)
    b += f'<line x1="112" y1="96" x2="112" y2="104" stroke="{INK}" stroke-width="2.5"/>'
    b += door(76, 166, 22, 42, STUDENT_BLUE)
    b += window(124, 134, 22, 26, shutters=False)
    b += window(124, 172, 22, 24, shutters=False)
    b += window(76, 130, 22, 26, shutters=False)
    b += bicycle(64, 232, 0.8)
    b += book_stack(176, 232)
    b += grass_tufts([(36, 60), (216, 62)])
    return svg(b, defs=d)


def student_large():
    d, b = frame("building")
    d += GLASS_DEFS
    b += ground_shadow([(36, 204), (190, 204), (222, 186), (208, 78)])
    b += box(36, 80, 154, 124, 26, 16, "#F2EEF8", "#CFC9DE", "#E6E0F0")
    b += f'<polygon points="30,82 190,82 216,66 56,66" fill="{STUDENT_BLUE}"/>'
    b += f'<polygon points="190,82 216,66 216,72 190,88" fill="{STUDENT_DARK}"/>'
    b += mortarboard(112, 44, 1.2, STUDENT_DARK)
    for row, y in enumerate([98, 138]):
        for x in [48, 84, 122, 156]:
            b += window(x, y, 20, 24, shutters=False)
            if row == 0:
                b += f'<rect x="{x-3}" y="{y+24}" width="26" height="4" fill="{STUDENT_BLUE}"/>'
    b += door(100, 168, 28, 36, STUDENT_BLUE)
    b += f'<rect x="92" y="164" width="44" height="6" rx="2" fill="{STUDENT_DARK}"/>'
    b += bicycle(54, 232, 0.8, SHUTTER)
    b += bicycle(96, 236, 0.8, BOUG)
    b += book_stack(168, 236)
    b += person(210, 232, "#4F8BEA", s=0.8)
    return svg(b, defs=d)


def commercial():
    d, b = frame("amenity")
    d += GLASS_DEFS
    b += ground_shadow([(40, 198), (196, 198), (226, 180), (210, 92)])
    b += box(40, 94, 156, 104, 28, 17, "#F4EFE2", WHITE_SIDE, WHITE_TOP)
    b += f'<rect x="40" y="94" width="156" height="26" fill="#C98A1A"/>'
    b += f'<rect x="108" y="48" width="44" height="40" rx="6" fill="{WHITE}" stroke="#C98A1A" stroke-width="4"/>'
    b += f'<path d="M118 64 h24 l-2 20 h-20z" fill="#E5A12B"/><path d="M123 64 a7 7 0 0 1 14 0" fill="none" stroke="#8A5A0C" stroke-width="3"/>'
    for i, x in enumerate([52, 94, 136]):
        col = SHUTTER if i % 2 == 0 else TERRACOTTA
        b += f'<rect x="{x}" y="126" width="36" height="46" rx="3" fill="url(#glass)"/>'
        b += f'<polygon points="{x-3},126 {x+39},126 {x+43},116 {x+1},116" fill="{col}"/>'
        b += f'<rect x="{x+6}" y="152" width="10" height="20" fill="{col}" opacity="0.5"/><rect x="{x+20}" y="146" width="10" height="26" fill="{GOLD}" opacity="0.6"/>'
    b += door(92, 168, 20, 30, SHUTTER, arch=False)
    b += f'<rect x="34" y="214" width="34" height="22" rx="3" fill="#B07A45" stroke="#7A5232" stroke-width="2"/>'
    b += f'<rect x="44" y="204" width="34" height="22" rx="3" fill="#C58A52" stroke="#7A5232" stroke-width="2"/>'
    b += person(150, 234, "#E5A12B", s=0.9)
    b += f'<rect x="176" y="218" width="30" height="16" rx="2" fill="{SHUTTER}"/><circle cx="184" cy="238" r="4" fill="{INK}"/><circle cx="200" cy="238" r="4" fill="{INK}"/>'
    return svg(b, defs=d)


def university():
    d, b = frame("amenity")
    d += GLASS_DEFS
    b += ground_shadow([(28, 200), (192, 200), (226, 182), (210, 112)])
    b += box(28, 116, 164, 84, 28, 17, SANDSTONE, SANDSTONE_SIDE, SANDSTONE_TOP)
    b += f'<polygon points="62,116 158,116 110,70" fill="{SANDSTONE_TOP}" stroke="{SANDSTONE_SIDE}" stroke-width="3"/>'
    b += f'<circle cx="110" cy="100" r="9" fill="{STUDENT_BLUE}" stroke="{WHITE}" stroke-width="3"/>'
    b += f'<path d="M82 48 a28 28 0 0 1 56 0z" fill="{STUDENT_DARK}"/><rect x="106" y="22" width="8" height="14" fill="{STUDENT_DARK}"/>'
    b += f'<polygon points="114,22 134,28 114,34" fill="{BOUG}"/>'
    for x in [66, 88, 110, 132]:
        b += f'<rect x="{x}" y="118" width="12" height="70" fill="{WHITE}" stroke="{SANDSTONE_SIDE}" stroke-width="2"/>'
        b += f'<rect x="{x-3}" y="114" width="18" height="6" fill="{SANDSTONE_SIDE}"/><rect x="{x-3}" y="186" width="18" height="6" fill="{SANDSTONE_SIDE}"/>'
    b += door(100, 150, 20, 38, STUDENT_DARK)
    for x in [38, 160]:
        b += window(x, 138, 18, 30, shutters=False)
    for i in range(3):
        b += f'<rect x="{50 - i*6}" y="{200 + i*6}" width="{120 + i*12}" height="6" fill="{SANDSTONE}" stroke="{SANDSTONE_SIDE}" stroke-width="1.5"/>'
    b += person(70, 236, "#4F8BEA", s=0.8)
    b += person(150, 238, BOUG, s=0.8)
    b += mortarboard(204, 226, 0.6, INK)
    return svg(b, defs=d)


def library():
    d, b = frame("amenity")
    d += GLASS_DEFS
    front, side, top = "#E7D3B0", "#C9B189", "#F0E1C4"
    b += ground_shadow([(40, 196), (186, 196), (220, 178), (204, 98)])
    b += box(40, 100, 146, 96, 26, 16, front, side, top)
    b += f'<polygon points="34,102 192,102 214,88 56,88" fill="#3F7A5B"/>'
    b += f'<polygon points="192,102 214,88 214,94 192,108" fill="#2C5A42"/>'
    b += f'<path d="M92 66 q10 -8 20 0 q10 -8 20 0 v22 q-10 -6 -20 0 q-10 -6 -20 0z" fill="{WHITE}" stroke="#2C5A42" stroke-width="3" stroke-linejoin="round"/>'
    b += f'<line x1="112" y1="66" x2="112" y2="86" stroke="#2C5A42" stroke-width="2.5"/>'
    for x in [54, 92, 138]:
        b += f'<path d="M{x} 176 V132 a14 14 0 0 1 28 0 V176z" fill="url(#glass)" stroke="{WHITE}" stroke-width="3"/>'
        b += f'<line x1="{x+14}" y1="120" x2="{x+14}" y2="176" stroke="{WHITE}" stroke-width="2"/>'
    b += door(104, 150, 24, 46, "#3F7A5B")
    for i in range(4):
        b += f'<rect x="{44 + i*10}" y="196" width="10" height="6" fill="{front}" stroke="{side}" stroke-width="1.2"/>'
    b += book_stack(52, 236, (SHUTTER, TERRACOTTA, "#3F7A5B", GOLD))
    b += f'<rect x="150" y="214" width="46" height="8" rx="2" fill="{TRUNK}"/><rect x="154" y="222" width="5" height="12" fill="{INK}"/><rect x="187" y="222" width="5" height="12" fill="{INK}"/>'
    b += person(172, 212, "#4F8BEA", s=0.7)
    return svg(b, defs=d)


def bookshop():
    d, b = frame("amenity")
    d += GLASS_DEFS
    b += ground_shadow([(44, 186), (186, 186), (218, 168), (202, 100)])
    b += box(44, 106, 142, 80, 24, 15, "#7B2E3B", "#5E1F2B", "#8D3C4A")
    b += f'<polygon points="38,120 192,120 184,106 46,106" fill="#245A3D"/>'
    for i in range(9):
        col = "#2F7A52" if i % 2 == 0 else WHITE
        b += f'<polygon points="{38 + i*17.1:.1f},120 {55.1 + i*17.1:.1f},120 {55.1 + i*17.1:.1f},136 {38 + i*17.1:.1f},136" fill="{col}"/>'
    b += f'<rect x="84" y="62" width="60" height="30" rx="5" fill="{WHITE}" stroke="#245A3D" stroke-width="4"/>'
    b += f'<path d="M96 70 q8 -5 18 0 q10 -5 18 0 v14 q-8 -4 -18 0 q-10 -4 -18 0z" fill="#E7D3B0" stroke="#245A3D" stroke-width="2.4"/>'
    b += f'<rect x="54" y="140" width="70" height="46" rx="2" fill="url(#glass)"/>'
    shelf = ""
    for i, c in enumerate([BOUG, GOLD, SHUTTER, "#2F7A52", TERRACOTTA, BOUG_LIGHT, SHUTTER_DARK, GOLD]):
        shelf += f'<rect x="{58 + i*8}" y="{156 - (i % 3) * 3}" width="7" height="{20 + (i % 3) * 3}" fill="{c}"/>'
    b += shelf + f'<rect x="54" y="176" width="70" height="4" fill="{WHITE_SIDE}"/>'
    b += door(136, 144, 22, 42, "#245A3D")
    b += f'<polygon points="176,232 192,196 208,232" fill="#2B3A2E"/><polygon points="181,226 192,203 203,226" fill="{WHITE}"/>'
    b += book_stack(60, 236, (TERRACOTTA, "#2F7A52", GOLD))
    b += person(126, 232, "#A15CC9", s=0.85)
    return svg(b, defs=d)


def print_shop():
    d, b = frame("amenity")
    d += GLASS_DEFS
    b += ground_shadow([(48, 190), (182, 190), (214, 172), (200, 100)])
    b += box(48, 104, 134, 86, 24, 15, "#EEF3F6", "#C5D1DA", "#E1E9EE")
    for i, c in enumerate(["#1CA7D8", "#D6337A", "#F2C21C", INK]):
        b += f'<rect x="{48 + i*33.5}" y="104" width="33.5" height="14" fill="{c}"/>'
    b += f'<rect x="88" y="54" width="54" height="40" rx="6" fill="{WHITE}" stroke="{INK}" stroke-width="3.5"/>'
    b += f'<rect x="98" y="62" width="34" height="16" rx="3" fill="{INK}"/><rect x="104" y="56" width="22" height="10" fill="{WHITE}" stroke="{INK}" stroke-width="2"/>'
    b += f'<rect x="102" y="76" width="26" height="14" fill="{WHITE}" stroke="{INK}" stroke-width="2"/><line x1="106" y1="82" x2="124" y2="82" stroke="{INK}" stroke-width="1.5"/>'
    b += f'<rect x="58" y="128" width="64" height="52" rx="2" fill="url(#glass)"/>'
    b += f'<rect x="66" y="148" width="48" height="26" rx="3" fill="#6B7684"/><rect x="72" y="140" width="36" height="12" rx="2" fill="#98A4B1"/>'
    b += f'<rect x="76" y="156" width="28" height="16" fill="{WHITE}"/>'
    b += door(134, 140, 24, 50, INK, arch=False)
    for i in range(3):
        b += f'<rect x="{40 + (i % 2) * 4}" y="{214 - i * 9}" width="38" height="9" rx="1.5" fill="{WHITE}" stroke="{WHITE_SIDE}" stroke-width="1.5"/>'
    b += f'<rect x="180" y="206" width="12" height="32" rx="6" fill="{GOLD}" stroke="#B9810F" stroke-width="2"/><rect x="196" y="210" width="12" height="28" rx="6" fill="{BOUG}" stroke="#A52264" stroke-width="2"/>'
    b += person(128, 234, "#1CA7D8", s=0.85)
    return svg(b, defs=d)


def kiosk():
    d, b = frame("amenity")
    d += GLASS_DEFS
    b += ground_shadow([(70, 200), (170, 200), (200, 184), (188, 112)])
    b += box(72, 112, 92, 88, 22, 14, "#F7E9C0", "#D9C48C", "#FFF1CE")
    for i in range(8):
        col = TERRACOTTA if i % 2 == 0 else WHITE
        b += f'<polygon points="{62 + i*14.5:.1f},112 {76.5 + i*14.5:.1f},112 {80.5 + i*14.5:.1f},96 {66 + i*14.5:.1f},96" fill="{col}"/>'
    b += "".join(f'<path d="M{62 + i*14.5:.1f} 112 q7.2 10 14.5 0" fill="{TERRACOTTA if i % 2 == 0 else WHITE}"/>' for i in range(8))
    b += f'<polygon points="62,96 178,96 168,78 72,78" fill="{TERRACOTTA_DARK}"/>'
    b += f'<circle cx="120" cy="64" r="14" fill="{GOLD}" stroke="{WHITE}" stroke-width="3"/><path d="M114 62 h12 l-6 12z" fill="{TERRACOTTA}"/>'
    b += f'<rect x="84" y="136" width="64" height="36" rx="2" fill="url(#glass)"/>'
    b += f'<rect x="80" y="170" width="72" height="8" rx="2" fill="{TRUNK}"/>'
    for i, c in enumerate([SHUTTER, TERRACOTTA, "#2FA05A", GOLD, BOUG]):
        b += f'<rect x="{88 + i*11}" y="178" width="9" height="16" fill="{c}"/>'
    b += f'<rect x="168" y="150" width="10" height="46" fill="{SHUTTER_DARK}"/><circle cx="173" cy="146" r="9" fill="{WHITE}" stroke="{SHUTTER_DARK}" stroke-width="2"/>'
    b += person(60, 234, "#E5A12B", s=0.9)
    b += person(186, 232, "#3A8DDE", s=0.85)
    b += pot_plant(120, 236)
    return svg(b, defs=d)


def restaurant():
    d, b = frame("amenity")
    d += GLASS_DEFS
    b += ground_shadow([(44, 172), (184, 172), (216, 154), (200, 88)])
    b += box(44, 92, 140, 80, 26, 16, "#F6E3C8", "#DDBF98", "#FFF0DA")
    b += f'<polygon points="38,106 190,106 182,94 46,94" fill="{TERRACOTTA_DARK}"/>'
    for i in range(9):
        col = TERRACOTTA if i % 2 == 0 else "#F6E3C8"
        b += f'<polygon points="{38 + i*16.9:.1f},106 {54.9 + i*16.9:.1f},106 {54.9 + i*16.9:.1f},122 {38 + i*16.9:.1f},122" fill="{col}"/>'
    b += f'<circle cx="114" cy="62" r="22" fill="{WHITE}" stroke="{TERRACOTTA}" stroke-width="5"/>'
    b += f'<path d="M104 50 v22 M101 50 v10 a3 3 0 0 0 6 0 v-10" fill="none" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>'
    b += f'<path d="M124 50 q-6 8 -2 18 h2 v6 M124 50 v24" fill="none" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>'
    b += f'<rect x="58" y="128" width="42" height="34" rx="2" fill="url(#glass)"/><rect x="128" y="128" width="42" height="34" rx="2" fill="url(#glass)"/>'
    b += door(106, 126, 22, 46, TERRACOTTA_DARK)
    for x in [64, 164]:
        b += f'<ellipse cx="{x+4}" cy="224" rx="26" ry="7" fill="{SHADOW}" opacity="0.25"/>'
        b += f'<ellipse cx="{x}" cy="212" rx="22" ry="8" fill="{WHITE}" stroke="{TERRACOTTA}" stroke-width="2.5"/>'
        b += f'<path d="M{x-14} 212 h28 M{x} 206 v12" stroke="{TERRACOTTA}" stroke-width="2" opacity="0.7"/>'
        b += f'<rect x="{x-3}" y="218" width="6" height="14" fill="{INK}"/>'
        b += f'<circle cx="{x-6}" cy="207" r="4" fill="{GOLD}"/><circle cx="{x+7}" cy="209" r="3" fill="#2FA05A"/>'
    b += person(118, 236, "#2F7A52", s=0.85)
    return svg(b, defs=d)


def supermarket():
    d, b = frame("amenity")
    d += GLASS_DEFS
    b += ground_shadow([(30, 186), (204, 186), (230, 170), (216, 100)])
    b += box(30, 102, 174, 84, 26, 16, "#F2F4EE", "#CDD4C6", "#E5EADF")
    b += f'<rect x="30" y="102" width="174" height="26" fill="#2FA05A"/>'
    b += f'<rect x="92" y="56" width="60" height="38" rx="6" fill="{WHITE}" stroke="#2FA05A" stroke-width="4"/>'
    b += f'<path d="M104 70 h36 l-5 18 h-26z" fill="#2FA05A"/><path d="M112 70 a10 10 0 0 1 20 0" fill="none" stroke="#1E7A42" stroke-width="3.5"/>'
    b += f'<rect x="40" y="136" width="154" height="44" rx="2" fill="url(#glass)"/>'
    for x in range(60, 190, 38):
        b += f'<line x1="{x}" y1="136" x2="{x}" y2="180" stroke="{WHITE}" stroke-width="3"/>'
    for i, c in enumerate(["#F28C28", "#D6403A", "#F4D23C", "#79C060", "#D6403A", "#F28C28"]):
        b += f'<circle cx="{54 + i*26}" cy="170" r="6" fill="{c}"/>'
    b += f'<rect x="102" y="140" width="30" height="40" fill="{WHITE}" opacity="0.55"/>'
    b += f'<path d="M40 214 h38 l-6 -26 h-36" fill="none" stroke="{INK}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'
    b += f'<line x1="44" y1="196" x2="76" y2="196" stroke="{INK}" stroke-width="2.5"/><circle cx="50" cy="220" r="4" fill="{INK}"/><circle cx="72" cy="220" r="4" fill="{INK}"/>'
    b += f'<path d="M88 216 h40 l-6 -26 h-34" fill="none" stroke="#6B7684" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/><circle cx="98" cy="222" r="4" fill="#6B7684"/><circle cx="120" cy="222" r="4" fill="#6B7684"/>'
    b += person(176, 236, "#E0533A", s=0.9)
    b += pot_plant(208, 238)
    return svg(b, defs=d)


def hospital():
    d, b = frame("amenity")
    d += GLASS_DEFS
    b += ground_shadow([(40, 214), (176, 214), (210, 196), (196, 54)])
    b += box(40, 72, 136, 142, 28, 17, "#F6F9FB", "#C8D6DF", "#E6EEF3")
    b += f'<rect x="80" y="26" width="56" height="50" rx="8" fill="{WHITE}" stroke="#3A8DDE" stroke-width="4"/>'
    b += f'<path d="M100 34 h16 v14 h14 v16 h-14 v10 h-16 v-10 h-14 v-16 h14z" fill="#D63A3A"/>'
    for y in [92, 128]:
        for x in [52, 84, 116, 146]:
            b += f'<rect x="{x}" y="{y}" width="20" height="24" rx="2" fill="url(#glass)"/>'
    b += f'<rect x="40" y="154" width="136" height="8" fill="#3A8DDE"/>'
    b += f'<rect x="84" y="170" width="52" height="44" rx="3" fill="url(#glass)" stroke="#3A8DDE" stroke-width="3"/>'
    b += f'<line x1="110" y1="170" x2="110" y2="214" stroke="#3A8DDE" stroke-width="3"/>'
    b += f'<polygon points="76,166 144,166 152,158 84,158" fill="#3A8DDE"/>'
    b += f'<rect x="168" y="214" width="56" height="26" rx="5" fill="{WHITE}" stroke="{WHITE_SIDE}" stroke-width="2"/>'
    b += f'<rect x="206" y="218" width="16" height="12" rx="2" fill="url(#glass)"/><rect x="168" y="228" width="56" height="4" fill="#D63A3A"/>'
    b += f'<path d="M184 218 h6 v-4 h4 v4 h6 v4 h-6 v4 h-4 v-4 h-6z" fill="#D63A3A"/>'
    b += f'<circle cx="182" cy="241" r="5" fill="{INK}"/><circle cx="212" cy="241" r="5" fill="{INK}"/><rect x="190" y="208" width="10" height="6" rx="2" fill="#E0533A"/>'
    b += person(60, 236, "#3A8DDE", s=0.85)
    return svg(b, defs=d)


def parking():
    d, b = frame("amenity", paving=False)
    d += GLASS_DEFS
    b += f'<rect x="26" y="26" width="204" height="204" rx="14" fill="#59616F"/>'
    b += f'<rect x="30" y="30" width="196" height="196" rx="11" fill="#6B7684"/>'
    for i in range(5):
        x = 38 + i * 36
        b += f'<line x1="{x}" y1="38" x2="{x}" y2="96" stroke="{WHITE}" stroke-width="3" opacity="0.9"/>'
        b += f'<line x1="{x}" y1="160" x2="{x}" y2="218" stroke="{WHITE}" stroke-width="3" opacity="0.9"/>'
    b += f'<line x1="38" y1="38" x2="218" y2="38" stroke="{WHITE}" stroke-width="3" opacity="0.9"/>'
    b += f'<line x1="38" y1="218" x2="218" y2="218" stroke="{WHITE}" stroke-width="3" opacity="0.9"/>'
    b += f'<path d="M50 128 h40 M166 128 h40" stroke="{GOLD}" stroke-width="4" stroke-dasharray="14 10" stroke-linecap="round"/>'

    def vcar(x, y, col):
        return (
            f'<rect x="{x-11+2}" y="{y-22+3}" width="22" height="44" rx="7" fill="{SHADOW}" opacity="0.28"/>'
            f'<rect x="{x-11}" y="{y-22}" width="22" height="44" rx="7" fill="{col}"/>'
            f'<rect x="{x-8}" y="{y-12}" width="16" height="22" rx="4" fill="url(#glass)"/>'
            f'<rect x="{x-8}" y="{y-20}" width="4" height="3" rx="1" fill="{GOLD}"/><rect x="{x+4}" y="{y-20}" width="4" height="3" rx="1" fill="{GOLD}"/>'
        )
    b += vcar(56, 68, "#E0533A") + vcar(92, 68, "#3A8DDE") + vcar(164, 68, "#F2B630")
    b += vcar(128, 190, WHITE) + vcar(200, 190, "#2FA05A") + vcar(56, 190, "#A15CC9")
    b += f'<rect x="206" y="96" width="5" height="42" fill="{INK}"/>'
    b += f'<rect x="192" y="66" width="34" height="34" rx="7" fill="#2A6FD0" stroke="{WHITE}" stroke-width="3"/>'
    b += f'<path d="M203 90 v-16 h8 a6 6 0 0 1 0 12 h-8" fill="none" stroke="{WHITE}" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/>'
    return svg(b, defs=d)


# ---------------------------------------------------------------- role icons

def role_icon(color, glyph):
    return svg(
        '<circle cx="32" cy="34" r="29" fill="#000" opacity="0.28"/>'
        f'<circle cx="32" cy="32" r="29" fill="{color}"/>'
        '<circle cx="32" cy="32" r="29" fill="none" stroke="#FFFFFF" stroke-opacity="0.45" stroke-width="2.5"/>'
        + glyph,
        64,
    )


def icon_role_student():
    g = '<polygon points="32,15 10,26 32,37 54,26" fill="#FFFFFF"/>'
    g += '<path d="M20 32 v9 q12 8 24 0 v-9 l-12 6z" fill="#FFFFFF" opacity="0.9"/>'
    g += '<line x1="50" y1="27" x2="50" y2="42" stroke="#FFE68A" stroke-width="2.6"/><circle cx="50" cy="44" r="3" fill="#FFE68A"/>'
    return role_icon("#4F8BEA", g)


def icon_role_worker():
    g = '<rect x="15" y="25" width="34" height="23" rx="4" fill="#FFFFFF"/>'
    g += '<path d="M25 25 v-4 a3 3 0 0 1 3 -3 h8 a3 3 0 0 1 3 3 v4" fill="none" stroke="#FFFFFF" stroke-width="3.2"/>'
    g += '<rect x="15" y="34" width="34" height="3" fill="#E5A12B" opacity="0.7"/><rect x="29" y="32" width="6" height="7" rx="1.5" fill="#E5A12B"/>'
    return role_icon("#E5A12B", g)


def icon_role_child():
    g = '<circle cx="32" cy="23" r="9" fill="#FFFFFF"/>'
    g += '<path d="M22 49 v-8 a10 10 0 0 1 20 0 v8z" fill="#FFFFFF"/>'
    g += '<circle cx="22" cy="19" r="4" fill="#FFFFFF"/><circle cx="42" cy="19" r="4" fill="#FFFFFF"/>'
    g += '<circle cx="29" cy="23" r="1.6" fill="#E2569C"/><circle cx="35" cy="23" r="1.6" fill="#E2569C"/>'
    g += '<path d="M29 27.5 q3 3 6 0" fill="none" stroke="#E2569C" stroke-width="1.6" stroke-linecap="round"/>'
    return role_icon("#E2569C", g)


def icon_role_older():
    g = '<circle cx="28" cy="19" r="8" fill="#FFFFFF"/>'
    g += '<path d="M18 49 v-11 a10 10 0 0 1 20 0 v11z" fill="#FFFFFF"/>'
    g += '<path d="M44 32 v18 M44 32 q0 -6 6 -6 q4 0 4 4" fill="none" stroke="#FFFFFF" stroke-width="3.4" stroke-linecap="round"/>'
    g += '<path d="M20 15 q8 -9 16 0" fill="none" stroke="#8C6CC4" stroke-width="2.2" opacity="0.55"/>'
    return role_icon("#8C6CC4", g)


def icon_role_access():
    """Resident with a disability: a person in a wheelchair, white on teal."""
    g = '<circle cx="30" cy="15" r="5.5" fill="#FFFFFF"/>'
    g += '<path d="M30 23 v13 h13 l5 9" fill="none" stroke="#FFFFFF" stroke-width="4.2" stroke-linecap="round" stroke-linejoin="round"/>'
    g += '<path d="M30 29 h10" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/>'
    g += '<path d="M23 31 a12.5 12.5 0 1 0 17 17" fill="none" stroke="#FFFFFF" stroke-width="4.2" stroke-linecap="round"/>'
    return role_icon("#2FA3A0", g)


def icon_role_expat():
    """Expat: a globe with a small plane, white on orange."""
    g = '<circle cx="30" cy="33" r="16" fill="none" stroke="#FFFFFF" stroke-width="3.4"/>'
    g += '<ellipse cx="30" cy="33" rx="7" ry="16" fill="none" stroke="#FFFFFF" stroke-width="2.6"/>'
    g += '<path d="M14 33 h32 M17 24 h26 M17 42 h26" fill="none" stroke="#FFFFFF" stroke-width="2.4"/>'
    g += '<path d="M40 12 l14 -2 l-6 6 l2 8 l-4 -3 l-3 4 l-1 -6 l-6 -2 z" fill="#FFE2C4" stroke="#D8682B" stroke-width="1.6" stroke-linejoin="round"/>'
    return role_icon("#D8682B", g)


def icon_event():
    """Event deck emblem: a gold star on a green disc."""
    import math
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = 22 if k % 2 == 0 else 10
        pts.append(f"{32 + r * math.cos(a):.1f},{33 + r * math.sin(a):.1f}")
    b = '<circle cx="32" cy="34" r="29" fill="#000" opacity="0.28"/><circle cx="32" cy="32" r="29" fill="#2FA05A"/>'
    b += '<circle cx="32" cy="32" r="29" fill="none" stroke="#FFE68A" stroke-width="3"/>'
    b += f'<polygon points="{" ".join(pts)}" fill="#FFE68A" stroke="#B9810F" stroke-width="2.5" stroke-linejoin="round"/>'
    return svg(b, 64)


def icon_penalty():
    """Penalty deck emblem: a warning triangle on a red disc."""
    b = '<circle cx="32" cy="34" r="29" fill="#000" opacity="0.28"/><circle cx="32" cy="32" r="29" fill="#C8402A"/>'
    b += '<circle cx="32" cy="32" r="29" fill="none" stroke="#FFD0C4" stroke-width="3"/>'
    b += '<path d="M32 12 L54 50 H10 Z" fill="#F2C21C" stroke="#7A1C10" stroke-width="3.5" stroke-linejoin="round"/>'
    b += '<rect x="29.5" y="24" width="5" height="14" rx="2.5" fill="#3A140E"/><circle cx="32" cy="44" r="3" fill="#3A140E"/>'
    return svg(b, 64)


TILE_CLIP_MARKER = 'stroke-opacity="0.28" stroke-width="3"/>'


def clip_to_tile(svg_text):
    """Keeps a tile's drawing inside its border: everything drawn after the frame is clipped to the
    inner ground area, so paths, trees and roofs end at the border instead of crossing it."""
    if TILE_CLIP_MARKER not in svg_text:
        return svg_text
    head, rest = svg_text.split("</defs>", 1)
    body, tail = rest.rsplit("</svg>", 1)
    cut = body.index(TILE_CLIP_MARKER) + len(TILE_CLIP_MARKER)
    head += '<clipPath id="tile-clip"><rect x="10" y="10" width="236" height="236" rx="22"/></clipPath>'
    return head + "</defs>" + body[:cut] + '<g clip-path="url(#tile-clip)">' + body[cut:] + "</g></svg>\n"


def main():
    os.makedirs(TILES, exist_ok=True)
    os.makedirs(UI, exist_ok=True)
    from gen_homes import HOMES  # one building per household, see tools/gen_homes.py
    tiles = {
        "amenity_cafe": amenity_cafe(),
        "amenity_clinic": amenity_clinic(), "amenity_school": amenity_school(),
        "amenity_market": amenity_market(), "park": park(), "trees": trees(),
        "lot": lot(), "shade_edge": shade_edge(),
        "student_small": student_small(), "student_large": student_large(),
        "commercial": commercial(), "university": university(), "library": library(),
        "bookshop": bookshop(), "print_shop": print_shop(), "kiosk": kiosk(),
        "restaurant": restaurant(), "supermarket": supermarket(), "hospital": hospital(),
        "parking": parking(),
    }
    for name, draw in HOMES.items():
        tiles[name] = draw()
    for m in range(16):
        tiles[f"road_{m}"] = road(m)
        for style in ("shaded", "pedestrian", "bike"):
            tiles[f"road_{style}_{m}"] = road(m, style)
    for name, content in tiles.items():
        if not name.startswith("road_"):
            content = clip_to_tile(content)
        with open(os.path.join(TILES, name + ".svg"), "w", encoding="utf-8") as f:
            f.write(content)
    icons = {
        "coin": coin(), "citizen": icon_citizen(), "pollution": icon_pollution(),
        "leaf": icon_leaf(), "sun": icon_sun(), "bank": icon_bank(), "route": icon_route(),
        "walk": icon_walk(), "sprout": icon_sprout(), "trophy": icon_trophy(), "crown": icon_crown(),
        "role_student": icon_role_student(), "role_worker": icon_role_worker(),
        "role_child": icon_role_child(), "role_older": icon_role_older(),
        "role_access": icon_role_access(), "role_expat": icon_role_expat(),
        "event": icon_event(), "penalty": icon_penalty(),
    }
    for name, content in icons.items():
        with open(os.path.join(UI, name + ".svg"), "w", encoding="utf-8") as f:
            f.write(content)
    print(f"wrote {len(tiles)} tiles and {len(icons)} icons")


if __name__ == "__main__":
    main()
