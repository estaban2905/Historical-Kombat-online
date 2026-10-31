## Escenarios temáticos (parte B). Ver stage_defs_a.gd para el formato.
class_name StageDefsB
extends RefCounted

static func get_def(id: StringName) -> Dictionary:
	match id:
		&"alejandro_magno": return _alejandro()
		&"isabel_ii": return _isabel()
		&"abraham_lincoln": return _lincoln()
		&"jesus_de_nazaret": return _jesus()
		&"buda": return _buda()
		&"papa_francisco": return _papa()
		&"rasputin": return _rasputin()
		&"pablo_escobar": return _escobar()
		&"albert_einstein": return _einstein()
		&"nikola_tesla": return _tesla()
		&"leonardo_da_vinci": return _da_vinci()
		&"marie_curie": return _curie()
		&"galileo_galilei": return _galileo()
		&"charles_darwin": return _darwin()
		&"cristobal_colon": return _colon()
	return {}

static func _alejandro() -> Dictionary:
	return {
		"name": "GAUGAMELA · EL EJÉRCITO MACEDONIO",
		"back": [
			["sky", ["b8783c", "c88a48", "d89c58", "e8b070", "f4c888"], 176],
			["disc", 70, 50, 14, "fff0c0"],
			["mount", 150, 40, "9a7248", 2.5, "", 0.7], ["mount", 176, 26, "8a6a40", 5.2, "", 0.8],
			["tent", 40, 176, 44, 28, "c8a040", "a08030"], ["tent", 340, 176, 50, 32, "c8a040", "a08030"],
			["tent", 392, 176, 40, 26, "b83030", "901818"],
			["ground", 176, "noise", "b08a58", "8a6a40", "d0aa70", 33],
			["formation", 12, 420, 172, 14, "hoplite", 16, 0.85, 3, 4, false, 0, "pike"],
		],
		"mid": [
			["clouds", 4, 4, 12, 60, "d8a870", "b08850", 2.0],
			["flag", 213, 176, 94, 28, 18, "7a2a8a", "e6b43c"],
			["patrol", "elephant", 186, 50, 370, 36, 1.0, 0.1, "7a7a80", "", "hoplite"],
			["sprite", "horse", 380, 186, 1.15, -1, "f4f0e8", "d8d0c0", "hoplite"],
			["formation", 80, 340, 184, 32, "hoplite", 17, 1.0, 1, 4, false, 0, "spear"],
		],
		"fx": [
			["embers", 20, "d8a060", 5],
		],
	}

static func _isabel() -> Dictionary:
	return {
		"name": "PALACIO DE BUCKINGHAM · LONDRES",
		"back": [
			["sky", ["8a98a8", "9aa6b4", "aab4c0", "bcc4cc", "ccd2d8"], 176],
			["rect", 340, 24, 32, 152, "b89c58"], ["rect", 340, 20, 32, 6, "9a8244"],
			["tent", 356, 22, 38, 26, "6a7a6a", "5a6a5a"], ["circle", 356, 42, 8, "e8e0c0"],
			["ring", 356, 42, 8, "5a4a2a"],
			["rect", 40, 100, 346, 76, "d8d0b8"], ["rect", 40, 92, 346, 8, "a8a090"],
			["tent", 213, 100, 70, 20, "e0d8c0", "c8c0a8"],
			["grid", 52, 110, 12, 3, 26, 20, 10, 12, "4a5060"],
			["grid", 190, 104, 5, 1, 12, 0, 4, 60, "f0e8d0"], ["rect", 190, 134, 50, 4, "b8b0a0"],
			["ground", 176, "slabs", "8a6a68", "5a4444", "3a2a2a", 35],
			["rect", 0, 160, 426, 2, "c8a030"], ["grid", 0, 162, 48, 1, 9, 0, 2, 14, "1a1a1a"],
		],
		"mid": [
			["clouds", 3, 6, 8, 40, "b8c0c8", "98a0aa", 1.5],
			["flag", 213, 100, 36, 36, 22, "1a2a8a", "", "uk"],
			["patrol", "corgi", 186, 40, 380, 22, 1.2, 0.55],
			["patrol", "corgi", 190, 60, 360, 26, 1.2, 0.1],
			["formation", 60, 380, 180, 22, "royal", 17, 1.0, 1, 4, true],
		],
		"fx": [
			["rain", 70, "b0c0d8", 200],
		],
	}

