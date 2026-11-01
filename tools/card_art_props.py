"""Hand-drawn props for the card pictures. Each prop is drawn around (0, 0), about 120 units across, with
the light coming from the top left; gen_cards.py places, scales and turns them. `a` is the card's Pal."""
from card_art_lib import *

STONE = "#EDE5D2"
PROPS = {}


def prop(fn):
    PROPS[fn.__name__] = fn
    return fn


# ---------------------------------------------------------------- money

@prop
def coin_stack(a):
    out = ""
    for y in (24, 10, -4, -18):
        out += f'<path d="M-34 {y} v10 a34 11 0 0 0 68 0 v-10z" fill="#C99014" stroke="#8A6008" stroke-width="3" stroke-linejoin="round"/>'
        out += ellipse(0, y, 34, 11, "#F5C23E", 3, "#8A6008")
        out += f'<ellipse cx="0" cy="{y}" rx="23" ry="7" fill="none" stroke="#D49A1C" stroke-width="2"/>'
    out += poly([(0, -26), (8, -18), (0, -10), (-8, -18)], "#E1A21E", 2, "#8A6008")
    return out


@prop
def money_bag(a):
    out = path("M-36 44 C-54 10 -28 -12 -14 -26 L14 -26 C28 -12 54 10 36 44 C20 52 -20 52 -36 44Z", "#CBA062")
    out += shine("M-30 32 C-40 8 -20 -8 -10 -20 L-4 -20 C-14 -4 -26 12 -26 36Z", 0.3)
    out += path("M-17 -26 L-24 -46 C-8 -38 8 -38 24 -46 L17 -26 Z", "#B98B4C")
    out += stroke_path("M-18 -25 C-6 -19 6 -19 18 -25", 5, "#7A5232")
    out += circle(0, 14, 17, GOLD, 3, GOLD_D) + poly([(0, 4), (7, 14), (0, 24), (-7, 14)], "#E1A21E", 2, GOLD_D)
    return out


@prop
def wallet(a):
    out = rect(-48, -28, 96, 62, 10, "#8B5A34")
    out += rect(-48, -28, 96, 20, 10, "#A06B3F")
    out += rect(22, -2, 34, 24, 8, "#6E4527")
    out += circle(38, 10, 5, GOLD, 2, GOLD_D)
    out += stroke_path("M-40 22 H10", 3, "#6E4527", "5 5")
    return out


@prop
def banknotes(a):
    out = ""
    for k, (dx, dy, r) in enumerate(((-14, 6, -10), (4, 0, 4), (20, -6, 16))):
        out += group(rect(-34, -20, 68, 40, 5, "#7FBF72") + rect(-26, -13, 52, 26, 3, "#6AA95F", 2)
                     + circle(0, 0, 9, "#CDEBC3", 2, "#4F8A47"), dx, dy, 1, r)
    return out


@prop
def envelope(a):
    out = group(rect(-34, -16, 68, 40, 5, "#7FBF72") + circle(0, 2, 8, "#CDEBC3", 2, "#4F8A47"), 4, -22, 1, -8)
    out += rect(-48, -14, 96, 62, 6, PAPER)
    out += path("M-48 -14 L0 24 L48 -14", "none", 3, edge(PAPER))
    out += shine("M-44 -10 H40 L0 20 Z", 0.0)
    return out


@prop
def pricetag_up(a):
    return _pricetag(a, "up")


@prop
def pricetag_down(a):
    return _pricetag(a, "down")


def _pricetag(a, way):
    out = poly([(-54, 0), (-22, -34), (52, -34), (52, 34), (-22, 34)], a.A if way == "up" else GREEN)
    out += circle(-28, 0, 7, a.L, 2)
    arrow = poly([(26, -18), (42, 2), (33, 2), (33, 22), (19, 22), (19, 2), (10, 2)], WHITE, 2, "#8C97A6")
    if way == "down":
        arrow = group(arrow, 0, 0, 1, 180)
        arrow = f'<g transform="translate(52 4) rotate(180) translate(-26 -2)"><polygon points="26,-18 42,2 33,2 33,22 19,22 19,2 10,2" fill="{WHITE}" stroke="#8C97A6" stroke-width="2"/></g>'
    return out + arrow


@prop
def percent_badge(a):
    out = circle(0, 0, 40, a.A, 4)
    out += shine("M-30 -16 A34 34 0 0 1 8 -34 L4 -26 A26 26 0 0 0 -24 -12Z", 0.45)
    out += circle(-14, -14, 8, "none", 5, WHITE) + circle(14, 14, 8, "none", 5, WHITE)
    out += stroke_path("M18 -18 L-18 18", 6, WHITE)
    return out


@prop
def receipt(a):
    out = path("M-34 -52 H34 V50 L26 44 L17 50 L9 44 L0 50 L-9 44 L-17 50 L-26 44 L-34 50 Z", PAPER)
    for y in (-34, -20, -6, 8):
        out += line(-22, y, 22 - (y % 3) * 4, y, 4, LINE)
    out += circle(14, 28, 13, GREEN, 3) + stroke_path("M7 28 L12 34 L22 22", 4, WHITE)
    return out


@prop
def ledger(a):
    out = rect(-50, -40, 100, 82, 6, "#6B4A8C" if False else a.D)
    out += rect(-44, -34, 88, 70, 3, PAPER, 2)
    for y in (-22, -8, 6, 20):
        out += line(-34, y, 34, y, 3, LINE)
    out += line(0, -34, 0, 36, 2, LINE)
    out += circle(-18, 26, 8, GREEN, 2) + stroke_path("M-22 26 L-18 30 L-12 22", 3, WHITE)
    return out


@prop
def calendar(a):
    out = rect(-42, -38, 84, 84, 8, PAPER)
    out += rect(-42, -38, 84, 24, 8, RED) + rect(-42, -26, 84, 12, 0, RED, 0)
    out += rect(-26, -50, 8, 20, 4, STEEL) + rect(18, -50, 8, 20, 4, STEEL)
    for r_ in range(2):
        for c in range(4):
            out += rect(-34 + c * 19, 0 + r_ * 20, 13, 13, 2, PAPER_D, 0)
    out += circle(24, 26, 11, "none", 4, RED)
    return out


