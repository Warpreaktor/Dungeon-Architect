extends SceneTree


func _initialize() -> void:
	var map := DungeonMap.create_blank(5, 5)
	assert(map.place_entity("player_spawn", 2, 2))
	var session := GameSession.start_for(map)
	assert(session != null)
	session._receive_item("potion_health_small", 12)
	session._receive_item("sword", 2)

	var scene := load("res://scenes/inventory_view.tscn") as PackedScene
	assert(scene != null)
	var view := scene.instantiate() as InventoryView
	get_root().add_child.call_deferred(view)
	await process_frame
	view.open_for(session)
	assert(not view.has_node("Center/Card/Margins/Content/ItemDetails/UseButton"))
	assert(not view.has_node("Center/Card/Margins/Content/Header/Title"))
	assert(not view.has_node("Center/Card/Margins/Content/Columns/Bag/BagTitle"))
	assert(not view.has_node("Center/Card/Margins/Content/Columns/EquipmentArea/EquipmentTitle"))

	var index: int = session.inventory_slot_ids().find("potion_health_small")
	assert(index >= 0)
	var second_index: int = session.inventory_slot_ids().find("potion_health_small", index + 1)
	assert(second_index >= 0)
	assert(view._bag_slots[index]._count.text == "10")
	assert(view._bag_slots[second_index]._count.text == "2")
	var requested: Array[String] = []
	var requested_slots: Array[int] = []
	view.item_use_requested.connect(func(item_id: String, bag_index: int) -> void:
		requested.append(item_id)
		requested_slots.append(bag_index)
	)
	view._on_bag_slot_activated(second_index)
	assert(view._item_action_menu.item_count == 1)
	assert(view._item_action_menu.get_item_text(0) == "Использовать")
	assert(requested.is_empty())
	view._on_item_action_pressed(0)
	assert(requested == ["potion_health_small"])
	assert(requested_slots == [second_index])
	assert(int(session.carried_items["potion_health_small"]) == 12)

	var sword_index: int = session.inventory_slot_ids().find("sword")
	assert(sword_index >= 0)
	view._on_bag_slot_activated(sword_index)
	assert(not view._item_action_menu.visible)
	view.close_by_player()
	assert(not view._item_action_menu.visible)
	view.queue_free()
	print("Inventory potion popup: OK")
	quit()
