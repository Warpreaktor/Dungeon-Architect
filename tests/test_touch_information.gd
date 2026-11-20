extends SceneTree


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var overlay := TouchInfoOverlay.new()
	root.add_child(overlay)
	assert(not overlay.is_open())
	overlay.show_text("Название\nОписание, зависящее от состояния")
	assert(overlay.is_open())
	assert(overlay._heading.text == "Название")
	assert(overlay._description.text == "Описание, зависящее от состояния")
	overlay.hide_info()
	assert(not overlay.is_open())

	var ability := AbilityCatalog.get_ability("basic_strike")
	var slot: BattleAbilitySlot = load("res://scenes/battle_ability_slot.tscn").instantiate() as BattleAbilitySlot
	root.add_child(slot)
	slot.configure(0, ability, true)
	var received: Array[String] = []
	slot.info_requested.connect(func(content: String) -> void: received.append(content))
	slot._info_button.pressed.emit()
	assert(received == [slot.tooltip_text])
	slot.configure_hidden(0)
	assert(not slot._info_button.visible)
	assert(slot.tooltip_text.is_empty())
	slot.reveal_enemy_action(ability, null)
	assert(slot._info_button.visible)
	slot._info_button.pressed.emit()
	assert(received.back() == slot.tooltip_text)

	var standard_press: Array[int] = []
	slot.slot_selected.connect(func(index: int) -> void: standard_press.append(index))
	slot._info_button.pressed.emit()
	assert(standard_press.is_empty())

	var status_presenter := BattleStatusPresenter.new(root)
	var status_events: Array[String] = []
	status_presenter.info_requested.connect(func(actor_id: String, status_id: String) -> void:
		status_events.append(actor_id + ":" + status_id))
	var portrait := TextureRect.new()
	portrait.size = Vector2(128, 128)
	root.add_child(portrait)
	status_presenter.setup({"target": portrait})
	var marker: TextureRect = status_presenter._status_markers["target"]["bleeding"]
	assert(marker.mouse_filter == Control.MOUSE_FILTER_STOP)
	status_presenter.set_visible("target", "bleeding", true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	marker.gui_input.emit(click)
	assert(status_events == ["target:bleeding"])

	portrait.queue_free()
	slot.queue_free()
	overlay.queue_free()
	quit()
