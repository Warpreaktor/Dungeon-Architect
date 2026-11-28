extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for viewport_size in [Vector2(1280, 800), Vector2(720, 480)]:
		var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
		var legacy := HeroState.new(HeroCatalog.get_hero("petushan"))
		var monsters: Array[MonsterDefinition] = [MonsterCatalog.get_monster("skeleton"), MonsterCatalog.get_monster("skeleton")]
		var view: BattleView = load("res://scenes/battle_view.tscn").instantiate()
		root.add_child(view)
		view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		view.size = viewport_size
		view.begin(CombatSession.for_encounter(monsters, hero, 125, [hero, legacy]), hero)
		view._is_playing_back = true
		await process_frame
		await process_frame
		view._create_impact_layer()
		var state: BattleState = view.current_battle_state()
		var before: Array = [state.rng.state, state.events.duplicate(true), state.get_hero().health, state.get_enemy().health]
		var hud: Rect2 = view._sequence_slots.get_global_rect()
		var normal: BattleImpactProfile = view.impact_profile
		assert(normal.hit_sound != null and normal.block_sound != null and normal.swing_sound != null)
		assert(normal.hit_sound != normal.block_sound and normal.hit_sound != normal.swing_sound)
		var custom: BattleImpactProfile = normal.duplicate() as BattleImpactProfile
		custom.hit_stop_seconds = 0.10
		custom.shake_fraction = 0.025
		custom.particle_count = 6
		var ability: AbilityDefinition = AbilityCatalog.get_ability("basic_strike")
		var original: BattleImpactProfile = ability.impact_profile
		ability.impact_profile = custom
		_check_attack(view, "hero", "enemy", {"damage": 2, "hp_damage": 2}, false, custom, 0.003)
		_check_attack(view, "enemy", "hero", {"damage": 1, "hp_damage": 1, "block_absorbed": 2}, false, custom, 0.019)
		_check_attack(view, "hero", "enemy", {"damage": 0, "hp_damage": 0, "dodged": true}, false, custom, 0.011)
		_check_attack(view, "hero_2", "enemy", {"damage": 0, "hp_damage": 0, "block_absorbed": 2}, true, custom, 0.007)
		_check_attack(view, "hero_2", "enemy", {"damage": 1, "hp_damage": 1}, true, custom, 0.017)
		_check_attack(view, "hero", BattleState.SUPPORT_ENEMY_ID, {"damage": 1, "hp_damage": 1}, false, custom, 0.025)
		ability.impact_profile = original
		assert(state.rng.state == before[0] and state.events == before[1])
		assert(state.get_hero().health == before[2] and state.get_enemy().health == before[3])
		assert(view._sequence_slots.get_global_rect() == hud)
		var event: Dictionary = _event("hero", "enemy", {"damage": 1, "hp_damage": 1})
		view._playback = view.create_tween()
		view._playback.pause()
		view._queue_single_attack(event)
		view._playback.custom_step(0.5)
		assert(is_instance_valid(view._active_impact_effect))
		view._cancel_playback()
		assert(view._active_impact_effect == null and view._impact_shake == Vector2.ZERO and view._impact_layer == null)
		view.queue_free()
		await process_frame
	print("Battle impact profile, synchronization, hit stop, SFX and cleanup passed")
	quit()


func _event(actor_id: String, target_id: String, result: Dictionary) -> Dictionary:
	var event: Dictionary = {"type": "attack", "actor_id": actor_id, "target_id": target_id, "ability_id": "basic_strike"}
	event.merge(result)
	return event


func _check_attack(view: BattleView, actor_id: String, target_id: String, result: Dictionary,
		show_slash: bool, config: BattleImpactProfile, step: float) -> void:
	var event: Dictionary = _event(actor_id, target_id, result)
	var actor: BattleFigureAnimator = view._impact_animators[actor_id]
	var target: BattleFigureAnimator = view._impact_animators[target_id]
	var hud: Rect2 = view._sequence_slots.get_global_rect()
	var layer_origin: Vector2 = view._impact_layer.position
	view._playback = view.create_tween()
	view._playback.pause()
	view._queue_single_attack(event)
	assert(view._active_impact_effect == null)
	for i in range(1500):
		if is_instance_valid(view._active_impact_effect):
			break
		view._playback.custom_step(step)
	var effect: BattleImpactEffect = view._active_impact_effect
	assert(is_instance_valid(effect))
	assert(actor.state == BattleFigureAnimator.STRIKE)
	assert(effect.profile == config and effect.show_slash == show_slash)
	assert(effect.missed == BattleImpactProfile.is_miss(event))
	assert(effect.blocked == BattleImpactProfile.is_block(event))
	assert(effect._sound.bus == &"SFX" and effect._sound.stream == config.sound_for(event))
	if not effect.missed:
		var expected: Vector2 = target.visible_point(target.current_pose.hit_anchor if target.current_pose != null else Vector2(0.5, 0.5))
		assert(effect.position.distance_to(expected) < 0.1)
		var contact_position: Vector2 = actor.figure.position
		var target_position: Vector2 = target.figure.position
		view._playback.custom_step(config.hit_stop_seconds * 0.4)
		assert(actor.figure.position == contact_position and target.figure.position == target_position)
		assert(view._impact_shake.length() > 0.0 and view._impact_layer.position != layer_origin)
	else:
		view._playback.custom_step(0.01)
		assert(config.contact_pause(event) == 0.0 and view._impact_shake == Vector2.ZERO)
		assert(target.state == BattleFigureAnimator.IDLE)
	assert(view._sequence_slots.get_global_rect() == hud)
	view._playback.custom_step(10.0)
	assert(view._active_impact_effect == null and view._impact_shake == Vector2.ZERO)
	assert(view._impact_layer.position.is_equal_approx(layer_origin))
	assert(actor.state == BattleFigureAnimator.IDLE and target.state == BattleFigureAnimator.IDLE)
