extends SceneTree


func _initialize() -> void:
	var solo: DungeonMap = DungeonMap.create_blank(7, 7)
	var first: DungeonMap = DungeonMap.create_blank(7, 7)
	var second: DungeonMap = DungeonMap.create_blank(7, 7)
	var another: DungeonMap = DungeonMap.create_blank(7, 7)
	var maps: Dictionary = {
		solo.map_id: solo,
		first.map_id: first,
		second.map_id: second,
		another.map_id: another
	}
	var campaign: CampaignDefinition = CampaignDefinition.create("Приключение", first.map_id)
	assert(campaign != null)
	campaign.map_ids.append(second.map_id)
	var foreign: CampaignDefinition = CampaignDefinition.create("Другое приключение", another.map_id)
	assert(foreign != null)
	var campaigns: Dictionary = {campaign.campaign_id: campaign, foreign.campaign_id: foreign}
	var personal: Array[DungeonMap] = MainMenu.unassigned_maps(maps, campaigns)
	assert(personal.size() == 1 and personal[0].map_id == solo.map_id)
	assert(MainMenu.unassigned_maps(maps, {}).size() == 4)
	assert(campaign.start_map_id == first.map_id)
	assert(campaign.map_ids.has(second.map_id))
	assert(not campaign.map_ids.has(solo.map_id))
	print("Main menu: campaign and personal map selection OK")
	quit()
