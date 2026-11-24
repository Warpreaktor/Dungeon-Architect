class_name CampaignGraphDiagnostics
extends RefCounted


static func analyze(campaigns: Dictionary, maps_by_id: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var owners: Dictionary = {}
	var campaign_ids: Array = campaigns.keys()
	campaign_ids.sort()
	for campaign_id in campaign_ids:
		var campaign: CampaignDefinition = campaigns[campaign_id]
		for map_id in campaign.map_ids:
			if owners.has(map_id):
				_add(issues, "error", campaign_id, map_id, "Карта указана в нескольких кампаниях: %s и %s." % [owners[map_id], campaign_id])
				_add(issues, "error", str(owners[map_id]), map_id, "Карта указана в нескольких кампаниях: %s и %s." % [owners[map_id], campaign_id])
			else:
				owners[map_id] = campaign_id
			if not maps_by_id.has(map_id):
				_add(issues, "error", campaign_id, map_id, "Карта отсутствует в библиотеке.")
			elif not (maps_by_id[map_id] is DungeonMap) or (maps_by_id[map_id] as DungeonMap).map_id != map_id:
				_add(issues, "error", campaign_id, map_id, "Идентификатор карты не совпадает с записью библиотеки.")
		if not campaign.map_ids.has(campaign.start_map_id):
			_add(issues, "error", campaign_id, campaign.start_map_id, "Стартовая карта не входит в кампанию.")
	for campaign_id in campaign_ids:
		var campaign: CampaignDefinition = campaigns[campaign_id]
		var adjacency: Dictionary = {}
		for map_id in campaign.map_ids:
			adjacency[map_id] = []
		for map_id in campaign.map_ids:
			if not maps_by_id.has(map_id) or not (maps_by_id[map_id] is DungeonMap):
				continue
			var dungeon: DungeonMap = maps_by_id[map_id]
			if dungeon.map_id != map_id:
				continue
			for entity in dungeon.entities:
				var target: String = DungeonMap.exit_target_id(entity)
				if target.is_empty():
					continue
				if not maps_by_id.has(target):
					_add(issues, "error", campaign_id, map_id, "Выход ссылается на отсутствующую карту %s." % target)
				elif not campaign.map_ids.has(target):
					var owner: String = str(owners.get(target, ""))
					var detail: String = "чужой кампании %s" % owner if not owner.is_empty() else "вне кампании"
					_add(issues, "error", campaign_id, map_id, "Выход на карту %s %s." % [target, detail])
				else:
					if not (adjacency[map_id] as Array).has(target):
						adjacency[map_id].append(target)
			if (adjacency[map_id] as Array).size() > 1:
				_add(issues, "info", campaign_id, map_id, "Развилка: переходов на другие карты %d." % (adjacency[map_id] as Array).size())
		var reachable: Dictionary = {}
		var pending: Array[String] = [campaign.start_map_id]
		while not pending.is_empty():
			var current: String = pending.pop_front()
			if reachable.has(current) or not adjacency.has(current):
				continue
			reachable[current] = true
			for next_id in adjacency[current]:
				if not reachable.has(next_id):
					pending.append(next_id)
		for map_id in campaign.map_ids:
			if not reachable.has(map_id):
				_add(issues, "warning", campaign_id, map_id, "Этаж недостижим из стартовой карты.")
		var states: Dictionary = {}
		for map_id in campaign.map_ids:
			if not states.has(map_id):
				_visit(map_id, adjacency, states, issues, campaign_id)
	return issues


static func _visit(map_id: String, adjacency: Dictionary, states: Dictionary, issues: Array[Dictionary], campaign_id: String) -> void:
	states[map_id] = 1
	for target in adjacency.get(map_id, []):
		if not states.has(target):
			_visit(target, adjacency, states, issues, campaign_id)
		elif states[target] == 1:
			_add(issues, "info", campaign_id, map_id, "Циклический переход на карту %s." % target)
	states[map_id] = 2


static func _add(issues: Array[Dictionary], severity: String, campaign_id: String, map_id: String, message: String) -> void:
	issues.append({"severity": severity, "campaign_id": campaign_id, "map_id": map_id, "message": message})
