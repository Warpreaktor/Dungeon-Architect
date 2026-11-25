extends SceneTree


func _initialize() -> void:
	_test_shield_instances()
	_test_full_bag_and_ground_loot()
	_test_stack_merge_and_use()
	_test_partial_chest_pickup()
	_test_random_chest_overflow()
	_test_stack_snapshots()
	_test_two_handed_rejection()
	_test_casualty_shield_order()
	_test_read_only_inventory_and_starter()
	_test_battle_shield_commit()
	_test_reward_with_selected_member()
	_test_stats_after_mutations()
	print("Inventory atomicity: OK")
	quit()


func _session() -> GameSession:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for(dungeon)


func _test_shield_instances() -> void:
	var session := _session()
	assert(session._receive_item("shield", 3, [2, 7, 11]) == 3)
	assert(session.hero.shield_durabilities["shield"] == [2, 7, 11])
	var bag: Array[String] = session.inventory_slot_ids()
	var first: int = bag.find("shield")
	var second: int = bag.find("shield", first + 1)
	assert(session.inventory_shield_durability(first) == 7)
	assert(session.inventory_shield_durability(second) == 11)
	assert(session.transfer_inventory_item("bag", first, "bag", 39))
	assert(session.inventory_shield_durability(39) == 7)
	assert(session.inventory_shield_durability(second) == 11)
	assert(session.transfer_inventory_item("bag", 39, "equipment", "off_hand"))
	assert(session.hero.current_shield_durability("shield") == 7)
	assert(session.inventory_shield_durability(39) == 2)
	assert(session.transfer_inventory_item("equipment", "off_hand", "bag", 38))
	assert(session.equipment_item_id("off_hand").is_empty())
	assert(session.inventory_shield_durability(38) == 7)
	assert(session.transfer_inventory_item("bag", 39, "equipment", "off_hand"))
	assert(session.hero.current_shield_durability("shield") == 2)
	assert(session._remove_carried_item("shield", 1))
	assert(session.inventory_slot_ids()[second].is_empty())
	assert(session.hero.shield_durabilities["shield"] == [2, 7])
	assert(session.hero.consume_shield_block(3) > 0)
	assert(session.resolve_broken_shield() == "shield")
	assert(session.carried_items["shield"] == 1)
	assert(session.inventory_shield_durability(38) == 7)
	assert(session._receive_item("shield", 1, [5]) == 1)
	assert(session.hero.current_shield_durability("shield") == 5)
	assert(session.inventory_shield_durability(38) == 7)


func _test_full_bag_and_ground_loot() -> void:
	var session := _session()
	assert(session._receive_item("sword", 45) == 41)
	assert(session.inventory_slot_ids().count("sword") == 40)
	assert(session.carried_items["sword"] == 41)
	var container: Dictionary = session.ground_container_at(session.player_pos)
	assert(not container.is_empty())
	assert(container["loot"][0]["quantity"] == 4)
	var container_id: String = str(container["id"])
	assert(not session.can_take_ground_loot(container_id, 0))
	assert(session._remove_carried_item("sword", 1))
	assert(session.take_ground_loot(container_id, 0) == 1)
	assert(session.carried_items["sword"] == 41)
	assert(session.ground_container_by_id(container_id)["loot"][0]["quantity"] == 3)
	assert(session._receive_item("potion", 2) == 0)
	assert(session.ground_container_by_id(container_id)["loot"].size() == 2)
	assert(session._remove_carried_item("sword", 1))
	assert(session.take_ground_loot(container_id, 1) == 2)
	assert(session.inventory_slot_ids().count("potion") == 1)
	assert(session._receive_item("potion", 3) == 3)
	assert(session.carried_items["potion"] == 5)

	var shield_session := _session()
	assert(shield_session._receive_item("sword", 41) == 41)
	assert(shield_session._receive_item("shield", 1, [4]) == 1)
	assert(shield_session._receive_item("shield", 1, [9]) == 0)
	var loot: Dictionary = shield_session.ground_container_at(shield_session.player_pos)
	assert(loot["loot"][0]["durabilities"] == [9])
	assert(shield_session._remove_carried_item("sword", 1))
	assert(shield_session.take_ground_loot(str(loot["id"]), 0) == 1)
	var shield_bag_index: int = shield_session.inventory_slot_ids().find("shield")
	assert(shield_session.inventory_shield_durability(shield_bag_index) == 9)
	assert(shield_session.hero.current_shield_durability("shield") == 4)


