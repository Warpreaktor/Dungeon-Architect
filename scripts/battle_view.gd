class_name BattleView
extends Control

## Боевая сцена использует ту же шкалу здоровья, что и экран исследования.
## Сведения о здоровье, атаке и блоке берутся из CombatSession/HeroState.
signal battle_won
signal battle_lost
signal shield_broken(item_id: String)

@onready var _hero_health_meter: HealthMeter = $OuterMargin/Main/Battlefield/HeroCard/HeroMargin/HeroColumn/HeroHealthMeter
@onready var _enemy_health_meter: HealthMeter = $OuterMargin/Main/Battlefield/EnemyCard/EnemyMargin/EnemyColumn/EnemyHealthMeter
@onready var _hero_portrait: TextureRect = %HeroPortrait
@onready var _hero_attack_icon: TextureRect = %HeroAttackIcon
@onready var _hero_attack_value: Label = %HeroAttackValue
@onready var _hero_defense_icon: TextureRect = %HeroDefenseIcon
@onready var _hero_defense_value: Label = %HeroDefenseValue
@onready var _hero_name: Label = $OuterMargin/Main/Battlefield/HeroCard/HeroMargin/HeroColumn/HeroName
@onready var _enemy_attack_value: Label = %EnemyAttackValue
@onready var _enemy_defense_value: Label = %EnemyDefenseValue
@onready var _enemy_defense_icon: TextureRect = %EnemyDefenseIcon
@onready var _enemy_name: Label = %EnemyName
@onready var _enemy_portrait: TextureRect = %EnemyPortrait
@onready var _punch_button: Button = %PunchButton
@onready var _guard_button: Button = %GuardButton
@onready var _result_text: Label = %ResultText
@onready var _sequence_slots: HBoxContainer = %SequenceSlots

const ABILITY_SLOT_SCENE: PackedScene = preload("res://scenes/battle_ability_slot.tscn")

var _combat: CombatSession
var _hero_attack_damage: int = CombatSession.PUNCH_DAMAGE
var _attack_name: String = "Удар кулаком"
var _defense_idle_color: Color = Color.WHITE
var _default_attack_icon: Texture2D
var _hero_chain: Array[String] = []
var _enemy_chain: Array[String] = []
var _playback: Tween
var _is_playing_back: bool = false
var _planner_editing: Array[String] = []
## Зафиксированная раскладка слотов, включая пропуски между приёмами.
var _committed_slots: Array[String] = []
var _ability_picker: PanelContainer
var _picker_grid: GridContainer
var _picker_actions: HBoxContainer
var _picker_target: int = -1


func _ready() -> void:
	_punch_button.pressed.connect(_on_punch_pressed)
	_guard_button.pressed.connect(_on_guard_pressed)
	_guard_button.icon = preload("res://assets/hud/menu.png")
	_punch_button.disabled = true
	_guard_button.visible = false
	_build_ability_picker()
	_default_attack_icon = _hero_attack_icon.texture
	_result_text.text = "Твой ход"
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.24)


