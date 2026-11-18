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

var _combat: CombatSession
var _hero_attack_damage: int = CombatSession.PUNCH_DAMAGE
var _attack_name: String = "Удар кулаком"
var _defense_idle_color: Color = Color.WHITE
var _default_attack_icon: Texture2D
var _hero_chain: Array[String] = []
var _enemy_chain: Array[String] = []
var _playback: Tween


func _ready() -> void:
	_punch_button.pressed.connect(_on_punch_pressed)
	_guard_button.pressed.connect(_on_guard_pressed)
	_guard_button.icon = _hero_defense_icon.texture
	_punch_button.disabled = true
	_guard_button.disabled = true
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
	_punch_button.icon = weapon.icon if weapon != null else null
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
	_hero_chain = _combat.battle_state.default_chain("hero")
	_enemy_chain = _combat.battle_state.default_chain("enemy")
	_punch_button.text = "Начать фазу"
	_guard_button.text = "Поменять порядок"
	_result_text.text = "Твоя цепочка: " + _chain_caption()
	_punch_button.disabled = _hero_chain.is_empty() or _enemy_chain.is_empty()
	_guard_button.disabled = _hero_chain.size() < 2
	_punch_button.grab_focus()


func _chain_caption() -> String:
	var names: Array[String] = []
	for action_id in _hero_chain:
		var definition: AbilityDefinition = AbilityCatalog.get_ability(action_id)
		names.append(definition.display_name if definition != null else action_id)
	return " → ".join(names)


func _on_punch_pressed() -> void:
	if _combat == null or _punch_button.disabled:
		return
	_punch_button.disabled = true
	_guard_button.disabled = true
	var result: Dictionary = _combat.play_phase(_hero_chain, _enemy_chain)
	if not bool(result.get("success", false)):
		_result_text.text = str(result.get("reason", "Фаза недоступна"))
		_refresh_phase_controls()
		return
	_play_phase_events(result.get("events", []))


func _on_guard_pressed() -> void:
	if _combat == null or _guard_button.disabled:
		return
	var flow: BattleFlow = _combat.battle_state.flow
	if flow.stage == BattleFlow.Stage.PREPARATION:
		_hero_chain.reverse()
	elif flow.stage == BattleFlow.Stage.BETWEEN_PHASES:
		if not _combat.request_tactic_change():
			return
		_hero_chain.reverse()
		_combat.confirm_tactic_change()
	else:
		return
	_result_text.text = "Новая тактика: " + _chain_caption()
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
		_result_text.text = "Фаза %d завершена. %s" % [_combat.battle_state.flow.phase_number, _chain_caption()]
		_refresh_phase_controls()


func _refresh_phase_controls() -> void:
	if _combat == null:
		return
	var flow: BattleFlow = _combat.battle_state.flow
	var allowed: bool = flow.stage == BattleFlow.Stage.PREPARATION or flow.stage == BattleFlow.Stage.BETWEEN_PHASES
	_punch_button.disabled = not allowed
	_punch_button.text = "Начать фазу" if flow.stage == BattleFlow.Stage.PREPARATION else "Следующая фаза"
	_guard_button.disabled = not (flow.stage == BattleFlow.Stage.PREPARATION or
		(flow.stage == BattleFlow.Stage.BETWEEN_PHASES and flow.reconfiguration_tokens > 0))
	_guard_button.text = "Поменять порядок" if flow.stage == BattleFlow.Stage.PREPARATION else "Изменить тактику"
	if allowed:
		_punch_button.grab_focus()


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
	if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and not _punch_button.disabled:
		_on_punch_pressed()
		get_viewport().set_input_as_handled()
