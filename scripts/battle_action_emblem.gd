class_name BattleActionEmblem
extends Control

enum Effect { ATTACK, DEFENSE, BUFF, CURSE, HEAL }

const ICON_SCENE: PackedScene = preload("res://scenes/ability_icon.tscn")
const COLORS: Dictionary = {
	Effect.ATTACK: Color("f6bb76"), Effect.DEFENSE: Color("68bdf4"),
	Effect.BUFF: Color("e3cb79"), Effect.CURSE: Color("bf89ef"),
	Effect.HEAL: Color("77df98")
}

var _icon: AbilityIcon
var _caption: Label
var _effect: Effect = Effect.ATTACK
var _ink: Color
var _panel: StyleBoxFlat
var _progress: float = 0.0
var _icon_side: float
var _bounds: Vector2
var _source: TextureRect


static func effect_for(ability: AbilityDefinition) -> Effect:
	if ability == null:
		return Effect.ATTACK
	if ability.category == AbilityDefinition.Category.ATTACK:
		return Effect.ATTACK
	if ability.category == AbilityDefinition.Category.DEFENSE:
		return Effect.DEFENSE
	for effect in ability.effects:
		if effect != null and effect.kind in [AbilityEffectDefinition.Kind.DAMAGE, AbilityEffectDefinition.Kind.DELAYED_DAMAGE]:
			return Effect.ATTACK
	for effect in ability.effects:
		if effect == null:
			continue
		if effect.kind == AbilityEffectDefinition.Kind.HEAL:
			return Effect.HEAL
		if effect.kind == AbilityEffectDefinition.Kind.APPLY_STATUS and ability.target == AbilityDefinition.Target.ENEMY:
			return Effect.CURSE
	return Effect.BUFF


func configure(ability: AbilityDefinition, actor: BattleParticipant, source: TextureRect, bounds: Vector2, fallback_name: String = "Атака", fallback_art: Texture2D = BattleAbilitySlot.ATTACK_ICON, fallback_effect: Effect = Effect.ATTACK) -> void:
	_source = source
	_bounds = bounds
	_effect = effect_for(ability) if ability != null else fallback_effect
	_ink = COLORS[_effect]
	var style: AbilityIconStyle = AbilityIconCatalog.style_for_actor(actor)
	if _effect == Effect.ATTACK and style != null and style.attack_glow.a > 0.0:
		_ink = style.attack_glow
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(0.045, 0.065, 0.09, 0.94)
	_panel.border_color = _ink.darkened(0.45)
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(7)
	_icon = ICON_SCENE.instantiate() as AbilityIcon
	add_child(_icon)
	if ability != null:
		_icon.configure_ability(ability, actor)
	else:
		var fallback := AbilityDefinition.new()
		fallback.icon_art = fallback_art
		_icon.configure_ability(fallback, actor)
	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.text = ability.display_name if ability != null else fallback_name
	_caption.add_theme_color_override("font_color", Color("f2eee5"))
	_caption.add_theme_font_size_override("font_size", 15 if bounds.x >= 900.0 else 13)
	add_child(_caption)
	_layout()
	advance(0.0)


func _layout() -> void:
	var width: float = minf(_bounds.x, clampf(_source.size.x * 1.65, 132.0, 240.0))
	_icon_side = minf(clampf(_source.size.x * 0.72, 44.0, 108.0), maxf(1.0, minf(width - 14.0, _bounds.y * 0.23)))
	_caption.size.x = maxf(1.0, width - 12.0)
	var label_height: float = _caption.get_minimum_size().y
	size = Vector2(width, _icon_side + label_height + 16.0)
	_icon.size = Vector2.ONE * _icon_side
	_icon.position = Vector2((width - _icon_side) * 0.5, 5.0)
	_icon.pivot_offset = _icon.size * 0.5
	_caption.position = Vector2(6.0, _icon_side + 9.0)
	_caption.size = Vector2(width - 12.0, label_height)
	var desired := _source.position + Vector2((_source.size.x - width) * 0.5, -size.y - 6.0)
	position = desired.clamp(Vector2.ZERO, (_bounds - size).max(Vector2.ZERO))


func advance(progress: float) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	var rise: float = smoothstep(0.0, 0.24, _progress)
	var fade: float = 1.0 - smoothstep(0.72, 1.0, _progress)
	modulate.a = rise * fade
	var pulse: float = sin(PI * clampf(_progress / 0.45, 0.0, 1.0))
	var peak: float = 0.18 if _effect == Effect.ATTACK else 0.08
	_icon.scale = Vector2.ONE * (lerpf(0.70, 1.0, rise) + pulse * peak)
	queue_redraw()


func _draw() -> void:
	if _panel == null:
		return
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var center := Vector2(size.x * 0.5, _icon_side * 0.5 + 5.0)
	var burst: float = clampf((_progress - 0.12) / 0.65, 0.0, 1.0)
	var alpha: float = sin(PI * burst) * 0.8
	var ink := Color(_ink, alpha)
	var radius: float = _icon_side * 0.5
	match _effect:
		Effect.ATTACK:
			for index in range(8):
				var direction := Vector2.from_angle(TAU * float(index) / 8.0)
				draw_line(center + direction * radius * (0.72 + burst * 0.26), center + direction * radius * (1.02 + burst * 0.14), ink, 2.0, true)
		Effect.DEFENSE:
			draw_arc(center, radius * lerpf(0.65, 1.14, burst), 0.0, TAU, 40, ink, 2.0, true)
		Effect.BUFF, Effect.HEAL:
			for index in range(7):
				var offset := Vector2(sin(float(index) * 2.4) * radius, radius * (0.65 - burst * 1.65) + float(index % 3) * 4.0)
				draw_circle(center + offset, 2.0 + float(index % 2), ink)
		Effect.CURSE:
			for index in range(9):
				var direction := Vector2.from_angle(TAU * float(index) / 9.0 + burst * 1.8)
				draw_circle(center + direction * radius * (0.85 + burst * 0.20), 3.5, Color(_ink, alpha * 0.55))
