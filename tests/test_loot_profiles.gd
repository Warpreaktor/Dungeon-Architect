extends SceneTree


func _initialize() -> void:
	_test_reward_levels()
	_test_mixed_rewards()
	_test_profile_pools()
	_test_source_selection()
	_test_container_variants()
	_test_depth_and_rarity()
	_test_profile_chest_and_persistence()
	_test_special_reward()
	_test_resolved_reward_replay()
	_test_reward_overflow_revisit()
	_test_author_rewards_and_legacy_maps()
	_test_encounter_rewards()
	print("Loot profiles: sources, depth, rarity, fixed rewards and persistence OK")
	quit()


func _test_reward_levels() -> void:
	var chest: LootProfile = LootProfileCatalog.get_profile("chest")
	var purse: LootProfile = LootProfileCatalog.get_profile("coin_purse")
	var rng := RandomNumberGenerator.new()
	var replay := RandomNumberGenerator.new()
	for level in range(1, LootProfile.REWARD_LEVELS.size() + 1):
		var rules: LootRewardLevel = LootProfile.level_rules(level)
		assert(rules.stage_for(ItemCatalog.LOOT_TABLE, 3, 2) == 2)
		rng.seed = 614
		replay.seed = 614
		var possible: Array[String] = chest.possible_item_ids(level)
		for index in range(20):
			var rewards: Array[Dictionary] = chest.roll(rng, 0, 0, level)
			assert(rewards == chest.roll(replay, 0, 0, level))
			assert(rng.state == replay.state)
			for reward in rewards:
				assert(str(reward["item_id"]) in possible)
				if reward.has("loot_stage"):
					assert(int(reward["loot_stage"]) == rules.minimum_stage)
		rng.seed = 615
		replay.seed = 615
		var baseline: Array[Dictionary] = purse.roll(rng, 0, 0)
		var adjusted: Array[Dictionary] = purse.roll(replay, 0, 0, level)
		assert(baseline[0]["item_id"] == adjusted[0]["item_id"] and rng.state == replay.state)
		assert(int(adjusted[0]["quantity"]) == ceili(int(baseline[0]["quantity"]) * rules.stack_quantity_multiplier))
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("chest", 3, 2))
	var entity: Dictionary = dungeon.entities_at(3, 2)[0]
	var id: String = str(entity["id"])
	assert(DungeonMap.loot_level(entity) == 1)
	assert(not dungeon.set_loot_level(id, 0) and not dungeon.set_loot_level(id, 4))
	assert(dungeon.set_loot_level(id, 3))
	assert(not dungeon.set_loot_level(id, 3))
	assert(LootProfileCatalog.for_source(entity) == chest)
	assert(dungeon.set_chest_contents(id, ["gold", "ring_copper_wire"], 17, false, false, {"gold": 17, "ring_copper_wire": 3}))
	var json: String = JSON.stringify(dungeon.to_dict())
	var loaded: DungeonMap = DungeonMap.from_dict(JSON.parse_string(json))
	assert(DungeonMap.loot_level(loaded.entities_at(3, 2)[0]) == 3)
	var session: GameSession = _seeded_session(loaded, 616)
	assert(session.move_by(1, 0))
	var rewards: Array = session.take_message_events()[0]["loot"]
	assert(rewards[0] == {"item_id": "gold", "quantity": 17})
	assert(rewards[1]["quantity"] == 3 and rewards[1]["instances"].size() == 3)
	assert(JSON.stringify(loaded.to_dict()) == json)
	assert(loaded.set_loot_level(id, 1))
	assert(not loaded.entities_at(3, 2)[0]["properties"].has("loot_level"))
	assert(loaded.set_chest_contents(id, [], 5, true))
	assert(loaded.set_loot_level(id, 3))
	var random_session: GameSession = _seeded_session(loaded, 617)
	var random_replay: GameSession = _seeded_session(loaded, 617)
	assert(random_session.move_by(1, 0) and random_replay.move_by(1, 0))
	assert(random_session.take_message_events() == random_replay.take_message_events())
	assert(random_session.trap_random.state == random_replay.trap_random.state)
	var state: int = random_session.trap_random.state
	random_session._open_chest(loaded.entities_at(3, 2)[0])
	assert(random_session.trap_random.state == state and random_session.take_message_events().is_empty())


