extends SceneTree

const HERO_IDS: Array[String] = ["volcha", "petushan", "burolom", "luma"]
const ENEMY_IDS: Array[String] = ["skeleton", "hunter", "skeleton", "lobar"]


func _initialize() -> void:
	call_deferred("_run")


func _make_view(hero_ids: Array[String], enemy_ids: Array[String], dimensions: Vector2) -> BattleView:
	var heroes: Array[HeroState] = []
	for id in hero_ids:
		var hero := HeroState.new(HeroCatalog.get_hero(id))
		hero.agility = 100
		heroes.append(hero)
	var enemies: Array[MonsterDefinition] = []
	for id in enemy_ids:
		enemies.append(MonsterCatalog.get_monster(id))
	var combat: CombatSession = CombatSession.for_encounter(enemies, heroes[0], 1255, heroes)
	var view: BattleView = load("res://scenes/battle_view.tscn").instantiate() as BattleView
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	view.size = dimensions
	view.begin(combat, heroes[0])
	view._is_playing_back = true
	return view


func _run() -> void:
	for dimensions in [Vector2(1280, 800), Vector2(800, 600), Vector2(1600, 900)]:
		var view: BattleView = _make_view(["volcha"], ["skeleton"], dimensions)
		await process_frame
		await process_frame
		_check_figures(view)
		assert(view._hero_portrait.size.x > 160.0)
		_check_playback(view, "hero", "enemy")
		_check_playback(view, "enemy", "hero")
		view._create_impact_layer()
		view.size = Vector2(960, 640)
		await process_frame
		await process_frame
		assert(is_equal_approx(view._impact_layer.scale.x, view._impact_layer.scale.y))
		view._clear_impact_layer()
		_check_figures(view)
		view.queue_free()
		await process_frame
	for dimensions in [Vector2(1280, 800), Vector2(800, 600)]:
		var view: BattleView = _make_view(HERO_IDS, ENEMY_IDS, dimensions)
		await process_frame
		await process_frame
		_check_figures(view)
		assert(view._portrait_for_id("hero_2").texture == HeroCatalog.get_hero("petushan").portrait)
		assert(view._portrait_for_id(BattleState.SUPPORT_ENEMY_ID).texture == view._enemy_texture(MonsterCatalog.get_monster("hunter")))
		assert(view._portrait_for_id("enemy_3").has_meta(&"combat_figure"))
		assert(view._turn_frame_overlays["hero"].anchor_top > 0.9)
		assert(view._turn_frame_overlays["hero_2"].anchor_top == 0.0)
		_check_teams(view)
		view.queue_free()
		await process_frame
	for hero_count in range(1, 5):
		for enemy_count in range(1, 5):
			var view: BattleView = _make_view(HERO_IDS.slice(0, hero_count), ENEMY_IDS.slice(0, enemy_count), Vector2(720, 480))
			await process_frame
			await process_frame
			_check_figures(view)
			_check_teams(view)
			view.queue_free()
			await process_frame
	var legacy: BattleView = _make_view(["petushan"], ["hunter"], Vector2(1280, 800))
	await process_frame
	await process_frame
	assert(not legacy._has_combat_figures())
	assert(legacy._hero_portrait.texture == HeroCatalog.get_hero("petushan").portrait)
	assert(legacy._hero_portrait.size.x <= 160.0)
	assert(legacy._turn_frame_overlays["hero"].anchor_top == 0.0)
	var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
	hero.agility = 100
	legacy.begin(CombatSession.new(MonsterCatalog.get_monster("skeleton"), hero), hero)
	legacy._is_playing_back = true
	await process_frame
	await process_frame
	_check_figures(legacy)
	legacy.queue_free()
	await process_frame
	quit()


