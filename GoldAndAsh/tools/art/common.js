/* GOLD & ASH (금빛과 재) — shared procedural SVG helpers for the key art.
 * Everything here is drawn from code: no bitmaps, no external artwork.
 * Used by icon.html and thumbnail.html; rendered by render_art.py.
 */
(function () {
  const GA = {};
  const f = (v) => (Math.round(v * 10) / 10).toString();

  GA.C = {
    gold: '#FFC44A', goldLight: '#FFE8A0', goldDeep: '#E08A1E', amber: '#B8560E',
    brown: '#6B3410', brownDark: '#3A1A08',
    ink: '#16141A', inkDeep: '#0B0A0E', crimson: '#D62C34', crimsonHot: '#FF5A4E',
    ash: '#8C8790', ashLight: '#C9C4CC',
  };

  /* seeded PRNG so every render is identical */
  GA.rng = (seed) => {
    let a = seed >>> 0;
    const r = () => {
      a = (a + 0x6d2b79f5) >>> 0;
      let t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
    r.range = (lo, hi) => lo + (hi - lo) * r();
    r.pick = (arr) => arr[Math.floor(r() * arr.length)];
    return r;
  };

  /* Catmull-Rom spline through control points -> dense polyline */
  GA.spline = (pts, n = 14) => {
    if (pts.length === 2) {
      const out = [];
      for (let j = 0; j <= n; j++) {
        const t = j / n;
        out.push([pts[0][0] + (pts[1][0] - pts[0][0]) * t, pts[0][1] + (pts[1][1] - pts[0][1]) * t]);
      }
      return out;
    }
    const out = [];
    for (let i = 0; i < pts.length - 1; i++) {
      const p0 = pts[Math.max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(i + 2, pts.length - 1)];
      for (let j = 0; j < n; j++) {
        const t = j / n, t2 = t * t, t3 = t2 * t;
        const c = (k) => 0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2 + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3);
        out.push([c(0), c(1)]);
      }
    }
    out.push(pts[pts.length - 1].slice());
    return out;
  };

  /* resample a polyline -> [{x,y,tx,ty,nx,ny,t,len}] */
  GA.frames = (poly) => {
    const L = [0];
    for (let i = 1; i < poly.length; i++) L.push(L[i - 1] + Math.hypot(poly[i][0] - poly[i - 1][0], poly[i][1] - poly[i - 1][1]));
    const total = L[L.length - 1] || 1;
    return poly.map((p, i) => {
      const a = poly[Math.max(i - 1, 0)], b = poly[Math.min(i + 1, poly.length - 1)];
      let tx = b[0] - a[0], ty = b[1] - a[1];
      const m = Math.hypot(tx, ty) || 1;
      tx /= m; ty /= m;
      return { x: p[0], y: p[1], tx, ty, nx: -ty, ny: tx, t: L[i] / total, len: L[i], total };
    });
  };

  GA.poly = (pts, close = true) => 'M' + pts.map((p) => f(p[0]) + ' ' + f(p[1])).join('L') + (close ? 'Z' : '');

  /* width profiles, t in [0,1] */
  GA.prof = {
    lin: (w0, w1) => (t) => w0 + (w1 - w0) * t,
    horn: (w, p = 0.85) => (t) => w * Math.pow(1 - t, p),
    spike: (w, a = 0.12) => (t) => w * Math.min(1, t / a) * Math.pow(1 - t, 0.9),
    lens: (w, peak = 0.45, pa = 0.55, pb = 0.9) => (t) => w * (t < peak ? Math.pow(t / peak, pa) : Math.pow((1 - t) / (1 - peak), pb)),
    body: (w0, w1) => (t) => (w0 + (w1 - w0) * Math.pow(t, 0.8)) * Math.min(1, 0.55 + t * 8),
  };

  /* filled ribbon along a spline with a width profile */
  GA.ribbon = (ctrl, width, n = 14, side = 0) => {
    const fr = GA.frames(GA.spline(ctrl, n));
    const wf = typeof width === 'function' ? width : GA.prof.lin(width[0], width[1]);
    const left = [], right = [];
    for (const q of fr) {
      const w = Math.max(0, wf(q.t));
      const a = side === 0 ? w / 2 : side > 0 ? w : 0;
      const b = side === 0 ? w / 2 : side < 0 ? w : 0;
      left.push([q.x + q.nx * a, q.y + q.ny * a]);
      right.push([q.x - q.nx * b, q.y - q.ny * b]);
    }
    return GA.poly(left.concat(right.reverse()));
  };

  /* straight (slightly bowed) slash sliver from A to B */
  GA.sliver = (ax, ay, bx, by, w, opt = {}) => {
    const peak = opt.peak ?? 0.45, bow = opt.bow ?? 0, n = opt.n ?? 60;
    const dx = bx - ax, dy = by - ay, m = Math.hypot(dx, dy), nx = -dy / m, ny = dx / m;
    const wf = GA.prof.lens(w, peak, opt.pa ?? 0.5, opt.pb ?? 0.85);
    const top = [], bot = [];
    for (let i = 0; i <= n; i++) {
      const t = i / n, cx = ax + dx * t + nx * bow * Math.sin(Math.PI * t), cy = ay + dy * t + ny * bow * Math.sin(Math.PI * t);
      const h = wf(t) / 2;
      const skew = opt.skew ?? 0.5; // share of width on the + side
      top.push([cx + nx * h * 2 * skew, cy + ny * h * 2 * skew]);
      bot.push([cx - nx * h * 2 * (1 - skew), cy - ny * h * 2 * (1 - skew)]);
    }
    return GA.poly(top.concat(bot.reverse()));
  };

  /* radial rays (starburst / speed lines). returns path d of thin triangles */
  GA.rays = (cx, cy, count, r0, r1, w, rng, opt = {}) => {
    let d = '';
    const a0 = opt.a0 ?? 0, a1 = opt.a1 ?? Math.PI * 2;
    for (let i = 0; i < count; i++) {
      const a = a0 + (a1 - a0) * (opt.even ? (i + rng() * 0.6) / count : rng());
      const ra = r0 * rng.range(0.8, 1.2), rb = r1 * rng.range(opt.minLen ?? 0.45, 1);
      const ww = w * rng.range(0.4, 1);
      const ca = Math.cos(a), sa = Math.sin(a), px = -sa, py = ca;
      if (opt.inward) {
        // wide at the outside, point toward center (manga speed lines)
        d += `M${f(cx + ca * ra)} ${f(cy + sa * ra)}L${f(cx + ca * rb + px * ww)} ${f(cy + sa * rb + py * ww)}L${f(cx + ca * rb - px * ww)} ${f(cy + sa * rb - py * ww)}Z`;
      } else {
        d += `M${f(cx + ca * ra + px * ww)} ${f(cy + sa * ra + py * ww)}L${f(cx + ca * rb)} ${f(cy + sa * rb)}L${f(cx + ca * ra - px * ww)} ${f(cy + sa * ra - py * ww)}Z`;
      }
    }
    return d;
  };

  /* irregular ash flake (3-5 sided shard) */
  GA.flake = (x, y, s, rot, rng) => {
    const k = 3 + Math.floor(rng() * 3), pts = [];
    for (let i = 0; i < k; i++) {
      const a = rot + (i / k) * Math.PI * 2 + rng.range(-0.35, 0.35);
      const r = s * rng.range(0.45, 1) * (i % 2 ? 0.55 : 1);
      pts.push([x + Math.cos(a) * r, y + Math.sin(a) * r * 0.6]);
    }
    return GA.poly(pts);
  };

  /* thin streak (spark) along direction */
  GA.streak = (x, y, ang, len, w) => {
    const c = Math.cos(ang), s = Math.sin(ang), px = -s * w / 2, py = c * w / 2;
    return `M${f(x - c * len / 2)} ${f(y - s * len / 2)}L${f(x + px)} ${f(y + py)}L${f(x + c * len / 2)} ${f(y + s * len / 2)}L${f(x - px)} ${f(y - py)}Z`;
  };

  /* transform that maps local point (px,py) to global (qx,qy) with rotate/scale */
  GA.place = (px, py, qx, qy, s, deg, flip = false) =>
    `translate(${f(qx)} ${f(qy)}) rotate(${deg}) scale(${flip ? -s : s} ${s}) translate(${-px} ${-py})`;

  /* where a local point lands under GA.place(lx,ly,qx,qy,s,deg) */
  GA.map = (lx, ly, qx, qy, sc, deg, px, py) => {
    const r = (deg * Math.PI) / 180, dx = (px - lx) * sc, dy = (py - ly) * sc;
    return [qx + dx * Math.cos(r) - dy * Math.sin(r), qy + dx * Math.sin(r) + dy * Math.cos(r)];
  };

  GA.el = (tag, attrs, inner = '') =>
    `<${tag} ${Object.entries(attrs).map(([k, v]) => `${k}="${v}"`).join(' ')}>${inner}</${tag}>`;

  /* ------------------------------------------------------------------ *
   * Golden dragon head (Chinese long), profile facing +x, made of light.
   * Local frame roughly x -90..370, y -80..260. Mouth centre ~ (300,150).
   * ids: suffix for gradient ids so several dragons can coexist.
   * ------------------------------------------------------------------ */
  GA.dragonHead = (id, opt = {}) => {
    const R = GA.rng(opt.seed ?? 7);
    const line = opt.line ?? GA.C.brown;
    let s = '';
    s += `<defs>
      <linearGradient id="dhSkull${id}" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#FFF6D2"/><stop offset=".35" stop-color="${GA.C.goldLight}"/>
        <stop offset=".75" stop-color="${GA.C.gold}"/><stop offset="1" stop-color="${GA.C.goldDeep}"/></linearGradient>
      <linearGradient id="dhJaw${id}" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${GA.C.gold}"/><stop offset="1" stop-color="${GA.C.amber}"/></linearGradient>
      <linearGradient id="dhMane${id}" x1="1" y1="0" x2="0" y2="0">
        <stop offset="0" stop-color="${GA.C.goldDeep}"/><stop offset=".6" stop-color="${GA.C.gold}"/><stop offset="1" stop-color="${GA.C.goldLight}" stop-opacity=".2"/></linearGradient>
      <linearGradient id="dhHorn${id}" x1="1" y1="1" x2="0" y2="0">
        <stop offset="0" stop-color="${GA.C.goldLight}"/><stop offset="1" stop-color="#FFF8E6"/></linearGradient>
      <radialGradient id="dhMouth${id}" cx=".85" cy=".5" r=".8">
        <stop offset="0" stop-color="#FFFFFF"/><stop offset=".4" stop-color="#FFF1B8"/><stop offset="1" stop-color="#FF9A2A"/></radialGradient>
    </defs>`;

    // mane: flame spikes flowing back from skull, cheek and jaw
    const maneBases = [[150, 26, -150, 1.1], [128, 34, -160, 1.25], [104, 50, -168, 1.35], [86, 72, -176, 1.35], [72, 98, 176, 1.3], [66, 124, 168, 1.2], [80, 146, 158, 1.1], [104, 160, 148, 1.0], [132, 170, 138, 0.9], [160, 182, 128, 0.8]];
    let mane = '', maneBack = '';
    maneBases.forEach(([x, y, deg, k], i) => {
      const a = (deg * Math.PI) / 180, L = 120 * k * R.range(0.85, 1.1);
      const c = Math.cos(a), sn = Math.sin(a), curl = (i % 2 ? 1 : -1) * 18;
      const pts = [[x, y], [x + c * L * 0.35 - sn * curl * 0.3, y + sn * L * 0.35 + c * curl * 0.3], [x + c * L * 0.7 + sn * curl, y + sn * L * 0.7 - c * curl - 10], [x + c * L, y + sn * L - 26 + curl * 0.4]];
      const d = GA.ribbon(pts, GA.prof.horn(46 * k, 1.1), 10);
      if (i % 2) maneBack += `<path d="${d}"/>`; else mane += `<path d="${d}"/>`;
    });
    s += `<g fill="${GA.C.goldDeep}" opacity=".95">${maneBack}</g>`;
    s += `<g fill="url(#dhMane${id})">${mane}</g>`;

    // antlers
    const hornA = [[164, 30], [128, -2], [82, -28], [26, -44], [-34, -40], [-70, -24]];
    const tineA = [[74, -30], [60, -62], [64, -92]];
    const tineA2 = [[16, -44], [-4, -70], [-2, -98]];
    const hornB = [[140, 42], [100, 22], [52, 10], [-4, 10], [-46, 24]];
    const tineB = [[40, 10], [20, -14], [18, -40]];
    s += `<g fill="${GA.C.goldDeep}">
      <path d="${GA.ribbon(hornB, GA.prof.horn(24, 0.9))}"/><path d="${GA.ribbon(tineB, GA.prof.horn(13, 0.9))}"/></g>`;
    s += `<g fill="url(#dhHorn${id})" stroke="${line}" stroke-width="2.2" stroke-linejoin="round">
      <path d="${GA.ribbon(tineA, GA.prof.horn(16, 0.9))}"/><path d="${GA.ribbon(tineA2, GA.prof.horn(14, 0.9))}"/>
      <path d="${GA.ribbon(hornA, GA.prof.horn(30, 0.9))}"/></g>`;

    // lower jaw
    s += `<path d="M178 136 C205 148 240 162 280 172 C298 177 314 182 322 192 C328 202 318 214 304 212 C270 210 230 202 194 190 C168 181 148 172 128 158 Z" fill="url(#dhJaw${id})" stroke="${line}" stroke-width="3" stroke-linejoin="round"/>`;
    // beard / chin spikes
    s += `<g fill="${GA.C.goldDeep}" stroke="${line}" stroke-width="2">
      <path d="${GA.ribbon([[290, 206], [276, 236], [250, 262]], GA.prof.horn(22))}"/>
      <path d="${GA.ribbon([[252, 202], [236, 228], [206, 246]], GA.prof.horn(20))}"/>
      <path d="${GA.ribbon([[212, 192], [192, 214], [160, 226]], GA.prof.horn(18))}"/></g>`;
    // mouth interior (white-hot, charging)
    s += `<path d="M330 108 L318 114 C290 116 250 118 215 124 C200 127 190 132 180 138 C205 149 240 162 280 172 C298 177 312 181 322 190 C316 162 318 132 330 108 Z" fill="url(#dhMouth${id})"/>`;
    // teeth
    let teeth = '';
    for (let x = 292; x > 222; x -= 13) teeth += `M${x} ${117 + (300 - x) * 0.05}l-5 0l2.5 ${10 + (x - 220) * 0.05}z`;
    for (let x = 262; x > 200; x -= 13) teeth += `M${x} ${166 - (270 - x) * 0.33}l6 0l-3 -10z`;
    s += `<path d="${teeth}" fill="#FFFDF2"/>`;
    s += `<path d="M298 114 L312 114 L302 152 Z M284 176 L298 180 L294 142 Z" fill="#FFFDF2" stroke="${line}" stroke-width="2" stroke-linejoin="round"/>`;

    // skull + upper jaw
    s += `<path d="M58 104 C60 72 84 50 118 40 C140 22 172 16 198 32 C208 40 212 52 224 58 C252 62 276 60 296 52 C306 36 328 32 338 48 C348 64 342 82 330 88 C336 96 338 106 330 110 L318 114 C290 116 250 118 215 124 C200 127 190 132 180 138 C168 150 150 156 128 156 C104 156 80 150 60 140 Z" fill="url(#dhSkull${id})" stroke="${line}" stroke-width="3" stroke-linejoin="round"/>`;
    // feature lines
    s += `<g fill="none" stroke="${line}" stroke-width="3" stroke-linecap="round">
      <path d="M232 72 C258 76 282 72 300 64"/>
      <path d="M318 72 C322 62 332 62 334 72"/>
      <path d="M214 60 C206 84 196 104 186 130"/>
      <path d="M244 96 C262 98 284 96 304 92" stroke-width="2.2" opacity=".7"/></g>`;
    // cheek curl (classic long cheek spiral) + brow ridge + fierce eye
    s += `<path d="M168 118 C150 128 124 122 120 100 C116 80 138 70 152 82 C162 92 152 106 142 100" fill="none" stroke="${line}" stroke-width="3" stroke-linecap="round"/>`;
    s += `<path d="M150 44 C176 22 214 28 234 58 L222 60 C204 44 180 42 158 56 Z" fill="${line}"/>`;
    s += `<path d="M166 62 L186 50 L218 56 L206 66 C194 70 178 69 166 62 Z" fill="#FFFBEA" stroke="${line}" stroke-width="2.5" stroke-linejoin="round"/>`;
    s += `<path d="M193 52 L199 52 L197 68 L192 67 Z" fill="#9E1016"/>`;
    // snout ridge bumps
    s += `<path d="M236 58 l6 -10 l6 10 M258 60 l6 -9 l6 9 M280 57 l5 -8 l5 7" fill="${GA.C.goldLight}" stroke="${line}" stroke-width="2" stroke-linejoin="round"/>`;
    // whiskers (barbels)
    s += `<g fill="${GA.C.goldLight}" stroke="${line}" stroke-width="1.6">
      <path d="${GA.ribbon([[334, 100], [364, 116], [372, 150], [352, 196], [308, 232], [240, 250], [170, 246]], GA.prof.horn(12, 0.7), 14)}"/>
      <path d="${GA.ribbon([[334, 62], [352, 40], [340, 18], [296, 8], [240, 12], [180, 2], [120, -14]], GA.prof.horn(10, 0.7), 14)}"/></g>`;
    // top highlight
    s += `<path d="M84 60 C108 42 132 30 150 26 M234 60 C258 62 278 58 296 50" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" opacity=".85"/>`;
    return s;
  };

  /* dragon body: serpentine tube with scale bands and dorsal fins.
   * ctrl: control points from neck -> tail. returns svg markup */
  GA.dragonBody = (id, ctrl, w0, w1, opt = {}) => {
    const R = GA.rng(opt.seed ?? 11);
    const line = opt.line ?? GA.C.brown;
    const fr = GA.frames(GA.spline(ctrl, 18));
    const wf = GA.prof.body(w0, w1);
    const finSide = opt.finSide ?? 1;
    let fins = '', bands = '';
    const total = fr[fr.length - 1].total;
    // dorsal fins
    for (let L = 30; L < total * 0.93; L += opt.finStep ?? 34) {
      const q = fr.find((p) => p.len >= L);
      if (!q) break;
      const w = wf(q.t), h = w * 0.75 + 6;
      const bx = q.x + q.nx * finSide * w * 0.42, by = q.y + q.ny * finSide * w * 0.42;
      const back = -(opt.finStep ?? 34) * 0.9;
      fins += `M${f(bx + q.tx * w * 0.35)} ${f(by + q.ty * w * 0.35)}` +
        `Q${f(bx + q.nx * finSide * h * 0.9)} ${f(by + q.ny * finSide * h * 0.9)} ${f(bx + q.nx * finSide * h + q.tx * back)} ${f(by + q.ny * finSide * h + q.ty * back)}` +
        `Q${f(bx + q.nx * finSide * h * 0.3 + q.tx * back * 0.3)} ${f(by + q.ny * finSide * h * 0.3 + q.ty * back * 0.3)} ${f(bx - q.tx * w * 0.35)} ${f(by - q.ty * w * 0.35)}Z`;
    }
    // scale bands (chevrons across the body)
    for (let L = 16; L < total * 0.97; L += opt.bandStep ?? 15) {
      const q = fr.find((p) => p.len >= L);
      if (!q) break;
      const w = wf(q.t) / 2 * 0.92;
      const k = w * 0.45;
      bands += `M${f(q.x + q.nx * w)} ${f(q.y + q.ny * w)}Q${f(q.x - q.tx * k)} ${f(q.y - q.ty * k)} ${f(q.x - q.nx * w)} ${f(q.y - q.ny * w)}`;
    }
    const body = GA.ribbon(ctrl, wf, 18);
    // belly strip on the non-fin side
    const belly = GA.ribbon(ctrl, (t) => wf(t) * 0.42, 18);
    const bellyOffset = opt.bellyShift ?? 0;
    return `<defs><linearGradient id="dbFill${id}" gradientUnits="userSpaceOnUse" ${opt.grad ?? 'x1="0" y1="0" x2="0" y2="400"'}>
        ${opt.stops ?? `<stop offset="0" stop-color="${GA.C.goldLight}"/><stop offset=".55" stop-color="${GA.C.gold}"/><stop offset="1" stop-color="${GA.C.goldDeep}"/>`}</linearGradient></defs>
      <path d="${fins}" fill="${GA.C.goldDeep}" stroke="${line}" stroke-width="2" stroke-linejoin="round"/>
      <path d="${body}" fill="url(#dbFill${id})" stroke="${line}" stroke-width="3" stroke-linejoin="round"/>
      <path d="${bands}" fill="none" stroke="${line}" stroke-width="2.2" opacity=".55"/>
      <path d="${belly}" transform="translate(${bellyOffset})" fill="#FFF3C8" opacity="0"/>`;
  };

  /* wait for injected fonts (render_art.py) then call draw() and flag ready */
  GA.boot = async (draw) => {
    try {
      if (window.__FONTS) {
        for (const [family, b64] of Object.entries(window.__FONTS)) {
          const bin = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
          const ff = new FontFace(family, bin.buffer);
          await ff.load();
          document.fonts.add(ff);
        }
      }
      await document.fonts.ready;
    } catch (e) { console.error(e); }
    draw();
    await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
    window.__ready = true;
  };

  window.GA = GA;
})();
