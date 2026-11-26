class_name PartySelectionBar
extends VBoxContainer

signal member_focused(hero_id: String)
signal member_removed(hero_id: String)

@onready var count: Label = $Count
@onready var row: HBoxContainer = $Slots

var portraits: Array[TextureRect] = []
var _buttons: Array[Button] = []
var _remove_buttons: Array[Button] = []
var _names: Array[Label] = []
var _ids: Array[String] = []
var _contents: Array[HBoxContainer] = []
var _compact: bool = false
var _highlighted_drop: int = -1
var _drop_style: StyleBoxFlat


func _ready() -> void:
	_drop_style = StyleBoxFlat.new()
	_drop_style.bg_color = Color(0.16, 0.27, 0.24)
	_drop_style.border_color = Color(0.63, 0.86, 0.66)
	_drop_style.set_border_width_all(2)
	_drop_style.set_corner_radius_all(6)
	for index in range(GameSession.MAX_PARTY_SIZE):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 66)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_focus.bind(index))
		row.add_child(button)
		_buttons.append(button)
		var content := HBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(content)
		_contents.append(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 4
		content.offset_top = 4
		content.offset_bottom = -4
		content.offset_right = -4
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(48, 48)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(portrait)
		portraits.append(portrait)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(label)
		_names.append(label)
		var remove := Button.new()
		remove.text = "×"
		remove.custom_minimum_size = Vector2(28, 28)
		remove.pressed.connect(_remove.bind(index))
		button.add_child(remove)
		remove.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		remove.offset_left = -30
		remove.offset_right = -2
		remove.offset_top = 2
		remove.offset_bottom = 30
		remove.tooltip_text = "Убрать из отряда"
		_remove_buttons.append(remove)


func refresh(ids: Array[String], heroes: Dictionary) -> void:
	_ids = ids.duplicate()
	count.text = "Отряд: %d / %d" % [ids.size(), GameSession.MAX_PARTY_SIZE]
	for index in range(_buttons.size()):
		var hero: HeroDefinition = heroes.get(ids[index]) as HeroDefinition if index < ids.size() else null
		portraits[index].texture = hero.portrait if hero != null else null
		portraits[index].visible = hero != null
		_names[index].text = hero.display_name if hero != null else "+"
		_names[index].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if hero != null else HORIZONTAL_ALIGNMENT_CENTER
		_buttons[index].tooltip_text = hero.display_name if hero != null else ""
		_buttons[index].disabled = hero == null
		_remove_buttons[index].visible = hero != null


func adapt(compact: bool) -> void:
	_compact = compact
	for index in range(_buttons.size()):
		_names[index].visible = not compact or index >= _ids.size()
		_contents[index].offset_right = -4 if compact or index >= _ids.size() else -34
		portraits[index].custom_minimum_size.x = 0.0 if compact else 48.0
		portraits[index].size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL


func _focus(index: int) -> void:
	if index < _ids.size():
		member_focused.emit(_ids[index])


func _remove(index: int) -> void:
	if index < _ids.size():
		member_removed.emit(_ids[index])


func target_rect(index: int) -> Rect2:
	var rect: Rect2 = _buttons[index].get_global_rect().grow(-4.0)
	if not _compact:
		rect.size.x = 48.0
	return rect


func accepts_drop(point: Vector2) -> bool:
	for index in range(_ids.size(), _buttons.size()):
		if _buttons[index].is_visible_in_tree() and _buttons[index].get_global_rect().has_point(point):
			return true
	return false


func highlight_drop(point: Vector2) -> void:
	var target: int = _ids.size() if accepts_drop(point) else -1
	if target == _highlighted_drop:
		return
	clear_drop_highlight()
	if target >= 0:
		_highlighted_drop = target
		_buttons[target].add_theme_stylebox_override("disabled", _drop_style)


func clear_drop_highlight() -> void:
	if _highlighted_drop >= 0:
		_buttons[_highlighted_drop].remove_theme_stylebox_override("disabled")
		_highlighted_drop = -1
