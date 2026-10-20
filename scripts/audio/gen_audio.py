#!/usr/bin/env python3
"""EMPIRE RUSH audio forge (Phase 5): every sound effect and the music loop
are synthesised here from scratch (sine partials, filtered noise, envelopes),
so the game ships no third-party audio. Output is deterministic (fixed seed).

  python3 scripts/audio/gen_audio.py            # writes client/assets/audio/

Licence of the output: original work of the EMPIRE RUSH project, released
under CC0 1.0 (see docs/ASSET_REGISTER.csv, AUD-001/AUD-002).
Needs numpy; the music is encoded to Ogg Vorbis with ffmpeg.
"""
import os
import subprocess
import sys
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "client", "assets", "audio")
rng = np.random.default_rng(2026)


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, decay=0.2, sustain=0.0, release=0.0, dur=None):
    """Attack + exponential decay envelope over n samples."""
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    d = np.exp(-x / max(decay, 1e-4))
    e = a * (sustain + (1 - sustain) * d)
    if release > 0:
        r = np.clip((n / SR - x) / release, 0, 1)
        e *= r
    return e


def tone(freq, dur, partials=((1, 1.0),), decay=0.3, attack=0.004, detune=0.0):
    x = t(dur)
    s = np.zeros_like(x)
    for mult, amp in partials:
        f = freq * mult * (1 + detune * rng.uniform(-1, 1))
        s += amp * np.sin(2 * np.pi * f * x + rng.uniform(0, 2 * np.pi))
    return s * env(len(x), attack, decay)


def noise(dur):
    return rng.standard_normal(int(SR * dur))


def band(sig, lo, hi):
    """Band-pass by FFT masking with soft edges."""
    n = len(sig)
    spec = np.fft.rfft(sig)
    f = np.fft.rfftfreq(n, 1 / SR)
    mask = 1 / (1 + (lo / np.maximum(f, 1)) ** 4) * 1 / (1 + (f / max(hi, 1)) ** 4)
    return np.fft.irfft(spec * mask, n)


def lowpass(sig, cutoff):
    return band(sig, 1, cutoff)


def mix(*parts, at=None):
    """Mix parts; `at` gives each part's start time (s)."""
    at = at or [0.0] * len(parts)
    n = max(int(a * SR) + len(p) for p, a in zip(parts, at))
    out = np.zeros(n)
    for p, a in zip(parts, at):
        i = int(a * SR)
        out[i:i + len(p)] += p
    return out


def norm(sig, peak=0.85):
    m = np.max(np.abs(sig)) or 1.0
    return sig / m * peak


def fade(sig, ms=4):
    k = int(SR * ms / 1000)
    if k and len(sig) > 2 * k:
        sig[:k] *= np.linspace(0, 1, k)
        sig[-k:] *= np.linspace(1, 0, k)
    return sig


