#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
금빛과 재 (Gold & Ash) -- procedural sound-effect + music generator.

Every sound in the game is synthesized from scratch here (numpy + scipy), then written as:

  assets/sounds/sfx/<name>.ogg        individual SFX (mono, 44.1 kHz, OGG Vorbis, -1 dBFS peak)
  assets/sounds/sfx_sprite.ogg        all SFX in ONE file ("sound sprite", 0.25 s of silence between)
  assets/sounds/music_*.ogg           4 seamless stereo music loops (exact number of bars, -3 dBFS peak)
  src/shared/SoundManifest.luau       sprite regions + music lengths (auto-generated, do not edit)
  src/shared/SoundIds.luau            created only if missing (asset IDs; filled by tools/upload_sounds.py)

The output is deterministic: each sound uses its own fixed random seed.

Requirements:   pip install numpy scipy soundfile
Usage:          python3 tools/gen_sounds.py               # generate everything
                python3 tools/gen_sounds.py --sfx-only    # skip the (slower) music loops
                python3 tools/gen_sounds.py --music-only  # only re-render the music loops
                python3 tools/gen_sounds.py --wav-dir /tmp/preview   # also dump .wav copies to listen to
"""
from __future__ import annotations

import argparse
import math
import sys
import time
import zlib
from pathlib import Path
from typing import Callable

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
TAU = 2.0 * math.pi

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "sounds"
SFX_DIR = OUT_DIR / "sfx"
SHARED_DIR = ROOT / "src" / "shared"
MANIFEST_PATH = SHARED_DIR / "SoundManifest.luau"
SOUND_IDS_PATH = SHARED_DIR / "SoundIds.luau"

SPRITE_GAP = 0.25          # seconds of silence before / between / after sprite entries
SFX_PEAK_DB = -1.0
MUSIC_PEAK_DB = -3.0
SFX_VORBIS_LEVEL = 0.3     # soundfile compression_level (0 = best quality, 1 = smallest)
MUSIC_VORBIS_LEVEL = 0.4


# =============================================================================================
#  Basic helpers
# =============================================================================================

def N(seconds: float) -> int:
    return int(round(seconds * SR))


def T(seconds: float) -> np.ndarray:
    return np.arange(N(seconds)) / SR


def db(v: float) -> float:
    return 10.0 ** (v / 20.0)


def peak(x: np.ndarray) -> float:
    return float(np.max(np.abs(x))) if x.size else 0.0


def nrm(x: np.ndarray, target: float = 1.0) -> np.ndarray:
    p = peak(x)
    return x * (target / p) if p > 0 else x


def rms(x: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(x)))) + 1e-12


def fit(x: np.ndarray, n: int) -> np.ndarray:
    if len(x) >= n:
        return x[:n].copy()
    pad = np.zeros((n - len(x),) + x.shape[1:])
    return np.concatenate([x, pad])


def add_at(dst: np.ndarray, src: np.ndarray, i: int, gain: float = 1.0) -> None:
    if i < 0:
        src = src[-i:]
        i = 0
    m = min(len(src), len(dst) - i)
    if m > 0:
        dst[i:i + m] += gain * src[:m]


def place(dst: np.ndarray, src: np.ndarray, t0: float, gain: float = 1.0) -> None:
    add_at(dst, src, N(t0), gain)


def smoothstep(x) -> np.ndarray:
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def midi_hz(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=np.float64) - 69.0) / 12.0)


def sat(x: np.ndarray, drive: float = 2.0) -> np.ndarray:
    """Soft saturation (tanh), normalised so that +-1 maps to +-1."""
    return np.tanh(drive * x) / math.tanh(drive)


def fades(x: np.ndarray, fin: float = 0.003, fout: float = 0.005) -> np.ndarray:
    x = x.copy()
    a, b = N(fin), N(fout)
    if a > 0:
        x[:a] *= np.linspace(0.0, 1.0, a)
    if b > 0:
        x[-b:] *= np.linspace(1.0, 0.0, b)
    return x


def mixp(*layers) -> np.ndarray:
    """Sum layers (signal, dB) after peak-normalising each one."""
    n = max(len(s) for s, _ in layers)
    out = np.zeros(n)
    for s, g in layers:
        out[:len(s)] += nrm(s) * db(g)
    return out


def mixr(*layers) -> np.ndarray:
    """Sum layers (signal, dB) after RMS-normalising each one (good for noise beds)."""
    n = max(len(s) for s, _ in layers)
    out = np.zeros(n)
    for s, g in layers:
        out[:len(s)] += s * (0.25 / rms(s)) * db(g)
    return out


def one_pole(x: np.ndarray, tau: float) -> np.ndarray:
    p = math.exp(-1.0 / max(tau * SR, 1e-9))
    y, _ = signal.lfilter([1.0 - p], [1.0, -p], x, zi=[p * x[0]])
    return y


# ---------------------------------------------------------------------------------------------
#  Noise
# ---------------------------------------------------------------------------------------------

def white(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n)


def colored(n: int, rng: np.random.Generator, alpha: float) -> np.ndarray:
    """1/f^alpha noise (alpha=1 pink, 2 brown), unit std."""
    X = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = f[1] if n > 2 else 1.0
    X /= f ** (alpha / 2.0)
    X[0] = 0.0
    y = np.fft.irfft(X, n)
    return y / (np.std(y) + 1e-12)


def bnoise(n: int, rng: np.random.Generator, fc, q=1.2, stages: int = 2, alpha: float = 0.7) -> np.ndarray:
    """Swept band-pass noise (tilted-pink source, cascaded stages) -- the core of every whoosh."""
    y = colored(n, rng, alpha)
    for _ in range(stages):
        y = sweep(y, "bp", fc, q)
    return y


def smooth_noise(n: int, rng: np.random.Generator, rate: float) -> np.ndarray:
    """Band-limited random control signal in [-1, 1]."""
    w = N(0.3)
    y = lpf(rng.standard_normal(n + w), rate, 2)[w:]
    return y / (peak(y) + 1e-12)


# ---------------------------------------------------------------------------------------------
#  Filters
# ---------------------------------------------------------------------------------------------

def _fc(f: float) -> float:
    return float(min(max(f, 5.0), SR * 0.45))


def lpf(x, f, order=2):
    return signal.sosfilt(signal.butter(order, _fc(f), "lowpass", fs=SR, output="sos"), x, axis=0)


def hpf(x, f, order=2):
    return signal.sosfilt(signal.butter(order, _fc(f), "highpass", fs=SR, output="sos"), x, axis=0)


def bpf(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [_fc(lo), _fc(hi)], "bandpass", fs=SR, output="sos"), x, axis=0)


def rbj(kind: str, f: float, q: float = 0.707, gain_db: float = 0.0):
    """RBJ audio-EQ-cookbook biquad coefficients."""
    w0 = TAU * _fc(f) / SR
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2.0 * max(q, 1e-3))
    A = 10.0 ** (gain_db / 40.0)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "bp":  # constant 0 dB peak gain
        b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "peak":
        b = [1 + alpha * A, -2 * cw, 1 - alpha * A]
        a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    elif kind == "hs":  # high shelf (slope 1)
        al = sw / 2 * math.sqrt(2.0)
        sa = 2 * math.sqrt(A) * al
        b = [A * ((A + 1) + (A - 1) * cw + sa), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sa)]
        a = [(A + 1) - (A - 1) * cw + sa, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sa]
    else:
        raise ValueError(kind)
    a0 = a[0]
    return np.array(b) / a0, np.array(a) / a0


def eq(x, kind, f, q=0.707, gain_db=0.0):
    b, a = rbj(kind, f, q, gain_db)
    return signal.lfilter(b, a, x, axis=0)


def sweep(x: np.ndarray, kind: str, f, q=0.707, block: int = 64) -> np.ndarray:
    """Time-varying biquad (frequency and Q may be arrays), block-wise coefficient update."""
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    f = np.broadcast_to(np.asarray(f, dtype=np.float64), (n,))
    q = np.broadcast_to(np.asarray(q, dtype=np.float64), (n,))
    y = np.empty(n)
    zi = np.zeros(2)
    for s in range(0, n, block):
        e = min(n, s + block)
        c = (s + e) // 2
        b, a = rbj(kind, f[c], q[c])
        y[s:e], zi = signal.lfilter(b, a, x[s:e], zi=zi)
    return y


# ---------------------------------------------------------------------------------------------
#  Envelopes
# ---------------------------------------------------------------------------------------------

def env_exp(t, tau, attack=0.0005):
    e = np.exp(-t / tau)
    if attack > 0:
        e = e * np.clip(t / attack, 0.0, 1.0)
    return e


def env_gamma(t, tp, k=2.0):
    """Smooth rise/fall envelope that peaks (=1) at time tp; larger k = sharper."""
    x = np.maximum(t, 0.0) / tp
    return np.power(x, k) * np.exp(k * (1.0 - x))


def env_pts(t, pts):
    ts, vs = zip(*pts)
    return np.interp(t, ts, vs)


# ---------------------------------------------------------------------------------------------
#  Oscillators
# ---------------------------------------------------------------------------------------------

def phase_of(f, ph0: float = 0.0) -> np.ndarray:
    """Running phase in cycles for a frequency array."""
    f = np.asarray(f, dtype=np.float64)
    ph = np.empty_like(f)
    ph[0] = 0.0
    np.cumsum(f[:-1], out=ph[1:])
    return ph / SR + ph0


def sine(f, ph0: float = 0.0):
    return np.sin(TAU * phase_of(f, ph0))


def _blep(p, dt):
    y = np.zeros_like(p)
    m = p < dt
    x = p[m] / dt[m]
    y[m] = x + x - x * x - 1.0
    m = p > 1.0 - dt
    x = (p[m] - 1.0) / dt[m]
    y[m] = x * x + x + x + 1.0
    return y


def saw(f, ph0: float = 0.0):
    """Band-limited (polyBLEP) sawtooth for a frequency array."""
    f = np.asarray(f, dtype=np.float64)
    dt = np.clip(np.abs(f) / SR, 1e-7, 0.5)
    p = np.mod(phase_of(f, ph0), 1.0)
    return 2.0 * p - 1.0 - _blep(p, dt)


def pulse(f, width: float = 0.5, ph0: float = 0.0):
    return 0.5 * (saw(f, ph0) - saw(f, ph0 + width))


def thump(t, f0, f1, ptau, atau, attack=0.0012):
    """Pitched-down sine thump: f0 -> f1 with pitch time-constant ptau, amp decay atau."""
    f = f1 + (f0 - f1) * np.exp(-t / ptau)
    return np.sin(TAU * phase_of(f)) * env_exp(t, atau, attack)


def partials(t, f0, ratios, amps, decays, attack=0.0004, rng=None):
    """Sum of exponentially decaying sine partials (inharmonic metal / bells / wood)."""
    y = np.zeros(len(t))
    for r, a, d in zip(ratios, amps, decays):
        f = f0 * r
        if f >= SR * 0.45:
            continue
        ph = rng.uniform(0, TAU) if rng is not None else 0.0
        y += a * np.exp(-t / d) * np.sin(TAU * f * t + ph)
    if attack > 0:
        y *= np.clip(t / attack, 0.0, 1.0)
    return y


def crackle(n, rng, rate, fmin, fmax, glen=(0.0005, 0.003), kind="mix", amp=None, fscale=None, jitter=0.7):
    """Granular crackle: Poisson-distributed tiny grains (noise clicks and/or damped sine pings)."""
    t = np.arange(n) / SR
    r = rate(t) if callable(rate) else np.full(n, float(rate))
    hits = np.nonzero(rng.random(n) < r / SR)[0]
    rmax = float(np.max(r)) + 1e-9
    y = np.zeros(n + N(0.06))
    lf0, lf1 = math.log(fmin), math.log(fmax)
    for i in hits:
        L = max(8, int(rng.uniform(*glen) * SR))
        k = np.arange(L)
        a = math.exp(rng.normal(0.0, jitter))
        if amp is not None:
            a *= float(amp(i / SR))
        else:
            a *= math.sqrt(r[i] / rmax)
        if kind == "ping" or (kind == "mix" and rng.random() < 0.5):
            f = math.exp(rng.uniform(lf0, lf1)) * (float(fscale(i / SR)) if fscale else 1.0)
            g = np.sin(TAU * min(f, SR * 0.45) * k / SR + rng.uniform(0, TAU))
        else:
            g = rng.standard_normal(L)
        y[i:i + L] += a * g * np.exp(-k / (L / 3.0))
    return y[:n]


def metal_bank(x, fbase, ratios=(1.0, 2.76, 5.40, 8.93), gains=(1.0, 0.6, 0.38, 0.22), q=30.0):
    """Excite a bank of swept resonant band-passes at inharmonic metal ratios (scrapes)."""
    out = np.zeros(len(x))
    fbase = np.broadcast_to(np.asarray(fbase, dtype=np.float64), (len(x),))
    for r, g in zip(ratios, gains):
        if np.max(fbase) * r > SR * 0.44:
            continue
        out += g * sweep(x, "bp", fbase * r, q)
    return out


# ---------------------------------------------------------------------------------------------
#  Reverb
# ---------------------------------------------------------------------------------------------

_IR_CACHE: dict = {}


def make_ir(rt60: float, seed: int = 7, stereo: bool = False, damp: float = 0.55,
            predelay: float = 0.008, bright: float = 7000.0) -> np.ndarray:
    """Synthetic room impulse response: multiband exponentially-decaying noise + early reflections."""
    key = (rt60, seed, stereo, damp, predelay, bright)
    if key in _IR_CACHE:
        return _IR_CACHE[key]
    rng = np.random.default_rng(seed)
    dur = min(rt60 * 1.25, 6.0)
    n = N(dur)
    t = np.arange(n) / SR
    chans = []
    for _ in range(2 if stereo else 1):
        w = rng.standard_normal(n)
        lo = lpf(w, 350)
        mid = bpf(w, 350, 2500)
        hi = hpf(w, 2500)
        ir = (lo * 10 ** (-3 * t / (rt60 * 1.1)) + mid * 10 ** (-3 * t / rt60)
              + hi * 10 ** (-3 * t / (rt60 * damp)))
        ir = lpf(ir, bright)
        ir *= 1.0 - np.exp(-t / 0.007)
        for _k in range(10):
            ti = rng.uniform(0.003, 0.05)
            ir[N(ti)] += rng.choice([-1.0, 1.0]) * rng.uniform(1.5, 4.0) * math.exp(-ti / 0.03)
        ir = np.concatenate([np.zeros(N(predelay)), ir])
        chans.append(ir)
    ir = np.stack(chans, axis=1) if stereo else chans[0]
    ir = ir / math.sqrt(np.sum(ir ** 2) / (2 if stereo else 1))
    _IR_CACHE[key] = ir
    return ir


def reverb(x: np.ndarray, rt60: float, wet: float, damp: float = 0.55, predelay: float = 0.008) -> np.ndarray:
    ir = make_ir(rt60, damp=damp, predelay=predelay)
    return x + wet * signal.fftconvolve(x, ir)[:len(x)]


def finalize_sfx(x: np.ndarray, dur: float, tail: float | None = None) -> np.ndarray:
    x = np.nan_to_num(np.asarray(x, dtype=np.float64))
    x = fit(x, N(dur))
    x = hpf(x, 25.0, 2)               # DC / sub-sonic removal
    # smooth (raised-cosine) tail so sounds that still ring at their nominal length never end abruptly
    tail = min(max(0.2 * dur, 0.03), 0.25) if tail is None else tail
    k = N(tail)
    if k > 0:
        x[-k:] *= 0.5 + 0.5 * np.cos(np.linspace(0.0, math.pi, k))
    x = fades(x, 0.003, 0.005)        # no clicks at the edges
    return nrm(x, db(SFX_PEAK_DB))


# =============================================================================================
#  SOUND EFFECTS
# =============================================================================================

SFX_LIST: list[tuple[str, float, Callable, float | None]] = []


def sfx(name: str, dur: float, tail: float | None = None):
    """Register a sound effect. `tail` = length of the final fade-out (default: 20 % of dur, 30-250 ms)."""
    def deco(fn):
        SFX_LIST.append((name, dur, fn, tail))
        return fn
    return deco


# ------------------------------------------------------------------ common -------------------

@sfx("m1_swing", 0.25)
def _m1_swing(rng, t):
    n = len(t)
    e = env_gamma(t, 0.085, 2.4)
    fc = 420.0 + 1500.0 * env_gamma(t, 0.095, 1.6)
    main = bnoise(n, rng, fc, 1.1) * e
    whistle = sweep(white(n, rng), "bp", fc * 1.9, 7.0) * env_gamma(t, 0.08, 3.0)
    body = bnoise(n, rng, fc * 0.45, 1.2) * env_gamma(t, 0.1, 2.0)
    air = hpf(white(n, rng), 4000) * env_gamma(t, 0.08, 3.0)
    return mixr((main, 0), (whistle, -12), (body, -5), (air, -18))


@sfx("m1_hit", 0.3)
def _m1_hit(rng, t):
    n = len(t)
    body = thump(t, 190, 58, 0.016, 0.06)
    low = thump(t, 95, 48, 0.04, 0.075)
    smack = bpf(white(n, rng), 600, 2600) * env_exp(t, 0.018, 0.0006)
    crack = hpf(white(n, rng), 2500) * env_exp(t, 0.004, 0.0003)
    y = mixp((body, 0), (low, -4), (smack, -3), (crack, -7))
    y = sat(nrm(y), 2.6)
    return lpf(y, 11000)


@sfx("m1_hit_heavy", 0.6)
def _m1_hit_heavy(rng, t):
    n = len(t)
    boom = thump(t, 150, 40, 0.03, 0.16)
    sub = thump(t, 72, 34, 0.08, 0.18)
    burst = bpf(white(n, rng), 500, 4500) * env_exp(t, 0.03, 0.0008)
    crunch = bpf(crackle(n, rng, lambda tt: 5000 * np.exp(-tt / 0.035), 800, 6000, (0.0004, 0.0018), "noise"),
                 600, 8000)
    crack = hpf(white(n, rng), 2500) * env_exp(t, 0.005, 0.0003)
    air = lpf(white(n, rng), 280) * env_exp(t, 0.07, 0.004)
    y = mixp((boom, 0), (sub, -3), (burst, -5), (crunch, -7), (crack, -8), (air, -9))
    y = sat(nrm(y), 3.0)
    return reverb(y, 0.9, 0.22)


@sfx("block_hit", 0.3)
def _block_hit(rng, t):
    n = len(t)
    thud = lpf(thump(t, 130, 62, 0.016, 0.05), 900, 2)
    body = bpf(white(n, rng), 140, 700) * env_exp(t, 0.028, 0.001)
    clack = partials(t, 1900, [1, 1.53, 2.31, 3.4], [1, .6, .4, .2], [.02, .013, .009, .006], rng=rng)
    clack = clack + 0.6 * nrm(hpf(white(n, rng), 3000) * env_exp(t, 0.0015, 0.0002))
    y = mixp((thud, 0), (body, -4), (clack, -12))
    y = sat(nrm(y), 1.7)
    return lpf(y, 6500)


@sfx("guard_break", 0.7)
def _guard_break(rng, t):
    n = len(t)
    low = thump(t, 140, 40, 0.03, 0.18)
    shatter = np.zeros(n)
    for _ in range(90):
        t0 = min(rng.exponential(0.07), 0.5)
        f = math.exp(rng.uniform(math.log(1800), math.log(9500)))
        dec = rng.uniform(0.008, 0.06)
        amp = rng.uniform(0.2, 1.0) * math.exp(-t0 / 0.18)
        s = T(min(dec * 6, 0.4))
        place(shatter, amp * np.sin(TAU * f * s + rng.uniform(0, TAU)) * np.exp(-s / dec)
              * np.clip(s / 0.0003, 0, 1), t0)
    crunch = bpf(white(n, rng), 800, 6500) * env_exp(t, 0.06, 0.0008)
    crunch = crunch + 0.8 * nrm(bpf(crackle(n, rng, lambda tt: 4000 * np.exp(-tt / 0.06), 900, 7000,
                                            (0.0004, 0.002), "noise"), 700, 8000)) * peak(crunch)
    fsw = 160 + 700 * np.exp(-t / 0.1)
    energy = lpf(saw(fsw) + saw(fsw * 1.01, 0.5), 2200) * env_exp(t, 0.12, 0.004)
    crack = hpf(white(n, rng), 2000) * env_exp(t, 0.006, 0.0003)
    y = mixp((low, 0), (shatter, -3), (crunch, -5), (crack, -7), (energy, -12))
    y = sat(nrm(y), 2.2)
    return reverb(y, 0.8, 0.2)


@sfx("parry", 0.6)
def _parry(rng, t):
    n = len(t)
    f0 = 1780.0
    R = [1.0, 2.76, 5.40, 8.93]
    A = [1.0, 0.55, 0.32, 0.18]
    D = [0.5, 0.28, 0.15, 0.08]
    ting = partials(t, f0, R, A, D, rng=rng) + 0.7 * partials(t, f0 * 1.0021, R, A, D, rng=rng)
    trem = 1.0 + 0.5 * np.sin(TAU * 9.0 * t)
    shimmer = partials(t, f0 * 3.07, [1, 1.34, 1.87, 2.41], [1, .7, .5, .35], [.32, .26, .2, .15], rng=rng) * trem
    hit = (hpf(white(n, rng), 3500) * env_exp(t, 0.0018, 0.0002)
           + 0.5 * bpf(white(n, rng), 4000, 10000) * env_exp(t, 0.012, 0.0004))
    clash = thump(t, 460, 210, 0.01, 0.03)
    y = mixp((ting, 0), (hit, -5), (shimmer, -13), (clash, -13))
    return reverb(y, 1.3, 0.22, damp=0.8)


@sfx("dash", 0.35)
def _dash(rng, t):
    n = len(t)
    e = env_gamma(t, 0.1, 2.0)
    fc = 330 + 1000 * env_gamma(t, 0.11, 1.4)
    main = bnoise(n, rng, fc, 1.0) * e
    rate = (27.0 - 10.0 * t / t[-1]) * (1 + 0.2 * smooth_noise(n, rng, 15))
    flap = (0.5 + 0.5 * np.sin(TAU * phase_of(rate))) ** 4
    cloth = bpf(colored(n, rng, 0.7), 600, 2800) * flap * env_gamma(t, 0.13, 1.6)
    low = lpf(white(n, rng), 260) * env_gamma(t, 0.1, 2.0)
    return mixr((main, 0), (cloth, -5), (low, -8))


@sfx("evasive", 0.5)
def _evasive(rng, t):
    n = len(t)
    ts = 0.2
    x = np.clip(t / ts, 0, 1)
    rise = np.where(t < ts, x ** 3, np.exp(-(t - ts) / 0.012))
    swell = bnoise(n, rng, 300.0 * 8.0 ** x, 1.6) * rise
    vwip = (sine(300.0 * 2 ** (2.3 * x)) + 0.3 * sine(600.0 * 2 ** (2.3 * x))) * rise
    t2 = np.maximum(t - (ts - 0.02), 0.0)
    e2 = env_gamma(t2, 0.045, 2.5) * (t > ts - 0.02)
    whoosh = bnoise(n, rng, 450 + 1900 * np.exp(-t2 / 0.12), 1.2) * e2
    return mixr((swell, -2), (vwip, -11), (whoosh, 0))


@sfx("land_heavy", 0.5)
def _land_heavy(rng, t):
    n = len(t)
    boom = thump(t, 115, 40, 0.03, 0.11)
    dirt = lpf(white(n, rng), 1500) * env_exp(t, 0.05, 0.001)
    lown = bpf(white(n, rng), 120, 600) * env_exp(t, 0.08, 0.002)
    debris = crackle(n, rng, lambda tt: 380 * env_gamma(tt, 0.07, 1.3), 1500, 6000, (0.002, 0.007), "ping",
                     amp=lambda tt: math.exp(-tt / 0.18))
    y = mixp((boom, 0), (dirt, -6), (lown, -6), (debris, -13))
    return sat(nrm(y), 2.0)


@sfx("ragdoll_fall", 0.4)
def _ragdoll_fall(rng, t):
    n = len(t)
    y = np.zeros(n)
    for t0, g, f0, tau in ((0.0, 1.0, 120, 0.08), (0.072, 0.55, 135, 0.05), (0.14, 0.28, 150, 0.04)):
        s = T(0.4 - t0)
        hit = thump(s, f0, 50, 0.022, tau) + 0.45 * nrm(bpf(white(len(s), rng), 300, 1500) * env_exp(s, 0.02, 0.0008))
        place(y, g * hit, t0)
    scuff = lpf(white(n, rng), 2500) * env_gamma(t, 0.05, 1.5)
    y = mixp((y, 0), (scuff, -16))
    return sat(nrm(y), 1.8)


@sfx("ground_crack", 0.9)
def _ground_crack(rng, t):
    n = len(t)
    crack0 = hpf(white(n, rng), 1500) * env_exp(t, 0.008, 0.0003)
    fract = np.zeros(n)
    tc = 0.0
    for i in range(28):
        tc += rng.exponential(0.011)
        if tc > 0.32:
            break
        s = T(0.06)
        a = math.exp(-tc / 0.15) * rng.uniform(0.4, 1.0)
        burst = bpf(white(len(s), rng), 800, 5000) * env_exp(s, rng.uniform(0.001, 0.004), 0.0002)
        rock = np.sin(TAU * rng.uniform(400, 1400) * s) * env_exp(s, 0.015, 0.0005)
        place(fract, a * (nrm(burst) + 0.5 * rock), tc)
    rumble = lpf(colored(n, rng, 2.0), 180) * (1 - np.exp(-t / 0.02)) * np.exp(-t / 0.3)
    boom = thump(t, 95, 30, 0.04, 0.25)
    debris = crackle(n, rng, lambda tt: 260 * env_gamma(tt, 0.25, 1.2), 1200, 5000, (0.002, 0.007), "ping")
    y = mixp((boom, 0), (crack0, -4), (fract, -5), (rumble, -3), (debris, -15))
    y = sat(nrm(y), 2.2)
    return reverb(y, 1.0, 0.18)


@sfx("explosion", 1.4)
def _explosion(rng, t):
    n = len(t)
    boom = thump(t, 120, 28, 0.06, 0.45)
    sub = thump(t, 60, 24, 0.15, 0.6)
    blast = sweep(white(n, rng), "lp", 250 + 7500 * np.exp(-t / 0.07), 0.8) * env_exp(t, 0.3, 0.003)
    crk = crackle(n, rng, lambda tt: 900 * np.exp(-tt / 0.25), 900, 7000, (0.0008, 0.004), "noise")
    rumble = lpf(colored(n, rng, 2.0), 160) * (1 - np.exp(-t / 0.04)) * np.exp(-t / 0.55)
    y = mixp((boom, 0), (sub, -3), (blast, -2), (rumble, -4), (bpf(crk, 900, 8000), -12))
    y = sat(nrm(y), 2.8)
    y = reverb(y, 1.8, 0.3)
    return y * env_pts(t, [(0, 1), (1.1, 1), (1.4, 0.3)])


@sfx("knockback_whoosh", 0.6)
def _knockback_whoosh(rng, t):
    n = len(t)
    e = env_gamma(t, 0.14, 1.5)
    fc = 330 + 1500 * np.exp(-t / 0.18)
    turb = 1.0 + 0.35 * smooth_noise(n, rng, 18)
    main = bnoise(n, rng, fc, 0.9) * e * turb
    low = lpf(white(n, rng), 380) * env_gamma(t, 0.16, 1.4)
    top = hpf(white(n, rng), 5000) * env_gamma(t, 0.06, 2.0)
    return mixr((main, 0), (low, -5), (top, -18))


@sfx("death", 1.0)
def _death(rng, t):
    n = len(t)
    thud = thump(t, 110, 42, 0.03, 0.15) + 0.5 * nrm(bpf(white(n, rng), 200, 1200) * env_exp(t, 0.03, 0.001))
    f = 55 + 165 * np.exp(-t / 0.3)
    tone = saw(f) + 0.7 * saw(f * 1.006, 0.3) + 0.8 * sine(f * 0.5)
    tone = sweep(tone, "lp", 300 + 1200 * np.exp(-t / 0.35), 0.9)
    tone = tone * (1 - np.exp(-t / 0.02)) * env_pts(t, [(0, 1), (0.6, 0.8), (1.0, 0)])
    y = mixp((thud, 0), (tone, -3))
    y = sat(nrm(y), 1.5)
    return reverb(y, 1.5, 0.3)


@sfx("ui_hover", 0.06)
def _ui_hover(rng, t):
    n = len(t)
    ping = np.sin(TAU * 1850 * t) * env_exp(t, 0.008, 0.0015) + 0.25 * np.sin(TAU * 3700 * t) * env_exp(t, 0.004, 0.0015)
    click = bpf(white(n, rng), 2000, 6000) * env_exp(t, 0.0012, 0.0002)
    return lpf(mixp((ping, 0), (click, -10)), 7000)


@sfx("ui_select", 0.12)
def _ui_select(rng, t):
    n = len(t)
    click = hpf(white(n, rng), 2500) * env_exp(t, 0.0015, 0.0002)
    f = 1100 + 500 * (1 - np.exp(-t / 0.01))
    blip = (sine(f) + 0.2 * sine(2 * f)) * env_exp(t, 0.035, 0.002)
    return lpf(mixp((blip, 0), (click, -8)), 9000)


def _bell(t, f, rng=None, decay=0.22):
    return partials(t, f, [1, 2.0, 3.01, 4.2], [1, .35, .12, .06], [decay, decay * .55, decay * .3, decay * .18],
                    attack=0.002, rng=rng)


@sfx("ui_confirm", 0.4)
def _ui_confirm(rng, t):
    y = _bell(t, 1318.5, decay=0.07)
    place(y, 0.9 * _bell(T(0.4 - 0.085), 1975.5, decay=0.085), 0.085)
    y = reverb(y, 0.5, 0.15)
    return y * env_pts(t, [(0, 1), (0.3, 1), (0.4, 0)])


@sfx("cooldown_ready", 0.12)
def _cooldown_ready(rng, t):
    n = len(t)
    tink = partials(t, 2637.0, [1, 2.0, 2.76], [1, .2, .15], [0.03, .015, .012], attack=0.001)
    click = bpf(white(n, rng), 3000, 8000) * env_exp(t, 0.001, 0.0002)
    return lpf(mixp((tink, 0), (click, -16)), 9000)


@sfx("awaken_ready", 0.8)
def _awaken_ready(rng, t):
    n = len(t)
    notes = [1174.7, 1318.5, 1480.0, 1760.0, 1975.5, 2349.3]  # D6 E6 F#6 A6 B6 D7
    arp = np.zeros(n)
    for i, f in enumerate(notes):
        t0 = 0.02 + i * 0.055
        place(arp, (0.65 + 0.35 * i / 5) * _bell(T(0.8 - t0), f, rng, 0.3), t0)
    x = np.clip(t / 0.45, 0, 1)
    swell = sweep(white(n, rng), "bp", 1500 * 4 ** x, 3.0) * env_gamma(t, 0.42, 2.0)
    trem = 0.8 + 0.2 * np.sin(TAU * 7 * t)
    pad = (sine(np.full(n, 587.33)) + 0.8 * sine(np.full(n, 880.0)) + 0.6 * sine(np.full(n, 1174.7))) \
        * env_gamma(t, 0.4, 1.5) * trem
    sparkle = crackle(n, rng, lambda tt: 180 * env_gamma(tt, 0.4, 1.5), 5000, 10000, (0.004, 0.015), "ping")
    y = mixp((arp, 0), (pad, -9), (swell, -12), (sparkle, -14))
    y = reverb(y, 1.2, 0.3)
    return y * env_pts(t, [(0, 1), (0.55, 1), (0.8, 0.0)])


@sfx("break_prop", 0.6)
def _break_prop(rng, t):
    n = len(t)
    crack = hpf(white(n, rng), 2000) * env_exp(t, 0.004, 0.0002)
    WR, WA, WD = [1, 2.32, 4.0, 6.39, 9.26], [1, .7, .5, .35, .2], [.06, .04, .03, .02, .012]
    wood = partials(t, 310, WR, WA, WD, rng=rng)
    splinter = bpf(crackle(n, rng, lambda tt: 3500 * np.exp(-tt / 0.05), 1000, 6000, (0.0005, 0.003), "noise"),
                   900, 7000)
    thud = thump(t, 130, 50, 0.025, 0.09)
    concrete = bpf(white(n, rng), 200, 1500) * env_exp(t, 0.05, 0.001)
    debris = crackle(n, rng, lambda tt: 220 * env_gamma(tt, 0.12, 1.2), 1500, 6000, (0.002, 0.007), "ping")
    clatter = np.zeros(n)
    for _ in range(6):
        t0 = rng.uniform(0.07, 0.45)
        s = T(0.12)
        place(clatter, rng.uniform(0.2, 0.5) * math.exp(-t0 / 0.3)
              * partials(s, 310 * rng.uniform(1.3, 2.6), WR, WA, WD, rng=rng), t0)
    y = mixp((crack, -4), (wood, -2), (splinter, -4), (thud, 0), (concrete, -6), (debris, -13), (clatter, -9))
    return sat(nrm(y), 1.8)


# ------------------------------------------------------------------ Lin Yuan -----------------

@sfx("lin_chi_charge", 1.2, tail=0.06)
def _lin_chi_charge(rng, t):
    n = len(t)
    x = t / 1.2
    f0 = 110.0 * 2.0 ** (x ** 1.3)          # A2 -> A3
    bright = 0.18 + 0.7 * x ** 1.5
    hum = np.zeros(n)
    for det, g in ((-6.0, 0.22), (0.0, 1.0), (5.0, 0.22)):
        ph = phase_of(f0 * 2 ** (det / 1200), rng.random())
        for k in range(1, 17):
            hum += g * (1.0 / k ** 1.2) * bright ** (k - 1) * np.sin(TAU * k * ph)
    fifth = sine(f0 * 1.5) * x ** 2
    air = sweep(white(n, rng), "bp", 2500 + 5000 * x, 2.0) * x ** 2
    sparkle = crackle(n, rng, lambda tt: 30 + 400 * (tt / 1.2) ** 2, 3000, 9000, (0.004, 0.02), "ping")
    env = smoothstep(t / 0.25) * (0.35 + 0.65 * x ** 0.8)
    y = mixr((hum * env, 0), (fifth * env, -9), (air, -17), (sparkle, -19))
    y = sat(nrm(y), 1.4)
    y = reverb(y, 0.9, 0.18)
    return y * env_pts(t, [(0, 1), (1.14, 1), (1.2, 0)])


@sfx("lin_palm_impact", 0.7)
def _lin_palm_impact(rng, t):
    n = len(t)
    whump = thump(t, 105, 36, 0.04, 0.14)
    push = lpf(white(n, rng), 350) * env_exp(t, 0.05, 0.003)
    punch = bpf(white(n, rng), 180, 900) * env_exp(t, 0.035, 0.001)
    crack = hpf(white(n, rng), 2500) * env_exp(t, 0.003, 0.0002)
    core = sat(nrm(mixp((whump, 0), (push, -6), (punch, -6), (crack, -12))), 2.6)
    gold = np.zeros(n)
    for i, f in enumerate([2349.3, 2637.0, 2960.0, 3520.0, 3951.1]):
        t0 = 0.015 + 0.013 * i
        place(gold, partials(T(0.7 - t0), f, [1, 2.0, 2.76], [1, .25, .12], [.35, .15, .08], attack=0.001, rng=rng), t0)
    sparkle = crackle(n, rng, lambda tt: 700 * np.exp(-tt / 0.12), 4000, 11000, (0.003, 0.012), "ping")
    gold = reverb(nrm(gold) + 0.5 * nrm(sparkle), 1.2, 0.4)
    y = mixp((core, 0), (gold, -9))
    return reverb(y, 0.9, 0.12)


@sfx("lin_staff_swing", 0.3)
def _lin_staff_swing(rng, t):
    n = len(t)
    e = env_gamma(t, 0.11, 2.4)
    fc = 260 + 750 * env_gamma(t, 0.12, 1.5)
    main = sweep(white(n, rng), "bp", fc, 1.7) * e
    whirr = sweep(white(n, rng), "bp", fc * 1.25, 9.0) * env_gamma(t, 0.11, 3.0)
    low = lpf(white(n, rng), 220) * env_gamma(t, 0.12, 2.0)
    return lpf(mixr((main, 0), (whirr, -4), (low, -7)), 4500)


@sfx("lin_staff_hit", 0.3)
def _lin_staff_hit(rng, t):
    n = len(t)
    wood = partials(t, 540, [1, 2.33, 3.98, 6.2, 8.7], [1, .7, .5, .3, .18], [.06, .035, .022, .014, .009], rng=rng)
    crack = hpf(white(n, rng), 2500) * env_exp(t, 0.0025, 0.0002)
    slap = bpf(white(n, rng), 800, 3500) * env_exp(t, 0.012, 0.0005)
    body = thump(t, 190, 80, 0.012, 0.045)
    y = mixp((wood, 0), (crack, -4), (slap, -6), (body, -5))
    y = sat(nrm(y), 2.0)
    return reverb(y, 0.5, 0.1)


@sfx("lin_redirect", 0.6)
def _lin_redirect(rng, t):
    n = len(t)
    e = env_gamma(t, 0.22, 1.8)
    swirl = 0.5 + 0.5 * np.sin(TAU * phase_of(5 + 10 * t))
    fc = (600 + 800 * e) * (1 + 0.35 * np.sin(TAU * phase_of(6.0 + 4 * t)))
    air1 = bnoise(n, rng, fc, 1.8) * e * (0.6 + 0.4 * swirl)
    air2 = bnoise(n, rng, fc * 2.1, 3.0) * e * (0.6 + 0.4 * (1 - swirl))
    air = mixr((air1, 0), (air2, -6))
    chime = np.zeros(n)
    for t0, f, g in ((0.12, 1568.0, 1.0), (0.16, 2349.3, 0.8)):
        place(chime, g * partials(T(0.6 - t0), f, [1, 2.0, 3.0, 4.07], [1, .3, .12, .05], [.35, .18, .1, .06],
                                  attack=0.001, rng=rng), t0)
    whump = np.zeros(n)
    place(whump, thump(T(0.4), 160, 70, 0.015, 0.06), 0.1)
    y = mixp((air, 0), (chime, -3), (whump, -10))
    return reverb(y, 1.0, 0.25)


@sfx("lin_dragon_roar", 1.8)
def _lin_dragon_roar(rng, t):
    n = len(t)
    contour = env_pts(t, [(0, 70), (0.3, 112), (0.7, 106), (1.1, 98), (1.5, 72), (1.8, 60)])
    jitter = 1 + 0.02 * smooth_noise(n, rng, 12)
    vib = 1 + 0.028 * np.sin(TAU * 6.3 * t) * np.clip(t / 0.3, 0, 1)
    f0 = contour * jitter * vib
    src = saw(f0, rng.random()) + 0.7 * saw(f0 * 0.5 * 1.003, rng.random()) + 0.5 * saw(f0 * 1.007, rng.random())
    growl = 1 + 0.55 * np.sin(TAU * phase_of(34 + 8 * smooth_noise(n, rng, 6)))
    src = src * growl + 0.5 * lpf(white(n, rng), 5000) * (0.5 + 0.5 * growl)
    F1 = env_pts(t, [(0, 450), (0.35, 780), (1.0, 700), (1.8, 420)])
    F2 = env_pts(t, [(0, 850), (0.35, 1250), (1.0, 1100), (1.8, 780)])
    F3 = env_pts(t, [(0, 2300), (0.35, 2650), (1.8, 2250)])
    voc = (sweep(src, "bp", F1, 5) + 0.6 * sweep(src, "bp", F2, 7) + 0.35 * sweep(src, "bp", F3, 9)
           + 0.5 * lpf(src, 500))
    voc = lpf(sat(nrm(voc), 4.0), 6000)
    sub = sine(f0 * 0.5)
    env = smoothstep(t / 0.2) * env_pts(t, [(0, 1), (1.15, 1.0), (1.65, 0.0), (1.8, 0)])
    y = (nrm(voc) + 0.3 * nrm(sub)) * env
    return reverb(y, 1.8, 0.3)


@sfx("lin_dragon_whoosh", 1.0)
def _lin_dragon_whoosh(rng, t):
    n = len(t)
    e = env_gamma(t, 0.42, 1.5)
    swirl_ph = phase_of(2.5 + 3.0 * t)
    fc = (400 + 900 * e) * (1 + 0.3 * np.sin(TAU * swirl_ph))
    a = bnoise(n, rng, fc, 1.2) * e
    b = bnoise(n, rng, fc * 2.3, 3.0) * e * (0.55 + 0.45 * np.sin(TAU * swirl_ph * 2 + 1.0))
    low = lpf(white(n, rng), 220) * env_gamma(t, 0.45, 1.3)
    return mixr((a, 0), (b, -7), (low, -5)) * env_pts(t, [(0, 1), (0.7, 1), (1.0, 0.2)])


def gong_tone(t, rng, f0=92.0, modes=44, decay=1.8, bloom=0.3, drift=-0.035):
    """Modal gong: inharmonic partials, slow decay, blooming mids/highs, downward pitch glide."""
    y = np.zeros(len(t))
    for k in range(modes):
        r = 1.0 if k == 0 else ((1 + 0.62 * k) ** 1.12) * (1 + rng.uniform(-0.05, 0.05))
        f = f0 * r
        if f > 7500:
            break
        a = 1.0 if k == 0 else rng.uniform(0.4, 1.0) / (1 + 0.28 * k)
        dk = decay * (1.25 if k == 0 else rng.uniform(0.75, 1.25) / (1 + 0.09 * k))
        blooming = 5 < k < 30
        att = 0.002 + (bloom * rng.uniform(0.3, 1.0) if blooming else 0.0)
        dr = drift * (1.0 if k == 0 else rng.uniform(0.5, 1.5))
        tau = 0.7
        ph = f * (t + dr * (t - tau * (1 - np.exp(-t / tau))))
        env = (1 - np.exp(-t / att)) * np.exp(-t / dk)
        y += a * env * np.sin(TAU * ph + rng.uniform(0, TAU))
    return y


def gong_hit(t, rng, f0=92.0, decay=1.8, bloom=0.3, drift=-0.035):
    n = len(t)
    body = gong_tone(t, rng, f0, 44, decay, bloom, drift)
    strike = bpf(white(n, rng), 600, 5000) * env_exp(t, 0.05, 0.0008)
    wash = bpf(white(n, rng), 300, 3000) * (1 - np.exp(-t / 0.25)) * np.exp(-t / (decay * 0.4))
    mallet = lpf(white(n, rng), 500) * env_exp(t, 0.025, 0.001) + 0.8 * thump(t, f0 * 1.4, f0 * 0.75, 0.02, 0.1)
    return sat(nrm(mixp((body, 0), (strike, -12), (wash, -19), (mallet, -7))), 1.3)


@sfx("lin_gong", 2.0)
def _lin_gong(rng, t):
    y = gong_hit(t, rng, 92.0, 1.5, 0.3, -0.035)
    y = reverb(y, 2.2, 0.2)
    return y * (0.5 + 0.5 * np.cos(np.pi * np.clip((t - 1.45) / 0.55, 0, 1)))


@sfx("lin_awaken", 2.5)
def _lin_awaken(rng, t):
    n = len(t)
    gong = gong_hit(t, rng, 70.0, 1.8, 0.4, -0.04)
    chord1 = [50, 57, 62, 67, 69, 74]      # Dsus4
    chord2 = [50, 57, 62, 66, 69, 74]      # D major (sus4 resolves at 1.25 s)
    src = np.zeros(n)
    for m1, m2 in zip(chord1, chord2):
        target = np.where(t < 1.25, float(m1), float(m2))
        fm = midi_hz(one_pole(target, 0.05))
        for v in range(4):
            c = (v - 1.5) * 8.0 + rng.uniform(-2, 2)
            vib = 1 + 0.004 * np.sin(TAU * rng.uniform(4.5, 5.5) * t + rng.uniform(0, TAU))
            src += saw(fm * 2 ** (c / 1200) * vib, rng.random())
    swell_raw = np.clip((t - 0.1) / 2.1, 0, 1)
    formant = (sweep(src, "bp", 750, 6) + 0.55 * sweep(src, "bp", 1150, 8) + 0.28 * sweep(src, "bp", 2800, 10)
               + 0.12 * sweep(src, "bp", 3500, 12) + 0.35 * lpf(src, 700))
    choir = sweep(formant, "lp", 1200 + 3000 * swell_raw, 0.7)
    swell = swell_raw ** 1.6 * env_pts(t, [(0, 1), (2.25, 1), (2.5, 0.5)])
    choir = choir * swell
    sub = sine(np.full(n, midi_hz(38))) * swell
    sparkle = crackle(n, rng, lambda tt: 20 + 300 * np.clip(tt / 2.2, 0, 1) ** 2, 3000, 10000, (0.005, 0.02), "ping")
    riser = sweep(white(n, rng), "bp", 300 * 2 ** (4 * np.clip(t / 2.3, 0, 1)), 2.0) * swell
    y = mixp((gong, 0), (choir, -3), (sub, -12), (riser, -16), (sparkle, -18))
    y = sat(nrm(y), 1.3)
    y = reverb(y, 2.2, 0.28)
    return y * env_pts(t, [(0, 1), (2.3, 1), (2.5, 0.3)])


# ------------------------------------------------------------------ Kanzaki Ren --------------

def _friction(n, rng, rate=250.0):
    return white(n, rng) * (0.35 + 0.65 * np.abs(smooth_noise(n, rng, rate)))


@sfx("ren_unsheathe", 0.6)
def _ren_unsheathe(rng, t):
    n = len(t)
    ts = 0.27
    x = np.clip(t / ts, 0, 1)
    fr = _friction(n, rng)
    scrape = metal_bank(fr, 1350 + 450 * x, (1, 2.76, 5.40), (1, .6, .3), 30)
    scrape = scrape + 0.15 * nrm(bnoise(n, rng, 4500 + 1500 * x, 1.5)) * peak(scrape)
    scrape = scrape * np.where(t < ts, x ** 1.4, np.exp(-(t - ts) / 0.01))
    s = T(0.6 - ts)
    R, A, D = [1, 2.76, 5.40], [1, .5, .25], [.45, .24, .12]
    ring = np.zeros(n)
    place(ring, partials(s, 1950, R, A, D, rng=rng) + 0.6 * partials(s, 1950 * 1.0025, R, A, D, rng=rng)
          + 0.35 * partials(s, 1950 * 0.5, [1.0], [1.0], [0.3], rng=rng), ts)
    click = np.zeros(n)
    place(click, hpf(white(len(s), rng), 4000) * env_exp(s, 0.0015, 0.0002), ts)
    motion = bnoise(n, rng, 900 + 1800 * x, 1.2) * env_gamma(t, 0.2, 2.0)
    y = mixp((scrape, -4), (ring, 0), (click, -9), (motion, -14))
    y = reverb(y, 1.0, 0.18)
    return y * env_pts(t, [(0, 1), (0.42, 1), (0.6, 0)])


@sfx("ren_sheathe", 0.3)
def _ren_sheathe(rng, t):
    n = len(t)
    ts = 0.06
    x = np.clip(t / ts, 0, 1)
    scrape = metal_bank(_friction(n, rng), 1900 - 300 * x, (1, 2.76, 5.40), (1, .6, .35), 25)
    scrape = scrape * np.where(t < ts, x ** 1.2, np.exp(-(t - ts) / 0.005))
    s = T(0.3 - ts)
    click = np.zeros(n)
    place(click, nrm(hpf(white(len(s), rng), 3500) * env_exp(s, 0.0015, 0.0002))
          + partials(s, 3300, [1, 1.55, 2.24], [1, .6, .4], [.009, .006, .004]), ts)
    s2 = T(0.3 - ts - 0.018)
    clack = np.zeros(n)
    place(clack, partials(s2, 880, [1, 2.15, 3.1], [1, .6, .35], [.025, .016, .01], rng=rng)
          + 0.7 * thump(s2, 260, 150, 0.01, 0.03)
          + 0.4 * nrm(bpf(white(len(s2), rng), 1000, 4000) * env_exp(s2, 0.008, 0.0003)), ts + 0.018)
    ring = np.zeros(n)
    place(ring, partials(s, 2600, [1, 2.76], [1, .4], [.09, .05], rng=rng), ts)
    return mixp((scrape, -6), (click, 0), (clack, -2), (ring, -14))


@sfx("ren_slash", 0.3)
def _ren_slash(rng, t):
    n = len(t)
    e = env_gamma(t, 0.065, 3.0)
    fc = 1200 + 2600 * env_gamma(t, 0.07, 2.0)
    main = bnoise(n, rng, fc, 1.8) * e
    whistle = sweep(white(n, rng), "bp", fc * 1.25, 12) * env_gamma(t, 0.07, 3.5)
    edge = ((np.sin(TAU * 3150 * t) + 0.6 * np.sin(TAU * 4830 * t + 1) + 0.3 * np.sin(TAU * 7870 * t + 2))
            * env_gamma(t, 0.07, 3.0) * (0.8 + 0.2 * np.sin(TAU * 60 * t)))
    body = bnoise(n, rng, fc * 0.3, 1.3) * env_gamma(t, 0.075, 2.5)
    return hpf(mixr((main, 0), (whistle, -9), (edge, -15), (body, -6)), 200)


@sfx("ren_slash_hit", 0.35)
def _ren_slash_hit(rng, t):
    n = len(t)
    cut = sweep(white(n, rng), "bp", 1500 + 8000 * np.exp(-t / 0.02), 1.1) * env_exp(t, 0.03, 0.0004)
    flesh = thump(t, 150, 60, 0.02, 0.07)
    thwack = bpf(white(n, rng), 400, 1600) * env_exp(t, 0.025, 0.0008)
    sheen = partials(t, 3300, [1, 2.76, 5.4], [1, .5, .3], [.12, .07, .04], rng=rng)
    crack = hpf(white(n, rng), 3000) * env_exp(t, 0.002, 0.0002)
    y = mixp((cut, 0), (flesh, -2), (thwack, -6), (sheen, -13), (crack, -8))
    y = sat(nrm(y), 2.2)
    return reverb(y, 0.6, 0.12)


@sfx("ren_ash_gain", 0.5)
def _ren_ash_gain(rng, t):
    n = len(t)
    grains = crackle(n, rng, lambda tt: 3000 * env_gamma(tt, 0.2, 1.6), 700, 5000, (0.0008, 0.005), "mix",
                     fscale=lambda tt: 1.0 - 0.45 * min(tt / 0.5, 1.0))
    grains = lpf(hpf(grains, 400), 7000)
    e = env_gamma(t, 0.22, 1.8)
    hiss = bnoise(n, rng, 4500 - 3000 * np.clip(t / 0.45, 0, 1), 1.2) * e
    sift = bpf(colored(n, rng, 1.0), 300, 1500) * env_gamma(t, 0.25, 1.5)
    y = mixr((grains, 0), (hiss, -8), (sift, -9))
    return y * env_pts(t, [(0, 1), (0.42, 1), (0.5, 0)])


@sfx("ren_ash_wave", 0.8)
def _ren_ash_wave(rng, t):
    n = len(t)
    e = env_gamma(t, 0.13, 1.4)
    fc = np.where(t < 0.12, 800 + 1700 * (t / 0.12), 450 + 2050 * np.exp(-(t - 0.12) / 0.22))
    main = bnoise(n, rng, fc, 1.1) * e
    grit = bpf(crackle(n, rng, lambda tt: 4500 * env_gamma(tt, 0.13, 1.4), 1200, 7000, (0.0005, 0.003), "noise",
                       amp=lambda tt: 0.4 + 0.6 * float(env_gamma(np.array(tt), 0.13, 1.4))), 900, 8000)
    low = lpf(white(n, rng), 300) * env_gamma(t, 0.15, 1.5)
    body = sat(nrm(mixr((main, 0), (grit, -4), (low, -6))), 2.5)
    onset = (sweep(white(n, rng), "bp", 2500 + 7000 * np.exp(-t / 0.015), 1.2) * env_exp(t, 0.02, 0.0003)
             + 0.5 * partials(t, 3800, [1, 2.76, 5.4], [1, .5, .3], [.1, .06, .035], rng=rng))
    y = mixp((body, 0), (onset, -6))
    return y * env_pts(t, [(0, 1), (0.65, 1), (0.8, 0.3)])


@sfx("ren_smoke", 1.2)
def _ren_smoke(rng, t):
    n = len(t)
    puff = sweep(white(n, rng), "lp", 250 + 1300 * np.exp(-t / 0.1), 0.8) * env_exp(t, 0.2, 0.008)
    whomp = thump(t, 90, 45, 0.03, 0.09)
    mid = bpf(white(n, rng), 200, 900) * env_gamma(t, 0.035, 1.5)
    turb = 0.6 + 0.4 * smooth_noise(n, rng, 8)
    hiss = lpf(hpf(colored(n, rng, 0.6), 2200), 9000) * (1 - np.exp(-t / 0.02)) * np.exp(-t / 0.42) * turb
    grit = bpf(crackle(n, rng, lambda tt: 600 * np.exp(-tt / 0.35), 1500, 6000, (0.0005, 0.002), "noise"), 1200, 7000)
    y = mixp((puff, 0), (whomp, -5), (mid, -4), (hiss, -12), (grit, -18))
    y = reverb(y, 1.0, 0.18)
    return y * env_pts(t, [(0, 1), (0.9, 1), (1.2, 0.3)])


@sfx("ren_seal_tick", 0.25)
def _ren_seal_tick(rng, t):
    n = len(t)
    click = hpf(white(n, rng), 3000) * env_exp(t, 0.0012, 0.0001)
    metal = partials(t, 2400, [1, 2.76, 5.40], [1, .5, .3], [.06, .035, .018], rng=rng)
    # "red" resonance: D5 with a minor third (F5) glow and a sub-octave -> ominous, clearly pitched
    res = (np.sin(TAU * 587.33 * t) + 0.4 * np.sin(TAU * 698.46 * t + 0.5) + 0.3 * np.sin(TAU * 293.66 * t)) \
        * env_exp(t, 0.09, 0.003)
    glow = sweep(white(n, rng), "bp", 587.33, 40) * env_exp(t, 0.12, 0.002)
    y = mixp((click, -3), (metal, 0), (res, -5), (glow, -12))
    return reverb(y, 0.6, 0.15)


@sfx("ren_max_output", 2.0)
def _ren_max_output(rng, t):
    n = len(t)
    t0 = 0.10                                     # the "tiny silence gap" before the cut
    s = T(2.0 - t0)
    m = len(s)
    crack = hpf(white(m, rng), 3000) * env_exp(s, 0.004, 0.0002)
    R, A, D = [1, 2.76, 5.40, 8.93], [1, .6, .4, .22], [0.9, .55, .3, .14]
    shing = partials(s, 1650, R, A, D, rng=rng) + 0.7 * partials(s, 1650 * 1.003, R, A, D, rng=rng)
    rush = sweep(white(m, rng), "bp", 600 + 9000 * np.exp(-s / 0.07), 0.9) * env_exp(s, 0.25, 0.002)
    rush2 = sweep(white(m, rng), "bp", 300 + 3000 * np.exp(-s / 0.15), 0.8) * env_gamma(s, 0.06, 1.2)
    boom = thump(s, 95, 26, 0.08, 0.55)
    sub = thump(s, 50, 27, 0.2, 0.8)
    rumble = lpf(colored(m, rng, 2.0), 120) * (1 - np.exp(-s / 0.05)) * np.exp(-s / 0.7)
    ash = crackle(m, rng, lambda tt: 350 * env_gamma(tt, 0.5, 1.2), 1500, 7000, (0.001, 0.005), "mix")
    core = mixp((boom, 0), (sub, -2), (rush, -1), (rush2, -5), (crack, -4), (shing, -9), (rumble, -6), (ash, -20))
    core = sat(nrm(core), 2.6)
    core = reverb(core, 2.6, 0.4)
    core = core * env_pts(s, [(0, 1), (1.3, 1), (1.9, 0.15)])
    y = np.zeros(n)
    place(y, core, t0)
    return y


@sfx("ren_awaken", 2.5)
def _ren_awaken(rng, t):
    n = len(t)
    x = np.clip(t / 2.25, 0, 1)
    drone = (saw(np.full(n, midi_hz(38))) + 0.7 * saw(np.full(n, midi_hz(39)), 0.3)
             + 0.8 * saw(np.full(n, midi_hz(26)), 0.6))
    drone = sweep(drone, "lp", 250 + 2200 * x ** 2, 1.2)
    drone = lpf(sat(nrm(drone), 5.0), 5000)
    fr = _friction(n, rng, 180)
    scrape = metal_bank(fr, 700 * 2 ** (1.9 * x ** 1.3), (1, 2.76, 5.40), (1, .6, .35), 28)
    riser = sweep(white(n, rng), "bp", 300 * 2 ** (3.8 * x), 2.0) * x ** 2
    env = smoothstep(t / 0.3) * (0.4 + 0.6 * x ** 1.2) * np.where(t < 2.25, 1.0, np.exp(-(t - 2.25) / 0.03))
    th = 2.25
    s = T(2.5 - th)
    hit = np.zeros(n)
    place(hit, partials(s, 1900, [1, 2.76, 5.40, 8.93], [1, .55, .35, .2], [.5, .3, .15, .08], rng=rng)
          + 0.8 * nrm(hpf(white(len(s), rng), 3000) * env_exp(s, 0.003, 0.0002))
          + 0.9 * thump(s, 90, 35, 0.04, 0.2), th)
    boom = thump(t, 80, 30, 0.06, 0.5)
    y = mixp((drone * env, 0), (scrape * env, -5), (riser * env, -12), (hit, -3), (boom, -7))
    return reverb(y, 1.8, 0.25)


# =============================================================================================
#  MUSIC  -- tiny sequencer + instruments
# =============================================================================================

def pan_gains(p: float):
    a = (p + 1.0) * math.pi / 4.0
    return math.cos(a), math.sin(a)


def active_rms(x: np.ndarray, frame: float = 0.25, rel_db: float = -35.0) -> float:
    p = x ** 2 if x.ndim == 1 else np.mean(x ** 2, axis=1)
    F = N(frame)
    k = len(p) // F
    fr = p[:k * F].reshape(k, F).mean(axis=1)
    if fr.max() <= 0:
        return 1e-12
    act = fr[fr > fr.max() * 10 ** (rel_db / 10)]
    return float(np.sqrt(np.mean(act))) + 1e-12


def duck_env(n: int, starts, depth=0.5, rel=0.16, att=0.004) -> np.ndarray:
    """Side-chain style gain envelope that dips at each kick."""
    e = np.ones(n)
    k = np.arange(N(rel * 5)) / SR
    shape = 1.0 - depth * (1 - np.exp(-k / att)) * np.exp(-k / rel)
    for s in starts:
        if s >= n:
            continue
        seg = e[s:s + len(shape)]
        np.minimum(seg, shape[:len(seg)], out=seg)
    return e


class Song:
    def __init__(self, name: str, bpm: float, bars: int, seed: int, tail: float = 7.0):
        self.name = name
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.L = int(round(bars * 4 * self.beat * SR))
        self.n = self.L + N(tail)
        self.buses: dict[str, np.ndarray] = {}
        self.rng = np.random.default_rng(seed)

    def sec(self, bar: float, beat: float = 0.0) -> float:
        return (bar * 4 + beat) * self.beat

    def s(self, bar: float, beat: float = 0.0) -> int:
        return int(round(self.sec(bar, beat) * SR))

    def st(self, bar: int, step: float) -> int:          # 16th-note steps
        return self.s(bar, step / 4.0)

    def put(self, bus: str, sig: np.ndarray, i: int, gain: float = 1.0, pan: float = 0.0) -> None:
        if i < 0:
            i += self.L                                   # anything before t=0 belongs to the loop's end
        b = self.buses.setdefault(bus, np.zeros((self.n, 2), dtype=np.float32))
        m = min(len(sig), self.n - i)
        if m <= 0:
            return
        if sig.ndim == 1:
            gl, gr = pan_gains(pan)
            b[i:i + m, 0] += (gain * gl) * sig[:m]
            b[i:i + m, 1] += (gain * gr) * sig[:m]
        else:
            b[i:i + m] += gain * sig[:m]

    def mixdown(self, levels: dict, sends: dict, rt60: float, damp: float = 0.6, predelay: float = 0.02,
                glue: float = 1.4, fx: dict | None = None, hp: dict | None = None, air: float = 0.0) -> np.ndarray:
        out = np.zeros((self.n, 2))
        rv = np.zeros((self.n, 2))
        for name, b in self.buses.items():
            b = hpf(b.astype(np.float64), (hp or {}).get(name, 30.0), 2)   # linear -> still loops seamlessly
            if fx and name in fx:
                b = fx[name](b)
            g = db(levels[name]) / active_rms(b)
            out += b * g
            if sends.get(name, 0.0) > 0:
                rv += b * (g * sends[name])
        ir = make_ir(rt60, seed=11, stereo=True, damp=damp, predelay=predelay)
        out[:, 0] += signal.fftconvolve(rv[:, 0], ir[:, 0])[:self.n]
        out[:, 1] += signal.fftconvolve(rv[:, 1], ir[:, 1])[:self.n]
        # seamless loop: wrap everything that rings past the loop end back onto the start
        y = out[:self.L].copy()
        tail = out[self.L:]
        y[:len(tail)] += tail
        # master: circular DC/sub-sonic high-pass, gentle tanh glue, peak normalise
        P = N(1.0)
        z = hpf(np.concatenate([y[-P:], y], axis=0), 28.0, 2)
        if air:
            z = eq(z, "hs", 6500.0, 0.707, air)
        z = z[P:]
        z = z / peak(z)
        z = np.tanh(glue * z) / math.tanh(glue)
        return z * (db(MUSIC_PEAK_DB) / peak(z))


# ---------------------------------------------------------------- drums ----------------------

def d_kick(rng, f0=150.0, f1=50.0, ptau=0.03, atau=0.22, click=-10.0, drive=1.8, dur=0.5):
    t = T(dur)
    body = thump(t, f0, f1, ptau, atau, attack=0.0008)
    cl = hpf(white(len(t), rng), 1800) * env_exp(t, 0.0025, 0.0001)
    knock = bpf(white(len(t), rng), 900, 4000) * env_exp(t, 0.008, 0.0003)
    y = sat(nrm(mixp((body, 0), (cl, click), (knock, click - 2))), drive)
    return nrm(hpf(y, 32, 2))


def d_snare(rng, tone=185.0, dur=0.32, ntau=0.11):
    t = T(dur)
    n = len(t)
    ft = tone * (1 + 0.4 * np.exp(-t / 0.012))
    body = sine(ft) * env_exp(t, 0.07, 0.0008) + 0.5 * sine(ft * 1.78) * env_exp(t, 0.04, 0.0008)
    nz = bpf(white(n, rng), 1200, 9500) * env_exp(t, ntau, 0.0008)
    sn = hpf(white(n, rng), 5000) * env_exp(t, 0.02, 0.0005)
    return nrm(sat(nrm(mixp((body, -3), (nz, 0), (sn, -6))), 1.6))


def d_hat(rng, open_=False):
    dur = 0.45 if open_ else 0.08
    t = T(dur)
    n = len(t)
    metal = sum(pulse(np.full(n, f * 1.4), 0.5, rng.random()) for f in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0))
    y = mixr((bpf(metal, 6500, 16000), 0), (hpf(white(n, rng), 7000), -3))
    return nrm(y * env_exp(t, 0.16 if open_ else 0.02, 0.0004))


def d_clap(rng):
    t = T(0.35)
    n = len(t)
    e = np.zeros(n)
    for k, o in enumerate((0.0, 0.009, 0.018, 0.027)):
        e += (t >= o) * np.exp(-np.maximum(t - o, 0) / 0.006) * (0.7 if k < 3 else 1.0)
    e += (t >= 0.027) * np.exp(-np.maximum(t - 0.027, 0) / 0.09) * 0.45
    return nrm(bpf(white(n, rng), 900, 5000) * e)


def d_crash(rng, dur=2.4, lo=2500.0):
    t = T(dur)
    n = len(t)
    nz = hpf(white(n, rng), 4000)
    metal = np.zeros(n)
    for _ in range(48):
        f = math.exp(rng.uniform(math.log(2000), math.log(12000)))
        metal += np.sin(TAU * f * t + rng.uniform(0, TAU)) * np.exp(-t / rng.uniform(0.4, 1.3))
    y = mixr((nz, 0), (metal, -4))
    y = y * (env_exp(t, 0.8, 0.001) + 0.6 * env_exp(t, 0.05, 0.001))
    return nrm(hpf(lpf(y, 14000), lo))


def d_ride(rng):
    t = T(0.9)
    n = len(t)
    ping = partials(t, 2900, [1, 1.47, 2.09, 2.71], [1, .6, .5, .3], [.5, .4, .3, .2], rng=rng)
    wash = hpf(white(n, rng), 5000) * env_exp(t, 0.25, 0.001)
    return nrm(mixp((ping, 0), (wash, -8)))


def d_tom(rng, f=110.0):
    t = T(0.6)
    body = thump(t, f * 1.6, f, 0.03, 0.22)
    skin = bpf(white(len(t), rng), 200, 2000) * env_exp(t, 0.03, 0.0008)
    return nrm(sat(nrm(mixp((body, 0), (skin, -8))), 1.5))


def d_taiko(rng, f=62.0, size=1.0, dur=1.4):
    t = T(dur)
    n = len(t)
    body = thump(t, f * 1.7, f, 0.025, 0.35 * size)
    mode2 = sine(np.full(n, f * 1.52)) * env_exp(t, 0.12 * size, 0.001)
    skin = lpf(white(n, rng), 1800) * env_exp(t, 0.03, 0.0005)
    slap = bpf(white(n, rng), 400, 2500) * env_exp(t, 0.008, 0.0003)
    return nrm(sat(nrm(mixp((body, 0), (mode2, -10), (skin, -6), (slap, -7))), 1.5))


def d_shime(rng):
    t = T(0.2)
    y = mixp((thump(t, 520, 400, 0.01, 0.06), 0), (hpf(white(len(t), rng), 2000) * env_exp(t, 0.006, 0.0003), -4))
    return nrm(y)


def d_kachi(rng):
    t = T(0.12)
    y = mixp((bpf(white(len(t), rng), 1800, 6000) * env_exp(t, 0.006, 0.0002), 0),
             (partials(t, 1750, [1, 2.3], [1, .5], [.02, .01]), -3))
    return nrm(y)


def d_bo(rng, dur=1.2):
    """Chinese 'bo' cymbal: trashier, shorter, lower than a crash."""
    t = T(dur)
    n = len(t)
    nz = bpf(white(n, rng), 1200, 9000)
    metal = np.zeros(n)
    for _ in range(40):
        f = math.exp(rng.uniform(math.log(600), math.log(6000)))
        metal += np.sin(TAU * f * t + rng.uniform(0, TAU)) * np.exp(-t / rng.uniform(0.15, 0.6))
    y = mixr((nz, 0), (metal, -2)) * (env_exp(t, 0.35, 0.001) + 0.5 * env_exp(t, 0.03, 0.001))
    return nrm(sat(nrm(y), 1.5))


def d_shaker(rng):
    t = T(0.09)
    return nrm(hpf(white(len(t), rng), 5000) * env_gamma(t, 0.012, 2.0))


def fx_riser(dur, rng, f0=300.0, f1=6000.0):
    t = T(dur)
    x = np.clip(t / dur, 0, 1)
    y = sweep(white(len(t), rng), "bp", f0 * (f1 / f0) ** x, 2.0, block=128) * x ** 2
    return nrm(fades(y, 0.01, 0.01))


def fx_revcym(dur, rng):
    c = d_crash(rng, dur + 0.2)[:N(dur)][::-1].copy()
    t = T(dur)
    return nrm(c * (t / dur) ** 1.5)


def fx_boom(rng):
    t = T(1.8)
    y = mixp((thump(t, 75, 28, 0.08, 0.6), 0),
             (lpf(white(len(t), rng), 200) * (1 - np.exp(-t / 0.02)) * np.exp(-t / 0.4), -8))
    return nrm(sat(nrm(y), 1.6))


def scrape_tex(dur, rng, f0, f1):
    t = T(dur)
    x = np.clip(t / dur, 0, 1)
    y = metal_bank(_friction(len(t), rng, 150), f0 * (f1 / f0) ** x, (1, 2.76, 5.40), (1, .5, .3), 30)
    return nrm(y * smoothstep(t / 0.3) * smoothstep((dur - t) / 0.3))


class Kit:
    """Pre-renders a few variants of each drum so repeated hits are not identical."""

    def __init__(self, rng, **makers):
        self.rng = rng
        self.v = {k: [fn(np.random.default_rng(rng.integers(1 << 31))) for _ in range(3)]
                  for k, fn in makers.items()}

    def __call__(self, name):
        vs = self.v[name]
        return vs[int(self.rng.integers(len(vs)))]


# ---------------------------------------------------------------- tonal instruments ----------

def pluck(f, dur, rng, bright=0.5, decay=1.6, pos=0.2, pick=0.2, vib=0.0, bend=0.0, bend_t=0.25,
          twang=0.0, max_h=28):
    """Additive plucked string (guzheng / koto flavours)."""
    t = T(dur)
    n = len(t)
    semis = np.zeros(n)
    if twang:
        semis += twang * np.exp(-t / 0.025)
    if bend:
        semis += bend * smoothstep((t - bend_t) / 0.12)
    if vib:
        semis += vib * np.clip((t - 0.35) / 0.4, 0, 1) * np.sin(TAU * 5.2 * t)
    ph = phase_of(f * 2 ** (semis / 12))
    y = np.zeros(n)
    for k in range(1, max_h + 1):
        if k * f > 15000:
            break
        a = abs(math.sin(math.pi * k * pos)) / k ** (1.6 - bright)
        dk = decay / (1 + (k - 1) * (0.18 + 0.6 * (1 - bright)))
        y += a * np.exp(-t / dk) * np.sin(TAU * k * ph + rng.uniform(-0.3, 0.3))
    y *= np.clip(t / 0.0015, 0, 1)
    if pick > 0:
        y += pick * peak(y) * nrm(bpf(white(n, rng), 1500, 9000) * env_exp(t, 0.004, 0.0002))
    return fades(y, 0.0, 0.04)


def pad(midis, dur, rng, cutoff=1400.0, attack=0.8, release=1.2, detune=10.0, voices=3, vib=0.0, width=0.8):
    tot = dur + release
    t = T(tot)
    n = len(t)
    L = np.zeros(n)
    R = np.zeros(n)
    for m in midis:
        f = float(midi_hz(m))
        for v in range(voices):
            u = (v / (voices - 1)) * 2 - 1 if voices > 1 else 0.0
            c = u * detune + rng.uniform(-1.5, 1.5)
            ff = np.full(n, f * 2 ** (c / 1200))
            if vib:
                ff = ff * (1 + vib * np.sin(TAU * rng.uniform(4.5, 5.8) * t + rng.uniform(0, TAU)))
            o = saw(ff, rng.random())
            gl, gr = pan_gains(u * width)
            L += o * gl
            R += o * gr
    st = lpf(np.stack([L, R], axis=1), cutoff, 2)
    a = N(attack)
    env = np.ones(n)
    env[:a] = np.sin(np.linspace(0, math.pi / 2, a)) ** 2
    d = N(dur)
    env[d:] = np.cos(np.linspace(0, math.pi / 2, n - d)) ** 2
    return st * env[:, None]


def soft_bass(f, dur, rng, attack=0.08):
    t = T(dur + 0.4)
    y = sine(np.full(len(t), f)) + 0.25 * sine(np.full(len(t), 2 * f), 0.25) + 0.08 * sine(np.full(len(t), 3 * f))
    env = smoothstep(t / attack) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.1))
    return y * env


def bass_synth(f, dur, rng, cutoff=380.0, env_amt=900.0, tau=0.09, drive=2.0, sub=0.8, rel=0.025):
    t = T(dur + rel)
    n = len(t)
    x = saw(np.full(n, f), rng.random()) + 0.6 * pulse(np.full(n, f * 1.004), 0.5, rng.random())
    x = sweep(x, "lp", cutoff + env_amt * np.exp(-t / tau), 1.1, block=128)
    y = np.tanh(drive * (0.7 * nrm(x) + 0.7 * sub * np.sin(TAU * f * t)))
    env = np.clip(t / 0.003, 0, 1) * np.where(t < dur, 1.0, np.clip(1 - (t - dur) / rel, 0, 1))
    return y * env


def synth_pluck(f, dur, rng, cutoff=2600.0, tau=0.06, decay=0.2):
    t = T(dur)
    n = len(t)
    x = pulse(np.full(n, f), 0.35, rng.random()) + 0.5 * saw(np.full(n, f * 1.005), rng.random())
    x = sweep(x, "lp", 300 + cutoff * np.exp(-t / tau), 1.4, block=128)
    return fades(x * env_exp(t, decay, 0.002), 0.0, 0.01)


def brass(midis, dur, rng, bright=2600.0):
    t = T(dur + 0.25)
    n = len(t)
    x = np.zeros(n)
    for m in midis:
        for c in (-6.0, 5.0):
            x += saw(np.full(n, float(midi_hz(m)) * 2 ** (c / 1200)), rng.random())
    fc = 400 + bright * (1 - np.exp(-t / 0.03)) * np.exp(-t / 0.3) + 300
    x = sweep(x, "lp", fc, 0.9, block=128)
    env = smoothstep(t / 0.02) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.06))
    return np.tanh(1.3 * nrm(x)) * env


def guitar(root, dur, rng, mute=False, vel=1.0):
    """Distorted power-chord 'guitar' (saws -> tanh -> cabinet-ish EQ)."""
    t = T(dur + (0.02 if mute else 0.08))
    n = len(t)
    notes = (root, root + 7) if mute else (root, root + 7, root + 12)
    x = np.zeros(n)
    for m in notes:
        for det in (-7.0, 6.0):
            x += saw(np.full(n, float(midi_hz(m)) * 2 ** (det / 1200)), rng.random()) * (1.0 if m == root else 0.8)
    x += 0.8 * nrm(hpf(white(n, rng), 2000) * env_exp(t, 0.004, 0.0002)) * 2
    if mute:
        x = lpf(x, 1000, 2)
        env = env_exp(t, 0.07, 0.002)
    else:
        env = np.clip(t / 0.003, 0, 1) * np.exp(-t / 2.5) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.015))
    x = hpf(x * env, 90)
    x = np.tanh(9.0 * vel * x / 3.0 + 0.15) - math.tanh(0.15)
    x = eq(x, "peak", 1600, 1.0, 3.0)
    x = eq(x, "peak", 450, 1.2, -3.0)
    x = lpf(x, 4800, 4)
    return hpf(x, 70) * vel


# ---------------------------------------------------------------- legato lead lines ----------

def render_line(notes, synth, rng, glide=0.04, vib_depth=0.25, vib_rate=5.5, vib_delay=0.2, attack=0.03,
                release=0.18, gap=0.02, scoop=0.0, scoop_tau=0.05, dip=0.25):
    """notes: (start_s, dur_s, midi, vel). Consecutive notes form legato phrases (pitch glides, vibrato)."""
    notes = sorted(notes)
    phrases, cur = [], [notes[0]]
    for nt in notes[1:]:
        prev = cur[-1]
        if nt[0] - (prev[0] + prev[1]) <= gap:
            cur.append(nt)
        else:
            phrases.append(cur)
            cur = [nt]
    phrases.append(cur)
    out = []
    for ph in phrases:
        t0 = ph[0][0]
        end = ph[-1][0] + ph[-1][1]
        n = N(end - t0 + release + 0.05)
        t = np.arange(n) / SR
        target = np.full(n, float(ph[0][2]))
        amp = np.zeros(n)
        vibe = np.zeros(n)
        sc = np.zeros(n)
        for j, (s, d, m, v) in enumerate(ph):
            a = N(s - t0)
            b = N(ph[j + 1][0] - t0) if j + 1 < len(ph) else N(s + d - t0)
            target[a:] = m
            tt = np.arange(b - a) / SR
            if j == 0:
                shape = 1 - np.exp(-tt / attack)
            else:
                shape = 1 - dip * np.exp(-tt / 0.035)
            amp[a:b] = v * shape
            vibe[a:b] = np.clip((tt - vib_delay) / 0.3, 0, 1)
            if scoop:
                sc[a:b] = -scoop * np.exp(-tt / scoop_tau)
        be = N(end - t0)
        last = amp[be - 1] if be > 0 else 0.0
        amp[be:] = last * np.exp(-np.arange(n - be) / SR / (release / 4))
        amp = one_pole(amp, 0.004)
        pitch = one_pole(target, glide) + sc + vib_depth * vibe * np.sin(TAU * vib_rate * t + rng.uniform(0, TAU))
        sig = synth(midi_hz(pitch), t, rng) * amp
        out.append((t0, sig))
    return out


def syn_erhu(f, t, rng):
    n = len(t)
    x = saw(f, rng.random()) + 0.25 * pulse(f, 0.3, rng.random())
    x = x + 0.05 * bpf(white(n, rng), 2000, 7000) * (1 + 0.6 * smooth_noise(n, rng, 30))
    x = eq(x, "peak", 700, 1.4, 6.0)
    x = eq(x, "peak", 1750, 2.0, 4.0)
    x = eq(x, "peak", 3200, 3.0, 3.0)
    return lpf(hpf(x, 280, 2), 5200, 2)


def syn_dizi(f, t, rng):
    n = len(t)
    ph = phase_of(f, rng.random())
    x = np.sin(TAU * ph) + 0.3 * np.sin(2 * TAU * ph) + 0.14 * np.sin(3 * TAU * ph) + 0.06 * np.sin(4 * TAU * ph)
    breath = 0.22 * sweep(white(n, rng), "bp", f, 3.0, block=128) + 0.02 * hpf(white(n, rng), 6000)
    buzz = 0.12 * bpf(np.tanh(3 * x), 2500, 7000)          # dimo membrane buzz
    return x + breath + buzz


def syn_shaku(f, t, rng):
    n = len(t)
    ph = phase_of(f, rng.random())
    x = np.sin(TAU * ph) + 0.18 * np.sin(2 * TAU * ph) + 0.05 * np.sin(3 * TAU * ph)
    breath = 0.45 * sweep(white(n, rng), "bp", f, 1.8, block=128) + 0.06 * bpf(white(n, rng), 1500, 5000)
    return x + breath


def syn_lead(f, t, rng):
    x = saw(f * 2 ** (7 / 1200), rng.random()) + saw(f * 2 ** (-7 / 1200), rng.random()) \
        + 0.45 * pulse(f * 0.5, 0.5, rng.random())
    return np.tanh(1.5 * lpf(x, 3800, 2))


def syn_lead_ren(f, t, rng):
    x = saw(f, rng.random()) + saw(f * 2 ** (11 / 1200), rng.random()) + 0.3 * saw(f * 2, rng.random())
    x = np.tanh(3.5 * hpf(x, 250))
    return eq(lpf(x, 4800, 2), "peak", 2400, 1.2, 3.0)


def put_line(S: Song, bus: str, notes, synth, gain=1.0, pan=0.0, **kw):
    for t0, sig in render_line(notes, synth, S.rng, **kw):
        S.put(bus, sig, N(t0), gain, pan)


def ladder(pcs, lo, hi):
    return [m for m in range(lo, hi + 1) if m % 12 in pcs]


def bass_root(m):
    while m > 47:
        m -= 12
    while m < 36:
        m += 12
    return m


def pingpong(x: np.ndarray, delay_s: float, fb=0.35, taps=5, lp=3500.0) -> np.ndarray:
    d = N(delay_s)
    out = x.copy()
    echo = x.mean(axis=1)
    for k in range(1, taps + 1):
        echo = lpf(echo, lp, 1)
        sh = d * k
        if sh >= len(x):
            break
        out[sh:, (k - 1) % 2] += (fb ** k) * echo[:-sh]
    return out


def loop_bed(S: Song, bus: str, sig_fn, xf: float = 3.0, gain=1.0):
    """Continuous bed (wind etc.) rendered L+xf long with equal-power crossfade across the loop seam."""
    n = S.L + N(xf)
    sig = sig_fn(n)
    k = N(xf)
    w = np.linspace(0, math.pi / 2, k)
    sig[:k] *= np.sin(w)
    sig[S.L:S.L + k] *= np.cos(w)
    S.put(bus, sig, 0, gain)


# =============================================================================================
#  music_lobby  (80 BPM, 24 bars = 72 s)  warm pads + guzheng/koto + dizi/shakuhachi
# =============================================================================================

LOBBY_CHORDS = [
    [50, 57, 64, 66, 69], [47, 54, 57, 62, 64], [43, 50, 57, 59, 66], [45, 52, 57, 62, 64],
    [50, 57, 64, 66, 69], [42, 49, 57, 61, 64], [43, 50, 54, 59, 62], [45, 52, 57, 61, 64],
    [50, 57, 62, 67], [51, 58, 62, 67], [43, 50, 58, 69], [50, 57, 63, 67],
    [48, 55, 58, 62, 63], [51, 58, 62, 69], [43, 50, 58, 62, 65], [45, 52, 57, 62, 64],
    [43, 50, 57, 59, 66], [45, 52, 59, 62, 66], [47, 54, 57, 62, 66], [42, 50, 57, 64, 66],
    [43, 50, 54, 59, 62], [39, 51, 58, 62, 69], [45, 52, 57, 62, 64], [45, 52, 57, 61, 64],
]
PENTA = {2, 4, 6, 9, 11}          # D major pentatonic (Chinese gong mode)
INSEN = {2, 3, 7, 9, 10}          # D miyako-bushi (Japanese)
INSEN_C = {0, 2, 3, 7, 10}


def music_lobby() -> tuple[np.ndarray, Song]:
    S = Song("lobby", 80, 24, seed=101)
    rng = S.rng
    scales = [PENTA] * 8 + [INSEN] * 4 + [INSEN_C] + [INSEN] * 2 + [PENTA] + [PENTA] * 5 + [INSEN] + [PENTA] * 2
    bar = S.sec(1)

    for b, ch in enumerate(LOBBY_CHORDS):
        voicing = [m for m in ch if m >= 48] or ch
        cut = 1300 if b < 8 else (1000 if b < 16 else 1600)
        S.put("pad", pad(voicing, bar, rng, cutoff=cut, attack=0.9, release=1.6, detune=10, voices=3), S.s(b))
        S.put("bass", soft_bass(float(midi_hz(bass_root(ch[0]))), bar * 0.97, rng, attack=0.25), S.s(b))

    contours = [[0, 1, 2, 4, 3, 2, 1, 2], [4, 3, 2, 3, 1, 0, 1, None],
                [0, 2, 1, 3, 2, 4, 3, 5], [5, 4, 2, 3, 1, 2, 0, None]]
    koto_c = [[0, None, 2, 1, None, 3, None, 2], [3, None, 2, None, 1, 0, None, None],
              [0, 1, None, 3, None, 2, 1, None], [2, None, None, 1, 0, None, -1, None]]
    for b in range(24):
        lad = ladder(scales[b], 60, 88)
        pcs = {m % 12 for m in LOBBY_CHORDS[b]}
        cands = [i for i, m in enumerate(lad) if m % 12 in pcs] or list(range(len(lad)))
        anchor = min(cands, key=lambda i: abs(lad[i] - 71))
        is_koto = 8 <= b < 16
        pat = (koto_c if is_koto else contours)[b % 4]
        for i, off in enumerate(pat):
            if off is None:
                continue
            idx = int(np.clip(anchor + off, 0, len(lad) - 1))
            m = lad[idx]
            start = S.s(b, i * 0.5) + int(rng.normal(0, 0.004) * SR)
            vel = (0.85 if i % 2 == 0 else 0.65) * rng.uniform(0.9, 1.05)
            if is_koto:
                nxt = pat[i + 1] if i + 1 < len(pat) else None
                bend = 0.0
                if nxt is None and idx + 1 < len(lad) and lad[idx + 1] - m <= 2 and rng.random() < 0.6:
                    bend = float(lad[idx + 1] - m)
                sig = pluck(float(midi_hz(m)), 1.6, rng, bright=0.72, decay=1.1, pos=0.12, pick=0.35,
                            twang=0.15, bend=bend, bend_t=0.3)
                S.put("pluck", sig, start, vel, pan=0.3)
            else:
                sig = pluck(float(midi_hz(m)), 2.2, rng, bright=0.45, decay=2.0, pos=0.22, pick=0.18, vib=0.12)
                S.put("pluck", sig, start, vel, pan=-0.35 + 0.3 * (m - 72) / 12)
    # guzheng glissandi sweeping up into bars 0, 8 and 16
    for b in (0, 8, 16):
        lad = ladder(PENTA if b != 8 else INSEN, 60, 90)
        top = min(range(len(lad)), key=lambda i: abs(lad[i] - 81))
        for k in range(8):
            m = lad[max(0, top - 7 + k)]
            S.put("pluck", pluck(float(midi_hz(m)), 1.5, rng, bright=0.45, decay=1.4, pos=0.22, pick=0.12),
                  S.s(b) - N(0.035 * (8 - k)), 0.35 + 0.05 * k, pan=-0.5 + 0.12 * k)

    # shakuhachi (B section, bars 8-15) and dizi (C section, bars 16-23)
    shaku = [(8, 0, 3, 69), (8, 3, 1, 67), (9, 0, 2, 70), (9, 2, 2, 69), (10, 0, 3, 67), (10, 3, 1, 63),
             (11, 0, 3.5, 62), (12, 1, 2, 74), (12, 3, 1, 72), (13, 0, 2, 70), (13, 2, 2, 69),
             (14, 0, 2, 67), (14, 2, 1, 70), (14, 3, 1, 69), (15, 0, 3, 69)]
    put_line(S, "flute", [(S.sec(b, bt), d * S.beat, m, 0.9) for b, bt, d, m in shaku], syn_shaku,
             glide=0.06, vib_depth=0.18, vib_rate=4.5, vib_delay=0.5, attack=0.08, release=0.5, scoop=0.7,
             scoop_tau=0.09, dip=0.35)
    dizi = [(16, 0, 1.5, 74), (16, 1.5, 0.5, 76), (16, 2, 2, 78), (17, 0, 2, 76), (17, 2, 1, 74), (17, 3, 1, 71),
            (18, 0, 3, 74), (18, 3, 1, 69), (19, 0, 1, 69), (19, 1, 1, 71), (19, 2, 2, 74),
            (20, 0, 2, 78), (20, 2, 1, 76), (20, 3, 1, 74), (21, 0, 2, 74), (21, 2, 2, 69),
            (22, 0, 1, 71), (22, 1, 1, 74), (22, 2, 2, 76), (23, 0, 3, 76)]
    put_line(S, "flute", [(S.sec(b, bt), d * S.beat, m, 0.85) for b, bt, d, m in dizi], syn_dizi,
             glide=0.03, vib_depth=0.2, vib_rate=5.3, vib_delay=0.3, attack=0.04, release=0.4, dip=0.3)

    # soft percussion: sparse in A, heartbeat in B, gentle groove in C
    kit = Kit(rng, taiko=lambda r: d_taiko(r, 58, 0.9), frame=lambda r: d_taiko(r, 95, 0.5, 0.8),
              kachi=d_kachi, shaker=d_shaker)
    for b in range(24):
        if b < 8:
            if b % 2 == 0:
                S.put("perc", kit("taiko"), S.s(b), 0.55)
        elif b < 16:
            S.put("perc", kit("taiko"), S.s(b), 0.6)
            S.put("perc", kit("taiko"), S.s(b, 0.5), 0.35)
            if b % 2 == 1:
                S.put("perc", kit("kachi"), S.s(b, 3.5), 0.18, pan=0.4)
        else:
            for bt, g in ((0, 0.65), (2, 0.4), (2.5, 0.3)):
                S.put("perc", kit("taiko"), S.s(b, bt), g)
            for bt in (1.5, 3.5):
                S.put("perc", kit("frame"), S.s(b, bt), 0.22, pan=-0.3)
            for k in range(8):
                S.put("perc", kit("shaker"), S.s(b, k * 0.5 + 0.25), 0.07 + 0.04 * (k % 2), pan=0.45)
    # singing bowl on section downbeats + reverse cymbal swells into them
    for b in (0, 8, 16):
        t = T(6.0)
        bowl = partials(t, 293.66, [1, 2.71, 5.15, 8.3], [1, .5, .25, .1], [3.5, 2.0, 1.0, .6], attack=0.004, rng=rng)
        bowl += partials(t, 293.66 * 1.004, [1, 2.71], [.6, .3], [3.0, 1.8], attack=0.004, rng=rng)
        S.put("bell", bowl, S.s(b), 1.0)
        S.put("swell", fx_revcym(S.sec(0, 2), rng), S.s(b) - S.s(0, 2), 1.0)
    loop_bed(S, "wind", lambda n: bpf(colored(n, rng, 1.0), 150, 1400) * (0.7 + 0.3 * smooth_noise(n, rng, 0.3)))
    # wind chimes at phrase ends (pentatonic, or in-scale in the Japanese section)
    for b in (3, 7, 11, 15, 19, 23):
        lad = ladder(INSEN if 8 <= b < 15 else PENTA, 86, 98)
        for k in range(6):
            m = lad[int(rng.integers(len(lad)))]
            S.put("chime", _bell(T(1.6), float(midi_hz(m)), rng, decay=0.45),
                  S.s(b, 2) + N(k * 0.1 + rng.uniform(0, 0.04)), rng.uniform(0.5, 1.0), pan=rng.uniform(-0.6, 0.6))

    levels = {"pad": -20, "bass": -24, "pluck": -21, "flute": -21, "perc": -25, "bell": -27, "swell": -30,
              "wind": -36, "chime": -31}
    sends = {"pad": 0.3, "pluck": 0.35, "flute": 0.35, "perc": 0.2, "bell": 0.5, "swell": 0.4, "chime": 0.5}
    return S.mixdown(levels, sends, rt60=3.2, damp=0.5, predelay=0.03, glue=1.2, hp={"perc": 40}, air=1.5), S


# =============================================================================================
#  music_battle  (140 BPM, 40 bars = 68.571 s)  driving drums, bass, arps, lead (E minor)
# =============================================================================================

BATTLE_CH = {"Em": (40, [64, 67, 71]), "C": (36, [60, 64, 67]), "D": (38, [62, 66, 69]),
             "Bm": (47, [59, 62, 66]), "Am": (45, [57, 60, 64]), "B": (47, [59, 63, 66]),
             "F": (41, [60, 65, 69])}
BATTLE_PROG = (["Em", "Em", "C", "D"] + ["Em", "C", "D", "Bm", "Em", "C", "Am", "B"]
               + ["C", "D", "Em", "Em", "C", "D", "B", "B"] + ["Am", "Em", "F", "B", "Am", "Em", "F", "B"]
               + ["Em", "C", "D", "Bm", "Em", "C", "Am", "B"] + ["C", "D", "B", "B"])
BATTLE_LEAD = {
    4: [(0, 3, 76), (3, 1, 71), (4, 2, 76), (6, 2, 78), (8, 4, 79), (12, 2, 78), (14, 2, 76)],
    5: [(0, 6, 79), (6, 2, 76), (8, 4, 72), (12, 2, 74), (14, 2, 76)],
    6: [(0, 3, 78), (3, 1, 74), (4, 2, 78), (6, 2, 79), (8, 4, 81), (12, 2, 79), (14, 2, 78)],
    7: [(0, 6, 78), (6, 2, 74), (8, 8, 71)],
    8: [(0, 3, 76), (3, 1, 71), (4, 2, 76), (6, 2, 78), (8, 4, 79), (12, 2, 81), (14, 2, 83)],
    9: [(0, 4, 84), (4, 2, 83), (6, 2, 81), (8, 4, 79), (12, 4, 76)],
    10: [(0, 3, 81), (3, 1, 79), (4, 4, 76), (8, 2, 72), (10, 2, 74), (12, 4, 76)],
    11: [(0, 4, 75), (4, 4, 78), (8, 6, 83)],
    12: [(0, 4, 79), (4, 2, 76), (6, 2, 79), (8, 6, 84), (14, 2, 83)],
    13: [(0, 4, 81), (4, 2, 78), (6, 2, 81), (8, 6, 86), (14, 2, 84)],
    14: [(0, 8, 83), (8, 2, 81), (10, 2, 79), (12, 4, 76)],
    15: [(0, 2, 79), (2, 2, 78), (4, 2, 76), (6, 2, 74), (8, 8, 76)],
    16: [(0, 4, 79), (4, 2, 76), (6, 2, 79), (8, 6, 84), (14, 2, 86)],
    17: [(0, 4, 88), (4, 2, 86), (6, 2, 84), (8, 4, 83), (12, 4, 81)],
    18: [(0, 4, 83), (4, 2, 81), (6, 2, 78), (8, 4, 75), (12, 4, 78)],
    19: [(0, 12, 83)],
    24: [(0, 6, 81), (6, 2, 79), (8, 8, 76)],
    25: [(0, 6, 83), (6, 2, 81), (8, 8, 79)],
    26: [(0, 6, 84), (6, 2, 81), (8, 8, 77)],
    27: [(0, 4, 78), (4, 4, 83), (8, 8, 87)],
}
for _b in range(4, 12):
    BATTLE_LEAD[_b + 24] = BATTLE_LEAD[_b]
E_MINOR = [4, 6, 7, 9, 11, 0, 2]


def third_below(m: int) -> int:
    pc = m % 12
    if pc not in E_MINOR:
        return m - 4
    i = E_MINOR.index(pc)
    j = (i - 2) % 7
    return m - ((pc - E_MINOR[j]) % 12)


def music_battle() -> tuple[np.ndarray, Song]:
    S = Song("battle", 140, 40, seed=202)
    rng = S.rng
    kit = Kit(rng, kick=lambda r: d_kick(r, 160, 50, 0.028, 0.24), snare=d_snare, clap=d_clap,
              hat=d_hat, ohat=lambda r: d_hat(r, True), crash=d_crash, tom_h=lambda r: d_tom(r, 160),
              tom_m=lambda r: d_tom(r, 120), tom_l=lambda r: d_tom(r, 85), taiko=lambda r: d_taiko(r, 65, 1.0))
    kicks = []

    def sec_of(b):
        return 0 if b < 4 else 1 if b < 12 else 2 if b < 20 else 3 if b < 28 else 4 if b < 36 else 5

    for b in range(40):
        sc = sec_of(b)
        root, tones = BATTLE_CH[BATTLE_PROG[b]]
        # ---- drums
        if sc == 3:
            kpat, spat = [0, 6, 10], [8]
        elif sc == 5:
            kpat, spat = [0, 4, 8, 12], []
        else:
            kpat, spat = [0, 3, 8, 10], [4, 12]
        for st in kpat:
            S.put("drums", kit("kick"), S.st(b, st), 0.9)
            kicks.append(S.st(b, st))
        for st in spat:
            S.put("drums", kit("snare"), S.st(b, st), 1.0)
            S.put("drums", kit("clap"), S.st(b, st), 0.45, pan=0.1)
        if sc in (0, 1, 2, 4):
            if b % 2 == 1:
                S.put("drums", kit("snare"), S.st(b, 15), 0.22)
            for st in range(16):
                if st == 14 and b % 2 == 1:
                    S.put("drums", kit("ohat"), S.st(b, st), 0.4, pan=0.25)
                    continue
                v = 0.5 if st % 4 == 0 else (0.36 if st % 2 == 0 else 0.24)
                S.put("drums", kit("hat"), S.st(b, st) + int(rng.normal(0, 0.002) * SR), v, pan=0.25)
        elif sc == 3:
            for st in range(0, 16, 2):
                S.put("drums", kit("hat"), S.st(b, st), 0.4 if st % 4 == 0 else 0.28, pan=0.25)
            if b in (20, 22, 24, 26):
                S.put("drums", kit("taiko"), S.st(b, 0), 0.7)
                S.put("drums", kit("taiko"), S.st(b, 10), 0.5)
        else:  # build
            dens = {36: 2, 37: 2, 38: 1, 39: 1}[b]
            for k, st in enumerate(range(0, 16, dens)):
                if b == 39 and st >= 14:
                    break
                prog = (b - 36 + st / 16) / 4
                S.put("drums", kit("snare"), S.st(b, st), 0.25 + 0.6 * prog)
            for st in range(0, 16, 2):
                S.put("drums", kit("hat"), S.st(b, st), 0.2, pan=0.25)
        if b in (0, 4, 12, 20, 28):
            S.put("drums", kit("crash"), S.st(b, 0), 0.6, pan=-0.3)
        if b in (11, 27):
            for k, (st, tn) in enumerate(((12, "tom_h"), (13, "tom_h"), (14, "tom_m"), (15, "tom_l"))):
                S.put("drums", kit(tn), S.st(b, st), 0.7, pan=0.4 - 0.25 * k)
        if b in (19, 35):
            for st in (8, 10, 12, 13, 14, 15):
                S.put("drums", kit("snare"), S.st(b, st), 0.45 + 0.03 * st)
        # ---- bass
        if sc == 3 and b < 24:
            bass_notes = [(0, 7, root), (8, 7, root)]
        elif sc == 2:
            bass_notes = [(st, 1, root + (12 if st in (6, 14) else 0)) for st in (0, 2, 3, 4, 6, 7, 8, 10, 11, 12, 14, 15)]
        elif sc == 5 and b >= 38:
            bass_notes = [(st, 1, root + (12 if st % 4 == 2 else 0)) for st in range(16)]
        else:
            bass_notes = [(st, 1.8, root + (12 if st in (4, 12) else 0)) for st in range(0, 16, 2)]
        for st, d, m in bass_notes:
            S.put("bass", bass_synth(float(midi_hz(m)), d * S.beat / 4, rng, cutoff=320, env_amt=1100, tau=0.07),
                  S.st(b, st), 1.0)
        # ---- arp (16ths)
        arp_t = tones + [tones[0] + 12, tones[1] + 12]
        idx = [0, 1, 2, 3, 1, 2, 3, 4, 0, 1, 2, 3, 4, 3, 2, 1]
        cut = 2000 if (sc == 3 and b < 24) else 3800
        for st in range(16):
            if sc == 0 and b < 2 and st % 2 == 1:
                continue
            m = arp_t[idx[st]]
            S.put("arp", synth_pluck(float(midi_hz(m)), 0.22, rng, cutoff=cut), S.st(b, st),
                  0.9 if st % 4 == 0 else 0.65, pan=0.35 if st % 2 else -0.35)
        # ---- pad
        if sc in (1, 2, 4, 5) or (sc == 3 and b >= 24):
            S.put("pad", pad([root + 12] + tones, S.sec(1), rng, cutoff=2000, attack=0.05, release=0.4,
                             detune=12, voices=3), S.s(b), 1.0)
        # ---- lead
        if b in BATTLE_LEAD:
            notes = [(S.sec(b, st / 4), d * S.beat / 4, m, 0.9) for st, d, m in BATTLE_LEAD[b]]
            put_line(S, "lead", notes, syn_lead, glide=0.025, vib_depth=0.18, vib_rate=5.8, vib_delay=0.18,
                     attack=0.008, release=0.12, dip=0.3)
            if b >= 28:
                harm = [(t0, d, third_below(m), 0.6) for t0, d, m, _ in notes]
                put_line(S, "lead", harm, syn_lead, 0.5, pan=0.3, glide=0.025, vib_depth=0.15, attack=0.01,
                         release=0.12, dip=0.3)
    # ---- fx
    S.put("fx", fx_riser(S.sec(4), rng, 250, 7000), S.s(36), 1.0)
    for b in (12, 20, 28):
        S.put("fx", fx_revcym(S.sec(0, 2), rng), S.s(b) - S.s(0, 2), 0.7)
    S.put("fx", fx_boom(rng), S.s(0), 0.9)

    duck = duck_env(S.n, kicks, depth=0.55, rel=0.14)
    for bus, dpt in (("pad", 1.0), ("arp", 0.6), ("bass", 0.5)):
        g = 1 - dpt * (1 - duck)
        S.buses[bus] *= g[:, None].astype(np.float32)
    levels = {"drums": -15, "bass": -19, "arp": -24, "pad": -25, "lead": -18.5, "fx": -25}
    sends = {"drums": 0.06, "arp": 0.25, "pad": 0.25, "lead": 0.2, "fx": 0.3}
    fx = {"lead": lambda x: pingpong(x, S.beat * 0.75, 0.3, 4, 3000)}
    return S.mixdown(levels, sends, rt60=1.5, damp=0.5, predelay=0.015, glue=1.6, fx=fx,
                     hp={"drums": 36, "bass": 36}, air=2.5), S


# =============================================================================================
#  music_lin_awaken  (120 BPM, 32 bars = 64 s)  heroic Chinese: dizi/erhu, taiko, gongs
# =============================================================================================

LIN_CH = {"D": (38, [62, 66, 69]), "Bm": (47, [59, 62, 66]), "G": (43, [55, 59, 62]), "A": (45, [57, 61, 64]),
          "F#m": (42, [54, 57, 61]), "Em": (40, [52, 55, 59])}
LIN_PROG = (["D", "D", "Bm", "Bm", "G", "A", "D", "A"] + ["G", "A", "F#m", "Bm", "G", "A", "Bm", "A"]
            + ["D", "Bm", "G", "A", "D", "Bm", "G", "A"] + ["Bm", "G", "D", "A", "Bm", "G", "Em", "A"])
LIN_DIZI_A = [(0, 0, 1.5, 81), (0, 1.5, .5, 83), (0, 2, 1, 81), (0, 3, 1, 78), (1, 0, 1, 76), (1, 1, 1, 74),
              (1, 2, 2, 76), (2, 0, 1.5, 78), (2, 1.5, .5, 81), (2, 2, 1, 83), (2, 3, 1, 86), (3, 0, 3, 83),
              (3, 3, 1, 81), (4, 0, 1.5, 83), (4, 1.5, .5, 81), (4, 2, 1, 78), (4, 3, 1, 76), (5, 0, 1, 76),
              (5, 1, 1, 78), (5, 2, 1, 81), (5, 3, 1, 76), (6, 0, 1.5, 74), (6, 1.5, .5, 76), (6, 2, 1, 78),
              (6, 3, 1, 81), (7, 0, 3.5, 76)]
LIN_ERHU_B = [(8, 0, 2, 71), (8, 2, 1, 74), (8, 3, 1, 76), (9, 0, 1.5, 76), (9, 1.5, .5, 78), (9, 2, 2, 76),
              (10, 0, 2, 69), (10, 2, 1, 66), (10, 3, 1, 69), (11, 0, 3, 71), (11, 3, 1, 74), (12, 0, 1.5, 74),
              (12, 1.5, .5, 76), (12, 2, 1, 74), (12, 3, 1, 71), (13, 0, 1, 69), (13, 1, 1, 71), (13, 2, 1, 74),
              (13, 3, 1, 76), (14, 0, 2, 78), (14, 2, 1, 76), (14, 3, 1, 74), (15, 0, 3.5, 76)]
LIN_DIZI_C = [(16, 0, 1.5, 81), (16, 1.5, .5, 83), (16, 2, 2, 86), (17, 0, 1, 83), (17, 1, 1, 81), (17, 2, 2, 78),
              (18, 0, 1.5, 83), (18, 1.5, .5, 86), (18, 2, 2, 88), (19, 0, 1, 88), (19, 1, 1, 86), (19, 2, 1, 83),
              (19, 3, 1, 81), (20, 0, 1.5, 86), (20, 1.5, .5, 88), (20, 2, 2, 90), (21, 0, 1, 88), (21, 1, 1, 86),
              (21, 2, 2, 83), (22, 0, 1, 83), (22, 1, 1, 86), (22, 2, 1, 88), (22, 3, 1, 86), (23, 0, 3.5, 88)]
LIN_ERHU_D = [(28, 0, 4, 78), (29, 0, 4, 74), (30, 0, 4, 76), (31, 0, 2, 76), (31, 2, 2, 81)]


def music_lin_awaken() -> tuple[np.ndarray, Song]:
    S = Song("lin_awaken", 120, 32, seed=303)
    rng = S.rng
    kit = Kit(rng, odaiko=lambda r: d_taiko(r, 62, 1.1, 1.6), taiko=lambda r: d_taiko(r, 100, 0.7, 1.0),
              shime=d_shime, kachi=d_kachi, bo=d_bo, crash=d_crash)

    def sec_of(b):
        return b // 8

    for b in range(32):
        sc = sec_of(b)
        root, tones = LIN_CH[LIN_PROG[b]]
        # ---- taiko ensemble
        if sc == 0:
            od, md = [0, 10], [4, 12, 14]
        elif sc == 1:
            od, md = [0, 6, 10], [4, 7, 12, 14, 15]
        elif sc == 2:
            od, md = [0, 4, 8, 12, 14], [2, 4, 6, 10, 12, 13, 14, 15]
        else:
            od = {24: [0, 3, 6], 25: [0, 8], 26: [0, 3, 6], 27: [0, 4, 8, 10, 12, 14], 28: [0, 8], 29: [0, 8],
                  30: [0, 6, 8, 12], 31: [0, 4, 8, 12]}[b]
            md = {24: [12, 13, 14, 15], 25: [4, 12], 26: [12, 13, 14, 15], 27: [], 28: [4, 12], 29: [4, 12, 14],
                  30: [4, 10, 12, 14], 31: list(range(16))}[b]
        for st in od:
            S.put("taiko", kit("odaiko"), S.st(b, st), 1.0 if st == 0 else 0.8)
        for st in md:
            v = 0.55 + (0.35 * st / 15 if b == 31 else 0.0)
            S.put("taiko", kit("taiko"), S.st(b, st), v, pan=(-0.35 if st % 2 else 0.35))
        if sc in (1, 2) or b >= 28:
            for st in range(16):
                v = (0.35 if st % 4 == 0 else 0.18) * (1.0 if b < 28 else 0.6 + 0.4 * (b - 28 + st / 16) / 4)
                S.put("taiko", kit("shime"), S.st(b, st) + int(rng.normal(0, 0.002) * SR), v, pan=0.45)
        elif sc == 0:
            for st in range(0, 16, 2):
                S.put("taiko", kit("shime"), S.st(b, st), 0.25 if st % 4 == 0 else 0.15, pan=0.45)
        if sc in (0, 1) or b in (24, 25, 26):
            for st in (2, 6, 10, 14):
                S.put("taiko", kit("kachi"), S.st(b, st), 0.3, pan=-0.45)
        if (sc == 0 and b % 2 == 0) or sc == 1:
            S.put("cym", kit("bo"), S.st(b, 0), 0.5 if sc == 0 else 0.4, pan=-0.2)
        if sc == 2:
            S.put("cym", kit("bo"), S.st(b, 8), 0.35, pan=0.2)
            if b in (16, 20):
                S.put("cym", kit("crash"), S.st(b, 0), 0.6, pan=0.3)
        # ---- ostinato (guzheng)
        if b < 24 or b >= 28:
            ost = sorted([m + 12 if m < 62 else m for m in tones])
            ost = ost + [ost[0] + 12]
            pat = [0, 1, 2, 1, 0, 1, 2, 3, 0, 1, 2, 1, 0, 2, 3, 2]
            stepw = 2 if sc == 0 else 1
            for st in range(0, 16, stepw):
                m = ost[pat[st]]
                S.put("ost", pluck(float(midi_hz(m)), 0.7, rng, bright=0.55, decay=0.45, pos=0.18, pick=0.25),
                      S.st(b, st), 0.9 if st % 4 == 0 else 0.6, pan=-0.3 if st % 2 else 0.1)
        # ---- strings + brass + bass
        if b < 24 or b >= 28:
            S.put("strings", pad([root + 12] + tones + [tones[1] + 12], S.sec(1), rng, cutoff=2600, attack=0.25,
                                 release=0.6, detune=9, voices=3, vib=0.004), S.s(b), 0.8 if sc == 0 else 1.0)
        if sc == 2 or (sc == 1 and b >= 12):
            hits = [(0, 5), (6, 5), (12, 4)] if sc == 2 else [(0, 6), (10, 5)]
            for st, d in hits:
                S.put("brass", brass([root + 12] + tones, d * S.beat / 4, rng), S.st(b, st), 1.0)
        if sc == 0:
            bn = [(0, 7.5, root), (8, 7.5, root)]
        elif 24 <= b < 28:
            bn = [(0, 15.5, root)]
        else:
            bn = [(st, 1.8, root + (12 if st in (6, 14) else 0)) for st in range(0, 16, 2)]
        for st, d, m in bn:
            S.put("bass", bass_synth(float(midi_hz(m)), d * S.beat / 4, rng, cutoff=260, env_amt=600, drive=1.6),
                  S.st(b, st), 1.0)
    # ---- gongs
    for b, g in ((0, 1.0), (8, 0.55), (16, 1.0), (24, 0.9)):
        S.put("gong", gong_hit(T(4.0), np.random.default_rng(900 + b), 88.0, 1.8, 0.35, -0.035), S.s(b), g)
    S.put("gong", fx_riser(S.sec(2), rng, 200, 5000), S.s(30), 0.35)
    # ---- leads
    dz = dict(glide=0.03, vib_depth=0.22, vib_rate=5.6, vib_delay=0.22, attack=0.03, release=0.3, dip=0.3)
    eh = dict(glide=0.07, vib_depth=0.35, vib_rate=6.0, vib_delay=0.15, attack=0.05, release=0.3, dip=0.2,
              scoop=0.8, scoop_tau=0.06)
    put_line(S, "lead", [(S.sec(b, bt), d * S.beat, m, 0.9) for b, bt, d, m in LIN_DIZI_A], syn_dizi, **dz)
    put_line(S, "lead", [(S.sec(b, bt), d * S.beat, m, 0.9) for b, bt, d, m in LIN_ERHU_B], syn_erhu, **eh)
    put_line(S, "lead", [(S.sec(b, bt), d * S.beat, m, 0.85) for b, bt, d, m in LIN_DIZI_C], syn_dizi, **dz)
    put_line(S, "lead", [(S.sec(b, bt), d * S.beat, m - 12, 0.75) for b, bt, d, m in LIN_DIZI_C], syn_erhu,
             pan=-0.15, **eh)
    put_line(S, "lead", [(S.sec(b, bt), d * S.beat, m, 0.9) for b, bt, d, m in LIN_ERHU_D], syn_erhu, **eh)

    levels = {"taiko": -15.5, "cym": -25, "gong": -21, "ost": -23.5, "strings": -22, "brass": -23, "bass": -21,
              "lead": -18.5}
    sends = {"taiko": 0.2, "cym": 0.25, "gong": 0.3, "ost": 0.2, "strings": 0.3, "brass": 0.2, "lead": 0.28}
    return S.mixdown(levels, sends, rt60=2.4, damp=0.55, predelay=0.02, glue=1.5,
                     hp={"taiko": 42, "bass": 36, "gong": 40}, air=2.0), S


# =============================================================================================
#  music_ren_awaken  (168 BPM, 44 bars = 62.857 s)  dark D-minor rock / drum & bass
# =============================================================================================

def _riff_a(last=False):
    b1 = [(0, 'o', 38, 2), (2, 'm', 38, 1), (3, 'm', 38, 1), (4, 'm', 38, 1), (6, 'm', 38, 1), (7, 'm', 38, 1),
          (8, 'o', 41, 2), (10, 'm', 38, 1), (11, 'm', 38, 1), (12, 'o', 39, 3), (15, 'm', 38, 1)]
    b2 = [(0, 'o', 38, 2), (2, 'm', 38, 1), (3, 'm', 38, 1), (4, 'm', 38, 1), (6, 'o', 48, 2), (8, 'm', 38, 1),
          (9, 'm', 38, 1), (10, 'o', 44 if last else 46, 2), (12, 'o', 45, 4)]
    return b1, b2


def _gallop(r):
    return [(0, 'o', r, 3), (3, 'm', r, 1), (4, 'm', r, 1), (6, 'm', r, 1), (7, 'm', r, 1), (8, 'o', r, 2),
            (10, 'm', r, 1), (11, 'm', r, 1), (12, 'o', r, 2), (14, 'm', r, 1), (15, 'm', r, 1)]


REN_LEAD_A = {
    0: [(0, 2, 74), (2, 1, 74), (3, 3, 77), (6, 2, 76), (8, 2, 74), (10, 2, 72), (12, 4, 74)],
    1: [(0, 2, 69), (2, 2, 72), (4, 2, 74), (6, 2, 77), (8, 4, 79), (12, 2, 77), (14, 2, 76)],
    2: [(0, 2, 74), (2, 1, 74), (3, 3, 77), (6, 2, 76), (8, 2, 74), (10, 2, 72), (12, 2, 74), (14, 2, 77)],
    3: [(0, 6, 81), (6, 2, 79), (8, 4, 77), (12, 4, 76)],
    4: [(0, 2, 74), (2, 1, 74), (3, 3, 77), (6, 2, 76), (8, 2, 74), (10, 2, 72), (12, 4, 74)],
    5: [(0, 2, 69), (2, 2, 72), (4, 2, 74), (6, 2, 77), (8, 4, 82), (12, 4, 81)],
    6: [(0, 3, 79), (3, 3, 77), (6, 2, 76), (8, 2, 77), (10, 2, 76), (12, 4, 73)],
    7: [(0, 8, 74)],
}
REN_LEAD_B = {
    0: [(0, 4, 77), (4, 2, 74), (6, 2, 77), (8, 6, 82), (14, 2, 81)],
    1: [(0, 4, 79), (4, 2, 76), (6, 2, 79), (8, 6, 84), (14, 2, 82)],
    2: [(0, 6, 81), (6, 2, 77), (8, 8, 86)],
    3: [(0, 4, 85), (4, 4, 81), (8, 4, 76), (12, 4, 73)],
    4: [(0, 4, 77), (4, 2, 74), (6, 2, 77), (8, 6, 82), (14, 2, 81)],
    5: [(0, 4, 79), (4, 2, 76), (6, 2, 79), (8, 4, 84), (12, 4, 86)],
    6: [(0, 4, 88), (4, 4, 86), (8, 8, 81)],
    7: [(0, 2, 79), (2, 2, 77), (4, 4, 76), (8, 8, 73)],
}
REN_LEAD_E = {
    36: [(0, 16, 77)], 37: [(0, 16, 79)], 38: [(0, 12, 81), (12, 4, 79)], 39: [(0, 16, 76)],
    40: [(0, 8, 86), (8, 4, 84), (12, 4, 82)], 41: [(0, 16, 84)], 42: [(0, 8, 82), (8, 8, 79)], 43: [(0, 8, 81)],
}


def music_ren_awaken() -> tuple[np.ndarray, Song]:
    S = Song("ren_awaken", 168, 44, seed=404)
    rng = S.rng
    kit = Kit(rng, kick=lambda r: d_kick(r, 170, 52, 0.025, 0.2, -8, 2.2), snare=lambda r: d_snare(r, 200, 0.3, 0.09),
              hat=d_hat, ohat=lambda r: d_hat(r, True), ride=d_ride, crash=d_crash,
              china=lambda r: d_bo(r, 0.9), tom_h=lambda r: d_tom(r, 170), tom_m=lambda r: d_tom(r, 125),
              tom_l=lambda r: d_tom(r, 90))
    kicks = []

    def sec_of(b):
        return 0 if b < 8 else 1 if b < 16 else 2 if b < 24 else 3 if b < 28 else 4 if b < 36 else 5

    S5_ROOTS = [46, 48, 38, 45, 46, 48, 39, 45]
    S2_ROOTS = [46, 48, 38, 45]
    for b in range(44):
        sc = sec_of(b)
        # ---- guitar part for this bar
        if sc in (0, 1, 4):
            r1, r2 = _riff_a(last=(b % 8 == 7))
            gpart = r1 if b % 2 == 0 else r2
        elif sc == 2:
            gpart = _gallop(S2_ROOTS[b % 4])
        elif sc == 3:
            gpart = {24: [(0, 'o', 38, 16)], 25: [(0, 'o', 39, 16)],
                     26: [(0, 'o', 38, 8), (8, 'm', 38, 1), (10, 'm', 38, 1), (12, 'm', 38, 1), (14, 'm', 38, 1)],
                     27: [(i, 'm', 38, 1) for i in range(16)]}[b]
        else:
            gpart = [(0, 'o', 45, 6)] if b == 43 else _gallop(S5_ROOTS[b - 36])
        for st, kind, root, d in gpart:
            vel = 1.0 if kind == 'o' else 0.8
            if b == 27:
                vel = 0.55 + 0.45 * st / 15
            dur = d * S.beat / 4
            for side, pan in ((0, -0.75), (1, 0.75)):
                g = guitar(root, dur * (0.9 if kind == 'm' else 1.0), rng, mute=(kind == 'm'), vel=vel)
                S.put("gtr", g, S.st(b, st) + (N(0.006) if side else 0), 1.0, pan=pan)
            bdur = dur * (0.7 if kind == 'm' else 0.95)
            S.put("bass", bass_synth(float(midi_hz(root)), bdur, rng, cutoff=500, env_amt=1400, tau=0.05, drive=2.6,
                                     sub=1.0), S.st(b, st), 1.0)
        # ---- drums
        if sc in (0, 1, 4):
            kp = [0, 10] if b % 2 == 0 else [0, 7, 10]
            sp = [4, 12]
            ghosts = [6, 14] if b % 2 == 0 else [3, 14]
        elif sc in (2, 5):
            kp, sp, ghosts = [0, 2, 3, 8, 10, 11], [4, 12], []
        else:
            kp, sp, ghosts = ([0, 3, 6], [8], []) if b < 27 else ([0, 4, 8, 12], [], [])
        if b == 43:
            kp, sp, ghosts = [0], [4], []
        for st in kp:
            S.put("drums", kit("kick"), S.st(b, st), 1.0)
            kicks.append(S.st(b, st))
        for st in sp:
            S.put("drums", kit("snare"), S.st(b, st), 0.9)
        for st in ghosts:
            S.put("drums", kit("snare"), S.st(b, st), 0.2)
        if sc in (0, 1):
            for st in range(0, 16, 2):
                S.put("drums", kit("hat"), S.st(b, st), 0.45 if st % 4 == 0 else 0.3, pan=0.3)
        elif sc == 4:
            for st in range(16):
                S.put("drums", kit("hat"), S.st(b, st) + int(rng.normal(0, 0.002) * SR),
                      0.45 if st % 4 == 0 else (0.3 if st % 2 == 0 else 0.18), pan=0.3)
        elif sc in (2, 5) and b != 43:
            for st in (0, 4, 8, 12):
                S.put("drums", kit("ride"), S.st(b, st), 0.45, pan=0.35)
        if sc == 3 and b < 27:
            S.put("drums", kit("china"), S.st(b, 8), 0.5, pan=-0.3)
        if b == 27:
            for st in range(16):
                S.put("drums", kit("snare"), S.st(b, st), 0.2 + 0.6 * st / 15)
        if b in (0, 8, 16, 20, 28, 32, 36, 40):
            S.put("drums", kit("crash"), S.st(b, 0), 0.65, pan=-0.35)
        if sc in (0, 1) and b % 4 == 3:
            S.put("drums", kit("china"), S.st(b, 12), 0.4, pan=0.35)
        if b in (15, 35):
            for st in (12, 13, 14, 15):
                S.put("drums", kit("snare"), S.st(b, st), 0.5 + 0.1 * (st - 12))
        if b == 43:
            for k, st in enumerate(range(8, 16)):
                tn = ("tom_h", "tom_h", "tom_m", "tom_m", "tom_l", "tom_l", "snare", "snare")[k]
                S.put("drums", kit(tn), S.st(b, st), 0.75, pan=0.4 - 0.1 * k)
        # ---- lead
        notes = []
        if sc in (1, 4):
            notes = REN_LEAD_A[b % 8]
        elif sc == 2:
            notes = REN_LEAD_B[b - 16]
        elif sc == 5:
            notes = REN_LEAD_E[b]
        if notes:
            nl = [(S.sec(b, st / 4), d * S.beat / 4, m, 0.9) for st, d, m in notes]
            lk = dict(glide=0.02, vib_depth=0.3, vib_rate=6.2, vib_delay=0.2, attack=0.006, release=0.1, dip=0.3,
                      scoop=1.0 if sc == 5 else 0.0, scoop_tau=0.04)
            put_line(S, "lead", nl, syn_lead_ren, **lk)
            if sc == 4:
                put_line(S, "lead", [(t0, d, m + 12, 0.35) for t0, d, m, _ in nl], syn_lead_ren, pan=0.2, **lk)
    # ---- fx: booms, risers, reverse cymbals, blade scrape in the breakdown
    for b in (0, 16, 28):
        S.put("fx", fx_boom(rng), S.s(b), 1.0)
    for b in (8, 16, 36):
        S.put("fx", fx_revcym(S.sec(0, 2), rng), S.s(b) - S.s(0, 2), 0.6)
    S.put("fx", fx_riser(S.sec(1), rng, 400, 8000), S.s(27), 0.7)
    S.put("fx", fx_riser(S.sec(1), rng, 400, 8000), S.s(43), 0.7)
    S.put("fx", scrape_tex(S.sec(3), rng, 500, 1800), S.s(24), 0.6, pan=-0.2)

    duck = duck_env(S.n, kicks, depth=0.45, rel=0.12)
    S.buses["bass"] *= (1 - 0.6 * (1 - duck))[:, None].astype(np.float32)
    levels = {"drums": -14.5, "gtr": -16.5, "bass": -20, "lead": -18.5, "fx": -24}
    sends = {"drums": 0.07, "gtr": 0.05, "lead": 0.16, "fx": 0.3}
    fx = {"lead": lambda x: pingpong(x, S.beat * 0.75, 0.25, 3, 3000)}
    return S.mixdown(levels, sends, rt60=1.3, damp=0.45, predelay=0.012, glue=1.7, fx=fx,
                     hp={"drums": 36, "bass": 36, "gtr": 75}, air=2.5), S


MUSIC = [
    ("lobby", "music_lobby.ogg", music_lobby),
    ("battle", "music_battle.ogg", music_battle),
    ("lin_awaken", "music_lin_awaken.ogg", music_lin_awaken),
    ("ren_awaken", "music_ren_awaken.ogg", music_ren_awaken),
]


# =============================================================================================
#  Output
# =============================================================================================

def write_ogg(path: Path, data: np.ndarray, level: float) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.clip(data, -1.0, 1.0).astype(np.float32)
    channels = 1 if data.ndim == 1 else data.shape[1]
    kw = dict(mode="w", samplerate=SR, channels=channels, format="OGG", subtype="VORBIS")
    try:
        f = sf.SoundFile(str(path), compression_level=level, **kw)
    except TypeError:          # older soundfile without compression_level
        f = sf.SoundFile(str(path), **kw)
    # write in blocks: libsndfile's Vorbis encoder can overflow the stack on one huge write call
    with f:
        for i in range(0, len(data), 16384):
            f.write(data[i:i + 16384])


def fmt(x: float) -> str:
    return repr(round(float(x), 3))


def write_manifest(regions, sprite_len: float, music_info) -> None:
    lines = [
        "--!strict",
        "-- AUTO-GENERATED by tools/gen_sounds.py. Do not edit by hand.",
        "local SoundManifest = {",
        "\tsprite = {",
    ]
    for name, start, length in regions:
        lines.append(f"\t\t{name} = {{ start = {fmt(start)}, length = {fmt(length)} }},")
    lines += ["\t},", f"\tspriteLength = {fmt(sprite_len)},", "\tmusic = {"]
    for key, fname, length in music_info:
        lines.append(f'\t\t{key} = {{ file = "{fname}", length = {fmt(length)} }},')
    lines += ["\t},", "}", "return SoundManifest", ""]
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text("\n".join(lines), encoding="utf-8")


SOUND_IDS_TEMPLATE = """--!strict
-- 로블록스에 업로드한 오디오 에셋 ID를 여기에 넣으세요. 0이면 내장(fallback) 사운드를 씁니다.
-- tools/upload_sounds.py 를 실행하면 자동으로 채워집니다.
local SoundIds = {
\tsprite = 0, -- assets/sounds/sfx_sprite.ogg
\tmusic_lobby = 0,
\tmusic_battle = 0,
\tmusic_lin_awaken = 0,
\tmusic_ren_awaken = 0,
}
return SoundIds
"""


def ensure_sound_ids() -> None:
    if not SOUND_IDS_PATH.exists():
        SOUND_IDS_PATH.parent.mkdir(parents=True, exist_ok=True)
        SOUND_IDS_PATH.write_text(SOUND_IDS_TEMPLATE, encoding="utf-8")
        print(f"  created {SOUND_IDS_PATH.relative_to(ROOT)}")


def read_music_lengths() -> dict:
    """Lengths of already-rendered music files (used with --sfx-only so the manifest stays complete)."""
    out = {}
    for key, fname, _fn in MUSIC:
        p = OUT_DIR / fname
        if p.exists():
            out[key] = sf.info(str(p)).frames / SR
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate Gold & Ash SFX + music (deterministic).")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--sfx-only", action="store_true", help="only (re)generate SFX, sprite and manifest")
    g.add_argument("--music-only", action="store_true", help="only (re)generate the music loops and manifest")
    ap.add_argument("--wav-dir", type=Path, default=None, help="also write .wav previews into this folder")
    args = ap.parse_args()

    t_start = time.time()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    SFX_DIR.mkdir(parents=True, exist_ok=True)
    if args.wav_dir:
        args.wav_dir.mkdir(parents=True, exist_ok=True)

    regions = None
    sprite_len = None
    if not args.music_only:
        print(f"Rendering {len(SFX_LIST)} SFX ...")
        gap = np.zeros(N(SPRITE_GAP))
        parts = [gap]
        regions = []
        pos = len(gap)
        for name, dur, fn, tail in SFX_LIST:
            rng = np.random.default_rng(zlib.crc32(name.encode("utf-8")))
            y = finalize_sfx(fn(rng, T(dur)), dur, tail)
            write_ogg(SFX_DIR / f"{name}.ogg", y, SFX_VORBIS_LEVEL)
            if args.wav_dir:
                sf.write(str(args.wav_dir / f"{name}.wav"), y.astype(np.float32), SR, subtype="FLOAT")
            regions.append((name, pos / SR, len(y) / SR))
            parts += [y, gap]
            pos += len(y) + len(gap)
            print(f"  {name:<20s} {dur:5.2f}s")
        sprite = np.concatenate(parts)
        sprite_len = len(sprite) / SR
        write_ogg(OUT_DIR / "sfx_sprite.ogg", sprite, SFX_VORBIS_LEVEL)
        print(f"  sfx_sprite.ogg  {sprite_len:.3f}s")
    else:
        # keep the existing sprite information when only re-rendering music
        spr = OUT_DIR / "sfx_sprite.ogg"
        if spr.exists():
            regions = []
            pos = N(SPRITE_GAP)
            for name, dur, _fn, _tail in SFX_LIST:
                regions.append((name, pos / SR, N(dur) / SR))
                pos += N(dur) + N(SPRITE_GAP)
            sprite_len = pos / SR

    music_lengths = read_music_lengths()
    if not args.sfx_only:
        for key, fname, fn in MUSIC:
            t0 = time.time()
            y, song = fn()
            write_ogg(OUT_DIR / fname, y, MUSIC_VORBIS_LEVEL)
            if args.wav_dir:
                sf.write(str(args.wav_dir / fname.replace(".ogg", ".wav")), y.astype(np.float32), SR, subtype="FLOAT")
            music_lengths[key] = len(y) / SR
            print(f"  {fname:<22s} {len(y) / SR:7.3f}s  ({song.bars} bars @ {song.bpm} BPM, {time.time() - t0:.1f}s)")

    music_info = [(key, fname, music_lengths.get(key, 0.0)) for key, fname, _fn in MUSIC]
    if regions is not None:
        write_manifest(regions, sprite_len, music_info)
        print(f"  wrote {MANIFEST_PATH.relative_to(ROOT)}")
    ensure_sound_ids()
    print(f"Done in {time.time() - t_start:.1f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
