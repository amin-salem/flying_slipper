"""Builds the Flying Slipper app icon (SVG) and renders every size with Chromium."""
import math
import os
from playwright.sync_api import sync_playwright

INK = "#2B1B3A"
OW = 18  # outline width
OUT = os.path.dirname(os.path.abspath(__file__))


def star8(cx, cy, r):
    pts = []
    for k in range(16):
        a = k * math.pi / 8 - math.pi / 2
        rr = r if k % 2 == 0 else r * 0.62
        pts.append(f"{cx + math.cos(a) * rr:.1f},{cy + math.sin(a) * rr:.1f}")
    return "M" + " L".join(pts) + " Z"


def background():
    cx, cy = 470, 430
    rays = []
    n = 18
    for k in range(n):
        a0 = k * 2 * math.pi / n
        a1 = a0 + math.pi / n
        R = 1600
        rays.append(
            f'<path d="M{cx},{cy} L{cx + math.cos(a0) * R:.0f},{cy + math.sin(a0) * R:.0f} '
            f'L{cx + math.cos(a1) * R:.0f},{cy + math.sin(a1) * R:.0f} Z" fill="#FFFFFF" fill-opacity="0.13"/>'
        )
    stars = []
    for row, y in enumerate(range(-40, 1100, 128)):
        for x in range(-40 + (64 if row % 2 else 0), 1100, 128):
            stars.append(f'<path d="{star8(x, y, 26)}" fill="#B8322B" fill-opacity="0.10"/>')
    return f"""
  <defs>
    <radialGradient id="bg" cx="{cx}" cy="{cy}" r="760" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFF1A6"/>
      <stop offset="0.35" stop-color="#FFC93C"/>
      <stop offset="0.75" stop-color="#FF8A2E"/>
      <stop offset="1" stop-color="#F0562B"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  {''.join(stars)}
  {''.join(rays)}
"""


def slipper(cx, cy, angle):
    """Top-down Persian plastic slipper (dampaee): footprint sole + wide raised strap."""
    sole = ("M-300,0 C-300,-82 -250,-92 -190,-92 C-110,-92 -70,-74 0,-80 "
            "C90,-88 170,-122 245,-108 C325,-94 325,94 245,112 C170,126 90,98 0,92 "
            "C-70,86 -110,92 -190,92 C-250,92 -300,82 -300,0 Z")
    bed = ("M-262,0 C-262,-60 -228,-68 -186,-68 C-112,-68 -72,-52 0,-58 "
           "C86,-66 160,-94 236,-82 C288,-72 288,72 236,86 C160,98 86,72 0,66 "
           "C-72,60 -112,68 -186,68 C-228,68 -262,60 -262,0 Z")
    nubs = "".join(f'<circle cx="{x}" cy="{y}" r="9"/>'
                   for x in range(-230, -60, 40) for y in (-36, 0, 36))
    nubs += "".join(f'<circle cx="{x}" cy="{y}" r="9"/>'
                    for x in range(140, 260, 40) for y in (-46, -6, 34))
    return f"""
  <g transform="translate({cx},{cy}) rotate({angle})">
    <!-- motion trail -->
    <g stroke="#FFFFFF" stroke-linecap="round" fill="none">
      <line x1="-300" y1="-55" x2="-470" y2="-55" stroke-width="26" stroke-opacity="0.9"/>
      <line x1="-300" y1="10" x2="-540" y2="10" stroke-width="30" stroke-opacity="0.95"/>
      <line x1="-300" y1="75" x2="-430" y2="75" stroke-width="22" stroke-opacity="0.8"/>
    </g>
    <!-- sole thickness (3D edge) -->
    <path d="{sole}" transform="translate(0,30)" fill="#1F3F86" stroke="{INK}" stroke-width="{OW}" stroke-linejoin="round"/>
    <!-- sole top -->
    <path d="{sole}" fill="url(#sole)" stroke="{INK}" stroke-width="{OW}" stroke-linejoin="round"/>
    <!-- footbed with grip nubs -->
    <path d="{bed}" fill="#5E93E8"/>
    <g fill="#3F70C8">{nubs}</g>
    <!-- shadow under the raised strap -->
    <path d="M10,-118 C30,-40 30,40 10,118 L120,124 C100,40 100,-40 120,-124 Z" fill="#163066" fill-opacity="0.5"/>
    <!-- strap: arched band across the middle of the foot -->
    <path d="M-25,-134 C15,-156 75,-156 105,-136 C88,-46 88,46 105,136 C75,156 15,156 -25,134 C-8,46 -8,-46 -25,-134 Z"
          fill="url(#strap)" stroke="{INK}" stroke-width="{OW}" stroke-linejoin="round"/>
    <path d="M-18,-112 C-2,-40 -2,40 -18,112" stroke="#7A1F1F" stroke-opacity="0.55" stroke-width="12"
          fill="none" stroke-linecap="round"/>
    <path d="M30,-118 C46,-40 46,40 30,118" stroke="#FFFFFF" stroke-opacity="0.5" stroke-width="14"
          fill="none" stroke-linecap="round"/>
    <!-- shine -->
    <path d="M-250,-58 Q-160,-78 -60,-66" stroke="#FFFFFF" stroke-opacity="0.65" stroke-width="14"
          fill="none" stroke-linecap="round"/>
    <!-- spin arcs -->
    <g stroke="{INK}" stroke-width="14" fill="none" stroke-linecap="round">
      <path d="M-250,-150 A 170 170 0 0 1 -60,-175"/>
      <path d="M-230,160 A 190 190 0 0 0 -40,190"/>
    </g>
  </g>
"""