@prop
def chart(a):
    out = rect(-54, -44, 108, 88, 8, PAPER)
    for k, h in enumerate((18, 30, 44, 60)):
        out += rect(-42 + k * 24, 36 - h, 17, h, 3, a.A if k < 3 else GREEN)
    out += stroke_path("M-44 14 L-18 -2 L6 6 L40 -28", 5, RED)
    out += poly([(40, -36), (50, -22), (34, -24)], RED, 2)
    return out


# ---------------------------------------------------------------- buildings and signs

@prop
def gov(a):
    out = poly([(0, -48), (-60, -14), (60, -14)], STONE)
    out += circle(0, -28, 8, a.A, 2)
    out += rect(-60, -14, 120, 10, 2, PAPER_D)
    for x in (-50, -28, -6, 16, 38):
        out += rect(x, -4, 14, 50, 3, WHITE)
    out += rect(-64, 46, 128, 10, 2, PAPER_D) + rect(-70, 56, 140, 10, 2, STONE)
    return out


@prop
def bank_building(a):
    out = poly([(0, -50), (-60, -16), (60, -16)], GOLD, 3, GOLD_D)
    out += circle(0, -30, 10, "#FFD96A", 2, GOLD_D) + poly([(0, -37), (5, -30), (0, -23), (-5, -30)], GOLD, 1.5, GOLD_D)
    out += rect(-60, -16, 120, 10, 2, "#E9C46A", 3, GOLD_D)
    for x in (-50, -28, -6, 16, 38):
        out += rect(x, -6, 14, 52, 3, WHITE, 3, "#A8A08A")
    out += rect(-64, 44, 128, 10, 2, "#E9C46A", 3, GOLD_D) + rect(-70, 54, 140, 10, 2, GOLD, 3, GOLD_D)
    return out


@prop
def flag(a):
    out = rect(-4, -62, 8, 124, 3, WOOD)
    out += path("M4 -58 C26 -68 42 -48 64 -58 L64 -16 C42 -6 26 -26 4 -16 Z", a.A)
    out += star_poly(34, -37, 11, WHITE)
    out += circle(0, -64, 6, GOLD, 2, GOLD_D)
    return out


def star_poly(cx, cy, r, fill):
    return poly(star_pts(cx, cy, r), fill, 2)


@prop
def flags_crossed(a):
    return group(flag(a), -14, 0, 0.9, -14) + group(flag(a), 14, 0, 0.9, 14)


@prop
def podium(a):
    out = rect(-22, -10, 44, 58, 3, a.A) + rect(-66, 14, 44, 34, 3, a.M) + rect(22, 24, 44, 24, 3, a.D)
    out += star_poly(0, -28, 17, GOLD)
    out += circle(-44, 32, 7, "none", 4, WHITE) + circle(44, 36, 6, "none", 4, WHITE)
    out += line(0, 6, 0, 26, 6, WHITE)
    return out


@prop
def medal(a):
    out = poly([(-22, -62), (-4, -62), (20, -16), (2, -16)], a.A) + poly([(22, -62), (4, -62), (-20, -16), (0, -16)], a.M)
    out += circle(0, 12, 32, GOLD, 3, GOLD_D) + circle(0, 12, 23, "#FFD96A", 2, GOLD_D)
    out += star_poly(0, 12, 17, GOLD)
    return out


@prop
def rosette(a):
    out = poly([(-18, 10), (-34, 62), (-12, 50), (0, 64), (6, 12)], a.M) + poly([(18, 10), (34, 62), (12, 50), (0, 64), (-6, 12)], a.A)
    for k in range(12):
        ang = k * math.pi / 6
        out += circle(round(40 * math.cos(ang), 1), round(40 * math.sin(ang) - 14, 1), 11, a.A, 2)
    out += circle(0, -14, 40, a.A, 3) + circle(0, -14, 26, WHITE, 3, edge(a.A)) + star_poly(0, -14, 16, a.A)
    return out


@prop
def laurel(a):
    out = ""
    for side in (-1, 1):
        for k in range(7):
            ang = 0.9 + k * 0.28
            x = side * 54 * math.sin(ang) * 1.0
            y = 50 * math.cos(ang) - 4 - k * 2
            out += group(ellipse(0, 0, 7, 15, GREEN, 2), round(x, 1), round(y, 1), 1, side * (20 + k * 12))
    return out


@prop
def crown_big(a):
    return ui("crown", 0, 0, 2.2)


@prop
def banner_arch(a):
    out = rect(-62, -34, 12, 90, 3, STEEL) + rect(50, -34, 12, 90, 3, STEEL)
    out += rect(-66, -50, 132, 30, 8, a.A)
    for k in range(8):
        out += rect(-58 + k * 15, -44, 7.5, 18, 0, WHITE, 0) if k % 2 == 0 else ""
    out += rect(-66, -50, 132, 30, 8, "none", 3)
    return out


@prop
def key(a):
    out = circle(-30, 0, 22, GOLD, 3, GOLD_D) + circle(-30, 0, 9, "#F8E39A", 3, GOLD_D)
    out += rect(-10, -7, 64, 14, 3, GOLD, 3, GOLD_D) + rect(34, 6, 8, 20, 2, GOLD, 3, GOLD_D) + rect(46, 6, 8, 14, 2, GOLD, 3, GOLD_D)
    return out


@prop
def padlock(a):
    out = stroke_path("M-20 -6 V-22 A20 20 0 0 1 20 -22 V-6", 9, STEEL)
    out += rect(-34, -8, 68, 56, 10, GOLD, 3, GOLD_D)
    out += circle(0, 16, 8, "#7A5C0C", 0) + rect(-3, 18, 6, 16, 2, "#7A5C0C", 0)
    return out


@prop
def chain(a):
    out = ""
    for k in range(4):
        out += group(rect(-9, -16, 18, 32, 9, "none", 5, STEEL), 0, -42 + k * 28, 1, 0 if k % 2 == 0 else 90)
    return out


