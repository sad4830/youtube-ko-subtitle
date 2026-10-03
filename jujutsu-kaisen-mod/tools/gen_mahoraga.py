"""Mahoraga (256x128) + its emissive glow map. UV layout must match MahoragaModel.java."""
from texlib import Tex, rgb, shade, faces, soft, mix

SKIN = rgb('E6E2DA')
SKIN_S = rgb('C9C4BA')
SKIN_D = rgb('A9A49B')
SKIN_L = rgb('F6F3EC')
HAKAMA = rgb('151515')
SASH = rgb('F2F0EA')
BANDAGE = rgb('EDE7D8')
WING = rgb('EEEBE4')
GOLD = rgb('C8A04A')
GOLD_S = rgb('8A6A28')
GOLD_L = rgb('EAD08A')
SILVER = rgb('BFC4CA')
SILVER_L = rgb('EEF3F8')
SILVER_D = rgb('8D949C')
MOUTH = rgb('2A0F12')
TEETH = rgb('F4F1E8')

SIDES = ('front', 'right', 'left', 'back')


def skin_box(t, box, top=1.06, bottom=0.88):
    f = faces(*box)
    mult = {'front': 1.0, 'right': 0.9, 'left': 0.9, 'back': 0.84}
    for name in SIDES:
        soft(t, f[name], shade(SKIN, mult[name]), top=top, bottom=bottom, edge=0.9, noise=0.025)
    t.noise_rect(*f['top'], SKIN_L, 0.02)
    t.noise_rect(*f['bottom'], SKIN_S, 0.02)
    return f


def line_h(t, x, y, w, c):
    for i in range(w):
        t.set(x + i, y, c)


def line_v(t, x, y, h, c):
    for j in range(h):
        t.set(x, y + j, c)


