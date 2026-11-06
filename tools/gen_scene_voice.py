#!/usr/bin/env python3
"""Genera las voces de las escenas de diálogo del modo Historia (assets/sounds/story/scenes/<escena>_<n>.wav).

Uso (Windows 10/11, desde la carpeta del proyecto; necesita ffmpeg y ffprobe en el PATH):
    python tools/gen_scene_voice.py                   # todas las escenas de scripts/story_scenes.gd
    python tools/gen_scene_voice.py albert_einstein   # solo esa escena (se pueden dar varias)

El texto sale de scripts/story_scenes.gd (SCENES y NEXO_TO_CREATOR), así que las voces siempre dicen lo
mismo que los subtítulos: al cambiar una frase hay que volver a generar su escena. La escena del Nexo cuando
juega un creador se llama "el_nexo_creador" (ver StoryScenes.scene_id).

Reutiliza el sintetizador de Windows de gen_intro_voice.py. Hay dos voces instaladas: "Raul" (hombre) y
"Sabina" (mujer); cada personaje usa una de las dos con otro tono, ritmo y tratamiento:
  - el Nexo: la voz grave de la intro, doble y con mucha reverberación;
  - los demás: más o menos graves, rápidos o sordos según su carácter.
Son voces PROVISIONALES: se pueden reemplazar por grabaciones humanas con los mismos nombres de archivo.
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_intro_voice as base

OUT = base.ROOT / "assets" / "sounds" / "story" / "scenes"
SCENES_GD = base.ROOT / "scripts" / "story_scenes.gd"


def _f(rate: float, extra: str = "", echo: str = "") -> str:
    """Filtro de ffmpeg: `rate` baja (<1) o sube (>1) el tono; `extra` y `echo` añaden carácter."""
    f = (f"[0:a]asetrate=22050*{rate},aresample=22050,atempo={1.0 / rate:.3f},"
         "equalizer=f=3200:t=q:w=1:g=-3,lowpass=f=6800")
    if extra:
        f += "," + extra
    if echo:
        f += "," + echo
    return f + ",alimiter=limit=0.95,volume=1.6"


# Cómo suena cada hablante: (voz de Windows, velocidad, tono del sintetizador, filtro de ffmpeg).
VOICES = {
    "nexo": ("Raul", 0.8, 0.7, base.FILTER),
    "albert_einstein": ("Raul", 0.9, 0.9, _f(0.97, "vibrato=f=5:d=0.04", "aecho=0.7:0.6:60:0.15")),
    "nikola_tesla": ("Raul", 0.9, 0.95, _f(0.92, "equalizer=f=180:t=q:w=1:g=3", "aecho=0.7:0.6:50:0.12")),
    "marie_curie": ("Sabina", 0.9, 1.0, _f(1.0, "", "aecho=0.7:0.6:70:0.15")),
    "leonardo_da_vinci": ("Raul", 0.85, 0.85, _f(0.88, "vibrato=f=4:d=0.03", "aecho=0.7:0.6:80:0.18")),
    "donald_trump": ("Raul", 1.05, 1.0, _f(1.02, "equalizer=f=1500:t=q:w=1:g=3", "")),
    "adolf_hitler": ("Raul", 1.05, 0.95, _f(1.0, "equalizer=f=2200:t=q:w=1:g=4,acompressor=threshold=0.1:ratio=6", "")),
    "napoleon": ("Raul", 1.0, 1.05, _f(1.05, "equalizer=f=2500:t=q:w=1:g=2", "aecho=0.7:0.6:55:0.12")),
    "hernan_cortes": ("Raul", 0.9, 0.85, _f(0.9, "equalizer=f=140:t=q:w=1:g=4", "aecho=0.7:0.6:65:0.15")),
    "julio_cesar": ("Raul", 0.85, 0.8, _f(0.85, "equalizer=f=130:t=q:w=1:g=4", "aecho=0.8:0.7:90|180:0.25|0.15")),
}


FEMALE = {"cleopatra", "juana_de_arco", "boudica", "isabel_ii", "janequeo", "mariya_oktyabrskaya", "liudmila_pavlichenko"}


def voice_for(speaker: str) -> tuple:
    """Voz propia si la tiene; si no, una por defecto (Raul o Sabina) con tono y ritmo repartidos por el id."""
    if speaker in VOICES:
        return VOICES[speaker]
    h = sum(ord(c) for c in speaker)
    rate = 0.88 + (h % 7) * 0.025
    pitch = 0.85 + (h % 5) * 0.05
    tone = 0.88 + (h % 6) * 0.04
    voice = "Sabina" if speaker in FEMALE else "Raul"
    if voice == "Sabina":
        tone += 0.08
    return (voice, round(rate, 3), round(pitch, 2), _f(round(tone, 3), "", "aecho=0.7:0.6:60:0.1"))


def parse_scenes() -> dict:
    """escena -> [(quién habla, texto)] leído de scripts/story_scenes.gd."""
    text = SCENES_GD.read_text(encoding="utf-8")
    scenes: dict = {}
    # SCENES: un bloque por rival.
    start = text.index("const SCENES := {")
    end = text.index("\n}\n", start)
    current = None
    for line in text[start:end].splitlines():
        key = re.match(r'^\t&"(\w+)": \[$', line)
        if key:
            current = key.group(1)
            scenes[current] = []
            continue
        row = re.match(r'^\t\t\[(NEXO|&"\w+"), "(.*)"\],$', line)
        if row and current:
            who = "nexo" if row.group(1) == "NEXO" else row.group(1)[2:-1]
            scenes[current].append((who, row.group(2)))
    # NEXO_TO_CREATOR: la escena del Nexo cuando juega un creador.
    start = text.index("const NEXO_TO_CREATOR := [")
    end = text.index("\n]\n", start)
    scenes["el_nexo_creador"] = [("nexo", m.group(1)) for m in re.finditer(r'^\t\[NEXO, "(.*)"\],$', text[start:end], re.M)]
    return scenes


def ps_for(voice: str, rate: float, pitch: float) -> str:
    return (base.PS.replace("*Raul*", "*%s*" % voice)
            .replace("SpeakingRate = 0.8", "SpeakingRate = %s" % rate)
            .replace("AudioPitch = 0.7", "AudioPitch = %s" % pitch))


def render_line(tmp: Path, speaker: str, text: str, dest: Path) -> None:
    voice, rate, pitch, filt = voice_for(speaker)
    script = tmp / ("tts_%s_%s_%s.ps1" % (voice, rate, pitch))
    script.write_text(ps_for(voice, rate, pitch), encoding="utf-8-sig")
    txt = tmp / "line.txt"
    raw = tmp / "line.wav"
    # Los guiones están en mayúsculas: el sintetizador deletrearía las palabras cortas, así que se pasa a minúsculas.
    spoken = text.lower()
    spoken = spoken[:1].upper() + spoken[1:]
    txt.write_text(spoken, encoding="utf-8")
    for attempt in range(1, 6):
        subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script),
                        str(txt), str(raw)], check=True)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(raw), "-filter_complex", filt,
                        "-ac", "1", "-ar", "22050", str(dest)], check=True)
        clipped = base.count_clipped(dest)
        if clipped < 200:
            break
        print(f"  {dest.name}: saturado ({clipped} muestras), reintento {attempt}", flush=True)
    dur = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(dest)],
                         capture_output=True, text=True).stdout.strip()
    print(dest.name, dur, "s", flush=True)


def main() -> None:
    only = sys.argv[1:]
    OUT.mkdir(parents=True, exist_ok=True)
    scenes = parse_scenes()
    with tempfile.TemporaryDirectory() as tmp:
        for scene, lines in scenes.items():
            if only and scene not in only:
                continue
            for i, (speaker, text) in enumerate(lines, start=1):
                render_line(Path(tmp), speaker, text, OUT / f"{scene}_{i}.wav")


if __name__ == "__main__":
    main()
