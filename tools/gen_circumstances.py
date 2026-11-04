"""Generates the 32 hidden circumstance card illustrations for Redesign the City.

Run from the project root:  python tools/gen_circumstances.py
Uses the palette and helpers of gen_art.py. Each card is a 256x256 scene with a rim in the
card's tint, so a card is recognised at a glance even at 48 px.
"""
import os

from gen_art import (
    ROOT, svg, lin, box, person, round_tree, solar_heater, ground_shadow, door, GLASS_DEFS,
    WHITE, WHITE_SIDE, WHITE_TOP, SHUTTER, GLASS_DARK, TERRACOTTA, TERRACOTTA_DARK, BOUG,
    TRUNK, OLIVE, OLIVE_DARK, INK, GOLD, SHADOW,
)

CIRCUMSTANCES = os.path.join(ROOT, "assets", "circumstances")


def circumstance_frame(tint, sky1, sky2):
    """Rim in the card's tint, a sky gradient inside, and a clip so scenes stay in the frame."""
    d = lin("sky", sky1, sky2)
    d += '<clipPath id="inner"><rect x="10" y="10" width="236" height="236" rx="22"/></clipPath>'
    b = f'<rect x="3" y="3" width="250" height="250" rx="28" fill="{tint}"/>'
    b += '<rect x="10" y="10" width="236" height="236" rx="22" fill="url(#sky)"/>'
    return d, b


def circumstance_finish(scene):
    """Wraps the scene in the clip and adds the soft inner highlight."""
    return (
        f'<g clip-path="url(#inner)">{scene}</g>'
        '<rect x="11.5" y="11.5" width="233" height="233" rx="21" fill="none" '
        'stroke="#FFFFFF" stroke-opacity="0.3" stroke-width="3"/>'
    )


def house_row(y, haze=0.0, tint="#F8F4EA"):
    """Three flat-roofed white houses on the horizon, with a solar heater on one (very Cypriot)."""
    b = ""
    for x, w, h, dy in [(14, 62, 58, 12), (92, 74, 76, 14), (180, 66, 52, 12)]:
        b += box(x, y - h, w, h, 16, dy, WHITE, WHITE_SIDE, WHITE_TOP)
        for k in range(2 if w < 70 else 3):
            b += f'<rect x="{x + 9 + k * 20}" y="{y - h + 14}" width="12" height="16" rx="2" fill="{GLASS_DARK}"/>'
        b += f'<rect x="{x + w / 2 - 6}" y="{y - 20}" width="12" height="20" rx="6" fill="{SHUTTER}"/>'
    b += solar_heater(112, y - 76)
    if haze:
        b += f'<rect x="0" y="{y - 90}" width="256" height="110" fill="{tint}" opacity="{haze}"/>'
    return b


def street(y, color="#D9CDB2", edge="#B8AA8C"):
    b = f'<rect x="0" y="{y}" width="256" height="{256 - y}" fill="{color}"/>'
    b += f'<rect x="0" y="{y}" width="256" height="8" fill="{edge}"/>'
    return b


def sun(cx, cy, r, core="#F2B630", glow="#FFE68A", rays=12, ray_color="#F28C28"):
    b = f'<circle cx="{cx}" cy="{cy}" r="{r * 1.9}" fill="{glow}" opacity="0.35"/>'
    for k in range(rays):
        b += (f'<rect x="{cx - 3}" y="{cy - r * 1.7}" width="6" height="{r * 0.6}" rx="3" fill="{ray_color}" '
              f'transform="rotate({k * 360 / rays} {cx} {cy})"/>')
    b += f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{core}"/>'
    b += f'<circle cx="{cx - r * 0.3}" cy="{cy - r * 0.3}" r="{r * 0.34}" fill="#FFF1B0"/>'
    return b


def cloud(cx, cy, s=1.0, fill="#FFFFFF", shade="#DCE8F2"):
    return (
        f'<g transform="translate({cx} {cy}) scale({s})">'
        f'<ellipse cx="0" cy="10" rx="46" ry="16" fill="{shade}"/>'
        f'<circle cx="-22" cy="2" r="18" fill="{fill}"/><circle cx="2" cy="-8" r="24" fill="{fill}"/>'
        f'<circle cx="26" cy="2" r="17" fill="{fill}"/><rect x="-40" y="2" width="80" height="16" rx="8" fill="{fill}"/>'
        f'</g>'
    )


