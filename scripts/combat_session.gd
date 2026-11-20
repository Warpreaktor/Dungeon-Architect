class_name CombatSession
extends RefCounted

## Совместимый фасад существующего боя. Расчёт теперь выполняет BattleState;
## BattleView продолжает пользоваться прежними полями и hero_attack().
var enemy_definition: MonsterDefinition
var support_enemy_definition: MonsterDefinition
var hero: HeroState
var battle_state: BattleState

var enemy_health: int:
	get:
		return battle_state.get_enemy().health
var enemy_max_health: int:
	get:
		return battle_state.get_enemy().max_health
var enemy_damage: int:
	get:
		var enemy: BattleParticipant = battle_state.get_enemy()
		var strike: AbilityDefinition = AbilityCatalog.get_ability("basic_strike")
		return AbilityExecutor.preview_damage(enemy, strike, strike.effects[0])
var enemy_defense: int:
	get:
		return battle_state.get_enemy().defense
var is_victory: bool:
	get:
		return battle_state.is_victory
var is_defeat: bool:
	get:
		return battle_state.is_defeat
var last_counter_damage: int:
	get:
		return battle_state.last_counter_damage
var last_blocked_damage: int:
	get:
		return battle_state.last_blocked_damage


func _init(monster: MonsterDefinition = null, participant: HeroState = null, secondary: MonsterDefinition = null) -> void:
	var selected: MonsterDefinition = monster if monster != null else MonsterCatalog.get_monster(MonsterCatalog.DEFAULT_MONSTER_ID)
	var bond: BattleBondDefinition = selected.battle_bond
	if bond != null and (not MonsterCatalog.has(bond.companion_monster_id)
			or (secondary != null and secondary.monster_id != bond.companion_monster_id)):
		bond = null
	enemy_definition = MonsterCatalog.get_monster(bond.companion_monster_id) if bond != null else selected
	support_enemy_definition = selected if bond != null else secondary
	hero = participant if participant != null else HeroState.new()
	battle_state = BattleState.begin(enemy_definition, hero)
	if support_enemy_definition != null:
		battle_state.add_support_enemy(support_enemy_definition)
	if bond != null:
		battle_state.configure_bond(bond)


func hero_attack(_legacy_attack_damage: int = 0) -> int:
	var damage: int = battle_state.perform_basic_attack()
	# Подтверждаем результат на реальном герое после расчёта, чтобы остальная
	# игровая сессия (инвентарь, HUD, сломанный щит) работала как раньше.
	var battle_hero: BattleParticipant = battle_state.get_hero()
	if battle_hero != null:
		battle_hero.commit_hero_result(hero)
	return damage


func hero_block() -> Dictionary:
	var result: Dictionary = battle_state.perform_guard()
	if bool(result.get("success", false)):
		var battle_hero: BattleParticipant = battle_state.get_hero()
		if battle_hero != null:
			battle_hero.commit_hero_result(hero)
	return result


func hero_punch() -> int:
	return hero_attack()


## пробная двухтактовая фаза на уже имеющихся приёмах.
## Старые hero_attack()/hero_block() сохраняются для регрессионных тестов.
func play_phase(hero_chain: Array[String], enemy_chain: Array[String]) -> Dictionary:
	var result: Dictionary = battle_state.run_phase(hero_chain, enemy_chain)
	if bool(result.get("success", false)):
		var battle_hero: BattleParticipant = battle_state.get_hero()
		if battle_hero != null:
			battle_hero.commit_hero_result(hero)
	return result


func request_tactic_change() -> bool:
	return battle_state.flow.request_reconfiguration()


func confirm_tactic_change() -> bool:
	return battle_state.flow.confirm_reconfiguration()
