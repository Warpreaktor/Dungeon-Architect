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
@onready var _enemy_health_meter: HealthMeter = $OuterMargin/Main/Battlefield/EnemyParty/EnemyCard/EnemyMargin/EnemyStack/EnemyColumn/EnemyHealthMeter
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
@onready var _combat_items_button: Button = %CombatItemsButton
@onready var _result_text: Label = %ResultText
@onready var _sequence_slots: HBoxContainer = %SequenceSlots
@onready var _sequence_scroll: ScrollContainer = $OuterMargin/Main/BottomPanel/ActionsMargin/ActionsColumn/SequenceSides/SequenceScroll
@onready var _enemy_sequence_slots: HBoxContainer = %EnemySequenceSlots
@onready var _enemy_sequence_scroll: ScrollContainer = $OuterMargin/Main/BottomPanel/ActionsMargin/ActionsColumn/SequenceSides/EnemySequenceScroll
@onready var _battlefield: HBoxContainer = $OuterMargin/Main/Battlefield
@onready var _enemy_party: HBoxContainer = $OuterMargin/Main/Battlefield/EnemyParty
@onready var _main_enemy_card: PanelContainer = $OuterMargin/Main/Battlefield/EnemyParty/EnemyCard
@onready var _hero_chain_title: Label = %HeroChainTitle
@onready var _enemy_chain_title: Label = %EnemyChainTitle

const ABILITY_SLOT_SCENE: PackedScene = preload("res://scenes/battle_ability_slot.tscn")
const MAX_CHAIN_SLOT_SIDE: float = 116.0
const MIN_CHAIN_SLOT_SIDE: float = 64.0

var _combat: CombatSession
var _defense_idle_color: Color = Color.WHITE
var _default_attack_icon: Texture2D
var _hero_chain: Array[String] = []
var _enemy_chain: Array[String] = []
## Карты врага раскрываются навсегда в рамках одной встречи.
var _enemy_revealed: Dictionary = {}
var _playback: Tween
var _is_playing_back: bool = false
## Зафиксированная раскладка слотов, включая пропуски между приёмами.
var _committed_slots: Array[String] = []
var _items_session: GameSession
var _item_picker: BattleItemPicker
## Временные портреты поверх поля: движение не меняет настоящие UI-узлы.
var _impact_layer: Control
var _impact_portraits: Dictionary = {}
var _impact_idle: Dictionary = {}
var _impact_origin: Dictionary = {}
var _impact_scale: float = 1.0
var _impact_shields: Dictionary = {}
var _shield_flash_tweens: Dictionary = {}
var _status_presenter: BattleStatusPresenter
var _support_enemy_view: BattleSupportEnemyView
var _touch_info: TouchInfoOverlay
var _visible_hero_hp: int = 0
var _visible_enemy_hp: int = 0
var _visible_support_hp: int = 0
var _visible_hero_max: int = 0
var _visible_enemy_max: int = 0
var _visible_support_max: int = 0
var _manual_started: bool = false
var _selected_manual_slot: int = -2
var _target_outlines: Dictionary = {}


# Длительность визуальной вспышки совпадает с паузой события «Блок».
# Эти параметры меняют только анимацию, не время действия защиты.
const SHIELD_FLASH_IN_SECONDS: float = 0.18
const SHIELD_FLASH_OUT_SECONDS: float = 1.00
const SHIELD_FLASH_START_SCALE: float = 0.25
const SHIELD_FLASH_PEAK_SCALE: float = 1.08
const SHIELD_FLASH_COLOR: Color = Color(0.40, 0.78, 1.0, 1.0)

