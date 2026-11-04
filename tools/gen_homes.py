"""Every household of Redesign the City gets its own building, so a player can tell who lives there at a glance.

Used by gen_art.py (run `python tools/gen_art.py` from the project root). The three apartments that were
already drawn keep their picture under their household's name; the ten others are drawn here, with the same
helpers, palette and 256x256 canvas as the rest of the tiles. The top-left corner is left calm for the round
citizen icons and the bottom-right corner for the price.

Files written (assets/tiles/):
  home_small_worker, home_small_older, home_small_access, home_small_expat
  home_medium_working_couple, home_medium_older_couple, home_medium_parent_child, home_medium_carer, home_medium_expat_couple
  home_large_family, home_large_three_generations, home_large_shared_house, home_large_expat_family
"""
from gen_art import (  # noqa: F401
    BOUG, BOUG_LIGHT, GLASS_DEFS, GOLD, INK, LEAF, LEAF_DARK, LEAF_LIGHT, SHADOW, SHUTTER, SHUTTER_DARK,
    TERRACOTTA, TERRACOTTA_DARK, TRUNK, WHITE, WHITE_SIDE, WHITE_TOP,
    apartment_large, apartment_medium, apartment_small, bicycle, bougainvillea, box, door, frame, grass_tufts,
    ground_shadow, lin, person, pot_plant, solar_heater, svg, window,
)

TEAL = "#2FA3A0"
TEAL_DARK = "#1F7B79"
ORANGE = "#D8682B"
ORANGE_LIGHT = "#F29A4E"
SLATE = "#4A5568"
SKIN_DARK = "#C98E66"


# ---------------------------------------------------------------- little things used by several homes

def elder(x, y, shirt="#8C6CC4", s=1.0, skin="#E3B08A"):
    """An older resident with white hair and a walking stick, feet at (x, y)."""
    return (
        person(x, y, shirt, skin=skin, hair="#E8E8E8", s=s)
        + f'<g transform="translate({x} {y}) scale({s})"><path d="M13 -24 V0" stroke="{TRUNK}" stroke-width="3" stroke-linecap="round"/>'
        f'<path d="M13 -24 q0 -5 5 -5" fill="none" stroke="{TRUNK}" stroke-width="3" stroke-linecap="round"/></g>'
    )


def kid(x, y, shirt="#E2569C", s=0.62):
    return person(x, y, shirt, hair="#4B2E1E", s=s)


def wheelchair(x, y, shirt=TEAL, s=1.0):
    """A person in a wheelchair, wheels on the ground at (x, y)."""
    return (
        f'<g transform="translate({x} {y}) scale({s})">'
        f'<ellipse cx="2" cy="1" rx="22" ry="3.4" fill="{SHADOW}" opacity="0.3"/>'
        f'<path d="M-9 -36 V-22 H12 L22 -22 L22 -8" fill="none" stroke="{INK}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>'
        f'<rect x="-10" y="-52" width="15" height="29" rx="7" fill="{shirt}"/>'
        f'<circle cx="-3" cy="-60" r="7.5" fill="#E8B48A"/>'
        f'<path d="M-10.5 -61 a7.5 7.5 0 0 1 15 0 q-7.5 -4 -15 0z" fill="#3B2A20"/>'
        f'<circle cx="-2" cy="-14" r="14" fill="none" stroke="{INK}" stroke-width="3.2"/>'
        f'<circle cx="-2" cy="-14" r="2.2" fill="{INK}"/>'
        f'<circle cx="22" cy="-5" r="4.5" fill="{INK}"/>'
        f'<path d="M-9 -38 H-16" stroke="{INK}" stroke-width="3.5" stroke-linecap="round"/>'
        f'</g>'
    )


def accessible_sign(x, y):
    """A blue accessible-parking sign on a post; the board is centred on (x, y)."""
    return (
        f'<rect x="{x - 2}" y="{y + 14}" width="4" height="46" fill="{INK}"/>'
        f'<rect x="{x - 16}" y="{y - 16}" width="32" height="32" rx="6" fill="#2A6FD0" stroke="{WHITE}" stroke-width="2.5"/>'
        f'<g fill="none" stroke="{WHITE}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round">'
        f'<circle cx="{x - 1}" cy="{y - 8}" r="2.6" fill="{WHITE}"/>'
        f'<path d="M{x - 2} {y - 3} v8 h8 l3 6"/><path d="M{x - 7} {y - 1} a7 7 0 1 0 10 8"/></g>'
    )


