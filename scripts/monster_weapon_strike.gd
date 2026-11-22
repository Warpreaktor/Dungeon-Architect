class_name MonsterWeaponStrike
extends RefCounted

const PREFIX: String = "monster_weapon_"


static func ability_id(item_id: String) -> String:
	return PREFIX + item_id


static func is_weapon_strike(value: String) -> bool:
	return value.begins_with(PREFIX)


static func make_ability(value: String) -> AbilityDefinition:
	if not is_weapon_strike(value):
		return null
	var weapon: ItemDefinition = ItemCatalog.get_item(value.trim_prefix(PREFIX))
	if weapon == null or weapon.equipment_slot != ItemDefinition.EquipmentSlot.WEAPON:
		return null
	var ability := AbilityDefinition.new()
	ability.ability_id = value
	ability.display_name = "Удар: %s" % weapon.display_name
	ability.description = weapon.get_description()
	ability.icon = weapon.monster_attack_icon
	ability.category = AbilityDefinition.Category.ATTACK
	ability.target = AbilityDefinition.Target.ENEMY
	ability.damage_delivery = AbilityDefinition.DamageDelivery.RANGED if weapon.weapon_kind == ItemDefinition.WeaponKind.RANGED else AbilityDefinition.DamageDelivery.MELEE
	var effect := AbilityEffectDefinition.new()
	effect.kind = AbilityEffectDefinition.Kind.DAMAGE
	effect.recipient = AbilityEffectDefinition.Recipient.TARGET
	ability.effects.append(effect)
	return ability


static func weapon_pool() -> Array[String]:
	var ids: Array[String] = []
	for item_id in ItemCatalog.equipment_ids():
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item != null and item.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON and item.monster_attack_icon != null and int(ItemCatalog.LOOT_TABLE.weights.get(item_id, 0)) > 0:
			ids.append(item_id)
	ids.sort()
	return ids


static func draw_weapon(monster: MonsterDefinition, rng: RandomNumberGenerator) -> String:
	if monster == null or rng == null or monster.weapon_spawn_chance_percent <= 0 or monster.weapon_replaced_ability_id.is_empty():
		return ""
	if rng.randi_range(1, 100) > monster.weapon_spawn_chance_percent:
		return ""
	var pool: Array[String] = weapon_pool()
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""


static func replace_default_card(monster: MonsterDefinition, participant: BattleParticipant, chain: Array[String]) -> Array[String]:
	var result: Array[String] = chain.duplicate()
	if monster == null or participant == null or participant.equipped_weapon_id.is_empty():
		return result
	var index: int = result.find(monster.weapon_replaced_ability_id)
	if index >= 0:
		result[index] = ability_id(participant.equipped_weapon_id)
	return result
