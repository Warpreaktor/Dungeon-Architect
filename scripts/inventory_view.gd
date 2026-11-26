class_name InventoryView
extends CanvasLayer

signal closed
signal item_use_requested(item_id: String, bag_index: int)
signal equipment_changed

@onready var _card: PanelContainer = %Card
@onready var _columns: Control = %Columns
@onready var _bag: Control = %Bag
@onready var _equipment_area: Control = %EquipmentArea
@onready var _item_tooltip: PanelContainer = %ItemTooltip
@onready var _detail_scroll: ScrollContainer = %DetailScroll
@onready var _details: VBoxContainer = %Details
@onready var _tooltip_close: Button = %TooltipClose
@onready var _use_button: Button = %UseButton
@onready var _item_comparison: RichTextLabel = %ItemComparison
@onready var _comparison_separator: HSeparator = %ComparisonSeparator
@onready var _bag_grid: GridContainer = %BagGrid
@onready var _gold_label: Label = %GoldLabel
@onready var _item_icon: TextureRect = %ItemIcon
@onready var _item_name: Label = %ItemName
@onready var _item_description: RichTextLabel = %ItemDescription
@onready var _item_properties: Label = %ItemProperties
@onready var _equip_target: OptionButton = %EquipTarget
@onready var _equip_button: Button = %EquipButton
@onready var _unequip_button: Button = %UnequipButton
@onready var _use_feedback: Label = %UseFeedback
@onready var _mannequin: EquipmentMannequin = %EquipmentMannequin
@onready var _hero_selector: HFlowContainer = %HeroSelector
@onready var _close_button: Button = %CloseButton

var _session: GameSession
var _selected_member: HeroState
var _entries: Array[String] = []
var _bag_slots: Array[InventoryGridSlot] = []
var _selector_members: Array[HeroState] = []
var _highlighted_index: int = -1
var _selected_instance_id: String = ""
var _selected_item_id: String = ""
var _selected_index: int = -1
var _selected_equipped_slot: String = ""
var _comparison_target: String = ""
var _comparison_text: String = ""
var _bag_cell_size: float = 52.0
var _touch_index: int = -1
var _touch_origin: Vector2
var _touch_started_at: int = 0
var _touch_source: Dictionary = {}
var _touch_dragging: bool = false
var _touch_target: Dictionary = {}
var _touch_preview: TextureRect
var _tooltip_layout_pending: bool = false

const HERO_SELECTOR_BUTTON_SIZE := Vector2(72, 72)
const HERO_SELECTOR_PORTRAIT_MARGIN := 6
const HERO_SELECTOR_STYLE_NORMAL := Color(0.09, 0.13, 0.18, 0.98)
const HERO_SELECTOR_STYLE_HOVER := Color(0.12, 0.18, 0.24, 1.0)
const HERO_SELECTOR_STYLE_SELECTED := Color(0.18, 0.25, 0.32, 1.0)
const HERO_SELECTOR_STYLE_BORDER := Color(0.27, 0.42, 0.56, 1.0)
const HERO_SELECTOR_STYLE_SELECTED_BORDER := Color(0.86, 0.7, 0.4, 1.0)


func _ready() -> void:
	_tooltip_close.pressed.connect(_hide_item_tooltip)
	_details.minimum_size_changed.connect(_queue_tooltip_layout)
	_item_tooltip.resized.connect(_reposition_item_tooltip)
	_use_button.pressed.connect(_use_selected)
	_close_button.pressed.connect(close_by_player)
	_equip_button.pressed.connect(_equip_selected)
	_unequip_button.pressed.connect(_unequip_selected)
	_equip_target.item_selected.connect(_on_comparison_target_changed)
	_mannequin.item_transferred.connect(_transfer_item)
	_mannequin.slot_selected.connect(_select_equipped)
	for slot: EquipmentSlotControl in _mannequin.slots.values():
		slot.drag_started.connect(_hide_item_tooltip)
	_columns.resized.connect(_layout_body)
	get_viewport().size_changed.connect(_resize_card)
	_resize_card()
	hide()
	set_process_input(false)


