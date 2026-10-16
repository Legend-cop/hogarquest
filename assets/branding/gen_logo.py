"""Genera el logo de HogarQuest: casita con carita.

Casa redondeada blanca, techo coral, ojos grandes + sonrisa + mejillas rosas,
contorno fino gris oscuro y sin sombras pesadas. Regenera todos los tamaños:
Android (mipmaps + adaptive), Web/PWA, Windows .ico e iOS.

Uso:  python assets/branding/gen_logo.py
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

SS = 4  # supersampling

# Paleta HogarQuest (arcoíris pastel por sección).
VERDE_TOP = (52, 211, 153)    # #34D399
VERDE_BOT = (16, 184, 129)    # #10B981
CORAL = (255, 122, 102)       # #FF7A66
ROSA = (249, 168, 212)        # #F9A8D4
ORO = (251, 191, 36)          # #FBBF24
INK = (31, 41, 55)            # #1F2937
BLANCO = (255, 255, 255)


def lerp(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def vertical_gradient(s, c_top, c_bot):
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(s):
        d.line([0, y, s, y], fill=lerp(c_top, c_bot, y / max(1, s - 1)) + (255,))
    return img


def _unit(x, y):
    n = math.hypot(x, y)
    if n < 1e-9:
        return 0.0, 0.0
    return x / n, y / n


def _star_pts(cx, cy, r, inner=0.46, rot=-math.pi / 2):
    pts = []
    for i in range(10):
        ang = rot + i * math.pi / 5
        rr = r if i % 2 == 0 else r * inner
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    return pts


def _rounded_poly(pts, r):
    """Polígono convexo con esquinas redondeadas de radio r.

    Devuelve (polígono_a_rellenar, [(cx, cy, r), ...]): el polígono conecta los
    puntos de tangencia sobre las aristas originales y los discos cierran los
    arcos. El resultado NO sobresale de los bordes originales.
    """
    n = len(pts)
    poly, disks = [], []
    for i in range(n):
        px, py = pts[i]
        ax, ay = pts[(i - 1) % n]
        bx, by = pts[(i + 1) % n]
        u1 = _unit(ax - px, ay - py)   # hacia el vértice previo
        u2 = _unit(bx - px, by - py)   # hacia el vértice siguiente
        c = max(-1.0, min(1.0, u1[0] * u2[0] + u1[1] * u2[1]))
        theta = math.acos(c)           # ángulo interior
        if theta < 1e-4 or abs(theta - math.pi) < 1e-4:
            poly.append((px, py))
            continue
        t = r / math.tan(theta / 2.0)               # tangencia a lo largo de aristas
        bis = _unit(u1[0] + u2[0], u1[1] + u2[1])   # bisectriz hacia dentro
        cs = r / math.sin(theta / 2.0)               # centro del arco
        poly.append((px + u1[0] * t, py + u1[1] * t))
        poly.append((px + u2[0] * t, py + u2[1] * t))
        disks.append(((px + bis[0] * cs, py + bis[1] * cs), r))
    return poly, disks


def _offset_outward(pts, by):
    """Copia del polígono convexo con cada vértice desplazado `by` px hacia
    fuera exactamente (los nuevos bordes quedan paralelos a +by)."""
    n = len(pts)
    out = []
    for i in range(n):
        px, py = pts[i]
        ax, ay = pts[(i - 1) % n]
        bx, by2 = pts[(i + 1) % n]
        u1 = _unit(ax - px, ay - py)
        u2 = _unit(bx - px, by2 - py)
        c = max(-1.0, min(1.0, u1[0] * u2[0] + u1[1] * u2[1]))
        theta = math.acos(c)
        bis = _unit(u1[0] + u2[0], u1[1] + u2[1])
        d = by / max(math.sin(theta / 2.0), 1e-6)
        out.append((px - bis[0] * d, py - bis[1] * d))
    return out


def _fill_rounded_poly(d, pts, r, color):
    poly, disks = _rounded_poly(pts, r)
    d.polygon(poly, fill=color)
    for (cx, cy), rr in disks:
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color)


def _house_geometry(s, scale=1.0, cx=0.5, cy=0.63):
    """Geometría de la casita en un lienzo de lado `s`."""
    bw = 0.48 * s * scale
    bh = 0.34 * s * scale
    bx0, bx1 = cx * s - bw / 2, cx * s + bw / 2
    by0, by1 = cy * s - bh / 2, cy * s + bh / 2
    radius = 0.055 * s * scale
    overhang = 0.055 * s * scale
    apex = (cx * s, by0 - 0.24 * s * scale)
    bl = (bx0 - overhang, by0 + 0.045 * s * scale)
    br = (bx1 + overhang, by0 + 0.045 * s * scale)
    return {
        "body": (bx0, by0, bx1, by1),
        "radius": radius,
        "roof": [apex, bl, br],
        "corner": 0.030 * s * scale,
        "ow": max(3, int(0.013 * s * scale)),
    }


def _house_layer(s, scale=1.0, cx=0.5, cy=0.63):
    """Capa RGBA con la casita: contorno fino uniforme, esquinas redondeadas
    sin perillas y cara completa."""
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    g = _house_geometry(s, scale, cx, cy)
    bx0, by0, bx1, by1 = g["body"]
    radius, ow = g["radius"], g["ow"]
    roof, corner = g["roof"], g["corner"]

    # Contorno del cuerpo (rectángulo expandido) debajo del relleno.
    d.rounded_rectangle(
        [bx0 - ow, by0 - ow, bx1 + ow, by1 + ow],
        radius=radius + ow,
        fill=INK + (255,),
    )
    # Relleno del cuerpo.
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=radius, fill=BLANCO + (255,))

    # Techo: contorno (polígono desplazado hacia fuera) y luego relleno coral.
    _fill_rounded_poly(d, _offset_outward(roof, ow), corner + ow, INK + (255,))
    _fill_rounded_poly(d, roof, corner, CORAL + (255,))

    # Cara sobre el cuerpo.
    ex_off = 0.085 * s * scale
    ey = by0 + (by1 - by0) * 0.42
    erx, ery = 0.040 * s * scale, 0.050 * s * scale
    for sign in (-1, 1):
        ex = cx * s + sign * ex_off
        d.ellipse([ex - erx, ey - ery, ex + erx, ey + ery], fill=INK + (255,))
        hr = erx * 0.34
        hx = ex - erx * 0.35
        hy = ey - ery * 0.45
        d.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=BLANCO + (255,))

    # Sonrisa (arco con puntas redondeadas).
    bh = by1 - by0
    r_m = 0.082 * s * scale
    mcx, mcy = cx * s, by0 + bh * 0.60
    mw = max(3, int(0.020 * s * scale))
    d.arc(
        [mcx - r_m, mcy - r_m * 0.85, mcx + r_m, mcy + r_m * 0.85],
        start=18,
        end=162,
        fill=INK + (255,),
        width=mw,
    )
    for a in (18, 162):
        px = mcx + r_m * math.cos(math.radians(a))
        py = mcy + r_m * 0.85 * math.sin(math.radians(a))
        hr = mw / 2
        d.ellipse([px - hr, py - hr, px + hr, py + hr], fill=INK + (255,))

    # Mejillas rosas.
    chx = 0.150 * s * scale
    chy = by0 + bh * 0.62
    crx, cry = 0.042 * s * scale, 0.028 * s * scale
    for sign in (-1, 1):
        px = cx * s + sign * chx
        d.ellipse([px - crx, chy - cry, px + crx, chy + cry], fill=ROSA + (255,))

    return layer, g


def _add_star(img, s):
    """Estrella dorada arriba-derecha + destellos blancos."""
    d = ImageDraw.Draw(img)
    sx, sy, sr = 0.815 * s, 0.215 * s, 0.072 * s
    ow = max(2, int(0.011 * s))
    pts = _star_pts(sx, sy, sr)
    # Contorno: trazo centrado de 2*ow; el relleno tapa la mitad interna.
    d.polygon(pts, outline=INK + (255,), width=2 * ow)
    d.polygon(pts, fill=ORO + (255,))
    # Destellos blancos (estrella de 4 puntas suave).
    for cx, cy, r in ((0.16 * s, 0.30 * s, 0.030 * s),
                      (0.87 * s, 0.64 * s, 0.024 * s)):
        d.polygon(
            [(cx, cy - r), (cx + r * 0.28, cy - r * 0.28), (cx + r, cy),
             (cx + r * 0.28, cy + r * 0.28), (cx, cy + r),
             (cx - r * 0.28, cy + r * 0.28), (cx - r, cy),
             (cx - r * 0.28, cy - r * 0.28)],
            fill=BLANCO + (235,),
        )


def make_logo(size=1024, maskable=False):
    """Logo completo. `maskable=True`: a sangre (sin esquinas redondeadas
    ni borde blanco) para iconos maskable/iOS/adaptive."""
    s = size * SS

    # Fondo degradado verde.
    bg = vertical_gradient(s, VERDE_TOP, VERDE_BOT)
    if maskable:
        img = bg
    else:
        mask = Image.new("L", (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=255
        )
        img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        img.paste(bg, (0, 0), mask)

    # Destello suave arriba-izquierda (sutil, sin sombras pesadas).
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [-s // 5, -s // 5, s // 3, s // 3], fill=(255, 255, 255, 55)
    )
    glow = glow.filter(ImageFilter.GaussianBlur(s // 14))
    img = Image.alpha_composite(img, glow)

    # Sombra muy suave bajo la casa.
    _, g = _house_layer(s)
    bx0, by0, bx1, by1 = g["body"]
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        [bx0 + s * 0.02, by1 - s * 0.012, bx1 - s * 0.02, by1 + s * 0.045],
        fill=(0, 0, 0, 55),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(s // 45))
    img = Image.alpha_composite(img, shadow)

    # Casita.
    house, _ = _house_layer(s)
    img = Image.alpha_composite(img, house)

    # Estrella + destellos.
    _add_star(img, s)

    # Borde interior blanco (solo versión no-maskable).
    if not maskable:
        d = ImageDraw.Draw(img)
        m = int(s * 0.045)
        d.rounded_rectangle(
            [m, m, s - m, s - m],
            radius=int(s * 0.17),
            outline=(255, 255, 255, 235),
            width=max(6, s // 55),
        )

    return img.resize((size, size), Image.LANCZOS).convert("RGBA")


def make_content(size=1024):
    """Solo la casita + estrella sobre fondo transparente (adaptive fg)."""
    s = size * SS
    house, _ = _house_layer(s)
    img = house
    d = ImageDraw.Draw(img)
    sx, sy, sr = 0.815 * s, 0.215 * s, 0.072 * s
    pts = _star_pts(sx, sy, sr)
    d.polygon(pts, fill=ORO + (255,))
    return img.resize((size, size), Image.LANCZOS).convert("RGBA")


def save_maskable(size, path):
    img = make_logo(size, maskable=True)
    img.save(path)
    return img


if __name__ == "__main__":
    base = os.path.dirname(os.path.abspath(__file__))
    root = os.path.abspath(os.path.join(base, "..", ".."))

    logo = make_logo(1024)
    logo.save(os.path.join(base, "hq_logo_1024.png"))
    full = make_logo(1024, maskable=True)
    content = make_content(1024)

    # --- Android ---
    android_res = os.path.join(root, "android", "app", "src", "main", "res")
    sizes = {"mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
             "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192}
    for folder, s in sizes.items():
        d = os.path.join(android_res, folder)
        os.makedirs(d, exist_ok=True)
        full.resize((s, s), Image.LANCZOS).save(os.path.join(d, "ic_launcher.png"))
        # Redondo: recorte circular del icono a sangre.
        rr = full.resize((s, s), Image.LANCZOS).convert("RGBA")
        m = Image.new("L", (s, s), 0)
        ImageDraw.Draw(m).ellipse([0, 0, s - 1, s - 1], fill=255)
        out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        out.paste(rr, (0, 0), m)
        out.save(os.path.join(d, "ic_launcher_round.png"))

    # Adaptive icon (Android 8+): fg transparente + bg degradado.
    fg_sizes = {"mipmap-mdpi": 108, "mipmap-hdpi": 162, "mipmap-xhdpi": 216,
                "mipmap-xxhdpi": 324, "mipmap-xxxhdpi": 432}
    for folder, s in fg_sizes.items():
        d = os.path.join(android_res, folder)
        os.makedirs(d, exist_ok=True)
        fg = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        inner = int(s * 0.72)
        tmp = content.resize((inner, inner), Image.LANCZOS)
        off = (s - inner) // 2
        fg.paste(tmp, (off, off), tmp)
        fg.save(os.path.join(d, "ic_launcher_foreground.png"))
        bg = vertical_gradient(s, VERDE_TOP, VERDE_BOT)
        bg.save(os.path.join(d, "ic_launcher_background.png"))
    anydpi = os.path.join(android_res, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    adaptive_xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w") as f:
        f.write(adaptive_xml)
    with open(os.path.join(anydpi, "ic_launcher_round.xml"), "w") as f:
        f.write(adaptive_xml)

    # --- Web / PWA ---
    web_icons = os.path.join(root, "web", "icons")
    os.makedirs(web_icons, exist_ok=True)
    logo.resize((192, 192), Image.LANCZOS).save(os.path.join(web_icons, "Icon-192.png"))
    logo.resize((512, 512), Image.LANCZOS).save(os.path.join(web_icons, "Icon-512.png"))
    full.resize((32, 32), Image.LANCZOS).save(os.path.join(root, "web", "favicon.png"))
    save_maskable(192, os.path.join(web_icons, "Icon-maskable-192.png"))
    save_maskable(512, os.path.join(web_icons, "Icon-maskable-512.png"))

    # --- Windows .ico ---
    ico_path = os.path.join(root, "windows", "runner", "resources", "app_icon.ico")
    if os.path.isdir(os.path.dirname(ico_path)):
        logo.save(ico_path, format="ICO",
                  sizes=[(x, x) for x in (16, 24, 32, 48, 64, 128, 256)])

    # --- iOS (opaco a sangre, todos los tamaños de Contents.json) ---
    ios_dir = os.path.join(
        root, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    if os.path.isdir(ios_dir):
        names = {f for f in os.listdir(ios_dir) if f.lower().endswith(".png")}
        for name in sorted(names):
            # Nombre: Icon-App-<L>x<L>@<escala>x.png -> px = L * escala
            core = name.rsplit(".", 1)[0]
            try:
                dims, scale = core.split("@")
                px = float(dims.split("-")[-1].split("x")[0])
                factor = float(scale.replace("x", ""))
                n = int(round(px * factor))
            except (ValueError, IndexError):
                continue
            if n > 1024:
                n = 1024
            full.resize((n, n), Image.LANCZOS).save(os.path.join(ios_dir, name))

    print("OK: logo casita con carita -> 1024 + android + web + windows + ios")
