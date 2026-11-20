class_name BattleView
extends Control

## Боевая сцена использует ту же шкалу здоровья, что и экран исследования.
## Сведения о здоровье, атаке и блоке берутся из CombatSession/HeroState.
signal battle_won
signal battle_lost
signal shield_broken(item_id: String)
signal combat_log_line(message: String)
signal item_use_requested(item_id: String)

@onready var _hero_health_meter: HealthMeter = $OuterMargin/Main/Battlefield/HeroCard/HeroMargin/HeroColumn/HeroHealthMeter
@onready var _enemy_health_meter: HealthMeter = $OuterMargin/Main/Battlefield/EnemyCard/EnemyMargin/EnemyColumn/EnemyHealthMeter
@onready var _hero_portrait: TextureRect = %HeroPortrait
@onready var _hero_attack_icon: TextureRect = %HeroAttackIcon
@onready var _hero_attack_value: Label = %HeroAttackValue
@onready var _hero_strength_value: Label = %HeroStrengthValue
@onready var _hero_agility_value: Label = %HeroAgilityValue
@onready var _hero_dodge_value: Label = %HeroDodgeValue
@onready var _hero_accuracy_value: Label = %HeroAccuracyValue
@onready var _hero_defense_icon: TextureRect = %HeroDefenseIcon
@onready var _hero_defense_value: Label = %HeroDefenseValue
@onready var _hero_name: Label = $OuterMargin/Main/Battlefield/HeroCard/HeroMargin/HeroColumn/HeroName
@onready var _enemy_attack_value: Label = %EnemyAttackValue
@onready var _enemy_strength_value: Label = %EnemyStrengthValue
@onready var _enemy_agility_value: Label = %EnemyAgilityValue
@onready var _enemy_dodge_value: Label = %EnemyDodgeValue
@onready var _enemy_accuracy_value: Label = %EnemyAccuracyValue
@onready var _enemy_defense_value: Label = %EnemyDefenseValue
@onready var _enemy_defense_icon: TextureRect = %EnemyDefenseIcon
@onready var _enemy_name: Label = %EnemyName
@onready var _enemy_portrait: TextureRect = %EnemyPortrait
@onready var _punch_button: Button = %PunchButton
@onready var _guard_button: Button = %GuardButton
@onready var _combat_items_button: Button = %CombatItemsButton
@onready var _result_text: Label = %ResultText
@onready var _sequence_slots: HBoxContainer = %SequenceSlots
@onready var _enemy_sequence_slots: HBoxContainer = %EnemySequenceSlots
@onready var _battlefield: HBoxContainer = $OuterMargin/Main/Battlefield
@onready var _hero_chain_title: Label = %HeroChainTitle
@onready var _enemy_chain_title: Label = %EnemyChainTitle

# Pixel sizes for the combat ability chooser; keep icon/row/scroll sizes in sync.
const PICKER_ICON_WIDTH: int = 54
const PICKER_CHOICE_WIDTH: float = 306.0
const PICKER_CHOICE_HEIGHT: float = 70.0
const PICKER_ROW_SPACING: float = 6.0
const PICKER_MAX_LIST_HEIGHT: float = 260.0

const ABILITY_SLOT_SCENE: PackedScene = preload("res://scenes/battle_ability_slot.tscn")

var _combat: CombatSession
var _hero_attack_damage: int = 0
var _attack_name: String = "Удар кулаком"
var _defense_idle_color: Color = Color.WHITE
var _default_attack_icon: Texture2D
var _hero_chain: Array[String] = []
var _enemy_chain: Array[String] = []
## Карты врага раскрываются навсегда в рамках одной встречи.
var _enemy_revealed: Dictionary = {}
var _playback: Tween
var _is_playing_back: bool = false
var _planner_editing: Array[String] = []
## Зафиксированная раскладка слотов, включая пропуски между приёмами.
var _committed_slots: Array[String] = []
var _ability_picker: PanelContainer
var _picker_grid: GridContainer
var _picker_actions: HBoxContainer
var _picker_target: int = -1
var _items_session: GameSession
var _item_picker: BattleItemPicker
## Два временных портрета поверх поля: движение не меняет настоящие UI-узлы.
var _impact_layer: Control
var _impact_portraits: Dictionary = {}
var _impact_idle: Dictionary = {}
var _impact_origin: Dictionary = {}
var _impact_shields: Dictionary = {}
var _shield_flash_tweens: Dictionary = {}
var _status_presenter: BattleStatusPresenter
var _support_enemy_view: BattleSupportEnemyView
var _visible_hero_hp: int = 0
var _visible_enemy_hp: int = 0
var _visible_support_hp: int = 0

# Длительность визуальной вспышки совпадает с паузой события «Блок».
# Эти параметры меняют только анимацию, не время действия защиты.
const SHIELD_FLASH_IN_SECONDS: float = 0.18
const SHIELD_FLASH_OUT_SECONDS: float = 1.00
const SHIELD_FLASH_START_SCALE: float = 0.25
const SHIELD_FLASH_PEAK_SCALE: float = 1.08
const SHIELD_FLASH_COLOR: Color = Color(0.40, 0.78, 1.0, 1.0)



