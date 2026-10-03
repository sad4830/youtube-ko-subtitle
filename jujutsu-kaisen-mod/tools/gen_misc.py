"""Shrine, shutter doors, technique visuals, items, effect icons, blocks and GUI."""
import math
from PIL import Image
from texlib import Tex, rgb, shade, faces, soft, mix, radial

SIDES = ('front', 'right', 'left', 'back')


# ───────────────────────────────────────────── Malevolent Shrine (256x256) ──
def shrine(path):
    t = Tex(256, 256, seed=9)
    wood = rgb('5A1A14')
    wood_d = rgb('3A0E0B')
    lacquer = rgb('7A2018')
    roof = rgb('24242A')
    bone = rgb('E4DDCC')
    bone_s = rgb('B8AE98')
    earth = rgb('2A1A14')

    def skull_pile(rect):
        x, y, w, h = rect
        for j in range(h):
            for i in range(w):
                t.set(x + i, y + j, shade(earth, 0.9 + t.rand.random() * 0.2))
        # Rows of skulls: rounded bone blobs with dark eye sockets.
        for sy in range(0, h, 5):
            off = (sy // 5) % 2 * 3
            for sx in range(off, w, 6):
                for j in range(4):
                    for i in range(5):
                        if (i in (0, 4) and j in (0, 3)):
                            continue
                        if sx + i < w and sy + j < h:
                            c = bone if j < 2 else bone_s
                            t.set(x + sx + i, y + sy + j, shade(c, 0.95 + t.rand.random() * 0.1))
                if sy + 1 < h and sx + 3 < w:
                    t.set(x + sx + 1, y + sy + 1, rgb('1A0E0A'))
                    t.set(x + sx + 3, y + sy + 1, rgb('1A0E0A'))
                if sy + 3 < h and sx + 2 < w:
                    t.set(x + sx + 2, y + sy + 3, rgb('3A2A20'))

    for box in ((0, 0, 52, 6, 36), (0, 42, 42, 4, 28)):
        for name, rect in faces(*box).items():
            skull_pile(rect)

    def planks(rect, base, vertical=False):
        x, y, w, h = rect
        for j in range(h):
            for i in range(w):
                k = i if vertical else j
                c = shade(base, 0.92 + 0.08 * ((k // 2) % 2) + (t.rand.random() - 0.5) * 0.06)
                if (k % 4) == 3:
                    c = shade(base, 0.72)
                t.set(x + i, y + j, c)

    for box in ((176, 28, 14, 2, 6), (216, 28, 14, 2, 3), (216, 34, 14, 2, 3), (0, 74, 38, 2, 26)):
        for name, rect in faces(*box).items():
            planks(rect, wood)
    for name, rect in faces(176, 0, 3, 22, 3).items():
        x, y, w, h = rect
        for j in range(h):
            for i in range(w):
                c = lacquer if i % 3 else shade(lacquer, 0.8)
                if j in (1, h - 2):
                    c = rgb('C8A04A')
                t.set(x + i, y + j, c)

    # Hall: dark red lacquered wood, gold trim, and the huge gaping mouth on the front.
    hf = faces(0, 102, 28, 20, 18)
    for name, rect in hf.items():
        planks(rect, lacquer if name == 'front' else wood, vertical=True)
    x, y, w, h = hf['front']
    for j in range(h):
        for i in range(w):
            dx = (i - w / 2 + 0.5) / (w / 2 - 3)
            dy = (j - h * 0.55) / (h * 0.32)
            r = dx * dx + dy * dy
            if r < 1:
                c = rgb('2A0508') if r < 0.75 else rgb('5A0A10')
                t.set(x + i, y + j, c)
            elif r < 1.25:
                t.set(x + i, y + j, rgb('8A1A1E'))
    for i in range(w):
        t.set(x + i, y, rgb('C8A04A'))
        t.set(x + i, y + h - 1, rgb('C8A04A'))

    # Teeth and tongue.
    for box in ((208, 0, 20, 3, 1), (208, 6, 20, 3, 1)):
        for name, (fx, fy, fw, fh) in faces(*box).items():
            for j in range(fh):
                for i in range(fw):
                    tooth = (i % 3) != 2
                    t.set(fx + i, fy + j, shade(bone, 1.0 - j * 0.08) if tooth else rgb('3A0508'))
    for name, rect in faces(208, 12, 8, 1, 4).items():
        t.noise_rect(*rect, rgb('A01828'), 0.08)

    # Roof tiles.
    def tiles(rect):
        x, y, w, h = rect
        for j in range(h):
            for i in range(w):
                c = shade(roof, 0.9 + 0.15 * ((i // 2 + j) % 2))
                if j % 3 == 2:
                    c = shade(roof, 0.65)
                t.set(x + i, y + j, c)

    for box in ((0, 140, 46, 3, 32), (0, 175, 34, 3, 24), (140, 42, 24, 3, 4), (140, 50, 6, 2, 32)):
        for name, rect in faces(*box).items():
            tiles(rect)
    # Bull skulls and horns.
    for name, rect in faces(188, 0, 5, 5, 5).items():
        x, y, w, h = rect
        t.noise_rect(x, y, w, h, bone, 0.06)
        if name == 'front':
            t.set(x + 1, y + 1, rgb('1A0E0A'))
            t.set(x + 3, y + 1, rgb('1A0E0A'))
            t.set(x + 2, y + 3, rgb('3A2A20'))
    for name, rect in faces(188, 12, 7, 2, 2).items():
        x, y, w, h = rect
        for j in range(h):
            for i in range(w):
                t.set(x + i, y + j, mix(rgb('D8CCAA'), rgb('3A3028'), i / max(1, w - 1)))
    t.save(path)


# ───────────────────────────────────────────── Shutter doors (64x64) ──
def shutter(path):
    t = Tex(64, 64, seed=4)
    metal = rgb('A3A9AF')
    for u in (0, 28):
        for name, (x, y, w, h) in faces(u, 0, 12, 38, 2).items():
            for j in range(h):
                for i in range(w):
                    c = metal
                    if j % 3 == 0:
                        c = shade(metal, 0.72)
                    elif j % 3 == 1:
                        c = shade(metal, 1.08)
                    if name == 'front' and (i in (0, w - 1)):
                        c = shade(metal, 0.6)
                    if name == 'front' and j > h - 4:
                        c = rgb('3C3F44')
                    t.set(x + i, y + j, c)
    t.save(path)


# ───────────────────────────────────────────── technique visuals ──
def orbs(dir_):
    radial(64, falloff=2.4).save(f'{dir_}/orb_glow.png')
    radial(64, falloff=0.6, core=0.5).save(f'{dir_}/orb_core.png')
    s = Tex(64, 64)
    c = 31.5
    for y in range(64):
        for x in range(64):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy) / c
            if r >= 1:
                continue
            a = math.atan2(dy, dx)
            arms = 0.5 + 0.5 * math.cos(3 * a + r * 9.0)
            v = arms ** 3 * (1 - r) ** 1.2 + (1 - r) ** 4 * 0.6
            i = int(255 * min(1, v))
            s.set(x, y, (i, i, i, i))
    s.save(f'{dir_}/orb_swirl.png')


def crescent(path, w, h, thickness, dark=False):
    t = Tex(w, h)
    for y in range(h):
        tt = (y / (h - 1)) * 2 - 1
        center = 0.22 + 0.55 * (1 - tt * tt)
        half = thickness * (1 - tt * tt) + 0.01
        for x in range(w):
            s = x / (w - 1)
            d = abs(s - center) / half
            if d >= 1:
                continue
            v = (1 - d) ** 1.5
            if dark:
                t.set(x, y, (int(40 * v), 0, int(8 * v), int(255 * min(1, v * 1.6))))
            else:
                i = int(255 * v)
                t.set(x, y, (i, i, i, i))
    t.save(path)


def fuga(path):
    t = Tex(64, 16)
    for y in range(16):
        for x in range(64):
            s = x / 63
            dy = abs(y - 7.5) / 7.5
            width = 0.15 + 0.85 * s ** 0.7
            if s > 0.85:
                width = (1 - s) / 0.15
            if dy >= width:
                continue
            v = (1 - dy / width) * (0.25 + 0.75 * s)
            r = int(255 * min(1, v * 1.4))
            g = int(255 * min(1, v ** 1.4 * 1.1))
            b = int(255 * v ** 3 * 0.6)
            t.set(x, y, (r, g, b, int(255 * min(1, v * 1.5))))
    t.save(path)


# ───────────────────────────────────────────── items (16x16) ──
def finger(path):
    """A mummified finger lying diagonally: three segments, creased knuckles, a dark nail, a severed base."""
    t = Tex(16, 16, seed=2)
    rows = ['................',
            '............oo..',
            '...........oNno.',
            '..........oNNno.',
            '.........oFLFo..',
            '........oFLFfo..',
            '.......okkFfo...',
            '......oFLFfo....',
            '.....oFLFfo.....',
            '....okkFffo.....',
            '...oFLFffo......',
            '..oFLFffo.......',
            '.oRRrrfo........',
            '.oRrrro.........',
            '..oooo..........',
            '................']
    pal = {'o': rgb('2A120E'), 'F': rgb('6E3A2E'), 'f': rgb('55291F'), 'L': rgb('8C5242'), 'k': rgb('3A1A14'),
           'N': rgb('8A7A70'), 'n': rgb('5A4C46'), 'R': rgb('7A1A1C'), 'r': rgb('4A0E10')}
    t.charmap(0, 0, rows, pal)
    t.save(path)


def talisman(path, ink, accent, symbol):
    t = Tex(16, 16, seed=6)
    paper = rgb('EDE3C8')
    for y in range(1, 15):
        for x in range(4, 12):
            c = shade(paper, 0.95 + t.rand.random() * 0.08)
            if x in (4, 11):
                c = shade(paper, 0.82)
            t.set(x, y, c)
    for x in range(4, 12):
        t.set(x, 1, accent)
        t.set(x, 14, accent)
    t.charmap(5, 3, symbol, {'#': ink, '+': accent, 'o': shade(ink, 1.3)})
    t.save(path)


def sword_item(path):
    t = Tex(16, 16)
    silver, light, dark, gold = rgb('C4CAD0'), rgb('F4F8FC'), rgb('7E858D'), rgb('C8A04A')
    for k in range(11):
        x, y = 4 + k, 11 - k
        t.set(x, y, silver)
        t.set(x + 1, y, light if k > 0 else silver)
        t.set(x, y + 1, dark)
    t.set(15, 0, light)
    for (x, y) in ((2, 11), (3, 12), (4, 13), (5, 14), (3, 10), (6, 13)):
        t.set(x, y, gold)
    for (x, y) in ((1, 14), (2, 13), (1, 15), (0, 15)):
        t.set(x, y, rgb('E8E2D4'))
    t.save(path)


def wheel_item(path):
    t = Tex(16, 16)
    gold, light, dark = rgb('C8A04A'), rgb('EAD08A'), rgb('7A5A20')
    c = 7.5
    for y in range(16):
        for x in range(16):
            r = math.hypot(x - c, y - c)
            if 4.2 <= r <= 5.4:
                t.set(x, y, light if y < 8 else gold)
            if r <= 1.6:
                t.set(x, y, dark)
    for k in range(8):
        a = k * math.pi / 4
        for rr in range(2, 8):
            x, y = int(round(c + math.cos(a) * rr)), int(round(c + math.sin(a) * rr))
            if 0 <= x < 16 and 0 <= y < 16:
                t.set(x, y, light if rr == 7 else gold)
    t.save(path)


def prison_realm(path):
    t = Tex(16, 16)
    top, left, right = rgb('6A5F58'), rgb('4A403A'), rgb('3A322D')
    for y in range(16):
        for x in range(16):
            # simple isometric cube
            if 2 <= x <= 13 and 1 <= y <= 14:
                if y < 6 - abs(x - 7.5) * 0.5 + 1:
                    t.set(x, y, top)
                elif x < 8:
                    t.set(x, y, left)
                else:
                    t.set(x, y, right)
    eye_w, eye_p = rgb('E8E2D8'), rgb('1A0A0A')
    for (cx, cy) in ((5, 9), (10, 9), (7, 3)):
        t.set(cx, cy, eye_w)
        t.set(cx + 1, cy, eye_w)
        t.set(cx, cy, eye_p)
    t.set(6, 9, rgb('A01020'))
    t.set(11, 9, rgb('A01020'))
    t.save(path)


def ticket(path):
    t = Tex(16, 16)
    black, gold, light = rgb('1A1A1E'), rgb('C9A43A'), rgb('F0D27A')
    for y in range(3, 13):
        for x in range(1, 15):
            t.set(x, y, gold if (x in (1, 14) or y in (3, 12)) else black)
    seven = ['###', '..#', '.#.', '.#.', '.#.']
    t.charmap(4, 5, seven, {'#': light})
    t.charmap(9, 5, seven, {'#': light})
    t.save(path)


def blindfold(path):
    t = Tex(16, 16)
    for y in range(16):
        for x in range(16):
            d = ((x - 7.5) / 6.5) ** 2 + ((y - 8) / 4.5) ** 2
            if 0.62 < d < 1.0:
                t.set(x, y, rgb('2A2C33') if y < 8 else rgb('15161A'))
    t.save(path)


def pachinko(path):
    t = Tex(16, 16)
    for y in range(16):
        for x in range(16):
            r = math.hypot(x - 7.5, y - 7.5)
            if r <= 4.6:
                l = 1.0 - math.hypot(x - 6, y - 6) / 7
                v = int(110 + 140 * max(0, l))
                t.set(x, y, (v, v, min(255, v + 10), 255))
    t.set(6, 5, (255, 255, 255, 255))
    t.save(path)


def armor_blindfold(path):
    t = Tex(64, 32)
    f = faces(0, 0, 8, 8, 8)
    band, hi = rgb('16171B'), rgb('2C2E35')
    for name in SIDES:
        x, y, w, h = f[name]
        for i in range(w):
            t.set(x + i, y + 3, hi if i % 3 == 0 else band)
            t.set(x + i, y + 4, band)
    bx, by, bw, bh = f['back']
    t.set(bx + 3, by + 5, band)
    t.set(bx + 4, by + 5, band)
    t.set(bx + 4, by + 6, band)
    t.save(path)


# ───────────────────────────────────────────── effect icons (18x18) ──
def effect_icons(dir_):
    def icon(name, draw):
        t = Tex(18, 18)
        draw(t)
        t.save(f'{dir_}/{name}.png')

    def infinity(t):
        for k in range(200):
            a = k / 200 * 2 * math.pi
            x = 9 + 6.5 * math.cos(a) / (1 + math.sin(a) ** 2)
            y = 9 + 6.5 * math.sin(a) * math.cos(a) / (1 + math.sin(a) ** 2)
            t.set(int(x), int(y), rgb('9FE6FF'))
            t.set(int(x), int(y) + 1, rgb('4FB8FF'))

    def burnout(t):
        for y in range(18):
            for x in range(18):
                d = math.hypot(x - 9, (y - 10) * 1.2)
                if d < 6:
                    t.set(x, y, mix(rgb('FFB040'), rgb('8A1A10'), d / 6))
        for (x, y) in ((8, 6), (9, 7), (8, 8), (10, 9), (9, 10), (10, 11)):
            t.set(x, y, rgb('1A0A08'))

    def jackpot(t):
        seven = ['#######', '......#', '.....#.', '....#..', '...#...', '...#...', '..#....', '..#....']
        t.charmap(5, 4, seven, {'#': rgb('FFD54A')})
        t.charmap(6, 5, seven, {'#': rgb('C88A10')})

    def zone(t):
        for k in range(14):
            t.set(2 + k, 15 - k, rgb('1A0006'))
            t.set(3 + k, 15 - k, rgb('C0142C'))
        for (x, y) in ((6, 6), (12, 11), (5, 12), (13, 4)):
            t.set(x, y, rgb('FF4050'))

    def six_eyes(t):
        for y in range(18):
            for x in range(18):
                d = ((x - 9) / 7) ** 2 + ((y - 9) / 4) ** 2
                if d < 1:
                    t.set(x, y, rgb('EAF6FF'))
                if math.hypot(x - 9, y - 9) < 3:
                    t.set(x, y, rgb('5BC8F5'))
                if math.hypot(x - 9, y - 9) < 1.2:
                    t.set(x, y, rgb('0A2A40'))

    icon('information_overload', infinity)
    icon('technique_burnout', burnout)
    icon('jackpot', jackpot)
    icon('the_zone', zone)
    icon('six_eyes', six_eyes)


# ───────────────────────────────────────────── domain barriers (animated) ──
def void_barrier(path):
    frames = 8
    img = Image.new('RGBA', (16, 16 * frames))
    import random
    rnd = random.Random(7)
    stars = [(rnd.randrange(16), rnd.randrange(16), rnd.random()) for _ in range(14)]
    for f in range(frames):
        for y in range(16):
            for x in range(16):
                n = rnd.random()
                base = mix(rgb('04040C'), rgb('0E1030'), (math.sin((x + y + f) * 0.5) + 1) / 4 + n * 0.15)
                img.putpixel((x, y + 16 * f), base)
        for (sx, sy, ph) in stars:
            tw = (math.sin(f / frames * 2 * math.pi + ph * 6.28) + 1) / 2
            c = mix(rgb('3A4A80'), rgb('FFFFFF'), tw)
            img.putpixel((sx, sy + 16 * f), c)
    img.save(path)


def gamble_barrier(path):
    frames = 8
    img = Image.new('RGBA', (16, 16 * frames))
    colors = [rgb('F2C230'), rgb('FF4FA0'), rgb('46D16A'), rgb('4FB8FF')]
    for f in range(frames):
        for y in range(16):
            for x in range(16):
                c = rgb('1A0E20')
                if x in (0, 15) or y in (0, 15):
                    c = rgb('C9A43A')
                if (x + y) % 4 == 0 and 0 < x < 15 and 0 < y < 15:
                    c = colors[((x + y) // 4 + f) % 4]
                img.putpixel((x, y + 16 * f), c)
        for (cx, cy) in ((4, 4), (11, 11)):
            img.putpixel((cx, cy + 16 * f), rgb('FFFFFF') if f % 2 == 0 else rgb('F2C230'))
    img.save(path)


def void_overlay(path):
    import random
    rnd = random.Random(42)
    w = h = 256
    img = Image.new('RGBA', (w, h))
    px = img.load()
    blobs = [(rnd.uniform(0, w), rnd.uniform(0, h), rnd.uniform(30, 90), rnd.choice([(40, 80, 200), (120, 60, 200), (200, 220, 255)]))
             for _ in range(14)]
    for y in range(h):
        for x in range(w):
            r, g, b = 4, 6, 18
            for (bx, by, br, col) in blobs:
                d = math.hypot(x - bx, y - by) / br
                if d < 1:
                    k = (1 - d) ** 2 * 0.45
                    r += col[0] * k
                    g += col[1] * k
                    b += col[2] * k
            px[x, y] = (min(255, int(r)), min(255, int(g)), min(255, int(b)), 255)
    for _ in range(500):
        x, y = rnd.randrange(w), rnd.randrange(h)
        v = rnd.randrange(150, 256)
        px[x, y] = (v, v, 255, 255)
    img.save(path)