def circumstance_heatwave():
    d, b = circumstance_frame("#E8743B", "#FF9F45", "#FFE7A3")
    s = sun(78, 70, 34, ray_color="#E8743B")
    s += house_row(172, haze=0.12, tint="#FFD27A")
    s += street(172, "#EBCB92", "#C9A25B")
    s += '<path d="M0 214 H256" stroke="#C9A25B" stroke-width="3" stroke-dasharray="22 16" opacity="0.7"/>'
    # heat shimmer rising off the street
    for x in (30, 84, 142, 198):
        s += f'<path d="M{x} 206 q8 -12 0 -24 t0 -24" fill="none" stroke="#FFF6D8" stroke-width="4" stroke-linecap="round" opacity="0.7"/>'
    # thermometer
    s += '<rect x="192" y="34" width="26" height="110" rx="13" fill="#FFFFFF" stroke="#B9810F" stroke-width="3"/>'
    s += '<circle cx="205" cy="152" r="20" fill="#FFFFFF" stroke="#B9810F" stroke-width="3"/>'
    s += '<rect x="199" y="58" width="12" height="94" rx="6" fill="#D93A2A"/><circle cx="205" cy="152" r="14" fill="#D93A2A"/>'
    for y in (48, 68, 88, 108):
        s += f'<line x1="218" y1="{y}" x2="228" y2="{y}" stroke="#B9810F" stroke-width="3" stroke-linecap="round"/>'
    s += '<circle cx="201" cy="148" r="4" fill="#FF9C8E"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_flash_flood():
    d, b = circumstance_frame("#3A8DDE", "#4F6E88", "#A9BFD0")
    s = cloud(70, 48, 1.15, "#6E8499", "#566B80") + cloud(176, 40, 1.0, "#7B91A6", "#5E7389")
    s += house_row(150, haze=0.18, tint="#8FA6B8")
    s += street(150, "#9AA5AE", "#7C8791")
    # flood water over the street
    s += '<path d="M0 176 Q32 166 64 176 T128 176 T192 176 T256 176 V256 H0Z" fill="#3C9BCB"/>'
    s += '<path d="M0 200 Q32 190 64 200 T128 200 T192 200 T256 200 V256 H0Z" fill="#2E7FB0"/>'
    s += '<path d="M0 226 Q32 216 64 226 T128 226 T192 226 T256 226 V256 H0Z" fill="#256A97"/>'
    for x, y in [(36, 188), (118, 210), (200, 190), (70, 238), (170, 240)]:
        s += f'<ellipse cx="{x}" cy="{y}" rx="16" ry="4" fill="none" stroke="#CFEFFB" stroke-width="2.5" opacity="0.8"/>'
    # rain
    for k in range(16):
        x = 12 + (k * 47) % 236
        y = 64 + (k * 31) % 90
        s += f'<line x1="{x}" y1="{y}" x2="{x - 9}" y2="{y + 26}" stroke="#DDF1FF" stroke-width="3.5" stroke-linecap="round" opacity="0.85"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_dust_storm():
    d, b = circumstance_frame("#C9A25B", "#E7B565", "#D49A4D")
    s = '<circle cx="190" cy="66" r="30" fill="#F6D9A0" opacity="0.8"/>'
    s += house_row(166, haze=0.35, tint="#D9A24E")
    s += street(166, "#D8B070", "#B98C47")
    # swirling bands of dust
    for y, op, w in [(70, 0.5, 7), (104, 0.6, 9), (140, 0.55, 8), (188, 0.6, 10), (222, 0.5, 8)]:
        s += (f'<path d="M-10 {y} C40 {y - 22} 70 {y + 22} 124 {y} S200 {y - 22} 270 {y}" fill="none" '
              f'stroke="#F3D79B" stroke-width="{w}" stroke-linecap="round" opacity="{op}"/>')
    s += '<rect x="0" y="150" width="256" height="106" fill="#D9A24E" opacity="0.28"/>'
    # grit
    for k in range(26):
        x = (k * 37) % 250 + 3
        y = 30 + (k * 53) % 210
        s += f'<circle cx="{x}" cy="{y}" r="{2 + k % 3}" fill="#9E6B2D" opacity="0.55"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_nice_weather():
    d, b = circumstance_frame("#7FB346", "#6EBBF0", "#DDF3FF")
    s = sun(70, 62, 28, rays=10, ray_color="#F2B630")
    s += cloud(190, 52, 0.9) + cloud(120, 96, 0.55)
    s += house_row(158)
    s += street(158, "#E3D9C2", "#C4B896")
    # grass verge with trees that shade the walk
    s += '<rect x="0" y="158" width="256" height="30" fill="#A3D163"/>'
    s += round_tree(54, 150, 30) + round_tree(206, 152, 28, OLIVE, OLIVE_DARK, "#B6C68E")
    s += '<ellipse cx="128" cy="214" rx="104" ry="14" fill="#2F5D34" opacity="0.18"/>'
    s += person(98, 232, "#D6337A", s=1.05) + person(150, 232, "#2E6DA4", s=1.0)
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_budget_cut():
    d, b = circumstance_frame("#B9810F", "#35566B", "#173A52")
    d += lin("note", "#BFE5A0", "#7FB346")
    s = ""
    # coin stack
    for y in (196, 178, 160, 142):
        s += f'<ellipse cx="86" cy="{y + 8}" rx="42" ry="13" fill="#B9810F"/>'
        s += f'<rect x="44" y="{y - 6}" width="84" height="14" fill="#E3A21E"/>'
        s += f'<ellipse cx="86" cy="{y - 6}" rx="42" ry="13" fill="#F2B630"/>'
        s += f'<ellipse cx="86" cy="{y - 6}" rx="30" ry="8" fill="none" stroke="#FFE68A" stroke-width="2.5"/>'
    # banknote being cut in half
    s += '<g transform="rotate(-8 170 82)">'
    s += '<rect x="112" y="50" width="106" height="62" rx="8" fill="url(#note)" stroke="#4C7F2B" stroke-width="3"/>'
    s += '<circle cx="165" cy="81" r="16" fill="#F2B630" stroke="#B9810F" stroke-width="3"/>'
    s += '<rect x="120" y="58" width="14" height="8" rx="2" fill="#4C7F2B" opacity="0.6"/>'
    s += '<rect x="196" y="96" width="14" height="8" rx="2" fill="#4C7F2B" opacity="0.6"/>'
    s += '</g>'
    # scissors
    s += '<g transform="translate(166 82) rotate(90)">'
    s += '<path d="M0 0 L58 -10 L58 -4 Z" fill="#E8EEF2"/><path d="M0 0 L58 10 L58 4 Z" fill="#C5D0D8"/>'
    s += '<circle cx="-14" cy="-12" r="11" fill="none" stroke="#E0533A" stroke-width="6"/>'
    s += '<circle cx="-14" cy="12" r="11" fill="none" stroke="#E0533A" stroke-width="6"/>'
    s += '<circle cx="0" cy="0" r="4" fill="#59616F"/>'
    s += '</g>'
    s += '<line x1="166" y1="38" x2="166" y2="128" stroke="#FFFFFF" stroke-width="3" stroke-dasharray="6 7" opacity="0.8"/>'
    # falling red arrow
    s += '<path d="M200 140 h26 v40 h18 l-31 40 l-31 -40 h18 z" fill="#E0533A" stroke="#8E2A1A" stroke-width="3" stroke-linejoin="round"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_grant():
    d, b = circumstance_frame("#5E9B3A", "#A5D96A", "#E7F6C8")
    s = sun(204, 54, 22, rays=10, ray_color="#F2B630")
    s += '<rect x="0" y="206" width="256" height="50" fill="#7FB346"/>'
    s += '<ellipse cx="128" cy="226" rx="92" ry="18" fill="#6B7F48" opacity="0.5"/>'
    # sapling growing out of a pot
    s += f'<path d="M128 206 C128 170 126 150 128 120" fill="none" stroke="{TRUNK}" stroke-width="9" stroke-linecap="round"/>'
    s += round_tree(128, 100, 38) + round_tree(88, 140, 22, "#86BE52", "#5E9B3A") + round_tree(170, 138, 24, "#86BE52", "#5E9B3A")
    s += '<path d="M104 206 h48 l-6 -20 h-36 z" fill="#C65A35"/><rect x="100" y="200" width="56" height="10" rx="3" fill="#9A4226"/>'
    # coins raining down onto the tree
    for x, y, r in [(52, 52, 17), (84, 24, 14), (178, 28, 16), (222, 100, 15), (36, 120, 14)]:
        s += f'<circle cx="{x}" cy="{y}" r="{r}" fill="#B9810F"/><circle cx="{x}" cy="{y - 1.5}" r="{r - 2.5}" fill="#F2B630"/>'
        s += f'<circle cx="{x}" cy="{y - 1.5}" r="{r - 6.5}" fill="none" stroke="#FFE68A" stroke-width="2"/>'
    for x, y in [(70, 82), (206, 70), (24, 80)]:
        s += (f'<path d="M{x} {y - 8} L{x + 2.5} {y - 2.5} L{x + 8} {y} L{x + 2.5} {y + 2.5} L{x} {y + 8} '
              f'L{x - 2.5} {y + 2.5} L{x - 8} {y} L{x - 2.5} {y - 2.5}Z" fill="#FFFFFF"/>')
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_road_works():
    d, b = circumstance_frame("#E0A030", "#FFD27A", "#FFF0C8")
    d += '<clipPath id="bar"><rect x="34" y="148" width="188" height="22" rx="4"/></clipPath>'
    s = house_row(112)
    s += street(112, "#59616F", "#3E4552")
    s += '<path d="M0 134 H256" stroke="#F8F4EA" stroke-width="5" stroke-dasharray="26 18" opacity="0.85"/>'
    # pit in the road
    s += '<ellipse cx="128" cy="206" rx="78" ry="24" fill="#2D323B"/><ellipse cx="128" cy="200" rx="68" ry="18" fill="#7A5536"/>'
    s += '<ellipse cx="128" cy="196" rx="52" ry="11" fill="#9A7A52"/>'
    # striped barrier
    s += '<rect x="42" y="158" width="6" height="40" fill="#59616F"/><rect x="208" y="158" width="6" height="40" fill="#59616F"/>'
    s += '<rect x="34" y="148" width="188" height="22" rx="4" fill="#F8F4EA"/>'
    s += '<g clip-path="url(#bar)">'
    for k in range(8):
        s += f'<polygon points="{30 + k * 28},170 {44 + k * 28},170 {58 + k * 28},148 {44 + k * 28},148" fill="#E0533A"/>'
    s += '</g><rect x="34" y="148" width="188" height="22" rx="4" fill="none" stroke="#3E4552" stroke-width="3"/>'
    # cones
    for x in (24, 232):
        s += (f'<polygon points="{x - 15},232 {x + 15},232 {x + 6},180 {x - 6},180" fill="#F2762E"/>'
              f'<polygon points="{x - 11},214 {x + 11},214 {x + 9},203 {x - 9},203" fill="#FFFFFF"/>'
              f'<rect x="{x - 19}" y="230" width="38" height="8" rx="3" fill="#2D323B"/>')
    # warning sign
    s += '<rect x="122" y="100" width="8" height="52" fill="#59616F"/>'
    s += '<polygon points="126,34 164,100 88,100" fill="#FFD23A" stroke="#2D323B" stroke-width="5" stroke-linejoin="round"/>'
    s += '<path d="M118 90 l8 -22 l8 22 z" fill="#2D323B"/><rect x="112" y="90" width="28" height="5" fill="#2D323B"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_new_attractor():
    d, b = circumstance_frame("#D6337A", "#F7B7D2", "#FFE9F2")
    d += GLASS_DEFS
    s = street(176, "#E3D9C2", "#C4B896")
    # new school with a flag
    s += ground_shadow([(60, 176), (176, 176), (214, 156), (196, 110)])
    s += box(56, 98, 124, 78, 26, 16, WHITE, WHITE_SIDE, WHITE_TOP)
    s += f'<polygon points="50,98 118,60 186,98" fill="{TERRACOTTA}"/><polygon points="50,98 118,60 118,98" fill="{TERRACOTTA_DARK}" opacity="0.4"/>'
    for x in (70, 148):
        s += f'<rect x="{x}" y="116" width="24" height="26" rx="3" fill="url(#glass)"/>'
    s += door(106, 132, 24, 44)
    s += f'<line x1="118" y1="60" x2="118" y2="26" stroke="{INK}" stroke-width="3"/><polygon points="118,26 150,36 118,46" fill="{BOUG}"/>'
    # map pin above it
    s += '<g transform="translate(206 48)"><path d="M0 40 C-26 10 -26 -22 0 -24 C26 -22 26 10 0 40Z" fill="#D6337A" stroke="#FFFFFF" stroke-width="4"/><circle cx="0" cy="-3" r="9" fill="#FFFFFF"/></g>'
    # citizens walking in from both sides
    for x1, x2 in [(34, 92), (214, 150)]:
        s += f'<path d="M{x1} 196 Q{(x1 + x2) / 2} 178 {x2} 190" fill="none" stroke="#D6337A" stroke-width="4" stroke-dasharray="3 9" stroke-linecap="round"/>'
    for x, y, col, sc in [(24, 224, "#2E6DA4", 0.95), (60, 238, "#F2B630", 1.05), (176, 238, "#5E9B3A", 1.0), (222, 224, "#E0533A", 0.95)]:
        s += person(x, y, col, s=sc)
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_population_growth():
    d, b = circumstance_frame("#2A6496", "#8BC3EB", "#E4F3FD")
    d += GLASS_DEFS
    s = street(190, "#E3D9C2", "#C4B896")
    # apartment block behind the crowd
    s += box(70, 64, 116, 126, 26, 16, WHITE, WHITE_SIDE, WHITE_TOP)
    for r in range(3):
        for c in range(3):
            s += f'<rect x="{82 + c * 34}" y="{78 + r * 36}" width="20" height="24" rx="2" fill="url(#glass)"/>'
    s += solar_heater(100, 64)
    # a crowd of citizens, shortest at the edges
    crowd = [(40, 238, "#E0533A", 0.8), (84, 244, "#2E6DA4", 1.0), (128, 240, "#F2B630", 1.1),
             (172, 244, "#5E9B3A", 1.0), (214, 238, "#D6337A", 0.82)]
    for x, y, col, sc in crowd:
        s += person(x, y, col, s=sc)
    # plus badge
    s += '<circle cx="204" cy="60" r="30" fill="#5E9B3A" stroke="#FFFFFF" stroke-width="5"/>'
    s += '<rect x="190" y="55" width="28" height="10" rx="4" fill="#FFFFFF"/><rect x="199" y="46" width="10" height="28" rx="4" fill="#FFFFFF"/>'
    return svg(b + circumstance_finish(s), defs=d)


