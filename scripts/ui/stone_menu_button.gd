class_name StoneMenuButton
extends Button

const STONE := preload("res://assets/ui/stone_menu_button.png")
const GLOW_SHADER := preload("res://shaders/stone_menu_button.gdshader")
const ASH_DUST := preload("res://scripts/ui/menu_button_ash.gd")
const SPARK := preload("res://assets/effects/fire_spark.png")
const MIN_TOUCH_HEIGHT := 48.0
const MAX_HEIGHT := 88.0
const FRAME_POINTS := [
	Vector2(0.10, 0.12), Vector2(0.18, 0.12), Vector2(0.26, 0.12),
	Vector2(0.34, 0.12), Vector2(0.42, 0.12), Vector2(0.50, 0.08),
	Vector2(0.58, 0.12), Vector2(0.66, 0.12), Vector2(0.74, 0.12),
	Vector2(0.82, 0.12), Vector2(0.90, 0.12), Vector2(0.055, 0.50),
	Vector2(0.945, 0.50), Vector2(0.18, 0.87), Vector2(0.34, 0.87),
	Vector2(0.50, 0.92), Vector2(0.66, 0.87), Vector2(0.82, 0.87)
]

var _stone: TextureRect
var _glow: ShaderMaterial
var _sparks: CPUParticles2D
var _highlight := 0.0
var _held := false
var _touch_mode := false
var _keyboard_mode := true
var _ash_dust: ASH_DUST
var _ash_burn := 0.0
var _ash_scatter := 0.0


func _ready() -> void:
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 22.0
	empty.content_margin_right = 22.0
	empty.content_margin_top = 8.0
	empty.content_margin_bottom = 8.0
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style_name, empty)
	add_theme_color_override("font_color", Color(0.96, 0.90, 0.77))
	add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.80))
	add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.78))
	add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.60))
	add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.88, 0.60))
	add_theme_color_override("font_disabled_color", Color(0.61, 0.60, 0.57))
	add_theme_color_override("font_outline_color", Color(0.09, 0.06, 0.04, 0.90))
	add_theme_constant_override("outline_size", 4)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_stone = TextureRect.new()
	_stone.name = "StoneArtwork"
	_stone.texture = STONE
	_stone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stone.show_behind_parent = true
	_glow = ShaderMaterial.new()
	_glow.shader = GLOW_SHADER
	_stone.material = _glow
	add_child(_stone)
	_stone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sparks = _create_sparks()
	add_child(_sparks)
	button_down.connect(func() -> void: _held = true)
	button_up.connect(func() -> void: _held = false)
	focus_exited.connect(func() -> void: _held = false)
	resized.connect(_layout_artwork)
	visibility_changed.connect(_sync_visibility)
	_layout_artwork()
	_sync_visibility()


func _input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_mode = true
		_keyboard_mode = false
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		_touch_mode = false
		_keyboard_mode = false
	elif event is InputEventKey or event is InputEventJoypadButton:
		_touch_mode = false
		_keyboard_mode = true


func _process(delta: float) -> void:
	var hovering: bool = not _touch_mode and is_hovered()
	var focused: bool = _keyboard_mode and has_focus()
	var active: bool = is_zero_approx(_ash_burn) and not disabled and (_held or hovering or focused)
	var target: float = 1.0 if active else 0.0
	_highlight = move_toward(_highlight, target, delta * (7.0 if active else 4.0))
	_glow.set_shader_parameter("highlight", _highlight)
	_glow.set_shader_parameter("pressed", 1.0 if _held and not disabled else 0.0)
	_glow.set_shader_parameter("disabled", 1.0 if disabled else 0.0)
	var emit_sparks: bool = is_zero_approx(_ash_burn) and not disabled and (_held or hovering)
	if _sparks.emitting != emit_sparks:
		_sparks.emitting = emit_sparks


func _sync_visibility() -> void:
	var shown: bool = is_visible_in_tree()
	set_process(shown)
	if not shown:
		_held = false
		_highlight = 0.0
		_glow.set_shader_parameter("highlight", 0.0)
		_glow.set_shader_parameter("pressed", 0.0)
		_sparks.emitting = false


func _layout_artwork() -> void:
	var aspect: float = STONE.get_size().aspect()
	var desired_height: float = clampf(ceilf(size.x / aspect), MIN_TOUCH_HEIGHT, MAX_HEIGHT)
	if not is_equal_approx(custom_minimum_size.y, desired_height):
		custom_minimum_size.y = desired_height
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var bounds: Rect2 = _artwork_bounds()
	var drawn_size: Vector2 = bounds.size
	var origin: Vector2 = bounds.position
	_glow.set_shader_parameter("artwork_size", drawn_size)
	if is_instance_valid(_ash_dust):
		_ash_dust.show_phase(bounds, _ash_burn, _ash_scatter)
	var points := PackedVector2Array()
	for point: Vector2 in FRAME_POINTS:
		points.append(origin + drawn_size * point)
	_sparks.emission_points = points


func _artwork_bounds() -> Rect2:
	var drawn_size: Vector2 = STONE.get_size() * minf(size.x / STONE.get_width(), size.y / STONE.get_height())
	return Rect2((size - drawn_size) * 0.5, drawn_size)


func set_ash_phase(burn: float, scatter: float) -> void:
	_ash_burn = clampf(burn, 0.0, 1.0)
	_ash_scatter = clampf(scatter, 0.0, 1.0)
	_glow.set_shader_parameter("burn", _ash_burn)
	self_modulate.a = 1.0 - smoothstep(0.32, 0.68, _ash_burn)
	if _ash_burn > 0.0:
		_held = false
		_sparks.emitting = false
		_sparks.hide()
		if not is_instance_valid(_ash_dust):
			_ash_dust = ASH_DUST.new()
			_ash_dust.name = "AshDust"
			add_child(_ash_dust)
			_ash_dust.prepare(STONE)
		_ash_dust.show_phase(_artwork_bounds(), _ash_burn, _ash_scatter)
	else:
		_sparks.show()
		if is_instance_valid(_ash_dust):
			_ash_dust.show_phase(_artwork_bounds(), 0.0, 0.0)


func _create_sparks() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "FrameSparks"
	particles.emitting = false
	particles.amount = 12
	particles.lifetime = 0.85
	particles.lifetime_randomness = 0.35
	particles.randomness = 0.8
	particles.local_coords = true
	particles.texture = SPARK
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	particles.emission_points = PackedVector2Array([Vector2.ZERO])
	particles.direction = Vector2(0.12, -1.0)
	particles.spread = 38.0
	particles.gravity = Vector2(0.0, -7.0)
	particles.initial_velocity_min = 9.0
	particles.initial_velocity_max = 23.0
	particles.particle_flag_align_y = true
	particles.scale_amount_min = 0.09
	particles.scale_amount_max = 0.19
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.16, 0.6, 1.0])
	colors.colors = PackedColorArray([
		Color(1.0, 0.89, 0.60, 0.0), Color(1.0, 0.92, 0.64, 1.0),
		Color(1.0, 0.53, 0.13, 0.8), Color(0.8, 0.26, 0.06, 0.0)
	])
	particles.color_ramp = colors
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = additive
	return particles
