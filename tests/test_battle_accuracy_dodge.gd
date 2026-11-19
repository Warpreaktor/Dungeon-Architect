extends SceneTree

## Проверяем формулу на модели независимо от HUD и анимаций.
func _initialize() -> void:
	var agile := BattleParticipant.new()
	agile.health = 100
	agile.max_health = 100
	agile.agility = 10
	var attacker := BattleParticipant.new()
	attacker.health = 100
	attacker.max_health = 100
	attacker.agility = 5
	assert(agile.dodge_percent() == 10)
	assert(attacker.accuracy_percent() == -5)
	assert(agile.dodge_chance_against(attacker) == 15)
	assert(agile.accuracy_percent() == 0)
	assert(attacker.dodge_chance_against(agile) == 5)

	# Дебафф Ловкости влияет одновременно на уклонение и меткость.
	var debuff := AbilityEffectDefinition.new()
	debuff.kind = AbilityEffectDefinition.Kind.APPLY_STATUS
	debuff.status_id = "accuracy_test_agility_down"
	debuff.status_stat = AbilityEffectDefinition.Stat.AGILITY
	debuff.status_modifier = -2
	debuff.duration_ticks = 2
	agile.apply_status(debuff, 1)
	assert(agile.effective_agility() == 8)
	assert(agile.dodge_chance_against(attacker) == 13)
	assert(agile.accuracy_percent() == -2)

	# Дополнительная меткость может противодействовать уклонению от бафов.
	var dodge_buff := AbilityEffectDefinition.new()
	dodge_buff.kind = AbilityEffectDefinition.Kind.APPLY_STATUS
	dodge_buff.status_id = "accuracy_test_dodge_buff"
	dodge_buff.status_stat = AbilityEffectDefinition.Stat.DODGE_PERCENT
	dodge_buff.status_modifier = 20
	dodge_buff.duration_ticks = 1
	dodge_buff.status_clock = AbilityEffectDefinition.Clock.INCOMING_ATTACK
	agile.apply_status(dodge_buff, 1)
	assert(agile.dodge_percent() == 28)
	assert(agile.dodge_chance_against(attacker) == 33)
	attacker.accuracy_bonus = 30
	assert(agile.dodge_chance_against(attacker) == 3)
	attacker.accuracy_bonus = 0

	var aiming := AbilityEffectDefinition.new()
	aiming.kind = AbilityEffectDefinition.Kind.APPLY_STATUS
	aiming.status_id = "accuracy_test_aiming"
	aiming.status_stat = AbilityEffectDefinition.Stat.ACCURACY
	aiming.status_modifier = 5
	aiming.duration_ticks = 1
	attacker.apply_status(aiming, 1)
	assert(attacker.accuracy_percent() == 0)
	assert(agile.dodge_chance_against(attacker) == 28)
	attacker.statuses.clear()

	# 100% не является потолком меткости: шанс уклонения уменьшается
	# без подбрасывания лишнего случайного значения.
	attacker.agility = 105
	assert(attacker.accuracy_percent() == 95)
	assert(agile.dodge_chance_against(attacker) == 0)

	# Отсутствие уклонения не исключает промах при меткости ниже 100%.
	attacker.agility = 2
	agile.agility = 0
	assert(attacker.accuracy_percent() == -8) # Меткость 92%.
	assert(agile.dodge_chance_against(attacker) == 8)
	var accuracy_down := AbilityEffectDefinition.new()
	accuracy_down.kind = AbilityEffectDefinition.Kind.APPLY_STATUS
	accuracy_down.status_id = "accuracy_test_minus_ten"
	accuracy_down.status_stat = AbilityEffectDefinition.Stat.ACCURACY
	accuracy_down.status_modifier = -10
	accuracy_down.duration_ticks = 1
	attacker.apply_status(accuracy_down, 2)
	assert(attacker.accuracy_percent() == -18) # Меткость 82%.
	assert(agile.dodge_chance_against(attacker) == 18)
	attacker.statuses.clear()

	# Исход броска и опубликованные проценты вычисляются одной моделью.
	attacker.agility = 5
	agile.statuses.clear()
	agile.agility = 10
	var random := RandomNumberGenerator.new()
	random.seed = 37
	var event := AbilityExecutor.apply_damage(attacker, agile, 4, "test_hit", random)
	assert(event.dodge_chance == 15)
	assert(event.effective_dodge_after == 15)
	assert(event.target_dodge == 10)
	assert(event.attacker_accuracy == -5)
	assert(agile.health == 96 or agile.health == 100)
	quit()
