extends SceneTree


func _initialize() -> void:
	_test_plain_door_and_missing_key()
	_test_two_door_traps_and_floor_return()
	_test_random_living_target_and_reproducibility()
	_test_json_preserves_trap_configuration()
	print("Door trap regressions: doors, party, keys, floors and JSON OK")
	quit()


func _map_with_doors() -> DungeonMap:
	var map: DungeonMap = DungeonMap.create_blank(9, 8)
	assert(map.place_entity("player_spawn", 1, 2))
	assert(map.place_entity("door", 2, 2))
	assert(map.place_entity("door", 4, 2))
	assert(map.place_entity("door", 2, 4))
	return map


func _door(map: DungeonMap, position: Vector2i) -> Dictionary:
	for entity in map.entities_at(position.x, position.y):
		if str(entity.get("type", "")) == "door":
			return entity
	return {}


func _test_plain_door_and_missing_key() -> void:
	var map: DungeonMap = _map_with_doors()
	var trapped: Dictionary = _door(map, Vector2i(2, 2))
	assert(map.attach_door_trap(str(trapped["id"]), "door_crossbow"))
	assert(map.set_door_lock(str(trapped["id"]), "key_red"))
	var session: GameSession = GameSession.start_for(map)
	var hp_before: int = session.hero.health
	assert(not session.move_by(1, 0))
	assert(not session.has_pending_door_trap())
	assert(not session.is_trap_disarmed(trapped))
	assert(session.take_message_events().is_empty())
	assert(session.hero.health == hp_before)
	assert(session.player_pos == Vector2i(1, 2))
	assert(not session.is_entity_removed(trapped))
	assert(map.set_door_lock(str(trapped["id"]), "key"))
	session._receive_item("key", 1)
	assert(not session.move_by(1, 0))
	assert(session.has_pending_door_trap())
	assert(int(session.carried_items.get("key", 0)) == 1)
	assert(session.take_message_events().size() == 1)
	assert(session.resolve_pending_door_trap())
	assert(int(session.carried_items.get("key", 0)) == 0)
	assert(session.is_trap_disarmed(trapped))
	assert(session.hero.health == hp_before - TrapCatalog.get_trap("door_crossbow").direct_damage)
	assert(session.move_by(1, 0))
	assert(session.move_by(-1, 0))
	assert(session.move_by(-1, 0))
	assert(session.move_by(1, 0))
	assert(not session.has_pending_door_trap())
	assert(session.take_message_events().is_empty())
	assert(session.take_party_damage_events().is_empty())


func _test_two_door_traps_and_floor_return() -> void:
	var map: DungeonMap = _map_with_doors()
	var first: Dictionary = _door(map, Vector2i(2, 2))
	var second: Dictionary = _door(map, Vector2i(4, 2))
	assert(map.attach_door_trap(str(first["id"]), "door_crossbow"))
	assert(map.attach_door_trap(str(second["id"]), "door_crossbow"))
	assert(map.set_door_trap_message(str(second["id"]), "Второй арбалет"))
	var original_json: String = JSON.stringify(map.to_dict())
	var session: GameSession = GameSession.start_for(map)
	session._receive_item("key", 2)
	assert(not session.move_by(1, 0))
	assert(session.take_message_events().size() == 1)
	assert(session.resolve_pending_door_trap())
	assert(session.is_trap_disarmed(first))
	assert(not session.is_trap_disarmed(second))
	assert(session.move_by(1, 0))
	assert(not session.move_by(1, 0))
	var messages: Array[Dictionary] = session.take_message_events()
	assert(messages.size() == 1)
	assert(str(messages[0]["text"]) == "Второй арбалет")
	assert(session.resolve_pending_door_trap())
	assert(session.is_trap_disarmed(second))
	assert(int(session.carried_items.get("key", 0)) == 0)
	var other: DungeonMap = DungeonMap.create_blank(6, 6)
	assert(other.place_entity("player_spawn", 1, 1))
	assert(session.enter_map(other))
	assert(session.enter_map(map))
	assert(session.is_trap_disarmed(first))
	assert(session.is_trap_disarmed(second))
	assert(session.is_entity_removed(first))
	assert(session.is_entity_removed(second))
	assert(not session.has_pending_door_trap())
	assert(session.move_by(-1, 0))
	assert(session.move_by(-1, 0))
	assert(session.move_by(-1, 0))
	assert(session.move_by(1, 0))
	assert(not session.has_pending_door_trap())
	assert(session.take_message_events().is_empty())
	assert(JSON.stringify(map.to_dict()) == original_json)


