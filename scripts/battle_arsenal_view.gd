class_name BattleArsenalView
extends Control

signal saved(slots: Array[String])
signal closed

const SLOT_SCENE: PackedScene = preload("res://scenes/battle_ability_slot.tscn")

var _hero: HeroState
var _session: GameSession
var _actor: BattleParticipant
var _read_only: bool = false
var _skills_grid: GridContainer
var _slots_label: Label
var _details: AcceptDialog
var _panel: PanelContainer
var _arsenal_content: VBoxContainer
var _profile_content: VBoxContainer
var _content_layout: BoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_interface()


func open_for(hero: HeroState, actor: BattleParticipant = null, read_only: bool = false, session: GameSession = null) -> void:
	if hero == null:
		return
	_hero = hero
	_session = session
	_actor = actor if actor != null else BattleParticipant.from_hero(hero)
	_read_only = read_only
	_arsenal_content.visible = not _read_only
	visible = true
	if not _read_only:
		_refresh()
	_refresh_profile()
	_resize_panel()


func dismiss() -> void:
	visible = false
	closed.emit()


func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.035, 0.05, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.theme = preload("res://themes/hero_hud.tres")
	_panel.custom_minimum_size = Vector2(1080, 620)
	center.add_child(_panel)
	resized.connect(_resize_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var heading := HBoxContainer.new()
	column.add_child(heading)
	var heading_title := Label.new()
	heading_title.text = "ПЕРСОНАЖ"
	heading_title.add_theme_color_override("font_color", Color("#e8c58a"))
	heading_title.add_theme_font_size_override("font_size", 22)
	heading_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(heading_title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(48, 44)
	close_button.pressed.connect(dismiss)
	heading.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_content_layout = BoxContainer.new()
	_content_layout.add_theme_constant_override("separation", 20)
	_content_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_layout)

	_profile_content = VBoxContainer.new()
	_profile_content.custom_minimum_size.x = 320
	_profile_content.add_theme_constant_override("separation", 12)
	_content_layout.add_child(_profile_content)

	_arsenal_content = VBoxContainer.new()
	_arsenal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arsenal_content.add_theme_constant_override("separation", 10)
	_content_layout.add_child(_arsenal_content)
	_slots_label = Label.new()
	_slots_label.add_theme_color_override("font_color", Color("#e8c58a"))
	_arsenal_content.add_child(_slots_label)
	_skills_grid = GridContainer.new()
	_skills_grid.columns = 4
	_skills_grid.add_theme_constant_override("h_separation", 8)
	_skills_grid.add_theme_constant_override("v_separation", 8)
	_arsenal_content.add_child(_skills_grid)

	_details = AcceptDialog.new()
	_details.title = "Приём"
	add_child(_details)


func _refresh_profile() -> void:
	for child in _profile_content.get_children():
		_profile_content.remove_child(child)
		child.queue_free()
	if _hero == null or _hero.definition == null:
		return
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 12)
	_profile_content.add_child(identity)
	var portrait := TextureRect.new()
	portrait.texture = _hero.definition.portrait
	portrait.custom_minimum_size = Vector2(136, 156)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	identity.add_child(portrait)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	identity.add_child(heading)
	var name := Label.new()
	name.text = _hero.definition.display_name
	name.add_theme_font_size_override("font_size", 20)
	heading.add_child(name)
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 5)
	heading.add_child(health_row)
	StatIconCatalog.add_icon(health_row, "health", 22.0)
	var totals: Dictionary = CharacterStats.participant_values(_actor) if _read_only else CharacterStats.hero_values(_hero)
	var hp := Label.new()
	hp.text = "%d / %d HP" % [_actor.health, _actor.max_health] if _read_only else "%d / %d HP" % [_hero.health, int(totals["max_health"])]
	hp.add_theme_color_override("font_color", Color("#dc7178"))
	health_row.add_child(hp)

	var values: Array[Dictionary] = [
		{"stat": "strength", "text": "Сила  %d" % int(totals["strength"])},
		{"stat": "agility", "text": "Ловкость  %d" % int(totals["agility"])},
		{"stat": "attack", "text": "Атака  %d" % int(totals["melee_attack"])},
		{"stat": "defense", "text": "Броня  %d" % int(totals["defense"])},
		{"stat": "evasion", "text": "Уклонение  %d%%" % int(totals["dodge_percent"])},
		{"stat": "accuracy", "text": "Меткость  %d%%" % int(totals["accuracy_percent"])}
	]
	if _read_only:
		values.append({"stat": "magic", "text": "Энергия  %d / %d" % [_actor.current_energy(), _actor.max_energy]})
	else:
		values.append({"stat": "combat_slots", "text": "Боевые слоты  %d" % _hero.action_slot_capacity()})
		values.append({"stat": "gold", "text": "Золото  %d" % _hero.gold})
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 12)
	stats.add_theme_constant_override("v_separation", 10)
	_profile_content.add_child(stats)
	for value in values:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		stats.add_child(row)
		StatIconCatalog.add_icon(row, str(value["stat"]))
		var label := Label.new()
		label.text = str(value["text"])
		row.add_child(label)

	var equipment_hero: HeroState = _actor._hero_snapshot if _read_only and _actor._hero_snapshot != null else _hero
	var weapon: ItemDefinition = ItemCatalog.get_item(equipment_hero.equipped_weapon_id)
	var shield: ItemDefinition = ItemCatalog.get_item(equipment_hero.equipped_shield_id)
	for value in ["Оружие  %s" % (weapon.display_name if weapon != null else "Нет"), "Щит  %s" % (shield.display_name if shield != null else "Нет")]:
		var label := Label.new()
		label.text = value
		_profile_content.add_child(label)


