## Escenarios temáticos (parte C): los nueve últimos luchadores. Ver stage_defs_a.gd
## para el formato.
class_name StageDefsC
extends RefCounted

static func get_def(id: StringName) -> Dictionary:
	match id:
		&"janequeo": return _janequeo()
		&"lautaro": return _lautaro()
		&"pachacutec": return _pachacutec()
		&"ivan_el_terrible": return _ivan()
		&"boudica": return _boudica()
		&"juana_de_arco": return _juana()
		&"augusto_pinochet": return _pinochet()
		&"salvador_allende": return _allende()
		&"arturo_prat": return _prat()
	return {}

static func _janequeo() -> Dictionary:
	return {
		"name": "ARAUCANÍA · BOSQUE DE ARAUCARIAS",
		"back": [
			["sky", ["7a9ab0", "98b4c4", "b4cad4", "d0dcd8", "e4e8dc"], 176],
			["mount", 120, 60, "6a7a8a", 7.0, "f0f4f8", 0.8], ["mount", 150, 34, "4a6a4a", 3.1, "", 0.9],
			["pine", 50, 176, 80, "2a5a3a"], ["pine", 98, 176, 62, "326a42"], ["pine", 330, 176, 86, "2a5a3a"],
			["pine", 384, 176, 64, "326a42"],
			["ground", 176, "noise", "5a7a3a", "3a5a28", "2a4a1a", 71],
		],
		"mid": [
			["clouds", 4, 3, 10, 46, "e8ecee", "c4ccd0", 1.5],
			["flag", 213, 176, 94, 30, 18, "8a2020", "141010"],
			["birds", 4, 7, 14, 70, 14, "202020", 1.0],
			["formation", 60, 370, 184, 30, "mapuche", 72, 1.0, 1, 4, false, 0, "spear"],
		],
	}

static func _lautaro() -> Dictionary:
	return {
		"name": "TUCAPEL · FUERTE ESPAÑOL, 1553",
		"back": [
			["sky", ["e07a4a", "ee9858", "f4b068", "f8cc88", "fce0a8"], 176],
			["disc", 320, 110, 24, "fff0c0", "ffffe0"],
			["mount", 140, 40, "5a4a5a", 2.4, "", 0.8],
			["wall", 130, 46, "8a6a48", "5a4228", true],
			["tower", 60, 176, 22, 74, "8a6a48", "5a4228", "5a3a22"],
			["tower", 366, 176, 22, 74, "8a6a48", "5a4228", "5a3a22"],
			["ground", 176, "noise", "8a6a3a", "6a4a28", "4a3218", 73],
		],
		"mid": [
			["embers", 22, "ffb040", 8],
			["flag", 213, 176, 96, 30, 18, "c02828", "1c1c24"],
			["patrol", "horse", 186, 60, 380, 24, 1.1, 0.2, "3a3030", "c02828"],
			["formation", 90, 340, 184, 28, "mapuche", 74, 1.05, 1, 4, true, 0, "spear"],
		],
	}

static func _pachacutec() -> Dictionary:
	return {
		"name": "MACHU PICCHU · CUSCO",
		"back": [
			["sky", ["5a8ac8", "78a2d4", "98bae0", "b8d0e8", "d8e4f0"], 176],
			["disc", 90, 44, 14, "fff4c0"],
			["mount", 110, 70, "5a7a5a", 6.2, "", 1.1], ["mount", 150, 50, "4a6a48", 2.2, "", 0.9],
			["rect", 40, 150, 346, 26, "8a8a80"], ["rect", 70, 132, 290, 18, "9a9a90"],
			["rect", 110, 116, 210, 16, "a8a89c"],
			["grid", 70, 134, 8, 1, 36, 0, 22, 2, "6a6a60"],
			["ground", 176, "slabs", "8a8478", "5a5a50", "3a3a34", 75],
		],
		"mid": [
			["clouds", 5, 8, 8, 56, "f0f4f8", "c8d4e0", 3.0],
			["flag", 213, 176, 94, 30, 18, "c04820", "e8c040"],
			["patrol", "sheep", 186, 20, 140, 40, 0.9, 0.3, "e8e0d0"],
			["patrol", "sheep", 188, 280, 400, 46, 0.9, 0.7, "d8d0c0"],
			["formation", 70, 360, 184, 30, "inca", 76, 1.0, 1, 4, false, 0, "spear"],
		],
	}

