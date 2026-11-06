## Escenarios temáticos (parte D): filósofos, estrategas, científicos y soldados.
## Ver stage_defs_a.gd para el formato.
class_name StageDefsD
extends RefCounted

static func get_def(id: StringName) -> Dictionary:
	match id:
		&"socrates": return _socrates()
		&"platon": return _platon()
		&"aristoteles": return _aristoteles()
		&"sun_tzu": return _sun_tzu()
		&"confucio": return _confucio()
		&"isaac_newton": return _newton()
		&"hernan_cortes": return _cortes()
		&"moctezuma_ii": return _moctezuma()
		&"nicolas_maquiavelo": return _maquiavelo()
		&"mariya_oktyabrskaya": return _mariya()
		&"liudmila_pavlichenko": return _liudmila()
		&"nostradamus": return _nostradamus()
		&"el_nexo": return _nexo()
		&"stephen_hawking": return _hawking()
		&"alan_turing": return _turing()
		&"nelson_mandela": return _mandela()
		&"martin_luther_king": return _king()
		&"dalai_lama": return _dalai()
		&"jacobo_grinberg": return _grinberg()
	return {}

static func _nexo() -> Dictionary:
	return {
		"name": "LA TORRE DEL RELOJ",
		"back": [
			["sky", ["05020a", "0a0415", "12081f", "1c0c2c", "2a1238"], 176],
			["stars", 60, 3, 120, "ffe8a0"],
			["glow", 213, 90, 120, "ffd24a", 0.22],
			["disc", 213, 70, 26, "ffd24a", "fff4c0"],
			["poly", [196, 0, 206, 60, 200, 110, 213, 176, 226, 110, 220, 60, 230, 0], "2a1238"],
			["poly", [206, 0, 211, 60, 208, 110, 213, 150, 218, 110, 215, 60, 220, 0], "ffd24a"],
			["rect", 30, 120, 18, 56, "160c1c"], ["rect", 370, 108, 22, 68, "160c1c"],
			["gear", 90, 104, 34, "5e4216", 0.5], ["gear", 336, 104, 34, "5e4216", -0.5],
			["ground", 176, "noise", "0c060f", "1a0c22", "2a1238", 97],
		],
		"mid": [
			["glow", 213, 176, 70, "9a4dff", 0.2],
		],
		"fx": [
			["embers", 26, "ffd24a", 14],
		],
	}

static func _socrates() -> Dictionary:
	return {
		"name": "ATENAS · EL ÁGORA",
		"back": [
			["sky", ["4a8ad8", "68a2e2", "88baea", "aad0f0", "cce4f4"], 176],
			["disc", 360, 40, 14, "fff4c0"],
			["mount", 128, 46, "a89878", 2.1, "", 0.7],
			["rect", 132, 84, 162, 6, "e8e0c8"], ["tent", 213, 84, 166, 16, "f0e8d4", "d8d0bc"],
			["col", 142, 90, 128, 7, "f0e8d4", "c8bea4", "fffaea"], ["col", 166, 90, 128, 7, "f0e8d4", "c8bea4", "fffaea"],
			["col", 190, 90, 128, 7, "f0e8d4", "c8bea4", "fffaea"], ["col", 214, 90, 128, 7, "f0e8d4", "c8bea4", "fffaea"],
			["col", 238, 90, 128, 7, "f0e8d4", "c8bea4", "fffaea"], ["col", 262, 90, 128, 7, "f0e8d4", "c8bea4", "fffaea"],
			["col", 286, 90, 128, 7, "f0e8d4", "c8bea4", "fffaea"],
			["rect", 128, 128, 170, 4, "d8d0bc"],
			["tree", 40, 176, 52, "6a8a4a", "6a5a3a"], ["tree", 86, 176, 38, "7a9a5a", "6a5a3a"],
			["tree", 380, 176, 50, "6a8a4a", "6a5a3a"],
			["rect", 300, 150, 70, 26, "e0d4b8"], ["grid", 306, 156, 4, 2, 16, 10, 6, 6, "8a7a60"],
			["ground", 176, "slabs", "d8c8a4", "a8987a", "7a6a50", 91],
		],
		"mid": [
			["clouds", 4, 11, 8, 50, "ffffff", "d4e0ec", 1.5],
			["birds", 3, 12, 20, 70, 12, "3a3a3a", 1.0],
			["banner", 120, 134, 14, 30, "3a5a9a", "e8c040", "e8c040"],
			["formation", 50, 380, 184, 30, "robe", 92, 1.0, 1, 4, false, 0, "staff"],
		],
	}

