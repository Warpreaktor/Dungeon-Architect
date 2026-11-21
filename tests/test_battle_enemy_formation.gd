extends SceneTree


func _initialize() -> void:
	var portrait_size := Vector2(128.0, 148.0)
	var two_enemies: Dictionary = {
		"hero": portrait_size,
		"enemy": portrait_size,
		"enemy_support": portrait_size
	}
	var center := Vector2(700.0, 310.0)
	var scale: float = 1.5
	var horizontal_gap: float = 0.35
	var vertical_gap: float = 0.12
	var positions: Dictionary = BattleClashGeometry.formation_positions(center, two_enemies,
		scale, horizontal_gap, vertical_gap)
	assert(positions.size() == 3)
	assert(is_equal_approx((positions["enemy"] as Vector2).x, (positions["enemy_support"] as Vector2).x))
	assert((positions["hero"] as Vector2).x < (positions["enemy"] as Vector2).x)
	var hero_center_y: float = (positions["hero"] as Vector2).y + portrait_size.y * 0.5
	var top_center_y: float = (positions["enemy"] as Vector2).y + portrait_size.y * 0.5
	var bottom_center_y: float = (positions["enemy_support"] as Vector2).y + portrait_size.y * 0.5
	assert(top_center_y < hero_center_y and hero_center_y < bottom_center_y)
	assert(is_equal_approx(hero_center_y, (top_center_y + bottom_center_y) * 0.5))
	var top_visual_bottom: float = (positions["enemy"] as Vector2).y + portrait_size.y * (1.0 + scale) * 0.5
	var bottom_visual_top: float = (positions["enemy_support"] as Vector2).y - portrait_size.y * (scale - 1.0) * 0.5
	assert(bottom_visual_top > top_visual_bottom)
	var required_height: float = portrait_size.y * scale * (2.0 + vertical_gap)
	assert(is_equal_approx(BattleClashGeometry.fit_formation_scale(required_height, two_enemies, scale, vertical_gap), scale))
	var limited_scale: float = BattleClashGeometry.fit_formation_scale(required_height * 0.8, two_enemies, scale, vertical_gap)
	assert(limited_scale < scale)
	assert(limited_scale > 0.0)

	var top_attack: Dictionary = BattleClashGeometry.contact_positions(positions, two_enemies,
		{"enemy": "hero"}, 0.14, scale)
	var bottom_attack: Dictionary = BattleClashGeometry.contact_positions(positions, two_enemies,
		{"enemy_support": "hero"}, 0.14, scale)
	assert(is_equal_approx((top_attack["enemy"] as Vector2).y + portrait_size.y * 0.5, hero_center_y))
	assert(is_equal_approx((bottom_attack["enemy_support"] as Vector2).y + portrait_size.y * 0.5, hero_center_y))
	var mutual: Dictionary = BattleClashGeometry.contact_positions(positions, two_enemies,
		{"hero": "enemy_support", "enemy_support": "hero"}, 0.14, scale)
	var hero_at_impact: Vector2 = mutual["hero"]
	var support_at_impact: Vector2 = mutual["enemy_support"]
	assert(is_equal_approx(hero_at_impact.y, support_at_impact.y))
	var without_support: Dictionary = BattleClashGeometry.formation_positions(center,
		{"hero": portrait_size, "enemy": portrait_size}, scale, horizontal_gap, vertical_gap)
	assert(without_support.size() == 2)
	assert(is_equal_approx((without_support["hero"] as Vector2).y, (without_support["enemy"] as Vector2).y))

	var scene: PackedScene = load("res://scenes/battle_view.tscn")
	assert(scene != null)
	var view: Control = scene.instantiate() as Control
	assert(view != null)
	assert(view.get_node_or_null("OuterMargin/Main/Battlefield/EnemyParty/EnemyCard/EnemyMargin/EnemyStack/EnemyPortrait") != null)
	assert(view.get_node_or_null("OuterMargin/Main/Battlefield/EnemyParty/EnemyCard/EnemyMargin/EnemyStack/EnemyColumn/EnemyHealthMeter") != null)
	assert(view.get_node("OuterMargin/Main/Battlefield/EnemyParty") is HBoxContainer)
	assert(view.get_node("OuterMargin/Main/Battlefield/EnemyParty/EnemyCard/EnemyMargin/EnemyStack") is VBoxContainer)
	view.free()
	print("Equal enemy party formation passed")
	quit()
