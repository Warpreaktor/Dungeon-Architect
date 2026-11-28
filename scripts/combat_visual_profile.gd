class_name CombatVisualProfile
extends CombatVisualPoseSet

@export var faces_right: bool = true
@export_range(0.1, 4.0, 0.01) var display_scale: float = 1.0
@export var ability_poses: Dictionary[String, CombatVisualPoseSet] = {}


func resolve_pose(state: StringName, ability_id: String = "") -> CombatVisualPose:
	var override_set: CombatVisualPoseSet = ability_poses.get(ability_id)
	if override_set != null:
		var override_pose: CombatVisualPose = override_set.pose_for(state)
		if override_pose != null and override_pose.texture != null:
			return override_pose
	var pose: CombatVisualPose = pose_for(state)
	if pose != null and pose.texture != null:
		return pose
	return idle if idle != null and idle.texture != null else null


func should_flip(face_right: bool) -> bool:
	return faces_right != face_right


static func texture_for(profile: CombatVisualProfile, portrait: Texture2D,
		state: StringName = &"idle", ability_id: String = "") -> Texture2D:
	if profile != null:
		var pose: CombatVisualPose = profile.resolve_pose(state, ability_id)
		if pose != null:
			return pose.texture
	return portrait