static func _platon() -> Dictionary:
	return {
		"name": "LA CAVERNA DE PLATÓN",
		"back": [
			["sky", ["0c0a10", "141018", "1c1620", "261e26", "30262a"], 176],
			["poly", [0, 0, 426, 0, 426, 40, 340, 60, 260, 34, 170, 56, 80, 30, 0, 50], "1a1418"],
			["mount", 176, 90, "2a2026", 3.3, "", 1.3],
			["rect", 150, 60, 126, 90, "4a3a34"], ["rect", 156, 66, 114, 78, "5a4a40"],
			["glow", 213, 150, 80, "ff9040", 0.25],
			["ground", 176, "noise", "3a2e28", "2a201c", "4a3a30", 93],
		],
		"mid": [
			["fire", 213, 168, 16, 6.0],
			["smoke", 213, 150, 4, "3a3030", 40.0, 0.8],
			["flicker", 213, 110, 60, "ff9040"],
			["formation", 60, 370, 186, 34, "robe", 94, 1.0, 1, 4, false, -1, "none"],
		],
		"fx": [
			["embers", 14, "ffb040", 10],
		],
	}

static func _aristoteles() -> Dictionary:
	return {
		"name": "EL LICEO · ATENAS",
		"back": [
			["sky", ["e8a060", "eeb878", "f4cc90", "f8dcaa", "fbe8c4"], 176],
			["disc", 90, 112, 22, "fff0b0", "ffffe0"],
			["mount", 132, 40, "b08a6a", 4.6, "", 0.8],
			["rect", 0, 96, 426, 6, "e8dcc0"], ["rect", 0, 102, 426, 3, "c8bca0"],
			["col", 24, 105, 160, 8, "f0e6cc", "c8bca0", "fff8e6"], ["col", 76, 105, 160, 8, "f0e6cc", "c8bca0", "fff8e6"],
			["col", 128, 105, 160, 8, "f0e6cc", "c8bca0", "fff8e6"], ["col", 298, 105, 160, 8, "f0e6cc", "c8bca0", "fff8e6"],
			["col", 350, 105, 160, 8, "f0e6cc", "c8bca0", "fff8e6"], ["col", 402, 105, 160, 8, "f0e6cc", "c8bca0", "fff8e6"],
			["rect", 0, 160, 426, 4, "d8ccb0"],
			["tree", 213, 160, 46, "6a8a4a", "6a5a3a"],
			["ground", 176, "slabs", "d0c09c", "a09070", "7a6a50", 95],
		],
		"mid": [
			["clouds", 3, 13, 10, 40, "fff4e0", "f0d8b8", 1.2],
			["orbit", 360, 40, 26, 8, 6.0, 3, "e8d0a0"],
			["birds", 4, 14, 24, 80, 14, "4a3a2a", 1.0],
			["formation", 60, 370, 184, 30, "robe", 96, 1.0, 1, 4, true, 0, "staff"],
		],
	}

