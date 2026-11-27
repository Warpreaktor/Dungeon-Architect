class_name BattleView
extends Control

## Боевая сцена использует ту же шкалу здоровья, что и экран исследования.
## Сведения о здоровье, атаке и блоке берутся из CombatSession/HeroState.
signal battle_won
signal battle_lost
signal shield_broken(item_id: String, member: HeroState)
signal combat_log_line(message: String)
signal item_use_requested(item_id: String)

@onready var _hero_health_meter: HealthMeter = $OuterMargin/Main/Battlefield/HeroSide/HeroParty/HeroCard/HeroMargin/HeroColumn/HeroHealthMeter
@onready var _enemy_health_meter: HealthMeter = $OuterMargin/Main/Battlefield/EnemySide/EnemyParty/EnemyCard/EnemyMargin/EnemyStack/EnemyColumn/EnemyHealthMeter
@onready var _hero_portrait: TextureRect = %HeroPortrait
@onready var _hero_attack_value: Label = %HeroAttackValue
@onready var _hero_strength_value: Label = %HeroStrengthValue
@onready var _hero_agility_value: Label = %HeroAgilityValue
@onready var _hero_dodge_value: Label = %HeroDodgeValue
@onready var _hero_accuracy_value: Label = %HeroAccuracyValue
@onready var _hero_defense_icon: TextureRect = %HeroDefenseIcon
@onready var _hero_defense_value: Label = %HeroDefenseValue
@onready var _hero_name: Label = $OuterMargin/Main/Battlefield/HeroSide/HeroParty/HeroCard/HeroMargin/HeroColumn/HeroName
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
@onready var _hero_party: HBoxContainer = $OuterMargin/Main/Battlefield/HeroSide/HeroParty
@onready var _enemy_party: HBoxContainer = $OuterMargin/Main/Battlefield/EnemySide/EnemyParty
@onready var _main_enemy_card: PanelContainer = $OuterMargin/Main/Battlefield/EnemySide/EnemyParty/EnemyCard
@onready var _hero_chain_title: Label = %HeroChainTitle
@onready var _enemy_chain_title: Label = %EnemyChainTitle

const ABILITY_SLOT_SCENE: PackedScene = preload("res://scenes/battle_ability_slot.tscn")
const TURN_GLOW_SHADER: Shader = preload("res://shaders/battle_turn_glow.gdshader")
const MAX_CHAIN_SLOT_SIDE: float = 116.0
const MIN_CHAIN_SLOT_SIDE: float = 64.0

var _combat: CombatSession
var _turn_glow_material := ShaderMaterial.new()
var _highlighted_portrait: TextureRect
var _defense_idle_color: Color = Color.WHITE
var _hero_chain: Array[String] = []
var _enemy_chain: Array[String] = []
## Карты врага раскрываются навсегда в рамках одной встречи.
var _enemy_revealed: Dictionary = {}
var _enemy_played: Dictionary = {}
var _playback: Tween
var _is_playing_back: bool = false
## Зафиксированная раскладка слотов, включая пропуски между приёмами.
var _committed_slots: Array[String] = []
var _items_session: GameSession
var _item_picker: BattleItemPicker
## Временные портреты поверх поля: движение не меняет настоящие UI-узлы.
var _impact_layer: Control
var _action_emblem: BattleActionEmblem
var _impact_portraits: Dictionary = {}
var _impact_idle: Dictionary = {}
var _impact_origin: Dictionary = {}
var _impact_shields: Dictionary = {}
var _shield_flash_tweens: Dictionary = {}
var _status_presenter: BattleStatusPresenter
var _support_enemy_view: BattleSupportEnemyView
var _extra_enemy_views: Dictionary = {}
var _extra_enemy_hp: Dictionary = {}
var _extra_enemy_max: Dictionary = {}
var _mounted_display: bool = false
var _mounted_details: Label
var _mounted_commander_energy: String = ""
var _visible_energy: Dictionary = {}
var _impact_originals: Dictionary = {}
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
var _support_hero_view: BattleSupportEnemyView
var _extra_hero_views: Dictionary = {}
var _turn_frame_overlays: Dictionary = {}
var _extra_hero_hp: Dictionary = {}
var _extra_hero_max: Dictionary = {}
var _hero_energy_label: Label
var _hero_profile: BattleArsenalView
var _inspection_timer: Timer
var _inspection_touch_index: int = -1
var _inspection_actor_id: String = ""
var _inspection_touch_position: Vector2 = Vector2.ZERO
var _inspection_triggered: bool = false
const LONG_PRESS_SECONDS: float = 0.55
const LONG_PRESS_MOVE_TOLERANCE: float = 24.0
var _enemy_energy_label: Label
var _selected_hero_id: String = "hero"
var _round_turn_label: Label
var _round_mode: bool = false
var _round_event_cursor: int = 0
var _selected_round_ability_id: String = ""
var _visible_support_hero_hp: int = 0
var _visible_support_hero_max: int = 0


# Длительность визуальной вспышки совпадает с паузой события «Блок».
# Эти параметры меняют только анимацию, не время действия защиты.
const SHIELD_FLASH_IN_SECONDS: float = 0.18
const SHIELD_FLASH_OUT_SECONDS: float = 1.00
const SHIELD_FLASH_START_SCALE: float = 0.25
const SHIELD_FLASH_PEAK_SCALE: float = 1.08
const SHIELD_FLASH_COLOR: Color = Color(0.40, 0.78, 1.0, 1.0)

@export_range(0.0, 2.0, 0.01) var clash_tick_seconds: float = 0.20
@export_range(0.0, 2.0, 0.01) var clash_action_start_seconds: float = 0.08
@export_range(0.1, 2.0, 0.01) var action_emblem_seconds: float = 0.65
@export_range(0.0, 2.0, 0.01) var clash_windup_seconds: float = 0.20
@export_range(0.0, 2.0, 0.01) var clash_impact_seconds: float = 0.13
@export_range(0.0, 2.0, 0.01) var clash_hold_seconds: float = 0.46
@export_range(0.0, 2.0, 0.01) var clash_recover_seconds: float = 0.27
@export_range(0.0, 2.0, 0.01) var clash_idle_seconds: float = 0.40
@export_range(0.0, 1.0, 0.01) var clash_recoil_fraction: float = 0.18
@export_range(0.0, 1.0, 0.01) var clash_contact_overlap_fraction: float = 0.14



