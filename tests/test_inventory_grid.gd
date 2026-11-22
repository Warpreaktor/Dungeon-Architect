extends SceneTree


func _initialize() -> void:
	var dungeon := DungeonMap.create_blank(5, 5)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	var session := GameSession.start_for(dungeon)
	assert(session != null)
	var initial: Array[String] = session.inventory_slot_ids()
	assert(initial.size() == GameSession.INVENTORY_SLOT_COUNT)
	for item_id in initial:
		assert(item_id.is_empty())

	session._receive_item("key", 5)
	session._receive_item("sword", 2)
	var slots: Array[String] = session.inventory_slot_ids()
	assert(slots.count("key") == 1)
	assert(slots.count("sword") == 1)
	assert(session.equipment_item_id("main_hand") == "sword")
	var index: int = slots.find("key")
	assert(index >= 0)
	assert(session.swap_inventory_slots(index, 39))
	slots = session.inventory_slot_ids()
	assert(slots[39] == "key")
	assert(not session.swap_inventory_slots(39, 40))
	assert(not session.swap_inventory_slots(38, 37))
	assert(session.use_item("key").get("used", false) == false)
	assert(session._remove_carried_item("key", 4))
	assert(session.inventory_slot_ids()[39] == "key")
	assert(session._remove_carried_item("key", 1))
	assert(session.inventory_slot_ids()[39].is_empty())
	assert(session.inventory_slot_ids().count("sword") == 1)

	var view_scene := load("res://scenes/inventory_view.tscn") as PackedScene
	assert(view_scene != null)
	var view := view_scene.instantiate() as InventoryView
	get_root().add_child.call_deferred(view)
	await process_frame
	view.open_for(session)
	assert(view.get_node("Center/Card/Margins/Content/BodyScroll/Columns/Bag/BagGrid").get_child_count() == 40)
	assert(view.get_node("Center/Card/Margins/Content/BodyScroll/Columns/Bag/BagGrid").columns == 10)
	view.queue_free()
	print("Inventory grid: OK")
	quit()