def car(x, y, col, s=1.0):
    """A small car seen from the side, wheels on the ground at (x, y)."""
    return (
        f'<g transform="translate({x} {y}) scale({s})">'
        f'<ellipse cx="2" cy="2" rx="36" ry="4.5" fill="{SHADOW}" opacity="0.3"/>'
        f'<path d="M-34 -8 v-12 q0 -4 5 -4 h10 l8 -11 q2 -3 6 -3 h14 q4 0 6 3 l9 11 h8 q6 0 6 5 v10z" fill="{col}"/>'
        f'<path d="M-14 -24 l6 -9 h13 q2 0 3 1 l8 8z" fill="url(#glass)"/>'
        f'<line x1="2" y1="-34" x2="2" y2="-24" stroke="{col}" stroke-width="2"/>'
        f'<circle cx="-20" cy="-6" r="8" fill="{INK}"/><circle cx="20" cy="-6" r="8" fill="{INK}"/>'
        f'<circle cx="-20" cy="-6" r="3.2" fill="#C9D1D8"/><circle cx="20" cy="-6" r="3.2" fill="#C9D1D8"/>'
        f'<rect x="34" y="-19" width="5" height="5" rx="1.5" fill="{GOLD}"/>'
        f'</g>'
    )


def pennant(x, y, top=ORANGE, bottom="#FFFFFF", mid="#2A6FD0", height=58):
    """A pole with a plain three-band pennant (no real country's flag), base at (x, y)."""
    return (
        f'<rect x="{x - 1.5}" y="{y - height}" width="3" height="{height}" fill="{INK}"/>'
        f'<circle cx="{x}" cy="{y - height - 2}" r="3" fill="{GOLD}"/>'
        f'<path d="M{x + 1.5} {y - height + 2} h26 q-4 5 0 10 h-26z" fill="{top}"/>'
        f'<path d="M{x + 1.5} {y - height + 12} h26 q-4 5 0 10 h-26z" fill="{mid}"/>'
        f'<path d="M{x + 1.5} {y - height + 22} h26 q-4 5 0 10 h-26z" fill="{bottom}"/>'
    )


def bench(x, y, w=44):
    """A park bench, left end of the seat at (x, y)."""
    return (
        f'<rect x="{x}" y="{y - 22}" width="{w}" height="6" rx="2" fill="{TRUNK}"/>'
        f'<rect x="{x}" y="{y - 14}" width="{w}" height="6" rx="2" fill="#9A7050"/>'
        f'<rect x="{x + 3}" y="{y - 8}" width="4" height="10" fill="{INK}"/><rect x="{x + w - 7}" y="{y - 8}" width="4" height="10" fill="{INK}"/>'
    )


def palm(x, y, s=1.0):
    """A palm tree with its trunk base at (x, y)."""
    out = f'<g transform="translate({x} {y}) scale({s})">'
    out += f'<ellipse cx="2" cy="1" rx="14" ry="4" fill="{SHADOW}" opacity="0.25"/>'
    out += f'<path d="M-3 0 Q4 -30 0 -62 L6 -62 Q10 -30 4 0z" fill="{TRUNK}"/>'
    for ang in (-70, -35, 0, 35, 70):
        out += f'<ellipse cx="3" cy="-64" rx="24" ry="5.5" fill="{LEAF if ang % 2 == 0 else LEAF_DARK}" transform="rotate({ang} 3 -64) translate(18 0)"/>'
    out += f'<circle cx="0" cy="-60" r="3.4" fill="{TRUNK}"/><circle cx="7" cy="-59" r="3.4" fill="{TERRACOTTA_DARK}"/>'
    return out + '</g>'


def pool(x, y, w, h):
    return (
        f'<rect x="{x - 4}" y="{y - 3}" width="{w + 8}" height="{h + 8}" rx="9" fill="{WHITE_SIDE}"/>'
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="7" fill="#4FB6E0"/>'
        f'<path d="M{x + 8} {y + 7} q8 -5 16 0 t16 0 t16 0" fill="none" stroke="#B8E6F6" stroke-width="2.2" stroke-linecap="round"/>'
        f'<path d="M{x + 14} {y + 15} q8 -5 16 0 t16 0" fill="none" stroke="#B8E6F6" stroke-width="2" stroke-linecap="round" opacity="0.8"/>'
    )


