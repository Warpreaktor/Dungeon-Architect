class_name HeroSelection
extends VBoxContainer

signal party_chosen(hero_ids: Array[String])
signal back_requested

@onready var _catalog: HeroCatalogGrid = %Catalog
@onready var _preview: HeroPreviewPanel = %Preview
@onready var _party_bar: PartySelectionBar = %PartyBar
@onready var _start_button: Button = %StartPartyButton
@onready var _body: BoxContainer = $Body

var _selected_ids: Array[String] = []
var _heroes: Dictionary = {}
var _focused_id: String = ""
var _detail_page: bool = false
var _separate_page: bool = false
var _flights: Array[TextureRect] = []


func _ready() -> void:
	_catalog.hero_focused.connect(_focus_hero)
	_preview.toggle_requested.connect(_toggle_focused)
	_preview.catalog_requested.connect(_show_catalog)
	_party_bar.member_focused.connect(_focus_hero)
	_party_bar.member_removed.connect(_remove_hero)
	_start_button.pressed.connect(_confirm_party)
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	resized.connect(_adapt_layout)
	visibility_changed.connect(_on_visibility_changed)
	var heroes: Array[HeroDefinition] = []
	for id in HeroCatalog.list_ids():
		heroes.append(HeroCatalog.get_hero(id))
	set_heroes(heroes)


func set_heroes(heroes: Array[HeroDefinition]) -> void:
	_heroes.clear()
	var unique: Array[HeroDefinition] = []
	for hero in heroes:
		if hero == null or hero.hero_id.is_empty() or _heroes.has(hero.hero_id):
			continue
		_heroes[hero.hero_id] = hero
		unique.append(hero)
	_catalog.set_heroes(unique)
	reset_selection()


func _focus_hero(hero_id: String) -> void:
	if not _heroes.has(hero_id):
		return
	_focused_id = hero_id
	_detail_page = true
	_preview.show_hero(_heroes[hero_id] as HeroDefinition)
	_refresh_selection()
	_adapt_layout()


func _toggle_focused() -> void:
	if _selected_ids.has(_focused_id):
		_remove_hero(_focused_id)
	elif _heroes.has(_focused_id) and _selected_ids.size() < GameSession.MAX_PARTY_SIZE:
		var source: TextureRect = _preview.portrait
		var tile: HeroCatalogTile = _catalog.tiles[_focused_id]
		if tile.is_visible_in_tree() and _catalog.scroll.get_global_rect().encloses(tile.portrait.get_global_rect()):
			source = tile.portrait
		_selected_ids.append(_focused_id)
		_refresh_selection()
		_animate_add(source, _selected_ids.size() - 1)


func _remove_hero(hero_id: String) -> void:
	_selected_ids.erase(hero_id)
	_refresh_selection()


func _refresh_selection() -> void:
	_catalog.refresh_selection(_focused_id, _selected_ids)
	_party_bar.refresh(_selected_ids, _heroes)
	_party_bar.adapt(size.x < 760.0)
	_preview.refresh_action(_heroes.has(_focused_id), _selected_ids.has(_focused_id), _selected_ids.size() >= GameSession.MAX_PARTY_SIZE)
	_start_button.disabled = _selected_ids.is_empty()


func _adapt_layout() -> void:
	if not is_node_ready():
		return
	var narrow: bool = size.x < 740.0
	_separate_page = narrow and size.y < 680.0
	_body.vertical = narrow and not _separate_page
	_catalog.visible = not _separate_page or not _detail_page
	_preview.visible = not _separate_page or _detail_page
	_preview.custom_minimum_size.x = 0.0 if narrow else minf(310.0, size.x * 0.36)
	_preview.size_flags_stretch_ratio = 0.65 if _body.vertical else 1.0
	_preview.adapt(narrow, _separate_page, size.y)
	_party_bar.adapt(size.x < 760.0)
	_catalog.call_deferred("_layout_tiles")


func _show_catalog() -> void:
	_detail_page = false
	_adapt_layout()
	focus_first()


func _animate_add(source: TextureRect, index: int) -> void:
	if not source.is_visible_in_tree() or source.texture == null:
		return
	var from: Rect2 = source.get_global_rect()
	var destination: Rect2 = _party_bar.target_rect(index)
	var flight := TextureRect.new()
	flight.texture = source.texture
	flight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flight.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flight.top_level = true
	flight.z_index = 10
	add_child(flight)
	flight.global_position = from.position
	flight.size = from.size
	_flights.append(flight)
	var tween: Tween = flight.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(flight, "global_position", destination.position, 0.28)
	tween.tween_property(flight, "size", destination.size, 0.28)
	tween.tween_property(flight, "modulate:a", 0.0, 0.12).set_delay(0.16)
	tween.chain().tween_callback(func() -> void:
		_flights.erase(flight)
		flight.queue_free()
	)


func _clear_flights() -> void:
	for flight in _flights:
		flight.hide()
		flight.queue_free()
	_flights.clear()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_clear_flights()
	else:
		_adapt_layout()


func selected_party() -> Array[String]:
	return _selected_ids.duplicate()


func reset_selection() -> void:
	_clear_flights()
	_selected_ids.clear()
	_catalog.reset_filter()
	_focused_id = ""
	if _heroes.has(HeroCatalog.DEFAULT_HERO_ID):
		_focused_id = HeroCatalog.DEFAULT_HERO_ID
	elif not _heroes.is_empty():
		_focused_id = str(_heroes.keys()[0])
	_detail_page = false
	_preview.show_hero(_heroes.get(_focused_id) as HeroDefinition)
	_refresh_selection()
	_adapt_layout()


func _confirm_party() -> void:
	if _selected_ids.is_empty() or _selected_ids.size() > GameSession.MAX_PARTY_SIZE:
		return
	party_chosen.emit(selected_party())


func focus_first() -> void:
	for tile in _catalog.tiles.values():
		if (tile as HeroCatalogTile).is_visible_in_tree():
			(tile as HeroCatalogTile).grab_focus()
			return
