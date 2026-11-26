extends SceneTree


func _initialize() -> void:
	_test_combat_death_keeps_enemy()
	_test_trap_death_and_continuation()
	_test_status_death_is_permanent()
	_test_several_deaths_across_floors()
	_test_survivor_shield_durabilities()
	_test_simultaneous_deaths_and_full_bag()
	call_deferred("_test_defeat_screen")


func _map() -> DungeonMap:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return dungeon


func _test_combat_death_keeps_enemy() -> void:
	var dungeon: DungeonMap = _map()
	assert(dungeon.place_entity("monster", 3, 2, {"monster_id": "skeleton"}))
	var session := GameSession.start_for(dungeon)
	assert(session.add_party_member("volcha"))
	var fallen: HeroState = session.hero
	assert(not session.move_by(1, 0) and session.has_pending_encounter())
	var participant: BattleParticipant = BattleParticipant.from_hero(fallen)
	participant.receive_damage(participant.health + 5)
	participant.commit_hero_result(fallen)
	assert(fallen.health == 0)
	assert(session.record_casualties() == [fallen])
	session.abandon_pending_encounter()
	assert(session.hero != fallen and session.hero.health > 0)
	assert(session.take_casualty_events() == [fallen])
	assert(session.take_casualty_events().is_empty())
	assert(session.record_casualties().is_empty())
	assert(session.entities_at(3, 2).size() == 1)
	assert(not session.move_by(1, 0) and session.has_pending_encounter())
	assert(session.pending_monster_definition().monster_id == "skeleton")
	assert(session.fallen_heroes == [fallen])


func _test_trap_death_and_continuation() -> void:
	var dungeon: DungeonMap = _map()
	assert(dungeon.place_entity("trap", 3, 2, {"trap_id": "spikes"}))
	var session := GameSession.start_for(dungeon)
	assert(session.add_party_member("volcha"))
	for member in session.party_members():
		member.perception = TrapCatalog.get_trap("spikes").detection_difficulty - 1
		member.health = 1
	session.trap_random.seed = 12
	assert(session.move_by(1, 0))
	var casualties: Array[HeroState] = session.take_casualty_events()
	assert(casualties.size() == 1)
	assert(casualties[0].health == 0)
	assert(session.party.size() == 1 and session.hero.health == 1)
	assert(not session.is_party_defeated())
	assert(session.move_by(-1, 0))
	assert(session.take_casualty_events().is_empty())
	assert(session.fallen_hero_locations.size() == 1)
	assert(session.fallen_hero_locations[0]["position"] == Vector2i(3, 2))


func _test_status_death_is_permanent() -> void:
	var session := GameSession.start_for(_map())
	assert(session.add_party_member("volcha"))
	var fallen: HeroState = session.hero
	fallen.health = 1
	fallen.learned_ability_ids.append("skeleton_grave_howl")
	assert(fallen.apply_overworld_status("bleeding", "Кровотечение", 3, 1, 1))
	assert(session.move_by(1, 0))
	assert(session.take_casualty_events() == [fallen])
	assert(session.hero != fallen)
	assert(session.hero.overworld_statuses.is_empty())
	assert(fallen.learned_ability_ids.has("skeleton_grave_howl"))
	assert(fallen.health == 0 and session.fallen_heroes.has(fallen))
	assert(session.move_by(-1, 0))
	assert(session.record_casualties().is_empty())


func _test_several_deaths_across_floors() -> void:
	var first: DungeonMap = _map()
	var second: DungeonMap = _map()
	first.map_id = "permadeath_regression_first"
	second.map_id = "permadeath_regression_second"
	var session := GameSession.start_for(first)
	assert(session.add_party_member("volcha"))
	assert(session.add_party_member("petushan"))
	var first_fallen: HeroState = session.hero
	first_fallen.gold = 31
	first_fallen.bonus_action_slots = 1
	first_fallen.health = 0
	assert(session.record_casualties() == [first_fallen])
	assert(session.take_casualty_events() == [first_fallen])
	var first_container: String = str(session.ground_container_at(session.player_pos)["id"])
	assert(session.enter_map(second))
	assert(session.ground_loot_containers.is_empty())
	var second_fallen: HeroState = session.hero
	second_fallen.gold = 9
	second_fallen.health = 0
	assert(session.record_casualties() == [second_fallen])
	assert(session.party.size() == 1 and not session.is_party_defeated())
	assert(session.take_casualty_events() == [second_fallen])
	assert(session.fallen_hero_locations.size() == 2)
	assert(session.fallen_hero_locations[0]["map_id"] == first.map_id)
	assert(session.fallen_hero_locations[1]["map_id"] == second.map_id)
	assert(session.enter_map(first))
	assert(session.ground_container_by_id(first_container)["loot"][0]["quantity"] == 31)
	assert(session.enter_map(second))
	var last: HeroState = session.hero
	last.gold = 12
	last.health = 0
	assert(session.record_casualties() == [last])
	assert(session.is_party_defeated() and session.hero == null)
	assert(session.fallen_heroes == [first_fallen, second_fallen, last])
	assert(session.fallen_hero_locations.size() == 3)
	assert(session.fallen_hero_locations[0]["hero"].bonus_action_slots == 1)
	assert(session.ground_container_at(session.player_pos)["loot"].size() >= 1)
	assert(session.record_casualties().is_empty())
	assert(not session.add_party_member("petushan"))
	assert(not session.enter_map(first))
	assert(not session.move_by(1, 0))
	assert(first_fallen.health == 0 and second_fallen.health == 0 and last.health == 0)