func _check_teams(view: BattleView) -> void:
	for ids in [view.current_battle_state().hero_ids(), view.current_battle_state().enemy_ids()]:
		var previous := Rect2()
		for id in ids:
			var portrait: TextureRect = view._portrait_for_id(id)
			assert(portrait.size.is_equal_approx(view._hero_portrait.size))
			assert(view.get_global_rect().grow(1.0).encloses(portrait.get_global_rect()))
			assert(not previous.intersects(portrait.get_global_rect()))
			previous = portrait.get_global_rect()


func _check_figures(view: BattleView) -> void:
	var hero_profile: CombatVisualProfile = HeroCatalog.get_hero("volcha").combat_visual_profile
	var enemy_profile: CombatVisualProfile = MonsterCatalog.get_monster("skeleton").combat_visual_profile
	var ground: Array[Vector2] = []
	for pair in [[view._hero_portrait, hero_profile], [view._enemy_portrait, enemy_profile]]:
		var portrait: TextureRect = pair[0]
		var profile: CombatVisualProfile = pair[1]
		var texture: AtlasTexture = portrait.texture as AtlasTexture
		assert(texture != null and texture.atlas == profile.idle.texture)
		assert(not portrait.flip_h)
		var rect: Rect2 = BattleFigureLayout.visual_rect(portrait)
		assert(Rect2(Vector2.ZERO, portrait.size).grow(1.0).encloses(rect))
		ground.append(portrait.global_position + rect.position + CombatVisualPose.point_offset(profile.idle.ground_anchor, rect.size, portrait.flip_h))
		assert(view._battlefield.get_global_rect().grow(1.0).encloses(portrait.get_global_rect()))
		assert(view.get_global_rect().grow(1.0).encloses(portrait.get_global_rect()))
	assert(absf(ground[0].y - ground[1].y) <= 1.0)
	assert(ground[0].x < ground[1].x)
	assert(not view._hero_portrait.get_global_rect().intersects(view._enemy_portrait.get_global_rect()))


func _check_playback(view: BattleView, actor_id: String, target_id: String) -> void:
	var state: BattleState = view.current_battle_state()
	var rng_state: int = state.rng.state
	var events: int = state.events.size()
	var target_actor: BattleParticipant = state.get_participant(target_id)
	var health: int = target_actor.health
	var hud_rect: Rect2 = view._enemy_health_meter.get_global_rect()
	var hero_hud_rect: Rect2 = view._hero_health_meter.get_global_rect()
	var chain_rect: Rect2 = view._sequence_slots.get_global_rect()
	view._create_impact_layer()
	var attacker: TextureRect = view._impact_portraits[actor_id]
	var target: TextureRect = view._impact_portraits[target_id]
	assert(attacker.texture == view._portrait_for_id(actor_id).texture)
	assert(attacker.global_position.is_equal_approx(view._portrait_for_id(actor_id).global_position))
	assert(target.global_position.is_equal_approx(view._portrait_for_id(target_id).global_position))
	var origin: Vector2 = attacker.position
	view._playback = view.create_tween()
	view._playback.pause()
	view._queue_single_attack({"type": "attack", "actor_id": actor_id, "target_id": target_id, "ability_id": "basic_strike", "damage": 1, "hp_after": health - 1, "hp_max": target_actor.max_health})
	view._playback.custom_step(view.clash_windup_seconds + 0.01)
	assert(attacker.z_index > target.z_index and target.z_index > 0)
	assert(not attacker.position.is_equal_approx(origin))
	assert(view._enemy_health_meter.get_global_rect() == hud_rect)
	assert(view._hero_health_meter.get_global_rect() == hero_hud_rect)
	assert(view._sequence_slots.get_global_rect() == chain_rect)
	view._playback.custom_step(10.0)
	assert(attacker.position.is_equal_approx(origin))
	assert(attacker.z_index == 0 and target.z_index == 0)
	assert(state.rng.state == rng_state and state.events.size() == events and target_actor.health == health)
	view._clear_impact_layer()
	assert(view._hero_portrait.modulate.a == 1.0)
