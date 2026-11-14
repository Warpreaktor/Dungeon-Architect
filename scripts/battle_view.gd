class_name BattleView
extends Control

## Боевой экран показывает CombatSession, но не управляет исходной картой.
## Позже портреты заменим анимированными персонажами внутри этой сцены.
signal battle_won
signal battle_lost

@onready var _hero_health: Label = %HeroHealth
@onready var _hero_portrait: TextureRect = %HeroPortrait
@onready var _enemy_health: Label = %EnemyHealth
@onready var _enemy_name: Label = %EnemyName
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
	_hero_attack_damage = hero.attack
	_attack_name = "Удар мечом" if hero.equipped_weapon_id == "sword" else "Удар кулаком"
	_punch_button.text = "%s  ·  %d" % [_attack_name, _hero_attack_damage]
	_punch_button.icon = ItemCatalog.get_item("sword").icon if hero.equipped_weapon_id == "sword" else null
	_enemy_name.text = combat.enemy_definition.display_name
	_enemy_portrait.texture = combat.enemy_definition.icon
	_enemy_portrait.modulate.a = 1.0
	_update_health()
	_punch_button.disabled = false
	_punch_button.grab_focus()


func _update_health() -> void:
	_enemy_health.text = "%d / %d HP" % [_combat.enemy_health, _combat.enemy_max_health]
	if _combat.hero != null:
		_hero_health.text = "%d / %d HP" % [_combat.hero.health, _combat.hero.max_health]


func _on_punch_pressed() -> void:
	if _combat == null or _combat.is_victory or _combat.is_defeat or _punch_button.disabled:
		return
	_punch_button.disabled = true
	var damage: int = _combat.hero_attack(_hero_attack_damage)
	_update_health()
	_result_text.text = "%s: %d урона" % [_attack_name, damage]
	var impact := create_tween()
	impact.tween_property(_enemy_portrait, "scale", Vector2(0.92, 0.92), 0.09)
	impact.tween_property(_enemy_portrait, "scale", Vector2.ONE, 0.09)
	if _combat.is_victory:
		impact.tween_property(_enemy_portrait, "modulate:a", 0.0, 0.24)
		impact.tween_callback(_show_victory)
	else:
		# Атака противника уже рассчитана моделью; UI лишь показывает результат.
		impact.tween_callback(_show_enemy_reply)


func _show_enemy_reply() -> void:
	if _combat.last_counter_damage == 0:
		_result_text.text = "%s: удар заблокирован (%d)" % [_enemy_name.text, _combat.last_blocked_damage]
	else:
		_result_text.text = "%s: −%d HP" % [_enemy_name.text, _combat.last_counter_damage]
		if _combat.last_blocked_damage > 0:
			_result_text.text += "  ·  блок: %d" % _combat.last_blocked_damage
	var recoil := create_tween()
	recoil.tween_property(_hero_portrait, "modulate", Color(1.0, 0.55, 0.55), 0.15)
	recoil.tween_property(_hero_portrait, "modulate", Color.WHITE, 0.18)
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
	var ending := create_tween()
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
