class_name GameDialogueView
extends CanvasLayer

## Одна игровая сцена для авторских реплик и наград из сундуков.
## Не изменяет состояние героя, карту или содержимое сундука.
signal closed
signal choice_selected(choice: String, actor_index: int)

@onready var _card: PanelContainer = %Card
@onready var _eyebrow: Label = %Eyebrow
@onready var _icon_holder: CenterContainer = %EventIconHolder
@onready var _icon: TextureRect = %EventIcon
@onready var _text: RichTextLabel = %MessageText
@onready var _loot_section: VBoxContainer = %LootSection
@onready var _loot_scroll: ScrollContainer = %LootScroll
@onready var _loot_rows: VBoxContainer = %LootRows
@onready var _continue_button: Button = %ContinueButton
@onready var _choice_prompt: Label = %ChoicePrompt
@onready var _choices: VBoxContainer = %ChoiceActions
@onready var _actor_portraits: HFlowContainer = %ActorPortraits
@onready var _actor_caption: Label = %ActorCaption
@onready var _disarm_button: Button = %DisarmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _enter_portal_button: Button = %EnterPortalButton
@onready var _decision_row: BoxContainer = %DecisionRow
@onready var _avoid_button: Button = %AvoidButton
@onready var _reaction_actions: VBoxContainer = %ReactionActions
@onready var _reaction_prompt: Label = %ReactionPrompt
@onready var _back_button: Button = %BackButton
@onready var _forward_button: Button = %ForwardButton

const ACTOR_CARD_SIZE := Vector2(88, 108)
const COMPACT_ACTOR_CARD_SIZE := Vector2(72, 92)
const ACTOR_PORTRAIT_SIZE := Vector2(64, 64)
const COMPACT_ACTOR_PORTRAIT_SIZE := Vector2(52, 52)

var _available_choices: Dictionary = {}
var _selected_actor_index: int = 0
var _actor_entries: Array[Dictionary] = []
var _actor_buttons: Array[Button] = []


func _ready() -> void:
	_continue_button.pressed.connect(dismiss_by_player)
	_disarm_button.pressed.connect(_choose.bind("disarm"))
	_cancel_button.pressed.connect(_choose.bind("cancel"))
	_enter_portal_button.pressed.connect(_choose.bind("enter_portal"))
	_avoid_button.pressed.connect(_choose.bind("avoid"))
	_back_button.pressed.connect(_choose.bind("back"))
	_forward_button.pressed.connect(_choose.bind("forward"))
	get_viewport().size_changed.connect(_resize_card)
	_resize_card()
	hide()


func show_dialog(message: String) -> void:
	show_event({"text": message})


func show_event(event: Dictionary) -> void:
	var story := str(event.get("text", "")).strip_edges()
	var result_text: String = str(event.get("result_text", "")).strip_edges()
	if not result_text.is_empty():
		story = result_text if story.is_empty() else "%s\n\n%s" % [result_text, story]
	var choices: Dictionary = event.get("choices", {})
	_available_choices = choices.duplicate()
	for disabled_choice in event.get("disabled_choices", []):
		_available_choices.erase(disabled_choice)
	_reaction_actions.visible = choices.has("back") or choices.has("forward")
	_reaction_prompt.text = str(event.get("prompt", ""))
	_back_button.visible = choices.has("back")
	_back_button.text = str(choices.get("back", ""))
	_back_button.disabled = not _available_choices.has("back")
	_forward_button.visible = choices.has("forward")
	_forward_button.text = str(choices.get("forward", ""))
	_forward_button.disabled = not _available_choices.has("forward")
	_choices.visible = not choices.is_empty()
	(_continue_button.get_parent() as Control).visible = choices.is_empty()
	if _choices.visible:
		_selected_actor_index = maxi(int(event.get("selected_actor", 0)), 0)
		_enter_portal_button.visible = choices.has("enter_portal")
		_enter_portal_button.text = str(choices.get("enter_portal", ""))
		_disarm_button.visible = choices.has("disarm")
		_cancel_button.visible = choices.has("cancel")
		_avoid_button.visible = choices.has("avoid")
		_disarm_button.text = _label_for_choice("disarm", choices)
		_cancel_button.text = _label_for_choice("cancel", choices)
		_avoid_button.text = str(choices.get("avoid", ""))
		_rebuild_actor_choices(event.get("actors", []), bool(event.get("select_actor", true)))
	else:
		_clear_actor_choices()
	_text.text = story
	_text.visible = not story.is_empty()
	_eyebrow.text = "ЛОВУШКА" if str(event.get("icon_type", "")) == "trap" else ("ПОСЛАНИЕ" if not story.is_empty() else "СОКРОВИЩА")
	_eyebrow.text = str(event.get("title", _eyebrow.text))
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
	if _reaction_actions.visible:
		_back_button.grab_focus()
	elif _choices.visible:
		_cancel_button.grab_focus()
	else:
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
		"portal":
			return ImageAsset.texture("res://assets/icons/portals/portal_%s.png" % icon_id)
		"item":
			var item := ItemCatalog.get_item(icon_id)
			return item.icon if item != null else null
	return null