static func _sun_tzu() -> Dictionary:
	return {
		"name": "REINO DE WU · CAMPO DE BATALLA",
		"back": [
			["sky", ["b8c4c4", "c4cec8", "d0d6cc", "dcdcd0", "e6e2d4"], 176],
			["mount", 120, 80, "8a9a96", 5.4, "", 1.4], ["mount", 140, 56, "6a7a74", 1.7, "", 1.1],
			["mount", 160, 34, "4a5a50", 8.2, "", 0.9],
			["tower", 340, 160, 26, 64, "8a2a20", "6a1a14", "2a3a30"],
			["tent", 90, 172, 46, 30, "c8b890", "a89870"], ["tent", 140, 172, 40, 26, "c8b890", "a89870"],
			["ground", 176, "noise", "8a8a5a", "6a6a40", "4a4a2a", 97],
		],
		"mid": [
			["clouds", 5, 15, 30, 80, "eef0ec", "d0d4d0", 1.0],
			["flag", 40, 176, 92, 30, 18, "c02828", "1a1a1a"],
			["flag", 386, 176, 92, 30, 18, "c02828", "1a1a1a"],
			["patrol", "horse", 186, 60, 360, 34, 1.0, 0.4, "5a3a22", "c02828"],
			["formation", 60, 370, 184, 26, "chinese", 98, 1.0, 1, 4, true, 0, "spear"],
		],
	}

static func _confucio() -> Dictionary:
	return {
		"name": "TEMPLO DE CONFUCIO · QUFU",
		"back": [
			["sky", ["7aa8c8", "94bad2", "aecadc", "c6d8e4", "dce6ec"], 176],
			["mount", 120, 44, "7a8a90", 2.6, "", 0.8],
			["rect", 96, 108, 234, 52, "a82820"], ["rect", 96, 108, 234, 3, "c84030"],
			["tent", 213, 108, 260, 26, "2a5a4a", "1a4a3a"], ["rect", 84, 104, 258, 4, "e8c040"],
			["grid", 110, 120, 8, 2, 26, 18, 12, 12, "5a1410"],
			["rect", 188, 130, 50, 30, "3a1a10"],
			["rect", 150, 160, 126, 4, "d8d0c0"], ["rect", 140, 164, 146, 4, "c8c0b0"], ["rect", 130, 168, 166, 8, "b8b0a0"],
			["pine", 40, 176, 84, "2a5a3a"], ["pine", 386, 176, 84, "2a5a3a"],
			["ground", 176, "slabs", "c8c0b0", "9a9080", "6a6050", 99],
		],
		"mid": [
			["clouds", 3, 16, 8, 40, "f4f6f8", "d0d8e0", 1.2],
			["glow", 120, 118, 8, "ffd060", 0.3], ["glow", 306, 118, 8, "ffd060", 0.3],
			["banner", 64, 120, 14, 40, "a82820", "e8c040", "e8c040"], ["banner", 348, 120, 14, 40, "a82820", "e8c040", "e8c040"],
			["birds", 3, 17, 20, 70, 10, "2a2a2a", 1.0],
			["formation", 60, 370, 184, 30, "robe", 100, 1.0, 1, 4, false, 0, "none"],
		],
		"fx": [
			["snow", 24, "ffc8d8", 14, 10],
		],
	}

static func _newton() -> Dictionary:
	return {
		"name": "WOOLSTHORPE · EL MANZANO",
		"back": [
			["sky", ["5a92d0", "78a8da", "98bee4", "b8d2ec", "d4e4f2"], 176],
			["disc", 70, 42, 14, "fff4c0"],
			["mount", 136, 30, "6a9a4a", 3.0, "", 0.6], ["mount", 156, 22, "5a8a3a", 6.4, "", 0.8],
			["rect", 260, 118, 86, 42, "c8b48a"], ["tent", 303, 118, 96, 22, "6a4a3a", "5a3a2a"],
			["grid", 268, 126, 4, 2, 20, 16, 8, 10, "3a4a6a"], ["rect", 296, 144, 14, 16, "4a3020"],
			["tree", 140, 176, 110, "3a7a2a", "5a3a22"],
			["circle", 120, 92, 3, "d82020"], ["circle", 150, 84, 3, "d82020"], ["circle", 132, 110, 3, "d82020"],
			["circle", 162, 104, 3, "d82020"], ["circle", 108, 106, 3, "d82020"], ["circle", 144, 120, 3, "c81818"],
			["ground", 176, "noise", "5a8a3a", "3a6a28", "6a9a4a", 101],
		],
		"mid": [
			["clouds", 4, 18, 8, 50, "ffffff", "d0dce8", 1.6],
			["patrol", "sheep", 186, 220, 400, 50, 0.9, 0.2, "f0ece0"],
			["orbit", 380, 34, 20, 7, 5.0, 2, "d82020"],
			["birds", 3, 19, 24, 70, 12, "2a2a2a", 1.0],
			["formation", 30, 100, 184, 30, "scientist", 102, 1.0, 1, 4, false, 1, "none"],
		],
	}

