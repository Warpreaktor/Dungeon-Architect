extends SceneTree

## Тултипы описывают приёмы без прогноза урона из текущих характеристик.
func _initialize() -> void:
	var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
	var actor: BattleParticipant = BattleParticipant.from_hero(hero)
	var strike: String = BattleAbilityTooltip.describe(AbilityCatalog.get_ability("basic_strike"), actor)
	assert(strike.contains("Атака: ближняя"))
	assert(strike.contains("Урон:"))
	assert(not strike.contains("Мощность приёма:"))
	var guard: String = BattleAbilityTooltip.describe(AbilityCatalog.get_ability("guard"), actor)
	assert(guard.contains("сила блока зависит от щита"))
	assert(not guard.contains("Броня блока:"))
	var regen: String = BattleAbilityTooltip.describe(AbilityCatalog.get_ability("kadavr_regen"), actor)
	assert(regen.contains("Лечение: 3 HP"))
	var lunge: AbilityDefinition = AbilityCatalog.get_ability("volcha_wolf_lunge")
	var first: String = BattleAbilityTooltip.describe(lunge, actor, 0)
	var later: String = BattleAbilityTooltip.describe(lunge, actor, 1)
	assert(first == later)
	assert(first.contains("Урон:"))
	assert(BattleAbilityTooltip.describe(null, actor).is_empty())
	quit()
