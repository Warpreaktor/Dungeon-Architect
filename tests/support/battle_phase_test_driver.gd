class_name BattlePhaseTestDriver
extends RefCounted


static func run_phase(battle: BattleState, hero_actions: Array[String], enemy_actions: Array[String]) -> Dictionary:
    var hero: BattleParticipant = battle.get_hero()
    var enemy: BattleParticipant = battle.get_enemy()
    if hero == null or enemy == null:
        return {"success": false, "events": []}
    if enemy.action_chain.is_empty() and battle.flow.stage == BattleFlow.Stage.PREPARATION:
        enemy.action_chain = enemy_actions.duplicate()
    if enemy.action_chain.is_empty() or enemy.action_chain.size() > enemy.action_slot_capacity:
        return {"success": false, "events": []}
    if not battle.manual_combat_active:
        var ready: Dictionary = battle.prepare_manual_combat(hero_actions)
        if not bool(ready.get("success", false)):
            return ready
    elif hero.action_chain != hero_actions:
        var configured: Dictionary = battle.configure_hero_chain(hero_actions)
        if not bool(configured.get("success", false)):
            return configured
    var phase_events: Array[Dictionary] = []
    var first_phase: int = hero.completed_phases
    var ticks: int = 0
    for slot in range(hero_actions.size() + 1):
        if battle.is_defeat or battle.flow.stage == BattleFlow.Stage.FINISHED:
            break
        var is_rest: bool = slot == hero_actions.size() or battle.is_victory
        var slot_index: int = -1 if is_rest else slot
        var target_id: String = ""
        if not is_rest:
            var definition: AbilityDefinition = AbilityCatalog.get_ability(hero_actions[slot])
            var context: BattleContext = battle.create_context()
            var options: Array[String] = context.target_ids(battle.hero_id, definition)
            if options.is_empty():
                return {"success": false, "events": phase_events, "reason": "Нет допустимой цели"}
            var clash: Dictionary = BattleClashPlanner.next_opponent(battle.participants, battle.enemy_ids(), battle.next_enemy_clash_cursor)
            var opponent_id: String = str(clash.get("actor_id", ""))
            target_id = opponent_id if options.has(opponent_id) else options[0]
        var result: Dictionary = battle.run_manual_tick(slot_index, target_id)
        if not bool(result.get("success", false)):
            return result
        if bool(result.get("tick_performed", false)):
            ticks += 1
        phase_events.append_array(result.get("events", []))
        if hero.completed_phases > first_phase:
            break
    battle.last_phase_events = phase_events
    return {"success": true, "events": phase_events, "finished": battle.flow.stage == BattleFlow.Stage.FINISHED,
        "phase_number": battle.flow.phase_number, "hero_hp": hero.health, "ticks": ticks}


static func play_phase(combat: CombatSession, hero_actions: Array[String], enemy_actions: Array[String]) -> Dictionary:
    var result: Dictionary = run_phase(combat.battle_state, hero_actions, enemy_actions)
    if bool(result.get("success", false)):
        combat.battle_state.get_hero().commit_hero_result(combat.hero)
    return result