@export_range(0.0, 2.0, 0.01) var clash_intro_seconds: float = 0.56
@export_range(0.0, 2.0, 0.01) var clash_outro_seconds: float = 0.42
@export_range(0.0, 2.0, 0.01) var clash_tick_seconds: float = 0.20
@export_range(0.0, 2.0, 0.01) var clash_action_start_seconds: float = 0.08
@export_range(0.0, 2.0, 0.01) var clash_windup_seconds: float = 0.20
@export_range(0.0, 2.0, 0.01) var clash_impact_seconds: float = 0.13
@export_range(0.0, 2.0, 0.01) var clash_hold_seconds: float = 0.46
@export_range(0.0, 2.0, 0.01) var clash_recover_seconds: float = 0.27
@export_range(0.0, 2.0, 0.01) var clash_idle_seconds: float = 0.40
@export_range(1.0, 3.0, 0.01) var clash_portrait_scale: float = 1.5
@export_range(0.0, 2.0, 0.01) var clash_idle_gap_fraction: float = 0.35
@export_range(0.0, 1.0, 0.01) var clash_recoil_fraction: float = 0.18
@export_range(0.0, 1.0, 0.01) var clash_contact_overlap_fraction: float = 0.14
@export_range(0.0, 1.0, 0.01) var clash_cast_icon_fraction: float = 0.42
@export_range(0.0, 1.0, 0.01) var clash_formation_vertical_gap_fraction: float = 0.12
@export_range(0.0, 1.0, 0.01) var clash_formation_vertical_padding_fraction: float = 0.06



func _ready() -> void:
	_sequence_scroll.resized.connect(_resize_chain_slots)
	_enemy_sequence_scroll.resized.connect(_resize_chain_slots)
	_combat_items_button.pressed.connect(_on_combat_items_pressed)
	_combat_items_button.icon = preload("res://assets/icons/potion.png")
	_combat_items_button.tooltip_text = "Боевые зелья"
	_combat_items_button.disabled = true
	_build_combat_item_picker()
	_touch_info = TouchInfoOverlay.new()
	add_child(_touch_info)
	_item_picker.info_requested.connect(_touch_info.show_text)
	for label in [_hero_strength_value, _enemy_strength_value]:
		label.tooltip_text = BattleAttributeTooltip.strength_description()
	for label in [_hero_agility_value, _enemy_agility_value]:
		label.tooltip_text = BattleAttributeTooltip.agility_description()
	for label in [_hero_accuracy_value, _enemy_accuracy_value]:
		label.tooltip_text = BattleAttributeTooltip.accuracy_description()
	_touch_info.attach_tap(_hero_strength_value, func() -> String: return _hero_strength_value.tooltip_text)
	_touch_info.attach_tap(_enemy_strength_value, func() -> String: return _enemy_strength_value.tooltip_text)
	_touch_info.attach_tap(_hero_agility_value, func() -> String: return _hero_agility_value.tooltip_text)
	_touch_info.attach_tap(_enemy_agility_value, func() -> String: return _enemy_agility_value.tooltip_text)
	_touch_info.attach_tap(_hero_dodge_value, func() -> String: return _hero_dodge_value.tooltip_text)
	_touch_info.attach_tap(_enemy_dodge_value, func() -> String: return _enemy_dodge_value.tooltip_text)
	_touch_info.attach_tap(_hero_accuracy_value, func() -> String: return "Меткость\n" + _hero_accuracy_value.text + " — итоговая меткость героя\n" + _hero_accuracy_value.tooltip_text)
	_touch_info.attach_tap(_enemy_accuracy_value, func() -> String: return "Меткость\n" + _enemy_accuracy_value.text + " — итоговая меткость противника\n" + _enemy_accuracy_value.tooltip_text)
	_default_attack_icon = _hero_attack_icon.texture
	_status_presenter = BattleStatusPresenter.new(self)
	_status_presenter.info_requested.connect(_on_status_info_requested)
	_status_presenter.setup({"hero": _hero_portrait, "enemy": _enemy_portrait})
	_support_enemy_view = BattleSupportEnemyView.new()
	_support_enemy_view.info_requested.connect(_touch_info.show_text)
	_support_enemy_view.name = "SupportEnemy"
	_support_enemy_view.theme = _main_enemy_card.theme
	_enemy_party.add_child(_support_enemy_view)
	_support_enemy_view.hide()
	_bind_target_portrait(_hero_portrait, "hero")
	_bind_target_portrait(_enemy_portrait, "enemy")
	_bind_target_portrait(_support_enemy_view.portrait_node(), BattleState.SUPPORT_ENEMY_ID)
	_enemy_health_meter.get_node("HealthColumn/HealthBar").custom_minimum_size.x = 0.0
	_enemy_party.resized.connect(_equalize_enemy_cards)
	_result_text.text = ""
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.24)


