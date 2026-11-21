class_name BattleArsenalView
extends Control

signal saved(slots: Array[String])
signal closed

const SLOT_SCENE: PackedScene = preload("res://scenes/battle_ability_slot.tscn")

var _hero: HeroState
var _actor: BattleParticipant
var _draft: Array[String] = []
var _selected_slot: int = 0
var _slots_row: HBoxContainer
var _ability_list: VBoxContainer
var _hint: Label
var _details: AcceptDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_interface()


func open_for(hero: HeroState, actor: BattleParticipant = null) -> void:
	if hero == null:
		return
	_hero = hero
	_actor = actor if actor != null else BattleParticipant.from_hero(hero)
	_draft = hero.get_saved_action_slots()
	for index in range(_draft.size()):
		if not _draft[index].is_empty() and not AbilityCatalog.knows_ability(_actor, _draft[index]):
			_draft[index] = ""
	_selected_slot = 0
	_hint.text = "Выбери слот и приём. Пустые слоты можно заполнить позже."
	visible = true
	_refresh()


func dismiss() -> void:
	visible = false
	closed.emit()


func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.035, 0.05, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme = preload("res://themes/hero_hud.tres")
	panel.custom_minimum_size = Vector2(380, 420)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Label.new()
	title.text = "БОЕВОЙ АРСЕНАЛ"
	title.add_theme_color_override("font_color", Color("#e8c58a"))
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(48, 44)
	close_button.pressed.connect(dismiss)
	heading.add_child(close_button)

	var slots_label := Label.new()
	slots_label.text = "АКТИВНЫЕ СЛОТЫ"
	column.add_child(slots_label)
	var slots_scroll := ScrollContainer.new()
	slots_scroll.custom_minimum_size = Vector2(0, 100)
	slots_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	slots_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(slots_scroll)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 8)
	slots_scroll.add_child(_slots_row)

	var position_actions := HBoxContainer.new()
	column.add_child(position_actions)
	for step in [-1, 1]:
		var move_button := Button.new()
		move_button.text = "← Поменять" if step == -1 else "Поменять →"
		move_button.custom_minimum_size.y = 40
		move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		move_button.pressed.connect(_swap_slot.bind(step))
		position_actions.add_child(move_button)
	var clear_button := Button.new()
	clear_button.text = "Очистить слот"
	clear_button.custom_minimum_size.y = 40
	clear_button.pressed.connect(_clear_slot)
	position_actions.add_child(clear_button)

	var available_label := Label.new()
	available_label.text = "ДОСТУПНЫЕ ПРИЁМЫ"
	column.add_child(available_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 190)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_ability_list = VBoxContainer.new()
	_ability_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_ability_list)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var cancel := Button.new()
	cancel.text = "Отмена"
	cancel.custom_minimum_size = Vector2(120, 44)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(dismiss)
	actions.add_child(cancel)
	var accept := Button.new()
	accept.text = "Сохранить арсенал"
	accept.custom_minimum_size = Vector2(170, 44)
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.pressed.connect(_save)
	actions.add_child(accept)

	_details = AcceptDialog.new()
	_details.title = "Приём"
	add_child(_details)


func _refresh() -> void:
	for slot in _slots_row.get_children():
		_slots_row.remove_child(slot)
		slot.queue_free()
	for index in range(_draft.size()):
		var ability: AbilityDefinition = AbilityCatalog.get_ability(_draft[index])
		var slot: BattleAbilitySlot = SLOT_SCENE.instantiate() as BattleAbilitySlot
		_slots_row.add_child(slot)
		slot.custom_minimum_size = Vector2(94, 94)
		slot.configure(index, ability, true, _actor)
		slot.slot_selected.connect(_select_slot)
		slot.info_requested.connect(_show_details)
		slot.set_current(index == _selected_slot)

	for child in _ability_list.get_children():
		_ability_list.remove_child(child)
		child.queue_free()
	for ability in AbilityCatalog.available_abilities(_actor):
		var row := HBoxContainer.new()
		_ability_list.add_child(row)
		var choice := Button.new()
		choice.text = ability.display_name
		choice.icon = BattleAbilitySlot.visual_icon(ability)
		choice.expand_icon = true
		choice.add_theme_constant_override("icon_max_width", 42)
		choice.custom_minimum_size = Vector2(230, 54)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var reason: String = AbilityCatalog.unavailable_reason(_actor, ability.ability_id)
		choice.disabled = not reason.is_empty()
		choice.tooltip_text = BattleAbilityTooltip.describe(ability, _actor, _selected_slot)
		choice.pressed.connect(_choose.bind(ability.ability_id))
		row.add_child(choice)
		var info := Button.new()
		info.text = "ⓘ"
		info.custom_minimum_size = Vector2(48, 54)
		info.pressed.connect(_show_details.bind(choice.tooltip_text))
		row.add_child(info)


func _select_slot(index: int) -> void:
	_selected_slot = index
	_refresh()


func _choose(ability_id: String) -> void:
	if not AbilityCatalog.can_prepare(_actor, ability_id):
		return
	_draft[_selected_slot] = ability_id
	_hint.text = "Изменения вступят в силу после сохранения."
	_refresh()


func _clear_slot() -> void:
	_draft[_selected_slot] = ""
	_refresh()


func _swap_slot(offset: int) -> void:
	var target: int = _selected_slot + offset
	if target < 0 or target >= _draft.size():
		return
	var previous: String = _draft[target]
	_draft[target] = _draft[_selected_slot]
	_draft[_selected_slot] = previous
	_selected_slot = target
	_refresh()


func _show_details(content: String) -> void:
	_details.dialog_text = content
	_details.popup_centered_ratio(0.7)


func _save() -> void:
	if _hero == null or _actor == null:
		return
	for ability_id in _draft:
		if not ability_id.is_empty() and not AbilityCatalog.can_prepare(_actor, ability_id):
			_hint.text = "Недоступный приём: %s" % ability_id
			return
	if not _hero.save_action_slots(_draft):
		_hint.text = "Количество слотов изменилось. Открой арсенал повторно."
		return
	saved.emit(_draft.duplicate())
	dismiss()