# ---------------------------------------------------------------- cards for the people and places of the city

def coin_shape(cx, cy, r=16):
    return (
        f'<circle cx="{cx + 2}" cy="{cy + 3}" r="{r}" fill="#8A5A0C" opacity="0.3"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#E3A21E" stroke="#B9810F" stroke-width="3"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r * 0.62:.1f}" fill="none" stroke="#FFE68A" stroke-width="2.4"/>'
        f'<path d="M{cx - r * 0.45:.1f} {cy - r * 0.45:.1f} A{r * 0.8:.1f} {r * 0.8:.1f} 0 0 1 {cx:.1f} {cy - r * 0.8:.1f}" fill="none" stroke="#FFF6C8" stroke-width="2.4" stroke-linecap="round"/>'
    )


def car_side(x, y, col, s=1.0):
    """A small car seen from the side, wheels on y."""
    return (
        f'<g transform="translate({x} {y}) scale({s})">'
        f'<ellipse cx="0" cy="2" rx="38" ry="5" fill="{SHADOW}" opacity="0.28"/>'
        f'<path d="M-36 -8 q0 -10 10 -10 l10 -14 q4 -6 12 -6 h12 q8 0 12 6 l8 14 q10 0 10 10 v8 h-74z" fill="{col}"/>'
        f'<path d="M-16 -20 l6 -10 h12 v10z M6 -20 v-10 h8 l8 10z" fill="url(#glass)"/>'
        f'<circle cx="-20" cy="2" r="9" fill="{INK}"/><circle cx="20" cy="2" r="9" fill="{INK}"/>'
        f'<circle cx="-20" cy="2" r="4" fill="#B8C2CC"/><circle cx="20" cy="2" r="4" fill="#B8C2CC"/>'
        f'</g>'
    )


def bunting(y, colors, x0=10, x1=246, n=9, sag=16):
    b = f'<path d="M{x0} {y} Q{(x0 + x1) / 2} {y + sag * 2} {x1} {y}" fill="none" stroke="{INK}" stroke-width="2.5"/>'
    for k in range(n):
        t = (k + 0.5) / n
        x = x0 + (x1 - x0) * t
        yy = y + sag * 2 * 2 * t * (1 - t)
        b += f'<polygon points="{x - 9:.1f},{yy:.1f} {x + 9:.1f},{yy:.1f} {x:.1f},{yy + 20:.1f}" fill="{colors[k % len(colors)]}"/>'
    return b


