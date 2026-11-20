class_name BattleSupportEnemyView
extends PanelContainer

signal info_requested(content: String)

const ICON_SIZE: Vector2 = Vector2(104.0, 120.0)
const SLOT_SIZE: Vector2 = Vector2(40.0, 40.0)
const PANEL_HORIZONTAL_PADDING: float = 24.0
const SLOT_SEPARATION: int = 3
const CONTENT_MARGIN: int = 10
const HEALTH_FONT_SIZE: int = 12
const CONTENT_SEPARATION: int = 9
const MUTED_COLOR: Color = Color("#8d9ba9")

var _portrait: TextureRect
var _name: Label
var _health: Label
var _slots: HBoxContainer
var _revealed: Dictionary = {}
var _participant: BattleParticipant


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, CONTENT_MARGIN)
	add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", CONTENT_SEPARATION)
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
	_health = Label.new()
	_health.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health.add_theme_font_size_override("font_size", HEALTH_FONT_SIZE)
	column.add_child(_health)
	_slots = HBoxContainer.new()
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots.add_theme_constant_override("separation", SLOT_SEPARATION)
	column.add_child(_slots)


func portrait_node() -> TextureRect:
	return _portrait


func configure(participant: BattleParticipant, portrait: Texture2D, display_name: String, flip_h: bool = false) -> void:
	_participant = participant
	visible = participant != null
	if participant == null:
		return
	_name.text = display_name
	_portrait.texture = portrait
	_portrait.flip_h = flip_h
	_revealed.clear()
	_refresh_slots()
	refresh_health(participant)
	highlight_cursor(participant.action_cursor)


func refresh_health(participant: BattleParticipant) -> void:
	if participant == null:
		return
	set_health(participant.health, participant.max_health)
	_portrait.modulate = Color.WHITE if participant.is_alive() else MUTED_COLOR


func set_health(health: int, maximum: int) -> void:
	_health.text = "%d / %d HP" % [health, maximum]


func reveal(index: int, ability_id: String) -> void:
	if _participant == null or index < 0 or index >= _participant.action_chain.size():
		return
	_revealed[index] = ability_id
	_render_slot(index)


func set_chain(participant: BattleParticipant) -> void:
	_participant = participant
	_revealed.clear()
	_refresh_slots()
	highlight_cursor(_participant.action_cursor if _participant != null else -1)


func _refresh_slots() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	if _participant == null:
		return
	var count: int = _participant.action_chain.size() + BattleChainPlanner.REST_TICKS
	custom_minimum_size.x = (SLOT_SIZE.x + float(SLOT_SEPARATION)) * float(count) + PANEL_HORIZONTAL_PADDING
	for index in range(count):
		var button := Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.disabled = true
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		_slots.add_child(button)
		var info := Button.new()
		info.text = "ⓘ"
		info.custom_minimum_size = Vector2(24, 24)
		info.size = info.custom_minimum_size
		info.position = Vector2(SLOT_SIZE.x - info.size.x, 0.0)
		info.focus_mode = Control.FOCUS_NONE
		info.mouse_filter = Control.MOUSE_FILTER_STOP
		info.pressed.connect(_show_slot_info.bind(index))
		button.add_child(info)
		_render_slot(index)


func _render_slot(index: int) -> void:
	var slot: Button = _slots.get_child(index) as Button
	if _participant == null or index >= _participant.action_chain.size():
		slot.text = "Zz"
		slot.icon = null
		slot.tooltip_text = "Отдых"
	elif _revealed.has(index):
		var ability: AbilityDefinition = AbilityCatalog.get_ability(str(_revealed[index]))
		slot.icon = BattleAbilitySlot.visual_icon(ability)
		slot.text = "" if slot.icon != null else (ability.display_name if ability != null else "?")
		slot.tooltip_text = BattleAbilityTooltip.describe(ability, _participant, index)
	else:
		slot.text = "?"
		slot.icon = null
		slot.tooltip_text = ""
	var info: Button = slot.get_child(0) as Button
	info.visible = not slot.tooltip_text.is_empty()


func _show_slot_info(index: int) -> void:
	var slot: Button = _slots.get_child(index) as Button
	if not slot.tooltip_text.is_empty():
		info_requested.emit(slot.tooltip_text)


func highlight_cursor(index: int) -> void:
	for slot_index in range(_slots.get_child_count()):
		var slot: Button = _slots.get_child(slot_index) as Button
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#3e3220") if slot_index == index else Color("#1c2530")
		style.border_color = Color("#f7c96b") if slot_index == index else Color("#455463")
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		slot.add_theme_stylebox_override("disabled", style)
