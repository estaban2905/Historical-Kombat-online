## Escenarios temáticos (parte A). Cada definición es una lista de operaciones
## de stage_ops.gd por capa:
##   back  = fondo y suelo (estático)      mid = actores animados
##   front = primer plano (estático)       fx  = efectos animados
## Las operaciones son ["nombre", args...]; ver op_xxx en stage_ops.gd.
class_name StageDefsA
extends RefCounted

static func get_def(id: StringName) -> Dictionary:
	match id:
		&"donald_trump": return _trump()
		&"kim_jong_un": return _kim()
		&"vladimir_putin": return _putin()
		&"xi_jinping": return _xi()
		&"nicolas_maduro": return _maduro()
		&"adolf_hitler": return _hitler()
		&"joseph_stalin": return _stalin()
		&"benito_mussolini": return _mussolini()
		&"saddam_hussein": return _saddam()
		&"osama_bin_laden": return _bin_laden()
		&"napoleon": return _napoleon()
		&"gengis_kan": return _gengis()
		&"fidel_castro": return _fidel()
		&"cleopatra": return _cleopatra()
	return {}

static func _trump() -> Dictionary:
	return {
		"name": "LA CASA BLANCA · WASHINGTON D.C.",
		"back": [
			["sky", ["4a8ad8", "6aa6e6", "8cbef0", "b0d6f6", "d4e8fa"], 168],
			["tree", 36, 168, 56, "3a7a3a"], ["tree", 74, 168, 40, "468a42"],
			["tree", 392, 168, 60, "3a7a3a"], ["tree", 352, 168, 38, "468a42"],
			["rect", 70, 148, 36, 20, "e8e8e0"], ["rect", 322, 148, 36, 20, "e8e8e0"],
			["grid", 76, 153, 3, 1, 10, 0, 4, 6, "3a4a6a"], ["grid", 328, 153, 3, 1, 10, 0, 4, 6, "3a4a6a"],
			["rect", 104, 131, 218, 3, "b8b8b0"],
			["rect", 104, 134, 218, 34, "f2f2ea"], ["rect", 104, 134, 218, 2, "fffffa"],
			["grid", 110, 141, 4, 2, 12, 12, 5, 7, "3a4a6a"], ["grid", 266, 141, 4, 2, 12, 12, 5, 7, "3a4a6a"],
			["rect", 167, 138, 92, 30, "b8b8b0"],
			["tent", 213, 134, 100, 16, "f6f6ee", "e6e6de"],
			["col", 173, 138, 168, 5, "f8f8f0", "d8d8d0", "ffffff"], ["col", 193, 138, 168, 5, "f8f8f0", "d8d8d0", "ffffff"],
			["col", 213, 138, 168, 5, "f8f8f0", "d8d8d0", "ffffff"], ["col", 233, 138, 168, 5, "f8f8f0", "d8d8d0", "ffffff"],
			["col", 253, 138, 168, 5, "f8f8f0", "d8d8d0", "ffffff"],
			["rect", 168, 146, 90, 2, "fffffa"],
			["ground", 168, "noise", "4a8a3a", "3a7a2a", "5a9a4a", 5],
			["rect", 0, 164, 426, 2, "1a1a22"], ["grid", 0, 156, 48, 1, 9, 0, 2, 12, "1a1a22"],
			["rect", 0, 166, 426, 2, "c8a030"],
		],
		"mid": [
			["clouds", 5, 1, 10, 70, "ffffff", "c8d8ec", 2.0],
			["flag", 60, 172, 92, 30, 18, "b22234", "f4f4f4", "2a3a8a"],
			["flag", 366, 172, 92, 30, 18, "b22234", "f4f4f4", "2a3a8a"],
			["flag", 213, 131, 30, 22, 13, "b22234", "f4f4f4", "2a3a8a"],
			["birds", 2, 3, 24, 70, 10, "5a3a22", 1.3],
			["formation", 184, 244, 166, 20, "marine", 6, 0.8],
			["formation", 90, 340, 178, 26, "suit", 4, 1.0, 1, 4],
		],
	}

