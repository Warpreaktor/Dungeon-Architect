extends SceneTree

## Формат журнала и снимки HP проверяем без боевого экрана.
func _initialize() -> void:
	var hit: Dictionary = {"type": "attack", "actor_id": "hero", "target_id": "enemy",
		"ability_id": "basic_strike", "damage": 4, "hp_after": 16, "hp_max": 20,
		"block_absorbed": 3, "armor_after": 0, "shield_durability_after": 2,
		"shield_broken": ""}
	var hero_name: String = HeroCatalog.get_hero("volcha").display_name
	var line: String = BattleCombatLog.format_event(hit, hero_name, "Кадавр")
	assert(line.contains("%s → Кадавр" % hero_name))
	assert(line.contains("HP −4 (16/20)"))
	assert(line.contains("блок −3"))
	assert(line.contains("прочность щита 2"))
	assert(BattleCombatLog.format_event({"type": "tick", "tick": 5}, "A", "B") == "  Такт 5")
	assert(BattleCombatLog.format_event({"type": "reload", "actor_id": "hero"}, hero_name, "Б") == "    %s: Отдых" % hero_name)
	assert(BattleCombatLog.format_event({"type": "action_start"}, "A", "B").is_empty())

	# Важная регрессия: HP после каждого удара не равен HP в конце фазы.
	var battle := BattleState.new()
	var hero := BattleParticipant.new()
	hero.participant_id = "hero"
	hero.team_id = "heroes"
	hero.max_health = 50
	hero.health = 50
	hero.strength = 8
	hero.personal_ability_ids = ["basic_strike"]
	var enemy := BattleParticipant.new()
	enemy.participant_id = "enemy"
	enemy.team_id = "enemies"
	enemy.max_health = 50
	enemy.health = 50
	enemy.personal_ability_ids = ["basic_strike"]
	battle.participants = {"hero": hero, "enemy": enemy}
	var first: Dictionary = battle.execute_ability("hero", "enemy", "basic_strike")
	var second: Dictionary = battle.execute_ability("hero", "enemy", "basic_strike")
	assert(first.success and second.success)
	assert(first.events[0].hp_after > second.events[0].hp_after)
	assert(first.events[0].hp_max == 50)
	quit()
