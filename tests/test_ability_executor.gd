extends SceneTree

## DA-4.04: реальные эффекты и целостность состояния без Control/сцены боя.
func _initialize() -> void:
	assert(AbilityCatalog.validate_catalog().is_empty())
	var hero := HeroState.new(HeroCatalog.get_hero("petushan"))
	var shield: ItemDefinition = ItemCatalog.get_item("shield")
	hero.register_shield(shield)
	assert(hero.equip_item(shield))
	var initial_durability: int = hero.current_shield_durability("shield")
	var battle: BattleState = BattleState.begin(MonsterCatalog.get_monster("kadavr"), hero)
	var actor: BattleParticipant = battle.get_hero()
	var enemy: BattleParticipant = battle.get_enemy()
	assert(actor.block_armor == 0 and actor.block_attack_bonus_percent == 0)
	assert(actor.defense == hero.base_defense) # Щит не даёт пассивной брони.
	var unguarded: int = actor.receive_damage(5)
	assert(unguarded == 5 - hero.base_defense)
	assert(actor._hero_snapshot.current_shield_durability("shield") == initial_durability)
	assert(hero.health == hero.max_health) # Изменяется только копия.

	var block: Dictionary = battle.execute_ability("hero", "hero", "guard")
	assert(block.success and block.events[0]["type"] == "block")
	assert(actor.block_attack_bonus_percent == 25)
	assert(actor.block_armor == shield.defense_bonus)
	var guard_damage: Dictionary = AbilityExecutor.apply_damage(enemy, actor, shield.defense_bonus + 1)
	assert(guard_damage.shield_blocked == mini(shield.defense_bonus, initial_durability))
	assert(actor.block_armor == 0)
	assert(actor._hero_snapshot.current_shield_durability("shield") == initial_durability - guard_damage.shield_blocked)
	assert(actor.block_attack_bonus_percent == 25)

	# Блоки копят бонус. Следующая атака его получает и расходует.
	assert(battle.execute_ability("hero", "hero", "guard").success)
	assert(actor.block_attack_bonus_percent == 50)
	var hp_before: int = enemy.health
	var hit: Dictionary = battle.execute_ability("hero", "enemy", "basic_strike")
	assert(hit.success and hit.events.size() == 1)
	assert(hit.events[0].damage == maxi(hero.attack * 150 / 100 - enemy.defense, 0))
	assert(enemy.health == hp_before - hit.events[0].damage)
	assert(actor.block_attack_bonus_percent == 0)
	assert(not battle.execute_ability("hero", "enemy", "not_registered").success)
	assert(not battle.execute_ability("hero", "hero", "basic_strike").success)
	assert(not battle.execute_ability("enemy", "enemy", "hunter_shot").success)
	assert(AbilityCatalog.get_ability("wolf_counter") != null)

	# Эффект блока и его бонус одноразовы в границах фазы.
	assert(battle.execute_ability("hero", "hero", "guard").success)
	battle.end_phase()
	assert(actor.block_attack_bonus_percent == 0 and actor.block_armor == 0)

	# Монстры используют тот же обработчик, могут блокировать и лечиться.
	assert(battle.execute_ability("enemy", "enemy", "guard").success)
	assert(enemy.block_attack_bonus_percent == 25)
	var enemy_hp: int = enemy.health
	assert(battle.execute_ability("enemy", "enemy", "kadavr_regen").success)
	assert(enemy.health == mini(enemy_hp + 3, enemy.max_health))
	assert(battle.execute_ability("enemy", "hero", "kadavr_curse").success)
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
	var other: BattleState = BattleState.begin(MonsterCatalog.get_monster("kadavr"), hero)
	assert(other.get_hero().block_attack_bonus_percent == 0)
	assert(other.get_hero()._hero_snapshot.current_shield_durability("shield") == initial_durability)
	actor.commit_hero_result(hero)
	assert(hero.health == actor.health)
	assert(hero.current_shield_durability("shield") == actor._hero_snapshot.current_shield_durability("shield"))
	quit()