static func _kim() -> Dictionary:
	return {
		"name": "PLAZA DE PYONGYANG · GRAN DESFILE",
		"back": [
			["sky", ["c8b8b0", "d4b0a4", "dca898", "e4a48c", "ec9c80"], 176],
			["skyline", 176, "9a98a8", 8, 18, 30, 30, 55, "d8d8c0"],
			["skyline", 176, "6a6a7a", 3, 16, 26, 40, 84, "d8d070"],
			["rect", 342, 70, 8, 106, "d8d8d0"], ["rect", 336, 100, 20, 6, "b8b8b0"], ["rect", 339, 56, 14, 14, "e04020"],
			["rect", 0, 148, 426, 28, "8a2020"], ["rect", 0, 148, 426, 2, "e6b43c"],
			["grid", 0, 156, 53, 1, 8, 0, 4, 3, "e6b43c"],
			["banner", 100, 34, 26, 70, "c02020", "e6b43c", "e6b43c"], ["banner", 300, 34, 26, 70, "c02020", "e6b43c", "e6b43c"],
			["ground", 176, "slabs", "8a8a88", "5a5a58", "3a3a3a", 7],
		],
		"mid": [
			["travel", "missile", 172, -16, 0.75, 2, 3],
			["flag", 18, 176, 72, 30, 16, "2a4a9a", "c02020"], ["flag", 398, 176, 72, 30, 16, "2a4a9a", "c02020"],
			["formation", 40, 400, 180, 17, "kpa", 2, 0.95, 2, 6, true],
		],
		"fx": [
			["fireworks", 4, 1, ["ff4040", "ffd040", "ffffff", "ff80c0"]],
		],
	}

static func _putin() -> Dictionary:
	return {
		"name": "LA PLAZA ROJA · MOSCÚ",
		"back": [
			["sky", ["8a9cb4", "a0b0c4", "b4c4d4", "c8d4e0", "dce4ec"], 176],
			["wall", 150, 26, "9a3a2a", "6a2218", true],
			["rect", 196, 72, 28, 78, "b04838"], ["tent", 210, 72, 34, 28, "3a8a4a", "2a6a3a"],
			["rect", 148, 104, 26, 46, "d8c8a0"], ["rect", 246, 110, 26, 40, "b04838"],
			["rect", 172, 120, 24, 30, "b04838"], ["rect", 224, 118, 24, 32, "d8c8a0"],
			["dome", 161, 104, 11, "3a8a4a", "e8d040", "e6b43c"], ["dome", 259, 110, 10, "c03030", "f0e0a0", "e6b43c"],
			["dome", 184, 120, 8, "2a6aa0", "f0e8c0", "e6b43c"], ["dome", 236, 118, 9, "e6b43c", "c03030", "e6b43c"],
			["tower", 60, 176, 20, 60, "a04030", "7a2a20", "2a6a3a"],
			["tower", 366, 176, 24, 88, "a04030", "7a2a20", "2a6a3a"],
			["rect", 361, 96, 10, 10, "f0e8c0"], ["rect", 365, 44, 3, 6, "d02020"],
			["ground", 176, "slabs", "dce2ea", "9aa4b4", "7a849a", 9],
		],
		"mid": [
			["clouds", 4, 2, 8, 40, "e8eef4", "b8c4d4", 1.0],
			["flag", 24, 176, 74, 30, 18, "f4f4f4", "2a4a9a", "tri:c02020"],
			["patrol", "bear", 186, 40, 380, 22, 1.0, 0.1, "6a4a30"],
			["formation", 60, 380, 180, 24, "rusguard", 3, 1.0, 1, 4, true],
		],
		"fx": [
			["snow", 70, "ffffff", 24, 8],
		],
	}