func _ready() -> void:
	_turn_glow_material.shader = TURN_GLOW_SHADER
	_hero_health_meter.set_heart_visible(false)
	_enemy_health_meter.set_heart_visible(false)
	_sequence_scroll.resized.connect(_resize_chain_slots)
	_combat_items_button.pressed.connect(_on_combat_items_pressed)
	_combat_items_button.icon = StatIconCatalog.icon("potion")
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
	_status_presenter = BattleStatusPresenter.new(self)
	_status_presenter.info_requested.connect(_on_status_info_requested)
	_status_presenter.setup({"hero": _hero_portrait, "enemy": _enemy_portrait})
	_support_enemy_view = BattleSupportEnemyView.new()
	_support_enemy_view.info_requested.connect(_touch_info.show_text)
	_support_enemy_view.name = "SupportEnemy"
	_support_enemy_view.theme = _main_enemy_card.theme
	_enemy_party.add_child(_support_enemy_view)
	_support_enemy_view.hide()
	_extra_enemy_views[BattleState.SUPPORT_ENEMY_ID] = _support_enemy_view
	for index in range(3, MonsterCatalog.MAX_ENCOUNTER_PARTICIPANTS + 1):
		var view := BattleSupportEnemyView.new()
		view.name = "Enemy%d" % index
		view.theme = _main_enemy_card.theme
		view.info_requested.connect(_touch_info.show_text)
		_enemy_party.add_child(view)
		view.hide()
		_extra_enemy_views["enemy_%d" % index] = view
	_build_hero_party()
	_apply_team_styles()
	_build_round_controls()
	_hero_profile = BattleArsenalView.new()
	_hero_profile.name = "HeroProfile"
	_hero_profile.z_index = 30
	add_child(_hero_profile)
	_inspection_timer = Timer.new()
	_inspection_timer.one_shot = true
	_inspection_timer.wait_time = LONG_PRESS_SECONDS
	_inspection_timer.timeout.connect(_on_inspection_long_press)
	add_child(_inspection_timer)
	_bind_target_portrait(_hero_portrait, "hero")
	_bind_target_portrait(_enemy_portrait, "enemy")
	_register_turn_frame("hero", _hero_portrait)
	_register_turn_frame("enemy", _enemy_portrait)
	for actor_id in _extra_enemy_views:
		var view: BattleSupportEnemyView = _extra_enemy_views[actor_id]
		_bind_target_portrait(view.portrait_node(), actor_id)
		_register_turn_frame(actor_id, view.portrait_node())
		_status_presenter.setup({actor_id: view.portrait_node()})
	for actor_id in _extra_hero_views.keys():
		var extra_view: BattleSupportEnemyView = _extra_hero_views[actor_id] as BattleSupportEnemyView
		_register_turn_frame(actor_id, extra_view.portrait_node())
		_bind_target_portrait(extra_view.portrait_node(), actor_id)
		_status_presenter.setup({actor_id: extra_view.portrait_node()})
	_enemy_health_meter.get_node("HealthColumn/HealthBar").custom_minimum_size.x = 0.0
	_hero_health_meter.get_node("HealthColumn/HealthBar").custom_minimum_size.x = 0.0
	_battlefield.resized.connect(_layout_party_cards)
	resized.connect(_layout_party_cards)
	_layout_party_cards()
	_result_text.text = ""
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.24)


func _refresh_energy_labels() -> void:
	if _combat == null:
		return
	for actor_id in _combat.battle_state.hero_ids() + _combat.battle_state.enemy_ids():
		var actor: BattleParticipant = _combat.battle_state.get_participant(actor_id)
		_visible_energy[actor_id] = actor.current_energy()
		_set_display_energy(actor_id, actor.current_energy())


func _set_display_energy(actor_id: String, amount: int) -> void:
	var actor: BattleParticipant = _combat.battle_state.get_participant(actor_id)
	if actor == null:
		return
	_visible_energy[actor_id] = amount
	var lines: PackedStringArray = actor.energy_display_text().split("\n")
	lines[0] = "Эн. %d/%d" % [amount, actor.max_energy]
	var caption: String = "\n".join(lines)
	if actor_id == "hero":
		_hero_energy_label.text = caption
	elif actor_id == "enemy":
		_enemy_energy_label.text = "%s\n%s" % [_enemy_name_for_id(actor_id), caption] if _mounted_display else caption
	else:
		var view: BattleSupportEnemyView = _extra_hero_views.get(actor_id, _extra_enemy_views.get(actor_id)) as BattleSupportEnemyView
		if view != null:
			view.set_energy_text(caption)
	if _mounted_display and actor_id == _combat.battle_state.bond_commander_id:
		_mounted_commander_energy = caption
		_refresh_mounted_details()


func _build_hero_party() -> void:
	var hero_card: PanelContainer = $OuterMargin/Main/Battlefield/HeroSide/HeroParty/HeroCard
	hero_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_card.mouse_filter = Control.MOUSE_FILTER_PASS
	hero_card.gui_input.connect(_on_target_portrait_input.bind("hero"))
	_support_hero_view = BattleSupportEnemyView.new()
	_support_hero_view.name = "SecondHero"
	_support_hero_view.theme = hero_card.theme
	_support_hero_view.info_requested.connect(_touch_info.show_text)
	_hero_party.add_child(_support_hero_view)
	_support_hero_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_support_hero_view.gui_input.connect(_on_target_portrait_input.bind("hero_2"))
	_support_hero_view.hide()
	_extra_hero_views["hero_2"] = _support_hero_view
	for index in [3, 4]:
		var extra_view := BattleSupportEnemyView.new()
		extra_view.name = "Hero%d" % index
		extra_view.theme = hero_card.theme
		extra_view.info_requested.connect(_touch_info.show_text)
		_hero_party.add_child(extra_view)
		extra_view.mouse_filter = Control.MOUSE_FILTER_PASS
		extra_view.gui_input.connect(_on_target_portrait_input.bind("hero_%d" % index))
		extra_view.hide()
		_extra_hero_views["hero_%d" % index] = extra_view
	_hero_energy_label = Label.new()
	_hero_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_energy_label.add_theme_color_override("font_color", Color("#66c9e8"))
	_hero_health_meter.get_parent().add_child(_hero_energy_label)
	_enemy_energy_label = Label.new()
	_enemy_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_energy_label.add_theme_color_override("font_color", Color("#66c9e8"))
	_enemy_health_meter.get_parent().add_child(_enemy_energy_label)
	_mounted_details = Label.new()
	_mounted_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mounted_details.add_theme_color_override("font_color", Color("#d9bc86"))
	_mounted_details.hide()
	_enemy_health_meter.get_parent().add_child(_mounted_details)


func _apply_team_styles() -> void:
	var plain_style := StyleBoxEmpty.new()
	for card in _hero_party.get_children():
		(card as PanelContainer).add_theme_stylebox_override("panel", plain_style)
	for card in _enemy_party.get_children():
		(card as PanelContainer).add_theme_stylebox_override("panel", plain_style)


func _equalize_hero_cards() -> void:
	_fit_party_cards(_hero_party, _hero_portrait, _hero_name, _hero_health_meter, _hero_energy_label)


func _layout_party_cards() -> void:
	_equalize_hero_cards()
	_equalize_enemy_cards()


func _fit_party_cards(party: HBoxContainer, portrait: TextureRect, actor_name: Label, health: HealthMeter, energy: Label) -> void:
	var count: int = 0
	for child in party.get_children():
		if child.visible:
			count += 1
	if count == 0:
		return
	var margins: MarginContainer = $OuterMargin
	var available: float = maxf(size.x - margins.get_theme_constant("margin_left") - margins.get_theme_constant("margin_right") - _battlefield.get_theme_constant("separation"), 0.0) * 0.5
	var gap: int = 6 if count > 2 else 12
	party.add_theme_constant_override("separation", gap)
	var width: float = clampf(floorf((available - gap * (count - 1)) / count), 1.0, 202.0)
	var height: float = maxf(_battlefield.size.y, 1.0)
	var side: float = maxf(1.0, minf(160.0, minf(width - 12.0, height * 0.48)))
	var font_size: int = clampi(floori(width / 8.0), 9, 15)
	for child in party.get_children():
		var card: PanelContainer = child as PanelContainer
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.custom_minimum_size = Vector2(width, 0)
		var margin: MarginContainer = card.get_child(0) as MarginContainer
		if margin != null:
			for edge in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
				margin.add_theme_constant_override(edge, 4)
		if card is BattleSupportEnemyView:
			(card as BattleSupportEnemyView).fit_card(side, font_size)
	portrait.custom_minimum_size = Vector2.ONE * side
	actor_name.clip_text = true
	actor_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	actor_name.add_theme_font_size_override("font_size", font_size)
	_fit_meter(health, font_size)
	energy.clip_text = true
	energy.add_theme_font_size_override("font_size", font_size)
	if party == _enemy_party and _mounted_details != null:
		_mounted_details.clip_text = true
		_mounted_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_mounted_details.add_theme_font_size_override("font_size", font_size)