func _test_two_handed_rejection() -> void:
	var session := _session()
	assert(session._receive_item("shield", 1) == 1)
	assert(session._receive_item("sword", 40) == 40)
	assert(session._receive_item("warhammer", 1) == 1)
	var before_bag: Array[String] = session.inventory_slot_ids()
	var before_shields: Dictionary = session.hero.shield_durabilities.duplicate(true)
	var hammer_index: int = before_bag.find("warhammer")
	assert(hammer_index >= 0 and before_bag.find("") == -1)
	assert(not session.can_transfer_inventory_item("bag", hammer_index, "equipment", "main_hand"))
	assert(not session.transfer_inventory_item("bag", hammer_index, "equipment", "main_hand"))
	assert(session.inventory_slot_ids() == before_bag)
	assert(session.hero.shield_durabilities == before_shields)
	assert(session.equipment_item_id("main_hand") == "sword")
	assert(session.equipment_item_id("off_hand") == "shield")
	assert(not session.unequip_item("shield"))
	assert(session._remove_carried_item("sword", 1))
	assert(session.unequip_item("shield"))
	assert(session.equipment_item_id("off_hand").is_empty())


func _test_casualty_shield_order() -> void:
	var session := _session()
	assert(session.add_party_member("volcha"))
	assert(session._receive_item("shield", 3, [3, 7, 11]) == 3)
	var fallen: HeroState = session.hero
	fallen.health = 0
	assert(session.record_casualties().size() == 1)
	assert(session.fallen_hero_locations[0]["shield_durabilities_at_death"]["shield"] == [3, 7, 11])
	assert(session.hero.shield_durabilities["shield"] == [7, 11, 3])
	var bag: Array[String] = session.inventory_slot_ids()
	assert(bag.count("shield") == 3)
	assert(session.inventory_shield_durability(bag.find("shield")) == 7)
	assert(session.inventory_shield_durability(bag.find("shield", 1)) == 11)
	assert(session.inventory_shield_durability(bag.find("shield", 2)) == 3)


func _test_read_only_inventory_and_starter() -> void:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	var session := GameSession.start_for_party(dungeon, ["burolom", "volcha", "petushan", "luma"])
	assert(session != null)
	var starter_id: String = str(session.hero.equipped_instance_ids.get("main_hand", ""))
	assert(not starter_id.is_empty())
	assert(session.item_instance(starter_id).item_id == "burolom_drill")
	assert(session._receive_item("sword", GameSession.INVENTORY_SLOT_COUNT) == GameSession.INVENTORY_SLOT_COUNT)
	var before: Dictionary = session.party_state_snapshot()
	var slots: Array[String] = session.inventory_slot_ids()
	for member in session.party:
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			assert(session.equipment_instance_id(slot_id, member) == str(member.equipped_instance_ids.get(slot_id, "")))
		for i in range(slots.size()):
			var instance: ItemInstance = session.item_instance(session.inventory_instance_id(i))
			assert(instance != null and instance.item_id == slots[i])
	assert(session.party_state_snapshot() == before)
	slots[0] = ""
	assert(not session.inventory_slot_ids()[0].is_empty())
	assert(session.inventory_instance_id(-1).is_empty())
	assert(session.inventory_instance_id(GameSession.INVENTORY_SLOT_COUNT).is_empty())
	var restored := GameSession.new()
	assert(restored.restore_party_state(before))
	assert(restored.party_state_snapshot() == before)


