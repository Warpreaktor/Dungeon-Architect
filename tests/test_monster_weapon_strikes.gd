extends SceneTree


func _initialize() -> void:
	var pool: Array[String] = MonsterWeaponStrike.weapon_pool()
	assert(pool.size() == 11)
	for item_id in pool:
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		var ability_id: String = MonsterWeaponStrike.ability_id(item_id)
		var ability: AbilityDefinition = AbilityCatalog.get_ability(ability_id)
		assert(ability != null and ability.validation_error().is_empty())
		assert(ability.icon == item.monster_attack_icon)
		assert(ability.effects.size() == 1)
		assert(ability.effects[0].effective_damage_multiplier() == 1.0)
		var actor: BattleParticipant = BattleParticipant.from_monster(MonsterCatalog.get_monster("skeleton"))
		actor.equipped_weapon_id = item_id
		actor.learned_ability_ids.append(ability_id)
		var baseline: AbilityDefinition = AbilityCatalog.get_ability("skeleton_rusty_slash")
		var armed_damage: int = AbilityExecutor.preview_damage(actor, ability, ability.effects[0])
		var basic_damage: int = AbilityExecutor.preview_damage(actor, baseline, baseline.effects[0])
		assert(armed_damage == basic_damage + item.weapon_damage)
		var ram: AbilityDefinition = AbilityCatalog.get_ability("skeleton_bone_ram")
		var armed_ram: int = AbilityExecutor.preview_damage(actor, ram, ram.effects[0])
		actor.equipped_weapon_id = ""
		assert(AbilityExecutor.preview_damage(actor, ram, ram.effects[0]) == armed_ram)

	for monster_id in ["skeleton", "fallen_hero"]:
		var monster: MonsterDefinition = MonsterCatalog.get_monster(monster_id)
		var fallback: String = monster.weapon_replaced_ability_id
		assert(monster.weapon_spawn_chance_percent > 0)
		var forced: MonsterDefinition = monster.duplicate(true) as MonsterDefinition
		forced.weapon_spawn_chance_percent = 100
		var a: BattleState = BattleState.begin(forced, null, 82)
		var b: BattleState = BattleState.begin(forced, null, 82)
		assert(a.get_enemy().equipped_weapon_id == b.get_enemy().equipped_weapon_id)
		assert(not a.get_enemy().equipped_weapon_id.is_empty())
		assert(a.get_enemy().action_chain == b.get_enemy().action_chain)
		assert(a.get_enemy().action_chain.has(MonsterWeaponStrike.ability_id(a.get_enemy().equipped_weapon_id)))
		assert(not a.get_enemy().action_chain.has(fallback))
		forced.weapon_spawn_chance_percent = 0
		var unarmed: BattleState = BattleState.begin(forced, null, 82)
		assert(unarmed.get_enemy().equipped_weapon_id.is_empty())
		assert(unarmed.get_enemy().action_chain.has(fallback))

	var skeleton: MonsterDefinition = MonsterCatalog.get_monster("skeleton").duplicate(true) as MonsterDefinition
	skeleton.weapon_spawn_chance_percent = 100
	var combat: BattleState = BattleState.begin(skeleton, null, 7)
	var enemy: BattleParticipant = combat.get_enemy()
	enemy.health = 3
	combat._reconfigure_enemy_for_actor("enemy")
	assert(enemy.action_chain.has(MonsterWeaponStrike.ability_id(enemy.equipped_weapon_id)))
	assert(not enemy.action_chain.has("skeleton_rusty_slash"))
	quit()
