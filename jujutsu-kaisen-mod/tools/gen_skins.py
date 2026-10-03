"""Character skins: Satoru Gojo, Kinji Hakari (64x64) and Ryomen Sukuna's Heian form (128x64)."""
from texlib import Tex, rgb, shade, faces, soft, soft_box
from PIL import Image

# Player skin layout (wide arms): (u, v, w, h, d)
HEAD = (0, 0, 8, 8, 8)
HAT = (32, 0, 8, 8, 8)
BODY = (16, 16, 8, 12, 4)
JACKET = (16, 32, 8, 12, 4)
R_ARM = (40, 16, 4, 12, 4)
R_SLEEVE = (40, 32, 4, 12, 4)
L_ARM = (32, 48, 4, 12, 4)
L_SLEEVE = (48, 48, 4, 12, 4)
R_LEG = (0, 16, 4, 12, 4)
R_PANTS = (0, 32, 4, 12, 4)
L_LEG = (16, 48, 4, 12, 4)
L_PANTS = (0, 48, 4, 12, 4)
SIDES = ('front', 'right', 'left', 'back')


def mirror_rows(rows):
    return [r[::-1] for r in rows]


def rows_band(tex, box, r0, r1, base, faces_list=SIDES, **kw):
    """Soft-shade rows [r0, r1) of the side faces of a box."""
    f = faces(*box)
    mult = {'front': 1.0, 'right': 0.9, 'left': 0.9, 'back': 0.82}
    for name in faces_list:
        x, y, w, h = f[name]
        soft(tex, (x, y + r0, w, r1 - r0), shade(base, mult[name]), **kw)


def detail(tex, box, face, rows, pal, row0=0):
    x, y, w, h = faces(*box)[face]
    tex.charmap(x, y + row0, rows, pal)


def cap(tex, box, face, color):
    x, y, w, h = faces(*box)[face]
    tex.noise_rect(x, y, w, h, color, 0.02)


def head(tex, front, right, back, pal, top, bottom):
    f = faces(*HEAD)
    tex.charmap(f['front'][0], f['front'][1], front, pal)
    tex.charmap(f['right'][0], f['right'][1], right, pal)
    tex.charmap(f['left'][0], f['left'][1], mirror_rows(right), pal)
    tex.charmap(f['back'][0], f['back'][1], back, pal)
    x, y, w, h = f['top']
    tex.rect(x, y, w, h, top)
    x, y, w, h = f['bottom']
    tex.rect(x, y, w, h, bottom)


def hat(tex, front, right, back, pal, top):
    f = faces(*HAT)
    tex.charmap(f['front'][0], f['front'][1], front, pal)
    tex.charmap(f['right'][0], f['right'][1], right, pal)
    tex.charmap(f['left'][0], f['left'][1], mirror_rows(right), pal)
    tex.charmap(f['back'][0], f['back'][1], back, pal)
    x, y, w, h = f['top']
    tex.rect(x, y, w, h, top)


def strands(pal, a, b, c):
    """Hair top: diagonal strands instead of random speckle."""
    def fn(i, j, w, h):
        k = (i + j * 2) % 5
        return pal[a] if k in (0, 1) else pal[b] if k == 2 else pal[c] if k == 4 else pal[a]
    return fn


