class_name BattleLab
extends Control

signal exit_requested

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle_view.tscn")

var _settings: Control
var _battle: BattleView
var _session: GameSession
var _hero_choice: OptionButton
var _enemy_choice: OptionButton
var _second_choice: OptionButton
var _weapon_choice: OptionButton
var _shield_choice: OptionButton
var _health_value: SpinBox
var _seed_value: SpinBox
var _potions_value: SpinBox
var _effects_text: TextEdit
var _message: Label
var _log: RichTextLabel
var _scenario: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_settings()


func _build_settings() -> void:
	_settings = MarginContainer.new()
	_settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings.add_theme_constant_override("margin_left", 24)
	_settings.add_theme_constant_override("margin_right", 24)
	_settings.add_theme_constant_override("margin_top", 18)
	_settings.add_theme_constant_override("margin_bottom", 18)
	add_child(_settings)
	var scroll := ScrollContainer.new()
	_settings.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	var title := Label.new()
	title.text = "Лаборатория боя"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	var note := Label.new()
	note.text = "Изолированный бой на настоящих ресурсах. Изменения не сохраняются в прохождение."
	column.add_child(note)
	_hero_choice = _choice(column, "Герой", HeroCatalog.list_ids(), "hero")
	_enemy_choice = _choice(column, "Противник", MonsterCatalog.list_placeable_ids(), "monster")
	var second_ids: Array[String] = [""]
	second_ids.append_array(MonsterCatalog.list_placeable_ids())
	_second_choice = _choice(column, "Второй противник (необязательно)", second_ids, "monster")
	_weapon_choice = _choice(column, "Оружие", _equipment_ids(ItemDefinition.EquipmentSlot.WEAPON), "item")
	_shield_choice = _choice(column, "Щит", _equipment_ids(ItemDefinition.EquipmentSlot.SHIELD), "item")
	_health_value = _number(column, "Начальное HP (0 = максимум)", 0, 9999, 0)
	_seed_value = _number(column, "Seed случайных решений", 0, 2147483647, 12345)
	_potions_value = _number(column, "Количество каждого боевого зелья", 0, 20, 2)
	var effects_label := Label.new()
	effects_label.text = "Начальные статусы героя (JSON-словарь, необязательно)"
	column.add_child(effects_label)
	_effects_text = TextEdit.new()
	_effects_text.custom_minimum_size.y = 90
	_effects_text.placeholder_text = '{"bleeding":{"ticks":2,"tick_damage":2}}'
	column.add_child(_effects_text)
	var row := HBoxContainer.new()
	column.add_child(row)
	var run := Button.new()
	run.text = "Начать бой"
	run.pressed.connect(_start_from_form)
	row.add_child(run)
	var repeat := Button.new()
	repeat.text = "Повторить сценарий"
	repeat.pressed.connect(_repeat)
	row.add_child(repeat)
	var back := Button.new()
	back.text = "Главное меню"
	back.pressed.connect(func() -> void: exit_requested.emit())
	row.add_child(back)
	_message = Label.new()
	column.add_child(_message)
	var log_title := Label.new()
	log_title.text = "Журнал последнего боя"
	column.add_child(log_title)
	_log = RichTextLabel.new()
	_log.custom_minimum_size.y = 180
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_log)


func _choice(parent: VBoxContainer, caption: String, ids: Array[String], category: String) -> OptionButton:
	var label := Label.new()
	label.text = caption
	parent.add_child(label)
	var choice := OptionButton.new()
	choice.custom_minimum_size.x = 320
	for id in ids:
		var display: String = "Нет" if id.is_empty() else id
		if not id.is_empty():
			if category == "hero":
				var hero: HeroDefinition = HeroCatalog.get_hero(id)
				display = hero.display_name if hero != null else id
			elif category == "monster":
				var monster: MonsterDefinition = MonsterCatalog.get_monster(id)
				display = monster.display_name if monster != null else id
			else:
				var item: ItemDefinition = ItemCatalog.get_item(id)
				display = item.display_name if item != null else id
		choice.add_item(display)
		choice.set_item_metadata(choice.item_count - 1, id)
	parent.add_child(choice)
	return choice


