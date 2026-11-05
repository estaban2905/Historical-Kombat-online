## Contenido narrativo del modo Historia: las épocas, sus jefes, los creadores del Reloj y las frases
## del Nexo y de cada combate. Son solo datos; la partida en curso (escalera, revanchas, guardado) está en
## Game, que mantiene los nombres STORY_* como atajos a estas constantes.
class_name StoryCampaign
extends RefCounted

const NEXO_NAME := "EL JUICIO DEL NEXO"
## Épocas (fragmentos del tiempo roto) del más reciente al más antiguo: [nombre, [luchadores]]. Cada una cierra con
## su jefe (STORY_BOSSES) y dentro de la época se ordenan por año.
const CHAPTERS := [
	["EL MUNDO ACTUAL", [&"kim_jong_un", &"nicolas_maduro", &"osama_bin_laden", &"xi_jinping", &"vladimir_putin",
		&"pablo_escobar", &"papa_francisco", &"isabel_ii", &"donald_trump"]],
	["EL SIGLO XX", [&"saddam_hussein", &"fidel_castro", &"liudmila_pavlichenko", &"augusto_pinochet",
		&"salvador_allende", &"mariya_oktyabrskaya", &"benito_mussolini", &"joseph_stalin", &"rasputin",
		&"albert_einstein", &"adolf_hitler"]],
	["REVOLUCIONES Y PROGRESO", [&"arturo_prat", &"abraham_lincoln", &"charles_darwin", &"nikola_tesla",
		&"marie_curie", &"napoleon"]],
	["IMPERIOS Y DESCUBRIMIENTOS", [&"isaac_newton", &"janequeo", &"galileo_galilei", &"lautaro", &"ivan_el_terrible",
		&"nicolas_maquiavelo", &"nostradamus", &"moctezuma_ii", &"leonardo_da_vinci", &"cristobal_colon", &"pachacutec",
		&"juana_de_arco", &"gengis_kan", &"hernan_cortes"]],
	["LA ANTIGÜEDAD", [&"boudica", &"jesus_de_nazaret", &"cleopatra", &"alejandro_magno", &"aristoteles", &"platon",
		&"socrates", &"sun_tzu", &"confucio", &"buda", &"julio_cesar"]],
]
## Jefe de cada época (índice -> luchador), el más controvertido de su tiempo; va al final.
const BOSSES := {0: &"donald_trump", 1: &"adolf_hitler", 2: &"napoleon", 3: &"hernan_cortes",
	4: &"julio_cesar"}
