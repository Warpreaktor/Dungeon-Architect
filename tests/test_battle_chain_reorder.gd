extends SceneTree


func _initialize() -> void:
	var cards: Array[String] = ["first", "second", "third"]
	var result: Array[String] = BattleChainReorderController.swapped(cards, 0, cards.size() - 1)
	assert(result.front() == cards.back())
	assert(result.back() == cards.front())
	assert(result.size() == cards.size())
	assert(cards.front() == "first")
	assert(BattleChainReorderController.swapped(cards, -1, 1) == cards)
	assert(BattleChainReorderController.swapped(cards, 0, cards.size()) == cards)
	var width: float = float(cards.size() * cards.size())
	var gap: float = width / float(cards.size())
	var threshold: float = width * BattleChainReorderController.DRAG_START_FRACTION
	assert(BattleChainReorderController.target_for_displacement(1, cards.size(), threshold * 0.5, width, gap) == 1)
	assert(BattleChainReorderController.target_for_displacement(1, cards.size(), width + gap, width, gap) == 2)
	assert(BattleChainReorderController.target_for_displacement(1, cards.size(), -(width + gap), width, gap) == 0)
	assert(BattleChainReorderController.target_for_displacement(0, cards.size(), -(width + gap), width, gap) == 0)
	quit()
