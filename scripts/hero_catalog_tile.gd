class_name HeroCatalogTile
extends Button

signal add_requested(hero_id: String)

const GOLD := Color(0.94, 0.76, 0.43)
const INK := Color(0.07, 0.11, 0.16)
const LOCK_ICON: Texture2D = preload("res://assets/ui/lock_overlay.png")
var hero: HeroDefinition
var portrait: TextureRect
var _content: BoxContainer
var _caption: Label
var _badge: Label
var _lock_overlay: TextureRect
var _lock_shade: ColorRect
var _locked: bool = false
var _focused: bool = false
var _party_position: int = -1


func _ready() -> void:
	var content := BoxContainer.new()
	content.vertical = true
	_content = content
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
	_lock_shade = ColorRect.new()
	_lock_shade.color = Color(0.06, 0.06, 0.07, 0.52)
	_lock_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_shade.visible = false
	portrait.add_child(_lock_shade)
	_lock_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_lock_overlay = TextureRect.new()
	_lock_overlay.texture = LOCK_ICON
	_lock_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lock_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_overlay.visible = false
	portrait.add_child(_lock_overlay)
	_lock_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lock_overlay.offset_left = -8
	_lock_overlay.offset_top = -8
	_lock_overlay.offset_right = 8
	_lock_overlay.offset_bottom = 8
	set_selection(false, 0)
	set_locked(_locked)


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


func set_locked(value: bool) -> void:
	_locked = value
	if _lock_shade != null:
		_lock_shade.visible = value
	if _lock_overlay != null:
		_lock_overlay.visible = value
		_lock_overlay.modulate = Color(1.0, 1.0, 1.0, 0.88)
	if portrait != null:
		portrait.self_modulate = Color(0.40, 0.40, 0.40) if value else Color.WHITE
	if _caption != null:
		_caption.modulate = Color(0.65, 0.65, 0.65) if value else Color.WHITE
	tooltip_text = "%s\nНедоступен в этой кампании" % hero.display_name if value and hero != null else (hero.display_name if hero != null else "")


func configure_flight() -> void:
	custom_minimum_size = Vector2.ZERO
	resized.connect(_adapt_flight)
	_adapt_flight()
	var style := get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.shadow_size = 9
	style.shadow_offset = Vector2(0, 6)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)


func _adapt_flight() -> void:
	var horizontal: bool = size.x > size.y * 1.15
	_content.vertical = not horizontal
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not horizontal else Control.SIZE_FILL
	portrait.custom_minimum_size.x = 0.0 if not horizontal else clampf(size.y - 8.0, 0.0, 48.0)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if horizontal else HORIZONTAL_ALIGNMENT_CENTER


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		accept_event()
		add_requested.emit(hero.hero_id)