func _fit_meter(health: HealthMeter, font_size: int) -> void:
	health.get_node("HeartIcon").hide()
	health.get_node("HealthColumn/HealthCaption/HealthTitle").hide()
	var value: Label = health.get_node("HealthColumn/HealthCaption/HealthValue")
	value.add_theme_font_size_override("font_size", font_size)
	value.clip_text = true
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _register_turn_frame(actor_id: String, portrait: TextureRect) -> void:
	if portrait == null or actor_id.is_empty():
		return
	var frame := Panel.new()
	frame.name = "TurnFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	frame.z_index = 1
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	style.border_color = Color(0.98, 0.82, 0.47, 0.98)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.72, 0.52, 0.16, 0.45)
	style.shadow_size = 8
	frame.add_theme_stylebox_override("panel", style)
	portrait.add_child(frame)
	_turn_frame_overlays[actor_id] = frame


func _refresh_active_turn_frame() -> void:
	if not _is_playing_back:
		_show_turn_frame(_round_next_actor())


func _show_turn_frame(actor_id: String) -> void:
	for frame in _turn_frame_overlays.values():
		(frame as Control).visible = false
	var frame: Control = _turn_frame_overlays.get(_display_actor_id(actor_id)) as Control
	if frame != null:
		frame.visible = true


func _build_round_controls() -> void:
	var actions: HBoxContainer = $OuterMargin/Main/BottomPanel/ActionsMargin/ActionsColumn/Actions
	_round_turn_label = Label.new()
	_round_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_round_turn_label)


func _hero_name_for_id(actor_id: String) -> String:
	var member: HeroState = _combat.hero_sources.get(actor_id) as HeroState
	return member.definition.display_name if member != null and member.definition != null else actor_id


func _select_hero_view(actor_id: String) -> void:
	if _combat == null or not _combat.battle_state.hero_ids().has(actor_id):
		return
	_selected_hero_id = actor_id
	var actor: BattleParticipant = _combat.battle_state.get_participant(actor_id)
	if actor == null or not actor.is_alive():
		return
	_hero_chain = AbilityCatalog.round_hero_ability_ids(actor)
	_selected_round_ability_id = ""
	_hero_chain_title.text = _hero_name_for_id(actor_id).to_upper()
	_refresh_chain_slots()
	_refresh_round_controls()


func _round_next_actor() -> String:
	if _combat == null or not _round_mode:
		return ""
	return _combat.battle_state.next_round_actor_id()


func _selected_round_ability() -> AbilityDefinition:
	return AbilityCatalog.get_ability(_selected_round_ability_id) if not _selected_round_ability_id.is_empty() else null


func _refresh_round_controls() -> void:
	if not _round_mode or _combat == null:
		return
	var actor_id: String = _round_next_actor()
	if not _is_playing_back:
		_set_turn_highlight(actor_id)
	var state: BattleState = _combat.battle_state
	_round_turn_label.text = "Раунд %d" % max(1, state.round_number)
	if not actor_id.is_empty():
		if actor_id in state.hero_ids():
			_round_turn_label.text += " · " + _hero_name_for_id(actor_id)
		else:
			_round_turn_label.text += " · " + _enemy_name_for_id(actor_id)
	_refresh_target_outlines()
	_refresh_active_turn_frame()


func _execute_round_turn(target_id: String = "", ability_id: String = "") -> void:
	if _is_playing_back or _combat == null or _combat.is_victory or _combat.is_defeat:
		return
	var result: Dictionary = _combat.play_round_turn(target_id, ability_id)
	if not bool(result.get("success", false)):
		_result_text.text = str(result.get("reason", ""))
		return
	_selected_round_ability_id = ""
	_is_playing_back = true
	_refresh_target_outlines()
	_play_phase_events(result.get("events", []))


func _continue_round() -> void:
	if not _round_mode or _combat == null or _is_playing_back:
		return
	var actor_id: String = _round_next_actor()
	if not (_combat.is_victory or _combat.is_defeat):
		actor_id = _combat.battle_state.prepare_next_round()
	if _combat.is_victory or _combat.is_defeat:
		_is_playing_back = true
		_play_phase_events(_combat.battle_state.events.slice(_round_event_cursor))
		return
	if actor_id in _combat.battle_state.enemy_ids():
		_execute_round_turn()
	else:
		if actor_id in _combat.battle_state.hero_ids():
			_select_hero_view(actor_id)
			var state: BattleState = _combat.battle_state
			if not AbilityCatalog.has_round_action(state.get_participant(actor_id), state.create_context()):
				_execute_round_turn()
				return
		_refresh_round_controls()


func _enemy_name_for_id(actor_id: String) -> String:
	var state: BattleState = _combat.battle_state
	var definition: MonsterDefinition = state.enemy_definition_for(actor_id)
	if definition == null:
		return actor_id
	if state.battle_bond != null and actor_id == state.bond_commander_id and not state.battle_bond.commander_separated_name.is_empty():
		return state.battle_bond.commander_separated_name
	var ordinal: int = 0
	var total: int = 0
	for id in state.enemy_ids():
		if state.enemy_definition_for(id) == definition:
			total += 1
			if id == actor_id:
				ordinal = total
	return "%s (%d)" % [definition.display_name, ordinal] if total > 1 else definition.display_name


func _display_actor_id(actor_id: String) -> String:
	if _mounted_display and _combat != null and actor_id == _combat.battle_state.bond_commander_id:
		return _combat.battle_state.bond_guardian_id
	return actor_id


func _enemy_texture(definition: MonsterDefinition) -> Texture2D:
	return definition.portrait if definition.portrait != null else definition.icon


func _configure_enemy_cards() -> void:
	var state: BattleState = _combat.battle_state
	_extra_enemy_hp.clear()
	_extra_enemy_max.clear()
	for actor_id in _extra_enemy_views:
		var view: BattleSupportEnemyView = _extra_enemy_views[actor_id]
		var actor: BattleParticipant = state.get_participant(actor_id)
		var definition: MonsterDefinition = state.enemy_definition_for(actor_id)
		view.configure(actor, _enemy_texture(definition) if definition != null else null,
			_enemy_name_for_id(actor_id), definition.portrait_flip_h if definition != null else false)
		view.hide_action_slots()
		if actor != null:
			_extra_enemy_hp[actor_id] = actor.health
			_extra_enemy_max[actor_id] = actor.max_health
	_sync_enemy_formation()


func _sync_enemy_formation() -> void:
	var state: BattleState = _combat.battle_state
	_mounted_display = state.battle_bond != null and state.bond_mounted
	var primary: MonsterDefinition = state.enemy_definition_for(state.enemy_id)
	var visual: MonsterDefinition = primary
	if _mounted_display:
		visual = state.enemy_definition_for(state.bond_commander_id)
	_enemy_name.text = visual.display_name if _mounted_display else _enemy_name_for_id(state.enemy_id)
	_enemy_health_meter.tooltip_text = primary.display_name if _mounted_display else ""
	_enemy_portrait.texture = _enemy_texture(visual)
	_enemy_portrait.flip_h = visual.portrait_flip_h
	for actor_id in _extra_enemy_views:
		var card: BattleSupportEnemyView = _extra_enemy_views[actor_id]
		var actor: BattleParticipant = state.get_participant(actor_id)
		card.visible = actor != null and not (_mounted_display and actor_id == state.bond_commander_id)
	if state.battle_bond != null:
		var commander: BattleParticipant = state.get_participant(state.bond_commander_id)
		var card: BattleSupportEnemyView = _extra_enemy_views[state.bond_commander_id]
		if commander != null:
			if state.battle_bond.commander_separated_portrait != null:
				card.portrait_node().texture = state.battle_bond.commander_separated_portrait
			_status_presenter.move_markers(state.bond_commander_id, _enemy_portrait if _mounted_display else card.portrait_node(), _mounted_display)
			_mounted_commander_energy = "Эн. %d/%d" % [commander.current_energy(), commander.max_energy]
	_main_enemy_card.visible = true
	if state.battle_bond != null and not _mounted_display:
		var guardian: BattleParticipant = state.get_participant(state.bond_guardian_id)
		var commander: BattleParticipant = state.get_participant(state.bond_commander_id)
		if guardian != null and commander != null:
			_main_enemy_card.visible = guardian.is_alive() or not commander.is_alive()
			(_extra_enemy_views[state.bond_commander_id] as Control).visible = commander.is_alive() or not guardian.is_alive()
	_mounted_details.visible = _mounted_display
	_refresh_mounted_details()
	_layout_party_cards()


