class_name BattleState
extends RefCounted

## Независимое от сцены состояние боя. Не управляет камерой и кнопками.
## Правила автоматических цепочек появятся в DA-4.03–DA-4.08.
var participants: Dictionary = {} # participant_id -> BattleParticipant
var hero_id: String = "hero"
var enemy_id: String = "enemy"
var is_victory: bool = false
var is_defeat: bool = false
var last_counter_damage: int = 0
var last_blocked_damage: int = 0
var turn_index: int = 0
var events: Array[Dictionary] = []


static func begin(monster: MonsterDefinition, hero: HeroState = null) -> BattleState:
	var state := BattleState.new()
	state.participants[state.enemy_id] = BattleParticipant.from_monster(monster)
	if hero != null:
		state.participants[state.hero_id] = BattleParticipant.from_hero(hero)
	return state


func get_participant(participant_id: String) -> BattleParticipant:
	return participants.get(participant_id) as BattleParticipant


func get_enemy() -> BattleParticipant:
	return get_participant(enemy_id)


func get_hero() -> BattleParticipant:
	return get_participant(hero_id)


## Полный результат действия с отдельными событиями для будущих анимаций.
func execute_ability(actor_id: String, target_id: String, ability_id: String) -> Dictionary:
	return AbilityExecutor.execute(self, actor_id, target_id, ability_id)


func update_outcome() -> void:
	var enemy: BattleParticipant = get_enemy()
	var hero: BattleParticipant = get_hero()
	is_victory = enemy != null and not enemy.is_alive()
	is_defeat = hero != null and not hero.is_alive() and not is_victory


## Упорядочение фаз появится в DA-4.05–4.06; здесь явный сброс бонуса.
func end_phase() -> void:
	for participant in participants.values():
		(participant as BattleParticipant).end_phase()


## Совместимость текущего экрана: удар героя, затем один ответ врага.
## Оба урона рассчитываются тем же обработчиком, что и способности из .tres.
func perform_basic_attack(attack_damage: int) -> int:
	if is_victory or is_defeat:
		return 0
	var hero: BattleParticipant = get_hero()
	var enemy: BattleParticipant = get_enemy()
	if enemy == null or not enemy.is_alive():
		return 0
	last_counter_damage = 0
	last_blocked_damage = 0
	var bonus_percent: int = hero.block_attack_bonus_percent if hero != null else 0
	var damage_amount: int = maxi(attack_damage, 0) * (100 + bonus_percent) / 100
	if hero != null:
		hero.block_attack_bonus_percent = 0
	var source: BattleParticipant = hero
	if source == null:
		source = BattleParticipant.new()
		source.participant_id = hero_id
	var hit: Dictionary = AbilityExecutor.apply_damage(source, enemy, damage_amount, "basic_strike")
	turn_index += 1
	hit["turn"] = turn_index
	events.append(hit)
	update_outcome()
	if not is_victory:
		_counterattack()
	return int(hit["damage"])


## Временная ручная кнопка блока: пока цепочки действий не появились.
func perform_guard() -> Dictionary:
	if is_victory or is_defeat:
		return {"success": false, "reason": "Бой завершён", "events": []}
	var result: Dictionary = execute_ability(hero_id, hero_id, "guard")
	if not bool(result.get("success", false)):
		return result
	last_counter_damage = 0
	last_blocked_damage = 0
	turn_index += 1
	if not is_victory:
		_counterattack()
	return result


func _counterattack() -> void:
	var hero: BattleParticipant = get_hero()
	var enemy: BattleParticipant = get_enemy()
	if hero == null or enemy == null or not hero.is_alive() or not enemy.is_alive():
		return
	var hit: Dictionary = AbilityExecutor.apply_damage(enemy, hero, enemy.attack, "basic_strike")
	hit["type"] = "counter" # Старые журналы и экран ожидают ответный удар.
	hit["turn"] = turn_index
	last_counter_damage = int(hit["damage"])
	last_blocked_damage = int(hit["blocked"])
	events.append(hit)
	update_outcome()
