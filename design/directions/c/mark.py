import math, sys

BG = "#1D1915"
LB = "#C9A05A"   # laurel bronze
LD = "#8C6A30"
CR = "#D23A2C"   # crest red
GD = "#D9A93E"   # helmet gold
GDD = "#A87A22"


def leaf(x, y, ang, L, W, fill=LB):
    a = math.radians(ang)
    dx, dy = math.cos(a), math.sin(a)
    px, py = -dy, dx
    tx, ty = x + dx * L, y + dy * L
    mx, my = x + dx * L * 0.5, y + dy * L * 0.5
    return (f'<path d="M{x:.1f},{y:.1f} Q{mx+px*W:.1f},{my+py*W:.1f} {tx:.1f},{ty:.1f} '
            f'Q{mx-px*W:.1f},{my-py*W:.1f} {x:.1f},{y:.1f}Z" fill="{fill}"/>')


def branch(side):
    out = []
    cx, cy, R = 200, 205, 156
    a0, a1 = (98, 205) if side < 0 else (82, -25)
    n = 11
    pts = []
    for i in range(n + 1):
        t = a0 + (a1 - a0) * i / n
        r = math.radians(t)
        pts.append((cx + R * math.cos(r), cy + R * math.sin(r), t))
    d = "M" + " L".join(f"{p[0]:.1f},{p[1]:.1f}" for p in pts)
    out.append(f'<path d="{d}" fill="none" stroke="{LD}" stroke-width="4" stroke-linecap="round"/>')
    for i, (x, y, t) in enumerate(pts[1:], 1):
        tang = t + (90 if side < 0 else -90)
        s = 1 - 0.35 * i / n
        out.append(leaf(x, y, tang + 40, 32 * s, 9.5 * s))
        out.append(leaf(x, y, tang - 40, 32 * s, 9.5 * s))
    x, y, t = pts[-1]
    out.append(leaf(x, y, t + (90 if side < 0 else -90), 24, 7.5))
    return "\n".join(out)


def strand(cx, cy, ang, r0, L, W, bend):
    """A flame-like strand: base on a circle of radius r0, pointed tip bent sideways."""
    a = math.radians(ang)
    dx, dy = math.cos(a), math.sin(a)
    px, py = -dy, dx
    bx, by = cx + dx * r0, cy + dy * r0
    tx, ty = bx + dx * L + px * bend, by + dy * L + py * bend
    c1 = (bx + dx * L * 0.55 + px * (W + bend * 0.3), by + dy * L * 0.55 + py * (W + bend * 0.3))
    c2 = (bx + dx * L * 0.55 - px * (W - bend * 0.5), by + dy * L * 0.55 - py * (W - bend * 0.5))
    b1 = (bx + px * W * 0.6, by + py * W * 0.6)
    b2 = (bx - px * W * 0.6, by - py * W * 0.6)
    return (f'<path d="M{b1[0]:.1f},{b1[1]:.1f} Q{c1[0]:.1f},{c1[1]:.1f} {tx:.1f},{ty:.1f} '
            f'Q{c2[0]:.1f},{c2[1]:.1f} {b2[0]:.1f},{b2[1]:.1f} Z"/>')


def crest():
    cx, cy = 200, 226
    out = []
    # back row then front row, so strands overlap like feathers
    for row, (r0, L, W, step, off) in enumerate([(92, 104, 23, 14, 0), (92, 90, 20, 14, 7)]):
        a = 178 + off
        k = 0
        while a <= 362:
            side = (a - 270) / 92          # -1 at left, +1 at right
            bend = 44 * side * abs(side) ** 0.5 + (7 if k % 2 else -7)
            LL = L * (1 - 0.18 * abs(side)) + (14 if k % 3 == 0 else 0)
            out.append(strand(cx, cy, a, r0, LL, W, bend))
            a += step
            k += 1
    return f'<g fill="{CR}" stroke="{BG}" stroke-width="3" stroke-linejoin="round">' + "".join(out) + "</g>"


def ell(cx, cy, rx, ry, deg):
    a = math.radians(deg)
    return cx + rx * math.cos(a), cy + ry * math.sin(a)


def holder():
    cx, cy = 200, 230
    o = [ell(cx, cy, 98, 112, t) for t in range(180, 361, 6)]
    i = [ell(cx, cy, 82, 96, t) for t in range(360, 179, -6)]
    p = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in o + i) + " Z"
    rv = "".join(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3" fill="{BG}" stroke="none"/>'
                 for x, y in (ell(cx, cy, 90, 104, t) for t in (200, 228, 312, 340)))
    return p, rv


