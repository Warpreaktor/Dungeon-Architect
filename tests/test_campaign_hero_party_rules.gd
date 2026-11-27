extends SceneTree

const REQUIRED_HERO := "volcha"
const OPTIONAL_HERO := "petushan"
const BLOCKED_HERO := "luma"


func _initialize() -> void:
	call_deferred("_verify")


func _map() -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return dungeon


func _metadata(allowed: Array[String], required: Array[String]) -> Dictionary:
	return {HeroPartyRules.METADATA_KEY: {"allowed_ids": allowed, "required_ids": required}}


func _verify() -> void:
	var map_ref: DungeonMap = _map()
	var unrestricted: HeroPartyRules = HeroPartyRules.from_metadata(map_ref.metadata)
	assert(unrestricted.accepts_party([OPTIONAL_HERO]))
	map_ref.metadata.merge(_metadata([REQUIRED_HERO, OPTIONAL_HERO], [REQUIRED_HERO]), true)
	var decoded: DungeonMap = DungeonMap.from_dict(JSON.parse_string(JSON.stringify(map_ref.to_dict())))
	assert(decoded != null)
	var rules: HeroPartyRules = HeroPartyRules.from_metadata(decoded.metadata)
	assert(rules.capacity() == 2)
	assert(rules.accepts_party([REQUIRED_HERO]))
	assert(rules.accepts_party([OPTIONAL_HERO, REQUIRED_HERO]))
	assert(not rules.accepts_party([OPTIONAL_HERO]))
	assert(not rules.accepts_party([REQUIRED_HERO, BLOCKED_HERO]))
	assert(not rules.accepts_party([REQUIRED_HERO, REQUIRED_HERO]))
	assert(HeroPartyRules.from_metadata(_metadata([], [])) == null)
	assert(HeroPartyRules.from_metadata(_metadata([REQUIRED_HERO], [OPTIONAL_HERO])) == null)
	assert(HeroPartyRules.from_metadata(_metadata(["missing_hero"], [])) == null)
	assert(GameSession.start_for_party(decoded, [OPTIONAL_HERO]) == null)
	assert(GameSession.start_for_party(decoded, [REQUIRED_HERO, BLOCKED_HERO]) == null)
	var test_session: GameSession = GameSession.start_for_party(decoded, [OPTIONAL_HERO], false, null, true)
	assert(test_session != null and test_session.is_editor_test)

	var picker: HeroSelection = load("res://scenes/hero_selection.tscn").instantiate() as HeroSelection
	root.add_child(picker)
	await process_frame
	picker.configure_party_rules(rules)
	assert(picker.selected_party() == [REQUIRED_HERO])
	assert(picker._focused_id == REQUIRED_HERO)
	assert(not picker._start_button.disabled)
	assert(picker._party_bar.count.text == "Отряд: 1 / 2")
	assert((picker._catalog.tiles[BLOCKED_HERO] as Button).disabled)
	var blocked_tile: HeroCatalogTile = picker._catalog.tiles[BLOCKED_HERO]
	assert(blocked_tile._lock_overlay.visible and blocked_tile._lock_overlay.get_parent() == blocked_tile.portrait)
	assert(blocked_tile._lock_overlay.anchor_right == 1.0 and blocked_tile._lock_overlay.anchor_bottom == 1.0)
	assert(blocked_tile.modulate == Color.WHITE and blocked_tile._lock_overlay.modulate == Color.WHITE)
	assert(blocked_tile.portrait.self_modulate != Color.WHITE)
	assert(not (picker._catalog.tiles[OPTIONAL_HERO] as Button).disabled)
	picker._add_hero(BLOCKED_HERO, false)
	picker._remove_hero(REQUIRED_HERO)
	picker._move_to_catalog(REQUIRED_HERO)
	assert(picker.selected_party() == [REQUIRED_HERO])
	picker._add_hero(OPTIONAL_HERO, false)
	assert(picker.selected_party() == [REQUIRED_HERO, OPTIONAL_HERO])
	picker.reset_selection()
	assert(picker.selected_party() == [REQUIRED_HERO])

	var official: Dictionary = OfficialCampaignLibrary.load_maps()
	var campaign_map: DungeonMap = official["official_map_varg_01_dead_garrison_treasury"]
	var official_rules: HeroPartyRules = HeroPartyRules.from_metadata(campaign_map.metadata)
	assert(official_rules.capacity() == 1)
	picker.configure_party_rules(official_rules)
	assert(picker.selected_party() == [REQUIRED_HERO])
	assert(picker._party_bar.count.text == "Отряд: 1 / 1")
	for id in HeroCatalog.list_ids():
		if id != REQUIRED_HERO:
			assert((picker._catalog.tiles[id] as Button).disabled)
			picker._add_hero(id, false)
	assert(picker.selected_party() == [REQUIRED_HERO])
	assert(not picker._party_bar._buttons[1].visible)
	assert(not picker._party_bar._buttons[2].visible)
	assert(not picker._party_bar._buttons[3].visible)
	var chosen: Array = []
	picker.party_chosen.connect(func(ids: Array[String]) -> void: chosen.append(ids))
	picker._confirm_party()
	assert(chosen == [[REQUIRED_HERO]])
	picker.configure_party_rules(unrestricted)
	assert(picker.selected_party().is_empty())
	assert(picker._start_button.disabled)
	assert(not (picker._catalog.tiles[BLOCKED_HERO] as Button).disabled)
	assert(not blocked_tile._lock_overlay.visible and blocked_tile.portrait.self_modulate == Color.WHITE)
	assert(picker._party_bar._buttons[3].visible)
	picker.queue_free()

	var panel := EditorPartyRulesPanel.new()
	root.add_child(panel)
	panel.show_rules(campaign_map.metadata)
	assert(panel._selectors[REQUIRED_HERO].get_selected_id() == EditorPartyRulesPanel.Access.REQUIRED)
	assert(panel._selectors[BLOCKED_HERO].get_selected_id() == EditorPartyRulesPanel.Access.BLOCKED)
	var applied: Array = []
	panel.rules_applied.connect(func(metadata: Dictionary) -> void: applied.append(metadata))
	panel._apply()
	assert(applied.size() == 1 and HeroPartyRules.from_metadata(applied[0]).required_ids == [REQUIRED_HERO])
	for selector in panel._selectors.values():
		selector.select(EditorPartyRulesPanel.Access.BLOCKED)
	panel._on_access_changed(0)
	assert(panel._apply_button.disabled)
	panel._apply()
	assert(applied.size() == 1)
	panel.queue_free()

	_test_campaign_restore(decoded)
	await process_frame
	print("Campaign hero rules: editor, selection, session, chapters and saves OK")
	quit()


