class_name HealthMeter
extends HBoxContainer

## Общий индикатор здоровья для исследования и боя.
## Сцена управляет только отображением, значения хранит HeroState/CombatSession.

@onready var _bar: TextureProgressBar = %HealthBar
@onready var _value: Label = %HealthValue

var _value_tween: Tween


func set_heart_visible(value: bool) -> void:
	$HeartIcon.visible = value


func set_health(current: int, maximum: int, animated: bool = false) -> void:
	var max_hp: int = maxi(maximum, 1)
	var hp: int = clampi(current, 0, max_hp)
	if _value_tween != null and _value_tween.is_valid():
		_value_tween.kill()
	_bar.max_value = max_hp
	_value.text = "%d / %d" % [hp, max_hp]
	if animated:
		_value_tween = create_tween()
		_value_tween.tween_property(_bar, "value", float(hp), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_bar.value = hp