## Единственный расчёт: тот же метод, что использует обработчик способности.
func _on_status_info_requested(actor_id: String, status_id: String) -> void:
	if _combat == null:
		return
	var actor: BattleParticipant = _combat.battle_state.get_participant(actor_id)
	if actor == null or not actor.statuses.has(status_id):
		return
	var status: Dictionary = actor.statuses[status_id]
	var title: String = "Кровотечение" if status_id == "bleeding" else ("Снижение меткости" if status_id == "petushan_accuracy_down" else str(status.get("label", status_id)))
	_touch_info.show_info(title, BattleStatusRules.describe(status))


func _basic_strike_damage(actor: BattleParticipant) -> int:
	return actor.melee_attack() if actor != null else 0


func begin(combat: CombatSession, hero: HeroState) -> void:
	_combat = combat
	_manual_started = false
	_selected_manual_slot = -2
	var support_definition: MonsterDefinition = combat.support_enemy_definition if combat.support_enemy_definition != null else combat.enemy_definition
	var support: BattleParticipant = combat.battle_state.get_participant(combat.battle_state.support_enemy_id)
	var portrait: Texture2D = support_definition.portrait if support_definition.portrait != null else support_definition.icon
	var support_name: String = support_definition.display_name
	if support_definition.monster_id == combat.enemy_definition.monster_id:
		support_name += " (2)"
	_support_enemy_view.configure(support, portrait, support_name, support_definition.portrait_flip_h)
	call_deferred("_equalize_enemy_cards")
	if support != null:
		_status_presenter.setup({combat.battle_state.support_enemy_id: _support_enemy_view.portrait_node()})
	if hero.definition != null:
		_hero_name.text = hero.definition.display_name
		_hero_portrait.texture = hero.definition.portrait
	var weapon: ItemDefinition = ItemCatalog.get_item(hero.equipped_weapon_id)
	var weapon_icon: Texture2D = weapon.icon if weapon != null else _default_attack_icon
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
	_enemy_portrait.flip_h = combat.enemy_definition.portrait_flip_h
	_enemy_portrait.modulate = Color.WHITE
	_hero_health_meter.set_health(hero.health, hero.effective_max_health())
	_enemy_health_meter.set_health(combat.enemy_health, combat.enemy_max_health)
	_visible_hero_hp = hero.health
	_visible_enemy_hp = combat.enemy_health
	_visible_support_hp = support.health if support != null else 0
	_visible_hero_max = hero.effective_max_health()
	_visible_enemy_max = combat.enemy_definition.max_health
	_visible_support_max = combat.support_enemy_definition.max_health if support != null else 0
	_status_presenter.reset()
	_status_presenter.sync(_combat.battle_state.participants)
	_committed_slots = hero.get_saved_action_slots()
	var playable: BattleParticipant = _combat.battle_state.get_hero()
	for i in range(_committed_slots.size()):
		if not _committed_slots[i].is_empty() and not AbilityCatalog.knows_ability(playable, _committed_slots[i]):
			_committed_slots[i] = ""
	_hero_chain.clear()
	for ability_id in _committed_slots:
		if not ability_id.is_empty():
			_hero_chain.append(ability_id)
	_enemy_chain = _combat.battle_state.default_chain("enemy")
	_enemy_revealed.clear()
	_refresh_enemy_slots()
	_result_text.text = ""
	_start_prepared_combat()


func _equalize_enemy_cards() -> void:
	_main_enemy_card.custom_minimum_size.y = 0.0
	_support_enemy_view.custom_minimum_size.y = 0.0
	if not _support_enemy_view.visible:
		return
	var gap: float = float(_enemy_party.get_theme_constant("separation"))
	var card_width: float = maxf((_enemy_party.size.x - gap) / float(_enemy_party.get_child_count()), 0.0)
	var content_height: float = maxf(_main_enemy_card.get_combined_minimum_size().y,
		_support_enemy_view.get_combined_minimum_size().y)
	var side: float = minf(maxf(card_width, content_height), _enemy_party.size.y)
	_main_enemy_card.custom_minimum_size.y = side
	_support_enemy_view.custom_minimum_size.y = side


