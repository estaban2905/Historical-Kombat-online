## Escenarios de la ciudad invadida del MODO HISTORIA: la Tierra de hoy en ruinas, con el ejército del rival
## acampado en las calles y su bandera clavada entre los escombros. Cada combate de la Historia se juega aquí.
## El identificador es "city:<id del rival>" (ver Game.stage_owner y StageRegistry.def_for).
## Ver stage_defs_a.gd para el formato de las definiciones.
class_name StageDefsCity
extends RefCounted

const PREFIX := "city:"

## Estilo de soldado del ejército de cada rival (los que no están aquí usan "militia").
const ARMY := {
	&"julio_cesar": "legion", &"alejandro_magno": "hoplite", &"gengis_kan": "mongol", &"cleopatra": "egypt",
	&"napoleon": "musket", &"ivan_el_terrible": "cossack", &"rasputin": "cossack", &"hernan_cortes": "conquistador",
	&"cristobal_colon": "sailor", &"nicolas_maquiavelo": "florentine", &"nostradamus": "robe",
	&"adolf_hitler": "wehr", &"joseph_stalin": "soviet", &"benito_mussolini": "fascist", &"saddam_hussein": "iraqi",
	&"fidel_castro": "guerrilla", &"augusto_pinochet": "chilean", &"vladimir_putin": "rusguard", &"kim_jong_un": "kpa",
	&"nicolas_maduro": "chavista", &"osama_bin_laden": "mujahid", &"pablo_escobar": "sicario", &"donald_trump": "suit",
	&"albert_einstein": "scientist", &"nikola_tesla": "scientist", &"marie_curie": "scientist", &"leonardo_da_vinci": "scientist",
}

## Un aspecto de ciudad por capítulo (el mundo actual, el siglo XX, revoluciones y la antigüedad).
const VARIANTS: Array = [
	{"name": "CIUDAD EN LLAMAS", "sky": ["1a0a1c", "3a1428", "6a2030", "a03a2c", "d0662c"], "far": "3a2430", "near": "20141c",
		"win": "e8a040", "glow": "ff7030", "ground": ["noise", "3a3640", "24222a", "5a5660", 31]},
	{"name": "CIUDAD BOMBARDEADA", "sky": ["2a2220", "4a3a34", "6a544a", "8a6c58", "a88a68"], "far": "5a4a44", "near": "34282a",
		"win": "d8a850", "glow": "d09050", "ground": ["noise", "4a4038", "2e2822", "6a5e50", 32]},
	{"name": "AVENIDA ASEDIADA", "sky": ["1a1038", "3a1c48", "6a2c4c", "b0502c", "e08a3a"], "far": "46304a", "near": "261a34",
		"win": "f0c060", "glow": "ff9040", "ground": ["noise", "403848", "282030", "60546a", 33], "cannons": true},
	{"name": "RUINAS DE LA METRÓPOLI", "sky": ["3a0f14", "6a1c1c", "a03a20", "d06028", "f09a3a"], "far": "6a3a2c", "near": "3a1e1c",
		"win": "ffb050", "glow": "ff6020", "ground": ["noise", "5a3a2a", "3a2418", "7a5238", 34], "pyramids": true},
]

static func _variant_of(rival: StringName) -> int:
	for i in StoryCampaign.CHAPTERS.size():
		if (StoryCampaign.CHAPTERS[i][1] as Array).has(rival):
			return i
	return 0

static func get_def(id: StringName) -> Dictionary:
	var s := String(id)
	if not s.begins_with(PREFIX):
		return {}
	var rival := StringName(s.substr(PREFIX.length()))
	var v: Dictionary = VARIANTS[_variant_of(rival)]
	var style: String = ARMY.get(rival, "militia")
	var st: Dictionary = StageOps.STYLES.get(style, StageOps.STYLES["legion"])
	var uni: String = st.get("uni", "b03030")
	var trim: String = st.get("trim", "e6b43c")
	var sd: int = absi(String(rival).hash()) % 50
	var back: Array = [
		["sky", v["sky"], 176],
		["stars", 24, sd, 80, "c8b8d8"],
		["glow", 213, 80, 150, v["glow"], 0.25],
		["skyline", 176, v["far"], sd + 1, 16, 26, 36, 80, "", true],
		["skyline", 176, v["near"], sd + 2, 14, 22, 40, 100, v["win"], true],
	]
	# Kim aprovecha el caos para multiplicar su arsenal: misiles listos para despegar entre las ruinas.
	var missile_smoke: Array = []
	if rival == &"kim_jong_un":
		for mx in [52, 150, 276, 376]:
			back.append(["rect", mx - 3, 118, 6, 58, "c8c8d0"])
			back.append(["poly", [mx - 3, 118, mx, 104, mx + 3, 118], "c02020"])
			back.append(["rect", mx - 6, 164, 12, 12, "6a6a78"])
			missile_smoke.append(["smoke", mx, 176, 4, "9a9288", 40, 1.0])
	if v.get("pyramids", false):
		back.append(["pyramid", 80, 176, 90, "c9a050", "a07a34"])
		back.append(["pyramid", 346, 176, 70, "c9a050", "a07a34"])
	# La grieta del Nexo sobre la ciudad.
	back.append(["poly", [204, 0, 212, 38, 206, 70, 212, 98, 218, 70, 214, 38, 222, 0], "9a4dff"])
	back.append(["poly", [210, 0, 213, 38, 210, 68, 213, 90, 216, 68, 214, 38, 216, 0], "ffd24a"])
	back.append(["ground", 176] + (v["ground"] as Array))
	var mid: Array = [
		["smoke", 70, 120, 5, "3a3430", 56, 1.4], ["smoke", 300, 100, 5, "3a3430", 60, 1.4],
		["fire", 40, 176, 12], ["fire", 392, 176, 12],
		["flag", 22, 176, 80, 30, 18, uni, "", trim], ["flag", 404, 176, 80, 30, 18, uni, "", trim],
		["formation", 6, 90, 184, 15, style, sd, 0.9, 2, 4, true],
		["formation", 340, 420, 184, 15, style, sd + 3, 0.9, 2, 4, true],
	]
	mid.append_array(missile_smoke)
	if v.get("cannons", false):
		mid.append(["cannonfire", 30, 176, 1, 5.0, 0.0])
		mid.append(["cannonfire", 396, 176, -1, 6.0, 1.0])
	return {
		"name": v["name"],
		"back": back,
		"mid": mid,
		"fx": [["embers", 26, "ff9030", 16]],
	}