func _test_mixed_rewards() -> void:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("chest", 3, 2))
	var chest: Dictionary = dungeon.entities_at(3, 2)[0]
	var id: String = str(chest["id"])
	assert(dungeon.set_loot_profile(id, "coin_purse"))
	assert(dungeon.set_loot_level(id, 3))
	var baseline: GameSession = _seeded_session(dungeon, 619)
	assert(baseline.move_by(1, 0))
	var random_rewards: Array = baseline.take_message_events()[0]["loot"]
	assert(random_rewards.size() == 1 and random_rewards[0]["item_id"] == "gold")
	assert(dungeon.set_chest_contents(id, ["key_red", "gold", "ring_copper_wire"], 7, true, false,
		{"key_red": 2, "gold": 7, "ring_copper_wire": 2}))
	assert(DungeonMap.chest_is_random(chest) and chest["properties"]["loot_mode"] == "mixed")
	assert(not dungeon.set_chest_contents(id, ["key_red", "gold", "ring_copper_wire"], 7, true, false,
		{"key_red": 2, "gold": 7, "ring_copper_wire": 2}))
	var json: String = JSON.stringify(dungeon.to_dict())
	var loaded: DungeonMap = DungeonMap.from_dict(JSON.parse_string(json))
	var source: Dictionary = loaded.entities_at(3, 2)[0]
	assert(DungeonMap.chest_is_random(source) and DungeonMap.loot_level(source) == 3)
	assert(DungeonMap.chest_item_quantities(source) == {"key_red": 2, "gold": 7, "ring_copper_wire": 2})
	var session: GameSession = _seeded_session(loaded, 619)
	var replay: GameSession = _seeded_session(loaded, 619)
	assert(session.move_by(1, 0) and replay.move_by(1, 0))
	var rewards: Array = session.take_message_events()[0]["loot"]
	assert(rewards == replay.take_message_events()[0]["loot"])
	assert(rewards.size() == 4 and rewards[0] == random_rewards[0])
	assert(rewards[1] == {"item_id": "key_red", "quantity": 2})
	assert(rewards[2] == {"item_id": "gold", "quantity": 7})
	assert(rewards[3]["item_id"] == "ring_copper_wire" and rewards[3]["instances"].size() == 2)
	assert(rewards[3]["instances"][0]["instance_id"] != rewards[3]["instances"][1]["instance_id"])
	assert(session.hero.gold == int(random_rewards[0]["quantity"]) + 7)
	assert(session.carried_items.get("key_red", 0) == 2)
	var rng_state: int = session.trap_random.state
	assert(rng_state == replay.trap_random.state)
	session._open_chest(source)
	assert(session.take_message_events().is_empty() and session.trap_random.state == rng_state)
	assert(JSON.stringify(loaded.to_dict()) == json)
	var restored: GameSession = GameSession.from_progress_snapshot(session.progress_snapshot(), {loaded.map_id: loaded})
	assert(restored != null and restored.trap_random.state == rng_state)
	restored._open_chest(source)
	assert(restored.take_message_events().is_empty() and restored.trap_random.state == rng_state)
	assert(restored.carried_items.get("key_red", 0) == 2)
	var legacy: Dictionary = source.duplicate(true)
	legacy["properties"]["loot_mode"] = "random"
	assert(DungeonMap.chest_contents(legacy).is_empty())
	assert(_seeded_session(loaded, 619)._resolve_source_rewards(legacy) == random_rewards)
	assert(loaded.set_chest_contents(id, ["key_red"], 5, false))
	assert(_seeded_session(loaded, 619)._resolve_source_rewards(source) == [{"item_id": "key_red", "quantity": 2}])
	assert(loaded.set_chest_contents(id, [], 5, true))
	assert(_seeded_session(loaded, 619)._resolve_source_rewards(source) == random_rewards)
	assert(loaded.place_entity("monster", 4, 2, {"monster_id": "skeleton"}))
	var monster: Dictionary = loaded.entities_at(4, 2)[0]
	assert(loaded.set_monster_loot(str(monster["id"]), ["key_red"], 5, true))
	assert(DungeonMap.monster_loot_is_random(monster))
	var monster_rewards: Array[Dictionary] = _seeded_session(loaded, 619)._resolve_source_rewards(monster)
	assert(monster_rewards.size() > 1 and monster_rewards.back() == {"item_id": "key_red", "quantity": 1})
	assert(loaded.place_entity("stairs_down", 5, 2))
	var stairs: Dictionary = loaded.entities_at(5, 2)[0]
	assert(loaded.set_chest_contents(str(stairs["id"]), ["key_red"], 5, true))
	var exit_rewards: Array[Dictionary] = _seeded_session(loaded, 619)._resolve_source_rewards(stairs)
	assert(exit_rewards.size() > 1 and exit_rewards.back() == {"item_id": "key_red", "quantity": 1})