func _test_battle_shield_commit() -> void:
	var session := _session()
	assert(session._receive_item("shield", 2, [5, 11]) == 2)
	var shield_id: String = session.equipment_instance_id("off_hand")
	var bag_index: int = session.inventory_slot_ids().find("shield")
	var bag_id: String = session.inventory_instance_id(bag_index)
	var copy: HeroState = session.hero.copy_for_battle()
	assert(copy.consume_shield_block(2) > 0)
	assert(session.item_instance(shield_id).durability == 5)
	assert(session.hero.current_shield_durability("shield") == 5)
	session.hero.apply_battle_result(copy)
	assert(session.item_instance(shield_id).durability == 3)
	assert(session.inventory_shield_durability(bag_index) == 11)
	assert(copy.consume_shield_block(3) > 0)
	session.hero.apply_battle_result(copy)
	assert(session.resolve_broken_shield() == "shield")
	assert(session.resolve_broken_shield().is_empty())
	assert(session.item_instance(shield_id) == null)
	assert(session.item_instance(bag_id).durability == 11)
	assert(session.carried_items["shield"] == 1)
	session.hero.apply_battle_result(copy)
	assert(session.equipment_instance_id("off_hand").is_empty())
	assert(session.resolve_broken_shield().is_empty())
	assert(session.carried_items["shield"] == 1)


func _test_reward_with_selected_member() -> void:
	var session := _session()
	assert(session.add_party_member("petushan"))
	var leader: HeroState = session.hero
	var other: HeroState = session.party[1]
	session.inventory_member = other
	assert(session._receive_item("shield", 2, [4, 9]) == 2)
	assert(leader.equipped_shield_id == "shield")
	assert(other.equipped_shield_id.is_empty())
	var bag_index: int = session.inventory_slot_ids().find("shield")
	assert(session.transfer_inventory_item("bag", bag_index, "equipment", "off_hand"))
	assert(other.current_shield_durability("shield") == 9)
	assert(leader.current_shield_durability("shield") == 4)
	assert(session._receive_item("key", 100) == 100)
	assert(session.inventory_slot_ids().count("key") == 10)
	assert(session._remove_carried_item("key", 99))
	assert(session.inventory_slot_ids().count("key") == 1)
	assert(session._remove_carried_item("key", 1))
	assert(not session.inventory_slot_ids().has("key"))
	assert(session.item_instance(session.equipment_instance_id("off_hand", leader)).durability == 4)
	assert(session.item_instance(session.equipment_instance_id("off_hand", other)).durability == 9)


func _test_stats_after_mutations() -> void:
	var session := _session()
	assert(session._receive_item("sword", 1) == 1)
	var hero: HeroState = session.hero
	var instance: ItemInstance = session.item_instance(session.equipment_instance_id("main_hand"))
	var before: Dictionary = CharacterStats.hero_values(hero)
	instance.quality_id = "masterwork"
	instance.rarity = ItemInstance.Rarity.MAGIC
	instance.affix_ids = ["edge"]
	instance.modifiers["weapon_damage"] = 2
	var after: Dictionary = CharacterStats.hero_values(hero)
	assert(after["melee_power"] > before["melee_power"])
	assert(hero.effective_max_health() == int(after["max_health"]))
	hero.strength += 2
	assert(hero.effective_strength() > int(after["strength"]))
	var snapshot: Dictionary = session.party_state_snapshot()
	var preview: Dictionary = CharacterStats.preview_equipment(hero, "main_hand", ItemCatalog.get_item("warhammer"))
	assert(not preview.is_empty())
	assert(session.party_state_snapshot() == snapshot)