func _refresh_mounted_details() -> void:
	if not _mounted_display:
		return
	var state: BattleState = _combat.battle_state
	var commander_id: String = state.bond_commander_id
	_mounted_details.text = "%s: %d/%d HP\n%s" % [_enemy_name_for_id(commander_id), int(_extra_enemy_hp.get(commander_id, 0)), int(_extra_enemy_max.get(commander_id, 0)), _mounted_commander_energy]


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
	_round_mode = true
	_round_event_cursor = 0
	_selected_hero_id = "hero"
	_combat_items_button.hide()
	_configure_enemy_cards()
	_extra_hero_hp.clear()
	_extra_hero_max.clear()
	for card in _extra_hero_views.values():
		(card as Control).hide()
	for extra_id in combat.battle_state.hero_ids():
		if extra_id == "hero" or not _extra_hero_views.has(extra_id):
			continue
		var extra_actor: BattleParticipant = combat.battle_state.get_participant(extra_id)
		var extra_member: HeroState = combat.hero_sources.get(extra_id) as HeroState
		var extra_view: BattleSupportEnemyView = _extra_hero_views[extra_id] as BattleSupportEnemyView
		var texture: Texture2D = extra_member.definition.portrait if extra_member != null and extra_member.definition != null else null
		extra_view.configure(extra_actor, texture, _hero_name_for_id(extra_id))
		extra_view.reveal_all()
		_extra_hero_hp[extra_id] = extra_actor.health
		_extra_hero_max[extra_id] = extra_actor.max_health
	call_deferred("_equalize_hero_cards")
	if hero.definition != null:
		_hero_name.text = hero.definition.display_name
		_hero_portrait.texture = hero.definition.portrait
	_defense_idle_color = Color(0.55, 0.60, 0.67, 0.65)
	_hero_attack_value.text = str(_basic_strike_damage(_combat.battle_state.get_hero()))
	_hero_strength_value.text = "%d" % _combat.battle_state.get_hero().effective_strength()
	_hero_agility_value.text = "%d" % _combat.battle_state.get_hero().effective_agility()
	_refresh_accuracy_and_dodge()
	_set_block_display("hero", _combat.battle_state.get_hero().block_armor)
	_hero_chain_title.text = _hero_name.text.to_upper()
	_enemy_chain_title.text = _enemy_name.text.to_upper()
	_enemy_attack_value.text = str(_basic_strike_damage(_combat.battle_state.get_enemy()))
	_enemy_strength_value.text = "%d" % _combat.battle_state.get_enemy().effective_strength()
	_enemy_agility_value.text = "%d" % _combat.battle_state.get_enemy().effective_agility()
	_set_block_display("enemy", _combat.battle_state.get_enemy().block_armor)
	_enemy_portrait.modulate = Color.WHITE
	_hero_health_meter.set_health(hero.health, hero.effective_max_health())
	_refresh_energy_labels()
	_enemy_health_meter.set_health(combat.enemy_health, combat.enemy_max_health)
	_visible_hero_hp = hero.health
	_visible_support_hero_hp = int(_extra_hero_hp.get("hero_2", 0))
	_visible_support_hero_max = int(_extra_hero_max.get("hero_2", 0))
	_visible_enemy_hp = combat.enemy_health
	_visible_support_hp = int(_extra_enemy_hp.get(BattleState.SUPPORT_ENEMY_ID, 0))
	_visible_hero_max = hero.effective_max_health()
	_visible_enemy_max = combat.enemy_max_health
	_visible_support_max = int(_extra_enemy_max.get(BattleState.SUPPORT_ENEMY_ID, 0))
	_status_presenter.reset()
	_status_presenter.sync(_combat.battle_state.participants)
	_enemy_chain = _combat.battle_state.get_enemy().action_chain.duplicate()
	_enemy_revealed.clear()
	_enemy_played.clear()
	_refresh_enemy_slots()
	_result_text.text = ""
	_start_round_combat()


func _start_round_combat() -> void:
	var prepared: Dictionary = _combat.prepare_round_combat()
	if not bool(prepared.get("success", false)):
		_result_text.text = str(prepared.get("reason", "Не удалось подготовить бой"))
		return
	_manual_started = false
	_select_hero_view("hero")
	for extra_id in _extra_hero_views:
		var extra_view: BattleSupportEnemyView = _extra_hero_views[extra_id] as BattleSupportEnemyView
		if extra_view.visible:
			extra_view.hide_action_slots()
	_refresh_chain_slots()
	_refresh_round_controls()
	call_deferred("_continue_round_after_layout")


func _continue_round_after_layout() -> void:
	await get_tree().process_frame
	if is_inside_tree():
		_continue_round()


func _equalize_enemy_cards() -> void:
	_fit_party_cards(_enemy_party, _enemy_portrait, _enemy_name, _enemy_health_meter, _enemy_energy_label)


func _refresh_chain_slots() -> void:
	for child in _sequence_slots.get_children():
		_sequence_slots.remove_child(child)
		child.queue_free()
	var actor: BattleParticipant = _combat.battle_state.get_participant(_selected_hero_id)
	if _round_mode:
		_hero_chain = AbilityCatalog.round_hero_ability_ids(actor)
		if not _hero_chain.has(_selected_round_ability_id):
			_selected_round_ability_id = ""
	var available: Array[int] = []
	if _manual_started:
		available = _combat.battle_state.manual_available_slots()
	for index in range(_hero_chain.size()):
		var ability_id: String = _hero_chain[index]
		var ability: AbilityDefinition = AbilityCatalog.get_ability(ability_id)
		var slot: BattleAbilitySlot = ABILITY_SLOT_SCENE.instantiate() as BattleAbilitySlot
		_sequence_slots.add_child(slot)
		var can_use: bool = _round_mode and actor != null and actor.is_alive() and AbilityCatalog.round_hero_unavailable_reason(actor, ability_id).is_empty()
		slot.configure(index, ability, can_use if _round_mode else available.has(index), actor)
		if _round_mode and not AbilityCatalog.uses_hero_action_slot(ability_id):
			slot.set_slot_number_visible(false)
		if _round_mode and not can_use and (ability == null or not ability.passive):
			slot.modulate = Color(0.48, 0.48, 0.48)
		elif _manual_started and not available.has(index):
			slot.modulate = Color(0.48, 0.48, 0.48)
		slot.slot_selected.connect(_on_slot_pressed.bind(slot))
		slot.info_requested.connect(_touch_info.show_text)
		_touch_info.attach_long_press(slot, func() -> String: return slot.tooltip_text)
	_resize_chain_slots()
	if _round_mode:
		_highlight_round_action()
	elif _manual_started:
		_highlight_manual_selection()
	else:
		_highlight_next_actions()


func _highlight_round_action() -> void:
	if _sequence_slots == null:
		return
	for index in range(_sequence_slots.get_child_count()):
		var selected: bool = _hero_chain[index] == _selected_round_ability_id
		(_sequence_slots.get_child(index) as BattleAbilitySlot).set_current(selected)


func _resize_chain_slots() -> void:
	_fit_chain_row(_sequence_scroll, _sequence_slots)


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
	var capacity: int = _enemy_chain.size()
	for index in range(capacity):
		var slot: BattleAbilitySlot = ABILITY_SLOT_SCENE.instantiate() as BattleAbilitySlot
		_enemy_sequence_slots.add_child(slot)
		if index < _enemy_chain.size():
			if _enemy_revealed.has(index):
				slot.reveal_enemy_action(AbilityCatalog.get_ability(_enemy_chain[index]), enemy)
			else:
				slot.configure_hidden(index)
		if _enemy_played.has(index):
			slot.modulate = BattleAbilitySlot.SPENT_MODULATE
		slot.info_requested.connect(_touch_info.show_text)
	if not _is_playing_back and not _round_mode:
		_highlight_next_actions()
	_resize_chain_slots()