func _test_profile_pools() -> void:
	ItemCatalog.prepare()
	LootProfileCatalog.prepare()
	var rng := RandomNumberGenerator.new()
	rng.seed = 610
	var replay := RandomNumberGenerator.new()
	replay.seed = rng.seed
	for profile_id in LootProfileCatalog.list_ids():
		var profile: LootProfile = LootProfileCatalog.get_profile(profile_id)
		assert(profile != null and not profile.pools.is_empty())
		for depth in range(3):
			for index in range(50):
				var rewards: Array[Dictionary] = profile.roll(rng, 0, depth)
				assert(rewards == profile.roll(replay, 0, depth))
				assert(rng.state == replay.state and not rewards.is_empty())
				var equipment_count: int = 0
				for reward in rewards:
					var item: ItemDefinition = ItemCatalog.get_item(str(reward["item_id"]))
					assert(item != null and item.category != ItemDefinition.Category.QUEST)
					assert(int(reward["quantity"]) > 0)
					assert(ItemCatalog.LOOT_TABLE.allows(item.item_id, depth))
					if item.category == ItemDefinition.Category.EQUIPMENT:
						equipment_count += 1
						assert(int(reward["quantity"]) == 1 and int(reward["loot_stage"]) == depth)
					if profile_id == "alchemy_table":
						assert(item.category == ItemDefinition.Category.CONSUMABLE)
						assert(int(reward["quantity"]) in [1, 2, 3])
					elif profile_id == "weapon_rack":
						assert(item.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON)
					elif profile_id == "armor_rack":
						assert(item.equipment_slot in [ItemDefinition.EquipmentSlot.SHIELD, ItemDefinition.EquipmentSlot.HEAD, ItemDefinition.EquipmentSlot.BODY, ItemDefinition.EquipmentSlot.BELT, ItemDefinition.EquipmentSlot.GLOVES, ItemDefinition.EquipmentSlot.BOOTS])
					elif profile_id == "jewelry_box":
						assert(item.equipment_slot in [ItemDefinition.EquipmentSlot.NECK, ItemDefinition.EquipmentSlot.RING])
					elif profile_id == "coin_purse":
						assert(item.category == ItemDefinition.Category.CURRENCY)
				if profile_id == "chest":
					assert(equipment_count == 1 and rewards.size() == 3)
					assert(rewards[1]["item_id"] == "gold")
				elif profile_id == "boss":
					assert(equipment_count == 2 and rewards.size() in [4, 5])


