## Escenas cortas del MODO HISTORIA que se ven antes de los combates clave: los cuatro creadores del
## Reloj (cada uno revela una pieza de la verdad), los cinco jefes de época y el Nexo.
## Son solo datos: StoryDialogue las reproduce y la pantalla de la historia decide cuándo.
## Cada línea es [quién habla, texto]; quién habla es el id de un luchador o NEXO.
class_name StoryScenes
extends RefCounted

const NEXO := &"el_nexo"
## Hablante que se sustituye por el luchador que elige el jugador (voz de héroe o de heroína, ver lines()).
const PLAYER := &"@jugador"

const SCENES := {
	# --- Los creadores del Reloj (en la historia se encuentran en otro orden: Curie, Einstein, Tesla y Leonardo).
	# El Nexo los posee para detener al jugador: si ellos lo vencen, nadie más podrá desafiarlo. ---
	&"albert_einstein": [
		[&"albert_einstein", "EL NEXO ME ARRANCÓ DE BERNA, 1905, Y USA MI PROPIA ECUACIÓN PARA ATARME. NO PUEDO CONTROLAR MI CUERPO."],
		[&"albert_einstein", "EL TIEMPO ES RELATIVO Y EL NEXO LO ESTIRA A SU ANTOJO. VENCE A MI SOMBRA Y ME LIBERAS."],
		[NEXO, "ÉL DIO LA TEORÍA Y YO LA CONVERTÍ EN ARMA. SI TE VENCE, NADIE MÁS PODRÁ DESAFIARME."],
	],
	&"nikola_tesla": [
		[&"nikola_tesla", "ME ARRANCÓ DE COLORADO SPRINGS, 1899. MI CORRIENTE ALTERNA ES LA CUERDA QUE ME ARRASTRA."],
		[&"nikola_tesla", "TODO LO QUE OSCILA RESUENA. SI ROMPES MI RITMO, ROMPES SU CONTROL SOBRE MÍ."],
		[NEXO, "SU CORRIENTE ES MÍA. QUE TE APAGUE, Y EL RELOJ SEGUIRÁ SIENDO MÍO."],
		[&"nikola_tesla", "GOLPEA AL RITMO ADECUADO Y ME SOLTARÁ."],
	],
	&"marie_curie": [
		[&"marie_curie", "ME ARRANCÓ DE PARÍS, 1898. MI RADIACTIVIDAD ALIMENTA AL NEXO Y AL URANIO INFINITO DE KIM."],
		[&"marie_curie", "TODO LO RADIACTIVO DECAE CON EL TIEMPO. EL CONTROL DEL NEXO TAMBIÉN, SI LO DEBILITAS."],
		[NEXO, "SU ENERGÍA ES MI ENERGÍA. QUE ELLA TE CONSUMA Y NADIE LLEGARÁ A MÍ."],
		[&"marie_curie", "NO TE DETENGAS. CUANDO CAIGA, TE DARÉ LO QUE SÉ."],
	],
	&"leonardo_da_vinci": [
		[&"leonardo_da_vinci", "ME ARRANCÓ DE MILÁN, 1495, Y ME OBLIGÓ A DISEÑAR EL RELOJ. SUS ENGRANAJES SON MI JAULA."],
		[&"leonardo_da_vinci", "EN MI CUADERNO ESTÁ EL PLANO COMPLETO: UN RELOJ DE CINCO FRAGMENTOS, Y YO SOY EL ÚLTIMO ENGRANAJE."],
		[&"leonardo_da_vinci", "OBSERVA SU MECANISMO. TODO MECANISMO TIENE UN PUNTO DÉBIL."],
		[NEXO, "ME PIDIERON VER TODO SIN PAGAR NADA, Y ESO SOY. LEONARDO ES MI ÚLTIMO ENGRANAJE: SI TE VENCE, EL RELOJ QUEDA COMPLETO."],
	],
	# --- Los jefes de cada época: nombran su derrota o traición y quieren rehacerla. El Nexo les ofrece volver a ese
	# momento si derrotan al jugador, y el jugador responde por qué no puede permitirlo ---
	&"donald_trump": [
		[&"donald_trump", "EL MUNDO ESTÁ ROTO Y ES EL MEJOR MOMENTO PARA HACER NEGOCIOS. ME QUEDARÉ CON TODAS LAS CIUDADES."],
		[&"donald_trump", "EN ESTE FRENTE MANDA EL QUE GRITA MÁS FUERTE, Y YO GRITO MÁS QUE NADIE."],
		[NEXO, "ADELANTE, TRUMP. DERROTA A QUIEN ME DESAFÍA Y TE ENTREGO EL MUNDO ENTERO. TE LO PROMETO."],
		[PLAYER, "ESTE MUNDO NO ESTÁ EN VENTA. NO PUEDO DEJARTE COMPRARLO."],
	],
	&"adolf_hitler": [
		[NEXO, "UN SIGLO DE GUERRAS ME DEJÓ MUCHOS ARREPENTIDOS. EL MÁS TERRIBLE ESTÁ FRENTE A TI."],
		[&"adolf_hitler", "VOLVERÉ A STALINGRADO, 1943: MI SEXTO EJÉRCITO SE RINDIÓ Y ALLÍ SE DECIDIÓ LA GUERRA. ESTA VEZ LA GANARÉ."],
		[NEXO, "ENTONCES DERROTA A QUIEN ME DESAFÍA, Y EL TIEMPO TE CONCEDERÁ ESA VICTORIA."],
		[PLAYER, "NO. ESA DERROTA LIBERÓ A MILLONES. NO TE DEJARÉ REESCRIBIRLA."],
	],
	&"napoleon": [
		[&"napoleon", "VOLVERÉ A WATERLOO, 18 DE JUNIO DE 1815: WELLINGTON Y BLÜCHER ME DERROTARON. ESTA VEZ GANARÉ."],
		[NEXO, "HAZLO, EMPERADOR. APLASTA A QUIEN ME DESAFÍA Y TE DEVUELVO ESA TARDE."],
		[&"napoleon", "POR ESO ESTOY AQUÍ: PARA REESCRIBIR ESA TARDE."],
		[PLAYER, "WATERLOO YA OCURRIÓ, NAPOLEÓN. SI LO CAMBIAS, EUROPA ENTERA SE DESHACE."],
	],
	&"hernan_cortes": [
		[&"hernan_cortes", "VOLVERÉ A TENOCHTITLAN, 30 DE JUNIO DE 1520: LA NOCHE TRISTE. ESTA VEZ NO PERDERÉ A MIS HOMBRES."],
		[NEXO, "VENCE A QUIEN ME DESAFÍA, CORTÉS, Y TE DEVUELVO ESA NOCHE PARA QUE LA CAMBIES."],
		[PLAYER, "ESA NOCHE TAMBIÉN FORMA PARTE DE LA HISTORIA. NO PUEDO DEJARTE CAMBIARLA."],
	],
	&"julio_cesar": [
		[&"julio_cesar", "VOLVERÉ A ROMA, 15 DE MARZO DEL 44 A.C.: LOS IDUS DE MARZO. BRUTO ME TRAICIONÓ. ESTA VEZ NO HABRÁ PUÑALES."],
		[NEXO, "ES EL ÚLTIMO ESCALÓN. DERROTA A QUIEN ME DESAFÍA, CÉSAR, Y TE DEVUELVO ESE DÍA."],
		[PLAYER, "TU MUERTE CAMBIÓ A ROMA PARA SIEMPRE, CÉSAR. NO PUEDO DEJARTE EVITARLA."],
	],
	# --- Los rivales. Los muertos quieren volver a su derrota y rehacerla; los que siguen vivos hoy (Kim, Putin, Maduro, Trump)
	# aprovechan el caos y el poder del Nexo para tener más. El Nexo los anima a todos: le conviene que el jugador caiga.
	# El jugador responde por qué no puede permitirlo (su respuesta va siempre la última). ---
	# --- El mundo actual ---
	&"kim_jong_un": [
		[&"kim_jong_un", "ESTE CAOS ES MI OPORTUNIDAD: CON LA ENERGÍA DEL NEXO TENDRÉ MÁS BOMBAS NUCLEARES DE LAS QUE TENGO."],
		[NEXO, "TODO EL URANIO QUE QUIERAS, KIM. SOLO DEBES ACABAR CON QUIEN ME DESAFÍA Y TOMAR ESTA CIUDAD."],
		[PLAYER, "NINGUNA BOMBA DE MÁS VALE UN MUNDO ROTO. NO TE DEJARÉ USAR ESE PODER."],
	],
	&"nicolas_maduro": [
		[&"nicolas_maduro", "AQUÍ NO HAY CALENDARIO NI ELECCIONES. CON EL PODER DEL NEXO ME QUEDARÉ MANDANDO PARA SIEMPRE, CON TODO EL SHOW."],
		[NEXO, "SIÉNTATE EN LA SILLA, MADURO. SI VENCES A QUIEN ME DESAFÍA, NADIE TE SACARÁ DE ELLA."],
		[PLAYER, "EL PODER SIN FIN NO ES UN SHOW: ES UNA JAULA. NO TE DEJARÉ QUEDARTE."],
	],
	&"osama_bin_laden": [
		[&"osama_bin_laden", "VOLVERÉ A ABBOTTABAD, 2 DE MAYO DE 2011: ME ENCONTRARON EN MI ESCONDITE. ESTA VEZ ESCAPARÉ."],
		[NEXO, "YO TE DARÉ ESE DÍA OTRA VEZ. SOLO TIENES QUE DERROTAR A QUIEN ME DESAFÍA."],
		[PLAYER, "ABBOTTABAD NO SE CAMBIA. CUANDO TE ENCONTRARON, EL MUNDO CERRÓ UNA PÁGINA."],
	],
	&"vladimir_putin": [
		[&"vladimir_putin", "EL MUNDO ESTÁ ROTO Y YO ESTOY AQUÍ. CON LOS EJÉRCITOS DE TODAS LAS ÉPOCAS, MI IMPERIO NO TENDRÁ FRONTERAS."],
		[NEXO, "CONQUISTA ESTA TIERRA, PUTIN, Y SERÁ TUYA PARA SIEMPRE. PRIMERO, DERROTA A QUIEN ME DESAFÍA."],
		[PLAYER, "EL MUNDO NO SE REPARTE ENTRE IMPERIOS. NO TE DEJARÉ HACERLO."],
	],
	&"xi_jinping": [
		[&"xi_jinping", "TODA MI VIDA ESPERÉ CON PACIENCIA. CON EL PODER DEL NEXO, MI IMPERIO CRECERÁ SIN LÍMITES."],
		[NEXO, "LA PACIENCIA SE PREMIA, XI. DERROTA A QUIEN ME DESAFÍA Y EL DRAGÓN SERÁ TUYO."],
		[PLAYER, "ESTE MUNDO NO TIENE DUEÑO. NO TE DEJARÉ CONSTRUIR TU IMPERIO."],
	],
	&"pablo_escobar": [
		[&"pablo_escobar", "VOLVERÉ A MEDELLÍN, 2 DE DICIEMBRE DE 1993: ME ABATIERON EN UN TEJADO DE LOS OLIVOS. ESTA VEZ ESCAPARÉ."],
		[NEXO, "ESCAPA, PABLO. SOLO ACABA CON QUIEN ME DESAFÍA Y ESE TEJADO NO EXISTIRÁ."],
		[PLAYER, "TU FINAL EN LOS OLIVOS PUSO PUNTO A UN TERROR. NO LO ABRIRÉ DE NUEVO."],
	],
	# --- El siglo XX ---
	&"saddam_hussein": [
		[&"saddam_hussein", "VOLVERÉ A KUWAIT, 1991: LA TORMENTA DEL DESIERTO ME EXPULSÓ EN CIEN HORAS. ESTA VEZ GANARÉ ESA GUERRA."],
		[NEXO, "GÁNALA, SADDAM. DERROTA A QUIEN ME DESAFÍA Y EL DESIERTO SERÁ TUYO."],
		[PLAYER, "ESA GUERRA YA SE DECIDIÓ. NO TE DEJARÉ REHACERLA."],
	],
	&"fidel_castro": [
		[&"fidel_castro", "VOLVERÉ A SANTIAGO DE CUBA, 26 DE JULIO DE 1953: EL ASALTO AL CUARTEL MONCADA FRACASÓ. ESTA VEZ LO TOMARÉ."],
		[NEXO, "TOMA EL CUARTEL, FIDEL. SOLO TE FALTA DERROTAR A QUIEN ME DESAFÍA."],
		[PLAYER, "MONCADA FUE UN FRACASO QUE ABRIÓ LA REVOLUCIÓN. SI LO CAMBIAS, NADA SERÁ COMO FUE."],
	],
	&"augusto_pinochet": [
		[&"augusto_pinochet", "VOLVERÉ A SANTIAGO, 5 DE OCTUBRE DE 1988: PERDÍ EL PLEBISCITO. ESTA VEZ GANARÉ EL SÍ."],
		[NEXO, "GANA ESE PLEBISCITO, AUGUSTO. DERROTA A QUIEN ME DESAFÍA Y EL SÍ SERÁ TUYO."],
		[PLAYER, "CHILE DIJO NO Y LA DEMOCRACIA VOLVIÓ. NO TE DEJARÉ BORRARLO."],
	],
	&"benito_mussolini": [
		[&"benito_mussolini", "VOLVERÉ A ROMA, 25 DE JULIO DE 1943: EL GRAN CONSEJO FASCISTA ME TRAICIONÓ. NO ME DEJARÉ DESTITUIR."],
		[NEXO, "NADIE TE DESTITUIRÁ, BENITO. SOLO DERROTA A QUIEN ME DESAFÍA."],
		[PLAYER, "ESA NOCHE ROMA SE LIBERÓ DE TI. NO VOY A DEVOLVERTE EL BALCÓN."],
	],
	&"joseph_stalin": [
		[&"joseph_stalin", "VOLVERÉ A MOSCÚ, 22 DE JUNIO DE 1941: HITLER ROMPIÓ EL PACTO E INVADIÓ SIN AVISO. ESTA VEZ ESTARÉ PREPARADO."],
		[NEXO, "ESTARÁS PREPARADO, JOSEPH. SOLO DERROTA A QUIEN ME DESAFÍA."],
		[PLAYER, "LO QUE PASÓ ENTONCES COSTÓ MILLONES DE VIDAS Y NO SE BORRA. LA HISTORIA SIGUE COMO ES."],
	],
	&"rasputin": [
		[&"rasputin", "VOLVERÉ A SAN PETERSBURGO, DICIEMBRE DE 1916: EL PRÍNCIPE YUSÚPOV ME TRAICIONÓ EN SU PALACIO. NO BEBERÉ SU VENENO."],
		[NEXO, "NO LO BEBERÁS, GRIGORI. DERROTA A QUIEN ME DESAFÍA Y VOLVERÁS A VIVIR."],
		[PLAYER, "TU MUERTE CAMBIÓ A RUSIA, RASPUTÍN. NO PUEDO DEJAR QUE LA DESHAGAS."],
	],
	# --- Imperios y descubrimientos ---
	&"ivan_el_terrible": [
		[&"ivan_el_terrible", "VOLVERÉ A LIVONIA, 1582: PERDÍ LA GUERRA Y LA PAZ DE YAM ZAPOLSKI ME QUITÓ LO CONQUISTADO. GANARÉ."],
		[NEXO, "LA GANARÁS, IVÁN. PRIMERO DERROTA A QUIEN ME DESAFÍA."],
		[PLAYER, "NO TODO SE CONQUISTA CON MIEDO, IVÁN. NO VOY A DEJAR QUE LO REHAGAS."],
	],
	&"nostradamus": [
		[&"nostradamus", "VOLVERÉ A AGEN, 1534: LA PESTE SE LLEVÓ A MI ESPOSA Y A MIS HIJOS Y NO PUDE CURARLOS. ESTA VEZ LOS SALVARÉ."],
		[NEXO, "TE DEVOLVERÉ A TU FAMILIA, MICHEL. SOLO DERROTA A QUIEN ME DESAFÍA."],
		[PLAYER, "AQUEL DOLOR TE LLEVÓ A ESTUDIAR LA PESTE Y EL FUTURO. NO PUEDO DEJARTE CAMBIARLO."],
	],
	&"nicolas_maquiavelo": [
		[&"nicolas_maquiavelo", "VOLVERÉ A FLORENCIA, 1513: LOS MEDICI ME ENCARCELARON Y ME TORTURARON. ESTA VEZ SERÉ YO QUIEN LOS TRAICIONE."],
		[NEXO, "TRAICIÓNALOS, NICOLÁS. EMPIEZA POR DERROTAR A QUIEN ME DESAFÍA."],
		[PLAYER, "DE ESE CASTIGO Y ESE EXILIO NACIÓ EL PRÍNCIPE. SI LO CAMBIAS, EL LIBRO NO EXISTE."],
	],
	&"cristobal_colon": [
		[&"cristobal_colon", "VOLVERÉ A SANTO DOMINGO, 1500: BOBADILLA ME ENCADENÓ Y ME ENVIÓ PRESO A ESPAÑA. ESTA VEZ CONSERVARÉ MI GOBIERNO."],
		[NEXO, "CONSERVARÁS TU GOBIERNO, CRISTÓBAL. SOLO DERROTA A QUIEN ME DESAFÍA."],
		[PLAYER, "TU VIAJE CAMBIÓ EL MUNDO, PARA BIEN Y PARA MAL. NO PUEDO DEJAR QUE LO REHAGAS."],
	],
	&"gengis_kan": [
		[&"gengis_kan", "VOLVERÉ A LA CAMPAÑA CONTRA LOS XIA, 1227: MORÍ ANTES DE VER LA VICTORIA. ESTA VEZ LA TERMINARÉ."],
		[NEXO, "LA TERMINARÁS, GENGIS. SOLO DERROTA A QUIEN ME DESAFÍA."],
		[PLAYER, "TU IMPERIO CRECIÓ DESPUÉS DE TI. NO PUEDO DEJARTE MODIFICAR ESE DESTINO."],
	],
	# --- La antigüedad ---
	&"cleopatra": [
		[&"cleopatra", "VOLVERÉ A ACCIO, 2 DE SEPTIEMBRE DEL 31 A.C.: OCTAVIANO NOS VENCIÓ A MARCO ANTONIO Y A MÍ. ESTA VEZ GANAREMOS."],
		[NEXO, "GANARÁN, CLEOPATRA. SOLO DERROTA A QUIEN ME DESAFÍA."],
		[PLAYER, "ESA BATALLA ABRIÓ LA ROMA IMPERIAL. NO PUEDO DEJAR QUE LA DESHAGAS."],
	],
	&"alejandro_magno": [
		[&"alejandro_magno", "VOLVERÉ A BABILONIA, 323 A.C.: MORÍ A LOS 32 AÑOS SIN TERMINAR LA CONQUISTA. ESTA VEZ NO MORIRÉ."],
		[NEXO, "NO MORIRÁS, ALEJANDRO. SOLO DERROTA A QUIEN ME DESAFÍA."],
		[PLAYER, "TU IMPERIO SE REPARTIÓ Y NACIÓ EL MUNDO HELENÍSTICO. NO PUEDO DEJARTE CAMBIARLO."],
	],
	# --- El combate final ---
	&"el_nexo": [
		[NEXO, "SOY LA AMBICIÓN DE TODOS ELLOS. TODO LO QUE QUISIERON Y LO QUE RECUERDAN, LO CARGO YO."],
		[NEXO, "SI ME VENCES, CARGARÁS CON ELLOS. ¿PUEDES?"],
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
	var out: Array = []
	for l in SCENES.get(rival, []):
		if l[0] == PLAYER:
			# La respuesta concreta al rival, con voz de héroe o de heroína según el luchador elegido
			# (assets/sounds/story/player/<rival>_m.wav o _f.wav; las genera tools/gen_scene_voice.py).
			var sex := "f" if FighterRegistry.get_by_id(player).female else "m"
			out.append([player, l[1], "res://assets/sounds/story/player/%s_%s.wav" % [rival, sex]])
		else:
			out.append([l[0], l[1]])
	return out