func _ready() -> void:
	_punch_button.pressed.connect(_on_punch_pressed)
	_guard_button.pressed.connect(_on_guard_pressed)
	_combat_items_button.pressed.connect(_on_combat_items_pressed)
	_combat_items_button.icon = preload("res://assets/icons/potion.png")
	_combat_items_button.tooltip_text = "Боевые зелья"
	_combat_items_button.disabled = true
	_guard_button.icon = preload("res://assets/hud/menu.png")
	_punch_button.disabled = true
	_guard_button.visible = false
	_build_ability_picker()
	_build_combat_item_picker()
	_default_attack_icon = _hero_attack_icon.texture
	_status_presenter = BattleStatusPresenter.new(self)
	_status_presenter.setup({"hero": _hero_portrait, "enemy": _enemy_portrait})
	_support_enemy_view = BattleSupportEnemyView.new()
	_support_enemy_view.name = "SupportEnemy"
	_support_enemy_view.theme = ($OuterMargin/Main/Battlefield/EnemyCard as PanelContainer).theme
	_battlefield.add_child(_support_enemy_view)
	_support_enemy_view.hide()
	_result_text.text = "Твой ход"
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.24)


## Единственный расчёт: тот же метод, что использует обработчик способности.
func _basic_strike_damage(actor: BattleParticipant) -> int:
	return actor.melee_attack() if actor != null else 0


func begin(combat: CombatSession, hero: HeroState) -> void:
	_combat = combat
	var support_definition: MonsterDefinition = combat.support_enemy_definition if combat.support_enemy_definition != null else combat.enemy_definition
	var support: BattleParticipant = combat.battle_state.get_participant(combat.battle_state.support_enemy_id)
	var portrait: Texture2D = support_definition.portrait if support_definition.portrait != null else support_definition.icon
	var support_name: String = support_definition.display_name
	if support_definition.monster_id == combat.enemy_definition.monster_id:
		support_name += " (2)"
	_support_enemy_view.configure(support, portrait, support_name)
	if support != null:
		_status_presenter.setup({combat.battle_state.support_enemy_id: _support_enemy_view.portrait_node()})
	if hero.definition != null:
		_hero_name.text = hero.definition.display_name
		_hero_portrait.texture = hero.definition.portrait
	_hero_attack_damage = _basic_strike_damage(_combat.battle_state.get_hero())
	var equipped_weapon: ItemDefinition = ItemCatalog.get_item(hero.equipped_weapon_id)
	_attack_name = "Удар: " + equipped_weapon.display_name if equipped_weapon != null else "Удар кулаком"
	var weapon: ItemDefinition = ItemCatalog.get_item(hero.equipped_weapon_id)
	var weapon_icon: Texture2D = weapon.icon if weapon != null else _default_attack_icon
	_punch_button.text = "%s  ·  %d" % [_attack_name, _hero_attack_damage]
	_punch_button.icon = weapon_icon
	_hero_attack_icon.texture = weapon_icon
	_hero_attack_value.text = str(_basic_strike_damage(_combat.battle_state.get_hero()))
	_hero_strength_value.text = "СИЛ %d" % hero.strength
	_hero_agility_value.text = "ЛОВ %d" % hero.agility
	_refresh_accuracy_and_dodge()
	_hero_defense_value.text = str(_combat.battle_state.get_hero().block_armor)
	_defense_idle_color = Color(0.55, 0.60, 0.67, 0.65)
	_hero_defense_icon.modulate = _defense_idle_color
	_hero_chain_title.text = _hero_name.text.to_upper()
	_enemy_name.text = combat.enemy_definition.display_name
	_enemy_chain_title.text = _enemy_name.text.to_upper()
	_enemy_attack_value.text = str(_basic_strike_damage(_combat.battle_state.get_enemy()))
	_enemy_strength_value.text = "СИЛ %d" % _combat.battle_state.get_enemy().strength
	_enemy_agility_value.text = "ЛОВ %d" % _combat.battle_state.get_enemy().agility
	_enemy_defense_value.text = str(_combat.battle_state.get_enemy().block_armor)
	_enemy_defense_icon.modulate = Color(0.55, 0.60, 0.67, 0.65)
	_enemy_portrait.texture = combat.enemy_definition.portrait if combat.enemy_definition.portrait != null else combat.enemy_definition.icon
	_enemy_portrait.modulate = Color.WHITE
	_hero_health_meter.set_health(hero.health, hero.max_health)
	_enemy_health_meter.set_health(combat.enemy_health, combat.enemy_max_health)
	_visible_hero_hp = hero.health
	_visible_enemy_hp = combat.enemy_health
	_visible_support_hp = support.health if support != null else 0
	_status_presenter.reset()
	_status_presenter.sync(_combat.battle_state.participants)
	# В рамках прохождения сохраняем именно позиции, включая пустые слоты.
	_committed_slots = hero.get_saved_action_slots()
	# Preserve positions but discard obsolete skills after a character's tree changed.
	var playable: BattleParticipant = _combat.battle_state.get_hero()
	for i in range(_committed_slots.size()):
		if not _committed_slots[i].is_empty() and not AbilityCatalog.knows_ability(playable, _committed_slots[i]):
			_committed_slots[i] = ""
	_set_draft_from_chain(_committed_slots)
	hero.save_action_slots(_committed_slots)
	_hero_chain = _draft_actions()
	_enemy_chain = _combat.battle_state.default_chain("enemy")
	_enemy_revealed.clear()
	_refresh_enemy_slots()
	_result_text.text = ""
	_refresh_phase_controls()