# ─────────────────────────────────────────────────────────────── Gojo ──
def gojo(path):
    t = Tex(64, 64, seed=11)
    P = {
        'H': rgb('F2F4F8'), 'h': rgb('CBD4E2'), 'd': rgb('A9B6C9'), 'W': rgb('FFFFFF'),
        'S': rgb('F1D3C2'), 's': rgb('DDB8A6'), 'n': rgb('D9AE9C'), 'm': rgb('B88378'),
        'B': rgb('16171B'), 'b': rgb('2C2E35'),
        'z': rgb('3B4568'), 'Z': rgb('6B78A3'), 'C': rgb('2A3352'), 'k': rgb('0C0F18'),
        'O': rgb('0A0A0A'), 'o': rgb('2B2B2B'),
        '.': None,
    }
    navy = rgb('1E2539')
    head(t,
         ['HWHHHWHH',
          'HhHHhHHh',
          'SHSSSShS',
          'BBBBBBBB',
          'BbBBBBbB',
          'SSSnSSSS',
          'sSSmmSSs',
          'ssSSSSss'],
         ['HHHHWHHH',
          'HHhHHHHH',
          'HHHHHhSS',
          'BBBBBBBB',
          'BBBBBBBB',
          'HHhsSSSS',
          'HHssSSSs',
          'hHssSSss'],
         ['HHWHHHWH',
          'HHhHHhHH',
          'HHHHHHHH',
          'BBBBBBBB',
          'BBBbbBBB',
          'HHHHHHHH',
          'HhHHHHhH',
          'hdHhhHdh'],
         P, strands(P, 'H', 'h', 'W'), P['s'])
    # Spiky white hair standing up over the blindfold.
    hat(t, ['HWHH.HWH', 'H.Hh..H.', '.......h'],
        ['HWHHWHH.', 'HHhHHH..', 'HhH.Hh..', 'h..h....'],
        ['HWHHHHWH', 'HHhHHhHH', 'HhHHHHhH', 'h.HhhH.h', '.h....h.'],
        P, strands(P, 'H', 'h', 'W'))

    # Dark navy high-collar uniform with a zip.
    soft_box(t, BODY, navy, fold={1, 6})
    detail(t, BODY, 'front', ['CCCzZCCC', 'CCkzZkCC'] + ['...zZ...'] * 10, P)
    for face in ('right', 'left'):
        detail(t, BODY, face, ['CCCC'], P)
    detail(t, BODY, 'back', ['CCCCCCCC', 'kkkkkkkk'], P)
    detail(t, JACKET, 'front', ['CC....CC', 'C......C'], P)
    detail(t, JACKET, 'back', ['CCCCCCCC', 'kCCCCCCk'], P)
    detail(t, JACKET, 'right', ['CCCC', 'kCCk'], P)
    detail(t, JACKET, 'left', ['CCCC', 'kCCk'], P)

    for arm in (R_ARM, L_ARM):
        soft_box(t, arm, navy, fold={2})
        rows_band(t, arm, 9, 10, rgb('141A2A'))
        rows_band(t, arm, 10, 12, P['S'], top=1.02, bottom=0.92, edge=0.94)
        cap(t, arm, 'bottom', P['s'])
    for leg in (R_LEG, L_LEG):
        soft_box(t, leg, rgb('15161A'), fold={1})
        rows_band(t, leg, 10, 12, P['O'], top=1.0, bottom=1.0, edge=1.0)
        detail(t, leg, 'front', ['....'] * 11 + ['oooo'], P)
        cap(t, leg, 'bottom', P['o'])
    t.save(path)


# ─────────────────────────────────────────────────────────────── Hakari ─
def hakari(path):
    t = Tex(64, 64, seed=23)
    P = {
        'H': rgb('E3C04A'), 'h': rgb('A8862A'), 'L': rgb('F4DC7A'), 'D': rgb('8C6E1E'),
        'S': rgb('A8724E'), 's': rgb('8B5C3E'), 'n': rgb('94603F'), 'l': rgb('6E3F2A'),
        'b': rgb('4A3020'), 'w': rgb('F2E8E0'), 'm': rgb('C2187A'),
        'C': rgb('2A3248'), 'k': rgb('0F121B'), 'g': rgb('C9A43A'), 'G': rgb('F0D27A'),
        'T': rgb('CDBA9C'), 't': rgb('A99878'), 'u': rgb('7C6E56'),
        '.': None,
    }
    navy = rgb('1C2130')
    head(t,
         ['HLHHHHLH',
          'hSSSSSSh',
          'SbbSSbbS',
          'SwmSSmwS',
          'SSSnnSSS',
          'SSbbbbSS',
          'sSSllSSs',
          'ssSSSSss'],
         ['HHLHHHHH',
          'HHHHHHhS',
          'HHHHHhSS',
          'HHHhSSSS',
          'HHhsSlSS',
          'HhsSSsSS',
          'hssSSSSs',
          'sssSSSss'],
         ['HLHHHHLH',
          'HHHLHHHH',
          'HhHHHHhH',
          'HHHHHHHH',
          'HhHHHHhH',
          'hHHhhHHh',
          'DhhhhhhD',
          'ssSSSSss'],
         P, strands(P, 'H', 'h', 'L'), P['s'])
    # Puffy blonde hair, slicked back.
    hat(t, ['LHHLHHLH', '.h....h.'],
        ['HHLHHHL.', 'HHHHHHh.', 'HHHHHh..', 'HHHh....', 'Hhh.....', 'h.......'],
        ['HLHHLHHL', 'HHHHHHHH', 'HhHLHHhH', 'HHHHHHHH', 'hHhHHhHh', 'DhhDDhhD', '.D....D.'],
        P, strands(P, 'H', 'h', 'L'))

    # Jujutsu High uniform with the hood attached, gold spiral buttons.
    soft_box(t, BODY, navy, fold={1, 6})
    detail(t, BODY, 'front', ['CC....CC', 'C......C', '...g....', '...G....', '........', '...g....', '...G....', '........',
                              '...g....', '...G....'], P)
    detail(t, BODY, 'back', ['CCCCCCCC', 'CkCCCCkC', '.CCCCCC.', '..kkkk..'], P)
    detail(t, JACKET, 'front', ['CC....CC'], P)
    detail(t, JACKET, 'back', ['CCCCCCCC', 'CC....CC', '.CCCCCC.', '..kkkk..'], P)
    detail(t, JACKET, 'right', ['CCCC'], P)
    detail(t, JACKET, 'left', ['CCCC'], P)

    for arm in (R_ARM, L_ARM):
        soft_box(t, arm, navy, fold={2})
        detail(t, arm, 'front', ['....'] * 9 + ['kggk'], P)
        rows_band(t, arm, 10, 12, P['S'], top=1.02, bottom=0.9, edge=0.94)
        cap(t, arm, 'bottom', P['s'])
    jeans = rgb('4F6A8C')
    for leg in (R_LEG, L_LEG):
        soft_box(t, leg, jeans, fold={1}, noise=0.05)
        rows_band(t, leg, 9, 12, P['T'], top=1.05, bottom=0.82)
        detail(t, leg, 'front', ['....'] * 11 + ['uuuu'], P)
        cap(t, leg, 'bottom', P['u'])
    t.save(path)


