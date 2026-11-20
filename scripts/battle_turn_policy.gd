class_name BattleTurnPolicy
extends RefCounted

## Порядок действий на одном такте, не зависящий от визуализации.
## Политика принадлежит экземпляру BattleState и может быть заменена в тестах.
var block_priority: int = 0
var other_priority: int = 10
var hero_first_on_tie: bool = true


func priority(action_id: String) -> int:
	var ability: AbilityDefinition = AbilityCatalog.get_ability(action_id)
	if ability != null:
		var has_block: bool = false
		for effect in ability.effects:
			# Выпад с последующей защитой остаётся атакой, а не «блоком».
			if effect.kind == AbilityEffectDefinition.Kind.DAMAGE:
				return other_priority
			if effect.kind == AbilityEffectDefinition.Kind.BLOCK:
				has_block = true
		if has_block:
			return block_priority
	return other_priority


func order(hero_id: String, hero_step: Dictionary, enemy_id: String, enemy_step: Dictionary) -> Array[String]:
	var first: String = hero_id
	var second: String = enemy_id
	var hero_reloading: bool = bool(hero_step.get("reload", false))
	var enemy_reloading: bool = bool(enemy_step.get("reload", false))
	var enemy_comes_first: bool = false
	if hero_reloading and not enemy_reloading:
		enemy_comes_first = true
	elif not hero_reloading and not enemy_reloading:
		var hero_priority: int = priority(str(hero_step.get("action_id", "")))
		var enemy_priority: int = priority(str(enemy_step.get("action_id", "")))
		enemy_comes_first = enemy_priority < hero_priority or (enemy_priority == hero_priority and not hero_first_on_tie)
	if enemy_comes_first:
		first = enemy_id
		second = hero_id
	return [first, second]
