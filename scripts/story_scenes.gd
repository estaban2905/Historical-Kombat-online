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
		[&"albert_einstein", "LA ECUACIÓN QUE APORTÉ AHORA ME MUEVE A MÍ. EL NEXO LA USA PARA ATARME."],
		[&"albert_einstein", "EL TIEMPO ES RELATIVO Y EL NEXO LO ESTIRA A SU ANTOJO. VENCE A MI SOMBRA Y ME LIBERAS."],
		[NEXO, "ÉL DIO LA TEORÍA. YO SOY LO QUE LA MÁQUINA HIZO CON ELLA."],
	],
	&"nikola_tesla": [
		[&"nikola_tesla", "MI CORRIENTE ALTERNA SIGUE FLUYENDO POR EL NEXO. ES LA CUERDA QUE ME ARRASTRA."],
		[&"nikola_tesla", "TODO LO QUE OSCILA RESUENA. SI ROMPES MI RITMO, ROMPES SU CONTROL SOBRE MÍ."],
		[&"nikola_tesla", "GOLPEA AL RITMO ADECUADO Y ME SOLTARÁ."],
	],
	&"marie_curie": [
		[&"marie_curie", "LA RADIACTIVIDAD QUE APORTÉ ALIMENTA AL NEXO. NO SE AGOTA MIENTRAS ME TENGA."],
		[&"marie_curie", "TODO LO RADIACTIVO DECAE CON EL TIEMPO. EL CONTROL DEL NEXO TAMBIÉN, SI LO DEBILITAS."],
		[&"marie_curie", "NO TE DETENGAS. CUANDO CAIGA, TE DARÉ LO QUE SÉ."],
	],
	&"leonardo_da_vinci": [
		[&"leonardo_da_vinci", "DISEÑÉ LOS ENGRANAJES DEL RELOJ. EL NEXO LOS HA CONVERTIDO EN MI JAULA."],
		[&"leonardo_da_vinci", "EN MI CUADERNO ESTÁ EL PLANO COMPLETO: UN RELOJ DE CINCO FRAGMENTOS, Y YO SOY EL ÚLTIMO ENGRANAJE."],
		[&"leonardo_da_vinci", "OBSERVA SU MECANISMO. TODO MECANISMO TIENE UN PUNTO DÉBIL."],
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
	[NEXO, "TÚ ME DISTE FORMA Y ESTÁS ATADO A MÍ. ¿VAS A ROMPER LO QUE CREASTE?"],
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