@prop
def scales(a):
    out = rect(-4, -48, 8, 90, 3, GOLD, 3, GOLD_D) + rect(-28, 40, 56, 10, 4, GOLD, 3, GOLD_D)
    out += line(-52, -30, 52, -34, 5, GOLD_D)
    for x, y in ((-52, -30), (52, -34)):
        out += line(x, y, x - 18, y + 38, 2, GOLD_D) + line(x, y, x + 18, y + 38, 2, GOLD_D)
        out += path(f"M{x - 24} {y + 38} H{x + 24} A24 12 0 0 1 {x - 24} {y + 38}Z", STEEL)
    out += circle(0, -50, 7, GOLD, 2, GOLD_D)
    return out


# ---------------------------------------------------------------- tools and work

@prop
def hardhat(a):
    out = path("M-46 16 C-46 -28 -20 -44 0 -44 C20 -44 46 -28 46 16Z", YELLOW)
    out += rect(-9, -44, 18, 58, 6, "#F0B52A", 2) + rect(-58, 12, 116, 16, 8, "#F0B52A")
    out += shine("M-40 4 C-40 -20 -24 -34 -8 -38 L-8 -30 C-24 -24 -32 -12 -32 4Z", 0.5)
    return out


@prop
def cone(a):
    out = rect(-32, 42, 64, 12, 3, "#D9651E") + poly([(-24, 42), (24, 42), (9, -46), (-9, -46)], ORANGE)
    out += poly([(-14, -14), (14, -14), (17, 4), (-17, 4)], WHITE, 2, "#C98A55")
    out += shine("M-18 38 L-6 -42 L-2 -42 L-12 38Z", 0.35)
    return out


@prop
def barrier(a):
    out = rect(-50, -8, 9, 62, 2, STEEL) + rect(41, -8, 9, 62, 2, STEEL)
    out += rect(-58, -36, 116, 28, 4, WHITE)
    for x in (-44, -20, 4, 28):
        out += poly([(x, -36), (x + 14, -36), (x + 4, -8), (x - 10, -8)], RED, 0)
    out += rect(-58, -36, 116, 28, 4, "none", 3, "#8C97A6")
    return out


@prop
def hammer(a):
    out = rect(-6, -8, 12, 74, 4, WOOD) + rect(-32, -36, 64, 28, 6, STEEL)
    out += shine("M-28 -32 H28 V-26 H-28Z", 0.45)
    return out


@prop
def wrench(a):
    out = rect(-7, -10, 14, 78, 6, STEEL) + circle(0, -26, 22, STEEL) + rect(-9, -54, 18, 24, 2, "#5E6A7A", 0)
    out += shine("M-3 -2 V60", 0.0)
    return out


@prop
def tools(a):
    return group(hammer(a), 0, 0, 0.95, 38) + group(wrench(a), 0, 0, 0.95, -38)


@prop
def magnifier(a):
    out = line(20, 20, 54, 54, 12, "#8B5A34")
    out += circle(-8, -8, 34, "#CFEAF8", 0) + f'<circle cx="-8" cy="-8" r="34" fill="none" stroke="{STEEL}" stroke-width="9"/>'
    out += f'<circle cx="-8" cy="-8" r="39" fill="none" stroke="{edge(STEEL)}" stroke-width="2"/>'
    out += stroke_path("M-26 -20 A20 20 0 0 1 -12 -30", 5, WHITE)
    return out


@prop
def clipboard(a, mark=None):
    out = rect(-40, -52, 80, 106, 8, "#B9824A") + rect(-32, -40, 64, 86, 3, PAPER, 2)
    out += rect(-15, -58, 30, 18, 6, STEEL)
    for y in (-26, -10, 6, 22):
        out += line(-22, y, 22 - (y % 5) * 3, y, 4, LINE)
    if mark == "check":
        out += circle(18, 30, 18, GREEN, 3) + stroke_path("M9 30 L16 38 L28 22", 5, WHITE)
    elif mark == "x":
        out += circle(18, 30, 18, RED, 3) + stroke_path("M10 22 L26 38 M26 22 L10 38", 5, WHITE)
    return out


PROPS["clipboard_check"] = lambda a: clipboard(a, "check")
PROPS["clipboard_x"] = lambda a: clipboard(a, "x")


@prop
def doc(a, stamp=None):
    out = path("M-36 -50 H14 L38 -26 V50 H-36Z", PAPER) + path("M14 -50 V-26 H38", PAPER_D, 2)
    for y in (-14, 0, 14, 28):
        out += line(-24, y, 24 - (y % 4) * 4, y, 4, LINE)
    if stamp == "red":
        out += circle(14, 28, 22, "none", 5, RED) + circle(14, 28, 14, "none", 3, RED) + star_poly(14, 28, 9, RED)
    elif stamp == "x":
        out += stroke_path("M-6 8 L38 52 M38 8 L-6 52", 8, RED)
    return out


PROPS["doc_stamp"] = lambda a: doc(a, "red")
PROPS["doc_x"] = lambda a: doc(a, "x")


@prop
def forms_stack(a):
    out = group(rect(-40, -44, 80, 92, 5, PAPER_D), -10, 6, 1, -8) + group(rect(-40, -44, 80, 92, 5, "#F2EAD3"), 8, 2, 1, 5)
    out += rect(-38, -48, 76, 92, 5, PAPER)
    for y in (-30, -16, -2, 12):
        out += line(-26, y, 26 - (y % 4) * 5, y, 4, LINE)
    out += rect(-26, 22, 52, 12, 3, a.L, 2)
    return out


@prop
def stamp(a):
    out = rect(-8, -62, 16, 40, 8, "#8B5A34") + circle(0, -64, 14, "#A06B3F", 3)
    out += rect(-30, -24, 60, 16, 5, STEEL) + rect(-36, -10, 72, 18, 5, RED) + line(-36, 8, 36, 8, 2, edge(RED))
    return out


@prop
def newspaper(a):
    out = group(rect(-54, -40, 104, 82, 4, PAPER_D), 5, 5, 1, 4)
    out += rect(-54, -42, 104, 84, 4, PAPER)
    out += rect(-44, -34, 84, 18, 2, DARK, 0)
    out += rect(-44, -10, 36, 28, 2, "#B7C2CF", 0)
    for y in (-8, 2, 12):
        out += line(-2, y, 40, y, 4, LINE)
    for y in (26, 34):
        out += line(-44, y, 38, y, 4, LINE)
    return out