def write_wav(name, sig, peak=0.85):
    sig = fade(norm(sig, peak))
    path = os.path.join(OUT, "sfx", name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(sig, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", os.path.relpath(path, ROOT), f"{len(sig) / SR:.2f}s")


BELL = ((1, 1.0), (2.76, 0.35), (5.4, 0.15), (8.9, 0.06))   # inharmonic, metallic
MARIMBA = ((1, 1.0), (4.0, 0.25), (9.9, 0.05))
WOOD = ((1, 1.0), (2.3, 0.4), (4.1, 0.15))


def note(n):
    """MIDI note -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def knock(freq, dur=0.09, bright=0.4):
    body = tone(freq, dur, WOOD, decay=0.025)
    click = band(noise(0.012), 1500, 6000) * env(int(SR * 0.012), 0.0005, 0.003) * bright
    return mix(body, click)


def sfx():
    # UI
    write_wav("ui_hover", tone(1800, 0.05, ((1, 1.0), (2, 0.2)), decay=0.012), 0.35)
    write_wav("ui_click", mix(knock(620, 0.07, 0.6), tone(1250, 0.05, decay=0.01) * 0.3), 0.6)
    write_wav("ui_confirm", mix(tone(note(84), 0.35, MARIMBA, 0.1), tone(note(91), 0.45, MARIMBA, 0.14), at=[0, 0.07]), 0.6)
    write_wav("ui_back", mix(tone(note(79), 0.25, MARIMBA, 0.08), tone(note(74), 0.3, MARIMBA, 0.1), at=[0, 0.06]), 0.5)
    # Dice: a rattle of wooden clicks, then the landing.
    parts, at = [], []
    tt = 0.0
    for k in range(11):
        parts.append(knock(rng.uniform(900, 1600), 0.04, 1.0) * (1 - k / 14))
        at.append(tt)
        tt += rng.uniform(0.03, 0.06)
    write_wav("dice_roll", mix(*parts, at=at), 0.7)
    write_wav("dice_land", mix(knock(240, 0.16, 0.8), knock(300, 0.14, 0.6) * 0.8, at=[0, 0.09]), 0.8)
    # Pawn step: a soft tok on the board.
    write_wav("step", knock(520, 0.07, 0.25), 0.5)
    # Money and property.
    coin = mix(tone(2600, 0.5, BELL, 0.12), tone(3900, 0.4, BELL, 0.08) * 0.6, at=[0, 0.05])
    write_wav("buy", mix(coin, tone(note(76), 0.4, MARIMBA, 0.15) * 0.6, tone(note(83), 0.45, MARIMBA, 0.18) * 0.6, at=[0, 0.02, 0.1]), 0.7)
    arp = [note(n) for n in (72, 76, 79, 84)]
    write_wav("upgrade", mix(*[tone(f, 0.5, MARIMBA, 0.16) for f in arp], tone(arp[-1] * 2, 0.6, BELL, 0.25) * 0.3,
                             at=[0, 0.07, 0.14, 0.21, 0.25]), 0.7)
    write_wav("cash_gain", mix(tone(3200, 0.3, BELL, 0.06), tone(4200, 0.25, BELL, 0.05) * 0.7, at=[0, 0.06]), 0.45)
    write_wav("cash_loss", mix(tone(note(67), 0.3, MARIMBA, 0.1), tone(note(62), 0.4, MARIMBA, 0.14), at=[0, 0.1]), 0.45)
    # Cards, choices, auctions.
    sweep = band(noise(0.35), 600, 4000) * np.sin(np.linspace(0, np.pi, int(SR * 0.35))) ** 2
    write_wav("card", mix(sweep * 0.6, knock(900, 0.05, 0.6) * 0.5, at=[0, 0.28]), 0.55)
    shimmer = mix(*[tone(note(n), 0.6, BELL, 0.2) * 0.5 for n in (88, 91, 95, 100)], at=[0, 0.06, 0.12, 0.18])
    write_wav("choice", shimmer, 0.45)
    write_wav("auction", mix(knock(180, 0.18, 0.9), knock(180, 0.18, 0.9), at=[0, 0.22]), 0.8)
    write_wav("bid", knock(210, 0.15, 0.7), 0.6)
    # Trouble.
    write_wav("rescue", mix(tone(note(57), 0.35, ((1, 1), (2, 0.3)), 0.2), tone(note(53), 0.45, ((1, 1), (2, 0.3)), 0.25), at=[0, 0.22]), 0.55)
    x = t(0.9)
    fall = np.sin(2 * np.pi * np.cumsum(np.linspace(220, 90, len(x))) / SR) * env(len(x), 0.01, 0.4)
    write_wav("bankrupt", fall, 0.6)
    # Turn and match end.
    write_wav("your_turn", mix(tone(note(88), 0.6, BELL, 0.25), tone(note(93), 0.7, BELL, 0.3) * 0.7, at=[0, 0.09]), 0.4)
    fan = [note(n) for n in (72, 76, 79, 84)]
    chord = mix(*[tone(f, 1.6, MARIMBA, 0.6) * 0.5 for f in fan])
    write_wav("win", mix(*[tone(f, 0.4, MARIMBA, 0.15) for f in fan], chord, tone(fan[-1] * 2, 1.4, BELL, 0.5) * 0.3,
                         at=[0, 0.11, 0.22, 0.33, 0.48, 0.5]), 0.75)
    write_wav("lose", mix(*[tone(note(n), 0.6, MARIMBA, 0.25) for n in (72, 68, 65)], at=[0, 0.18, 0.36]), 0.55)


def sfx_phase51():
    """Phase 5.1 dice beats, on their own seed so the Phase 5 files stay
    byte-identical: a bounce on the felt tray (soft, low) and the result
    chime when "5 + 6 = 11" appears."""
    global rng
    keep, rng = rng, np.random.default_rng(20261)
    felt = lowpass(band(noise(0.06), 200, 2500) * env(int(SR * 0.06), 0.001, 0.012), 3000)
    write_wav("dice_bounce", mix(knock(380, 0.08, 0.5), felt * 0.6), 0.55)
    write_wav("dice_result", mix(tone(note(79), 0.4, MARIMBA, 0.12), tone(note(84), 0.5, MARIMBA, 0.16),
                                 tone(note(91), 0.55, BELL, 0.2) * 0.35, at=[0, 0.06, 0.12]), 0.55)
    rng = keep


def music():
    """~48 s seamless loop: warm pad chords + a quiet plucked arpeggio,
    low-passed so it stays under the effects."""
    bpm = 80
    beat = 60 / bpm
    bars = 16
    total = bars * 4 * beat
    n = int(SR * total)
    out = np.zeros(n)
    prog = [(60, 64, 67, 71), (57, 60, 64, 67), (53, 57, 60, 64), (55, 59, 62, 67)]  # Cmaj7 Am7 Fmaj7 G6
    x_bar = t(4 * beat)
    for b in range(bars):
        chord = prog[b % 4]
        start = int(b * 4 * beat * SR)
        pad = np.zeros(len(x_bar))
        for m in chord:
            for det in (-0.004, 0.004):
                f = note(m - 12) * (1 + det)
                pad += np.sin(2 * np.pi * f * x_bar) + 0.3 * np.sin(2 * np.pi * 2 * f * x_bar)
        # Slow swell, overlapping into the next bar for a seamless bed.
        sw = np.sin(np.linspace(0, np.pi, len(x_bar))) ** 0.8
        seg = pad * sw * 0.12
        end = min(n, start + len(seg))
        out[start:end] += seg[:end - start]
        # Plucked arpeggio, eighth notes, soft.
        for k in range(8):
            if (b + k) % 3 == 2:
                continue
            m = chord[k % 4] + 12
            p = tone(note(m), 0.9, MARIMBA, 0.35) * 0.07
            i = start + int(k * beat * 0.5 * SR)
            j = min(n, i + len(p))
            out[i:j] += p[:j - i]
    # Bass on each bar.
    for b in range(bars):
        root = prog[b % 4][0] - 24
        p = tone(note(root), 4 * beat, ((1, 1.0), (2, 0.2)), decay=1.4, attack=0.03) * 0.18
        i = int(b * 4 * beat * SR)
        j = min(n, i + len(p))
        out[i:j] += p[:j - i]
    out = lowpass(out, 2400)
    # Seamless loop: crossfade the tail into the head.
    xf = int(SR * 1.5)
    out[:xf] = out[:xf] * np.linspace(0, 1, xf) + out[-xf:] * np.linspace(1, 0, xf)
    out = out[:-xf]
    out = norm(out, 0.6)
    os.makedirs(os.path.join(OUT, "music"), exist_ok=True)
    tmp = os.path.join(OUT, "music", "_tmp.wav")
    data = (np.clip(out, -1, 1) * 32767).astype("<i2")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    dst = os.path.join(OUT, "music", "theme_loop.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3",
                    "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", dst], check=True)
    os.remove(tmp)
    print("wrote", os.path.relpath(dst, ROOT), f"{len(out) / SR:.1f}s")


if __name__ == "__main__":
    sfx()
    music()
    sfx_phase51()
    sys.exit(0)