func _test_survivor_shield_durabilities() -> void:
	var session := GameSession.start_for(_map())
	assert(session.add_party_member("volcha"))
	var fallen: HeroState = session.hero
	var survivor: HeroState = session.party[1]
	assert(session._receive_item("shield", 3) == 3)
	fallen.shield_durabilities["shield"] = [11, 3, 5]
	assert(fallen.equipped_shield_id == "shield")
	fallen.health = 0
	assert(session.record_casualties() == [fallen])
	assert(session.hero == survivor)
	assert(session.carried_items["shield"] == 3)
	assert(session.inventory_slot_ids().count("shield") == 3)
	var durabilities: Array[int] = []
	for index in range(GameSession.INVENTORY_SLOT_COUNT):
		if session.inventory_slot_ids()[index] == "shield":
			durabilities.append(session.inventory_shield_durability(index))
	durabilities.sort()
	assert(durabilities == [3, 5, 11])
	assert(session.fallen_hero_locations[0]["shield_durabilities_at_death"]["shield"] == [11, 3, 5])


func _test_simultaneous_deaths_and_full_bag() -> void:
	var session := GameSession.start_for(_map())
	assert(session.add_party_member("volcha"))
	assert(session._receive_item("sword", 41) == 41)
	assert(session.inventory_slot_ids().find("") == -1)
	var members: Array[HeroState] = session.party_members()
	members[0].gold = 10
	members[1].gold = 20
	members[0].health = 0
	members[1].health = 0
	assert(session.record_casualties() == members)
	assert(session.is_party_defeated())
	assert(session.take_casualty_events() == members)
	assert(session.take_casualty_events().is_empty())
	assert(session.carried_items.is_empty())
	assert(session.fallen_heroes.size() == 2)
	var total_swords: int = 0
	var total_gold: int = 0
	for entry in session.ground_container_at(session.player_pos)["loot"]:
		if entry["item_id"] == "sword":
			total_swords += int(entry["quantity"])
		elif entry["item_id"] == "gold":
			total_gold += int(entry["quantity"])
	assert(total_swords == 41 and total_gold == 30)
	assert(not session.move_by(1, 0))


func _test_defeat_screen() -> void:
	var view: VictoryView = (load("res://scenes/victory_view.tscn") as PackedScene).instantiate() as VictoryView
	root.add_child(view)
	var fallen := HeroState.new(HeroCatalog.get_hero("petushan"))
	var survivor := HeroState.new(HeroCatalog.get_hero("volcha"))
	var fallen_party: Array[HeroState] = [fallen]
	view.show_party_defeat(5, fallen_party, survivor)
	assert(view.is_party_defeat)
	assert(view.get_node("Center/Card/Margins/Content/Title").text == "ГЕРОЙ ПОГИБ")
	assert(view.get_node("Center/Card/Margins/Content/Buttons/RetryButton").text == "Продолжить")
	assert(view.get_node("Center/Card/Margins/Content/Buttons/RetryButton").visible)
	assert(view.get_node("Center/Card/Margins/Content/Description").text.contains(survivor.definition.display_name))
	view.show_game_over(6, fallen_party)
	assert(not view.is_party_defeat)
	assert(view.get_node("Center/Card/Margins/Content/Title").text == "GAME OVER")
	assert(not view.get_node("Center/Card/Margins/Content/Buttons/RetryButton").visible)
	view.queue_free()
	print("Permanent defeat regressions: OK")
	quit()
