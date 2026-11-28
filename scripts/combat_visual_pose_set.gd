class_name CombatVisualPoseSet
extends Resource

@export var idle: CombatVisualPose
@export var wind_up: CombatVisualPose
@export var strike: CombatVisualPose
@export var hurt: CombatVisualPose


func pose_for(state: StringName) -> CombatVisualPose:
	match state:
		&"idle":
			return idle
		&"wind_up":
			return wind_up
		&"strike":
			return strike
		&"hurt":
			return hurt
	return null