@prop
def megaphone(a):
    out = path("M-30 -14 L34 -46 V50 L-30 22Z", a.A) + ellipse(34, 2, 12, 48, a.M)
    out += rect(-46, -16, 22, 40, 6, STEEL) + path("M-22 18 L-14 56 H-2 L-8 20Z", WHITE)
    out += shine("M-24 -10 L28 -36 V-26 L-24 2Z", 0.4)
    out += stroke_path("M56 -22 Q70 2 56 26", 5, a.D) + stroke_path("M66 -36 Q88 2 66 40", 5, a.D)
    return out


@prop
def placard(a, mark="!"):
    out = rect(-5, -4, 10, 66, 3, WOOD) + rect(-44, -58, 88, 62, 8, PAPER)
    if mark == "!":
        out += rect(-6, -48, 12, 26, 5, RED, 0) + circle(0, -12, 7, RED, 0)
    elif mark == "x":
        out += stroke_path("M-18 -48 L18 -12 M18 -48 L-18 -12", 9, RED)
    else:
        for y in (-44, -30, -16):
            out += line(-30, y, 30, y, 6, a.A)
    return out


PROPS["placard_x"] = lambda a: placard(a, "x")
PROPS["placard_text"] = lambda a: placard(a, "t")


@prop
def mask(a):
    out = path("M-56 -10 Q0 -40 56 -10 V16 Q56 40 24 40 Q8 40 2 24 H-2 Q-8 40 -24 40 Q-56 40 -56 16Z", DARK)
    out += ellipse(-26, 12, 15, 10, WHITE, 0) + ellipse(26, 12, 15, 10, WHITE, 0)
    out += circle(-26, 12, 5, DARK, 0) + circle(26, 12, 5, DARK, 0)
    out += rect(-56, -14, 112, 14, 7, RED, 2)
    return out


@prop
def wreck(a):
    out = line(-58, -52, 36, -52, 12, "#6C7787") + rect(-60, -62, 10, 120, 3, STEEL)
    out += line(34, -52, 34, 0, 5, STEEL, "butt") + circle(34, 30, 32, "#4A5565", 3) + shine("M14 14 A22 22 0 0 1 30 4 L28 12 A14 14 0 0 0 20 20Z", 0.5)
    return out


@prop
def beetle(a):
    out = ""
    for dy in (-14, 8, 30):
        out += line(-22, dy, -50, dy - 12, 5, "#3E2C1C") + line(22, dy, 50, dy - 12, 5, "#3E2C1C")
    out += line(-8, -40, -18, -58, 4, "#3E2C1C") + line(8, -40, 18, -58, 4, "#3E2C1C")
    out += ellipse(0, 10, 28, 40, "#7A8F2C") + circle(0, -34, 14, "#3E2C1C", 3)
    out += line(0, -26, 0, 50, 3, "#4A5A1A")
    for x, y in ((-12, -2), (12, -2), (-12, 24), (12, 24)):
        out += circle(x, y, 5, "#F2E8B0", 0)
    out += shine("M-20 -10 C-22 -20 -12 -26 -8 -26 L-8 -18 C-14 -16 -18 -10 -18 0Z", 0.4)
    return out


@prop
def factory(a):
    out = rect(-60, 4, 120, 50, 3, "#C9B79A") + poly([(-60, 4), (-60, -14), (-34, 4), (-34, -14), (-8, 4), (-8, -14), (18, 4)], "#B8A685", 3)
    out += rect(26, -40, 16, 46, 2, "#8A5A3A") + rect(46, -22, 14, 28, 2, "#8A5A3A")
    for x in (-50, -26, -2):
        out += rect(x, 24, 16, 14, 2, "#BFE3F5", 2)
    out += rect(30, 28, 22, 26, 2, "#7A5232", 2)
    out += cloud_shape(30, -64, 0.5, "#9AA3AD") + cloud_shape(56, -52, 0.38, "#B5BCC4")
    return out


# ---------------------------------------------------------------- weather and water

def cloud_shape(cx, cy, s, fill):
    d = "M-48 18 C-62 18 -66 -4 -46 -6 C-46 -26 -14 -34 -2 -18 C8 -34 44 -28 42 -4 C64 -4 64 18 46 18Z"
    return group(path(d, fill, 3) + shine("M-40 -4 C-36 -18 -18 -24 -8 -18 C-20 -20 -30 -14 -34 -2Z", 0.5), cx, cy, s)


@prop
def cloud(a):
    return cloud_shape(0, 0, 1.15, "#F4F1EA")


@prop
def storm_cloud(a):
    return cloud_shape(0, -4, 1.15, "#7D8798")


@prop
def bolt(a):
    return poly([(6, -56), (-26, 8), (-4, 8), (-14, 58), (28, -10), (4, -10), (16, -56)], "#FFD33D", 3, "#B8860B")


@prop
def rain(a):
    out = ""
    for x, y in ((-34, -10), (-14, 10), (6, -6), (26, 12), (46, -8), (-44, 24), (36, 34), (-6, 34)):
        out += line(x, y, x - 8, y + 20, 5, "#5C98D6")
    return out


@prop
def waves(a):
    out = path("M-70 -6 q17 -17 35 0 t35 0 t35 0 t35 0 V54 H-70Z", "#4C93D6")
    out += path("M-70 22 q17 -17 35 0 t35 0 t35 0 t35 0 V54 H-70Z", "#6DB2EA")
    out += stroke_path("M-60 -8 q10 -8 20 0", 4, "#CFE9FA") + stroke_path("M10 -8 q10 -8 20 0", 4, "#CFE9FA")
    return out


@prop
def flame(a):
    out = path("M0 -60 C20 -26 52 -14 52 22 A52 52 0 0 1 -52 22 C-52 -2 -34 -10 -26 -34 C-14 -16 -6 -18 -6 -30 C-6 -42 -2 -50 0 -60Z", "#E8582A")
    out += path("M2 -22 C14 -4 34 4 34 28 A34 34 0 0 1 -34 28 C-34 12 -22 4 -18 -10 C-12 0 -4 -2 2 -22Z", "#F6A02E")
    out += path("M0 8 C8 18 18 24 18 36 A18 18 0 0 1 -18 36 C-18 26 -8 22 0 8Z", "#FFE27A")
    return out


