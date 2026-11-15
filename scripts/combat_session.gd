class_name CombatSession
extends RefCounted

## Пошаговый поединок. После удара героя выживший враг отвечает.
## Все изменения здоровья относятся к HeroState текущей GameSession, не к JSON карты.
const ENEMY_MAX_HEALTH: int = 1 # Совместимость с тестами первого поединка.
const PUNCH_DAMAGE: int = 1

var enemy_definition: MonsterDefinition
var enemy_health: int = ENEMY_MAX_HEALTH
var enemy_max_health: int = ENEMY_MAX_HEALTH
var enemy_damage: int = 1
var enemy_defense: int = 0
var is_victory: bool = false
var is_defeat: bool = false
var last_counter_damage: int = 0 # Урон после блока щитом.
var last_blocked_damage: int = 0
var hero: HeroState


func _init(monster: MonsterDefinition = null, participant: HeroState = null) -> void:
	enemy_definition = monster if monster != null else MonsterCatalog.get_monster(MonsterCatalog.DEFAULT_MONSTER_ID)
	enemy_max_health = enemy_definition.max_health
	enemy_health = enemy_max_health
	enemy_damage = enemy_definition.attack_damage
	enemy_defense = enemy_definition.defense
	hero = participant


func hero_attack(attack_damage: int) -> int:
	if is_victory or is_defeat:
		return 0
	var damage: int = maxi(attack_damage - enemy_defense, 0)
	enemy_health = maxi(enemy_health - damage, 0)
	is_victory = enemy_health == 0
	last_counter_damage = 0
	last_blocked_damage = 0
	if not is_victory and hero != null:
		last_counter_damage = hero.take_damage(enemy_damage)
		last_blocked_damage = maxi(enemy_damage - last_counter_damage, 0)
		is_defeat = hero.health <= 0
	return damage


func hero_punch() -> int:
	return hero_attack(PUNCH_DAMAGE)
