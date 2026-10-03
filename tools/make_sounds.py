"""
Generates every sound in the game (no recordings needed).
Run:  python tools/make_sounds.py   (needs numpy, scipy and ffmpeg)
Writes assets/sfx/*.ogg and assets/music/chase.ogg

Sound design rules (so nothing hurts the ears on a phone speaker):
  * soft waveforms only (sine + a few quiet harmonics) - no square / saw buzz
  * nothing sharp above ~5 kHz (a gentle low-pass on every sound)
  * a short fade in and fade out on every sound (no clicks)
  * every sound is matched by loudness (RMS), not by peak, and kept quiet
  * a tiny warm room reverb so sounds feel round instead of dry
"""
import os
import subprocess
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter, sosfilt, fftconvolve

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..")
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.006, curve=4.0):
    """Soft attack + exponential decay envelope."""
    x = np.ones(n)
    na = max(1, min(n - 1, int(SR * a)))
    x[:na] = np.sin(np.linspace(0, np.pi / 2, na)) ** 2
    decay = np.linspace(0, 1, n - na)
    x[na:] = np.exp(-curve * decay)
    return x


def sweep(f0, f1, d):
    tt = t(d)
    f = np.geomspace(f0, f1, len(tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    # sine with a quiet 2nd harmonic: round, not buzzy
    return np.sin(ph) + 0.12 * np.sin(2 * ph)


def marimba(f, d, decay=6.0, bright=0.15):
    """Soft wooden mallet note (much gentler than a bell)."""
    tt = t(d)
    body = np.sin(2 * np.pi * f * tt)
    over = bright * np.sin(2 * np.pi * f * 4 * tt) * np.exp(-tt * 40)
    return (body + over) * env(len(tt), 0.004, decay)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lowpass(x, cutoff, order=2):
    sos = butter(order, cutoff / (SR / 2), "low", output="sos")
    return sosfilt(sos, x)


def bandpass(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], "band")
    return lfilter(b, a, x)


def cat(*parts, gap=0.0):
    out = []
    for p in parts:
        out.append(p)
        if gap:
            out.append(np.zeros(int(SR * gap)))
    return np.concatenate(out)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(sig, offset):
    return np.concatenate([np.zeros(int(SR * offset)), sig])


# small warm "room": decaying, darkened noise
_ir_t = t(0.35)
ROOM = lowpass(rng.normal(0, 1, len(_ir_t)), 2500) * np.exp(-_ir_t / 0.07)
ROOM /= np.sqrt(np.sum(ROOM ** 2))


def reverb(x, wet=0.12):
    tail = fftconvolve(x, ROOM)
    dry = np.concatenate([x, np.zeros(len(tail) - len(x))])
    return dry * (1 - wet) + tail * wet * 3


def finish(x, cutoff=5000, wet=0.12, fade_out=0.03):
    x = lowpass(x, cutoff)
    x = reverb(x, wet)
    # trim silence at the end and fade both ends
    idx = np.where(np.abs(x) > np.max(np.abs(x)) * 0.002)[0]
    if len(idx):
        x = x[: idx[-1] + 1]
    nf = min(len(x) // 2, int(SR * fade_out))
    x[-nf:] *= np.linspace(1, 0, nf) ** 2
    ni = min(len(x) // 4, int(SR * 0.002))
    x[:ni] *= np.linspace(0, 1, ni)
    return x


# raise or lower every sound together (dB)
LOUD_OFFSET = 4.0


def save(name, x, folder="sfx", loud=-22.0, peak=0.5, process=True, **kw):
    """loud = target RMS in dBFS (of the loud part); peak = max sample."""
    if process:
        x = finish(x, **kw)
    # loudness of the loud part (ignore the quiet tail)
    a = np.abs(x)
    body = x[a > np.max(a) * 0.1]
    rms = np.sqrt(np.mean(body ** 2)) + 1e-9
    x = x * (10 ** ((loud + LOUD_OFFSET) / 20) / rms)
    m = np.max(np.abs(x))
    if m > peak:
        x = x * (peak / m)
    os.makedirs(os.path.join(ROOT, "assets", folder), exist_ok=True)
    wav = os.path.join(ROOT, "assets", folder, name + ".wav")
    ogg = wav[:-4] + ".ogg"
    wavfile.write(wav, SR, (x * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
                    "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    os.remove(wav)
    print(f"wrote {ogg}  peak={20*np.log10(np.max(np.abs(x))):.1f} dB")


# ---------------- Sound effects ----------------

def sfx():
    # Jump: soft springy "hup" going up
    d = 0.17
    save("jump", sweep(300, 640, d) * env(int(SR * d), 0.01, 3.5), loud=-25)

    # Land: a soft, low cushion thump
    d = 0.12
    th = sweep(130, 70, d) * env(int(SR * d), 0.003, 7)
    puff = lowpass(noise(0.06), 600) * env(int(SR * 0.06), 0.002, 8) * 0.4
    save("land", mix(th, puff), loud=-27, cutoff=1500)

    # Coin: two soft marimba notes (round, not piercing)
    c = mix(marimba(1046, 0.18, 9), at(marimba(1568, 0.35, 7), 0.06) * 0.8)
    save("coin", c, loud=-26, cutoff=4500)

    # Whoosh: airy swish, dark and smooth
    d = 0.36
    n = lowpass(noise(d), 1400, order=4)
    shape = np.sin(np.linspace(0, np.pi, len(n))) ** 3
    save("whoosh", n * shape, loud=-30, cutoff=1800, wet=0.08)

    # Wind-up: soft rising "wooo" as Mom swings her arm
    d = 0.24
    w = sweep(220, 420, d) * np.sin(np.linspace(0, np.pi, int(SR * d))) ** 1.5
    save("windup", w, loud=-31)

    # Hit: cushioned "bonk" + a cartoon wobble going down
    bonk = sweep(260, 120, 0.12) * env(int(SR * 0.12), 0.002, 6)
    wob = sweep(440, 150, 0.45) * env(int(SR * 0.45), 0.01, 3)
    wob *= 1 + 0.3 * np.sin(2 * np.pi * 14 * t(0.45))
    save("hit", mix(bonk, at(wob * 0.6, 0.05)), loud=-22)

    # Bounce: rubbery little "boing"
    d = 0.14
    save("bounce", sweep(150, 300, d) * env(int(SR * d), 0.004, 4), loud=-28)

    # Near miss: quick happy marimba run
    run = mix(*[at(marimba(f, 0.2, 8), k * 0.055)
                for k, f in enumerate([659, 784, 988, 1318])])
    save("nearmiss", run, loud=-26, cutoff=4500)

    # Power-up: sparkly but soft rising run
    run = mix(*[at(marimba(f, 0.25, 7), k * 0.05)
                for k, f in enumerate([523, 659, 784, 1046, 1318])])
    save("powerup", run, loud=-25, cutoff=4500, wet=0.18)

    # Shield break: soft pop + gentle ping
    pop = lowpass(noise(0.05), 1200) * env(int(SR * 0.05), 0.002, 8)
    save("shield", mix(pop, at(marimba(1175, 0.4, 6), 0.03) * 0.8), loud=-25)

    # Game over: gentle "wah wah wah waaah" (warm, not buzzy)
    def wah(f, d):
        tt = t(d)
        ph = 2 * np.pi * f * tt
        s = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
        e = np.minimum(1, tt * 25) * np.exp(-tt * 1.6)
        return s * e
    last = wah(277, 1.1) * (1 + 0.05 * np.sin(2 * np.pi * 5 * t(1.1)))
    save("gameover", cat(wah(349, 0.3), wah(330, 0.3), wah(311, 0.3), last),
         loud=-24, cutoff=2500, wet=0.18)

    # Belt crack: a "swish" then a dull leather slap (no sharp snap)
    swish = lowpass(noise(0.12), 1800, order=4) * np.linspace(0, 0.5, int(SR * 0.12)) ** 2
    slap = bandpass(noise(0.07), 500, 2200) * env(int(SR * 0.07), 0.001, 10)
    save("crack", cat(swish, slap * 1.5), loud=-25, cutoff=3000)

    # Kick: soft thump + the obstacle flying away
    th = sweep(170, 60, 0.13) * env(int(SR * 0.13), 0.002, 6)
    fly = sweep(300, 700, 0.25) * env(int(SR * 0.25), 0.02, 3) * 0.4
    save("kick", mix(th, at(fly, 0.05)), loud=-24)

    # Dad arrives: "dun dun DUNNN" on soft low horns
    def horn(f, d):
        tt = t(d)
        ph = 2 * np.pi * f * tt
        s = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph) + 0.1 * np.sin(4 * ph)
        e = np.minimum(1, tt * 18) * np.exp(-tt * (1.3 if d > 0.5 else 4))
        return s * e
    save("dad", cat(horn(147, 0.24), horn(139, 0.24), horn(117, 1.1)),
         loud=-23, cutoff=1800, wet=0.2)

    # UI click: tiny soft wooden "tok"
    save("click", marimba(880, 0.06, 12, bright=0.05), loud=-30, cutoff=3500, wet=0.04)

    # Reward / purchase: gentle coin sparkle
    shower = mix(*[at(marimba(f, 0.3, 7), k * 0.07)
                   for k, f in enumerate([784, 988, 1175, 1318, 1568, 1318, 1568])])
    save("reward", shower, loud=-25, cutoff=4500, wet=0.2)


# ---------------- Music: Persian 6/8 chase loop ----------------
# Santur-like plucks (Karplus-Strong) in dastgah Shur on G,
# with tombak (dom / tak) and a daf-like frame drum. Softened.

def pluck(freq, dur):
    n = int(SR * dur)
    period = int(SR / freq)
    # darker excitation = softer hammer
    buf = lowpass(rng.uniform(-1, 1, period * 4), 2500)[-period:]
    buf = buf / (np.max(np.abs(buf)) + 1e-9)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = 0.4985 * (buf[i % period] + buf[(i + 1) % period])
    na = int(SR * 0.003)
    out[:na] *= np.linspace(0, 1, na)
    return out


def santur(freq, dur):
    return (pluck(freq, dur) + pluck(freq * 1.003, dur)) * 0.5


def dom(d=0.25):
    tt = t(d)
    f = 90 * np.exp(-tt * 9) + 55
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 13) * env(len(tt), 0.003, 0.1)


def tak(d=0.05):
    return bandpass(noise(d), 1200, 3200) * env(int(SR * d), 0.001, 10)


def music():
    G = 196.0
    cents = {"G": 0, "Ak": 150, "Bb": 300, "C": 500, "D": 700, "Eb": 800, "F": 1000}

    def hz(n, octv=1):
        return G * octv * 2 ** (cents[n] / 1200)

    eighth = 60 / 160 / 2
    bar = eighth * 6
    bars = 16
    total = int(SR * bar * bars) + SR
    out = np.zeros(total)

    def place(sig, when, vol):
        i = int(SR * when)
        end = min(total, i + len(sig))
        out[i:end] += sig[: end - i] * vol

    A = [("G", 2, 1), ("Ak", 2, 1), ("Bb", 2, 1), ("C", 2, 2), ("Bb", 2, 1),
         ("Ak", 2, 1), ("Bb", 2, 1), ("Ak", 2, 1), ("G", 2, 3),
         ("D", 2, 1), ("Eb", 2, 1), ("D", 2, 1), ("C", 2, 2), ("Bb", 2, 1),
         ("C", 2, 1), ("Bb", 2, 1), ("Ak", 2, 1), ("G", 2, 3)]
    B = [("D", 2, 2), ("Eb", 2, 1), ("F", 2, 2), ("Eb", 2, 1),
         ("D", 2, 1), ("C", 2, 1), ("Bb", 2, 1), ("C", 2, 3),
         ("Bb", 2, 1), ("C", 2, 1), ("D", 2, 1), ("C", 2, 1), ("Bb", 2, 1), ("Ak", 2, 1),
         ("G", 2, 2), ("Ak", 2, 1), ("G", 2, 3)]
    pos = 0.0
    for note, octv, ln in A + B + A + B:
        d = ln * eighth
        f = hz(note, octv)
        place(santur(f, min(d + 0.4, 1.2)), pos, 0.5)
        if ln >= 2:  # soft tremolo on long notes
            r = eighth / 2
            while r < d - 0.01:
                place(santur(f, 0.35), pos + r, 0.18)
                r += eighth / 2
        pos += d

    for b in range(bars):
        root = hz("G", 0.5) if b % 4 != 3 else hz("D", 0.5)
        place(santur(root, bar), b * bar, 0.3)

    pattern = ["dom", None, "tak", "dom", "tak", "tak"]
    for b in range(bars):
        for i, p in enumerate(pattern):
            when = b * bar + i * eighth
            if p == "dom":
                place(dom(), when, 0.55)
            elif p == "tak":
                place(tak(), when, 0.12 if i != 5 else 0.08)
        place(lowpass(noise(0.15), 900) * env(int(SR * 0.15), 0.002, 8), b * bar, 0.12)

    out = lowpass(out, 4500)
    out = reverb(out, 0.15)[:total]
    loop = out[: int(SR * bar * bars)].copy()
    tail = out[int(SR * bar * bars):]
    loop[: len(tail)] += tail
    # tiny crossfade-safe edges
    save("chase", loop, folder="music", loud=-24, peak=0.6, process=False)


if __name__ == "__main__":
    sfx()
    music()