func _test_source_selection() -> void:
	assert(LootProfileCatalog.for_source({"type": "chest"}) == LootProfileCatalog.get_profile("chest"))
	assert(LootProfileCatalog.for_source({"type": "weapon_rack"}) == LootProfileCatalog.get_profile("weapon_rack"))
	assert(LootProfileCatalog.for_source({"type": "chest", "properties": {"variant": "weapon_rack"}}) == LootProfileCatalog.get_profile("weapon_rack"))
	assert(LootProfileCatalog.for_source({"type": "chest", "properties": {"variant": "alchemy_table"}}) == LootProfileCatalog.get_profile("alchemy_table"))
	assert(LootProfileCatalog.for_source({"type": "monster", "properties": {"monster_id": "skeleton"}}) == LootProfileCatalog.get_profile("monster"))
	assert(LootProfileCatalog.for_source({"type": "monster", "properties": {"monster_id": "rabbit_symbiont"}}) == LootProfileCatalog.get_profile("boss"))
	assert(LootProfileCatalog.for_source({"type": "chest", "properties": {"loot_profile_id": "alchemy_table"}}) == LootProfileCatalog.get_profile("alchemy_table"))
	assert(LootProfileCatalog.for_source({"type": "chest", "properties": {"loot_profile_id": "missing"}}) == LootProfileCatalog.get_profile("chest"))


func _test_container_variants() -> void:
	var dungeon := DungeonMap.create_blank(8, 8)
	var placements := [
		{"cell": Vector2i(2, 2), "variant": "chest_gold", "profile": "coin_purse"},
		{"cell": Vector2i(3, 2), "variant": "jewelry_table", "profile": "jewelry_box"},
		{"cell": Vector2i(4, 2), "variant": "weapon_rack", "profile": "weapon_rack"},
		{"cell": Vector2i(5, 2), "variant": "armor_rack", "profile": "armor_rack"},
		{"cell": Vector2i(6, 2), "variant": "alchemy_table", "profile": "alchemy_table"}
	]
	for entry in placements:
		var cell: Vector2i = entry["cell"]
		assert(dungeon.place_entity("chest", cell.x, cell.y, {"variant": str(entry["variant"])}))
		var entity: Dictionary = dungeon.entities_at(cell.x, cell.y)[0]
		assert(DungeonMap.chest_variant(entity) == str(entry["variant"]))
		assert(DungeonMap.chest_profile_id(entity) == str(entry["profile"]))
		assert(LootProfileCatalog.for_source(entity) == LootProfileCatalog.get_profile(str(entry["profile"])))
	assert(dungeon.place_entity("chest", 2, 3, {"variant": "unknown_variant"}))
	assert(DungeonMap.chest_variant(dungeon.entities_at(2, 3)[0]) == "chest")
	var loaded: DungeonMap = DungeonMap.from_dict(JSON.parse_string(JSON.stringify(dungeon.to_dict())))
	for entry in placements:
		var cell: Vector2i = entry["cell"]
		var entity: Dictionary = loaded.entities_at(cell.x, cell.y)[0]
		assert(DungeonMap.chest_variant(entity) == str(entry["variant"]))
		assert(LootProfileCatalog.for_source(entity) == LootProfileCatalog.get_profile(str(entry["profile"])))


func _test_depth_and_rarity() -> void:
	var table: WeightedLootTable = ItemCatalog.LOOT_TABLE
	assert(table.stage_for_progress(0, 0) == 0)
	assert(table.stage_for_progress(0, 1) == 1)
	assert(table.stage_for_progress(0, 2) == 2)
	assert(table.stage_for_progress(3, 0) == 2)
	var sword: ItemDefinition = ItemCatalog.get_item("sword")
	var rng := RandomNumberGenerator.new()
	rng.seed = 611
	var weights: Dictionary = {0: 0, 1: 0, 2: 1}
	var early: ItemInstance = ItemInstance.create("early", sword)
	ItemMagicCatalog.roll(early, sword, rng, 0, weights)
	assert(early.rarity == ItemInstance.Rarity.COMMON)
	var late: ItemInstance = ItemInstance.create("late", sword)
	ItemMagicCatalog.roll(late, sword, rng, 2, weights)
	assert(late.rarity == ItemInstance.Rarity.RARE and late.affix_ids.size() >= 2)