static func _cortes() -> Dictionary:
	return {
		"name": "VERACRUZ · 1519",
		"back": [
			["sky", ["f4a060", "f6b878", "f8cc90", "fadcac", "fce8c8"], 176],
			["disc", 300, 120, 20, "fff0b0", "ffffe0"],
			["waves", 122, 54, "2a6a9a", "3a80b0", "ffd8a0"],
			["palm", 40, 176, 70], ["palm", 74, 176, 54], ["palm", 392, 176, 66],
			["ground", 176, "noise", "e0c890", "c8b078", "f0dca8", 103],
		],
		"mid": [
			["travel", "ship", 126, 6, 0.7, 2, 4, "5a3a22", "f0ece0"],
			["patrol", "ship", 142, 140, 330, 70, 1.2, 0.0, "6a3a20", "f0ece0"],
			["birds", 4, 20, 20, 80, 14, "f4f4f0", 1.0],
			["flag", 213, 176, 94, 30, 20, "f0f0e8", "c02020"],
			["formation", 60, 370, 184, 30, "conquistador", 104, 1.0, 1, 4, false, 0, "halberd"],
		],
	}

static func _moctezuma() -> Dictionary:
	return {
		"name": "TENOCHTITLÁN · TEMPLO MAYOR",
		"back": [
			["sky", ["4a90c8", "6aa6d4", "8cbcdc", "aed0e2", "cce0e6"], 176],
			["mount", 120, 74, "6a7a8a", 2.2, "f4f6f8", 1.0], ["mount", 132, 40, "5a6a5a", 5.8, "", 0.8],
			["waves", 140, 36, "3a7a8a", "4a8a9a", "c8e4e8"],
			["rect", 133, 150, 160, 26, "b8a080"], ["rect", 145, 132, 136, 18, "c8b090"],
			["rect", 157, 114, 112, 18, "b8a080"], ["rect", 169, 98, 88, 16, "c8b090"],
			["rect", 205, 98, 16, 78, "8a7058"], ["grid", 207, 100, 1, 15, 0, 5, 12, 2, "6a5040"],
			["rect", 172, 78, 30, 20, "e8e0d0"], ["rect", 172, 72, 30, 6, "c02828"],
			["rect", 224, 78, 30, 20, "e8e0d0"], ["rect", 224, 72, 30, 6, "2a6ab0"],
			["ground", 176, "slabs", "c8b090", "9a8064", "6a5440", 105],
		],
		"mid": [
			["clouds", 4, 21, 8, 44, "ffffff", "d0dce4", 1.4],
			["smoke", 187, 70, 4, "e8e0d0", 40.0, 0.6], ["smoke", 239, 70, 4, "e8e0d0", 40.0, 0.6],
			["birds", 2, 22, 20, 60, 10, "3a3a2a", 1.2],
			["banners", 40, 3, 30, 120, 12, 30, "2a8a7a", "e8c040", "e04030"],
			["banners", 322, 3, 30, 120, 12, 30, "2a8a7a", "e8c040", "e04030"],
			["formation", 50, 380, 184, 30, "mexica", 106, 1.0, 1, 4, false, 0, "spear"],
		],
	}