@prop
def crack(a):
    return stroke_path("M-40 -50 L-12 -22 L-26 -4 L8 22 L-6 40 L22 62", 7, "#3E2C1C") + stroke_path("M-12 -22 L14 -34 M8 22 L34 14", 5, "#3E2C1C")


@prop
def hole(a):
    out = ellipse(0, 10, 62, 26, "#5A3F28") + ellipse(0, 14, 50, 18, "#2B1D12", 0) + ellipse(0, 22, 36, 11, "#120B06", 0)
    return out


@prop
def rocks(a):
    out = poly([(-60, 50), (-40, 4), (-8, 20), (-14, 50)], "#8A7B6A") + poly([(-10, 50), (8, -8), (40, 6), (60, 50)], "#9C8D7A")
    out += poly([(-30, 50), (-10, 28), (20, 34), (30, 50)], "#B0A18C")
    out += shine("M10 -4 L30 4 L22 14 L10 8Z", 0.35)
    return out


@prop
def thermometer(a):
    out = rect(-12, -56, 24, 86, 12, WHITE) + circle(0, 38, 22, WHITE)
    out += rect(-6, -30, 12, 62, 6, RED, 0) + circle(0, 38, 15, RED, 0)
    for y in (-44, -32, -20):
        out += line(14, y, 26, y, 4, STEEL)
    return out


@prop
def moon(a):
    return path("M10 -50 A50 50 0 1 0 44 30 A40 40 0 0 1 10 -50Z", "#F2E7A8") + circle(-10, -2, 7, "#E1D48C", 0) + circle(8, 22, 5, "#E1D48C", 0)


@prop
def smoke(a):
    out = ""
    for x, y, r, c in ((-24, 20, 22, "#B5BCC4"), (6, 0, 28, "#C6CCD3"), (34, -22, 22, "#D3D8DD"), (-4, -34, 18, "#DEE2E6")):
        out += circle(x, y, r, c, 3)
    return out


@prop
def gas_cloud(a):
    out = ""
    for x, y, r, c in ((-26, 18, 24, "#9CC25A"), (4, -2, 30, "#B4D46E"), (34, 16, 22, "#9CC25A"), (-4, -30, 20, "#C6E080")):
        out += circle(x, y, r, c, 3)
    return out


@prop
def virus(a):
    out = ""
    for k in range(10):
        ang = k * math.pi / 5
        x, y = 40 * math.cos(ang), 40 * math.sin(ang)
        out += line(round(26 * math.cos(ang), 1), round(26 * math.sin(ang), 1), round(x, 1), round(y, 1), 5, "#5B9A3E") + circle(round(x, 1), round(y, 1), 7, "#8BC34A", 2)
    out += circle(0, 0, 30, "#7DB347", 3) + circle(-9, -8, 5, "#B5DB82", 0) + circle(10, 8, 7, "#B5DB82", 0)
    return out


# ---------------------------------------------------------------- vehicles and streets

@prop
def car(a, body=RED):
    out = path("M-56 18 V0 L-38 -2 L-24 -24 H20 L38 -2 L56 4 V18Z", body)
    out += path("M-30 -2 L-20 -18 H-2 V-2Z", "#BFE3F5", 2) + path("M6 -2 V-18 H16 L30 -2Z", "#BFE3F5", 2)
    out += circle(-32, 20, 13, "#2B3340", 3) + circle(-32, 20, 5, STEEL, 0) + circle(34, 20, 13, "#2B3340", 3) + circle(34, 20, 5, STEEL, 0)
    out += rect(46, 4, 10, 6, 2, "#FFE27A", 1)
    return out


PROPS["car_blue"] = lambda a: car(a, BLUE)
PROPS["car_yellow"] = lambda a: car(a, YELLOW)
PROPS["car_green"] = lambda a: car(a, GREEN)


@prop
def bus(a):
    out = rect(-62, -34, 124, 66, 14, a.A)
    for k in range(4):
        out += rect(-52 + k * 26, -24, 20, 22, 4, "#BFE3F5", 2)
    out += rect(-62, 6, 124, 6, 0, WHITE, 0) + circle(-34, 34, 13, "#2B3340", 3) + circle(34, 34, 13, "#2B3340", 3)
    out += circle(-34, 34, 5, STEEL, 0) + circle(34, 34, 5, STEEL, 0) + rect(52, -6, 8, 8, 2, "#FFE27A", 1)
    return out


@prop
def bike(a):
    out = circle(-34, 20, 24, "none", 6, DARK) + circle(34, 20, 24, "none", 6, DARK)
    out += stroke_path("M-34 20 L-8 -18 H26 L34 20 M-8 -18 L4 20 H-34 M4 20 L26 -18", 6, a.A) + stroke_path("M26 -18 L22 -34 H36", 6, DARK)
    out += stroke_path("M-14 -24 H4", 7, DARK) + circle(4, 20, 6, STEEL, 2)
    return out


@prop
def traffic_light(a, lit="red"):
    out = rect(-8, 40, 16, 22, 3, STEEL) + rect(-26, -58, 52, 102, 14, "#2B3340")
    for k, (y, col) in enumerate(((-38, RED), (-10, YELLOW), (18, GREEN))):
        on = (lit == "red" and k == 0) or (lit == "green" and k == 2)
        out += circle(0, y, 12, col if on else "#4A5565", 2, "#1B2733")
    return out


PROPS["traffic_light_green"] = lambda a: traffic_light(a, "green")


@prop
def bulb(a, on=False):
    out = path("M-26 14 C-46 -8 -40 -50 0 -52 C40 -50 46 -8 26 14 C20 22 18 28 18 34 H-18 C-18 28 -20 22 -26 14Z", "#FFE27A" if on else "#B9C2CD")
    out += rect(-18, 34, 36, 10, 3, STEEL) + rect(-14, 44, 28, 10, 5, STEEL)
    out += stroke_path("M-10 14 L-6 -6 L0 6 L6 -6 L10 14", 4, "#8C97A6" if not on else "#D98A1E")
    return out


