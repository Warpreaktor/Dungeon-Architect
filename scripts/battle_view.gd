class_name BattleView
extends Control

## Отдельная игровая сцена сражения. UI не меняет карту и персонажа.
## Портреты пока статические; позже их можно заменить анимированными актёрами.

signal battle_won

@onready var _hero_health: Label = %HeroHealth
@onready var _enemy_health: Label = %EnemyHealth
@onready var _enemy_portrait: TextureRect = %EnemyPortrait
@onready var _punch_button: Button = %PunchButton
@onready var _result_text: Label = %ResultText

var _combat: CombatSession
var _hero_attack_damage: int = CombatSession.PUNCH_DAMAGE
var _attack_name: String = "Удар кулаком"


func _ready() -> void:
	_punch_button.pressed.connect(_on_punch_pressed)
	_punch_button.disabled = true
	_result_text.text = "Твой ход"
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.24)


func begin(combat: CombatSession, hero: HeroState) -> void:
	_combat = combat
	_hero_health.text = "%d / %d HP" % [hero.health, hero.max_health]
	_hero_attack_damage = hero.attack
	_attack_name = "Удар мечом" if hero.equipped_weapon_id == "sword" else "Удар кулаком"
	_punch_button.text = "%s  ·  %d" % [_attack_name, _hero_attack_damage]
	_punch_button.icon = ItemCatalog.get_item("sword").icon if hero.equipped_weapon_id == "sword" else null
	_update_enemy()
	_punch_button.disabled = false
	_punch_button.grab_focus()


func _update_enemy() -> void:
	_enemy_health.text = "%d / %d HP" % [_combat.enemy_health, CombatSession.ENEMY_MAX_HEALTH]


func _on_punch_pressed() -> void:
	if _combat == null or _combat.is_victory:
		return
	_punch_button.disabled = true
	var damage: int = _combat.hero_attack(_hero_attack_damage)
	_update_enemy()
	_result_text.text = "%s: %d урона" % [_attack_name, damage]
	# Короткий визуальный отклик: удар и исчезновение поверженного врага.
	var impact := create_tween()
	impact.tween_property(_enemy_portrait, "scale", Vector2(0.92, 0.92), 0.09)
	impact.tween_property(_enemy_portrait, "scale", Vector2.ONE, 0.09)
	if _combat.is_victory:
		impact.tween_property(_enemy_portrait, "modulate:a", 0.0, 0.24)
		impact.tween_callback(_show_victory)
	else:
		impact.tween_callback(_restore_controls)


func _restore_controls() -> void:
	_punch_button.disabled = false
	_punch_button.grab_focus()


func _show_victory() -> void:
	_result_text.text = "ПОБЕДА!"
	var ending := create_tween()
	ending.tween_interval(0.6)
	ending.tween_property(self, "modulate:a", 0.0, 0.25)
	ending.tween_callback(_emit_victory)


func _emit_victory() -> void:
	battle_won.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_on_punch_pressed()
		get_viewport().set_input_as_handled()