def kid(cx, cy, r):
    # spiky hair with zig-zag bangs
    pts = []
    n = 6
    a0, a1 = math.pi * 1.10, math.pi * 1.90
    for k in range(n * 2 + 1):
        a = a0 + (a1 - a0) * k / (n * 2)
        rr = r + 72 if k % 2 else r + 10
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    bangs = []
    m = 7
    xr, xl = pts[-1][0], pts[0][0]
    for k in range(1, m):
        x = xr + (xl - xr) * k / m
        y = cy - r * (0.40 if k % 2 else 0.58)
        bangs.append((x, y))
    hair = "M" + " L".join(f"{x:.0f},{y:.0f}" for x, y in pts + bangs) + " Z"
    ex1, ex2, ey = cx - 98, cx + 98, cy + 32
    eye_rx, eye_ry = 70, 86
    px, py = -20, -26  # looking up-left at the slipper

    def eye(ex):
        return f"""
    <ellipse cx="{ex}" cy="{ey}" rx="{eye_rx}" ry="{eye_ry}" fill="#FFFFFF" stroke="{INK}" stroke-width="{OW}"/>
    <circle cx="{ex + px}" cy="{ey + py}" r="38" fill="{INK}"/>
    <circle cx="{ex + px - 13}" cy="{ey + py - 15}" r="14" fill="#FFFFFF"/>
    <circle cx="{ex + px + 14}" cy="{ey + py + 14}" r="6" fill="#FFFFFF"/>"""

    return f"""
  <g>
    <!-- ears -->
    <circle cx="{cx - r + 6}" cy="{cy + 40}" r="56" fill="#F7CDA4" stroke="{INK}" stroke-width="{OW}"/>
    <circle cx="{cx + r - 6}" cy="{cy + 40}" r="56" fill="#F7CDA4" stroke="{INK}" stroke-width="{OW}"/>
    <!-- head -->
    <circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#skin)" stroke="{INK}" stroke-width="{OW}"/>
    <!-- hair -->
    <path d="{hair}" fill="#3A2416" stroke="{INK}" stroke-width="{OW}" stroke-linejoin="round"/>
    <!-- worried brows -->
    <path d="M{ex1 - 60},{ey - 100} L{ex1 + 40},{ey - 124}" stroke="{INK}" stroke-width="22" stroke-linecap="round"/>
    <path d="M{ex2 + 60},{ey - 100} L{ex2 - 40},{ey - 124}" stroke="{INK}" stroke-width="22" stroke-linecap="round"/>
    {eye(ex1)}
    {eye(ex2)}
    <!-- blush -->
    <ellipse cx="{cx - 172}" cy="{cy + 125}" rx="46" ry="28" fill="#FF6F8A" fill-opacity="0.45"/>
    <ellipse cx="{cx + 172}" cy="{cy + 125}" rx="46" ry="28" fill="#FF6F8A" fill-opacity="0.45"/>
    <!-- screaming mouth -->
    <ellipse cx="{cx}" cy="{cy + 172}" rx="58" ry="60" fill="#7A1F1F" stroke="{INK}" stroke-width="{OW}"/>
    <ellipse cx="{cx}" cy="{cy + 200}" rx="34" ry="22" fill="#FF8A8A"/>
    <rect x="{cx - 36}" y="{cy + 120}" width="72" height="18" rx="8" fill="#FFFFFF"/>
    <!-- sweat drops -->
    <path d="M{cx + r - 10},{cy - r + 40} q34,58 0,80 q-34,-22 0,-80 z" fill="#A8E6FF" stroke="{INK}" stroke-width="12"/>
    <path d="M{cx + r + 50},{cy - r + 140} q24,40 0,56 q-24,-16 0,-56 z" fill="#A8E6FF" stroke="{INK}" stroke-width="10"/>
  </g>
"""