func _test_stack_merge_and_use() -> void:
	var session := _session()
	var item_id: String = "potion_health_small"
	var limit: int = ItemCatalog.get_item(item_id).stack_limit()
	assert(limit == 10)
	assert(session._receive_item(item_id, 25) == 25)
	assert(session.inventory_slot_ids().count(item_id) == 3)
	assert(session.inventory_slot_quantity(0) == limit)
	assert(session.inventory_slot_quantity(1) == limit)
	assert(session.inventory_slot_quantity(2) == 5)
	assert(not session.swap_inventory_slots(2, 0))
	session.hero.health -= 3
	assert(session.use_item(item_id, session.hero, 1).used)
	assert(session.inventory_slot_quantity(0) == limit)
	assert(session.inventory_slot_quantity(1) == 9)
	assert(session.inventory_slot_quantity(2) == 5)
	assert(session.swap_inventory_slots(2, 1))
	assert(session.inventory_slot_quantity(1) == limit)
	assert(session.inventory_slot_quantity(2) == 4)
	assert(session.swap_inventory_slots(2, 39))
	assert(session.inventory_slot_quantity(2) == 0 and session.inventory_slot_quantity(39) == 4)
	assert(session._receive_item("potion_health_medium", 2) == 2)
	assert(session.swap_inventory_slots(39, 2))
	assert(session.inventory_slot_ids()[39] == "potion_health_medium")
	assert(session.inventory_slot_quantity(39) == 2 and session.inventory_slot_quantity(2) == 4)
	assert(session._remove_carried_item(item_id, 13))
	assert(session.inventory_slot_quantity(0) == 0 and session.inventory_slot_quantity(1) == 7)
	assert(session.carried_items[item_id] == 11)
	assert(session.swap_inventory_slots(2, 1))
	assert(session.inventory_slot_quantity(1) == limit and session.inventory_slot_quantity(2) == 1)
	assert(session._remove_carried_item(item_id, 2, 1))
	assert(session.swap_inventory_slots(2, 1))
	assert(session.inventory_slot_quantity(1) == 9 and session.inventory_slot_quantity(2) == 0)
	assert(session.carried_items[item_id] == 9)
	assert(session._receive_item("sword", 3) == 3)
	var first: int = session.inventory_slot_ids().find("sword")
	var second: int = session.inventory_slot_ids().find("sword", first + 1)
	var first_id: String = session.inventory_instance_id(first)
	var second_id: String = session.inventory_instance_id(second)
	assert(first_id != second_id and not first_id.is_empty() and not second_id.is_empty())
	assert(session.swap_inventory_slots(first, second))
	assert(session.inventory_instance_id(first) == second_id and session.inventory_instance_id(second) == first_id)
	assert(session.inventory_slot_quantity(first) == 1 and session.inventory_slot_quantity(second) == 1)


func _test_partial_chest_pickup() -> void:
	var session := _session()
	var map: DungeonMap = session.map_data
	assert(map.place_entity("chest", 3, 2))
	var chest: Dictionary = map.entities_at(3, 2)[0]
	assert(map.set_chest_contents(str(chest["id"]), ["potion"], 5, false, false, {"potion": 15}))
	assert(session._receive_item("potion", 9) == 9)
	assert(session._receive_item("sword", 40) == 40)
	assert(not session.inventory_slot_ids().has(""))
	assert(session.move_by(1, 0))
	assert(session.is_chest_open(chest))
	assert(session.carried_items["potion"] == 10)
	var container: Dictionary = session.ground_container_at(session.player_pos)
	var container_id: String = str(container["id"])
	assert(container["loot"][0]["quantity"] == 14)
	assert(not session.can_take_ground_loot(container_id, 0))
	assert(session.take_ground_loot(container_id, 0) == 0)
	assert(session._remove_carried_item("potion", 1))
	assert(session.take_ground_loot(container_id, 0) == 1)
	assert(container["loot"][0]["quantity"] == 13)
	assert(session._remove_carried_item("sword", 1))
	assert(session.take_ground_loot(container_id, 0) == 10)
	assert(container["loot"][0]["quantity"] == 3)
	assert(session._remove_carried_item("sword", 1))
	assert(session.take_ground_loot(container_id, 0) == 3)
	assert(session.carried_items["potion"] == 23)
	assert(session.ground_container_by_id(container_id).is_empty())


