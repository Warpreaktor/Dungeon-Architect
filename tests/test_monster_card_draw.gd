extends SceneTree

## Гарантированная карта, случайный добор, фиксированный порядок и курсоры.
func _initialize() -> void:
	var monster := MonsterDefinition.new()
	monster.monster_id = "test_deck"
	monster.display_name = "Тестовый противник"
	monster.max_health = 999
	monster.base_action_slots = 2
	monster.personal_ability_ids = ["basic_strike", "guard", "crab_pincer", "lobar_charge"]
	monster.guaranteed_card_ids = ["basic_strike"]
	monster.random_card_count = 1
	var participant: BattleParticipant = BattleParticipant.from_monster(monster)
	var rng := RandomNumberGenerator.new()
	var observed: Dictionary = {}
	for seed_value in range(24):
		rng.seed = seed_value
		var selected: Array[String] = MonsterCardDraw.draw(monster, participant, rng)
		assert(selected.size() == 2)
		assert(selected[0] == "basic_strike")
		assert(selected[1] in ["guard", "crab_pincer", "lobar_charge"])
		observed[selected[1]] = true
	assert(observed.size() > 1)
	monster.random_card_count = 0
	assert(MonsterCardDraw.draw(monster, participant, rng) == ["basic_strike"])
	monster.random_card_count = 1
	var combat := BattleState.begin(monster, HeroState.new(HeroCatalog.get_hero("volcha")))
	var deck: Array[String] = combat.default_chain("enemy")
	assert(deck.size() == 2 and deck[0] == "basic_strike")
	var hero_chain: Array[String] = ["volcha_wolf_lunge", "volcha_strike_and_rebound", "volcha_wolf_instinct"]
	var result: Dictionary = BattlePhaseTestDriver.run_phase(combat, hero_chain, ["guard"])
	assert(result.success)
	assert(combat.get_enemy().action_chain == deck)
	assert(combat.get_hero().action_cursor == 0)
	assert(combat.get_enemy().action_cursor >= 0)
	assert(combat.get_enemy().action_cursor <= deck.size())
	var second_phase: Dictionary = BattlePhaseTestDriver.run_phase(combat, hero_chain, ["lobar_charge"])
	assert(second_phase.success)
	assert(combat.get_enemy().action_chain == deck)
	assert(combat.get_hero().action_cursor == 0)
	quit()