static func _xi() -> Dictionary:
	return {
		"name": "LA GRAN MURALLA · CHINA",
		"back": [
			["sky", ["9ab8d0", "b0c8dc", "c8d8e4", "dce4e8", "ece8e0"], 176],
			["mount", 150, 70, "b8c4cc", 1.5, "", 1.3], ["mount", 165, 60, "8ea4a0", 3.2, "", 1.5],
			["mount", 176, 50, "5a7a60", 5.0, "", 1.8],
			["wall", 138, 38, "a89a84", "7a6e5c", true],
			["tower", 70, 176, 24, 56, "b0a28c", "7a6e5c", "3a5a4a"],
			["tower", 356, 176, 26, 70, "b0a28c", "7a6e5c", "3a5a4a"],
			["ground", 176, "slabs", "a09a8a", "6a6256", "4a4236", 11],
		],
		"mid": [
			["clouds", 3, 4, 14, 50, "e8e8e8", "c0c8d0", 1.5],
			["dragon", 54, 8, 22, "c02020", "e6b43c"],
			["flag", 26, 176, 74, 30, 18, "c02020", "", "e6b43c"],
			["flag", 400, 176, 74, 30, 18, "c02020", "", "e6b43c"],
			["formation", 40, 400, 178, 36, "chinese", 5, 0.95],
		],
		"front": [
			["rect", 30, 0, 1, 22, "3a2a20"], ["circle", 30, 28, 7, "c02020"], ["rect", 27, 25, 7, 1, "e6b43c"],
			["rect", 140, 0, 1, 14, "3a2a20"], ["circle", 140, 20, 7, "c02020"], ["rect", 137, 17, 7, 1, "e6b43c"],
			["rect", 300, 0, 1, 14, "3a2a20"], ["circle", 300, 20, 7, "c02020"], ["rect", 297, 17, 7, 1, "e6b43c"],
			["rect", 396, 0, 1, 22, "3a2a20"], ["circle", 396, 28, 7, "c02020"], ["rect", 393, 25, 7, 1, "e6b43c"],
		],
		"fx": [
			["glow", 30, 28, 14, "ff8040", 0.2], ["glow", 140, 20, 14, "ff8040", 0.2],
			["glow", 300, 20, 14, "ff8040", 0.2], ["glow", 396, 28, 14, "ff8040", 0.2],
			["snow", 30, "f4b0b8", 12, 10],
		],
	}

static func _maduro() -> Dictionary:
	return {
		"name": "CARACAS · CERRO EL ÁVILA",
		"back": [
			["sky", ["5aa0e0", "7ab8ec", "a0cef0", "f0d8a0", "f8c080"], 176],
			["mount", 130, 40, "5a8a6a", 4.0], ["mount", 176, 90, "3a6a40", 2.0, "", 1.0],
			["skyline", 176, "7a8a9a", 12, 14, 22, 30, 70, "e8e0a0"],
			["rect", 300, 50, 14, 126, "6a7a8a"], ["rect", 318, 60, 14, 116, "6a7a8a"],
			["grid", 302, 56, 3, 16, 4, 7, 2, 3, "c8d8e0"], ["grid", 320, 66, 3, 14, 4, 7, 2, 3, "c8d8e0"],
			["ground", 176, "slabs", "a89880", "6a5a48", "4a3a2a", 13],
		],
		"mid": [
			["palm", 24, 176, 76], ["palm", 402, 176, 68],
			["flag", 44, 176, 96, 36, 22, "f0c020", "2a4aa0", "tri:c02020"],
			["flag", 384, 176, 96, 36, 22, "f0c020", "2a4aa0", "tri:c02020"],
			["birds", 3, 5, 20, 70, 12, "202020"],
			["sprite", "horse", 82, 178, 1.2, 1, "7a6a40", "5a4a2a"],
			["formation", 150, 330, 182, 20, "chavista", 4, 1.0, 2, 6],
		],
	}

static func _hitler() -> Dictionary:
	return {
		"name": "NÚREMBERG · LA CATEDRAL DE LUZ",
		"back": [
			["sky", ["06060e", "0c0c1a", "12122a", "1a1a3a"], 176],
			["stars", 40, 1, 90, "c8c8e0"],
			["rect", 30, 82, 366, 4, "c0c0b8"], ["rect", 30, 86, 366, 8, "a0a098"],
			["rect", 30, 94, 366, 82, "7a7a76"],
			["grid", 36, 96, 11, 1, 34, 0, 10, 76, "9a9a94"], ["grid", 44, 96, 11, 1, 34, 0, 2, 76, "5a5a58"],
			["banners", 48, 5, 68, 100, 22, 56, "a82020", "1a1a1a", "1a1a1a"],
			["ground", 176, "slabs", "5a5a5c", "3a3a3c", "1a1a1c", 15],
			["formation", 10, 420, 174, 13, "wehr", 6, 0.9, 3, 4],
			["rect", 22, 150, 14, 26, "3a3a3a"], ["rect", 390, 150, 14, 26, "3a3a3a"],
		],
		"mid": [
			["fire", 29, 150, 10], ["fire", 397, 150, 10],
		],
		"fx": [
			["beams", 7, "a8c0ff28", 24, 402, 176],
			["embers", 14, "ff9040", 10],
		],
	}