static func _lincoln() -> Dictionary:
	return {
		"name": "GETTYSBURG · 1863",
		"back": [
			["sky", ["6a7a96", "8a96a8", "aab0b8", "c8c0b0", "e0cca8"], 176],
			["mount", 160, 22, "5a7a48", 1.0, "", 0.6],
			["tree", 30, 176, 52, "3a6a38"], ["tree", 62, 176, 36, "467a42"], ["tree", 392, 176, 58, "3a6a38"],
			["tent", 108, 174, 40, 24, "e8e0d0", "c8c0b0"], ["tent", 326, 174, 40, 24, "e8e0d0", "c8c0b0"],
			["ground", 176, "noise", "7a8a4a", "5a6a34", "9aaa5a", 37],
			["rect", 0, 168, 426, 2, "6a4a2a"], ["rect", 0, 173, 426, 2, "6a4a2a"],
			["grid", 0, 165, 36, 1, 12, 0, 2, 12, "5a3a1a"],
		],
		"mid": [
			["flag", 30, 176, 86, 36, 20, "c02828", "f4f4f4", "2a3a8a"],
			["flag", 396, 176, 86, 36, 20, "8a8a90", "", "c02828"],
			["sprite", "cannon", 182, 190, 1.2, 1], ["cannonfire", 182, 190, 1, 4.5, 0.1],
			["sprite", "cannon", 244, 190, 1.2, -1], ["cannonfire", 244, 190, -1, 6.0, 0.6],
			["formation", 20, 150, 182, 20, "union", 18, 1.0, 2, 6, false, 1],
			["formation", 280, 410, 182, 20, "confed", 19, 1.0, 2, 6, false, -1],
		],
		"fx": [
			["smoke", 60, 176, 4, "7a7470", 60, 2.0],
		],
	}

static func _jesus() -> Dictionary:
	return {
		"name": "JERUSALÉN · MONTE DE LOS OLIVOS",
		"back": [
			["sky", ["f8e8b0", "f8dca0", "f4cc9c", "e8bcac", "c8b0c8"], 176],
			["disc", 330, 70, 22, "fff4c8", "ffffe8"],
			["mount", 160, 40, "b09868", 1.8, "", 0.6],
			["skyline", 176, "d8c090", 41, 16, 28, 26, 60],
			["hemi", 110, 146, 18, "e6b43c", "ffe8a0", "c8a030"],
			["wall", 146, 30, "d0b888", "a89868", true],
			["tower", 40, 176, 18, 52, "d0b888", "a89868"], ["tower", 386, 176, 18, 56, "d0b888", "a89868"],
			["tree", 20, 176, 44, "7a8a58", "6a4a2a"], ["tree", 404, 176, 50, "7a8a58", "6a4a2a"],
			["tree", 360, 176, 36, "6a7a4c", "6a4a2a"],
			["ground", 176, "noise", "c8a870", "a88850", "e0c890", 43],
		],
		"mid": [
			["glow", 213, 70, 60, "fff0b0", 0.1],
			["birds", 5, 4, 20, 90, 16, "ffffff", 1.3],
			["travel", "sheep", 184, 6, 1.0, 5, 3, "f4f0e4"],
			["formation", 110, 340, 182, 40, "robe", 20],
		],
		"fx": [
			["beams", 4, "fff4c030", 80, 350, 176],
			["embers", 12, "fff0a0", 6],
		],
	}

