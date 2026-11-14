class_name CombatSession
extends RefCounted

## Временная модель поединка. Не зависит от UI или исходной карты.
## Позже здесь появятся участники, порядок ходов и способности.

const ENEMY_MAX_HEALTH: int = 1
const PUNCH_DAMAGE: int = 1

var enemy_health: int = ENEMY_MAX_HEALTH
var is_victory: bool = false


func hero_attack(attack_damage: int) -> int:
	if is_victory:
		return 0
	var damage: int = maxi(attack_damage, 0)
	enemy_health = maxi(enemy_health - damage, 0)
	is_victory = enemy_health == 0
	return damage


func hero_punch() -> int:
	return hero_attack(PUNCH_DAMAGE)
