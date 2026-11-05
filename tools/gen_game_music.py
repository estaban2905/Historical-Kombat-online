#!/usr/bin/env python3
"""Sintetiza la música de menús y combate: assets/music/select.ogg y assets/music/fight.ogg.

Uso (desde la carpeta del proyecto; necesita numpy y ffmpeg en el PATH):
    python tools/gen_game_music.py

Ambas pistas son bucles sin costura (las colas de las notas se pliegan al principio).
Música PROVISIONAL generada por código, igual que intro.ogg y los efectos.
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 32000
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "music"
rng = np.random.default_rng(1905)


def midi(n: float) -> float:
    return 440.0 * 2 ** ((n - 69) / 12)


class Track:
    def __init__(self, bpm: float, bars: int):
        self.beat = 60.0 / bpm
        self.bars = bars
        self.n = int(round(bars * 4 * self.beat * SR))
        self.buf = np.zeros(self.n)

    def add(self, t: float, sig: np.ndarray, gain: float = 1.0) -> None:
        """Suma con plegado circular para que el bucle no tenga corte."""
        i = int(t * SR) % self.n
        idx = (np.arange(len(sig)) + i) % self.n
        np.add.at(self.buf, idx, sig * gain)


def tt(d: float) -> np.ndarray:
    return np.arange(int(d * SR)) / SR


def adsr(d: float, a: float, r: float) -> np.ndarray:
    n = int(d * SR)
    e = np.ones(n)
    na = max(1, int(a * SR))
    nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return e


def saw(f: float, d: float, detune: float = 0.004) -> np.ndarray:
    t = tt(d)
    out = np.zeros_like(t)
    for k in (-1, 0, 1):
        ff = f * (1 + k * detune)
        out += 2 * ((t * ff) % 1.0) - 1
    return out / 3


def tri(f: float, d: float) -> np.ndarray:
    return 2 * np.abs(2 * ((tt(d) * f) % 1.0) - 1) - 1


def lowpass(x: np.ndarray, k: float) -> np.ndarray:
    """Filtro de un polo (k en 0..1, más alto = más abierto)."""
    out = np.empty_like(x)
    y = 0.0
    for i, v in enumerate(x):
        y += k * (v - y)
        out[i] = y
    return out


def kick(d: float = 0.35) -> np.ndarray:
    t = tt(d)
    f = 45 + 110 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9)


def snare(d: float = 0.22) -> np.ndarray:
    t = tt(d)
    nz = rng.uniform(-1, 1, len(t))
    return (nz * 0.8 + np.sin(2 * np.pi * 190 * t) * 0.4) * np.exp(-t * 20)


def hat(d: float = 0.05) -> np.ndarray:
    t = tt(d)
    nz = rng.uniform(-1, 1, len(t))
    nz = nz - np.concatenate(([0], nz[:-1]))  # pasa-altos burdo
    return nz * np.exp(-t * 90)


def pad(f: float, d: float) -> np.ndarray:
    return saw(f, d, 0.006) * adsr(d, d * 0.4, d * 0.4)


def finish(tr: Track, name: str, peak: float = 0.85) -> None:
    x = tr.buf
    x = np.tanh(x * 1.1)
    x = x / max(1e-9, np.max(np.abs(x))) * peak
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "m.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((x * 32767).astype("<i2").tobytes())
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4",
             str(OUT / name)],
            check=True,
        )
    print(f"{name}: {tr.n / SR:.1f}s")


# Progresión Am - F - C - G (fundamentales graves, MIDI) y tríadas
PROG = [
    (45, [57, 60, 64]),   # Am
    (41, [53, 57, 60]),   # F
    (48, [55, 60, 64]),   # C
    (43, [55, 59, 62]),   # G
]


def select_track() -> None:
    """Selección de partida: 84 BPM, cálida y expectante."""
    tr = Track(84, 16)
    b = tr.beat
    for bar in range(tr.bars):
        root, tri_notes = PROG[bar % 4]
        t0 = bar * 4 * b
        for nt in tri_notes:
            tr.add(t0, lowpass(pad(midi(nt), 4 * b), 0.08), 0.22)
        tr.add(t0, tri(midi(root - 12), 4 * b) * adsr(4 * b, 0.05, 0.4), 0.5)
        # arpegio en corcheas
        order = [0, 1, 2, 1, 2, 1, 2, 1]
        for k in range(8):
            nt = tri_notes[order[k]] + 12
            d = b * 0.6
            tr.add(t0 + k * b / 2, tri(midi(nt), d) * adsr(d, 0.005, 0.25), 0.28)
        # pulso suave
        for beat in (0, 2):
            tr.add(t0 + beat * b, kick() , 0.35)
        if bar % 2 == 1:
            tr.add(t0 + 3.5 * b, hat(), 0.25)
        # melodía lenta en la segunda mitad
        if bar >= 8:
            for k, off in enumerate((0, 7, 4, 2) if bar % 4 in (0, 2) else (0, 4, 7, 4)):
                nt = tri_notes[0] + 24 + (off if off < 12 else 0)
                d = b * 1.8
                tr.add(t0 + k * b, lowpass(saw(midi(nt), d), 0.12) * adsr(d, 0.02, 0.5), 0.18)
    finish(tr, "select.ogg")


def fight_track() -> None:
    """Combate: 138 BPM, bajo sierra, bombo, caja y riff."""
    tr = Track(138, 16)
    b = tr.beat
    riff = [0, 0, 12, 0, 7, 0, 10, 12]
    for bar in range(tr.bars):
        root, tri_notes = PROG[(bar // 2) % 4] if False else PROG[bar % 4]
        t0 = bar * 4 * b
        # bajo en corcheas
        for k in range(8):
            nt = root + (12 if riff[k] == 12 else 0)
            d = b * 0.45
            sig = lowpass(saw(midi(nt - 12), d, 0.002), 0.25) * adsr(d, 0.004, 0.12)
            tr.add(t0 + k * b / 2, sig, 0.55)
        # batería
        for beat in range(4):
            tr.add(t0 + beat * b, kick(), 0.8)
            tr.add(t0 + (beat + 0.5) * b, hat(), 0.3)
        tr.add(t0 + 1 * b, snare(), 0.55)
        tr.add(t0 + 3 * b, snare(), 0.55)
        if bar % 4 == 3:
            for k in range(4):
                tr.add(t0 + 3.5 * b + k * b / 8, snare(0.12), 0.35)
        # acordes cortantes a contratiempo
        for beat in (0.5, 1.5, 2.5, 3.5):
            for nt in tri_notes:
                d = b * 0.3
                tr.add(t0 + beat * b, lowpass(saw(midi(nt), d), 0.18) * adsr(d, 0.004, 0.1), 0.16)
        # lead en la segunda mitad
        if bar >= 8:
            lead = [tri_notes[2], tri_notes[1], tri_notes[2], tri_notes[0] + 12]
            for k, nt in enumerate(lead):
                d = b * 0.95
                tr.add(t0 + k * b, lowpass(saw(midi(nt + 12), d, 0.007), 0.3) * adsr(d, 0.01, 0.3), 0.2)
    finish(tr, "fight.ogg")


if __name__ == "__main__":
    select_track()
    fight_track()
