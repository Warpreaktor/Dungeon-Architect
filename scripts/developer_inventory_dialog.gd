class_name DeveloperInventoryDialog
extends AcceptDialog

signal loadout_changed

var _session: GameSession
var _hero_selector: OptionButton
var _items: ItemList
var _item_selector: OptionButton
var _quality_selector: OptionButton
var _rarity_selector: OptionButton
var _affix_list: VBoxContainer
var _affix_controls: Dictionary = {}
var _quantity: SpinBox
var _feedback: Label
var _location_entries: Array[Dictionary] = []
var _updating: bool = false


func _ready() -> void:
	title = "Инвентарь разработчика"
	ok_button_text = "Закрыть"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.add_theme_constant_override("separation", 7)
	row.add_child(left)
	left.add_child(_caption("Герой"))
	_hero_selector = OptionButton.new()
	_hero_selector.item_selected.connect(_on_hero_selected)
	left.add_child(_hero_selector)
	left.add_child(_caption("Снаряжение и рюкзак"))
	_items = ItemList.new()
	_items.custom_minimum_size = Vector2(300, 380)
	_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items.item_selected.connect(_on_location_selected)
	left.add_child(_items)
	var inventory_actions := HBoxContainer.new()
	left.add_child(inventory_actions)
	inventory_actions.add_child(_action("Надеть", _equip_selected))
	inventory_actions.add_child(_action("Снять", _unequip_selected))
	inventory_actions.add_child(_action("Удалить", _remove_selected))

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 380
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	right.add_child(_caption("Предмет"))
	_item_selector = OptionButton.new()
	_item_selector.item_selected.connect(_on_item_selected)
	right.add_child(_item_selector)
	var number_row := HBoxContainer.new()
	right.add_child(number_row)
	number_row.add_child(_caption("Количество"))
	_quantity = SpinBox.new()
	_quantity.min_value = 1
	_quantity.max_value = 999
	_quantity.value = 1
	_quantity.custom_minimum_size.x = 90
	number_row.add_child(_quantity)
	right.add_child(_caption("Качество"))
	_quality_selector = OptionButton.new()
	right.add_child(_quality_selector)
	right.add_child(_caption("Редкость"))
	_rarity_selector = OptionButton.new()
	_rarity_selector.item_selected.connect(_on_rarity_selected)
	right.add_child(_rarity_selector)
	right.add_child(_caption("Магические свойства"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 240
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_affix_list = VBoxContainer.new()
	_affix_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_affix_list)
	var create_actions := HBoxContainer.new()
	right.add_child(create_actions)
	create_actions.add_child(_action("Добавить", _add_item))
	create_actions.add_child(_action("Изменить выбранное", _apply_properties))
	_feedback = _caption("")
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_feedback)
	_fill_item_choices()
	_fill_quality_choices()
	_fill_rarity_choices()
	_update_affixes()


func open_for(session: GameSession) -> void:
	if not DeveloperMode.is_enabled() or session == null or not session.is_editor_test:
		return
	_session = session
	_hero_selector.clear()
	for member in session.party:
		_hero_selector.add_item(member.definition.display_name)
	_hero_selector.select(0)
	_session.inventory_member = session.party[0]
	_feedback.text = ""
	_refresh_locations()
	_update_affixes()
	popup_centered_clamped(Vector2i(750, 600))


func _caption(value: String) -> Label:
	var label := Label.new()
	label.text = value
	return label


