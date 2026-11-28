class_name GameActionResolver
extends RefCounted


static func execute(session: GameSession, action: GameAction) -> GameActionResult:
	var result := GameActionResult.new()
	result.previous_position = session.player_pos
	result.position = session.player_pos
	if action == null:
		return result
	if action.kind in [GameAction.Kind.BATTLE_PREPARE, GameAction.Kind.BATTLE_NEXT, GameAction.Kind.BATTLE_TURN, GameAction.Kind.BATTLE_MANUAL_PREPARE, GameAction.Kind.BATTLE_MANUAL_TICK, GameAction.Kind.BATTLE_ITEM]:
		return _execute_battle(session, action, result)
	if session.is_party_defeated() or session.has_pending_encounter():
		return result
	var previous_chests: Dictionary = session.opened_chests.duplicate()
	var pending: PendingInteraction = session.pending_interaction
	if pending != null:
		if action.kind != GameAction.Kind.CHOOSE or action.interaction_id != pending.id or not pending.allows(action.choice, action.actor_index):
			return result
	elif action.kind == GameAction.Kind.CHOOSE:
		return result
	if session.is_completed and action.kind not in [GameAction.Kind.ENTER_FLOOR, GameAction.Kind.CANCEL_EXIT]:
		return result
	match action.kind:
		GameAction.Kind.MOVE:
			if absi(action.direction.x) + absi(action.direction.y) != 1:
				return result
			result.moved = session.move_by(action.direction.x, action.direction.y)
			result.discovered_trap = session.last_move_detected_trap
			result.accepted = result.moved or result.discovered_trap or session.pending_interaction != null or session.has_pending_encounter()
		GameAction.Kind.CHOOSE:
			match pending.kind:
				PendingInteraction.Kind.TRAP_CHOICE, PendingInteraction.Kind.TRAP_REACTION:
					result.moved = session.resolve_pending_trap_choice(action.choice, action.actor_index)
				PendingInteraction.Kind.DOOR_TRAP:
					result.moved = session.resolve_pending_door_trap()
				PendingInteraction.Kind.PORTAL:
					result.moved = session.resolve_pending_portal_choice(action.choice)
			result.accepted = session.pending_interaction != pending
			if not result.accepted:
				return result
		GameAction.Kind.ENTER_FLOOR:
			if not session.can_enter_next_map(action.destination):
				return result
			result.accepted = session.enter_map(action.destination)
		GameAction.Kind.CANCEL_EXIT:
			if not session.is_completed:
				return result
			session.cancel_exit_transition()
			result.accepted = true
		GameAction.Kind.SWITCH_SLIDING_PLATES:
			result.accepted = session.activate_controlled_sliding_plates(action.target_id)
			if not result.accepted and session.last_event_message.is_empty():
				return result
		GameAction.Kind.USE_ITEM:
			result.item_result = session.use_item(action.item_id, action.recipient, action.bag_index)
			result.accepted = bool(result.item_result.get("used", false))
		GameAction.Kind.TRANSFER_ITEM:
			result.accepted = session.transfer_inventory_item(action.from_kind, action.from_slot, action.to_kind, action.to_slot)
		GameAction.Kind.SAVE_ARSENAL:
			result.accepted = action.recipient != null and session.party.has(action.recipient) and action.recipient.health > 0 and action.recipient.save_action_slots(action.chain)
		GameAction.Kind.TAKE_LOOT:
			result.amount = session.take_ground_loot(action.container_id, action.entry_index)
			result.accepted = result.amount > 0
	if action.kind in [GameAction.Kind.MOVE, GameAction.Kind.CHOOSE, GameAction.Kind.ENTER_FLOOR, GameAction.Kind.SWITCH_SLIDING_PLATES]:
		_collect_exploration_result(session, result, previous_chests if action.kind != GameAction.Kind.ENTER_FLOOR else session.opened_chests)
	else:
		_set_status(session, result)
	return result


