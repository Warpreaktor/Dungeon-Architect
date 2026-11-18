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
	assert(BattleChainPlanner.validate(["basic_strike", "guard", "wolf_feint"], battle.get_hero()).is_empty())
	assert(not BattleChainPlanner.validate(["guard", "guard", "guard", "guard"], battle.get_hero()).is_empty())
	assert(not BattleChainPlanner.validate(["hunter_shot", "hunter_shot", "hunter_shot", "hunter_shot"], battle.get_enemy()).is_empty())
	var saved: Array[String] = ["wolf_feint", "", "basic_strike"]
	assert(wolf.save_action_slots(saved))
	saved[0] = "guard"
	assert(wolf.get_saved_action_slots() == ["wolf_feint", "", "basic_strike"])
	var received: Array[String] = wolf.get_saved_action_slots()
	received[0] = "guard"
	assert(wolf.get_saved_action_slots()[0] == "wolf_feint")
	assert(rooster.get_saved_action_slots() == ["", "", ""])
	var copy: HeroState = wolf.copy_for_battle()
	assert(copy.get_saved_action_slots() == wolf.get_saved_action_slots())
	assert(copy.save_action_slots(["guard", "", ""]))
	assert(wolf.get_saved_action_slots()[0] == "wolf_feint")
	# Никаких хардкодов «только 3» в планировщике: будущий предмет даст +2.
	wolf.bonus_action_slots = 2
	assert(wolf.action_slot_capacity() == 5)
	var expanded := BattleState.begin(monster, wolf)
	assert(expanded.get_hero().action_slot_capacity == 5)
	assert(BattleChainPlanner.validate(["guard", "guard", "guard", "guard", "guard"], expanded.get_hero()).is_empty())
	assert(wolf.get_saved_action_slots() == ["wolf_feint", "", "basic_strike", "", ""])
	assert(not wolf.save_action_slots(["guard"]))
	quit()
