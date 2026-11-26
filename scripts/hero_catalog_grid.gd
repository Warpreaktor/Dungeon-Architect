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
var _cells: Dictionary = {}
var _heroes: Array[HeroDefinition] = []
var _selected: Array[String] = []
var _lifted_id := ""
var _landing_id := ""
var _reflow_generation := 0
var _reflow: Tween


func _ready() -> void:
	search.text_changed.connect(_filter)
	scroll.resized.connect(_layout_tiles)


func set_heroes(heroes: Array[HeroDefinition]) -> void:
	_stop_reflow()
	_selected.clear()
	_lifted_id = ""
	_landing_id = ""
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	tiles.clear()
	_cells.clear()
	_heroes = heroes.duplicate()
	for hero in _heroes:
		var cell := Control.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(cell)
		var tile := HeroCatalogTile.new()
		cell.add_child(tile)
		tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.configure(hero)
		tile.pressed.connect(_emit_focus.bind(hero.hero_id))
		tile.add_requested.connect(hero_add_requested.emit)
		tiles[hero.hero_id] = tile
		_cells[hero.hero_id] = cell
	reset_filter()


func reset_filter() -> void:
	search.text = ""
	_filter("")


func _filter(_text: String) -> void:
	_stop_reflow()
	_sync_visibility(false)
	scroll.scroll_vertical = 0
	_layout_tiles()


func _matches(hero: HeroDefinition) -> bool:
	var query: String = search.text.strip_edges().to_lower().replace("ё", "е")
	return query.is_empty() or hero.display_name.to_lower().replace("ё", "е").contains(query) or hero.hero_id.contains(query)


func _sync_visibility(animate: bool) -> void:
	var positions: Dictionary = {}
	var changed := false
	for hero in _heroes:
		var tile: HeroCatalogTile = tiles[hero.hero_id]
		var show_tile: bool = not _selected.has(hero.hero_id) and hero.hero_id != _lifted_id and _matches(hero)
		changed = changed or tile.visible != show_tile
		if animate and tile.visible:
			positions[hero.hero_id] = tile.global_position
	if changed:
		_stop_reflow()
	var shown := 0
	for hero in _heroes:
		var tile: HeroCatalogTile = tiles[hero.hero_id]
		tile.visible = not _selected.has(hero.hero_id) and hero.hero_id != _lifted_id and _matches(hero)
		(_cells[hero.hero_id] as Control).visible = tile.visible
		_set_landing(tile, hero.hero_id == _landing_id)
		if tile.visible:
			shown += 1
	count.text = "Герои: %d из %d" % [shown, _heroes.size()]
	if changed:
		grid.queue_sort()
		if animate and not positions.is_empty() and is_visible_in_tree():
			_animate_reflow.call_deferred(positions, _reflow_generation)


func _stop_reflow() -> void:
	_reflow_generation += 1
	if _reflow != null and _reflow.is_valid():
		_reflow.kill()
	_reflow = null
	for tile in tiles.values():
		(tile as HeroCatalogTile).position = Vector2.ZERO


func _animate_reflow(positions: Dictionary, generation: int) -> void:
	if generation != _reflow_generation or not is_visible_in_tree():
		return
	_reflow = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var moving := false
	for id in positions:
		var tile: HeroCatalogTile = tiles[id]
		if not tile.visible or tile.global_position.is_equal_approx(positions[id]):
			continue
		tile.global_position = positions[id]
		_reflow.tween_property(tile, "position", Vector2.ZERO, 0.18)
		moving = true
	if not moving:
		_reflow.kill()


func set_transfer(lifted_id: String, landing_id: String) -> void:
	if _lifted_id == lifted_id and _landing_id == landing_id:
		return
	var reflow: bool = _lifted_id != lifted_id
	_lifted_id = lifted_id
	_landing_id = landing_id
	if reflow:
		_sync_visibility(true)
	else:
		for id in tiles:
			_set_landing(tiles[id] as HeroCatalogTile, id == _landing_id)


func _set_landing(tile: HeroCatalogTile, landing: bool) -> void:
	tile.modulate.a = 0.0 if landing else 1.0
	tile.disabled = landing


func return_rect(hero_id: String) -> Rect2:
	var tile: HeroCatalogTile = tiles.get(hero_id) as HeroCatalogTile
	if tile != null and tile.is_visible_in_tree() and scroll.get_global_rect().intersects(tile.get_global_rect()):
		return tile.get_global_rect()
	var target: Rect2 = scroll.get_global_rect() if is_visible_in_tree() else Rect2()
	return Rect2(target.get_center() - Vector2(16, 20), Vector2(32, 40)) if target.has_area() else Rect2()


func _layout_tiles() -> void:
	var available: float = scroll.size.x - scroll.get_v_scroll_bar().get_combined_minimum_size().x - 2.0
	if available <= 0.0:
		return
	grid.columns = maxi(1, floori((available + GAP) / (TILE_TARGET + GAP)))
	var side: float = clampf(floorf((available - GAP * (grid.columns - 1)) / grid.columns), 1.0, TILE_MAX)
	for id in tiles:
		var tile: HeroCatalogTile = tiles[id]
		tile.set_tile_size(side)
		(_cells[id] as Control).custom_minimum_size = tile.custom_minimum_size


func refresh_selection(focused_id: String, selected: Array[String]) -> void:
	if _selected != selected:
		_selected = selected.duplicate()
		_sync_visibility(true)
	for id in tiles:
		(tiles[id] as HeroCatalogTile).set_selection(id == focused_id, 0)


func _emit_focus(hero_id: String) -> void:
	hero_focused.emit(hero_id)
