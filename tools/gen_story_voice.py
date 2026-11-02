#!/usr/bin/env python3
"""Genera la voz del Nexo del modo Historia en assets/sounds/story/.

Uso (igual que gen_intro_voice.py, del que reutiliza la voz y los filtros):
    python tools/gen_story_voice.py          # mini-intro (nexo_N.wav) y épocas (era_N.wav)
    python tools/gen_story_voice.py era      # solo las seis épocas

El texto de cada frase es el mismo que se muestra como subtítulo en
scripts/ui/story_prologue.gd (NEXO_INTRO) y scripts/ui/story_era_intro.gd (ERAS).
Al regenerar, pasa las duraciones impresas a NEXO_INTRO / ERAS (campo "len").
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_intro_voice as base

OUT = base.ROOT / "assets" / "sounds" / "story"

LINES = [
    "El tiempo te eligió.",
    "Solo uno reclamará mi poder.",
    "¿Quién merece controlar el destino de toda la historia?",
]

# Una por época, en el orden de Game.STORY_CHAPTERS, y la última para el combate final.
ERA_LINES = [
    "Hoy gobiernan los que gritan más fuerte. El tiempo los escucha... y se ríe.",
    "Un siglo de guerras. El tiempo aún sangra.",
    "Aquí nació la grieta. Mentes que quisieron ver todo el tiempo.",
    "Reinos, flotas y coronas. Demasiado poder, poca memoria.",
    "El origen. Aquí empezó todo, y aquí decidirás cómo termina.",
    "Has llegado hasta mí. Demuestra que mereces el tiempo.",
]

if __name__ == "__main__":
    only_era = "era" in sys.argv[1:]
    if not only_era:
        base.render(LINES, OUT, "nexo")
    base.render(ERA_LINES, OUT, "era")