func begin(combat: CombatSession, hero: HeroState) -> void:
	_combat = combat
	if hero.definition != null:
		_hero_name.text = hero.definition.display_name
		_hero_portrait.texture = hero.definition.portrait
	_hero_attack_damage = hero.attack
	var equipped_weapon: ItemDefinition = ItemCatalog.get_item(hero.equipped_weapon_id)
	_attack_name = "Удар: " + equipped_weapon.display_name if equipped_weapon != null else "Удар кулаком"
	var weapon: ItemDefinition = ItemCatalog.get_item(hero.equipped_weapon_id)
	var weapon_icon: Texture2D = weapon.icon if weapon != null else _default_attack_icon
	_punch_button.text = "%s  ·  %d" % [_attack_name, _hero_attack_damage]
	_punch_button.icon = weapon_icon
	_hero_attack_icon.texture = weapon_icon
	_hero_attack_value.text = str(hero.attack)
	var shield_item: ItemDefinition = ItemCatalog.get_item(hero.equipped_shield_id)
	_hero_defense_value.text = str(shield_item.defense_bonus if shield_item != null else hero.defense)
	_defense_idle_color = Color.WHITE if shield_item != null or hero.defense > 0 else Color(0.55, 0.60, 0.67, 0.65)
	_hero_defense_icon.modulate = _defense_idle_color
	_enemy_name.text = combat.enemy_definition.display_name
	_enemy_attack_value.text = str(combat.enemy_damage)
	_enemy_defense_value.text = str(combat.enemy_defense)
	_enemy_defense_icon.modulate = Color.WHITE if combat.enemy_defense > 0 else Color(0.55, 0.60, 0.67, 0.65)
	_enemy_portrait.texture = combat.enemy_definition.icon
	_enemy_portrait.modulate = Color.WHITE
	_hero_health_meter.set_health(hero.health, hero.max_health)
	_enemy_health_meter.set_health(combat.enemy_health, combat.enemy_max_health)
	# В рамках прохождения сохраняем именно позиции, включая пустые слоты.
	_committed_slots = hero.get_saved_action_slots()
	_set_draft_from_chain(_committed_slots)
	_hero_chain = _draft_actions()
	_enemy_chain = _combat.battle_state.default_chain("enemy")
	_result_text.text = ""
	_refresh_phase_controls()


func _editing_allowed() -> bool:
	if _combat == null or _is_playing_back:
		return false
	var stage: int = _combat.battle_state.flow.stage
	return stage == BattleFlow.Stage.PREPARATION or stage == BattleFlow.Stage.RECONFIGURING


func _set_draft_from_chain(slots: Array[String]) -> void:
	_planner_editing.clear()
	var capacity: int = _combat.battle_state.get_hero().action_slot_capacity
	for index in range(capacity):
		_planner_editing.append(slots[index] if index < slots.size() else "")


func _draft_actions() -> Array[String]:
	var result: Array[String] = []
	for action_id in _planner_editing:
		if not action_id.is_empty():
			result.append(action_id)
	return result


func _refresh_chain_slots() -> void:
	for child in _sequence_slots.get_children():
		_sequence_slots.remove_child(child)
		child.queue_free()
	var editable: bool = _editing_allowed()
	for index in range(_planner_editing.size()):
		var action_id: String = _planner_editing[index]
		var ability: AbilityDefinition = AbilityCatalog.get_ability(action_id)
		var slot: BattleAbilitySlot = ABILITY_SLOT_SCENE.instantiate() as BattleAbilitySlot
		_sequence_slots.add_child(slot)
		slot.configure(index, ability, editable, _combat.battle_state.get_hero())
		slot.slot_selected.connect(_on_slot_selected)


func _build_ability_picker() -> void:
	# Контекстная панель, а не отдельный экран поверх боя.
	_ability_picker = PanelContainer.new()
	_ability_picker.name = "AbilityPicker"
	_ability_picker.theme = preload("res://themes/hero_hud.tres")
	_ability_picker.custom_minimum_size.x = 336.0
	_ability_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_ability_picker.z_index = 10
	_ability_picker.visible = false
	add_child(_ability_picker)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_ability_picker.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := Label.new()
	title.text = "ПРИЁМЫ"
	title.add_theme_color_override("font_color", Color("#e8c58a"))
	title.add_theme_font_size_override("font_size", 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Закрыть список"
	close_button.custom_minimum_size = Vector2(40, 40)
	_style_picker_button(close_button)
	close_button.pressed.connect(_hide_ability_picker)
	title_row.add_child(close_button)
	var scroll := ScrollContainer.new()
	scroll.name = "AbilityPickerScroll"
	scroll.custom_minimum_size.y = 74.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(scroll)
	_picker_grid = GridContainer.new()
	_picker_grid.columns = 1
	_picker_grid.add_theme_constant_override("h_separation", 6)
	_picker_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_picker_grid)
	_picker_actions = HBoxContainer.new()
	_picker_actions.add_theme_constant_override("separation", 6)
	column.add_child(_picker_actions)


func _style_picker_button(button: Button) -> void:
	# Общая тёмная палитра со штатной темой боевого HUD.
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#192a38")
	normal.border_color = Color("#546779")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#25394a")
	hover.border_color = Color("#e0bd7a")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	var pressed: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#3e3524")
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#17212a")
	disabled.border_color = Color("#303e49")
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_constant_override("icon_max_width", 30)