func _test_profile_chest_and_persistence() -> void:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("chest", 3, 2))
	assert(dungeon.place_entity("chest", 4, 2))
	var chest: Dictionary = dungeon.entities_at(3, 2)[0]
	assert(dungeon.set_loot_profile(str(chest["id"]), "alchemy_table"))
	assert(not dungeon.set_loot_profile(str(chest["id"]), "missing"))
	assert(not dungeon.set_loot_profile(str(chest["id"]), "alchemy_table"))
	var fixed: Dictionary = dungeon.entities_at(4, 2)[0]
	assert(dungeon.set_loot_profile(str(fixed["id"]), "weapon_rack"))
	assert(dungeon.set_chest_contents(str(fixed["id"]), ["gold"], 19))
	dungeon.metadata["loot_depth"] = 2
	var restored_map: DungeonMap = DungeonMap.from_dict(JSON.parse_string(JSON.stringify(dungeon.to_dict())))
	var session: GameSession = GameSession.start_for(restored_map)
	assert(session.loot_depth() == 2)
	session.trap_random.seed = 612
	assert(session.move_by(1, 0))
	var events: Array[Dictionary] = session.take_message_events()
	assert(events.size() == 1 and events[0]["loot"].size() == 2)
	for reward in events[0]["loot"]:
		assert(ItemCatalog.get_item(str(reward["item_id"])).category == ItemDefinition.Category.CONSUMABLE)
	var before: Dictionary = session.carried_items.duplicate(true)
	var gold: int = session.hero.gold
	assert(session.move_by(1, 0))
	assert(session.hero.gold == gold + 19 and session.carried_items == before)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var loaded: GameSession = GameSession.from_progress_snapshot(snapshot, {restored_map.map_id: restored_map})
	assert(loaded != null and loaded.loot_depth() == 2)
	assert(loaded.move_by(-1, 0) and loaded.move_by(1, 0))
	assert(loaded.hero.gold == gold + 19 and loaded.carried_items == before)


func _test_special_reward() -> void:
	var first := DungeonMap.create_blank(8, 8)
	var second := DungeonMap.create_blank(8, 8)
	assert(first.place_entity("player_spawn", 2, 2))
	assert(second.place_entity("player_spawn", 2, 2))
	assert(first.place_entity("stairs_down", 3, 2))
	var stairs: Dictionary = first.entities_at(3, 2)[0]
	assert(first.set_stairs_target(str(stairs["id"]), second.map_id))
	stairs["properties"]["loot_mode"] = "random"
	var session: GameSession = GameSession.start_for(first)
	assert(session.loot_depth() == 0)
	assert(session.move_by(1, 0))
	assert(session.take_message_events()[0]["loot"].size() == 2)
	assert(session.enter_map(second))
	assert(session.loot_depth() == 1)


func _seeded_session(dungeon: DungeonMap, seed_value: int) -> GameSession:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return GameSession.start_for(dungeon, "volcha", false, rng)


func _test_resolved_reward_replay() -> void:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("chest", 3, 2))
	assert(dungeon.place_entity("monster", 4, 2, {"monster_id": "kadavr"}))
	assert(dungeon.place_entity("stairs_down", 5, 2))
	var stairs: Dictionary = dungeon.entities_at(5, 2)[0]
	stairs["properties"]["loot_mode"] = "random"
	dungeon.metadata["loot_depth"] = 2
	for seed_value in range(611, 627):
		var first: GameSession = _seeded_session(dungeon, seed_value)
		var replay: GameSession = _seeded_session(dungeon, seed_value)
		assert(first.move_by(1, 0, true) and replay.move_by(1, 0, true))
		assert(first.take_message_events().is_empty())
		assert(first.trap_random.state == replay.trap_random.state)
		assert(first.open_pending_chest() and replay.open_pending_chest())
		var chest_events: Array[Dictionary] = first.take_message_events()
		assert(chest_events == replay.take_message_events())
		assert(chest_events[0]["loot"][0]["instances"].size() == 1)
		var snapshot: Dictionary = JSON.parse_string(JSON.stringify(first.progress_snapshot()))
		var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {dungeon.map_id: dungeon})
		assert(restored != null and first.trap_random.state == restored.trap_random.state)
		for session in [first, replay, restored]:
			var before: int = session.trap_random.state
			assert(not session.open_pending_chest())
			assert(session.move_by(-1, 0) and session.move_by(1, 0))
			assert(session.take_message_events().is_empty())
			assert(session.trap_random.state == before)
			assert(not session.move_by(1, 0) and session.has_pending_encounter())
			assert(session.win_pending_encounter())
			assert(not session.win_pending_encounter())
		var victory: Array[Dictionary] = first.take_message_events()
		assert(victory == replay.take_message_events() and victory == restored.take_message_events())
		assert(victory[0]["loot"][0]["instances"].size() == 1)
		for session in [first, replay, restored]:
			assert(session.move_by(1, 0))
		var exit_events: Array[Dictionary] = first.take_message_events()
		assert(exit_events == replay.take_message_events() and exit_events == restored.take_message_events())
		assert(first.trap_random.state == replay.trap_random.state and first.trap_random.state == restored.trap_random.state)
		assert(JSON.stringify(first.carried_items) == JSON.stringify(replay.carried_items))
		assert(JSON.parse_string(JSON.stringify(first.carried_items)) == JSON.parse_string(JSON.stringify(restored.carried_items)))
		assert(first.hero.gold == replay.hero.gold and first.hero.gold == restored.hero.gold)
		var state_after_exit: int = first.trap_random.state
		first._claim_exit_reward(stairs)
		assert(first.take_message_events().is_empty() and first.trap_random.state == state_after_exit)