func open_for(session: GameSession) -> void:
	if session == null or session.hero == null:
		return
	_cancel_drag()
	if _session != null:
		_session.inventory_member = null
	_session = session
	_selected_member = session.hero
	_session.inventory_member = _selected_member
	_rebuild_hero_selector()
	_hide_item_tooltip()
	_reset_selection()
	_use_feedback.text = ""
	_resize_card()
	_refresh_contents()
	show()
	_layout_body()
	set_process_input(true)
	_close_button.grab_focus()



func _rebuild_hero_selector() -> void:
	_selector_members.clear()
	for member in _session.party_members():
		if member != null and member.health > 0:
			_selector_members.append(member)
	while _hero_selector.get_child_count() > _selector_members.size():
		var child: Node = _hero_selector.get_child(_hero_selector.get_child_count() - 1)
		_hero_selector.remove_child(child)
		child.queue_free()
	while _hero_selector.get_child_count() < _selector_members.size():
		var index: int = _hero_selector.get_child_count()
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = HERO_SELECTOR_BUTTON_SIZE
		button.pressed.connect(_select_member_at.bind(index))
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.anchor_right = 1.0
		portrait.anchor_bottom = 1.0
		portrait.offset_left = HERO_SELECTOR_PORTRAIT_MARGIN
		portrait.offset_top = HERO_SELECTOR_PORTRAIT_MARGIN
		portrait.offset_right = -HERO_SELECTOR_PORTRAIT_MARGIN
		portrait.offset_bottom = -HERO_SELECTOR_PORTRAIT_MARGIN
		button.add_child(portrait)
		_hero_selector.add_child(button)
	for index in range(_selector_members.size()):
		var button: Button = _hero_selector.get_child(index) as Button
		var member: HeroState = _selector_members[index]
		var portrait: TextureRect = button.get_node("Portrait") as TextureRect
		portrait.texture = member.definition.portrait
		button.text = ""
		button.tooltip_text = member.definition.display_name
		button.set_pressed_no_signal(member == _selected_member)
		_apply_hero_selector_button_theme(button, member == _selected_member)


func _select_member_at(index: int) -> void:
	if index >= 0 and index < _selector_members.size():
		_select_member(_selector_members[index])


func _select_member(member: HeroState) -> void:
	if _session == null or not _session.party.has(member) or member.health <= 0:
		return
	_cancel_drag()
	_hide_item_tooltip()
	_selected_member = member
	_session.inventory_member = member
	_reset_selection()
	_rebuild_hero_selector()
	_gold_label.text = "%d" % _selected_member.gold
	_mannequin.show_hero(_session)
	_selected_index = _first_occupied_slot()
	_update_selection()


