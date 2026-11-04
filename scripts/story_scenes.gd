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
		[&"albert_einstein", "SABÍA QUE LA ECUACIÓN TENÍA UN PRECIO. LA ENCENDIMOS IGUAL."],
		[&"albert_einstein", "SABER NO BASTA. LO CONSTRUIMOS PORQUE PODÍAMOS, NO PORQUE DEBÍAMOS."],
		[NEXO, "ÉL HABLA DE CULPA. YO LA LLAMO ORIGEN."],
	],
	&"nikola_tesla": [
		[&"nikola_tesla", "LE DI LA CORRIENTE AL RELOJ SIN PREGUNTAR A QUIÉN ALUMBRARÍA."],
		[&"nikola_tesla", "PENSÉ QUE LA ENERGÍA ERA SOLO ENERGÍA. SE ALIMENTA DE LO QUE SE LE DA."],
		[&"nikola_tesla", "VENCE A MI MÁQUINA Y ENTENDERÁS EL RESTO."],
	],
	&"marie_curie": [
		[&"marie_curie", "MI LUZ CURÓ A MUCHOS Y ENFERMÓ A OTROS. EL RELOJ HACE LO MISMO."],
		[&"marie_curie", "NADA QUE BRILLA TANTO SE TOCA SIN CONSECUENCIAS."],
		[&"marie_curie", "DEMUESTRA QUE PUEDES CARGAR CON ESA LUZ."],
	],
	&"leonardo_da_vinci": [
		[&"leonardo_da_vinci", "LA IDEA FUE MÍA: UN DIBUJO EN UN CUADERNO. NADA MÁS."],
		[&"leonardo_da_vinci", "NO TODO LO POSIBLE SE DEBE CONSTRUIR. ESO LO APRENDÍ TARDE."],
		[&"leonardo_da_vinci", "EL RELOJ NO SE ROMPIÓ: HIZO EXACTAMENTE LO QUE LE PEDIMOS."],
		[NEXO, "VER TODO SIN PAGAR NADA. ESO PEDÍAN. ESO SOY."],
	],
	# --- Los jefes de cada época ---
	&"donald_trump": [
		[&"donald_trump", "LLEGUÉ ÚLTIMO, PERO LA CABECERA ES MÍA."],
		[&"donald_trump", "EN ESTE FRAGMENTO MANDA EL QUE GRITA MÁS FUERTE."],
		[NEXO, "ENTONCES GRITA. O CALLA PARA SIEMPRE."],
	],
	&"adolf_hitler": [
		[NEXO, "UN SIGLO DE GUERRAS, Y ÉL SU PEOR SÍMBOLO."],
		[&"adolf_hitler", "MI IMPERIO DEBÍA DURAR MIL AÑOS. NO LO ACEPTO."],
		[NEXO, "DURÓ DOCE, Y EL MUNDO LO RECUERDA. AQUÍ ES SOLO UN GRITÓN."],
	],
	&"napoleon": [
		[&"napoleon", "ME CORONÉ CON MIS PROPIAS MANOS. ¿QUIÉN ME DIRÁ QUE NO?"],
		[NEXO, "EL INVIERNO. WATERLOO."],
		[&"napoleon", "POR ESO ESTOY AQUÍ: PARA VOLVER Y GANAR."],
	],
	&"hernan_cortes": [
		[&"hernan_cortes", "CONQUISTÉ UN IMPERIO CON AUDACIA Y ACERO. EL NEXO SERÁ MÁS FÁCIL."],
		[NEXO, "NADIE CONQUISTA LO QUE ES MEMORIA."],
	],
	&"julio_cesar": [
		[&"julio_cesar", "CRUCÉ EL RUBICÓN UNA VEZ. LO CRUZARÉ OTRA."],
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

## Escena antes de pelear contra `rival` (vacía si no tiene) con `player` como luchador del jugador.
static func lines(rival: StringName, player: StringName) -> Array:
	if rival == NEXO and StoryCampaign.CREATORS.has(player):
		return NEXO_TO_CREATOR
	return SCENES.get(rival, [])