func _resize_card() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var compact: bool = _choices.visible and viewport_size.y < 450.0
	var narrow: bool = viewport_size.x < 560.0
	_decision_row.vertical = _available_choices.has("enter_portal") and narrow
	var content: VBoxContainer = _choices.get_parent() as VBoxContainer
	var margins: MarginContainer = content.get_parent() as MarginContainer
	content.add_theme_constant_override("separation", 8 if compact else 16)
	margins.add_theme_constant_override("margin_top", 12 if compact else 23)
	margins.add_theme_constant_override("margin_bottom", 12 if compact else 23)
	_icon.custom_minimum_size = Vector2(32, 32) if compact else Vector2(48, 48)
	_card.custom_minimum_size.x = minf(680.0, maxf(280.0, viewport_size.x - 32.0))
	# Если авторский текст и добыча показаны одновременно, оба блока остаются
	# внутри игрового окна на невысоком экране планшета.
	_text.custom_minimum_size.y = minf(72.0, maxf(44.0, viewport_size.y * 0.12)) if _choices.visible else minf(168.0, maxf(75.0, viewport_size.y * 0.24))
	if _reaction_actions.visible:
		_text.custom_minimum_size.y = minf(152.0, maxf(80.0, viewport_size.y * 0.24))
	if _loot_section.visible:
		var ideal_height := minf(186.0, float(_loot_rows.get_child_count()) * 40.0)
		_loot_scroll.custom_minimum_size.y = minf(ideal_height, maxf(60.0, viewport_size.y * 0.22))
	if _choice_prompt != null:
		_choice_prompt.visible = _actor_entries.size() > 0 and (_actor_buttons.size() > 1 or _disarm_button.visible)
	if _actor_caption != null:
		_actor_caption.visible = _actor_entries.size() > 0
	var size: Vector2 = COMPACT_ACTOR_CARD_SIZE if compact or narrow else ACTOR_CARD_SIZE
	var portrait_size: Vector2 = COMPACT_ACTOR_PORTRAIT_SIZE if compact or narrow else ACTOR_PORTRAIT_SIZE
	_refresh_actor_choice_sizes(size, portrait_size)


func has_choices() -> bool:
	return visible and _choices.visible


func _choose(choice: String) -> void:
	if not has_choices() or not _available_choices.has(choice):
		return
	hide()
	choice_selected.emit(choice, _selected_actor_index)


func _label_for_choice(choice: String, choices: Dictionary) -> String:
	var text: String = str(choices.get(choice, ""))
	if choice == "disarm" and text == "Да":
		return "Обезвредить"
	if choice == "cancel" and text == "Нет":
		return "Отмена"
	return text


