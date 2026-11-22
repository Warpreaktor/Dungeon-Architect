class_name InventoryView
extends CanvasLayer

signal closed
signal item_use_requested(item_id: String)
signal equipment_changed

@onready var _card: PanelContainer = %Card
@onready var _columns: GridContainer = %Columns
@onready var _bag_grid: GridContainer = %BagGrid
@onready var _gold_label: Label = %GoldLabel
@onready var _item_icon: TextureRect = %ItemIcon
@onready var _item_name: Label = %ItemName
@onready var _item_description: RichTextLabel = %ItemDescription
@onready var _item_properties: Label = %ItemProperties
@onready var _use_feedback: Label = %UseFeedback
@onready var _mannequin: EquipmentMannequin = %EquipmentMannequin
@onready var _close_button: Button = %CloseButton

var _session: GameSession
var _entries: Array[String] = []
var _selected_index: int = -1
var _bag_cell_size: float = 52.0
var _touch_index: int = -1
var _touch_origin: Vector2
var _touch_started_at: int = 0
var _touch_source: Dictionary = {}
var _touch_dragging: bool = false
var _touch_preview: TextureRect
var _item_action_menu: PopupMenu
var _popup_slot: int = -1



func _ready() -> void:
	_item_action_menu = PopupMenu.new()
	_item_action_menu.add_item("Использовать", 0)
	_item_action_menu.id_pressed.connect(_on_item_action_pressed)
	add_child(_item_action_menu)
	_close_button.pressed.connect(close_by_player)
	_mannequin.item_transferred.connect(_transfer_item)
	_mannequin.slot_selected.connect(_select_equipped)
	get_viewport().size_changed.connect(_resize_card)
	_resize_card()
	hide()


func open_for(session: GameSession) -> void:
	if session == null or session.hero == null:
		return
	_session = session
	_item_action_menu.hide()
	_popup_slot = -1
	_use_feedback.text = ""
	_refresh_contents()
	_resize_card()
	show()
	_close_button.grab_focus()


func _refresh_contents() -> void:
	for child in _bag_grid.get_children():
		_bag_grid.remove_child(child)
		child.queue_free()
	_entries = _session.inventory_slot_ids()
	var hero: HeroState = _session.hero
	_gold_label.text = "%d" % hero.gold
	_mannequin.show_hero(_session)
	if _selected_index < 0 or _selected_index >= _entries.size() or _entries[_selected_index].is_empty():
		_selected_index = _first_occupied_slot()
	for index in range(_entries.size()):
		var item_id: String = _entries[index]
		var definition: ItemDefinition = ItemCatalog.get_item(item_id) if not item_id.is_empty() else null
		var quantity: int = int(_session.carried_items.get(item_id, 0)) if definition != null and definition.stackable else 1
		var slot := InventoryGridSlot.new()
		_bag_grid.add_child(slot)
		slot.configure(index, definition, quantity, index == _selected_index, _bag_cell_size, _session)
		slot.activated.connect(_on_bag_slot_activated)
		slot.transferred.connect(_transfer_item)
	if _selected_index < 0:
		_clear_item_info()
	else:
		_show_item(_selected_index)


func _first_occupied_slot() -> int:
	for index in range(_entries.size()):
		if not _entries[index].is_empty():
			return index
	return -1


func _transfer_item(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant) -> void:
	_item_action_menu.hide()
	_popup_slot = -1
	if _session == null or not _session.transfer_inventory_item(from_kind, from_slot, to_kind, to_slot):
		return
	_selected_index = int(to_slot) if to_kind == "bag" else -1
	_refresh_contents()
	if to_kind == "equipment":
		_select_equipped(str(to_slot))
	if from_kind == "equipment" or to_kind == "equipment":
		equipment_changed.emit()
		if to_kind == "equipment":
			var changed_slot: EquipmentSlotControl = _mannequin.slots.get(str(to_slot)) as EquipmentSlotControl
			if changed_slot != null:
				changed_slot.modulate = Color(1.35, 1.2, 0.82)
				create_tween().tween_property(changed_slot, "modulate", Color.WHITE, 0.25)


func _select_equipped(slot_id: String) -> void:
	if _session == null:
		return
	var item_id: String = _session.equipment_item_id(slot_id)
	if item_id.is_empty():
		_clear_item_info()
		return
	_selected_index = -1
	_show_item_definition(item_id)


func _clear_item_info() -> void:
	_item_icon.texture = null
	_item_name.text = ""
	_item_description.text = ""
	_item_properties.text = ""