static func _maquiavelo() -> Dictionary:
	return {
		"name": "FLORENCIA · PIAZZA DELLA SIGNORIA",
		"back": [
			["sky", ["5a8ac8", "78a0d0", "98b8dc", "b8cee6", "d8e2ee"], 176],
			["mount", 130, 36, "6a8a6a", 3.6, "", 0.7],
			["skyline", 150, "c8885a", 107, 18, 34, 20, 44, "3a2a20", false, true],
			["dome", 150, 112, 26, "c86a3a", "a85028", "e8c040"], ["rect", 124, 112, 52, 30, "e8dcc4"],
			["tower", 290, 150, 18, 104, "c8a878", "a88858", "6a5a40"],
			["rect", 250, 110, 80, 50, "d8c098"], ["grid", 256, 118, 6, 2, 12, 16, 6, 10, "3a2a20"],
			["ground", 176, "slabs", "b8a888", "8a7a60", "5a4a38", 108],
		],
		"mid": [
			["clouds", 3, 23, 8, 40, "ffffff", "d8e0e8", 1.3],
			["flag", 290, 46, 20, 18, 12, "f0f0e8", "c02020"],
			["birds", 4, 24, 20, 70, 14, "2a2a2a", 1.0],
			["formation", 50, 380, 184, 30, "florentine", 109, 1.0, 1, 4, false, 0, "none"],
		],
	}

static func _mariya() -> Dictionary:
	return {
		"name": "FRENTE ORIENTAL · 1943",
		"back": [
			["sky", ["6a6a70", "7a7a80", "8a8a8e", "9a9a9c", "acaaa8"], 176],
			["skyline", 150, "4a4a50", 110, 16, 34, 30, 70, "", true],
			["skyline", 164, "3a3a3e", 111, 12, 26, 14, 40, "", true],
			["ground", 176, "noise", "6a6250", "4a4436", "8a8270", 112],
		],
		"mid": [
			["clouds", 5, 25, 6, 40, "8a8a90", "6a6a70", 2.0],
			["smoke", 80, 140, 6, "3a3634", 60.0, 1.2], ["smoke", 340, 130, 6, "3a3634", 60.0, 1.2],
			["patrol", "tank", 168, 40, 380, 40, 1.0, 0.3, "4a5a30"],
			["flag", 213, 176, 92, 30, 18, "c02020", "c02020"],
			["formation", 60, 370, 184, 30, "soviet", 113, 1.0, 1, 4, true, 0, "rifle"],
		],
		"fx": [
			["snow", 60, "f0f0f0", 24, 10],
			["embers", 10, "ff8030", 10],
		],
	}

static func _liudmila() -> Dictionary:
	return {
		"name": "SEBASTOPOL · 1942",
		"back": [
			["sky", ["8a7a6a", "9a8a78", "aa9a86", "bcaa94", "ccbca4"], 176],
			["waves", 118, 30, "3a5a6a", "4a6a7a", "a8b8c0"],
			["mount", 150, 46, "7a6a58", 4.2, "", 1.2],
			["skyline", 158, "5a5248", 114, 14, 30, 16, 40, "", true],
			["rects", [[30, 164, 20, 6, "a09060"], [52, 164, 20, 6, "8a7a50"], [40, 158, 20, 6, "a09060"],
				[350, 164, 20, 6, "a09060"], [372, 164, 20, 6, "8a7a50"], [362, 158, 20, 6, "a09060"]]],
			["ground", 176, "noise", "8a7a58", "6a5a40", "9a8a68", 115],
		],
		"mid": [
			["clouds", 4, 26, 6, 40, "b8aa98", "9a8c7c", 1.6],
			["smoke", 120, 150, 5, "4a4440", 50.0, 1.0], ["smoke", 300, 146, 5, "4a4440", 50.0, 1.0],
			["flag", 213, 176, 92, 30, 18, "c02020", "c02020"],
			["birds", 3, 27, 20, 70, 12, "2a2a2a", 1.0],
			["formation", 80, 350, 184, 34, "soviet", 116, 1.0, 1, 4, false, 0, "rifle"],
		],
		"fx": [
			["embers", 12, "ff9040", 12],
		],
	}

