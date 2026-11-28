class_name PendingInteraction
extends RefCounted

enum Kind { TRAP_CHOICE, TRAP_REACTION, DOOR_TRAP, PORTAL }

var id: int
var kind: Kind
var context: Dictionary
var actors: Array[HeroState] = []
var accepted: Array[String] = []
var opener: HeroState
var presentation: Dictionary = {}


func _init(interaction_id: int, interaction_kind: Kind, details: Dictionary) -> void:
	id = interaction_id
	kind = interaction_kind
	context = details


func allows(choice: String, actor_index: int) -> bool:
	if kind == Kind.DOOR_TRAP:
		return choice == "continue"
	if not presentation.get("choices", {}).has(choice) or choice in presentation.get("disabled_choices", []):
		return false
	return actor_index >= -1 and (actor_index <= 0 if actors.is_empty() else actor_index < actors.size())
