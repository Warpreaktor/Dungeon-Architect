class_name CombatSession
extends RefCounted

## Временная модель поединка. Не зависит от UI или исходной карты.
## Позже здесь появятся участники, порядок ходов и способности.

const ENEMY_MAX_HEALTH: int = 1
const PUNCH_DAMAGE: int = 1

var enemy_health: int = ENEMY_MAX_HEALTH
var is_victory: bool = false


func hero_punch() -> int:
	if is_victory:
		return 0
	var damage: int = mini(PUNCH_DAMAGE, enemy_health)
	enemy_health -= damage
	is_victory = enemy_health == 0
	return damage