static func _nostradamus() -> Dictionary:
	return {
		"name": "SALON-DE-PROVENCE · OBSERVATORIO",
		"back": [
			["sky", ["05061a", "0a0e2a", "141a3c", "1e2650", "2a3262"], 176],
			["stars", 70, 3, 120, "fff0c0"],
			["disc", 300, 40, 14, "e8e4d0", "fffbe8"],
			["mount", 140, 30, "1a1a3a", 3.6, "", 0.8],
			["tower", 110, 120, 22, 80, "3a3a5a", "2a2a48", "1a1a30"],
			["dome", 110, 120, 20, "4a4a7a", "3a3a62", "c0a040"],
			["ground", 176, "slabs", "4a4a5a", "3a3a4a", "2a2a38", 120],
		],
		"mid": [
			["birds", 3, 24, 20, 60, 14, "1a1a2a", 1.0],
		],
	}

static func _hawking() -> Dictionary:
	return {
		"name": "CAMBRIDGE · 1974",
		"back": [
			["sky", ["05020f", "0a0420", "140838", "1e0e50", "2a1668"], 176],
			["stars", 70, 3, 120, "ffe8ff"],
			["glow", 213, 80, 110, "9a4dff", 0.22],
			["disc", 213, 70, 24, "07030f", "1a0a30"],
			["rect", 40, 112, 96, 64, "2a2a3a"], ["tent", 88, 112, 106, 24, "3a3a4a", "2a2a3a"],
			["grid", 48, 122, 5, 2, 16, 16, 8, 10, "e8d890"],
			["rect", 300, 124, 80, 52, "2a2a3a"], ["grid", 306, 132, 4, 2, 17, 14, 7, 8, "e8d890"],
			["ground", 176, "noise", "1a1a2a", "10101c", "2a2a40", 201],
		],
		"mid": [
			["orbit", 213, 70, 38, 12, 3.0, 2, "ffd070"],
			["birds", 2, 19, 24, 70, 12, "2a2a2a", 0.6],
		],
	}

static func _turing() -> Dictionary:
	return {
		"name": "BLETCHLEY PARK · 1942",
		"back": [
			["sky", ["5a6a7a", "6e7e8e", "8292a2", "98a8b6", "b0bfcb"], 176],
			["clouds", 5, 18, 8, 50, "c8d0d8", "a8b2bc", 1.2],
			["rect", 80, 96, 150, 80, "8a5a3a"], ["tent", 155, 96, 164, 26, "4a3a32", "3a2e28"],
			["grid", 90, 108, 8, 3, 16, 16, 8, 10, "e8d890"],
			["rect", 270, 120, 100, 56, "7a4e32"], ["tent", 320, 120, 110, 18, "4a3a32", "3a2e28"],
			["grid", 280, 130, 5, 2, 16, 14, 8, 8, "e8d890"],
			["tree", 40, 176, 100, "3a5a2a", "3a2a1a"], ["tree", 395, 176, 90, "3a5a2a", "3a2a1a"],
			["ground", 176, "noise", "4a5a38", "36442a", "5a6a46", 202],
		],
		"mid": [
			["birds", 3, 19, 24, 70, 12, "2a2a2a", 1.0],
			["formation", 30, 120, 184, 30, "scientist", 203, 1.0, 1, 4, false, 1, "none"],
		],
	}

static func _mandela() -> Dictionary:
	return {
		"name": "PRETORIA · 1994",
		"back": [
			["sky", ["4a8ad0", "68a2dc", "88bae6", "a8d0ee", "c8e2f4"], 176],
			["disc", 340, 44, 16, "fff4c0"],
			["rect", 120, 100, 180, 76, "d8c8a0"], ["tent", 210, 100, 196, 24, "8a6a4a", "6a4a32"],
			["grid", 132, 112, 8, 2, 20, 22, 12, 12, "5a4a3a"],
			["rect", 60, 124, 36, 52, "d8c8a0"], ["rect", 324, 124, 36, 52, "d8c8a0"],
			["palm", 36, 176, 70], ["palm", 400, 176, 62],
			["ground", 176, "noise", "7a9a4a", "5a7a36", "8aaa58", 204],
		],
		"mid": [
			["clouds", 4, 18, 8, 50, "ffffff", "d8e4f0", 1.6],
			["flag", 213, 176, 96, 30, 20, "20a050", "f0d020"],
			["birds", 3, 19, 24, 70, 12, "2a2a2a", 1.0],
		],
	}

