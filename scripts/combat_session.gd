class_name CombatSession
extends RefCounted

## Совместимый фасад существующего боя. Расчёт теперь выполняет BattleState;
## BattleView продолжает пользоваться прежними полями и hero_attack().
const ENEMY_MAX_HEALTH: int = 1 # Совместимость с тестами первого поединка.
const PUNCH_DAMAGE: int = 1

var enemy_definition: MonsterDefinition
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
		return battle_state.get_enemy().attack
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


func _init(monster: MonsterDefinition = null, participant: HeroState = null) -> void:
	enemy_definition = monster if monster != null else MonsterCatalog.get_monster(MonsterCatalog.DEFAULT_MONSTER_ID)
	hero = participant
	battle_state = BattleState.begin(enemy_definition, participant)


func hero_attack(attack_damage: int) -> int:
	var damage: int = battle_state.perform_basic_attack(attack_damage)
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
	return hero_attack(PUNCH_DAMAGE)