func _editing_allowed() -> bool:
	if _combat == null or _is_playing_back:
		return false
	var stage: int = _combat.battle_state.flow.stage
	return stage in [BattleFlow.Stage.PREPARATION, BattleFlow.Stage.BETWEEN_PHASES, BattleFlow.Stage.RECONFIGURING]


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
	# Отдых всегда следует после полного круга, но не входит в три
	# переставляемых слота и не сохраняется в HeroState.
	var rest_slot: BattleAbilitySlot = ABILITY_SLOT_SCENE.instantiate() as BattleAbilitySlot
	_sequence_slots.add_child(rest_slot)
	rest_slot.configure_recharge(_planner_editing.size())
	_highlight_next_actions()


func _refresh_enemy_slots() -> void:
	for child in _enemy_sequence_slots.get_children():
		_enemy_sequence_slots.remove_child(child)
		child.queue_free()
	var enemy: BattleParticipant = _combat.battle_state.get_enemy()
	var capacity: int = _enemy_chain.size() + 1
	for index in range(capacity):
		var slot: BattleAbilitySlot = ABILITY_SLOT_SCENE.instantiate() as BattleAbilitySlot
		_enemy_sequence_slots.add_child(slot)
		if index < _enemy_chain.size():
			if _enemy_revealed.has(index):
				slot.reveal_enemy_action(AbilityCatalog.get_ability(_enemy_chain[index]), enemy)
			else:
				slot.configure_hidden(index)
		else:
			slot.configure_recharge(index)
	if not _is_playing_back:
		_highlight_next_actions()


func _conceal_enemy_actions() -> void:
	# Скрывать можно только ещё не сыгранные позиции.
	for index in range(_enemy_chain.size()):
		if not _enemy_revealed.has(index):
			(_enemy_sequence_slots.get_child(index) as BattleAbilitySlot).configure_hidden(index)


func _highlight_slots(hero_index: int, enemy_index: int, hero_reloading: bool = false, enemy_reloading: bool = false) -> void:
	for index in range(_sequence_slots.get_child_count()):
		var active: bool = index == _planner_editing.size() if hero_reloading else index == hero_index
		(_sequence_slots.get_child(index) as BattleAbilitySlot).set_current(active)
	for index in range(_enemy_sequence_slots.get_child_count()):
		var active: bool = index == enemy_index if not enemy_reloading else index == _enemy_chain.size()
		(_enemy_sequence_slots.get_child(index) as BattleAbilitySlot).set_current(active)


func _highlight_next_actions() -> void:
	if _combat == null:
		return
	var hero: BattleParticipant = _combat.battle_state.get_hero()
	var enemy: BattleParticipant = _combat.battle_state.get_enemy()
	if hero == null or enemy == null:
		return
	# После завершения отдыха курсор героя уже на первом слоте.
	var hero_index: int = hero.action_cursor
	var enemy_index: int = enemy.action_cursor if enemy.is_alive() else -1
	_highlight_slots(hero_index, enemy_index)


func current_battle_state() -> BattleState:
	return _combat.battle_state if _combat != null else null


func bind_combat_items(session: GameSession) -> void:
	_items_session = session
	_refresh_combat_items_button()


func _build_combat_item_picker() -> void:
	_item_picker = BattleItemPicker.new()
	_item_picker.name = "BattleItemPicker"
	_item_picker.hide()
	add_child(_item_picker)
	_item_picker.closed.connect(_hide_combat_item_picker)
	_item_picker.item_selected.connect(_on_combat_item_chosen)


func _refresh_combat_items_button() -> void:
	if _combat == null:
		_combat_items_button.disabled = true
		return
	var count: int = 0
	if _items_session != null:
		for item_id in _items_session.combat_item_ids():
			count += int(_items_session.carried_items.get(item_id, 0))
	_combat_items_button.text = "×%d" % count
	_combat_items_button.disabled = (_is_playing_back or not _combat.battle_state.flow.can_use_item() or count == 0)
	if _item_picker != null and _item_picker.visible and _combat_items_button.disabled:
		_hide_combat_item_picker()


func _on_combat_items_pressed() -> void:
	if _combat_items_button.disabled or _items_session == null:
		return
	if _item_picker.visible:
		_hide_combat_item_picker()
		return
	_hide_ability_picker()
	_item_picker.refresh_items(_items_session)
	_item_picker.show()
	_position_combat_item_picker()
	call_deferred("_position_combat_item_picker")


func _position_combat_item_picker() -> void:
	if _item_picker == null or not _item_picker.visible:
		return
	var rect: Rect2 = _combat_items_button.get_global_rect()
	var size_needed: Vector2 = _item_picker.get_combined_minimum_size()
	var local: Vector2 = rect.position - global_position
	var x: float = clampf(local.x + rect.size.x - size_needed.x, 8.0,
		maxf(8.0, size.x - size_needed.x - 8.0))
	var y: float = local.y - size_needed.y - 8.0
	if y < 8.0:
		y = local.y + rect.size.y + 8.0
	_item_picker.position = Vector2(x, clampf(y, 8.0, maxf(8.0, size.y - size_needed.y - 8.0)))


func _hide_combat_item_picker() -> void:
	if _item_picker != null:
		_item_picker.hide()


func _on_combat_item_chosen(item_id: String) -> void:
	if _combat != null and not _is_playing_back and _combat.battle_state.flow.can_use_item():
		item_use_requested.emit(item_id)


