class_name CombatVisualPose
extends Resource

@export var texture: Texture2D
@export var ground_anchor: Vector2 = Vector2(0.5, 1.0)
@export var hit_anchor: Vector2 = Vector2(0.5, 0.4)
@export var effect_anchor: Vector2 = Vector2(0.5, 0.4)
@export var contact_anchor: Vector2 = Vector2(-1.0, -1.0)
@export_range(0.1, 4.0, 0.01) var height_scale: float = 1.0
@export var embedded_slash: bool = false


func has_contact_anchor() -> bool:
	return contact_anchor.x >= 0.0 and contact_anchor.x <= 1.0 and contact_anchor.y >= 0.0 and contact_anchor.y <= 1.0


func rendered_size(reference_height: float) -> Vector2:
	if texture == null or texture.get_height() <= 0:
		return Vector2.ZERO
	var height: float = reference_height * height_scale
	return Vector2(height * float(texture.get_width()) / float(texture.get_height()), height)


static func point_offset(point: Vector2, size: Vector2, flip_h: bool) -> Vector2:
	return Vector2(1.0 - point.x if flip_h else point.x, point.y) * size
