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
	assert(view.get_node("Center/Card/Margins/Content/Columns/Bag/BagGrid").get_child_count() == 40)
	assert(view.get_node("Center/Card/Margins/Content/Columns/Bag/BagGrid").columns == 10)
	await _test_reuse(view, dungeon)
	view.queue_free()
	print("Inventory grid: OK")
	quit()


func _test_reuse(view: InventoryView, dungeon: DungeonMap) -> void:
	var session := GameSession.start_for_party(dungeon, ["petushan", "volcha", "burolom", "luma"])
	assert(session.party.size() == 4)
	assert(session._receive_item("potion_health_small", 2) == 2)
	assert(session._receive_item("sword", 3) == 3)
	view.open_for(session)
	var cells: Array[Node] = view._bag_grid.get_children()
	var buttons: Array[Node] = view._hero_selector.get_children()
	assert(view._hero_selector.alignment == FlowContainer.ALIGNMENT_BEGIN)
	for index in range(buttons.size()):
		var button: Button = buttons[index] as Button
		assert(button != null and button.text.is_empty())
		assert(button.tooltip_text == session.party[index].definition.display_name)
		var portrait: TextureRect = button.get_node("Portrait") as TextureRect
		assert(portrait != null and portrait.texture == session.party[index].definition.portrait)
	var styles: Array[StyleBox] = []
	for cell in cells:
		styles.append((cell as InventoryGridSlot).get_theme_stylebox("panel"))
		assert(not cell.is_processing())
	var potion_index: int = session.inventory_slot_ids().find("potion_health_small")
	var sword_index: int = session.inventory_slot_ids().find("sword")
	var potion: InventoryGridSlot = cells[potion_index] as InventoryGridSlot
	var sword: InventoryGridSlot = cells[sword_index] as InventoryGridSlot
	assert(potion._count.text == "2")
	assert(session._receive_item("potion_health_small", 1) == 1)
	view._show_item(sword_index)
	assert(sword._selected and not potion._selected)
	view._resize_card()
	view._select_equipped("main_hand")
	view._select_member(session.party[1])
	assert(potion._count.text == "2")
	assert(view._hero_selector.get_children() == buttons)
	view._refresh_contents()
	assert(potion._count.text == "3")
	view._show_item(sword_index)
	var instance_id: String = session.inventory_instance_id(sword_index)
	var destination: int = session.inventory_slot_ids().find("")
	assert(session.transfer_inventory_item("bag", sword_index, "bag", destination))
	view._refresh_contents()
	assert(view._selected_index == destination)
	assert(view._selected_instance_id == instance_id)
	assert((cells[destination] as InventoryGridSlot)._selected)
	assert(not sword._selected and sword.item_id.is_empty())
	view._transfer_item("bag", destination, "equipment", "main_hand")
	assert(session.equipment_instance_id("main_hand") == instance_id)
	assert(view._selected_equipped_slot == "main_hand")
	var main_hand: EquipmentSlotControl = view._mannequin.slots["main_hand"]
	var equipment_style: StyleBox = main_hand.get_theme_stylebox("panel")
	assert(main_hand._selected)
	view._show_item(potion_index)
	assert(not main_hand._selected)
	assert(session._remove_carried_item("potion_health_small", 3))
	view.show_use_result("potion_health_small", "")
	assert(potion.item_id.is_empty() and potion._count.text.is_empty())
	assert(view._selected_item_id != "potion_health_small")
	var source_index: int = session.inventory_slot_ids().find("sword")
	assert(source_index >= 0)
	var source: Dictionary = {"kind": "bag", "slot": source_index}
	var target: Dictionary = {"kind": "bag", "slot": potion_index}
	view._touch_source = source.duplicate()
	view._touch_index = 0
	view._touch_dragging = true
	view._update_touch_target(target)
	assert(potion._drag_drop_state == 1 and not potion.is_processing())
	view._update_touch_target(target)
	assert(potion.get_theme_stylebox("panel") == styles[potion_index])
	view._update_touch_target(source)
	assert(potion._drag_drop_state == 0)
	assert((cells[source_index] as InventoryGridSlot)._drag_drop_state == 2)
	var cancel := InputEventScreenTouch.new()
	cancel.index = 0
	cancel.canceled = true
	view._input(cancel)
	assert(view._touch_index == -1 and view._touch_target.is_empty())
	assert((cells[source_index] as InventoryGridSlot)._drag_drop_state == 0)
	assert(potion._can_drop_data(Vector2.ZERO, source))
	assert(potion.is_processing())
	assert(potion._can_drop_data(Vector2.ZERO, source))
	assert(not main_hand._can_drop_data(Vector2.ZERO, {"kind": "equipment", "slot": "main_hand"}))
	assert(main_hand.is_processing())
	view.dismiss()
	assert(not view.is_processing_input())
	assert(session.inventory_member == null)
	assert(main_hand.session == null and not main_hand.is_processing())
	for cell in cells:
		assert((cell as InventoryGridSlot).session == null)
		assert(not cell.is_processing())
	view.open_for(session)
	assert(view.is_processing_input())
	assert(session._receive_item("sword", GameSession.INVENTORY_SLOT_COUNT) > 0)
	view._refresh_contents()
	assert(not session.inventory_slot_ids().has(""))
	view._resize_card()
	view.dismiss()
	view.open_for(session)
	await process_frame
	assert(view._bag_grid.get_children() == cells)
	assert(view._hero_selector.get_children() == buttons)
	assert(view._mannequin.slots["main_hand"] == main_hand)
	assert(main_hand.get_theme_stylebox("panel") == equipment_style)
	for index in range(cells.size()):
		var cell: InventoryGridSlot = cells[index] as InventoryGridSlot
		assert(cell.get_theme_stylebox("panel") == styles[index])
		assert(cell.item_id == session.inventory_slot_ids()[index])
		assert(cell.activated.get_connections().size() == 1)
		assert(cell.transferred.get_connections().size() == 1)
		assert(not cell.is_processing())
