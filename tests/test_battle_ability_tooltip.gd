extends SceneTree

## Тултип показывает числа из ресурсов, а не общие описания.
func _initialize() -> void:
	var hero := HeroState.new(HeroCatalog.get_hero("volcha"))
	var actor: BattleParticipant = BattleParticipant.from_hero(hero)
	var strike: String = BattleAbilityTooltip.describe(AbilityCatalog.get_ability("basic_strike"), actor)
	assert(strike.contains("Урон: %d" % AbilityExecutor.preview_damage(actor, AbilityCatalog.get_ability("basic_strike"), AbilityCatalog.get_ability("basic_strike").effects[0])))
	assert(strike.contains("до защиты"))
	var guard: String = BattleAbilityTooltip.describe(AbilityCatalog.get_ability("guard"), actor)
	assert(guard.contains("Броня блока:"))
	assert(guard.contains("+25%"))
	var regen: String = BattleAbilityTooltip.describe(AbilityCatalog.get_ability("kadavr_regen"), actor)
	assert(regen.contains("Лечение: 3 HP"))
	var feint: String = BattleAbilityTooltip.describe(AbilityCatalog.get_ability("volcha_wolf_lunge"), actor)
	assert(feint.contains("Урон:"))
	assert(feint.contains("Урон:"))
	assert(BattleAbilityTooltip.describe(null, actor).is_empty())
	quit()