func _refresh_chain_slots() -> void:
	for child in _sequence_slots.get_children():
		_sequence_slots.remove_child(child)
		child.queue_free()
	var displayed: Array[String] = _hero_chain
	var available: Array[int] = []
	if _manual_started:
		available = _combat.battle_state.manual_available_slots()
	for index in range(displayed.size()):
		var action_id: String = displayed[index]
		var ability: AbilityDefinition = AbilityCatalog.get_ability(action_id)
		var slot: BattleAbilitySlot = ABILITY_SLOT_SCENE.instantiate() as BattleAbilitySlot
		_sequence_slots.add_child(slot)
		slot.configure(index, ability, available.has(index), _combat.battle_state.get_hero())
		if _manual_started and not available.has(index):
			slot.modulate = Color(0.48, 0.48, 0.48)
		slot.slot_selected.connect(_on_slot_pressed.bind(slot))
		slot.info_requested.connect(_touch_info.show_text)
		_touch_info.attach_long_press(slot, func() -> String: return slot.tooltip_text)
	# Отдых не занимает слот арсенала и не сохраняется в HeroState.
	var rest_slot: BattleAbilitySlot = ABILITY_SLOT_SCENE.instantiate() as BattleAbilitySlot
	_sequence_slots.add_child(rest_slot)
	rest_slot.configure_recharge(displayed.size())
	rest_slot.slot_selected.connect(_on_slot_pressed.bind(rest_slot))
	if _manual_started and not _is_playing_back and _combat.battle_state.flow.stage != BattleFlow.Stage.FINISHED:
		rest_slot.disabled = false
	rest_slot.info_requested.connect(_touch_info.show_text)
	_resize_chain_slots()
	if _manual_started:
		_highlight_manual_selection()
	else:
		_highlight_next_actions()


func _resize_chain_slots() -> void:
	_fit_chain_row(_sequence_scroll, _sequence_slots)
	_fit_chain_row(_enemy_sequence_scroll, _enemy_sequence_slots)


func _fit_chain_row(scroll: ScrollContainer, row: HBoxContainer) -> void:
	var count: int = row.get_child_count()
	if count == 0 or scroll.size.x <= 0.0:
		return
	var gap: float = float(row.get_theme_constant("separation"))
	var side: float = BattleAbilitySlot.side_for_width(scroll.size.x, count, gap, MIN_CHAIN_SLOT_SIDE, MAX_CHAIN_SLOT_SIDE)
	scroll.custom_minimum_size.y = side
	for child in row.get_children():
		(child as Control).custom_minimum_size = Vector2.ONE * side


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
		slot.info_requested.connect(_touch_info.show_text)
	if not _is_playing_back:
		_highlight_next_actions()
	_resize_chain_slots()


func _conceal_enemy_actions() -> void:
	# Скрывать можно только ещё не сыгранные позиции.
	for index in range(_enemy_chain.size()):
		if not _enemy_revealed.has(index):
			(_enemy_sequence_slots.get_child(index) as BattleAbilitySlot).configure_hidden(index)


func _highlight_slots(hero_index: int, enemy_index: int, hero_reloading: bool = false, enemy_reloading: bool = false) -> void:
	for index in range(_sequence_slots.get_child_count()):
		var active: bool = index == _hero_chain.size() if hero_reloading else index == hero_index
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
	if _manual_started:
		_highlight_manual_selection()
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
		_visible_hero_max = session.hero.effective_max_health()
		_hero_health_meter.set_health(_visible_hero_hp, _visible_hero_max, true)
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


func _on_slot_pressed(index: int, slot: BattleAbilitySlot) -> void:
	if _touch_info.consume_long_press(slot):
		return
	_on_slot_selected(index)


