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
         skin="f0d0a8", hair="141010", coat="3a4048", trim="9aa0a8", shirt="d8d8d8", accent="3a4048",
         pants="30343a", boots="141414", hat="141414",
         hair_style="short", hat_style="none", beard="none", chest="uniform",
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
         hair_style="short", hat_style="none", beard="none", chest="tie",
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
         skin="d8a878", hair="1c1410", coat="e8e8e0", trim="a0a0a0", shirt="e8e8e0", accent="3a6a3a",
         pants="3a4a6a", boots="3a2a1a", hat="141414",
         hair_style="curls", hat_style="none", beard="mustache", chest="plain",
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


def build_attacks(c, h, tempo):
    """Devuelve {slot: líneas} para las 7 ranuras de ataque."""
    ds = {"fast": -1, "normal": 0, "slow": 1}[tempo]
    k = h / 70.0
    r = 0.4 * h  # alcance base

    def t(st, rec):
        return max(3, st + ds), max(5, rec + ds)

    out = {}
    st, rec = t(4, 7)
    out["punch_light"] = attack("punch_light", c["moves"][0], 0, "jab", 5, 14, 8, 90, 0, 4, 1.0,
                                st, 3, rec, (round(r), round(-0.72 * h)), (round(21 * k), 10),
                                (0, 16), (-4, 16), True, True, 0, 0, 0, 0, "ball")
    st, rec = t(8, 14)
    out["punch_heavy"] = attack("punch_heavy", c["moves"][1], 0, "straight", 10, 20, 12, 168, 0, 7, 1.3,
                                st, 4, rec, (round(r * 1.2), round(-0.71 * h)), (round(25 * k), 12),
                                (0, 16), (-8, 16), True, True, 0, 0, 0, 0, "ball")
    st, rec = t(5, 8)
    out["kick_light"] = attack("kick_light", c["moves"][2], 1, "kick_low", 7, 15, 9, 110, 0, 5, 1.0,
                               st, 3, rec, (round(r * 0.95), round(-0.36 * h)), (round(23 * k), 10),
                               (2, 12), (-3, 22), True, True, 0, 0, 0, 0, "ball")
    st, rec = t(10, 16)
    out["kick_heavy"] = attack("kick_heavy", c["moves"][3], 1, "kick_high", 12, 22, 13, 205, 0, 8, 1.4,
                               st, 4, rec, (round(r * 0.92), round(-0.6 * h)), (round(23 * k), 14),
                               (2, 27), (-4, 36), True, True, 0, 0, 0, 0, "ball")
    out["special_1"] = special(c["s1"], "special_1", h, k, r, 25, 45)
    out["special_2"] = special(c["s2"], "special_2", h, k, r, 40, 60)
    out["ultimate"] = attack("ultimate", c["ult"], 3, "charge", 35, 60, 8, 260, 0, 14, 1.0,
                             20, 30, 30, (60, -40), (120, 80), (0, 0), (0, 0), True, True,
                             100, 0, 0, 0, "ball")
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
    out = [f'[gd_resource type="Resource" script_class="FighterData" load_steps={n_sub + 4} format=3]', "",
           '[ext_resource type="Script" path="res://scripts/combo_data.gd" id="1_combo"]',
           '[ext_resource type="Script" path="res://scripts/attack_data.gd" id="2_attack"]',
           '[ext_resource type="Script" path="res://scripts/fighter_data.gd" id="3_fighter"]', ""]
    for s in slots:
        out += [f'[sub_resource type="Resource" id="{ids[s]}"]', 'script = ExtResource("2_attack")']
        out += atks[s]
        out.append("")
    out += [
        "[resource]",
        'script = ExtResource("3_fighter")',
        f'id = &"{c["id"]}"',
        f'display_name = "{esc(c["name"])}"',
        f'short_name = "{esc(c["short"])}"',
        f'country = "{esc(c["country"])}"',
        f'era = "{esc(c["era"])}"',
        f'intro_quote = "{esc(c["intro"])}"',
        f'victory_quote = "{esc(c["victory"])}"',
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
        'combos = Array[ExtResource("1_combo")]([])',
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
        "",
    ]
    return "\n".join(out)


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
    if len(c["short"]) > 10:
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
