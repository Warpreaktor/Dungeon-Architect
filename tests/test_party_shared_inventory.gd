extends SceneTree


func _initialize() -> void:
	_test_shared_bag_and_equipment()
	_test_shield_instances_and_casualty()
	print("Party shared inventory: OK")
	quit()


func _session() -> GameSession:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for_party(dungeon, ["petushan", "volcha"])


func _test_shared_bag_and_equipment() -> void:
	var session := _session()
	var first: HeroState = session.party[0]
	var second: HeroState = session.party[1]
	assert(session._receive_item("sword", 2) == 2)
	var source: int = session.inventory_slot_ids().find("sword")
	assert(source >= 0)
	assert(first.equipped_weapon_id == "sword")
	session.inventory_member = second
	assert(session.transfer_inventory_item("bag", source, "equipment", "main_hand"))
	assert(second.equipped_weapon_id == "sword")
	assert(first.equipped_weapon_id == "sword")
	assert(session.inventory_slot_ids().count("sword") == 0)
	assert(session.carried_items["sword"] == 2)
	assert(not session.transfer_inventory_item("equipment", "main_hand", "equipment", "off_hand"))
	assert(session.transfer_inventory_item("equipment", "main_hand", "bag", source))
	assert(second.equipped_weapon_id.is_empty())
	assert(first.equipped_weapon_id == "sword")
	session.inventory_member = first
	assert(session.transfer_inventory_item("equipment", "main_hand", "bag", session.inventory_slot_ids().find("")))
	assert(first.equipped_weapon_id.is_empty())
	session.inventory_member = second
	assert(session.transfer_inventory_item("bag", source, "equipment", "main_hand"))
	assert(second.equipped_weapon_id == "sword")
	assert(session.carried_items["sword"] == 2)
	session.inventory_member = null
	assert(session.equipment_item_id("main_hand").is_empty())


func _test_shield_instances_and_casualty() -> void:
	var session := _session()
	var first: HeroState = session.party[0]
	var second: HeroState = session.party[1]
	assert(session._receive_item("shield", 2, [3, 9]) == 2)
	var bag_slot: int = session.inventory_slot_ids().find("shield")
	assert(bag_slot >= 0)
	assert(session.inventory_shield_durability(bag_slot) == 9)
	session.inventory_member = second
	assert(session.transfer_inventory_item("bag", bag_slot, "equipment", "off_hand"))
	assert(first.current_shield_durability("shield") == 3)
	assert(second.current_shield_durability("shield") == 9)
	assert(session.inventory_slot_ids().count("shield") == 0)
	assert(session.transfer_inventory_item("equipment", "off_hand", "bag", bag_slot))
	assert(session.inventory_shield_durability(bag_slot) == 9)
	assert(session.transfer_inventory_item("bag", bag_slot, "equipment", "off_hand"))
	assert(second.current_shield_durability("shield") == 9)
	session.inventory_member = null
	first.health = 0
	assert(session.record_casualties().size() == 1)
	assert(session.hero == second)
	assert(second.equipped_shield_id == "shield")
	assert(second.current_shield_durability("shield") == 9)
	assert(session.inventory_slot_ids().count("shield") == 1)
	assert(session.inventory_shield_durability(session.inventory_slot_ids().find("shield")) == 3)
