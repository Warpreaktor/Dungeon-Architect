class_name BattleFigureLayout
extends RefCounted

const GROUND_POINT := Vector2(0.5, 0.95)
const FIGURE_HEIGHT_FRACTION: float = 0.88
const SINGLE_SLOT_WIDTH_FRACTION: float = 0.78
const FIELD_HEIGHT_FRACTION: float = 0.70
const CARD_INSET: float = 12.0


static func idle_texture(profile: CombatVisualProfile) -> AtlasTexture:
	if profile == null:
		return null
	var pose: CombatVisualPose = profile.resolve_pose(&"idle")
	if pose == null:
		return null
	var source_size: Vector2 = pose.texture.get_size()
	var anchor: Vector2 = pose.ground_anchor.clamp(Vector2.ZERO, Vector2.ONE) * source_size
	var logical_side: float = source_size.y / (FIGURE_HEIGHT_FRACTION * pose.height_scale * profile.display_scale)
	logical_side = maxf(logical_side, anchor.x / GROUND_POINT.x)
	logical_side = maxf(logical_side, (source_size.x - anchor.x) / (1.0 - GROUND_POINT.x))
	logical_side = maxf(logical_side, anchor.y / GROUND_POINT.y)
	logical_side = maxf(logical_side, (source_size.y - anchor.y) / (1.0 - GROUND_POINT.y))
	logical_side = ceilf(logical_side)
	var texture := AtlasTexture.new()
	texture.atlas = pose.texture
	texture.region = Rect2(Vector2.ZERO, source_size)
	texture.margin = Rect2(Vector2.ONE * logical_side * GROUND_POINT - anchor, Vector2.ONE * logical_side - source_size)
	texture.filter_clip = true
	return texture


static func slot_side(half_width: float, field_height: float, max_team_size: int, gap: float) -> float:
	var width: float = half_width * SINGLE_SLOT_WIDTH_FRACTION if max_team_size == 1 else (half_width - gap * (max_team_size - 1)) / max_team_size
	return maxf(1.0, floorf(minf(width - CARD_INSET, field_height * FIELD_HEIGHT_FRACTION)))


static func visual_rect(portrait: TextureRect) -> Rect2:
	var texture: AtlasTexture = portrait.texture as AtlasTexture
	if texture == null or not portrait.has_meta(&"combat_figure"):
		return Rect2(Vector2.ZERO, portrait.size)
	var canvas_size: Vector2 = texture.get_size()
	var factor: float = minf(portrait.size.x / canvas_size.x, portrait.size.y / canvas_size.y)
	var origin: Vector2 = (portrait.size - canvas_size * factor) * 0.5
	var offset: Vector2 = texture.margin.position
	if portrait.flip_h:
		offset.x = canvas_size.x - offset.x - texture.region.size.x
	return Rect2(origin + offset * factor, texture.region.size * factor)


static func configure_marker(panel: Panel, figure: bool, active_turn: bool) -> void:
	if not panel.has_meta(&"portrait_style"):
		panel.set_meta(&"portrait_style", panel.get_theme_stylebox("panel"))
	if not figure:
		panel.add_theme_stylebox_override("panel", panel.get_meta(&"portrait_style") as StyleBox)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ffe0a0") if active_turn else Color("#f5c568")
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.36 if active_turn else 0.28
	panel.anchor_right = 0.64 if active_turn else 0.72
	panel.anchor_top = 0.967 if active_turn else 0.981
	panel.anchor_bottom = 0.979 if active_turn else 0.993
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