func _resize_panel() -> void:
	if _panel == null:
		return
	var width := minf(520.0 if _read_only else 1180.0, maxf(320.0, size.x - 32.0))
	_panel.custom_minimum_size = Vector2(width, minf(560.0 if _read_only else 620.0, maxf(240.0, size.y - 32.0)))
	if _content_layout != null:
		_content_layout.vertical = _read_only or width < 860.0
		_profile_content.custom_minimum_size.x = 0.0 if _content_layout.vertical else 320.0
		if _skills_grid != null:
			var side: float = 60.0 if width < 440.0 else (88.0 if _content_layout.vertical else 112.0)
			for skill in _skills_grid.get_children():
				skill.custom_minimum_size = Vector2(side, side)


func _refresh() -> void:
	for child in _skills_grid.get_children():
		_skills_grid.remove_child(child)
		child.queue_free()
	if _hero == null or _actor == null:
		return
	var active: Array[String] = _hero.get_saved_action_slots()
	_slots_label.text = "БОЕВЫЕ НАВЫКИ  %d / %d" % [active.size() - active.count(""), _hero.action_slot_capacity()]
	var index: int = 0
	for ability in AbilityCatalog.available_abilities(_actor):
		var locked: bool = _hero.definition.is_personal_ability_locked(ability.ability_id)
		var selectable: bool = _hero.can_select_action(ability.ability_id)
		if not selectable and not locked and not ability.passive and not AbilityCatalog.is_automatic_equipment_ability(ability.ability_id):
			continue
		var slot: BattleAbilitySlot = SLOT_SCENE.instantiate() as BattleAbilitySlot
		_skills_grid.add_child(slot)
		var panel_width: float = _panel.custom_minimum_size.x
		var side: float = 60.0 if panel_width < 440.0 else (88.0 if panel_width < 860.0 else 112.0)
		slot.custom_minimum_size = Vector2(side, side)
		slot.configure(index, ability, selectable, _actor)
		slot.set_locked(locked)
		if AbilityCatalog.is_automatic_equipment_ability(ability.ability_id):
			slot.set_slot_number_visible(false)
		var selected: bool = active.has(ability.ability_id) or MonsterWeaponStrike.is_weapon_strike(ability.ability_id)
		slot.set_current(selected)
		if locked:
			slot.modulate = Color.WHITE
		else:
			slot.modulate = Color.WHITE if selected or not selectable else Color(0.52, 0.54, 0.60)
		slot.pressed.connect(_toggle_ability.bind(ability.ability_id))
		slot.info_requested.connect(_show_details)
		index += 1


func _toggle_ability(ability_id: String) -> void:
	if _read_only or _hero == null or not _hero.can_select_action(ability_id):
		return
	var active: Array[String] = []
	for id in _hero.get_saved_action_slots():
		if not id.is_empty() and id != ability_id:
			active.append(id)
	if not _hero.get_saved_action_slots().has(ability_id):
		if active.size() >= _hero.action_slot_capacity():
			return
		active.append(ability_id)
	while active.size() < _hero.action_slot_capacity():
		active.append("")
	var accepted: bool = _session.execute(GameAction.save_arsenal(_hero, active)).accepted if _session != null else _hero.save_action_slots(active)
	if accepted:
		_refresh()
		saved.emit(active.duplicate())


func _show_details(content: String) -> void:
	_details.dialog_text = content
	_details.popup_centered_ratio(0.7)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") and not _details.visible:
		dismiss()
		get_viewport().set_input_as_handled()
