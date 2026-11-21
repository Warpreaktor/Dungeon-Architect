extends SceneTree


func _initialize() -> void:
	var idle: Dictionary = {
		"hero": Vector2(160.0, 80.0),
		"enemy": Vector2(650.0, 120.0),
		"enemy_support": Vector2(1050.0, 160.0)
	}
	var sizes: Dictionary = {
		"hero": Vector2(140.0, 180.0),
		"enemy": Vector2(160.0, 180.0),
		"enemy_support": Vector2(120.0, 130.0)
	}
	var overlap_fraction: float = 0.14
	var hero_width: float = (sizes["hero"] as Vector2).x
	var support_width: float = (sizes["enemy_support"] as Vector2).x
	var expected_overlap: float = minf(hero_width, support_width) * overlap_fraction

	var single: Dictionary = BattleClashGeometry.contact_positions(idle, sizes, {"enemy_support": "hero"}, overlap_fraction)
	assert(single.size() == 1)
	var single_destination: Vector2 = single["enemy_support"]
	assert(is_equal_approx(single_destination.x, (idle["hero"] as Vector2).x + hero_width - expected_overlap))
	var hero_center_y: float = (idle["hero"] as Vector2).y + (sizes["hero"] as Vector2).y * 0.5
	assert(is_equal_approx(single_destination.y + (sizes["enemy_support"] as Vector2).y * 0.5, hero_center_y))

	var mutual: Dictionary = BattleClashGeometry.contact_positions(idle, sizes,
		{"hero": "enemy_support", "enemy_support": "hero"}, overlap_fraction)
	assert(mutual.size() == 2)
	var hero_destination: Vector2 = mutual["hero"]
	var support_destination: Vector2 = mutual["enemy_support"]
	assert(is_equal_approx(hero_destination.x + hero_width - support_destination.x, expected_overlap))
	var contact_middle: float = ((idle["hero"] as Vector2).x + hero_width * 0.5
		+ (idle["enemy_support"] as Vector2).x + support_width * 0.5) * 0.5
	assert(is_equal_approx(hero_destination.x + hero_width - expected_overlap * 0.5, contact_middle))
	assert(is_equal_approx(support_destination.x + expected_overlap * 0.5, contact_middle))
	assert(is_equal_approx(hero_destination.y + (sizes["hero"] as Vector2).y * 0.5,
		support_destination.y + (sizes["enemy_support"] as Vector2).y * 0.5))

	var right_attacker: Dictionary = BattleClashGeometry.contact_positions(idle, sizes, {"enemy": "hero"}, overlap_fraction)
	var enemy_overlap: float = minf(hero_width, (sizes["enemy"] as Vector2).x) * overlap_fraction
	assert(is_equal_approx((right_attacker["enemy"] as Vector2).x, (idle["hero"] as Vector2).x + hero_width - enemy_overlap))
	assert(BattleClashGeometry.contact_positions(idle, sizes, {"unknown": "hero"}, overlap_fraction).is_empty())
	var scale_factor: float = 1.5
	var scaled: Dictionary = BattleClashGeometry.contact_positions(idle, sizes,
		{"hero": "enemy_support", "enemy_support": "hero"}, overlap_fraction, scale_factor)
	var scaled_hero: Vector2 = scaled["hero"]
	var scaled_support: Vector2 = scaled["enemy_support"]
	var scaled_hero_left: float = scaled_hero.x - hero_width * (scale_factor - 1.0) * 0.5
	var scaled_support_left: float = scaled_support.x - support_width * (scale_factor - 1.0) * 0.5
	var scaled_overlap: float = minf(hero_width, support_width) * scale_factor * overlap_fraction
	assert(is_equal_approx(scaled_hero_left + hero_width * scale_factor - scaled_support_left, scaled_overlap))

	var scaled_single: Dictionary = BattleClashGeometry.contact_positions(idle, sizes,
		{"enemy_support": "hero"}, overlap_fraction, scale_factor)
	var hero_visual_right: float = (idle["hero"] as Vector2).x + hero_width * (scale_factor + 1.0) * 0.5
	var scaled_single_left: float = (scaled_single["enemy_support"] as Vector2).x - support_width * (scale_factor - 1.0) * 0.5
	assert(is_equal_approx(hero_visual_right - scaled_single_left, scaled_overlap))

	var baseline_seconds: float = 0.13
	var short_move: Dictionary = {"enemy_support": (idle["enemy_support"] as Vector2) + Vector2(support_width * 0.5, 0.0)}
	var long_move: Dictionary = {"enemy_support": (idle["enemy_support"] as Vector2) - Vector2(support_width * 2.0, 0.0)}
	assert(is_equal_approx(BattleClashGeometry.approach_seconds(baseline_seconds, idle, short_move, sizes), baseline_seconds))
	assert(BattleClashGeometry.approach_seconds(baseline_seconds, idle, long_move, sizes) > baseline_seconds)

	print("Battle clash contact geometry passed")
	quit()
