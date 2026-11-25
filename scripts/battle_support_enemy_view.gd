class_name BattleSupportEnemyView
extends PanelContainer

signal info_requested(content: String)

const PORTRAIT_SIZE: Vector2 = Vector2(112.0, 120.0)
const SLOT_SIZE: Vector2 = Vector2(40.0, 40.0)
const SLOT_SEPARATION: int = 3
const CONTENT_MARGIN: int = 10
const CONTENT_SEPARATION: int = 7
const ROW_SEPARATION: int = 14
const STAT_SEPARATION: int = 5
const STAT_ICON_SIZE: Vector2 = Vector2(24.0, 24.0)
const PRECISION_SEPARATION: int = 5
const NAME_FONT_SIZE: int = 18
const STAT_FONT_SIZE: int = 13
const PRECISION_FONT_SIZE: int = 12
const ATTACK_FONT_SIZE: int = 18
const MUTED_COLOR: Color = Color("#8d9ba9")
const STAT_COLOR: Color = Color(0.91, 0.76, 0.53, 1.0)
const DODGE_COLOR: Color = Color(0.52, 0.89, 0.76, 1.0)
const DEFENSE_IDLE_COLOR: Color = Color(0.55, 0.60, 0.67, 0.65)
const HEALTH_METER_SCENE: PackedScene = preload("res://scenes/health_meter.tscn")
const ATTACK_ICON: Texture2D = preload("res://assets/icons/stats/24x24/attack.png")
const DEFENSE_ICON: Texture2D = preload("res://assets/icons/stats/24x24/defense.png")

var _portrait: TextureRect
var _name: Label
var _energy: Label
var _health: HealthMeter
var _attack: Label
var _strength: Label
var _agility: Label
var _defense: Label
var _defense_icon: TextureRect
var _dodge: Label
var _accuracy: Label
var _slots: HBoxContainer
var _revealed: Dictionary = {}
var _played: Dictionary = {}
var _participant: BattleParticipant


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size.x = 202.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, CONTENT_MARGIN)
	add_child(margin)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", CONTENT_SEPARATION)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = PORTRAIT_SIZE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", CONTENT_SEPARATION)
	row.add_child(column)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	column.add_child(_name)
	_health = HEALTH_METER_SCENE.instantiate() as HealthMeter
	column.add_child(_health)
	_energy = Label.new()
	_energy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy.add_theme_color_override("font_color", Color("#66c9e8"))
	column.add_child(_energy)
	_health.get_node("HealthColumn/HealthBar").custom_minimum_size.x = 0.0
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", STAT_SEPARATION)
	column.add_child(stats)
	stats.hide()
	_add_icon(stats, ATTACK_ICON)
	_attack = _add_label(stats, ATTACK_FONT_SIZE)
	_add_icon(stats, StatIconCatalog.icon("strength"))
	_strength = _add_label(stats, STAT_FONT_SIZE, STAT_COLOR)
	_add_icon(stats, StatIconCatalog.icon("agility"))
	_agility = _add_label(stats, STAT_FONT_SIZE, STAT_COLOR)
	_strength.tooltip_text = BattleAttributeTooltip.strength_description()
	_agility.tooltip_text = BattleAttributeTooltip.agility_description()
	_defense_icon = _add_icon(stats, DEFENSE_ICON)
	_defense = _add_label(stats, ATTACK_FONT_SIZE)
	var precision := HBoxContainer.new()
	precision.alignment = BoxContainer.ALIGNMENT_CENTER
	precision.add_theme_constant_override("separation", PRECISION_SEPARATION)
	column.add_child(precision)
	precision.hide()
	_add_icon(precision, StatIconCatalog.icon("evasion"))
	_dodge = _add_label(precision, PRECISION_FONT_SIZE, DODGE_COLOR)
	_add_icon(precision, StatIconCatalog.icon("accuracy"))
	_accuracy = _add_label(precision, PRECISION_FONT_SIZE, STAT_COLOR)
	_accuracy.tooltip_text = BattleAttributeTooltip.accuracy_description()
	_slots = HBoxContainer.new()
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots.add_theme_constant_override("separation", SLOT_SEPARATION)
	column.add_child(_slots)


func _add_label(parent: Container, font_size: int, tint: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label


func _add_icon(parent: Container, texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = STAT_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon


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
	_played.clear()
	_refresh_slots()
	refresh_health(participant)
	refresh_stats(participant)
	highlight_cursor(participant.action_cursor)


func refresh_health(participant: BattleParticipant) -> void:
	if participant == null:
		return
	_health.set_health(participant.health, participant.max_health)
	_portrait.modulate = Color.WHITE if participant.is_alive() else MUTED_COLOR


func set_health(health: int, maximum: int) -> void:
	_health.set_health(health, maximum, true)


func refresh_stats(participant: BattleParticipant) -> void:
	if participant == null:
		return
	_energy.text = "Энергия %d/%d" % [participant.current_energy(), participant.max_energy]
	_attack.text = str(participant.melee_attack())
	_strength.text = "%d" % participant.effective_strength()
	_agility.text = "%d" % participant.effective_agility()
	set_block(participant.block_armor)
	_dodge.text = "%d%%" % participant.dodge_percent()
	_accuracy.text = "%d%%" % (BattleParticipant.PERCENT_SCALE + participant.accuracy_percent())


func set_block(amount: int) -> void:
	var armor: int = _participant.effective_defense() if _participant != null else 0
	_defense.text = "%d / %d" % [armor, amount] if amount > 0 else str(armor)
	_defense.tooltip_text = "Броня: %d\nАктивный блок: %d" % [armor, amount]
	_defense_icon.modulate = Color.WHITE if armor > 0 or amount > 0 else DEFENSE_IDLE_COLOR


func set_precision(dodge: int, accuracy: int) -> void:
	_dodge.text = "%d%%" % dodge
	_accuracy.text = "%d%%" % (BattleParticipant.PERCENT_SCALE + accuracy)


func reveal(index: int, ability_id: String) -> void:
	if _participant == null or index < 0 or index >= _participant.action_chain.size():
		return
	_revealed[index] = ability_id
	_played[index] = true
	_render_slot(index)


func reveal_all() -> void:
	if _participant == null:
		return
	for index in range(_participant.action_chain.size()):
		_revealed[index] = _participant.action_chain[index]
		_render_slot(index)


func reset_played() -> void:
	_played.clear()
	for index in range(_slots.get_child_count()):
		_render_slot(index)


func hide_action_slots() -> void:
	_slots.hide()


func set_chain(participant: BattleParticipant) -> void:
	_participant = participant
	_revealed.clear()
	_played.clear()
	_refresh_slots()
	highlight_cursor(_participant.action_cursor if _participant != null else -1)


func _refresh_slots() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	if _participant == null:
		return
	var count: int = _participant.action_chain.size()
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
	slot.modulate = BattleAbilitySlot.SPENT_MODULATE if _played.has(index) else Color.WHITE
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