func _on_slot_selected(_index: int) -> void:
	if _manual_started:
		if _is_playing_back or _combat.battle_state.flow.stage == BattleFlow.Stage.FINISHED:
			return
		if _index < _hero_chain.size() and not _combat.battle_state.manual_available_slots().has(_index):
			return
		var requested_slot: int = -1 if _index == _hero_chain.size() else _index
		if requested_slot == -1:
			_selected_manual_slot = -1
			_play_selected_manual_action("hero")
			return
		_selected_manual_slot = -2 if _selected_manual_slot == requested_slot else requested_slot
		_result_text.text = ""
		_refresh_phase_controls()
		return


func _input(event: InputEvent) -> void:
	if _item_picker == null or not _item_picker.visible:
		return
	if event.is_action_pressed("ui_cancel"):
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
	if not _item_picker.get_global_rect().has_point(point) and not _combat_items_button.get_global_rect().has_point(point):
		_hide_combat_item_picker()


func _start_prepared_combat() -> void:
	if _combat == null or _manual_started:
		return
	var prepared: Dictionary = _combat.prepare_manual_combat(_hero_chain)
	if not bool(prepared.get("success", false)):
		_result_text.text = str(prepared.get("reason", "Не удалось подготовить бой"))
		return
	_manual_started = true
	_hide_combat_item_picker()
	_result_text.text = ""
	_refresh_phase_controls()


func _play_selected_manual_action(target_id: String) -> void:
	if not _manual_started or _is_playing_back or _selected_manual_slot == -2:
		return
	if _combat.battle_state.flow.stage == BattleFlow.Stage.FINISHED:
		return
	if _selected_manual_slot >= 0:
		var ability: AbilityDefinition = AbilityCatalog.get_ability(_hero_chain[_selected_manual_slot])
		if not _combat.battle_state.create_context().target_ids("hero", ability).has(target_id):
			return
	_hide_combat_item_picker()
	var result: Dictionary = _combat.play_manual_tick(_selected_manual_slot, target_id)
	if not bool(result.get("success", false)):
		_result_text.text = str(result.get("reason", "Такт недоступен"))
		_refresh_phase_controls()
		return
	_is_playing_back = true
	_selected_manual_slot = -2
	_combat_items_button.disabled = true
	_refresh_target_outlines()
	_play_phase_events(result.get("events", []))


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
	var portrait_sizes: Dictionary = {"hero": _hero_portrait.size, "enemy": _enemy_portrait.size}
	if actor_ids.has(BattleState.SUPPORT_ENEMY_ID):
		portrait_sizes[BattleState.SUPPORT_ENEMY_ID] = _support_enemy_view.portrait_node().size
	var available_height: float = _battlefield.size.y * (1.0 - clash_formation_vertical_padding_fraction * 2.0)
	_impact_scale = BattleClashGeometry.fit_formation_scale(available_height, portrait_sizes,
		clash_portrait_scale, clash_formation_vertical_gap_fraction)
	var idle_positions: Dictionary = BattleClashGeometry.formation_positions(center, portrait_sizes,
		_impact_scale, clash_idle_gap_fraction, clash_formation_vertical_gap_fraction)
	for actor_id in actor_ids:
		var original: TextureRect = _hero_portrait if actor_id == "hero" else (_enemy_portrait if actor_id == "enemy" else _support_enemy_view.portrait_node())
		if original == null or original.texture == null:
			continue
		var portrait := TextureRect.new()
		portrait.name = "Impact_" + actor_id
		portrait.texture = original.texture
		portrait.flip_h = original.flip_h
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.size = original.size
		portrait.pivot_offset = portrait.size * 0.5
		portrait.position = original.global_position - global_position
		_impact_origin[actor_id] = portrait.position
		_impact_idle[actor_id] = idle_positions[actor_id]
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
	_create_impact_layer()
	_playback = create_tween()
	_playback.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var first_intro: bool = true
	for actor_id in _impact_portraits:
		var portrait: TextureRect = _impact_portraits[actor_id]
		if first_intro:
			_playback.tween_property(portrait, "position", _impact_idle[actor_id], clash_intro_seconds)
			first_intro = false
		else:
			_playback.parallel().tween_property(portrait, "position", _impact_idle[actor_id], clash_intro_seconds)
		_playback.parallel().tween_property(portrait, "scale", Vector2.ONE * _impact_scale, clash_intro_seconds)
	for group in BattleClashTimeline.group_events(phase_events, true):
		var group_events: Array[Dictionary] = group["events"]
		if bool(group.get("is_clash", false)):
			_queue_clash_animation(group_events)
		else:
			for event in group_events:
				_playback.tween_callback(_display_phase_event.bind(event))
			_playback.tween_interval(clash_idle_seconds)
	var first_return: bool = true
	for actor_id in _impact_portraits:
		var portrait: TextureRect = _impact_portraits[actor_id]
		if first_return:
			_playback.tween_property(portrait, "position", _impact_origin[actor_id], clash_outro_seconds)
			first_return = false
		else:
			_playback.parallel().tween_property(portrait, "position", _impact_origin[actor_id], clash_outro_seconds)
		_playback.parallel().tween_property(portrait, "scale", Vector2.ONE, clash_outro_seconds)
	_playback.tween_callback(_clear_impact_layer)
	_playback.tween_callback(_after_phase_playback)


