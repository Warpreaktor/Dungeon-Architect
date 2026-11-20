class_name BattleEquipment
extends RefCounted

var _hero: HeroState


func _init(hero_snapshot: HeroState = null) -> void:
	_hero = hero_snapshot


func set_snapshot(hero_snapshot: HeroState) -> void:
	_hero = hero_snapshot


func weapon_damage(weapon_kind: int) -> int:
	return _hero.weapon_damage(weapon_kind) if _hero != null else 0


func shield_durability(shield_id: String) -> int:
	if _hero == null or shield_id.is_empty():
		return -1
	return _hero.current_shield_durability(shield_id)


func has_shield(shield_id: String) -> bool:
	if shield_id.is_empty():
		return false
	if _hero == null:
		return true
	return shield_durability(shield_id) > 0


func block_armor(shield_id: String, unarmed_armor: int) -> int:
	if _hero != null and has_shield(shield_id):
		var shield: ItemDefinition = ItemCatalog.get_item(shield_id)
		if shield != null:
			return maxi(shield.defense_bonus, 0)
	return unarmed_armor


func absorb(shield_id: String, incoming: int, blocked: int) -> Dictionary:
	if _hero == null or not has_shield(shield_id) or blocked <= 0:
		return {"blocked": blocked, "shield_blocked": 0, "broken": ""}
	var actual: int = _hero.consume_shield_block(incoming, blocked)
	return {"blocked": actual, "shield_blocked": actual, "broken": _hero.last_shield_broken}


func has_damaged_shield(shield_id: String) -> bool:
	if _hero == null or not has_shield(shield_id):
		return false
	var shield: ItemDefinition = ItemCatalog.get_item(shield_id)
	if shield == null:
		return false
	var full: int = maxi(shield.max_durability, shield.defense_bonus)
	return shield_durability(shield_id) < full
