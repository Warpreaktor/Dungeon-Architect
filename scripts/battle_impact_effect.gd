class_name BattleImpactEffect
extends Node2D

var profile: BattleImpactProfile
var elapsed: float = 0.0
var radius: float
var direction: float
var show_slash: bool
var missed: bool
var blocked: bool
var penetrated: bool
var critical: bool
var intensity: float
var _sound: AudioStreamPlayer


func configure(config: BattleImpactProfile, event: Dictionary, point: Vector2, slash_direction: float,
		reference_height: float, allow_slash: bool) -> void:
	profile = config
	position = point
	z_index = 5
	intensity = profile.intensity_for(event)
	radius = maxf(1.0, reference_height * profile.radius_fraction * intensity)
	direction = -1.0 if slash_direction < 0.0 else 1.0
	missed = BattleImpactProfile.is_miss(event)
	blocked = BattleImpactProfile.is_block(event)
	penetrated = blocked and BattleImpactProfile.hp_damage(event) > 0
	critical = BattleImpactProfile.is_critical(event)
	show_slash = allow_slash and profile.slash_enabled
	var stream: AudioStream = profile.sound_for(event)
	if stream != null:
		_sound = AudioStreamPlayer.new()
		_sound.bus = &"SFX"
		_sound.stream = stream
		_sound.volume_db = profile.sound_volume_db
		add_child(_sound)
		if DisplayServer.get_name() != "headless":
			_sound.play()
	advance(0.0)


func advance(seconds: float) -> void:
	elapsed = maxf(seconds, 0.0)
	queue_redraw()


func shake_offset(reference_height: float) -> Vector2:
	if missed or profile == null:
		return Vector2.ZERO
	var progress: float = clampf(elapsed / profile.effect_seconds, 0.0, 1.0)
	var envelope: float = pow(1.0 - progress, 2.0)
	return Vector2(sin(progress * TAU * 3.0), sin(progress * TAU * 4.0)) * reference_height * profile.shake_fraction * intensity * envelope


func stop_sound() -> void:
	if is_instance_valid(_sound):
		_sound.stop()
		_sound.stream = null


func _draw() -> void:
	if profile == null:
		return
	var t: float = clampf(elapsed / profile.effect_seconds, 0.0, 1.0)
	if t >= 1.0:
		return
	if show_slash:
		_draw_slash(t)
	if missed:
		return
	if blocked:
		_draw_guard(t)
	var ink: Color = profile.critical_color if critical else profile.hit_color
	if blocked and not penetrated:
		ink = profile.block_color
	var flash: float = pow(1.0 - t, 3.0)
	var center_size: float = radius * (0.12 + 0.22 * t)
	draw_circle(Vector2.ZERO, center_size * 1.7, Color(ink, flash * 0.24))
	draw_circle(Vector2.ZERO, center_size, Color(ink.lerp(Color.WHITE, 0.8), flash * 0.9))
	draw_arc(Vector2.ZERO, radius * (0.18 + 0.58 * t), 0.0, TAU, 32, Color(ink, flash * 0.75), maxf(1.0, radius * 0.035), true)
	for i in range(roundi(profile.particle_count * intensity)):
		var angle: float = float(i) * 2.399963 + 0.35
		var vector := Vector2(cos(angle), sin(angle))
		var speed: float = 0.55 + float((i * 7) % 11) / 12.0
		var distance: float = radius * (0.18 + t * speed)
		var tail: float = radius * (0.11 + 0.12 * speed) * (1.0 - t)
		draw_line(vector * maxf(0.0, distance - tail), vector * distance, Color(ink.lerp(Color.WHITE, 0.45), (1.0 - t) * 0.95), maxf(1.0, radius * 0.045 * (1.0 - t)), true)


func _draw_guard(t: float) -> void:
	var fade: float = pow(1.0 - t, 2.0)
	var ink := Color(profile.block_color, fade * 0.95)
	var guard := PackedVector2Array([
		Vector2(-0.42, -0.42), Vector2(0.0, -0.58), Vector2(0.42, -0.42),
		Vector2(0.34, 0.16), Vector2(0.0, 0.46), Vector2(-0.34, 0.16), Vector2(-0.42, -0.42)])
	for i in range(guard.size()):
		guard[i] *= radius * (1.0 + t * 0.45)
	if penetrated:
		draw_polyline(guard.slice(0, 4), ink, maxf(1.0, radius * 0.045), true)
		draw_polyline(guard.slice(4), ink, maxf(1.0, radius * 0.045), true)
	else:
		draw_polyline(guard, ink, maxf(1.0, radius * 0.045), true)


func _draw_slash(t: float) -> void:
	var fade: float = pow(1.0 - t, 2.0)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var sweep: float = 2.3
	for i in range(25):
		var u: float = float(i) / 24.0
		var angle: float = -1.15 + u * sweep
		var vector := Vector2(cos(angle) * direction, sin(angle))
		var width: float = (0.008 + sin(u * PI) * 0.20) * radius
		var length: float = radius * (1.0 + 0.16 * t)
		var center := Vector2(-direction * radius * 0.65, 0.0)
		outer.append(center + vector * length)
		inner.append(center + vector * (length - width))
	inner.reverse()
	outer.append_array(inner)
	draw_colored_polygon(outer, Color(profile.slash_color, fade * 0.8))
