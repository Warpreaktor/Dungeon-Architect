extends SceneTree


func _initialize() -> void:
	var minimum: float = BattleView.MIN_CHAIN_SLOT_SIDE
	var maximum: float = BattleView.MAX_CHAIN_SLOT_SIDE
	var gap: float = minimum / 8.0
	var count: int = 3
	var roomy_width: float = maximum * float(count) + gap * float(count - 1)
	assert(is_equal_approx(BattleAbilitySlot.side_for_width(roomy_width, count, gap, minimum, maximum), maximum))
	var compact_width: float = minimum * float(count) + gap * float(count - 1)
	assert(is_equal_approx(BattleAbilitySlot.side_for_width(compact_width, count, gap, minimum, maximum), minimum))
	var extended_count: int = count + 5
	var extended_width: float = compact_width
	assert(is_equal_approx(BattleAbilitySlot.side_for_width(extended_width, extended_count, gap, minimum, maximum), minimum))
	assert(BattleAbilitySlot.side_for_width(roomy_width, extended_count, gap, minimum, maximum) < maximum)
	quit()