PROPS["bulb_on"] = lambda a: bulb(a, True)


@prop
def plug(a):
    out = rect(-26, -20, 52, 44, 10, DARK) + rect(-16, -42, 8, 24, 2, STEEL) + rect(8, -42, 8, 24, 2, STEEL)
    out += stroke_path("M0 24 C0 44 24 36 24 58", 7, DARK)
    return out


@prop
def sign_no(a):
    out = circle(0, 0, 48, WHITE, 4, RED) + f'<circle cx="0" cy="0" r="40" fill="none" stroke="{RED}" stroke-width="10"/>' + line(-28, 28, 28, -28, 10, RED)
    return out


@prop
def sign_warning(a):
    return poly([(0, -54), (56, 42), (-56, 42)], YELLOW, 4, "#8A6008") + rect(-5, -24, 10, 38, 4, "#1B2733", 0) + circle(0, 28, 6, "#1B2733", 0)


@prop
def sign_closed(a):
    out = rect(-6, 10, 12, 52, 3, STEEL) + rect(-50, -46, 100, 60, 8, RED)
    out += line(-34, -16, 34, -16, 10, WHITE) + line(-34, -16, 34, -16, 0, WHITE)
    return out


@prop
def sign_open(a):
    out = rect(-50, -30, 100, 60, 10, GREEN) + rect(-42, -22, 84, 44, 6, "none", 3, WHITE)
    out += circle(0, 0, 14, WHITE, 0) + stroke_path("M-6 0 L-2 5 L7 -6", 4, GREEN)
    out += line(-26, -30, -26, -52, 3, STEEL) + line(26, -30, 26, -52, 3, STEEL)
    return out


@prop
def fence(a):
    out = ""
    for k in range(6):
        x = -56 + k * 22
        out += poly([(x, -30), (x + 9, -40), (x + 18, -30), (x + 18, 40), (x, 40)], WOOD)
    out += rect(-60, -10, 120, 10, 2, "#9A6B3F") + rect(-60, 18, 120, 10, 2, "#9A6B3F")
    return out


# ---------------------------------------------------------------- growing things, food, objects

@prop
def pot(a):
    out = path("M-30 -6 H30 L22 44 H-22Z", "#C96B3A") + rect(-34, -16, 68, 16, 4, "#D9804A")
    out += stroke_path("M0 -16 V-48", 5, "#3F8A3A") + path("M0 -32 C-24 -34 -30 -52 -26 -58 C-6 -56 0 -46 0 -32Z", GREEN, 2) + path("M0 -40 C22 -42 28 -58 24 -64 C6 -62 0 -52 0 -40Z", "#6CBF5A", 2)
    return out


@prop
def pots_row(a):
    return group(pot(a), -42, 10, 0.78) + group(pot(a), 0, 4, 0.9) + group(pot(a), 44, 12, 0.72)


@prop
def shovel(a):
    out = rect(-5, -60, 10, 70, 4, WOOD) + rect(-14, -64, 28, 8, 3, WOOD)
    out += path("M-20 8 H20 L16 50 Q0 62 -16 50Z", STEEL) + shine("M-14 14 H-6 L-8 44 L-14 40Z", 0.5)
    return out


@prop
def watering_can(a):
    out = path("M-36 -16 H24 L28 40 H-40Z", a.A) + path("M24 -2 L58 -26 L64 -16 L28 12Z", a.M)
    out += stroke_path("M-36 -4 C-62 -4 -62 30 -38 30", 6, a.D) + stroke_path("M-18 -16 C-18 -42 8 -42 8 -16", 6, a.D)
    return out


@prop
def sprout_big(a):
    return ui("sprout", 0, 0, 2.4)


@prop
def lungs(a):
    out = rect(-5, -52, 10, 40, 4, "#E9A0A0") + stroke_path("M0 -14 L-14 4 M0 -14 L14 4", 6, "#E9A0A0")
    out += path("M-8 -20 C-40 -26 -58 20 -52 48 C-46 56 -22 54 -12 44 C-8 30 -8 6 -8 -20Z", "#7DBF6A")
    out += path("M8 -20 C40 -26 58 20 52 48 C46 56 22 54 12 44 C8 30 8 6 8 -20Z", "#6CB05A")
    out += stroke_path("M-14 0 L-30 20 M-14 14 L-26 28 M14 0 L30 20 M14 14 L26 28", 4, "#4F8A47")
    return out


@prop
def basket(a):
    out = stroke_path("M-26 -8 C-26 -50 26 -50 26 -8", 7, "#8B5A34") + path("M-44 -6 H44 L34 46 H-34Z", "#C58A4E")
    out += line(-14, 0, -10, 42, 4, "#8B5A34") + line(14, 0, 10, 42, 4, "#8B5A34") + line(-40, 20, 40, 20, 4, "#8B5A34")
    return out


@prop
def shelves(a):
    out = rect(-56, -48, 112, 100, 6, "#B07C47") + rect(-48, -40, 96, 84, 2, "#7A5232", 0)
    for y in (-14, 14):
        out += rect(-52, y, 104, 8, 2, "#C58A4E")
    out += rect(-52, 44, 104, 8, 2, "#C58A4E")
    out += rect(-38, -34, 16, 20, 2, a.A, 2)
    return out


@prop
def suitcase(a):
    out = stroke_path("M-14 -28 V-42 H14 V-28", 6, DARK) + rect(-46, -30, 92, 70, 10, a.A) + rect(-46, -30, 92, 70, 10, "none", 3)
    out += line(-46, 0, 46, 0, 3, edge(a.A)) + rect(-8, -6, 16, 14, 3, GOLD, 2, GOLD_D) + line(-28, -30, -28, 40, 3, edge(a.A)) + line(28, -30, 28, 40, 3, edge(a.A))
    return out


@prop
def jar(a):
    out = rect(-38, -34, 76, 92, 16, "#D8EEF6") + rect(-30, -50, 60, 18, 5, a.A)
    out += ellipse(0, 46, 32, 9, GOLD, 2, GOLD_D) + ellipse(-8, 36, 28, 8, "#F8D26A", 2, GOLD_D)
    out += group(path("M0 12 C-30 -8 -16 -30 -4 -22 C0 -20 0 -16 0 -16 C0 -16 0 -20 4 -22 C16 -30 30 -8 0 12Z", "#E24B5A"), 0, 0, 0.8)
    out += shine("M-30 -26 V44", 0.0)
    return out