## Отображает подтверждённый GameSession результат, не рассчитывая эффекты.
func show_combat_item_result(result: Dictionary, session: GameSession) -> void:
	if _combat == null or session == null or session.hero == null:
		return
	if bool(result.get("used", false)):
		_visible_hero_hp = session.hero.health
		_hero_health_meter.set_health(_visible_hero_hp, session.hero.max_health, true)
		_hero_attack_value.text = str(_basic_strike_damage(_combat.battle_state.get_hero()))
		_result_text.text = str(result.get("message", ""))
	elif not str(result.get("message", "")).is_empty():
		_result_text.text = str(result["message"])
	_refresh_combat_items_button()
	if _item_picker != null and _item_picker.visible:
		if _combat_items_button.disabled:
			_hide_combat_item_picker()
		else:
			_item_picker.refresh_items(session)
			_position_combat_item_picker()


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
	_picker_grid.add_theme_constant_override("v_separation", int(PICKER_ROW_SPACING))
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
	button.add_theme_constant_override("icon_max_width", PICKER_ICON_WIDTH)


func _on_slot_selected(index: int) -> void:
	if not _editing_allowed():
		return
	if _ability_picker.visible and _picker_target == index:
		_hide_ability_picker()
		return
	_hide_combat_item_picker()
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
		choice.custom_minimum_size = Vector2(PICKER_CHOICE_WIDTH, PICKER_CHOICE_HEIGHT)
		choice.clip_text = true
		choice.expand_icon = true
		choice.text = ability.display_name
		choice.icon = BattleAbilitySlot.visual_icon(ability)
		choice.tooltip_text = BattleAbilityTooltip.describe(ability, actor, index)
		var reason: String = AbilityCatalog.unavailable_reason(actor, ability.ability_id)
		if not reason.is_empty() and not choice.tooltip_text.contains(reason):
			choice.tooltip_text += "\nНедоступно: " + reason
		choice.disabled = not reason.is_empty()
		_style_picker_button(choice)
		choice.pressed.connect(_choose_ability.bind(index, ability.ability_id))
		_picker_grid.add_child(choice)
		shown += 1
	var scroll: ScrollContainer = _picker_grid.get_parent() as ScrollContainer
	scroll.custom_minimum_size.y = minf(PICKER_MAX_LIST_HEIGHT, maxf(PICKER_CHOICE_HEIGHT, float(shown) * (PICKER_CHOICE_HEIGHT + PICKER_ROW_SPACING)))
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
	var abilities_open: bool = _ability_picker != null and _ability_picker.visible
	var items_open: bool = _item_picker != null and _item_picker.visible
	if not abilities_open and not items_open:
		return
	if event.is_action_pressed("ui_cancel"):
		_hide_ability_picker()
		_hide_combat_item_picker()
		get_viewport().set_input_as_handled()
		return
	var point: Vector2
	if event is InputEventMouseButton and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	else:
		return
	if abilities_open and not _ability_picker.get_global_rect().has_point(point) and not _point_is_on_slot(point):
		_hide_ability_picker()
	if items_open and not _item_picker.get_global_rect().has_point(point) and not _combat_items_button.get_global_rect().has_point(point):
		_hide_combat_item_picker()


func _commit_draft() -> bool:
	# Незанятая позиция не считается действием. Показываем ошибку только
	# красным миганием самих ячеек, без текстовых инструкций.
	var missing: bool = false
	for index in range(_planner_editing.size()):
		if _planner_editing[index].is_empty():
			missing = true
			(_sequence_slots.get_child(index) as BattleAbilitySlot).flash_empty()
	if missing:
		return false
	var actions: Array[String] = _draft_actions()
	var response: Dictionary = _combat.battle_state.configure_hero_chain(actions)
	if not bool(response.get("success", false)):
		_result_text.text = str(response.get("reason", ""))
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
	if flow.stage in [BattleFlow.Stage.PREPARATION, BattleFlow.Stage.BETWEEN_PHASES] and not _commit_draft():
		# Не пересоздаём слоты: иначе Tween красного мигания мгновенно погибнет.
		return
	_hide_ability_picker()
	_hide_combat_item_picker()
	_is_playing_back = true
	var result: Dictionary = _combat.play_phase(_hero_chain, _enemy_chain)
	if not bool(result.get("success", false)):
		_is_playing_back = false
		_result_text.text = str(result.get("reason", "Фаза недоступна"))
		_refresh_phase_controls()
		return
	_punch_button.disabled = true
	_guard_button.disabled = true
	_combat_items_button.disabled = true
	combat_log_line.emit("Бой · фаза %d" % int(result.get("phase_number", 0)))
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


