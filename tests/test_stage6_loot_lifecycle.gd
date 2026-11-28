extends SceneTree


func _initialize() -> void:
	_test_casualty_and_floor_roundtrip()
	_test_legacy_ground_migration()
	_test_pending_rewards_and_lethal_step()
	print("DA-6.14: loot ownership, casualties and floor persistence OK")
	quit()


func _map(id: String) -> DungeonMap:
	var dungeon := DungeonMap.create_blank(8, 8)
	dungeon.map_id = id
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return dungeon


func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


func _assert_unique_ownership(session: GameSession) -> void:
	var seen: Dictionary = {}
	var snapshot: Dictionary = session.party_state_snapshot()
	for record in snapshot["item_instances"]:
		assert(not seen.has(record["instance_id"]))
		seen[record["instance_id"]] = true
	for floor in session.visited_floor_snapshots().values():
		for container in floor["ground_loot"]:
			for entry in container["loot"]:
				for record in entry.get("instances", []):
					assert(not seen.has(record["instance_id"]))
					seen[record["instance_id"]] = true


func _test_casualty_and_floor_roundtrip() -> void:
	var first := _map("loot_lifecycle_first")
	var second := _map("loot_lifecycle_second")
	var maps: Dictionary = {first.map_id: first, second.map_id: second}
	assert(first.place_entity("chest", 3, 2))
	var chest: Dictionary = first.entities_at(3, 2)[0]
	assert(first.set_chest_contents(str(chest["id"]), ["ring_copper_wire"], 5, false, false, {"ring_copper_wire": 2}))
	var session := GameSession.start_for_party(first, ["petushan", "volcha"])
	assert(session._receive_item("shield", 2, [3, 7]) == 2)
	var fallen: HeroState = session.hero
	var survivor: HeroState = session.party[1]
	var fallen_id: String = session.equipment_instance_id("off_hand", fallen)
	var shield_slot: int = session.inventory_slot_ids().find("shield")
	var survivor_id: String = session.inventory_instance_id(shield_slot)
	session.inventory_member = survivor
	assert(session.transfer_inventory_item("bag", shield_slot, "equipment", "off_hand"))
	assert(session._receive_item("sword", 1) == 1)
	var sword_id: String = session.equipment_instance_id("main_hand", fallen)
	var stack_id: String = "potion_health_small"
	var limit: int = ItemCatalog.get_item(stack_id).stack_limit()
	var capacity: int = limit * GameSession.INVENTORY_SLOT_COUNT
	assert(session._receive_item(stack_id, capacity) == capacity)
	assert(session.move_by(1, 0))
	assert(session.is_chest_open(chest))
	var reward: Dictionary = session.take_message_events()[0]["loot"][0]
	var reward_id: String = reward["instances"][0]["instance_id"]
	var original_ground: Dictionary = session.ground_container_at(session.player_pos)
	assert(original_ground["loot"][0] == reward)
	assert(session._receive_reward(reward, session.player_pos) == 0)
	assert(session.ground_container_at(session.player_pos) == original_ground)
	assert(session.enter_map(second))
	assert(session._receive_reward(reward, session.player_pos) == 0)
	assert(session.ground_loot_containers.is_empty())
	fallen.gold = 12
	session.inventory_member = fallen
	fallen.health = 0
	assert(session.record_casualties() == [fallen])
	assert(session.record_casualties().is_empty())
	assert(session.hero == survivor and session.inventory_member == null)
	assert(session.equipment_instance_id("off_hand", survivor) == survivor_id)
	assert(session.item_instance(survivor_id).durability == 7)
	assert(session.carried_items[stack_id] == capacity)
	assert(session.item_instance(fallen_id) == null and session.item_instance(sword_id) == null)
	var death_ground: Dictionary = session.ground_container_at(session.player_pos)
	assert(death_ground["loot"].size() == 3)
	assert(session.floor_state_snapshot(first.map_id)["ground_loot"][0] == original_ground)
	_assert_unique_ownership(session)
	var snapshot: Dictionary = _json(session.progress_snapshot())
	var restored := GameSession.from_progress_snapshot(snapshot, maps)
	assert(restored != null)
	assert(_json(restored.progress_snapshot()) == snapshot)
	assert(restored.fallen_hero_locations[0]["map_id"] == second.map_id)
	assert(restored.item_instance(survivor_id).durability == 7)
	assert(restored.enter_map(first))
	assert(restored.is_chest_open(chest))
	assert(restored.move_by(1, 0))
	assert(restored.take_message_events().is_empty())
	assert(restored._remove_carried_item(stack_id, limit))
	assert(restored.take_ground_loot(str(original_ground["id"]), 0) == 1)
	assert(_json(restored.item_instance(reward_id).to_dict()) == _json(reward["instances"][0]))
	assert(restored.ground_container_by_id(str(original_ground["id"]))["loot"][0]["quantity"] == 1)
	_assert_unique_ownership(restored)
	assert(restored.enter_map(second))
	assert(_json(restored.ground_container_at(restored.player_pos)) == _json(death_ground))
	assert(restored._remove_carried_item(stack_id, limit))
	assert(restored.take_ground_loot(str(death_ground["id"]), 0) == 1)
	assert(restored._remove_carried_item(stack_id, limit))
	assert(restored.take_ground_loot(str(death_ground["id"]), 0) == 1)
	assert(restored.item_instance(fallen_id).durability == 3)
	assert(restored.item_instance(sword_id) != null)
	assert(restored.take_ground_loot(str(death_ground["id"]), 0) == 12)
	assert(restored.ground_loot_containers.is_empty())
	_assert_unique_ownership(restored)
	var continued := GameSession.from_progress_snapshot(_json(restored.progress_snapshot()), maps)
	assert(continued != null and continued.ground_loot_containers.is_empty())
	assert(continued.item_instance(fallen_id).durability == 3)
	assert(continued.item_instance(survivor_id).durability == 7)
	continued.hero.health = 0
	assert(continued.record_casualties().size() == 1)
	assert(continued.is_party_defeated() and continued.carried_items.is_empty())
	assert(continued.record_casualties().is_empty())
	var dropped: Dictionary = continued._ground_instance_ids()
	for instance_id in [fallen_id, survivor_id, sword_id, reward_id]:
		assert(dropped.has(instance_id) and continued.item_instance(instance_id) == null)
	_assert_unique_ownership(continued)
	assert(continued.progress_snapshot().is_empty())
	assert(not continued.enter_map(first))


