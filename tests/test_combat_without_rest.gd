extends SceneTree


func _initialize() -> void:
	assert(AbilityCatalog.get_ability("rest") == null)
	assert(not ResourceLoader.exists("res://assets/abilities/rest.png"))
	var battle := BattleState.new()
	var hero := BattleParticipant.new()
	hero.participant_id = "hero"
	hero.team_id = "heroes"
	hero.health = 100
	hero.max_health = 100
	hero.agility = 100
	hero.personal_ability_ids = ["guard"]
	hero.action_chain = ["guard"]
	hero.resource_amounts = {"energy": 0}
	var enemy := BattleParticipant.new()
	enemy.participant_id = "enemy"
	enemy.team_id = "enemies"
	enemy.health = 100
	enemy.max_health = 100
	enemy.agility = 1
	enemy.strength = 4
	enemy.personal_ability_ids = ["guard", "basic_strike"]
	enemy.action_chain = ["guard"]
	enemy.resource_amounts = {"energy": 0}
	battle.participants = {"hero": hero, "enemy": enemy}
	assert(battle.start_round_combat().success)
	assert(battle.prepare_next_round() == "hero")
	assert(not battle.run_round_turn("", "rest").success)
	var skipped: Dictionary = battle.run_round_turn()
	assert(skipped.success)
	var found_skip: bool = false
	for event in skipped.events:
		if event.type == "turn_skipped":
			found_skip = true
	assert(found_skip and hero.current_energy() == 0)
	var enemy_turn: Dictionary = battle.run_round_turn()
	assert(enemy_turn.success)
	var found_attack: bool = false
	for event in enemy_turn.events:
		if event.type == "action_start" and event.ability_id == "basic_strike":
			found_attack = true
	assert(found_attack and enemy.current_energy() == 0)
	var saved: Dictionary = HeroState.new(HeroCatalog.get_hero("volcha")).to_snapshot()
	saved["learned_ability_ids"] = ["rest"]
	saved["saved_action_slots"] = ["rest", "", ""]
	var restored: HeroState = HeroState.from_snapshot(saved)
	assert(restored != null)
	assert(not restored.learned_ability_ids.has("rest"))
	assert(not restored.get_saved_action_slots().has("rest"))
	quit()
