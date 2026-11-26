class_name AbilityIconStyle
extends Resource

@export var monster_ids: Array[String] = []
@export var frame: Texture2D
@export var boss_frame: Texture2D
@export var background: Texture2D
@export var attack_glow: Color = Color.TRANSPARENT
@export_file("*.png") var frame_path: String = ""
@export_file("*.png") var boss_frame_path: String = ""


func frame_for_rank(rank: int) -> Texture2D:
	if rank == MonsterDefinition.Rank.BOSS:
		var special: Texture2D = _texture_or_path(boss_frame, boss_frame_path)
		if special != null:
			return special
	return _texture_or_path(frame, frame_path)


func _texture_or_path(texture: Texture2D, path: String) -> Texture2D:
	if texture != null:
		return texture
	if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
		return ResourceLoader.load(path, "Texture2D") as Texture2D
	return null
