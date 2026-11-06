## Contenido narrativo del modo Historia: las épocas, sus jefes, los creadores del Reloj y las frases
## del Nexo y de cada combate. Son solo datos; la partida en curso (escalera, revanchas, guardado) está en
## Game, que mantiene los nombres STORY_* como atajos a estas constantes.
class_name StoryCampaign
extends RefCounted

const NEXO_NAME := "EL JUICIO DEL NEXO"
## Épocas (fragmentos del tiempo roto) del más reciente al más antiguo: [nombre, [luchadores]]. Aquí solo están los
## RIVALES: villanos, dictadores y ambiciosos, más el creador del Reloj poseído que cierra cada época. Dentro de cada
## una se ordenan por año; el jefe (BOSSES) va el último de los rivales y el creador poseído, después de él.
const CHAPTERS := [
	["EL MUNDO ACTUAL", [&"kim_jong_un", &"nicolas_maduro", &"osama_bin_laden", &"vladimir_putin", &"pablo_escobar",
		&"donald_trump", &"marie_curie"]],
	["EL SIGLO XX", [&"saddam_hussein", &"fidel_castro", &"augusto_pinochet", &"benito_mussolini", &"joseph_stalin",
		&"rasputin", &"adolf_hitler", &"albert_einstein"]],
	["REVOLUCIONES, IMPERIOS Y DESCUBRIMIENTOS", [&"ivan_el_terrible", &"nostradamus", &"hernan_cortes",
		&"nicolas_maquiavelo", &"cristobal_colon", &"napoleon", &"nikola_tesla"]],
	["LA ANTIGÜEDAD Y LA EDAD MEDIA", [&"gengis_kan", &"cleopatra", &"alejandro_magno", &"julio_cesar",
		&"leonardo_da_vinci"]],
]
## Los buenos y justos: solo se pueden elegir (no son rivales) y están disponibles desde el principio.
const PLAYABLE_ONLY: Array[StringName] = [
	&"socrates", &"platon", &"aristoteles", &"confucio", &"sun_tzu", &"buda", &"jesus_de_nazaret", &"boudica",
	&"juana_de_arco", &"lautaro", &"janequeo", &"galileo_galilei", &"pachacutec", &"moctezuma_ii",
	&"isaac_newton", &"charles_darwin", &"abraham_lincoln", &"arturo_prat",
	&"salvador_allende", &"liudmila_pavlichenko", &"mariya_oktyabrskaya", &"papa_francisco", &"isabel_ii", &"xi_jinping",
]
## Jefe de cada época (índice -> luchador), el más controvertido de su tiempo; va al final de los rivales.
const BOSSES := {0: &"donald_trump", 1: &"adolf_hitler", 2: &"napoleon", 3: &"julio_cesar"}
## Los cuatro creadores del Reloj del Origen: al vencer al jefe de cada época, el Nexo posee a uno y pelea en la
## misma batalla. Al vencerlo queda libre (y se desbloquea).
const CREATORS: Array[StringName] = [&"nikola_tesla", &"albert_einstein", &"marie_curie", &"leonardo_da_vinci"]
## Lo que está en juego en cada fragmento del tiempo (la animación de la época ya trae la voz del Nexo).
## Todos los luchadores quieren volver a su época a corregir su derrota; el jugador debe impedirlo.
const NEXO_LINES := [
	["LOS VIVOS QUIEREN MÁS PODER; LOS MUERTOS,", "VOLVER A GANAR. DETENLOS A TODOS."],
	["LA GRIETA SIGUE ABIERTA. LOS EJÉRCITOS", "AVANZAN SOBRE LAS CIUDADES."],
	["CORONAS, FLOTAS Y REVOLUCIONES", "QUIEREN REESCRIBIR SU DERROTA."],
	["EL FRENTE MÁS ANTIGUO. SI SE", "REESCRIBE, TODO LO DEMÁS SE DERRUMBA."],
	["SOLO YO SOSTENGO TODAS LAS ÉPOCAS.", "ESTA ES LA PRUEBA FINAL."],
]
## Reacción del Nexo al empezar un capítulo, según las revanchas gastadas hasta ahora.
const NEXO_REACT_FLAWLESS := ["SIN UNA SOLA REVANCHA.", "EL TIEMPO TE RESPETA."]
const NEXO_REACT_WOUNDED := ["HAS CAÍDO, PERO TE LEVANTAS.", "EL TIEMPO TOMA NOTA."]
const NEXO_REACT_WORN := ["TANTAS CAÍDAS... ¿SEGURO", "QUE MERECES EL NEXO?"]
## Consejos de los creadores del Reloj cuando el jugador pierde: cada uno liga su ciencia con una
## técnica del combate. [creador, [consejos]]; se reparten según las revanchas gastadas.
const DEFEAT_TIPS := [
	[&"albert_einstein", [
		"Guarda 100 de energía y lanza el ultimate (Especial 1 y 2) en el momento justo.",
		"Todo es relativo al momento: tras bloquear, el rival queda en desventaja. Castígalo.",
		"Un salto no se corrige en el aire: si salta, agáchate y usa S + I (antiaéreo).",
	]],
	[&"nikola_tesla", [
		"La corriente alterna oscila: alterna golpes débiles y fuertes para romper su ritmo.",
		"La resonancia amplifica: encadena golpes débiles para cargar energía y lanza un especial.",
		"Sin carga un circuito no sirve: no gastes el especial sin energía (25 y 40).",
	]],
	[&"marie_curie", [
		"La radiación decae con la distancia: haz un backdash (doble toque atrás) y contraataca.",
		"Mide antes de actuar: observa dos o tres ataques y verás cuándo baja la defensa.",
		"El radio tiene vida media: no gastes toda tu energía de golpe, regúlala.",
	]],
	[&"leonardo_da_vinci", [
		"La anatomía manda: un barrido bajo (S + J o K) derriba a quien está de pie.",
		"Estudia antes de construir: mira su especial y esquívalo con un backdash.",
		"Observa: el rival repite sus ataques. Espera el golpe, bloquea y responde.",
	]],
]
## Lo que dice el rival vencido (se muestra en los resultados): su último aliento antes de volver al tiempo roto.
const FAREWELL := {
	&"kim_jong_un": "QUE NO ABRAN MI PAÍS, PROMÉTELO.",
	&"nicolas_maduro": "SE ACABÓ EL SHOW... POR HOY.",
	&"osama_bin_laden": "AL FIN ALGUIEN ME ENCONTRÓ.",
	&"xi_jinping": "LA PACIENCIA TAMBIÉN SE AGOTA.",
	&"vladimir_putin": "TOMA EL PODER... PERO NO LO SUELTES.",
	&"pablo_escobar": "ESTO NO SE COMPRA, YA LO VEO.",
	&"papa_francisco": "QUE ESTA PELEA SIRVA DE ALGO.",
	&"isabel_ii": "QUE EL TIEMPO TE TRATE BIEN.",
	&"donald_trump": "LA CABECERA ERA MÍA... ¿O NO?",
	&"saddam_hussein": "EL DESIERTO SE TRAGA TODOS LOS TRONOS.",
	&"fidel_castro": "OTRA ISLA, OTRO FINAL. SUERTE.",
	&"liudmila_pavlichenko": "DILE A CASA QUE CUMPLÍ.",
	&"augusto_pinochet": "NO PUDE BORRAR NADA.",
	&"salvador_allende": "ESTA VEZ CAÍ DE PIE. GRACIAS.",
	&"mariya_oktyabrskaya": "CUIDA MI TANQUE, CAMARADA.",
	&"benito_mussolini": "EL BALCÓN SE QUEDÓ VACÍO.",
	&"joseph_stalin": "EL ACERO TAMBIÉN SE DOBLA.",
	&"rasputin": "NI ASÍ MORIRÉ... PERO DUELE.",
	&"albert_einstein": "ME HAS SOLTADO. LA ECUACIÓN YA NO ES SUYA.",
	&"adolf_hitler": "DOCE AÑOS... Y NI UNO MÁS.",
	&"arturo_prat": "SIGUE NAVEGANDO. YO YA ABORDÉ.",
	&"abraham_lincoln": "QUE LA UNIÓN NO SE ROMPA OTRA VEZ.",
	&"charles_darwin": "ERES EL MÁS ADAPTADO. POR AHORA.",
	&"nikola_tesla": "MI CORRIENTE VUELVE A SER MÍA. APAGA SU LUZ.",
	&"marie_curie": "LA ENERGÍA ES MÍA OTRA VEZ. LLÉVALA CONTIGO.",
	&"napoleon": "WATERLOO SE REPITE... SIEMPRE.",
	&"isaac_newton": "MIDE BIEN LA GRIETA ANTES DE CERRARLA.",
	&"janequeo": "MI TIERRA QUEDA EN TUS MANOS.",
	&"galileo_galilei": "¿VES? SE MUEVE.",
	&"lautaro": "QUE TU CABALLO ALCANCE AL NEXO.",
	&"ivan_el_terrible": "EL MIEDO NO ALCANZÓ. APRÉNDELO.",
	&"nostradamus": "ESTO TAMBIÉN ESTABA ESCRITO.",
	&"nicolas_maquiavelo": "HICISTE LO QUE HABÍA QUE HACER.",
	&"moctezuma_ii": "ESTA VEZ, QUE TENOCHTITLAN SE SALVE.",
	&"leonardo_da_vinci": "LIBRE. TODO MECANISMO TIENE UN PUNTO DÉBIL.",
	&"cristobal_colon": "HAY RUTAS QUE NO TIENEN VUELTA.",
	&"pachacutec": "QUE EL IMPERIO VIVA EN TU MEMORIA.",
	&"juana_de_arco": "LAS VOCES DICEN QUE SIGAS.",
	&"gengis_kan": "TAMBIÉN EL TIEMPO SE PUEDE CRUZAR.",
	&"hernan_cortes": "AUDACIA Y ACERO... ME GANASTE LA PARTIDA.",
	&"boudica": "QUE ROMA RECUERDE MI NOMBRE.",
	&"jesus_de_nazaret": "TE PERDONO. SIGUE ADELANTE.",
	&"cleopatra": "EGIPTO MERECE UN MEJOR FINAL.",
	&"alejandro_magno": "AÚN QUEDAN MUNDOS POR CONQUISTAR.",
	&"aristoteles": "LA LÓGICA TAMBIÉN TIENE LÍMITES.",
	&"platon": "LA IDEA DE TU VICTORIA ERA PERFECTA.",
	&"socrates": "AHORA SÉ ALGO: PEGAS MUY FUERTE.",
	&"sun_tzu": "GANASTE LUCHANDO. NO ES LO MÍO.",
	&"confucio": "EL ORDEN TAMBIÉN CAE.",
	&"buda": "NO DESEO NADA... SALVO TU PAZ.",
	&"julio_cesar": "LOS IDUS ME LLAMAN... OTRA VEZ.",
}
## Lo que dice el Nexo al cambiar de fase en su combate (fase II y fase III): su origen, poco a poco.
const NEXO_PHASE_LINES := [
	["SOY LA AMBICIÓN DE QUIENES", "ME CONSTRUYERON."],
	["SOY LA MEMORIA Y EL ARREPENTIMIENTO", "DE TODAS LAS ÉPOCAS. ¿PUEDES CARGARLOS?"],
]