func _create_impact_layer() -> void:
	_impact_layer = Control.new()
	_impact_layer.name = "CombatImpacts"
	_impact_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_impact_layer.z_index = 15
	add_child(_impact_layer)
	_impact_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_impact_layer.size = size
	_impact_portraits.clear()
	_impact_origin.clear()
	_impact_idle.clear()
	_impact_shields.clear()
	_shield_flash_tweens.clear()
	_status_presenter.clear_impact()
	var center: Vector2 = _battlefield.get_global_rect().get_center() - global_position
	var actor_ids: Array[String] = ["hero", "enemy"]
	if _combat.battle_state.get_participant(BattleState.SUPPORT_ENEMY_ID) != null:
		actor_ids.append(BattleState.SUPPORT_ENEMY_ID)
	for actor_id in actor_ids:
		var original: TextureRect = _hero_portrait if actor_id == "hero" else (_enemy_portrait if actor_id == "enemy" else _support_enemy_view.portrait_node())
		if original == null or original.texture == null:
			continue
		var portrait := TextureRect.new()
		portrait.name = "Impact_" + actor_id
		portrait.texture = original.texture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.size = original.size
		portrait.pivot_offset = portrait.size * 0.5
		portrait.position = original.global_position - global_position
		_impact_origin[actor_id] = portrait.position
		var idle_x: float = center.x - portrait.size.x * 1.12 if actor_id == "hero" else center.x + portrait.size.x * 0.12
		if actor_id == BattleState.SUPPORT_ENEMY_ID:
			idle_x = original.global_position.x - global_position.x
		_impact_idle[actor_id] = Vector2(idle_x, center.y - portrait.size.y * 0.5)
		_impact_layer.add_child(portrait)
		_impact_portraits[actor_id] = portrait
		var shield_icon := TextureRect.new()
		shield_icon.texture = BattleAbilitySlot.DEFENSE_ICON
		shield_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shield_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shield_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shield_icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
		shield_icon.size = portrait.size
		shield_icon.position = Vector2.ZERO
		shield_icon.pivot_offset = shield_icon.size * 0.5
		shield_icon.modulate = SHIELD_FLASH_COLOR
		shield_icon.modulate.a = 0.0
		shield_icon.hide()
		portrait.add_child(shield_icon)
		_impact_shields[actor_id] = shield_icon
		_status_presenter.attach_impact(actor_id, portrait)
		# Не hide(): скрытый узел изменил бы расчёт VBoxContainer и сдвинул HUD.
		original.modulate.a = 0.0


func _clear_impact_layer() -> void:
	for flash in _shield_flash_tweens.values():
		var tween: Tween = flash as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	_shield_flash_tweens.clear()
	_status_presenter.clear_impact()
	if _impact_layer != null and is_instance_valid(_impact_layer):
		_impact_layer.queue_free()
	_impact_layer = null
	_impact_portraits.clear()
	_impact_shields.clear()
	_hero_portrait.modulate.a = 1.0
	_enemy_portrait.modulate.a = 1.0
	if _support_enemy_view != null:
		_support_enemy_view.portrait_node().modulate.a = 1.0
	_highlight_next_actions()


func _play_phase_events(phase_events: Array) -> void:
	# Единственный расчёт уже выполнил BattleState. Здесь только режиссура.
	_create_impact_layer()
	_playback = create_tween()
	_playback.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var first_intro: bool = true
	for actor_id in _impact_portraits:
		var portrait: TextureRect = _impact_portraits[actor_id]
		if first_intro:
			_playback.tween_property(portrait, "position", _impact_idle[actor_id], 0.56)
			first_intro = false
		else:
			_playback.parallel().tween_property(portrait, "position", _impact_idle[actor_id], 0.56)
		_playback.parallel().tween_property(portrait, "scale", Vector2(1.5, 1.5), 0.56)
	_playback.tween_interval(0.16)
	for raw_event in phase_events:
		var event: Dictionary = raw_event
		var kind: String = str(event.get("type", ""))
		_playback.tween_callback(_display_phase_event.bind(event))
		match kind:
			"tick":
				_playback.tween_interval(0.20)
			"action_start":
				_playback.tween_interval(0.08)
			"enemy_chain_changed", "enemy_intermission_action":
				_playback.tween_interval(0.12)
			"attack":
				var actor_id: String = str(event.get("actor_id", ""))
				var target_id: String = str(event.get("target_id", ""))
				var actor: TextureRect = _impact_portraits.get(actor_id) as TextureRect
				var target: TextureRect = _impact_portraits.get(target_id) as TextureRect
				if actor == null or target == null:
					continue
				var direction: float = 1.0 if actor_id == "hero" else -1.0
				var windup: Vector2 = _impact_idle[actor_id] + Vector2(-direction * 30.0, 0)
				var contact: Vector2 = _impact_idle[target_id] + Vector2(-direction * actor.size.x * 0.84, 0)
				_playback.tween_property(actor, "position", windup, 0.20).set_trans(Tween.TRANS_QUAD)
				_playback.parallel().tween_property(actor, "rotation_degrees", -direction * 7.0, 0.20)
				_playback.tween_property(actor, "rotation_degrees", direction * 4.0, 0.065)
				_playback.tween_property(actor, "rotation_degrees", -direction * 4.0, 0.065)
				_playback.tween_property(actor, "position", contact, 0.13).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
				_playback.parallel().tween_property(actor, "rotation_degrees", 0.0, 0.13)
				_playback.tween_callback(_impact.bind(event))
				_playback.tween_property(target, "position", _impact_idle[target_id] + Vector2(direction * 12.0, 0), 0.08)
				_playback.tween_interval(0.46)
				_playback.tween_property(actor, "position", _impact_idle[actor_id], 0.27)
				_playback.parallel().tween_property(target, "position", _impact_idle[target_id], 0.27)
				_playback.parallel().tween_property(target, "modulate", Color.WHITE, 0.27)
			"block":
				_playback.tween_interval(0.40)
			"reload":
				_playback.tween_interval(0.42)
			_:
				_playback.tween_interval(0.40)
	var first_return: bool = true
	for actor_id in _impact_portraits:
		var portrait: TextureRect = _impact_portraits[actor_id]
		if first_return:
			_playback.tween_property(portrait, "position", _impact_origin[actor_id], 0.42)
			first_return = false
		else:
			_playback.parallel().tween_property(portrait, "position", _impact_origin[actor_id], 0.42)
		_playback.parallel().tween_property(portrait, "scale", Vector2.ONE, 0.42)
	_playback.tween_callback(_clear_impact_layer)
	_playback.tween_callback(_after_phase_playback)


