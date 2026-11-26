class_name HeroCatalogGrid
extends VBoxContainer

signal hero_focused(hero_id: String)
signal hero_add_requested(hero_id: String)

const TILE_TARGET := 108.0
const TILE_MAX := 140.0
const GAP := 7

@onready var search: LineEdit = $Search
@onready var count: Label = $Count
@onready var scroll: ScrollContainer = $Scroll
@onready var grid: GridContainer = $Scroll/Grid

var tiles: Dictionary = {}
var _heroes: Array[HeroDefinition] = []


func _ready() -> void:
	search.text_changed.connect(_filter)
	scroll.resized.connect(_layout_tiles)


func set_heroes(heroes: Array[HeroDefinition]) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	tiles.clear()
	_heroes = heroes.duplicate()
	for hero in _heroes:
		var tile := HeroCatalogTile.new()
		grid.add_child(tile)
		tile.configure(hero)
		tile.pressed.connect(_emit_focus.bind(hero.hero_id))
		tile.add_requested.connect(hero_add_requested.emit)
		tiles[hero.hero_id] = tile
	reset_filter()


func reset_filter() -> void:
	search.text = ""
	_filter("")


func _filter(text: String) -> void:
	var query: String = text.strip_edges().to_lower().replace("ё", "е")
	var shown: int = 0
	for hero in _heroes:
		var tile: HeroCatalogTile = tiles[hero.hero_id]
		tile.visible = query.is_empty() or hero.display_name.to_lower().replace("ё", "е").contains(query) or hero.hero_id.contains(query)
		if tile.visible:
			shown += 1
	count.text = "Герои: %d из %d" % [shown, _heroes.size()]
	scroll.scroll_vertical = 0
	_layout_tiles()


func _layout_tiles() -> void:
	var available: float = scroll.size.x - scroll.get_v_scroll_bar().get_combined_minimum_size().x - 2.0
	if available <= 0.0:
		return
	grid.columns = maxi(1, floori((available + GAP) / (TILE_TARGET + GAP)))
	var side: float = clampf(floorf((available - GAP * (grid.columns - 1)) / grid.columns), 1.0, TILE_MAX)
	for tile in tiles.values():
		(tile as HeroCatalogTile).set_tile_size(side)


func refresh_selection(focused_id: String, selected: Array[String]) -> void:
	for id in tiles:
		(tiles[id] as HeroCatalogTile).set_selection(id == focused_id, selected.find(id) + 1)


func _emit_focus(hero_id: String) -> void:
	hero_focused.emit(hero_id)
