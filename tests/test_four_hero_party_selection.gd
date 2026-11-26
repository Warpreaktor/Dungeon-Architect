extends SceneTree

const PARTY_IDS: Array[String] = ["volcha", "petushan", "burolom", "luma"]


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var picker: HeroSelection = load("res://scenes/hero_selection.tscn").instantiate() as HeroSelection
	root.add_child(picker)
	assert(picker.selected_party().is_empty())
	assert((picker.get_node("%StartPartyButton") as Button).disabled)
	var chosen_parties: Array = []
	picker.party_chosen.connect(func(ids: Array[String]) -> void: chosen_parties.append(ids.duplicate()))
	for hero_id in PARTY_IDS:
		var button: Button = picker._catalog.tiles.get(hero_id) as Button
		assert(button != null)
		button.pressed.emit()
		picker._catalog.hero_add_requested.emit(hero_id)
	assert(picker.selected_party() == PARTY_IDS)
	assert(not (picker.get_node("%StartPartyButton") as Button).disabled)
	assert(picker._party_bar.count.text == "Отряд: 4 / 4")
	picker.get_node("%StartPartyButton").pressed.emit()
	assert(chosen_parties.size() == 1 and chosen_parties[0] == PARTY_IDS)

	var wolf_button: Button = picker._catalog.tiles["volcha"] as Button
	picker._party_bar._remove_buttons[0].pressed.emit()
	assert(picker.selected_party() == ["petushan", "burolom", "luma"])
	wolf_button.pressed.emit()
	picker._catalog.hero_add_requested.emit("volcha")
	assert(picker.selected_party() == ["petushan", "burolom", "luma", "volcha"])
	picker.reset_selection()
	assert(picker.selected_party().is_empty())
	assert((picker.get_node("%StartPartyButton") as Button).disabled)
	picker.queue_free()

	var test_panel := EditorTestHeroPanel.new()
	root.add_child(test_panel)
	test_panel.select_party(PARTY_IDS)
	assert(test_panel.selected_party() == PARTY_IDS)
	assert(test_panel.fourth_selector != null)
	test_panel.select_party(["burolom"])
	assert(test_panel.selected_party() == ["burolom"])
	test_panel.queue_free()

	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	var session: GameSession = GameSession.start_for_party(dungeon, PARTY_IDS)
	assert(session != null and session.party_members().size() == GameSession.MAX_PARTY_SIZE)
	for index in range(PARTY_IDS.size()):
		assert(session.party[index].definition.hero_id == PARTY_IDS[index])
	assert(GameSession.start_for_party(dungeon, []) == null)
	assert(GameSession.start_for_party(dungeon, ["volcha", "petushan", "burolom", "luma", "volcha"]) == null)
	assert(GameSession.start_for_party(dungeon, ["volcha", "volcha"]) == null)

	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {dungeon.map_id: dungeon})
	assert(restored != null and restored.party.size() == PARTY_IDS.size())
	for index in range(PARTY_IDS.size()):
		assert(restored.party[index].definition.hero_id == PARTY_IDS[index])
		assert(restored.party[index].energy == session.party[index].energy)

	var monster: MonsterDefinition = MonsterCatalog.get_monster("skeleton")
	var combat: CombatSession = CombatSession.new(monster, restored.party[0], null, 6074, restored.party_members())
	assert(combat.battle_state.hero_ids().size() == PARTY_IDS.size())
	var view: BattleView = load("res://scenes/battle_view.tscn").instantiate() as BattleView
	root.add_child(view)
	await process_frame
	view.begin(combat, restored.party[0])
	for index in range(2, GameSession.MAX_PARTY_SIZE + 1):
		var actor_id: String = "hero_%d" % index
		assert(view._extra_hero_views.has(actor_id))
		assert((view._extra_hero_views[actor_id] as Control).visible)
	view._create_impact_layer()
	for index in range(2, GameSession.MAX_PARTY_SIZE + 1):
		var actor_id: String = "hero_%d" % index
		assert(view._impact_idle.has(actor_id))
	view._clear_impact_layer()
	for index in range(2, GameSession.MAX_PARTY_SIZE + 1):
		var actor_id: String = "hero_%d" % index
		var portrait: TextureRect = (view._extra_hero_views[actor_id] as BattleSupportEnemyView).portrait_node()
		assert(is_equal_approx(portrait.modulate.a, 1.0))
	view.queue_free()
	await process_frame
	print("Four-hero party selection, editor, save and combat OK")
	quit()
