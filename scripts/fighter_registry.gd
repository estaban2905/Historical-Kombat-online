## Catálogo de luchadores disponibles.
##
## Para añadir un personaje: crea fighters/<id>/<id>.tres (FighterData)
## y añade su ruta a ROSTER. El orden de la lista es el orden en la
## pantalla de selección. Se usa una lista explícita (y no un escaneo de
## carpetas) porque en las exportaciones Web los .tres se renombran.
class_name FighterRegistry
extends RefCounted

const ROSTER: Array[String] = [
	"res://fighters/donald_trump/donald_trump.tres",
	"res://fighters/kim_jong_un/kim_jong_un.tres",
	"res://fighters/vladimir_putin/vladimir_putin.tres",
	"res://fighters/xi_jinping/xi_jinping.tres",
	"res://fighters/nicolas_maduro/nicolas_maduro.tres",
	"res://fighters/adolf_hitler/adolf_hitler.tres",
	"res://fighters/joseph_stalin/joseph_stalin.tres",
	"res://fighters/benito_mussolini/benito_mussolini.tres",
	"res://fighters/saddam_hussein/saddam_hussein.tres",
	"res://fighters/osama_bin_laden/osama_bin_laden.tres",
	"res://fighters/napoleon/napoleon.tres",
	"res://fighters/gengis_kan/gengis_kan.tres",
	"res://fighters/fidel_castro/fidel_castro.tres",
	"res://fighters/cleopatra/cleopatra.tres",
	"res://fighters/julio_cesar/julio_cesar.tres",
	"res://fighters/alejandro_magno/alejandro_magno.tres",
	"res://fighters/isabel_ii/isabel_ii.tres",
	"res://fighters/abraham_lincoln/abraham_lincoln.tres",
	"res://fighters/jesus_de_nazaret/jesus_de_nazaret.tres",
	"res://fighters/buda/buda.tres",
	"res://fighters/papa_francisco/papa_francisco.tres",
	"res://fighters/rasputin/rasputin.tres",
	"res://fighters/pablo_escobar/pablo_escobar.tres",
	"res://fighters/albert_einstein/albert_einstein.tres",
	"res://fighters/nikola_tesla/nikola_tesla.tres",
	"res://fighters/leonardo_da_vinci/leonardo_da_vinci.tres",
	"res://fighters/marie_curie/marie_curie.tres",
	"res://fighters/galileo_galilei/galileo_galilei.tres",
	"res://fighters/charles_darwin/charles_darwin.tres",
	"res://fighters/cristobal_colon/cristobal_colon.tres",
]

static var _cache: Array[FighterData] = []

## Devuelve todas las fichas, cargadas y validadas una sola vez.
static func all() -> Array[FighterData]:
	if _cache.is_empty():
		for path in ROSTER:
			var data := load(path) as FighterData
			if data == null:
				push_error("FighterRegistry: no se pudo cargar " + path)
				continue
			var errors := data.validate()
			if not errors.is_empty():
				push_error("FighterRegistry: ficha incompleta %s -> %s" % [path, ", ".join(errors)])
				continue
			_cache.append(data)
	return _cache

static func get_by_id(fighter_id: StringName) -> FighterData:
	for data in all():
		if data.id == fighter_id:
			return data
	return all()[0] if not all().is_empty() else null

static func index_of(fighter_id: StringName) -> int:
	var list := all()
	for i in list.size():
		if list[i].id == fighter_id:
			return i
	return 0

## Libera la caché (al cerrar el juego).
static func clear_cache() -> void:
	_cache.clear()
