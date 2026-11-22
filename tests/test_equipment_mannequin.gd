extends SceneTree


func _initialize() -> void:
	var map := DungeonMap.create_blank(5, 5)
	assert(map.place_entity("player_spawn", 2, 2))
	var session := GameSession.start_for(map)
	assert(session != null)
	assert(EquipmentSlotRules.SLOT_IDS.size() == 10)

	session._receive_item("sword", 2)
	session._receive_item("shield", 1)
	assert(session.equipment_item_id("main_hand") == "sword")
	assert(session.equipment_item_id("off_hand") == "shield")
	assert(session.inventory_slot_ids().count("sword") == 1)
	assert(session.inventory_slot_ids().count("shield") == 0)

	var sword_index: int = session.inventory_slot_ids().find("sword")
	assert(sword_index >= 0)
	assert(session.transfer_inventory_item("bag", sword_index, "equipment", "main_hand"))
	assert(session.inventory_slot_ids().count("sword") == 1)
	assert(not session.transfer_inventory_item("bag", sword_index, "equipment", "off_hand"))
	assert(not session.transfer_inventory_item("equipment", "off_hand", "equipment", "main_hand"))

	session._receive_item("warhammer", 1)
	var hammer_index: int = session.inventory_slot_ids().find("warhammer")
	assert(hammer_index >= 0)
	assert(session.transfer_inventory_item("bag", hammer_index, "equipment", "main_hand"))
	assert(session.equipment_item_id("main_hand") == "warhammer")
	assert(session.equipment_item_id("off_hand").is_empty())
	assert(session.inventory_slot_ids().count("shield") == 1)
	assert(session.inventory_slot_ids().count("sword") == 2)
	var shield_index: int = session.inventory_slot_ids().find("shield")
	assert(shield_index >= 0)
	assert(not session.transfer_inventory_item("bag", shield_index, "equipment", "off_hand"))
	assert(session.equipment_item_id("main_hand") == "warhammer")
	assert(session.inventory_slot_ids().count("shield") == 1)

	var free_index: int = session.inventory_slot_ids().find("")
	assert(free_index >= 0)
	assert(session.transfer_inventory_item("equipment", "main_hand", "bag", free_index))
	assert(session.equipment_item_id("main_hand").is_empty())
	assert(session.inventory_slot_ids()[free_index] == "warhammer")
	assert(session.transfer_inventory_item("bag", shield_index, "equipment", "off_hand"))
	assert(session.equipment_item_id("off_hand") == "shield")

	var full := GameSession.start_for(map)
	full._receive_item("shield", 1)
	full._receive_item("sword", 41)
	assert(full.inventory_slot_ids().count("") == 0)
	var before: Array[String] = full.inventory_slot_ids()
	assert(not full.transfer_inventory_item("equipment", "off_hand", "bag", 0))
	assert(full.equipment_item_id("off_hand") == "shield")
	assert(full.inventory_slot_ids() == before)

	var ring := ItemDefinition.new()
	ring.category = ItemDefinition.Category.EQUIPMENT
	ring.equipment_slot = ItemDefinition.EquipmentSlot.RING
	assert(EquipmentSlotRules.accepts("ring_left", ring))
	assert(EquipmentSlotRules.accepts("ring_right", ring))
	assert(not EquipmentSlotRules.accepts("neck", ring))

	var scene: PackedScene = load("res://scenes/inventory_view.tscn") as PackedScene
	assert(scene != null)
	var view: InventoryView = scene.instantiate() as InventoryView
	get_root().add_child.call_deferred(view)
	await process_frame
	view.open_for(session)
	assert(view.get_node("Center/Card/Margins/Content/BodyScroll/Columns/Bag/BagGrid").get_child_count() == 40)
	assert(view.get_node("Center/Card/Margins/Content/BodyScroll/Columns/EquipmentArea/EquipmentMannequin").slots.size() == 10)

	var two_handed := GameSession.start_for(map)
	two_handed._receive_item("warhammer", 1)
	assert(two_handed.hero.equipped_weapon_id == "warhammer")
	assert(two_handed.equipment_item_id("off_hand").is_empty())
	view.open_for(two_handed)
	var mannequin: EquipmentMannequin = view.get_node("Center/Card/Margins/Content/BodyScroll/Columns/EquipmentArea/EquipmentMannequin") as EquipmentMannequin
	var off_hand: EquipmentSlotControl = mannequin.slots["off_hand"] as EquipmentSlotControl
	assert(off_hand.item_id.is_empty())
	assert(off_hand._icon.texture == ItemCatalog.get_item("warhammer").icon)
	assert(off_hand._icon.modulate.a < 1.0)
	assert(off_hand._get_drag_data(Vector2.ZERO) == null)
	off_hand.set_drag_drop_state(2, "touch")
	assert(off_hand._last_visual_state == 2)
	off_hand.set_drag_drop_state(0)
	assert(off_hand._last_visual_state == 0)
	var bag_slot: InventoryGridSlot = view.get_node("Center/Card/Margins/Content/BodyScroll/Columns/Bag/BagGrid").get_child(0) as InventoryGridSlot
	bag_slot.set_drag_drop_state(1, "touch")
	assert(bag_slot._drag_drop_state == 1)
	bag_slot.set_drag_drop_state(0)
	assert(bag_slot._drag_drop_state == 0)
	view.open_for(session)
	assert(off_hand._icon.texture != ItemCatalog.get_item("warhammer").icon)
	view.queue_free()
	print("Equipment mannequin: OK")
	quit()