def circumstance_exam_season():
    d, b = circumstance_frame("#4F8BEA", "#A9C6F5", "#EAF1FF")
    d += GLASS_DEFS
    s = '<rect x="0" y="176" width="256" height="80" fill="#8B5E3C"/><rect x="0" y="176" width="256" height="10" fill="#A7774F"/>'
    # clock on the wall
    s += f'<circle cx="198" cy="64" r="30" fill="{WHITE}" stroke="{INK}" stroke-width="5"/>'
    s += f'<path d="M198 64 V44 M198 64 L212 72" stroke="{INK}" stroke-width="4.5" stroke-linecap="round"/><circle cx="198" cy="64" r="4" fill="#D63A3A"/>'
    # tall pile of papers with an A+
    s += f'<rect x="28" y="120" width="62" height="58" rx="3" fill="{WHITE}" stroke="{WHITE_SIDE}" stroke-width="3"/>'
    s += f'<rect x="34" y="106" width="62" height="16" rx="3" fill="#F7F1E1" stroke="{WHITE_SIDE}" stroke-width="3"/>'
    s += '<path d="M42 146 l14 14 l26 -30" fill="none" stroke="#D63A3A" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>'
    # open book
    s += f'<path d="M96 206 L156 190 L216 206 L216 226 L156 212 L96 226z" fill="{WHITE}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    s += f'<line x1="156" y1="190" x2="156" y2="212" stroke="{INK}" stroke-width="3"/>'
    s += '<path d="M108 204 l38 -9 M108 212 l38 -9 M166 195 l38 9 M166 203 l38 9" stroke="#9FB3C2" stroke-width="2.5"/>'
    # pencil and lamp
    s += f'<g transform="rotate(-28 70 208)"><rect x="40" y="200" width="70" height="12" fill="{GOLD}"/><polygon points="110,200 128,206 110,212" fill="#F1D3A6"/><polygon points="122,204 128,206 122,208" fill="{INK}"/><rect x="34" y="200" width="8" height="12" fill="#E5758E"/></g>'
    s += f'<path d="M214 176 v-40 l-26 -22" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/><path d="M168 108 l30 -14 l14 24 z" fill="#2F63B8"/>'
    s += '<path d="M176 126 L206 120" stroke="#FFE68A" stroke-width="6" stroke-linecap="round" opacity="0.8"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_flu_wave():
    d, b = circumstance_frame("#3BA27A", "#BFE3D5", "#F0FAF5")
    s = ""
    # germs
    for x, y, r, col in [(60, 70, 22, "#7DBB3D"), (190, 62, 16, "#9CCB5A"), (206, 140, 20, "#7DBB3D"), (46, 150, 13, "#9CCB5A")]:
        for k in range(10):
            s += f'<line x1="{x}" y1="{y}" x2="{x}" y2="{y - r - 9}" stroke="{col}" stroke-width="4" stroke-linecap="round" transform="rotate({k * 36} {x} {y})"/>'
            s += f'<circle cx="{x}" cy="{y - r - 10}" r="3.5" fill="{col}" transform="rotate({k * 36} {x} {y})"/>'
        s += f'<circle cx="{x}" cy="{y}" r="{r}" fill="{col}"/><circle cx="{x - r * 0.3:.1f}" cy="{y - r * 0.3:.1f}" r="{r * 0.28:.1f}" fill="#E5F6C8"/>'
        s += f'<circle cx="{x - r * 0.28:.1f}" cy="{y + r * 0.05:.1f}" r="2.2" fill="{INK}"/><circle cx="{x + r * 0.28:.1f}" cy="{y + r * 0.05:.1f}" r="2.2" fill="{INK}"/>'
    # tissue box
    s += f'<rect x="92" y="170" width="76" height="46" rx="6" fill="#7FC8E8" stroke="#3A8DDE" stroke-width="4"/>'
    s += f'<ellipse cx="130" cy="170" rx="22" ry="7" fill="{INK}" opacity="0.55"/><path d="M118 168 q6 -26 14 -4 q8 -22 14 4z" fill="{WHITE}"/>'
    # thermometer
    s += f'<g transform="rotate(35 128 120)"><rect x="104" y="108" width="82" height="16" rx="8" fill="{WHITE}" stroke="{INK}" stroke-width="3"/><circle cx="104" cy="116" r="12" fill="#D93A2A" stroke="{INK}" stroke-width="3"/><rect x="108" y="112" width="52" height="8" rx="4" fill="#D93A2A"/></g>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_supply_shortage():
    d, b = circumstance_frame("#C9742E", "#F3D4B0", "#FFF1DE")
    s = ""
    # empty shelves
    for y in (74, 132, 190):
        s += f'<rect x="22" y="{y}" width="212" height="9" rx="2" fill="#8B5E3C"/>'
    s += '<rect x="22" y="40" width="9" height="160" fill="#7A5232"/><rect x="225" y="40" width="9" height="160" fill="#7A5232"/>'
    # a few lonely items
    s += '<rect x="46" y="44" width="26" height="30" rx="4" fill="#E0533A"/><rect x="46" y="52" width="26" height="8" fill="#F8F4EA"/>'
    s += '<rect x="170" y="102" width="30" height="30" rx="4" fill="#F4D23C" stroke="#C9A61C" stroke-width="2"/>'
    s += '<rect x="108" y="160" width="26" height="30" rx="4" fill="#79C060"/><rect x="108" y="168" width="26" height="8" fill="#F8F4EA"/>'
    # price tags and cobweb dust
    for x in (60, 120, 190):
        s += f'<rect x="{x}" y="{82 if x != 120 else 140}" width="26" height="14" rx="2" fill="{WHITE}" stroke="{INK}" stroke-width="2"/>'
    s += '<path d="M24 42 q20 4 30 24 M24 42 q8 22 6 30 M24 42 q26 -2 40 14" fill="none" stroke="#B7AE9B" stroke-width="2" opacity="0.8"/>'
    # empty basket with a sad sign
    s += f'<path d="M84 214 h88 l-10 28 h-68z" fill="#C58A52" stroke="#7A5232" stroke-width="3"/>'
    s += f'<path d="M100 214 a28 22 0 0 1 56 0" fill="none" stroke="#7A5232" stroke-width="4"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_back_to_school():
    d, b = circumstance_frame("#E2569C", "#FAD0E4", "#FFF0F7")
    d += GLASS_DEFS
    s = sun(210, 50, 20, rays=10, ray_color="#F2B630")
    s += street(188, "#8B95A1", "#6B7684")
    s += '<path d="M0 222 H256" stroke="#F2C21C" stroke-width="4" stroke-dasharray="26 18"/>'
    # school bus
    s += f'<rect x="30" y="102" width="176" height="82" rx="14" fill="#F5B800" stroke="#B88700" stroke-width="4"/>'
    s += f'<rect x="30" y="148" width="176" height="8" fill="{INK}" opacity="0.8"/>'
    for x in (44, 84, 124, 164):
        s += f'<rect x="{x}" y="114" width="30" height="30" rx="4" fill="url(#glass)" stroke="#B88700" stroke-width="3"/>'
    s += f'<path d="M206 118 h22 q10 0 10 12 v54 h-32z" fill="#F5B800" stroke="#B88700" stroke-width="4"/><rect x="210" y="124" width="22" height="28" rx="3" fill="url(#glass)"/>'
    s += f'<circle cx="74" cy="188" r="17" fill="{INK}"/><circle cx="74" cy="188" r="7" fill="#B8C2CC"/><circle cx="176" cy="188" r="17" fill="{INK}"/><circle cx="176" cy="188" r="7" fill="#B8C2CC"/>'
    # backpack and apple in front
    s += f'<rect x="20" y="198" width="38" height="44" rx="12" fill="#E2569C" stroke="#A52264" stroke-width="3"/><rect x="26" y="220" width="26" height="16" rx="5" fill="#F08AB8"/>'
    s += f'<circle cx="214" cy="226" r="14" fill="#D63A3A"/><path d="M214 212 q2 -10 8 -12" fill="none" stroke="{TRUNK}" stroke-width="3" stroke-linecap="round"/><ellipse cx="222" cy="204" rx="6" ry="3" fill="#5E9B3A"/>'
    s += person(120, 240, "#3A8DDE", s=0.9)
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_parking_shortage():
    d, b = circumstance_frame("#5C6BC0", "#C9CFF2", "#F0F2FF")
    d += GLASS_DEFS
    s = street(108, "#6B7684", "#59616F")
    # packed bays with a car in each
    for k, col in enumerate(["#E0533A", "#3A8DDE", "#F2B630", "#2FA05A", "#A15CC9", "#F8F4EA"]):
        x = 18 + k * 38
        s += f'<line x1="{x}" y1="120" x2="{x}" y2="196" stroke="{WHITE}" stroke-width="3"/>'
        s += f'<rect x="{x + 7}" y="126" width="24" height="52" rx="8" fill="{col}"/><rect x="{x + 11}" y="138" width="16" height="22" rx="4" fill="url(#glass)"/>'
    s += f'<line x1="246" y1="120" x2="246" y2="196" stroke="{WHITE}" stroke-width="3"/>'
    # a lone car circling, with an arrow
    s += car_side(110, 232, "#E0533A", 0.8)
    s += '<path d="M168 228 a30 22 0 1 0 -6 -18" fill="none" stroke="#D63A3A" stroke-width="5" stroke-linecap="round"/><polygon points="156,200 172,210 154,216" fill="#D63A3A"/>'
    # big P sign
    s += f'<rect x="120" y="52" width="9" height="62" fill="{INK}"/>'
    s += f'<rect x="84" y="22" width="82" height="62" rx="12" fill="#2A6FD0" stroke="{WHITE}" stroke-width="5"/>'
    s += f'<path d="M110 70 v-32 h20 a11 11 0 0 1 0 22 h-20" fill="none" stroke="{WHITE}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>'
    s += f'<rect x="150" y="60" width="64" height="24" rx="4" fill="#D63A3A" stroke="{WHITE}" stroke-width="3" transform="rotate(-8 182 72)"/>'
    s += f'<rect x="164" y="68" width="36" height="8" rx="2" fill="{WHITE}" transform="rotate(-8 182 72)"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_traffic_jam():
    d, b = circumstance_frame("#B5483A", "#F0C9BF", "#FFF1EE")
    d += GLASS_DEFS
    s = house_row(120, haze=0.1, tint="#F0C9BF")
    s += street(120, "#6B7684", "#59616F")
    s += '<path d="M0 190 H256" stroke="#F2C21C" stroke-width="4" stroke-dasharray="24 16"/>'
    # cars bumper to bumper
    for x, col, y in [(48, "#E0533A", 172), (126, "#3A8DDE", 172), (204, "#F2B630", 172), (88, "#2FA05A", 236), (170, "#A15CC9", 236)]:
        s += car_side(x, y, col, 0.95)
    # traffic light
    s += f'<rect x="118" y="26" width="9" height="40" fill="{INK}"/>'
    s += f'<rect x="102" y="-6" width="40" height="86" rx="10" fill="{INK}" transform="translate(0 6)"/>'
    s += '<circle cx="122" cy="26" r="11" fill="#E0533A"/><circle cx="122" cy="26" r="16" fill="#E0533A" opacity="0.25"/><circle cx="122" cy="52" r="9" fill="#5B4A18"/><circle cx="122" cy="76" r="9" fill="#1E4A2C"/>'
    # horn marks
    for dx, dy in [(-16, -8), (-20, 4), (-14, 16)]:
        s += f'<path d="M{44 + dx} {128 + dy} q-8 0 -8 8" fill="none" stroke="#D63A3A" stroke-width="3.5" stroke-linecap="round" transform="translate(-6 8)"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_drought():
    d, b = circumstance_frame("#D9A441", "#F6D58C", "#FFF3D2")
    s = sun(190, 60, 36, rays=14, ray_color="#E8743B")
    # cracked earth
    s += '<rect x="0" y="150" width="256" height="106" fill="#C58F4F"/><rect x="0" y="150" width="256" height="9" fill="#A66F36"/>'
    for pts in ["M20 170 l30 20 l-10 24 l30 22", "M90 164 l-8 34 l36 14 l-12 30", "M150 168 l24 26 l-18 22 l34 24", "M210 164 l-20 30 l30 18", "M60 238 l40 -14 l24 10", "M178 240 l30 -16"]:
        s += f'<path d="{pts}" fill="none" stroke="#7A4F22" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>'
    # a thirsty dead tree
    s += f'<path d="M72 168 V104 M72 126 L48 100 M72 116 L98 90 M48 100 L40 84 M98 90 L108 76" fill="none" stroke="#6A4A2A" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>'
    # empty water drop with a cross
    s += f'<path d="M168 190 q-26 -34 0 -60 q26 26 0 60z" fill="none" stroke="#3A8DDE" stroke-width="6" stroke-linejoin="round"/>'
    s += f'<path d="M154 150 l28 28 M182 150 l-28 28" stroke="#D63A3A" stroke-width="6" stroke-linecap="round"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_tourist_season():
    d, b = circumstance_frame("#2A9DB5", "#8FDDF0", "#EAFBFF")
    s = sun(60, 56, 26, rays=12, ray_color="#F2B630")
    s += '<rect x="0" y="170" width="256" height="86" fill="#F1DDA6"/><path d="M0 170 Q64 156 128 170 T256 170 V150 H0z" fill="#3FB8D0"/>'
    # beach umbrella
    s += f'<line x1="170" y1="86" x2="170" y2="214" stroke="{INK}" stroke-width="5"/>'
    s += f'<path d="M110 100 Q170 36 230 100 Z" fill="#E0533A"/>'
    for x in (126, 148, 170, 192, 214):
        s += f'<path d="M{x} 100 Q{x + 2} 70 170 56" fill="none" stroke="{WHITE}" stroke-width="5" opacity="0.9"/>'
    # camera
    s += f'<rect x="34" y="150" width="86" height="58" rx="10" fill="{INK}"/><rect x="34" y="150" width="86" height="16" rx="8" fill="#3A8DDE"/>'
    s += f'<circle cx="77" cy="184" r="19" fill="#6B7684" stroke="{WHITE}" stroke-width="4"/><circle cx="77" cy="184" r="10" fill="#3A8DDE"/><circle cx="72" cy="179" r="3.5" fill="{WHITE}"/>'
    s += f'<rect x="92" y="142" width="22" height="10" rx="3" fill="{INK}"/><circle cx="46" cy="162" r="4" fill="#D63A3A"/>'
    # suitcase
    s += f'<rect x="132" y="196" width="56" height="40" rx="6" fill="{GOLD}" stroke="#B9810F" stroke-width="3"/><path d="M148 196 v-8 h24 v8" fill="none" stroke="#B9810F" stroke-width="4"/>'
    s += f'<line x1="132" y1="214" x2="188" y2="214" stroke="#B9810F" stroke-width="3"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_health_campaign():
    d, b = circumstance_frame("#3BA27A", "#BFE3D5", "#F0FAF5")
    s = ""
    # big heart with a cross
    s += f'<path d="M128 214 C46 150 44 78 92 70 C112 68 124 80 128 94 C132 80 144 68 164 70 C212 78 210 150 128 214z" fill="#E0533A" stroke="#A52E22" stroke-width="5" stroke-linejoin="round"/>'
    s += f'<path d="M120 100 h16 v22 h22 v16 h-22 v22 h-16 v-22 h-22 v-16 h22z" fill="{WHITE}"/>'
    # stethoscope
    s += f'<path d="M34 62 q-8 70 36 78 q44 6 40 -30" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>'
    s += f'<circle cx="112" cy="106" r="11" fill="#98A4B1" stroke="{INK}" stroke-width="4"/><circle cx="34" cy="58" r="6" fill="{INK}"/><circle cx="52" cy="54" r="6" fill="{INK}"/>'
    # heartbeat line
    s += f'<path d="M20 226 h60 l12 -26 l16 44 l14 -34 h120" fill="none" stroke="#2FA05A" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_open_day():
    d, b = circumstance_frame("#4F8BEA", "#A9C6F5", "#EAF1FF")
    s = bunting(34, ["#E0533A", "#F2B630", "#2FA05A", "#3A8DDE", "#D6337A"])
    # university with columns and a banner
    s += f'<rect x="30" y="140" width="196" height="86" fill="#EADFC6"/><polygon points="52,140 204,140 128,92" fill="#F4ECD8" stroke="#CDBF9F" stroke-width="4"/>'
    s += f'<circle cx="128" cy="124" r="11" fill="#4F8BEA" stroke="{WHITE}" stroke-width="4"/>'
    for x in (58, 92, 126, 160, 194):
        s += f'<rect x="{x - 6}" y="144" width="14" height="76" fill="{WHITE}" stroke="#CDBF9F" stroke-width="2"/>'
    s += f'<rect x="108" y="180" width="40" height="46" rx="3" fill="#2F63B8"/>'
    s += '<rect x="16" y="226" width="224" height="12" rx="3" fill="#CDBF9F"/>'
    # balloons and a mortarboard
    for x, y, col in [(34, 112, "#E0533A"), (52, 96, "#F2B630"), (216, 108, "#2FA05A"), (232, 124, "#D6337A")]:
        s += f'<ellipse cx="{x}" cy="{y}" rx="12" ry="15" fill="{col}"/><path d="M{x} {y + 15} q-6 14 0 28" fill="none" stroke="{INK}" stroke-width="1.8"/>'
    s += f'<g transform="translate(128 66)"><polygon points="0,-14 -34,0 0,14 34,0" fill="{INK}"/><path d="M-18 8 v12 q18 9 36 0 v-12 l-18 8z" fill="{INK}" opacity="0.85"/><line x1="30" y1="1" x2="30" y2="22" stroke="{GOLD}" stroke-width="3"/><circle cx="30" cy="25" r="4" fill="{GOLD}"/></g>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_business_boom():
    d, b = circumstance_frame("#D4A017", "#FFE9A8", "#FFF8DD")
    s = ""
    # rising bars with a green arrow
    for k, h in enumerate([40, 66, 96, 130]):
        x = 30 + k * 40
        s += f'<rect x="{x}" y="{218 - h}" width="30" height="{h}" rx="4" fill="{["#F2B630", "#E5A12B", "#C98A1A", "#2FA05A"][k]}" stroke="{INK}" stroke-opacity="0.3" stroke-width="2"/>'
    s += '<path d="M30 130 L96 96 L132 112 L214 52" fill="none" stroke="#2FA05A" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>'
    s += '<polygon points="228,40 194,48 216,76" fill="#2FA05A"/>'
    # coins
    s += coin_shape(206, 190, 22) + coin_shape(176, 212, 16) + coin_shape(222, 220, 14)
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_tax_refund():
    d, b = circumstance_frame("#5E9B3A", "#CDE9B0", "#F4FBE8")
    s = ""
    # envelope with notes and coins popping out
    s += f'<rect x="46" y="120" width="164" height="104" rx="8" fill="{WHITE}" stroke="#5E9B3A" stroke-width="5"/>'
    s += f'<path d="M46 126 L128 186 L210 126" fill="none" stroke="#5E9B3A" stroke-width="5" stroke-linejoin="round"/>'
    for x, rot, col in [(78, -14, "#79C060"), (118, 4, "#9CD07E"), (158, 16, "#79C060")]:
        s += f'<g transform="rotate({rot} {x + 20} 110)"><rect x="{x}" y="64" width="44" height="64" rx="4" fill="{col}" stroke="#3F7228" stroke-width="3"/><circle cx="{x + 22}" cy="96" r="12" fill="none" stroke="#3F7228" stroke-width="3"/></g>'
    s += coin_shape(40, 70, 18) + coin_shape(214, 56, 22) + coin_shape(222, 150, 14) + coin_shape(30, 160, 13)
    s += '<path d="M60 44 l4 10 l10 4 l-10 4 l-4 10 l-4 -10 l-10 -4 l10 -4z" fill="#FFF6C8"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_bike_week():
    d, b = circumstance_frame("#2FA36B", "#BDEBD3", "#F0FBF5")
    s = sun(206, 52, 22, rays=10, ray_color="#F2B630") + cloud(66, 52, 0.7)
    s += '<rect x="0" y="168" width="256" height="88" fill="#6B7684"/><rect x="0" y="168" width="256" height="9" fill="#59616F"/>'
    s += '<rect x="0" y="196" width="256" height="30" fill="#2FA36B" opacity="0.85"/>'
    s += '<path d="M0 211 H256" stroke="#FFFFFF" stroke-width="3" stroke-dasharray="20 14"/>'
    # big bicycle
    s += f'<circle cx="82" cy="188" r="38" fill="none" stroke="{INK}" stroke-width="7"/><circle cx="176" cy="188" r="38" fill="none" stroke="{INK}" stroke-width="7"/>'
    s += f'<circle cx="82" cy="188" r="6" fill="#B8C2CC"/><circle cx="176" cy="188" r="6" fill="#B8C2CC"/>'
    s += '<path d="M82 188 L118 124 L160 124 L176 188 M118 124 L132 188 L82 188 M160 124 L152 100 M142 100 h22" fill="none" stroke="#E0533A" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>'
    s += f'<path d="M106 112 h26" stroke="{INK}" stroke-width="8" stroke-linecap="round"/>'
    # helmet
    s += f'<path d="M24 90 a26 24 0 0 1 52 0 z" fill="#F2B630" stroke="#B9810F" stroke-width="4"/><path d="M34 90 v-12 M50 90 v-18 M66 90 v-12" stroke="#B9810F" stroke-width="3"/><rect x="22" y="90" width="56" height="6" rx="3" fill="#B9810F"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_street_festival():
    d, b = circumstance_frame("#E87D3E", "#FFD7B0", "#FFF3E4")
    s = bunting(30, ["#E0533A", "#F2B630", "#2FA05A", "#3A8DDE", "#D6337A", "#A15CC9"], n=11, sag=14)
    s += house_row(150, haze=0.0)
    s += street(150, "#EBCB92", "#C9A25B")
    # lanterns
    for x, col in [(40, "#E0533A"), (96, "#F2B630"), (160, "#D6337A"), (216, "#2FA05A")]:
        s += f'<line x1="{x}" y1="56" x2="{x}" y2="72" stroke="{INK}" stroke-width="2"/><ellipse cx="{x}" cy="86" rx="14" ry="17" fill="{col}"/><ellipse cx="{x}" cy="86" rx="14" ry="17" fill="none" stroke="{WHITE}" stroke-opacity="0.5" stroke-width="2"/>'
    # long table with food
    s += f'<rect x="22" y="188" width="212" height="12" rx="3" fill="{WHITE}" stroke="{WHITE_SIDE}" stroke-width="3"/>'
    for x in (36, 206):
        s += f'<rect x="{x}" y="200" width="8" height="34" fill="{INK}"/>'
    s += f'<ellipse cx="70" cy="184" rx="22" ry="7" fill="#C58A52"/><circle cx="62" cy="178" r="7" fill="#E0533A"/><circle cx="76" cy="177" r="7" fill="#F4D23C"/>'
    s += f'<path d="M110 186 a22 14 0 0 1 44 0z" fill="{TERRACOTTA}"/><rect x="106" y="184" width="52" height="4" rx="2" fill="{TERRACOTTA_DARK}"/>'
    s += f'<rect x="178" y="166" width="14" height="22" rx="3" fill="#2F7A52"/><rect x="198" y="170" width="14" height="18" rx="3" fill="#3A8DDE"/>'
    s += person(64, 236, "#E0533A", s=0.85) + person(132, 238, "#2FA05A", s=0.85) + person(184, 238, "#A15CC9", s=0.85)
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_remote_work():
    d, b = circumstance_frame("#8C6CC4", "#D9CDF0", "#F6F2FC")
    d += GLASS_DEFS
    s = '<rect x="0" y="190" width="256" height="66" fill="#8B5E3C"/><rect x="0" y="190" width="256" height="9" fill="#A7774F"/>'
    # laptop
    s += f'<polygon points="44,190 212,190 196,178 60,178" fill="#98A4B1"/><rect x="62" y="84" width="132" height="94" rx="8" fill="{INK}"/>'
    s += f'<rect x="70" y="92" width="116" height="78" rx="4" fill="url(#glass)"/>'
    s += f'<path d="M98 150 v-24 l30 -22 l30 22 v24z" fill="{WHITE}"/><rect x="118" y="132" width="20" height="18" fill="#8C6CC4"/><polygon points="94,128 128,100 162,128" fill="{TERRACOTTA}"/>'
    # wifi arcs
    for r, w in [(18, 5), (32, 5), (46, 5)]:
        s += f'<path d="M{128 - r} {70 - r * 0.2:.1f} a{r} {r} 0 0 1 {2 * r} 0" fill="none" stroke="#8C6CC4" stroke-width="{w}" stroke-linecap="round" transform="translate(0 -4)"/>'
    s += '<circle cx="128" cy="66" r="5" fill="#8C6CC4"/>'
    # coffee cup and plant
    s += f'<path d="M206 176 h38 v18 a19 19 0 0 1 -38 0z" fill="{WHITE}" stroke="{WHITE_SIDE}" stroke-width="3"/><path d="M244 182 a9 9 0 0 1 0 16" fill="none" stroke="{WHITE_SIDE}" stroke-width="4"/>'
    s += '<path d="M218 168 q-5 -9 0 -16 M230 168 q-5 -9 0 -16" fill="none" stroke="#FFFFFF" stroke-width="3.5" stroke-linecap="round" opacity="0.85"/>'
    s += f'<path d="M14 190 h38 l-6 36 h-26z" fill="{TERRACOTTA}"/><circle cx="26" cy="172" r="12" fill="#5E9B3A"/><circle cx="42" cy="168" r="12" fill="#86BE52"/><circle cx="34" cy="154" r="12" fill="#5E9B3A"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_autumn_rain():
    d, b = circumstance_frame("#4F9BD0", "#B7D3E8", "#E6F1F8")
    s = cloud(70, 52, 1.1, "#9FB2C4", "#7F93A6") + cloud(178, 44, 1.0, "#AFC0D0", "#8DA0B3")
    s += '<rect x="0" y="176" width="256" height="80" fill="#7FB346"/><rect x="0" y="176" width="256" height="8" fill="#5E9B3A"/>'
    for k in range(18):
        x = 12 + (k * 47) % 236
        y = 84 + (k * 29) % 90
        s += f'<line x1="{x}" y1="{y}" x2="{x - 7}" y2="{y + 22}" stroke="#4F9BD0" stroke-width="3.5" stroke-linecap="round" opacity="0.85"/>'
    s += f'<rect x="50" y="128" width="10" height="56" fill="{TRUNK}"/>' + round_tree(55, 112, 30, "#E8A33B", "#C9782A", "#F4C46A")
    s += f'<rect x="196" y="132" width="10" height="52" fill="{TRUNK}"/>' + round_tree(201, 116, 28, "#5E9B3A", "#3F7A34", "#86BE52")
    s += '<ellipse cx="128" cy="214" rx="44" ry="10" fill="#6FB3E8" opacity="0.8"/><ellipse cx="116" cy="212" rx="14" ry="3" fill="#FFFFFF" opacity="0.6"/>'
    s += '<path d="M104 160 a24 22 0 0 1 48 0z" fill="#E0533A"/><path d="M128 160 v34" stroke="#1B2733" stroke-width="3" stroke-linecap="round"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_smog_alert():
    d, b = circumstance_frame("#7A7F88", "#B9BDC4", "#E3E5E8")
    s = house_row(172, haze=0.25, tint="#9A9DA4")
    s += street(172, "#8C8F96", "#74777E")
    for x in (30, 62):
        s += f'<rect x="{x}" y="84" width="18" height="80" fill="#5A5E66"/><rect x="{x - 3}" y="80" width="24" height="8" fill="#43474E"/>'
    for cx, cy, sc in [(46, 62, 1.0), (86, 42, 1.2), (140, 54, 1.3), (200, 40, 1.1), (96, 100, 0.9), (170, 96, 1.0)]:
        s += cloud(cx, cy, sc, "#6C7078", "#53575E")
    s += '<rect x="0" y="120" width="256" height="136" fill="#9A9DA4" opacity="0.35"/>'
    s += '<rect x="180" y="130" width="52" height="34" rx="6" fill="#FFFFFF" opacity="0.9"/><path d="M190 148 q8 -12 16 0 q8 12 16 0" fill="none" stroke="#E0533A" stroke-width="4" stroke-linecap="round"/>'
    s += '<path d="M104 212 h48 v10 a10 10 0 0 1 -10 10 h-28 a10 10 0 0 1 -10 -10z" fill="#E8EEF2" stroke="#74777E" stroke-width="3"/><path d="M114 212 v-10 M128 212 v-14 M142 212 v-10" stroke="#74777E" stroke-width="3" stroke-linecap="round"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_cold_snap():
    d, b = circumstance_frame("#6BB4E8", "#CFE6F6", "#F4FAFE")
    s = cloud(190, 50, 0.9, "#FFFFFF", "#DCE8F2")
    s += '<rect x="0" y="176" width="256" height="80" fill="#F4F8FB"/><rect x="0" y="176" width="256" height="8" fill="#D6E4EE"/>'
    s += f'<path d="M70 190 V112 M70 140 L44 114 M70 126 L98 100 M44 114 L36 98 M98 100 L106 86" fill="none" stroke="#6A4A2A" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>'
    s += '<path d="M44 110 q-6 6 -8 12 M98 96 q4 8 4 14" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/>'
    for cx, cy, r in [(150, 80, 16), (210, 120, 12), (118, 140, 10), (30, 70, 10), (230, 70, 9)]:
        for k in range(3):
            s += f'<line x1="{cx}" y1="{cy - r}" x2="{cx}" y2="{cy + r}" stroke="#6BB4E8" stroke-width="3.5" stroke-linecap="round" transform="rotate({k * 60} {cx} {cy})"/>'
    s += box(150, 140, 70, 40, 14, 10, WHITE, WHITE_SIDE, WHITE_TOP)
    s += f'<polygon points="146,142 224,142 212,122 158,122" fill="#F4F8FB" stroke="#D6E4EE" stroke-width="3"/>'
    for x in (160, 178, 196, 210):
        s += f'<path d="M{x} 144 v14 l-3 -4z" fill="#BFE0F5"/>'
    s += person(120, 232, "#3A8DDE", s=0.9)
    s += '<rect x="40" y="206" width="36" height="14" rx="6" fill="#E0533A"/><path d="M76 210 q18 6 22 -8" fill="none" stroke="#E0533A" stroke-width="6" stroke-linecap="round"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_farmers_market():
    d, b = circumstance_frame("#6FAE3A", "#CDE8B0", "#F3FAE8")
    s = sun(212, 50, 20, rays=10, ray_color="#F2B630") + cloud(60, 52, 0.7)
    s += '<rect x="0" y="176" width="256" height="80" fill="#E6D3A4"/><rect x="0" y="176" width="256" height="8" fill="#C9B27B"/>'
    s += '<rect x="34" y="86" width="8" height="96" fill="#7A5A3A"/><rect x="214" y="86" width="8" height="96" fill="#7A5A3A"/>'
    for k in range(8):
        s += f'<path d="M{34 + k * 23.5} 84 h23.5 v24 a11.75 11.75 0 0 1 -23.5 0z" fill="{"#E0533A" if k % 2 == 0 else "#FFFFFF"}" stroke="#B9382A" stroke-width="2"/>'
    s += '<rect x="34" y="150" width="188" height="14" rx="3" fill="#B8743F"/><rect x="40" y="164" width="176" height="20" fill="#9A5E30"/>'
    for x, c in [(54, "#E0533A"), (96, "#F2B630"), (138, "#5E9B3A"), (180, "#E8743B")]:
        s += f'<path d="M{x - 18} 150 l4 -14 h28 l4 14z" fill="#C58A52" stroke="#7A5232" stroke-width="3"/>'
        for dx in (-9, 0, 9):
            s += f'<circle cx="{x + dx}" cy="134" r="8" fill="{c}"/>'
    s += person(120, 236, "#3A8DDE", s=0.9) + person(168, 238, "#D6337A", s=0.9)
    s += '<path d="M60 214 a20 14 0 0 1 40 0" fill="none" stroke="#7A5232" stroke-width="4" stroke-linecap="round"/><rect x="56" y="212" width="48" height="22" rx="4" fill="#C58A52" stroke="#7A5232" stroke-width="3"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_science_fair():
    d, b = circumstance_frame("#2A9DB5", "#BFE6EE", "#F0FAFC")
    s = bunting(30, ["#E0533A", "#F2B630", "#2FA05A", "#3A8DDE", "#D6337A"], n=9, sag=12)
    s += '<rect x="0" y="190" width="256" height="66" fill="#8B5E3C"/><rect x="0" y="190" width="256" height="9" fill="#A7774F"/>'
    s += '<path d="M104 70 h48 v34 l34 70 a14 14 0 0 1 -12 20 h-92 a14 14 0 0 1 -12 -20 l34 -70z" fill="#E8F6FA" stroke="#1C6670" stroke-width="6" stroke-linejoin="round"/>'
    s += '<path d="M86 140 h84 l18 38 a8 8 0 0 1 -7 12 h-106 a8 8 0 0 1 -7 -12z" fill="#5BC58A" opacity="0.9"/>'
    s += '<rect x="98" y="62" width="60" height="12" rx="5" fill="#1C6670"/>'
    for cx, cy, r in [(118, 150, 6), (138, 138, 8), (150, 160, 5), (124, 122, 5)]:
        s += f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#FFFFFF" opacity="0.8"/>'
    s += '<ellipse cx="38" cy="132" rx="18" ry="7" fill="none" stroke="#2A9DB5" stroke-width="3"/><ellipse cx="38" cy="132" rx="18" ry="7" fill="none" stroke="#2A9DB5" stroke-width="3" transform="rotate(60 38 132)"/><ellipse cx="38" cy="132" rx="18" ry="7" fill="none" stroke="#2A9DB5" stroke-width="3" transform="rotate(120 38 132)"/><circle cx="38" cy="132" r="5" fill="#E0533A"/>'
    s += person(212, 232, "#2FA05A", s=0.9)
    s += f'<path d="M204 176 l8 -10 l8 10" fill="none" stroke="#F2B630" stroke-width="4" stroke-linecap="round"/>'
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_road_subsidy():
    d, b = circumstance_frame("#5E9B3A", "#CDE8B0", "#F3FAE8")
    s = sun(206, 52, 20, rays=10, ray_color="#F2B630") + cloud(64, 56, 0.7)
    s += '<rect x="0" y="150" width="256" height="106" fill="#6B7684"/><rect x="0" y="150" width="256" height="9" fill="#59616F"/>'
    s += '<path d="M0 206 H256" stroke="#F2C21C" stroke-width="5" stroke-dasharray="26 16"/>'
    for x in (38, 214):
        s += f'<path d="M{x - 14} 176 l10 -34 h8 l10 34z" fill="#F28C28" stroke="#B9610F" stroke-width="3"/><rect x="{x - 12}" y="156" width="24" height="7" fill="#FFFFFF"/><rect x="{x - 18}" y="176" width="36" height="8" rx="3" fill="#B9610F"/>'
    s += '<rect x="70" y="104" width="116" height="40" rx="10" fill="#F2B630" stroke="#B9810F" stroke-width="4"/><rect x="152" y="86" width="34" height="26" rx="6" fill="#F2B630" stroke="#B9810F" stroke-width="4"/>'
    s += '<rect x="158" y="92" width="22" height="14" rx="3" fill="#BFE6EE"/>'
    s += f'<circle cx="94" cy="150" r="22" fill="{INK}"/><circle cx="94" cy="150" r="9" fill="#B8C2CC"/><circle cx="168" cy="150" r="22" fill="{INK}"/><circle cx="168" cy="150" r="9" fill="#B8C2CC"/>'
    for cx, cy, r in [(92, 222, 18), (128, 232, 20), (166, 224, 18), (110, 196, 16), (148, 198, 16)]:
        s += coin_shape(cx, cy, r)
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_bus_strike():
    d, b = circumstance_frame("#B5483A", "#F0C9BF", "#FFF1EE")
    d += GLASS_DEFS
    s = house_row(130, haze=0.1, tint="#F0C9BF")
    s += street(130, "#6B7684", "#59616F")
    s += '<path d="M0 196 H256" stroke="#F2C21C" stroke-width="4" stroke-dasharray="24 16"/>'
    s += '<rect x="26" y="130" width="204" height="72" rx="14" fill="#6E7580" stroke="#43474E" stroke-width="5"/><rect x="26" y="180" width="204" height="10" fill="#8B939E"/>'
    for k in range(5):
        s += f'<rect x="{40 + k * 37}" y="142" width="28" height="28" rx="5" fill="url(#glass)" stroke="#43474E" stroke-width="3"/>'
    s += f'<circle cx="76" cy="204" r="16" fill="{INK}"/><circle cx="76" cy="204" r="6" fill="#B8C2CC"/><circle cx="180" cy="204" r="16" fill="{INK}"/><circle cx="180" cy="204" r="6" fill="#B8C2CC"/>'
    for x, y in [(52, 86), (206, 80)]:
        s += f'<rect x="{x - 3}" y="{y}" width="6" height="60" fill="#7A5A3A"/><rect x="{x - 24}" y="{y - 36}" width="48" height="40" rx="5" fill="#FFFFFF" stroke="#B5483A" stroke-width="4"/>'
        s += f'<path d="M{x} {y - 28} v16" stroke="#E0533A" stroke-width="6" stroke-linecap="round"/><circle cx="{x}" cy="{y - 4}" r="4" fill="#E0533A"/>'
    s += person(118, 246, "#F2B630", s=0.85) + person(146, 248, "#3A8DDE", s=0.85)
    return svg(b + circumstance_finish(s), defs=d)


