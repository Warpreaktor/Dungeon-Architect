class_name HeroSelection
extends VBoxContainer

signal character_chosen(hero_id: String)
signal back_requested

@onready var _volcha_button: Button = %VolchaButton
@onready var _petushan_button: Button = %PetushanButton

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
    %BackButton.pressed.connect(func() -> void: back_requested.emit())

func _configure_card(button: Button, hero_id: String) -> void:
    var hero: HeroDefinition = HeroCatalog.get_hero(hero_id)
    var portrait: TextureRect = button.get_node("CardContent/Portrait") as TextureRect
    var name_label: Label = button.get_node("CardContent/Name") as Label
    var stats_label: Label = button.get_node("CardContent/Stats") as Label
    portrait.texture = hero.portrait
    name_label.text = hero.display_name
    stats_label.text = "%d HP   ·   СИЛ %d   ·   ЛОВ %d" % [hero.max_health, hero.strength, hero.agility]
    button.pressed.connect(func() -> void: character_chosen.emit(hero.hero_id))

func focus_first() -> void:
    _volcha_button.grab_focus()
