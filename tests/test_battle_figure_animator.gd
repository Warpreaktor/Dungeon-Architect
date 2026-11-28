extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _make_view(heroes: Array[String], monsters: Array[String]) -> BattleView:
	var members: Array[HeroState] = []
	for id in heroes:
		var hero := HeroState.new(HeroCatalog.get_hero(id))
		hero.agility = 100
		members.append(hero)
	var enemies: Array[MonsterDefinition] = []
	for id in monsters:
		enemies.append(MonsterCatalog.get_monster(id))
	var combat: CombatSession = CombatSession.for_encounter(enemies, members[0], 1014, members)
	var view: BattleView = load("res://scenes/battle_view.tscn").instantiate()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(1280, 800)
	view.begin(combat, members[0])
	view._is_playing_back = true
	return view


func _event(view: BattleView, actor: String, target: String, damage: int = 1, dodged: bool = false) -> Dictionary:
	var recipient: BattleParticipant = view.current_battle_state().get_participant(target)
	return {"type": "attack", "actor_id": actor, "target_id": target, "ability_id": "basic_strike",
		"damage": damage, "hp_damage": damage, "hp_after": recipient.health - damage,
		"hp_max": recipient.max_health, "dodged": dodged}


func _run() -> void:
	var view: BattleView = _make_view(["volcha", "petushan"], ["skeleton", "skeleton"])
	await process_frame
	await process_frame
	view._create_impact_layer()
	var hero: BattleFigureAnimator = view._impact_animators["hero"]
	var enemy: BattleFigureAnimator = view._impact_animators["enemy"]
	var extra: BattleFigureAnimator = view._impact_animators[BattleState.SUPPORT_ENEMY_ID]
	var legacy: BattleFigureAnimator = view._impact_animators["hero_2"]
	var state: BattleState = view.current_battle_state()
	var before: Array = [state.rng.state, state.events.duplicate(true), state.get_hero().health, state.get_enemy().health]
	var hud_rect: Rect2 = view._enemy_health_meter.get_global_rect()
	var chain_rect: Rect2 = view._sequence_slots.get_global_rect()
	_check_attack(view, hero, enemy, _event(view, "hero", "enemy"), true)
	_check_attack(view, enemy, hero, _event(view, "enemy", "hero"), true)
	_check_attack(view, hero, extra, _event(view, "hero", BattleState.SUPPORT_ENEMY_ID, 0, true), false)
	var blocked: Dictionary = _event(view, "enemy", "hero", 0)
	blocked["block_absorbed"] = 3
	_check_attack(view, enemy, hero, blocked, false)
	_check_attack(view, legacy, enemy, _event(view, "hero_2", "enemy"), true)
	_check_attack(view, enemy, legacy, _event(view, "enemy", "hero_2"), true)
	assert(view._enemy_health_meter.get_global_rect() == hud_rect)
	assert(view._sequence_slots.get_global_rect() == chain_rect)
	assert(state.rng.state == before[0] and state.events == before[1])
	assert(state.get_hero().health == before[2] and state.get_enemy().health == before[3])
	# A second attack must start from the original pose even after accelerated playback.
	view._playback = view.create_tween()
	view._playback.pause()
	view._queue_single_attack(_event(view, "hero", "enemy"))
	view._queue_single_attack(_event(view, "hero", BattleState.SUPPORT_ENEMY_ID))
	view._playback.custom_step(20.0)
	_check_idle(hero)
	_check_idle(enemy)
	_check_idle(extra)
	view._playback = view.create_tween()
	view._playback.pause()
	view._queue_single_attack(_event(view, "hero", "enemy"))
	view._playback.custom_step(view.clash_windup_seconds * 0.5)
	assert(hero.state == BattleFigureAnimator.WIND_UP)
	view._cancel_playback()
	assert(view._impact_layer == null and view._impact_animators.is_empty())
	assert(view._hero_portrait.modulate.a == 1.0 and view._enemy_portrait.modulate.a == 1.0)
	assert(not view._is_playing_back)
	view._create_impact_layer()
	var fresh: BattleFigureAnimator = view._impact_animators["hero"]
	_check_idle(fresh)
	view._playback = view.create_tween()
	view._playback.pause()
	view._queue_single_attack(_event(view, "hero", "enemy"))
	view._playback.custom_step(view.clash_windup_seconds * 0.5)
	view.queue_free()
	await process_frame
	_check_profile_overrides()
	await process_frame
	quit()


