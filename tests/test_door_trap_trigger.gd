extends SceneTree


func _initialize() -> void:
	_test_trigger_order_and_damage()
	_test_locked_door()
	_test_last_hero_death()
	_test_survivor_continues()
	_test_floor_return()
	print("Door crossbow: triggers, messages, party damage, death and floor state OK")
	quit()


func _map_with_door() -> DungeonMap:
	var map := DungeonMap.create_blank(7, 7)
	assert(map.place_entity("player_spawn", 1, 2))
	assert(map.place_entity("door", 2, 2))
	var door: Dictionary = map.entities_at(2, 2)[0]
	assert(map.attach_door_trap(str(door["id"]), "door_crossbow"))
	return map


func _test_trigger_order_and_damage() -> void:
	var map: DungeonMap = _map_with_door()
	assert(map.set_message_at(2, 2, "Послание за дверью"))
	var door: Dictionary = map.entities_at(2, 2)[0]
	var original: String = JSON.stringify(map.to_dict())
	var trap_damage: int = TrapCatalog.get_trap("door_crossbow").direct_damage
	var heroes: Array[String] = ["petushan", "volcha"]
	var session := GameSession.start_for_party(map, heroes)
	assert(session != null)
	session._receive_item("key", 1)
	session.trap_random.seed = 207
	var members: Array[HeroState] = session.party_members()
	members[0].agility = 0
	var initial: Array[int] = [members[0].health, members[1].health]
	assert(not session.move_by(1, 0))
	assert(session.has_pending_door_trap())
	assert(session.player_pos == Vector2i(1, 2))
	assert(int(session.carried_items.get("key", 0)) == 1)
	assert(not session.is_entity_removed(door))
	assert(not session.is_trap_disarmed(door))
	var messages: Array[Dictionary] = session.take_message_events()
	assert(messages.size() == 1)
	assert(messages[0]["activation"] == "door_trap")
	assert(messages[0]["text"] == TrapCatalog.get_trap("door_crossbow").trigger_message)
	assert(str(messages[0].get("icon_type", "")) == "trap")
	assert(str(messages[0].get("icon_id", "")) == "door_crossbow")
	assert(not session.move_by(1, 0))
	assert(session.take_message_events().is_empty())
	assert(members[0].health == initial[0] and members[1].health == initial[1])
	assert(session.resolve_pending_door_trap())
	assert(not session.has_pending_door_trap())
	assert(not session.resolve_pending_door_trap())
	assert(session.is_trap_disarmed(door))
	assert(session.player_pos == Vector2i(2, 2))
	assert(session.is_entity_removed(door))
	assert(int(session.carried_items.get("key", 0)) == 0)
	var hit_count: int = 0
	for i in range(members.size()):
		var damage: int = initial[i] - members[i].health
		assert(damage == 0 or damage == trap_damage)
		if damage == trap_damage:
			hit_count += 1
	assert(hit_count == 1 and members[0].health == initial[0] - trap_damage)
	var hits: Array[Dictionary] = session.take_party_damage_events()
	assert(hits.size() == 1 and int(hits[0]["damage"]) == trap_damage)
	assert(session.take_party_damage_events().is_empty())
	messages = session.take_message_events()
	assert(messages.size() == 1)
	assert(messages[0]["activation"] == "door_open")
	assert(messages[0]["text"] == "Послание за дверью")
	assert(str(messages[0]["result_text"]).contains(members[0].definition.display_name))
	assert(session.move_by(-1, 0))
	assert(session.move_by(1, 0))
	assert(session.take_message_events().is_empty())
	assert(session.take_party_damage_events().is_empty())
	assert(JSON.stringify(map.to_dict()) == original)


func _test_locked_door() -> void:
	var map: DungeonMap = _map_with_door()
	var door: Dictionary = map.entities_at(2, 2)[0]
	assert(map.set_door_lock(str(door["id"]), "key_red"))
	assert(map.set_door_trap_message(str(door["id"]), "Засада!"))
	var session := GameSession.start_for(map)
	session._receive_item("key", 1)
	assert(not session.move_by(1, 0))
	assert(not session.has_pending_door_trap())
	assert(session.take_message_events().is_empty())
	assert(int(session.carried_items["key"]) == 1)
	session._receive_item("key_red", 1)
	assert(not session.move_by(1, 0))
	assert(session.has_pending_door_trap())
	var messages: Array[Dictionary] = session.take_message_events()
	assert(messages.size() == 1 and messages[0]["text"] == "Засада!")
	assert(session.resolve_pending_door_trap())
	assert(int(session.carried_items["key_red"]) == 0)
	assert(int(session.carried_items["key"]) == 1)


func _test_last_hero_death() -> void:
	var map: DungeonMap = _map_with_door()
	var door: Dictionary = map.entities_at(2, 2)[0]
	var session := GameSession.start_for(map)
	session._receive_item("key", 1)
	session.hero.agility = 0
	session.hero.health = TrapCatalog.get_trap("door_crossbow").direct_damage - 1
	assert(not session.move_by(1, 0))
	assert(session.take_message_events().size() == 1)
	assert(not session.resolve_pending_door_trap())
	assert(session.is_party_defeated())
	assert(session.player_pos == Vector2i(1, 2))
	assert(not session.is_entity_removed(door))
	assert(session.is_trap_disarmed(door))
	assert(session.fallen_heroes.size() == 1)
	assert(session.take_casualty_events().size() == 1)
	assert(session.take_casualty_events().is_empty())
	var ground: Dictionary = session.ground_container_at(Vector2i(1, 2))
	assert(not ground.is_empty())
	var dropped_key: bool = false
	for item in ground["loot"]:
		if str(item.get("item_id", "")) == "key":
			dropped_key = int(item.get("quantity", 0)) == 1
	assert(dropped_key)
	assert(not session.move_by(1, 0))


func _test_survivor_continues() -> void:
	var map: DungeonMap = _map_with_door()
	var heroes: Array[String] = ["petushan", "volcha"]
	var session := GameSession.start_for_party(map, heroes)
	session._receive_item("key", 1)
	var members: Array[HeroState] = session.party_members()
	session.trap_random.seed = 45
	var victim: HeroState = members[0]
	victim.agility = 0
	var survivor: HeroState = members[1]
	victim.health = TrapCatalog.get_trap("door_crossbow").direct_damage - 1
	assert(not session.move_by(1, 0))
	assert(session.take_message_events().size() == 1)
	assert(session.resolve_pending_door_trap())
	assert(session.party_members().size() == 1)
	assert(session.hero == survivor)
	assert(session.fallen_heroes.has(victim))
	assert(session.take_casualty_events() == [victim])
	assert(session.player_pos == Vector2i(2, 2))
	assert(not session.is_party_defeated())
	assert(session.fallen_hero_locations[0]["position"] == Vector2i(1, 2))


func _test_floor_return() -> void:
	var map: DungeonMap = _map_with_door()
	var other := DungeonMap.create_blank(6, 6)
	assert(other.place_entity("player_spawn", 2, 2))
	var door: Dictionary = map.entities_at(2, 2)[0]
	var session := GameSession.start_for(map)
	session._receive_item("key", 1)
	assert(not session.move_by(1, 0))
	assert(session.take_message_events().size() == 1)
	assert(session.resolve_pending_door_trap())
	assert(session.enter_map(other))
	assert(session.enter_map(map))
	assert(session.is_trap_disarmed(door))
	assert(session.is_entity_removed(door))
	assert(session.move_by(-1, 0))
	assert(session.move_by(1, 0))
	assert(not session.has_pending_door_trap())
	assert(session.take_message_events().is_empty())
