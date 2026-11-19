class_name BattleItemPicker
extends PanelContainer

## Компактный пояс зелий. Не изменяет GameSession самостоятельно.
signal item_selected(item_id: String)
signal closed

var _item_list: VBoxContainer
var _scroll: ScrollContainer
var _close_button: Button


func _ready() -> void:
	theme = preload("res://themes/hero_hud.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 20
	custom_minimum_size.x = 292.0
	var margin := MarginContainer.new()
	for name in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(name, 10)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "БОЕВЫЕ ЗЕЛЬЯ"
	title.add_theme_color_override("font_color", Color("#e8c58a"))
	title.add_theme_font_size_override("font_size", 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close_button = Button.new()
	_close_button.text = "×"
	_close_button.custom_minimum_size = Vector2(42, 42)
	_close_button.pressed.connect(func() -> void: closed.emit())
	header.add_child(_close_button)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(282, 56)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(_scroll)
	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 5)
	_scroll.add_child(_item_list)


func refresh_items(session: GameSession) -> void:
	for child in _item_list.get_children():
		_item_list.remove_child(child)
		child.queue_free()
	if session == null or session.hero == null:
		return
	var entries: Array[String] = session.combat_item_ids()
	for item_id in entries:
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		var count: int = int(session.carried_items.get(item_id, 0))
		var choice := Button.new()
		choice.text = "%s   ×%d" % [item.display_name, count]
		choice.icon = item.icon
		choice.expand_icon = true
		choice.clip_text = true
		choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice.add_theme_constant_override("icon_max_width", 32)
		choice.custom_minimum_size = Vector2(282, 52)
		choice.tooltip_text = item.description
		if item.consumable_effect in [ItemDefinition.ConsumableEffect.HEAL, ItemDefinition.ConsumableEffect.NONE] and session.hero.health >= session.hero.max_health:
			choice.disabled = true
			choice.tooltip_text += "\nЗдоровье полное"
		choice.pressed.connect(_choose.bind(item_id))
		_item_list.add_child(choice)
	_scroll.custom_minimum_size.y = minf(268.0, maxf(56.0, float(entries.size()) * 57.0))


func _choose(item_id: String) -> void:
	item_selected.emit(item_id)