func _on_slot_selected(index: int) -> void:
	if not _editing_allowed():
		return
	if _ability_picker.visible and _picker_target == index:
		_hide_ability_picker()
		return
	_picker_target = index
	_populate_ability_picker(index)
	_ability_picker.show()
	_position_ability_picker()
	# После раскладки Container его фактический размер может уточниться.
	call_deferred("_position_ability_picker")


func _populate_ability_picker(index: int) -> void:
	for child in _picker_grid.get_children():
		_picker_grid.remove_child(child)
		child.queue_free()
	for child in _picker_actions.get_children():
		_picker_actions.remove_child(child)
		child.queue_free()
	var actor: BattleParticipant = _combat.battle_state.get_hero()
	var available: Array[AbilityDefinition] = AbilityCatalog.available_abilities(actor)
	var shown: int = 0
	for ability in available:
		var choice := Button.new()
		choice.custom_minimum_size = Vector2(306, 48)
		choice.clip_text = true
		choice.expand_icon = true
		choice.text = ability.display_name
		choice.icon = BattleAbilitySlot.visual_icon(ability)
		choice.tooltip_text = BattleAbilityTooltip.describe(ability, actor)
		choice.disabled = not AbilityCatalog.can_prepare(actor, ability.ability_id)
		_style_picker_button(choice)
		choice.pressed.connect(_choose_ability.bind(index, ability.ability_id))
		_picker_grid.add_child(choice)
		shown += 1
	var scroll: ScrollContainer = _picker_grid.get_parent() as ScrollContainer
	scroll.custom_minimum_size.y = minf(228.0, maxf(52.0, float(shown) * 52.0))
	if not _planner_editing[index].is_empty():
		_add_picker_action("←", "Сдвинуть приём влево", index > 0, _move_draft.bind(index, -1))
		_add_picker_action("→", "Сдвинуть приём вправо", index + 1 < _planner_editing.size(), _move_draft.bind(index, 1))
		_add_picker_action("✕ Убрать", "Очистить ячейку", true, _clear_draft.bind(index))


