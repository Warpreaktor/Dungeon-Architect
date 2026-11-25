class_name PartyPortraitSlot
extends VBoxContainer

signal status_info_requested(title: String, description: String)
signal character_requested(member: HeroState)

# Размеры элементов одной карточки на карте: ширина всех зон совпадает.
const PORTRAIT_SIDE: float = 90.0
const HEALTH_BAR_HEIGHT: float = 20.0
const BADGE_SIDE: float = 24.0
const SLOT_SPACING: int = 4
const BADGE_SPACING: int = 2
const HEALTH_FONT_SIZE: int = 13
const STATUS_MAX_ICONS: int = 4
const HIT_IN_SECONDS: float = 0.13
const HIT_OUT_SECONDS: float = 0.24
const HIT_COLOR: Color = Color(1.0, 0.25, 0.25, 1.0)
const STATUS_TEXTURES: Dictionary = {
	"bleeding": preload("res://assets/abilities/statuses/bleeding.png"),
	"fallen_hero_infection": preload("res://assets/abilities/fallen_hero/rotten_bite.png"),
	"strength": preload("res://assets/icons/potions/potion_strength_small.png"),
	"vitality": preload("res://assets/icons/potions/potion_vitality_small.png"),
	"vision": preload("res://assets/icons/potions/potion_vision_small.png")
}
const DEFAULT_STATUS_ICON: Texture2D = preload("res://assets/icons/map_objects/trigger.png")
const HEALTH_BACKGROUND_COLOR: Color = Color("#263039")
const HEALTH_FILL_COLOR: Color = Color("#d45062")
const HEALTH_EDGE_COLOR: Color = Color("#70808f")
const HEALTH_TEXT_COLOR: Color = Color("#ffffff")
const HEALTH_TEXT_DISABLED_COLOR: Color = Color("#c5cbd1")
const BADGE_BACKGROUND_COLOR: Color = Color("#1b2632")
const BADGE_BORDER_COLOR: Color = Color("#637789")
const HEALTH_CORNER_RADIUS: int = 3
const BADGE_CORNER_RADIUS: int = 4
const HEALTH_BORDER_WIDTH: int = 1
const BADGE_BORDER_WIDTH: int = 1

var _portrait: TextureRect
var _badges: HBoxContainer
var _health: Label
var _health_bar: ProgressBar
var _hit_tween: Tween
var _member: HeroState
var _normal_tint: Color = Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", SLOT_SPACING)
	custom_minimum_size = Vector2(PORTRAIT_SIDE, 0.0)

	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(PORTRAIT_SIDE, PORTRAIT_SIDE)
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_box)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	_portrait.gui_input.connect(_on_portrait_input)
	portrait_box.add_child(_portrait)
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var health_box := Control.new()
	health_box.custom_minimum_size = Vector2(PORTRAIT_SIDE, HEALTH_BAR_HEIGHT)
	health_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(health_box)
	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.max_value = 1.0
	_health_bar.value = 1.0
	_health_bar.add_theme_stylebox_override("background", _health_background_style())
	_health_bar.add_theme_stylebox_override("fill", _health_fill_style())
	health_box.add_child(_health_bar)
	_health_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_health = Label.new()
	_health.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health.add_theme_font_size_override("font_size", HEALTH_FONT_SIZE)
	_health.add_theme_color_override("font_color", HEALTH_TEXT_COLOR)
	_health.add_theme_color_override("font_shadow_color", Color.BLACK)
	_health.add_theme_constant_override("shadow_offset_x", 1)
	_health.add_theme_constant_override("shadow_offset_y", 1)
	_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_box.add_child(_health)
	_health.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_badges = HBoxContainer.new()
	_badges.custom_minimum_size = Vector2(PORTRAIT_SIDE, BADGE_SIDE)
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badges.add_theme_constant_override("separation", BADGE_SPACING)
	add_child(_badges)


func _health_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = HEALTH_BACKGROUND_COLOR
	style.border_color = HEALTH_EDGE_COLOR
	style.set_border_width_all(HEALTH_BORDER_WIDTH)
	style.set_corner_radius_all(HEALTH_CORNER_RADIUS)
	return style


func _health_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = HEALTH_FILL_COLOR
	style.set_corner_radius_all(HEALTH_CORNER_RADIUS)
	return style


