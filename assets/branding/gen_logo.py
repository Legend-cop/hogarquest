import os
from PIL import Image, ImageDraw, ImageFilter

SS = 4  # supersampling

def lerp(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))

def rounded_rect(draw, box, r, fill, outline=None, width=0):
    draw.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)

def draw_house(d, cx, cy, s, body, roof, door, window, outline):
    """Dibuja casita tipo Duolingo: cuerpo + techo + puerta + ventana."""
    w, h = s, s
    # cuerpo
    left, right = cx - w//2, cx + w//2
    top, bot = cy - h//2, cy + h//2
    rounded_rect(d, [left, top, right, bot], int(s*0.10), body)
    # techo (triángulo redondeado aproximado)
    roof_pts = [(cx, top - int(s*0.42)), (left - int(s*0.10), top + int(s*0.18)),
                (right + int(s*0.10), top + int(s*0.18))]
    d.polygon(roof_pts, fill=roof)
    # redondear esquina del techo con círculos
    d.ellipse([roof_pts[1][0]-int(s*0.06), roof_pts[1][1]-int(s*0.06),
               roof_pts[1][0]+int(s*0.06), roof_pts[1][1]+int(s*0.06)], fill=roof)
    d.ellipse([roof_pts[2][0]-int(s*0.06), roof_pts[2][1]-int(s*0.06),
               roof_pts[2][0]+int(s*0.06), roof_pts[2][1]+int(s*0.06)], fill=roof)
    # puerta
    dw = int(s*0.22); dh = int(s*0.42)
    d.rounded_rectangle([cx-dw//2, bot-dh, cx+dw//2, bot], radius=int(dw*0.4), fill=door)
    # perilla
    d.ellipse([cx+dw//2-int(dw*0.35), bot-dh//2-int(dw*0.09),
               cx+dw//2-int(dw*0.12), bot-dh//2+int(dw*0.09)], fill=outline)
    # ventana
    vw = int(s*0.34); vh = int(s*0.26)
    vx, vy = cx - vw//2, top + int(s*0.30)
    d.rounded_rectangle([vx, vy, vx+vw, vy+vh], radius=int(vw*0.15), fill=window)
    d.line([cx, vy, cx, vy+vh], fill=outline, width=max(3, int(s*0.018)))
    d.line([vx, vy+vh//2, vx+vw, vy+vh//2], fill=outline, width=max(3, int(s*0.018)))

def draw_bubble(d, x, y, r, color, highlight):
    d.ellipse([x-r, y-r, x+r, y+r], fill=color)
    # brillo
    hr = int(r*0.45)
    d.ellipse([x-int(r*0.30), y-int(r*0.35), x-int(r*0.30)+hr, y-int(r*0.35)+hr],
              fill=highlight)

def make_logo(size=1024):
    img = Image.new("RGBA", (size*SS, size*SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    S = size * SS

    # fondo: gradiente verde lima
    c_top = (109, 219, 56)    # 6DDB38
    c_bot = (65, 158, 20)     # 419E14
    for y in range(S):
        d.line([0, y, S, y], fill=lerp(c_top, c_bot, y/S))

    # burbujas de jabón
    white = (255, 255, 255, 255)
    light = (255, 255, 255, 200)
    draw_bubble(d, int(S*0.20), int(S*0.20), int(S*0.10), white, light)
    draw_bubble(d, int(S*0.80), int(S*0.16), int(S*0.075), white, light)
    draw_bubble(d, int(S*0.86), int(S*0.72), int(S*0.09), white, light)
    draw_bubble(d, int(S*0.14), int(S*0.78), int(S*0.065), white, light)

    # estrella dorada (gamificación) arriba derecha de la casa
    star_col = (255, 209, 0)
    sx, sy, sr = int(S*0.685), int(S*0.275), int(S*0.115)
    import math
    pts = []
    for i in range(10):
        ang = -math.pi/2 + i * math.pi/5
        r = sr if i % 2 == 0 else sr*0.42
        pts.append((sx + r*math.cos(ang), sy + r*math.sin(ang)))
    d.polygon(pts, fill=star_col)
    # brillo estrella
    d.ellipse([sx-sr*0.18, sy-sr*0.18, sx+sr*0.18, sy+sr*0.18], fill=(255, 230, 120))

    # casa central
    house_body = (255, 255, 255, 255)
    roof = (255, 90, 90)          # techo rojo alegre
    door = (110, 201, 255)        # puerta azul
    window = (255, 224, 90)       # ventana amarilla
    outline = (80, 80, 80, 255)
    draw_house(d, S//2, int(S*0.56), int(S*0.46), house_body, roof, door, window, outline)

    # borde interior blanco tipo Duolingo
    m = int(S*0.045)
    d.rounded_rectangle([m, m, S-m, S-m], radius=int(S*0.18), outline=(255,255,255,235), width=max(6, S//55))

    # destello radial suave en esquina superior izquierda (efecto limpio/fresco)
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-S//5, -S//5, S//3, S//3], fill=(255, 255, 255, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(S//12))
    img = Image.alpha_composite(img, glow)

    # sombra sutil bajo la casa
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.ellipse([S//2 - int(S*0.36), int(S*0.80), S//2 + int(S*0.36), int(S*0.95)], fill=(0, 0, 0, 60))
    sh = sh.filter(ImageFilter.GaussianBlur(S//30))
    img = Image.alpha_composite(img, sh)

    img = img.resize((size, size), Image.LANCZOS)
    return img.convert("RGBA")

def save_maskable(size, path):
    """Icono maskable: logo completo hasta los bordes (sin margen)."""
    img = Image.new("RGBA", (size*SS, size*SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    S = size * SS
    c_top = (109, 219, 56); c_bot = (65, 158, 20)
    for y in range(S):
        d.line([0, y, S, y], fill=lerp(c_top, c_bot, y/S))
    # casa más grande y centrada para llenar zona segura
    house_body = (255, 255, 255, 255); roof = (255, 90, 90)
    door = (110, 201, 255); window = (255, 224, 90); outline = (80, 80, 80, 255)
    draw_house(d, S//2, int(S*0.56), int(S*0.52), house_body, roof, door, window, outline)
    star_col = (255, 209, 0)
    import math
    sx, sy, sr = int(S*0.68), int(S*0.24), int(S*0.12)
    pts = []
    for i in range(10):
        ang = -math.pi/2 + i * math.pi/5
        r = sr if i % 2 == 0 else sr*0.42
        pts.append((sx + r*math.cos(ang), sy + r*math.sin(ang)))
    d.polygon(pts, fill=star_col)
    draw_bubble(d, int(S*0.14), int(S*0.18), int(S*0.09), (255,255,255,255), (255,255,255,200))
    img = img.resize((size, size), Image.LANCZOS)
    img = img.convert("RGBA")
    img.save(path)
    return img

if __name__ == "__main__":
    base = os.path.dirname(os.path.abspath(__file__))
    logo = make_logo(1024)
    logo.save(os.path.join(base, "hq_logo_1024.png"))

    # Android mipmaps
    android_res = os.path.join(base, "res")
    sizes = {"mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
             "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192}
    for folder, s in sizes.items():
        d = os.path.join(android_res, folder)
        os.makedirs(d, exist_ok=True)
        logo.resize((s, s), Image.LANCZOS).save(os.path.join(d, "ic_launcher.png"))

    # Web icons
    web_icons = os.path.join(base, "web_icons")
    os.makedirs(web_icons, exist_ok=True)
    logo.resize((192, 192), Image.LANCZOS).save(os.path.join(web_icons, "Icon-192.png"))
    logo.resize((512, 512), Image.LANCZOS).save(os.path.join(web_icons, "Icon-512.png"))
    logo.resize((32, 32), Image.LANCZOS).save(os.path.join(base, "favicon.png"))
    save_maskable(192, os.path.join(web_icons, "Icon-maskable-192.png"))
    save_maskable(512, os.path.join(web_icons, "Icon-maskable-512.png"))

    print("OK: logo 1024 + android mipmaps + web icons generados")