def parasol(x, y, col=ORANGE, s=1.0):
    """A terrace parasol with its pole base at (x, y)."""
    return (
        f'<g transform="translate({x} {y}) scale({s})">'
        f'<rect x="-1.5" y="-34" width="3" height="34" fill="{INK}"/>'
        f'<path d="M-24 -32 Q0 -56 24 -32 Z" fill="{col}"/>'
        f'<path d="M-24 -32 Q-12 -38 0 -32 Q12 -38 24 -32" fill="none" stroke="{WHITE}" stroke-width="2"/>'
        f'</g>'
    )


def balloon(x, y, col="#E2569C"):
    return (
        f'<path d="M{x} {y} q-3 14 3 24" fill="none" stroke="{INK}" stroke-width="1.4"/>'
        f'<ellipse cx="{x}" cy="{y - 9}" rx="8" ry="10" fill="{col}"/>'
        f'<ellipse cx="{x - 3}" cy="{y - 12}" rx="2" ry="3" fill="#FFFFFF" opacity="0.55"/>'
    )


def tiled_roof(x0, y0, x1, y1, ridge_x0, ridge_x1, ridge_y, depth, id_):
    """A pitched terracotta roof: front slope, end slope and the ridge. Uses gradient `id_`."""
    return (
        f'<polygon points="{x0},{y0} {x1},{y1} {ridge_x1},{ridge_y} {ridge_x0},{ridge_y}" fill="url(#{id_})"/>'
        f'<polygon points="{x1},{y1} {x1 + depth},{y1 - depth * 0.62} {ridge_x1 + depth * 0.8},{ridge_y - depth * 0.45} {ridge_x1},{ridge_y}" fill="{TERRACOTTA_DARK}"/>'
        f'<polygon points="{ridge_x0},{ridge_y} {ridge_x1},{ridge_y} {ridge_x1 + depth * 0.8},{ridge_y - depth * 0.45} {ridge_x0 + depth * 0.8},{ridge_y - depth * 0.45}" fill="#B04E2D"/>'
    )


def roof_lines(x_left, x_right, y_top, y_bottom, n):
    out = ""
    for i in range(1, n):
        y = y_top + (y_bottom - y_top) * i / n
        inset = (y_bottom - y) / (y_bottom - y_top) * 6
        out += f'<line x1="{x_left + inset:.1f}" y1="{y:.1f}" x2="{x_right - inset:.1f}" y2="{y:.1f}" stroke="{TERRACOTTA_DARK}" stroke-width="2" opacity="0.55"/>'
    return out


# ---------------------------------------------------------------- small homes (one citizen)

def home_small_older():
    """A low cottage with a chimney, a vine over the porch and a bench to sit on."""
    d, b = frame("building")
    d += GLASS_DEFS + lin("roofo", "#D4724A", "#9A4226")
    b += ground_shadow([(48, 208), (186, 208), (220, 190), (206, 128)])
    b += box(50, 128, 128, 80, 26, 15, "#F6DFA8", "#D8BE80", "#EBD28F")
    b += tiled_roof(42, 132, 186, 132, 66, 164, 92, 26, "roofo") + roof_lines(46, 182, 92, 132, 4)
    b += f'<rect x="146" y="68" width="18" height="30" fill="#B7684A"/><rect x="143" y="64" width="24" height="7" rx="2" fill="#8F3F25"/>'
    b += f'<path d="M150 56 q-5 -8 0 -14 M158 52 q-5 -8 0 -14" fill="none" stroke="{WHITE_SIDE}" stroke-width="3" stroke-linecap="round" opacity="0.8"/>'
    b += window(64, 150, 20, 26)
    b += door(104, 160, 26, 48, "#4C8C6B")
    b += window(152, 152, 18, 24, shutters=False)
    b += f'<rect x="96" y="150" width="42" height="7" rx="2" fill="{TERRACOTTA_DARK}"/>'
    b += f'<rect x="97" y="156" width="4" height="52" fill="{WHITE_SIDE}"/><rect x="135" y="156" width="4" height="52" fill="{WHITE_SIDE}"/>'
    b += bougainvillea(118, 150, 8, 22)
    b += pot_plant(52, 212) + pot_plant(166, 210)
    b += bench(70, 232, 46)
    b += elder(86, 232, "#8C6CC4", 0.95)
    b += grass_tufts([(36, 62), (214, 74), (40, 112)])
    return svg(b, defs=d)