static func _buda() -> Dictionary:
	return {
		"name": "BODH GAYA · EL ÁRBOL DE LA ILUMINACIÓN",
		"back": [
			["sky", ["a8d8e8", "c0e4e8", "d8ecd8", "ecf0c8", "f8f0c0"], 176],
			["mount", 130, 70, "c8d8e8", 1.4, "ffffff", 1.2], ["mount", 160, 40, "88a8a0", 3.2, "", 1.0],
			["rect", 286, 100, 48, 76, "c8a870"], ["tent", 310, 100, 52, 52, "d8b880", "b89860"],
			["rect", 308, 40, 4, 12, "d8b030"], ["tent", 290, 100, 14, 22, "c8a870", "a88850"],
			["tent", 330, 100, 14, 22, "c8a870", "a88850"],
			["grid", 290, 112, 5, 4, 8, 14, 4, 8, "6a4a30"],
			["line", 30, 58, 280, 74, "5a4a3a"],
			["grid", 40, 60, 5, 1, 48, 0, 6, 5, "3a60b0"], ["grid", 50, 62, 5, 1, 48, 0, 6, 5, "e8e8e8"],
			["grid", 60, 64, 5, 1, 48, 0, 6, 5, "c03030"],
			["waves", 168, 8, "4a98a8", "5aa8b8", "9ad8e0"],
			["ground", 176, "noise", "8aaa60", "6a8a48", "a8c878", 45],
			["circle", 150, 171, 3, "f08aa8"], ["circle", 220, 173, 3, "f0a8c0"], ["circle", 300, 170, 3, "f08aa8"],
		],
		"mid": [
			["tree", 56, 176, 104, "4a9a48", "5a3a22"], ["tree", 100, 176, 62, "5aaa50", "5a3a22"],
			["birds", 4, 10, 20, 70, 10, "f4f0e0"],
			["patrol", "elephant", 184, 140, 400, 50, 0.9, 0.3, "e8e8e0", "", "monk"],
			["formation", 130, 340, 182, 34, "monk", 21],
		],
		"fx": [
			["snow", 26, "f8a8c0", 9, 14],
		],
	}

static func _papa() -> Dictionary:
	return {
		"name": "PLAZA DE SAN PEDRO · EL VATICANO",
		"back": [
			["sky", ["6aa8e8", "88bcf0", "a8d0f4", "c8e0f8", "e4f0fa"], 176],
			["hemi", 213, 92, 34, "c8c0a8", "e8e0cc", "e8e0cc"],
			["rect", 212, 30, 2, 12, "e6b43c"], ["rect", 209, 34, 8, 2, "e6b43c"],
			["rect", 130, 92, 166, 84, "e8e0cc"], ["rect", 130, 88, 166, 6, "d8d0b8"],
			["tent", 213, 94, 150, 22, "f0e8d4", "d8d0bc"],
			["grid", 138, 104, 8, 1, 20, 0, 8, 68, "f6f0e0"],
			["rect", 0, 114, 130, 6, "c8c0a8"], ["rect", 296, 114, 130, 6, "c8c0a8"],
			["rect", 0, 120, 130, 56, "b8b098"], ["rect", 296, 120, 130, 56, "b8b098"],
			["grid", 6, 120, 7, 1, 18, 0, 8, 56, "e0d8c4"], ["grid", 306, 120, 7, 1, 18, 0, 8, 56, "e0d8c4"],
			["ground", 176, "slabs", "c0b49c", "8a7e68", "6a5e48", 47],
		],
		"mid": [
			["flag", 24, 176, 84, 30, 18, "e6b43c", "f4f4f0"],
			["birds", 10, 11, 30, 150, 10, "f4f4f0", 1.1],
			["formation", 30, 400, 188, 14, "crowd", 23, 0.95],
			["formation", 100, 340, 182, 22, "swiss", 22],
		],
	}