# ─────────────────────────────────────────────────────────────── Sukuna ─
def sukuna(path):
    t = Tex(128, 64, seed=37)
    P = {
        'P': rgb('E8899A'), 'p': rgb('C2687A'), 'L': rgb('F5B0BC'),
        'S': rgb('EFD3C0'), 's': rgb('D6B19C'), 'n': rgb('D9A994'),
        'k': rgb('0D0D0D'), 'R': rgb('C0142C'), 'r': rgb('6A0614'), 'm': rgb('5A1A1A'),
        'X': rgb('B0182A'), 'W': rgb('F4EEE4'), 'Y': rgb('E8E2D4'), 'y': rgb('BDB4A4'),
        'K': rgb('141414'), 'j': rgb('060606'), 'c': rgb('2A2A2A'),
        'E': rgb('E8E4DA'), 'e': rgb('C9C3B5'), 'B': rgb('1A1A1A'),
        '.': None,
    }
    skin = P['S']
    head(t,
         ['PLPPPLPP',
          'PSSkkSSp',
          'SSSkkSSS',
          'SRrSSrRS',
          'SkkSSkkS',
          'SSSnSSSS',
          'sSkmmkSs',
          'ssSkkSss'],
         ['PPPLPPPP',
          'PPPPPPpS',
          'PPPPpSSS',
          'PPpSSSSS',
          'PpSkkkSS',
          'pSSSSSSS',
          'sSSkkkSS',
          'ssSSSSss'],
         ['PLPPPPLP', 'PPPpPPPP', 'PpPPPPpP', 'pPPPPPPp', 'SpppppSS', 'SSSSSSSS', 'sSSkkSSs', 'ssSSSSss'],
         P, strands(P, 'P', 'p', 'L'), P['s'])
    hat(t, ['P.LP.PL.', '.p...p..'], ['PLPPPP..', 'PPpP....', 'p.......'], ['PLPPLPPL', 'pPPpPPpP', '.p..p..p'], P,
        lambda i, j, w, h: P['L'] if (i + 2 * j) % 6 == 0 else (P['p'] if (3 * i + j) % 7 == 0 else None))

    # Bare tattooed torso; the mouth on the abdomen; black sash at the waist.
    soft_box(t, BODY, skin, top=1.04, bottom=0.94, edge=0.93)
    detail(t, BODY, 'front', ['........',
                              '.k....k.',
                              '..k..k..',
                              '........',
                              '........',
                              '.k....k.',
                              '..k..k..',
                              '.XWWWWX.',
                              '..XXXX..',
                              '........',
                              'BBBBBBBB',
                              'BcBBBBcB'], P)
    detail(t, BODY, 'back', ['........', '........', '.k....k.', '..kkkk..'] + ['........'] * 6 + ['BBBBBBBB', 'BBBBBBBB'], P)
    for face in ('right', 'left'):
        detail(t, BODY, face, ['....', '....', '.k..', '....', '....', '..k.', '....', '....', '....', '....', 'BBBB', 'BBBB'], P)
    # Black haori draped over the shoulders, open at the front.
    haori = rgb('151515')
    jf = faces(*JACKET)
    soft(t, (jf['front'][0], jf['front'][1], 2, 10), haori, edge=1.0)
    soft(t, (jf['front'][0] + 6, jf['front'][1], 2, 10), haori, edge=1.0)
    for name in ('right', 'left', 'back'):
        x, y, w, h = jf[name]
        soft(t, (x, y, w, 11), shade(haori, 0.9 if name != 'back' else 0.85), fold={1, 6} if name == 'back' else {2})
    detail(t, JACKET, 'back', ['........', '........', '........', '...cc...', '..c..c..', '...cc...'], P)
    x, y, w, h = jf['top']
    t.rect(x, y, w, h, P['K'])

    # Arms: double tattoo bands on the upper arm and wrist, a black dot on each shoulder.
    arm_detail = ['....', '....', 'kkkk', '....', 'kkkk', '....', '....', '....', 'kkkk', '....', '....', 'k.k.']
    for arm in (R_ARM, L_ARM):
        soft_box(t, arm, skin, top=1.04, bottom=0.92, edge=0.93)
        for face in SIDES:
            detail(t, arm, face, arm_detail if face == 'front' else arm_detail[:11], P)
        x, y, w, h = faces(*arm)['top']
        t.rect(x, y, w, h, lambda i, j, w, h: P['k'] if 1 <= i <= 2 and 1 <= j <= 2 else P['S'])
    for sleeve in (R_SLEEVE, L_SLEEVE):
        sf = faces(*sleeve)
        for face in SIDES:
            x, y, w, h = sf[face]
            soft(t, (x, y, w, 5), shade(haori, 0.95), edge=1.0, bottom=0.8)
        x, y, w, h = sf['top']
        t.rect(x, y, w, h, P['K'])

    # Light hakama and black sandals.
    hakama = P['E']
    for leg in (R_LEG, L_LEG):
        soft_box(t, leg, hakama, fold={1}, top=1.04, bottom=0.86)
        rows_band(t, leg, 10, 11, skin, top=1, bottom=1, edge=0.95)
        detail(t, leg, 'front', ['....'] * 10 + ['.k.k', 'kkkk'], P)
        for face in ('right', 'left', 'back'):
            detail(t, leg, face, ['....'] * 11 + ['kkkk'], P)
        cap(t, leg, 'bottom', P['k'])
    for pants in (R_PANTS, L_PANTS):
        pf = faces(*pants)
        for face in SIDES:
            x, y, w, h = pf[face]
            soft(t, (x, y, w, 9), shade(hakama, 0.97), fold={2}, bottom=0.82)

    # The second pair of arms (4x11x4 at 64,0 and 80,0).
    low_detail = ['....', 'kkkk', '....', '....', '....', '....', 'kkkk', '....', 'kkkk', '....', 'k.k.']
    for box in ((64, 0, 4, 11, 4), (80, 0, 4, 11, 4)):
        soft_box(t, box, skin, top=1.02, bottom=0.9, edge=0.93)
        for face in SIDES:
            detail(t, box, face, low_detail, P)

    # The bony mask of the second face, with two more eyes.
    mf = faces(64, 16, 3, 4, 1)
    t.charmap(mf['front'][0], mf['front'][1], ['YYy', 'RrY', 'YRr', 'yYy'], P)
    for face in ('top', 'bottom', 'right', 'left', 'back'):
        x, y, w, h = mf[face]
        t.rect(x, y, w, h, P['y'])
    t.save(path)