## Los cuatro creadores del Reloj del Origen, repartidos por las épocas.
const CREATORS: Array[StringName] = [&"nikola_tesla", &"albert_einstein", &"marie_curie", &"leonardo_da_vinci"]
## Lo que está en juego en cada fragmento del tiempo (la animación de la época ya trae la voz del Nexo).
## Todos los luchadores quieren volver a su época a corregir su derrota; el jugador debe impedirlo.
const NEXO_LINES := [
	["TODOS QUIEREN VOLVER A SU ÉPOCA", "A CORREGIR SU DERROTA. DETENLOS."],
	["LA GRIETA SIGUE ABIERTA. CADA UNO", "QUIERE REESCRIBIR SU HISTORIA."],
	["LOS INVENTOS Y LAS REVOLUCIONES", "QUIEREN CAMBIAR SU FINAL. IMPÍDELO."],
	["CORONAS Y FLOTAS QUIEREN VOLVER", "Y GANAR LO QUE PERDIERON."],
	["EL FRAGMENTO MÁS ANTIGUO. SI SE", "REESCRIBE, TODO LO DEMÁS SE DERRUMBA."],
	["SOLO YO SOSTENGO TODAS LAS ÉPOCAS.", "ESTA ES LA PRUEBA FINAL."],
]
## Reacción del Nexo al empezar un capítulo, según las revanchas gastadas hasta ahora.
const NEXO_REACT_FLAWLESS := ["SIN UNA SOLA REVANCHA.", "EL TIEMPO TE RESPETA."]
const NEXO_REACT_WOUNDED := ["HAS CAÍDO, PERO TE LEVANTAS.", "EL TIEMPO TOMA NOTA."]
const NEXO_REACT_WORN := ["TANTAS CAÍDAS... ¿SEGURO", "QUE MERECES EL NEXO?"]
## Frases antes del combate: rival -> [línea 1, línea 2]. Cada luchador quiere volver a su época para
## reescribir su historia y ganar la batalla que perdió; el jugador debe impedirlo. Los creadores del Reloj
## solo aportaron sus conocimientos científicos.
const VS := {
	&"el_nexo": ["SOY LO QUE QUISIERON CONSTRUIR.", "SOY LO QUE RECUERDAN."],
	# Los creadores del Reloj: científicos que aportaron lo que sabían.
	&"albert_einstein": ["CREADOR DEL RELOJ: APORTÓ LA RELATIVIDAD.", "PARA ÉL EL TIEMPO SE ESTIRA Y SE CURVA."],
	&"nikola_tesla": ["CREADOR DEL RELOJ: APORTÓ LA CORRIENTE", "ALTERNA Y LA RESONANCIA."],
	&"marie_curie": ["CREADORA DEL RELOJ: APORTÓ LA RADIACTIVIDAD", "Y LA MEDIDA DE LA VIDA MEDIA."],
	&"leonardo_da_vinci": ["CREADOR DEL RELOJ: APORTÓ EL DISEÑO,", "ENGRANAJE POR ENGRANAJE."],
	# El mundo actual
	&"kim_jong_un": ["QUIERE REESCRIBIR LA HISTORIA", "Y CERRAR EL TIEMPO COMO SU FRONTERA."],
	&"nicolas_maduro": ["QUIERE REESCRIBIR SU HISTORIA", "A PUNTA DE BAILE Y AGUANTE."],
	&"osama_bin_laden": ["QUIERE VOLVER A 2011 Y ESCAPAR", "DE QUIEN LO ENCONTRÓ."],
	&"xi_jinping": ["QUIERE REESCRIBIR EL TIEMPO", "A SU RITMO: LENTO Y SEGURO."],
	&"vladimir_putin": ["QUIERE VOLVER A 1991 Y EVITAR", "QUE LA UNIÓN SOVIÉTICA SE DISUELVA."],
	&"pablo_escobar": ["QUIERE VOLVER A 1993 Y ESCAPAR", "DE MEDELLÍN. ESTA VEZ, GANA."],
	&"papa_francisco": ["QUIERE REESCRIBIR LA HISTORIA PARA", "QUE NO HAYA MÁS GUERRAS."],
	&"isabel_ii": ["QUIERE VOLVER A 1952 Y REINAR", "OTRA VEZ SIN QUE NADA CAMBIE."],
	&"donald_trump": ["QUIERE VOLVER A 2020 Y GANAR", "LA ELECCIÓN QUE PERDIÓ."],
	# El siglo XX
	&"saddam_hussein": ["QUIERE VOLVER A 1991 Y GANAR", "LA GUERRA DEL GOLFO."],
	&"fidel_castro": ["QUIERE REESCRIBIR SU ISLA:", "QUE EL BLOQUEO NO EXISTA."],
	&"liudmila_pavlichenko": ["QUIERE VOLVER A 1942 Y SALVAR", "A SUS COMPAÑEROS CAÍDOS."],
	&"augusto_pinochet": ["QUIERE VOLVER A 1988 Y GANAR", "EL PLEBISCITO QUE PERDIÓ."],
	&"salvador_allende": ["QUIERE VOLVER AL 11 DE SEPTIEMBRE", "DE 1973 Y GANAR EN LA MONEDA."],
	&"mariya_oktyabrskaya": ["QUIERE VOLVER A 1944 Y EVITAR", "LA BATALLA EN LA QUE CAYÓ."],
	&"benito_mussolini": ["QUIERE VOLVER A 1943 Y GANAR", "LA GUERRA QUE PERDIÓ."],
	&"joseph_stalin": ["QUIERE REESCRIBIR 1941 Y QUE", "NADIE LO SORPRENDA OTRA VEZ."],
	&"rasputin": ["QUIERE VOLVER A DICIEMBRE DE 1916", "Y SOBREVIVIR POR FIN."],
	&"adolf_hitler": ["QUIERE VOLVER A 1945 Y GANAR", "LA GUERRA QUE PERDIÓ. NO PUEDE."],
	# Revoluciones y progreso
	&"arturo_prat": ["QUIERE VOLVER A IQUIQUE, 1879,", "Y GANAR SIN PERDER LA VIDA."],
	&"abraham_lincoln": ["QUIERE VOLVER A 1865 Y EVITAR", "LA NOCHE DEL TEATRO FORD."],
	&"charles_darwin": ["QUIERE REESCRIBIR SU HISTORIA", "Y COMPROBAR QUIÉN SE ADAPTA."],
	&"napoleon": ["QUIERE VOLVER A WATERLOO, 1815,", "Y GANAR LA BATALLA QUE PERDIÓ."],
	# Imperios y descubrimientos
	&"isaac_newton": ["QUIERE VOLVER A 1720 Y NO PERDER", "SU FORTUNA EN LA BURBUJA."],
	&"janequeo": ["QUIERE VOLVER AL SUR Y EVITAR", "LA MUERTE DE SU ESPOSO EN LA GUERRA."],
	&"galileo_galilei": ["QUIERE VOLVER A 1633 Y GANAR", "EL JUICIO QUE LO CALLÓ."],
	&"lautaro": ["QUIERE VOLVER A MATAQUITO, 1557,", "Y NO CAER EN LA EMBOSCADA."],
	&"ivan_el_terrible": ["QUIERE VOLVER A 1582 Y GANAR", "LA GUERRA DE LIVONIA QUE PERDIÓ."],
	&"nostradamus": ["QUIERE VOLVER A SU ÉPOCA Y ACERTAR", "LA PROFECÍA QUE FALLÓ."],
	&"nicolas_maquiavelo": ["QUIERE VOLVER A 1512 Y EVITAR QUE", "LOS MEDICI LO ENCARCELEN."],
	&"moctezuma_ii": ["QUIERE VOLVER A 1519 Y NO DEJAR", "ENTRAR A CORTÉS EN TENOCHTITLAN."],
	&"cristobal_colon": ["QUIERE VOLVER A 1500 Y EVITAR", "CAER EN DESGRACIA ENCADENADO."],
	&"pachacutec": ["QUIERE VOLVER A SU ÉPOCA Y EVITAR", "LA CAÍDA FUTURA DEL TAHUANTINSUYO."],
	&"juana_de_arco": ["QUIERE VOLVER A 1431 Y EVITAR", "LA HOGUERA DE ROUEN."],
	&"gengis_kan": ["QUIERE VOLVER A 1227 Y CABALGAR", "SIN MORIR ANTES DE TERMINAR."],
	&"hernan_cortes": ["QUIERE VOLVER A 1520 Y GANAR", "LA NOCHE TRISTE QUE PERDIÓ."],
	# La antigüedad
	&"boudica": ["QUIERE VOLVER AL AÑO 60 Y GANAR", "LA BATALLA CONTRA ROMA."],
	&"jesus_de_nazaret": ["QUIERE VOLVER A SU ÉPOCA A DEFENDER", "A LOS SUYOS. SU VARA TAMBIÉN GOLPEA."],
	&"cleopatra": ["QUIERE VOLVER A ACCIO, 31 A.C., Y GANAR", "LA BATALLA QUE PERDIÓ."],
	&"alejandro_magno": ["QUIERE VOLVER A BABILONIA, 323 A.C.,", "Y NO MORIR A LOS 32."],
	&"aristoteles": ["QUIERE VOLVER A 323 A.C. Y EVITAR", "EL EXILIO DE ATENAS."],
	&"platon": ["QUIERE VOLVER A SIRACUSA Y CONVERTIR", "A UN REY EN FILÓSOFO."],
	&"socrates": ["QUIERE VOLVER AL JUICIO DE 399 A.C.", "Y GANAR SU DEFENSA."],
	&"sun_tzu": ["QUIERE REESCRIBIR SU HISTORIA", "Y GANAR SIN LUCHAR... CASI."],
	&"confucio": ["QUIERE VOLVER A SU ÉPOCA Y LOGRAR", "QUE UN REY ESCUCHE SU DOCTRINA."],
	&"buda": ["QUIERE VOLVER A SU ÉPOCA SIN DESEO,", "Y AUN ASÍ TE DETENDRÁ."],
	&"julio_cesar": ["QUIERE VOLVER A LOS IDUS DE MARZO", "DEL 44 A.C. Y EVITAR LAS PUÑALADAS."],
}
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
## Frases cuando se enfrentan dos luchadores concretos, en cualquier orden: "id|id" -> líneas.
const VS_PAIR := {
	"salvador_allende|augusto_pinochet": ["LA MONEDA, 1973.", "AHORA SE DECIDE DE OTRO MODO."],
	"hernan_cortes|moctezuma_ii": ["DOS MUNDOS SE ENCUENTRAN", "EN TENOCHTITLAN."],
	"cristobal_colon|lautaro": ["EL DESCUBRIDOR Y EL TOQUI", "SE VEN LAS CARAS."],
	"cristobal_colon|hernan_cortes": ["DEL MISMO OCÉANO,", "DOS CONQUISTAS."],
	"napoleon|juana_de_arco": ["UN EMPERADOR Y UNA SANTA.", "TRES SIGLOS Y MEDIO ENTRE ELLOS."],
	"napoleon|julio_cesar": ["DOS EMPERADORES, DOS CORONAS,", "UN SOLO TIEMPO."],
	"adolf_hitler|napoleon": ["EL INVIERNO RUSO VENCIÓ", "A LOS DOS."],
	"abraham_lincoln|charles_darwin": ["NACIERON EL MISMO DÍA.", "SOLO UNO SE QUEDA EN PIE."],
	"socrates|platon": ["MAESTRO Y DISCÍPULO.", "LA LECCIÓN SE DA A GOLPES."],
	"platon|aristoteles": ["EL DISCÍPULO CONTRA", "SU MAYOR RIVAL DE IDEAS."],
	"socrates|aristoteles": ["TRES SABIOS, UNA IDEA:", "EL MÁS FUERTE ENSEÑA."],
	"julio_cesar|cleopatra": ["ROMA Y EGIPTO,", "OTRA VEZ ENFRENTADAS."],
	"alejandro_magno|aristoteles": ["EL ALUMNO DEBE LA CLASE", "A SU MAESTRO."],
	"alejandro_magno|gengis_kan": ["DOS CONQUISTADORES.", "AL TIEMPO LE SOBRA UNO."],
	"juana_de_arco|boudica": ["DOS MUJERES AL MANDO", "DE EJÉRCITOS. SOLO UNA GANA."],
	"sun_tzu|confucio": ["DOS MAESTROS DE CHINA:", "LA GUERRA Y EL ORDEN."],
	"papa_francisco|jesus_de_nazaret": ["EL PASTOR Y SU MAESTRO.", "EL PERDÓN NO EVITA EL GOLPE."],
	"isaac_newton|galileo_galilei": ["NEWTON NACIÓ EL AÑO", "EN QUE MURIÓ GALILEO."],
	"adolf_hitler|joseph_stalin": ["DOS TIRANOS, UN PACTO", "ROTO. FUEGO CRUZADO."],
	"adolf_hitler|benito_mussolini": ["EL EJE SE QUIEBRA.", "NO HAY ALIADOS EN EL NEXO."],
	"liudmila_pavlichenko|adolf_hitler": ["LADY DEATH ENFRENTA", "AL HOMBRE DE LA GUERRA."],
	"fidel_castro|donald_trump": ["MEDIO SIGLO DE ENEMISTAD.", "SALDADA EN UN RING."],
	"nikola_tesla|albert_einstein": ["DOS MENTES, UNA MÁQUINA.", "AHORA, UN SOLO GANADOR."],
	"marie_curie|nikola_tesla": ["LUZ CONTRA CORRIENTE.", "EL RELOJ LOS UNIÓ."],
	"albert_einstein|marie_curie": ["LA ECUACIÓN Y LA LUZ.", "DOS CIENCIAS, UNA MISMA MÁQUINA."],
	"albert_einstein|leonardo_da_vinci": ["LA TEORÍA Y EL DISEÑO.", "UN RELOJ, DOS APORTES."],
	"nikola_tesla|leonardo_da_vinci": ["EL INVENTOR Y SU MAESTRO.", "LA MÁQUINA NACIÓ DE LOS DOS."],
}
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
	&"albert_einstein": "USEN LA CIENCIA CON CUIDADO.",
	&"adolf_hitler": "DOCE AÑOS... Y NI UNO MÁS.",
	&"arturo_prat": "SIGUE NAVEGANDO. YO YA ABORDÉ.",
	&"abraham_lincoln": "QUE LA UNIÓN NO SE ROMPA OTRA VEZ.",
	&"charles_darwin": "ERES EL MÁS ADAPTADO. POR AHORA.",
	&"nikola_tesla": "ALUMBRA A TODOS, NO SOLO A UNOS.",
	&"marie_curie": "CUIDA LA LUZ O TE CONSUMIRÁ.",
	&"napoleon": "WATERLOO SE REPITE... SIEMPRE.",
	&"isaac_newton": "MIDE BIEN LA GRIETA ANTES DE CERRARLA.",
	&"janequeo": "MI TIERRA QUEDA EN TUS MANOS.",
	&"galileo_galilei": "¿VES? SE MUEVE.",
	&"lautaro": "QUE TU CABALLO ALCANCE AL NEXO.",
	&"ivan_el_terrible": "EL MIEDO NO ALCANZÓ. APRÉNDELO.",
	&"nostradamus": "ESTO TAMBIÉN ESTABA ESCRITO.",
	&"nicolas_maquiavelo": "HICISTE LO QUE HABÍA QUE HACER.",
	&"moctezuma_ii": "ESTA VEZ, QUE TENOCHTITLAN SE SALVE.",
	&"leonardo_da_vinci": "OBSERVA, MIDE Y SOLO ENTONCES CONSTRUYE.",
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
	["SOY LA MEMORIA DE TODAS LAS ÉPOCAS.", "¿PUEDES CARGARLA?"],
]
