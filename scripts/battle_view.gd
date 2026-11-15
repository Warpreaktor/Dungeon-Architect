class_name BattleView
extends Control

## Боевая сцена использует ту же шкалу здоровья, что и экран исследования.
## Сведения о здоровье, атаке и блоке берутся из CombatSession/HeroState.
signal battle_won
signal battle_lost

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
@onready var _result_text: Label = %ResultText

var _combat: CombatSession
var _hero_attack_damage: int = CombatSession.PUNCH_DAMAGE
var _attack_name: String = "Удар кулаком"
var _defense_idle_color: Color = Color.WHITE
var _default_attack_icon: Texture2D


func _ready() -> void:
	_punch_button.pressed.connect(_on_punch_pressed)
	_punch_button.disabled = true
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
	_attack_name = "Удар мечом" if not hero.equipped_weapon_id.is_empty() else "Удар кулаком"
	var weapon: ItemDefinition = ItemCatalog.get_item(hero.equipped_weapon_id)
	var weapon_icon: Texture2D = weapon.icon if weapon != null else _default_attack_icon
	_punch_button.text = "%s  ·  %d" % [_attack_name, _hero_attack_damage]
	_punch_button.icon = weapon.icon if weapon != null else null
	_hero_attack_icon.texture = weapon_icon
	_hero_attack_value.text = str(hero.attack)
	_hero_defense_value.text = str(hero.defense)
	_defense_idle_color = Color.WHITE if hero.defense > 0 else Color(0.55, 0.60, 0.67, 0.65)
	_hero_defense_icon.modulate = _defense_idle_color
	_enemy_name.text = combat.enemy_definition.display_name
	_enemy_attack_value.text = str(combat.enemy_damage)
	_enemy_defense_value.text = str(combat.enemy_defense)
	_enemy_defense_icon.modulate = Color.WHITE if combat.enemy_defense > 0 else Color(0.55, 0.60, 0.67, 0.65)
	_enemy_portrait.texture = combat.enemy_definition.icon
	_enemy_portrait.modulate = Color.WHITE
	_hero_health_meter.set_health(hero.health, hero.max_health)
	_enemy_health_meter.set_health(combat.enemy_health, combat.enemy_max_health)
	_punch_button.disabled = false
	_punch_button.grab_focus()


func _on_punch_pressed() -> void:
	if _combat == null or _combat.is_victory or _combat.is_defeat or _punch_button.disabled:
		return
	_punch_button.disabled = true
	var damage: int = _combat.hero_attack(_hero_attack_damage)
	_enemy_health_meter.set_health(_combat.enemy_health, _combat.enemy_max_health, true)
	_result_text.text = "%s: %d урона" % [_attack_name, damage]
	var impact: Tween = create_tween()
	impact.tween_property(_enemy_portrait, "modulate", Color(1.0, 0.53, 0.53), 0.12)
	impact.parallel().tween_property(_enemy_portrait, "scale", Vector2(0.93, 0.93), 0.12)
	impact.tween_property(_enemy_portrait, "modulate", Color.WHITE, 0.15)
	impact.parallel().tween_property(_enemy_portrait, "scale", Vector2.ONE, 0.15)
	if _combat.is_victory:
		impact.tween_property(_enemy_portrait, "modulate:a", 0.0, 0.24)
		impact.tween_callback(_show_victory)
	else:
		impact.tween_callback(_show_enemy_reply)


func _show_enemy_reply() -> void:
	# Урон уже посчитан моделью; обновляем UI в момент ответного удара.
	_hero_health_meter.set_health(_combat.hero.health, _combat.hero.max_health, true)
	var taken: int = _combat.last_counter_damage
	var blocked: int = _combat.last_blocked_damage
	if taken == 0 and blocked > 0:
		_result_text.text = "Щит поглотил %d урона" % blocked
	else:
		_result_text.text = "%s: −%d HP" % [_enemy_name.text, taken]
		if blocked > 0:
			_result_text.text += "  ·  блок: %d" % blocked

	if blocked > 0:
		var shield_flash: Tween = create_tween()
		shield_flash.tween_property(_hero_defense_icon, "modulate", Color(0.35, 0.85, 1.0), 0.15)
		shield_flash.tween_property(_hero_defense_icon, "modulate", _defense_idle_color, 0.22)

	var recoil: Tween = create_tween()
	if taken > 0:
		recoil.tween_property(_hero_portrait, "modulate", Color(1.0, 0.53, 0.53), 0.15)
	elif blocked > 0:
		recoil.tween_property(_hero_portrait, "modulate", Color(0.65, 0.84, 1.0), 0.15)
	else:
		recoil.tween_interval(0.15)
	if taken > 0 or blocked > 0:
		recoil.tween_property(_hero_portrait, "modulate", Color.WHITE, 0.22)
	if _combat.is_defeat:
		recoil.tween_callback(_show_defeat)
	else:
		recoil.tween_callback(_restore_controls)


func _restore_controls() -> void:
	_result_text.text += "   ·   Твой ход"
	_punch_button.disabled = false
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
