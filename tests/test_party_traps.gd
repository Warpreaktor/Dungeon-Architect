extends SceneTree


func _initialize() -> void:
	var dungeon := DungeonMap.create_blank(10, 6)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("trap", 3, 2, {"trap_id": "spikes"}))
	var trap_entity: Dictionary = dungeon.entities_at(3, 2)[0]
	var play := GameSession.start_for(dungeon)
	assert(play != null)
	assert(play.party_members().size() == 1)
	assert(play.add_party_member("petushan"))
	assert(play.add_party_member("volcha"))
	assert(play.add_party_member("petushan"))
	assert(play.party_members().size() == GameSession.MAX_PARTY_SIZE)
	assert(not play.add_party_member("volcha"))
	assert(not play.add_party_member("missing_hero"))

	play.trap_random.seed = 1345
	var members: Array[HeroState] = play.party_members()
	var starting_health: Array[int] = []
	for member in members:
		starting_health.append(member.health)
	assert(play.move_by(1, 0))
	assert(play.is_trap_disarmed(trap_entity))
	var wounded_index: int = -1
	for i in range(members.size()):
		var missing: int = starting_health[i] - members[i].health
		if missing > 0:
			assert(wounded_index == -1)
			assert(missing == 2)
			assert(members[i].overworld_statuses.has("bleeding"))
			wounded_index = i
		else:
			assert(members[i].overworld_statuses.is_empty())
	assert(wounded_index != -1)
	var hit_events: Array[Dictionary] = play.take_party_damage_events()
	assert(hit_events.size() == 1)
	assert(int(hit_events[0]["hero_index"]) == wounded_index)
	assert(play.take_party_damage_events().is_empty())

	for i in range(3):
		assert(play.move_by(-1 if i % 2 == 0 else 1, 0))
		assert(members[wounded_index].health == starting_health[wounded_index] - 2)
	assert(play.move_by(1, 0))
	assert(members[wounded_index].health == starting_health[wounded_index] - 4)
	assert(play.take_party_damage_events()[0]["hero_index"] == wounded_index)
	for i in range(3):
		assert(play.move_by(-1 if i % 2 == 0 else 1, 0))
	assert(play.move_by(1, 0))
	assert(members[wounded_index].health == starting_health[wounded_index] - 6)
	assert(not members[wounded_index].overworld_statuses.has("bleeding"))
	for i in range(members.size()):
		if i != wounded_index:
			assert(members[i].health == starting_health[i])

	var follow_up := GameSession.start_for(dungeon)
	assert(follow_up.add_party_member("petushan"))
	follow_up.hero.health = 0
	follow_up.move_by(1, 0)
	assert(follow_up.hero.health > 0)
	assert(follow_up.party_members()[0].health == 0)
	assert(follow_up.party_members()[1].health > 0)

	call_deferred("_verify_hud", members)


func _verify_hud(members: Array[HeroState]) -> void:
	var hud_scene: PackedScene = load("res://scenes/hero_hud.tscn") as PackedScene
	var hud: HeroHUD = hud_scene.instantiate() as HeroHUD
	root.add_child(hud)
	hud.set_party(members)
	var row: HBoxContainer = hud.get_node("PartyRow") as HBoxContainer
	assert(row.get_child_count() == GameSession.MAX_PARTY_SIZE)
	for i in range(row.get_child_count()):
		var slot: PartyPortraitSlot = row.get_child(i) as PartyPortraitSlot
		assert(slot.visible)
		assert(slot._health.text == "%d / %d" % [members[i].health, members[i].max_health])
		assert(slot._health_bar.value == float(members[i].health))
		assert(slot._health_bar.max_value == float(members[i].max_health))
		assert(not slot._health_bar.show_percentage)
		assert(slot._health.get_parent() == slot._health_bar.get_parent())
		assert(slot._portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		assert(slot._badges.get_parent() == slot)
		assert(slot._badges.custom_minimum_size.y > 0.0)
		assert(slot._badges.get_index() > slot._health.get_parent().get_index())
	members[0].apply_overworld_status("bleeding", "Кровотечение", 2, 2, 4)
	hud.set_party(members)
	var first_slot: PartyPortraitSlot = row.get_child(0) as PartyPortraitSlot
	assert(first_slot._badges.get_child_count() == 1)
	first_slot.flash_damage()
	hud.set_hero(members[0])
	assert(row.get_child(0).visible)
	for i in range(1, row.get_child_count()):
		assert(not row.get_child(i).visible)
	print("Party HUD and trap tests passed")
	quit()
