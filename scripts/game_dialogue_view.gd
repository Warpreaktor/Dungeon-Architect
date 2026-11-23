class_name GameDialogueView
extends CanvasLayer

## Одна игровая сцена для авторских реплик и наград из сундуков.
## Не изменяет состояние героя, карту или содержимое сундука.
signal closed

@onready var _card: PanelContainer = %Card
@onready var _eyebrow: Label = %Eyebrow
@onready var _icon_holder: CenterContainer = %EventIconHolder
@onready var _icon: TextureRect = %EventIcon
@onready var _text: RichTextLabel = %MessageText
@onready var _loot_section: VBoxContainer = %LootSection
@onready var _loot_scroll: ScrollContainer = %LootScroll
@onready var _loot_rows: VBoxContainer = %LootRows
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(dismiss_by_player)
	get_viewport().size_changed.connect(_resize_card)
	_resize_card()
	hide()


func show_dialog(message: String) -> void:
	show_event({"text": message})


func show_event(event: Dictionary) -> void:
	var story := str(event.get("text", "")).strip_edges()
	_text.text = story
	_text.visible = not story.is_empty()
	_eyebrow.text = "ПОСЛАНИЕ" if not story.is_empty() else "СОКРОВИЩА"
	var event_icon: Texture2D = _resolve_event_icon(event)
	_icon.texture = event_icon
	_icon_holder.visible = event_icon != null
	for child in _loot_rows.get_children():
		_loot_rows.remove_child(child)
		child.queue_free()
	var loot: Array = event.get("loot", [])
	for entry in loot:
		if not (entry is Dictionary):
			continue
		var item_id := str(entry.get("item_id", ""))
		var item := ItemCatalog.get_item(item_id)
		if item == null:
			continue
		var quantity := maxi(int(entry.get("quantity", 1)), 1)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var caption := Label.new()
		caption.text = "%d монет" % quantity if item_id == "gold" else "%s ×%d" % [item.display_name, quantity]
		caption.add_theme_color_override("font_color", Color(0.94, 0.91, 0.83))
		caption.add_theme_font_size_override("font_size", 18)
		row.add_child(caption)
		_loot_rows.add_child(row)
	_loot_section.visible = _loot_rows.get_child_count() > 0
	_loot_scroll.custom_minimum_size.y = minf(186.0, float(_loot_rows.get_child_count()) * 40.0)
	if not _text.visible and not _loot_section.visible:
		return
	_resize_card()
	show()
	if _text.visible:
		_text.scroll_to_line(0)
	_continue_button.grab_focus()



func _resolve_event_icon(event: Dictionary) -> Texture2D:
	var explicit_icon: Variant = event.get("icon", null)
	if explicit_icon is Texture2D:
		return explicit_icon as Texture2D
	var icon_type: String = str(event.get("icon_type", ""))
	var icon_id: String = str(event.get("icon_id", ""))
	match icon_type:
		"trap":
			if TrapCatalog.has(icon_id):
				return TrapCatalog.get_trap(icon_id).icon
		"item":
			var item := ItemCatalog.get_item(icon_id)
			return item.icon if item != null else null
	return null

func _resize_card() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_card.custom_minimum_size.x = minf(620.0, maxf(260.0, viewport_size.x - 32.0))
	# Если авторский текст и добыча показаны одновременно, оба блока остаются
	# внутри игрового окна на невысоком экране планшета.
	_text.custom_minimum_size.y = minf(168.0, maxf(75.0, viewport_size.y * 0.24))
	if _loot_section.visible:
		var ideal_height := minf(186.0, float(_loot_rows.get_child_count()) * 40.0)
		_loot_scroll.custom_minimum_size.y = minf(ideal_height, maxf(60.0, viewport_size.y * 0.22))


func dismiss_by_player() -> void:
	hide()
	closed.emit()


func dismiss() -> void:
	hide()
