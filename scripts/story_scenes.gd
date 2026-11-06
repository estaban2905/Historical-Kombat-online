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
	# --- Todos los demás luchadores: dicen qué quieren rehacer y el Nexo les responde (una escena de dos frases) ---
	# --- El mundo actual ---
	&"kim_jong_un": [
		[&"kim_jong_un", "QUIERO REESCRIBIR LA HISTORIA PARA QUE NINGÚN MURO DE MI PAÍS SE ABRA JAMÁS."],
		[NEXO, "TODO MURO SE ABRE ALGÚN DÍA. YO NACÍ DE ESA VERDAD."],
	],
	&"nicolas_maduro": [
		[&"nicolas_maduro", "QUIERO REESCRIBIR MI HISTORIA Y GANAR OTRA VEZ, A PUNTA DE BAILE Y AGUANTE."],
		[NEXO, "AQUÍ NO HAY ELECCIONES, SOLO TIEMPO. BAILA TODO LO QUE QUIERAS."],
	],
	&"osama_bin_laden": [
		[&"osama_bin_laden", "QUIERO VOLVER A 2011 Y ESCAPAR DE LA CASA DONDE ME ENCONTRARON."],
		[NEXO, "EL TIEMPO TAMBIÉN TE ENCONTRÓ. NO HAY CASA DONDE ESCONDERSE DE MÍ."],
	],
	&"xi_jinping": [
		[&"xi_jinping", "QUIERO REESCRIBIR EL TIEMPO A MI RITMO: LENTO, SEGURO, SIN QUE NADIE ME ADELANTE."],
		[NEXO, "YO SOY EL TIEMPO. TU PACIENCIA SE ACABA AQUÍ."],
	],
	&"vladimir_putin": [
		[&"vladimir_putin", "QUIERO VOLVER A 1991 Y EVITAR QUE LA UNIÓN SOVIÉTICA SE DISUELVA."],
		[NEXO, "SE DISOLVIÓ PORQUE NADA DURA PARA SIEMPRE. NI SIQUIERA YO."],
	],
	&"pablo_escobar": [
		[&"pablo_escobar", "QUIERO VOLVER A 1993 Y ESCAPAR DE MEDELLÍN. ESTA VEZ NO ME ENCUENTRAN."],
		[NEXO, "PLATA O PLOMO: ESA ES TU DEUDA CON EL TIEMPO. VAS A PAGARLA."],
	],
	&"papa_francisco": [
		[&"papa_francisco", "QUIERO REESCRIBIR LA HISTORIA PARA QUE NO HAYA MÁS GUERRAS."],
		[NEXO, "ES UN BUEN DESEO. POR ESO ME ALIMENTA TANTO."],
	],
	&"isabel_ii": [
		[&"isabel_ii", "QUIERO VOLVER A 1952 Y REINAR OTRA VEZ SIN QUE NADA CAMBIE."],
		[NEXO, "TODO CAMBIA, MAJESTAD. HASTA EL TIEMPO ROTO."],
	],
	# --- El siglo XX ---
	&"saddam_hussein": [
		[&"saddam_hussein", "QUIERO VOLVER A 1991 Y GANAR LA GUERRA DEL GOLFO."],
		[NEXO, "ESA ARENA YA SE LLEVÓ TU TRONO. AQUÍ SE LLEVARÁ TU ARREPENTIMIENTO."],
	],
	&"fidel_castro": [
		[&"fidel_castro", "QUIERO REESCRIBIR MI ISLA: QUE EL BLOQUEO NUNCA EXISTA."],
		[NEXO, "TÚ NUNCA TE RENDISTE. POR ESO ESTÁS AQUÍ."],
	],
	&"liudmila_pavlichenko": [
		[&"liudmila_pavlichenko", "QUIERO VOLVER A 1942 Y SALVAR A LOS COMPAÑEROS QUE PERDÍ."],
		[NEXO, "TU PUNTERÍA ES PERFECTA, PERO EL TIEMPO NO SE APUNTA."],
	],
	&"augusto_pinochet": [
		[&"augusto_pinochet", "QUIERO VOLVER A 1988 Y GANAR EL PLEBISCITO QUE PERDÍ."],
		[NEXO, "EL PUEBLO YA HABÍA DECIDIDO. AQUÍ NO HAY URNAS."],
	],
	&"salvador_allende": [
		[&"salvador_allende", "QUIERO VOLVER AL 11 DE SEPTIEMBRE DE 1973 Y DEFENDER LA MONEDA, ESTA VEZ GANANDO."],
		[NEXO, "TU FINAL FUE DIGNO. ¿DE VERDAD QUIERES CAMBIARLO?"],
	],
	&"mariya_oktyabrskaya": [
		[&"mariya_oktyabrskaya", "QUIERO VOLVER A 1944 Y EVITAR LA BATALLA DONDE CAÍ."],
		[NEXO, "TU TANQUE FUE LEGENDARIO. EL TIEMPO LO RECUERDA TAL COMO FUE."],
	],
	&"benito_mussolini": [
		[&"benito_mussolini", "QUIERO VOLVER A 1943 Y GANAR LA GUERRA QUE PERDÍ."],
		[NEXO, "UN BALCÓN VACÍO ES TODO LO QUE TE ESPERA."],
	],
	&"joseph_stalin": [
		[&"joseph_stalin", "QUIERO REESCRIBIR 1941 Y QUE NADIE ME SORPRENDA OTRA VEZ."],
		[NEXO, "EL ACERO TAMBIÉN SE ENMOHECE. YO LO VI."],
	],
	&"rasputin": [
		[&"rasputin", "QUIERO VOLVER A DICIEMBRE DE 1916 Y SOBREVIVIR POR FIN."],
		[NEXO, "SOBREVIVISTE AL VENENO Y A LAS BALAS. YO NO SOY UNA DE ELLAS."],
	],
	# --- Revoluciones y progreso ---
	&"arturo_prat": [
		[&"arturo_prat", "QUIERO VOLVER A IQUIQUE, 1879, Y GANAR SIN PERDER LA VIDA."],
		[NEXO, "TU ABORDAJE ES LEYENDA PORQUE PERDISTE. ¿LO CAMBIARÍAS?"],
	],
	&"abraham_lincoln": [
		[&"abraham_lincoln", "QUIERO VOLVER A 1865 Y EVITAR LA NOCHE EN EL TEATRO."],
		[NEXO, "TU UNIÓN SANÓ. LO QUE FALTA ES TU PROPIA HERIDA."],
	],
	&"charles_darwin": [
		[&"charles_darwin", "QUIERO REESCRIBIR MI HISTORIA Y COMPROBAR QUIÉN SE ADAPTA."],
		[NEXO, "TÚ ESCRIBISTE QUE SOBREVIVE EL QUE CAMBIA. CAMBIA."],
	],
	# --- Imperios y descubrimientos ---
	&"isaac_newton": [
		[&"isaac_newton", "QUIERO VOLVER A 1720 Y NO PERDER MI FORTUNA EN LA BURBUJA DEL MAR DEL SUR."],
		[NEXO, "PUDISTE CALCULAR LA GRAVEDAD, NO LA CODICIA."],
	],
	&"janequeo": [
		[&"janequeo", "QUIERO VOLVER AL SUR Y EVITAR QUE MI ESPOSO MUERA EN LA GUERRA."],
		[NEXO, "TU DOLOR ES JUSTO. POR ESO ME LLAMÓ TAN FUERTE."],
	],
	&"galileo_galilei": [
		[&"galileo_galilei", "QUIERO VOLVER A 1633 Y GANAR EL JUICIO QUE ME CALLÓ."],
		[NEXO, "TUVISTE RAZÓN, Y PERDISTE IGUAL. LA TIERRA SIGUIÓ MOVIÉNDOSE."],
	],
	&"lautaro": [
		[&"lautaro", "QUIERO VOLVER A MATAQUITO, 1557, Y NO CAER EN LA EMBOSCADA."],
		[NEXO, "TU ESTRATEGIA ENSEÑÓ A TU PUEBLO. TU FINAL TAMBIÉN."],
	],
	&"ivan_el_terrible": [
		[&"ivan_el_terrible", "QUIERO VOLVER A 1582 Y GANAR LA GUERRA DE LIVONIA."],
		[NEXO, "NI EL MIEDO COMPRA TERRITORIOS. YA LO PERDISTE TODO."],
	],
	&"nostradamus": [
		[&"nostradamus", "QUIERO VOLVER A MI ÉPOCA Y ACERTAR LA PROFECÍA QUE FALLÓ."],
		[NEXO, "YA SABÍA QUE ME LO PEDIRÍAS. ESA PROFECÍA SÍ SE CUMPLE."],
	],
	&"nicolas_maquiavelo": [
		[&"nicolas_maquiavelo", "QUIERO VOLVER A 1512 Y EVITAR QUE LOS MEDICI ME ENCARCELEN."],
		[NEXO, "EL FIN JUSTIFICA LOS MEDIOS, DIJISTE. ¿Y TUS MEDIOS?"],
	],
	&"moctezuma_ii": [
		[&"moctezuma_ii", "QUIERO VOLVER A 1519 Y NO DEJAR ENTRAR A CORTÉS EN TENOCHTITLAN."],
		[NEXO, "CORTÉS ESPERA MÁS ADELANTE. ¿TE ATREVES A VERLO?"],
	],
	&"cristobal_colon": [
		[&"cristobal_colon", "QUIERO VOLVER A 1500 Y EVITAR LAS CADENAS QUE ME PUSIERON."],
		[NEXO, "CRUZASTE UN OCÉANO. CRUZA ESTA CULPA."],
	],
	&"pachacutec": [
		[&"pachacutec", "QUIERO VOLVER A MI ÉPOCA Y EVITAR QUE EL TAHUANTINSUYO CAIGA."],
		[NEXO, "UN IMPERIO QUE NO CAE NO APRENDE. CAE CON ELEGANCIA."],
	],
	&"juana_de_arco": [
		[&"juana_de_arco", "QUIERO VOLVER A 1431 Y EVITAR LA HOGUERA DE ROUEN."],
		[NEXO, "TUS VOCES TE LLAMARON AQUÍ. YO SOLO LAS ESCUCHÉ."],
	],
	&"gengis_kan": [
		[&"gengis_kan", "QUIERO VOLVER A 1227 Y CABALGAR SIN MORIR ANTES DE TERMINAR."],
		[NEXO, "TU IMPERIO ES EL MÁS GRANDE. TU TIEMPO, EL MÁS CORTO."],
	],
	# --- La antigüedad ---
	&"boudica": [
		[&"boudica", "QUIERO VOLVER AL AÑO 60 Y GANAR LA BATALLA CONTRA ROMA."],
		[NEXO, "ROMA TEMBLÓ Y NO TE BASTÓ. AQUÍ TAMPOCO TE BASTARÁ."],
	],
	&"jesus_de_nazaret": [
		[&"jesus_de_nazaret", "QUIERO VOLVER A MI ÉPOCA A DEFENDER A LOS MÍOS. NO QUIERO GANAR, QUIERO PROTEGER."],
		[NEXO, "TU ARREPENTIMIENTO ES COMPASIÓN. ES EL MÁS DIFÍCIL DE ALIMENTAR."],
	],
	&"cleopatra": [
		[&"cleopatra", "QUIERO VOLVER A ACCIO, 31 A.C., Y GANAR LA BATALLA QUE PERDÍ."],
		[NEXO, "EGIPTO CAYÓ Y TÚ TE LEVANTAS. ESO TE HACE PELIGROSA."],
	],
	&"alejandro_magno": [
		[&"alejandro_magno", "QUIERO VOLVER A BABILONIA, 323 A.C., Y NO MORIR A LOS 32."],
		[NEXO, "EL TIEMPO NO DISCUTE CON LOS CONQUISTADORES. LOS ESPERA."],
	],
	&"aristoteles": [
		[&"aristoteles", "QUIERO VOLVER A 323 A.C. Y EVITAR EL EXILIO DE ATENAS."],
		[NEXO, "TU LÓGICA TAMBIÉN TIENE UN FINAL. ESTE."],
	],
	&"platon": [
		[&"platon", "QUIERO VOLVER A SIRACUSA Y CONVERTIR A UN TIRANO EN FILÓSOFO."],
		[NEXO, "LO INTENTASTE VARIAS VECES. ESTA NO SERÁ DISTINTA."],
	],
	&"socrates": [
		[&"socrates", "QUIERO VOLVER AL JUICIO DEL 399 A.C. Y GANAR MI DEFENSA."],
		[NEXO, "BEBISTE LA CICUTA CON CALMA. AHORA BEBE ESTA DUDA."],
	],
	&"sun_tzu": [
		[&"sun_tzu", "QUIERO REESCRIBIR MI HISTORIA Y GANAR SIN LUCHAR."],
		[NEXO, "YA ESTÁS LUCHANDO. ESTA ES TU PRIMERA DERROTA."],
	],
	&"confucio": [
		[&"confucio", "QUIERO VOLVER A MI ÉPOCA Y LOGRAR QUE UN REY ESCUCHE MI DOCTRINA."],
		[NEXO, "NINGÚN REY TE OYÓ. YO SÍ TE ESCUCHO."],
	],
	&"buda": [
		[&"buda", "QUIERO VOLVER A MI ÉPOCA SIN DESEO. PERO PRIMERO TE DETENDRÉ."],
		[NEXO, "UN SOLO DESEO TE TRAJO AQUÍ: PROTEGER LA CALMA. ES SUFICIENTE."],
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
