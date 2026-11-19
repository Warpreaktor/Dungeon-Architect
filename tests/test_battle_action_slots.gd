extends SceneTree

## Лимит слотов задаётся бойцом, сохранённые шаблоны независимы.
func _initialize() -> void:
	var wolf := HeroState.new(HeroCatalog.get_hero("volcha"))
	var rooster := HeroState.new(HeroCatalog.get_hero("petushan"))
	var monster := MonsterCatalog.get_monster("hunter")
	assert(wolf.action_slot_capacity() == 3)
	assert(rooster.action_slot_capacity() == 3)
	var battle := BattleState.begin(monster, wolf)
	assert(battle.get_enemy().action_slot_capacity == 3)
	assert(battle.get_hero().action_slot_capacity == 3)
	assert(BattleChainPlanner.validate(["volcha_strike_and_rebound", "volcha_wolf_instinct", "volcha_wolf_lunge"], battle.get_hero()).is_empty())
	assert(not BattleChainPlanner.validate(["volcha_wolf_instinct", "volcha_wolf_instinct", "volcha_wolf_instinct", "volcha_wolf_instinct"], battle.get_hero()).is_empty())
	assert(not BattleChainPlanner.validate(["hunter_shot", "hunter_shot", "hunter_shot", "hunter_shot"], battle.get_enemy()).is_empty())
	var saved: Array[String] = ["volcha_wolf_lunge", "", "volcha_strike_and_rebound"]
	assert(wolf.save_action_slots(saved))
	saved[0] = "volcha_wolf_instinct"
	assert(wolf.get_saved_action_slots() == ["volcha_wolf_lunge", "", "volcha_strike_and_rebound"])
	var received: Array[String] = wolf.get_saved_action_slots()
	received[0] = "volcha_wolf_instinct"
	assert(wolf.get_saved_action_slots()[0] == "volcha_wolf_lunge")
	assert(rooster.get_saved_action_slots() == ["", "", ""])
	var copy: HeroState = wolf.copy_for_battle()
	assert(copy.get_saved_action_slots() == wolf.get_saved_action_slots())
	assert(copy.save_action_slots(["volcha_wolf_instinct", "", ""]))
	assert(wolf.get_saved_action_slots()[0] == "volcha_wolf_lunge")
	# Никаких хардкодов «только 3» в планировщике: будущий предмет даст +2.
	wolf.bonus_action_slots = 2
	assert(wolf.action_slot_capacity() == 5)
	var expanded := BattleState.begin(monster, wolf)
	assert(expanded.get_hero().action_slot_capacity == 5)
	assert(BattleChainPlanner.validate(["volcha_wolf_instinct", "volcha_wolf_instinct", "volcha_wolf_instinct", "volcha_wolf_instinct", "volcha_wolf_instinct"], expanded.get_hero()).is_empty())
	assert(wolf.get_saved_action_slots() == ["volcha_wolf_lunge", "", "volcha_strike_and_rebound", "", ""])
	assert(not wolf.save_action_slots(["volcha_wolf_instinct"]))
	quit()
