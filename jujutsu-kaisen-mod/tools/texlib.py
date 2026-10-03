"""Tiny pixel-art helpers used by gen_textures.py (Pillow)."""
import math
import random
from PIL import Image


def rgb(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(4))


def shade(c, f):
    """f < 1 darkens, f > 1 lightens (towards white)."""
    if f <= 1:
        return (int(c[0] * f), int(c[1] * f), int(c[2] * f), c[3])
    t = f - 1
    return mix(c, (255, 255, 255, c[3]), t)


class Tex:
    def __init__(self, w, h, seed=1):
        self.w, self.h = w, h
        self.img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        self.px = self.img.load()
        self.rand = random.Random(seed)

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.px[x, y] = c

    def get(self, x, y):
        return self.px[x, y]

    def rect(self, x, y, w, h, c):
        for j in range(h):
            for i in range(w):
                self.set(x + i, y + j, c(i, j, w, h) if callable(c) else c)

    def noise_rect(self, x, y, w, h, base, amt=0.06, grad=0.0):
        """Fill with slight noise and an optional vertical light gradient (top lighter)."""
        for j in range(h):
            g = 1.0 + grad * (0.5 - j / max(1, h - 1))
            for i in range(w):
                n = 1.0 + (self.rand.random() * 2 - 1) * amt
                self.set(x + i, y + j, shade(base, g * n))

    def charmap(self, x, y, rows, palette):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in palette and palette[ch] is not None:
                    self.set(x + i, y + j, palette[ch])

    def save(self, path):
        self.img.save(path)


def faces(u, v, w, h, d):
    """UV rectangles (x, y, w, h) of a model box at texOffs(u, v) with size (w, h, d)."""
    return {
        'top': (u + d, v, w, d),
        'bottom': (u + d + w, v, w, d),
        'right': (u, v + d, d, h),
        'front': (u + d, v + d, w, h),
        'left': (u + d + w, v + d, d, h),
        'back': (u + 2 * d + w, v + d, w, h),
    }


def paint_box(tex, u, v, w, h, d, base, amt=0.05, grad=0.25, side_dark=0.88, back_dark=0.8, top_light=1.08, bottom_dark=0.7):
    f = faces(u, v, w, h, d)
    for name, (x, y, fw, fh) in f.items():
        mult = {'top': top_light, 'bottom': bottom_dark, 'right': side_dark, 'left': side_dark, 'back': back_dark}.get(name, 1.0)
        tex.noise_rect(x, y, fw, fh, shade(base, mult), amt, grad if name not in ('top', 'bottom') else 0)
    return f


def outline_edges(tex, rect, c, sides='lrtb'):
    x, y, w, h = rect
    for i in range(w):
        if 't' in sides:
            tex.set(x + i, y, c)
        if 'b' in sides:
            tex.set(x + i, y + h - 1, c)
    for j in range(h):
        if 'l' in sides:
            tex.set(x, y + j, c)
        if 'r' in sides:
            tex.set(x + w - 1, y + j, c)


def radial(size, falloff=2.0, core=0.0):
    tex = Tex(size, size)
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - c, y - c) / c
            if r >= 1:
                continue
            v = (1 - r) ** falloff
            if core and r < core:
                v = 1.0
            i = int(255 * min(1, v))
            tex.set(x, y, (i, i, i, i))
    return tex


def soft(tex, rect, base, top=1.07, bottom=0.88, edge=0.9, noise=0.02, fold=None):
    """Smooth cloth/skin shading: light from above, darker edges, faint noise, optional fold columns."""
    x, y, w, h = rect
    for j in range(h):
        f_row = top + (bottom - top) * (j / max(1, h - 1))
        for i in range(w):
            f = f_row
            if w > 2 and (i == 0 or i == w - 1):
                f *= edge
            if fold and i in fold:
                f *= 0.9
            f *= 1 + (tex.rand.random() * 2 - 1) * noise
            tex.set(x + i, y + j, shade(base, f))


def soft_box(tex, box, base, faces_list=('front', 'right', 'left', 'back'), **kw):
    f = faces(*box)
    mult = {'front': 1.0, 'right': 0.9, 'left': 0.9, 'back': 0.82}
    for name in faces_list:
        soft(tex, f[name], shade(base, mult.get(name, 1.0)), **kw)
    for name, m in (('top', 1.08), ('bottom', 0.72)):
        x, y, w, h = f[name]
        tex.noise_rect(x, y, w, h, shade(base, m), 0.02)
    return f
