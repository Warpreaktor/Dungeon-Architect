class_name EquipmentMannequin
extends Control

signal slot_selected(slot_id: String)
signal item_transferred(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant)

const POSITIONS: Dictionary = {
	"head": Vector2(0.5, 0.24), "neck": Vector2(0.76, 0.31),
	"body": Vector2(0.5, 0.49), "main_hand": Vector2(0.18, 0.49),
	"off_hand": Vector2(0.82, 0.49), "ring_left": Vector2(0.20, 0.64),
	"ring_right": Vector2(0.80, 0.64), "belt": Vector2(0.5, 0.67),
	"gloves": Vector2(0.31, 0.84), "boots": Vector2(0.69, 0.84)
}

const STATS: Array[Dictionary] = [
	{"id": "strength", "label": "Сила", "icon": preload("res://assets/icons/stats/24x24/strength.png")},
	{"id": "agility", "label": "Ловкость", "icon": preload("res://assets/icons/stats/24x24/agility.png")},
	{"id": "energy", "label": "Энергия", "icon": preload("res://assets/icons/stats/24x24/magic.png")},
	{"id": "damage", "label": "Урон", "icon": preload("res://assets/icons/stats/24x24/attack.png")},
	{"id": "health", "label": "Жизнь", "icon": preload("res://assets/icons/stats/24x24/health.png")},
	{"id": "defense", "label": "Броня", "icon": preload("res://assets/icons/stats/24x24/defense.png")}
]

var slots: Dictionary = {}
var _portrait: TextureRect
var _stats_panel: PanelContainer
var _stats_grid: GridContainer
var _stat_values: Dictionary = {}
var _selected_slot: String = ""


func _ready() -> void:
	clip_contents = false
	_stats_panel = PanelContainer.new()
	_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.10, 0.14, 0.72)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.27, 0.42, 0.56, 0.85)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.content_margin_left = 8
	panel_style.content_margin_top = 6
	panel_style.content_margin_right = 8
	panel_style.content_margin_bottom = 6
	_stats_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_stats_panel)
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 3
	_stats_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_grid.add_theme_constant_override("h_separation", 10)
	_stats_grid.add_theme_constant_override("v_separation", 4)
	_stats_panel.add_child(_stats_grid)
	_build_stat_rows()
	_portrait = TextureRect.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.modulate = Color(0.45, 0.59, 0.69, 0.66)
	add_child(_portrait)
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var slot := EquipmentSlotControl.new()
		add_child(slot)
		slot.selected.connect(func(id: String) -> void: slot_selected.emit(id))
		slot.transferred.connect(func(kind: String, origin: Variant, dest_kind: String, dest: Variant) -> void: item_transferred.emit(kind, origin, dest_kind, dest))
		slots[slot_id] = slot
	resized.connect(_layout_slots)
	_layout_slots()


func show_hero(session: GameSession) -> void:
	var member: HeroState = session._inventory_equipment_member() if session != null else null
	var portrait: Texture2D = member.definition.portrait if member != null else null
	if _portrait.texture != portrait:
		_portrait.texture = portrait
	_update_stats(member)
	var weapon: ItemDefinition = ItemCatalog.get_item(member.equipped_weapon_id) if member != null else null
	var shadow: Texture2D = weapon.icon if weapon != null and weapon.two_handed else null
	for slot_id in slots:
		var slot: EquipmentSlotControl = slots[slot_id]
		slot.configure(str(slot_id), session, shadow if slot_id == "off_hand" else null)


func clear_session() -> void:
	_update_stats(null)
	for slot in slots.values():
		slot.session = null


func set_selected_slot(slot_id: String) -> void:
	if _selected_slot == slot_id:
		return
	if slots.has(_selected_slot):
		slots[_selected_slot].set_selected(false)
	_selected_slot = slot_id
	if slots.has(_selected_slot):
		slots[_selected_slot].set_selected(true)


func _layout_slots() -> void:
	if _portrait == null:
		return
	var stats_size := Vector2(size.x, minf(108.0, size.y * 0.22))
	if _stats_panel != null:
		_stats_panel.position = Vector2.ZERO
		_stats_panel.size = stats_size
	var body_top: float = stats_size.y + 6.0
	var body_size := Vector2(size.x, maxf(1.0, size.y - body_top))
	_portrait.position = Vector2(size.x * 0.24, body_top + body_size.y * 0.12)
	_portrait.size = Vector2(size.x * 0.52, body_size.y * 0.68)
	var side: float = maxf(1.0, floorf(minf(58.0, minf(size.x / 4.9, body_size.y / 5.8))))
	var slot_size := Vector2(side, side)
	for slot_id in slots:
		var slot: EquipmentSlotControl = slots[slot_id]
		var center: Vector2 = POSITIONS.get(slot_id, Vector2(0.5, 0.5))
		slot.set_slot_size(side)
		var local_center := Vector2(center.x * body_size.x, center.y * body_size.y)
		slot.position = Vector2(local_center.x - side * 0.5, body_top + local_center.y - side * 0.5)

func _build_stat_rows() -> void:
	for entry in STATS:
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = entry["icon"]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(icon)
		var value := Label.new()
		value.name = str(entry["id"])
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.add_theme_font_size_override("font_size", 14)
		value.add_theme_color_override("font_color", Color(0.91, 0.94, 0.97, 1.0))
		value.text = "-"
		line.add_child(value)
		line.tooltip_text = str(entry["label"])
		_stats_grid.add_child(line)
		_stat_values[str(entry["id"])] = value


func _update_stats(member: HeroState) -> void:
	if _stat_values.is_empty():
		return
	if member == null:
		for label in _stat_values.values():
			(label as Label).text = "-"
		return
	var values: Dictionary = CharacterStats.hero_values(member)
	var damage: int = int(values.get("ranged_attack", 0)) if int(values.get("ranged_attack", 0)) > 0 else int(values.get("melee_attack", 0))
	if int(values.get("melee_attack", 0)) > 0 and int(values.get("ranged_attack", 0)) > 0:
		damage = maxi(int(values.get("melee_attack", 0)), int(values.get("ranged_attack", 0)))
	(_stat_values["strength"] as Label).text = str(int(values.get("strength", 0)))
	(_stat_values["agility"] as Label).text = str(int(values.get("agility", 0)))
	(_stat_values["energy"] as Label).text = "%d/%d" % [member.energy, member.definition.max_energy]
	(_stat_values["damage"] as Label).text = str(damage)
	(_stat_values["health"] as Label).text = "%d/%d" % [member.health, member.effective_max_health()]
	(_stat_values["defense"] as Label).text = str(int(values.get("defense", 0)))
	var damage_hint := "Ближний: %d  Дальний: %d" % [int(values.get("melee_attack", 0)), int(values.get("ranged_attack", 0))]
	(_stat_values["damage"] as Label).tooltip_text = damage_hint