func _on_bag_slot_activated(index: int) -> void:
	_item_action_menu.hide()
	_popup_slot = -1
	if _session == null or index < 0 or index >= _entries.size():
		return
	var item_id: String = _entries[index]
	if item_id.is_empty():
		return
	_show_item(index)
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null or item.category != ItemDefinition.Category.CONSUMABLE:
		return
	var cells: Array[Node] = _bag_grid.get_children()
	if index >= cells.size():
		return
	_popup_slot = index
	var rect: Rect2 = (cells[index] as Control).get_global_rect()
	var menu_size := Vector2i(164, 44)
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var popup_position := Vector2i(
		clampi(int(rect.end.x) + 4, 0, maxi(0, int(viewport_rect.size.x) - menu_size.x)),
		clampi(int(rect.position.y), 0, maxi(0, int(viewport_rect.size.y) - menu_size.y))
	)
	_item_action_menu.popup(Rect2i(popup_position, menu_size))


func _on_item_action_pressed(action_id: int) -> void:
	if action_id != 0 or _session == null or _popup_slot < 0 or _popup_slot >= _entries.size():
		return
	var item_id: String = _entries[_popup_slot]
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	_popup_slot = -1
	if item != null and item.category == ItemDefinition.Category.CONSUMABLE:
		item_use_requested.emit(item_id)


func _show_item(index: int) -> void:
	if index < 0 or index >= _entries.size() or _session == null:
		return
	var item_id := _entries[index]
	if item_id.is_empty():
		return
	_selected_index = index
	for child in _bag_grid.get_children():
		if child is InventoryGridSlot:
			var definition: ItemDefinition = ItemCatalog.get_item(child.item_id) if not child.item_id.is_empty() else null
			var quantity: int = int(_session.carried_items.get(child.item_id, 0)) if definition != null and definition.stackable else 1
			child.configure(child.slot_index, definition, quantity, child.slot_index == _selected_index, _bag_cell_size, _session)
	_show_item_definition(item_id)


func _show_item_definition(item_id: String) -> void:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null:
		return
	_item_icon.texture = item.icon
	_item_name.text = item.display_name
	_item_description.text = item.get_description()
	_use_feedback.text = ""
	var category := "Квестовый предмет"
	match item.category:
		ItemDefinition.Category.CONSUMABLE:
			category = "Расходник"
		ItemDefinition.Category.EQUIPMENT:
			category = "Снаряжение"
		ItemDefinition.Category.CURRENCY:
			category = "Валюта"
	var details := category
	var count: int = int(_session.carried_items.get(item_id, 0))
	if item.stackable:
		details += "  ·  количество: %d" % count
	match item.consumable_effect:
		ItemDefinition.ConsumableEffect.HEAL:
			details += "\nВосстанавливает: до %d HP" % item.healing_amount
		ItemDefinition.ConsumableEffect.ATTACK:
			details += "\nАтака: +%d на %s" % [item.effect_value, DescriptionTemplate.phases(item.effect_duration_phases)]
		ItemDefinition.ConsumableEffect.RESIST:
			details += "\nПолучаемый урон: −%d%% на %s" % [item.effect_value, DescriptionTemplate.phases(item.effect_duration_phases)]
		ItemDefinition.ConsumableEffect.VISION:
			details += "\nОбзор: +%d на %s" % [item.effect_value, DescriptionTemplate.phases(item.effect_duration_phases)]
		_:
			if item.healing_amount > 0:
				details += "\nВосстанавливает: до %d HP" % item.healing_amount
	if item.weapon_damage > 0:
		details += "\nУрон оружия: %d (%s)" % [item.weapon_damage, "дальний" if item.weapon_kind == ItemDefinition.WeaponKind.RANGED else "ближний"]
	if item.defense_bonus > 0:
		details += "\nБлок: +%d" % item.defense_bonus
		if item.max_durability > 0:
			details += "\nПрочность: %d / %d" % [_session.hero.current_shield_durability(item_id), item.max_durability]
	if _is_equipped(item_id):
		details += "\nНадето"
	_item_properties.text = details.replace("\n", " · ")


func _is_equipped(item_id: String) -> bool:
	if _session == null or _session.hero == null:
		return false
	return item_id == _session.hero.equipped_weapon_id or item_id == _session.hero.equipped_shield_id


func show_use_result(item_id: String, message: String) -> void:
	_item_action_menu.hide()
	_popup_slot = -1
	if _session == null:
		return
	_refresh_contents()
	var index: int = _entries.find(item_id)
	if index >= 0:
		_show_item(index)
	_use_feedback.text = message


func show_equipment_result(item_id: String, message: String = "") -> void:
	if _session == null:
		return
	_refresh_contents()
	var index: int = _entries.find(item_id)
	if index >= 0:
		_show_item(index)
	_use_feedback.text = message


func _resize_card() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_columns.columns = 1 if viewport_size.x < 1040.0 else 2
	_card.custom_minimum_size = Vector2(
		minf(1190.0, maxf(300.0, viewport_size.x - 24.0)),
		minf(760.0, maxf(240.0, viewport_size.y - 24.0))
	)
	var available_width: float = _card.custom_minimum_size.x - 60.0
	if _columns.columns == 2:
		available_width -= 358.0
	_bag_cell_size = clampf((available_width - 9.0 * 4.0) / 10.0, 44.0, 59.0)
	if _session != null:
		_refresh_contents()