@prop
def jar_hands(a):
    return jar(a)


@prop
def heart(a, cross=True):
    out = path("M0 40 C-66 -4 -38 -56 -8 -38 C-3 -35 0 -30 0 -30 C0 -30 3 -35 8 -38 C38 -56 66 -4 0 40Z", "#E24B5A")
    out += shine("M-42 -16 C-48 -34 -30 -44 -18 -34 C-26 -30 -34 -24 -42 -16Z", 0.5)
    if cross:
        out += rect(-6, -14, 12, 34, 3, WHITE, 0) + rect(-17, -3, 34, 12, 3, WHITE, 0)
    return out


PROPS["heart_plain"] = lambda a: heart(a, False)


@prop
def gift(a):
    out = rect(-40, -2, 80, 52, 6, a.A) + rect(-46, -22, 92, 26, 6, a.M) + rect(-8, -22, 16, 72, 0, WHITE, 2, "#C9C1AC")
    out += path("M0 -22 C-30 -58 -54 -30 -26 -20Z", WHITE, 3, "#C9C1AC") + path("M0 -22 C30 -58 54 -30 26 -20Z", WHITE, 3, "#C9C1AC")
    return out


@prop
def bow(a):
    out = path("M0 6 L-22 48 L-6 40 L2 54 Z", RED) + path("M0 6 L22 48 L6 40 L-2 54 Z", mix(RED, 0.15))
    out += path("M0 2 C-38 -44 -64 -8 -30 8 C-14 12 -6 8 0 2Z", RED) + path("M0 2 C38 -44 64 -8 30 8 C14 12 6 8 0 2Z", mix(RED, 0.15))
    out += shine("M-44 -14 C-36 -24 -24 -24 -16 -16 C-28 -16 -36 -10 -44 -14Z", 0.5) + circle(0, 4, 10, mix(RED, 0.1, "#1B2733"), 3)
    return out


@prop
def ticket(a):
    d = "M-56 -30 H56 V-8 A10 10 0 0 0 56 12 V34 H-56 V12 A10 10 0 0 0 -56 -8 Z"
    out = path(d, a.A) + rect(-44, -20, 54, 44, 4, WHITE, 2, edge(a.A))
    for k in range(3):
        out += circle(-34 + k * 18, 2, 7, GOLD, 2, GOLD_D)
    out += star_poly(34, 2, 13, GOLD) + stroke_path("M18 -26 V30", 3, WHITE, "3 6")
    return out


@prop
def trophy_big(a):
    return ui("trophy", 0, 0, 2.2)


@prop
def mic(a):
    out = line(-6, 14, -34, 54, 10, DARK) + circle(8, -14, 30, STEEL, 3) + shine("M-10 -30 A22 22 0 0 1 12 -40 L10 -34 A16 16 0 0 0 -4 -26Z", 0.5)
    for k in range(-2, 3):
        out += line(-14, -14 + k * 8, 30, -14 + k * 8, 2, "#5E6A7A")
    out += rect(-6, 12, 28, 14, 4, DARK)
    return out


@prop
def camera(a):
    out = rect(-48, -26, 96, 66, 10, DARK) + rect(-18, -40, 36, 16, 5, STEEL) + circle(0, 8, 24, "#1B2733", 3) + circle(0, 8, 15, "#4C6B8A", 2) + circle(-6, 2, 4, WHITE, 0)
    out += circle(34, -14, 6, RED, 2)
    return out


@prop
def lanterns(a):
    out = stroke_path("M-70 -40 Q0 -8 70 -40", 4, DARK)
    for k, (x, c) in enumerate(((-52, RED), (-26, ORANGE), (0, YELLOW), (26, ORANGE), (52, RED))):
        y = -40 + 30 * (1 - ((x / 70) ** 2)) * 0.9
        out += line(x, round(y, 1), x, round(y + 8, 1), 3, DARK) + ellipse(x, round(y + 26, 1), 12, 17, c, 2) + rect(x - 6, round(y + 8, 1), 12, 5, 1, DARK, 0)
    return out


@prop
def bunting(a):
    out = stroke_path("M-70 -36 Q0 4 70 -36", 4, DARK)
    for k, c in enumerate((RED, YELLOW, GREEN, BLUE, RED, YELLOW, GREEN)):
        x = -58 + k * 19.5
        y = -36 + 40 * (1 - ((x / 70) ** 2)) * 0.97
        out += poly([(x - 9, round(y, 1)), (x + 9, round(y, 1)), (x, round(y + 26, 1))], c, 2)
    return out


@prop
def balloons(a):
    out = ""
    for x, y, c, r in ((-26, -14, RED, 24), (6, -30, a.A, 26), (34, -8, YELLOW, 24)):
        out += stroke_path(f"M{x} {y + r} Q{x + 6} {y + r + 26} 0 58", 3, STEEL) + ellipse(x, y, r - 3, r, c, 3) + poly([(x - 4, y + r), (x + 4, y + r), (x, y + r + 6)], c, 2)
        out += shine(f"M{x - 12} {y - 8} A12 14 0 0 1 {x - 2} {y - 18} L{x} {y - 12} A8 10 0 0 0 {x - 8} {y - 4}Z", 0.5)
    return out


@prop
def bricks(a):
    out = ""
    for row, y in enumerate((30, 4, -22)):
        for k in range(3 - (row % 2)):
            x = -48 + k * 36 + (18 if row % 2 else 0)
            out += rect(x, y, 34, 22, 2, "#C9684A" if (k + row) % 2 else "#D9805A")
    return out


@prop
def pallet(a):
    out = rect(-56, 28, 112, 12, 2, "#C9A06A") + rect(-56, 52, 112, 12, 2, "#C9A06A")
    for x in (-52, -4, 40):
        out += rect(x, 40, 14, 12, 2, "#A87A44")
    return out


