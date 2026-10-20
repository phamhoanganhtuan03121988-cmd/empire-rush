#!/usr/bin/env python3
"""EMPIRE RUSH app icon (web/PWA home-screen icon, Windows icon source).

Draws the game's identity as vector shapes - an isometric board ring in the
seven district colours on a walnut plinth, the gold-domed landmark tower in
the centre, on a night-blue field - and writes an SVG. Full-bleed square, no
transparency and no text (iOS rounds the corners itself; text would be
unreadable at 60 px).

  python3 scripts/art/gen_app_icon.py   # -> client/assets/branding/app_icon.svg

PNG sizes are rendered by Godot (scripts/web/render_icons.gd) so no extra
tool is needed. Licence: original work of the EMPIRE RUSH project, CC0 1.0.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "client", "assets", "branding", "app_icon.svg")
DISTRICTS = ["#e8775a", "#3fb5a5", "#7fc36b", "#f08cc0", "#f2c94c", "#5b9be8", "#b16be0"]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def poly(pts, fill, extra=""):
    return '<polygon points="%s" fill="%s"%s/>' % (" ".join("%.1f,%.1f" % p for p in pts), fill, extra)


def main():
    cx, cy = 512, 640
    hw, hh = 400, 230          # board half extents (isometric diamond)
    depth = 46
    top, right, bottom, left = (cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)
    s = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">',
         "<defs>",
         '<radialGradient id="bg" cx="0.5" cy="0.42" r="0.75"><stop offset="0" stop-color="#24365c"/>'
         '<stop offset="0.6" stop-color="#121a2e"/><stop offset="1" stop-color="#070b14"/></radialGradient>',
         '<linearGradient id="gold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffe29a"/>'
         '<stop offset="0.45" stop-color="#f5b83d"/><stop offset="1" stop-color="#a8701a"/></linearGradient>',
         '<linearGradient id="tower" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff6e2"/>'
         '<stop offset="0.55" stop-color="#f1e0bd"/><stop offset="1" stop-color="#c9b089"/></linearGradient>',
         '<radialGradient id="pool" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#ffd27a" stop-opacity="0.35"/>'
         '<stop offset="1" stop-color="#ffd27a" stop-opacity="0"/></radialGradient>',
         "</defs>",
         '<rect width="1024" height="1024" fill="url(#bg)"/>',
         '<ellipse cx="512" cy="600" rx="470" ry="300" fill="url(#pool)"/>']
    # Plinth sides (walnut) and gold inlay line.
    s.append(poly([left, bottom, (bottom[0], bottom[1] + depth), (left[0], left[1] + depth)], "#4a3426"))
    s.append(poly([bottom, right, (right[0], right[1] + depth), (bottom[0], bottom[1] + depth)], "#3a281d"))
    s.append('<polyline points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="none" stroke="#e2b448" stroke-width="7"/>'
             % (left[0], left[1] + 10, bottom[0], bottom[1] + 10, right[0], right[1] + 10))
    # Ivory board and the tile ring in district colours.
    s.append(poly([top, right, bottom, left], "#f6f1e7"))
    corners = [top, right, bottom, left]
    k = 0
    inner = 0.72
    for e in range(4):
        a, b = corners[e], corners[(e + 1) % 4]
        for i in range(7):
            t0, t1 = (i + 0.08) / 7, (i + 0.92) / 7
            p0, p1 = lerp(a, b, t0), lerp(a, b, t1)
            q0 = lerp((cx, cy), p0, inner + 0.08)
            q1 = lerp((cx, cy), p1, inner + 0.08)
            o0 = lerp((cx, cy), p0, 0.97)
            o1 = lerp((cx, cy), p1, 0.97)
            if i in (0, 6):
                continue  # corner tiles stay ivory
            s.append(poly([o0, o1, q1, q0], DISTRICTS[k % 7]))
            k += 1
    # Road and park in the centre.
    s.append(poly([lerp((cx, cy), c, inner) for c in corners], "#4a5160"))
    s.append(poly([lerp((cx, cy), c, inner - 0.08) for c in corners], "#7cc36a"))
    # Landmark tower: tiers in warm stone, gold bands, dome and spire.
    base_y = cy + 20
    tiers = [(150, 120), (122, 110), (96, 100), (72, 80)]
    y = base_y
    for w, h in tiers:
        s.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="url(#tower)"/>' % (cx - w / 2, y - h, w, h))
        for wx in range(int(cx - w / 2) + 14, int(cx + w / 2) - 10, 22):
            s.append('<rect x="%d" y="%.1f" width="10" height="%.1f" rx="2" fill="#2c4f8f" opacity="0.75"/>'
                     % (wx, y - h + 16, h - 34))
        s.append('<rect x="%.1f" y="%.1f" width="%.1f" height="12" fill="url(#gold)"/>' % (cx - w / 2 - 6, y - h - 6, w + 12))
        y -= h
    s.append('<path d="M%.1f,%.1f A62,62 0 0 1 %.1f,%.1f Z" fill="url(#gold)"/>' % (cx - 62, y - 6, cx + 62, y - 6))
    s.append('<rect x="%.1f" y="%.1f" width="10" height="70" fill="url(#gold)"/>' % (cx - 5, y - 132))
    s.append('<circle cx="%d" cy="%.1f" r="14" fill="#ffe29a"/>' % (cx, y - 138))
    # Gold frame.
    s.append('<rect x="22" y="22" width="980" height="980" rx="190" fill="none" stroke="#f5b83d" stroke-opacity="0.55" stroke-width="10"/>')
    s.append("</svg>")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write("\n".join(s) + "\n")
    print("wrote", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