func _test_random_living_target_and_reproducibility() -> void:
	var victims: Array[int] = []
	for trial in range(2):
		var map: DungeonMap = _map_with_doors()
		var door: Dictionary = _door(map, Vector2i(2, 2))
		assert(map.attach_door_trap(str(door["id"]), "door_crossbow"))
		var heroes: Array[String] = ["petushan", "volcha"]
		var session: GameSession = GameSession.start_for_party(map, heroes)
		session._receive_item("key", 1)
		session.trap_random.seed = 12345
		var members: Array[HeroState] = session.party_members()
		var hp: Array[int] = [members[0].health, members[1].health]
		assert(not session.move_by(1, 0))
		assert(session.take_message_events().size() == 1)
		assert(session.resolve_pending_door_trap())
		var hit_index: int = -1
		for i in range(2):
			var damage: int = hp[i] - members[i].health
			assert(damage == 0 or damage == TrapCatalog.get_trap("door_crossbow").direct_damage)
			if damage != 0:
				assert(hit_index == -1)
				hit_index = i
		assert(hit_index >= 0)
		victims.append(hit_index)
	assert(victims[0] == victims[1])

	var map: DungeonMap = _map_with_doors()
	var door: Dictionary = _door(map, Vector2i(2, 2))
	assert(map.attach_door_trap(str(door["id"]), "door_crossbow"))
	var heroes: Array[String] = ["petushan", "volcha"]
	var session: GameSession = GameSession.start_for_party(map, heroes)
	var members: Array[HeroState] = session.party_members()
	members[0].health = 0
	session.record_casualties()
	assert(session.party_members().size() == 1)
	var survivor: HeroState = session.party_members()[0]
	var initial_hp: int = survivor.health
	session._receive_item("key", 1)
	assert(not session.move_by(1, 0))
	assert(session.take_message_events().size() == 1)
	assert(session.resolve_pending_door_trap())
	assert(survivor.health == initial_hp - TrapCatalog.get_trap("door_crossbow").direct_damage)
	assert(members[0].health == 0)
	assert(not session.is_party_defeated())


func _test_json_preserves_trap_configuration() -> void:
	var map: DungeonMap = _map_with_doors()
	var door: Dictionary = _door(map, Vector2i(2, 2))
	var plain: Dictionary = _door(map, Vector2i(2, 4))
	assert(map.attach_door_trap(str(door["id"]), "door_crossbow"))
	assert(map.set_door_trap_message(str(door["id"]), "Авторский текст ловушки"))
	assert(map.set_message_at(2, 2, "Авторский текст двери"))
	assert(map.set_door_lock(str(door["id"]), "key_blue"))
	var saved: String = JSON.stringify(map.to_dict())
	var loaded: DungeonMap = DungeonMap.from_dict(JSON.parse_string(saved))
	assert(loaded != null)
	assert(JSON.stringify(loaded.to_dict()) == saved)
	var copy: Dictionary = _door(loaded, Vector2i(2, 2))
	assert(str(copy.get("id", "")) == str(door["id"]))
	assert(DungeonMap.door_trap_id(copy) == "door_crossbow")
	assert(DungeonMap.door_trap_message(copy) == "Авторский текст ловушки")
	assert(LockCatalog.required_key(copy) == "key_blue")
	assert(str(loaded.message_at(2, 2).get("properties", {}).get("text", "")) == "Авторский текст двери")
	assert(DungeonMap.door_trap_id(_door(loaded, Vector2i(2, 4))).is_empty())
	assert(DungeonMap.door_trap_id(plain).is_empty())