func _conceal_enemy_actions() -> void:
	# Скрывать можно только ещё не сыгранные позиции.
	for index in range(_enemy_chain.size()):
		if not _enemy_revealed.has(index):
			(_enemy_sequence_slots.get_child(index) as BattleAbilitySlot).configure_hidden(index)


func _highlight_slots(hero_index: int, enemy_index: int) -> void:
	for index in range(_sequence_slots.get_child_count()):
		var active: bool = index == hero_index
		(_sequence_slots.get_child(index) as BattleAbilitySlot).set_current(active)
	for index in range(_enemy_sequence_slots.get_child_count()):
		var active: bool = index == enemy_index
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
	if _round_mode:
		if _is_playing_back or _round_next_actor() != _selected_hero_id:
			return
		if _index < 0 or _index >= _hero_chain.size():
			return
		var ability_id: String = _hero_chain[_index]
		var actor: BattleParticipant = _combat.battle_state.get_participant(_selected_hero_id)
		if not AbilityCatalog.round_hero_unavailable_reason(actor, ability_id).is_empty():
			return
		_selected_round_ability_id = ability_id
		_highlight_round_action()
		_refresh_round_controls()
		return
	if _manual_started:
		if _is_playing_back or _combat.battle_state.flow.stage == BattleFlow.Stage.FINISHED:
			return
		if not _combat.battle_state.manual_available_slots().has(_index):
			return
		var requested_slot: int = _index
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


func _portrait_for_id(actor_id: String) -> TextureRect:
	actor_id = _display_actor_id(actor_id)
	if actor_id == "hero":
		return _hero_portrait
	if actor_id == "enemy":
		return _enemy_portrait if _main_enemy_card.visible else null
	var view: BattleSupportEnemyView = _extra_hero_views.get(actor_id, _extra_enemy_views.get(actor_id)) as BattleSupportEnemyView
	return view.portrait_node() if view != null and view.visible else null


func _set_turn_highlight(actor_id: String) -> void:
	var portrait: TextureRect = _portrait_for_id(actor_id)
	if portrait == _highlighted_portrait:
		return
	if is_instance_valid(_highlighted_portrait):
		_highlighted_portrait.material = null
	_highlighted_portrait = portrait
	if portrait != null:
		portrait.material = _turn_glow_material


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
	_impact_originals.clear()
	var state: BattleState = _combat.battle_state
	for actor_id in state.hero_ids() + state.enemy_ids():
		var original: TextureRect = _portrait_for_id(actor_id)
		if original == null or original.texture == null:
			continue
		var visual_id: String = _display_actor_id(actor_id)
		if _impact_portraits.has(visual_id):
			var existing: TextureRect = _impact_portraits[visual_id]
			_impact_portraits[actor_id] = existing
			_impact_origin[actor_id] = existing.position
			_impact_idle[actor_id] = existing.position
			_impact_shields[actor_id] = _impact_shields[visual_id]
			_status_presenter.attach_impact(actor_id, existing)
			continue
		var portrait := TextureRect.new()
		portrait.name = "Impact_" + actor_id
		portrait.texture = original.texture
		portrait.material = original.material
		portrait.flip_h = original.flip_h
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.size = original.size
		portrait.pivot_offset = portrait.size * 0.5
		portrait.position = original.global_position - global_position
		_impact_origin[actor_id] = portrait.position
		_impact_idle[actor_id] = portrait.position
		portrait.modulate = original.modulate
		_impact_originals[original] = original.modulate
		_impact_layer.add_child(portrait)
		_impact_portraits[actor_id] = portrait
		var turn_frame: Control = _turn_frame_overlays.get(visual_id) as Control
		if turn_frame != null and turn_frame.visible:
			var frame: Control = turn_frame.duplicate() as Control
			portrait.add_child(frame)
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
	_clear_action_emblem()
	for flash in _shield_flash_tweens.values():
		var tween: Tween = flash as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	_shield_flash_tweens.clear()
	_status_presenter.clear_impact()
	if _impact_layer != null and is_instance_valid(_impact_layer):
		_impact_layer.hide()
		_impact_layer.queue_free()
	_impact_layer = null
	_impact_portraits.clear()
	_impact_shields.clear()
	for original in _impact_originals:
		if is_instance_valid(original):
			(original as TextureRect).modulate = _impact_originals[original]
	_impact_originals.clear()
	if _round_mode:
		_highlight_round_action()
	else:
		_highlight_next_actions()


func _play_phase_events(phase_events: Array) -> void:
	if _round_mode:
		var actor_id: String = ""
		for event in phase_events:
			if event.get("type", "") == "turn":
				actor_id = str(event.get("actor_id", ""))
				break
		_set_turn_highlight(actor_id)
		_show_turn_frame(actor_id)
	_create_impact_layer()
	_playback = create_tween()
	_playback.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for group in BattleClashTimeline.group_events(phase_events, true):
		_queue_clash_animation(group["events"])
	_playback.tween_callback(_clear_impact_layer)
	_playback.tween_callback(_after_phase_playback)


func _queue_clash_animation(group_events: Array[Dictionary]) -> void:
	var has_attack: bool = false
	var announced: Dictionary = {}
	for event in group_events:
		var kind: String = str(event.get("type", ""))
		var actor_id: String = str(event.get("actor_id", ""))
		var ability_id: String = str(event.get("ability_id", ""))
		if kind in ["attack", "counter"]:
			if not announced.has(actor_id) or announced[actor_id] != ability_id:
				_queue_action_emblem(event)
				announced[actor_id] = ability_id
			_queue_single_attack(event)
			has_attack = true
		else:
			_playback.tween_callback(_display_phase_event.bind(event))
			if kind in ["tick", "turn"]:
				_playback.tween_interval(clash_tick_seconds)
			elif kind == "action_start":
				var failed: bool = group_events.any(func(result: Dictionary) -> bool:
					return result.get("type") == "failed" and result.get("actor_id") == actor_id and result.get("ability_id") == ability_id)
				if not failed:
					_queue_action_emblem(event)
					announced[actor_id] = ability_id
				else:
					_playback.tween_interval(clash_action_start_seconds)
	if not has_attack:
		_playback.tween_interval(clash_idle_seconds)


func _queue_action_emblem(event: Dictionary) -> void:
	_playback.tween_callback(_show_clash_ability.bind(event))
	_playback.tween_method(_advance_action_emblem, 0.0, 1.0, action_emblem_seconds).set_trans(Tween.TRANS_LINEAR)
	_playback.tween_callback(_clear_action_emblem)


func _queue_single_attack(event: Dictionary) -> void:
	var actor_id: String = str(event.get("actor_id", ""))
	var target_id: String = str(event.get("target_id", ""))
	var attacker: TextureRect = _impact_portraits.get(actor_id) as TextureRect
	var target: TextureRect = _impact_portraits.get(target_id) as TextureRect
	if attacker == null or target == null or attacker == target:
		_playback.tween_callback(_impact.bind(event))
		_playback.tween_interval(clash_hold_seconds)
		return
	var origin: Vector2 = _impact_origin[actor_id]
	var target_origin: Vector2 = _impact_origin[target_id]
	var delta: Vector2 = target_origin + target.size * 0.5 - origin - attacker.size * 0.5
	var windup: Vector2 = origin - delta.normalized() * attacker.size.x * clash_recoil_fraction
	var contact: Vector2 = BattleClashGeometry.contact_positions(_impact_origin,
		{actor_id: attacker.size, target_id: target.size}, {actor_id: target_id}, clash_contact_overlap_fraction)[actor_id]
	_playback.tween_callback(_set_attack_layer.bind(attacker, true))
	_playback.tween_property(attacker, "position", windup, clash_windup_seconds)
	var approach: float = clampf(BattleClashGeometry.approach_seconds(clash_impact_seconds,
		{actor_id: windup}, {actor_id: contact}, {actor_id: attacker.size}), clash_impact_seconds, maxf(clash_impact_seconds, 0.48))
	_playback.tween_property(attacker, "position", contact, approach).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_playback.tween_callback(_impact.bind(event))
	_playback.tween_interval(clash_hold_seconds)
	_playback.tween_property(attacker, "position", origin, clash_recover_seconds)
	_playback.parallel().tween_property(target, "modulate", Color.WHITE, clash_recover_seconds)
	_playback.tween_callback(_set_attack_layer.bind(attacker, false))