static func _stalin() -> Dictionary:
	return {
		"name": "STALINGRADO · 1942",
		"back": [
			["sky", ["2a1e1e", "4a2a26", "6a3a2c", "8a4a30", "a85a34"], 176],
			["skyline", 176, "2a1a16", 21, 18, 30, 50, 100, "", true],
			["rect", 60, 70, 10, 106, "3a2a24"],
			["skyline", 176, "4a3028", 22, 14, 24, 30, 70, "e8a040", true],
			["rect", 378, 150, 44, 26, "3a2e26"],
			["ground", 176, "noise", "5a4a3a", "3a2e26", "7a6a58", 17],
		],
		"mid": [
			["smoke", 66, 70, 5, "3a3430", 50, 1.5], ["smoke", 240, 110, 5, "3a3430", 60, 1.5], ["smoke", 350, 100, 5, "3a3430", 60, 1.5],
			["fire", 110, 176, 14], ["fire", 300, 176, 12], ["fire", 372, 176, 10],
			["flag", 384, 150, 36, 30, 20, "c02020", "", "e6b43c"],
			["patrol", "tank", 180, 40, 380, 26, 0.9, 0.0, "4a5a3a"],
			["formation", 120, 330, 186, 26, "soviet", 8],
		],
		"fx": [
			["embers", 30, "ff8030", 18],
			["snow", 40, "9a9088", 14, 4],
		],
	}

static func _mussolini() -> Dictionary:
	return {
		"name": "ROMA · ALTAR DE LA PATRIA",
		"back": [
			["sky", ["78a8d8", "98c0e4", "b8d4ee", "d8e4f0", "f0ece0"], 176],
			["rect", 30, 70, 20, 12, "d8b040"], ["rect", 376, 70, 20, 12, "d8b040"],
			["rect", 30, 138, 366, 38, "e8e0cc"],
			["rect", 30, 82, 366, 4, "c8c0a8"], ["rect", 30, 86, 366, 8, "f4efe0"],
			["grid", 50, 94, 4, 1, 22, 0, 10, 50, "f8f4ea"], ["grid", 290, 94, 4, 1, 22, 0, 10, 50, "f8f4ea"],
			["grid", 56, 94, 4, 1, 22, 0, 2, 50, "c8c0a8"], ["grid", 296, 94, 4, 1, 22, 0, 2, 50, "c8c0a8"],
			["rect", 196, 102, 34, 40, "e8e0d0"], ["rect", 192, 138, 42, 6, "d8d0bc"],
			["banners", 61, 3, 22, 110, 10, 26, "1a1a1a", "d8d8d8", "c02020"],
			["banners", 301, 3, 22, 110, 10, 26, "1a1a1a", "d8d8d8", "c02020"],
			["ground", 176, "slabs", "d0c4a4", "9a8e72", "7a6e52", 19],
		],
		"mid": [
			["sprite", "horse", 213, 104, 1.3, 1, "7a6a40", "5a4a2a", "legion"],
			["birds", 4, 7, 30, 70, 12, "f0f0f0"],
			["flag", 24, 176, 82, 34, 20, "2a8a40", "f4f4f4", "vtri:c02020"],
			["flag", 402, 176, 82, 34, 20, "2a8a40", "f4f4f4", "vtri:c02020"],
			["formation", 90, 340, 180, 18, "fascist", 9, 1.0, 2, 6],
		],
	}