func _queue_clash_animation(group_events: Array[Dictionary]) -> void:
	var outcomes: Array[Dictionary] = []
	var attackers: Dictionary = {}
	for event in group_events:
		var kind: String = str(event.get("type", ""))
		if kind in ["tick", "action_start", "block"]:
			_playback.tween_callback(_display_phase_event.bind(event))
			if kind == "tick":
				_playback.tween_interval(clash_tick_seconds)
			elif kind == "action_start":
				_playback.tween_callback(_show_clash_ability.bind(event))
				_playback.tween_interval(clash_action_start_seconds)
		else:
			outcomes.append(event)
		if kind in ["attack", "counter"]:
			var actor_id: String = str(event.get("actor_id", ""))
			var target_id: String = str(event.get("target_id", ""))
			if _impact_portraits.has(actor_id) and _impact_portraits.has(target_id):
				attackers[actor_id] = target_id
	if attackers.is_empty():
		_playback.tween_interval(clash_idle_seconds)
	else:
		var windup_positions: Dictionary = {}
		var first_actor: bool = true
		for actor_id in attackers:
			var portrait: TextureRect = _impact_portraits[actor_id]
			var target: TextureRect = _impact_portraits[attackers[actor_id]]
			var direction: float = signf((_impact_idle[attackers[actor_id]] + target.size * 0.5).x - (_impact_idle[actor_id] + portrait.size * 0.5).x)
			var windup: Vector2 = _impact_idle[actor_id] - Vector2(direction * portrait.size.x * clash_recoil_fraction, 0.0)
			windup_positions[actor_id] = windup
			if first_actor:
				_playback.tween_property(portrait, "position", windup, clash_windup_seconds)
				first_actor = false
			else:
				_playback.parallel().tween_property(portrait, "position", windup, clash_windup_seconds)
		var sizes: Dictionary = {}
		for actor_id in _impact_portraits:
			sizes[actor_id] = (_impact_portraits[actor_id] as TextureRect).size
		var contacts: Dictionary = BattleClashGeometry.contact_positions(_impact_idle, sizes, attackers, clash_contact_overlap_fraction, _impact_scale)
		var approach_duration: float = BattleClashGeometry.approach_seconds(clash_impact_seconds, windup_positions, contacts, sizes)
		var first_contact: bool = true
		for actor_id in contacts:
			var portrait: TextureRect = _impact_portraits[actor_id]
			var contact: Vector2 = contacts[actor_id]
			if first_contact:
				_playback.tween_property(portrait, "position", contact, approach_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
				first_contact = false
			else:
				_playback.parallel().tween_property(portrait, "position", contact, approach_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	for event in outcomes:
		if str(event.get("type", "")) in ["attack", "counter"]:
			_playback.tween_callback(_impact.bind(event))
		else:
			_playback.tween_callback(_display_phase_event.bind(event))
	if not attackers.is_empty():
		_playback.tween_interval(clash_hold_seconds)
		var first_recover: bool = true
		for actor_id in _impact_portraits:
			var portrait: TextureRect = _impact_portraits[actor_id]
			if first_recover:
				_playback.tween_property(portrait, "position", _impact_idle[actor_id], clash_recover_seconds)
				first_recover = false
			else:
				_playback.parallel().tween_property(portrait, "position", _impact_idle[actor_id], clash_recover_seconds)
			_playback.parallel().tween_property(portrait, "modulate", Color.WHITE, clash_recover_seconds)


func _show_clash_ability(event: Dictionary) -> void:
	if _impact_layer == null or not is_instance_valid(_impact_layer):
		return
	var actor_id: String = str(event.get("actor_id", ""))
	var portrait: TextureRect = _impact_portraits.get(actor_id) as TextureRect
	var ability: AbilityDefinition = AbilityCatalog.get_ability(str(event.get("ability_id", "")))
	if portrait == null or ability == null or ability.icon == null:
		return
	var icon := TextureRect.new()
	icon.texture = ability.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = portrait.size * clash_cast_icon_fraction
	icon.position = portrait.position + Vector2((portrait.size.x - icon.size.x) * 0.5, -icon.size.y * 0.65)
	_impact_layer.add_child(icon)
	var effect: Tween = create_tween()
	effect.tween_property(icon, "modulate:a", 0.0, clash_windup_seconds + clash_impact_seconds + clash_hold_seconds)
	effect.tween_callback(icon.queue_free)


func _display_phase_event(event: Dictionary) -> void:
	var actor_id: String = str(event.get("actor_id", ""))
	var kind: String = str(event.get("type", ""))
	# Удар записывается при контакте портретов, остальные события здесь.
	if kind not in ["attack", "counter"] and not (kind == "rest" and bool(event.get("premature", false))):
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
			if _manual_started:
				var hero_slot: int = _hero_chain.size() if bool(event.get("hero_reload", false)) else int(event.get("hero_slot", -1))
				_highlight_slots(hero_slot, int(event.get("enemy_slot", -1)))
			else:
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
				_hero_health_meter.set_health(_visible_hero_hp, _visible_hero_max, true)
			elif actor_id == "enemy":
				_visible_enemy_hp += healed
				_enemy_health_meter.set_health(_visible_enemy_hp, _visible_enemy_max, true)
			elif actor_id == BattleState.SUPPORT_ENEMY_ID:
				_visible_support_hp += healed
				_support_enemy_view.set_health(_visible_support_hp, _visible_support_max)
			if healed > 0:
				_spawn_number(str(event.get("target_id", "")), "+%d" % healed, Color("#70d994"))
		"hp_limit_changed":
			var target_id: String = str(event.get("target_id", ""))
			var actual_hp: int = int(event.get("hp_after", 0))
			var actual_max: int = int(event.get("hp_max", 0))
			if target_id == "hero":
				_visible_hero_hp = actual_hp
				_visible_hero_max = actual_max
				_hero_health_meter.set_health(actual_hp, actual_max, true)
			elif target_id == "enemy":
				_visible_enemy_hp = actual_hp
				_visible_enemy_max = actual_max
				_enemy_health_meter.set_health(actual_hp, actual_max, true)
			elif target_id == BattleState.SUPPORT_ENEMY_ID and _support_enemy_view != null:
				_visible_support_hp = actual_hp
				_visible_support_max = actual_max
				_support_enemy_view.set_health(actual_hp, actual_max)
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
				_hero_health_meter.set_health(_visible_hero_hp, _visible_hero_max, true)
			elif target_id == "enemy":
				_visible_enemy_hp -= amount
				_enemy_health_meter.set_health(_visible_enemy_hp, _visible_enemy_max, true)
			elif target_id == BattleState.SUPPORT_ENEMY_ID:
				_visible_support_hp -= amount
				_support_enemy_view.set_health(_visible_support_hp, _visible_support_max)
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
		_hero_health_meter.set_health(_visible_hero_hp, _visible_hero_max, true)
	elif target_id == "enemy":
		_visible_enemy_hp -= hp_damage
		_enemy_health_meter.set_health(_visible_enemy_hp, _visible_enemy_max, true)
	elif target_id == BattleState.SUPPORT_ENEMY_ID:
		_visible_support_hp -= hp_damage
		_support_enemy_view.set_health(_visible_support_hp, _visible_support_max)
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
		_support_enemy_view.set_block(amount)
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
	_visible_hero_max = _combat.hero.effective_max_health()
	_visible_enemy_max = _combat.enemy_max_health
	_hero_health_meter.set_health(_combat.hero.health, _visible_hero_max, true)
	_enemy_health_meter.set_health(_combat.enemy_health, _visible_enemy_max, true)
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
		_result_text.text = ""
		_refresh_phase_controls()


## При проигрывании показываем снимок результата события, а не конечное
## состояние уже рассчитанной фазы.
func _set_accuracy_and_dodge_from_event(event: Dictionary) -> void:
	if not event.has("dodge_after"):
		return
	var target_id: String = str(event.get("target_id", ""))
	if target_id == BattleState.SUPPORT_ENEMY_ID:
		_support_enemy_view.set_precision(int(event.get("dodge_after", 0)), int(event.get("accuracy_after", 0)))
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
	if _support_enemy_view != null:
		_support_enemy_view.refresh_stats(_combat.battle_state.get_participant(BattleState.SUPPORT_ENEMY_ID))
	_hero_dodge_value.tooltip_text = "Собственное уклонение, без учёта меткости противника"
	_enemy_dodge_value.tooltip_text = "Собственное уклонение, без учёта меткости противника"


func _refresh_phase_controls() -> void:
	if _combat == null:
		return
	_refresh_accuracy_and_dodge()
	var stage: int = _combat.battle_state.flow.stage
	_refresh_chain_slots()
	_refresh_combat_items_button()
	_refresh_target_outlines()


func _highlight_manual_selection() -> void:
	if _sequence_slots == null:
		return
	for index in range(_sequence_slots.get_child_count()):
		var selected: bool = (_selected_manual_slot == -1 and index == _hero_chain.size()) or index == _selected_manual_slot
		(_sequence_slots.get_child(index) as BattleAbilitySlot).set_current(selected)


func _bind_target_portrait(portrait: TextureRect, actor_id: String) -> void:
	portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.gui_input.connect(_on_target_portrait_input.bind(actor_id))
	var outline := Panel.new()
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(outline)
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var border := StyleBoxFlat.new()
	border.bg_color = Color.TRANSPARENT
	border.border_color = Color("#f5c568")
	border.set_border_width_all(4)
	border.set_corner_radius_all(8)
	outline.add_theme_stylebox_override("panel", border)
	_target_outlines[actor_id] = outline
	outline.hide()


func _on_target_portrait_input(event: InputEvent, actor_id: String) -> void:
	var pressed: bool = false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		pressed = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if not pressed or not _manual_started or _selected_manual_slot < 0 or _is_playing_back:
		return
	var ability: AbilityDefinition = AbilityCatalog.get_ability(_hero_chain[_selected_manual_slot])
	if not _combat.battle_state.create_context().target_ids("hero", ability).has(actor_id):
		return
	get_viewport().set_input_as_handled()
	_play_selected_manual_action(actor_id)


func _refresh_target_outlines() -> void:
	var valid_targets: Array[String] = []
	if _manual_started and not _is_playing_back and _selected_manual_slot >= 0 and _combat.battle_state.flow.stage != BattleFlow.Stage.FINISHED:
		var ability: AbilityDefinition = AbilityCatalog.get_ability(_hero_chain[_selected_manual_slot])
		valid_targets = _combat.battle_state.create_context().target_ids("hero", ability)
	for actor_id in _target_outlines:
		var outline: Panel = _target_outlines[actor_id]
		outline.visible = valid_targets.has(str(actor_id))
		var portrait: TextureRect = outline.get_parent() as TextureRect
		portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if outline.visible else Control.CURSOR_ARROW


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
