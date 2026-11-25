extends SceneTree


func _initialize() -> void:
	await _test_equipment_actions_and_magic_instances()
	await _test_ring_choice_and_party_members()
	print("DA-6.08: equipment comparison and direct actions OK")
	quit()


func _session() -> GameSession:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for_party(dungeon, ["petushan", "volcha"])


func _open(session: GameSession) -> InventoryView:
	var scene: PackedScene = load("res://scenes/inventory_view.tscn") as PackedScene
	assert(scene != null)
	var view: InventoryView = scene.instantiate() as InventoryView
	root.add_child(view)
	view.open_for(session)
	return view


func _test_equipment_actions_and_magic_instances() -> void:
	var session: GameSession = _session()
	assert(session._receive_item("sword", 2) == 2)
	var bag_index: int = session.inventory_slot_ids().find("sword")
	assert(bag_index >= 0)
	var magic_id: String = session.inventory_instance_id(bag_index)
	var old_id: String = session.equipment_instance_id("main_hand")
	assert(magic_id != old_id)
	var magic: ItemInstance = session.item_instance(magic_id)
	magic.quality_id = "sturdy"
	magic.rarity = ItemInstance.Rarity.MAGIC
	magic.affix_ids.append("edge")
	magic.modifiers["weapon_damage"] = 2
	var original: Dictionary = magic.to_dict()
	var view: InventoryView = _open(session)
	await process_frame
	var slot: InventoryGridSlot = view._bag_grid.get_child(bag_index) as InventoryGridSlot
	var center: Vector2 = slot.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = center
	touch.pressed = true
	view._input(touch)
	touch.pressed = false
	view._input(touch)
	assert(view._selected_index == bag_index)
	assert(view._equip_button.visible and not view._equip_button.disabled)
	assert(not view._item_action_menu.visible)
	assert(view._item_name.text == ItemMagicCatalog.display_name(ItemCatalog.get_item("sword"), magic))
	assert(view._item_name.text.contains("Добротное"))
	assert(view._item_properties.text.contains("Слот: Правая рука"))
	assert(view._item_properties.text.contains("Качество: Добротное"))
	assert(view._item_properties.text.contains("Редкость: волшебное"))
	assert(view._item_comparison.visible)
	assert(view._item_comparison.text.contains("Надето (Правая рука):"))
	assert(view._item_comparison.text.contains("Ближний урон:"))
	view._equip_button.pressed.emit()
	assert(session.equipment_instance_id("main_hand") == magic_id)
	assert(session.inventory_instance_id(bag_index) == old_id)
	assert(session.item_instance(magic_id).to_dict() == original)
	assert(view._unequip_button.visible and not view._unequip_button.disabled)
	view._unequip_button.pressed.emit()
	assert(session.equipment_item_id("main_hand").is_empty())
	assert(session.item_instance(magic_id).to_dict() == original)
	var found: bool = false
	for index in range(session.inventory_slot_ids().size()):
		if session.inventory_instance_id(index) == magic_id:
			found = true
			break
	assert(found)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(saved, {session.map_data.map_id: session.map_data})
	assert(restored != null)
	assert(restored.item_instance(magic_id) != null)
	assert(restored.item_instance(magic_id).to_dict() == original)
	assert(view._equip_button.custom_minimum_size.y >= 40.0)
	assert(view._hero_selector is HFlowContainer)
	view.queue_free()
	await process_frame


func _test_ring_choice_and_party_members() -> void:
	var session: GameSession = _session()
	assert(session._receive_item("ring_copper_wire", 3) == 3)
	for ring_slot in ["ring_left", "ring_right"]:
		var equip_index: int = session.inventory_slot_ids().find("ring_copper_wire")
		assert(equip_index >= 0)
		assert(session.transfer_inventory_item("bag", equip_index, "equipment", ring_slot))
	var left_id: String = session.equipment_instance_id("ring_left")
	var right_id: String = session.equipment_instance_id("ring_right")
	var bag_index: int = session.inventory_slot_ids().find("ring_copper_wire")
	var new_id: String = session.inventory_instance_id(bag_index)
	assert(left_id != right_id and new_id != right_id)
	var ring: ItemInstance = session.item_instance(new_id)
	ring.quality_id = "masterwork"
	ring.rarity = ItemInstance.Rarity.MAGIC
	ring.affix_ids.append("might")
	ring.modifiers["strength_bonus"] = 3
	var expected: Dictionary = ring.to_dict()
	var view: InventoryView = _open(session)
	await process_frame
	view._on_bag_slot_activated(bag_index)
	assert(view._equip_target.visible and view._equip_target.item_count == 2)
	view._on_comparison_target_changed(1)
	assert(view._comparison_target == "ring_right")
	assert(view._item_comparison.text.contains("Надето (Кольцо):"))
	assert(view._item_comparison.text.contains("Сила:"))
	view._equip_button.pressed.emit()
	assert(session.equipment_instance_id("ring_right") == new_id)
	assert(session.equipment_instance_id("ring_left") == left_id)
	assert(session.inventory_instance_id(bag_index) == right_id)
	assert(session.item_instance(new_id).to_dict() == expected)
	view._select_member(session.party[1])
	assert(view._selected_member == session.party[1])
	assert(view._selected_equipped_slot.is_empty())
	assert(view._selected_index >= 0)
	assert(session.equipment_instance_id("ring_right", session.party[0]) == new_id)
	assert(session.equipment_instance_id("ring_right", session.party[1]).is_empty())
	view.queue_free()
	await process_frame