func _action(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	return button


func _fill_item_choices() -> void:
	_item_selector.clear()
	var ids: Array[String] = ResourceCatalog.list_ids(ItemCatalog.ITEM_DIRECTORY)
	for id in ids:
		var item: ItemDefinition = ItemCatalog.get_item(id)
		if item == null:
			continue
		_item_selector.add_item(item.display_name)
		_item_selector.set_item_metadata(_item_selector.item_count - 1, id)


func _fill_quality_choices() -> void:
	_quality_selector.clear()
	for entry in ItemMagicCatalog.RULES.qualities:
		if entry == null:
			continue
		_quality_selector.add_item(entry.display_name)
		_quality_selector.set_item_metadata(_quality_selector.item_count - 1, entry.quality_id)


func _fill_rarity_choices() -> void:
	_rarity_selector.clear()
	for entry in ItemMagicCatalog.RULES.rarities:
		if entry == null:
			continue
		_rarity_selector.add_item(entry.display_name)
		_rarity_selector.set_item_metadata(_rarity_selector.item_count - 1, entry.tier)


func _selected_item() -> ItemDefinition:
	return ItemCatalog.get_item(str(_item_selector.get_selected_metadata()))


func _selected_location() -> Dictionary:
	var indices: PackedInt32Array = _items.get_selected_items()
	return _location_entries[indices[0]] if not indices.is_empty() and indices[0] < _location_entries.size() else {}


func _refresh_locations(preferred_id: String = "") -> void:
	_items.clear()
	_location_entries.clear()
	if _session == null:
		return
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var item_id: String = _session.equipment_item_id(slot_id)
		if item_id.is_empty():
			continue
		var instance_id: String = _session.equipment_instance_id(slot_id)
		_add_location({"kind": "equipment", "slot": slot_id, "instance_id": instance_id, "item_id": item_id}, "%s: %s" % [str(EquipmentSlotRules.LABELS[slot_id]), _item_name(item_id, instance_id)])
	var bag: Array[String] = _session.inventory_slot_ids()
	for index in range(bag.size()):
		var item_id: String = bag[index]
		if item_id.is_empty():
			continue
		var instance_id: String = _session.inventory_instance_id(index)
		var count: int = _session.inventory_slot_quantity(index)
		_add_location({"kind": "bag", "slot": index, "instance_id": instance_id, "item_id": item_id}, "Рюкзак %d: %s%s" % [index + 1, _item_name(item_id, instance_id), " × %d" % count if count > 1 else ""])
	if _items.item_count > 0:
		var index: int = 0
		for i in range(_location_entries.size()):
			if _location_entries[i]["instance_id"] == preferred_id and not preferred_id.is_empty():
				index = i
				break
		_items.select(index)
		_show_selected_item()


func _item_name(item_id: String, instance_id: String) -> String:
	return ItemMagicCatalog.display_name(ItemCatalog.get_item(item_id), _session.item_instance(instance_id))


func _add_location(entry: Dictionary, label: String) -> void:
	_location_entries.append(entry)
	_items.add_item(label)


func _on_hero_selected(index: int) -> void:
	if _session == null or index < 0 or index >= _session.party.size():
		return
	_session.inventory_member = _session.party[index]
	_refresh_locations()


func _on_location_selected(_index: int) -> void:
	_show_selected_item()


func _show_selected_item() -> void:
	var location: Dictionary = _selected_location()
	if location.is_empty():
		return
	_updating = true
	var item_id: String = str(location["item_id"])
	for i in range(_item_selector.item_count):
		if str(_item_selector.get_item_metadata(i)) == item_id:
			_item_selector.select(i)
			break
	var instance: ItemInstance = _session.item_instance(str(location["instance_id"]))
	if instance != null:
		_select_metadata(_quality_selector, instance.quality_id)
		_select_metadata(_rarity_selector, instance.rarity)
	else:
		_select_metadata(_quality_selector, ItemMagicCatalog.RULES.default_quality_id)
		_select_metadata(_rarity_selector, ItemInstance.Rarity.COMMON)
	_updating = false
	_update_affixes(instance)


func _select_metadata(control: OptionButton, value: Variant) -> void:
	for index in range(control.item_count):
		if control.get_item_metadata(index) == value:
			control.select(index)
			return


func _on_item_selected(_index: int) -> void:
	if _updating:
		return
	_select_metadata(_quality_selector, ItemMagicCatalog.RULES.default_quality_id)
	_select_metadata(_rarity_selector, ItemInstance.Rarity.COMMON)
	_update_affixes()


func _on_rarity_selected(_index: int) -> void:
	if not _updating:
		_update_affixes()


func _update_affixes(instance: ItemInstance = null) -> void:
	for child in _affix_list.get_children():
		_affix_list.remove_child(child)
		child.queue_free()
	_affix_controls.clear()
	var item: ItemDefinition = _selected_item()
	var equipment: bool = item != null and item.category == ItemDefinition.Category.EQUIPMENT and not item.stackable
	_quality_selector.disabled = not equipment
	_rarity_selector.disabled = not equipment
	_quantity.editable = not equipment
	if not equipment:
		return
	var rarity: ItemRarityDefinition = ItemMagicCatalog.rarity(int(_rarity_selector.get_selected_metadata()))
	if rarity == null or rarity.maximum_affixes == 0:
		return
	for entry in ItemMagicCatalog.RULES.affixes:
		if entry == null or not entry.accepts(item) or not ItemMagicCatalog.modifier_is_valid(item, entry.stat_id):
			continue
		var line := HBoxContainer.new()
		_affix_list.add_child(line)
		var toggle := CheckBox.new()
		toggle.text = entry.display_name
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(toggle)
		var value := SpinBox.new()
		value.min_value = mini(entry.minimum_value, entry.maximum_value)
		value.max_value = maxi(entry.minimum_value, entry.maximum_value)
		value.value = value.min_value
		value.custom_minimum_size.x = 95
		line.add_child(value)
		_affix_controls[entry.affix_id] = {"check": toggle, "value": value, "definition": entry}
		if instance != null and instance.affix_ids.has(entry.affix_id):
			toggle.button_pressed = true
			value.value = int(instance.modifiers.get(entry.stat_id, value.value))


func _magic_options(item: ItemDefinition) -> Dictionary:
	if item == null or item.category != ItemDefinition.Category.EQUIPMENT or item.stackable:
		return {}
	var quality_id: String = str(_quality_selector.get_selected_metadata())
	var quality: ItemQualityDefinition = ItemMagicCatalog.quality(quality_id)
	var rarity: ItemRarityDefinition = ItemMagicCatalog.rarity(int(_rarity_selector.get_selected_metadata()))
	if quality == null or not quality.accepts(item) or rarity == null or not rarity.accepts(item):
		return {}
	var affixes: Array[String] = []
	var modifiers: Dictionary = {}
	for affix_id in _affix_controls:
		var control: Dictionary = _affix_controls[affix_id]
		if not (control["check"] as CheckBox).button_pressed:
			continue
		var definition: ItemAffixDefinition = control["definition"]
		var number: int = roundi((control["value"] as SpinBox).value)
		affixes.append(str(affix_id))
		modifiers[definition.stat_id] = int(modifiers.get(definition.stat_id, 0)) + number
	if affixes.size() < rarity.minimum_affixes or affixes.size() > rarity.maximum_affixes:
		_feedback.text = "Для этой редкости нужно свойств: %d–%d" % [rarity.minimum_affixes, rarity.maximum_affixes]
		return {}
	return {"quality_id": quality_id, "rarity": rarity.tier, "affix_ids": affixes, "modifiers": modifiers}


func _apply_magic(instance: ItemInstance, item: ItemDefinition, options: Dictionary) -> bool:
	if instance == null or options.is_empty():
		return false
	var saved: Dictionary = instance.to_dict()
	saved["quality_id"] = options["quality_id"]
	saved["rarity"] = options["rarity"]
	saved["affix_ids"] = options["affix_ids"]
	saved["modifiers"] = options["modifiers"]
	if ItemInstance.from_dict(saved) == null:
		_feedback.text = "Недопустимые свойства для выбранного предмета"
		return false
	instance.quality_id = str(options["quality_id"])
	instance.rarity = int(options["rarity"])
	instance.affix_ids.assign(options["affix_ids"])
	instance.modifiers = options["modifiers"].duplicate(true)
	if item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD:
		instance.durability = maxi(instance.stat("max_durability"), instance.stat("defense_bonus"))
		_session.developer_refresh_shield(instance.instance_id)
	return true


func _add_item() -> void:
	if not DeveloperMode.is_enabled() or _session == null:
		return
	var item: ItemDefinition = _selected_item()
	if item == null:
		return
	var options: Dictionary = _magic_options(item) if item.category == ItemDefinition.Category.EQUIPMENT and not item.stackable else {}
	if item.category == ItemDefinition.Category.EQUIPMENT and not item.stackable and options.is_empty():
		return
	var count: int = 1 if not item.stackable else int(_quantity.value)
	var result: Dictionary = _session.developer_add_item(item.item_id, count)
	if int(result.get("received", 0)) <= 0:
		_feedback.text = "Нет свободного места в рюкзаке"
		return
	var instance_id: String = ""
	if item.category == ItemDefinition.Category.EQUIPMENT and not item.stackable:
		var ids: Array = result.get("instances", [])
		if ids.is_empty():
			return
		instance_id = str(ids[0])
		if not _apply_magic(_session.item_instance(instance_id), item, options):
			return
		for member in _session.party:
			member._recalculate_equipment_stats()
	_feedback.text = "Добавлено: %s ×%d" % [item.display_name, int(result["received"])]
	loadout_changed.emit()
	_refresh_locations(instance_id)


func _apply_properties() -> void:
	if not DeveloperMode.is_enabled() or _session == null:
		return
	var location: Dictionary = _selected_location()
	var instance: ItemInstance = _session.item_instance(str(location.get("instance_id", "")))
	if instance == null:
		_feedback.text = "Выберите снаряжение в списке"
		return
	var item: ItemDefinition = ItemCatalog.get_item(instance.item_id)
	var options: Dictionary = _magic_options(item)
	if options.is_empty() or not _apply_magic(instance, item, options):
		return
	for member in _session.party:
		member._recalculate_equipment_stats()
	_feedback.text = "Свойства изменены"
	loadout_changed.emit()
	_refresh_locations(instance.instance_id)


func _equip_selected() -> void:
	if not DeveloperMode.is_enabled() or _session == null:
		return
	var location: Dictionary = _selected_location()
	if str(location.get("kind", "")) != "bag":
		return
	var item: ItemDefinition = ItemCatalog.get_item(str(location["item_id"]))
	if item == null or item.category != ItemDefinition.Category.EQUIPMENT:
		return
	var slots: Array[String] = EquipmentSlotRules.SLOT_IDS
	for slot_id in slots:
		if EquipmentSlotRules.accepts(slot_id, item) and _session.equipment_item_id(slot_id).is_empty():
			if _session.transfer_inventory_item("bag", int(location["slot"]), "equipment", slot_id):
				loadout_changed.emit()
				_refresh_locations(str(location["instance_id"]))
				return
	_feedback.text = "Подходящий слот занят или экипировка несовместима"


func _unequip_selected() -> void:
	if not DeveloperMode.is_enabled() or _session == null:
		return
	var location: Dictionary = _selected_location()
	if str(location.get("kind", "")) != "equipment":
		return
	var index: int = _session.inventory_slot_ids().find("")
	if index < 0 or not _session.transfer_inventory_item("equipment", str(location["slot"]), "bag", index):
		_feedback.text = "В рюкзаке нет свободного места"
		return
	loadout_changed.emit()
	_refresh_locations(str(location["instance_id"]))


func _remove_selected() -> void:
	if not DeveloperMode.is_enabled() or _session == null:
		return
	var location: Dictionary = _selected_location()
	if str(location.get("kind", "")) != "bag":
		_feedback.text = "Сначала снимите предмет"
		return
	if not _session.developer_remove_bag_slot(int(location["slot"])):
		_feedback.text = "Не удалось удалить предмет"
		return
	loadout_changed.emit()
	_refresh_locations()
