extends SceneTree

## DA-4.07: детерминированные такты, блок, перезарядка, накопление бонуса.
func _fighter(id: String, team: String, hp: int, power: int) -> BattleParticipant:
	var participant := BattleParticipant.new()
	participant.participant_id = id
	participant.team_id = team
	participant.max_health = hp
	participant.health = hp
	## basic_strike даёт +1, остальное зависит от Силы, не от скрытой атаки.
	participant.strength = maxi(power - 1, 0) * 2
	participant.defense = 0
	participant.personal_ability_ids = ["basic_strike", "guard"]
	return participant


func _battle(hero_hp: int = 100, enemy_hp: int = 100, power: int = 10) -> BattleState:
	var state := BattleState.new()
	state.participants["hero"] = _fighter("hero", "heroes", hero_hp, power)
	state.participants["enemy"] = _fighter("enemy", "enemies", enemy_hp, power)
	return state


func _initialize() -> void:
	var battle: BattleState = _battle()
	var hero_chain: Array[String] = ["basic_strike", "guard", "basic_strike"]
	var enemy_chain: Array[String] = ["guard", "basic_strike"]
	assert(battle.tick_policy.priority("volcha_wolf_lunge") == battle.tick_policy.other_priority)
	var result: Dictionary = battle.run_phase(hero_chain, enemy_chain)
	assert(result.success and result.ticks == 4)
	var decisions: Array[String] = []
	for event in battle.last_phase_events:
		if event.type in ["block", "attack", "reload"]:
			decisions.append(str(event.actor_id) + ":" + str(event.type))
	assert(decisions == ["enemy:block", "hero:attack", "hero:block", "enemy:attack", "hero:attack", "enemy:reload", "enemy:block", "hero:reload"])
	var next: Dictionary = battle.run_phase(hero_chain, enemy_chain)
	assert(next.success and next.ticks == 4) # каждый круг заканчивается отдыхом
	assert(not battle.last_phase_events[0].hero_reload)
	assert(battle.last_phase_events[-1].type == "reload" and battle.last_phase_events[-1].actor_id == "hero")
	assert(battle.last_phase_events[0].enemy_slot == 1)

	# При равном приоритете два блока ставятся в порядке герой -> монстр.
	var both_guard: BattleState = _battle()
	assert(both_guard.run_phase(["guard", "guard", "guard"], ["guard"]).success)
	var first_two: Array[String] = []
	for event in both_guard.last_phase_events:
		if event.type == "block" and first_two.size() < 2:
			first_two.append(str(event.actor_id))
	assert(first_two == ["hero", "enemy"])

	# Герой убивает монстра первым ударом: у монстра нет ответа.
	var lethal: BattleState = _battle(100, 1, 10)
	assert(lethal.run_phase(["basic_strike", "guard", "basic_strike"], ["basic_strike"]).success)
	assert(lethal.is_victory and not lethal.is_defeat and lethal.flow.completed_ticks == 1 + BattleChainPlanner.REST_TICKS)
	var enemy_attacks: int = 0
	for event in lethal.last_phase_events:
		if event.type == "attack" and event.actor_id == "enemy":
			enemy_attacks += 1
	assert(enemy_attacks == 0)

	# Процент накапливается от БАЗЫ, без округления дроби вверх.
	var arithmetic: BattleState = _battle(100, 100, 10)
	var fighter: BattleParticipant = arithmetic.get_hero()
	assert(arithmetic.execute_ability("hero", "hero", "guard").success)
	assert(fighter.block_attack_bonus_percent == 25)
	arithmetic.end_phase()
	assert(fighter.block_attack_bonus_percent == 25)
	var hit: Dictionary = arithmetic.execute_ability("hero", "enemy", "basic_strike")
	assert(hit.success and hit.events[0].damage == 12) # 10 * 1.25 = 12.5 -> 12
	assert(fighter.block_attack_bonus_percent == 0)
	assert(arithmetic.execute_ability("hero", "hero", "guard").success)
	assert(arithmetic.execute_ability("hero", "hero", "guard").success)
	assert(fighter.block_attack_bonus_percent == 50)
	arithmetic.end_phase()
	hit = arithmetic.execute_ability("hero", "enemy", "basic_strike")
	assert(hit.success and hit.events[0].damage == 15) # 10 * 1.5
	assert(fighter.block_attack_bonus_percent == 0)

	# Перезарядки существуют у обоих и не запускают никакого приёма.
	var rests: BattleState = _battle(200, 200, 1)
	for i in range(4):
		assert(rests.run_phase(["guard", "guard", "guard"], ["guard", "guard"]).success)
	var both_reloading: bool = false
	for event in rests.events:
		if event.type == "tick" and event.hero_reload and event.enemy_reload:
			both_reloading = true
	assert(both_reloading)
	quit()