CRD = "#8A2419"


def crest_brush():
    cx, cy = 200, 232
    n = 30
    a0, a1 = 186, 354
    d = []
    for i in range(n + 1):
        a = math.radians(a0 + i * (a1 - a0) / n)
        r = 1.0 if i % 2 == 0 else 0.93
        d.append((cx + 172 * r * math.cos(a), cy + 178 * r * math.sin(a)))
    p = f"M{d[0][0]:.1f},{d[0][1]+14:.1f} L{d[0][0]:.1f},{d[0][1]:.1f}"
    for i in range(1, len(d) - 1, 2):
        c, e = d[i], d[i + 1]
        p += f" Q{c[0]:.1f},{c[1]:.1f} {e[0]:.1f},{e[1]:.1f}"
    p += f" L{d[-1][0]:.1f},{d[-1][1]+14:.1f}"
    inner = [ell(200, 230, 98, 112, t) for t in range(360, 179, -6)]
    p += " L" + " L".join(f"{x:.1f},{y:.1f}" for x, y in inner) + " Z"
    lines = []
    for i in range(21):
        t = math.radians(190 + i * (160 / 20))
        x1, y1 = cx + 106 * math.cos(t), cy + 120 * math.sin(t)
        x2, y2 = cx + 158 * math.cos(t), cy + 164 * math.sin(t)
        lines.append(f"M{x1:.1f},{y1:.1f} L{x2:.1f},{y2:.1f}")
    return (f'<path d="{p}" fill="{CR}" stroke="{BG}" stroke-width="4" stroke-linejoin="round"/>'
            f'<path d="{" ".join(lines)}" stroke="{CRD}" stroke-width="4" fill="none"/>')


hp, hrv = holder()


def rivets(pts, r=3.2):
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{BG}" stroke="none"/>' for x, y in pts)


helmet = f'''
<g transform="translate(200,214) scale(0.7) translate(-200,-230)">
 {crest_brush()}
 <g stroke="{BG}" stroke-width="4" stroke-linejoin="round" fill="{GD}">
  <path d="{hp}"/>
  <path d="M193,122 L207,122 L207,170 L193,170 Z"/>
  <path d="M104,262 L118,252 L120,290 L106,282 Z"/>
  <path d="M296,262 L282,252 L280,290 L294,282 Z"/>
  <path d="M130,236 C128,186 160,160 200,160 C240,160 272,186 270,236 Z"/>
  <path d="M114,258 L148,262 C148,300 162,334 192,352 L192,382 C160,380 128,356 118,324 C112,302 110,280 114,258 Z"/>
  <path d="M286,258 L252,262 C252,300 238,334 208,352 L208,382 C240,380 272,356 282,324 C288,302 290,280 286,258 Z"/>
  <path d="M116,234 Q200,208 284,234 L286,264 Q236,252 212,256 L200,270 L188,256 Q164,252 114,264 Z"/>
  <path d="M190,256 L210,256 L210,300 L200,318 L190,300 Z"/>
  <circle cx="200" cy="384" r="9"/>
 </g>
 {hrv}
 <path d="M200,166 L200,226" stroke="{BG}" stroke-width="4"/>
 <path d="M166,174 C158,194 156,214 158,232 M234,174 C242,194 244,214 242,232" fill="none" stroke="{BG}" stroke-width="3"/>
 <path d="M126,270 L144,272 C146,304 158,330 182,346 L182,368 C156,362 136,344 128,318 C124,302 122,286 126,270 Z" fill="none" stroke="{BG}" stroke-width="3"/>
 <path d="M274,270 L256,272 C254,304 242,330 218,346 L218,368 C244,362 264,344 272,318 C276,302 278,286 274,270 Z" fill="none" stroke="{BG}" stroke-width="3"/>
 {rivets([(132,244),(160,236),(240,236),(268,244),(134,300),(150,336),(266,300),(250,336),(200,200)])}
</g>
'''

bg = "" if "--nobg" in sys.argv else f'<rect width="400" height="400" fill="{BG}"/>\n'
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">
<title>AVGVR mark: crested Roman helmet in open laurel</title>
{bg}{branch(-1)}
{branch(1)}
{helmet}
</svg>'''
open("mark.svg", "w").write(svg)
