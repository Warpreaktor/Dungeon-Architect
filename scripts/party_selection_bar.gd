class_name PartySelectionBar
extends VBoxContainer

signal member_focused(hero_id: String)

@onready var count: Label = $Count
@onready var row: HBoxContainer = $Slots

var portraits: Array[TextureRect] = []
var _buttons: Array[Button] = []
var _names: Array[Label] = []
var _ids: Array[String] = []
var _contents: Array[VBoxContainer] = []
var _transfer_id := ""
var _highlights: Array[Panel] = []


func _ready() -> void:
	for index in range(GameSession.MAX_PARTY_SIZE):
		var button := Button.new()
		button.custom_minimum_size = Vector2(60, 82)
		button.pressed.connect(_focus.bind(index))
		row.add_child(button)
		_buttons.append(button)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 2)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(content)
		_contents.append(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 4
		content.offset_top = 4
		content.offset_bottom = -4
		content.offset_right = -4
		var portrait := TextureRect.new()
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(portrait)
		portraits.append(portrait)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(label)
		_names.append(label)
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
		_names[index].size_flags_vertical = Control.SIZE_FILL if hero != null else Control.SIZE_EXPAND_FILL
		_names[index].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_buttons[index].tooltip_text = hero.display_name if hero != null else ""
		_buttons[index].disabled = hero == null
	_apply_transfer()


func adapt(side: float) -> void:
	for index in range(_buttons.size()):
		_buttons[index].custom_minimum_size = Vector2(side, side + 22.0)
		_names[index].add_theme_font_size_override("font_size", 12 if side < 80.0 else 13)


func _focus(index: int) -> void:
	if index < _ids.size():
		member_focused.emit(_ids[index])


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
	return _ids[index]


func set_transfer(hero_id: String) -> void:
	_transfer_id = hero_id
	_apply_transfer()


func _apply_transfer() -> void:
	for index in range(_buttons.size()):
		var hidden: bool = index < _ids.size() and _ids[index] == _transfer_id
		_contents[index].modulate.a = 0.0 if hidden else 1.0
		_buttons[index].disabled = hidden or index >= _ids.size()


func highlight_slot(index: int) -> void:
	for slot in range(_highlights.size()):
		_highlights[slot].visible = slot == index


func focus_member(hero_id: String) -> void:
	var index: int = _ids.find(hero_id)
	if index >= 0:
		_buttons[index].grab_focus()


func accepts_drop(point: Vector2) -> bool:
	return slot_at(point) >= _ids.size()