static func _rasputin() -> Dictionary:
	return {
		"name": "SAN PETERSBURGO · NOCHE DE INVIERNO",
		"back": [
			["sky", ["0a0618", "160e2c", "241a40", "342a58", "4a3a6a"], 176],
			["stars", 60, 3, 120, "e8e0ff"],
			["disc", 340, 50, 18, "f0ecd8", "ffffff"],
			["rect", 20, 110, 386, 66, "8ab0a0"], ["rect", 20, 104, 386, 6, "e8f0e8"],
			["grid", 24, 116, 32, 1, 12, 0, 3, 52, "e8f0e8"], ["grid", 28, 122, 31, 2, 12, 20, 4, 10, "f0c860"],
			["rect", 62, 84, 16, 20, "c8d0c0"], ["dome", 70, 84, 12, "3a8a8a", "e8d870", "e6b43c"],
			["rect", 348, 84, 16, 20, "c8d0c0"], ["dome", 356, 84, 12, "b03a3a", "e8d870", "e6b43c"],
			["ground", 176, "noise", "8aa0b8", "5a7090", "c8dcf0", 49],
		],
		"mid": [
			["glow", 340, 50, 50, "d8e0ff", 0.1],
			["patrol", "wolf", 186, 30, 396, 24, 1.0, 0.0, "8a8a96"],
			["patrol", "wolf", 192, 30, 396, 20, 1.0, 0.5, "5a5a66"],
			["formation", 110, 330, 182, 36, "cossack", 24],
		],
		"fx": [
			["snow", 60, "ffffff", 18, 10],
			["embers", 10, "c070ff", 5],
			["flicker", 213, 150, 60, "b060ff"],
		],
	}

static func _escobar() -> Dictionary:
	return {
		"name": "HACIENDA NÁPOLES · COLOMBIA",
		"back": [
			["sky", ["5a4a9a", "8a5aa0", "c8708a", "f09858", "f8c070"], 176],
			["mount", 150, 70, "2a4a3a", 2.4, "", 1.0], ["mount", 176, 40, "1e3a2a", 5.1, "", 1.4],
			["rect", 30, 130, 90, 46, "e8d8b8"], ["tent", 75, 130, 100, 20, "b04838", "903828"],
			["grid", 40, 140, 4, 1, 20, 0, 8, 10, "4a3a2a"],
			["rect", 150, 100, 14, 76, "e8e0d0"], ["rect", 262, 100, 14, 76, "e8e0d0"],
			["rect", 150, 100, 126, 8, "c8c0b0"],
			["palm", 20, 176, 80], ["palm", 400, 176, 74], ["palm", 370, 176, 60],
			["waves", 166, 10, "3a6a6a", "4a7a7a", "8ab8b0"],
			["ground", 176, "noise", "8a7a50", "6a5a38", "a89868", 51],
		],
		"mid": [
			["flag", 24, 176, 86, 34, 22, "f0c020", "2a4aa0", "tri:c02020"],
			["sprite", "plane", 213, 98, 1.6, 1],
			["birds", 4, 12, 24, 80, 12, "2a2a2a"],
			["patrol", "hippo", 178, 30, 396, 60, 1.0, 0.0, "6a5a6a"],
			["sprite", "hippo", 360, 178, 1.1, -1, "7a6a7a"],
			["formation", 150, 300, 184, 28, "sicario", 25],
		],
		"fx": [
			["snow", 18, "6aa860", 14, 10],
		],
	}

static func _einstein() -> Dictionary:
	return {
		"name": "EL COSMOS · TEORÍA DE LA RELATIVIDAD",
		"back": [
			["sky", ["02020e", "06061a", "0a0a28", "10103a", "161650"], 176],
			["stars", 90, 5, 170, "ffffff", false],
			["galaxy", 90, 60, 40, "b8c0ff"], ["galaxy", 330, 110, 30, "ffc8a0"],
			["planet", 380, 40, 14, "c88a50", "e8b878", "d8c8a0"], ["planet", 40, 130, 8, "4a7ad8", "7aa8f0"],
			["rect", 138, 38, 150, 74, "6a4a2a"], ["rect", 142, 42, 142, 66, "1a2a22"],
			["text", 150, 66, "E=MC2", 16, "f0f0e0"], ["text", 150, 88, "RELATIVIDAD", 8, "c8d8c8"],
			["ground", 176, "checker", "1a1a3a", "2a2a5a", "6a6aff", 53],
		],
		"mid": [
			["glow", 213, 100, 70, "6a5aff", 0.2],
			["orbit", 213, 100, 150, 30, 10, 3, "ffe080", 0.0],
			["orbit", 213, 100, 150, 30, 10, 3, "80c0ff", 3.14],
			["clock", 60, 100, 12], ["clock", 370, 86, 10],
		],
		"fx": [
			["stars", 30, 9, 170, "ffffff", true],
			["embers", 16, "a0a8ff", 6],
		],
	}

