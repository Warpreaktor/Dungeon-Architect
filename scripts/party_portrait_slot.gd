class_name PartyPortraitSlot
extends VBoxContainer

signal status_info_requested(title: String, description: String)

const PORTRAIT_SIDE: float = 78.0
const BADGE_SIDE: float = 24.0
const SLOT_SPACING: int = 3
const HEALTH_FONT_SIZE: int = 15
const STATUS_MAX_ICONS: int = 3
const HIT_IN_SECONDS: float = 0.13
const HIT_OUT_SECONDS: float = 0.24
const HIT_COLOR: Color = Color(1.0, 0.25, 0.25, 1.0)
const STATUS_TEXTURES: Dictionary = {
	"bleeding": preload("res://assets/abilities/statuses/bleeding.png"),
	"strength": preload("res://assets/icons/potion_strength_small.png"),
	"vitality": preload("res://assets/icons/potion_vitality_small.png"),
	"vision": preload("res://assets/icons/potion_vision_small.png")
}
const DEFAULT_STATUS_ICON: Texture2D = preload("res://assets/icons/trigger.png")

var _portrait: TextureRect
var _badges: HBoxContainer
var _health: Label
var _hit_tween: Tween
var _member: HeroState
var _normal_tint: Color = Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", SLOT_SPACING)
	custom_minimum_size = Vector2(PORTRAIT_SIDE, PORTRAIT_SIDE)
	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(PORTRAIT_SIDE, PORTRAIT_SIDE)
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_box)
	_portrait = TextureRect.new()
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	_portrait.gui_input.connect(_on_portrait_input)
	portrait_box.add_child(_portrait)
	_badges = HBoxContainer.new()
	_badges.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_badges.offset_left = 1.0
	_badges.offset_right = PORTRAIT_SIDE
	_badges.offset_top = -BADGE_SIDE
	_badges.offset_bottom = 0.0
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badges.add_theme_constant_override("separation", 1)
	portrait_box.add_child(_badges)
	_health = Label.new()
	_health.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health.add_theme_font_size_override("font_size", HEALTH_FONT_SIZE)
	_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health)


func display_member(member: HeroState) -> void:
	_member = member
	if member == null:
		visible = false
		return
	visible = true
	_portrait.texture = member.definition.portrait if member.definition != null else null
	var name_text: String = member.definition.display_name if member.definition != null else "Герой"
	_portrait.tooltip_text = "%s: %d/%d HP" % [name_text, member.health, member.max_health]
	_health.text = "%d / %d" % [member.health, member.max_health]
	_health.add_theme_color_override("font_color", Color("#aeb7c1") if member.health <= 0 else Color("#f4dad0"))
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
	for i in range(mini(effects.size(), STATUS_MAX_ICONS)):
		var entry: Dictionary = effects[i]
		var icon := Button.new()
		icon.flat = true
		icon.icon = STATUS_TEXTURES.get(str(entry["id"]), DEFAULT_STATUS_ICON)
		icon.expand_icon = true
		icon.custom_minimum_size = Vector2(BADGE_SIDE, BADGE_SIDE)
		icon.tooltip_text = "%s\n%s" % [entry["name"], entry["description"]]
		icon.pressed.connect(_on_status_pressed.bind(str(entry["name"]), str(entry["description"])))
		_badges.add_child(icon)


func _effect_entries(member: HeroState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for status_id in member.overworld_statuses:
		var status: Dictionary = member.overworld_statuses[status_id]
		var label: String = str(status.get("label", status_id))
		result.append({
			"id": str(status_id), "name": label,
			"description": "%d урона через %d шагов. Осталось срабатываний: %d." % [
				int(status.get("damage", 0)), int(status.get("steps_until_tick", 0)), int(status.get("ticks_remaining", 0))]
		})
	if member.strength_steps > 0:
		result.append({"id": "strength", "name": "Усиление атаки", "description": "Атака +%d, осталось шагов: %d." % [member.strength_bonus, member.strength_steps]})
	if member.vitality_steps > 0:
		result.append({"id": "vitality", "name": "Живучесть", "description": "Получаемый урон −%d%%, осталось шагов: %d." % [member.vitality_percent, member.vitality_steps]})
	if member.vision_steps > 0:
		result.append({"id": "vision", "name": "Всевиденье", "description": "Бонус обзора +%d, осталось шагов: %d." % [member.vision_bonus, member.vision_steps]})
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
	var name_text: String = _member.definition.display_name if _member.definition != null else "Герой"
	var description: String = "Здоровье: %d / %d" % [_member.health, _member.max_health]
	var effects: String = _member.active_effects_summary()
	if not effects.is_empty():
		description += "\n" + effects
	status_info_requested.emit(name_text, description)