def home_small_access():
    """A step-free flat with a ramp, a wide glass door and a reserved parking sign."""
    d, b = frame("building")
    d += GLASS_DEFS
    b += ground_shadow([(60, 210), (184, 210), (214, 194), (200, 124)])
    b += box(66, 122, 112, 88, 22, 14, "#EAF6F2", "#BFDCD5", "#DDEEE9")
    b += f'<rect x="58" y="114" width="128" height="9" rx="2" fill="{TEAL_DARK}"/>'
    b += f'<polygon points="186,114 208,100 208,108 186,123" fill="#165A59"/>'
    b += f'<polygon points="58,114 186,114 208,100 80,100" fill="{TEAL}"/>'
    # wide glass door, no step
    b += f'<rect x="92" y="148" width="42" height="62" rx="3" fill="{TEAL_DARK}"/>'
    b += f'<rect x="96" y="152" width="16" height="58" fill="url(#glass)"/><rect x="114" y="152" width="16" height="58" fill="url(#glass)"/>'
    b += f'<rect x="146" y="158" width="26" height="22" rx="2" fill="url(#glass)"/><rect x="144" y="180" width="30" height="4" fill="{WHITE_SIDE}"/>'
    b += f'<rect x="72" y="158" width="14" height="22" rx="2" fill="url(#glass)"/>'
    # ramp with handrails
    b += f'<polygon points="22,226 98,226 98,208 82,208" fill="#C9CFCB"/>'
    b += '<g stroke="#A5ADA8" stroke-width="1.6">' + "".join(f'<line x1="{x}" y1="226" x2="{x + 10}" y2="208"/>' for x in (36, 52, 68, 84)) + '</g>'
    b += f'<path d="M24 208 L84 190 L98 190" fill="none" stroke="{TEAL_DARK}" stroke-width="3.2" stroke-linecap="round"/>'
    b += f'<path d="M24 208 v18 M60 199 v22 M98 190 v18" stroke="{TEAL_DARK}" stroke-width="2.6"/>'
    b += accessible_sign(206, 150)
    b += pot_plant(158, 214)
    b += wheelchair(54, 238, TEAL, 0.78)
    b += grass_tufts([(214, 62), (36, 66), (34, 112)])
    return svg(b, defs=d)


def home_small_expat():
    """A modern white cube with a glass wall, a pennant on the roof, a car and a suitcase."""
    d, b = frame("building")
    d += GLASS_DEFS
    b += ground_shadow([(58, 208), (182, 208), (214, 192), (200, 112)])
    b += box(62, 112, 116, 96, 24, 15, "#FBF4EA", "#DCCFBD", "#EFE5D3")
    b += f'<rect x="54" y="104" width="132" height="9" rx="2" fill="#3A3F4A"/>'
    b += f'<polygon points="186,104 210,90 210,98 186,113" fill="#23272F"/>'
    b += f'<polygon points="54,104 186,104 210,90 78,90" fill="#4A5160"/>'
    b += f'<rect x="72" y="124" width="62" height="40" rx="2" fill="url(#glass)"/>'
    b += '<g stroke="#FFFFFF" stroke-width="2.4" opacity="0.8">' + '<line x1="93" y1="124" x2="93" y2="164"/><line x1="113" y1="124" x2="113" y2="164"/></g>'
    b += f'<rect x="144" y="124" width="24" height="84" fill="{ORANGE}"/><rect x="148" y="132" width="16" height="30" rx="2" fill="url(#glass)"/>'
    b += f'<circle cx="162" cy="176" r="2.4" fill="{GOLD}"/>'
    b += f'<rect x="72" y="172" width="62" height="36" rx="2" fill="url(#glass)"/>'
    b += pennant(190, 104, height=48)
    b += car(66, 238, ORANGE, 0.82)
    b += f'<rect x="136" y="210" width="20" height="16" rx="3" fill="#3A3F4A"/><rect x="141" y="206" width="10" height="5" rx="2" fill="none" stroke="#3A3F4A" stroke-width="2.4"/>'
    b += grass_tufts([(214, 62), (40, 64), (36, 112)])
    return svg(b, defs=d)


# ---------------------------------------------------------------- medium homes (two citizens)