def defs():
    return """
  <defs>
    <linearGradient id="sole" x1="0" y1="-120" x2="0" y2="92" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#7FB0FF"/>
      <stop offset="1" stop-color="#3F70C8"/>
    </linearGradient>
    <linearGradient id="strap" x1="0" y1="-150" x2="0" y2="140" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FF7A6E"/>
      <stop offset="1" stop-color="#D9342B"/>
    </linearGradient>
    <radialGradient id="skin" cx="0.4" cy="0.35" r="0.75">
      <stop offset="0" stop-color="#FFE0C2"/>
      <stop offset="1" stop-color="#F2B98A"/>
    </radialGradient>
    <filter id="drop" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="18" stdDeviation="14" flood-color="#5A1A0A" flood-opacity="0.35"/>
    </filter>
  </defs>
"""


def foreground():
    # impact sparks between slipper toe and hair
    sparks = "".join(
        f'<path d="M{590 + math.cos(a) * 80:.0f},{400 + math.sin(a) * 80:.0f} '
        f'L{590 + math.cos(a) * 125:.0f},{400 + math.sin(a) * 125:.0f}" '
        f'stroke="{INK}" stroke-width="16" stroke-linecap="round"/>'
        for a in (-1.9, -1.3, -0.7)
    )
    return f"""
  <g filter="url(#drop)">
    {kid(640, 718, 250)}
  </g>
  {sparks}
  <g filter="url(#drop)">
    {slipper(330, 290, 32)}
  </g>
"""


def svg(content, size=1024):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
            f'viewBox="0 0 1024 1024">{defs()}{content}</svg>')


def full_icon(radius=0):
    clip = ""
    if radius:
        clip = f'<clipPath id="rc"><rect width="1024" height="1024" rx="{radius}"/></clipPath>'
        return svg(f'<defs>{clip}</defs><g clip-path="url(#rc)">{background()}{foreground()}</g>')
    return svg(background() + foreground())


def adaptive_fg():
    # Android adaptive icons only show the middle ~66% safely: shrink the art.
    s = 0.62
    t = 512 * (1 - s)
    return svg(f'<g transform="translate({t},{t}) scale({s})">{foreground()}</g>')


def adaptive_bg():
    return svg(background())


def render(pages):
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(viewport={"width": 1024, "height": 1024})
        for name, markup in pages.items():
            pg.set_content(f'<html><body style="margin:0;background:transparent">{markup}</body></html>')
            pg.screenshot(path=os.path.join(OUT, name), omit_background=True,
                          clip={"x": 0, "y": 0, "width": 1024, "height": 1024})
            print("rendered", name)
        b.close()


if __name__ == "__main__":
    pages = {
        "icon_full.png": full_icon(),
        "icon_rounded.png": full_icon(radius=230),
        "icon_fg.png": adaptive_fg(),
        "icon_bg.png": adaptive_bg(),
    }
    for n, m in pages.items():
        open(os.path.join(OUT, n.replace(".png", ".svg")), "w").write(m)
    render(pages)