func _set_attack_layer(portrait: TextureRect, attacking: bool) -> void:
	portrait.z_index = 1 if attacking else 0


func _show_clash_ability(event: Dictionary) -> void:
	_clear_action_emblem()
	if not is_instance_valid(_impact_layer):
		return
	var actor_id: String = str(event.get("actor_id", ""))
	var portrait: TextureRect = _impact_portraits.get(actor_id) as TextureRect
	if portrait == null:
		return
	var kind: String = str(event.get("type", ""))
	var actor: BattleParticipant = _combat.battle_state.get_participant(actor_id)
	var ability_id: String = str(event.get("ability_id", ""))
	var ability: AbilityDefinition = AbilityCatalog.get_ability(ability_id) if not ability_id.is_empty() else null
	if ability == null and kind not in ["attack", "counter"]:
		return
	_action_emblem = BattleActionEmblem.new()
	_impact_layer.add_child(_action_emblem)
	_action_emblem.configure(ability, actor, portrait, _impact_layer.size,
		"Контратака" if kind == "counter" else "Атака",
		BattleAbilitySlot.ATTACK_ICON,
		BattleActionEmblem.Effect.ATTACK)


func _advance_action_emblem(progress: float) -> void:
	if is_instance_valid(_action_emblem):
		_action_emblem.advance(progress)


func _clear_action_emblem() -> void:
	if is_instance_valid(_action_emblem):
		_action_emblem.hide()
		_action_emblem.queue_free()
	_action_emblem = null


func _display_phase_event(event: Dictionary) -> void:
	var actor_id: String = str(event.get("actor_id", ""))
	var kind: String = str(event.get("type", ""))
	# Удар записывается при контакте портретов, остальные события здесь.
	if kind not in ["attack", "counter"]:
		_emit_combat_event_log(event)
	match kind:
		"enemy_chain_changed":
			if actor_id == "enemy":
				_enemy_chain = _combat.battle_state.get_enemy().action_chain.duplicate()
				_enemy_revealed.clear()
				_enemy_played.clear()
				_refresh_enemy_slots()
			elif _extra_enemy_views.has(actor_id):
				(_extra_enemy_views[actor_id] as BattleSupportEnemyView).set_chain(_combat.battle_state.get_participant(actor_id))
		"tick":
			_conceal_enemy_actions()
			if _manual_started:
				var hero_slot: int = int(event.get("hero_slot", -1))
				_highlight_slots(hero_slot, int(event.get("enemy_slot", -1)))
			else:
				_highlight_slots(int(event.get("hero_slot", -1)), int(event.get("enemy_slot", -1)))
			if _support_enemy_view != null:
				var support_slot: int = int(event.get("support_slot", -1))
				var support: BattleParticipant = _combat.battle_state.get_participant(BattleState.SUPPORT_ENEMY_ID)
				if support != null:
					_support_enemy_view.highlight_cursor(support_slot)
		"turn":
			if _round_mode:
				var slot_index: int = int(event.get("slot_index", -1))
				if actor_id in _combat.battle_state.hero_ids():
					_select_hero_view(actor_id)
					for i in range(_sequence_slots.get_child_count()):
						(_sequence_slots.get_child(i) as BattleAbilitySlot).set_current(i == slot_index)
				elif actor_id == "enemy":
					for i in range(_enemy_sequence_slots.get_child_count()):
						(_enemy_sequence_slots.get_child(i) as BattleAbilitySlot).set_current(i == slot_index)
				elif _extra_enemy_views.has(actor_id):
					(_extra_enemy_views[actor_id] as BattleSupportEnemyView).highlight_cursor(slot_index)
				_round_turn_label.text = "Раунд %d · %s" % [int(event.get("round", 0)), _hero_name_for_id(actor_id) if actor_id in _combat.battle_state.hero_ids() else _enemy_name_for_id(actor_id)]
		"action_start":
			# Враг показывает только исполняемый сейчас приём, не будущие.
			if actor_id == "enemy":
				var index: int = int(event.get("slot_index", -1))
				if index >= 0 and index < _enemy_chain.size():
					_enemy_revealed[index] = true
					_enemy_played[index] = true
					var slot: BattleAbilitySlot = _enemy_sequence_slots.get_child(index) as BattleAbilitySlot
					slot.reveal_enemy_action(AbilityCatalog.get_ability(str(event.get("ability_id", ""))),
						_combat.battle_state.get_enemy())
					slot.modulate = BattleAbilitySlot.SPENT_MODULATE
			elif _extra_enemy_views.has(actor_id):
				(_extra_enemy_views[actor_id] as BattleSupportEnemyView).reveal(int(event.get("slot_index", -1)), str(event.get("ability_id", "")))
		"block":
			var target_id: String = str(event.get("target_id", ""))
			_set_block_display(target_id, int(event.get("armor", 0)))
			_flash_shield(target_id)
		"block_consumed":
			_set_block_display(str(event.get("target_id", "")), int(event.get("armor", 0)))
		"heal":
			var healed: int = int(event.get("healed", 0))
			var healed_id: String = str(event.get("target_id", actor_id))
			if healed_id == "hero":
				_visible_hero_hp += healed
				_hero_health_meter.set_health(_visible_hero_hp, _visible_hero_max, true)
			elif _extra_hero_views.has(healed_id):
				_set_extra_hero_health(healed_id, int(_extra_hero_hp.get(healed_id, 0)) + healed,
					int(_extra_hero_max.get(healed_id, 0)))
			elif healed_id == "enemy":
				_visible_enemy_hp += healed
				_enemy_health_meter.set_health(_visible_enemy_hp, _visible_enemy_max, true)
			elif _extra_enemy_views.has(healed_id):
				_set_extra_enemy_health(healed_id, int(_extra_enemy_hp.get(healed_id, 0)) + healed, int(_extra_enemy_max.get(healed_id, 0)))
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
			elif _extra_hero_views.has(target_id):
				_set_extra_hero_health(target_id, actual_hp, actual_max)
			elif target_id == "enemy":
				_visible_enemy_hp = actual_hp
				_visible_enemy_max = actual_max
				_enemy_health_meter.set_health(actual_hp, actual_max, true)
			elif _extra_enemy_views.has(target_id):
				_set_extra_enemy_health(target_id, actual_hp, actual_max)
		"status_applied":
			_set_accuracy_and_dodge_from_event(event)
			_status_presenter.flash(str(event.get("target_id", "")), str(event.get("status_id", "")))
		"status_removed":
			_status_presenter.set_visible(str(event.get("target_id", "")), str(event.get("status_id", "")), false)
		"status_tick", "health_spent":
			var target_id: String = str(event.get("target_id", actor_id))
			var amount: int = int(event.get("damage", 0))
			if target_id == "hero":
				_visible_hero_hp -= amount
				_hero_health_meter.set_health(_visible_hero_hp, _visible_hero_max, true)
			elif _extra_hero_views.has(target_id):
				_set_extra_hero_health(target_id, int(_extra_hero_hp.get(target_id, 0)) - amount,
					int(_extra_hero_max.get(target_id, 0)))
			elif target_id == "enemy":
				_visible_enemy_hp -= amount
				_enemy_health_meter.set_health(_visible_enemy_hp, _visible_enemy_max, true)
			elif _extra_enemy_views.has(target_id):
				_set_extra_enemy_health(target_id, int(_extra_enemy_hp.get(target_id, 0)) - amount, int(_extra_enemy_max.get(target_id, 0)))
			if amount > 0:
				_spawn_number(target_id, "−%d" % amount, Color("#ed4444"), 18.0)
		"cycle_completed":
			if actor_id == "enemy":
				_enemy_played.clear()
				for slot in _enemy_sequence_slots.get_children():
					(slot as BattleAbilitySlot).modulate = Color.WHITE
			elif _extra_enemy_views.has(actor_id):
				(_extra_enemy_views[actor_id] as BattleSupportEnemyView).reset_played()
		"failed":
			# Текущий слот коротко вспыхивает красным, без текстовых предупреждений.
			var slot_index: int = int(event.get("slot_index", -1))
			if not _extra_enemy_views.has(actor_id) and not _extra_hero_views.has(actor_id):
				var row: HBoxContainer = _sequence_slots if actor_id == "hero" else _enemy_sequence_slots
				if slot_index >= 0 and slot_index < row.get_child_count():
					(row.get_child(slot_index) as BattleAbilitySlot).flash_empty()
		"resource_spent":
			if str(event.get("resource_id", "")) == "energy":
				_set_display_energy(actor_id, int(event.get("remaining", 0)))
		"energy_restored":
			_set_display_energy(str(event.get("target_id", actor_id)), int(event.get("remaining", 0)))
		"energy_drained":
			var target_id: String = str(event.get("target_id", ""))
			_set_display_energy(target_id, int(_visible_energy.get(target_id, 0)) - int(event.get("amount", 0)))
			_set_display_energy(actor_id, int(_visible_energy.get(actor_id, 0)) + int(event.get("restored", 0)))


