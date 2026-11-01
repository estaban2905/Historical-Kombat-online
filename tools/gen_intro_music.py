#!/usr/bin/env python3
"""Sintetiza la música de la intro (assets/music/intro.ogg), sincronizada con scripts/ui/intro_screen.gd.

Uso (desde la carpeta del proyecto; necesita numpy y ffmpeg en el PATH):
    python tools/gen_intro_music.py

Tres etapas, como en el guion:
    0:00-1:06   misterio y ciencia, luego guerra y destino (taiko, trompetas, kultrún, gaita, coros)
    1:06-1:30   el juicio del Nexo (coros, graves, multitud)
    1:30-1:52   combate arcade a 140 BPM (bajo, kick, metales industriales)
    1:52-2:04   choque final, logotipo, campanada y latido
Los instantes clave (T_*) deben coincidir con las constantes de intro_screen.gd.
Es música PROVISIONAL generada por código, igual que los efectos de assets/sounds.
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 22050
LEN = 124.0
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "music" / "intro.ogg"

# Instantes clave (segundos). Mantener iguales a intro_screen.gd.
T_LEVER = 15.5     # Tesla acciona el interruptor
T_BLAST = 17.2     # estallido tras el silencio
T_JUDGE = 66.0     # aparece la esfera del Nexo
T_ARCADE = 90.0    # empiezan las presentaciones, entra el ritmo industrial
T_BUILD = 111.0    # subida antes del choque
T_CLASH = 115.0    # choque de puños
T_LOGO = 116.0     # aparece el logotipo

rng = np.random.default_rng(1815)
N = int(LEN * SR)
mix = np.zeros(N, dtype=np.float64)
mute = np.ones(N, dtype=np.float64)   # máscara para el silencio antes de la explosión

def add(t0: float, sig: np.ndarray, gain: float = 1.0) -> None:
    i = int(t0 * SR)
    if i >= N or i < 0:
        return
    j = min(N, i + len(sig))
    mix[i:j] += sig[: j - i] * gain

def tt(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR

def env(dur: float, a: float, d: float = 0.0, s: float = 1.0, r: float = 0.05) -> np.ndarray:
    """ADSR lineal; d=0 -> sin caída."""
    n = int(dur * SR)
    e = np.ones(n)
    na = max(1, int(a * SR))
    e[:na] = np.linspace(0, 1, na)
    if d > 0:
        nd = int(d * SR)
        e[na:na + nd] = np.linspace(1, s, min(nd, max(0, n - na)))[: max(0, min(nd, n - na))]
        e[na + nd:] = s
    nr = max(1, int(r * SR))
    e[-nr:] *= np.linspace(1, 0, nr)
    return e

def expdecay(dur: float, k: float) -> np.ndarray:
    return np.exp(-tt(dur) * k)

def lowpass(x: np.ndarray, n: int) -> np.ndarray:
    return np.convolve(x, np.ones(n) / n, mode="same")

# ----------------------------------------------------------------------------- instrumentos
def harm(f: float, dur: float, weights, vib: float = 0.0, vib_hz: float = 5.5, detune: float = 0.0) -> np.ndarray:
    t = tt(dur)
    ph = 2 * np.pi * f * t + (vib * np.sin(2 * np.pi * vib_hz * t) if vib else 0)
    out = np.zeros_like(t)
    for k, w in enumerate(weights, start=1):
        out += w * np.sin(k * ph)
        if detune:
            out += w * 0.6 * np.sin(k * (ph * (1 + detune)))
    return out

def kick(t0: float, vol: float = 1.0) -> None:
    t = tt(0.32)
    f = 48 + 90 * np.exp(-t * 35)
    add(t0, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11), 0.9 * vol)

def taiko(t0: float, vol: float = 1.0) -> None:
    t = tt(1.1)
    f = 52 + 70 * np.exp(-t * 18)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4.5)
    skin = lowpass(rng.standard_normal(len(t)), 6) * np.exp(-t * 22)
    add(t0, body + 0.5 * skin, 1.0 * vol)

def kultrun(t0: float, vol: float = 1.0) -> None:
    t = tt(0.35)
    f = 150 + 60 * np.exp(-t * 30)
    add(t0, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14) + 0.3 * rng.standard_normal(len(t)) * np.exp(-t * 40), 0.55 * vol)

def hat(t0: float, vol: float = 1.0, open_: bool = False) -> None:
    n = rng.standard_normal(int((0.18 if open_ else 0.05) * SR))
    n = np.diff(n, prepend=0)
    add(t0, n * np.exp(-tt(len(n) / SR) * (14 if open_ else 55)), 0.25 * vol)

def snare(t0: float, vol: float = 1.0) -> None:
    t = tt(0.22)
    n = rng.standard_normal(len(t)) * np.exp(-t * 20)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25)
    add(t0, n * 0.6 + tone * 0.6, 0.6 * vol)

def metal(t0: float, vol: float = 1.0, f: float = 420.0) -> None:
    t = tt(0.7)
    s = sum(np.sin(2 * np.pi * f * r * t) / (i + 1) for i, r in enumerate((1.0, 1.47, 2.09, 2.56, 3.4)))
    add(t0, s * np.exp(-t * 7) * 0.3, vol)

def bell(t0: float, f: float, vol: float = 1.0, dur: float = 6.0) -> None:
    t = tt(dur)
    s = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * k)
            for r, a, k in ((0.5, 0.8, 0.7), (1.0, 1.0, 0.9), (1.19, 0.6, 1.3), (1.56, 0.5, 1.6), (2.0, 0.5, 1.9), (2.74, 0.3, 2.6), (3.76, 0.2, 3.5)))
    add(t0, s * 0.5, vol)

def boom(t0: float, vol: float = 1.0) -> None:
    t = tt(3.5)
    f = 28 + 90 * np.exp(-t * 5)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 1.3)
    s += 0.5 * lowpass(rng.standard_normal(len(t)), 14) * np.exp(-t * 3)
    add(t0, s, 1.2 * vol)

def tick(t0: float, tock: bool, vol: float = 1.0) -> None:
    t = tt(0.06)
    f = 1500 if tock else 2300
    add(t0, (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.3 * t)) * np.exp(-t * 90) * 0.5
        + rng.standard_normal(len(t)) * np.exp(-t * 200) * 0.3, vol)

def crackle(t0: float, t1: float, density: float, vol: float) -> None:
    n = int((t1 - t0) * SR)
    x = (rng.random(n) < density / SR) * rng.standard_normal(n)
    x = np.diff(lowpass(x, 3), prepend=0)
    add(t0, x, vol)

def pad(t0: float, dur: float, freqs, vol: float = 0.3, attack: float = 1.5, release: float = 1.5) -> None:
    """Coro sostenido: armónicos suaves con vibrato lento."""
    w = (1.0, 0.45, 0.6, 0.2, 0.25, 0.1)
    s = sum(harm(f, dur, w, vib=0.6, vib_hz=5.0 + 0.3 * i, detune=0.003) for i, f in enumerate(freqs))
    e = env(dur, attack, 0, 1, release)
    add(t0, s * e / max(1, len(freqs)), vol)

def brass(t0: float, dur: float, f: float, vol: float = 0.4) -> None:
    w = [1 / k for k in range(1, 11)]
    t = tt(dur)
    scoop = 1 - 0.03 * np.exp(-t * 18)
    ph = 2 * np.pi * f * np.cumsum(scoop) / SR
    s = sum(wk * np.sin((k + 1) * ph) for k, wk in enumerate(w))
    add(t0, s * env(dur, 0.07, 0.15, 0.8, 0.12), vol)

def reed(t0: float, dur: float, f: float, vol: float = 0.3) -> None:
    """Gaita: lengüeta nasal, armónicos impares, un poco desafinada."""
    w = [1, 0.1, 0.8, 0.1, 0.6, 0.05, 0.5, 0.1, 0.3]
    s = harm(f, dur, w, vib=0.3, vib_hz=6.0, detune=0.006)
    add(t0, s * env(dur, 0.04, 0.1, 0.85, 0.08), vol)

def bass(t0: float, dur: float, f: float, vol: float = 0.5) -> None:
    w = [1 / k for k in range(1, 14)]
    s = harm(f, dur, w, detune=0.004)
    add(t0, s * env(dur, 0.005, 0.12, 0.55, 0.03), vol)

def pluck(t0: float, f: float, vol: float = 0.25) -> None:
    w = [1, 0.5, 0.33, 0.25, 0.2]
    s = harm(f, 0.3, w)
    add(t0, s * expdecay(0.3, 12), vol)

def riser(t0: float, t1: float, vol: float = 0.5, f0: float = 200, f1: float = 2400) -> None:
    dur = t1 - t0
    t = tt(dur)
    k = t / dur
    f = f0 * (f1 / f0) ** k
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR)
    noise = np.diff(rng.standard_normal(len(t)), prepend=0)
    add(t0, (0.5 * tone + 0.5 * noise) * k ** 2.0, vol)

def crowd(t0: float, t1: float, vol: float) -> None:
    dur = t1 - t0
    t = tt(dur)
    n = lowpass(rng.standard_normal(len(t)), 30)
    n = n / (np.abs(n).max() + 1e-9)
    swell = (0.4 + 0.6 * np.sin(np.pi * t / dur / 1.0) ** 2) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.7 * t))
    add(t0, n * swell, vol)

def heartbeat(t0: float, vol: float = 1.0) -> None:
    for dt, v in ((0.0, 1.0), (0.28, 0.7)):
        t = tt(0.4)
        f = 40 + 40 * np.exp(-t * 25)
        add(t0 + dt, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9), 1.1 * vol * v)

def hz(note: str) -> float:
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    n = names[note[0]]
    i = 1
    if note[i] == "b":
        n -= 1
        i += 1
    elif note[i] == "#":
        n += 1
        i += 1
    octave = int(note[i:])
    return 440.0 * 2 ** ((n + 12 * (octave + 1) - 69) / 12)

# ----------------------------------------------------------------------------- partitura
def stage_mystery() -> None:
    """0:00 - 0:33. Tic-tac, violonchelos oscuros, coros, electricidad, silencio y estallido."""
    beat = 0.6
    t = 0.4
    i = 0
    while t < T_LEVER + 1.0:
        tick(t, i % 2 == 1, 0.8 if i % 2 == 0 else 0.6)
        t += beat
        i += 1
    # Violonchelos: notas largas graves
    for k, (n, d) in enumerate((("A1", 7.5), ("F1", 7.5), ("G1", 7.5), ("E1", 7.0))):
        t0 = k * 7.5
        if t0 >= T_LEVER + 1:
            break
        s = harm(hz(n), d, [1, 0.7, 0.5, 0.35, 0.25, 0.15], vib=0.5, vib_hz=4.5, detune=0.004)
        add(t0, s * env(d, 1.8, 0, 1, 1.5), 0.55)
        s2 = harm(hz(n) * 2, d, [1, 0.5, 0.3, 0.2], vib=0.8, vib_hz=5, detune=0.004)
        add(t0, s2 * env(d, 2.5, 0, 1, 1.5), 0.2)
    # Coros gregorianos: acordes de Am / F
    pad(5.0, 7.0, [hz("A3"), hz("C4"), hz("E4")], 0.30, 2.5, 2.0)
    pad(12.0, 5.0, [hz("F3"), hz("A3"), hz("C4")], 0.34, 2.0, 0.5)
    # Electricidad estática
    crackle(2.0, T_LEVER, 20, 0.35)
    crackle(T_LEVER - 4, T_LEVER, 90, 0.5)
    riser(T_LEVER - 2.5, T_LEVER + 0.9, 0.45, 150, 3000)
    # Silencio absoluto antes de la detonación
    sil0, sil1 = T_LEVER + 0.95, T_BLAST
    mute[int(sil0 * SR):int(sil1 * SR)] = 0.0
    # Detonación + taiko
    boom(T_BLAST, 1.0)
    taiko(T_BLAST, 1.0)
    taiko(T_BLAST + 0.5, 0.8)
    taiko(T_BLAST + 1.0, 0.9)
    taiko(T_BLAST + 1.5, 1.0)
    # Después: pulso grave del Nexo y coro sombrío
    pad(T_BLAST + 1.0, 14.0, [hz("D3"), hz("F3"), hz("A3")], 0.30, 3.0, 3.0)
    for k in range(6):
        taiko(T_BLAST + 3.0 + k * 2.4, 0.55)
    s = harm(hz("D1"), 16, [1, 0.6, 0.3], vib=0.2)
    add(T_BLAST, s * env(16, 1.0, 0, 1, 3), 0.7)

def stage_war() -> None:
    """0:33 - 1:06. Guerra y destino: taiko, trompetas imperiales, kultrún, gaitas."""
    bpm = 96
    beat = 60 / bpm
    t0 = 33.0
    bars = int((T_JUDGE - t0) / (4 * beat))
    chords = [("D2", ("D3", "F3", "A3")), ("Bb1", ("Bb2", "D3", "F3")), ("C2", ("C3", "E3", "G3")), ("D2", ("D3", "F3", "A3"))]
    motif = [
        [("D5", 2), ("C5", 1), ("A4", 1)],
        [("Bb4", 2), ("A4", 1), ("F4", 1)],
        [("G4", 2), ("A4", 1), ("C5", 1)],
        [("D5", 3), ("A4", 1)],
    ]
    for b in range(bars):
        bt = t0 + b * 4 * beat
        root, ch = chords[b % 4]
        bass(bt, 4 * beat * 0.98, hz(root), 0.42)
        pad(bt, 4 * beat, [hz(n) for n in ch], 0.20, 0.6, 0.6)
        # Percusión: taiko fuerte en 1, kultrún en los contratiempos
        taiko(bt, 1.0)
        taiko(bt + 2 * beat, 0.7)
        taiko(bt + 3 * beat, 0.6)
        for off in (1.5, 2.5, 3.5):
            kultrun(bt + off * beat, 0.7)
        # Trompetas imperiales a partir del compás 2
        if b >= 2:
            x = bt
            for n, d in motif[b % 4]:
                brass(x, d * beat * 0.95, hz(n), 0.30)
                x += d * beat
        # Gaita celta: bordón + floritura en los compases pares
        if b >= 4:
            reed(bt, 4 * beat, hz("D3"), 0.14)
            reed(bt, 4 * beat, hz("A3"), 0.10)
            if b % 2 == 0:
                for k, n in enumerate(("A4", "C5", "D5", "C5", "A4", "G4", "A4", "D4")):
                    reed(bt + k * 0.5 * beat * 2, beat * 0.9, hz(n), 0.17)
    # Subida hacia el juicio
    riser(T_JUDGE - 4, T_JUDGE, 0.45, 180, 2600)
    # Silencio brevísimo antes de que hable el Nexo
    taiko(T_JUDGE, 1.0)
    boom(T_JUDGE, 0.7)

def stage_judgement() -> None:
    """1:06 - 1:30. El Nexo habla: coros monumentales, vibración grave y multitud."""
    chords = [("Bb", ("Bb3", "D4", "F4")), ("C", ("C4", "E4", "G4")), ("D", ("D4", "F4", "A4")), ("A", ("A3", "C#4", "E4"))]
    dur_c = 6.0
    for k, (_n, ch) in enumerate(chords):
        t0 = T_JUDGE + k * dur_c
        pad(t0, dur_c + 0.8, [hz(n) for n in ch], 0.42, 1.2, 1.0)
        pad(t0, dur_c + 0.8, [hz(n) / 2 for n in ch], 0.28, 1.2, 1.0)
        s = harm(hz(("Bb1", "C2", "D2", "A1")[k]), dur_c + 0.5, [1, 0.8, 0.4, 0.2], vib=0.2)
        add(t0, s * env(dur_c + 0.5, 0.5, 0, 1, 0.8), 0.6)
        taiko(t0, 0.9)
    crowd(T_JUDGE + 8, T_ARCADE, 0.55)
    # Latidos graves del coliseo
    for k in range(9):
        heartbeat(T_JUDGE + 3 + k * 2.6, 0.45)
    # Subida final y golpe de entrada del ritmo industrial
    riser(T_ARCADE - 5, T_ARCADE, 0.55, 150, 3500)
    for k in range(8):
        snare(T_ARCADE - 2.0 + k * 0.25, 0.3 + 0.08 * k)

def stage_arcade() -> None:
    """1:30 - 1:55. Combate arcade a 140 BPM: industrial, bajos electrónicos, impactos metálicos."""
    bpm = 140
    beat = 60 / bpm
    t = T_ARCADE
    bar = 0
    bass_pat = ["D2", "D2", "F2", "D2", "C2", "D2", "A1", "C2"]
    arp = ["D4", "F4", "A4", "C5", "A4", "F4", "D5", "C5"]
    while t < T_BUILD:
        bt = t
        for step in range(8):
            ts = bt + step * beat * 0.5
            if ts >= T_BUILD:
                break
            bass(ts, beat * 0.45, hz(bass_pat[(step + bar * 3) % 8]), 0.34)
            if bar >= 1:
                pluck(ts, hz(arp[(step + bar) % 8]), 0.17)
            hat(ts + beat * 0.25, 0.7)
        for beat_i in range(4):
            tk = bt + beat_i * beat
            if tk >= T_BUILD:
                break
            kick(tk, 1.0)
            if beat_i in (1, 3):
                snare(tk, 1.0)
                metal(tk, 0.7, 380)
        if bar % 4 == 3:
            metal(bt + 3.5 * beat, 0.8, 520)
            hat(bt + 3.75 * beat, 1.0, True)
        # Líneas de bronce industrial en los compases 3 y 4 de cada frase de 4
        if bar % 4 in (2, 3):
            brass(bt, 2 * beat, hz("D4" if bar % 4 == 2 else "F4"), 0.22)
            brass(bt + 2 * beat, 2 * beat, hz("A4" if bar % 4 == 2 else "C5"), 0.22)
        t += 4 * beat
        bar += 1
    # Subida frenética hasta el choque
    riser(T_BUILD - 0.2, T_CLASH, 0.6, 250, 5000)
    for k in range(16):
        snare(T_BUILD + 0.5 + k * (T_CLASH - T_BUILD - 0.7) / 16, 0.35 + 0.04 * k)

def stage_finale() -> None:
    """1:55 - 2:04. Choque, silencio, logotipo, campanada, descarga eléctrica y último latido."""
    # Choque congelado
    boom(T_CLASH, 1.0)
    taiko(T_CLASH, 1.0)
    metal(T_CLASH, 1.0, 300)
    snare(T_CLASH, 1.0)
    crackle(T_CLASH, T_CLASH + 0.5, 600, 0.9)
    mute[int((T_CLASH + 0.18) * SR):int((T_LOGO - 0.05) * SR)] *= 0.12   # casi silencio con el cuadro congelado
    # Logotipo: acorde de metales y coro, campanada de bronce
    bell(T_LOGO, hz("D3"), 1.1, 7.0)
    boom(T_LOGO, 0.9)
    for n in ("D3", "A3", "D4", "F4", "A4"):
        brass(T_LOGO, 3.0, hz(n), 0.17)
    pad(T_LOGO, 6.0, [hz("D3"), hz("A3"), hz("F4")], 0.38, 0.3, 2.5)
    # Descarga eléctrica que se apaga
    crackle(T_LOGO + 0.5, T_LOGO + 3.0, 300, 0.5)
    mix[int((T_LOGO + 0.5) * SR):int((T_LOGO + 3.0) * SR)] *= np.linspace(1, 0.75, int(2.5 * SR))
    # Último latido
    heartbeat(T_LOGO + 5.0, 1.0)

def main() -> None:
    stage_mystery()
    stage_war()
    stage_judgement()
    stage_arcade()
    stage_finale()
    out = mix * mute
    # Fundido de entrada y salida
    fi = int(1.0 * SR)
    out[:fi] *= np.linspace(0, 1, fi)
    fo = int(2.5 * SR)
    out[-fo:] *= np.linspace(1, 0, fo)
    out = np.tanh(out * 0.9) / np.tanh(0.9)
    out = out / (np.abs(out).max() + 1e-9) * 0.92
    pcm = (out * 32767).astype(np.int16)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "intro.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        # Un poco de reverberación de sala grande y volumen homogéneo.
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
                        "-af", "aecho=0.8:0.7:45|90|180:0.30|0.20|0.12,alimiter=limit=0.95",
                        "-c:a", "libvorbis", "-q:a", "4", str(OUT)], check=True)
    print("OK", OUT, f"{OUT.stat().st_size / 1e6:.1f} MB")

if __name__ == "__main__":
    main()