def home_medium_older_couple():
    """A pink two-storey townhouse with flower boxes, an arched door and two neighbours to talk to."""
    d, b = frame("building")
    d += GLASS_DEFS + lin("roofc", "#D4724A", "#9A4226")
    b += ground_shadow([(52, 210), (178, 210), (212, 192), (196, 80)])
    b += box(54, 90, 122, 120, 24, 15, "#F5D9D0", "#D9B5AA", "#EBCBC1")
    b += tiled_roof(46, 94, 182, 94, 66, 166, 62, 24, "roofc") + roof_lines(50, 178, 62, 94, 3)
    for x in (66, 134):
        b += window(x, 104, 20, 28)
        b += f'<rect x="{x - 3}" y="132" width="26" height="9" rx="2" fill="{TERRACOTTA}"/>'
        b += "".join(f'<circle cx="{x + k * 6 - 2}" cy="130" r="4.5" fill="{BOUG if k % 2 == 0 else BOUG_LIGHT}"/>' for k in range(4))
    b += f'<rect x="58" y="146" width="114" height="5" fill="{WHITE_SIDE}"/>'
    b += door(100, 164, 28, 46, "#8A5A3A")
    b += window(64, 168, 22, 26, shutters=False) + window(144, 168, 20, 26, shutters=False)
    b += bougainvillea(60, 150, 7, 12)
    b += pot_plant(54, 214) + pot_plant(170, 212)
    b += bench(60, 234, 50)
    b += elder(72, 234, "#8C6CC4", 0.92) + elder(98, 234, "#C45A7A", 0.92, "#D9A27A")
    return svg(b, defs=d)


def home_medium_parent_child():
    """A sunny yellow building with bunting, a bike with a child seat, a parent, a child and a balloon."""
    d, b = frame("building")
    d += GLASS_DEFS + lin("roofp", "#38B4B0", TEAL_DARK)
    b += ground_shadow([(56, 208), (178, 208), (212, 192), (196, 86)])
    b += box(56, 96, 120, 112, 24, 15, "#FFF0B8", "#E3D08E", "#F5E4A2")
    b += f'<polygon points="48,100 184,100 164,66 68,66" fill="url(#roofp)"/>'
    b += f'<polygon points="184,100 208,86 188,52 164,66" fill="{TEAL_DARK}"/>'
    b += f'<polygon points="68,66 164,66 188,52 92,52" fill="#2A8B88"/>'
    # round-topped windows with children's drawings
    for x, col in ((68, "#E2569C"), (112, "#F2B630"), (146, "#3A8DDE")):
        b += f'<path d="M{x} 138 v-24 a11 11 0 0 1 22 0 v24 z" fill="url(#glass)"/>'
        b += f'<rect x="{x + 5}" y="122" width="12" height="12" rx="1.5" fill="{col}" opacity="0.85" transform="rotate(-6 {x + 11} 128)"/>'
        b += f'<rect x="{x - 3}" y="138" width="28" height="5" fill="{WHITE_SIDE}"/>'
    # bunting across the facade
    b += f'<path d="M58 104 Q116 120 174 104" fill="none" stroke="{INK}" stroke-width="1.6"/>'
    for i, (x, col) in enumerate(((72, BOUG), (90, GOLD), (108, SHUTTER), (126, "#5E9B3A"), (144, BOUG), (160, GOLD))):
        y = 104 + 13 * (1 - ((x - 116) / 58) ** 2)
        b += f'<polygon points="{x - 6},{y:.1f} {x + 6},{y:.1f} {x},{y + 12:.1f}" fill="{col}"/>'
    b += door(100, 164, 26, 44, ORANGE)
    b += window(64, 166, 20, 26, shutters=False) + window(146, 166, 20, 26, shutters=False)
    b += bicycle(62, 236, 0.78, TEAL)
    b += f'<rect x="72" y="212" width="10" height="9" rx="3" fill="{BOUG}"/>'
    b += person(112, 236, "#E5A12B") + kid(132, 236, "#E2569C") + balloon(142, 196)
    b += f'<circle cx="94" cy="230" r="5" fill="{BOUG}"/><path d="M89 230 h10" stroke="{WHITE}" stroke-width="1.5"/>'
    return svg(b, defs=d)