func _rebuild_actor_choices(raw_actors: Array, allow_selection: bool) -> void:
	_clear_actor_choices()
	if not allow_selection:
		return
	for raw_actor in raw_actors:
		_actor_entries.append(_normalize_actor_entry(raw_actor))
	if _actor_entries.is_empty():
		_choice_prompt.visible = false
		_actor_portraits.visible = false
		_actor_caption.visible = false
		return
	_selected_actor_index = clampi(_selected_actor_index, 0, _actor_entries.size() - 1)
	_choice_prompt.text = "Кто обезвреживает ловушку?" if _disarm_button.visible else "Кто идёт первым?"
	_choice_prompt.visible = true
	_actor_portraits.visible = true
	_actor_caption.visible = true
	for index in _actor_entries.size():
		var actor: Dictionary = _actor_entries[index]
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = ACTOR_CARD_SIZE
		button.disabled = not allow_selection
		button.tooltip_text = _actor_tooltip(actor)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if allow_selection else Control.CURSOR_ARROW
		button.pressed.connect(_select_actor.bind(index))
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		button.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 4)
		margin.add_child(box)
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.texture = actor.get("portrait", null) as Texture2D
		portrait.custom_minimum_size = ACTOR_PORTRAIT_SIZE
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(portrait)
		var hp := Label.new()
		hp.name = "HP"
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp.text = str(actor.get("summary", ""))
		hp.add_theme_font_size_override("font_size", 13)
		hp.add_theme_color_override("font_color", Color(0.82, 0.87, 0.92, 0.9))
		hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(hp)
		_actor_portraits.add_child(button)
		_actor_buttons.append(button)
	_update_actor_selection()


func _clear_actor_choices() -> void:
	_choice_prompt.hide()
	_actor_portraits.hide()
	_actor_caption.hide()
	_actor_entries.clear()
	_actor_buttons.clear()
	for child in _actor_portraits.get_children():
		_actor_portraits.remove_child(child)
		child.queue_free()


func _normalize_actor_entry(raw_actor: Variant) -> Dictionary:
	if raw_actor is Dictionary:
		var actor: Dictionary = raw_actor.duplicate(true)
		actor["name"] = str(actor.get("name", "Герой"))
		return actor
	return {"name": str(raw_actor), "summary": ""}


func _actor_tooltip(actor: Dictionary) -> String:
	var name: String = str(actor.get("name", "Герой"))
	var summary: String = str(actor.get("summary", ""))
	return name if summary.is_empty() else "%s\n%s" % [name, summary]


func _select_actor(index: int) -> void:
	if index < 0 or index >= _actor_entries.size():
		return
	_selected_actor_index = index
	_update_actor_selection()


func _update_actor_selection() -> void:
	for index in _actor_buttons.size():
		_apply_actor_button_style(_actor_buttons[index], index == _selected_actor_index)
	if _selected_actor_index >= 0 and _selected_actor_index < _actor_entries.size():
		_actor_caption.text = str(_actor_entries[_selected_actor_index].get("name", ""))


func _apply_actor_button_style(button: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.18, 0.23, 0.96) if selected else Color(0.09, 0.12, 0.16, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.95, 0.77, 0.45, 1.0) if selected else Color(0.39, 0.47, 0.56, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.modulate = Color(1.0, 1.0, 1.0, 1.0) if selected else Color(0.94, 0.94, 0.94, 0.92)


func _refresh_actor_choice_sizes(button_size: Vector2, portrait_size: Vector2) -> void:
	for button in _actor_buttons:
		button.custom_minimum_size = button_size
		var portrait: TextureRect = button.find_child("Portrait", true, false) as TextureRect
		if portrait != null:
			portrait.custom_minimum_size = portrait_size


func dismiss_by_player() -> void:
	if has_choices():
		_choose("cancel")
		return
	if not visible:
		return
	hide()
	closed.emit()


func dismiss() -> void:
	hide()
