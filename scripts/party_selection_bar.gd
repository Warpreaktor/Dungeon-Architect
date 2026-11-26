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
var _transfer_id := ""
var _highlights: Array[Panel] = []


func _ready() -> void:
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
		var highlight := Panel.new()
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.94, 0.76, 0.43, 0.13)
		style.border_color = Color(0.94, 0.76, 0.43)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		highlight.add_theme_stylebox_override("panel", style)
		button.add_child(highlight)
		highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		highlight.hide()
		_highlights.append(highlight)


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
	_apply_transfer()


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
	if index < 0 or index >= _buttons.size():
		return Rect2()
	return _buttons[index].get_global_rect()


func slot_at(point: Vector2) -> int:
	if not is_visible_in_tree():
		return -1
	for index in range(_buttons.size()):
		if target_rect(index).has_point(point):
			return index
	return -1


func member_at(point: Vector2) -> String:
	var index: int = slot_at(point)
	if index < 0 or index >= _ids.size() or _ids[index] == _transfer_id:
		return ""
	if _remove_buttons[index].is_visible_in_tree() and _remove_buttons[index].get_global_rect().has_point(point):
		return ""
	return _ids[index]


func set_transfer(hero_id: String) -> void:
	_transfer_id = hero_id
	_apply_transfer()


func _apply_transfer() -> void:
	for index in range(_buttons.size()):
		var hidden: bool = index < _ids.size() and _ids[index] == _transfer_id
		_contents[index].modulate.a = 0.0 if hidden else 1.0
		_buttons[index].disabled = hidden or index >= _ids.size()
		_remove_buttons[index].visible = index < _ids.size() and not hidden


func highlight_slot(index: int) -> void:
	for slot in range(_highlights.size()):
		_highlights[slot].visible = slot == index


func focus_member(hero_id: String) -> void:
	var index: int = _ids.find(hero_id)
	if index >= 0:
		_buttons[index].grab_focus()


func accepts_drop(point: Vector2) -> bool:
	return slot_at(point) >= _ids.size()
