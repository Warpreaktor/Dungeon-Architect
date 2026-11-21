extends SceneTree


func _initialize() -> void:
	var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
	var enemy: MonsterDefinition = MonsterCatalog.get_monster("skeleton")
	var battle := BattleState.begin(enemy, hero, 2224)
	assert(battle.add_support_enemy(enemy) != null)
	var chain: Array[String] = ["volcha_wolf_instinct", "volcha_wolf_instinct", "volcha_wolf_instinct"]
	var result: Dictionary = battle.run_phase(chain, battle.get_enemy().action_chain)
	assert(bool(result.get("success", false)))
	var events: Array = result["events"]
	var opponents: Array[String] = []
	for event in events:
		if str(event.get("type", "")) == "tick":
			opponents.append(str(event.get("opponent_id", "")))
	assert(opponents.size() >= 2)
	assert(opponents[0] == battle.enemy_id)
	assert(opponents[1] == battle.support_enemy_id)
	var steps: Array[Dictionary] = BattlePlaybackTimeline.split_events(events)
	assert(not steps.is_empty())
	var restored: Array[Dictionary] = []
	for step in steps:
		restored.append_array(step["events"])
	assert(restored == events)
	var main: BattleParticipant = battle.get_enemy()
	var support: BattleParticipant = battle.get_participant(battle.support_enemy_id)
	main.health = 0
	battle.update_outcome()
	assert(not battle.is_victory)
	assert(support.is_targetable)
	assert(battle.create_context().target_ids("hero", AbilityCatalog.get_ability("basic_strike")) == [battle.support_enemy_id])
	support.health = 0
	battle.update_outcome()
	assert(battle.is_victory)
	quit()