def home_medium_carer():
    """A cool blue building with a glass lift shaft, a ramp, a person in a wheelchair and their carer."""
    d, b = frame("building")
    d += GLASS_DEFS
    b += ground_shadow([(46, 210), (178, 210), (214, 194), (200, 84)])
    b += box(84, 94, 94, 116, 22, 14, "#E6EFF8", "#BFCFE0", "#D8E4F1")
    b += f'<rect x="76" y="86" width="110" height="9" rx="2" fill="{SLATE}"/>'
    # the glass lift tower on the left
    b += f'<rect x="42" y="74" width="40" height="136" rx="3" fill="#CFE6EE" stroke="{TEAL_DARK}" stroke-width="4"/>'
    b += f'<rect x="46" y="78" width="32" height="128" fill="url(#glass)" opacity="0.85"/>'
    b += f'<g stroke="{TEAL_DARK}" stroke-width="2.5"><line x1="46" y1="120" x2="78" y2="120"/><line x1="46" y1="162" x2="78" y2="162"/></g>'
    b += f'<rect x="52" y="124" width="20" height="30" rx="2" fill="{WHITE}" stroke="{TEAL_DARK}" stroke-width="2"/><path d="M62 130 l-5 6 h10z M62 148 l-5 -6 h10z" fill="{TEAL_DARK}"/>'
    b += f'<rect x="40" y="68" width="44" height="9" rx="2" fill="{TEAL_DARK}"/>'
    # windows and a wide door
    for x in (98, 136):
        b += f'<rect x="{x}" y="104" width="24" height="26" rx="2" fill="url(#glass)"/><rect x="{x - 2}" y="130" width="28" height="4" fill="{WHITE_SIDE}"/>'
    b += f'<rect x="96" y="158" width="38" height="52" rx="3" fill="{TEAL_DARK}"/><rect x="100" y="162" width="14" height="48" fill="url(#glass)"/><rect x="116" y="162" width="14" height="48" fill="url(#glass)"/>'
    b += f'<rect x="144" y="164" width="24" height="22" rx="2" fill="url(#glass)"/>'
    # a small heart sign
    b += f'<circle cx="150" cy="116" r="0" fill="none"/>'
    b += f'<path d="M154 112 c-5 -6 -13 1 -6 8 l6 6 l6 -6 c7 -7 -1 -14 -6 -8z" fill="#E0533A"/>'
    # ramp
    b += f'<polygon points="92,226 142,226 142,210 130,210" fill="#C9CFCB"/>'
    b += f'<path d="M94 210 L130 192 L142 192" fill="none" stroke="{TEAL_DARK}" stroke-width="3" stroke-linecap="round"/><path d="M94 210 v16 M142 192 v18" stroke="{TEAL_DARK}" stroke-width="2.4"/>'
    b += wheelchair(60, 238, TEAL, 0.78) + person(96, 238, "#E5A12B", s=0.82)
    b += f'<rect x="102" y="214" width="9" height="11" rx="2" fill="{TERRACOTTA_DARK}"/>'
    return svg(b, defs=d)


def home_medium_expat_couple():
    """Two stacked modern blocks with a roof terrace, a parasol, a pennant and a car."""
    d, b = frame("building")
    d += GLASS_DEFS
    b += ground_shadow([(52, 210), (180, 210), (214, 194), (200, 100)])
    b += box(52, 132, 126, 78, 24, 15, "#FBF4EA", "#DCCFBD", "#EFE5D3")
    b += box(72, 84, 106, 52, 22, 14, "#5A6578", "#3F4858", "#6D7A8F")
    b += f'<rect x="66" y="78" width="118" height="8" rx="2" fill="#2F3744"/>'
    # terrace on top: parasol, chairs, plants
    b += f'<rect x="76" y="64" width="100" height="6" rx="2" fill="{WHITE_SIDE}"/>'
    b += '<g stroke="#9CC9E8" stroke-width="2" opacity="0.9">' + "".join(f'<line x1="{x}" y1="64" x2="{x}" y2="78"/>' for x in range(80, 176, 10)) + '</g>'
    b += parasol(116, 80, ORANGE, 0.9)
    b += f'<rect x="136" y="70" width="12" height="9" rx="2" fill="{ORANGE_LIGHT}"/><rect x="152" y="70" width="12" height="9" rx="2" fill="{ORANGE_LIGHT}"/>'
    # big windows of the upper block, orange band, balcony below
    b += f'<rect x="80" y="94" width="42" height="34" rx="2" fill="url(#glass)"/><rect x="128" y="94" width="42" height="34" rx="2" fill="url(#glass)"/>'
    b += f'<rect x="72" y="134" width="106" height="6" fill="{ORANGE}"/>'
    b += f'<rect x="60" y="146" width="40" height="26" rx="2" fill="url(#glass)"/><rect x="132" y="146" width="36" height="26" rx="2" fill="url(#glass)"/>'
    b += f'<rect x="102" y="164" width="26" height="46" rx="2" fill="{ORANGE}"/><rect x="106" y="170" width="18" height="30" rx="2" fill="url(#glass)"/>'
    b += pennant(194, 134, height=40)
    b += car(70, 238, "#2A6FD0", 0.82)
    b += f'<circle cx="150" cy="226" r="9" fill="{LEAF}"/><circle cx="158" cy="222" r="8" fill="{LEAF_LIGHT}"/><rect x="146" y="228" width="16" height="9" rx="2" fill="{TERRACOTTA}"/>'
    return svg(b, defs=d)


