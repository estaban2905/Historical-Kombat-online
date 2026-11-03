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
## Frases antes del combate: rival -> [línea 1, línea 2].
const VS := {
	&"el_nexo": ["EL PODER QUE SOSTIENE", "TODAS LAS ÉPOCAS."],
	&"albert_einstein": ["CREADOR DEL RELOJ: LO CONSTRUYÓ", "Y TEME SU PRECIO."],
	&"leonardo_da_vinci": ["CREADOR DEL RELOJ: DISEÑÓ", "EL MECANISMO DEL ORIGEN."],
	&"nikola_tesla": ["CREADOR DEL RELOJ: SU", "CORRIENTE ALIMENTÓ LA MÁQUINA."],
	&"marie_curie": ["CREADORA DEL RELOJ: SU", "LUZ ENCENDIÓ EL NÚCLEO."],
	&"salvador_allende": ["CAYÓ EN LA MONEDA.", "AQUÍ PELEA DE PIE."],
	&"augusto_pinochet": ["SE LLEVÓ EL PODER A LA FUERZA.", "AQUÍ NO HAY CUARTEL."],
	&"moctezuma_ii": ["SU IMPERIO CAYÓ ANTE", "UN PUÑADO DE ESPADAS."],
	&"hernan_cortes": ["CONQUISTÓ UN IMPERIO", "CON AUDACIA Y ACERO."],
	&"cristobal_colon": ["CRUZÓ EL OCÉANO", "Y CAMBIÓ EL MAPA."],
	&"lautaro": ["EL TOQUI QUE ENSEÑÓ", "A VENCER A CABALLO."],
	&"juana_de_arco": ["OYÓ VOCES Y LIDERÓ", "UN EJÉRCITO."],
	&"napoleon": ["CORONÓ SU PROPIO IMPERIO", "CON SUS MANOS."],
	&"gengis_kan": ["SU HORDA CRUZÓ", "MEDIO MUNDO."],
	&"cleopatra": ["LA ÚLTIMA FARAONA.", "SU ASTUCIA AFILA SU DAGA."],
	&"julio_cesar": ["LLEGÓ, VIO...", "Y VENCERÁ."],
	&"jesus_de_nazaret": ["PREDICÓ EL PERDÓN.", "SU VARA TAMBIÉN GOLPEA."],
	&"alejandro_magno": ["NUNCA PERDIÓ UNA BATALLA.", "NO EMPEZARÁ AHORA."],
	&"sun_tzu": ["GANA SIN LUCHAR.", "TÚ LO ESTÁS HACIENDO MAL."],
	&"buda": ["LA PAZ INTERIOR", "TAMBIÉN GOLPEA."],
	&"adolf_hitler": ["SU IMPERIO DEBÍA DURAR MIL AÑOS.", "DURÓ DOCE."],
	&"joseph_stalin": ["ACERO EN EL NOMBRE.", "ACERO EN LOS PUÑOS."],
	&"donald_trump": ["EL ÚLTIMO EN LLEGAR", "SIEMPRE QUIERE LA CABECERA."],
	&"kim_jong_un": ["GOBIERNA UN PAÍS CERRADO.", "AQUÍ SOLO ENTRAN PUÑOS."],
	&"vladimir_putin": ["CINTURÓN NEGRO DE JUDO.", "NO SE LE DA LA ESPALDA."],
	&"xi_jinping": ["PACIENTE COMO UNA MURALLA.", "ESPERA TU ERROR."],
	&"nicolas_maduro": ["BAILA SALSA ENTRE GOLPES.", "NO CONFÍES EN SU RITMO."],
	&"benito_mussolini": ["EL DUCE SUBE AL BALCÓN", "A DAR SU ÚLTIMO DISCURSO."],
	&"saddam_hussein": ["REY DEL DESIERTO.", "SU TRONO ES ARENA."],
	&"osama_bin_laden": ["SE ESCONDE EN LA SOMBRA.", "ATACA SIN AVISAR."],
	&"fidel_castro": ["BAJÓ DE LA SIERRA", "A CAMBIAR UNA ISLA."],
	&"isabel_ii": ["SIETE DÉCADAS EN EL TRONO.", "NI UN GOLPE LA DESPEINA."],
	&"abraham_lincoln": ["ABOLIÓ LA ESCLAVITUD", "CON LAS MANOS Y UN HACHA."],
	&"papa_francisco": ["PASTOR DE LOS HUMILDES.", "TAMBIÉN SABE GOLPEAR."],
	&"rasputin": ["EL MONJE QUE NO MUERE.", "SU MIRADA TE CONTROLA."],
	&"pablo_escobar": ["PLATA O PLOMO.", "AQUÍ PAGAS EN GOLPES."],
	&"charles_darwin": ["SOBREVIVE EL MÁS ADAPTADO.", "A VER SI ERES TÚ."],
	&"galileo_galilei": ["LA TIERRA SE MUEVE.", "Y SU TELESCOPIO TAMBIÉN."],
	&"janequeo": ["LA TOQUI DEL SUR.", "SU PICA NO PERDONA."],
	&"pachacutec": ["TRANSFORMADOR DEL MUNDO.", "FUNDÓ EL TAHUANTINSUYO."],
	&"ivan_el_terrible": ["PRIMER ZAR DE RUSIA.", "SU FAMA ES SU ARMA."],
	&"boudica": ["REINA DE LOS ICENOS.", "ROMA TEMBLÓ ANTE ELLA."],
	&"arturo_prat": ["SALTÓ AL ABORDAJE", "SABIENDO QUE NO VOLVERÍA."],
	&"socrates": ["SOLO SÉ QUE NO SÉ NADA.", "PERO PEGA MUY FUERTE."],
	&"platon": ["FUNDÓ LA ACADEMIA.", "SU REPÚBLICA ES IMBATIBLE."],
	&"aristoteles": ["MAESTRO DE ALEJANDRO.", "SU LÓGICA ES IMPLACABLE."],
	&"confucio": ["PRIMERO EL ORDEN,", "DESPUÉS EL GOLPE."],
	&"isaac_newton": ["LA GRAVEDAD TIENE", "UN NOMBRE: ÉL."],
	&"nicolas_maquiavelo": ["EL FIN JUSTIFICA", "LOS MEDIOS. TODOS."],
	&"mariya_oktyabrskaya": ["VENDIÓ TODO PARA COMPRAR", "UN TANQUE: EL SUYO."],
	&"liudmila_pavlichenko": ["LADY DEATH: 309 BAJAS", "CONFIRMADAS EN LA GUERRA."],
}
## Frases cuando se enfrentan dos luchadores concretos, en cualquier orden: "id|id" -> líneas.
const VS_PAIR := {
	"salvador_allende|augusto_pinochet": ["LA MONEDA, 1973.", "AHORA SE DECIDE DE OTRO MODO."],
	"hernan_cortes|moctezuma_ii": ["DOS MUNDOS SE ENCUENTRAN", "EN TENOCHTITLAN."],
	"cristobal_colon|lautaro": ["EL DESCUBRIDOR Y EL TOQUI", "SE VEN LAS CARAS."],
	"napoleon|juana_de_arco": ["UN EMPERADOR Y UNA SANTA.", "TRES SIGLOS Y MEDIO ENTRE ELLOS."],
	"abraham_lincoln|charles_darwin": ["NACIERON EL MISMO DÍA.", "SOLO UNO SE QUEDA EN PIE."],
	"socrates|platon": ["MAESTRO Y DISCÍPULO.", "LA LECCIÓN SE DA A GOLPES."],
	"platon|aristoteles": ["EL DISCÍPULO CONTRA", "SU MAYOR RIVAL DE IDEAS."],
	"socrates|aristoteles": ["TRES SABIOS, UNA IDEA:", "EL MÁS FUERTE ENSEÑA."],
	"julio_cesar|cleopatra": ["ROMA Y EGIPTO,", "OTRA VEZ ENFRENTADAS."],
	"alejandro_magno|aristoteles": ["EL ALUMNO DEBE LA CLASE", "A SU MAESTRO."],
	"adolf_hitler|joseph_stalin": ["DOS TIRANOS, UN PACTO", "ROTO. FUEGO CRUZADO."],
	"adolf_hitler|benito_mussolini": ["EL EJE SE QUIEBRA.", "NO HAY ALIADOS EN EL NEXO."],
	"fidel_castro|donald_trump": ["MEDIO SIGLO DE ENEMISTAD.", "SALDADA EN UN RING."],
	"nikola_tesla|albert_einstein": ["DOS MENTES, UNA MÁQUINA.", "AHORA, UN SOLO GANADOR."],
	"marie_curie|nikola_tesla": ["LUZ CONTRA CORRIENTE.", "EL RELOJ LOS UNIÓ."],
}
