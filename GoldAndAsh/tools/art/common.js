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

  /* ------------------------------------------------------------------ *
   * Golden dragon head (Chinese long), mascot-style cel shading, profile
   * facing +x, jaws open. Local frame ~ x -90..380, y -90..265;
   * jaw front ~ (335,150). id: suffix for gradient ids.
   * ------------------------------------------------------------------ */
  GA.dragonHead = (id, opt = {}) => {
    const R = GA.rng(opt.seed ?? 7);
    const L = opt.line ?? '#2A0E02';
    const hi = '#FFF4C8', base = '#FFC44A', mid = '#F29A22', shade = '#C4600E';
    const sw = opt.sw ?? 3.2;
    const stroke = `stroke="${L}" stroke-width="${sw}" stroke-linejoin="round"`;
    let s = `<defs>
      <linearGradient id="dhMouth${id}" x1="0" y1="0" x2="1" y2="0">
        <stop offset="0" stop-color="#3A0A04"/><stop offset=".55" stop-color="#8A240A"/><stop offset="1" stop-color="#FF9A3A"/></linearGradient>
      <radialGradient id="dhEye${id}" cx=".6" cy=".5" r=".7">
        <stop offset="0" stop-color="#FFFFFF"/><stop offset=".6" stop-color="#FFF6C8"/><stop offset="1" stop-color="#FFD24A"/></radialGradient>
    </defs>`;

    // --- mane: wind-blown flame spikes from the back of the skull/jaw
    const maneBases = [[158, 34, -158, 1.0], [132, 40, -166, 1.2], [108, 50, -172, 1.3], [88, 66, -178, 1.35], [72, 88, 176, 1.35], [62, 112, 170, 1.3], [66, 136, 162, 1.2], [84, 154, 154, 1.05], [110, 164, 146, 0.95], [140, 170, 138, 0.85]];
    const spikes = maneBases.map(([x, y, deg, k], i) => {
      const a = (deg * Math.PI) / 180, len = 130 * k * R.range(0.88, 1.08);
      const c = Math.cos(a), sn = Math.sin(a), px = -sn, py = c;
      const wave = (i % 2 ? 1 : -1) * 14;
      const pts = [[x, y], [x + c * len * 0.3 + px * wave, y + sn * len * 0.3 + py * wave],
        [x + c * len * 0.66 - px * wave, y + sn * len * 0.66 - py * wave - 8], [x + c * len, y + sn * len - 30]];
      return GA.ribbon(pts, GA.prof.horn(50 * k, 1.15), 10);
    });
    s += `<g fill="${shade}" ${stroke}>${spikes.filter((_, i) => i % 2).map((d) => `<path d="${d}"/>`).join('')}</g>`;
    s += `<g fill="${mid}" ${stroke}>${spikes.filter((_, i) => !(i % 2)).map((d) => `<path d="${d}"/>`).join('')}</g>`;

    // --- horns (back one darker)
    const hornB = [[150, 44], [110, 22], [60, 10], [6, 12], [-44, 26]];
    const hornA = [[178, 36], [140, 8], [90, -16], [30, -30], [-30, -26], [-66, -12]];
    const tineA = [[80, -18], [64, -52], [70, -86]];
    s += `<g fill="${shade}" ${stroke}><path d="${GA.ribbon(hornB, GA.prof.horn(30, 0.9))}"/></g>`;
    s += `<g fill="#FFE6A0" ${stroke}><path d="${GA.ribbon(tineA, GA.prof.horn(20, 0.9))}"/><path d="${GA.ribbon(hornA, GA.prof.horn(38, 0.9))}"/></g>`;
    s += `<path d="${GA.ribbon(hornA.map(([x, y]) => [x, y - 5]), GA.prof.horn(12, 0.9))}" fill="${hi}"/>`;

    // --- cheek frill + beard
    s += `<g fill="${mid}" ${stroke}>
      <path d="${GA.ribbon([[186, 150], [154, 184], [112, 202]], GA.prof.horn(30, 1))}"/>
      <path d="${GA.ribbon([[156, 162], [126, 198], [86, 214]], GA.prof.horn(26, 1))}"/></g>`;
    s += `<g fill="${shade}" ${stroke}>
      <path d="${GA.ribbon([[304, 208], [292, 238], [264, 262]], GA.prof.horn(26))}"/>
      <path d="${GA.ribbon([[266, 206], [248, 234], [218, 250]], GA.prof.horn(22))}"/>
      <path d="${GA.ribbon([[226, 196], [204, 222], [172, 234]], GA.prof.horn(20))}"/></g>`;

    // --- mouth interior + tongue
    s += `<path d="M334 106 L246 116 L192 130 L186 140 L246 160 L304 182 L328 186 C334 160 336 130 334 106 Z" fill="url(#dhMouth${id})" ${stroke}/>`;
    s += `<path d="M206 146 C246 152 286 166 322 160 C306 174 256 174 210 158 Z" fill="#E0561C"/>`;

    // --- lower jaw
    s += `<path d="M186 140 L246 160 L304 182 L328 186 L336 200 L320 214 L252 210 L196 190 L138 164 Z" fill="${base}" ${stroke}/>`;
    s += `<path d="M146 170 L198 180 L254 196 L330 204 L320 214 L252 210 L196 190 Z" fill="${shade}"/>`;
    // --- teeth
    let tu = '', tl = '';
    for (let i = 0; i < 6; i++) { const x = 312 - i * 14, y = 108 + i * 1.6 + (i > 3 ? (i - 3) * 3 : 0); tu += `M${x} ${y}L${x - 9} ${y + 1}L${x - 5} ${y + 13 - i}Z`; }
    for (let i = 0; i < 6; i++) { const x = 300 - i * 16, y = 180 - i * 6.4; tl += `M${x} ${y}L${x - 9} ${y - 3}L${x - 6} ${y - 13 + i}Z`; }
    s += `<path d="${tu}${tl}" fill="#FFFBEA" stroke="${L}" stroke-width="1.6" stroke-linejoin="round"/>`;
    s += `<path d="M324 107 L336 106 L326 142 Z M314 184 L326 186 L318 150 Z" fill="#FFFBEA" ${stroke}/>`;

    // --- skull + upper jaw
    const skull = 'M58 112 C58 84 80 58 112 46 L150 34 L206 12 L216 40 L236 52 C262 58 290 58 306 50 L322 30 C338 24 354 36 352 56 C351 68 344 76 336 78 L346 94 L334 108 L246 116 L192 130 L176 152 L128 164 L74 150 Z';
    s += `<path d="${skull}" fill="${base}" ${stroke}/>`;
    // cel shade (lower band) + highlight (upper planes)
    s += `<path d="M60 124 C96 132 140 128 176 116 L246 100 L336 94 L346 94 L334 108 L246 116 L192 130 L176 152 L128 164 L74 150 Z" fill="${mid}"/>`;
    s += `<path d="M74 150 L128 164 L176 152 L192 130 L150 142 L100 144 Z" fill="${shade}"/>`;
    s += `<path d="M84 86 C94 66 106 54 124 46 L150 36 L204 16 L200 32 L156 50 C130 58 104 72 84 86 Z" fill="${hi}"/>`;
    s += `<path d="M236 58 C262 64 292 64 308 56 L324 36 C334 32 344 34 348 42 L326 52 C302 70 262 70 236 64 Z" fill="${hi}"/>`;
    s += `<path d="${skull}" fill="none" ${stroke}/>`;
    // feature lines
    s += `<g fill="none" stroke="${L}" stroke-width="${sw * 0.85}" stroke-linecap="round" stroke-linejoin="round">
      <path d="M332 42 C340 40 344 48 339 55"/>
      <path d="M224 76 L202 104 L196 128"/>
      <path d="M152 92 C140 84 124 88 124 104 C124 116 138 120 146 112"/>
      <path d="M250 84 L292 80"/>
      <path d="M100 128 L120 114 M84 118 L100 102"/></g>`;
    // brow + glowing eye
    s += `<ellipse cx="192" cy="70" rx="40" ry="18" transform="rotate(-12 192 70)" fill="#FFFFFF" opacity=".85" filter="url(#dhBlur${id})"/>`;
    s += `<path d="M146 56 L206 24 L230 58 L214 60 L198 48 L160 66 Z" fill="${L}"/>`;
    s += `<path d="M162 72 L198 58 L222 62 L208 74 C194 80 176 80 162 72 Z" fill="url(#dhEye${id})" stroke="${L}" stroke-width="${sw * 0.8}" stroke-linejoin="round"/>`;
    s += `<defs><filter id="dhBlur${id}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="5"/></filter></defs>`;
    // snout ridge spikes
    s += `<path d="M244 56 l7 -13 l8 14 M266 59 l7 -12 l7 12 M288 58 l6 -10 l6 9" fill="${hi}" stroke="${L}" stroke-width="${sw * 0.7}" stroke-linejoin="round"/>`;

    // --- whiskers
    s += `<g fill="${hi}" ${stroke}>
      <path d="${GA.ribbon([[346, 90], [374, 104], [384, 140], [366, 186], [324, 220], [262, 236], [198, 232]], GA.prof.horn(15, 0.75), 14)}"/>
      <path d="${GA.ribbon([[340, 34], [362, 14], [358, -8], [330, -20], [292, -16], [262, -30]], GA.prof.horn(14, 0.75), 14)}"/></g>`;
    return s;
  };

  /* dragon body: cel-shaded serpentine tube with belly plates, scale
   * chevrons and dorsal fins. ctrl: control points neck -> tail.
   * finSide: +1/-1 which side of the path carries the fins (belly is the other). */
  GA.dragonBody = (id, ctrl, w0, w1, opt = {}) => {
    const L = opt.line ?? '#2A0E02', sw = opt.sw ?? 3.2;
    const stroke = `stroke="${L}" stroke-width="${sw}" stroke-linejoin="round"`;
    const fr = GA.frames(GA.spline(ctrl, 18));
    const wf = opt.width ?? GA.prof.body(w0, w1);
    const fs = opt.finSide ?? 1;
    const total = fr[fr.length - 1].total;
    const at = (len) => fr.find((p) => p.len >= len) || fr[fr.length - 1];
    let fins = '', chev = '', plates = '';
    const fstep = opt.finStep ?? 40;
    for (let len = 24; len < total * 0.95; len += fstep) {
      const q = at(len), w = wf(q.t), h = w * 0.62 + 8;
      const bx = q.x + q.nx * fs * w * 0.4, by = q.y + q.ny * fs * w * 0.4;
      const back = -fstep * 1.05;
      fins += `M${(bx + q.tx * w * 0.3).toFixed(1)} ${(by + q.ty * w * 0.3).toFixed(1)}` +
        `Q${(bx + q.nx * fs * h * 0.8).toFixed(1)} ${(by + q.ny * fs * h * 0.8).toFixed(1)} ${(bx + q.nx * fs * h + q.tx * back).toFixed(1)} ${(by + q.ny * fs * h + q.ty * back).toFixed(1)}` +
        `Q${(bx + q.nx * fs * h * 0.25 + q.tx * back * 0.3).toFixed(1)} ${(by + q.ny * fs * h * 0.25 + q.ty * back * 0.3).toFixed(1)} ${(bx - q.tx * w * 0.35).toFixed(1)} ${(by - q.ty * w * 0.35).toFixed(1)}Z`;
    }
    const cstep = opt.chevStep ?? 22;
    for (let len = 14; len < total * 0.96; len += cstep) {
      const q = at(len), w = wf(q.t) / 2;
      // chevron on the back half (fin side), belly plate line on the belly half
      const k = w * 0.5;
      chev += `M${(q.x + q.nx * fs * w * 0.85).toFixed(1)} ${(q.y + q.ny * fs * w * 0.85).toFixed(1)}Q${(q.x - q.tx * k + q.nx * fs * w * 0.3).toFixed(1)} ${(q.y - q.ty * k + q.ny * fs * w * 0.3).toFixed(1)} ${(q.x - q.nx * fs * w * 0.2).toFixed(1)} ${(q.y - q.ny * fs * w * 0.2).toFixed(1)}`;
      plates += `M${(q.x - q.nx * fs * w * 0.3).toFixed(1)} ${(q.y - q.ny * fs * w * 0.3).toFixed(1)}L${(q.x - q.nx * fs * w * 0.98).toFixed(1)} ${(q.y - q.ny * fs * w * 0.98).toFixed(1)}`;
    }
    const body = GA.ribbon(ctrl, wf, 18);
    // strip between two fractions of the half-width on one side of the centre line
    const offStrip = (ratioIn, ratioOut, side) => {
      const left = [], right = [];
      for (const q of fr) {
        const w = wf(q.t) / 2;
        left.push([q.x + q.nx * side * w * ratioIn, q.y + q.ny * side * w * ratioIn]);
        right.push([q.x + q.nx * side * w * ratioOut, q.y + q.ny * side * w * ratioOut]);
      }
      return GA.poly(left.concat(right.reverse()));
    };
    return `<path d="${fins}" fill="${opt.finFill ?? '#E0741A'}" ${stroke}/>
      <path d="${body}" fill="${opt.fill ?? '#FFC44A'}"/>
      <path d="${offStrip(0.05, 1, -fs)}" fill="${opt.shade ?? '#F29A22'}"/>
      <path d="${offStrip(0.5, 1, -fs)}" fill="${opt.belly ?? '#FFD76A'}"/>
      <path d="${plates}" fill="none" stroke="${L}" stroke-width="${sw * 0.6}" opacity=".7"/>
      <path d="${offStrip(0.4, 0.68, fs)}" fill="${opt.hi ?? '#FFF4C8'}" opacity=".85"/>
      <path d="${chev}" fill="none" stroke="#B8560E" stroke-width="${sw * 0.7}" stroke-linecap="round" opacity=".8"/>
      <path d="${body}" fill="none" ${stroke}/>`;
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