func _badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BADGE_BACKGROUND_COLOR
	style.border_color = BADGE_BORDER_COLOR
	style.set_border_width_all(BADGE_BORDER_WIDTH)
	style.set_corner_radius_all(BADGE_CORNER_RADIUS)
	return style


func display_member(member: HeroState) -> void:
	_member = member
	if member == null:
		visible = false
		return
	visible = true
	_portrait.texture = member.definition.portrait if member.definition != null else null
	var name_text: String = member.definition.display_name if member.definition != null else "Герой"
	var max_health: int = member.effective_max_health()
	_portrait.tooltip_text = "%s: %d/%d HP · %d/%d Энергия" % [name_text, member.health, max_health, member.energy, member.definition.max_energy]
	_health_bar.max_value = float(max_health)
	_health_bar.value = float(clampi(member.health, 0, max_health))
	_health.text = "%d / %d" % [member.health, max_health]
	_health.add_theme_color_override("font_color", HEALTH_TEXT_DISABLED_COLOR if member.health <= 0 else HEALTH_TEXT_COLOR)
	_normal_tint = Color(0.55, 0.55, 0.55) if member.health <= 0 else Color.WHITE
	if _hit_tween == null or not _hit_tween.is_running():
		_portrait.modulate = _normal_tint
	_update_badges(member)


func flash_damage() -> void:
	if _portrait == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_portrait.modulate = Color.WHITE
	_hit_tween = create_tween()
	_hit_tween.tween_property(_portrait, "modulate", HIT_COLOR, HIT_IN_SECONDS)
	_hit_tween.tween_property(_portrait, "modulate", Color.WHITE, HIT_OUT_SECONDS)
	_hit_tween.tween_property(_portrait, "modulate", HIT_COLOR, HIT_IN_SECONDS)
	_hit_tween.tween_property(_portrait, "modulate", _normal_tint, HIT_OUT_SECONDS)


func _update_badges(member: HeroState) -> void:
	for child in _badges.get_children():
		_badges.remove_child(child)
		child.queue_free()
	var effects: Array[Dictionary] = _effect_entries(member)
	var visible_count: int = mini(effects.size(), STATUS_MAX_ICONS)
	if visible_count == 0:
		return
	var icon_side: float = minf(BADGE_SIDE,
		(PORTRAIT_SIDE - float(visible_count - 1) * float(BADGE_SPACING)) / float(visible_count))
	for i in range(visible_count):
		var entry: Dictionary = effects[i]
		var icon := Button.new()
		icon.icon = STATUS_TEXTURES.get(str(entry["id"]), DEFAULT_STATUS_ICON)
		icon.expand_icon = true
		icon.custom_minimum_size = Vector2(icon_side, icon_side)
		var style: StyleBoxFlat = _badge_style()
		for state in ["normal", "hover", "pressed", "focus"]:
			icon.add_theme_stylebox_override(state, style)
		icon.tooltip_text = "%s\n%s" % [entry["name"], entry["description"]]
		icon.pressed.connect(_on_status_pressed.bind(str(entry["name"]), str(entry["description"])))
		_badges.add_child(icon)


func _effect_entries(member: HeroState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for status_id in member.overworld_statuses:
		var status: Dictionary = member.overworld_statuses[status_id]
		var label: String = str(status.get("label", status_id))
		result.append({"id": str(status_id), "name": label,
			"description": BattleStatusRules.describe(status)})
	if member.strength_phases > 0:
		result.append({"id": "strength", "name": "Усиление атаки", "description": "Атака +%d, осталось фаз: %d." % [member.strength_bonus, member.strength_phases]})
	if member.vitality_phases > 0:
		result.append({"id": "vitality", "name": "Живучесть", "description": "Получаемый урон −%d%%, осталось фаз: %d." % [member.vitality_percent, member.vitality_phases]})
	if member.vision_phases > 0:
		result.append({"id": "vision", "name": "Всевиденье", "description": "Бонус обзора +%d, осталось фаз: %d." % [member.vision_bonus, member.vision_phases]})
	return result


func _on_status_pressed(title: String, description: String) -> void:
	status_info_requested.emit(title, description)


func _on_portrait_input(event: InputEvent) -> void:
	if _member == null:
		return
	var tapped: bool = false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		tapped = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		tapped = (event as InputEventScreenTouch).pressed
	if not tapped:
		return
	character_requested.emit(_member)