static func _collect_exploration_result(session: GameSession, result: GameActionResult, previous_chests: Dictionary) -> void:
	for chest_id in session.opened_chests:
		if not previous_chests.has(chest_id):
			result.opened_chest_ids.append(str(chest_id))
	result.position = session.player_pos
	result.terrain_changes = session.take_terrain_changes()
	result.stop_movement = not result.terrain_changes.is_empty() or (result.moved and session.is_on_controlled_sliding_plates())
	result.messages = session.take_message_events()
	result.triggers = session.take_trigger_events()
	result.trap_visuals = session.take_trap_visual_events()
	result.damage = session.take_party_damage_events()
	result.casualties = session.take_casualty_events()
	result.trap_result = session.take_trap_result_message()
	result.message = session.last_event_message
	if session.has_pending_encounter() and not session.is_party_defeated() and session.active_combat == null:
		var monsters: Array[MonsterDefinition] = MonsterCatalog.normalize_legacy_encounter(session.pending_monster_definitions())
		session.active_combat = CombatSession.for_encounter(monsters, session.hero, session.trap_random.randi(), session.party)
	_set_status(session, result)


static func _set_status(session: GameSession, result: GameActionResult) -> void:
	if session.is_party_defeated():
		result.status = GameActionResult.Status.SESSION_DEFEATED
	elif session.pending_interaction != null:
		result.status = GameActionResult.Status.AWAITING_INPUT
		result.interaction_id = session.pending_interaction.id
	elif session.has_pending_encounter():
		result.status = GameActionResult.Status.BATTLE_STARTED
	elif session.is_completed:
		result.status = GameActionResult.Status.SESSION_COMPLETED if session.next_map_id().is_empty() else GameActionResult.Status.FLOOR_EXIT
	elif result.accepted:
		result.status = GameActionResult.Status.COMPLETED


static func _execute_battle(session: GameSession, action: GameAction, result: GameActionResult) -> GameActionResult:
	var combat: CombatSession = session.active_combat
	if combat == null or not session.has_pending_encounter():
		return result
	match action.kind:
		GameAction.Kind.BATTLE_PREPARE:
			result.battle_result = combat.prepare_round_combat()
		GameAction.Kind.BATTLE_NEXT:
			if not combat.battle_state.round_combat_active:
				return result
			result.battle_next_actor = combat.battle_state.prepare_next_round()
			result.battle_result = {"success": true}
		GameAction.Kind.BATTLE_TURN:
			result.battle_result = combat.play_round_turn(action.target_id, action.ability_id)
		GameAction.Kind.BATTLE_MANUAL_PREPARE:
			result.battle_result = combat.prepare_manual_combat(action.chain)
		GameAction.Kind.BATTLE_MANUAL_TICK:
			result.battle_result = combat.play_manual_tick(action.slot_index, action.target_id)
		GameAction.Kind.BATTLE_ITEM:
			result.item_result = session.use_combat_item(action.item_id, combat.battle_state)
			result.accepted = bool(result.item_result.get("used", false))
			if result.accepted:
				result.status = GameActionResult.Status.BATTLE_ACTIVE
			return result
	result.accepted = bool(result.battle_result.get("success", false))
	if action.kind == GameAction.Kind.BATTLE_NEXT or combat.is_victory or combat.is_defeat:
		combat.sync_hero_results()
	for actor_id in combat.hero_sources:
		var member: HeroState = combat.hero_sources[actor_id]
		if not member.last_shield_broken.is_empty():
			session.resolve_broken_shield(member)
			var fighter: BattleParticipant = combat.battle_state.get_participant(actor_id)
			if fighter != null and fighter._hero_snapshot != null:
				fighter._hero_snapshot.last_shield_broken = ""
				fighter._hero_snapshot.equipped_instance_ids.erase("off_hand")
	if combat.is_victory or combat.is_defeat:
		var previous_chests: Dictionary = session.opened_chests.duplicate()
		result.battle_finished = true
		result.accepted = true
		session.active_combat = null
		if combat.is_victory:
			result.moved = session.win_pending_encounter(combat.battle_state)
			result.discovered_trap = session.last_move_detected_trap
		else:
			session.record_casualties()
			session.abandon_pending_encounter()
		_collect_exploration_result(session, result, previous_chests)
	elif result.accepted:
		result.status = GameActionResult.Status.BATTLE_ACTIVE
	return result
