class_name HeroCatalogTile
extends Button

const GOLD := Color(0.94, 0.76, 0.43)
const INK := Color(0.07, 0.11, 0.16)
var hero: HeroDefinition
var portrait: TextureRect
var _caption: Label
var _badge: Label
var _focused: bool = false
var _party_position: int = -1


func _ready() -> void:
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 4
	content.offset_right = -4
	content.offset_top = 4
	content.offset_bottom = -4
	content.add_theme_constant_override("separation", 2)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(portrait)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.add_theme_font_size_override("font_size", 13)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_caption)
	_badge = Label.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.add_theme_color_override("font_color", GOLD)
	_badge.add_theme_color_override("font_shadow_color", Color.BLACK)
	_badge.add_theme_constant_override("shadow_offset_x", 1)
	_badge.add_theme_constant_override("shadow_offset_y", 1)
	_badge.position = Vector2(6, 4)
	add_child(_badge)
	set_selection(false, 0)


func configure(definition: HeroDefinition) -> void:
	hero = definition
	portrait.texture = hero.portrait
	_caption.text = hero.display_name
	tooltip_text = hero.display_name


func set_tile_size(side: float) -> void:
	custom_minimum_size = Vector2(side, side + 22.0)


func set_selection(focused: bool, party_position: int) -> void:
	if _focused == focused and _party_position == party_position:
		return
	_focused = focused
	_party_position = party_position
	var border: Color = GOLD if party_position > 0 else (Color(0.48, 0.73, 0.85) if focused else Color(0.30, 0.42, 0.52))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.20, 0.27) if focused else INK
	style.border_color = border
	style.set_border_width_all(2 if focused or party_position > 0 else 1)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.27, 0.34)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	_badge.text = "✓ %d" % party_position if party_position > 0 else ""