static func _ivan() -> Dictionary:
	return {
		"name": "KREMLIN · MOSCÚ, 1560",
		"back": [
			["sky", ["7a7a90", "8e8ea2", "a2a2b4", "b8b8c6", "cccdd6"], 176],
			["wall", 140, 36, "9a3a2a", "6a2218", true],
			["dome", 70, 140, 16, "2a6a3a", "1a4a28", "e8c040"], ["dome", 150, 140, 12, "c8a030", "a08020", "e8c040"],
			["tower", 213, 140, 30, 84, "a04030", "7a2a20", "2a6a3a"],
			["dome", 290, 140, 14, "b02828", "801818", "e8c040"], ["dome", 356, 140, 16, "2a4a9a", "1a3070", "e8c040"],
			["ground", 176, "slabs", "dce2ea", "9aa4b4", "7a849a", 77],
		],
		"mid": [
			["clouds", 3, 5, 8, 40, "c0c4cc", "9ea2ac", 1.5],
			["flag", 213, 176, 96, 30, 18, "7a1a2a", "e8c040"],
			["formation", 40, 390, 184, 30, "cossack", 78, 1.05, 1, 4, false, 0, "halberd"],
		],
		"fx": [
			["snow", 90, "ffffff", 26, 8],
		],
	}

static func _boudica() -> Dictionary:
	return {
		"name": "COLINAS DE BRITANIA · 61 d.C.",
		"back": [
			["sky", ["6a7a82", "7e8e94", "94a4a6", "aebcb8", "c8d0c4"], 176],
			["mount", 130, 36, "5a7a48", 2.7, "", 0.6], ["mount", 156, 24, "4a6a3a", 5.1, "", 0.8],
			["tree", 40, 172, 64, "3a6a32"], ["tree", 92, 172, 44, "467a3a"], ["tree", 372, 172, 60, "3a6a32"],
			["tent", 150, 172, 50, 34, "8a6a48", "6a4a30"], ["tent", 300, 172, 54, 38, "8a6a48", "6a4a30"],
			["ground", 176, "noise", "5a7a3a", "3a5a28", "2a4a1a", 79],
		],
		"mid": [
			["clouds", 4, 6, 8, 44, "b8c0c0", "98a0a0", 1.8],
			["flag", 213, 176, 94, 30, 18, "2a6a3a", "c0a040"],
			["patrol", "horse", 186, 40, 380, 30, 1.15, 0.1, "e8e0d0", "6a4a2a"],
			["formation", 70, 360, 184, 30, "celt", 80, 1.0, 1, 4, false, 0, "spear"],
		],
		"fx": [
			["rain", 50, "a8b8c8", 200],
		],
	}

static func _juana() -> Dictionary:
	return {
		"name": "ORLEANS · 1429",
		"back": [
			["sky", ["7aa0d0", "98b8dc", "b4cce6", "d0e0ee", "e8f0f4"], 176],
			["disc", 340, 40, 14, "fff4c0"],
			["wall", 120, 56, "b0a48c", "7a7060", true],
			["tower", 70, 176, 26, 96, "b8ac94", "8a7e68", "2a4ab0"],
			["tower", 356, 176, 26, 96, "b8ac94", "8a7e68", "2a4ab0"],
			["banner", 150, 60, 20, 56, "2a4ab0", "e8c040", "e8c040"], ["banner", 276, 60, 20, 56, "2a4ab0", "e8c040", "e8c040"],
			["ground", 176, "slabs", "9a9078", "6a6050", "4a4238", 81],
		],
		"mid": [
			["clouds", 3, 4, 10, 44, "f4f8fa", "d0dce4", 2.0],
			["flag", 213, 176, 98, 30, 20, "e8e8f0", "2a4ab0", "tri:c02828"],
			["birds", 5, 3, 20, 80, 16, "f4f4f0", 1.1],
			["formation", 60, 370, 184, 30, "conquistador", 82, 1.0, 1, 4, true, 0, "sword"],
		],
	}

