extends SceneTree


func _initialize() -> void:
	var portrait_size := Vector2(128.0, 148.0)
	var two_enemies: Dictionary = {
		"hero": portrait_size,
		"enemy": portrait_size,
		"enemy_support": portrait_size
	}
	var positions: Dictionary = {
		"hero": Vector2(240, 250), "enemy": Vector2(720, 250),
		"enemy_support": Vector2(870, 250)
	}
	var original: Dictionary = positions.duplicate()
	for attacker in ["enemy", "enemy_support"]:
		var contacts: Dictionary = BattleClashGeometry.contact_positions(positions, two_enemies,
			{attacker: "hero"}, 0.14)
		assert(contacts.size() == 1 and contacts.has(attacker))
		assert(is_equal_approx((contacts[attacker] as Vector2).y, (positions["hero"] as Vector2).y))
		assert((contacts[attacker] as Vector2).x < (positions[attacker] as Vector2).x)
		assert(positions == original)

	var scene: PackedScene = load("res://scenes/battle_view.tscn")
	assert(scene != null)
	var view: Control = scene.instantiate() as Control
	assert(view != null)
	assert(view.get_node_or_null("OuterMargin/Main/Battlefield/EnemySide/EnemyParty/EnemyCard/EnemyMargin/EnemyStack/EnemyPortrait") != null)
	assert(view.get_node_or_null("OuterMargin/Main/Battlefield/EnemySide/EnemyParty/EnemyCard/EnemyMargin/EnemyStack/EnemyColumn/EnemyHealthMeter") != null)
	assert(view.get_node("OuterMargin/Main/Battlefield/EnemySide/EnemyParty") is HBoxContainer)
	assert(view.get_node("OuterMargin/Main/Battlefield/EnemySide/EnemyParty/EnemyCard/EnemyMargin/EnemyStack") is VBoxContainer)
	view.free()
	print("Independent enemy approach geometry passed")
	quit()
