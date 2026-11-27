extends SceneTree


func _initialize() -> void:
	_test_two_heroes_and_shared_inventory()
	_test_fallen_hero_and_defeat()
	_test_corrupt_snapshot_is_rejected()
	_test_rebalanced_health()
	_test_map_objects_use_palette_art()
	print("Stage 5 party snapshot: heroes, bag, shield instances, statuses, casualties, RNG and stairs OK")
	quit()


func _map() -> DungeonMap:
	var dungeon := DungeonMap.create_blank(8, 8)
	dungeon.map_id = "stage5_party_snapshot"
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return dungeon


func _round_trip(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert(parsed is Dictionary)
	return parsed


func _test_two_heroes_and_shared_inventory() -> void:
	var dungeon: DungeonMap = _map()
	var source: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	assert(source != null)
	assert(source._receive_item("sword", 3) == 3)
	assert(source._receive_item("shield", 3, [3, 7, 11]) == 3)
	assert(source._receive_item("potion", 4) == 4)
	var first: HeroState = source.party[0]
	var second: HeroState = source.party[1]
	var sword_slot: int = source.inventory_slot_ids().find("sword")
	assert(sword_slot >= 0)
	source.inventory_member = second
	assert(source.transfer_inventory_item("bag", sword_slot, "equipment", "main_hand"))
	var shield_slot: int = source.inventory_slot_ids().find("shield")
	assert(shield_slot >= 0)
	assert(source.transfer_inventory_item("bag", shield_slot, "equipment", "off_hand"))
	assert(first.current_shield_durability("shield") == 3)
	assert(second.current_shield_durability("shield") == 7)
	var remaining_shield: int = source.inventory_slot_ids().find("shield")
	assert(source.inventory_shield_durability(remaining_shield) == 11)
	assert(source.transfer_inventory_item("bag", remaining_shield, "bag", 39))
	assert(source.inventory_shield_durability(39) == 11)
	second.health -= 6
	second.gold = 41
	second.bonus_action_slots = 1
	second.learned_ability_ids.append("hunter_shot")
	second.saved_action_slots = ["hunter_shot", "", "volcha_wolf_lunge", ""]
	second.strength_bonus = 4
	second.strength_phases = 3
	second.vision_bonus = 1
	second.vision_phases = 2
	second._potion_phase_progress = 2
	assert(second.apply_overworld_status("bleeding", "Кровотечение", 2, 3, 2))
	source.steps = 37
	source.trap_random.seed = 207
	source.trap_random.randi_range(0, 10)
	var snapshot: Dictionary = source.party_state_snapshot()
	assert(snapshot["inventory_slots"].size() == GameSession.INVENTORY_SLOT_COUNT)
	assert(snapshot["inventory_slots"][39] == "shield")
	assert(snapshot["active_heroes"][1]["saved_action_slots"][1] == "")
	var saved_data: Dictionary = _round_trip(snapshot)
	var restored: GameSession = GameSession.start_for(dungeon)
	assert(restored.restore_party_state(_round_trip(snapshot)))
	assert(_round_trip(restored.party_state_snapshot()) == saved_data)
	assert(restored.party.size() == 2)
	assert(restored.hero == restored.party[0])
	assert(restored.inventory_member == restored.party[1])
	assert(restored.party[0].definition == first.definition)
	assert(restored.party[1].definition == second.definition)
	assert(restored.party[1].health == second.health)
	assert(restored.party[1].gold == 41)
	assert(restored.party[1].learned_ability_ids == ["hunter_shot"])
	assert(restored.party[1].get_saved_action_slots() == ["hunter_shot", "", "volcha_wolf_lunge", ""])
	assert(restored.party[1].overworld_statuses == second.overworld_statuses)
	assert(restored.party[1]._potion_phase_progress == 2)
	assert(restored.inventory_slot_ids()[39] == "shield")
	assert(restored.carried_items == source.carried_items)
	assert(restored.party[0].current_shield_durability("shield") == 3)
	assert(restored.party[1].current_shield_durability("shield") == 7)
	assert(restored.inventory_shield_durability(39) == 11)
	assert(restored.steps == source.steps)
	assert(restored.trap_random.randi() == source.trap_random.randi())
	var copied: Dictionary = restored.party_state_snapshot()
	copied["active_heroes"][1]["shield_durabilities"].clear()
	copied["inventory_slots"][39] = ""
	assert(restored.party[1].shield_durabilities.has("shield"))
	assert(restored.inventory_slot_ids()[39] == "shield")
	assert(dungeon.find_entity_position("player_spawn") == Vector2i(2, 2))


func _test_fallen_hero_and_defeat() -> void:
	var dungeon: DungeonMap = _map()
	var source: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	assert(source._receive_item("shield", 1, [5]) == 1)
	var fallen: HeroState = source.party[0]
	fallen.gold = 23
	fallen.bonus_action_slots = 1
	fallen.learned_ability_ids.append("hunter_shot")
	fallen.health = 0
	assert(source.record_casualties() == [fallen])
	assert(source.fallen_hero_locations.size() == 1)
	var original_location: Dictionary = source.fallen_hero_locations[0]
	var data: Dictionary = _round_trip(source.party_state_snapshot())
	var restored: GameSession = GameSession.start_for(dungeon)
	assert(restored.restore_party_state(data))
	assert(restored.party.size() == 1)
	assert(restored.fallen_heroes.size() == 1)
	assert(restored.hero == restored.party[0])
	assert(restored.fallen_heroes[0].health == 0)
	assert(restored.fallen_heroes[0].bonus_action_slots == 1)
	assert(restored.fallen_heroes[0].learned_ability_ids == ["hunter_shot"])
	assert(restored.fallen_hero_locations[0]["hero"] == restored.fallen_heroes[0])
	assert(restored.fallen_hero_locations[0]["position"] == original_location["position"])
	assert(restored.fallen_hero_locations[0]["map_id"] == original_location["map_id"])
	assert(restored.fallen_hero_locations[0]["equipment_at_death"] == original_location["equipment_at_death"])
	assert(restored.fallen_hero_locations[0]["shield_durabilities_at_death"] == original_location["shield_durabilities_at_death"])
	assert(restored.fallen_hero_locations[0]["gold_at_death"] == 23)
	assert(restored.party[0].health > 0)
	assert(restored.carried_items == source.carried_items)
	assert(restored.inventory_slot_ids() == source.inventory_slot_ids())
	assert(restored.record_casualties().is_empty())

	var last: HeroState = source.party[0]
	last.health = 0
	assert(source.record_casualties() == [last])
	assert(source.is_party_defeated())
	data = _round_trip(source.party_state_snapshot())
	var game_over: GameSession = GameSession.start_for(dungeon)
	assert(game_over.restore_party_state(data))
	assert(game_over.hero == null)
	assert(game_over.party.is_empty())
	assert(game_over.fallen_heroes.size() == 2)
	assert(game_over.is_party_defeated())
	assert(game_over.fallen_hero_locations[1]["hero"] == game_over.fallen_heroes[1])
	assert(game_over.carried_items.is_empty())


func _test_corrupt_snapshot_is_rejected() -> void:
	var source: GameSession = GameSession.start_for(_map())
	assert(source._receive_item("shield", 1, [6]) == 1)
	var original: String = JSON.stringify(source.party_state_snapshot())
	var damaged: Dictionary = _round_trip(source.party_state_snapshot())
	damaged["inventory_slots"][39] = "shield"
	assert(not source.restore_party_state(damaged))
	assert(JSON.stringify(source.party_state_snapshot()) == original)
	damaged = _round_trip(source.party_state_snapshot())
	damaged["active_heroes"][0]["hero_id"] = "missing_hero"
	assert(not source.restore_party_state(damaged))
	assert(JSON.stringify(source.party_state_snapshot()) == original)
	damaged = _round_trip(source.party_state_snapshot())
	damaged["random_state"] = "not-a-number"
	assert(not source.restore_party_state(damaged))
	assert(JSON.stringify(source.party_state_snapshot()) == original)


func _test_map_objects_use_palette_art() -> void:
	assert(DungeonCanvas.STAIRS_DOWN_TEXTURE == load("res://assets/icons/map_objects/stairs_down.png"))
	assert(DungeonCanvas.CHEST_TEXTURE == load("res://assets/icons/map_objects/chest.png"))
	var editor_script: Script = load("res://scripts/editor.gd")
	var palette: Dictionary = editor_script.get_script_constant_map()["TOOL_ICONS"]
	assert(palette["chest"] == DungeonCanvas.CHEST_TEXTURE)


func _test_rebalanced_health() -> void:
	var dungeon: DungeonMap = _map()
	var source: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	var first: HeroState = source.party[0]
	var second: HeroState = source.party[1]
	first.max_health *= 2
	first.health = roundi(first.max_health * 0.5)
	second.max_health *= 2
	second.health = 1
	var restored: GameSession = GameSession.start_for(dungeon)
	assert(restored.restore_party_state(_round_trip(source.party_state_snapshot())))
	assert(restored.party[0].max_health == first.definition.max_health)
	assert(restored.party[0].health == roundi(first.definition.max_health * 0.5))
	assert(restored.party[1].max_health == second.definition.max_health)
	assert(restored.party[1].health == 1)
	var snapshot: Dictionary = _round_trip(restored.party_state_snapshot())
	assert(restored.restore_party_state(snapshot))
	assert(_round_trip(restored.party_state_snapshot()) == snapshot)