func _add_picker_action(caption: String, hint: String, enabled: bool, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.tooltip_text = hint
	button.disabled = not enabled
	button.custom_minimum_size.y = 42.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_picker_button(button)
	button.pressed.connect(callback)
	_picker_actions.add_child(button)


func _position_ability_picker() -> void:
	if not _ability_picker.visible or _picker_target < 0:
		return
	if _picker_target >= _sequence_slots.get_child_count():
		return
	var slot: Control = _sequence_slots.get_child(_picker_target) as Control
	var rect: Rect2 = slot.get_global_rect()
	var size_needed: Vector2 = _ability_picker.get_combined_minimum_size()
	_ability_picker.size = size_needed
	var local_pos: Vector2 = rect.position - global_position
	var x: float = clampf(local_pos.x + rect.size.x * 0.5 - size_needed.x * 0.5,
		8.0, maxf(8.0, size.x - size_needed.x - 8.0))
	var y: float = local_pos.y - size_needed.y - 8.0
	if y < 8.0:
		y = local_pos.y + rect.size.y + 8.0
	y = clampf(y, 8.0, maxf(8.0, size.y - size_needed.y - 8.0))
	_ability_picker.position = Vector2(x, y)


func _choose_ability(index: int, ability_id: String) -> void:
	if not _editing_allowed() or index < 0 or index >= _planner_editing.size():
		return
	if not AbilityCatalog.can_prepare(_combat.battle_state.get_hero(), ability_id):
		return
	_planner_editing[index] = ability_id
	_hide_ability_picker()
	_refresh_phase_controls()


func _clear_draft(index: int) -> void:
	if not _editing_allowed() or index < 0 or index >= _planner_editing.size():
		return
	_planner_editing[index] = ""
	_hide_ability_picker()
	_refresh_phase_controls()


func _move_draft(index: int, offset: int) -> void:
	if not _editing_allowed():
		return
	var other: int = index + offset
	if other < 0 or other >= _planner_editing.size():
		return
	var previous: String = _planner_editing[index]
	_planner_editing[index] = _planner_editing[other]
	_planner_editing[other] = previous
	_hide_ability_picker()
	_refresh_phase_controls()


func _hide_ability_picker() -> void:
	_ability_picker.hide()
	_picker_target = -1


func _point_is_on_slot(point: Vector2) -> bool:
	for node in _sequence_slots.get_children():
		var slot: Control = node as Control
		if slot != null and slot.get_global_rect().has_point(point):
			return true
	return false


func _input(event: InputEvent) -> void:
	if _ability_picker == null or not _ability_picker.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_hide_ability_picker()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if not _ability_picker.get_global_rect().has_point(event.position) and not _point_is_on_slot(event.position):
			_hide_ability_picker()
	elif event is InputEventScreenTouch and event.pressed:
		if not _ability_picker.get_global_rect().has_point(event.position) and not _point_is_on_slot(event.position):
			_hide_ability_picker()


func _commit_draft() -> bool:
	var actions: Array[String] = _draft_actions()
	var response: Dictionary = _combat.battle_state.configure_hero_chain(actions)
	if not bool(response.get("success", false)):
		_result_text.text = str(response.get("reason", "Проверь алгоритм"))
		return false
	_hero_chain = actions.duplicate()
	_committed_slots = _planner_editing.duplicate()
	if _combat.hero != null:
		_combat.hero.save_action_slots(_committed_slots)
	return true


func _on_punch_pressed() -> void:
	if _combat == null or _punch_button.disabled:
		return
	var flow: BattleFlow = _combat.battle_state.flow
	if flow.stage == BattleFlow.Stage.RECONFIGURING:
		if _commit_draft():
			_combat.confirm_tactic_change()
			_result_text.text = "Алгоритм сохранён."
			_refresh_phase_controls()
		return
	if flow.stage == BattleFlow.Stage.PREPARATION and not _commit_draft():
		_refresh_phase_controls()
		return
	_hide_ability_picker()
	_is_playing_back = true
	var result: Dictionary = _combat.play_phase(_hero_chain, _enemy_chain)
	if not bool(result.get("success", false)):
		_is_playing_back = false
		_result_text.text = str(result.get("reason", "Фаза недоступна"))
		_refresh_phase_controls()
		return
	_refresh_phase_controls()
	_play_phase_events(result.get("events", []))


func _on_guard_pressed() -> void:
	if _combat == null or _guard_button.disabled:
		return
	var flow: BattleFlow = _combat.battle_state.flow
	if flow.stage == BattleFlow.Stage.RECONFIGURING:
		_combat.battle_state.flow.cancel_reconfiguration()
		_set_draft_from_chain(_committed_slots)
		_result_text.text = "Изменения отменены"
	elif flow.stage == BattleFlow.Stage.BETWEEN_PHASES and _combat.request_tactic_change():
		_set_draft_from_chain(_committed_slots)
		_result_text.text = "Перенастройка"
	_refresh_phase_controls()


func _play_phase_events(phase_events: Array) -> void:
	# События уже вычислены моделью. Этот Tween управляет только показом.
	_playback = create_tween()
	for raw_event in phase_events:
		var event: Dictionary = raw_event
		_playback.tween_callback(Callable(self, "_display_phase_event").bind(event))
		var actor_id: String = str(event.get("actor_id", ""))
		var portrait: TextureRect = _hero_portrait if actor_id == "hero" else _enemy_portrait
		_playback.tween_property(portrait, "modulate", Color(1.0, 0.75, 0.48), 0.12)
		_playback.tween_property(portrait, "modulate", Color.WHITE, 0.16)
	_playback.tween_callback(_after_phase_playback)


func _display_phase_event(event: Dictionary) -> void:
	var actor_id: String = str(event.get("actor_id", ""))
	var actor_name: String = _hero_name.text if actor_id == "hero" else _enemy_name.text
	var ability: AbilityDefinition = AbilityCatalog.get_ability(str(event.get("ability_id", "")))
	var label_text: String = ability.display_name if ability != null else "Действие"
	match str(event.get("type", "")):
		"attack":
			_result_text.text = "%s: %s (−%d HP)" % [actor_name, label_text, int(event.get("damage", 0))]
		"block":
			_result_text.text = "%s: %s (броня %d)" % [actor_name, label_text, int(event.get("armor", 0))]
		"heal":
			_result_text.text = "%s: %s (+%d HP)" % [actor_name, label_text, int(event.get("healed", 0))]
		"failed":
			_result_text.text = "%s: %s" % [actor_name, str(event.get("reason", "Приём недоступен"))]
		_:
			_result_text.text = "%s: %s" % [actor_name, label_text]


func _after_phase_playback() -> void:
	_is_playing_back = false
	_hero_health_meter.set_health(_combat.hero.health, _combat.hero.max_health, true)
	_enemy_health_meter.set_health(_combat.enemy_health, _combat.enemy_max_health, true)
	# При нескольких ударах за фазу щит мог сломаться не на последнем.
	# Берём ID из событий, а не из состояния последнего попадания.
	for event in _combat.battle_state.last_phase_events:
		var broken_id: String = str(event.get("shield_broken", ""))
		if not broken_id.is_empty():
			_combat.hero.last_shield_broken = broken_id
			_hero_defense_value.text = str(_combat.hero.defense)
			shield_broken.emit(broken_id)
			_combat.hero.last_shield_broken = ""
			var hero_actor: BattleParticipant = _combat.battle_state.get_hero()
			if hero_actor != null and hero_actor._hero_snapshot != null:
				hero_actor._hero_snapshot.last_shield_broken = ""
	if _combat.is_victory:
		_show_victory()
	elif _combat.is_defeat:
		_show_defeat()
	else:
		_result_text.text = "Фаза %d завершена." % _combat.battle_state.flow.phase_number
		_refresh_phase_controls()


func _refresh_phase_controls() -> void:
	if _combat == null:
		return
	var flow: BattleFlow = _combat.battle_state.flow
	var stage: int = flow.stage
	var editable: bool = _editing_allowed()
	if not editable and _ability_picker.visible:
		_hide_ability_picker()
	_refresh_chain_slots()
	var draft: Array[String] = _draft_actions()
	var valid_draft: bool = not draft.is_empty() and BattleChainPlanner.validate(
		draft, _combat.battle_state.get_hero()).is_empty()
	_punch_button.disabled = (_is_playing_back or stage == BattleFlow.Stage.EXECUTING or stage == BattleFlow.Stage.FINISHED or
		(editable and not valid_draft) or (not editable and _hero_chain.is_empty()))
	match stage:
		BattleFlow.Stage.PREPARATION:
			_punch_button.text = "Начать бой"
		BattleFlow.Stage.RECONFIGURING:
			_punch_button.text = "Сохранить алгоритм"
		_:
			_punch_button.text = "Следующая фаза"
	_guard_button.visible = not _is_playing_back and (stage == BattleFlow.Stage.RECONFIGURING or
		(stage == BattleFlow.Stage.BETWEEN_PHASES and flow.reconfiguration_tokens > 0))
	_guard_button.disabled = _is_playing_back or stage == BattleFlow.Stage.EXECUTING or stage == BattleFlow.Stage.FINISHED
	_guard_button.text = "Отмена" if stage == BattleFlow.Stage.RECONFIGURING else "Изменить тактику"


func _show_victory() -> void:
	_result_text.text = "ПОБЕДА!"
	_finish_battle(true)


func _show_defeat() -> void:
	_result_text.text = "ПОРАЖЕНИЕ"
	_finish_battle(false)


func _finish_battle(won: bool) -> void:
	var ending: Tween = create_tween()
	ending.tween_interval(0.6)
	ending.tween_property(self, "modulate:a", 0.0, 0.25)
	if won:
		ending.tween_callback(_emit_victory)
	else:
		ending.tween_callback(_emit_defeat)


func _emit_victory() -> void:
	battle_won.emit()


func _emit_defeat() -> void:
	battle_lost.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if _ability_picker.visible:
		return
	if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and not _punch_button.disabled:
		_on_punch_pressed()
		get_viewport().set_input_as_handled()