func _emit_combat_event_log(event: Dictionary) -> void:
	var names: Dictionary = {}
	for id in _combat.battle_state.hero_ids():
		names[id] = _hero_name_for_id(id)
	for id in _combat.battle_state.enemy_ids():
		names[id] = _enemy_name_for_id(id)
	var message: String = BattleCombatLog.format_event(event, _hero_name.text, _enemy_name.text, "", names)
	if _round_mode and str(event.get("type", "")) == "turn":
		message = "  Раунд %d · ход %s" % [int(event.get("round", 0)), str(names.get(str(event.get("actor_id", "")), ""))]
	if not message.is_empty():
		combat_log_line.emit(message)


func _impact(event: Dictionary) -> void:
	_emit_combat_event_log(event)
	var target_id: String = str(event.get("target_id", ""))
	var target: TextureRect = _impact_portraits.get(target_id) as TextureRect
	var hp_damage: int = int(event.get("damage", 0))
	var shield_damage: int = int(event.get("block_absorbed", event.get("shield_blocked", 0)))
	if shield_damage > 0:
		_spawn_number(target_id, "−%d" % shield_damage, Color("#67c8ff"), -12)
	if hp_damage > 0:
		_spawn_number(target_id, "−%d" % hp_damage, Color("#ff6969"), 18)
	if hp_damage == 0 and shield_damage == 0 and not bool(event.get("dodged", false)):
		_spawn_number(target_id, "0", Color("#c1cad2"))
	if target_id == "hero":
		_visible_hero_hp = int(event.get("hp_after", _visible_hero_hp - hp_damage))
		_visible_hero_max = int(event.get("hp_max", _visible_hero_max))
		_hero_health_meter.set_health(_visible_hero_hp, _visible_hero_max, true)
	elif _extra_hero_views.has(target_id):
		_set_extra_hero_health(target_id, int(event.get("hp_after", int(_extra_hero_hp.get(target_id, 0)) - hp_damage)),
			int(event.get("hp_max", _extra_hero_max.get(target_id, 0))))
	elif target_id == "enemy":
		_visible_enemy_hp = int(event.get("hp_after", _visible_enemy_hp - hp_damage))
		_visible_enemy_max = int(event.get("hp_max", _visible_enemy_max))
		_enemy_health_meter.set_health(_visible_enemy_hp, _visible_enemy_max, true)
	elif _extra_enemy_views.has(target_id):
		_set_extra_enemy_health(target_id, int(event.get("hp_after", int(_extra_enemy_hp.get(target_id, 0)) - hp_damage)), int(event.get("hp_max", _extra_enemy_max.get(target_id, 0))))
	if target == null:
		return
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
	if _extra_hero_views.has(actor_id):
		(_extra_hero_views[actor_id] as BattleSupportEnemyView).set_block(amount)
		return
	if _extra_enemy_views.has(actor_id):
		(_extra_enemy_views[actor_id] as BattleSupportEnemyView).set_block(amount)
		return
	var value: Label = _hero_defense_value if actor_id == "hero" else _enemy_defense_value
	var icon: TextureRect = _hero_defense_icon if actor_id == "hero" else _enemy_defense_icon
	var actor: BattleParticipant = _combat.battle_state.get_participant(actor_id) if _combat != null else null
	var armor: int = actor.effective_defense() if actor != null else 0
	value.text = "%d / %d" % [armor, amount] if amount > 0 else str(armor)
	value.tooltip_text = "Броня: %d\nАктивный блок: %d" % [armor, amount]
	icon.modulate = Color.WHITE if armor > 0 or amount > 0 else _defense_idle_color


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
	label.z_index = 2
	_impact_layer.add_child(label)
	label.position = portrait.position + Vector2(portrait.size.x * 0.45 + x_offset, -22.0)
	var float_tween: Tween = label.create_tween()
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
	if _round_mode:
		_after_round_playback()
		return
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
			shield_broken.emit(broken_id, _combat.hero)
			_combat.hero.last_shield_broken = ""
			var hero_actor: BattleParticipant = _combat.battle_state.get_hero()
			if hero_actor != null and hero_actor._hero_snapshot != null:
				hero_actor._hero_snapshot.last_shield_broken = ""
	if _combat.is_victory:
		combat_log_line.emit("Бой окончен: победа %s" % _hero_name.text)
		_refresh_active_turn_frame()
		_show_victory()
	elif _combat.is_defeat:
		combat_log_line.emit("Бой окончен: поражение %s" % _hero_name.text)
		_refresh_active_turn_frame()
		_show_defeat()
	else:
		_result_text.text = ""
		_refresh_phase_controls()


func _after_round_playback() -> void:
	var state: BattleState = _combat.battle_state
	_status_presenter.sync(state.participants)
	_refresh_accuracy_and_dodge()
	for actor_id in state.hero_ids() + state.enemy_ids():
		var actor: BattleParticipant = state.get_participant(actor_id)
		if actor == null:
			continue
		_set_block_display(actor_id, actor.block_armor)
		if _extra_hero_views.has(actor_id):
			_set_extra_hero_health(actor_id, actor.health, actor.max_health)
			var view: BattleSupportEnemyView = _extra_hero_views[actor_id] as BattleSupportEnemyView
			view.refresh_health(actor)
			view.refresh_stats(actor)
		elif _extra_enemy_views.has(actor_id):
			_set_extra_enemy_health(actor_id, actor.health, actor.max_health)
			var view: BattleSupportEnemyView = _extra_enemy_views[actor_id]
			view.refresh_health(actor)
			view.refresh_stats(actor)
			view.highlight_cursor(actor.action_cursor)
		elif actor_id == "hero":
			_visible_hero_hp = actor.health
			_visible_hero_max = actor.max_health
			_hero_health_meter.set_health(actor.health, actor.max_health, true)
			_hero_portrait.modulate = Color.WHITE if actor.is_alive() else Color("#87909c")
		elif actor_id == "enemy":
			_visible_enemy_hp = actor.health
			_visible_enemy_max = actor.max_health
			_enemy_health_meter.set_health(actor.health, actor.max_health, true)
			_enemy_portrait.modulate = Color.WHITE if actor.is_alive() else Color("#87909c")
	_sync_enemy_formation()
	_refresh_energy_labels()
	for event_index in range(_round_event_cursor, state.events.size()):
		var event: Dictionary = state.events[event_index]
		var broken_id: String = str(event.get("shield_broken", ""))
		if broken_id.is_empty():
			continue
		var source: HeroState = _combat.hero_sources.get(str(event.get("target_id", ""))) as HeroState
		if source != null and source.last_shield_broken == broken_id:
			shield_broken.emit(broken_id, source)
			source.last_shield_broken = ""
	_round_event_cursor = state.events.size()
	if _combat.is_victory:
		_refresh_active_turn_frame()
		_show_victory()
	elif _combat.is_defeat:
		_refresh_active_turn_frame()
		_show_defeat()
	else:
		_refresh_enemy_slots()
		_refresh_chain_slots()
		_refresh_round_controls()
		call_deferred("_continue_round_after_layout")