func _display_phase_event(event: Dictionary) -> void:
	var actor_id: String = str(event.get("actor_id", ""))
	var kind: String = str(event.get("type", ""))
	# Удар записывается при контакте портретов, остальные события здесь.
	if kind != "attack" and not (kind == "rest" and bool(event.get("premature", false))):
		_emit_combat_event_log(event)
	match kind:
		"enemy_chain_changed":
			if actor_id == "enemy":
				_enemy_chain = _combat.battle_state.get_enemy().action_chain.duplicate()
				_enemy_revealed.clear()
				_refresh_enemy_slots()
			elif actor_id == BattleState.SUPPORT_ENEMY_ID and _support_enemy_view != null:
				_support_enemy_view.set_chain(_combat.battle_state.get_participant(actor_id))
		"tick":
			_conceal_enemy_actions()
			_highlight_slots(int(event.get("hero_slot", -1)), int(event.get("enemy_slot", -1)),
				bool(event.get("hero_reload", false)), bool(event.get("enemy_reload", false)))
			if _support_enemy_view != null:
				var support_slot: int = int(event.get("support_slot", -1))
				var support: BattleParticipant = _combat.battle_state.get_participant(BattleState.SUPPORT_ENEMY_ID)
				if support != null:
					_support_enemy_view.highlight_cursor(support.action_chain.size() if bool(event.get("support_reload", false)) else support_slot)
		"action_start":
			# Враг показывает только исполняемый сейчас приём, не будущие.
			if actor_id == "enemy":
				var index: int = int(event.get("slot_index", -1))
				if index >= 0 and index < _enemy_chain.size():
					_enemy_revealed[index] = true
					var slot: BattleAbilitySlot = _enemy_sequence_slots.get_child(index) as BattleAbilitySlot
					slot.reveal_enemy_action(AbilityCatalog.get_ability(str(event.get("ability_id", ""))),
						_combat.battle_state.get_enemy())
			elif actor_id == BattleState.SUPPORT_ENEMY_ID and _support_enemy_view != null:
				_support_enemy_view.reveal(int(event.get("slot_index", -1)), str(event.get("ability_id", "")))
		"block":
			var target_id: String = str(event.get("target_id", ""))
			_set_block_display(target_id, int(event.get("armor", 0)))
			_flash_shield(target_id)
		"block_consumed":
			_set_block_display(str(event.get("target_id", "")), int(event.get("armor", 0)))
		"heal":
			var healed: int = int(event.get("healed", 0))
			if actor_id == "hero":
				_visible_hero_hp += healed
				_hero_health_meter.set_health(_visible_hero_hp, _combat.hero.max_health, true)
			elif actor_id == "enemy":
				_visible_enemy_hp += healed
				_enemy_health_meter.set_health(_visible_enemy_hp, _combat.enemy_max_health, true)
			elif actor_id == BattleState.SUPPORT_ENEMY_ID:
				_visible_support_hp += healed
				_support_enemy_view.set_health(_visible_support_hp, _combat.battle_state.get_participant(actor_id).max_health)
			if healed > 0:
				_spawn_number(str(event.get("target_id", "")), "+%d" % healed, Color("#70d994"))
		"status_applied":
			_set_accuracy_and_dodge_from_event(event)
			_status_presenter.flash(str(event.get("target_id", "")), str(event.get("status_id", "")))
		"status_removed":
			_status_presenter.set_visible(str(event.get("target_id", "")), str(event.get("status_id", "")), false)
		"status_tick":
			var target_id: String = str(event.get("target_id", ""))
			var amount: int = int(event.get("damage", 0))
			if target_id == "hero":
				_visible_hero_hp -= amount
				_hero_health_meter.set_health(_visible_hero_hp, _combat.hero.max_health, true)
			elif target_id == "enemy":
				_visible_enemy_hp -= amount
				_enemy_health_meter.set_health(_visible_enemy_hp, _combat.enemy_max_health, true)
			elif target_id == BattleState.SUPPORT_ENEMY_ID:
				_visible_support_hp -= amount
				_support_enemy_view.set_health(_visible_support_hp, _combat.battle_state.get_participant(target_id).max_health)
			if amount > 0:
				_spawn_number(target_id, "−%d" % amount, Color("#ed4444"), 18.0)
		"reload":
			_show_reload_icon(actor_id)
		"failed":
			# Текущий слот коротко вспыхивает красным, без текстовых предупреждений.
			var slot_index: int = int(event.get("slot_index", -1))
			if actor_id != BattleState.SUPPORT_ENEMY_ID:
				var row: HBoxContainer = _sequence_slots if actor_id == "hero" else _enemy_sequence_slots
				if slot_index >= 0 and slot_index < row.get_child_count():
					(row.get_child(slot_index) as BattleAbilitySlot).flash_empty()
		"rest":
			_show_reload_icon(actor_id)


func _emit_combat_event_log(event: Dictionary) -> void:
	var support_name: String = _combat.support_enemy_definition.display_name if _combat.support_enemy_definition != null else _enemy_name.text
	if _combat.support_enemy_definition != null and _combat.support_enemy_definition.monster_id == _combat.enemy_definition.monster_id:
		support_name += " (2)"
	var message: String = BattleCombatLog.format_event(event, _hero_name.text, _enemy_name.text, support_name)
	if not message.is_empty():
		combat_log_line.emit(message)