func _apply_hero_selector_button_theme(button: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = HERO_SELECTOR_STYLE_SELECTED if selected else HERO_SELECTOR_STYLE_NORMAL
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = HERO_SELECTOR_STYLE_SELECTED_BORDER if selected else HERO_SELECTOR_STYLE_BORDER
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_right = 8
	normal.corner_radius_bottom_left = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = HERO_SELECTOR_STYLE_SELECTED if selected else HERO_SELECTOR_STYLE_HOVER
	hover.border_color = HERO_SELECTOR_STYLE_SELECTED_BORDER if selected else Color(0.39, 0.58, 0.74, 1.0)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = HERO_SELECTOR_STYLE_SELECTED
	pressed.border_color = HERO_SELECTOR_STYLE_SELECTED_BORDER
	var focus := pressed.duplicate() as StyleBoxFlat
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", normal)


func _reset_selection() -> void:
	_selected_index = -1
	_selected_equipped_slot = ""
	_selected_instance_id = ""
	_selected_item_id = ""
	_comparison_target = ""


func _ensure_bag_slots(count: int) -> void:
	while _bag_slots.size() > count:
		var slot: InventoryGridSlot = _bag_slots.pop_back()
		_bag_grid.remove_child(slot)
		slot.queue_free()
	while _bag_slots.size() < count:
		var slot := InventoryGridSlot.new()
		_bag_grid.add_child(slot)
		slot.activated.connect(_on_bag_slot_activated)
		slot.transferred.connect(_transfer_item)
		_bag_slots.append(slot)


func _refresh_contents() -> void:
	_cancel_touch_drag()
	_entries = _session.inventory_slot_ids()
	_ensure_bag_slots(_entries.size())
	_layout_body()
	_gold_label.text = "%d" % _selected_member.gold
	_mannequin.show_hero(_session)
	_restore_selection()
	for index in range(_entries.size()):
		var item_id: String = _entries[index]
		var definition: ItemDefinition = ItemCatalog.get_item(item_id) if not item_id.is_empty() else null
		var quantity: int = _session.inventory_slot_quantity(index)
		_bag_slots[index].configure(index, definition, quantity, index == _selected_index, _bag_cell_size, _session)
	_update_selection()


func _restore_selection() -> void:
	if not _selected_instance_id.is_empty():
		_selected_index = -1
		_selected_equipped_slot = ""
		for index in range(_entries.size()):
			if _session.inventory_instance_id(index) == _selected_instance_id:
				_selected_index = index
				return
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			if _session.equipment_instance_id(slot_id) == _selected_instance_id:
				_selected_equipped_slot = slot_id
				return
		_reset_selection()
	elif not _selected_item_id.is_empty():
		if _selected_index < 0 or _selected_index >= _entries.size() or _entries[_selected_index] != _selected_item_id:
			_selected_index = _entries.find(_selected_item_id)
	if not _selected_equipped_slot.is_empty() and _session.equipment_item_id(_selected_equipped_slot).is_empty():
		_selected_equipped_slot = ""
	if _selected_equipped_slot.is_empty() and (_selected_index < 0 or _selected_index >= _entries.size() or _entries[_selected_index].is_empty()):
		_selected_index = _first_occupied_slot()
		_comparison_target = ""


func _update_selection() -> void:
	if _highlighted_index >= 0 and _highlighted_index < _bag_slots.size() and _highlighted_index != _selected_index:
		_bag_slots[_highlighted_index].set_selected(false)
	if _selected_index >= 0 and _selected_index < _bag_slots.size():
		_bag_slots[_selected_index].set_selected(true)
	_highlighted_index = _selected_index
	_mannequin.set_selected_slot(_selected_equipped_slot)
	if not _selected_equipped_slot.is_empty():
		_selected_instance_id = _session.equipment_instance_id(_selected_equipped_slot)
		_selected_item_id = _session.equipment_item_id(_selected_equipped_slot)
		_show_item_definition(_selected_item_id, -1, _selected_equipped_slot)
	elif _selected_index >= 0:
		_selected_instance_id = _session.inventory_instance_id(_selected_index)
		_selected_item_id = _entries[_selected_index]
		_show_item_definition(_selected_item_id, _selected_index)
	else:
		_selected_instance_id = ""
		_selected_item_id = ""
		_clear_item_info()


func _first_occupied_slot() -> int:
	for index in range(_entries.size()):
		if not _entries[index].is_empty():
			return index
	return -1


func _transfer_item(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant) -> void:
	if _session == null or not _session.transfer_inventory_item(from_kind, from_slot, to_kind, to_slot):
		return
	_reset_selection()
	_selected_index = int(to_slot) if to_kind == "bag" else -1
	_selected_equipped_slot = str(to_slot) if to_kind == "equipment" else ""
	_refresh_contents()
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
	_hide_item_tooltip()
	_reset_selection()
	if not _session.equipment_item_id(slot_id).is_empty():
		_selected_equipped_slot = slot_id
	_update_selection()
	if not _selected_equipped_slot.is_empty():
		_show_item_tooltip()


func _clear_item_info() -> void:
	_item_icon.texture = null
	_item_name.text = ""
	_item_name.remove_theme_color_override("font_color")
	_item_description.text = ""
	_item_properties.text = ""
	_item_properties.hide()
	_comparison_text = ""
	_item_comparison.text = ""
	_item_comparison.hide()
	_comparison_separator.hide()
	_equip_target.hide()
	_equip_button.hide()
	_unequip_button.hide()
	_use_button.hide()
	_hide_item_tooltip()


func _on_bag_slot_activated(index: int) -> void:
	if _session == null or index < 0 or index >= _entries.size():
		return
	if _entries[index].is_empty():
		_hide_item_tooltip()
		return
	_show_item(index)
	_show_item_tooltip()


func _use_selected() -> void:
	if _session == null or _selected_index < 0 or _selected_index >= _entries.size():
		return
	var index: int = _selected_index
	var item_id: String = _entries[index]
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item != null and item.category == ItemDefinition.Category.CONSUMABLE:
		item_use_requested.emit(item_id, index)


func _show_item(index: int) -> void:
	if index < 0 or index >= _entries.size() or _session == null:
		return
	var item_id := _entries[index]
	if item_id.is_empty():
		return
	if index != _selected_index or not _selected_equipped_slot.is_empty():
		_comparison_target = ""
	_selected_index = index
	_selected_equipped_slot = ""
	_update_selection()


func _show_item_definition(item_id: String, bag_index: int = -1, equipped_slot: String = "") -> void:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null:
		_clear_item_info()
		return
	var instance_id: String = _session.inventory_instance_id(bag_index) if bag_index >= 0 else (_session.equipment_instance_id(equipped_slot) if not equipped_slot.is_empty() else "")
	var instance: ItemInstance = _session.item_instance(instance_id)
	_item_icon.texture = item.icon
	_item_name.text = ItemMagicCatalog.display_name(item, instance)
	_item_name.add_theme_color_override("font_color", ItemMagicCatalog.display_color(instance))
	_item_description.text = item.get_description(instance, true)
	_detail_scroll.scroll_vertical = 0
	_update_equipment_actions(item, instance, bag_index, equipped_slot)
	_use_button.visible = bag_index >= 0 and item.category == ItemDefinition.Category.CONSUMABLE
	_use_feedback.text = ""
	var details := PackedStringArray()
	if item.stackable and bag_index >= 0:
		details.append("Количество: %d / %d" % [_session.inventory_slot_quantity(bag_index), item.stack_limit()])
	if not equipped_slot.is_empty():
		details.append("Надето")
	_item_properties.text = "\n".join(details)
	_item_properties.visible = not details.is_empty()
	_queue_tooltip_layout()


func _comparison_slot(item: ItemDefinition) -> String:
	if not _comparison_target.is_empty() and EquipmentSlotRules.accepts(_comparison_target, item):
		return _comparison_target
	if item.equipment_slot == ItemDefinition.EquipmentSlot.RING:
		if str(_selected_member.equipped_accessories.get("ring_left", "")).is_empty():
			return "ring_left"
		if str(_selected_member.equipped_accessories.get("ring_right", "")).is_empty():
			return "ring_right"
		return "ring_left"
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if EquipmentSlotRules.accepts(slot_id, item):
			return slot_id
	return ""


func _update_equipment_actions(item: ItemDefinition, instance: ItemInstance, bag_index: int, equipped_slot: String) -> void:
	_comparison_text = ""
	_item_comparison.text = ""
	_item_comparison.hide()
	_comparison_separator.hide()
	_equip_target.hide()
	_equip_button.hide()
	_unequip_button.hide()
	if _session == null or _selected_member == null or item.category != ItemDefinition.Category.EQUIPMENT:
		return
	if not equipped_slot.is_empty():
		_unequip_button.show()
		_unequip_button.disabled = _entries.find("") < 0
		return
	if bag_index < 0:
		return
	var compare_slot: String = _comparison_slot(item)
	if compare_slot.is_empty():
		return
	if item.equipment_slot == ItemDefinition.EquipmentSlot.RING:
		_equip_target.clear()
		for ring_slot in ["ring_left", "ring_right"]:
			_equip_target.add_item(str(EquipmentSlotRules.LABELS[ring_slot]) + (" (левое)" if ring_slot == "ring_left" else " (правое)"))
			_equip_target.set_item_metadata(_equip_target.item_count - 1, ring_slot)
		_equip_target.select(0 if compare_slot == "ring_left" else 1)
		_equip_target.show()
	_equip_button.show()
	_equip_button.text = "Заменить" if not _session.equipment_item_id(compare_slot).is_empty() else "Надеть"
	_equip_button.disabled = not _session.can_transfer_inventory_item("bag", bag_index, "equipment", compare_slot)
	var equipped_id: String = _session.equipment_item_id(compare_slot)
	var equipped_item: ItemDefinition = ItemCatalog.get_item(equipped_id)
	var equipped_instance: ItemInstance = _session.item_instance(_session.equipment_instance_id(compare_slot))
	var equipped_name: String = ItemMagicCatalog.display_name(equipped_item, equipped_instance) if equipped_item != null else "Пусто"
	var before: Dictionary = CharacterStats.hero_values(_selected_member)
	var after: Dictionary = CharacterStats.preview_equipment(_selected_member, compare_slot, item, instance)
	var lines := PackedStringArray()
	var name_text: String = DescriptionTemplate.colored(equipped_name, ItemMagicCatalog.display_color(equipped_instance)) if equipped_item != null else equipped_name
	lines.append("Надето (%s): %s" % [EquipmentSlotRules.LABELS[compare_slot], name_text])
	if equipped_item != null:
		lines.append_array(DescriptionTemplate.equipment_properties(equipped_item, equipped_instance, true))
	if not after.is_empty():
		var differences: PackedStringArray = DescriptionTemplate.comparison_details(before, after)
		lines.append("")
		lines.append("После замены для %s:" % DescriptionTemplate.escape_bbcode(_selected_member.definition.display_name))
		lines.append_array(differences if not differences.is_empty() else PackedStringArray(["Характеристики не изменятся"]))
	_comparison_text = "\n".join(lines)
	_item_comparison.text = _comparison_text
	_item_comparison.show()
	_comparison_separator.show()


func _on_comparison_target_changed(index: int) -> void:
	if _session == null or _selected_index < 0:
		return
	_comparison_target = str(_equip_target.get_item_metadata(index))
	_show_item_definition(_entries[_selected_index], _selected_index)


func _equip_selected() -> void:
	if _session == null or _selected_index < 0 or _selected_index >= _entries.size():
		return
	var item: ItemDefinition = ItemCatalog.get_item(_entries[_selected_index])
	if item == null:
		return
	var slot_id: String = _comparison_slot(item)
	if not slot_id.is_empty():
		_transfer_item("bag", _selected_index, "equipment", slot_id)


func _unequip_selected() -> void:
	if _session == null or _selected_equipped_slot.is_empty():
		return
	var empty_index: int = _session.inventory_slot_ids().find("")
	if empty_index >= 0:
		_transfer_item("equipment", _selected_equipped_slot, "bag", empty_index)


func show_use_result(item_id: String, message: String) -> void:
	if _session == null:
		return
	_refresh_contents()
	if _selected_item_id != item_id:
		var index: int = _entries.find(item_id)
		if index >= 0:
			_show_item(index)
		else:
			_hide_item_tooltip()
	_use_feedback.text = message
	_queue_tooltip_layout()


func show_equipment_result(item_id: String, message: String = "") -> void:
	if _session == null:
		return
	_refresh_contents()
	if _selected_item_id != item_id:
		var index: int = _entries.find(item_id)
		if index >= 0:
			_show_item(index)
	_use_feedback.text = message
	_queue_tooltip_layout()


func _resize_card() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_card.custom_minimum_size = Vector2(
		minf(1190.0, maxf(1.0, viewport_size.x - 24.0)),
		minf(760.0, maxf(1.0, viewport_size.y - 24.0))
	)
	_layout_body()


func _layout_body() -> void:
	var available: Vector2 = _columns.size
	if available.x <= 0.0 or available.y <= 0.0:
		return
	var gap: float = 14.0
	var stacked: bool = available.x < available.y * 1.5
	var bag_size: Vector2
	var equipment_size: Vector2
	if stacked:
		var bag_height: float = maxf(0.0, available.y - gap) * 0.42
		bag_size = Vector2(available.x, bag_height)
		equipment_size = Vector2(available.x, maxf(0.0, available.y - bag_height - gap))
		_equipment_area.position = Vector2(0.0, bag_height + gap)
	else:
		var bag_width: float = maxf(0.0, available.x - gap) * 0.60
		bag_size = Vector2(bag_width, available.y)
		equipment_size = Vector2(maxf(0.0, available.x - bag_width - gap), available.y)
		_equipment_area.position = Vector2(bag_width + gap, 0.0)
	_bag.size = bag_size
	var fitted_width: float = minf(equipment_size.x, equipment_size.y * 1.2)
	_equipment_area.position.x += (equipment_size.x - fitted_width) * 0.5
	equipment_size.x = fitted_width
	_equipment_area.size = equipment_size
	var columns: int = _bag_grid.columns
	var rows: int = maxi(1, ceili(float(_bag_slots.size()) / float(columns)))
	var h_gap: float = float(_bag_grid.get_theme_constant("h_separation"))
	var v_gap: float = float(_bag_grid.get_theme_constant("v_separation"))
	_bag_cell_size = maxf(1.0, floorf(minf(59.0, minf(
		(bag_size.x - h_gap * (columns - 1)) / columns,
		(bag_size.y - v_gap * (rows - 1)) / rows
	))))
	for slot in _bag_slots:
		slot.set_cell_size(_bag_cell_size)
	var grid_size := Vector2(
		_bag_cell_size * columns + h_gap * (columns - 1),
		_bag_cell_size * rows + v_gap * (rows - 1)
	)
	_bag_grid.size = grid_size
	_bag_grid.position = (bag_size - grid_size) * 0.5
	_queue_tooltip_layout()


func _show_item_tooltip() -> void:
	_item_tooltip.show()
	_reposition_item_tooltip()
	_queue_tooltip_layout()


func _hide_item_tooltip() -> void:
	_item_tooltip.hide()


func _queue_tooltip_layout() -> void:
	if not _item_tooltip.visible or _tooltip_layout_pending:
		return
	_tooltip_layout_pending = true
	call_deferred("_layout_item_tooltip")


func _layout_item_tooltip() -> void:
	if not visible or not _item_tooltip.visible:
		_tooltip_layout_pending = false
		return
	var bounds: Rect2 = get_viewport().get_visible_rect().grow(-8.0)
	var width: float = minf(380.0, bounds.size.x)
	_item_tooltip.size.x = width
	_reposition_item_tooltip()
	await get_tree().process_frame
	_tooltip_layout_pending = false
	if not visible or not _item_tooltip.visible:
		return
	bounds = get_viewport().get_visible_rect().grow(-8.0)
	if not is_equal_approx(width, minf(380.0, bounds.size.x)):
		_queue_tooltip_layout()
		return
	var chrome: float = _item_tooltip.get_combined_minimum_size().y - _detail_scroll.get_combined_minimum_size().y
	var available_height: float = maxf(0.0, bounds.size.y * 0.8 - chrome)
	var detail_height: float = minf(_details.get_combined_minimum_size().y, available_height)
	_detail_scroll.custom_minimum_size.y = detail_height
	_item_tooltip.size = Vector2(width, chrome + detail_height)
	_reposition_item_tooltip()


func _reposition_item_tooltip() -> void:
	if not visible or not _item_tooltip.visible:
		return
	var source: Control
	if _selected_index >= 0 and _selected_index < _bag_slots.size():
		source = _bag_slots[_selected_index]
	elif not _selected_equipped_slot.is_empty():
		source = _mannequin.slots.get(_selected_equipped_slot) as Control
	if source == null:
		_hide_item_tooltip()
		return
	var bounds: Rect2 = get_viewport().get_visible_rect().grow(-8.0)
	var extent: Vector2 = _item_tooltip.size
	var anchor: Rect2 = source.get_global_rect()
	var gap: float = 8.0
	var candidates: Array[Vector2] = [
		Vector2(anchor.end.x + gap, clampf(anchor.position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - extent.y))),
		Vector2(anchor.position.x - extent.x - gap, clampf(anchor.position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - extent.y))),
		Vector2(clampf(anchor.position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - extent.x)), anchor.end.y + gap),
		Vector2(clampf(anchor.position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - extent.x)), anchor.position.y - extent.y - gap)
	]
	for candidate in candidates:
		if bounds.encloses(Rect2(candidate, extent)):
			_item_tooltip.position = candidate
			return
	_item_tooltip.position = Vector2(
		clampf(candidates[0].x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - extent.x)),
		clampf(candidates[0].y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - extent.y))
	)