## При проигрывании показываем снимок результата события, а не конечное
## состояние уже рассчитанной фазы.
func _set_extra_hero_health(actor_id: String, health: int, maximum: int) -> void:
	_extra_hero_hp[actor_id] = health
	_extra_hero_max[actor_id] = maximum
	var view: BattleSupportEnemyView = _extra_hero_views.get(actor_id) as BattleSupportEnemyView
	if view != null:
		view.set_health(health, maximum)


func _set_extra_enemy_health(actor_id: String, health: int, maximum: int) -> void:
	_extra_enemy_hp[actor_id] = health
	_extra_enemy_max[actor_id] = maximum
	if actor_id == BattleState.SUPPORT_ENEMY_ID:
		_visible_support_hp = health
		_visible_support_max = maximum
	var view: BattleSupportEnemyView = _extra_enemy_views.get(actor_id) as BattleSupportEnemyView
	if view != null:
		view.set_health(health, maximum)
	_refresh_mounted_details()


func _set_accuracy_and_dodge_from_event(event: Dictionary) -> void:
	if not event.has("dodge_after"):
		return
	var target_id: String = str(event.get("target_id", ""))
	if _extra_hero_views.has(target_id):
		(_extra_hero_views[target_id] as BattleSupportEnemyView).set_precision(int(event.get("dodge_after", 0)), int(event.get("accuracy_after", 0)))
		return
	if _extra_enemy_views.has(target_id):
		(_extra_enemy_views[target_id] as BattleSupportEnemyView).set_precision(int(event.get("dodge_after", 0)), int(event.get("accuracy_after", 0)))
		return
	var dodge_label: Label = _hero_dodge_value if target_id == "hero" else _enemy_dodge_value
	var accuracy_label: Label = _hero_accuracy_value if target_id == "hero" else _enemy_accuracy_value
	dodge_label.text = "%d%%" % int(event.get("dodge_after", 0))
	accuracy_label.text = "%d%%" % (BattleParticipant.PERCENT_SCALE + int(event.get("accuracy_after", 0)))


func _refresh_accuracy_and_dodge() -> void:
	if _combat == null:
		return
	var hero: BattleParticipant = _combat.battle_state.get_hero()
	var enemy: BattleParticipant = _combat.battle_state.get_enemy()
	if hero == null or enemy == null:
		return
	_hero_strength_value.text = "%d" % hero.effective_strength()
	_enemy_strength_value.text = "%d" % enemy.effective_strength()
	_hero_agility_value.text = "%d" % hero.effective_agility()
	_enemy_agility_value.text = "%d" % enemy.effective_agility()
	_hero_dodge_value.text = "%d%%" % hero.dodge_percent()
	_hero_accuracy_value.text = "%d%%" % (BattleParticipant.PERCENT_SCALE + hero.accuracy_percent())
	_enemy_dodge_value.text = "%d%%" % enemy.dodge_percent()
	_enemy_accuracy_value.text = "%d%%" % (BattleParticipant.PERCENT_SCALE + enemy.accuracy_percent())
	_set_block_display("hero", hero.block_armor)
	_set_block_display("enemy", enemy.block_armor)
	for hero_id in _extra_hero_views:
		var view: BattleSupportEnemyView = _extra_hero_views[hero_id] as BattleSupportEnemyView
		if view.visible:
			view.refresh_stats(_combat.battle_state.get_participant(hero_id))
	for actor_id in _extra_enemy_views:
		(_extra_enemy_views[actor_id] as BattleSupportEnemyView).refresh_stats(_combat.battle_state.get_participant(actor_id))
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
		var selected: bool = index == _selected_manual_slot
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


func _open_hero_profile(actor_id: String) -> void:
	if _combat == null or not _combat.battle_state.hero_ids().has(actor_id):
		return
	var source: HeroState = _combat.hero_sources.get(actor_id) as HeroState
	var actor: BattleParticipant = _combat.battle_state.get_participant(actor_id)
	if source == null or actor == null:
		return
	_hero_profile.open_for(source, actor, true)
	_hero_profile.move_to_front()


func _on_inspection_long_press() -> void:
	if _inspection_touch_index < 0 or _inspection_actor_id.is_empty():
		return
	_inspection_triggered = true
	_open_hero_profile(_inspection_actor_id)


func _clear_inspection_touch() -> void:
	_inspection_timer.stop()
	_inspection_touch_index = -1
	_inspection_actor_id = ""
	_inspection_touch_position = Vector2.ZERO
	_inspection_triggered = false


func _on_target_portrait_input(event: InputEvent, actor_id: String) -> void:
	if _combat == null:
		return
	var pressed: bool = false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT and actor_id in _combat.battle_state.hero_ids():
			_open_hero_profile(actor_id)
			get_viewport().set_input_as_handled()
			return
		pressed = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _inspection_touch_index and drag.position.distance_to(_inspection_touch_position) > LONG_PRESS_MOVE_TOLERANCE:
			_clear_inspection_touch()
		return
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if actor_id in _combat.battle_state.hero_ids():
			if touch.pressed:
				_clear_inspection_touch()
				_inspection_touch_index = touch.index
				_inspection_actor_id = actor_id
				_inspection_touch_position = touch.position
				_inspection_timer.start()
				return
			if touch.index != _inspection_touch_index or actor_id != _inspection_actor_id:
				return
			var was_long_press: bool = _inspection_triggered
			_clear_inspection_touch()
			if was_long_press:
				get_viewport().set_input_as_handled()
				return
			pressed = true
		else:
			pressed = touch.pressed
	else:
		return
	if _round_mode:
		if not pressed or _is_playing_back:
			return
		var current_id: String = _round_next_actor()
		if current_id not in _combat.battle_state.hero_ids():
			return
		var ability: AbilityDefinition = _selected_round_ability()
		if ability != null and _combat.battle_state.create_context().target_ids(current_id, ability).has(actor_id):
			get_viewport().set_input_as_handled()
			_execute_round_turn(actor_id, _selected_round_ability_id)
			return
		if _selected_round_ability_id.is_empty() and actor_id in _combat.battle_state.hero_ids():
			_select_hero_view(actor_id)
		return
	if not pressed or not _manual_started or _selected_manual_slot < 0 or _is_playing_back:
		return
	var ability: AbilityDefinition = AbilityCatalog.get_ability(_hero_chain[_selected_manual_slot])
	if not _combat.battle_state.create_context().target_ids("hero", ability).has(actor_id):
		return
	get_viewport().set_input_as_handled()
	_play_selected_manual_action(actor_id)


func _refresh_target_outlines() -> void:
	var valid_targets: Array[String] = []
	if _round_mode and not _is_playing_back:
		var actor_id: String = _round_next_actor()
		if actor_id in _combat.battle_state.hero_ids():
			var ability: AbilityDefinition = _selected_round_ability()
			if ability != null:
				valid_targets = _combat.battle_state.create_context().target_ids(actor_id, ability)
		for target_id in _target_outlines:
			var panel: Panel = _target_outlines[target_id]
			panel.visible = valid_targets.has(str(target_id))
			(panel.get_parent() as TextureRect).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if panel.visible else Control.CURSOR_ARROW
		return
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
	_set_turn_highlight("")
	_show_turn_frame("")
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