# ---------------------------------------------------------------- large homes (three citizens)

def home_large_three_generations():
    """A big old family house round a courtyard arch, with laundry on a line and three generations out front."""
    d, b = frame("building")
    d += GLASS_DEFS + lin("roofg", "#D4724A", "#9A4226")
    b += ground_shadow([(34, 210), (182, 210), (220, 190), (204, 74)])
    b += box(38, 84, 148, 126, 28, 17, "#F9E7B8", "#DCC890", "#EEDAA2")
    b += tiled_roof(30, 90, 192, 90, 54, 176, 56, 28, "roofg") + roof_lines(34, 188, 56, 90, 3)
    # courtyard arch in the middle
    b += f'<path d="M92 210 V158 a24 24 0 0 1 48 0 V210 Z" fill="#6B4A32"/>'
    b += f'<path d="M98 210 V160 a18 18 0 0 1 36 0 V210 Z" fill="#8DBB60"/><rect x="104" y="170" width="24" height="40" fill="#5E9B3A" opacity="0.7"/>'
    b += f'<path d="M92 158 a24 24 0 0 1 48 0" fill="none" stroke="{WHITE_SIDE}" stroke-width="5"/>'
    for x in (50, 156):
        b += window(x, 108, 20, 28)
        b += window(x, 160, 18, 24, shutters=False)
    # laundry line between the upper windows
    b += f'<path d="M72 118 Q114 140 156 118" fill="none" stroke="{INK}" stroke-width="1.4"/>'
    for x, col, w in ((86, "#E2569C", 12), (106, "#FFFFFF", 14), (126, "#3A8DDE", 12)):
        y = 118 + 22 * (1 - ((x - 114) / 42) ** 2) * 0.62
        b += f'<rect x="{x}" y="{y:.1f}" width="{w}" height="16" rx="2" fill="{col}" stroke="{WHITE_SIDE}" stroke-width="1"/>'
    b += bougainvillea(50, 150, 8, 14) + bougainvillea(176, 150, 7, 12)
    b += elder(48, 236, "#8C6CC4", 0.9) + person(76, 236, "#E5A12B", s=0.92) + kid(98, 236, "#E2569C")
    b += pot_plant(148, 214)
    return svg(b, defs=d)