func _source_at(point: Vector2) -> Dictionary:
	for child in _bag_slots:
		if not child.item_id.is_empty() and child.get_global_rect().has_point(point):
			return {"kind": "bag", "slot": child.slot_index}
	for slot_id in _mannequin.slots:
		var slot: EquipmentSlotControl = _mannequin.slots[slot_id]
		if not slot.item_id.is_empty() and slot.get_global_rect().has_point(point):
			return {"kind": "equipment", "slot": slot_id}
	return {}


func _target_at(point: Vector2) -> Dictionary:
	for child in _bag_slots:
		if child.get_global_rect().has_point(point):
			return {"kind": "bag", "slot": child.slot_index}
	for slot_id in _mannequin.slots:
		var slot: EquipmentSlotControl = _mannequin.slots[slot_id]
		if slot.get_global_rect().has_point(point):
			return {"kind": "equipment", "slot": slot_id}
	return {}


func _dismiss_tooltip_outside(point: Vector2) -> bool:
	if not _item_tooltip.visible:
		return false
	if _item_tooltip.get_global_rect().has_point(point):
		return true
	_hide_item_tooltip()
	return false


func _input(event: InputEvent) -> void:
	if not visible or _session == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dismiss_tooltip_outside(event.position)
	if event is InputEventScreenTouch:
		if event.pressed and _dismiss_tooltip_outside(event.position):
			return
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
			if event.canceled:
				_cancel_touch_drag()
				return
			if _touch_dragging:
				var destination: Dictionary = _target_at(event.position)
				if not destination.is_empty():
					_transfer_item(str(_touch_source["kind"]), _touch_source["slot"], str(destination["kind"]), destination["slot"])
			elif event.position.distance_to(_touch_origin) < 16.0:
				var destination: Dictionary = _target_at(event.position)
				if destination == _touch_source:
					if destination["kind"] == "bag":
						_on_bag_slot_activated(int(destination["slot"]))
					else:
						_select_equipped(str(destination["slot"]))
			_cancel_touch_drag()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		if not _touch_dragging and event.position.distance_to(_touch_origin) > 16.0 and Time.get_ticks_msec() - _touch_started_at >= 180:
			_touch_dragging = true
			_hide_item_tooltip()
			_touch_preview = TextureRect.new()
			var item_id: String = ""
			if str(_touch_source["kind"]) == "bag":
				item_id = _entries[int(_touch_source["slot"])]
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