static func _tesla() -> Dictionary:
	return {
		"name": "COLORADO SPRINGS · LABORATORIO TESLA",
		"back": [
			["sky", ["1a1626", "221c32", "2a2440", "322c4e"], 176],
			["grid", 0, 0, 53, 1, 8, 0, 1, 176, "0a0814"],
			["rect", 28, 28, 64, 74, "3a3048"], ["rect", 32, 32, 56, 66, "0a0a22"],
			["rect", 58, 50, 6, 36, "1a1a30"], ["circle", 61, 50, 8, "1a1a30"],
			["rect", 60, 32, 2, 66, "3a3048"], ["rect", 32, 64, 56, 2, "3a3048"],
			["rect", 334, 28, 64, 74, "3a3048"], ["rect", 338, 32, 56, 66, "0a0a22"],
			["rect", 364, 32, 2, 66, "3a3048"], ["rect", 338, 64, 56, 2, "3a3048"],
			["rect", 186, 142, 54, 34, "6a4a2a"], ["rect", 200, 62, 26, 82, "a8683a"],
			["grid", 198, 66, 1, 10, 0, 8, 30, 3, "c8884a"],
			["circle", 213, 54, 17, "c8c8d0"], ["circle", 213, 54, 9, "2a2640"],
			["ground", 176, "planks", "4a3626", "2a1e14", "1a1008", 55],
		],
		"mid": [
			["glow", 213, 54, 60, "6ac0ff", 0.25],
			["lightning", 213, 54, 40, 150, 3, "a8d8ff", 1, 70],
			["lightning", 213, 54, 386, 150, 3, "a8d8ff", 2, 70],
			["lightning", 213, 54, 213, 20, 2, "a8d8ff", 3, 40],
			["circle", 120, 40, 3, "fff0a0"], ["flicker", 120, 40, 18, "fff0a0"],
			["circle", 306, 40, 3, "fff0a0"], ["flicker", 306, 40, 18, "fff0a0"],
			["sprite", "bird", 61, 100, 1.4, 1, "e8e8f0"],
		],
		"fx": [
			["embers", 20, "80d0ff", 20],
			["flicker", 213, 100, 100, "6ac0ff"],
		],
	}

static func _da_vinci() -> Dictionary:
	return {
		"name": "FLORENCIA · TALLER DE LEONARDO",
		"back": [
			["sky", ["c8a878", "c0a070", "b89868", "b09060"], 176],
			["arch", 40, 150, 70, 110, "9ac8e8"], ["hemi", 75, 120, 16, "c8603a", "e08a5a", "e0d8c0"],
			["arch", 316, 150, 70, 110, "9ac8e8"], ["hemi", 351, 120, 14, "c8603a", "e08a5a", "e0d8c0"],
			["rect", 172, 22, 82, 84, "e8dcb8"],
			["ring", 213, 64, 30, "3a2a1a"],
			["line", 213, 40, 213, 92, "3a2a1a"], ["line", 190, 64, 236, 64, "3a2a1a"],
			["line", 213, 92, 200, 102, "3a2a1a"], ["line", 213, 92, 226, 102, "3a2a1a"],
			["rect", 120, 30, 30, 40, "e8dcb8"], ["rect", 280, 30, 30, 40, "e8dcb8"],
			["line", 124, 40, 146, 40, "3a2a1a"], ["line", 124, 50, 146, 58, "3a2a1a"],
			["line", 284, 44, 306, 44, "3a2a1a"], ["line", 284, 56, 306, 50, "3a2a1a"],
			["ground", 176, "planks", "8a6a40", "5a4220", "3a2a14", 57],
		],
		"mid": [
			["sprite", "bird", 110, 90, 5, 1, "6a4a2a"],
			["gear", 40, 162, 8, "8a6a30", 1.0], ["gear", 56, 168, 6, "6a4a20", -1.4],
			["gear", 386, 160, 9, "8a6a30", -0.9],
			["flicker", 150, 100, 40, "ffc860"], ["flicker", 280, 100, 40, "ffc860"],
			["formation", 100, 340, 182, 40, "florentine", 26],
		],
		"fx": [
			["embers", 14, "ffd890", 4],
		],
	}