def home_large_shared_house():
    """A tall patchwork house with a different colour on every floor, bikes, mailboxes and a roof garden."""
    d, b = frame("building")
    d += GLASS_DEFS
    b += ground_shadow([(66, 210), (162, 210), (200, 194), (190, 56)])
    b += box(66, 56, 100, 154, 24, 15, "#F6EAF8", "#D6C3DA", "#E9DBEE")
    floors = ((64, "#FFD9E6"), (100, "#D9F0FF"), (136, "#E5F7D4"))
    for y, col in floors:
        b += f'<rect x="66" y="{y}" width="100" height="34" fill="{col}" opacity="0.9"/>'
    shutters = (BOUG, SHUTTER, "#5E9B3A", GOLD, TERRACOTTA, TEAL)
    k = 0
    for y in (68, 104, 140):
        for x in (74, 104, 134):
            c = shutters[k % len(shutters)]
            k += 1
            b += f'<rect x="{x - 3}" y="{y}" width="6" height="22" rx="1.5" fill="{c}"/><rect x="{x + 22}" y="{y}" width="6" height="22" rx="1.5" fill="{c}"/>'
            b += f'<rect x="{x + 4}" y="{y}" width="18" height="22" rx="2" fill="url(#glass)"/>'
    # roof garden with string lights
    b += f'<rect x="62" y="48" width="108" height="8" rx="2" fill="#7A5A8C"/>'
    b += "".join(f'<circle cx="{x}" cy="{y}" r="6.5" fill="{c}"/>' for x, y, c in ((76, 42, LEAF), (88, 38, LEAF_LIGHT), (150, 40, LEAF), (160, 44, LEAF_LIGHT)))
    b += f'<path d="M64 52 Q116 70 168 52" fill="none" stroke="{INK}" stroke-width="1.3"/>'
    b += "".join(f'<circle cx="{x}" cy="{y:.1f}" r="2.8" fill="{GOLD}"/>' for x, y in ((80, 56.2), (96, 60.0), (116, 61.0), (136, 60.0), (152, 56.2)))
    # ground floor: wide door, mural, mailboxes
    b += f'<rect x="66" y="176" width="100" height="34" fill="#C9B6D4"/>'
    b += f'<path d="M72 206 q8 -22 16 -8 t16 -10 t14 12" fill="none" stroke="{BOUG}" stroke-width="5" stroke-linecap="round"/><circle cx="82" cy="190" r="5" fill="{GOLD}"/>'
    b += door(122, 168, 28, 42, TEAL)
    b += f'<rect x="156" y="184" width="14" height="18" rx="2" fill="{INK}"/>'
    b += "".join(f'<rect x="{158 + (i % 2) * 5}" y="{186 + (i // 2) * 8}" width="4.5" height="6" fill="{c}"/>' for i, c in enumerate((GOLD, BOUG, "#5E9B3A", SHUTTER)))
    b += bicycle(54, 238, 0.8, SHUTTER) + bicycle(98, 240, 0.8, BOUG)
    b += f'<polygon points="22,220 38,220 30,212" fill="#4F8BEA"/><rect x="26" y="220" width="8" height="10" fill="#2F63B8"/>'
    return svg(b, defs=d)


def home_large_expat_family():
    """A modern villa with a garage, a pool, a palm tree and a pennant: a family that moved for work."""
    d, b = frame("building")
    d += GLASS_DEFS
    b += ground_shadow([(34, 200), (186, 200), (222, 184), (206, 80)])
    b += box(36, 90, 150, 110, 26, 16, "#FFFFFF", "#DCCFBD", "#F0E8DA")
    b += f'<rect x="28" y="82" width="166" height="10" rx="2" fill="#3A3F4A"/>'
    b += f'<polygon points="194,82 220,66 220,76 194,92" fill="#23272F"/>'
    b += f'<polygon points="28,82 194,82 220,66 54,66" fill="#4A5160"/>'
    # upper glass band and orange accent
    b += f'<rect x="50" y="102" width="110" height="38" rx="2" fill="url(#glass)"/>'
    b += '<g stroke="#FFFFFF" stroke-width="2.4" opacity="0.8">' + "".join(f'<line x1="{x}" y1="102" x2="{x}" y2="140"/>' for x in (77, 105, 132)) + '</g>'
    b += f'<rect x="164" y="102" width="16" height="98" fill="{ORANGE}"/>'
    # garage and front door
    b += f'<rect x="46" y="152" width="58" height="48" rx="2" fill="#B8C0C8"/>'
    b += "".join(f'<line x1="46" y1="{y}" x2="104" y2="{y}" stroke="#8D969E" stroke-width="2"/>' for y in (162, 172, 182, 192))
    b += f'<rect x="114" y="152" width="30" height="48" rx="2" fill="{ORANGE}"/><rect x="119" y="158" width="20" height="34" rx="2" fill="url(#glass)"/>'
    b += pennant(204, 200, height=44)
    b += pool(104, 210, 52, 24)
    b += palm(40, 218, 0.78)
    b += person(86, 244, "#E5A12B", s=0.7) + kid(176, 240, "#E2569C", 0.55)
    return svg(b, defs=d)


# ---------------------------------------------------------------- the three apartments that were already drawn

HOMES = {
    "home_small_worker": apartment_small,
    "home_small_older": home_small_older,
    "home_small_access": home_small_access,
    "home_small_expat": home_small_expat,
    "home_medium_working_couple": apartment_medium,
    "home_medium_older_couple": home_medium_older_couple,
    "home_medium_parent_child": home_medium_parent_child,
    "home_medium_carer": home_medium_carer,
    "home_medium_expat_couple": home_medium_expat_couple,
    "home_large_family": apartment_large,
    "home_large_three_generations": home_large_three_generations,
    "home_large_shared_house": home_large_shared_house,
    "home_large_expat_family": home_large_expat_family,
}