def torso(t):
    f = skin_box(t, (0, 0, 18, 22, 10))
    x, y, w, h = f['front']  # 18 x 22
    # Pectorals.
    for i in range(w):
        for j in range(8):
            if j == 7 or (j == 6 and 2 < i < 15):
                t.set(x + i, y + j, shade(SKIN_S, 0.95))
    line_v(t, x + 8, y + 1, 7, SKIN_S)
    line_v(t, x + 9, y + 1, 7, shade(SKIN_S, 1.05))
    # Abdominal muscles: 3 rows x 2 columns plus the obliques.
    for row in range(4):
        yy = y + 9 + row * 3
        line_h(t, x + 5, yy, 8, SKIN_S)
    line_v(t, x + 8, y + 9, 12, SKIN_D)
    line_v(t, x + 9, y + 9, 12, SKIN_S)
    for j in range(9, 22):
        t.set(x + 4, y + j, SKIN_S)
        t.set(x + 13, y + j, SKIN_S)
    t.set(x + 8, y + 19, SKIN_D)  # navel
    # Gill-like slits under the armpits.
    for name in ('right', 'left'):
        sx, sy, sw, sh = f[name]
        for k in range(3):
            line_h(t, sx + 3, sy + 3 + k * 2, 4, SKIN_D)
    # Back muscles and spine.
    bx, by, bw, bh = f['back']
    line_v(t, bx + 9, by + 2, 18, SKIN_D)
    for j in range(3, 9):
        t.set(bx + 4 + (j - 3) // 2, by + j, SKIN_S)
        t.set(bx + 13 - (j - 3) // 2, by + j, SKIN_S)


def pecs(t):
    f = faces(56, 0, 17, 7, 1)
    x, y, w, h = f['front']
    for j in range(h):
        for i in range(w):
            g = 1.08 - 0.25 * (j / (h - 1)) ** 2
            t.set(x + i, y + j, shade(SKIN, g))
    line_v(t, x + 8, y, h, SKIN_S)
    line_h(t, x, y + h - 1, w, SKIN_D)
    for name in ('top', 'bottom', 'right', 'left', 'back'):
        t.noise_rect(*f[name], SKIN_S, 0.02)


def hakama(t):
    f = faces(0, 32, 19, 9, 11)
    for name in SIDES:
        soft(t, f[name], HAKAMA, top=1.25, bottom=0.9, edge=0.85, noise=0.04, fold={2, 6, 10, 14})
    t.noise_rect(*f['top'], HAKAMA, 0.03)
    t.noise_rect(*f['bottom'], shade(HAKAMA, 0.7), 0.02)
    # Sash (inflated box at 60,32).
    s = faces(60, 32, 19, 3, 11)
    for name in SIDES:
        soft(t, s[name], SASH, top=1.0, bottom=0.86, edge=0.92, noise=0.02)
    x, y, w, h = s['front']
    for j in range(h):  # the knot
        for i in range(8, 11):
            t.set(x + i, y + j, shade(SASH, 0.86 if (i + j) % 2 else 0.95))
    t.noise_rect(*s['top'], SASH, 0.02)
    t.noise_rect(*s['bottom'], shade(SASH, 0.8), 0.02)


def head(t):
    f = skin_box(t, (120, 0, 10, 10, 10), top=1.05, bottom=0.92)
    x, y, w, h = f['front']  # 10 x 10 — no eyes; wing roots, lipless mouth with teeth.
    line_h(t, x + 1, y + 2, 8, SKIN_S)  # brow ridge
    for i in (1, 2, 7, 8):
        t.set(x + i, y + 3, SKIN_D)
        t.set(x + i, y + 4, SKIN_S)
    line_v(t, x + 4, y + 4, 2, SKIN_S)  # nose bridge
    line_v(t, x + 5, y + 4, 2, SKIN_S)
    for i in range(2, 8):
        t.set(x + i, y + 6, MOUTH)
        t.set(x + i, y + 7, TEETH if i % 2 == 0 else shade(TEETH, 0.85))
        t.set(x + i, y + 8, MOUTH)
    for i in range(1, 9):
        t.set(x + i, y + 9, SKIN_S)
    # Jaw plate with teeth (160,0: 7x3x1).
    jf = faces(160, 0, 7, 3, 1)
    jx, jy, jw, jh = jf['front']
    for i in range(jw):
        t.set(jx + i, jy, MOUTH)
        t.set(jx + i, jy + 1, TEETH if i % 2 == 0 else shade(TEETH, 0.8))
        t.set(jx + i, jy + 2, SKIN_S)
    for name in ('top', 'bottom', 'right', 'left', 'back'):
        t.noise_rect(*jf[name], SKIN_S, 0.02)
    # Wings: feather-like, off-white with darker vanes.
    for (u, v, w, h) in ((180, 0, 9, 3), (180, 6, 8, 2)):
        wf = faces(u, v, w, h, 1)
        for name, (fx, fy, fw, fh) in wf.items():
            for j in range(fh):
                for i in range(fw):
                    c = WING
                    if (i % 3 == 2) and name in ('front', 'back'):
                        c = shade(WING, 0.82)
                    if j == fh - 1 and name in ('front', 'back'):
                        c = shade(WING, 0.88)
                    t.set(fx + i, fy + j, c)
    # Serpent-like tail from the back of the head.
    tf = faces(200, 0, 3, 10, 3)
    for name, (fx, fy, fw, fh) in tf.items():
        for j in range(fh):
            for i in range(fw):
                c = shade(SKIN, 0.95) if j % 3 else SKIN_S
                t.set(fx + i, fy + j, c)


def arm(t, u, v):
    f = skin_box(t, (u, v, 7, 24, 7))
    for name in SIDES:
        x, y, w, h = f[name]
        line_h(t, x, y + 6, w, shade(SKIN_S, 1.02))  # deltoid edge
        for j in range(20, 24):  # fist
            for i in range(w):
                t.set(x + i, y + j, shade(SKIN, 0.95 - (j - 20) * 0.03))
        if name == 'front':
            line_h(t, x + 1, y + 21, w - 2, SKIN_D)  # knuckles
            line_v(t, x + 3, y + 8, 7, SKIN_S)  # biceps split


def bandage(t, u, v):
    f = faces(u, v, 7, 10, 7)
    for name, (x, y, w, h) in f.items():
        for j in range(h):
            for i in range(w):
                c = BANDAGE
                if (i + j * 2) % 6 == 0:
                    c = shade(BANDAGE, 0.86)
                elif (i + j * 2) % 6 == 1:
                    c = shade(BANDAGE, 0.94)
                t.set(x + i, y + j, c)


def sword(t):
    f = faces(112, 52, 1, 22, 3)
    for name, (x, y, w, h) in f.items():
        for j in range(h):
            for i in range(w):
                c = SILVER
                if name in ('right', 'left'):
                    c = mix(SILVER_L, SILVER, i / max(1, w - 1))
                    if j > h - 4:
                        c = mix(c, SILVER_L, 0.5)
                elif name == 'front':
                    c = SILVER_L
                elif name == 'back':
                    c = SILVER_D
                t.set(x + i, y + j, c)
    g = faces(120, 52, 3, 2, 5)
    for name, (x, y, w, h) in g.items():
        t.rect(x, y, w, h, lambda i, j, w, h: GOLD_L if j == 0 else GOLD)


def legs(t, u, v):
    f = faces(u, v, 7, 17, 7)
    mult = {'front': 1.0, 'right': 0.9, 'left': 0.9, 'back': 0.84}
    for name in SIDES:
        x, y, w, h = f[name]
        soft(t, (x, y, w, 14), shade(HAKAMA, mult[name]), top=1.2, bottom=0.95, edge=0.85, noise=0.04, fold={2, 5})
        soft(t, (x, y + 14, w, 3), shade(SKIN, mult[name]), top=1.0, bottom=0.85, edge=0.9)
    t.noise_rect(*f['top'], HAKAMA, 0.03)
    t.noise_rect(*f['bottom'], SKIN_S, 0.02)


def neck(t):
    skin_box(t, (56, 84, 7, 3, 7))


def wheel(t):
    def gold(x, y, w, h):
        for j in range(h):
            for i in range(w):
                c = GOLD
                if j == 0:
                    c = GOLD_L
                elif j == h - 1:
                    c = GOLD_S
                elif (i + j) % 5 == 0:
                    c = shade(GOLD, 1.08)
                t.set(x + i, y + j, c)
    gold(140, 52, 18, 3)    # rim segments
    gold(160, 52, 4, 13)    # spokes
    gold(166, 52, 8, 5)     # knobs
    gold(176, 52, 12, 6)    # hub
    t.rect(181, 54, 2, 2, GOLD_S)


def glow(path):
    g = Tex(256, 128, seed=3)
    # Positive energy along the Sword of Extermination.
    for (x, y, w, h) in faces(112, 52, 1, 22, 3).values():
        for j in range(h):
            for i in range(w):
                v = 150 + int(80 * (j / max(1, h - 1)))
                g.set(x + i, y + j, (v, v, int(v * 0.92), 255))
    # A faint gleam on the wheel.
    for (x, y, w, h) in ((140, 52, 18, 3), (166, 52, 8, 5), (176, 52, 12, 6)):
        for j in range(h):
            for i in range(w):
                g.set(x + i, y + j, (70, 52, 18, 255))
    g.save(path)


def mahoraga(path, glow_path):
    t = Tex(256, 128, seed=5)
    torso(t)
    pecs(t)
    hakama(t)
    head(t)
    arm(t, 0, 52)
    arm(t, 28, 52)
    bandage(t, 56, 52)
    bandage(t, 84, 52)
    sword(t)
    legs(t, 0, 84)
    legs(t, 28, 84)
    neck(t)
    wheel(t)
    t.save(path)
    glow(glow_path)
