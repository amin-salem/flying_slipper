"""
Generates every sound in the game (no recordings needed).
Run:  python tools/make_sounds.py   (needs numpy, scipy and ffmpeg)
Writes assets/sfx/*.ogg and assets/music/chase.ogg
"""
import os
import subprocess
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..")
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=None, curve=4.0):
    """Attack + exponential decay envelope."""
    x = np.ones(n)
    na = max(1, int(SR * a))
    x[:na] = np.linspace(0, 1, na)
    decay = np.linspace(0, 1, n - na)
    x[na:] = np.exp(-curve * decay)
    if r:
        nr = int(SR * r)
        x[-nr:] *= np.linspace(1, 0, nr)
    return x


def sweep(f0, f1, d, wave="sine"):
    tt = t(d)
    f = np.geomspace(f0, f1, len(tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave == "square":
        return np.sign(np.sin(ph)) * 0.6 + np.sin(ph) * 0.4
    if wave == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    return np.sin(ph)


def tone(f, d, harmonics=(1,), decay=5.0):
    tt = t(d)
    s = sum(np.sin(2 * np.pi * f * h * tt) / (i + 1) for i, h in enumerate(harmonics))
    return s * env(len(tt), 0.002, curve=decay)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lowpass(x, cutoff):
    b, a = butter(2, cutoff / (SR / 2), "low")
    return lfilter(b, a, x)


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


def save(name, x, folder="sfx", gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    os.makedirs(os.path.join(ROOT, "assets", folder), exist_ok=True)
    wav = os.path.join(ROOT, "assets", folder, name + ".wav")
    ogg = wav[:-4] + ".ogg"
    wavfile.write(wav, SR, (x * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
                    "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    os.remove(wav)
    print("wrote", ogg)


# ---------------- Sound effects ----------------

def sfx():
    # Jump: bright springy upward "boing"
    j = sweep(260, 820, 0.16, "tri") * env(int(SR * 0.16), 0.004, curve=2.5)
    save("jump", j, gain=0.6)

    # Land: soft thump on the rug
    th = sweep(150, 60, 0.09) * env(int(SR * 0.09), 0.002, curve=6)
    save("land", mix(th, lowpass(noise(0.05), 900) * env(int(SR * 0.05), 0.001) * 0.5), gain=0.5)

    # Coin: two-note bell
    c = cat(tone(1318, 0.07, (1, 2, 3), 6), tone(1975, 0.28, (1, 2, 3), 5))
    save("coin", c, gain=0.45)

    # Whoosh: slipper flying
    n = noise(0.38)
    sw = np.concatenate([bandpass(n[i:i + 1700], 400 + i / 8, 1400 + i / 4)
                         for i in range(0, len(n), 1700)])[: len(n)]
    e = np.sin(np.linspace(0, np.pi, len(sw))) ** 2
    save("whoosh", sw * e, gain=0.55)

    # Wind-up: Mom winding her arm
    w = sweep(180, 520, 0.22, "tri") * np.linspace(0.2, 1, int(SR * 0.22))
    save("windup", w * env(len(w), 0.01, curve=1), gain=0.35)

    # Hit: slap + cartoon boing down
    slap = bandpass(noise(0.05), 1500, 6000) * env(int(SR * 0.05), 0.0005, curve=9)
    boing = sweep(520, 110, 0.45) * env(int(SR * 0.45), 0.003, curve=3)
    vib = 1 + 0.25 * np.sin(2 * np.pi * 18 * t(0.45))
    save("hit", mix(slap * 1.4, np.zeros(400), boing * vib * 0.8), gain=0.8)

    # Bounce: slipper hits the rug and bounces
    b = sweep(140, 330, 0.12) * env(int(SR * 0.12), 0.002, curve=4)
    save("bounce", b, gain=0.5)

    # Near miss: quick happy arpeggio
    notes = [784, 988, 1175, 1568]
    save("nearmiss", cat(*[tone(f, 0.07, (1, 2), 4) for f in notes]), gain=0.45)

    # Power-up: sparkly rising run
    notes = [523, 659, 784, 1046, 1318, 1568]
    save("powerup", cat(*[tone(f, 0.06, (1, 3), 3) for f in notes]) , gain=0.45)

    # Shield break: pop + ping
    pop = lowpass(noise(0.06), 3000) * env(int(SR * 0.06), 0.001, curve=7)
    save("shield", cat(pop, tone(1760, 0.25, (1, 2.7), 5)), gain=0.5)

    # Game over: sad trombone "wah wah wah waaah"
    def wah(f, d):
        tt = t(d)
        saw = 2 * ((f * tt) % 1) - 1
        e = np.minimum(1, tt * 20) * np.exp(-tt * 1.2)
        return lowpass(saw, 1400) * e
    last = wah(277, 1.1) * (1 + 0.04 * np.sin(2 * np.pi * 6 * t(1.1)))
    save("gameover", cat(wah(349, 0.32), wah(330, 0.32), wah(311, 0.32), last), gain=0.55)

    # UI click
    save("click", tone(1200, 0.035, (1,), 9) + tone(600, 0.035, (1,), 9), gain=0.35)

    # Reward / purchase: coin shower
    shower = np.zeros(int(SR * 0.9))
    for k in range(9):
        s = tone(1318 + k * 110, 0.2, (1, 2, 3), 6)
        o = int(SR * k * 0.07)
        shower[o:o + len(s)] += s[: len(shower) - o]
    save("reward", shower, gain=0.5)


# ---------------- Music: Persian 6/8 chase loop ----------------
# Santur-like plucks (Karplus-Strong) in dastgah Shur on G,
# with tombak (dom / tak) and a daf-like frame drum.

def pluck(freq, dur, bright=0.5):
    n = int(SR * dur)
    period = int(SR / freq)
    buf = rng.uniform(-1, 1, period) * bright + rng.uniform(-1, 1, period) * (1 - bright) * 0.3
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = 0.497 * (buf[i % period] + buf[(i + 1) % period])
    # santur hammers sound doubled strings: add a slightly detuned copy
    return out


def santur(freq, dur):
    a = pluck(freq, dur)
    b = pluck(freq * 1.003, dur)
    return (a + b) * 0.5


def dom(d=0.25):
    tt = t(d)
    f = 95 * np.exp(-tt * 9) + 55
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 14)


def tak(d=0.06):
    return bandpass(noise(d), 2500, 7000) * env(int(SR * d), 0.0005, curve=10)


def music():
    # Shur on G: G, A-koron (quarter-tone flat), Bb, C, D, Eb, F
    G = 196.0
    cents = {"G": 0, "Ak": 150, "Bb": 300, "C": 500, "D": 700, "Eb": 800, "F": 1000}
    def hz(n, octv=1):
        return G * octv * 2 ** (cents[n] / 1200)

    eighth = 60 / 168 / 2 * 1.0   # 6/8 at a lively tempo
    bar = eighth * 6
    bars = 16
    total = int(SR * bar * bars) + SR
    out = np.zeros(total)

    def place(sig, at, vol):
        i = int(SR * at)
        end = min(total, i + len(sig))
        out[i:end] += sig[: end - i] * vol

    # Melody: two 4-bar phrases, repeated with variation
    # (note, octave, length in eighths)
    A = [("G", 2, 1), ("Ak", 2, 1), ("Bb", 2, 1), ("C", 2, 2), ("Bb", 2, 1),
         ("Ak", 2, 1), ("Bb", 2, 1), ("Ak", 2, 1), ("G", 2, 3),
         ("D", 2, 1), ("Eb", 2, 1), ("D", 2, 1), ("C", 2, 2), ("Bb", 2, 1),
         ("C", 2, 1), ("Bb", 2, 1), ("Ak", 2, 1), ("G", 2, 3)]
    B = [("D", 2, 2), ("Eb", 2, 1), ("F", 2, 2), ("Eb", 2, 1),
         ("D", 2, 1), ("C", 2, 1), ("Bb", 2, 1), ("C", 2, 3),
         ("Bb", 2, 1), ("C", 2, 1), ("D", 2, 1), ("C", 2, 1), ("Bb", 2, 1), ("Ak", 2, 1),
         ("G", 2, 2), ("Ak", 2, 1), ("G", 2, 3)]
    phrase = A + B + A + B
    pos = 0.0
    for note, octv, ln in phrase:
        d = ln * eighth
        f = hz(note, octv)
        s = santur(f, min(d + 0.4, 1.2))
        place(s, pos, 0.55)
        # santur tremolo on long notes
        if ln >= 2:
            k = eighth / 2
            r = k
            while r < d - 0.01:
                place(santur(f, 0.35), pos + r, 0.3)
                r += k
        pos += d

    # Bass drone notes (G and D) each bar
    for b in range(bars):
        root = hz("G", 0.5) if b % 4 != 3 else hz("D", 0.5)
        place(santur(root, bar), b * bar, 0.35)

    # Tombak: dom . tak dom tak tak   (6/8 dance groove)
    pattern = ["dom", None, "tak", "dom", "tak", "tak"]
    for b in range(bars):
        for i, p in enumerate(pattern):
            at = b * bar + i * eighth
            if p == "dom":
                place(dom(), at, 0.9)
            elif p == "tak":
                place(tak(), at, 0.35 if i != 5 else 0.25)
        # daf-like accent on beat 1
        place(lowpass(noise(0.18), 1800) * env(int(SR * 0.18), 0.001, curve=8), b * bar, 0.25)

    loop = out[: int(SR * bar * bars)]
    # fold the tail into the start for a seamless loop
    tail = out[int(SR * bar * bars):]
    loop[: len(tail)] += tail
    save("chase", loop, folder="music", gain=0.8)


if __name__ == "__main__":
    sfx()
    music()