def preview(skin_path, out_path, scale=8):
    """Front view of a skin (head, body, arms, legs + overlays) for eyeballing the result."""
    src = Image.open(skin_path).convert('RGBA')
    canvas = Image.new('RGBA', (16, 32), (60, 60, 70, 255))

    def blit(rect, dx, dy):
        x, y, w, h = rect
        canvas.alpha_composite(src.crop((x, y, x + w, y + h)), (dx, dy))

    blit(faces(*HEAD)['front'], 4, 0)
    blit(faces(*HAT)['front'], 4, 0)
    blit(faces(*BODY)['front'], 4, 8)
    blit(faces(*JACKET)['front'], 4, 8)
    blit(faces(*R_ARM)['front'], 0, 8)
    blit(faces(*R_SLEEVE)['front'], 0, 8)
    blit(faces(*L_ARM)['front'], 12, 8)
    blit(faces(*L_SLEEVE)['front'], 12, 8)
    blit(faces(*R_LEG)['front'], 4, 20)
    blit(faces(*R_PANTS)['front'], 4, 20)
    blit(faces(*L_LEG)['front'], 8, 20)
    blit(faces(*L_PANTS)['front'], 8, 20)
    canvas.resize((16 * scale, 32 * scale), Image.NEAREST).save(out_path)