def circumstance_pipe_repairs():
    d, b = circumstance_frame("#B9810F", "#EBD6A6", "#FBF3DD")
    s = '<rect x="0" y="150" width="256" height="106" fill="#8B5E3C"/><rect x="0" y="150" width="256" height="9" fill="#A7774F"/>'
    s += '<rect x="0" y="170" width="256" height="30" fill="#6B7684"/><rect x="0" y="170" width="256" height="6" fill="#8B939E"/><rect x="0" y="194" width="256" height="6" fill="#4F5663"/>'
    s += '<rect x="80" y="166" width="14" height="38" fill="#4F5663"/><rect x="160" y="166" width="14" height="38" fill="#4F5663"/>'
    s += '<path d="M104 170 q22 -26 44 0 q-8 36 -22 36 q-14 0 -22 -36z" fill="#3A8DDE" opacity="0.9"/>'
    for cx, cy in [(128, 120), (112, 138), (146, 136), (128, 148)]:
        s += f'<path d="M{cx} {cy - 12} q-10 14 0 20 q10 -6 0 -20z" fill="#6FB3E8" stroke="#3A8DDE" stroke-width="2"/>'
    s += '<g transform="rotate(-28 190 110)"><rect x="184" y="64" width="12" height="96" rx="5" fill="#98A4B1" stroke="#5F6C7B" stroke-width="3"/><path d="M178 64 a18 18 0 0 1 24 0 v18 h-24z" fill="#98A4B1" stroke="#5F6C7B" stroke-width="3"/></g>'
    s += coin_shape(40, 100, 18) + '<path d="M62 100 h28 M80 90 l12 10 l-12 10" fill="none" stroke="#D63A3A" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'
    s += f'<path d="M20 238 l10 -28 h30 l10 28z" fill="#F28C28"/><rect x="28" y="222" width="34" height="6" fill="{WHITE}"/>'
    return svg(b + circumstance_finish(s), defs=d)