static func _pinochet() -> Dictionary:
	return {
		"name": "PALACIO DE LA MONEDA · SANTIAGO",
		"back": [
			["sky", ["8a8a98", "9c9ca8", "b0b0ba", "c4c4cc", "d4d4da"], 176],
			["mount", 110, 60, "5a6a8a", 4.4, "f0f4f8", 0.9],
			["rect", 60, 96, 306, 80, "d8d0b8"], ["rect", 60, 88, 306, 8, "a8a090"],
			["tent", 213, 96, 90, 22, "e0d8c0", "c8c0a8"],
			["grid", 72, 108, 14, 3, 20, 20, 9, 12, "3a4050"],
			["rect", 196, 134, 34, 42, "6a5a4a"],
			["ground", 176, "slabs", "8a8a88", "5a5a58", "3a3a3a", 83],
		],
		"mid": [
			["clouds", 3, 8, 8, 36, "b8b8c4", "9898a4", 1.5],
			["flag", 120, 96, 60, 30, 20, "e8e8f0", "c02828", "2a3a8a"],
			["flag", 306, 96, 60, 30, 20, "e8e8f0", "c02828", "2a3a8a"],
			["formation", 40, 390, 184, 30, "chilean", 84, 1.05, 1, 4, true, 0, "rifle"],
		],
	}

static func _allende() -> Dictionary:
	return {
		"name": "LA MONEDA · 11 DE SEPTIEMBRE DE 1973",
		"back": [
			["sky", ["5a5a68", "6e6e7a", "84848e", "9a9aa2", "b0b0b6"], 176],
			["mount", 110, 60, "4a5a7a", 4.4, "e0e8f0", 0.9],
			["rect", 60, 96, 306, 80, "c8c0a8"], ["rect", 60, 88, 306, 8, "98907e"],
			["tent", 213, 96, 90, 22, "d0c8b0", "b8b098"],
			["grid", 72, 108, 14, 3, 20, 20, 9, 12, "2a3040"],
			["rect", 196, 134, 34, 42, "5a4a3a"],
			["ground", 176, "slabs", "7a7a78", "4a4a48", "2a2a2a", 85],
		],
		"mid": [
			["clouds", 4, 9, 6, 40, "8a8a96", "6a6a76", 2.0],
			["flag", 213, 176, 96, 30, 20, "e8e8f0", "c02828", "2a3a8a"],
			["formation", 50, 380, 184, 34, "chilean", 86, 1.0, 1, 4, false, 0, "rifle"],
		],
		"fx": [
			["smoke", 110, 120, 6, "4a4640", 60.0, 1.2],
			["smoke", 316, 120, 6, "4a4640", 60.0, 1.2],
			["embers", 16, "ff8030", 12],
		],
	}

static func _prat() -> Dictionary:
	return {
		"name": "IQUIQUE · 21 DE MAYO DE 1879",
		"back": [
			["sky", ["f09a5a", "f4b070", "f8c888", "fcdca8", "fceac8"], 176],
			["disc", 213, 124, 24, "fff0b0", "ffffe0"],
			["mount", 112, 40, "8a6a5a", 3.4, "", 0.7],
			["waves", 118, 58, "2a5a9a", "3a70b0", "ffd8a0"],
			["rect", 20, 166, 400, 2, "4a3220"], ["grid", 0, 164, 16, 1, 28, 0, 4, 14, "4a3220"],
			["ground", 176, "planks", "8a6a40", "5a4220", "3a2a14", 87],
		],
		"mid": [
			["travel", "ship", 128, 5, 0.7, 2, 3, "3a3a48", "e8e0c8"],
			["patrol", "ship", 146, 60, 360, 80, 1.3, 0.0, "1a2a5a", "f0e8d0"],
			["birds", 5, 6, 20, 90, 16, "f4f4f0", 1.1],
			["flag", 24, 176, 88, 34, 20, "e8e8f0", "c02828", "2a3a8a"],
			["cannonfire", 380, 188, 1, 4.0, 0.2],
			["formation", 60, 380, 184, 34, "marine", 88],
		],
	}