func _equipment_ids(slot: int) -> Array[String]:
	var ids: Array[String] = [""]
	for id in ItemCatalog.equipment_ids():
		var item: ItemDefinition = ItemCatalog.get_item(id)
		if item != null and item.equipment_slot == slot:
			ids.append(id)
	return ids


func _number(parent: VBoxContainer, caption: String, minimum: int, maximum: int, initial: int) -> SpinBox:
	var label := Label.new()
	label.text = caption
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = initial
	parent.add_child(spin)
	return spin


func _selected(choice: OptionButton) -> String:
	return str(choice.get_selected_metadata())


func _start_from_form() -> void:
	var effects: Dictionary = {}
	var raw := _effects_text.text.strip_edges()
	if not raw.is_empty():
		var parsed: Variant = JSON.parse_string(raw)
		if not parsed is Dictionary:
			_message.text = "Статусы должны быть JSON-словарём"
			return
		effects = parsed
		for key in effects:
			if not effects[key] is Dictionary:
				_message.text = "Каждый статус должен быть словарём"
				return
	_scenario = {
		"hero": _selected(_hero_choice), "enemy": _selected(_enemy_choice),
		"second": _selected(_second_choice), "weapon": _selected(_weapon_choice),
		"shield": _selected(_shield_choice), "health": int(_health_value.value),
		"seed": int(_seed_value.value), "potions": int(_potions_value.value),
		"statuses": effects.duplicate(true), "slots": []
	}
	_launch(_scenario)


func _repeat() -> void:
	if not _scenario.is_empty():
		_launch(_scenario)


func _launch(config: Dictionary) -> void:
	var definition: HeroDefinition = HeroCatalog.get_hero(str(config["hero"]))
	var hero := HeroState.new(definition)
	var initial_slots: Array[String] = []
	for slot in config.get("slots", []):
		initial_slots.append(str(slot))
	if initial_slots.size() == hero.action_slot_capacity():
		hero.save_action_slots(initial_slots)
	var weapon: ItemDefinition = ItemCatalog.get_item(str(config["weapon"]))
	var shield: ItemDefinition = ItemCatalog.get_item(str(config["shield"]))
	if weapon != null:
		hero.equip_item(weapon)
	if shield != null and (weapon == null or not weapon.two_handed):
		hero.register_shield(shield)
		hero.equip_item(shield)
	if int(config["health"]) > 0:
		hero.health = mini(int(config["health"]), hero.max_health)
	_session = GameSession.new()
	_session.hero = hero
	_session.party.append(hero)
	for id in ItemCatalog.consumable_ids():
		var item: ItemDefinition = ItemCatalog.get_item(id)
		if GameSession.is_combat_item(item):
			_session.carried_items[id] = int(config["potions"])
	var enemy: MonsterDefinition = MonsterCatalog.get_monster(str(config["enemy"]))
	var second: MonsterDefinition = null
	if not str(config["second"]).is_empty():
		second = MonsterCatalog.get_monster(str(config["second"]))
	var combat := CombatSession.new(enemy, hero, second, int(config["seed"]))
	var statuses: Dictionary = config["statuses"]
	for key in statuses:
		combat.battle_state.get_hero().statuses[str(key)] = (statuses[key] as Dictionary).duplicate(true)
	_settings.hide()
	_battle = BATTLE_SCENE.instantiate() as BattleView
	add_child(_battle)
	_battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle.battle_won.connect(func() -> void: _finish(true))
	_battle.battle_lost.connect(func() -> void: _finish(false))
	_battle.combat_log_line.connect(_append_log)
	_battle.item_use_requested.connect(_use_item)
	_log.clear()
	_message.text = ""
	_battle.begin(combat, hero)
	_battle.enable_lab_playback()
	_battle.bind_combat_items(_session)


func _append_log(message: String) -> void:
	_log.append_text(message + "\n")


func _use_item(id: String) -> void:
	if _battle == null:
		return
	var outcome: Dictionary = _session.use_combat_item(id, _battle.current_battle_state())
	_battle.show_combat_item_result(outcome, _session)


func _finish(won: bool) -> void:
	if _session != null and _session.hero != null:
		_scenario["slots"] = _session.hero.get_saved_action_slots()
	if _battle != null:
		_battle.queue_free()
		_battle = null
	_message.text = "Победа" if won else "Поражение"
	_settings.show()
