extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for viewport_size in [Vector2(1280, 800), Vector2(720, 480)]:
		var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
		var companion := HeroState.new(HeroCatalog.get_hero("petushan"))
		var monsters: Array[MonsterDefinition] = [MonsterCatalog.get_monster("skeleton"), MonsterCatalog.get_monster("skeleton")]
		var view: BattleView = load("res://scenes/battle_view.tscn").instantiate()
		root.add_child(view)
		view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		view.size = viewport_size
		view.begin(CombatSession.for_encounter(monsters, hero, 125, [hero, companion]), hero)
		view._is_playing_back = true
		await process_frame
		await process_frame
		view._create_impact_layer()
		var varg: BattleFigureAnimator = view._impact_animators["hero"]
		var skeleton: BattleFigureAnimator = view._impact_animators["enemy"]
		var other: BattleFigureAnimator = view._impact_animators[BattleState.SUPPORT_ENEMY_ID]
		var legacy: BattleFigureAnimator = view._impact_animators["hero_2"]
		var config: BattleMeleeChoreography = view.melee_choreography
		var state: BattleState = view.current_battle_state()
		var before: Array = [state.rng.state, state.events.duplicate(true), state.get_hero().health, state.get_enemy().health]
		var hud: Rect2 = view._sequence_slots.get_global_rect()
		_check_contact(view, varg, skeleton, config, {"hp_damage": 1}, 0.005)
		_check_contact(view, skeleton, varg, config, {"hp_damage": 1}, 0.037)
		_check_contact(view, varg, other, config, {"hp_damage": 1}, 0.01)
		_check_contact(view, skeleton, legacy, config, {"hp_damage": 1}, 0.01)
		_check_contact(view, varg, skeleton, config, {"hp_damage": 0, "dodged": true}, 0.025)
		_check_contact(view, skeleton, varg, config, {"hp_damage": 0, "block_absorbed": 2}, 0.015)
		var custom: BattleMeleeChoreography = config.duplicate() as BattleMeleeChoreography
		custom.windup_seconds = 0.06
		custom.strike_scale = 1.11
		custom.approach_seconds = 0.05
		custom.max_approach_seconds = 0.09
		_check_contact(view, varg, skeleton, custom, {"hp_damage": 1}, 0.001)
		_check_integration(view, varg, skeleton, custom)
		assert(state.rng.state == before[0] and state.events == before[1])
		assert(state.get_hero().health == before[2] and state.get_enemy().health == before[3])
		assert(view._sequence_slots.get_global_rect() == hud)
		view._cancel_playback()
		assert(view._impact_layer == null and view._impact_animators.is_empty())
		view.queue_free()
		await process_frame
	_check_mirrored()
	await process_frame
	print("Melee choreography contact and timing passed")
	quit()


func _visible_point(animator: BattleFigureAnimator, pose: CombatVisualPose, point: Vector2) -> Vector2:
	if animator.profile == null:
		return animator.figure.get_transform() * (animator.figure.size * point)
	var local: Vector2
	if pose == animator.profile.idle:
		var rect: Rect2 = BattleFigureLayout.visual_rect(animator.figure)
		local = rect.position + CombatVisualPose.point_offset(point, rect.size, animator.figure.flip_h)
	else:
		var sprite: TextureRect = animator.figure.get_node("CombatPose")
		assert(sprite.visible and sprite.texture == pose.texture)
		local = sprite.get_transform() * CombatVisualPose.point_offset(point, sprite.size, sprite.flip_h)
	return animator.figure.get_transform() * local


