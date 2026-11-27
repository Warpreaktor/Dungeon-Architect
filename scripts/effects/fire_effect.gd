class_name FireEffect
extends Node2D

@export var flame_size: Vector2 = Vector2(88.0, 112.0)
@export var glow_size: Vector2 = Vector2(210.0, 140.0)
@export var ember_amount: int = 26
@export var smoke_amount: int = 10
@export var intensity: float = 1.0:
	set(value):
		intensity = maxf(0.0, value)
		_apply_intensity()
@export var flicker_speed: float = 1.45
@export var flame_speed: float = 1.2
@export var flame_sway: float = 0.22

var _flame: Sprite2D
var _glow: Sprite2D
var _ground_glow: Sprite2D
var _embers: GPUParticles2D
var _smoke: GPUParticles2D
var _flame_material: ShaderMaterial
var _time: float = 0.0
var _seed: float = randf_range(0.0, 1000.0)


func _ready() -> void:
	_build_once()
	_apply_intensity()
	set_process(true)


func _process(delta: float) -> void:
	if _flame == null:
		return
	_time += delta
	var pulse: float = 0.92 + sin(_time * flicker_speed + _seed) * 0.05 + sin(_time * (flicker_speed * 2.3) + _seed * 0.37) * 0.035
	var current_intensity: float = intensity * pulse
	_glow.modulate.a = 0.36 * current_intensity
	_ground_glow.modulate.a = 0.32 * current_intensity
	_glow.scale = glow_size / 128.0 * Vector2(1.0 + current_intensity * 0.08, 1.0 + current_intensity * 0.04)
	_ground_glow.scale = Vector2(glow_size.x * 0.85, glow_size.y * 0.55) / 128.0 * Vector2(1.0 + current_intensity * 0.05, 1.0)
	_flame.scale = flame_size * Vector2(1.0 + sin(_time * (flicker_speed * 1.7) + _seed * 0.71) * 0.015, 1.0 + sin(_time * (flicker_speed * 1.1) + _seed * 0.13) * 0.03)
	_flame_material.set_shader_parameter("intensity", current_intensity)


func _build_once() -> void:
	if _flame != null:
		return
	_glow = _build_glow_sprite(Color(1.0, 0.68, 0.28, 0.32), Vector2(0.0, -42.0), Vector2(glow_size.x, glow_size.y))
	_ground_glow = _build_glow_sprite(Color(1.0, 0.55, 0.18, 0.24), Vector2(0.0, -4.0), Vector2(glow_size.x * 0.85, glow_size.y * 0.55))
	add_child(_ground_glow)
	add_child(_glow)
	_flame = Sprite2D.new()
	_flame.centered = true
	_flame.texture = _solid_texture()
	_flame.position = Vector2(0.0, -flame_size.y * 0.52)
	_flame.z_index = 1
	_flame.scale = flame_size
	_flame_material = ShaderMaterial.new()
	_flame_material.shader = load("res://shaders/procedural_fire.gdshader") as Shader
	_flame_material.set_shader_parameter("phase", _seed)
	_flame_material.set_shader_parameter("speed", flame_speed)
	_flame_material.set_shader_parameter("sway", flame_sway)
	_flame.material = _flame_material
	add_child(_flame)
	if ember_amount > 0:
		_embers = _build_ember_particles()
		add_child(_embers)
	if smoke_amount > 0:
		_smoke = _build_smoke_particles()
		add_child(_smoke)


func _apply_intensity() -> void:
	visible = intensity > 0.01
	if _flame == null:
		return
	if _embers != null:
		_embers.amount = maxi(1, int(round(ember_amount * maxf(0.2, intensity))))
		_embers.emitting = intensity > 0.01
	if _smoke != null:
		_smoke.amount = maxi(1, int(round(smoke_amount * maxf(0.2, intensity))))
		_smoke.emitting = intensity > 0.01


func _build_glow_sprite(color: Color, position_offset: Vector2, pixel_size: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture = _radial_texture(128)
	sprite.position = position_offset
	sprite.modulate = color
	sprite.scale = pixel_size / 128.0
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = material
	return sprite


func _build_ember_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.z_index = 3
	particles.local_coords = true
	particles.position = Vector2(0.0, -10.0)
	particles.amount = ember_amount
	particles.lifetime = 1.25
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.45
	particles.texture = _soft_circle_texture(32, Color(1.0, 0.82, 0.45, 1.0))
	particles.visibility_rect = Rect2(-90.0, -160.0, 180.0, 220.0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(16.0, 4.0, 1.0)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 24.0
	process.gravity = Vector3(0.0, -12.0, 0.0)
	process.initial_velocity_min = 42.0
	process.initial_velocity_max = 72.0
	process.scale_min = 0.12
	process.scale_max = 0.3
	process.angular_velocity_min = -30.0
	process.angular_velocity_max = 30.0
	process.color_ramp = _ember_ramp()
	particles.process_material = process
	particles.emitting = true
	return particles


func _build_smoke_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.z_index = 2
	particles.local_coords = true
	particles.position = Vector2(0.0, -28.0)
	particles.amount = smoke_amount
	particles.lifetime = 2.4
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.55
	particles.texture = _soft_circle_texture(48, Color(0.88, 0.88, 0.92, 1.0))
	particles.visibility_rect = Rect2(-110.0, -220.0, 220.0, 260.0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(12.0, 4.0, 1.0)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 16.0
	process.gravity = Vector3(0.0, -8.0, 0.0)
	process.initial_velocity_min = 18.0
	process.initial_velocity_max = 28.0
	process.scale_min = 0.28
	process.scale_max = 0.55
	process.radial_accel_min = -3.0
	process.radial_accel_max = 3.0
	process.angle_min = -8.0
	process.angle_max = 8.0
	process.color_ramp = _smoke_ramp()
	particles.process_material = process
	particles.emitting = true
	return particles


func _solid_texture() -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _radial_texture(size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_radius := size * 0.5
	for y in size:
		for x in size:
			var distance := center.distance_to(Vector2(x + 0.5, y + 0.5)) / max_radius
			var alpha := clampf(1.0 - distance, 0.0, 1.0)
			alpha = pow(alpha, 2.2)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _soft_circle_texture(size: int, color: Color) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_radius := size * 0.5
	for y in size:
		for x in size:
			var distance := center.distance_to(Vector2(x + 0.5, y + 0.5)) / max_radius
			var alpha := clampf(1.0 - distance, 0.0, 1.0)
			alpha = pow(alpha, 1.8)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha * color.a))
	return ImageTexture.create_from_image(image)


func _ember_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.92, 0.72, 0.0),
		Color(1.0, 0.88, 0.56, 0.95),
		Color(1.0, 0.52, 0.18, 0.7),
		Color(0.35, 0.1, 0.05, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.68, 1.0])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _smoke_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.75, 0.72, 0.68, 0.0),
		Color(0.56, 0.55, 0.58, 0.28),
		Color(0.22, 0.23, 0.27, 0.12),
		Color(0.10, 0.12, 0.15, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.72, 1.0])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture
