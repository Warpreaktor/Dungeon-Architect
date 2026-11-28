extends SceneTree


func _initialize() -> void:
	var hero: HeroDefinition = HeroCatalog.get_hero("volcha")
	var monster: MonsterDefinition = MonsterCatalog.get_monster("skeleton")
	assert(hero.portrait != null and monster.portrait != null)
	_check_profile(hero.combat_visual_profile, true)
	_check_profile(monster.combat_visual_profile, false)
	for hero_id in HeroCatalog.list_ids():
		var other: HeroDefinition = HeroCatalog.get_hero(hero_id)
		if other.combat_visual_profile == null:
			assert(CombatVisualProfile.texture_for(other.combat_visual_profile, other.portrait) == other.portrait)
	for monster_id in MonsterCatalog.list_ids():
		var other: MonsterDefinition = MonsterCatalog.get_monster(monster_id)
		if other.combat_visual_profile == null:
			var portrait: Texture2D = other.portrait if other.portrait != null else other.icon
			assert(CombatVisualProfile.texture_for(other.combat_visual_profile, portrait) == portrait)
	assert(HeroDefinition.new().combat_visual_profile == null)
	assert(MonsterDefinition.new().combat_visual_profile == null)
	assert(CombatVisualProfile.texture_for(null, hero.portrait, &"strike") == hero.portrait)
	_check_overrides(hero.combat_visual_profile)
	assert(CombatVisualProfile.texture_for(CombatVisualProfile.new(), hero.portrait, &"hurt") == hero.portrait)
	quit()


func _check_profile(profile: CombatVisualProfile, faces_right: bool) -> void:
	assert(profile != null and profile.faces_right == faces_right)
	assert(not profile.should_flip(faces_right) and profile.should_flip(not faces_right))
	for state in [&"idle", &"wind_up", &"strike", &"hurt"]:
		var pose: CombatVisualPose = profile.resolve_pose(state)
		assert(pose != null and pose.texture != null)
		assert(pose.texture.get_image().detect_alpha() != Image.ALPHA_NONE)
		assert(pose.texture.get_width() <= 1024 and pose.texture.get_height() <= 1024)
		assert(pose.embedded_slash == (state == &"strike"))
		var size: Vector2 = pose.rendered_size(400.0 * profile.display_scale)
		assert(size.x > 0.0 and size.y > 0.0)
		for point in [pose.ground_anchor, pose.hit_anchor, pose.effect_anchor]:
			assert(point.x >= 0.0 and point.x <= 1.0 and point.y >= 0.0 and point.y <= 1.0)
			var normal: Vector2 = CombatVisualPose.point_offset(point, size, false)
			var mirrored: Vector2 = CombatVisualPose.point_offset(point, size, true)
			assert(is_equal_approx(normal.x + mirrored.x, size.x) and is_equal_approx(normal.y, mirrored.y))
	assert(profile.resolve_pose(&"unknown") == profile.idle)


func _check_overrides(base: CombatVisualProfile) -> void:
	var profile: CombatVisualProfile = base.duplicate() as CombatVisualProfile
	var special := CombatVisualPoseSet.new()
	var strike := CombatVisualPose.new()
	strike.texture = profile.wind_up.texture
	special.strike = strike
	special.hurt = CombatVisualPose.new()
	profile.ability_poses = {"special": special}
	assert(profile.resolve_pose(&"strike", "special") == strike)
	assert(profile.resolve_pose(&"wind_up", "special") == profile.wind_up)
	assert(profile.resolve_pose(&"hurt", "special") == profile.hurt)
	assert(profile.resolve_pose(&"strike", "unknown") == profile.strike)
	assert(base.ability_poses.is_empty())
	var path: String = "user://combat_visual_profile_test_%d.tres" % OS.get_process_id()
	assert(ResourceSaver.save(profile, path) == OK)
	var restored: CombatVisualProfile = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CombatVisualProfile
	assert(restored != null)
	assert(restored.resolve_pose(&"strike", "special").texture == profile.wind_up.texture)
	assert(restored.resolve_pose(&"hurt", "special").texture == profile.hurt.texture)
	assert(DirAccess.remove_absolute(path) == OK)
	profile.strike = null
	assert(profile.resolve_pose(&"strike") == profile.idle)