func _test_campaign_restore(first: DungeonMap) -> void:
	var second: DungeonMap = _map()
	second.metadata.merge(_metadata([BLOCKED_HERO], [BLOCKED_HERO]), true)
	assert(first.place_entity("stairs_down", 3, 2))
	for entity in first.entities_at(3, 2):
		if DungeonMap.is_exit(entity):
			assert(first.set_exit_target(str(entity["id"]), second.map_id))
	var campaign: CampaignDefinition = CampaignDefinition.create("Кампания", first.map_id)
	assert(campaign.add_map(second.map_id))
	var maps: Dictionary = {first.map_id: first, second.map_id: second}
	var campaigns: Dictionary = {campaign.campaign_id: campaign}
	var session: GameSession = GameSession.start_for_party(first, [REQUIRED_HERO])
	assert(session != null and session.set_campaign(campaign))
	assert(not session.add_party_member(BLOCKED_HERO))
	assert(session.move_by(1, 0) and session.is_completed)
	assert(session.enter_map(second))
	assert(session.party[0].definition.hero_id == REQUIRED_HERO)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, maps, campaigns)
	assert(restored != null and not restored.add_party_member(BLOCKED_HERO))
	assert(restored.party[0].definition.hero_id == REQUIRED_HERO)
	first.metadata.merge(_metadata([OPTIONAL_HERO], [OPTIONAL_HERO]), true)
	assert(GameSession.from_progress_snapshot(snapshot, maps, campaigns) == null)