func _test_random_chest_overflow() -> void:
	var session := _session()
	assert(session._receive_item("sword", 41) == 41)
	assert(session._receive_item("shield", 1) == 1)
	var rng := RandomNumberGenerator.new()
	var seed_value: int = 1
	var expected: Dictionary = {}
	while seed_value <= 1000:
		rng.seed = seed_value
		expected = ItemCatalog.roll_loot(rng)
		if not expected.is_empty() and ItemCatalog.get_item(str(expected["item_id"])).category == ItemDefinition.Category.CONSUMABLE:
			break
		seed_value += 1
	assert(seed_value <= 1000)
	session.trap_random.seed = seed_value
	assert(session.map_data.place_entity("chest", 3, 2))
	var chest: Dictionary = session.map_data.entities_at(3, 2)[0]
	assert(DungeonMap.chest_is_random(chest))
	assert(session.move_by(1, 0))
	var container: Dictionary = session.ground_container_at(session.player_pos)
	assert(container["loot"][0]["item_id"] == expected["item_id"])
	assert(container["loot"][0]["quantity"] == expected["quantity"])
	assert(session.is_chest_open(chest))
	assert(session.move_by(-1, 0) and session.move_by(1, 0))
	assert(container["loot"].size() == 1)
	assert(session._remove_carried_item("sword", 1))
	assert(session.take_ground_loot(str(container["id"]), 0) == int(expected["quantity"]))


func _test_stack_snapshots() -> void:
	var session := _session()
	assert(session._receive_item("potion", 23) == 23)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var maps: Dictionary = {session.map_data.map_id: session.map_data}
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, maps)
	assert(restored != null)
	assert(restored.inventory_slot_quantity(0) == 10 and restored.inventory_slot_quantity(2) == 3)
	var damaged: Dictionary = snapshot.duplicate(true)
	damaged["party"]["bag_quantities"][0] = 11
	assert(GameSession.from_progress_snapshot(damaged, maps) == null)
	damaged = snapshot.duplicate(true)
	damaged["party"]["bag_quantities"][39] = 1
	assert(GameSession.from_progress_snapshot(damaged, maps) == null)
	damaged = snapshot.duplicate(true)
	damaged["party"]["carried_items"]["potion"] = 24
	assert(GameSession.from_progress_snapshot(damaged, maps) == null)
	var old: Dictionary = snapshot.duplicate(true)
	old["party"].erase("bag_quantities")
	old["party"]["inventory_slots"][1] = ""
	old["party"]["inventory_slots"][2] = ""
	var migrated_with_space: GameSession = GameSession.from_progress_snapshot(old, maps)
	assert(migrated_with_space != null)
	assert(migrated_with_space.inventory_slot_quantity(0) == 10)
	assert(migrated_with_space.inventory_slot_quantity(1) == 10)
	assert(migrated_with_space.inventory_slot_quantity(2) == 3)
	assert(migrated_with_space.ground_loot_containers.is_empty())
	var full := _session()
	assert(full._receive_item("potion", 10) == 10)
	assert(full._receive_item("sword", 40) == 40)
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(full.progress_snapshot()))
	legacy["party"].erase("bag_quantities")
	legacy["party"]["carried_items"]["potion"] = 25
	var legacy_maps: Dictionary = {full.map_data.map_id: full.map_data}
	var migrated: GameSession = GameSession.from_progress_snapshot(legacy, legacy_maps)
	assert(migrated != null and migrated.carried_items["potion"] == 10)
	var ground: Dictionary = migrated.ground_container_at(migrated.player_pos)
	assert(ground["loot"][0]["quantity"] == 15)
	var loaded: GameSession = GameSession.from_progress_snapshot(JSON.parse_string(JSON.stringify(migrated.progress_snapshot())), legacy_maps)
	assert(loaded != null)
	assert(loaded._remove_carried_item("sword", 2))
	assert(loaded.take_ground_loot(str(ground["id"]), 0) == 15)
	assert(loaded.carried_items["potion"] == 25)
	assert(loaded.ground_loot_containers.is_empty())
	assert(loaded.inventory_slot_ids().count("potion") == 3)