static func _saddam() -> Dictionary:
	return {
		"name": "BABILONIA · PUERTA DE ISHTAR",
		"back": [
			["sky", ["e8b868", "f0c878", "f4d890", "f8e4a8", "fcecc0"], 176],
			["disc", 340, 40, 16, "fff4c0", "ffffe0"],
			["mount", 176, 38, "d8b070", 2.0, "", 0.5],
			["rect", 100, 50, 52, 126, "1a4a9a"], ["rect", 274, 50, 52, 126, "1a4a9a"],
			["rect", 150, 70, 126, 106, "1a4a9a"],
			["grid", 100, 44, 9, 1, 6, 0, 4, 6, "1a4a9a"], ["grid", 274, 44, 9, 1, 6, 0, 4, 6, "1a4a9a"],
			["arch", 166, 176, 94, 82, "0a2a5a"],
			["rect", 100, 100, 226, 4, "d8b040"], ["rect", 100, 140, 226, 4, "d8b040"],
			["grid", 104, 108, 9, 2, 24, 14, 12, 7, "e8d890"], ["grid", 104, 56, 2, 4, 28, 18, 18, 9, "e8d890"],
			["grid", 278, 56, 2, 4, 28, 18, 18, 9, "e8d890"],
			["ground", 176, "noise", "c8a468", "a88848", "e8cc88", 21],
		],
		"mid": [
			["palm", 66, 176, 62], ["palm", 360, 176, 66],
			["flag", 28, 176, 82, 34, 20, "c02020", "f4f4f0", "tri:1a1a1a"],
			["travel", "camel", 174, 8, 0.9, 2, 5, "b88a50", "8a6030"],
			["formation", 100, 330, 182, 26, "iraqi", 10],
		],
		"fx": [
			["snow", 30, "e8d098", 10, 14],
		],
	}

static func _bin_laden() -> Dictionary:
	return {
		"name": "TORA BORA · MONTAÑAS BLANCAS",
		"back": [
			["sky", ["8aa8c0", "a4bcd0", "bcd0dc", "d4e0e4", "e8ece4"], 176],
			["mount", 120, 90, "c8d0d8", 1.2, "ffffff", 1.2], ["mount", 150, 80, "8a8470", 3.5, "e8e8e8", 1.6],
			["mount", 176, 60, "6a6454", 6.0, "", 2.0],
			["arch", 58, 176, 24, 30, "121010"], ["arch", 316, 176, 34, 38, "121010"],
			["tent", 30, 176, 30, 16, "6a6048", "5a5038"], ["tent", 396, 176, 34, 18, "6a6048", "5a5038"],
			["ground", 176, "noise", "a89878", "7a6c54", "c8b890", 23],
		],
		"mid": [
			["fire", 40, 182, 8], ["smoke", 40, 170, 4, "8a8480", 40, 1.0],
			["travel", "camel", 174, -6, 0.85, 2, 6, "b89060", "8a6a40"],
			["patrol", "sheep", 184, 200, 300, 12, 1.0, 0.3, "c8c0b0"],
			["formation", 100, 340, 182, 28, "mujahid", 11],
		],
		"fx": [
			["snow", 20, "ffffff", 8, 6],
		],
	}

static func _napoleon() -> Dictionary:
	return {
		"name": "AUSTERLITZ · CAMPO DE BATALLA",
		"back": [
			["sky", ["7a8aa8", "96a0b4", "b4b0b8", "d0b8a8", "e8c0a0"], 176],
			["disc", 330, 62, 14, "ffe0a0", "fff0c8"],
			["mount", 150, 50, "6a7a8a", 2.2, "", 0.7], ["mount", 176, 36, "5a7a4a", 4.5, "", 0.9],
			["tree", 30, 176, 44, "3a6a3a"], ["tree", 396, 176, 50, "3a6a3a"],
			["ground", 176, "noise", "6a7a3a", "4a5a2a", "8a9a4a", 25],
			["formation", 70, 360, 174, 15, "musket", 12, 0.9, 2, 5],
		],
		"mid": [
			["clouds", 4, 3, 10, 50, "d8c8c0", "a89aa0", 1.5],
			["flag", 213, 176, 92, 32, 20, "2a4aa0", "f4f4f4", "vtri:c02020"],
			["sprite", "cannon", 58, 188, 1.25, 1], ["cannonfire", 58, 188, 1, 4.0, 0.2],
			["sprite", "cannon", 372, 188, 1.25, -1], ["cannonfire", 372, 188, -1, 5.5, 0.7],
			["travel", "horse", 178, 26, 0.9, 3, 2, "f0f0e8", "c8c0b0", "musket"],
			["formation", 90, 340, 186, 24, "musket", 13],
		],
		"fx": [
			["smoke", 30, 176, 5, "8a8480", 70, 2.0], ["smoke", 400, 176, 5, "8a8480", 70, 2.0],
		],
	}

