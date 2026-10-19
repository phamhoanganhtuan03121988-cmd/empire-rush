#!/usr/bin/env python3
"""EMPIRE RUSH portrait forge (Phase 5.1): the stylised character portraits
are drawn here from vector shapes (no third-party art), one SVG per persona,
in the game's palette (night blue, ivory, gold accents).

  python3 scripts/art/gen_portraits.py      # writes client/assets/ui/portraits/*.svg

Licence of the output: original work of the EMPIRE RUSH project, CC0 1.0
(docs/ASSET_REGISTER.csv, ART-POR-001). Personas are cosmetic identities only
(name, face, colour); they carry no rules data and no gameplay effect.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "client", "assets", "ui", "portraits")
DATA = os.path.join(ROOT, "client", "data", "presentation", "personas.json")


def shade(hex_color, k):
    """k < 0 darkens, k > 0 lightens (towards white)."""
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    if k < 0:
        r, g, b = (int(c * (1 + k)) for c in (r, g, b))
    else:
        r, g, b = (int(c + (255 - c) * k) for c in (r, g, b))
    return "#%02x%02x%02x" % (r, g, b)


SKIN = {"light": "#f2c9a8", "warm": "#e4b08a", "tan": "#cd9168", "deep": "#a8714d"}

HEAD = "M256,146 C327,146 346,204 344,252 C342,306 302,356 256,358 C210,356 170,306 168,252 C166,204 185,146 256,146 Z"

# Hair: (back layer drawn behind the head, front layer drawn over it).
HAIR = {
    "side_part": ("",
                  "M166,256 C152,176 198,124 262,126 C326,128 360,176 346,252 C340,222 330,198 312,184 "
                  "C286,196 236,200 206,188 C190,204 176,226 166,256 Z "
                  "M300,180 C268,168 232,170 210,186 C236,160 280,152 312,170 Z"),
    "long": ("M256,128 C170,128 138,194 142,282 C146,362 124,404 112,446 L400,446 C388,404 366,362 370,282 "
             "C374,194 342,128 256,128 Z",
             "M168,262 C160,180 206,132 258,134 C314,136 354,178 344,256 C334,222 306,196 262,190 "
             "C236,212 200,232 168,262 Z"),
    "bob": ("M256,132 C180,132 148,190 150,268 C152,322 160,350 178,356 L334,356 C352,350 360,322 362,268 "
            "C364,190 332,132 256,132 Z",
            "M170,244 C166,172 206,140 256,140 C306,140 346,172 342,244 C322,214 292,202 256,202 "
            "C220,202 190,214 170,244 Z"),
    "older": ("M170,250 C162,212 168,190 182,176 C176,214 180,236 186,262 Z M342,250 C350,212 344,190 330,176 "
              "C336,214 332,236 326,262 Z",
              "M186,190 C204,160 236,150 260,152 C290,152 316,164 330,186 C306,174 284,172 258,174 "
              "C232,176 208,180 186,190 Z"),
    "curly": ("",
              "".join("M%d,%d m-30,0 a30,30 0 1,0 60,0 a30,30 0 1,0 -60,0 " % (x, y) for x, y in
                      [(186, 196), (206, 160), (240, 140), (276, 138), (310, 154), (334, 188), (176, 230),
                       (342, 226), (258, 162), (224, 176), (292, 176)])),
    "bun": ("M256,104 m-40,0 a40,40 0 1,0 80,0 a40,40 0 1,0 -80,0",
            "M168,250 C160,176 204,134 256,134 C308,134 352,176 344,250 C332,214 302,194 256,192 "
            "C210,194 180,214 168,250 Z"),
    "cap": ("M172,262 C170,236 172,214 180,200 L188,262 Z M340,262 C342,236 340,214 332,200 L324,262 Z", ""),
    "ponytail": ("M330,170 C392,180 404,260 384,330 C376,360 360,380 344,388 C362,340 366,280 340,220 Z",
                 "M168,250 C162,178 206,136 258,136 C312,136 352,178 344,250 C328,212 300,192 270,188 "
                 "C238,200 200,218 168,250 Z"),
}

# Clothing: list of (path, fill) drawn over the shoulders base.
def clothing(kind, c):
    shoulders = "M84,512 C92,440 140,404 206,392 L306,392 C372,404 420,440 428,512 Z"
    if kind == "suit":
        return [(shoulders, c),
                ("M222,392 L256,470 L290,392 Z", "#f6f1e7"),
                ("M246,412 L266,412 L272,470 L256,500 L240,470 Z", "#f5b83d"),
                ("M206,392 L256,476 L232,512 L180,512 C186,456 196,420 206,392 Z", shade(c, -0.25)),
                ("M306,392 L256,476 L280,512 L332,512 C326,456 316,420 306,392 Z", shade(c, -0.25))]
    if kind == "ao_dai":
        return [(shoulders, c),
                ("M214,372 L298,372 L302,404 C282,414 230,414 210,404 Z", shade(c, -0.15)),
                ("M210,404 C230,414 282,414 302,404", "none:#f5b83d:5"),
                ("M256,412 L256,512", "none:#f5b83d:4")]
    if kind == "cardigan":
        return [(shoulders, c),
                ("M222,392 L256,450 L290,392 Z", "#e9e2d2"),
                ("M226,392 L246,420 L256,400 Z M286,392 L266,420 L256,400 Z", "#fbf7ee"),
                ("M206,392 L256,480 L256,512 L178,512 C184,456 194,420 206,392 Z", shade(c, -0.12)),
                ("M306,392 L256,480 L256,512 L334,512 C328,456 318,420 306,392 Z", shade(c, -0.12)),
                ("M256,470 m-5,0 a5,5 0 1,0 10,0 a5,5 0 1,0 -10,0", "#f5b83d")]
    if kind == "blazer":
        return [(shoulders, c),
                ("M214,392 C228,420 284,420 298,392 Z", "#fbf7ee"),
                ("M206,392 L248,452 L230,512 L178,512 C186,456 196,420 206,392 Z", shade(c, -0.2)),
                ("M306,392 L264,452 L282,512 L334,512 C326,456 316,420 306,392 Z", shade(c, -0.2))]
    if kind == "hoodie":
        return [("M150,430 C170,380 342,380 362,430 C330,404 182,404 150,430 Z", shade(c, -0.25)),
                (shoulders, c),
                ("M214,394 C230,424 282,424 298,394", "none:%s:10" % shade(c, -0.3)),
                ("M236,420 L232,476 M276,420 L280,476", "none:#fbf7ee:5")]
    if kind == "architect":
        return [(shoulders, "#dfe7f2"),
                ("M220,392 L256,430 L292,392 L300,404 L256,446 L212,404 Z", "#fbfdff"),
                ("M150,512 C156,450 180,420 214,404 L232,512 Z", c),
                ("M362,512 C356,450 332,420 298,404 L280,512 Z", c),
                ("M150,470 L232,470 M280,470 L362,470", "none:#f6e27a:8")]
    if kind == "jacket":
        return [(shoulders, c),
                ("M220,392 C232,408 280,408 292,392 L292,378 L220,378 Z", shade(c, -0.3)),
                ("M256,404 L256,512", "none:%s:4" % shade(c, -0.4)),
                ("M120,470 C150,450 170,450 190,470 M322,470 C342,450 362,450 392,470", "none:%s:6" % shade(c, -0.18))]
    if kind == "resort":
        dots = "".join("M%d,%d m-9,0 a9,9 0 1,0 18,0 a9,9 0 1,0 -18,0 " % (x, y) for x, y in
                       [(140, 470), (186, 440), (330, 444), (372, 476), (300, 492), (206, 496), (160, 506), (352, 508)])
        return [(shoulders, c),
                (dots, shade(c, 0.45)),
                ("M226,392 L256,446 L286,392 Z", SKIN_CUR[0]),
                ("M206,392 L256,452 L236,470 C220,440 210,418 206,392 Z M306,392 L256,452 L276,470 "
                 "C292,440 302,418 306,392 Z", shade(c, -0.18))]
    return [(shoulders, c)]


SKIN_CUR = ["#e4b08a"]


def path(d, fill, extra=""):
    if fill.startswith("none:"):
        _, stroke, width = fill.split(":")
        return ('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" '
                'stroke-linejoin="round"%s/>' % (d, stroke, width, extra))
    return '<path d="%s" fill="%s"%s/>' % (d, fill, extra)


def portrait(p):
    pid = p["id"]
    color = p["color"]
    skin = SKIN[p["skin"]]
    SKIN_CUR[0] = skin
    hair = p["hair_color"]
    style = p["hair"]
    back, front = HAIR[style]
    s = []
    s.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">')
    s.append("<defs>")
    s.append('<radialGradient id="bg" cx="0.5" cy="0.32" r="0.75">'
             '<stop offset="0" stop-color="%s"/><stop offset="0.62" stop-color="%s"/>'
             '<stop offset="1" stop-color="%s"/></radialGradient>' % (shade(color, 0.35), color, shade(color, -0.45)))
    s.append('<linearGradient id="face" x1="0" y1="0" x2="1" y2="0.2">'
             '<stop offset="0" stop-color="%s"/><stop offset="0.55" stop-color="%s"/>'
             '<stop offset="1" stop-color="%s"/></linearGradient>' % (shade(skin, 0.08), skin, shade(skin, -0.12)))
    s.append('<linearGradient id="hair" x1="0" y1="0" x2="0" y2="1">'
             '<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>'
             % (shade(hair, 0.18), shade(hair, -0.2)))
    s.append('<clipPath id="disc"><circle cx="256" cy="256" r="256"/></clipPath>')
    s.append("</defs>")
    s.append('<g clip-path="url(#disc)">')
    s.append('<rect width="512" height="512" fill="url(#bg)"/>')
    # Soft skyline silhouette in the background (the game's city).
    sky = shade(color, -0.3)
    s.append('<path d="M0,400 L0,330 L40,330 L40,290 L72,290 L72,340 L104,340 L104,260 L126,250 L148,260 L148,350 '
             'L364,350 L364,280 L392,270 L420,280 L420,320 L448,320 L448,240 L470,232 L492,240 L492,330 L512,330 '
             'L512,400 Z" fill="%s" opacity="0.55"/>' % sky)
    s.append('<circle cx="256" cy="256" r="248" fill="none" stroke="#f5b83d" stroke-opacity="0.35" stroke-width="6"/>')
    # The figure is drawn 15 % larger, anchored low, so the face reads at small sizes.
    s.append('<g transform="translate(256,330) scale(1.15) translate(-256,-310)">')
    if back:
        s.append(path(back, "url(#hair)"))
    # Neck and shoulders.
    s.append(path("M222,320 L290,320 L298,398 C280,410 232,410 214,398 Z", shade(skin, -0.12)))
    s.append(path("M222,350 C240,372 272,372 290,350 L290,330 L222,330 Z", shade(skin, -0.25), ' opacity="0.45"'))
    for d, f in clothing(p["outfit"], p["outfit_color"]):
        s.append(path(d, f))
    # Ears.
    for x in (170, 342):
        s.append('<ellipse cx="%d" cy="262" rx="16" ry="25" fill="%s"/>' % (x, shade(skin, -0.06)))
        s.append('<ellipse cx="%d" cy="262" rx="7" ry="13" fill="%s"/>' % (x, shade(skin, -0.2)))
    s.append(path(HEAD, "url(#face)"))
    # Cheek blush and jaw shadow.
    s.append('<ellipse cx="208" cy="304" rx="22" ry="12" fill="#e8766a" opacity="0.28"/>')
    s.append('<ellipse cx="304" cy="304" rx="22" ry="12" fill="#e8766a" opacity="0.28"/>')
    s.append(path("M196,330 C222,356 290,356 316,330 C300,352 280,358 256,358 C232,358 212,352 196,330 Z",
                  shade(skin, -0.2), ' opacity="0.35"'))
    if front:
        s.append(path(front, "url(#hair)"))
        if style in ("side_part", "long", "bob", "bun", "ponytail"):
            s.append(path("M212,162 C232,150 262,148 284,154", "none:%s:6" % shade(hair, 0.45), ' opacity="0.6"'))
    if style == "cap":
        cap = p.get("accent", "#2f80ed")
        s.append(path("M166,236 C164,160 206,124 258,124 C312,124 350,160 348,236 C318,214 290,208 256,208 "
                      "C222,208 194,214 166,236 Z", cap))
        s.append(path("M166,236 C200,214 312,214 348,236 C380,246 396,258 392,266 C350,248 300,238 256,238 "
                      "C210,238 176,246 166,236 Z", shade(cap, -0.25)))
        s.append('<circle cx="257" cy="128" r="8" fill="%s"/>' % shade(cap, -0.3))
    if style == "bob" and p.get("accent"):
        s.append(path("M174,214 C206,176 306,176 338,214", "none:%s:12" % p["accent"]))
    if style == "older":
        s.append(path("M186,190 C204,160 236,150 260,152 C290,152 316,164 330,186", "none:%s:3" % shade(hair, -0.2)))
    # Eyebrows.
    brow = shade(hair, -0.15) if style != "older" else "#d8d4cc"
    s.append(path("M196,236 C210,226 230,226 242,232", "none:%s:7" % brow))
    s.append(path("M270,232 C282,226 302,226 316,236", "none:%s:7" % brow))
    # Eyes.
    iris = p.get("eyes", "#4a2f22")
    for x in (220, 292):
        s.append('<ellipse cx="%d" cy="262" rx="17" ry="12" fill="#fffdf8"/>' % x)
        s.append('<circle cx="%d" cy="263" r="9.5" fill="%s"/>' % (x + 1, iris))
        s.append('<circle cx="%d" cy="263" r="4.5" fill="#1a1210"/>' % (x + 1))
        s.append('<circle cx="%d" cy="259" r="3" fill="#ffffff"/>' % (x + 4))
        s.append(path("M%d,256 C%d,247 %d,247 %d,256" % (x - 18, x - 8, x + 8, x + 18), "none:#2a1a14:4"))
    # Nose and mouth.
    s.append(path("M258,272 C254,288 248,298 252,302 C256,305 262,304 266,301", "none:%s:4" % shade(skin, -0.3)))
    if p.get("mustache"):
        s.append(path("M226,318 C240,306 252,310 256,314 C260,310 272,306 286,318 C272,322 262,320 256,318 "
                      "C250,320 240,322 226,318 Z", "#d8d4cc"))
    s.append(path("M232,322 C244,338 268,338 280,322 C270,328 242,328 232,322 Z", "#a0453c"))
    s.append(path("M236,323 C250,331 262,331 276,323", "none:#fffdf8:3"))
    if p.get("beard"):
        s.append(path("M176,292 C182,340 216,362 256,364 C296,362 330,340 336,292 C330,322 312,338 290,342 "
                      "C276,330 236,330 222,342 C200,338 182,322 176,292 Z", "url(#hair)"))
        s.append(path("M232,322 C244,338 268,338 280,322 C270,328 242,328 232,322 Z", "#a0453c"))
    # Accessories.
    acc = p.get("accessory", "")
    if acc == "glasses":
        for x in (220, 292):
            s.append('<rect x="%d" y="246" width="44" height="32" rx="12" fill="#ffffff" fill-opacity="0.12" '
                     'stroke="#2a2420" stroke-width="5"/>' % (x - 22))
        s.append(path("M242,260 C250,254 262,254 270,260", "none:#2a2420:5"))
    if acc == "earrings":
        for x in (170, 342):
            s.append('<circle cx="%d" cy="292" r="7" fill="#f5b83d" stroke="%s" stroke-width="2"/>' % (x, shade("#f5b83d", -0.3)))
    if acc == "headphones":
        s.append(path("M160,268 C150,150 362,150 352,268", "none:#2b2f3a:12"))
        for x in (162, 350):
            s.append('<rect x="%d" y="240" width="26" height="54" rx="12" fill="#2b2f3a"/>' % (x - 13))
            s.append('<rect x="%d" y="250" width="12" height="34" rx="6" fill="%s"/>' % (x - 6, p.get("accent", "#f5b83d")))
    if acc == "pencil":
        s.append(path("M300,96 L344,140", "none:#f5b83d:10"))
        s.append(path("M344,140 L352,148", "none:#2a2420:6"))
    if acc == "sunglasses":
        s.append(path("M196,176 C216,164 240,164 252,174 L260,174 C272,164 296,164 316,176 L312,192 "
                      "C298,200 270,196 262,184 L250,184 C242,196 214,200 200,192 Z", "#1f2633"))
        s.append(path("M206,178 C220,172 232,172 240,176", "none:#7fb2ff:3"))
    s.append("</g>")
    s.append("</g>")
    s.append('<circle cx="256" cy="256" r="252" fill="none" stroke="%s" stroke-width="8"/>' % shade(color, -0.5))
    s.append("</svg>")
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, pid + ".svg"), "w") as f:
        f.write("\n".join(s) + "\n")
    print("wrote", os.path.relpath(os.path.join(OUT, pid + ".svg"), ROOT))


if __name__ == "__main__":
    with open(DATA) as f:
        data = json.load(f)
    for p in data["personas"]:
        portrait(p)
