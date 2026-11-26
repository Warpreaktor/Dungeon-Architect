extends SceneTree


func _initialize() -> void:
	_test_ground_index()
	_test_ground_snapshots()
	_test_survivors_keep_bag_and_gear()
	_test_full_bag_and_shield_durability()
	_test_last_hero_drops_shared_bag()
	_test_floor_persistence_and_loot_removal()
	print("Ground loot containers: OK")
	quit()


func _session() -> GameSession:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return GameSession.start_for(dungeon)


func _test_survivors_keep_bag_and_gear() -> void:
	var session := _session()
	assert(session.add_party_member("volcha"))
	var fallen: HeroState = session.hero
	var survivor: HeroState = session.party[1]
	fallen.gold = 25
	session._receive_item("sword", 1)
	session._receive_item("shield", 1)
	session._receive_item("potion", 2)
	assert(fallen.equipped_weapon_id == "sword")
	assert(fallen.equipped_shield_id == "shield")
	fallen.shield_durabilities["shield"] = [7]
	fallen.health = 0
	assert(session.record_casualties().size() == 1)
	assert(session.record_casualties().is_empty())
	assert(session.hero == survivor)
	assert(session.party.size() == 1)
	assert(session.fallen_heroes[0] == fallen)
	assert(fallen.equipped_weapon_id.is_empty())
	assert(fallen.equipped_shield_id.is_empty())
	assert(fallen.learned_ability_ids == [])
	assert(session.carried_items["sword"] == 1)
	assert(session.carried_items["shield"] == 1)
	assert(session.carried_items["potion"] == 2)
	assert(session.inventory_slot_ids().has("sword"))
	assert(session.inventory_slot_ids().has("shield"))
	assert(session.hero.shield_durabilities["shield"] == [7])
	var container: Dictionary = session.ground_container_at(session.player_pos)
	assert(not container.is_empty())
	assert(container["loot"].size() == 1 and container["loot"][0]["item_id"] == "gold")
	assert(session.take_ground_loot(str(container["id"]), 0) == 25)
	assert(survivor.gold == 25)
	assert(session.ground_loot_containers.is_empty())


func _test_full_bag_and_shield_durability() -> void:
	var session := _session()
	assert(session.add_party_member("volcha"))
	session._receive_item("sword", 41)
	session._receive_item("shield", 1)
	session.hero.shield_durabilities["shield"] = [3]
	assert(session.inventory_slot_ids().find("") == -1)
	session.hero.health = 0
	session.record_casualties()
	var container: Dictionary = session.ground_container_at(session.player_pos)
	assert(not container.is_empty())
	assert(container["loot"].size() == 2)
	assert(session.carried_items["sword"] == 40)
	assert(session.carried_items["shield"] == 0)
	var container_id: String = str(container["id"])
	assert(not session.can_take_ground_loot(container_id, 1))
	assert(session.take_ground_loot(container_id, 1) == 0)
	assert(session._remove_carried_item("sword", 1))
	assert(session.take_ground_loot(container_id, 1) == 1)
	assert(session.hero.shield_durabilities["shield"] == [3])
	assert(session.ground_container_by_id(container_id)["loot"].size() == 1)
	assert(session._remove_carried_item("sword", 1))
	assert(session.take_ground_loot(container_id, 0) == 1)
	assert(session.ground_container_by_id(container_id).is_empty())


func _test_last_hero_drops_shared_bag() -> void:
	var session := _session()
	session._receive_item("potion", 3)
	session._receive_item("warhammer", 1)
	session.hero.gold = 12
	var fallen: HeroState = session.hero
	fallen.health = 0
	assert(session.record_casualties().size() == 1)
	assert(session.is_party_defeated())
	assert(session.hero == null)
	assert(session.carried_items.is_empty())
	assert(session.inventory_slot_ids().count("potion") == 0)
	var container: Dictionary = session.ground_container_at(session.player_pos)
	assert(container["loot"].size() == 3)
	assert(not session.can_take_ground_loot(str(container["id"]), 0))
	assert(fallen.max_health > 0)
	assert(session.fallen_heroes.has(fallen))


func _test_floor_persistence_and_loot_removal() -> void:
	var session := _session()
	assert(session.add_party_member("volcha"))
	session.hero.gold = 6
	session.hero.health = 0
	session.record_casualties()
	var container_id: String = str(session.ground_loot_containers[0]["id"])
	var original: String = JSON.stringify(session.map_data.to_dict())
	var original_map: DungeonMap = session.map_data
	var next_map := DungeonMap.create_blank(8, 8)
	assert(next_map.place_entity("player_spawn", 3, 3))
	assert(session.enter_map(next_map))
	assert(session.ground_loot_containers.is_empty())
	assert(session.enter_map(original_map))
	assert(session.ground_container_by_id(container_id)["loot"][0]["quantity"] == 6)
	assert(session.take_ground_loot(container_id, 0) == 6)
	assert(session.ground_container_by_id(container_id).is_empty())
	assert(session.ground_container_at(session.player_pos).is_empty())
	assert(JSON.stringify(original_map.to_dict()) == original)


func _test_ground_index() -> void:
	var session := _session()
	var cell := session.player_pos
	session._append_ground_loot(cell, [{"item_id": "gold", "quantity": 2}])
	session._append_ground_loot(cell + Vector2i(1, 0), [{"item_id": "gold", "quantity": 7}])
	session._append_ground_loot(cell, [{"item_id": "gold", "quantity": 3}])
	var container: Dictionary = session.ground_container_at(cell)
	var container_id: String = str(container["id"])
	assert(container["loot"].size() == 2)
	assert(session.ground_container_by_id(container_id) == container)
	assert(session.entities_at(cell.x, cell.y).back()["id"] == container_id)
	assert(session.map_data.entities_at(cell.x, cell.y).size() == 1)
	assert(session.take_ground_loot(container_id, 0) == 2)
	assert(session.take_ground_loot(container_id, 0) == 3)
	assert(session.ground_container_at(cell).is_empty())
	assert(session.ground_container_by_id(container_id).is_empty())
	assert(session.ground_container_at(cell + Vector2i(1, 0))["loot"][0]["quantity"] == 7)
	assert(session.entities_at(cell.x, cell.y).size() == 1)


func _test_ground_snapshots() -> void:
	var session := _session()
	var cell: Vector2i = session.player_pos
	var entries: Array[Dictionary] = [{"item_id": "gold", "quantity": 2}]
	session._append_ground_loot(cell, entries)
	session._append_ground_loot(cell, entries)
	entries[0]["quantity"] = 999
	var container: Dictionary = session.ground_container_at(cell)
	var id: String = str(container["id"])
	container["loot"][0]["quantity"] = 999
	var by_id: Dictionary = session.ground_container_by_id(id)
	by_id["loot"].clear()
	var all: Array[Dictionary] = session.ground_loot_containers
	all[0]["loot"][1]["quantity"] = 999
	all.clear()
	assert(session.ground_container_by_id(id)["loot"] == [{"item_id": "gold", "quantity": 2}, {"item_id": "gold", "quantity": 2}])
	assert(session.take_ground_loot(id, 0) == 2)
	assert(session.take_ground_loot(id, 0) == 2)
	assert(session.take_ground_loot(id, 0) == 0 and session.hero.gold == 4)