static func _curie() -> Dictionary:
	return {
		"name": "PARÍS · LABORATORIO DEL RADIO",
		"back": [
			["sky", ["9ac0a8", "a4c8b0", "aed0b8", "b8d8c0"], 176],
			["grid", 0, 0, 36, 1, 12, 0, 1, 176, "88a890"], ["grid", 0, 0, 1, 15, 0, 12, 426, 1, "88a890"],
			["rect", 158, 26, 110, 94, "5a4a3a"], ["rect", 162, 30, 102, 86, "1a2a4a"],
			["tent", 213, 116, 44, 80, "3a4a6a", "2a3a5a"], ["circle", 240, 44, 6, "f0ecd8"],
			["rect", 20, 74, 112, 3, "6a4a2a"], ["rect", 20, 120, 112, 3, "6a4a2a"],
			["grid", 28, 58, 6, 1, 17, 0, 9, 16, "40d878"], ["grid", 30, 52, 6, 1, 17, 0, 5, 6, "a0e8c0"],
			["grid", 28, 104, 6, 1, 17, 0, 9, 16, "90e840"], ["grid", 30, 98, 6, 1, 17, 0, 5, 6, "d0f0a0"],
			["rect", 294, 74, 112, 3, "6a4a2a"], ["rect", 294, 120, 112, 3, "6a4a2a"],
			["grid", 302, 58, 6, 1, 17, 0, 9, 16, "60e0e8"], ["grid", 304, 52, 6, 1, 17, 0, 5, 6, "b0f0f8"],
			["rect", 296, 128, 108, 38, "1a2a22"], ["text", 306, 152, "Ra 88", 16, "e6b43c"],
			["ground", 176, "checker", "e8e8e0", "6a7a78", "3a4a48", 59],
		],
		"mid": [
			["glow", 32, 66, 14, "60ff90", 0.3], ["glow", 83, 66, 14, "60ff90", 0.3],
			["glow", 32, 112, 14, "90e840", 0.3],
			["bubbles", 60, 76, 6, "80ffa0", 20],
			["glow", 213, 80, 70, "60ff90", 0.1],
			["formation", 120, 330, 184, 44, "scientist", 27],
		],
		"fx": [
			["embers", 24, "90ffb0", 8],
			["flicker", 213, 80, 90, "60ff90"],
		],
	}

static func _galileo() -> Dictionary:
	return {
		"name": "PISA · OBSERVATORIO DE GALILEO",
		"back": [
			["sky", ["04040e", "080818", "0c0c24", "141438", "1e1e50"], 176],
			["stars", 110, 7, 170, "fff8e0", false],
			["disc", 70, 50, 22, "f0ecd0", "fffff0"],
			["circle", 62, 44, 3, "d8d0b0"], ["circle", 78, 56, 4, "d8d0b0"], ["circle", 66, 60, 2, "d8d0b0"],
			["poly", [296, 176, 330, 176, 340, 50, 306, 50], "e8e0cc"],
			["poly", [306, 50, 340, 50, 342, 40, 308, 40], "c8c0a8"],
			["grid", 300, 60, 1, 10, 0, 11, 36, 2, "9a927c"],
			["hemi", 392, 152, 18, "c8c0a8", "e8e0cc", ""],
			["rect", 374, 152, 40, 24, "d8d0b8"],
			["poly", [140, 156, 154, 162, 214, 94, 200, 88], "8a5a2a"],
			["poly", [196, 90, 214, 96, 218, 90, 202, 84], "d8b040"],
			["line", 147, 159, 128, 176, "4a3218", 3.0], ["line", 147, 159, 168, 176, "4a3218", 3.0],
			["ground", 176, "slabs", "8a8478", "5a5448", "3a3428", 61],
		],
		"mid": [
			["planet", 215, 40, 16, "d8a868", "e8c898"],
			["orbit", 215, 40, 34, 6, 6, 2, "fff0c8", 0.0], ["orbit", 215, 40, 50, 8, 10, 2, "fff0c8", 1.5],
			["orbit", 215, 40, 66, 10, 16, 2, "fff0c8", 3.0], ["orbit", 215, 40, 82, 12, 25, 2, "fff0c8", 4.5],
			["clouds", 2, 8, 100, 140, "2a2a48", "1a1a38", 2.0],
			["formation", 150, 340, 184, 44, "florentine", 28],
		],
		"fx": [
			["stars", 40, 3, 150, "ffffff", true],
		],
	}

