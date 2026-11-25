class_name HeroSelection
extends VBoxContainer

signal party_chosen(hero_ids: Array[String])
signal back_requested

@onready var _volcha_button: Button = %VolchaButton
@onready var _petushan_button: Button = %PetushanButton
@onready var _count_label: Label = %PartyCount
@onready var _start_button: Button = %StartPartyButton

var _selected_ids: Array[String] = []
var _hero_buttons: Dictionary = {}


func _ready() -> void:
	_configure_card(_volcha_button, "volcha")
	_configure_card(_petushan_button, "petushan")
	for hero_id in HeroCatalog.list_ids():
		if hero_id in ["volcha", "petushan"]:
			continue
		var button: Button = _volcha_button.duplicate(0) as Button
		button.name = "%sButton" % hero_id.capitalize()
		button.unique_name_in_owner = false
		$Scroll/Cards.add_child(button)
		_configure_card(button, hero_id)
	_start_button.pressed.connect(_confirm_party)
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	_refresh_selection()


func _configure_card(button: Button, hero_id: String) -> void:
	var hero: HeroDefinition = HeroCatalog.get_hero(hero_id)
	var portrait: TextureRect = button.get_node("CardContent/Portrait") as TextureRect
	var name_label: Label = button.get_node("CardContent/Name") as Label
	var stats_label: Label = button.get_node("CardContent/Stats") as Label
	portrait.texture = hero.portrait
	name_label.text = hero.display_name
	stats_label.text = "%d HP · %d ЭН · СИЛ %d · ЛОВ %d" % [hero.max_health, hero.max_energy, hero.strength, hero.agility]
	button.toggle_mode = true
	button.set_pressed_no_signal(false)
	_hero_buttons[hero_id] = button
	button.toggled.connect(func(pressed: bool) -> void: _toggle_hero(hero_id, pressed))


func _toggle_hero(hero_id: String, pressed: bool) -> void:
	if pressed:
		if not _selected_ids.has(hero_id):
			if _selected_ids.size() >= GameSession.MAX_PARTY_SIZE:
				(_hero_buttons[hero_id] as Button).set_pressed_no_signal(false)
				return
			_selected_ids.append(hero_id)
	else:
		_selected_ids.erase(hero_id)
	_refresh_selection()


func _refresh_selection() -> void:
	_count_label.text = "Отряд: %d / %d" % [_selected_ids.size(), GameSession.MAX_PARTY_SIZE]
	_start_button.disabled = _selected_ids.is_empty()
	for hero_id in _hero_buttons:
		var button: Button = _hero_buttons[hero_id] as Button
		button.disabled = _selected_ids.size() >= GameSession.MAX_PARTY_SIZE and not _selected_ids.has(str(hero_id))
		var name_label: Label = button.get_node("CardContent/Name") as Label
		var hero: HeroDefinition = HeroCatalog.get_hero(str(hero_id))
		var index: int = _selected_ids.find(str(hero_id))
		name_label.text = "%d. %s" % [index + 1, hero.display_name] if index >= 0 else hero.display_name


func selected_party() -> Array[String]:
	return _selected_ids.duplicate()


func reset_selection() -> void:
	_selected_ids.clear()
	for button in _hero_buttons.values():
		(button as Button).set_pressed_no_signal(false)
	_refresh_selection()


func _confirm_party() -> void:
	if _selected_ids.is_empty() or _selected_ids.size() > GameSession.MAX_PARTY_SIZE:
		return
	party_chosen.emit(selected_party())


func focus_first() -> void:
	_volcha_button.grab_focus()