func _check_contact(view: BattleView, actor: BattleFigureAnimator, target: BattleFigureAnimator,
		config: BattleMeleeChoreography, event: Dictionary, step: float) -> void:
	var impacts: Array[Vector2] = []
	var direction: float = signf(target.home.x - actor.home.x)
	var expected_windup: Vector2 = actor.home - Vector2(direction * actor.reference_height * config.windup_fraction, 0.0)
	var strike: CombatVisualPose = actor.profile.resolve_pose(BattleFigureAnimator.STRIKE, str(event.get("ability_id", "")))
	assert(strike.has_contact_anchor())
	var tween: Tween = view.create_tween()
	tween.pause()
	assert(actor.queue_melee(tween, target, event, config, func() -> void:
		assert(actor.state == BattleFigureAnimator.STRIKE)
		var hurt: bool = BattleFigureAnimator.receives_hurt(event)
		assert(target.state == (BattleFigureAnimator.HURT if hurt else BattleFigureAnimator.IDLE))
		var weapon: Vector2 = _visible_point(actor, strike, strike.contact_anchor)
		var point: Vector2 = _visible_point(target, target.current_pose, target.current_pose.hit_anchor if target.profile != null else Vector2(0.5, 0.5))
		impacts.append(point - weapon)))
	tween.custom_step(config.windup_seconds * 0.5)
	assert(actor.state == BattleFigureAnimator.WIND_UP and impacts.is_empty())
	assert((actor.figure.position.x - actor.home.x) * direction < 0.0)
	tween.custom_step(config.windup_seconds * 0.5)
	assert(actor.figure.position.distance_to(expected_windup) < 0.1)
	var destination: Vector2 = actor.melee_contact(target, event, config)
	var duration: float = config.approach_duration(expected_windup.distance_to(destination), actor.reference_height)
	tween.custom_step(duration * 0.5)
	assert(actor.state == BattleFigureAnimator.WIND_UP and impacts.is_empty())
	assert(actor.figure.position.distance_to(expected_windup) < expected_windup.distance_to(destination) * 0.25)
	for index in range(1000):
		if not impacts.is_empty():
			break
		tween.custom_step(step)
	assert(impacts.size() == 1)
	var expected_gap: Vector2 = Vector2(direction * actor.reference_height * config.dodge_gap_fraction, 0.0) if bool(event.get("dodged", false)) else Vector2.ZERO
	assert(impacts[0].distance_to(expected_gap) < 0.1)
	tween.custom_step(10.0)
	assert(impacts.size() == 1)
	assert(actor.state == BattleFigureAnimator.IDLE and target.state == BattleFigureAnimator.IDLE)
	assert(actor.figure.position.is_equal_approx(actor.home) and target.figure.position.is_equal_approx(target.home))
	assert(actor.figure.scale.is_equal_approx(Vector2.ONE) and target.figure.scale.is_equal_approx(Vector2.ONE))
	assert(actor.figure.z_index == 0 and target.figure.z_index == 0)


func _check_integration(view: BattleView, actor: BattleFigureAnimator, target: BattleFigureAnimator, config: BattleMeleeChoreography) -> void:
	var ability: AbilityDefinition = AbilityCatalog.get_ability("basic_strike")
	var original: BattleMeleeChoreography = ability.melee_choreography
	ability.melee_choreography = config
	var event: Dictionary = {"type": "attack", "actor_id": "hero", "target_id": "enemy", "ability_id": "basic_strike", "damage": 1, "hp_damage": 1}
	view._playback = view.create_tween()
	view._playback.pause()
	view._queue_single_attack(event)
	view._playback.custom_step(config.windup_seconds + config.max_approach_seconds + 0.001)
	assert(actor.state == BattleFigureAnimator.STRIKE and target.state == BattleFigureAnimator.HURT)
	assert(actor.figure.scale.is_equal_approx(Vector2.ONE * config.strike_scale))
	view._playback.custom_step(10.0)
	ability.melee_choreography = original
	var ranged_event: Dictionary = event.duplicate()
	ranged_event["ability_id"] = "hunter_shot"
	view._playback = view.create_tween()
	view._playback.pause()
	view._queue_single_attack(ranged_event)
	view._playback.custom_step(config.windup_seconds + config.max_approach_seconds + 0.001)
	assert(actor.state == BattleFigureAnimator.WIND_UP)
	view._playback.custom_step(10.0)
	assert(actor.state == BattleFigureAnimator.IDLE)


func _check_mirrored() -> void:
	var profile: CombatVisualProfile = HeroCatalog.get_hero("volcha").combat_visual_profile
	var figure := TextureRect.new()
	figure.texture = BattleFigureLayout.idle_texture(profile)
	figure.set_meta(&"combat_figure", true)
	figure.flip_h = true
	figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	figure.size = Vector2(300, 300)
	figure.position = Vector2(500, 40)
	root.add_child(figure)
	var animator := BattleFigureAnimator.new(figure, profile)
	var strike: CombatVisualPose = profile.strike
	animator.set_pose(BattleFigureAnimator.STRIKE)
	assert(animator.pose_point_at_home(strike, strike.contact_anchor).distance_to(_visible_point(animator, strike, strike.contact_anchor)) < 0.1)
	assert(animator.pose_point_at_home(strike, strike.contact_anchor).x < animator.home.x + animator.ground.x)
	figure.queue_free()