def main():
    os.makedirs(CIRCUMSTANCES, exist_ok=True)
    cards = {
        "circumstance_heatwave": circumstance_heatwave(), "circumstance_flash_flood": circumstance_flash_flood(),
        "circumstance_dust_storm": circumstance_dust_storm(), "circumstance_nice_weather": circumstance_nice_weather(),
        "circumstance_budget_cut": circumstance_budget_cut(), "circumstance_grant": circumstance_grant(),
        "circumstance_road_works": circumstance_road_works(), "circumstance_new_attractor": circumstance_new_attractor(),
        "circumstance_population_growth": circumstance_population_growth(),
        "circumstance_exam_season": circumstance_exam_season(),
        "circumstance_flu_wave": circumstance_flu_wave(),
        "circumstance_supply_shortage": circumstance_supply_shortage(),
        "circumstance_back_to_school": circumstance_back_to_school(),
        "circumstance_parking_shortage": circumstance_parking_shortage(),
        "circumstance_traffic_jam": circumstance_traffic_jam(),
        "circumstance_drought": circumstance_drought(),
        "circumstance_tourist_season": circumstance_tourist_season(),
        "circumstance_health_campaign": circumstance_health_campaign(),
        "circumstance_open_day": circumstance_open_day(),
        "circumstance_business_boom": circumstance_business_boom(),
        "circumstance_tax_refund": circumstance_tax_refund(),
        "circumstance_bike_week": circumstance_bike_week(),
        "circumstance_street_festival": circumstance_street_festival(),
        "circumstance_remote_work": circumstance_remote_work(),
        "circumstance_autumn_rain": circumstance_autumn_rain(),
        "circumstance_smog_alert": circumstance_smog_alert(),
        "circumstance_cold_snap": circumstance_cold_snap(),
        "circumstance_farmers_market": circumstance_farmers_market(),
        "circumstance_science_fair": circumstance_science_fair(),
        "circumstance_road_subsidy": circumstance_road_subsidy(),
        "circumstance_bus_strike": circumstance_bus_strike(),
        "circumstance_pipe_repairs": circumstance_pipe_repairs(),
    }
    for name, content in cards.items():
        with open(os.path.join(CIRCUMSTANCES, name + ".svg"), "w", encoding="utf-8") as f:
            f.write(content)
    print(f"wrote {len(cards)} circumstance cards")


if __name__ == "__main__":
    main()