func _impact(event: Dictionary) -> void:
	_emit_combat_event_log(event)
	var target_id: String = str(event.get("target_id", ""))
	var target: TextureRect = _impact_portraits.get(target_id) as TextureRect
	if target == null:
		return
	var hp_damage: int = int(event.get("damage", 0))
	var shield_damage: int = int(event.get("block_absorbed", event.get("shield_blocked", 0)))
	if shield_damage > 0:
		_spawn_number(target_id, "−%d" % shield_damage, Color("#67c8ff"), -12)
	if hp_damage > 0:
		_spawn_number(target_id, "−%d" % hp_damage, Color("#ff6969"), 18)
	if hp_damage == 0 and shield_damage == 0 and not bool(event.get("dodged", false)):
		_spawn_number(target_id, "0", Color("#c1cad2"))
	if target_id == "hero":
		_visible_hero_hp -= hp_damage
		_hero_health_meter.set_health(_visible_hero_hp, _combat.hero.max_health, true)
	elif target_id == "enemy":
		_visible_enemy_hp -= hp_damage
		_enemy_health_meter.set_health(_visible_enemy_hp, _combat.enemy_max_health, true)
	elif target_id == BattleState.SUPPORT_ENEMY_ID:
		_visible_support_hp -= hp_damage
		_support_enemy_view.set_health(_visible_support_hp, _combat.battle_state.get_participant(target_id).max_health)
	if hp_damage > 0:
		target.modulate = Color("#ff6464")
	elif shield_damage > 0:
		target.modulate = Color("#81c9ff")
	else:
		target.modulate = Color("#d0d5de")
	if bool(event.get("dodged", false)):
		_spawn_number(target_id, "УКЛОНЕНИЕ", Color("#83e7bb"))
	_set_accuracy_and_dodge_from_event(event)
	_set_block_display(target_id, int(event.get("active_block_after", 0)))


func _flash_shield(actor_id: String) -> void:
	var icon: TextureRect = _impact_shields.get(actor_id) as TextureRect
	if icon == null or not is_instance_valid(icon):
		return
	var previous: Tween = _shield_flash_tweens.get(actor_id) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	icon.modulate = SHIELD_FLASH_COLOR
	icon.modulate.a = 0.0
	icon.scale = Vector2.ONE * SHIELD_FLASH_START_SCALE
	icon.show()
	var flash: Tween = create_tween()
	_shield_flash_tweens[actor_id] = flash
	flash.tween_property(icon, "modulate:a", 1.0, SHIELD_FLASH_IN_SECONDS)
	flash.parallel().tween_property(icon, "scale", Vector2.ONE * SHIELD_FLASH_PEAK_SCALE, SHIELD_FLASH_IN_SECONDS)
	flash.tween_property(icon, "modulate:a", 0.0, SHIELD_FLASH_OUT_SECONDS).set_trans(Tween.TRANS_CUBIC)
	flash.parallel().tween_property(icon, "scale", Vector2.ONE, SHIELD_FLASH_OUT_SECONDS)
	flash.tween_callback(icon.hide)


func _set_block_display(actor_id: String, amount: int) -> void:
	if actor_id == BattleState.SUPPORT_ENEMY_ID:
		return
	var value: Label = _hero_defense_value if actor_id == "hero" else _enemy_defense_value
	var icon: TextureRect = _hero_defense_icon if actor_id == "hero" else _enemy_defense_icon
	value.text = str(amount)
	icon.modulate = Color.WHITE if amount > 0 else _defense_idle_color


func _show_reload_icon(actor_id: String) -> void:
	var portrait: TextureRect = _impact_portraits.get(actor_id) as TextureRect
	if portrait == null:
		return
	var icon := TextureRect.new()
	icon.texture = BattleAbilitySlot.SPECIAL_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = portrait.size * 0.64
	icon.position = portrait.size * 0.18
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(0.75, 0.86, 1.0, 0.92)
	portrait.add_child(icon)
	var tween: Tween = create_tween()
	tween.tween_property(icon, "modulate:a", 0.0, 0.55)
	tween.tween_callback(icon.queue_free)


func _spawn_number(actor_id: String, number: String, ink: Color, x_offset: float = 0) -> void:
	var portrait: TextureRect = _impact_portraits.get(actor_id) as TextureRect
	if portrait == null or _impact_layer == null:
		return
	var label := Label.new()
	label.text = number
	label.add_theme_font_size_override("font_size", 31)
	label.add_theme_color_override("font_color", ink)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_impact_layer.add_child(label)
	label.position = portrait.position + Vector2(portrait.size.x * 0.45 + x_offset, -22.0)
	var float_tween: Tween = create_tween()
	float_tween.tween_property(label, "position:y", label.position.y - 54.0, 0.98)
	float_tween.parallel().tween_property(label, "modulate:a", 0.0, 0.98).set_delay(0.32)
	float_tween.tween_callback(label.queue_free)


func _exit_tree() -> void:
	if _playback != null and _playback.is_valid():
		_playback.kill()
	if _status_presenter != null:
		_status_presenter.clear_impact()
	if _impact_layer != null and is_instance_valid(_impact_layer):
		_impact_layer.free()
