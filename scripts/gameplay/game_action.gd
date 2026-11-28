class_name GameAction
extends RefCounted

enum Kind { MOVE, CHOOSE, ENTER_FLOOR, CANCEL_EXIT, USE_ITEM, TRANSFER_ITEM, TAKE_LOOT, SAVE_ARSENAL, BATTLE_PREPARE, BATTLE_NEXT, BATTLE_TURN, BATTLE_MANUAL_PREPARE, BATTLE_MANUAL_TICK, BATTLE_ITEM, SWITCH_SLIDING_PLATES }

var kind: Kind
var direction: Vector2i
var interaction_id: int
var choice: String
var actor_index: int = -1
var destination: DungeonMap
var item_id: String
var recipient: HeroState
var bag_index: int = -1
var from_kind: String
var from_slot: Variant
var to_kind: String
var to_slot: Variant
var container_id: String
var entry_index: int
var target_id: String
var ability_id: String
var chain: Array[String] = []
var slot_index: int


static func switch_sliding_plates(trigger_id: String) -> GameAction:
	var action := GameAction.new(Kind.SWITCH_SLIDING_PLATES)
	action.target_id = trigger_id
	return action


func _init(action_kind: Kind) -> void:
	kind = action_kind


static func move(delta: Vector2i) -> GameAction:
	var action := GameAction.new(Kind.MOVE)
	action.direction = delta
	return action


static func choose(id: int, option: String, actor: int = -1) -> GameAction:
	var action := GameAction.new(Kind.CHOOSE)
	action.interaction_id = id
	action.choice = option
	action.actor_index = actor
	return action


static func enter_floor(map_ref: DungeonMap) -> GameAction:
	var action := GameAction.new(Kind.ENTER_FLOOR)
	action.destination = map_ref
	return action


static func cancel_exit() -> GameAction:
	return GameAction.new(Kind.CANCEL_EXIT)


static func use_item(id: String, member: HeroState, index: int) -> GameAction:
	var action := GameAction.new(Kind.USE_ITEM)
	action.item_id = id
	action.recipient = member
	action.bag_index = index
	return action


static func transfer_item(source_kind: String, source: Variant, target_kind: String, target: Variant) -> GameAction:
	var action := GameAction.new(Kind.TRANSFER_ITEM)
	action.from_kind = source_kind
	action.from_slot = source
	action.to_kind = target_kind
	action.to_slot = target
	return action


static func take_loot(id: String, index: int) -> GameAction:
	var action := GameAction.new(Kind.TAKE_LOOT)
	action.container_id = id
	action.entry_index = index
	return action


static func battle_turn(target: String, ability: String) -> GameAction:
	var action := GameAction.new(Kind.BATTLE_TURN)
	action.target_id = target
	action.ability_id = ability
	return action


static func battle_manual_prepare(actions: Array[String]) -> GameAction:
	var action := GameAction.new(Kind.BATTLE_MANUAL_PREPARE)
	action.chain = actions.duplicate()
	return action


static func battle_manual_tick(index: int, target: String) -> GameAction:
	var action := GameAction.new(Kind.BATTLE_MANUAL_TICK)
	action.slot_index = index
	action.target_id = target
	return action


static func battle_item(id: String) -> GameAction:
	var action := GameAction.new(Kind.BATTLE_ITEM)
	action.item_id = id
	return action


static func save_arsenal(member: HeroState, slots: Array[String]) -> GameAction:
	var action := GameAction.new(Kind.SAVE_ARSENAL)
	action.recipient = member
	action.chain = slots.duplicate()
	return action
