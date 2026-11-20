class_name BattlePassiveEnemyView
extends PanelContainer

const ICON_SIZE: Vector2 = Vector2(104.0, 120.0)
const SLOT_SIZE: Vector2 = Vector2(36.0, 36.0)
const REST_LABEL: String = "Zz"
const PANEL_HORIZONTAL_PADDING: float = 24.0

var _portrait: TextureRect
var _name: Label
var _phase: Label
var _slots: HBoxContainer


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_color_override("font_color", Color("#e9c895"))
	column.add_child(_name)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = ICON_SIZE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_portrait)
	_phase = Label.new()
	_phase.text = "Пассивный участник"
	_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase.add_theme_font_size_override("font_size", 11)
	column.add_child(_phase)
	_slots = HBoxContainer.new()
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots.add_theme_constant_override("separation", 3)
	column.add_child(_slots)


func configure(participant: BattleParticipant, portrait: Texture2D, display_name: String) -> void:
	visible = participant != null
	if participant == null:
		return
	_name.text = display_name
	_portrait.texture = portrait
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	custom_minimum_size.x = (SLOT_SIZE.x + _slots.get_theme_constant("separation")) * float(participant.action_chain.size() + BattleChainPlanner.REST_TICKS) + PANEL_HORIZONTAL_PADDING
	for _slot_index in range(participant.action_chain.size() + BattleChainPlanner.REST_TICKS):
		var label := Label.new()
		label.custom_minimum_size = SLOT_SIZE
		label.text = REST_LABEL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slots.add_child(label)
	highlight_cursor(participant.action_cursor)


func highlight_cursor(index: int) -> void:
	for slot_index in range(_slots.get_child_count()):
		var slot: Label = _slots.get_child(slot_index) as Label
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#3e3220") if slot_index == index else Color("#1c2530")
		style.border_color = Color("#f7c96b") if slot_index == index else Color("#455463")
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		slot.add_theme_stylebox_override("normal", style)
