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
		&"nicolas_maquiavelo", &"moctezuma_ii", &"leonardo_da_vinci", &"cristobal_colon", &"pachacutec",
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
const NEXO_LINES := [
	["EL FRAGMENTO MÁS JOVEN DEL TIEMPO.", "CIÉRRALO O SE ROMPERÁ TODO."],
	["LA GRIETA SIGUE ABIERTA.", "NO DEJES QUE SE LLEVE OTRO SIGLO."],
	["LAS IDEAS QUE ROMPIERON EL TIEMPO", "SIGUEN GIRANDO EN ESTE FRAGMENTO."],
	["CORONAS Y FLOTAS TIRAN DEL TIEMPO", "HACIA DIRECCIONES OPUESTAS."],
	["EL FRAGMENTO MÁS ANTIGUO.", "SI CAE, TODO LO DEMÁS SE DERRUMBA."],
	["SOLO YO SOSTENGO TODAS LAS ÉPOCAS.", "ESTA ES LA PRUEBA FINAL."],
]
## Reacción del Nexo al empezar un capítulo, según las revanchas gastadas hasta ahora.
const NEXO_REACT_FLAWLESS := ["SIN UNA SOLA REVANCHA.", "EL TIEMPO TE RESPETA."]
const NEXO_REACT_WOUNDED := ["HAS CAÍDO, PERO TE LEVANTAS.", "EL TIEMPO TOMA NOTA."]
const NEXO_REACT_WORN := ["TANTAS CAÍDAS... ¿SEGURO", "QUE MERECES EL NEXO?"]
## Frases antes del combate: rival -> [línea 1, línea 2]. Cada una dice qué quiere ese luchador en el
## Nexo (volver a su época, reescribir su destino o quedarse con el poder) y, en los creadores, qué ocultan.
const VS := {
	&"el_nexo": ["SOY LO QUE QUISIERON CONSTRUIR.", "SOY LO QUE RECUERDAN."],
	# Los creadores del Reloj: cada uno revela una pieza de la verdad.
	&"albert_einstein": ["CREADOR DEL RELOJ: SABÍA EL PRECIO.", "LO ENCENDIERON IGUAL."],
	&"nikola_tesla": ["CREADOR DEL RELOJ: DIO LA CORRIENTE", "SIN PREGUNTAR A QUIÉN ALUMBRARÍA."],
	&"marie_curie": ["CREADORA DEL RELOJ: SU LUZ CURA", "Y TAMBIÉN ENFERMA."],
	&"leonardo_da_vinci": ["CREADOR DEL RELOJ: LA IDEA FUE SUYA,", "EN UN CUADERNO."],
	# El mundo actual
	&"kim_jong_un": ["EL NEXO ABRIÓ SU FRONTERA.", "ÉL LA CERRARÁ A PUÑOS."],
	&"nicolas_maduro": ["CREE QUE ESTO ES OTRO SHOW.", "BAILA... PERO NO TE CONFÍES."],
	&"osama_bin_laden": ["SE ESCONDE PARA NO SER JUZGADO.", "EL NEXO YA LO ENCONTRÓ."],
	&"xi_jinping": ["ESPERA A QUE FALLES.", "LA PACIENCIA TAMBIÉN ES PODER."],
	&"vladimir_putin": ["LO QUE TOMA, NO LO DEVUELVE.", "TAMPOCO EL PODER DEL NEXO."],
	&"pablo_escobar": ["QUIERE COMPRAR EL NEXO.", "PLATA O PLOMO."],
	&"papa_francisco": ["PELEA PARA DETENER LA PELEA.", "AUN ASÍ, GOLPEA."],
	&"isabel_ii": ["QUIERE QUE TODO SIGA IGUAL.", "EL TIEMPO ROTO NO LA DESPEINA."],
	&"donald_trump": ["QUIERE LA CABECERA DEL NEXO.", "SIEMPRE QUIERE LA ÚLTIMA PALABRA."],
	# El siglo XX
	&"saddam_hussein": ["SU TRONO ERA ARENA.", "QUIERE UNO QUE DURE."],
	&"fidel_castro": ["QUIERE OTRO FINAL PARA SU ISLA.", "NO SE RINDE SIN PELEAR."],
	&"liudmila_pavlichenko": ["309 BAJAS Y UN SOLO DEBER:", "VOLVER A CASA."],
	&"augusto_pinochet": ["QUIERE BORRAR EL 73.", "EL TIEMPO NO SE BORRA."],
	&"salvador_allende": ["QUIERE OTRO FINAL PARA LA MONEDA.", "AQUÍ PELEA DE PIE."],
	&"mariya_oktyabrskaya": ["VENDIÓ TODO PARA COMPRAR UN TANQUE.", "NO PIENSA PERDERLO."],
	&"benito_mussolini": ["NO ACEPTA SU FINAL.", "EL BALCÓN LO ESPERA OTRA VEZ."],
	&"joseph_stalin": ["EL ACERO NO CEDE,", "NI SIQUIERA ANTE EL NEXO."],
	&"rasputin": ["NO PUEDE MORIR Y LO SABE.", "AHORA QUIERE SABER POR QUÉ."],
	&"adolf_hitler": ["SU IMPERIO DEBÍA DURAR MIL AÑOS.", "DURÓ DOCE. NO LO ACEPTA."],
	# Revoluciones y progreso
	&"arturo_prat": ["QUIERE OTRO ABORDAJE,", "UNO QUE NO CUESTE SU VIDA."],
	&"abraham_lincoln": ["QUIERE VER LA UNIÓN SANA.", "SU HACHA YA ESTÁ LISTA."],
	&"charles_darwin": ["QUIERE COMPROBAR QUIÉN SE ADAPTA.", "A VER SI ERES TÚ."],
	&"napoleon": ["CORONÓ SU PROPIO IMPERIO.", "QUIERE VOLVER A WATERLOO Y GANAR."],
	# Imperios y descubrimientos
	&"isaac_newton": ["QUIERE MEDIR LA GRIETA DEL TIEMPO.", "LA GRAVEDAD TIENE SU NOMBRE."],
	&"janequeo": ["LA TOQUI DEL SUR.", "DEFIENDE SU TIERRA DE TODOS."],
	&"galileo_galilei": ["QUIERE QUE POR FIN LE CREAN.", "LA TIERRA SE MUEVE. ÉL TAMBIÉN."],
	&"lautaro": ["EL TOQUI QUE ENSEÑÓ A VENCER.", "DEFIENDE LO SUYO."],
	&"ivan_el_terrible": ["GOBIERNA POR MIEDO.", "QUIERE QUE EL TIEMPO LO TEMA."],
	&"nicolas_maquiavelo": ["EL FIN JUSTIFICA LOS MEDIOS.", "TODOS, INCLUIDO EL NEXO."],
	&"moctezuma_ii": ["QUIERE EVITAR LA CAÍDA", "DE TENOCHTITLAN."],
	&"cristobal_colon": ["BUSCA UNA RUTA FUERA DE ESTE CAOS.", "CRUZÓ EL OCÉANO; CRUZARÁ EL TIEMPO."],
	&"pachacutec": ["QUIERE RECONSTRUIR SU IMPERIO.", "EL TAHUANTINSUYO NO CAE."],
	&"juana_de_arco": ["QUIERE EVITAR LA HOGUERA.", "LAS VOCES AHORA GRITAN MÁS."],
	&"gengis_kan": ["CRUZÓ MEDIO MUNDO A CABALLO.", "QUIERE CRUZAR EL TIEMPO."],
	&"hernan_cortes": ["QUIERE CONQUISTAR EL NEXO", "COMO CONQUISTÓ UN IMPERIO."],
	# La antigüedad
	&"boudica": ["QUIERE VENGAR A SU PUEBLO.", "ROMA TEMBLÓ ANTE ELLA."],
	&"jesus_de_nazaret": ["VINO A PERDONARTE.", "SU VARA TAMBIÉN GOLPEA."],
	&"cleopatra": ["QUIERE OTRO FINAL PARA EGIPTO.", "SU ASTUCIA AFILA SU DAGA."],
	&"alejandro_magno": ["MURIÓ A LOS 32 SIN PERDER.", "QUIERE VIVIR PARA SEGUIR."],
	&"aristoteles": ["BUSCA LA VERDAD DEL TIEMPO.", "SU LÓGICA ES IMPLACABLE."],
	&"platon": ["BUSCA EL MUNDO DE LAS IDEAS.", "SU REPÚBLICA ES IMBATIBLE."],
	&"socrates": ["SOLO SÉ QUE NO SÉ NADA.", "PERO PEGA MUY FUERTE."],
	&"sun_tzu": ["QUIERE GANAR SIN LUCHAR.", "TÚ LO ESTÁS HACIENDO MAL."],
	&"confucio": ["PIDE ORDEN EN ESTE CAOS.", "PRIMERO EL ORDEN, DESPUÉS EL GOLPE."],
	&"buda": ["NO DESEA NADA, NI EL NEXO.", "LA PAZ INTERIOR TAMBIÉN GOLPEA."],
	&"julio_cesar": ["QUIERE CRUZAR OTRA VEZ EL RUBICÓN.", "LLEGÓ, VIO... Y VENCERÁ."],
}
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
	"albert_einstein|marie_curie": ["LA ECUACIÓN Y LA LUZ.", "LOS DOS PAGARON SU PRECIO."],
	"albert_einstein|leonardo_da_vinci": ["LA IDEA Y EL CÁLCULO.", "UN RELOJ, DOS CULPAS."],
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
	&"albert_einstein": "NO REPITAN NUESTRO ERROR.",
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
	&"nicolas_maquiavelo": "HICISTE LO QUE HABÍA QUE HACER.",
	&"moctezuma_ii": "ESTA VEZ, QUE TENOCHTITLAN SE SALVE.",
	&"leonardo_da_vinci": "HAY PLANOS QUE NO DEBEN DIBUJARSE.",
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