func _after_phase_playback() -> void:
	_is_playing_back = false
	_refresh_accuracy_and_dodge()
	_status_presenter.sync(_combat.battle_state.participants)
	_set_block_display("hero", _combat.battle_state.get_hero().block_armor)
	_set_block_display("enemy", _combat.battle_state.get_enemy().block_armor)
	_conceal_enemy_actions()
	_highlight_next_actions()
	if _support_enemy_view != null:
		var passive: BattleParticipant = _combat.battle_state.get_participant(BattleState.SUPPORT_ENEMY_ID)
		if passive != null:
			_support_enemy_view.highlight_cursor(passive.action_cursor)
			_support_enemy_view.refresh_health(passive)
	_hero_health_meter.set_health(_combat.hero.health, _combat.hero.max_health, true)
	_enemy_health_meter.set_health(_combat.enemy_health, _combat.enemy_max_health, true)
	if _combat.battle_state.get_enemy() != null and not _combat.battle_state.get_enemy().is_alive():
		_enemy_portrait.modulate = Color("#87909c")
	# При нескольких ударах за фазу щит мог сломаться не на последнем.
	# Берём ID из событий, а не из состояния последнего попадания.
	for event in _combat.battle_state.last_phase_events:
		var broken_id: String = str(event.get("shield_broken", ""))
		if not broken_id.is_empty():
			_combat.hero.last_shield_broken = broken_id
			_set_block_display("hero", _combat.battle_state.get_hero().block_armor)
			shield_broken.emit(broken_id)
			_combat.hero.last_shield_broken = ""
			var hero_actor: BattleParticipant = _combat.battle_state.get_hero()
			if hero_actor != null and hero_actor._hero_snapshot != null:
				hero_actor._hero_snapshot.last_shield_broken = ""
	if _combat.is_victory:
		combat_log_line.emit("Бой окончен: победа %s" % _hero_name.text)
		_show_victory()
	elif _combat.is_defeat:
		combat_log_line.emit("Бой окончен: поражение %s" % _hero_name.text)
		_show_defeat()
	else:
		combat_log_line.emit("Фаза %d завершена" % _combat.battle_state.flow.phase_number)
		_result_text.text = "Фаза %d завершена." % _combat.battle_state.flow.phase_number
		_refresh_phase_controls()


## При проигрывании показываем снимок результата события, а не конечное
## состояние уже рассчитанной фазы.
func _set_accuracy_and_dodge_from_event(event: Dictionary) -> void:
	if not event.has("dodge_after"):
		return
	var target_id: String = str(event.get("target_id", ""))
	if target_id == BattleState.SUPPORT_ENEMY_ID:
		return
	var dodge_label: Label = _hero_dodge_value if target_id == "hero" else _enemy_dodge_value
	var accuracy_label: Label = _hero_accuracy_value if target_id == "hero" else _enemy_accuracy_value
	dodge_label.text = "УКЛ %d%%" % int(event.get("dodge_after", 0))
	accuracy_label.text = "МЕТ %d%%" % (BattleParticipant.PERCENT_SCALE + int(event.get("accuracy_after", 0)))


func _refresh_accuracy_and_dodge() -> void:
	if _combat == null:
		return
	var hero: BattleParticipant = _combat.battle_state.get_hero()
	var enemy: BattleParticipant = _combat.battle_state.get_enemy()
	if hero == null or enemy == null:
		return
	_hero_agility_value.text = "ЛОВ %d" % hero.effective_agility()
	_enemy_agility_value.text = "ЛОВ %d" % enemy.effective_agility()
	_hero_dodge_value.text = "УКЛ %d%%" % hero.dodge_percent()
	_hero_accuracy_value.text = "МЕТ %d%%" % (BattleParticipant.PERCENT_SCALE + hero.accuracy_percent())
	_enemy_dodge_value.text = "УКЛ %d%%" % enemy.dodge_percent()
	_enemy_accuracy_value.text = "МЕТ %d%%" % (BattleParticipant.PERCENT_SCALE + enemy.accuracy_percent())
	_hero_dodge_value.tooltip_text = "Собственное уклонение, без учёта меткости противника"
	_enemy_dodge_value.tooltip_text = "Собственное уклонение, без учёта меткости противника"


func _refresh_phase_controls() -> void:
	if _combat == null:
		return
	_refresh_accuracy_and_dodge()
	var flow: BattleFlow = _combat.battle_state.flow
	var stage: int = flow.stage
	var editable: bool = _editing_allowed()
	if not editable and _ability_picker.visible:
		_hide_ability_picker()
	_refresh_chain_slots()
	_refresh_combat_items_button()
	# Кнопка остаётся доступной, чтобы по нажатию мигнули пустые слоты.
	_punch_button.disabled = (_is_playing_back or stage == BattleFlow.Stage.EXECUTING or stage == BattleFlow.Stage.FINISHED)
	match stage:
		BattleFlow.Stage.PREPARATION:
			_punch_button.text = "Начать бой"
		BattleFlow.Stage.RECONFIGURING:
			_punch_button.text = "Сохранить алгоритм"
		_:
			_punch_button.text = "Следующая фаза"
	# Свободная перестановка доступна прямо в слотах между фазами.
	_guard_button.visible = false
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
	if _ability_picker.visible or (_item_picker != null and _item_picker.visible):
		return
	if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and not _punch_button.disabled:
		_on_punch_pressed()
		get_viewport().set_input_as_handled()