static func _darwin() -> Dictionary:
	return {
		"name": "ISLAS GALÁPAGOS · EL BEAGLE",
		"back": [
			["sky", ["58a8e0", "78bcec", "98d0f0", "b8e0f4", "d8f0f8"], 176],
			["waves", 118, 58, "2a7ab0", "3a8cc0", "a8e0f0"],
			["mount", 176, 26, "3a3430", 2.5, "", 1.6],
			["tree", 34, 176, 50, "7a9a5a", "8a7a60"], ["tree", 384, 176, 56, "7a9a5a", "8a7a60"],
			["ground", 176, "noise", "d8c8a0", "b0a078", "f0e4c0", 63],
			["rects", [[20, 170, 16, 6, "2a2420"], [24, 166, 8, 5, "2a2420"], [390, 168, 20, 8, "2a2420"], [396, 163, 10, 6, "2a2420"]]],
		],
		"mid": [
			["clouds", 3, 9, 10, 50, "ffffff", "c8e0f0", 2.0],
			["patrol", "ship", 144, 60, 380, 90, 0.9, 0.0, "5a3a22", "e8e0c8"],
			["birds", 4, 13, 20, 80, 14, "2a2a30"], ["birds", 3, 14, 30, 70, 12, "f4f4f0", 1.3],
			["sprite", "iguana", 52, 176, 1.4, 1, "2a2a2a"], ["sprite", "iguana", 388, 174, 1.4, -1, "3a3a3a"],
			["patrol", "tortoise", 184, 40, 380, 70, 1.2, 0.0, "6a5a3a", "7a7a5a"],
			["patrol", "tortoise", 192, 40, 380, 90, 1.0, 0.5, "5a4a30", "6a6a4a"],
		],
	}

static func _colon() -> Dictionary:
	return {
		"name": "PUERTO DE PALOS · 1492",
		"back": [
			["sky", ["ff8a5a", "ffa068", "ffb878", "ffd090", "ffe4b0"], 176],
			["disc", 213, 120, 22, "fff0b0", "ffffe0"],
			["waves", 120, 56, "2a5a9a", "3a70b0", "ffd8a0"],
			["rect", 20, 166, 400, 2, "4a3220"], ["grid", 0, 164, 16, 1, 28, 0, 4, 14, "4a3220"],
			["ground", 176, "planks", "8a6a40", "5a4220", "3a2a14", 65],
			["rects", [[24, 160, 12, 16, "6a4a2a"], [24, 164, 12, 1, "3a2a14"], [24, 170, 12, 1, "3a2a14"], [392, 162, 12, 14, "6a4a2a"], [392, 167, 12, 1, "3a2a14"]]],
		],
		"mid": [
			["travel", "ship", 132, 5, 0.7, 2, 2, "5a3a22", "e8e0c8"],
			["patrol", "ship", 148, 60, 360, 80, 1.3, 0.0, "6a4426", "f0e8d0"],
			["birds", 5, 15, 20, 90, 16, "f4f4f0", 1.1],
			["flag", 24, 176, 88, 34, 20, "c02828", "e6b43c"],
			["formation", 60, 380, 184, 34, "sailor", 28],
			["formation", 110, 330, 180, 50, "conquistador", 29],
		],
	}