func _test_reward_overflow_revisit() -> void:
	var dungeon := DungeonMap.create_blank(8, 8)
	var second := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(second.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("chest", 3, 2))
	var chest: Dictionary = dungeon.entities_at(3, 2)[0]
	assert(dungeon.set_chest_contents(str(chest["id"]), ["ring_copper_wire"], 5, false, false, {"ring_copper_wire": 2}))
	var first: GameSession = _seeded_session(dungeon, 611)
	var full: GameSession = _seeded_session(dungeon, 611)
	first.loot_victories = 3
	full.loot_victories = 3
	var potion_id: String = "potion_health_small"
	var capacity: int = ItemCatalog.get_item(potion_id).stack_limit() * GameSession.INVENTORY_SLOT_COUNT
	assert(full._receive_item(potion_id, capacity) == capacity)
	assert(not full.inventory_slot_ids().has(""))
	assert(first.move_by(1, 0) and full.move_by(1, 0))
	var events: Array[Dictionary] = first.take_message_events()
	assert(events == full.take_message_events())
	var records: Array = events[0]["loot"][0]["instances"]
	assert(records.size() == 2 and records[0]["instance_id"] != records[1]["instance_id"])
	for record in records:
		assert(first.item_instance(str(record["instance_id"])).to_dict() == record)
	var container: Dictionary = full.ground_container_at(Vector2i(3, 2))
	assert(container["loot"][0]["instances"] == records)
	assert(first.trap_random.state == full.trap_random.state)
	var rng_state: int = full.trap_random.state
	full._open_chest(chest)
	assert(full.trap_random.state == rng_state and full.take_message_events().is_empty())
	assert(full.enter_map(second))
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(full.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {dungeon.map_id: dungeon, second.map_id: second})
	assert(restored != null and restored.enter_map(dungeon))
	assert(restored.move_by(1, 0) and restored.take_message_events().is_empty())
	var restored_container: Dictionary = restored.ground_container_at(Vector2i(3, 2))
	assert(restored_container["loot"][0]["instances"] == JSON.parse_string(JSON.stringify(records)))
	assert(restored._remove_carried_item(potion_id, ItemCatalog.get_item(potion_id).stack_limit()))
	assert(restored.take_ground_loot(str(restored_container["id"]), 0) == 1)
	assert(JSON.parse_string(JSON.stringify(restored.item_instance(str(records[0]["instance_id"])).to_dict())) == JSON.parse_string(JSON.stringify(records[0])))
	assert(restored.ground_container_by_id(str(restored_container["id"]))["loot"][0]["instances"] == JSON.parse_string(JSON.stringify([records[1]])))
	assert(restored.trap_random.state == rng_state)
	assert(restored._remove_carried_item(potion_id, ItemCatalog.get_item(potion_id).stack_limit()))
	assert(restored.take_ground_loot(str(restored_container["id"]), 0) == 1)
	assert(JSON.parse_string(JSON.stringify(restored.item_instance(str(records[1]["instance_id"])).to_dict())) == JSON.parse_string(JSON.stringify(records[1])))
	assert(restored.ground_container_at(Vector2i(3, 2)).is_empty())
	assert(restored.trap_random.state == rng_state)


