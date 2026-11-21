class_name BattleArsenalView
extends Control

signal saved(slots: Array[String])
signal closed

const SLOT_SCENE: PackedScene = preload("res://scenes/battle_ability_slot.tscn")
const REORDER_SCRIPT: Script = preload("res://scripts/battle_chain_reorder_controller.gd")
const TILE_SIZE := Vector2(112, 118)
const DRAG_DISTANCE := 18.0

var _hero: HeroState
var _actor: BattleParticipant
var _draft: Array[String] = []
var _selected_slot: int = 0
var _selected_ability: String = ""
var _slots_row: HBoxContainer
var _available_row: HBoxContainer
var _hint: Label
var _details: AcceptDialog
var _panel: PanelContainer
var _reorder: BattleChainReorderController
var _tile_buttons: Dictionary = {}
var _drag_pointer: int = -1
var _drag_touch: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_id: String = ""
var _dragging: bool = false
var _drag_ghost: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_interface()
	_reorder = REORDER_SCRIPT.new() as BattleChainReorderController
	_reorder.configure(self, _slots_row, _can_reorder, _move_slot)


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
	_selected_ability = ""
	_hint.text = "Перетащи приём на слот. Порядок слотов меняется свайпом."
	visible = true
	_refresh()


func dismiss() -> void:
	_cancel_drag()
	if _reorder != null:
		_reorder.cancel()
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

	_panel = PanelContainer.new()
	_panel.theme = preload("res://themes/hero_hud.tres")
	_panel.custom_minimum_size = Vector2(minf(1000.0, maxf(340.0, size.x - 32.0)), 398)
	center.add_child(_panel)
	resized.connect(_resize_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
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
	slots_scroll.custom_minimum_size = Vector2(0, 108)
	slots_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	slots_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(slots_scroll)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 8)
	slots_scroll.add_child(_slots_row)

	var available_label := Label.new()
	available_label.text = "ДОСТУПНЫЕ ПРИЁМЫ · ПЕРЕТАЩИ В СЛОТ"
	column.add_child(available_label)
	var available_scroll := ScrollContainer.new()
	available_scroll.custom_minimum_size = Vector2(0, 134)
	available_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	available_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(available_scroll)
	_available_row = HBoxContainer.new()
	_available_row.add_theme_constant_override("separation", 8)
	available_scroll.add_child(_available_row)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var clear_button := Button.new()
	clear_button.text = "Очистить выбранный слот"
	clear_button.custom_minimum_size = Vector2(160, 44)
	clear_button.pressed.connect(_clear_slot)
	actions.add_child(clear_button)
	var cancel := Button.new()
	cancel.text = "Отмена"
	cancel.custom_minimum_size = Vector2(90, 44)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(dismiss)
	actions.add_child(cancel)
	var accept := Button.new()
	accept.text = "Сохранить арсенал"
	accept.custom_minimum_size = Vector2(155, 44)
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.pressed.connect(_save)
	actions.add_child(accept)

	_details = AcceptDialog.new()
	_details.title = "Приём"
	add_child(_details)

	_drag_ghost = TextureRect.new()
	_drag_ghost.custom_minimum_size = Vector2(72, 72)
	_drag_ghost.size = Vector2(72, 72)
	_drag_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.z_index = 50
	_drag_ghost.modulate.a = 0.85
	_drag_ghost.hide()
	add_child(_drag_ghost)


func _resize_panel() -> void:
	if _panel != null:
		_panel.custom_minimum_size.x = minf(1000.0, maxf(340.0, size.x - 32.0))


func _refresh() -> void:
	if _reorder != null:
		_reorder.cancel()
	for slot in _slots_row.get_children():
		_slots_row.remove_child(slot)
		slot.queue_free()
	for index in range(_draft.size()):
		var ability: AbilityDefinition = AbilityCatalog.get_ability(_draft[index])
		var slot: BattleAbilitySlot = SLOT_SCENE.instantiate() as BattleAbilitySlot
		_slots_row.add_child(slot)
		slot.custom_minimum_size = Vector2(98, 98)
		slot.configure(index, ability, true, _actor)
		slot.slot_selected.connect(_select_slot)
		slot.info_requested.connect(_show_details)
		slot.set_current(index == _selected_slot)
	var rest: BattleAbilitySlot = SLOT_SCENE.instantiate() as BattleAbilitySlot
	_slots_row.add_child(rest)
	rest.custom_minimum_size = Vector2(98, 98)
	rest.configure_recharge(_draft.size())
	rest.info_requested.connect(_show_details)

	for child in _available_row.get_children():
		_available_row.remove_child(child)
		child.queue_free()
	_tile_buttons.clear()
	for ability in AbilityCatalog.available_abilities(_actor):
		var tile := Button.new()
		tile.custom_minimum_size = TILE_SIZE
		tile.tooltip_text = BattleAbilityTooltip.describe(ability, _actor, _selected_slot)
		var reason: String = AbilityCatalog.unavailable_reason(_actor, ability.ability_id)
		tile.disabled = not reason.is_empty()
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 2)
		tile.add_child(content)
		var icon := TextureRect.new()
		icon.texture = BattleAbilitySlot.visual_icon(ability)
		icon.custom_minimum_size = Vector2(64, 72)
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)
		var name := Label.new()
		name.text = ability.display_name
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.add_theme_font_size_override("font_size", 12)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(name)
		var ability_id: String = ability.ability_id
		tile.pressed.connect(_select_ability.bind(ability_id))
		var info := Button.new()
		info.name = "Info"
		info.text = "ⓘ"
		info.custom_minimum_size = Vector2(28, 28)
		info.size = Vector2(28, 28)
		info.position = Vector2(TILE_SIZE.x - 30.0, 2.0)
		info.tooltip_text = "Описание приёма"
		info.pressed.connect(_show_details.bind(tile.tooltip_text))
		tile.add_child(info)
		_available_row.add_child(tile)
		_tile_buttons[ability_id] = tile


