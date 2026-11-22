class_name GroundLootView
extends CanvasLayer

signal closed
signal loot_changed

var _session: GameSession
var _container_id: String = ""
var _card: PanelContainer
var _scroll: ScrollContainer
var _rows: VBoxContainer


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)

	_card = PanelContainer.new()
	center.add_child(_card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_card.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var title := Label.new()
	title.text = "НАХОДКИ"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#e8c58a"))
	content.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	_scroll.add_child(_rows)

	var close_button := Button.new()
	close_button.text = "Закрыть"
	close_button.custom_minimum_size.y = 44
	close_button.pressed.connect(dismiss_by_player)
	content.add_child(close_button)
	get_viewport().size_changed.connect(_resize)
	_resize()
	hide()


func _resize() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_card.custom_minimum_size.x = minf(440.0, maxf(230.0, viewport_size.x - 36.0))
	_scroll.custom_minimum_size.y = minf(340.0, maxf(110.0, viewport_size.y * 0.48))


func open_for(session: GameSession, container_id: String) -> void:
	_session = session
	_container_id = container_id
	if session == null or session.ground_container_by_id(container_id).is_empty():
		return
	_refresh()
	show()


func _refresh() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var container: Dictionary = _session.ground_container_by_id(_container_id)
	if container.is_empty():
		dismiss_by_player()
		return
	var loot: Array = container["loot"]
	for index in range(loot.size()):
		var entry: Dictionary = loot[index]
		var item: ItemDefinition = ItemCatalog.get_item(str(entry.get("item_id", "")))
		if item == null:
			continue
		var button := Button.new()
		button.text = "%s ×%d" % [item.display_name, int(entry.get("quantity", 0))]
		button.icon = item.icon
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 50
		button.disabled = not _session.can_take_ground_loot(_container_id, index)
		button.pressed.connect(_take.bind(index))
		_rows.add_child(button)


func _take(index: int) -> void:
	if _session == null or _session.take_ground_loot(_container_id, index) <= 0:
		return
	loot_changed.emit()
	_refresh()


func dismiss_by_player() -> void:
	dismiss()
	closed.emit()


func dismiss() -> void:
	hide()
	_session = null
	_container_id = ""