func _source_at(point: Vector2) -> Dictionary:
	for child in _bag_grid.get_children():
		if child is InventoryGridSlot and not child.item_id.is_empty() and child.get_global_rect().has_point(point):
			return {"kind": "bag", "slot": child.slot_index}
	for slot_id in _mannequin.slots:
		var slot: EquipmentSlotControl = _mannequin.slots[slot_id]
		if not slot.item_id.is_empty() and slot.get_global_rect().has_point(point):
			return {"kind": "equipment", "slot": slot_id}
	return {}


func _target_at(point: Vector2) -> Dictionary:
	for child in _bag_grid.get_children():
		if child is InventoryGridSlot and child.get_global_rect().has_point(point):
			return {"kind": "bag", "slot": child.slot_index}
	for slot_id in _mannequin.slots:
		var slot: EquipmentSlotControl = _mannequin.slots[slot_id]
		if slot.get_global_rect().has_point(point):
			return {"kind": "equipment", "slot": slot_id}
	return {}


func _input(event: InputEvent) -> void:
	if not visible or _session == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index >= 0:
				return
			_touch_source = _source_at(event.position)
			if _touch_source.is_empty():
				return
			_touch_index = event.index
			_touch_origin = event.position
			_touch_started_at = Time.get_ticks_msec()
			_touch_dragging = false
		elif event.index == _touch_index:
			if _touch_dragging:
				var destination: Dictionary = _target_at(event.position)
				if not destination.is_empty():
					_transfer_item(str(_touch_source["kind"]), _touch_source["slot"], str(destination["kind"]), destination["slot"])
			elif event.position.distance_to(_touch_origin) < 16.0 and str(_touch_source.get("kind", "")) == "bag":
				var destination: Dictionary = _target_at(event.position)
				if str(destination.get("kind", "")) == "bag" and destination.get("slot") == _touch_source["slot"]:
					_on_bag_slot_activated(int(_touch_source["slot"]))
			_cancel_touch_drag()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		if not _touch_dragging and event.position.distance_to(_touch_origin) > 16.0 and Time.get_ticks_msec() - _touch_started_at >= 180:
			_touch_dragging = true
			_touch_preview = TextureRect.new()
			var item_id: String = ""
			if str(_touch_source["kind"]) == "bag":
				var ids: Array[String] = _session.inventory_slot_ids()
				item_id = ids[int(_touch_source["slot"])]
			else:
				item_id = _session.equipment_item_id(str(_touch_source["slot"]))
			var item: ItemDefinition = ItemCatalog.get_item(item_id)
			_touch_preview.texture = item.icon if item != null else null
			_touch_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_touch_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_touch_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_touch_preview.size = Vector2(56, 56)
			add_child(_touch_preview)
		if _touch_dragging and _touch_preview != null:
			_touch_preview.global_position = event.position + Vector2(25, -75)
			_update_touch_target(_target_at(event.position))


func _update_touch_target(destination: Dictionary) -> void:
	for child in _bag_grid.get_children():
		if child is InventoryGridSlot:
			var is_target: bool = not destination.is_empty() and str(destination["kind"]) == "bag" and int(destination["slot"]) == child.slot_index
			var accepted: bool = is_target and _session.can_transfer_inventory_item(str(_touch_source["kind"]), _touch_source["slot"], "bag", child.slot_index)
			var state: int = (1 if accepted else 2) if is_target else 0
			child.set_drag_drop_state(state, "touch")
	for slot_id in _mannequin.slots:
		var slot: EquipmentSlotControl = _mannequin.slots[slot_id]
		var can_accept: bool = not destination.is_empty() and str(destination["kind"]) == "equipment" and str(destination["slot"]) == slot_id and _session.can_transfer_inventory_item(str(_touch_source["kind"]), _touch_source["slot"], "equipment", slot_id)
		var is_target: bool = not destination.is_empty() and str(destination["kind"]) == "equipment" and str(destination["slot"]) == slot_id
		slot.set_drag_drop_state((1 if can_accept else 2) if is_target else 0, "touch")


func _cancel_touch_drag() -> void:
	_touch_index = -1
	_touch_source.clear()
	_touch_dragging = false
	for child in _bag_grid.get_children():
		if child is InventoryGridSlot:
			child.set_drag_drop_state(0)
	for slot_id in _mannequin.slots:
		var slot: EquipmentSlotControl = _mannequin.slots[slot_id]
		slot.set_drag_drop_state(0)
	if _touch_preview != null:
		_touch_preview.queue_free()
		_touch_preview = null


func close_by_player() -> void:
	dismiss()
	closed.emit()


func dismiss() -> void:
	_item_action_menu.hide()
	_popup_slot = -1
	_cancel_touch_drag()
	hide()
	_session = null
