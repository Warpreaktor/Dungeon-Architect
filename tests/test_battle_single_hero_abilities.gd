extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle: Control = load("res://scenes/battle_view.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame
	var scroll: ScrollContainer = battle.get_node("OuterMargin/Main/BottomPanel/ActionsMargin/ActionsColumn/SequenceSides/SequenceScroll")
	var hero_slots: HBoxContainer = battle.get_node("OuterMargin/Main/BottomPanel/ActionsMargin/ActionsColumn/SequenceSides/SequenceScroll/SequenceSlots")
	var enemy_scroll: ScrollContainer = battle.get_node("OuterMargin/Main/BottomPanel/ActionsMargin/ActionsColumn/SequenceSides/EnemySequenceScroll")
	var enemy_title: Label = battle.get_node("OuterMargin/Main/BottomPanel/ActionsMargin/ActionsColumn/SequenceHeader/EnemyChainTitle")
	var hero_title: Label = battle.get_node("OuterMargin/Main/BottomPanel/ActionsMargin/ActionsColumn/SequenceHeader/HeroChainTitle")
	assert(not enemy_scroll.visible)
	assert(not enemy_title.visible)
	assert(scroll.visible)
	assert((scroll.size_flags_horizontal & Control.SIZE_EXPAND) != 0)
	assert((hero_slots.size_flags_horizontal & Control.SIZE_EXPAND) != 0)
	assert(hero_slots.alignment == BoxContainer.ALIGNMENT_CENTER)
	assert(hero_title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	battle.queue_free()
	print("Battle HUD: one centered hero sequence without enemy cards OK")
	quit()
