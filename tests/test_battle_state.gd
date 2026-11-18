extends SceneTree

## DA-4.02: независимое состояние боя без создания сцены или Canvas.
func _initialize() -> void:
	var hero := HeroState.new(HeroCatalog.get_hero(HeroCatalog.DEFAULT_HERO_ID))
	var monster: MonsterDefinition = MonsterCatalog.get_monster("hunter")
	var original_hp: int = hero.health
	var definition_hp: int = monster.max_health
	var fight_a: BattleState = BattleState.begin(monster, hero)
	var fight_b: BattleState = BattleState.begin(monster, hero)
	assert(fight_a != fight_b)
	assert(fight_a.get_hero() != fight_b.get_hero())
	assert(fight_a.get_participant("hero") != null)
	assert(fight_a.get_participant("enemy") != null)
	assert(fight_a.get_participant("missing") == null)
	assert(fight_a.get_enemy().health == definition_hp)
	assert(fight_a.perform_basic_attack(2) == maxi(2 - monster.defense, 0))
	assert(fight_a.turn_index == 1 and fight_a.events.size() == 2)
	assert(fight_a.events[0]["actor_id"] == "hero")
	assert(fight_a.events[1]["actor_id"] == "enemy")
	assert(hero.health == original_hp) # Вычисление не изменяет реального героя.
	assert(fight_b.get_hero().health == original_hp)
	assert(fight_b.get_enemy().health == definition_hp)
	assert(monster.max_health == definition_hp) # Resource — определение, не состояние.

	var shield: ItemDefinition = ItemCatalog.get_item("shield")
	var guarded := HeroState.new(HeroCatalog.get_hero(HeroCatalog.DEFAULT_HERO_ID))
	guarded.register_shield(shield)
	assert(guarded.equip_item(shield))
	var before_durability: int = guarded.current_shield_durability("shield")
	var shield_fight := BattleState.begin(monster, guarded)
	assert(shield_fight.get_hero().equipped_shield_id == "shield")
	shield_fight.perform_basic_attack(1)
	assert(guarded.current_shield_durability("shield") == before_durability)
	assert(shield_fight.get_hero()._hero_snapshot.current_shield_durability("shield") <= before_durability)
	shield_fight.get_hero().commit_hero_result(guarded)
	assert(guarded.health == shield_fight.get_hero().health)
	assert(guarded.current_shield_durability("shield") == shield_fight.get_hero()._hero_snapshot.current_shield_durability("shield"))

	# Старый интерфейс CombatSession сохраняет работу и сразу передаёт HP герою.
	var legacy_hero := HeroState.new(HeroCatalog.get_hero(HeroCatalog.DEFAULT_HERO_ID))
	var old_hp: int = legacy_hero.health
	var combat := CombatSession.new(monster, legacy_hero)
	assert(combat.battle_state.get_hero() != null)
	assert(combat.enemy_health == monster.max_health)
	assert(combat.hero_attack(1) == maxi(1 - monster.defense, 0))
	assert(legacy_hero.health == old_hp - combat.last_counter_damage)
	assert(combat.battle_state.get_hero().health == legacy_hero.health)
	assert(combat.hero == legacy_hero)

	var doomed := HeroState.new(HeroCatalog.get_hero(HeroCatalog.DEFAULT_HERO_ID))
	doomed.health = 1
	var defeat := CombatSession.new(monster, doomed)
	defeat.hero_attack(1)
	assert(defeat.is_defeat and doomed.health == 0)
	assert(defeat.hero_attack(1) == 0)

	var finisher := CombatSession.new(monster, HeroState.new(HeroCatalog.get_hero(HeroCatalog.DEFAULT_HERO_ID)))
	assert(finisher.hero_attack(monster.max_health + monster.defense) == monster.max_health)
	assert(finisher.is_victory and not finisher.is_defeat)
	assert(finisher.battle_state.events.size() == 1)
	assert(finisher.hero_attack(1) == 0)
	quit()