func _check_attack(view: BattleView, actor: BattleFigureAnimator, target: BattleFigureAnimator, event: Dictionary, hurt: bool) -> void:
	var original_texture: Texture2D = actor.figure.texture
	view._playback = view.create_tween()
	view._playback.pause()
	view._queue_single_attack(event)
	view._playback.custom_step(view.clash_windup_seconds * 0.5)
	assert(actor.state == BattleFigureAnimator.WIND_UP)
	assert(actor.figure.position != actor.home)
	assert(actor.figure.z_index > target.figure.z_index)
	_check_pose(actor)
	for index in range(100):
		if actor.state == BattleFigureAnimator.STRIKE:
			break
		view._playback.custom_step(0.01)
	assert(actor.state == BattleFigureAnimator.STRIKE)
	assert(target.state == (BattleFigureAnimator.HURT if hurt else BattleFigureAnimator.IDLE))
	_check_pose(actor)
	_check_pose(target)
	if target.profile != null and hurt:
		view._playback.custom_step(0.10)
		assert(target.figure.position != target.home)
	view._playback.custom_step(10.0)
	_check_idle(actor)
	_check_idle(target)
	assert(actor.figure.texture == original_texture)


func _check_pose(animator: BattleFigureAnimator) -> void:
	if animator.profile == null:
		assert(animator.figure.get_node_or_null("CombatPose") == null)
		return
	var sprite: TextureRect = animator.figure.get_node("CombatPose")
	if animator.current_pose == animator.profile.idle:
		assert(not sprite.visible and animator.figure.self_modulate.a == 1.0)
		return
	assert(sprite.visible and animator.figure.self_modulate.a == 0.0)
	assert(sprite.texture == animator.current_pose.texture)
	assert(sprite.flip_h == animator.figure.flip_h)
	var point: Vector2 = sprite.position + CombatVisualPose.point_offset(animator.current_pose.ground_anchor, sprite.size, sprite.flip_h)
	assert(point.is_equal_approx(animator.ground))
	assert(sprite.size.is_equal_approx(animator.current_pose.rendered_size(animator.reference_height)))


func _check_idle(animator: BattleFigureAnimator) -> void:
	assert(animator.state == BattleFigureAnimator.IDLE)
	assert(animator.figure.position.is_equal_approx(animator.home))
	assert(animator.figure.scale.is_equal_approx(Vector2.ONE))
	assert(animator.figure.z_index == 0)
	_check_pose(animator)


func _check_profile_overrides() -> void:
	var base: CombatVisualProfile = HeroCatalog.get_hero("volcha").combat_visual_profile
	var profile: CombatVisualProfile = base.duplicate() as CombatVisualProfile
	var special := CombatVisualPoseSet.new()
	special.strike = profile.wind_up
	profile.ability_poses = {"special": special}
	var figure := TextureRect.new()
	figure.texture = BattleFigureLayout.idle_texture(profile)
	figure.set_meta(&"combat_figure", true)
	figure.flip_h = true
	figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	figure.size = Vector2(300, 300)
	root.add_child(figure)
	var animator := BattleFigureAnimator.new(figure, profile)
	animator.set_pose(BattleFigureAnimator.STRIKE, "special")
	assert(animator.current_pose == special.strike)
	_check_pose(animator)
	animator.set_pose(BattleFigureAnimator.HURT, "special")
	assert(animator.current_pose == profile.hurt)
	_check_pose(animator)
	profile.hurt = null
	animator.set_pose(BattleFigureAnimator.HURT)
	assert(animator.current_pose == profile.idle)
	_check_pose(animator)
	animator.reset()
	_check_idle(animator)
	assert(base.hurt != null and base.ability_poses.is_empty())
	figure.queue_free()
