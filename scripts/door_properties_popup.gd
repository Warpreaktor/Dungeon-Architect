class_name DoorPropertiesPopup
extends PopupPanel

signal lock_changed(door_id: String, lock_id: String)

var _door_id: String = ""
var _selector: OptionButton

func _ready() -> void:
    var margin := MarginContainer.new()
    add_child(margin)
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 12)
    margin.add_child(content)
    var title := Label.new()
    title.text = "Замок двери"
    title.add_theme_font_size_override("font_size", 22)
    content.add_child(title)
    var description := Label.new()
    description.text = "Выбери ключ, который откроет дверь."
    content.add_child(description)
    _selector = OptionButton.new()
    _selector.custom_minimum_size = Vector2(0, 48)
    for lock_id in LockCatalog.LOCK_IDS:
        var item: ItemDefinition = ItemCatalog.get_item(lock_id)
        _selector.add_icon_item(item.icon, LockCatalog.label(lock_id))
        _selector.set_item_metadata(_selector.item_count - 1, lock_id)
    content.add_child(_selector)
    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_END
    content.add_child(actions)
    var cancel := Button.new()
    cancel.text = "Отмена"
    cancel.custom_minimum_size = Vector2(110, 46)
    cancel.pressed.connect(hide)
    actions.add_child(cancel)
    var save := Button.new()
    save.text = "Сохранить"
    save.custom_minimum_size = Vector2(125, 46)
    save.pressed.connect(_save)
    actions.add_child(save)

func configure(door_id: String, lock_id: String) -> void:
    _door_id = door_id
    for index in range(_selector.item_count):
        if str(_selector.get_item_metadata(index)) == LockCatalog.normalize(lock_id):
            _selector.select(index)
            break

func _save() -> void:
    lock_changed.emit(_door_id, str(_selector.get_selected_metadata()))
    hide()
