#!/usr/bin/env python3
"""Genera las fichas FighterData (.tres) de los luchadores del roster.

Uso (desde la carpeta del proyecto):
    python tools/generate_fighters.py

Cada personaje se describe con un diccionario en CHARACTERS (identidad,
arquetipo de estadísticas, aspecto y nombres/estilo de sus ataques). El
script calcula las cajas de impacto a partir de su altura y escribe
fighters/<id>/<id>.tres. Napoleón y Trump se hicieron a mano y NO se
regeneran (ver SKIP). Para retocar un personaje a mano basta con editar su
.tres en Godot; vuelve a ejecutar el script solo si cambias esta tabla.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP = {"donald_trump", "napoleon"}

# --------------------------------------------------------------------------
#  Arquetipos de estadísticas: vida, caminar, salto, salto adelante, fuerza,
#  resistencia, ritmo de los ataques normales.
# --------------------------------------------------------------------------
ARCHETYPES = {
    # (vida, andar, salto, salto adelante, fuerza, resistencia, tempo). La vida efectiva
    # (vida x resistencia) va de ~84 (glass) a ~115 (tank); la fuerza compensa.
    "balanced": (100, 72, -360, 110, 1.00, 1.00, "normal"),
    "rusher":   (94, 88, -375, 125, 1.00, 0.97, "fast"),
    "bruiser":  (106, 62, -340, 98, 1.05, 1.02, "slow"),
    "zoner":    (94, 72, -360, 112, 0.98, 0.97, "normal"),
    "glass":    (88, 92, -380, 130, 1.10, 0.96, "fast"),
    "tank":     (108, 56, -330, 90, 0.97, 1.06, "slow"),
    "agile":    (94, 84, -385, 128, 0.99, 0.97, "fast"),
    "sage":     (100, 64, -345, 102, 0.98, 1.03, "slow"),   # defensa sólida, golpes lentos
    "armored":  (106, 54, -325, 88, 1.04, 1.06, "slow"),    # mucho daño y aguante, poca movilidad
}

# Cuerpos: muslo, espinilla, ancho pierna, torso, ancho torso, brazo, antebrazo,
# ancho brazo, ancho cabeza, alto cabeza.
BUILDS = {
    "normal": (13, 13, 6, 26, 18, 11, 11, 5, 12, 13),
    "slim":   (13, 13, 5, 25, 15, 11, 11, 4, 11, 13),
    "stocky": (11, 12, 7, 24, 22, 10, 10, 6, 14, 13),
    "tall":   (15, 15, 6, 27, 17, 12, 12, 5, 12, 14),
    "short":  (11, 11, 6, 22, 16, 9, 10, 5, 12, 12),
    "big":    (13, 13, 7, 27, 22, 11, 11, 6, 14, 14),
}

# Tamaño de la caja de cada tipo de proyectil.
PROJ_BOX = {"ball": (12, 12), "soundwave": (16, 18), "orb": (14, 14),
            "bolt": (22, 10), "spin": (12, 10)}


def P(**kw):
    """Especial con proyectil."""
    return dict(type="proj", **kw)


def L(**kw):
    """Especial que lanza al rival por los aires."""
    return dict(type="launch", **kw)


def D(**kw):
    """Especial de embestida."""
    return dict(type="dash", **kw)


def S(**kw):
    """Especial de golpe pesado (aplastante)."""
    return dict(type="slam", **kw)


def W(**kw):
    """Poder especial con efectos propios (scripts/power_effects.gd)."""
    return dict(type="power", **kw)


# --------------------------------------------------------------------------
#  Personajes (los nº 1 y 11 del roster ya existen a mano).
# --------------------------------------------------------------------------
CHARACTERS = [
    dict(id="kim_jong_un", name="KIM JONG-UN", short="KIM", country="Corea del Norte", era="1984 –",
         intro="¡Mi peinado es un arma nuclear!",
         victory="Otro éxito rotundo. Que nadie diga lo contrario.",
         bio="Líder supremo con pasión por los misiles y los peinados atrevidos.",
         arch="bruiser", build="stocky",
         skin="f0d0a8", hair="141010", coat="1e2026", trim="9aa0a8", shirt="d8d8d8", accent="3a4048",
         pants="1e2026", boots="141414", hat="141414",
         hair_style="undercut", hat_style="none", beard="none", chest="mao",
         moves=("Palmada Suprema", "Puño Juche", "Patada de Pyongyang", "Patada Balística"),
         s1=P(name="Misil Balístico", anim="cannon", style="orb", color="ff5030", speed=220, dmg=15),
         s2=D(name="Desfile Militar", anim="rush", dmg=18, dash=280),
         ult="Lluvia de Misiles"),
    dict(id="vladimir_putin", name="VLADIMIR PUTIN", short="PUTIN", country="Rusia", era="1952 –",
         intro="Cinturón negro de judo. Te lo advierto.",
         victory="Ni siquiera despeiné mi cara de póker.",
         bio="Maestro del judo y de la mirada gélida. Pelea sin quitarse la camisa. Casi.",
         arch="balanced", build="normal",
         skin="f0d0b0", hair="b8a890", coat="30343c", trim="c0c0c8", shirt="e8e8f0", accent="2a3a8a",
         pants="30343c", boots="141414", hat="141414",
         hair_style="short", hat_style="none", beard="none", chest="tie",
         moves=("Palmada de Oso", "Directo del Kremlin", "Patada Siberiana", "Patada de Tigre"),
         s1=P(name="Mirada de Hielo", anim="cast", style="orb", color="80d8ff", speed=210, dmg=14),
         s2=L(name="Llave de Judo", anim="cast", dmg=18, launch=-330),
         ult="Oso Ruso Desatado"),
    dict(id="xi_jinping", name="XI JINPING", short="XI JINPING", country="China", era="1953 –",
         intro="Mi muralla es más alta que tu guardia.",
         victory="La armonía se impone. Siempre.",
         bio="Dirigente de la gran potencia asiática. Defensa de hierro y paciencia infinita.",
         arch="tank", build="big",
         skin="f0cfa8", hair="141010", coat="202428", trim="c0a040", shirt="e8e8e8", accent="c02020",
         pants="202428", boots="141414", hat="141414",
         hair_style="sidepart", hat_style="none", beard="none", chest="tie",
         moves=("Palmada Imperial", "Puño del Dragón", "Patada de Tai Chi", "Patada del Pueblo"),
         s1=P(name="Ruta de la Seda", anim="cast", style="spin", color="e0c040", speed=200, dmg=14),
         s2=S(name="Gran Muralla", anim="straight", dmg=20),
         ult="Dragón Planificador"),
    dict(id="nicolas_maduro", name="NICOLÁS MADURO", short="MADURO", country="Venezuela", era="1962 –",
         intro="¡Pelea, pueblo, pelea!",
         victory="Victoria total. Los datos lo confirman.",
         bio="Ex conductor de autobús convertido en político. Bigote legendario y mucho aguante.",
         arch="bruiser", build="big",
         skin="d8a878", hair="1c1410", coat="1a4aa0", trim="f0c020", shirt="f0d020", accent="d02020",
         pants="1a4aa0", boots="f0f0f0", hat="141414",
         hair_style="short", hat_style="none", beard="mustache", chest="plain",
         moves=("Manotazo Bolivariano", "Puño Caribeño", "Patada de Chándal", "Patada de Autobús"),
         s1=P(name="Lluvia de Arepas", anim="cannon", style="spin", color="e8a030", speed=200, dmg=15),
         s2=D(name="Autobús Descontrolado", anim="rush", dmg=18, dash=300),
         ult="Cadena Nacional"),
    dict(id="adolf_hitler", name="ADOLF HITLER", short="HITLER", country="Alemania", era="1889 – 1945",
         intro="¡Silencio! ¡Aquí hablo yo!",
         victory="¿Ganar? ...¡Una vez en la vida!",
         bio="Dictador del siglo XX. Aquí es una caricatura ridícula; nada de él se glorifica.",
         arch="glass", build="slim",
         skin="f0d0b0", hair="1c1410", coat="6a5a40", trim="a08850", shirt="d8d0b8", accent="6a5a40",
         pants="4a4030", boots="141414", hat="141414",
         hair_style="short", hat_style="none", beard="toothbrush", chest="uniform", tall_boots=True,
         moves=("Pataleta", "Berrinche", "Pisotón Furioso", "Patada Histérica"),
         s1=P(name="Discurso Ensordecedor", anim="cast", style="soundwave", speed=230, dmg=14),
         s2=D(name="Carga Desesperada", anim="rush", dmg=16, dash=300),
         ult="Rabieta Final"),
    dict(id="joseph_stalin", name="JOSEPH STALIN", short="STALIN", country="Unión Soviética", era="1878 – 1953",
         intro="Mi bigote tiene más rango que tú.",
         victory="Otro rival que desaparece de la foto.",
         bio="Líder soviético de bigote inmenso. Duro como una estepa helada.",
         arch="tank", build="big",
         skin="e0b890", hair="3a3030", coat="5a6040", trim="c0a040", shirt="d8d0b8", accent="a02020",
         pants="4a5030", boots="141414", hat="3a4030",
         hair_style="short", hat_style="cap", beard="mustache", chest="uniform", tall_boots=True,
         epaulettes=True,
         moves=("Martillazo", "Puño de Acero", "Patada Siberiana", "Patada del Plan Quinquenal"),
         s1=P(name="Hoz Voladora", anim="cannon", style="spin", color="c03030", speed=210, dmg=15),
         s2=D(name="Tren de Siberia", anim="rush", dmg=19, dash=270),
         ult="Plan Quinquenal Explosivo"),
    dict(id="benito_mussolini", name="BENITO MUSSOLINI", short="MUSSOLINI", country="Italia", era="1883 – 1945",
         intro="¡Miradme desde el balcón, plebeyos!",
         victory="Siempre supe que acabaría en lo alto. Del balcón.",
         bio="Dictador italiano de mentón desafiante y discursos teatrales.",
         arch="balanced", build="stocky",
         skin="e8c098", hair="3a3030", coat="2a2a30", trim="c0c0c8", shirt="e0e0e0", accent="2a2a30",
         pants="2a2a30", boots="141414", hat="141414",
         hair_style="bald", hat_style="none", beard="chin", chest="uniform", tall_boots=True,
         moves=("Gancho del Balcón", "Puño Teatral", "Patada de Vespa", "Patada del Coliseo"),
         s1=P(name="Discurso Desde el Balcón", anim="cast", style="soundwave", speed=225, dmg=15),
         s2=D(name="Vespa Imperial", anim="rush", dmg=17, dash=300),
         ult="Marcha Imperial"),
    dict(id="saddam_hussein", name="SADDAM HUSSEIN", short="SADDAM", country="Irak", era="1937 – 2006",
         intro="¡Tengo un palacio entero de dorado!",
         victory="Te dije que era la madre de todas las peleas.",
         bio="Presidente de Irak, famoso por su bigote y su gusto por el dorado.",
         arch="zoner", build="big",
         skin="d8a878", hair="1c1410", coat="5a6040", trim="e0c040", shirt="d8d0b8", accent="a02020",
         pants="4a5030", boots="141414", hat="2a3020",
         hair_style="short", hat_style="beret", beard="mustache", chest="uniform", tall_boots=True,
         moves=("Manotazo Dorado", "Puño de Palacio", "Patada de Arena", "Patada Blindada"),
         s1=P(name="Disparo Dorado", anim="cannon", style="orb", color="f0c030", speed=215, dmg=15),
         s2=D(name="Tanque Dorado", anim="rush", dmg=18, dash=280),
         ult="La Madre de Todas las Batallas"),
    dict(id="osama_bin_laden", name="OSAMA BIN LADEN", short="BIN LADEN", country="Arabia Saudita", era="1957 – 2011",
         intro="Salí de mi cueva solo para esto.",
         victory="¿Me encontraron? Esta vez no.",
         bio="Fugitivo de barba larga y turbante. En este torneo solo huye y golpea con la mirada.",
         arch="agile", build="tall",
         skin="d8b088", hair="2a2018", coat="e8e0d0", trim="b0a080", shirt="e8e0d0", accent="4a5030",
         pants="e8e0d0", boots="6a5030", hat="f0f0f0",
         hair_style="short", hat_style="turban", beard="long", chest="robe",
         moves=("Manotazo del Desierto", "Puño de la Cueva", "Patada de Arena", "Patada del Oasis"),
         s1=P(name="Mirada Fulminante", anim="cast", style="orb", color="ffe080", speed=210, dmg=14),
         s2=D(name="Tormenta del Desierto", anim="rush", dmg=17, dash=300),
         ult="Eclipse del Desierto"),
    dict(id="gengis_kan", name="GENGIS KAN", short="GENGIS KAN", country="Imperio mongol", era="1162 – 1227",
         intro="Mi horda no pide permiso.",
         victory="Otra tierra conquistada. Siguiente.",
         bio="Fundador del mayor imperio continuo de la historia. Jinete implacable.",
         arch="rusher", build="stocky",
         skin="d8a070", hair="1c1410", coat="4a3a8a", trim="e0c040", shirt="c8b890", accent="a02020",
         pants="5a4a30", boots="3a2a1a", hat="3a2a1a",
         hair_style="long", hat_style="fur_hat", beard="goatee", chest="robe", tall_boots=True,
         moves=("Gancho de la Estepa", "Puño de la Horda", "Patada de Jinete", "Patada del Khan"),
         s1=P(name="Lluvia de Flechas", anim="cannon", style="spin", color="8a6a3a", speed=240, dmg=14),
         s2=D(name="Carga de la Horda", anim="charge", dmg=19, dash=320),
         ult="Imperio Imparable"),
    dict(id="fidel_castro", name="FIDEL CASTRO", short="FIDEL", country="Cuba", era="1926 – 2016",
         intro="Mi discurso aún no ha terminado.",
         victory="Podría seguir hablando siete horas más.",
         bio="Líder de la Revolución cubana. Barba mítica y discursos interminables.",
         arch="balanced", build="normal",
         skin="e8c098", hair="3a3030", coat="4a5a30", trim="c0a040", shirt="d8d0b8", accent="a02020",
         pants="4a5a30", boots="141414", hat="3a4a28",
         hair_style="short", hat_style="cap", beard="full", chest="uniform", tall_boots=True,
         moves=("Manotazo Revolucionario", "Puño del Malecón", "Patada Caribeña", "Patada de la Sierra"),
         s1=P(name="Discurso de Siete Horas", anim="cast", style="soundwave", speed=225, dmg=15),
         s2=D(name="Marcha Revolucionaria", anim="rush", dmg=18, dash=290),
         ult="Revolución Permanente"),
    dict(id="cleopatra", name="CLEOPATRA", short="CLEOPATRA", country="Egipto", era="69 – 30 a.C.",
         intro="El Nilo se inclina ante mí.",
         victory="Ni Roma pudo conmigo. Tú tampoco.",
         bio="Última reina de Egipto. Inteligente, seductora y letal con una sandalia.",
         arch="agile", build="slim",
         skin="d8a070", hair="141010", coat="f0f0e8", trim="e0c040", shirt="f0f0e8", accent="2a6ac0",
         pants="f0f0e8", boots="e0c040", hat="2a5ac0",
         hair_style="long", hat_style="nemes", beard="none", chest="robe",
         moves=("Bofetada Real", "Garra del Nilo", "Patada de Sandalia", "Patada Faraónica"),
         s1=P(name="Áspid Venenoso", anim="cast", style="orb", color="40d060", speed=215, dmg=14),
         s2=D(name="Danza del Nilo", anim="rush", dmg=17, dash=300),
         ult="Maldición del Faraón"),
    dict(id="julio_cesar", name="JULIO CÉSAR", short="CÉSAR", country="Roma", era="100 – 44 a.C.",
         intro="Vine, vi... y voy a vencer.",
         victory="¡Veni, vidi, vici! Y nadie me apuñaló.",
         bio="General y dictador romano. Conquistó la Galia y casi todo lo demás.",
         arch="balanced", build="normal",
         skin="e8c098", hair="3a3030", coat="f0f0f0", trim="e0c040", shirt="f0f0f0", accent="a02050",
         pants="f0f0f0", boots="8a5a2a", hat="4a9a40",
         hair_style="short", hat_style="laurel", beard="none", chest="robe",
         moves=("Gancho Romano", "Puño del Senado", "Patada de Legionario", "Patada del Rubicón"),
         s1=P(name="Pilum Romano", anim="cannon", style="spin", color="a0a0b0", speed=220, dmg=15),
         s2=D(name="Veni, Vidi, Vici", anim="charge", dmg=18, dash=300),
         ult="Legiones de Roma"),
    dict(id="alejandro_magno", name="ALEJANDRO MAGNO", short="ALEJANDRO", country="Macedonia", era="356 – 323 a.C.",
         intro="Ya conquisté el mundo. ¿Y tú?",
         victory="No quedan mundos por conquistar. Casi.",
         bio="Rey de Macedonia que llegó hasta la India sin perder una batalla.",
         arch="rusher", build="normal",
         skin="e8c098", hair="8a6a3a", coat="b08a3a", trim="f0d060", shirt="d8c890", accent="c02020",
         pants="a02a2a", boots="8a5a2a", hat="c09a40",
         hair_style="curls", hat_style="helmet", beard="none", chest="uniform", tall_boots=True,
         epaulettes=True,
         moves=("Gancho Macedonio", "Puño de la Falange", "Patada de Hoplita", "Patada de Bucéfalo"),
         s1=P(name="Nudo Gordiano", anim="cannon", style="spin", color="c8a860", speed=215, dmg=14),
         s2=D(name="Falange Macedonia", anim="charge", dmg=19, dash=320),
         ult="Conquista Total"),
    dict(id="isabel_ii", name="REINA ISABEL II", short="ISABEL II", country="Reino Unido", era="1926 – 2022",
         intro="Tomaré el té... después de esto.",
         victory="Qué diversión. Sigamos con el té.",
         bio="Reina durante 70 años. Pequeña, imperturbable y con un bolso peligrosísimo.",
         arch="tank", build="short",
         skin="f0d0b8", hair="d8d8d8", coat="6a9ad0", trim="f0f0f0", shirt="f0f0f0", accent="f0f0f0",
         pants="6a9ad0", boots="2a2a40", hat="e0c040",
         hair_style="curls", hat_style="crown", beard="none", chest="robe",
         moves=("Bofetón con Guante", "Bolsazo Real", "Patada de Tacón", "Patada del Palacio"),
         s1=P(name="Corgi Lanzado", anim="cast", style="spin", color="c08a50", speed=210, dmg=15),
         s2=S(name="Bolsazo Real", anim="cast", dmg=20),
         ult="Dieciséis Corgis"),
    dict(id="abraham_lincoln", name="ABRAHAM LINCOLN", short="LINCOLN", country="Estados Unidos", era="1809 – 1865",
         intro="Hace ochenta y siete años... ¡y a pelear!",
         victory="Un gobierno del pueblo, por el pueblo y para ganar.",
         bio="Presidente altísimo con sombrero de copa. Era leñador antes que estadista.",
         arch="bruiser", build="tall",
         skin="d8b088", hair="1c1410", coat="1a1a1e", trim="3a3a40", shirt="f0f0f0", accent="141414",
         pants="1a1a1e", boots="141414", hat="1a1a1e",
         hair_style="short", hat_style="top_hat", beard="chin", chest="plain",
         moves=("Manotazo Presidencial", "Puño de Gettysburg", "Patada de Leñador", "Patada de Longitud"),
         s1=P(name="Discurso de Gettysburg", anim="cast", style="soundwave", speed=225, dmg=15),
         s2=L(name="Hachazo de Leñador", anim="staff", dmg=18, launch=-340),
         ult="Emancipación Fulminante"),
    dict(id="jesus_de_nazaret", name="JESÚS DE NAZARET", short="JESÚS", country="Judea", era="4 a.C.–30 d.C.",
         intro="La paz sea contigo.",
         victory="Perdono, ¡pero igual gané!",
         bio="Maestro de Galilea. Aquí pelea con luz y bondad, poniendo la otra mejilla... al final.",
         arch="balanced", build="tall",
         skin="e0b890", hair="5a3a20", coat="f0f0f0", trim="e0c040", shirt="f0f0f0", accent="b02020",
         pants="f0f0f0", boots="a07a4a", hat="f0d060",
         hair_style="long", hat_style="halo", beard="full", chest="robe",
         moves=("Palma Abierta", "Golpe de Fe", "Paso Sobre el Agua", "Patada Divina"),
         s1=P(name="Rayo de Luz", anim="cast", style="orb", color="fff0a0", speed=215, dmg=14),
         s2=L(name="Bastón del Pastor", anim="staff", dmg=18, launch=-330),
         ult="Luz del Mundo"),
    dict(id="buda", name="BUDA", short="BUDA", country="India", era="563 – 483 a.C.",
         intro="Respira. Y recibe.",
         victory="El camino del medio pasa por tu cara.",
         bio="El Iluminado. Tan sereno que nada parece afectarle. Casi nada.",
         arch="tank", build="stocky",
         skin="d8a870", hair="2a3a6a", coat="e0801a", trim="f0c040", shirt="e0801a", accent="a02020",
         pants="e0801a", boots="a07a4a", hat="f0d060",
         hair_style="bun", hat_style="halo", beard="none", chest="robe",
         moves=("Palma del Loto", "Puño Sereno", "Patada de Meditación", "Patada del Camino"),
         s1=P(name="Rayo de Iluminación", anim="cast", style="orb", color="ffd040", speed=210, dmg=14),
         s2=S(name="Loto Aplastante", anim="cast", dmg=20),
         ult="Nirvana"),
    dict(id="papa_francisco", name="PAPA FRANCISCO", short="FRANCISCO", country="Vaticano", era="1936 – 2025",
         intro="¡Hagan lío!",
         victory="Recen por mí. Ahora mismo.",
         bio="El papa argentino, humilde y cercano. Su Papamóvil acelera más de lo que parece.",
         arch="balanced", build="normal",
         skin="f0d0b8", hair="d8d8d8", coat="f4f4f4", trim="e0c040", shirt="f4f4f4", accent="e0c040",
         pants="f4f4f4", boots="4a3a2a", hat="f4f4f4",
         hair_style="short", hat_style="zucchetto", beard="none", chest="robe",
         moves=("Bendición Rápida", "Puño de la Plaza", "Patada de San Pedro", "Patada del Vaticano"),
         s1=P(name="Bendición Explosiva", anim="cast", style="orb", color="f8f8ff", speed=210, dmg=14),
         s2=D(name="Papamóvil", anim="rush", dmg=18, dash=300),
         ult="Misa Multitudinaria"),
    dict(id="rasputin", name="GRIGORI RASPUTÍN", short="RASPUTÍN", country="Imperio ruso", era="1869 – 1916",
         intro="No puedes matar lo que no muere.",
         victory="Me envenenaron, me dispararon... y aquí sigo.",
         bio="Místico de la corte rusa. Según la leyenda, fue casi imposible de matar.",
         arch="tank", build="tall",
         skin="d8b890", hair="1c1410", coat="2a2024", trim="8a6a3a", shirt="3a3038", accent="6a1a2a",
         pants="2a2024", boots="141414", hat="141414",
         hair_style="long", hat_style="none", beard="long", chest="robe",
         moves=("Zarpazo Místico", "Puño del Monje", "Patada Hipnótica", "Patada Siberiana"),
         s1=P(name="Mirada Hipnótica", anim="cast", style="orb", color="a050e0", speed=205, dmg=14),
         s2=L(name="Bastón Místico", anim="staff", dmg=18, launch=-330),
         ult="Maldición Inmortal"),
    dict(id="pablo_escobar", name="PABLO ESCOBAR", short="ESCOBAR", country="Colombia", era="1949 – 1993",
         intro="Plata o plomo. Elige.",
         victory="Con esta plata, hasta los jueces aplauden.",
         bio="Narcotraficante colombiano. Aquí paga sus golpes con billetes y hasta hipopótamos.",
         arch="balanced", build="stocky",
         skin="d8a878", hair="1c1410", coat="3a5aa0", trim="a0a0a0", shirt="e8e8e0", accent="e8e8e0",
         pants="4a6a9a", boots="f0f0ec", hat="141414",
         hair_style="mop", hat_style="none", beard="stubble", chest="polo",
         moves=("Cachetada Paisa", "Puño Millonario", "Patada de Hacienda", "Patada de Medellín"),
         s1=P(name="Lluvia de Billetes", anim="cannon", style="spin", color="50c060", speed=205, dmg=15),
         s2=D(name="Hipopótamo Descontrolado", anim="rush", dmg=18, dash=290),
         ult="Imperio de Billetes"),
    dict(id="albert_einstein", name="ALBERT EINSTEIN", short="EINSTEIN", country="Alemania", era="1879 – 1955",
         intro="Todo es relativo, menos tu derrota.",
         victory="Lo calculé. Estaba escrito en la pizarra.",
         bio="El genio de la relatividad. Pelo imposible y la mente más rápida del torneo.",
         arch="zoner", build="slim",
         skin="f0d0b0", hair="e8e8e8", coat="6a7080", trim="a0a8b0", shirt="e8e8e8", accent="6a7080",
         pants="3a3a40", boots="3a2a1a", hat="141414",
         hair_style="wild", hat_style="none", beard="mustache", chest="plain",
         moves=("Pizarrazo", "Puño Cuántico", "Patada Relativa", "Patada de Energía"),
         s1=P(name="Rayo E=mc²", anim="cast", style="orb", color="60a0ff", speed=225, dmg=15),
         s2=L(name="Dilatación del Tiempo", anim="cast", dmg=18, launch=-330),
         ult="Bomba de Relatividad"),
    dict(id="nikola_tesla", name="NIKOLA TESLA", short="TESLA", country="Serbia", era="1856 – 1943",
         intro="¡Voy a electrificarte!",
         victory="Edison nunca habría ganado así.",
         bio="Inventor de la corriente alterna. Lanza rayos de verdad (más o menos).",
         arch="zoner", build="tall",
         skin="f0d0b0", hair="1c1410", coat="2a2e3a", trim="8a90a0", shirt="e8e8e8", accent="2a6ac0",
         pants="2a2e3a", boots="141414", hat="141414",
         hair_style="short", hat_style="none", beard="mustache", chest="plain",
         moves=("Chispazo", "Puño Eléctrico", "Patada de Bobina", "Patada de Alto Voltaje"),
         s1=P(name="Rayo Tesla", anim="cast", style="bolt", color="70e0ff", speed=250, dmg=15),
         s2=L(name="Descarga de Bobina", anim="cast", dmg=19, launch=-340),
         ult="Tormenta Eléctrica"),
    dict(id="leonardo_da_vinci", name="LEONARDO DA VINCI", short="DA VINCI", country="Italia", era="1452 – 1519",
         intro="Inventé el helicóptero. Y ahora tu derrota.",
         victory="Mi mejor obra: tu cara en el suelo.",
         bio="Pintor, inventor y genio del Renacimiento. Dibuja máquinas y también golpes.",
         arch="agile", build="tall",
         skin="e8c098", hair="8a7a5a", coat="a03a30", trim="e0c040", shirt="e8d8b0", accent="6a4a2a",
         pants="a03a30", boots="4a3a2a", hat="2a4a8a",
         hair_style="long", hat_style="beret", beard="full", chest="robe",
         moves=("Pincelada Veloz", "Puño del Renacimiento", "Patada de Vitruvio", "Patada de Florencia"),
         s1=P(name="Ornitóptero", anim="cannon", style="spin", color="c8a860", speed=215, dmg=14),
         s2=S(name="Hombre de Vitruvio", anim="cast", dmg=20),
         ult="Máquina Voladora"),
    dict(id="marie_curie", name="MARIE CURIE", short="CURIE", country="Polonia-Francia", era="1867 – 1934",
         intro="¡Estás brillando de miedo!",
         victory="Dos Nobel y ahora también este K.O.",
         bio="Pionera de la radiactividad y doble premio Nobel. Su laboratorio brilla en la oscuridad.",
         arch="zoner", build="slim",
         skin="f0d0b8", hair="6a5a4a", coat="2a2a30", trim="8a8a90", shirt="f0f0f0", accent="2a2a30",
         pants="2a2a30", boots="141414", hat="141414",
         hair_style="bun", hat_style="none", beard="none", chest="plain",
         moves=("Cachetada de Laboratorio", "Puño de Polonio", "Patada Radiante", "Patada Atómica"),
         s1=P(name="Radiación Verde", anim="flask", style="orb", color="60f070", speed=215, dmg=15),
         s2=L(name="Explosión de Radio", anim="flask", dmg=18, launch=-330),
         ult="Reacción en Cadena"),
    dict(id="galileo_galilei", name="GALILEO GALILEI", short="GALILEO", country="Italia", era="1564 – 1642",
         intro="Y sin embargo... te voy a ganar.",
         victory="Lo dije: la Tierra se mueve. Y tú también.",
         bio="Astrónomo que apuntó el telescopio al cielo. Desde la Torre de Pisa tira de todo.",
         arch="zoner", build="normal",
         skin="e8c098", hair="b0a898", coat="3a2a3a", trim="8a6a3a", shirt="d8d0c0", accent="a03030",
         pants="3a2a3a", boots="2a1a1a", hat="2a1a2a",
         hair_style="short", hat_style="beret", beard="full", chest="robe",
         moves=("Pizarrazo Astral", "Puño del Telescopio", "Patada de Órbita", "Patada de Pisa"),
         s1=P(name="Telescopio Láser", anim="cast", style="orb", color="a0d0ff", speed=225, dmg=15),
         s2=P(name="Bola de la Torre de Pisa", anim="cannon", style="ball", speed=200, dmg=17,
              cost=40, cooldown=60),
         ult="Lluvia de Planetas"),
    dict(id="charles_darwin", name="CHARLES DARWIN", short="DARWIN", country="Reino Unido", era="1809 – 1882",
         intro="Sobrevive el más apto. Eso no eres tú.",
         victory="Selección natural: ¡tú perdiste!",
         bio="Naturalista de barba inmensa. Su libro pesa más que muchos puños.",
         arch="bruiser", build="stocky",
         skin="e8c8a8", hair="d8d8d8", coat="4a3a2a", trim="8a6a3a", shirt="e8e8e8", accent="4a3a2a",
         pants="4a4030", boots="2a1a1a", hat="141414",
         hair_style="bald", hat_style="none", beard="long", chest="plain",
         moves=("Manotazo Evolutivo", "Puño del Beagle", "Patada de Galápagos", "Patada de Tortuga"),
         s1=P(name="Pinzón Lanzado", anim="cannon", style="spin", color="a08040", speed=215, dmg=15),
         s2=S(name="Origen de las Especies", anim="book", dmg=21),
         ult="Extinción Masiva"),
    dict(id="cristobal_colon", name="CRISTÓBAL COLÓN", short="COLÓN", country="Génova", era="1451 – 1506",
         intro="¡Tierra a la vista! Creo que es la India.",
         victory="Descubrí el K.O. ¡Y es nuevo!",
         bio="Navegante genovés que buscó la India y se encontró un continente por error.",
         arch="rusher", build="normal",
         skin="e8c098", hair="8a5a30", coat="a02a2a", trim="e0c040", shirt="e8d8b0", accent="e0c040",
         pants="3a2a4a", boots="3a2a1a", hat="a02a2a",
         hair_style="long", hat_style="beret", beard="none", chest="uniform", tall_boots=True,
         moves=("Gancho de Marinero", "Puño de Carabela", "Patada de Cubierta", "Patada de la Pinta"),
         s1=P(name="Cañonazo de la Santa María", anim="cannon", style="ball", speed=210, dmg=15),
         s2=D(name="¡Tierra a la Vista!", anim="charge", dmg=18, dash=300),
         ult="Flota Descubridora"),
    dict(id="janequeo", name="JANEQUEO", short="JANEQUEO", country="Pueblo mapuche", era="c. 1600",
         intro="x", victory="x",
         bio="Guerrera mapuche que resistió a los invasores con lanza y coraje. Su pueblo jamás se arrodilla.",
         arch="agile", build="slim",
         skin="c08a58", hair="141010", coat="8a2020", trim="c0c4cc", shirt="141010", accent="c0c4cc",
         pants="2a2020", boots="3a2a1a", hat="8a2020",
         hair_style="long", hat_style="none", beard="none", chest="robe",
         moves=("Golpe de Lanza", "Puño del Weichan", "Patada de Newen", "Patada Guerrera"),
         s1=P(name="Boleadoras", anim="cannon", style="spin", color="8a6a3a", speed=230, dmg=14),
         s2=W(name="x", anim="staff", power="x", dmg=1),
         ult="Rebelión de Arauco"),
    dict(id="lautaro", name="LAUTARO", short="LAUTARO", country="Pueblo mapuche", era="1534 – 1557",
         intro="x", victory="x",
         bio="Toqui mapuche que aprendió las artes del invasor y las usó para liberar a su pueblo.",
         arch="rusher", build="normal",
         skin="b87c4c", hair="141010", coat="1c1c24", trim="c02828", shirt="3a2a2a", accent="c02828",
         pants="2a2024", boots="3a2a1a", hat="c02828",
         hair_style="long", hat_style="none", beard="none", chest="robe",
         moves=("Golpe del Toqui", "Lanzada Corta", "Patada Pillán", "Patada de Jinete"),
         s1=D(name="Embestida Mapuche", anim="rush", dmg=17, dash=300),
         s2=W(name="x", anim="staff", power="x", dmg=1),
         ult="Malón del Toqui"),
    dict(id="pachacutec", name="PACHACÚTEC", short="PACHACÚTEC", country="Imperio inca", era="1418 – 1471",
         intro="x", victory="x",
         bio="El Sapa Inca que convirtió una ciudad de los Andes en el imperio del Tahuantinsuyo.",
         arch="bruiser", build="stocky",
         skin="b07848", hair="141010", coat="c04820", trim="e8c040", shirt="e8c040", accent="2a8a9a",
         pants="c04820", boots="a07040", hat="e8c040",
         hair_style="short", hat_style="crown", beard="none", chest="robe",
         moves=("Puño del Sol", "Golpe de Cetro", "Patada Andina", "Patada de Piedra"),
         s1=S(name="Cetro Solar", anim="axe", dmg=22),
         s2=W(name="x", anim="axe", power="x", dmg=1),
         ult="Sol del Tahuantinsuyo"),
    dict(id="ivan_el_terrible", name="IVÁN EL TERRIBLE", short="IVÁN IV", country="Rusia", era="1530 – 1584",
         intro="x", victory="x",
         bio="Primer zar de Rusia. Su temperamento era tan gélido como un invierno en Moscovia.",
         arch="bruiser", build="big",
         skin="e8c8a8", hair="3a2a1a", coat="7a1a2a", trim="e8c040", shirt="e8c040", accent="e8c040",
         pants="3a1a2a", boots="141010", hat="7a1a2a",
         hair_style="long", hat_style="fur_hat", beard="long", chest="robe", tall_boots=True,
         moves=("Puñetazo del Zar", "Gancho de Moscú", "Patada de Boyardo", "Patada Opríchnik"),
         s1=P(name="Cristal de Hielo", anim="cast", style="orb", color="a0e0ff", speed=215, dmg=15),
         s2=W(name="x", anim="cast", power="x", dmg=1),
         ult="Oprichnina"),
    dict(id="boudica", name="BOUDICA", short="BOUDICA", country="Britania", era="m. 61 d.C.",
         intro="x", victory="x",
         bio="Reina de los icenos que se alzó contra Roma al frente de un ejército furioso.",
         arch="bruiser", build="tall",
         skin="f0d0b0", hair="c04a20", coat="2a6a3a", trim="c0a040", shirt="8a2a2a", accent="c0a040",
         pants="6a3a2a", boots="3a2a1a", hat="c0a040",
         hair_style="wild", hat_style="none", beard="none", chest="plain",
         moves=("Puño Celta", "Mazazo Iceno", "Patada de Carro", "Patada de Guerra"),
         s1=S(name="Lanzada Celta", anim="staff", dmg=22),
         s2=W(name="x", anim="cast", power="x", dmg=1),
         ult="Furia de los Icenos"),
    dict(id="juana_de_arco", name="JUANA DE ARCO", short="JUANA", country="Francia", era="1412 – 1431",
         intro="x", victory="x",
         bio="Joven campesina que lideró ejércitos guiada por sus visiones. Santa y estratega.",
         arch="balanced", build="slim",
         skin="f0d0b0", hair="6a4a2a", coat="a8b0c0", trim="e8c040", shirt="2a4ab0", accent="2a4ab0",
         pants="5a6070", boots="5a6070", hat="a8b0c0",
         hair_style="short", hat_style="helmet", beard="none", chest="uniform",
         moves=("Puño de Armadura", "Escudo Real", "Patada de Caballero", "Patada de Orleans"),
         s1=P(name="Estandarte de Luz", anim="cast", style="orb", color="ffe880", speed=225, dmg=14),
         s2=W(name="x", anim="charge", power="x", dmg=1),
         ult="Llama de Orleans"),
    dict(id="augusto_pinochet", name="AUGUSTO PINOCHET", short="PINOCHET", country="Chile", era="1915 – 2006",
         intro="x", victory="x",
         bio="General que gobernó Chile con mano de hierro. Mirada fría y gafas oscuras.",
         arch="zoner", build="normal",
         skin="e8c8a8", hair="a0a0a0", coat="5a6a5a", trim="e8c040", shirt="d8d8c8", accent="e8c040",
         pants="4a5a4a", boots="141010", hat="e8e8e0",
         hair_style="short", hat_style="cap", beard="mustache", chest="uniform",
         moves=("Golpe de Mando", "Puño del General", "Patada de Cuartel", "Patada de Parada"),
         s1=D(name="Marcha Militar", anim="rush", dmg=17, dash=290),
         s2=W(name="x", anim="cast", power="x", dmg=1),
         ult="Toque de Queda"),
    dict(id="salvador_allende", name="SALVADOR ALLENDE", short="ALLENDE", country="Chile", era="1908 – 1973",
         intro="x", victory="x",
         bio="Médico y presidente de Chile. Defendió sus ideas hasta el último día con casco y fusil.",
         arch="zoner", build="normal",
         skin="e8c8a8", hair="3a3a3a", coat="6a4a3a", trim="c02828", shirt="e8e8e0", accent="c02828",
         pants="4a3a3a", boots="141010", hat="3a5a3a",
         hair_style="short", hat_style="helmet", beard="mustache", chest="tie",
         moves=("Puño Popular", "Discurso Directo", "Patada Obrera", "Patada Constituyente"),
         s1=P(name="Octavilla Roja", anim="cannon", style="spin", color="e03030", speed=225, dmg=14),
         s2=W(name="x", anim="cast", power="x", dmg=1),
         ult="Último Discurso"),
    dict(id="arturo_prat", name="ARTURO PRAT", short="PRAT", country="Chile", era="1848 – 1879",
         intro="x", victory="x",
         bio="Capitán de la Esmeralda. Saltó al abordaje del Huáscar y se volvió leyenda.",
         arch="balanced", build="normal",
         skin="e8c8a8", hair="3a2a1a", coat="1a2a5a", trim="e8c040", shirt="e8e8f0", accent="e8c040",
         pants="1a2a5a", boots="141010", hat="e8e8f0",
         hair_style="short", hat_style="cap", beard="full", chest="uniform",
         moves=("Puño de Cubierta", "Golpe de Sable", "Patada de Marinero", "Patada de Abordaje"),
         s1=P(name="Cañonazo Naval", anim="cannon", style="ball", speed=230, dmg=15),
         s2=W(name="x", anim="charge", power="x", dmg=1),
         ult="Abordaje Final"),
    # --- Filósofos, estrategas, científicos y soldados ---
    dict(id="socrates", name="SÓCRATES", short="SÓCRATES", country="Grecia", era="470 – 399 a.C.",
         intro="x", victory="x",
         bio="Filósofo ateniense que no escribió nada y lo preguntó todo. Su ironía desarma a cualquiera.",
         arch="sage", build="stocky",
         skin="e8c09a", hair="c8c4b8", coat="e8e2d0", trim="8a6a40", shirt="e8e2d0", accent="8a6a40",
         pants="e8c09a", boots="8a5a30", hat="8a6a40",
         hair_style="bald", hat_style="none", beard="full", chest="robe",
         moves=("Golpe Irónico", "Bastonazo", "Patada Descalza", "Patada del Ágora"),
         s1=P(name="Pregunta Incómoda", anim="cast", style="soundwave", speed=210, dmg=13),
         s2=W(name="x", anim="staff", power="x", dmg=1),
         ult="La Copa de Cicuta"),
    dict(id="platon", name="PLATÓN", short="PLATÓN", country="Grecia", era="427 – 347 a.C.",
         intro="x", victory="x",
         bio="Discípulo de Sócrates y fundador de la Academia. Pelea con ideas, ilusiones y pergaminos.",
         arch="zoner", build="big",
         skin="e8c8a0", hair="3a2a1a", coat="ece6d4", trim="3a5a9a", shirt="ece6d4", accent="3a5a9a",
         pants="e8c8a0", boots="8a5a30", hat="3a5a9a",
         hair_style="short", hat_style="none", beard="full", chest="robe",
         moves=("Golpe Ideal", "Pergaminazo", "Patada Dialéctica", "Patada de la Academia"),
         s1=P(name="Rayo de la Idea", anim="scroll", style="orb", color="fff0b0", speed=225, dmg=14),
         s2=W(name="x", anim="scroll", power="x", dmg=1),
         ult="La Caverna de las Sombras"),
    dict(id="aristoteles", name="ARISTÓTELES", short="ARISTÓTELES", country="Grecia", era="384 – 322 a.C.",
         intro="x", victory="x",
         bio="Discípulo de Platón y maestro de Alejandro Magno. Todo lo observa, todo lo mide y todo lo calcula.",
         arch="sage", build="slim",
         skin="e0b890", hair="6a5a48", coat="e0d4b4", trim="6a3a6a", shirt="e0d4b4", accent="6a3a6a",
         pants="e0b890", boots="8a5a30", hat="6a3a6a",
         hair_style="short", hat_style="none", beard="full", chest="robe",
         moves=("Golpe Lógico", "Bastón del Liceo", "Patada Empírica", "Patada Peripatética"),
         s1=S(name="Silogismo Contundente", anim="staff", dmg=21),
         s2=W(name="x", anim="cast", power="x", dmg=1),
         ult="La Pizarra Definitiva"),
    dict(id="sun_tzu", name="SUN TZU", short="SUN TZU", country="China", era="544 – 496 a.C.",
         intro="x", victory="x",
         bio="General chino autor de El arte de la guerra. Gana el combate antes de que empiece.",
         arch="agile", build="normal",
         skin="e8c8a0", hair="1c1410", coat="7a2a1a", trim="c0a040", shirt="2a2a30", accent="c02828",
         pants="3a2a20", boots="2a1a10", hat="4a3a2a",
         hair_style="long", hat_style="helmet", beard="long", chest="uniform", tall_boots=True, epaulettes=True,
         moves=("Golpe de Mando", "Tajo de Jian", "Patada del Viento", "Patada del Tigre"),
         s1=D(name="Avance Relámpago", anim="charge", dmg=17, dash=330),
         s2=W(name="x", anim="charge", power="x", dmg=1),
         ult="Ejército Ilusorio"),
    dict(id="confucio", name="CONFUCIO", short="CONFUCIO", country="China", era="551 – 479 a.C.",
         intro="x", victory="x",
         bio="Maestro chino de la virtud, el orden y la disciplina. Su guardia es tan firme como sus principios.",
         arch="tank", build="normal",
         skin="e8c8a0", hair="c8c8c0", coat="2a5a5a", trim="c0a040", shirt="e8e0c8", accent="c0a040",
         pants="2a5a5a", boots="1a1a1a", hat="1a1a1a",
         hair_style="long", hat_style="guan", beard="long", chest="robe",
         moves=("Palmada Virtuosa", "Bastón Ceremonial", "Patada del Equilibrio", "Patada Celestial"),
         s1=L(name="Bastón del Maestro", anim="staff", dmg=17, launch=-320),
         s2=W(name="x", anim="cast", power="x", dmg=1),
         ult="Estatua del Maestro"),
    dict(id="isaac_newton", name="ISAAC NEWTON", short="NEWTON", country="Inglaterra", era="1643 – 1727",
         intro="x", victory="x",
         bio="Físico inglés que formuló la gravitación universal. Una manzana le cambió la vida.",
         arch="zoner", build="slim",
         skin="f0d0b0", hair="e8e4dc", coat="3a2a3a", trim="c0c0c8", shirt="f0f0f0", accent="c02020",
         pants="3a2a3a", boots="1a1a1a", hat="1a1a1a",
         hair_style="wig", hat_style="none", beard="none", chest="lapels",
         moves=("Golpe Inercial", "Bastón Científico", "Patada de Acción", "Patada de Reacción"),
         s1=P(name="Manzanazo", anim="cannon", style="spin", color="d83030", speed=220, dmg=14),
         s2=W(name="x", anim="cast", power="x", dmg=1),
         ult="La Manzana Gigante"),
    dict(id="hernan_cortes", name="HERNÁN CORTÉS", short="CORTÉS", country="España", era="1485 – 1547",
         intro="x", victory="x",
         bio="Conquistador español que derribó al Imperio mexica. Ambicioso, astuto y con mucho acero encima.",
         arch="bruiser", build="normal",
         skin="e8c8a0", hair="2a1a10", coat="9a9aa4", trim="e8c040", shirt="b02020", accent="b02020",
         pants="6a2a2a", boots="3a2a1a", hat="b0b0b8",
         hair_style="short", hat_style="morion", beard="full", chest="uniform", tall_boots=True,
         moves=("Guantelete", "Estocada", "Patada de Conquistador", "Patada de Armadura"),
         s1=P(name="Arcabuzazo", anim="cannon", style="ball", speed=240, dmg=15),
         s2=W(name="x", anim="cast", power="x", dmg=1),
         ult="Flota de Veracruz"),
    dict(id="moctezuma_ii", name="MOCTEZUMA II", short="MOCTEZUMA", country="Imperio mexica", era="1466 – 1520",
         intro="x", victory="x",
         bio="Huey tlatoani de Tenochtitlán, la gran ciudad sobre el lago. Combate con el poder del Sol.",
         arch="bruiser", build="tall",
         skin="a86a40", hair="141010", coat="2a8a7a", trim="e8c040", shirt="e8c040", accent="e04030",
         pants="e8e0c8", boots="a07040", hat="2a9a5a",
         hair_style="long", hat_style="plumes", beard="none", chest="robe",
         moves=("Puño Imperial", "Golpe de Macuahuitl", "Patada del Jaguar", "Patada del Águila"),
         s1=P(name="Rayo de Tonatiuh", anim="cast", style="orb", color="ffc040", speed=215, dmg=15),
         s2=W(name="x", anim="cast", power="x", dmg=1),
         ult="Disco Solar"),
    dict(id="nicolas_maquiavelo", name="NICOLÁS MAQUIAVELO", short="MAQUIAVELO", country="Florencia", era="1469 – 1527",
         intro="x", victory="x",
         bio="Diplomático florentino autor de El príncipe. Para él, una buena estrategia lo justifica todo.",
         arch="agile", build="slim",
         skin="f0d0b0", hair="2a2018", coat="1c1c24", trim="8a1a1a", shirt="8a1a1a", accent="8a1a1a",
         pants="1c1c24", boots="1a1a1a", hat="7a1a1a",
         hair_style="short", hat_style="beret", beard="none", chest="robe",
         moves=("Puñal Rápido", "Puñalada", "Patada Florentina", "Patada del Príncipe"),
         s1=D(name="Puñalada Traicionera", anim="dagger", dmg=16, dash=320),
         s2=W(name="x", anim="dagger", power="x", dmg=1),
         ult="Atrapado en El Príncipe"),
    dict(id="mariya_oktyabrskaya", name="MARIYA OKTYABRSKAYA", short="MARIYA", country="Unión Soviética", era="1905 – 1944",
         intro="x", victory="x",
         bio="Vendió todo lo que tenía para comprar un tanque T-34 y lo condujo ella misma al frente.",
         arch="armored", build="stocky",
         skin="f0d0b0", hair="6a4a2a", coat="6a7040", trim="c0a040", shirt="6a7040", accent="c02020",
         pants="4a5030", boots="2a2018", hat="3a3a30",
         hair_style="bob", hat_style="cap", beard="none", chest="uniform", tall_boots=True,
         moves=("Puño de Mecánica", "Culatazo", "Patada de Oruga", "Patada Blindada"),
         s1=P(name="Disparo de Pistola", anim="pistol", style="bolt", color="ffe080", speed=300, dmg=13),
         s2=W(name="x", anim="cast", power="x", dmg=1),
         ult="Cañonazo del T-34"),
    dict(id="liudmila_pavlichenko", name="LIUDMILA PAVLICHENKO", short="LIUDMILA", country="URSS (Ucrania)", era="1916 – 1974",
         intro="x", victory="x",
         bio="Francotiradora soviética nacida en Ucrania, una de las más certeras de la historia.",
         arch="zoner", build="slim",
         skin="f0d0b0", hair="4a2a1a", coat="7a7a50", trim="c0a040", shirt="7a7a50", accent="c02020",
         pants="5a5a3a", boots="2a2018", hat="6a6a48",
         hair_style="bob", hat_style="cap", beard="none", chest="uniform", tall_boots=True,
         moves=("Golpe de Culata", "Culatazo de Rifle", "Patada de Trinchera", "Patada de Asalto"),
         s1=P(name="Disparo Certero", anim="rifle", style="bolt", color="fff0a0", speed=330, dmg=14),
         s2=W(name="x", anim="rifle", power="x", dmg=1),
         ult="Mira Telescópica"),
]


# --------------------------------------------------------------------------
#  Generación
# --------------------------------------------------------------------------
def col(hexstr):
    h = hexstr.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return f"Color({r:.6g}, {g:.6g}, {b:.6g}, 1)"


def f(x):
    return f"{float(x):.1f}"


def vec(x, y):
    return f"Vector2({x:g}, {y:g})"


def year_of(era):
    """Año de referencia para ordenar la línea de tiempo del modo Historia: el de
    nacimiento (negativo si es a.C.). Ej.: "1769 – 1821" -> 1769, "69 – 30 a.C." -> -69."""
    special = {"Siglo XXI": 1946, "m. 61 d.C.": 61, "c. 1600": 1600}
    if era in special:
        return special[era]
    n = int(re.match(r"\s*(\d+)", era).group(1))
    first = era.split("–")[0] if "–" in era else era
    return -n if ("a.C." in first or era.strip().endswith("a.C.")) else n


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def attack(aid, name, kind, anim, dmg, hitstun, blockstun, knock, launch, hitstop, fx,
           st, ac, rec, off, size, c_off, a_off, in_air, crouch, cost, cd, dash,
           pspeed, pstyle, pcolor=None, extra=None):
    lines = [
        f'id = &"{aid}"',
        f'display_name = "{esc(name)}"',
        f"kind = {kind}",
        f'anim = &"{anim}"',
        f"damage = {f(dmg)}",
        f"hitstun = {hitstun}",
        f"blockstun = {blockstun}",
        f"knockback = {f(knock)}",
        f"launch = {f(launch)}",
        f"hitstop = {hitstop}",
        f"effect_scale = {f(fx)}",
        f"startup = {st}",
        f"active = {ac}",
        f"recovery = {rec}",
        f"hitbox_offset = {vec(*off)}",
        f"hitbox_size = {vec(*size)}",
        f"crouch_offset = {vec(*c_off)}",
        f"air_offset = {vec(*a_off)}",
        f"usable_in_air = {str(in_air).lower()}",
        f"usable_crouching = {str(crouch).lower()}",
        f"energy_cost = {f(cost)}",
        f"cooldown = {cd}",
        f"dash_speed = {f(dash)}",
        f"projectile_speed = {f(pspeed)}",
        f'projectile_style = &"{pstyle}"',
        "projectile_lifetime = 2.0",
    ]
    if pcolor:
        lines.append(f"projectile_color = {col(pcolor)}")
    if extra:
        lines += extra
    return lines


# --------------------------------------------------------------------------
#  Golpes normales: cada personaje tiene su ritmo según su estilo y su arma.
# --------------------------------------------------------------------------
SLOT_OF = {"LP": "punch_light", "HP": "punch_heavy", "LK": "kick_light", "HK": "kick_heavy",
           "S1": "special_1", "S2": "special_2"}
RANK_OF = {"LP": 1, "LK": 1, "HP": 2, "HK": 2, "S1": 3, "S2": 3}

# Estilos: (frames extra de startup, frames extra de recuperación, multiplicador de daño,
# multiplicador de alcance) por golpe. Los que llevan arma o bastón alcanzan más pero
# se recuperan más despacio; los pesados pegan fuerte y lento; los veloces al revés.
STYLE_MODS = {
    "sword":   {"LP": (0, 1, 1.00, 1.15), "HP": (1, 2, 1.15, 1.30), "LK": (0, 0, 1.00, 1.00), "HK": (2, 2, 1.10, 1.20)},
    "spear":   {"LP": (0, 1, 1.00, 1.25), "HP": (1, 2, 1.15, 1.40), "LK": (0, 0, 1.00, 1.00), "HK": (2, 2, 1.10, 1.10)},
    "axe":     {"LP": (1, 1, 1.10, 1.00), "HP": (3, 3, 1.35, 1.15), "LK": (1, 1, 1.00, 1.00), "HK": (3, 2, 1.20, 1.00)},
    "heavy":   {"LP": (1, 1, 1.15, 1.00), "HP": (3, 3, 1.40, 1.10), "LK": (1, 2, 1.15, 1.00), "HK": (3, 3, 1.30, 1.00)},
    "brawler": {"LP": (-1, -1, 1.00, 0.95), "HP": (0, 0, 1.15, 1.00), "LK": (0, 0, 1.00, 1.00), "HK": (1, 1, 1.10, 1.00)},
    "speed":   {"LP": (-1, -1, 0.90, 0.95), "HP": (-1, -1, 1.00, 1.00), "LK": (-1, -1, 0.95, 1.00), "HK": (0, -1, 1.00, 1.00)},
    "zoner":   {"LP": (0, 0, 0.95, 1.00), "HP": (0, 0, 1.00, 1.10), "LK": (0, 0, 0.95, 1.00), "HK": (1, 1, 1.00, 1.05)},
    "mystic":  {"LP": (0, 0, 0.90, 1.00), "HP": (1, 1, 1.00, 1.20), "LK": (0, 0, 0.95, 1.00), "HK": (1, 1, 1.00, 1.00)},
    "scholar": {"LP": (0, 1, 0.85, 1.00), "HP": (0, 2, 0.95, 1.05), "LK": (0, 1, 0.90, 1.00), "HK": (1, 2, 1.00, 1.00)},
}
# Aturdimiento extra de los golpes débiles: con los estilos de golpes lentos hace falta
# más margen para poder enlazar un golpe fuerte (ver las pruebas de perfiles).
STYLE_LIGHT_HITSTUN = {"sword": 2, "spear": 3, "heavy": 5, "axe": 4, "mystic": 3, "scholar": 2, "zoner": 3}

# Animación (y objeto en la mano) de los golpes con arma.
STYLE_ANIMS = {
    "sword": {"HP": "charge"},
    "spear": {"LP": "staff", "HP": "staff"},
    "axe": {"HP": "axe"},
    "mystic": {"HP": "staff"},
    "scholar": {"HP": "book"},
}

# Perfil de cada luchador: estilo de golpes normales, un golpe propio (oh = alto/overhead,
# solo se bloquea de pie; low = bajo, solo se bloquea agachado) y sus dos combos propios.
# Un combo es una cadena de ranuras enlazadas con cancelaciones (rango igual o mayor,
# sin repetir golpe): LP/LK = débiles, HP/HK = fuertes, S1/S2 = especiales.
def _pf(style, kind, slot, name, c1, c2, anim=None):
    return dict(style=style, kind=kind, slot=slot, name=name, combos=[c1, c2], anim=anim or {})

PROFILES = {
    "donald_trump": _pf("heavy", "oh", "HK", "Patada Presidencial", ("TUIT", "LP LK HP", 3.5), ("DECRETO", "LP LK HP HK", 6.0)),
    "kim_jong_un": _pf("heavy", "oh", "HK", "Patada de Desfile", ("PARADA", "LP HP HK", 4.0), ("LANZAMIENTO", "LK LP HP S1", 7.0)),
    "vladimir_putin": _pf("brawler", "low", "LK", "Barrido de Judo", ("LLAVE", "LK LP HP", 3.5), ("IPPON", "LP LK HP HK", 6.0)),
    "xi_jinping": _pf("heavy", "oh", "HK", "Patada del Dragón", ("ARMONÍA", "LP HP HK", 4.0), ("GRAN MURALLA", "LK LP HP S1", 7.0)),
    "nicolas_maduro": _pf("brawler", "low", "LK", "Patada de Salsa", ("SALSA", "LK LP HP", 3.0), ("CUMBIA", "LP LK HP HK", 6.0)),
    "adolf_hitler": _pf("speed", "low", "LK", "Barrido Veloz", ("RÁFAGA", "LP LK HP", 3.0), ("RELÁMPAGO", "LK LP HK S1", 7.0)),
    "joseph_stalin": _pf("heavy", "oh", "HP", "Mazazo de Acero", ("QUINQUENAL", "LP HP HK", 4.5), ("PURGA", "LK LP HP S2", 8.0)),
    "benito_mussolini": _pf("brawler", "oh", "HK", "Patada de Balcón", ("DISCURSO", "LP HP HK", 3.5), ("MARCHA", "LK LP HP S1", 7.0)),
    "saddam_hussein": _pf("brawler", "low", "LK", "Barrido del Desierto", ("DUNA", "LK LP HP", 3.0), ("TORMENTA", "LP LK HP S1", 6.5)),
    "osama_bin_laden": _pf("speed", "low", "LK", "Patada Sombra", ("SOMBRA", "LP LK HK", 3.0), ("EMBOSCADA", "LK LP HP S2", 7.0)),
    "napoleon": _pf("sword", "oh", "HP", "Sablazo Imperial", ("ESTRATEGIA", "LP HP S1", 4.0), ("CAMPAÑA", "LK LP HP HK", 6.0)),
    "gengis_kan": _pf("sword", "oh", "HK", "Tajo de Jinete", ("HORDA", "LP HP HK", 4.0), ("GALOPE", "LK LP HP S1", 7.0)),
    "fidel_castro": _pf("brawler", "low", "LK", "Patada Guerrillera", ("SIERRA", "LK LP HP", 3.0), ("REVOLUCIÓN", "LP LK HP HK", 6.0)),
    "cleopatra": _pf("speed", "low", "LK", "Barrido de Sandalia", ("NILO", "LP LK HK", 3.0), ("ÁSPID", "LK LP HP S1", 7.0)),
    "julio_cesar": _pf("sword", "oh", "HP", "Gladio Descendente", ("VENI VIDI", "LP HP HK", 4.0), ("VICI", "LK LP HP S1", 7.0)),
    "alejandro_magno": _pf("sword", "oh", "HK", "Tajo Macedonio", ("FALANGE", "LP HP HK", 4.0), ("GAUGAMELA", "LK LP HP S2", 7.0)),
    "isabel_ii": _pf("zoner", "oh", "HP", "Golpe de Cetro", ("PROTOCOLO", "LP HP HK", 3.5), ("CORONACIÓN", "LK LP HP S1", 6.5)),
    "abraham_lincoln": _pf("axe", "oh", "HP", "Hachazo Presidencial", ("EMANCIPACIÓN", "LP HP HK", 4.0), ("GETTYSBURG", "LK LP HP S1", 7.0)),
    "jesus_de_nazaret": _pf("mystic", "oh", "HP", "Vara del Pastor", ("PARÁBOLA", "LP HP HK", 3.0), ("MILAGRO", "LK LP HP S2", 7.0)),
    "buda": _pf("mystic", "low", "LK", "Patada del Loto", ("LOTO", "LK LP HP", 3.0), ("NIRVANA", "LP LK HP S1", 7.0)),
    "papa_francisco": _pf("zoner", "oh", "HP", "Golpe de Báculo", ("BENDICIÓN", "LP HP HK", 3.0), ("ÁNGELUS", "LK LP HP S1", 6.5)),
    "rasputin": _pf("mystic", "oh", "HP", "Báculo Hipnótico", ("HIPNOSIS", "LP HP HK", 4.0), ("MALDICIÓN", "LK LP HP S2", 7.0)),
    "pablo_escobar": _pf("brawler", "low", "LK", "Patada de Sicario", ("PLATA", "LK LP HP", 3.0), ("PLOMO", "LP LK HP S1", 6.5)),
    "albert_einstein": _pf("scholar", "low", "LK", "Patada Relativa", ("ECUACIÓN", "LP HP HK", 3.0), ("RELATIVIDAD", "LK LP HP S1", 6.5)),
    "nikola_tesla": _pf("scholar", "oh", "HP", "Descarga en Arco", ("ARCO", "LP HP HK", 3.5), ("CORRIENTE", "LK LP HP S1", 7.0)),
    "leonardo_da_vinci": _pf("scholar", "oh", "HP", "Trazo Descendente", ("BOCETO", "LP HP HK", 3.0), ("OBRA MAESTRA", "LK LP HP S2", 7.0)),
    "marie_curie": _pf("scholar", "low", "LK", "Barrido Radiante", ("ISÓTOPO", "LK LP HP", 3.0), ("RADIACIÓN", "LP LK HP S1", 6.5), anim={"HP": "flask"}),
    "galileo_galilei": _pf("scholar", "oh", "HP", "Golpe de Telescopio", ("ÓRBITA", "LP HP HK", 3.0), ("EPPUR SI MUOVE", "LK LP HP S1", 7.0)),
    "charles_darwin": _pf("scholar", "low", "LK", "Patada Primate", ("ADAPTACIÓN", "LK LP HP", 3.0), ("SELECCIÓN", "LP LK HP S1", 6.5)),
    "cristobal_colon": _pf("sword", "oh", "HK", "Tajo de Capitán", ("RUMBO", "LP HP HK", 3.5), ("TIERRA A LA VISTA", "LK LP HP S1", 7.0)),
    "janequeo": _pf("spear", "low", "LK", "Lanzada Baja", ("WEICHAN", "LP HP HK", 4.0), ("NEWEN", "LK LP HP S1", 7.0)),
    "lautaro": _pf("spear", "low", "LK", "Lanzada Rasante", ("TOQUI", "LP HP HK", 4.0), ("MALÓN", "LK LP HP S2", 7.0)),
    "pachacutec": _pf("heavy", "oh", "HP", "Cetro Solar", ("INTI", "LP HP HK", 4.0), ("TAHUANTINSUYO", "LK LP HP S1", 7.0), anim={"HP": "axe"}),
    "ivan_el_terrible": _pf("heavy", "oh", "HP", "Bastón de Hierro", ("ZAR", "LP HP HK", 4.5), ("TERROR", "LK LP HP S2", 8.0), anim={"HP": "staff"}),
    "boudica": _pf("spear", "oh", "HP", "Lanza Descendente", ("ICENOS", "LP HP HK", 4.0), ("REBELIÓN", "LK LP HP S1", 7.0)),
    "juana_de_arco": _pf("sword", "oh", "HP", "Tajo Sagrado", ("FE", "LP HP HK", 3.5), ("ORLEANS", "LK LP HP S1", 7.0)),
    "augusto_pinochet": _pf("brawler", "low", "LK", "Patada de Cuartel", ("MANDO", "LK LP HP", 3.5), ("TOQUE", "LP LK HP S1", 6.5)),
    "salvador_allende": _pf("zoner", "oh", "HP", "Golpe de Tribuna", ("DISCURSO", "LP HP HK", 3.5), ("PUEBLO", "LK LP HP S1", 6.5)),
    "arturo_prat": _pf("sword", "oh", "HP", "Sablazo de Abordaje", ("ABORDAJE", "LP HP HK", 4.0), ("ESMERALDA", "LK LP HP S1", 7.0)),
    "socrates": _pf("mystic", "oh", "HP", "Bastonazo Mayéutico", ("IRONÍA", "LP HP HK", 3.5), ("MAYÉUTICA", "LK LP HP S2", 7.0)),
    "platon": _pf("scholar", "low", "LK", "Barrido Dialéctico", ("DIÁLOGO", "LK LP HP", 3.0), ("REPÚBLICA", "LP LK HP S1", 6.5), anim={"HP": "scroll"}),
    "aristoteles": _pf("mystic", "low", "LK", "Patada Silogística", ("PREMISA", "LK LP HP", 3.0), ("SILOGISMO", "LP LK HP S2", 7.0)),
    "sun_tzu": _pf("sword", "oh", "HK", "Tajo del Estratega", ("ENGAÑO", "LP HP HK", 4.0), ("ARTE DE LA GUERRA", "LK LP HP S2", 7.5)),
    "confucio": _pf("mystic", "oh", "HP", "Bastón del Orden", ("VIRTUD", "LP HP HK", 3.5), ("ANALECTAS", "LK LP HP S1", 7.0)),
    "isaac_newton": _pf("scholar", "oh", "HP", "Bastonazo Gravitatorio", ("INERCIA", "LP HP HK", 3.0), ("PRINCIPIA", "LK LP HP S1", 7.0), anim={"HP": "staff"}),
    "hernan_cortes": _pf("sword", "oh", "HP", "Estocada Ropera", ("VERACRUZ", "LP HP HK", 4.0), ("CONQUISTA", "LK LP HP S1", 7.0)),
    "moctezuma_ii": _pf("axe", "oh", "HP", "Golpe de Macuahuitl", ("TENOCHTITLAN", "LP HP HK", 4.0), ("QUINTO SOL", "LK LP HP S1", 7.5), anim={"HP": "macana"}),
    "nicolas_maquiavelo": _pf("speed", "low", "LK", "Zancadilla Florentina", ("INTRIGA", "LP LK HK", 3.0), ("EL FIN", "LK LP HP S2", 7.0), anim={"LP": "dagger", "HP": "dagger"}),
    "mariya_oktyabrskaya": _pf("heavy", "oh", "HP", "Culatazo Blindado", ("ORUGA", "LP HP HK", 4.5), ("FRENTE ORIENTAL", "LK LP HP S1", 8.0), anim={"HP": "pistol"}),
    "liudmila_pavlichenko": _pf("zoner", "low", "LK", "Barrido de Trinchera", ("TRINCHERA", "LK LP HP", 3.0), ("SEVASTOPOL", "LP LK HP S1", 6.5), anim={"HP": "rifle"}),
}


# Retoques personales sobre el estilo (frames extra de startup y recuperación, multiplicadores
# de daño y de alcance): lo que hace distinto a un luchador de otro con el mismo estilo.
TWEAKS = {
    "vladimir_putin": {"LP": (0, -1, 1.05, 0.9), "HP": (0, -1, 1.0, 0.95)},       # judo: corto y rápido
    "fidel_castro": {"LP": (0, 1, 1.0, 1.0), "HP": (1, 1, 1.1, 1.0)},             # discursos largos: más lento
    "augusto_pinochet": {"LP": (0, 0, 1.0, 1.1), "HP": (1, 0, 1.05, 1.1)},        # mando: alcance controlado
    "adolf_hitler": {"HP": (0, 0, 1.15, 1.0)},                                    # frágil pero castiga
    "cleopatra": {"HK": (0, -1, 0.95, 1.1)},                                      # patada larga y ágil
    "joseph_stalin": {"HP": (1, 1, 1.1, 1.0)},                                    # aún más lento y duro
    "ivan_el_terrible": {"HP": (-1, 0, 1.0, 1.25)},                               # el bastón alcanza lejos
    "julio_cesar": {"LP": (0, -1, 1.0, 0.9), "HP": (0, 0, 1.05, 0.95)},           # gladio corto y rápido
    "arturo_prat": {"HP": (0, 1, 1.0, 1.1), "HK": (0, 1, 1.0, 1.05)},             # sable largo
    "alejandro_magno": {"HK": (-1, 0, 1.0, 1.1)},                                 # ofensivo
    "cristobal_colon": {"HP": (0, 1, 1.0, 1.0), "LK": (0, 1, 1.0, 1.0)},          # marinero tosco
    "papa_francisco": {"LP": (0, 1, 0.95, 1.0)},                                  # gesto suave
    "salvador_allende": {"HP": (0, -1, 1.0, 1.0)},                                # directo
    "marie_curie": {"HK": (1, 1, 1.0, 1.0)},                                      # pausada
    "socrates": {"LP": (1, 1, 1.0, 0.9), "HP": (1, 1, 1.0, 0.95)},                # lento y de poco alcance
    "platon": {"HP": (0, 0, 0.95, 1.2)},                                          # el pergamino llega lejos
    "aristoteles": {"LP": (0, 0, 1.05, 1.0), "HP": (0, -1, 1.0, 1.0)},            # golpes técnicos y precisos
    "sun_tzu": {"LP": (-1, -1, 1.0, 1.0), "HP": (-1, 0, 1.0, 1.05)},              # el más rápido de los estrategas
    "confucio": {"LP": (1, 1, 1.0, 1.0), "HP": (1, 1, 1.0, 1.1)},                 # ataques lentos
    "isaac_newton": {"LP": (0, 1, 0.9, 0.9), "HK": (1, 1, 0.95, 1.0)},            # cuerpo a cuerpo limitado
    "hernan_cortes": {"LP": (0, -1, 1.0, 1.0), "HP": (0, 1, 1.0, 1.1), "HK": (-1, 0, 1.0, 1.0)},  # ropera larga, guantelete rápido
    "moctezuma_ii": {"HP": (1, 0, 1.05, 1.1)},                                    # macuahuitl pesado y largo
    "nicolas_maquiavelo": {"HP": (0, 0, 0.9, 1.0)},                               # poca fuerza física
    "mariya_oktyabrskaya": {"HP": (1, 1, 1.1, 1.0)},                              # golpes de tanquista
    "liudmila_pavlichenko": {"HP": (0, 1, 1.0, 1.15)},                            # culatazo largo, recuperación lenta
}


def fix_seq(keys, oh):
    """Un golpe alto (overhead) es lento y no se puede enlazar: sale de los combos."""
    if oh not in keys:
        return keys
    keys = [k for k in keys if k != oh]
    other = "HK" if oh == "HP" else "HP"
    if other not in keys:
        keys.append(other)
    for light in ("LK", "LP"):
        if len(keys) >= 3:
            break
        if light not in keys:
            keys.insert(0, light)
    keys.sort(key=lambda k: RANK_OF[k])
    return keys


def profile_for(cid):
    p = PROFILES.get(cid)
    if p is None:
        return {"mods": {}, "anim": {}, "combos": [], "light_hs": 0, "oh": None, "low": None, "names": {}}
    anim = dict(STYLE_ANIMS.get(p["style"], {}))
    anim.update(p["anim"])
    oh = p["slot"] if p["kind"] == "oh" else None
    combos = [(n, " ".join(fix_seq(s.split(), oh)), b) for n, s, b in p["combos"]]
    mods = {}
    for key, (a, b, c, d) in STYLE_MODS[p["style"]].items():
        ta, tb, tc, td = TWEAKS.get(cid, {}).get(key, (0, 0, 1.0, 1.0))
        mods[key] = (a + ta, b + tb, c * tc, d * td)
    return {"mods": mods, "anim": anim, "combos": combos, "light_hs": STYLE_LIGHT_HITSTUN.get(p["style"], 0),
            "oh": p["slot"] if p["kind"] == "oh" else None,
            "low": p["slot"] if p["kind"] == "low" else None,
            "names": {p["slot"]: p["name"]}}


def build_normals(c, h, tempo):
    """Los 4 golpes normales con el ritmo, alcance y niveles del perfil del luchador."""
    ds = {"fast": -1, "normal": 0, "slow": 1}[tempo]
    k = h / 70.0
    r = 0.4 * h
    prof = profile_for(c["id"])
    # clave, ranura, nombre, tipo, anim, daño, hitstun, blockstun, empuje, hitstop, fx,
    # startup, active, recuperación, alcance, y, ancho, alto, off agachado, off aire
    specs = [
        ("LP", "punch_light", 0, 0, "jab", 5, 14, 8, 90, 4, 1.0, 4, 3, 7, 1.0, -0.72, 21, 10, (0, 16), (-4, 16)),
        ("HP", "punch_heavy", 1, 0, "straight", 10, 20, 12, 168, 7, 1.3, 8, 4, 14, 1.2, -0.71, 25, 12, (0, 16), (-8, 16)),
        ("LK", "kick_light", 2, 1, "kick_low", 7, 15, 9, 110, 5, 1.0, 5, 3, 8, 0.95, -0.36, 23, 10, (2, 12), (-3, 22)),
        ("HK", "kick_heavy", 3, 1, "kick_high", 12, 22, 13, 205, 8, 1.4, 10, 4, 16, 0.92, -0.6, 23, 14, (2, 27), (-4, 36)),
    ]
    out = {}
    for key, slot, idx, kind, anim, dmg, hs, bs, kn, hstop, fx, st0, ac, rec0, ox, oy, w, hh, c_off, a_off in specs:
        dst, drec, dm, xr = prof["mods"].get(key, (0, 0, 1.0, 1.0))
        st = max(3, st0 + ds + dst)
        rec = max(5, rec0 + ds + drec)
        dmg *= dm
        if key in ("LP", "LK"):
            hs += prof["light_hs"]
        extra = None
        if prof["oh"] == key:
            # Alto: solo se bloquea de pie. Más lento y algo más aturdidor.
            st = max(st + 4, 12)
            dmg *= 1.05
            hs += 2
            extra = ["hit_level = 2"]
        elif prof["low"] == key:
            # Bajo: solo se bloquea agachado. Un frame más lento.
            st += 1
            dmg *= 0.95
            extra = ["hit_level = 1"]
        name = prof["names"].get(key, c["moves"][idx])
        out[slot] = attack(slot, name, kind, prof["anim"].get(key, anim), round(dmg, 1), hs, bs, kn, 0, hstop, fx,
                           st, ac, rec, (round(r * ox * xr), round(oy * h)), (round(w * k * xr), hh),
                           c_off, a_off, True, True, 0, 0, 0, 0, "ball", extra=extra)
    return out


# --------------------------------------------------------------------------
#  Ultimates: cada luchador tiene el suyo. Tipo (escena de pantalla completa), dibujo
#  principal, color de las grietas, color con el que se nubla el ambiente y animación.
#  Tipos: barrage (bombardeo) · charge (estampida) · quake (terremoto) · storm (tormenta)
#         light (luz sagrada) · wave (ondas de choque) · summon (aliados desde los lados)
#         meteor (meteoritos) · slash (lluvia de cortes en la oscuridad)
# --------------------------------------------------------------------------
ULTS = {
    "donald_trump": ("wave", "ring", "ffb030", "261a08", "megaphone"),
    "napoleon": ("barrage", "bomb", "ffb030", "241808", "cannon"),
    "kim_jong_un": ("barrage", "bomb", "ff5030", "2a0808", "cannon"),
    "vladimir_putin": ("summon", "bear", "d0d0d8", "0a1a2a", "cast"),
    "xi_jinping": ("summon", "dragon", "ffd040", "2a0808", "cast"),
    "nicolas_maduro": ("wave", "dance", "ff70c0", "2a0a22", "cast"),
    "adolf_hitler": ("quake", "", "d8c8a0", "1a160c", "rush"),
    "joseph_stalin": ("quake", "", "9ab0c8", "10141c", "straight"),
    "benito_mussolini": ("charge", "legion", "d8d0b0", "1a1a1a", "rush"),
    "saddam_hussein": ("meteor", "meteor", "ffb030", "3a2208", "cast"),
    "osama_bin_laden": ("slash", "", "c0b0e0", "05030a", "cast"),
    "gengis_kan": ("charge", "horses", "e0a040", "2a2008", "charge"),
    "fidel_castro": ("wave", "ring", "ff9030", "281408", "megaphone"),
    "cleopatra": ("summon", "jackal", "40d060", "14200a", "cast"),
    "julio_cesar": ("summon", "legion", "e04040", "2a0808", "charge"),
    "alejandro_magno": ("charge", "horses", "b060e0", "1c0a2a", "charge"),
    "isabel_ii": ("summon", "corgis", "6a9ad0", "0a1428", "cast"),
    "abraham_lincoln": ("storm", "", "ffe880", "0e1018", "axe"),
    "jesus_de_nazaret": ("light", "", "fff0b0", "1a1408", "cast"),
    "buda": ("wave", "ring", "ffd040", "1a1200", "cast"),
    "papa_francisco": ("light", "", "fff4d0", "1a1408", "cast"),
    "rasputin": ("slash", "", "a050e0", "060210", "cast"),
    "pablo_escobar": ("barrage", "bill", "50c060", "08200c", "cannon"),
    "albert_einstein": ("wave", "ring", "70e0ff", "041020", "cast"),
    "nikola_tesla": ("storm", "", "70e0ff", "060c1c", "cast"),
    "leonardo_da_vinci": ("barrage", "bomb", "ffb030", "241808", "cast"),
    "marie_curie": ("barrage", "sphere", "60f070", "061a0a", "flask"),
    "galileo_galilei": ("meteor", "meteor", "ffd070", "080818", "cast"),
    "charles_darwin": ("summon", "monkeys", "70d060", "0a1a0a", "cast"),
    "cristobal_colon": ("charge", "caravel", "60b0ff", "08202e", "cast"),
    "janequeo": ("slash", "", "d0d4dc", "14080a", "staff"),
    "lautaro": ("charge", "toqui", "e03030", "1a0808", "staff"),
    "pachacutec": ("light", "", "ffc040", "1a1204", "axe"),
    "ivan_el_terrible": ("storm", "", "a0e0ff", "08121e", "cast"),
    "boudica": ("charge", "chariot", "d04040", "0c1a0c", "cast"),
    "juana_de_arco": ("light", "", "ffe0a0", "1a1408", "charge"),
    "augusto_pinochet": ("slash", "", "9aaa9a", "000000", "cast"),
    "salvador_allende": ("wave", "ring", "e03030", "260606", "cast"),
    "arturo_prat": ("charge", "shipfull", "5090e0", "081828", "charge"),
    # Fatalities caricaturescas: trap (un objeto gigante atrapa al rival) · snipe (un solo disparo).
    "socrates": ("trap", "hemlock", "60d070", "0a1a10", "cast"),
    "platon": ("trap", "cave", "fff0b0", "05030a", "scroll"),
    "aristoteles": ("trap", "blackboard", "80f0c0", "0a1414", "cast"),
    "sun_tzu": ("summon", "ghost_army", "90b8ff", "080c1a", "cast"),
    "confucio": ("trap", "statue", "ffd860", "1a1408", "staff"),
    "isaac_newton": ("trap", "apple", "ff5040", "0a0a1a", "cast"),
    "hernan_cortes": ("charge", "galleon", "60b0ff", "06182a", "charge"),
    "moctezuma_ii": ("trap", "sundisc", "ffc040", "2a1404", "cast"),
    "nicolas_maquiavelo": ("trap", "prince_book", "e8c040", "140608", "dagger"),
    "mariya_oktyabrskaya": ("snipe", "tank", "ff9040", "1a1408", "pistol"),
    "liudmila_pavlichenko": ("snipe", "scope", "ff4040", "000000", "rifle"),
}


def ultimate_attack(cid, name):
    """El ultimate: un poder a pantalla completa (PowerEffects._cast_ultimate) con su ambiente."""
    kind, art, color, tint, anim = ULTS[cid]
    extra = ['power = &"ult"', f'ult_kind = &"{kind}"', f'ult_art = &"{art}"',
             f"ult_color = {col(color)}", f"ult_tint = {col(tint)}"]
    return attack("ultimate", name, 3, anim, 35, 60, 8, 260, 0, 14, 1.0,
                  20, 4, 40, (60, -40), (120, 80), (0, 0), (0, 0), True, True,
                  100, 0, 0, 0, "ball", extra=extra)


def patch_hand_made_ultimate(fid, text):
    """Pone a Trump / Napoleón el ultimate nuevo conservando su nombre."""
    import re
    name = re.search(r'id = &"ultimate"\ndisplay_name = "([^"]*)"', text).group(1)
    pat = re.compile(r'(\[sub_resource type="Resource" id="[^"]+"\]\nscript = ExtResource\("[^"]+"\)\n)(id = &"ultimate"\n.*?)(\n\n)', re.S)
    text, n = pat.subn(lambda mm: mm.group(1) + "\n".join(ultimate_attack(fid, name)) + mm.group(3), text, count=1)
    assert n == 1, f"no se encontró el ultimate de {fid}"
    return text


def look_lines(c):
    """Rasgos de aspecto (silueta, falda, gafas, capa, joyas) de la ficha."""
    out = []
    if c.get("female"):
        out.append("female = true")
    if c.get("outfit"):
        out.append(f'outfit = &"{c["outfit"]}"')
        if c.get("outfit_color"):
            out.append(f"outfit_color = {col(c['outfit_color'])}")
    if c.get("eyes"):
        out.append(f'eye_shape = &"{c["eyes"]}"')
    if c.get("glasses"):
        out.append(f'glasses = &"{c["glasses"]}"')
    if c.get("cape"):
        out.append(f"cape_color = {col(c['cape'])}")
    if c.get("jewelry"):
        out.append(f'jewelry = &"{c["jewelry"]}"')
        out.append(f"jewelry_color = {col(c.get('jewelry_color', 'e8c040'))}")
    return out


def combo_resource_lines(cid, prof):
    """Sub-recursos ComboData del luchador y la lista de referencias (para `combos = ...`)."""
    lines, refs = [], []
    for i, (cname, seq, bonus) in enumerate(prof["combos"]):
        keys = seq.split()
        ranks = [RANK_OF[x] for x in keys]
        assert ranks == sorted(ranks) and len(set(keys)) == len(keys), f"combo imposible en {cid}: {seq}"
        assert keys[-1] not in ("S1", "S2") or len(keys) >= 3
        rid = f"C_{cid}_{i}"
        slug = "".join(ch for ch in cname.lower() if ch.isalnum()) or f"combo{i}"
        lines += [f'[sub_resource type="Resource" id="{rid}"]', 'script = ExtResource("{COMBO}")',
                  f'id = &"{slug}"', f'display_name = "{esc(cname)}"',
                  "sequence = Array[StringName]([" + ", ".join(f'&"{SLOT_OF[x]}"' for x in keys) + "])",
                  "max_gap_frames = 24", f"bonus_damage = {f(bonus)}", ""]
        refs.append(f'SubResource("{rid}")')
    return lines, refs


def build_attacks(c, h, tempo):
    """Devuelve {slot: líneas} para las 7 ranuras de ataque."""
    ds = {"fast": -1, "normal": 0, "slow": 1}[tempo]
    k = h / 70.0
    r = 0.4 * h  # alcance base

    def t(st, rec):
        return max(3, st + ds), max(5, rec + ds)

    out = build_normals(c, h, tempo)
    out["special_1"] = special(c["s1"], "special_1", h, k, r, 25, 45)
    out["special_2"] = special(c["s2"], "special_2", h, k, r, 40, 60)
    out["ultimate"] = ultimate_attack(c["id"], c["ult"])
    return out


def special(s, slot, h, k, r, default_cost, default_cd):
    kind = 2
    cost = s.get("cost", default_cost)
    cd = s.get("cooldown", default_cd)
    dmg = s.get("dmg", 15)
    aid = s["name"].lower().replace(" ", "_")
    aid = "".join(ch for ch in aid if ch.isalnum() or ch == "_") or slot
    typ = s["type"]
    if typ == "power":
        extra = [f'power = &"{s["power"]}"']
        if s.get("status"):
            extra += [f'status = &"{s["status"]}"', f'status_frames = {s["status_frames"]}']
        if s.get("energy"):
            extra.append(f"energy_on_hit = {f(s['energy'])}")
        return attack(aid, s["name"], kind, s["anim"], dmg, 24, 14, 180, 0, 7, 1.5,
                      s.get("startup", 14), s.get("active", 4), 24, (0, 0), (10, 10), (0, 0), (0, 0),
                      False, False, cost, cd, s.get("dash", 0), 0, "ball", extra=extra)
    if typ == "proj":
        style = s.get("style", "ball")
        size = PROJ_BOX[style]
        return attack(aid, s["name"], kind, s["anim"], dmg, 22, 14, 175, 0, 6, 1.3,
                      14, 2, 20, (round(0.45 * h), round(-0.7 * h)), size, (0, 0), (0, 0),
                      False, False, cost, cd, 0, s.get("speed", 215), style,
                      s.get("color") if style in ("orb", "bolt", "spin") else None)
    if typ == "launch":
        return attack(aid, s["name"], kind, s["anim"], dmg, 30, 16, 120, s.get("launch", -330), 9, 1.5,
                      12, 6, 24, (round(0.34 * h), round(-0.6 * h)), (round(30 * k), round(46 * k)),
                      (0, 0), (0, 0), False, False, cost, cd, 0, 0, "ball")
    if typ == "dash":
        return attack(aid, s["name"], kind, s["anim"], dmg, 26, 16, 260, 0, 9, 1.6,
                      8, 12, 20, (round(0.43 * h), round(-0.52 * h)), (round(28 * k), round(30 * k)),
                      (0, 0), (0, 0), False, False, cost, cd, s.get("dash", 300), 0, "ball")
    # slam: golpe pesado y lento, empuja muy lejos
    return attack(aid, s["name"], kind, s["anim"], dmg, 32, 18, 290, 0, 10, 1.7,
                  14, 5, 26, (round(0.45 * h), round(-0.55 * h)), (round(32 * k), round(36 * k)),
                  (0, 0), (0, 0), False, False, cost, cd, 0, 0, "ball")


def build_tres(c):
    hp, walk, jump, jfwd, strength, resist, tempo = ARCHETYPES[c["arch"]]
    thigh, shin, legw, torso, tw, ua, fa, aw, hw, hh = BUILDS[c["build"]]
    stand = thigh + shin + torso + 2 + hh + 3
    crouch = round(stand * 0.64)
    bw = max(22, tw + 8)
    atks = build_attacks(c, stand, tempo)

    slots = ["kick_heavy", "kick_light", "punch_heavy", "punch_light",
             "special_1", "special_2", "ultimate"]
    ids = {s: f"R_{c['id']}_{s}" for s in slots}
    n_sub = len(slots)
    out = [f'[gd_resource type="Resource" script_class="FighterData" load_steps={n_sub + 6} format=3]', "",
           '[ext_resource type="Script" path="res://scripts/combo_data.gd" id="1_combo"]',
           '[ext_resource type="Script" path="res://scripts/attack_data.gd" id="2_attack"]',
           '[ext_resource type="Script" path="res://scripts/fighter_data.gd" id="3_fighter"]', ""]
    for s in slots:
        out += [f'[sub_resource type="Resource" id="{ids[s]}"]', 'script = ExtResource("2_attack")']
        out += atks[s]
        out.append("")
    combo_lines, combo_refs = combo_resource_lines(c["id"], profile_for(c["id"]))
    out += [ln.replace("{COMBO}", "1_combo") for ln in combo_lines]
    out += [
        "[resource]",
        'script = ExtResource("3_fighter")',
        f'id = &"{c["id"]}"',
        f'display_name = "{esc(c["name"])}"',
        f'short_name = "{esc(c["short"])}"',
        f'country = "{esc(c["country"])}"',
        f'era = "{esc(c["era"])}"',
        f'year = {year_of(c["era"])}',
        f'intro_quote = "{esc(c["intro"])}"',
        f'victory_quote = "{esc(c["victory"])}"',
        f'power_quote = "{esc(c.get("power_quote", ""))}"',
        f'bio = "{esc(c["bio"])}"',
        f"max_health = {f(hp)}",
        f"walk_speed = {f(walk)}",
        f"jump_velocity = {f(jump)}",
        f"jump_forward_speed = {f(jfwd)}",
        f"strength = {strength:.2f}",
        f"resistance = {resist:.2f}",
    ]
    for s in ("punch_light", "punch_heavy", "kick_light", "kick_heavy", "special_1", "special_2", "ultimate"):
        out.append(f'{s} = SubResource("{ids[s]}")')
    out += [
        'combos = Array[ExtResource("1_combo")]([' + ", ".join(combo_refs) + '])',
        f"body_width = {f(bw)}",
        f"stand_height = {f(stand)}",
        f"crouch_height = {f(crouch)}",
        "sprite_offset = Vector2(0, 0)",
        f"skin_color = {col(c['skin'])}",
        f"hair_color = {col(c['hair'])}",
        f"coat_color = {col(c['coat'])}",
        f"coat_trim_color = {col(c['trim'])}",
        f"shirt_color = {col(c['shirt'])}",
        f"accent_color = {col(c['accent'])}",
        f"pants_color = {col(c['pants'])}",
        f"boots_color = {col(c['boots'])}",
        f"hat_color = {col(c['hat'])}",
        f'hair_style = &"{c["hair_style"]}"',
        f'hat_style = &"{c["hat_style"]}"',
        f'beard_style = &"{c["beard"]}"',
        f'chest_style = &"{c["chest"]}"',
        f"has_epaulettes = {str(c.get('epaulettes', False)).lower()}",
        f"tall_boots = {str(c.get('tall_boots', False)).lower()}",
        f"thigh_len = {f(thigh)}",
        f"shin_len = {f(shin)}",
        f"leg_width = {f(legw)}",
        f"torso_len = {f(torso)}",
        f"torso_width = {f(tw)}",
        f"upper_arm_len = {f(ua)}",
        f"forearm_len = {f(fa)}",
        f"arm_width = {f(aw)}",
        f"head_width = {f(hw)}",
        f"head_height = {f(hh)}",
        'idle_style = &"normal"',
    ] + look_lines(c) + [
        "",
    ]
    return "\n".join(out)


# Rasgos que definen el aspecto de cada luchador más allá de los colores: silueta femenina,
# falda o vestido, peinado, gafas, capa y joyas. Se mezclan sobre la tabla CHARACTERS.
#   female, outfit (skirt|dress|gown), outfit_color, glasses (round|dark), cape (color),
#   jewelry (necklace|cross|earplug|pin), jewelry_color, eyes (almond), y cualquier campo de CHARACTERS.
LOOKS = {
    # --- Mujeres ---
    "cleopatra": dict(female=True, outfit="gown", outfit_color="f6f2e4", jewelry="necklace", jewelry_color="e8c040"),
    "isabel_ii": dict(female=True, outfit="dress", hair_style="updo", hat_style="tiara", hat="e8d060",
                      chest="plain", jewelry="necklace", jewelry_color="f4f4f4"),
    "marie_curie": dict(female=True, outfit="dress", outfit_color="34343c", hair_style="bun"),
    "janequeo": dict(female=True, outfit="dress", outfit_color="8a2020", hair_style="braids",
                     hat_style="headband", hat="c0c4cc", jewelry="necklace", jewelry_color="c0c4cc"),
    "boudica": dict(female=True, outfit="skirt", outfit_color="6a3a2a", cape="8a2a2a",
                    jewelry="necklace", jewelry_color="e8c040"),
    "juana_de_arco": dict(female=True, outfit="skirt", outfit_color="2a4ab0", hair_style="bob",
                          hat_style="none", jewelry="cross", jewelry_color="e8c040"),
    "mariya_oktyabrskaya": dict(female=True),
    "liudmila_pavlichenko": dict(female=True, outfit="skirt", outfit_color="5a5a3a"),
    # --- Túnicas, capas y joyas de los nuevos ---
    "socrates": dict(outfit="skirt", outfit_color="e8e2d0"),
    "platon": dict(outfit="skirt", outfit_color="ece6d4", cape="3a5a9a"),
    "aristoteles": dict(outfit="skirt", outfit_color="e0d4b4", cape="6a3a6a"),
    "confucio": dict(outfit="gown", outfit_color="2a5a5a"),
    "hernan_cortes": dict(cape="8a1a1a"),
    "moctezuma_ii": dict(outfit="skirt", outfit_color="e8e0c8", cape="2a8a7a", jewelry="earplug", jewelry_color="e8c040"),
    "nicolas_maquiavelo": dict(outfit="dress", outfit_color="1c1c24"),
    # --- Hombres con rasgos propios ---
    "augusto_pinochet": dict(glasses="dark", cape="4a5a4a"),
    "salvador_allende": dict(glasses="round"),
    "papa_francisco": dict(glasses="round", jewelry="cross", jewelry_color="c8c8d0"),
    "rasputin": dict(jewelry="cross", jewelry_color="c8a040"),
    "ivan_el_terrible": dict(cape="5a1020", jewelry="cross", jewelry_color="e8c040"),
    "pachacutec": dict(cape="2a8a9a", jewelry="earplug", jewelry_color="e8c040"),
    "lautaro": dict(hat_style="headband", hat="c02828"),
    "gengis_kan": dict(cape="4a3a8a"),
    "julio_cesar": dict(cape="b02020"),
    "alejandro_magno": dict(cape="7a2a8a"),
    "cristobal_colon": dict(cape="8a2a2a"),
    "arturo_prat": dict(hair_style="bald", hat_style="none"),   # calvo y sin gorra, con barba
    "leonardo_da_vinci": dict(cape="6a2a2a"),
    "pablo_escobar": dict(jewelry="necklace", jewelry_color="e8c040"),   # cadena de oro
    "kim_jong_un": dict(jewelry="pin", jewelry_color="c02020", eyes="almond"),        # insignia roja del Partido
    "xi_jinping": dict(jewelry="pin", jewelry_color="c02020", eyes="almond"),         # insignia del Partido en la solapa
}


# --------------------------------------------------------------------------
#  Frases y poder especial (special_2) de los 30 luchadores.
#  id: (frase inicial, frase de victoria)
# --------------------------------------------------------------------------
QUOTES = {
    "donald_trump": ("¡Este combate será el mejor de todos los tiempos!", "¡Una victoria espectacular! ¡Nadie pelea mejor que yo!"),
    "kim_jong_un": ("¡Mi poder no tiene límites!", "¡Victoria absoluta! ¡Que lo transmitan por televisión!"),
    "vladimir_putin": ("No sabes con quién te estás metiendo.", "El resultado estaba decidido."),
    "xi_jinping": ("La paciencia es una gran estrategia.", "El orden ha sido restaurado."),
    "nicolas_maduro": ("¡La victoria está garantizada, hermano!", "¡Victoria revolucionaria!"),
    "adolf_hitler": ("¡Este combate será una conquista!", "¡El combate ha terminado!"),
    "joseph_stalin": ("Aquí no hay lugar para los débiles.", "La victoria pertenece al Estado."),
    "benito_mussolini": ("¡Mírame bien, porque soy el espectáculo!", "¡Una victoria digna de un gran discurso!"),
    "saddam_hussein": ("¡Este territorio es mío!", "¡Nadie pudo derrotarme!"),
    "osama_bin_laden": ("La sombra siempre encuentra su objetivo.", "La batalla termina aquí."),
    "napoleon": ("¡La victoria es cuestión de estrategia!", "¡Otra conquista para el emperador!"),
    "gengis_kan": ("¡Mi imperio no conoce fronteras!", "¡Otro territorio conquistado!"),
    "fidel_castro": ("¡Prepárate, que esto va para largo!", "¡La resistencia ha triunfado!"),
    "cleopatra": ("¡Arrodíllate ante la reina del Nilo!", "¡La reina nunca pierde su corona!"),
    "julio_cesar": ("¡Vine, vi y venceré!", "¡Veni, vidi, vici!"),
    "alejandro_magno": ("¡El mundo entero será mío!", "¡Una conquista más para la historia!"),
    "isabel_ii": ("La corona no se inclina ante nadie.", "God save the Queen."),
    "abraham_lincoln": ("¡La libertad también se defiende en combate!", "¡La libertad ha prevalecido!"),
    "jesus_de_nazaret": ("Que comience el combate; que prevalezca la paz.", "La luz siempre encuentra su camino."),
    "buda": ("La mente tranquila es mi mayor poder.", "La verdadera victoria comienza dentro de uno mismo."),
    "papa_francisco": ("¡Que Dios nos acompañe en este combate!", "¡La paz sea contigo!"),
    "rasputin": ("¡No puedes matar lo que no puedes comprender!", "¡Te dije que no era fácil deshacerte de mí!"),
    "pablo_escobar": ("Plata o plomo, ¡tú eliges!", "¡El patrón sigue mandando!"),
    "albert_einstein": ("¡Todo es relativo, excepto mi victoria!", "¡Era cuestión de física!"),
    "nikola_tesla": ("¡Prepárate para una descarga de genialidad!", "¡La electricidad nunca falla!"),
    "leonardo_da_vinci": ("¡El arte de ganar es una ciencia!", "¡Una obra maestra!"),
    "marie_curie": ("¡La ciencia tiene sus propios secretos!", "¡Una victoria científicamente comprobada!"),
    "galileo_galilei": ("¡Y, sin embargo, te voy a derrotar!", "¡Tenía razón!"),
    "charles_darwin": ("¡Solo los más fuertes sobreviven!", "¡La evolución ha elegido al ganador!"),
    "cristobal_colon": ("¡Prepárate para descubrir tu derrota!", "¡Tierra a la vista... y victoria asegurada!"),
    "janequeo": ("¡Mi pueblo no se arrodilla ante nadie!", "¡La tierra de mis antepasados sigue en pie!"),
    "lautaro": ("¡Hoy luchamos por nuestra libertad!", "¡Ni el imperio más poderoso pudo detenernos!"),
    "pachacutec": ("¡Desde los Andes se levantará mi imperio!", "¡El Tahuantinsuyo jamás será olvidado!"),
    "ivan_el_terrible": ("¡Ante el zar, todos tiemblan!", "¡El zar siempre obtiene lo que quiere!"),
    "boudica": ("¡Mi pueblo no nació para ser esclavo!", "¡La reina de los icenos nunca se rinde!"),
    "juana_de_arco": ("¡Mi espada lucha por una causa!", "¡La fe me dio fuerzas para vencer!"),
    "augusto_pinochet": ("¡Aquí se hace lo que yo ordeno!", "¡Se acabó el combate!"),
    "salvador_allende": ("¡La historia la escriben los pueblos!", "¡La historia es nuestra y la hacen los pueblos!"),
    "arturo_prat": ("¡Al abordaje, muchachos!", "¡Mientras exista valor, nunca habrá derrota!"),
    "socrates": ("¡Demuestra que puedes vencerme, si es que sabes cómo!", "¡Solo sé que hoy tú has perdido!"),
    "platon": ("¡La verdadera batalla ocurre en el mundo de las ideas!", "¡La razón siempre prevalece!"),
    "aristoteles": ("¡Todo combate tiene una explicación lógica!", "¡La observación confirma mi victoria!"),
    "sun_tzu": ("¡La mejor victoria es la que se consigue sin luchar!", "¡La estrategia ha decidido el resultado!"),
    "confucio": ("¡La disciplina es el camino hacia la victoria!", "¡El orden ha triunfado!"),
    "isaac_newton": ("¡Todo lo que sube tiene que bajar!", "¡La gravedad nunca se equivoca!"),
    "hernan_cortes": ("¡Una nueva conquista comienza aquí!", "¡La batalla ha terminado!"),
    "moctezuma_ii": ("¡El poder de Tenochtitlán no será olvidado!", "¡Mi imperio seguirá vivo en la historia!"),
    "nicolas_maquiavelo": ("¡En este combate, la estrategia lo es todo!", "¡El fin justifica la estrategia!"),
    "mariya_oktyabrskaya": ("¡Mi tanque abrirá el camino hacia la victoria!", "¡Misión cumplida! ¡El enemigo ha sido aplastado!"),
    "liudmila_pavlichenko": ("Un solo disparo es suficiente.", "Objetivo eliminado. Siguiente."),
}

# Frase que se grita al lanzar el poder especial (special_2). Vacía = no dice nada.
POWER_QUOTES = {
    "janequeo": "¡Por el espíritu de mi pueblo!",
    "lautaro": "¡Bajo el espíritu del Toqui!",
    "pachacutec": "¡Que tiemble la tierra!",
    "ivan_el_terrible": "¡Desata tu furia, tormenta!",
    "boudica": "¡Que ruja mi carro de guerra!",
    "juana_de_arco": "¡Por Orleans, que brille mi espada!",
    "augusto_pinochet": "¡Se declara el Estado de Sitio!",
    "salvador_allende": "¡Que avance la vía chilena!",
    "arturo_prat": "¡A toda máquina, Esmeralda!",
    "socrates": "¡Responde esta pregunta!",
    "platon": "¡Contempla el mundo de las ideas!",
    "aristoteles": "¡Que comience el experimento!",
    "sun_tzu": "¡Cae en mi estrategia!",
    "confucio": "¡Restableceré el equilibrio!",
    "isaac_newton": "¡Que actúe la gravedad!",
    "hernan_cortes": "¡Avancen los conquistadores!",
    "moctezuma_ii": "¡Despierta, dios del Sol!",
    "nicolas_maquiavelo": "¡Que caigan en mi trampa!",
    "mariya_oktyabrskaya": "¡Enciende los motores!",
    "liudmila_pavlichenko": "¡No fallaré!",
}

# Poder especial (botón L / Numpad 6). El daño es el TOTAL si todo conecta.
POWERS = {
    "donald_trump": W(name="Muro Imparable", anim="cast", power="wall", dmg=22),
    "kim_jong_un": W(name="Lluvia de Cohetes", anim="cannon", power="rockets", dmg=20),
    "vladimir_putin": W(name="Oso Siberiano", anim="cast", power="bear", dmg=20),
    "xi_jinping": W(name="Dragón Imperial", anim="cast", power="dragon", dmg=22),
    "nicolas_maduro": W(name="Baile Sorpresa", anim="cast", power="dance", dmg=18),
    "adolf_hitler": W(name="Marcha del Caos", anim="rush", power="chaos_march", dmg=18),
    "joseph_stalin": W(name="Puño de Acero", anim="straight", power="steel_fist", dmg=22),
    "benito_mussolini": W(name="Discurso Explosivo", anim="megaphone", power="big_speech", dmg=20),
    "saddam_hussein": W(name="Tormenta del Desierto", anim="cast", power="sandstorm", dmg=21),
    "osama_bin_laden": W(name="Fantasma del Desierto", anim="cast", power="desert_ghost", dmg=18),
    "napoleon": W(name="Artillería Imperial", anim="cannon", power="artillery", dmg=20),
    "gengis_kan": W(name="Carga Mongola", anim="cast", power="mongol_charge", dmg=22),
    "fidel_castro": W(name="Discurso Interminable", anim="megaphone", power="endless_speech", dmg=18),
    "cleopatra": W(name="Maldición de Anubis", anim="cast", power="anubis", dmg=20),
    "julio_cesar": W(name="Legión Romana", anim="cast", power="legion", dmg=20),
    "alejandro_magno": W(name="Carga de Bucéfalo", anim="rush", power="bucephalus", dmg=22, startup=8, active=14, dash=400),
    "isabel_ii": W(name="Protocolo Real", anim="cast", power="royal_guards", dmg=18),
    "abraham_lincoln": S(name="Hacha Presidencial", anim="axe", dmg=24),
    "jesus_de_nazaret": W(name="Luz Divina", anim="cast", power="divine_light", dmg=16, energy=30),
    "buda": W(name="Iluminación", anim="cast", power="enlightenment", dmg=20),
    "papa_francisco": W(name="Campanas del Vaticano", anim="cast", power="vatican_bells", dmg=18),
    "rasputin": W(name="Hipnosis Oscura", anim="cast", power="dark_hypnosis", dmg=14, status="invert", status_frames=150),
    "pablo_escobar": W(name="Lluvia de Billetes", anim="cannon", power="bill_rain", dmg=20),
    "albert_einstein": W(name="Relatividad", anim="cast", power="relativity", dmg=12, status="slow", status_frames=150),
    "nikola_tesla": W(name="Tormenta Tesla", anim="cast", power="tesla_storm", dmg=20),
    "leonardo_da_vinci": W(name="Máquina Voladora", anim="cast", power="flying_machine", dmg=20),
    "marie_curie": W(name="Radiación Radiante", anim="flask", power="radiant_sphere", dmg=20),
    "galileo_galilei": W(name="Gravedad Invertida", anim="cast", power="gravity_flip", dmg=14, status="float", status_frames=80),
    "charles_darwin": W(name="Evolución Salvaje", anim="cast", power="wild_evolution", dmg=20),
    "cristobal_colon": W(name="Descubrimiento", anim="cast", power="discovery", dmg=22),
    "janequeo": W(name="Espíritu del Weichan", anim="staff", power="weichan_spirit", dmg=20),
    "lautaro": W(name="Carga del Toqui", anim="staff", power="toqui_charge", dmg=22),
    "pachacutec": W(name="Terremoto Andino", anim="axe", power="andean_quake", dmg=20),
    "ivan_el_terrible": W(name="Furia del Zar", anim="cast", power="tsar_fury", dmg=21),
    "boudica": W(name="Carro de Guerra", anim="cast", power="war_chariot", dmg=22),
    "juana_de_arco": W(name="Espada de Orleans", anim="charge", power="orleans_blade", dmg=20),
    "augusto_pinochet": W(name="Estado de Sitio", anim="cast", power="state_siege", dmg=20, status="root", status_frames=100),
    "salvador_allende": W(name="Vía Chilena", anim="cast", power="chilean_way", dmg=18),
    "arturo_prat": W(name="Abordaje de la Esmeralda", anim="charge", power="esmeralda", dmg=20),
    "socrates": W(name="Método Socrático", anim="staff", power="socratic", dmg=20, status="invert", status_frames=90),
    "platon": W(name="Mundo de las Ideas", anim="scroll", power="ideas", dmg=21),
    "aristoteles": W(name="Lógica Implacable", anim="cast", power="logic", dmg=20),
    "sun_tzu": W(name="El Arte de la Guerra", anim="charge", power="art_of_war", dmg=21),
    "confucio": W(name="Orden Celestial", anim="cast", power="celestial_order", dmg=20),
    "isaac_newton": W(name="Gravedad Absoluta", anim="cast", power="gravity_absolute", dmg=22, status="float", status_frames=45),
    "hernan_cortes": W(name="Conquista de Tenochtitlán", anim="cast", power="conquest", dmg=22),
    "moctezuma_ii": W(name="Cólera de Huitzilopochtli", anim="cast", power="huitzilopochtli", dmg=22),
    "nicolas_maquiavelo": W(name="El Príncipe", anim="dagger", power="the_prince", dmg=20, status="root", status_frames=70),
    "mariya_oktyabrskaya": W(name="Tanque Fighting Girlfriend", anim="cast", power="t34", dmg=22),
    "liudmila_pavlichenko": W(name="Disparo de la Muerte", anim="rifle", power="death_shot", dmg=21, status="slow", status_frames=120),
}

# Especiales 1 que se cambian para no repetir el estilo del poder nuevo.
S1_OVERRIDE = {
    "kim_jong_un": D(name="Desfile Militar", anim="rush", dmg=18, dash=280),
    "fidel_castro": P(name="Puro Explosivo", anim="cannon", style="orb", color="ff9030", speed=215, dmg=15),
    "marie_curie": L(name="Explosión de Radio", anim="flask", dmg=18, launch=-330),
    "pablo_escobar": D(name="Hipopótamo Descontrolado", anim="rush", dmg=18, dash=290),
    "nikola_tesla": D(name="Carrera Eléctrica", anim="rush", dmg=17, dash=300),
    "leonardo_da_vinci": S(name="Hombre de Vitruvio", anim="cast", dmg=20),
    "jesus_de_nazaret": L(name="Bastón del Pastor", anim="staff", dmg=18, launch=-330),
    "rasputin": L(name="Bastón Místico", anim="staff", dmg=18, launch=-330),
}

# Fichas hechas a mano: solo se les cambia la frase y el poder especial 2.
HAND_MADE = {"donald_trump": 1.0, "napoleon": 1.0}  # id -> altura relativa (ver patch_hand_made)
HAND_STAND = {"donald_trump": 76.0, "napoleon": 66.0}


def patch_hand_made_normals(fid, text):
    """Pone a Trump / Napoleón los golpes normales y combos de su perfil (sin tocar el resto)."""
    import re
    h = HAND_STAND[fid]
    slots = ["punch_light", "punch_heavy", "kick_light", "kick_heavy"]
    moves = tuple(re.search(r'id = &"%s"\ndisplay_name = "([^"]*)"' % s, text).group(1) for s in slots)
    atks = build_normals({"id": fid, "moves": moves}, h, "normal")
    for s in slots:
        pat = re.compile(r'(\[sub_resource type="Resource" id="[^"]+"\]\nscript = ExtResource\("[^"]+"\)\n)(id = &"%s"\n.*?)(\n\n)' % s, re.S)
        text, n = pat.subn(lambda mm: mm.group(1) + "\n".join(atks[s]) + mm.group(3), text, count=1)
        assert n == 1, f"no se encontró {s} de {fid}"
    # Combos propios (se quitan los de una pasada anterior para poder repetir el script).
    text = re.sub(r'\[sub_resource type="Resource" id="C_%s_\d+"\]\n.*?\n\n' % fid, "", text, flags=re.S)
    cext = re.search(r'path="res://scripts/combo_data.gd" id="([^"]+)"', text).group(1)
    lines, refs = combo_resource_lines(fid, profile_for(fid))
    lines = [ln.replace("{COMBO}", cext) for ln in lines]
    text = text.replace("[resource]\n", "\n".join(lines) + "\n[resource]\n", 1)
    text = re.sub(r'^combos = .*$', lambda mm: 'combos = Array[ExtResource("%s")]([%s])' % (cext, ", ".join(refs)), text, flags=re.M)
    return text


def patch_hand_made(fid):
    """Cambia frases y special_2 de Trump / Napoleón sin tocar sus estadísticas."""
    import re
    path = ROOT / "fighters" / fid / f"{fid}.tres"
    text = path.read_text(encoding="utf-8")
    m = re.search(r'^special_2 = SubResource\("([^"]+)"\)', text, re.M)
    sid = m.group(1)
    block = re.compile(r'(\[sub_resource type="Resource" id="%s"\]\nscript = ExtResource\("[^"]+"\)\n)(.*?)(\n\n)' % re.escape(sid), re.S)
    c = dict(CHARACTERS_BY_ID.get(fid, {}))
    h = HAND_STAND[fid]
    new = "\n".join(special(POWERS[fid], "special_2", h, h / 70.0, 0.4 * h, 40, 60))
    text, n = block.subn(lambda mm: mm.group(1) + new + mm.group(3), text, count=1)
    assert n == 1, f"no se encontró el bloque special_2 de {fid}"
    intro, victory = QUOTES[fid]
    text = re.sub(r'^intro_quote = .*$', lambda mm: f'intro_quote = "{esc(intro)}"', text, flags=re.M)
    text = re.sub(r'^victory_quote = .*$', lambda mm: f'victory_quote = "{esc(victory)}"', text, flags=re.M)
    text = patch_hand_made_normals(fid, text)
    text = patch_hand_made_ultimate(fid, text)
    path.write_text(text, encoding="utf-8", newline="\n")
    print("PARCHE", path)


CHARACTERS_BY_ID = {}


def wrap_lines(text, width=21):
    lines, line = 0, ""
    for w in text.split(" "):
        test = w if not line else line + " " + w
        if len(test) > width and line:
            lines += 1
            line = w
        else:
            line = test
    return lines + (1 if line else 0)


def validate(c):
    errs = []
    if len(c["short"]) > 11:   # ARISTÓTELES; la placa de selección admite ~13
        errs.append(f"short_name largo ({len(c['short'])})")
    if len(c["era"]) > 15:
        errs.append(f"era larga ({len(c['era'])})")
    if len(c["country"]) > 15:
        errs.append(f"country largo ({len(c['country'])})")
    if wrap_lines('"%s"' % c["intro"]) > 4:
        errs.append(f"intro demasiado larga para la selección ({c['intro']})")
    return errs


def main():
    ids = [c["id"] for c in CHARACTERS]
    assert len(ids) == len(set(ids)), "ids duplicados"
    bad = False
    for c in CHARACTERS:
        CHARACTERS_BY_ID[c["id"]] = c
        c["intro"], c["victory"] = QUOTES[c["id"]]
        c["s2"] = POWERS[c["id"]]
        c["power_quote"] = POWER_QUOTES.get(c["id"], "")
        c.update(LOOKS.get(c["id"], {}))
        if c["id"] in S1_OVERRIDE:
            c["s1"] = S1_OVERRIDE[c["id"]]
        errs = validate(c)
        if errs:
            bad = True
            print(f"[AVISO] {c['id']}: {', '.join(errs)}")
        if c["id"] in SKIP:
            continue
        folder = ROOT / "fighters" / c["id"]
        folder.mkdir(parents=True, exist_ok=True)
        (folder / f"{c['id']}.tres").write_text(build_tres(c), encoding="utf-8", newline="\n")
        print("OK ", folder / f"{c['id']}.tres")
    for fid in HAND_MADE:
        intro, _ = QUOTES[fid]
        if wrap_lines('"%s"' % intro) > 4:
            bad = True
            print(f"[AVISO] {fid}: intro demasiado larga")
        patch_hand_made(fid)
    for fid in QUOTES:
        assert fid in POWERS, fid
    print(f"{len(CHARACTERS)} personajes generados + {len(HAND_MADE)} parcheados.", "(hay avisos)" if bad else "")


if __name__ == "__main__":
    main()
