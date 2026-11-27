class_name HeroMapAnimation
extends RefCounted

var frames: SpriteFrames
var facing := Vector2i.DOWN
var animation: StringName = &"idle_down"
var frame_index: int = 0
var mirrored: bool = false
var _walking: bool = false
var _elapsed: float = 0.0


func configure(value: SpriteFrames) -> bool:
	if frames == value:
		return false
	frames = value
	_select_animation()
	return true


func start_walk(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		if absf(direction.x) > absf(direction.y):
			facing = Vector2i.RIGHT if direction.x > 0.0 else Vector2i.LEFT
		else:
			facing = Vector2i.DOWN if direction.y > 0.0 else Vector2i.UP
	_walking = true
	_select_animation()


func stop_walk() -> void:
	if not _walking:
		return
	_walking = false
	_select_animation()


func _select_animation() -> void:
	var suffix: String = "down"
	match facing:
		Vector2i.UP:
			suffix = "up"
		Vector2i.RIGHT:
			suffix = "right"
		Vector2i.LEFT:
			suffix = "left"
	var prefix: String = "walk_" if _walking else "idle_"
	var next := StringName(prefix + suffix)
	mirrored = false
	if frames != null and facing == Vector2i.LEFT and not frames.has_animation(next):
		next = StringName(prefix + "right")
		mirrored = true
	animation = next
	frame_index = 0
	_elapsed = 0.0


func texture() -> Texture2D:
	if frames == null or not frames.has_animation(animation):
		return null
	if frame_index >= frames.get_frame_count(animation):
		return null
	return frames.get_frame_texture(animation, frame_index)


func advance(delta: float) -> bool:
	if frames == null or not frames.has_animation(animation):
		return false
	var count: int = frames.get_frame_count(animation)
	var speed: float = frames.get_animation_speed(animation)
	if count <= 1 or speed <= 0.0:
		return false
	if frame_index >= count:
		frame_index = 0
	var previous: int = frame_index
	_elapsed += maxf(delta, 0.0)
	var duration: float = maxf(frames.get_frame_duration(animation, frame_index) / speed, 0.001)
	while _elapsed >= duration:
		_elapsed -= duration
		if frame_index == count - 1 and not frames.get_animation_loop(animation):
			_elapsed = 0.0
			break
		frame_index = (frame_index + 1) % count
		duration = maxf(frames.get_frame_duration(animation, frame_index) / speed, 0.001)
	return previous != frame_index
