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


## Совместимый первый удар: герой атакует, выживший противник отвечает.
## Модель меняет только свои снимки и возвращает факты для отображения.
func perform_basic_attack(attack_damage: int) -> int:
	if is_victory or is_defeat:
		return 0
	var enemy: BattleParticipant = get_enemy()
	if enemy == null:
		return 0
	last_counter_damage = 0
	last_blocked_damage = 0
	var dealt: int = maxi(attack_damage - enemy.defense, 0)
	enemy.health = maxi(enemy.health - dealt, 0)
	turn_index += 1
	events.append({"turn": turn_index, "actor_id": hero_id, "target_id": enemy_id, "type": "attack", "damage": dealt})
	is_victory = not enemy.is_alive()
	if not is_victory:
		var hero: BattleParticipant = get_hero()
		if hero != null:
			last_counter_damage = hero.receive_damage(enemy.attack)
			last_blocked_damage = maxi(enemy.attack - last_counter_damage, 0)
			is_defeat = not hero.is_alive()
			events.append({"turn": turn_index, "actor_id": enemy_id, "target_id": hero_id,
				"type": "counter", "damage": last_counter_damage, "blocked": last_blocked_damage})
	return dealt