func _can_reorder() -> bool:
	return visible and not _dragging and _details != null and not _details.visible


func _move_slot(from_index: int, to_index: int) -> void:
	_draft = BattleChainReorderController.moved(_draft, from_index, to_index)
	_selected_slot = to_index
	_hint.text = "Порядок изменён. Сохрани арсенал, чтобы подтвердить."
	_refresh()


func _select_slot(index: int) -> void:
	if _reorder != null and _reorder.consume_selection(index):
		return
	_selected_slot = index
	if not _selected_ability.is_empty():
		_assign_ability(index, _selected_ability)
	else:
		_refresh()


func _select_ability(ability_id: String) -> void:
	_selected_ability = ability_id
	_hint.text = "Перетащи «%s» на слот или коснись нужного слота." % AbilityCatalog.get_ability(ability_id).display_name


func _assign_ability(index: int, ability_id: String) -> void:
	if index < 0 or index >= _draft.size() or not AbilityCatalog.can_prepare(_actor, ability_id):
		return
	_draft[index] = ability_id
	_selected_slot = index
	_selected_ability = ""
	_hint.text = "Приём размещён. Изменения вступят в силу после сохранения."
	_refresh()


func _clear_slot() -> void:
	if _selected_slot < 0 or _selected_slot >= _draft.size():
		return
	_draft[_selected_slot] = ""
	_refresh()


func _show_details(content: String) -> void:
	_details.dialog_text = content
	_details.popup_centered_ratio(0.7)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _details.visible:
			_details.hide()
		else:
			dismiss()
		get_viewport().set_input_as_handled()
		return
	if _reorder != null:
		_reorder.handle_input(event)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _drag_id.is_empty():
				_begin_drag(touch.position, true, touch.index)
		elif _drag_touch and touch.index == _drag_pointer:
			_end_drag(touch.position)
	elif event is InputEventScreenDrag:
		var touch_drag := event as InputEventScreenDrag
		if _drag_touch and touch_drag.index == _drag_pointer:
			_move_drag(touch_drag.position)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.device == InputEvent.DEVICE_ID_EMULATION or mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed and _drag_id.is_empty():
			_begin_drag(mouse.position, false, -1)
		elif not mouse.pressed and not _drag_touch:
			_end_drag(mouse.position)
	elif event is InputEventMouseMotion and not _drag_touch and not _drag_id.is_empty():
		_move_drag((event as InputEventMouseMotion).position)


func _begin_drag(point: Vector2, touch: bool, index: int) -> void:
	if _details.visible:
		return
	for ability_id in _tile_buttons:
		var tile: Button = _tile_buttons[ability_id]
		if not tile.disabled and tile.get_global_rect().has_point(point):
			var info: Control = tile.get_node("Info") as Control
			if info.get_global_rect().has_point(point):
				return
			_drag_id = str(ability_id)
			_drag_start = point
			_drag_touch = touch
			_drag_pointer = index
			_dragging = false
			return


func _move_drag(point: Vector2) -> void:
	if _drag_id.is_empty():
		return
	var delta := point - _drag_start
	if not _dragging:
		if delta.length() < DRAG_DISTANCE:
			return
		if absf(delta.x) > absf(delta.y) * 1.3:
			_cancel_drag()
			return
		_dragging = true
		var ability: AbilityDefinition = AbilityCatalog.get_ability(_drag_id)
		_drag_ghost.texture = BattleAbilitySlot.visual_icon(ability)
		_drag_ghost.show()
	_drag_ghost.position = point - global_position - _drag_ghost.size * 0.5
	for index in range(_draft.size()):
		var slot: Control = _slots_row.get_child(index) as Control
		slot.modulate = Color(1.0, 0.88, 0.56) if slot.get_global_rect().has_point(point) else Color.WHITE


func _end_drag(point: Vector2) -> void:
	if _dragging:
		for index in range(_draft.size()):
			var slot: Control = _slots_row.get_child(index) as Control
			if slot.get_global_rect().has_point(point):
				var ability_id := _drag_id
				_cancel_drag()
				_assign_ability(index, ability_id)
				return
	_cancel_drag()


func _cancel_drag() -> void:
	_drag_id = ""
	_dragging = false
	_drag_pointer = -1
	_drag_ghost.hide()
	if _slots_row != null:
		for index in range(mini(_draft.size(), _slots_row.get_child_count())):
			(_slots_row.get_child(index) as Control).modulate = Color.WHITE


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