func _test_author_rewards_and_legacy_maps() -> void:
	var dungeon := DungeonMap.create_blank(9, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("chest", 3, 2))
	assert(dungeon.place_entity("chest", 4, 2))
	assert(dungeon.place_entity("chest", 5, 2))
	assert(dungeon.place_entity("chest", 6, 2))
	assert(dungeon.place_entity("chest", 7, 2))
	var legacy: Dictionary = dungeon.entities_at(3, 2)[0]
	legacy["properties"] = {"reward": "key_yellow", "hidden": true, "item_quantities": {"key_yellow": 2}}
	var chest: Dictionary = dungeon.entities_at(4, 2)[0]
	assert(dungeon.set_chest_contents(str(chest["id"]), ["gold", "potion_health_medium", "ring_copper_wire"], 37, false, false,
		{"gold": 37, "potion_health_medium": 12, "ring_copper_wire": 2}))
	assert(dungeon.set_loot_profile(str(chest["id"]), "weapon_rack"))
	var empty: Dictionary = dungeon.entities_at(5, 2)[0]
	assert(dungeon.set_chest_contents(str(empty["id"]), [], 5, false))
	var missing: Dictionary = dungeon.entities_at(6, 2)[0]
	missing["properties"] = {"contents": ["missing_item"]}
	var old_gold: Dictionary = dungeon.entities_at(7, 2)[0]
	old_gold["properties"] = {"contents": ["gold"], "gold_amount": 19}
	var json: String = JSON.stringify(dungeon.to_dict())
	var loaded: DungeonMap = DungeonMap.from_dict(JSON.parse_string(json))
	var session: GameSession = _seeded_session(loaded, 612)
	assert(session.is_entity_hidden_from_hero(legacy))
	session.hero.vision_bonus = 1
	session.hero.vision_phases = 3
	assert(not session.is_entity_hidden_from_hero(legacy))
	assert(session.move_by(1, 0, true) and session.open_pending_chest())
	assert(session.keys == 2 and session.is_chest_open(legacy))
	assert(session.take_message_events()[0]["loot"] == [{"item_id": "key", "quantity": 2}])
	assert(session.move_by(1, 0))
	var rewards: Array = session.take_message_events()[0]["loot"]
	assert(rewards.size() == 3)
	assert(rewards[0] == {"item_id": "gold", "quantity": 37})
	assert(rewards[1] == {"item_id": "potion_health_medium", "quantity": 12})
	assert(rewards[2]["item_id"] == "ring_copper_wire" and rewards[2]["instances"].size() == 2)
	assert(session.hero.gold == 37 and session.carried_items["potion_health_medium"] == 12)
	assert(session.carried_items["ring_copper_wire"] == 2)
	var before: int = session.trap_random.state
	assert(session.move_by(1, 0) and session.is_chest_open(empty))
	assert(session.move_by(1, 0) and session.is_chest_open(missing))
	assert(session.take_message_events().is_empty() and session.trap_random.state == before)
	assert(session.move_by(1, 0) and session.hero.gold == 56)
	assert(session.take_message_events()[0]["loot"] == [{"item_id": "gold", "quantity": 19}])
	for step in range(5):
		assert(session.move_by(-1, 0))
	for step in range(5):
		assert(session.move_by(1, 0))
	assert(session.hero.gold == 56 and session.keys == 2 and session.take_message_events().is_empty())
	assert(session.trap_random.state == before and JSON.stringify(loaded.to_dict()) == json)