func _set_touch_target_state(destination: Dictionary, state: int) -> void:
	if destination.is_empty():
		return
	if destination["kind"] == "bag":
		var index: int = int(destination["slot"])
		if index >= 0 and index < _bag_slots.size():
			_bag_slots[index].set_drag_drop_state(state, "touch")
	else:
		var slot: EquipmentSlotControl = _mannequin.slots.get(destination["slot"]) as EquipmentSlotControl
		if slot != null:
			slot.set_drag_drop_state(state, "touch")


func _update_touch_target(destination: Dictionary) -> void:
	if destination == _touch_target:
		return
	_set_touch_target_state(_touch_target, 0)
	_touch_target = destination.duplicate()
	if not destination.is_empty():
		var accepted: bool = _session.can_transfer_inventory_item(str(_touch_source["kind"]), _touch_source["slot"], str(destination["kind"]), destination["slot"])
		_set_touch_target_state(destination, 1 if accepted else 2)


func _cancel_touch_drag() -> void:
	_touch_index = -1
	_touch_source.clear()
	_touch_dragging = false
	_set_touch_target_state(_touch_target, 0)
	_touch_target.clear()
	if _touch_preview != null:
		_touch_preview.queue_free()
		_touch_preview = null


func _cancel_drag() -> void:
	_cancel_touch_drag()
	if visible and get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()
	for slot in _bag_slots:
		slot.cancel_gesture()
	for slot in _mannequin.slots.values():
		slot.set_drag_drop_state(0)


func close_by_player() -> void:
	dismiss()
	closed.emit()


func dismiss() -> void:
	_hide_item_tooltip()
	_cancel_drag()
	hide()
	set_process_input(false)
	if _session != null:
		_session.inventory_member = null
	_session = null
	_selected_member = null
	_selector_members.clear()
	for slot in _bag_slots:
		slot.session = null
	_mannequin.clear_session()
	_reset_selection()