static func _gengis() -> Dictionary:
	return {
		"name": "LA ESTEPA MONGOLA",
		"back": [
			["sky", ["3a78c8", "5a94d8", "7eb0e4", "a4cbee", "c8dff2"], 176],
			["mount", 150, 26, "8aa860", 2.0, "", 0.5], ["mount", 170, 18, "7a9a50", 5.0, "", 0.6],
			["yurt", 50, 172, 36, "f0ece0", "c8b898"], ["yurt", 100, 170, 30, "f0ece0", "c8b898"],
			["yurt", 350, 172, 38, "f0ece0", "c8b898"], ["yurt", 396, 170, 30, "f0ece0", "c8b898"],
			["ground", 176, "noise", "9ca858", "7a8a40", "bcc878", 27],
		],
		"mid": [
			["clouds", 5, 5, 12, 60, "ffffff", "c8d8ec", 2.0],
			["birds", 2, 6, 20, 60, 10, "3a2a1a", 1.6],
			["flag", 213, 176, 92, 22, 14, "1a1a1a", "3a3a3a"],
			["travel", "horse", 178, 44, 1.0, 3, 7, "7a5028", "1a1208", "mongol"],
			["travel", "horse", 186, -36, 0.95, 2, 9, "d8d0c0", "3a3a3a", "mongol"],
			["formation", 110, 330, 176, 30, "mongol", 13],
		],
		"fx": [
			["snow", 18, "f0f0c0", 5, 12],
		],
	}

static func _fidel() -> Dictionary:
	return {
		"name": "SIERRA MAESTRA · CUBA",
		"back": [
			["sky", ["4a9ab8", "7ab8c0", "a8d0b8", "e8d890", "f8c070"], 176],
			["mount", 150, 80, "2a5a3a", 1.7, "", 1.0], ["mount", 176, 50, "1e4a2a", 4.3, "", 1.3],
			["rect", 0, 134, 426, 34, "a8d0b840"],
			["rect", 300, 150, 36, 26, "8a6a40"], ["tent", 318, 150, 48, 14, "6a4a20", "5a3a18"],
			["palm", 70, 176, 62], ["palm", 350, 176, 70],
			["ground", 176, "noise", "5a7a3a", "3a5a28", "7a9a4a", 29],
		],
		"mid": [
			["palm", 40, 176, 88], ["palm", 384, 176, 98],
			["flag", 212, 176, 88, 34, 18, "1a1a1a", "c02020"],
			["birds", 3, 8, 24, 70, 12, "1a3a2a"],
			["formation", 100, 340, 182, 24, "guerrilla", 14],
		],
		"fx": [
			["embers", 18, "f0f080", 4],
		],
	}

static func _cleopatra() -> Dictionary:
	return {
		"name": "GIZA · EL REINO DEL NILO",
		"back": [
			["sky", ["e8a458", "f0b868", "f4cc80", "f8e0a0", "fcf0c8"], 176],
			["disc", 90, 56, 20, "ffe090", "fff0b8"],
			["pyramid", 190, 170, 60, "e0bc80", "c0a060"], ["pyramid", 280, 174, 124, "d8b070", "b8904c"],
			["pyramid", 372, 174, 82, "d8b070", "b8904c"],
			["rect", 52, 90, 8, 86, "c8a860"], ["poly", [52, 90, 56, 78, 60, 90], "e8c878"],
			["waves", 168, 8, "2a78a8", "3a90b8", "7ac8e0"],
			["ground", 176, "noise", "e0c078", "c0a058", "f0d898", 31],
		],
		"mid": [
			["palm", 22, 176, 72], ["palm", 404, 176, 62],
			["sprite", "sphinx", 92, 180, 1.4, 1, "d0a860"],
			["birds", 3, 9, 24, 60, 10, "2a2218"],
			["patrol", "camel", 182, 60, 360, 30, 0.9, 0.2, "c8a060", "a88040"],
			["formation", 130, 340, 184, 30, "egypt", 15],
		],
		"fx": [
			["snow", 24, "f0d890", 8, 14],
		],
	}
