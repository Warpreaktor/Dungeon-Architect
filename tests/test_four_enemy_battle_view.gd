extends SceneTree

const HERO_IDS: Array[String] = ["volcha", "petushan", "burolom", "luma"]
const MONSTER_IDS: Array[String] = ["skeleton", "hunter", "skeleton", "lobar"]


func _initialize() -> void:
	call_deferred("_run")


func _make_view(hero_count: int, enemy_count: int, viewport_size: Vector2, boss: bool = false) -> BattleView:
	var heroes: Array[HeroState] = []
	for index in range(hero_count):
		var hero := HeroState.new(HeroCatalog.get_hero(HERO_IDS[index]))
		hero.agility = 100 - index
		heroes.append(hero)
	var monsters: Array[MonsterDefinition] = []
	if boss:
		monsters.append(MonsterCatalog.get_monster("rabbit_symbiont"))
	else:
		for index in range(enemy_count):
			monsters.append(MonsterCatalog.get_monster(MONSTER_IDS[index]))
	var combat: CombatSession = CombatSession.for_encounter(monsters, heroes[0], 7331, heroes)
	assert(combat != null)
	var view: BattleView = load("res://scenes/battle_view.tscn").instantiate() as BattleView
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	view.size = viewport_size
	view.begin(combat, heroes[0])
	view._is_playing_back = true
	return view


func _check_team(view: BattleView, actor_ids: Array[String], side: Control) -> void:
	var portraits: Array[Rect2] = []
	var previous_x: float = -INF
	for actor_id in actor_ids:
		var portrait: TextureRect = view._portrait_for_id(actor_id)
		assert(portrait != null and portrait.is_visible_in_tree())
		assert(portrait.texture != null and portrait.size.x > 0.0 and portrait.size.y > 0.0)
		assert(is_equal_approx(portrait.size.x, portrait.size.y))
		var rect: Rect2 = portrait.get_global_rect()
		assert(side.get_global_rect().grow(1.0).encloses(rect))
		assert(view.get_global_rect().grow(1.0).encloses(rect))
		assert(rect.position.x > previous_x)
		previous_x = rect.position.x
		for previous in portraits:
			assert(not previous.intersects(rect))
		portraits.append(rect)
		assert(view._target_outlines.has(actor_id))
		assert(view._turn_frame_overlays.has(actor_id))
		assert(view._status_presenter._status_markers.has(actor_id))


func _check_composition(hero_count: int, enemy_count: int, viewport_size: Vector2) -> void:
	var view: BattleView = _make_view(hero_count, enemy_count, viewport_size)
	await process_frame
	await process_frame
	var state: BattleState = view.current_battle_state()
	assert(state.hero_ids().size() == hero_count and state.enemy_ids().size() == enemy_count)
	_check_team(view, state.hero_ids(), view._hero_party.get_parent() as Control)
	_check_team(view, state.enemy_ids(), view._enemy_party.get_parent() as Control)
	for id in state.enemy_ids():
		var actor: BattleParticipant = state.get_participant(id)
		assert(view._visible_energy[id] == actor.current_energy())
		if id != "enemy":
			var card: BattleSupportEnemyView = view._extra_enemy_views[id]
			assert(card._participant == actor)
			assert(view._extra_enemy_hp[id] == actor.health)
			assert(view._extra_enemy_max[id] == actor.max_health)
			assert(card._energy.text.contains("%d/%d" % [actor.current_energy(), actor.max_energy]))
	if hero_count == 4 and enemy_count == 4:
		_check_attack_animation(view)
	view.queue_free()
	await process_frame


