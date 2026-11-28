class_name GameActionResult
extends RefCounted

enum Status { COMPLETED, REJECTED, AWAITING_INPUT, BATTLE_STARTED, BATTLE_ACTIVE, FLOOR_EXIT, SESSION_COMPLETED, SESSION_DEFEATED }

var status: Status = Status.REJECTED
var accepted: bool = false
var previous_position: Vector2i
var position: Vector2i
var moved: bool = false
var terrain_changes: Dictionary = {}
var discovered_trap: bool = false
var stop_movement: bool = false
var interaction_id: int = 0
var opened_chest_ids: Array[String] = []
var messages: Array[Dictionary] = []
var triggers: Array[Dictionary] = []
var trap_visuals: Array[Dictionary] = []
var damage: Array[Dictionary] = []
var casualties: Array[HeroState] = []
var trap_result: String = ""
var message: String = ""
var item_result: Dictionary = {}
var amount: int = 0
var battle_result: Dictionary = {}
var battle_next_actor: String = ""
var battle_finished: bool = false
