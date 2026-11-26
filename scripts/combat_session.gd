class_name CombatSession
extends RefCounted

## Совместимый фасад существующего боя. Расчёт теперь выполняет BattleState;
## Объединяет данные боевого ядра с постоянным состоянием героя.
var enemy_definition: MonsterDefinition:
	get:
		return battle_state.enemy_definition
var support_enemy_definition: MonsterDefinition:
	get:
		return battle_state.support_enemy_definition
var hero: HeroState
var hero_sources: Dictionary = {}
var battle_state: BattleState

var enemy_health: int:
	get:
		return battle_state.get_enemy().health
var enemy_max_health: int:
	get:
		return battle_state.get_enemy().max_health
var enemy_damage: int:
	get:
		var enemy: BattleParticipant = battle_state.get_enemy()
		var strike: AbilityDefinition = AbilityCatalog.get_ability("basic_strike")
		return AbilityExecutor.preview_damage(enemy, strike, strike.effects[0])
var enemy_defense: int:
	get:
		return battle_state.get_enemy().defense
var is_victory: bool:
	get:
		return battle_state.is_victory
var is_defeat: bool:
	get:
		return battle_state.is_defeat
var last_counter_damage: int:
	get:
		return battle_state.last_counter_damage
var last_blocked_damage: int:
	get:
		return battle_state.last_blocked_damage


static func for_encounter(monsters: Array[MonsterDefinition], participant: HeroState = null, rng_seed: int = -1, party_members: Array[HeroState] = []) -> CombatSession:
	if not MonsterCatalog.valid_encounter(monsters):
		return null
	return CombatSession.new(null, participant, null, rng_seed, party_members, monsters)


func _init(monster: MonsterDefinition = null, participant: HeroState = null, secondary: MonsterDefinition = null, rng_seed: int = -1, party_members: Array[HeroState] = [], encounter: Array[MonsterDefinition] = []) -> void:
	var monsters: Array[MonsterDefinition] = encounter.duplicate()
	if monsters.is_empty():
		var selected: MonsterDefinition = monster if monster != null else MonsterCatalog.get_monster(MonsterCatalog.DEFAULT_MONSTER_ID)
		monsters.append(selected)
		if secondary != null:
			monsters.append(secondary)
		monsters = MonsterCatalog.normalize_legacy_encounter(monsters)
	if not MonsterCatalog.valid_encounter(monsters):
		monsters.assign([MonsterCatalog.get_monster(MonsterCatalog.DEFAULT_MONSTER_ID)])
	hero = participant if participant != null else HeroState.new()
	var combat_party: Array[HeroState] = party_members.duplicate()
	if combat_party.is_empty():
		combat_party.append(hero)
	battle_state = BattleState.begin_for_encounter(monsters, combat_party, rng_seed)
	for index in range(combat_party.size()):
		var member: HeroState = combat_party[index]
		if member == null:
			continue
		var participant_id: String = battle_state.hero_id if index == 0 else "hero_%d" % (index + 1)
		hero_sources[participant_id] = member


func hero_attack(_legacy_attack_damage: int = 0) -> int:
	var damage: int = battle_state.perform_basic_attack()
	# Подтверждаем результат на реальном герое после расчёта, чтобы остальная
	# игровая сессия (инвентарь, HUD, сломанный щит) работала как раньше.
	sync_hero_results()
	return damage


func hero_block() -> Dictionary:
	var result: Dictionary = battle_state.perform_guard()
	if bool(result.get("success", false)):
		sync_hero_results()
	return result




func prepare_manual_combat(hero_chain: Array[String]) -> Dictionary:
	return battle_state.prepare_manual_combat(hero_chain)


func play_manual_tick(slot_index: int, target_id: String = "") -> Dictionary:
	var result: Dictionary = battle_state.run_manual_tick(slot_index, target_id)
	if bool(result.get("success", false)):
		sync_hero_results()
	return result


func prepare_round_combat() -> Dictionary:
	return battle_state.start_round_combat()


func play_round_turn(target_id: String = "", ability_id: String = "") -> Dictionary:
	var result: Dictionary = battle_state.run_round_turn(target_id, ability_id)
	if bool(result.get("success", false)):
		sync_hero_results()
	return result


func sync_hero_results() -> void:
	for participant_id in battle_state.hero_ids():
		var fighter: BattleParticipant = battle_state.get_participant(participant_id)
		var member: HeroState = hero_sources.get(participant_id) as HeroState
		if fighter != null and member != null:
			fighter.commit_hero_result(member)
