extends SceneTree

## DA-4.04: реальные эффекты и целостность состояния без Control/сцены боя.
func _initialize() -> void:
	assert(AbilityCatalog.validate_catalog().is_empty())
	var hero := HeroState.new(HeroCatalog.get_hero("petushan"))
	var shield: ItemDefinition = ItemCatalog.get_item("shield")
	hero.register_shield(shield)
	assert(hero.equip_item(shield))
	var initial_durability: int = hero.current_shield_durability("shield")
	var monster := MonsterDefinition.new()
	monster.monster_id = "executor_fixture"
	monster.display_name = "Противник"
	monster.max_health = 100
	monster.strength = 10
	monster.defense = 2
	monster.max_energy = 24
	monster.personal_ability_ids = ["basic_strike", "guard", "test_heal", "test_curse"]
	monster.guaranteed_card_ids = ["basic_strike"]
	monster.random_card_count = 0
	var battle: BattleState = BattleState.begin(monster, hero, 7)
	battle.rng = null
	var actor: BattleParticipant = battle.get_hero()
	if not actor.personal_ability_ids.has("basic_strike"):
		actor.personal_ability_ids.append("basic_strike")
	var enemy: BattleParticipant = battle.get_enemy()
	assert(actor.block_armor == 0 and actor.block_attack_bonus_percent == 0)
	assert(actor.defense == hero.base_defense) # Щит не даёт пассивной брони.
	var unguarded: int = actor.receive_damage(5)
	assert(unguarded == 5 - hero.base_defense)
	assert(actor._hero_snapshot.current_shield_durability("shield") == initial_durability)
	assert(hero.health == hero.max_health) # Изменяется только копия.

	var block: Dictionary = battle.execute_ability("hero", "hero", "guard")
	assert(block.success and block.events.any(func(event: Dictionary) -> bool: return event["type"] == "block"))
	assert(actor.block_attack_bonus_percent == 25)
	assert(actor.block_armor == shield.defense_bonus)
	var guard_damage: Dictionary = AbilityExecutor.apply_damage(enemy, actor, shield.defense_bonus + 1)
	assert(guard_damage.shield_blocked == mini(shield.defense_bonus, initial_durability))
	assert(actor.block_armor == 0)
	assert(actor._hero_snapshot.current_shield_durability("shield") == maxi(initial_durability - (shield.defense_bonus + 1 - hero.base_defense), 0))
	assert(actor.block_attack_bonus_percent == 25)

	# Блоки копят бонус. Следующая атака его получает и расходует.
	assert(battle.execute_ability("hero", "hero", "guard").success)
	assert(actor.block_attack_bonus_percent == 50)
	var hp_before: int = enemy.health
	var hit: Dictionary = battle.execute_ability("hero", "enemy", "basic_strike")
	assert(hit.success)
	var attack_event: Dictionary = hit.events.filter(func(event: Dictionary) -> bool: return event["type"] == "attack")[0]
	assert(attack_event.damage == maxi(floori((hero.melee_attack_value() + 1.0) * 1.5) - enemy.defense, 0))
	assert(enemy.health == hp_before - attack_event.damage)
	assert(actor.block_attack_bonus_percent == 0)
	assert(not battle.execute_ability("hero", "enemy", "not_registered").success)
	assert(not battle.execute_ability("hero", "hero", "basic_strike").success)
	assert(not battle.execute_ability("enemy", "enemy", "hunter_shot").success)
	assert(AbilityCatalog.get_ability("wolf_counter") == null)

	# Блок и его накопленная мощь сохраняются через границу фазы.
	assert(battle.execute_ability("hero", "hero", "guard").success)
	battle.end_phase()
	assert(actor.block_attack_bonus_percent == 25 and actor.block_armor > 0)
	assert(battle.execute_ability("hero", "enemy", "basic_strike").success)
	assert(actor.block_attack_bonus_percent == 0)

	# Монстры используют тот же обработчик, могут блокировать и лечиться.
	assert(battle.execute_ability("enemy", "enemy", "guard").success)
	assert(enemy.block_attack_bonus_percent == 25)
	var enemy_hp: int = enemy.health
	var heal := AbilityDefinition.new()
	heal.ability_id = "test_heal"
	heal.display_name = "Лечение"
	heal.target = AbilityDefinition.Target.SELF
	var heal_effect := AbilityEffectDefinition.new()
	heal_effect.kind = AbilityEffectDefinition.Kind.HEAL
	heal_effect.recipient = AbilityEffectDefinition.Recipient.SELF
	heal_effect.amount = 3
	heal.effects = [heal_effect]
	assert(battle.execute_definition("enemy", "enemy", heal).success)
	assert(enemy.health == mini(enemy_hp + 3, enemy.max_health))
	var curse := AbilityDefinition.new()
	curse.ability_id = "test_curse"
	curse.display_name = "Ослабление"
	var curse_effect := AbilityEffectDefinition.new()
	curse_effect.kind = AbilityEffectDefinition.Kind.APPLY_STATUS
	curse_effect.status_id = "attack_down"
	curse_effect.status_stat = AbilityEffectDefinition.Stat.ATTACK_POWER
	curse_effect.status_modifier = -2
	curse_effect.duration_ticks = 2
	curse.effects = [curse_effect]
	assert(battle.execute_definition("enemy", "hero", curse).success)
	assert(actor.statuses.has("attack_down"))
	battle.end_phase()
	assert(actor.statuses.has("attack_down"))
	battle.end_phase()
	assert(not actor.statuses.has("attack_down"))

	# Неизвестный и недоступный приём не меняет состояние и журнал.
	var old_events: int = battle.events.size()
	var old_hp: int = actor.health
	var fail: Dictionary = battle.execute_ability("hero", "enemy", "wolf_counter")
	assert(not fail.success and not fail.reason.is_empty())
	assert(battle.events.size() == old_events and actor.health == old_hp)

	# Отдельные схватки не могут делить прочность или эффекты.
	var other: BattleState = BattleState.begin(monster, hero)
	assert(other.get_hero().block_attack_bonus_percent == 0)
	assert(other.get_hero()._hero_snapshot.current_shield_durability("shield") == initial_durability)
	actor.commit_hero_result(hero)
	assert(hero.health == actor.health)
	assert(hero.current_shield_durability("shield") == actor._hero_snapshot.current_shield_durability("shield"))
	quit()