@prop
def crane(a):
    out = rect(-36, -60, 10, 120, 2, "#E8A02A") + line(-30, -56, 56, -56, 10, "#E8A02A") + line(-30, -56, 56, -56, 3, "#C97A12")
    out += line(40, -56, 40, -14, 3, DARK) + rect(30, -14, 20, 14, 2, STEEL) + rect(-50, 52, 38, 10, 2, "#C97A12")
    for k in range(5):
        out += line(-36, -50 + k * 22, -26, -28 + k * 22, 2, "#C97A12") + line(-26, -50 + k * 22, -36, -28 + k * 22, 2, "#C97A12")
    return out


@prop
def scissors(a):
    out = ""
    out += group(rect(-5, -52, 10, 58, 3, STEEL), 0, 0, 1, -22) + group(rect(-5, -52, 10, 58, 3, "#B5BFCC"), 0, 0, 1, 22)
    out += stroke_path("M-2 4 L-22 24 M2 4 L22 24", 7, STEEL)
    out += circle(-24, 38, 16, "none", 7, RED) + circle(24, 38, 16, "none", 7, RED) + circle(0, 4, 5, DARK, 0)
    return out


@prop
def ribbon_long(a):
    out = path("M-66 -18 H66 V18 H-66 L-54 0Z", RED) + line(-66, 0, 66, 0, 0, RED)
    out += star_poly(0, 0, 12, GOLD)
    return out


@prop
def spray(a):
    out = rect(-18, -24, 36, 70, 8, a.A) + rect(-12, -38, 24, 16, 4, STEEL) + rect(-4, -48, 8, 12, 2, DARK)
    out += rect(-18, -2, 36, 22, 0, WHITE, 0) + shine("M-14 -20 V42", 0.0)
    out += circle(34, -50, 5, a.M, 0) + circle(46, -36, 4, a.M, 0) + circle(26, -34, 3, a.M, 0)
    return out


@prop
def graffiti_wall(a):
    out = rect(-60, -46, 120, 96, 4, "#B9A890")
    for k in range(5):
        out += line(-60, -34 + k * 20, 60, -34 + k * 20, 1.5, "#A3927A") + line(-40 + (k % 2) * 20, -46 + k * 20, -40 + (k % 2) * 20, -26 + k * 20, 1.5, "#A3927A")
    out += stroke_path("M-44 14 C-30 -30 -10 40 6 -6 S34 -20 46 8", 11, a.A) + stroke_path("M-40 24 L40 -4", 5, YELLOW)
    return out


@prop
def music(a):
    out = ""
    for x, y in ((-20, 24), (24, 10)):
        out += ellipse(x, y, 13, 10, DARK, 0) + rect(x + 9, y - 56, 5, 58, 0, DARK, 0)
    out += poly([(-6, -32), (38, -46), (38, -34), (-6, -20)], DARK, 0)
    return out


@prop
def speaker(a):
    out = rect(-32, -50, 64, 100, 8, "#2B3340") + circle(0, -18, 18, "#4A5565", 3) + circle(0, -18, 6, STEEL, 0) + circle(0, 22, 22, "#4A5565", 3) + circle(0, 22, 9, STEEL, 0)
    return out


@prop
def solar(a):
    out = poly([(-60, 40), (-40, -30), (60, -30), (46, 40)], "#2F5C9A")
    for k in range(1, 4):
        out += line(round(-60 + k * 26, 1), 40, round(-40 + k * 24, 1), -30, 2, "#9CC6F0")
    for k in range(1, 3):
        out += line(round(-60 + k * 6.8 + 0, 1), round(40 - k * 23.4, 1), round(46 + k * 4.6 + 0, 1), round(40 - k * 23.4, 1), 2, "#9CC6F0")
    return out


@prop
def arrow_up(a):
    return poly([(0, -50), (38, -4), (14, -4), (14, 46), (-14, 46), (-14, -4), (-38, -4)], GREEN, 4)


@prop
def arrow_down(a):
    return poly([(0, 50), (38, 4), (14, 4), (14, -46), (-14, -46), (-14, 4), (-38, 4)], RED, 4)


@prop
def badge_check(a):
    return circle(0, 0, 40, GREEN, 4) + stroke_path("M-18 2 L-6 16 L20 -14", 9, WHITE)


@prop
def badge_x(a):
    return circle(0, 0, 40, RED, 4) + stroke_path("M-16 -16 L16 16 M16 -16 L-16 16", 9, WHITE)


@prop
def badge_plus(a):
    return circle(0, 0, 40, GREEN, 4) + rect(-6, -20, 12, 40, 3, WHITE, 0) + rect(-20, -6, 40, 12, 3, WHITE, 0)


@prop
def badge_minus(a):
    return circle(0, 0, 40, RED, 4) + rect(-20, -6, 40, 12, 3, WHITE, 0)


@prop
def badge_question(a):
    return circle(0, 0, 40, a.A, 4) + stroke_path("M-12 -12 C-12 -30 18 -30 14 -12 C12 0 0 0 0 12", 8, WHITE) + circle(0, 28, 5, WHITE, 0)


@prop
def badge_exclaim(a):
    return circle(0, 0, 40, RED, 4) + rect(-6, -26, 12, 34, 5, WHITE, 0) + circle(0, 22, 7, WHITE, 0)


@prop
def badge_zero(a):
    return circle(0, 0, 40, GREEN, 4) + ellipse(0, 0, 14, 22, "none", 0) + f'<ellipse cx="0" cy="0" rx="13" ry="21" fill="none" stroke="{WHITE}" stroke-width="9"/>'


@prop
def badge_or(a):
    return (circle(0, 0, 32, WHITE, 3, edge(a.A)) + stroke_path("M-18 0 H18", 6, a.A)
            + poly([(-24, 0), (-10, -11), (-10, 11)], a.A, 2) + poly([(24, 0), (10, -11), (10, 11)], a.A, 2))


@prop
def citizens3(a):
    return ui("role_worker", -34, 0, 1.15) + ui("role_child", 0, 8, 1.0) + ui("role_older", 34, 0, 1.15)


@prop
def queue4(a):
    out = ""
    for k, name in enumerate(("role_worker", "role_older", "role_student", "role_child")):
        out += ui(name, -48 + k * 32, 0, 0.9)
    return out
