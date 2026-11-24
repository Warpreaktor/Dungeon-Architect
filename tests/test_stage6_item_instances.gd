extends SceneTree


func _initialize() -> void:
	_test_identity_and_quality()
	_test_roundtrip_and_legacy()
	_test_casualty_and_ground_identity()
	_test_selected_member_consumable()
	_test_invalid_identity()
	print("DA-6.02: instances, slots and snapshots OK")
	quit()


func _session() -> GameSession:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for_party(dungeon, ["petushan", "volcha"])


func _test_identity_and_quality() -> void:
	var session: GameSession = _session()
	assert(session._receive_item("shield", 3, [2, 7, 11]) == 3)
	var bag: Array[String] = session.inventory_slot_ids()
	var first: int = bag.find("shield")
	var second: int = bag.find("shield", first + 1)
	var equipped_id: String = session.equipment_instance_id("off_hand", session.hero)
	var first_id: String = session.inventory_instance_id(first)
	var second_id: String = session.inventory_instance_id(second)
	assert(not equipped_id.is_empty() and first_id != equipped_id and first_id != second_id)
	assert(session.item_instance(first_id).durability == 7)
	session.item_instance(first_id).rarity = ItemInstance.Rarity.RARE
	session.item_instance(first_id).modifiers["strength"] = 2
	assert(session.transfer_inventory_item("bag", first, "bag", 39))
	assert(session.inventory_instance_id(39) == first_id)
	assert(session.inventory_instance_id(second) == second_id)
	assert(session.item_instance(first_id).rarity == ItemInstance.Rarity.RARE)
	assert(session.transfer_inventory_item("bag", 39, "equipment", "off_hand"))
	assert(session.equipment_instance_id("off_hand") == first_id)
	assert(session.inventory_instance_id(39) == equipped_id)
	assert(session.hero.current_shield_durability("shield") == 7)
	assert(session.item_instance(first_id).modifiers["strength"] == 2)
	var removed_id: String = session.inventory_instance_id(session.inventory_slot_ids().find("shield"))
	assert(session._remove_carried_item("shield", 1))
	assert(session.item_instance(removed_id) == null)
	assert(session.item_instance(first_id) != null)


func _test_roundtrip_and_legacy() -> void:
	var session: GameSession = _session()
	assert(session._receive_item("sword", 2) == 2)
	var sword_slot: int = session.inventory_slot_ids().find("sword")
	var original_id: String = session.inventory_instance_id(sword_slot)
	session.item_instance(original_id).rarity = ItemInstance.Rarity.UNIQUE
	session.item_instance(original_id).unique_id = "artifact_wolf"
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	assert(snapshot["version"] == ProgressSnapshotCodec.FORMAT_VERSION)
	var maps: Dictionary = {session.map_data.map_id: session.map_data}
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, maps)
	assert(restored != null)
	assert(restored.inventory_instance_id(sword_slot) == original_id)
	assert(restored.item_instance(original_id).unique_id == "artifact_wolf")
	var old: Dictionary = snapshot.duplicate(true)
	old["version"] = ProgressSnapshotCodec.PREVIOUS_FORMAT_VERSION
	old["party"].erase("item_instances")
	old["party"].erase("bag_instance_ids")
	old["party"].erase("next_item_instance_number")
	for member in old["party"]["active_heroes"]:
		member.erase("equipped_instance_ids")
	var migrated: GameSession = GameSession.from_progress_snapshot(old, maps)
	assert(migrated != null)
	assert(not migrated.inventory_instance_id(sword_slot).is_empty())
	assert(migrated.carried_items == session.carried_items)


func _test_invalid_identity() -> void:
	var session: GameSession = _session()
	assert(session._receive_item("sword", 2) == 2)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var maps: Dictionary = {session.map_data.map_id: session.map_data}
	var corrupted: Dictionary = snapshot.duplicate(true)
	var bag: Array = corrupted["party"]["bag_instance_ids"]
	var index: int = bag.find(session.inventory_instance_id(session.inventory_slot_ids().find("sword")))
	bag[index] = str(corrupted["party"]["active_heroes"][0]["equipped_instance_ids"]["main_hand"])
	assert(GameSession.from_progress_snapshot(corrupted, maps) == null)
	corrupted = snapshot.duplicate(true)
	corrupted["party"]["item_instances"].append(corrupted["party"]["item_instances"][0].duplicate(true))
	assert(GameSession.from_progress_snapshot(corrupted, maps) == null)


func _test_casualty_and_ground_identity() -> void:
	var session: GameSession = _session()
	assert(session._receive_item("sword", 41) == 41)
	var dropped_id: String = session.equipment_instance_id("main_hand", session.hero)
	session.item_instance(dropped_id).rarity = ItemInstance.Rarity.MAGIC
	session.item_instance(dropped_id).modifiers["agility"] = 3
	session.hero.health = 0
	assert(session.record_casualties().size() == 1)
	var container: Dictionary = session.ground_container_at(session.player_pos)
	assert(container["loot"].size() == 1)
	assert(container["loot"][0]["instances"][0]["instance_id"] == dropped_id)
	assert(session.item_instance(dropped_id) == null)
	assert(session._remove_carried_item("sword", 1))
	assert(session.take_ground_loot(str(container["id"]), 0) == 1)
	assert(session.item_instance(dropped_id) != null)
	assert(session.item_instance(dropped_id).modifiers["agility"] == 3)


func _test_selected_member_consumable() -> void:
	var session: GameSession = _session()
	var active: HeroState = session.party[0]
	var target: HeroState = session.party[1]
	target.health -= 3
	assert(session._receive_item("potion_health_small", 1) == 1)
	var active_health: int = active.health
	var before: int = target.health
	assert(bool(session.use_item("potion_health_small", target).get("used", false)))
	assert(active.health == active_health)
	assert(target.health > before)