static func _king() -> Dictionary:
	return {
		"name": "WASHINGTON · 1963",
		"back": [
			["sky", ["5a98d8", "74aee2", "90c2ea", "acd4f0", "c8e4f6"], 176],
			["clouds", 4, 18, 8, 50, "ffffff", "d8e4f0", 1.4],
			["rect", 100, 96, 226, 80, "e8e4d8"], ["tent", 213, 96, 240, 24, "d0ccc0", "b8b4a8"],
			["rect", 112, 106, 12, 70, "f4f0e4"], ["rect", 152, 106, 12, 70, "f4f0e4"], ["rect", 192, 106, 12, 70, "f4f0e4"],
			["rect", 232, 106, 12, 70, "f4f0e4"], ["rect", 272, 106, 12, 70, "f4f0e4"], ["rect", 306, 106, 12, 70, "f4f0e4"],
			["tree", 40, 176, 100, "3a7a2a", "5a3a22"], ["tree", 396, 176, 96, "3a7a2a", "5a3a22"],
			["ground", 176, "noise", "7a9a58", "5a7a40", "8aaa68", 205],
		],
		"mid": [
			["birds", 4, 19, 24, 70, 12, "2a2a2a", 1.0],
			["formation", 30, 370, 184, 24, "scientist", 206, 1.0, 1, 4, false, 1, "none"],
		],
	}

static func _dalai() -> Dictionary:
	return {
		"name": "DHARAMSALA · HIMALAYA",
		"back": [
			["sky", ["7a9ad0", "98b4dc", "b4cce6", "d0e0f0", "e8f0f8"], 176],
			["disc", 90, 46, 16, "fff4d0"],
			["mount", 150, 70, "e8eef6", 2.4, "", 0.5], ["mount", 164, 54, "b8c8dc", 5.2, "", 0.7],
			["mount", 176, 36, "6a7a8a", 3.6, "", 0.9],
			["rect", 150, 112, 120, 64, "a02828"], ["tent", 210, 112, 134, 26, "e0a020", "c08818"],
			["grid", 160, 124, 5, 2, 18, 16, 8, 10, "f0d070"],
			["ground", 176, "noise", "8a8a6a", "6a6a52", "a0a07e", 207],
		],
		"mid": [
			["clouds", 5, 18, 8, 50, "ffffff", "d8e4f0", 1.0],
			["flag", 92, 176, 70, 24, 16, "2a60c0", "e0c020"],
			["flag", 330, 176, 70, 24, 16, "c02020", "f0f0f0"],
			["birds", 3, 19, 24, 70, 12, "2a2a2a", 1.0],
		],
	}

static func _grinberg() -> Dictionary:
	return {
		"name": "CIUDAD UNIVERSITARIA · MÉXICO",
		"back": [
			["sky", ["3a2a5a", "6a3a6a", "a85a70", "d88a6a", "f0b878"], 176],
			["disc", 330, 52, 14, "ffe8b0"],
			["mount", 120, 80, "e8eef6", 2.6, "", 0.5], ["mount", 136, 62, "8a7a9a", 5.0, "", 0.7],
			["mount", 176, 40, "4a3a5a", 3.4, "", 0.9],
			["rect", 130, 100, 160, 76, "9a7a5a"], ["tent", 210, 100, 176, 20, "6a4a3a", "523830"],
			["grid", 142, 110, 7, 3, 20, 16, 10, 10, "f0d890"],
			["palm", 60, 176, 70], ["palm", 380, 176, 64],
			["ground", 176, "noise", "7a6a4a", "5a4c36", "8a7a58", 208],
		],
		"mid": [
			["birds", 3, 24, 20, 60, 14, "2a1a2a", 1.0],
		],
	}

