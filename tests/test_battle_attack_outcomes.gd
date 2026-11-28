extends SceneTree

const UnlockedHeroFixture = preload("res://tests/support/unlocked_hero_fixture.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_avoided_block_metadata()
	var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
	var monsters: Array[MonsterDefinition] = [MonsterCatalog.get_monster("skeleton"), MonsterCatalog.get_monster("skeleton")]
	var view: BattleView = load("res://scenes/battle_view.tscn").instantiate()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(1280, 800)
	view.begin(CombatSession.for_encounter(monsters, hero, 125, [hero]), hero)
	view._is_playing_back = true
	await process_frame
	await process_frame
	view._create_impact_layer()
	var state: BattleState = view.current_battle_state()
	var before: Array = [state.rng.state, state.events.duplicate(true), state.get_hero().health, state.get_enemy().health]
	var config: BattleImpactProfile = view.impact_profile
	_check_reaction(view, {"hp_damage": 2, "damage": 2}, false, false, false, false)
	_check_reaction(view, {"hp_damage": 0, "damage": 0, "block_absorbed": 3}, true, false, false, false)
	_check_reaction(view, {"hp_damage": 2, "damage": 2, "block_absorbed": 3}, true, true, false, false)
	_check_reaction(view, {"hp_damage": 2, "damage": 2, "critical": true}, false, false, false, true)
	_check_reaction(view, {"hp_damage": 0, "dodged": true, "block_absorbed": 3}, false, false, true, false)
	_check_reaction(view, {"hp_damage": 0, "missed": true}, false, false, true, false)
	assert(config.contact_pause({"critical": true, "hp_damage": 2}) > config.contact_pause({"hp_damage": 2}))
	assert(config.contact_pause({"dodged": true, "critical": true, "hp_damage": 2}) == 0.0)
	var expired: Control = view._attack_numbers["enemy"]
	expired.queue_free()
	await process_frame
	assert(not is_instance_valid(expired))
	_check_reaction(view, {"hp_damage": 1, "damage": 1}, false, false, false, false)
	_check_multi_hit(view, 0.009)
	_check_multi_hit(view, 0.073)
	_check_real_multi_hit(view)
	_check_reaction(view, {"hp_damage": 1, "damage": 8, "hp_after": 0}, false, false, false, false)
	var target: BattleFigureAnimator = view._impact_animators["enemy"]
	assert(target.figure.modulate == BattleFigureAnimator.DEFEATED_MODULATE)
	assert(target.state == BattleFigureAnimator.IDLE)
	assert(state.rng.state == before[0] and state.events == before[1])
	assert(state.get_hero().health == before[2] and state.get_enemy().health == before[3])
	view._cancel_playback()
	assert(view._impact_layer == null)
	view.queue_free()
	await process_frame
	print("Battle attack outcomes, block metadata and ordered multi-hit playback passed")
	quit()


func _event(result: Dictionary) -> Dictionary:
	var event: Dictionary = {"type": "attack", "actor_id": "hero", "target_id": "enemy", "ability_id": "basic_strike"}
	event.merge(result, true)
	return event


func _check_reaction(view: BattleView, result: Dictionary, blocked: bool, penetrated: bool, missed: bool, critical: bool) -> void:
	var event: Dictionary = _event(result)
	var target: BattleFigureAnimator = view._impact_animators["enemy"]
	view._playback = view.create_tween()
	view._playback.pause()
	view._queue_single_attack(event)
	for i in range(200):
		if is_instance_valid(view._active_impact_effect):
			break
		view._playback.custom_step(0.005)
	var effect: BattleImpactEffect = view._active_impact_effect
	assert(is_instance_valid(effect))
	assert(effect.blocked == blocked and effect.penetrated == penetrated and effect.missed == missed and effect.critical == critical)
	assert(target.state == (BattleFigureAnimator.HURT if BattleImpactProfile.hp_damage(event) > 0 else BattleFigureAnimator.IDLE))
	assert(effect.intensity == (view.impact_profile.critical_intensity if critical else 1.0))
	if penetrated:
		var numbers: Control = view._attack_numbers["enemy"]
		assert(numbers.get_child_count() == 2 and numbers.get_child(0).text == "−3" and numbers.get_child(1).text == "−2")
	if missed:
		assert(effect.shake_offset(100.0) == Vector2.ZERO)
		view._playback.custom_step(0.04)
		assert((target.figure.position != target.home) == bool(event.get("dodged", false)))
		var expected: String = "УКЛОНЕНИЕ" if event.get("dodged", false) else "ПРОМАХ"
		assert(view._attack_numbers["enemy"].get_children().any(func(child: Node) -> bool: return child is Label and child.text == expected))
	view._playback.custom_step(10.0)
	assert(target.figure.position.is_equal_approx(target.home))
	assert(view._active_impact_effect == null and view._impact_shake == Vector2.ZERO)


func _check_multi_hit(view: BattleView, step: float) -> void:
	var events: Array[Dictionary] = [
		_event({"ability_id": "volcha_broken_rhythm", "hit_index": 0, "hit_count": 3, "hp_damage": 0, "block_absorbed": 2, "hp_after": 10}),
		_event({"ability_id": "volcha_broken_rhythm", "hit_index": 1, "hit_count": 3, "hp_damage": 0, "dodged": true, "hp_after": 10}),
		_event({"ability_id": "volcha_broken_rhythm", "hit_index": 2, "hit_count": 3, "hp_damage": 2, "hp_after": 8})]
	var log: Array[String] = []
	var collect: Callable = func(line: String) -> void: log.append(line)
	view.combat_log_line.connect(collect)
	view._playback = view.create_tween()
	view._playback.pause()
	view._queue_clash_animation(events)
	var effects: Array[BattleImpactEffect] = []
	var outcomes: Array = []
	for i in range(3000):
		if not view._playback.is_valid():
			break
		view._playback.custom_step(step)
		var effect: BattleImpactEffect = view._active_impact_effect
		if is_instance_valid(effect) and not effects.has(effect):
			effects.append(effect)
			outcomes.append([effect.blocked, effect.missed, effect.penetrated])
	assert(outcomes == [[true, false, false], [false, true, false], [false, false, false]])
	assert(log.size() == 3 and log[0].contains("блок −2") and log[1].contains("уклонение") and log[2].contains("HP −2 (8/"))
	assert(view._visible_enemy_hp == 8)
	view.combat_log_line.disconnect(collect)


func _check_avoided_block_metadata() -> void:
	var attacker := BattleParticipant.new()
	var target := BattleParticipant.new()
	attacker.health = 100
	target.health = 100
	target.max_health = 100
	target.prepare_block(3)
	var blocked: Dictionary = AbilityExecutor.apply_damage(attacker, target, 2, "basic_strike")
	assert(blocked.block_absorbed > 0)
	target.base_dodge_percent = 100
	target.last_shield_broken = "previous_shield"
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var avoided: Dictionary = AbilityExecutor.apply_damage(attacker, target, 2, "basic_strike", rng)
	assert(avoided.dodged and avoided.block_absorbed == 0 and avoided.shield_blocked == 0 and avoided.shield_broken == "")


func _check_real_multi_hit(view: BattleView) -> void:
	var source := HeroState.new(UnlockedHeroFixture.definition("volcha"))
	var battle := BattleState.begin(MonsterCatalog.get_monster("skeleton"), source)
	var actor: BattleParticipant = battle.get_hero()
	var target: BattleParticipant = battle.get_enemy()
	actor.accuracy_bonus = BattleMath.PERCENT_SCALE
	actor.resource_amounts["energy"] = actor.max_energy
	target.health = 1000
	target.max_health = 1000
	battle.rng.seed = 42
	var ability: AbilityDefinition = AbilityCatalog.get_ability("volcha_broken_rhythm")
	var result: Dictionary = battle.execute_definition("hero", "enemy", ability)
	assert(result.success)
	var hits: Array[Dictionary] = []
	for event in result.events:
		if event.get("type") == "attack":
			hits.append(event)
	assert(hits.size() == ability.effects[0].hit_count)
	for i in range(hits.size()):
		assert(hits[i].hit_index == i and hits[i].hit_count == hits.size())
	var log: Array[String] = []
	var collect: Callable = func(line: String) -> void: log.append(line)
	view.combat_log_line.connect(collect)
	view._playback = view.create_tween()
	view._playback.pause()
	view._queue_clash_animation(hits)
	view._playback.custom_step(60.0)
	assert(log.size() == hits.size())
	assert(view._visible_enemy_hp == hits[-1].hp_after)
	for i in range(hits.size()):
		assert(log[i] == BattleCombatLog.format_event(hits[i], view._hero_name_for_id("hero"), view._enemy_name_for_id("enemy")))
	view.combat_log_line.disconnect(collect)
