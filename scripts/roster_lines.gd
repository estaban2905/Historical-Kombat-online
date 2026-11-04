## Frases cruzadas: lo que dice un luchador cuando enfrenta o vence a un rival concreto.
##
## VERSUS["a>b"] = [lo que A dice al enfrentar a B (selección de luchador), lo que A dice al vencer a B
## (pantalla de resultados)]. Es direccional: "a>b" y "b>a" son entradas distintas y cada una es opcional.
## Si no hay entrada, se usa la frase normal del luchador (intro_quote / victory_quote), así que se puede
## ampliar de a poco sin romper nada.
##
## Límites de texto (pantalla de 426x240): intro hasta ~55 caracteres, victoria hasta ~70.
## Tono: son caricaturas de la historia; ninguna frase glorifica a nadie.
class_name RosterLines
extends RefCounted

const VERSUS := {
	# --- Roma y Egipto ---
	&"julio_cesar>cleopatra": ["Reina, Roma también sabe seducir.", "Vine, vi y vencí. Hasta a una reina."],
	&"cleopatra>julio_cesar": ["César, Egipto no se conquista fácil.", "Roma tiene un general; Egipto, una reina."],
	&"boudica>julio_cesar": ["Roma pagará cada insulto a mi pueblo.", "Los icenos no se arrodillan ante Roma."],
	&"julio_cesar>boudica": ["Reina, Roma no teme a una rebelión.", "Una rebelión menos en el mapa de Roma."],
	&"napoleon>julio_cesar": ["César, yo también crucé fronteras.", "Un emperador sobre un dictador: ¡justicia!"],
	&"julio_cesar>napoleon": ["¿Emperador? Yo inventé el cargo.", "Un día más, Roma gana a Francia."],
	# --- Grecia ---
	&"platon>aristoteles": ["Fuiste mi alumno; hoy repites la lección.", "Las ideas siempre superan a las observaciones."],
	&"aristoteles>platon": ["Querido maestro, la verdad está en lo que veo.", "Amigo de Platón, pero más amigo de la verdad."],
	&"socrates>platon": ["¿Y si el alumno ya no recuerda al maestro?", "Solo sé que mi discípulo aún no sabe ganar."],
	&"platon>socrates": ["Maestro, hoy te defiendo con los puños.", "Tu sabiduría sobrevive en mis diálogos."],
	&"alejandro_magno>aristoteles": ["Maestro, vengo a aplicar lo que me enseñaste.", "Me enseñaste a pensar; yo aprendí a conquistar."],
	&"aristoteles>alejandro_magno": ["Alumno, la lógica pesa más que tu espada.", "Un buen alumno supera al maestro... otro día."],
	# --- Conquistadores ---
	&"gengis_kan>alejandro_magno": ["Macedonio, mis jinetes llegaron más lejos.", "La estepa venció a Macedonia."],
	&"alejandro_magno>gengis_kan": ["Kan, yo no perdí ni una batalla.", "Un conquistador menos entre mis rivales."],
	&"moctezuma_ii>hernan_cortes": ["Extranjero, esta ciudad es del Sol.", "Tenochtitlan sigue en pie en esta historia."],
	&"hernan_cortes>moctezuma_ii": ["Rey, vengo por tu ciudad y tu oro.", "Quemen las naves: Tenochtitlan es nuestra."],
	&"pachacutec>moctezuma_ii": ["Imperio hermano, solo uno ocupa la cima.", "Los Andes imponen respeto sobre el lago."],
	&"moctezuma_ii>pachacutec": ["Sapa Inca, el Sol brilla más en mi imperio.", "El Sol de Tenochtitlan ilumina más fuerte."],
	# --- Pueblo mapuche ---
	&"janequeo>lautaro": ["Toqui, hoy también peleo por Arauco.", "Arauco enseña: la tierra no se rinde."],
	&"lautaro>janequeo": ["Hermana de lucha, no te daré ventaja.", "Buen combate: la libertad nos une."],
	# --- Chile ---
	&"salvador_allende>augusto_pinochet": ["Chile merece democracia, no uniformes.", "La historia la escriben los pueblos."],
	&"augusto_pinochet>salvador_allende": ["Presidente, aquí mando yo.", "Se acabó el debate, doctor."],
	# --- Estrategia ---
	&"sun_tzu>nicolas_maquiavelo": ["Conozco tu Príncipe. Y también tu derrota.", "El arte de la guerra supera al arte del poder."],
	&"nicolas_maquiavelo>sun_tzu": ["Maestro chino, el poder no es filosofía.", "Mejor temido que amado... y yo gano."],
	&"confucio>sun_tzu": ["Maestro de la guerra, la virtud vence al arte.", "El orden y la virtud se imponen."],
	&"sun_tzu>confucio": ["Maestro del orden, la guerra se gana pensando.", "Gané antes de empezar. Perdone, maestro."],
	# --- Ciencia ---
	&"nikola_tesla>albert_einstein": ["Tu fórmula brilla, pero mi corriente enciende.", "La electricidad vence a la relatividad."],
	&"albert_einstein>nikola_tesla": ["Tus bobinas son bonitas, pero todo es relativo.", "Hasta los rayos obedecen a las ecuaciones."],
	&"galileo_galilei>isaac_newton": ["Yo vi las lunas; tú solo viste una manzana.", "Sobre los hombros de gigantes: sobre los míos."],
	&"isaac_newton>galileo_galilei": ["Viste el cielo; yo escribí sus leyes.", "La gravedad también te derribó, Galileo."],
	# --- Segunda Guerra Mundial (Hitler siempre como caricatura ridícula) ---
	&"joseph_stalin>adolf_hitler": ["Berlín cayó; tú también caerás.", "El acero soviético aplasta a los gritones."],
	&"adolf_hitler>joseph_stalin": ["¡Un pacto es un pacto... por ahora!", "¡Gané! ¿Dónde están los aplausos?"],
	&"liudmila_pavlichenko>adolf_hitler": ["Un disparo basta, aunque grites mucho.", "Objetivo eliminado: uno más para mi cuenta."],
	&"mariya_oktyabrskaya>adolf_hitler": ["Vendí todo por mi tanque. ¡Prepárate!", "El T-34 pasó por encima del ruido."],
	# --- Coronas y santos ---
	&"juana_de_arco>isabel_ii": ["Los ingleses ya me quemaron una vez.", "Dios y Francia vencen a la Corona."],
	&"isabel_ii>juana_de_arco": ["Querida, la Corona no se quema tan fácil.", "Dios salve a la Reina. Como siempre."],
	&"ivan_el_terrible>rasputin": ["Monje, en Rusia solo manda un zar.", "Ni un místico puede con el zar."],
	&"rasputin>ivan_el_terrible": ["Zar, yo sobreviví a más que tú.", "Ni el zar más terrible me mata."],
	# --- Fe ---
	&"buda>jesus_de_nazaret": ["Dos caminos, una misma paz. Peleemos en paz.", "Ambos buscamos la paz. Hoy la encontré yo."],
	&"jesus_de_nazaret>buda": ["Amigo, que gane quien tenga más amor.", "La luz y la calma caminan juntas."],
	&"papa_francisco>jesus_de_nazaret": ["Señor, perdona que te dispute este combate.", "Que Dios nos perdone: esta vez gané yo."],
	# --- Siglo XXI ---
	&"donald_trump>vladimir_putin": ["Vladimir, nadie negocia mejor que yo.", "¡Gané! Fue un trato espectacular."],
	&"vladimir_putin>donald_trump": ["Donald, esto no es un negocio.", "El resultado estaba decidido, Donald."],
	&"donald_trump>kim_jong_un": ["Hombre Cohete, hoy pierdes el trato.", "¡Otro gran trato! El cohete se quedó en tierra."],
	&"kim_jong_un>donald_trump": ["Mis cohetes ya apuntan a tu peinado.", "¡Victoria! Que lo transmitan en directo."],
}

static func _key(a: StringName, b: StringName) -> StringName:
	return StringName("%s>%s" % [a, b])

## ¿Hay frases específicas de `me` contra `foe`?
static func has_duel(me: StringName, foe: StringName) -> bool:
	return VERSUS.has(_key(me, foe))

## Lo que `me` dice al enfrentar a `foe`; `fallback` (su frase normal) si no hay entrada.
static func intro(me: StringName, foe: StringName, fallback: String) -> String:
	var k := _key(me, foe)
	return VERSUS[k][0] if VERSUS.has(k) else fallback

## Lo que `me` dice al vencer a `foe`; `fallback` (su frase normal) si no hay entrada.
static func win(me: StringName, foe: StringName, fallback: String) -> String:
	var k := _key(me, foe)
	return VERSUS[k][1] if VERSUS.has(k) else fallback