func _test_legacy_ground_migration() -> void:
	var first := _map("legacy_loot_first")
	var second := _map("legacy_loot_second")
	var maps: Dictionary = {first.map_id: first, second.map_id: second}
	var session := GameSession.start_for(first)
	session._append_ground_loot(session.player_pos, [{"item_id": "shield", "quantity": 2, "durabilities": [3, 7]}])
	assert(session.enter_map(second))
	var snapshot: Dictionary = _json(session.progress_snapshot())
	snapshot["floors"][first.map_id]["ground_loot"][0]["loot"][0].erase("instances")
	var restored := GameSession.from_progress_snapshot(snapshot, maps)
	assert(restored != null)
	var entry: Dictionary = restored.floor_state_snapshot(first.map_id)["ground_loot"][0]["loot"][0]
	assert(entry["instances"].size() == 2)
	assert(entry["instances"][0]["durability"] == 3 and entry["instances"][1]["durability"] == 7)
	var migrated: Dictionary = _json(restored.progress_snapshot())
	var again := GameSession.from_progress_snapshot(migrated, maps)
	assert(again != null and _json(again.progress_snapshot()) == migrated)
	assert(again.enter_map(first))
	var container: Dictionary = again.ground_container_at(again.player_pos)
	assert(again.take_ground_loot(str(container["id"]), 0) == 1)
	assert(again.item_instance(entry["instances"][0]["instance_id"]).durability == 3)
	var invalid: Dictionary = _json(again.progress_snapshot())
	invalid["floors"][first.map_id]["ground_loot"][0]["loot"][0]["instances"][0] = entry["instances"][0]
	invalid["floors"][first.map_id]["ground_loot"][0]["loot"][0]["durabilities"][0] = 3
	assert(GameSession.from_progress_snapshot(invalid, maps) == null)


func _test_pending_rewards_and_lethal_step() -> void:
	var first := _map("lethal_chest")
	var second := _map("other_floor")
	assert(first.place_entity("chest", 3, 2))
	var chest: Dictionary = first.entities_at(3, 2)[0]
	assert(first.set_chest_contents(str(chest["id"]), ["gold"], 9))
	for defer in [false, true]:
		var session := GameSession.start_for_party(first, ["petushan", "volcha"])
		var fallen: HeroState = session.hero
		fallen.health = 1
		assert(fallen.apply_overworld_status("bleeding", "Кровотечение", 3, 1, 1))
		assert(session.move_by(1, 0, defer))
		assert(session.party.size() == 1 and fallen.gold == 0)
		if defer:
			assert(not session.enter_map(second))
			assert(session.progress_snapshot().is_empty())
			assert(session.open_pending_chest())
		assert(session.hero.gold == 9 and session.is_chest_open(chest))
		assert(session.ground_loot_containers.is_empty())
		assert(not session.open_pending_chest())
		assert(session.enter_map(second))
		assert(session.enter_map(first))
		assert(session.move_by(1, 0))
		assert(session.hero.gold == 9)
		var doomed := GameSession.start_for(first)
		doomed.hero.health = 1
		assert(doomed.hero.apply_overworld_status("bleeding", "Кровотечение", 3, 1, 1))
		assert(doomed.move_by(1, 0, defer))
		assert(doomed.is_party_defeated() and not doomed.is_chest_open(chest))
		assert(doomed.pending_chest_id.is_empty())
		assert(doomed.ground_loot_containers.is_empty())