func _test_encounter_rewards() -> void:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("monster", 3, 2, {"monster_id": "skeleton"}))
	assert(dungeon.place_entity("monster", 4, 2, {"monster_id": "skeleton"}))
	assert(dungeon.place_entity("monster", 5, 2, {"monster_id": "skeleton"}))
	var random: Dictionary = dungeon.entities_at(3, 2)[0]
	assert(not dungeon.set_monster_party(str(random["id"]), ["skeleton", "kadavr"]))
	assert(dungeon.set_monster_party(str(random["id"]), ["skeleton", "hunter"]))
	assert(dungeon.set_loot_profile(str(random["id"]), "boss"))
	assert(LootProfileCatalog.for_source(random) == LootProfileCatalog.get_profile("boss"))
	var fixed: Dictionary = dungeon.entities_at(4, 2)[0]
	assert(dungeon.set_monster_party(str(fixed["id"]), ["skeleton", "hunter"]))
	assert(dungeon.set_monster_loot(str(fixed["id"]), ["gold", "potion_health_small", "ring_copper_wire"], 17, false, false,
		{"gold": 17, "potion_health_small": 13, "ring_copper_wire": 2}))
	assert(dungeon.set_loot_profile(str(fixed["id"]), "boss"))
	var custom: Dictionary = dungeon.entities_at(5, 2)[0]
	assert(dungeon.set_loot_profile(str(custom["id"]), "alchemy_table"))
	var json: String = JSON.stringify(dungeon.to_dict())
	var loaded: DungeonMap = DungeonMap.from_dict(JSON.parse_string(json))
	var session: GameSession = _seeded_session(loaded, 613)
	assert(not session.move_by(1, 0) and session.has_pending_encounter())
	var defs: Array[MonsterDefinition] = session.pending_monster_definitions()
	var fight := CombatSession.new(defs[0], session.hero, defs[1], 613, session.party)
	var state: BattleState = fight.battle_state
	var before: int = session.trap_random.state
	state.get_enemy().health = 0
	state.update_outcome()
	assert(not state.is_victory and not session.win_pending_encounter(state))
	assert(not session.is_entity_removed(random) and session.loot_victories == 0)
	assert(session.trap_random.state == before and session.take_message_events().is_empty())
	state.get_participant(state.support_enemy_id).health = 0
	state.update_outcome()
	assert(state.is_victory and session.win_pending_encounter(state))
	var rewards: Array = session.take_message_events()[0]["loot"]
	assert(rewards.size() in [4, 5])
	assert(rewards[0]["instances"].size() == 1 and rewards[1]["instances"].size() == 1)
	assert(rewards[2]["item_id"] == "gold")
	assert(session.loot_victories == 1 and session.is_entity_removed(random))
	assert(not session.win_pending_encounter(state))
	var gold: int = session.hero.gold
	var rings: int = int(session.carried_items.get("ring_copper_wire", 0))
	var potions: int = int(session.carried_items.get("potion_health_small", 0))
	assert(not session.move_by(1, 0))
	assert(session.win_pending_encounter())
	assert(session.loot_victories == 2 and session.hero.gold == gold + 17)
	assert(session.carried_items["ring_copper_wire"] == rings + 2 and session.carried_items["potion_health_small"] == potions + 13)
	var fixed_rewards: Array = session.take_message_events()[0]["loot"]
	assert(fixed_rewards.size() == 3 and fixed_rewards[2]["instances"].size() == 2)
	assert(not session.move_by(1, 0) and session.win_pending_encounter())
	var custom_rewards: Array = session.take_message_events()[0]["loot"]
	assert(custom_rewards.size() == 2)
	for entry in custom_rewards:
		assert(ItemCatalog.get_item(str(entry["item_id"])).category == ItemDefinition.Category.CONSUMABLE)
	assert(session.loot_victories == 3)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {loaded.map_id: loaded})
	assert(restored != null)
	var restored_rng: int = restored.trap_random.state
	var restored_gold: int = restored.hero.gold
	for step in range(3):
		assert(restored.move_by(-1, 0))
	for step in range(3):
		assert(restored.move_by(1, 0))
	assert(restored.loot_victories == 3 and restored.hero.gold == restored_gold)
	assert(restored.trap_random.state == restored_rng and restored.take_message_events().is_empty())
	assert(JSON.stringify(loaded.to_dict()) == json)