func _check_attack_animation(view: BattleView) -> void:
	var state: BattleState = view.current_battle_state()
	var actor_id: String = "hero_4"
	var target_id: String = "enemy_4"
	var target: BattleParticipant = state.get_participant(target_id)
	var original_health: int = target.health
	var original_rng: int = state.rng.state
	var event_count: int = state.events.size()
	var initial: Dictionary = {}
	for id in state.hero_ids() + state.enemy_ids():
		initial[id] = view._portrait_for_id(id).global_position
	view._create_impact_layer()
	assert(view._impact_portraits.size() == 8)
	for id in initial:
		var portrait: TextureRect = view._impact_portraits[id]
		assert(portrait.global_position.is_equal_approx(initial[id]))
		assert(view._impact_idle[id] == view._impact_origin[id])
	view._playback = view.create_tween()
	view._playback.pause()
	var enemy_actor: String = "enemy_3"
	var ability_id: String = "skeleton_rusty_slash"
	var announcement: Array[Dictionary] = [{"type": "action_start", "actor_id": enemy_actor, "ability_id": ability_id, "slot_index": -1}]
	view._queue_clash_animation(announcement)
	view._playback.custom_step(view.action_emblem_seconds * 0.5)
	assert(view._action_emblem != null and view._action_emblem.modulate.a > 0.0)
	assert(view._action_emblem._caption.text == AbilityCatalog.get_ability(ability_id).display_name)
	assert(view._action_emblem._source == view._impact_portraits[enemy_actor])
	assert(not view._enemy_sequence_scroll.visible and not (view._extra_enemy_views[enemy_actor] as BattleSupportEnemyView)._slots.visible)
	for id in initial:
		assert((view._impact_portraits[id] as TextureRect).global_position.is_equal_approx(initial[id]))
	view._playback.custom_step(10.0)
	assert(view._action_emblem == null)
	assert(state.rng.state == original_rng and state.events.size() == event_count)
	view._playback = view.create_tween()
	view._playback.pause()
	view._queue_single_attack({"type": "attack", "actor_id": actor_id, "target_id": target_id,
		"ability_id": "basic_strike", "damage": 1, "hp_after": original_health - 1,
		"hp_max": target.max_health})
	view._playback.custom_step(view.clash_windup_seconds * 0.5 + 0.001)
	var attacker: TextureRect = view._impact_portraits[actor_id]
	assert(not attacker.global_position.is_equal_approx(initial[actor_id]))
	for id in initial:
		if id != actor_id:
			assert((view._impact_portraits[id] as TextureRect).global_position.is_equal_approx(initial[id]))
	view._playback.custom_step(10.0)
	for id in initial:
		assert((view._impact_portraits[id] as TextureRect).global_position.is_equal_approx(initial[id]))
	assert(view._extra_enemy_hp[target_id] == original_health - 1)
	assert(view._extra_enemy_hp["enemy_3"] == state.get_participant("enemy_3").health)
	assert(target.health == original_health and state.rng.state == original_rng and state.events.size() == event_count)
	view._clear_impact_layer()
	view._show_turn_frame("enemy_3")
	assert((view._turn_frame_overlays["enemy_3"] as Control).visible)
	assert(not (view._turn_frame_overlays["enemy_4"] as Control).visible)
	view._display_phase_event({"type": "resource_spent", "actor_id": "enemy_4", "resource_id": "energy", "remaining": 1})
	assert((view._extra_enemy_views["enemy_4"] as BattleSupportEnemyView)._energy.text.contains("1/"))
	view._is_playing_back = false
	view._continue_round()
	assert(view._round_next_actor() == "hero")
	var strike_index: int = view._hero_chain.find("volcha_wolf_lunge")
	assert(strike_index >= 0)
	view._on_slot_selected(strike_index)
	assert((view._target_outlines["enemy_4"] as Control).visible)
	var event: InputEvent
	if view.size.x < 1000.0:
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		event = touch
	else:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		event = mouse
	view._on_target_portrait_input(event, "enemy_4")
	assert(state.round_turn_count == 1)
	assert(state.events.any(func(e: Dictionary) -> bool:
		return e.get("actor_id") == "hero" and e.get("target_id") == "enemy_4" and e.get("ability_id") == "volcha_wolf_lunge"))


func _check_bond() -> void:
	var view: BattleView = _make_view(4, 1, Vector2(900, 600), true)
	await process_frame
	await process_frame
	var state: BattleState = view.current_battle_state()
	var commander_id: String = state.bond_commander_id
	var guardian_id: String = state.bond_guardian_id
	var commander: BattleParticipant = state.get_participant(commander_id)
	assert(view._mounted_display and not view._support_enemy_view.visible)
	assert(view._mounted_details.visible and view._mounted_details.text.contains(str(commander.health)))
	assert(view._portrait_for_id(commander_id) == view._portrait_for_id(guardian_id))
	view._create_impact_layer()
	assert(view._impact_portraits[commander_id] == view._impact_portraits[guardian_id])
	view._clear_impact_layer()
	var commander_hp: int = commander.health
	state._bond_change_form(false)
	view._sync_enemy_formation()
	await process_frame
	assert(not view._mounted_display and view._support_enemy_view.visible)
	assert(view._portrait_for_id(commander_id) != view._portrait_for_id(guardian_id))
	assert(commander.health == commander_hp)
	state._bond_change_form(true)
	view._sync_enemy_formation()
	assert(view._mounted_display and not view._support_enemy_view.visible)
	state.get_participant(guardian_id).health = 0
	state.update_outcome()
	view._sync_enemy_formation()
	assert(not state.is_victory and not view._mounted_display)
	assert(view._portrait_for_id(commander_id) != null and view._portrait_for_id(guardian_id) == null)
	view.queue_free()
	await process_frame


func _check_editor_encounter() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	var dungeon: DungeonMap = DungeonMap.create_blank(7, 7)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("monster", 3, 2, {"monster_id": MONSTER_IDS[0]}))
	var entity: Dictionary = dungeon.entities_at(3, 2)[0]
	assert(dungeon.set_monster_party(str(entity["id"]), MONSTER_IDS))
	assert(dungeon.set_monster_loot(str(entity["id"]), ["gold"], 7))
	editor.call("_set_map", dungeon)
	editor.call("_start_play_mode")
	var session: GameSession = editor.get("game_session") as GameSession
	assert(not session.move_by(1, 0) and session.has_pending_encounter())
	editor.set("_combat_active", true)
	editor.call("_show_combat_view")
	var view: BattleView = editor.get("_battle_view") as BattleView
	var state: BattleState = view.current_battle_state()
	assert(state.enemy_ids().size() == 4)
	view._is_playing_back = true
	var victories: int = session.loot_victories
	for index in range(4):
		state.get_participant(state.enemy_ids()[index]).health = 0
		state.update_outcome()
		assert(state.is_victory == (index == 3))
		assert(session.has_pending_encounter())
	view.battle_won.emit()
	assert(not session.has_pending_encounter())
	assert(session.loot_victories == victories + 1)
	editor.call("_finish_combat")
	assert(session.loot_victories == victories + 1)
	editor.queue_free()
	await process_frame


func _run() -> void:
	for viewport_size in [Vector2(1280, 800), Vector2(720, 480)]:
		for hero_count in range(1, 5):
			for enemy_count in range(1, 5):
				await _check_composition(hero_count, enemy_count, viewport_size)
	await _check_bond()
	await _check_editor_encounter()
	print("Four enemy battle view: all compositions, stationary portraits, event routing and bond forms OK")
	quit()
