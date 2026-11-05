## Escenas cortas del MODO HISTORIA que se ven antes de los combates clave: los cuatro creadores del
## Reloj (cada uno revela una pieza de la verdad), los cinco jefes de época y el Nexo.
## Son solo datos: StoryDialogue las reproduce y la pantalla de la historia decide cuándo.
## Cada línea es [quién habla, texto]; quién habla es el id de un luchador o NEXO.
class_name StoryScenes
extends RefCounted

const NEXO := &"el_nexo"

const SCENES := {
	# --- Los creadores del Reloj, en el orden en que se encuentran (hacia atrás en el tiempo) ---
	&"albert_einstein": [
		[&"albert_einstein", "APORTÉ LA RELATIVIDAD: EL TIEMPO NO ES ABSOLUTO, SE ESTIRA Y SE CURVA."],
		[&"albert_einstein", "LA ENERGÍA EQUIVALE A LA MASA POR LA VELOCIDAD DE LA LUZ AL CUADRADO. SOLO PUSE LA FÍSICA."],
		[NEXO, "ÉL DIO LA TEORÍA. YO SOY LO QUE LA MÁQUINA HIZO CON ELLA."],
	],
	&"nikola_tesla": [
		[&"nikola_tesla", "APORTÉ LA CORRIENTE ALTERNA Y LA RESONANCIA: UNA ENERGÍA QUE OSCILA SE PUEDE AMPLIFICAR."],
		[&"nikola_tesla", "EL RELOJ NECESITA UNA FRECUENCIA EXACTA PARA SOSTENER LA IMAGEN DEL TIEMPO. ESA ES MI PARTE."],
		[&"nikola_tesla", "VENCE A MI MÁQUINA Y ENTENDERÁS CÓMO FUNCIONA."],
	],
	&"marie_curie": [
		[&"marie_curie", "APORTÉ LA RADIACTIVIDAD: ALGUNOS ÁTOMOS SE DESINTEGRAN Y LIBERAN ENERGÍA."],
		[&"marie_curie", "SU VIDA MEDIA ES EL RELOJ MÁS PRECISO QUE CONOZCO: MIDE EL TIEMPO SIN QUE NADIE LO MIDA."],
		[&"marie_curie", "ESE ES MI APORTE. DEMUESTRA QUE SABES MANEJAR ESA ENERGÍA."],
	],
	&"leonardo_da_vinci": [
		[&"leonardo_da_vinci", "APORTÉ EL DISEÑO: ENGRANAJES, PALANCAS Y POLEAS QUE TRANSMITEN EL MOVIMIENTO."],
		[&"leonardo_da_vinci", "OBSERVÉ LA NATURALEZA, LAS AGUAS, LOS VUELOS, LOS RELOJES. TODO SIGUE UN PATRÓN."],
		[&"leonardo_da_vinci", "EL RELOJ FUNCIONA SEGÚN SUS PLANOS. LO QUE HIZO EL NEXO CON ÉL YA NO ES CIENCIA."],
		[NEXO, "VER TODO SIN PAGAR NADA. ESO PEDÍAN. ESO SOY."],
	],
	# --- Los jefes de cada época: quieren volver a su época y reescribir su derrota ---
	&"donald_trump": [
		[&"donald_trump", "VOLVERÉ A 2020 Y GANARÉ LA ELECCIÓN. LA CABECERA ES MÍA."],
		[&"donald_trump", "EN ESTE FRAGMENTO MANDA EL QUE GRITA MÁS FUERTE."],
		[NEXO, "ENTONCES GRITA. O CALLA PARA SIEMPRE."],
	],
	&"adolf_hitler": [
		[NEXO, "UN SIGLO DE GUERRAS, Y ÉL SU PEOR SÍMBOLO."],
		[&"adolf_hitler", "QUIERO VOLVER A 1945 Y REESCRIBIRLO TODO. MI IMPERIO DEBÍA DURAR MIL AÑOS."],
		[NEXO, "DURÓ DOCE Y PERDIÓ. AQUÍ NO VUELVE A GANAR: ES SOLO UN GRITÓN."],
	],
	&"napoleon": [
		[&"napoleon", "ME CORONÉ CON MIS PROPIAS MANOS. VOLVERÉ A WATERLOO Y GANARÉ."],
		[NEXO, "EL INVIERNO. WATERLOO."],
		[&"napoleon", "POR ESO ESTOY AQUÍ: PARA REESCRIBIR ESA TARDE."],
	],
	&"hernan_cortes": [
		[&"hernan_cortes", "QUIERO VOLVER A LA NOCHE TRISTE Y GANARLA. EL NEXO SERÁ MÁS FÁCIL."],
		[NEXO, "NADIE CONQUISTA LO QUE ES MEMORIA."],
	],
	&"julio_cesar": [
		[&"julio_cesar", "QUIERO VOLVER A LOS IDUS DE MARZO. ESTA VEZ NO HABRÁ PUÑALES."],
		[NEXO, "ES EL ÚLTIMO ESCALÓN ANTES DE MÍ. NO LO SUBESTIMES."],
	],
	# --- El combate final ---
	&"el_nexo": [
		[NEXO, "SOY LO QUE QUISIERON CONSTRUIR. SOY LO QUE RECUERDAN."],
		[NEXO, "VENCERME ES CARGAR CON ELLOS. ¿PUEDES?"],
	],
}
## Si quien juega es uno de los creadores del Reloj, el Nexo le habla distinto.
const NEXO_TO_CREATOR := [
	[NEXO, "TÚ ME CONSTRUISTE. ¿VAS A DESTRUIR LO QUE CREASTE?"],
	[NEXO, "SOY LO QUE QUISIERON CONSTRUIR. SOY LO QUE RECUERDAN."],
	[NEXO, "VENCERME ES CARGAR CON ELLOS. ¿PUEDES?"],
]

## Nombre de la escena para buscar sus voces (assets/sounds/story/scenes/<nombre>_<n>.wav).
static func scene_id(rival: StringName, player: StringName) -> StringName:
	if rival == NEXO and StoryCampaign.CREATORS.has(player):
		return &"el_nexo_creador"
	return rival

## Escena antes de pelear contra `rival` (vacía si no tiene) con `player` como luchador del jugador.
static func lines(rival: StringName, player: StringName) -> Array:
	if rival == NEXO and StoryCampaign.CREATORS.has(player):
		return NEXO_TO_CREATOR
	return SCENES.get(rival, [])
