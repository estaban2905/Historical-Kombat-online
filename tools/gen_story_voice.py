#!/usr/bin/env python3
"""Genera la voz del Nexo del modo Historia en assets/sounds/story/.

Uso (igual que gen_intro_voice.py, del que reutiliza la voz y los filtros):
    python tools/gen_story_voice.py          # mini-intro (nexo_N.wav) y épocas (era_N.wav)
    python tools/gen_story_voice.py era      # solo las seis épocas
    python tools/gen_story_voice.py end      # solo el final

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
    "Cada época es ahora un fragmento roto. Este lo gobiernan los que gritan más fuerte.",
    "Un siglo de guerras. El tiempo aún sangra.",
    "Aquí brotaron las ideas de la ciencia. Algunas terminaron dentro del Reloj.",
    "Reinos, flotas y coronas. Demasiado poder, poca memoria.",
    "La cuna de la historia. Aquí nació el poder, y aquí decides cómo termina.",
    "Has llegado hasta mí. Demuestra que mereces el tiempo.",
]

# Final del modo Historia (scripts/ui/story_ending.gd): 1 y 2 antes de elegir, y la de cada decisión:
# 3 reparar, 4 reescribir, 5 liberar (el final oculto).
END_LINES = [
    "Me has vencido. Todas las épocas cayeron ante ti, y ahora esperan.",
    "El poder del Nexo es tuyo. ¿Qué harás con el tiempo?",
    "Que cada uno vuelva a su tiempo. Que el mundo recuerde sus errores, y aprenda de ellos.",
    "Que el tiempo sea tuyo. Pero quien escribe la historia a su imagen, termina repitiéndola.",
    "Ni tú, ni yo. Que el tiempo sea de todos, y que cada generación aprenda de la anterior.",
]

if __name__ == "__main__":
    args = sys.argv[1:]
    if "end" in args:
        base.render(END_LINES, OUT, "end")
    elif "era" in args:
        base.render(ERA_LINES, OUT, "era")
    else:
        base.render(LINES, OUT, "nexo")
        base.render(ERA_LINES, OUT, "era")
        base.render(END_LINES, OUT, "end")
