#!/usr/bin/env python3
"""Genera la voz del Nexo para la mini-intro del modo Historia (assets/sounds/story/nexo_N.wav).

Uso (igual que gen_intro_voice.py, del que reutiliza la voz y los filtros):
    python tools/gen_story_voice.py

El texto de cada frase es el mismo que se muestra como subtítulo en scripts/ui/story_screen.gd
(NEXO_INTRO). Al regenerar, pasa las duraciones impresas a NEXO_INTRO_LEN.
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

if __name__ == "__main__":
    base.render(LINES, OUT, "nexo")
