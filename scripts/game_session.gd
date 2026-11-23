class_name GameSession
extends RefCounted

## Состояние конкретного прохождения карты. Не изменяет саму карту.

const VISION_RADIUS := 1
## Число одновременных портретов в походном интерфейсе.
const MAX_PARTY_SIZE: int = 4
const INVENTORY_SLOT_COUNT: int = 40

var map_data: DungeonMap
var hero: HeroState
var inventory_member: HeroState
var party: Array[HeroState] = []
var fallen_heroes: Array[HeroState] = []
var fallen_hero_locations: Array[Dictionary] = []
var _casualty_events: Array[HeroState] = []
var trap_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _party_damage_events: Array[Dictionary] = []
var player_pos := Vector2i(-1, -1)
var steps: int = 0
var keys: int = 0
var potions: int = 0
var carried_items: Dictionary = {} # Количество найденных предметов по ID, без интерфейса инвентаря.
var _inventory_order: Array[String] = []
var is_completed: bool = false # Выход достигнут в текущем прохождении.
var removed_entities: Dictionary = {} # ID объектов, исчезнувших только в этом прохождении.
var opened_chests: Dictionary = {} # ID открытых сундуков только в этом прохождении.
var disarmed_traps: Dictionary = {} # ID разряженных ловушек только в этом прохождении.
var revealed_traps: Dictionary = {}
var pending_chest_id: String = "" # Ожидает завершения анимации шага до открытия сундука.
var pending_door_trap_id: String = ""
var pending_door_trap_cell := Vector2i(-1, -1)
var activated_triggers: Dictionary = {} # ID сработавших триггеров; обнуляется с новой сессией.
var shown_messages: Dictionary = {} # Авторские сообщения показываются один раз за прохождение.
var _message_events: Array[Dictionary] = []
var _trigger_events: Array[Dictionary] = [] # События последнего хода для игрового контроллера.
var last_event_message: String = ""
var encounter_monster_id: String = ""
var encounter_target := Vector2i(-1, -1)
var debug_open_map: bool = false # Только для теста редактора, никогда не сериализуется.
var is_editor_test: bool = false
var _revealed_before_debug_open_map: Array = []
var revealed: Array = [] # revealed[y][x] = bool
var visible: Array = []  # visible[y][x] = bool
var ground_loot_containers: Array[Dictionary] = []
var _ground_loot_counter: int = 0
var claimed_exit_rewards: Dictionary = {}
var _floor_states: Dictionary = {} # Состояние посещённых карт только в памяти этого прохождения.
var _stairs_history: Array[Dictionary] = []
var _pending_return_exit: Dictionary = {}



static func start_for(map_ref: DungeonMap, hero_id: String = HeroCatalog.DEFAULT_HERO_ID, open_map: bool = false) -> GameSession:
	return start_for_party(map_ref, [hero_id], open_map)


static func start_for_party(map_ref: DungeonMap, hero_ids: Array[String], open_map: bool = false) -> GameSession:
	if hero_ids.is_empty() or hero_ids.size() > MAX_PARTY_SIZE:
		return null
	for hero_id in hero_ids:
		if not HeroCatalog.has(hero_id):
			return null
	if map_ref == null:
		return null
	var spawn := map_ref.find_entity_position("player_spawn")
	if spawn.x < 0 or spawn.y < 0:
		return null
	var session := GameSession.new()
	session.map_data = map_ref
	for hero_id in hero_ids:
		session.party.append(HeroState.new(HeroCatalog.get_hero(hero_id)))
	session.hero = session.party[0]
	session.trap_random.randomize()
	session.player_pos = spawn
	session.debug_open_map = open_map
	session._init_masks()
	session._refresh_visibility()
	session._collect_pickups_at(spawn)
	session._activate_triggers_at(spawn)
	session._activate_message_at(spawn, "enter")
	return session


func equipment_item_id(slot_id: String) -> String:
	return _member_equipment_id(_inventory_equipment_member(), slot_id)


func _inventory_equipment_member() -> HeroState:
	return inventory_member if inventory_member != null and party.has(inventory_member) else hero


func inventory_slot_ids() -> Array[String]:
	_inventory_order = _inventory_slots_snapshot()
	return _inventory_order.duplicate()


func _inventory_slots_snapshot() -> Array[String]:
	var bag: Array[String] = []
	bag.assign(_inventory_order)
	if bag.size() != INVENTORY_SLOT_COUNT:
		bag.resize(INVENTORY_SLOT_COUNT)
		bag.fill("")
	var remaining: Dictionary = {}
	for key in carried_items:
		var item_id: String = str(key)
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item == null:
			continue
		var count: int = int(carried_items[key])
		if count > 0:
			remaining[item_id] = 1 if item.stackable else count
	for member in party:
		if member == null:
			continue
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var item_id: String = _member_equipment_id(member, slot_id)
			if not item_id.is_empty():
				remaining[item_id] = maxi(0, int(remaining.get(item_id, 0)) - 1)
	for index in range(bag.size()):
		var item_id: String = bag[index]
		if item_id.is_empty():
			continue
		var count: int = int(remaining.get(item_id, 0))
		if count > 0:
			remaining[item_id] = count - 1
		else:
			bag[index] = ""
	var ids: Array[String] = []
	for key in remaining:
		ids.append(str(key))
	ids.sort()
	for item_id in ids:
		for entry in range(int(remaining[item_id])):
			var empty_index: int = bag.find("")
			if empty_index < 0:
				break
			bag[empty_index] = item_id
	return bag


func swap_inventory_slots(source: int, destination: int) -> bool:
	return transfer_inventory_item("bag", source, "bag", destination)


func _equipment_snapshot(member: HeroState = null) -> Dictionary:
	var selected: HeroState = member if member != null else _inventory_equipment_member()
	var current: Dictionary = {}
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		current[slot_id] = _member_equipment_id(selected, slot_id)
	return current


func _can_equip_layout(equipped: Dictionary) -> bool:
	var weapon_id: String = str(equipped.get("main_hand", ""))
	var weapon: ItemDefinition = ItemCatalog.get_item(weapon_id)
	if weapon != null and weapon.two_handed and not str(equipped.get("off_hand", "")).is_empty():
		return false
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var item_id: String = str(equipped.get(slot_id, ""))
		if not item_id.is_empty() and not EquipmentSlotRules.accepts(slot_id, ItemCatalog.get_item(item_id)):
			return false
	return true


func _is_shield(item_id: String) -> bool:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	return item != null and item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD


func _shield_layout(bag: Array[String], equipped: Dictionary, member: HeroState = null) -> Dictionary:
	var selected: HeroState = member if member != null else _inventory_equipment_member()
	if selected != hero:
		var shared: Dictionary = _shield_layout(bag, _equipment_snapshot(hero), hero)
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var item_id: String = str(equipped.get(slot_id, ""))
			if _is_shield(item_id):
				shared["equipment:%s" % slot_id] = selected.current_shield_durability(item_id)
		return shared
	var values_at: Dictionary = {}
	var cursors: Dictionary = {}
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var item_id: String = str(equipped.get(slot_id, ""))
		if _is_shield(item_id):
			var values: Array = selected.shield_durabilities.get(item_id, [])
			var cursor: int = int(cursors.get(item_id, 0))
			values_at["equipment:%s" % slot_id] = int(values[cursor]) if cursor < values.size() else _new_shield_durability(item_id)
			cursors[item_id] = cursor + 1
	for index in range(bag.size()):
		var item_id: String = bag[index]
		if _is_shield(item_id):
			var values: Array = selected.shield_durabilities.get(item_id, [])
			var cursor: int = int(cursors.get(item_id, 0))
			values_at["bag:%d" % index] = int(values[cursor]) if cursor < values.size() else _new_shield_durability(item_id)
			cursors[item_id] = cursor + 1
	return values_at

func _new_shield_durability(item_id: String) -> int:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	return maxi(item.max_durability, item.defense_bonus) if item != null else 0


func _apply_shield_layout(bag: Array[String], equipped: Dictionary, values_at: Dictionary, member: HeroState = null) -> void:
	var selected: HeroState = member if member != null else _inventory_equipment_member()
	if selected != hero:
		var primary_equipment: Dictionary = _equipment_snapshot(hero)
		var primary_values: Dictionary = _shield_layout(bag, primary_equipment, hero)
		for index in range(bag.size()):
			if _is_shield(bag[index]):
				primary_values["bag:%d" % index] = values_at.get("bag:%d" % index, _new_shield_durability(bag[index]))
		_apply_shield_layout(bag, primary_equipment, primary_values, hero)
		var selected_values: Dictionary = selected.shield_durabilities.duplicate(true)
		for item_id in selected_values.keys():
			if _is_shield(str(item_id)):
				selected_values.erase(item_id)
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var item_id: String = str(equipped.get(slot_id, ""))
			if _is_shield(item_id):
				var values: Array = selected_values.get(item_id, [])
				values.append(int(values_at.get("equipment:%s" % slot_id, _new_shield_durability(item_id))))
				selected_values[item_id] = values
		selected.shield_durabilities = selected_values
		return
	var updated: Dictionary = selected.shield_durabilities.duplicate(true)
	for item_id in updated.keys():
		if _is_shield(str(item_id)):
			updated.erase(item_id)
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var item_id: String = str(equipped.get(slot_id, ""))
		if _is_shield(item_id):
			var values: Array = updated.get(item_id, [])
			values.append(int(values_at.get("equipment:%s" % slot_id, _new_shield_durability(item_id))))
			updated[item_id] = values
	for index in range(bag.size()):
		var item_id: String = bag[index]
		if _is_shield(item_id):
			var values: Array = updated.get(item_id, [])
			values.append(int(values_at.get("bag:%d" % index, _new_shield_durability(item_id))))
			updated[item_id] = values
	selected.shield_durabilities = updated

func inventory_shield_durability(index: int) -> int:
	var bag: Array[String] = _inventory_slots_snapshot()
	if index < 0 or index >= bag.size() or not _is_shield(bag[index]) or hero == null:
		return 0
	return int(_shield_layout(bag, _equipment_snapshot()).get("bag:%d" % index, 0))


func can_transfer_inventory_item(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant) -> bool:
	return _planned_inventory_transfer(from_kind, from_slot, to_kind, to_slot).size() > 0


func transfer_inventory_item(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant) -> bool:
	var plan: Dictionary = _planned_inventory_transfer(from_kind, from_slot, to_kind, to_slot)
	if plan.is_empty():
		return false
	_inventory_order = plan["bag"]
	var member: HeroState = _inventory_equipment_member()
	var equipped: Dictionary = plan["equipment"]
	member.equipped_weapon_id = str(equipped["main_hand"])
	member.equipped_shield_id = str(equipped["off_hand"])
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if slot_id != "main_hand" and slot_id != "off_hand":
			var item_id: String = str(equipped[slot_id])
			if item_id.is_empty():
				member.equipped_accessories.erase(slot_id)
			else:
				member.equipped_accessories[slot_id] = item_id
	member._recalculate_equipment_stats()
	_apply_shield_layout(_inventory_order, equipped, plan["shield_layout"])
	return true


func _planned_inventory_transfer(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant) -> Dictionary:
	if hero == null or not (from_kind in ["bag", "equipment"]) or not (to_kind in ["bag", "equipment"]):
		return {}
	if (from_kind == "bag" and typeof(from_slot) != TYPE_INT) or (to_kind == "bag" and typeof(to_slot) != TYPE_INT):
		return {}
	var bag: Array[String] = _inventory_slots_snapshot()
	var equipped: Dictionary = _equipment_snapshot()
	var shield_layout: Dictionary = _shield_layout(bag, equipped)
	var source: String = ""
	var target: String = ""
	var source_index: int = -1
	var target_index: int = -1
	var source_slot: String = ""
	var target_slot: String = ""
	if from_kind == "bag":
		source_index = int(from_slot)
		if source_index < 0 or source_index >= bag.size():
			return {}
		source = bag[source_index]
	else:
		source_slot = str(from_slot)
		if not equipped.has(source_slot):
			return {}
		source = str(equipped[source_slot])
	if source.is_empty():
		return {}
	if to_kind == "bag":
		target_index = int(to_slot)
		if target_index < 0 or target_index >= bag.size():
			return {}
		target = bag[target_index]
	else:
		target_slot = str(to_slot)
		if not equipped.has(target_slot):
			return {}
		target = str(equipped[target_slot])
	if from_kind == to_kind and from_slot == to_slot:
		return {}
	if to_kind == "equipment" and not EquipmentSlotRules.accepts(target_slot, ItemCatalog.get_item(source)):
		return {}
	if from_kind == "equipment" and not target.is_empty() and not EquipmentSlotRules.accepts(source_slot, ItemCatalog.get_item(target)):
		return {}
	var source_location: String = "bag:%d" % source_index if from_kind == "bag" else "equipment:%s" % source_slot
	var target_location: String = "bag:%d" % target_index if to_kind == "bag" else "equipment:%s" % target_slot
	var source_durability: Variant = shield_layout.get(source_location)
	var target_durability: Variant = shield_layout.get(target_location)
	shield_layout.erase(source_location)
	shield_layout.erase(target_location)
	if from_kind == "bag":
		bag[source_index] = target
	else:
		equipped[source_slot] = target
	if to_kind == "bag":
		bag[target_index] = source
	else:
		equipped[target_slot] = source
	if source_durability != null:
		shield_layout[target_location] = source_durability
	if target_durability != null:
		shield_layout[source_location] = target_durability
	var current_weapon: ItemDefinition = ItemCatalog.get_item(str(equipped["main_hand"]))
	if current_weapon != null and current_weapon.two_handed and not str(equipped["off_hand"]).is_empty():
		var off_hand: String = str(equipped["off_hand"])
		var free_index: int = bag.find("")
		if free_index < 0:
			return {}
		bag[free_index] = off_hand
		equipped["off_hand"] = ""
		if shield_layout.has("equipment:off_hand"):
			shield_layout["bag:%d" % free_index] = shield_layout["equipment:off_hand"]
			shield_layout.erase("equipment:off_hand")
	if not _can_equip_layout(equipped):
		return {}
	return {"bag": bag, "equipment": equipped, "shield_layout": shield_layout}


func party_members() -> Array[HeroState]:
	var members: Array[HeroState] = []
	members.append_array(party)
	return members


func _member_equipment_id(member: HeroState, slot_id: String) -> String:
	if member == null:
		return ""
	match slot_id:
		"main_hand":
			return member.equipped_weapon_id
		"off_hand":
			return member.equipped_shield_id
		_:
			return str(member.equipped_accessories.get(slot_id, ""))


func _clear_member_equipment(member: HeroState) -> void:
	member.equipped_weapon_id = ""
	member.equipped_shield_id = ""
	member.equipped_accessories.clear()
	member._recalculate_equipment_stats()


func _append_ground_loot(cell: Vector2i, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	var container: Dictionary = ground_container_at(cell)
	if not container.is_empty():
		var contents: Array = container["loot"]
		contents.append_array(entries)
		return
	_ground_loot_counter += 1
	ground_loot_containers.append({
		"id": "ground_%d" % _ground_loot_counter,
		"x": cell.x, "y": cell.y,
		"loot": entries.duplicate(true)
	})


func ground_container_at(cell: Vector2i) -> Dictionary:
	for container in ground_loot_containers:
		if int(container["x"]) == cell.x and int(container["y"]) == cell.y:
			return container
	return {}


func ground_container_by_id(container_id: String) -> Dictionary:
	for container in ground_loot_containers:
		if str(container["id"]) == container_id:
			return container
	return {}


func _shield_durability_for_drop(member: HeroState, item_id: String) -> int:
	var values: Array = member.shield_durabilities.get(item_id, [])
	if values.is_empty():
		var shield: ItemDefinition = ItemCatalog.get_item(item_id)
		return maxi(shield.max_durability, shield.defense_bonus) if shield != null else 0
	var durability: int = int(values.pop_front())
	member.shield_durabilities[item_id] = values
	return durability


func take_casualty_events() -> Array[HeroState]:
	var events: Array[HeroState] = _casualty_events.duplicate()
	_casualty_events.clear()
	return events


func record_casualties() -> Array[HeroState]:
	var casualties: Array[HeroState] = []
	for member in party:
		if member != null and member.health <= 0:
			casualties.append(member)
	if casualties.is_empty():
		return casualties
	var bag: Array[String] = inventory_slot_ids()
	var bag_shields: Dictionary = _shield_layout(bag, _equipment_snapshot()) if hero != null else {}
	var survivor: HeroState = null
	for member in party:
		if member != null and member.health > 0:
			survivor = member
			break
	if survivor != null:
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var item_id: String = _member_equipment_id(survivor, slot_id)
			if _is_shield(item_id):
				bag_shields["equipment:%s" % slot_id] = survivor.current_shield_durability(item_id)
	var ground: Array[Dictionary] = []
	var death_gold: int = 0
	for member in casualties:
		var equipped_at_death: Dictionary = {}
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var item_id: String = _member_equipment_id(member, slot_id)
			if not item_id.is_empty():
				equipped_at_death[slot_id] = item_id
		var durability_at_death: Dictionary = member.shield_durabilities.duplicate(true)
		var member_gold: int = member.gold
		death_gold += member_gold
		member.gold = 0
		if survivor != null:
			for slot_id in equipped_at_death:
				var item_id: String = str(equipped_at_death[slot_id])
				var durability: int = _shield_durability_for_drop(member, item_id) if _is_shield(item_id) else 0
				var free: int = bag.find("")
				if free >= 0:
					bag[free] = item_id
					if _is_shield(item_id):
						bag_shields["bag:%d" % free] = durability
				else:
					carried_items[item_id] = maxi(int(carried_items.get(item_id, 0)) - 1, 0)
					var entry: Dictionary = {"item_id": item_id, "quantity": 1}
					if _is_shield(item_id):
						entry["durabilities"] = [durability]
					ground.append(entry)
		_clear_member_equipment(member)
		fallen_heroes.append(member)
		fallen_hero_locations.append({
			"hero": member, "map_id": map_data.map_id,
			"position": player_pos, "equipment_at_death": equipped_at_death,
			"shield_durabilities_at_death": durability_at_death,
			"gold_at_death": member_gold
		})
		party.erase(member)
	if survivor == null:
		for key in carried_items:
			var item_id: String = str(key)
			var amount: int = int(carried_items[key])
			if amount <= 0:
				continue
			var entry: Dictionary = {"item_id": item_id, "quantity": amount}
			if _is_shield(item_id):
				var durabilities: Array = []
				for member in casualties:
					durabilities.append_array(member.shield_durabilities.get(item_id, []))
				entry["durabilities"] = durabilities
			ground.append(entry)
		carried_items.clear()
		bag.fill("")
		for member in casualties:
			member.shield_durabilities.clear()
	else:
		hero = survivor
		_apply_shield_layout(bag, _equipment_snapshot(), bag_shields)
		for member in casualties:
			member.shield_durabilities.clear()
	if death_gold > 0:
		ground.append({"item_id": "gold", "quantity": death_gold})
	_inventory_order = bag
	keys = int(carried_items.get("key", 0))
	potions = int(carried_items.get("potion", 0))
	_append_ground_loot(player_pos, ground)
	hero = survivor
	_casualty_events.append_array(casualties)
	return casualties


func _ground_loot_take_count(entry: Dictionary) -> int:
	var item_id: String = str(entry.get("item_id", ""))
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	var quantity: int = int(entry.get("quantity", 0))
	if hero == null or item == null or quantity <= 0:
		return 0
	if item.category == ItemDefinition.Category.CURRENCY:
		return quantity
	var bag: Array[String] = _inventory_slots_snapshot()
	if bag.find("") < 0 and not (item.stackable and bag.has(item_id)):
		return 0
	return quantity if item.stackable else 1


func can_take_ground_loot(container_id: String, entry_index: int) -> bool:
	var container: Dictionary = ground_container_by_id(container_id)
	if container.is_empty() or is_party_defeated():
		return false
	var cell := Vector2i(int(container["x"]), int(container["y"]))
	if absi(cell.x - player_pos.x) + absi(cell.y - player_pos.y) > 1:
		return false
	var loot: Array = container["loot"]
	return entry_index >= 0 and entry_index < loot.size() and _ground_loot_take_count(loot[entry_index]) > 0


func take_ground_loot(container_id: String, entry_index: int) -> int:
	if not can_take_ground_loot(container_id, entry_index):
		return 0
	var container: Dictionary = ground_container_by_id(container_id)
	var loot: Array = container["loot"]
	var entry: Dictionary = loot[entry_index]
	var item_id: String = str(entry["item_id"])
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	var amount: int = _ground_loot_take_count(entry)
	if item.category == ItemDefinition.Category.CURRENCY:
		hero.gold += amount
	else:
		var bag: Array[String] = _inventory_slots_snapshot()
		var equipped: Dictionary = _equipment_snapshot()
		var shield_layout: Dictionary = _shield_layout(bag, equipped)
		if not (item.stackable and bag.has(item_id)):
			var free: int = bag.find("")
			if free < 0:
				return 0
			bag[free] = item_id
			if _is_shield(item_id):
				var durabilities: Array = entry.get("durabilities", [])
				shield_layout["bag:%d" % free] = int(durabilities.pop_front()) if not durabilities.is_empty() else _new_shield_durability(item_id)
				entry["durabilities"] = durabilities
		_inventory_order = bag
		carried_items[item_id] = int(carried_items.get(item_id, 0)) + amount
		if _is_shield(item_id):
			_apply_shield_layout(bag, equipped, shield_layout)
		keys = int(carried_items.get("key", 0))
		potions = int(carried_items.get("potion", 0))
	entry["quantity"] = int(entry["quantity"]) - amount
	if int(entry["quantity"]) <= 0:
		loot.remove_at(entry_index)
	if loot.is_empty():
		ground_loot_containers.erase(container)
	return amount


func abandon_pending_encounter() -> void:
	encounter_monster_id = ""
	encounter_target = Vector2i(-1, -1)


func add_party_member(hero_id: String) -> bool:
	if not HeroCatalog.has(hero_id):
		return false
	if party.size() >= MAX_PARTY_SIZE or (party.is_empty() and not fallen_heroes.is_empty()):
		return false
	var member := HeroState.new(HeroCatalog.get_hero(hero_id))
	party.append(member)
	if hero == null:
		hero = member
	return true


func is_party_defeated() -> bool:
	for member in party:
		if member != null and member.health > 0:
			return false
	return true


func has_party_damage_events() -> bool:
	return not _party_damage_events.is_empty()


func take_party_damage_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = _party_damage_events.duplicate(true)
	_party_damage_events.clear()
	return result


func _record_party_damage(member: HeroState, damage: int, source: String) -> void:
	if damage <= 0:
		return
	var index: int = party_members().find(member)
	_party_damage_events.append({"hero_index": index, "member": member, "damage": damage, "source": source})


func _random_living_party_member() -> HeroState:
	var living: Array[HeroState] = []
	for member in party_members():
		if member != null and member.health > 0:
			living.append(member)
	if living.is_empty():
		return null
	return living[trap_random.randi_range(0, living.size() - 1)]


func _capture_floor_state() -> Dictionary:
	if map_data == null:
		return {}
	var visited_cells: Array = revealed
	if debug_open_map and _revealed_before_debug_open_map.size() == map_data.height:
		visited_cells = _revealed_before_debug_open_map
	return {
		"map_id": map_data.map_id,
		"position": player_pos,
		"ground_loot": ground_loot_containers.duplicate(true),
		"exit_rewards": claimed_exit_rewards.duplicate(true),
		"removed": removed_entities.duplicate(true),
		"chests": opened_chests.duplicate(true),
		"traps": disarmed_traps.duplicate(true),
		"revealed_traps": revealed_traps.duplicate(true),
		"triggers": activated_triggers.duplicate(true),
		"messages": shown_messages.duplicate(true),
		"revealed": visited_cells.duplicate(true)
	}


func floor_state_snapshot(map_id: String = "") -> Dictionary:
	var selected_id: String = map_id
	if selected_id.is_empty() and map_data != null:
		selected_id = map_data.map_id
	if map_data != null and selected_id == map_data.map_id:
		return _capture_floor_state()
	var saved: Dictionary = _floor_states.get(selected_id, {})
	if saved.is_empty():
		return {}
	var snapshot: Dictionary = saved.duplicate(true)
	snapshot.erase("map")
	return snapshot


func visited_floor_snapshots() -> Dictionary:
	var snapshots: Dictionary = {}
	for map_id in _floor_states:
		snapshots[str(map_id)] = floor_state_snapshot(str(map_id))
	if map_data != null:
		snapshots[map_data.map_id] = _capture_floor_state()
	return snapshots


func party_state_snapshot() -> Dictionary:
	var active: Array[Dictionary] = []
	for member in party:
		active.append(member.to_snapshot())
	var fallen: Array[Dictionary] = []
	for member in fallen_heroes:
		fallen.append(member.to_snapshot())
	var locations: Array[Dictionary] = []
	for location in fallen_hero_locations:
		var index: int = fallen_heroes.find(location.get("hero"))
		if index < 0:
			return {}
		var cell: Vector2i = location.get("position", Vector2i(-1, -1))
		locations.append({
			"fallen_index": index,
			"map_id": str(location.get("map_id", "")),
			"x": cell.x,
			"y": cell.y,
			"equipment_at_death": location.get("equipment_at_death", {}).duplicate(true),
			"shield_durabilities_at_death": location.get("shield_durabilities_at_death", {}).duplicate(true),
			"gold_at_death": int(location.get("gold_at_death", 0))
		})
	return {
		"active_heroes": active,
		"fallen_heroes": fallen,
		"fallen_locations": locations,
		"hero_index": party.find(hero),
		"inventory_member_index": party.find(inventory_member),
		"carried_items": carried_items.duplicate(true),
		"inventory_slots": inventory_slot_ids(),
		"steps": steps,
		"random_seed": str(trap_random.seed),
		"random_state": str(trap_random.state)
	}


func restore_party_state(snapshot: Dictionary) -> bool:
	if not (snapshot.get("active_heroes") is Array) or not (snapshot.get("fallen_heroes") is Array):
		return false
	if not (snapshot.get("fallen_locations") is Array) or not (snapshot.get("carried_items") is Dictionary):
		return false
	if not (snapshot.get("inventory_slots") is Array):
		return false
	var active_data: Array = snapshot["active_heroes"]
	var fallen_data: Array = snapshot["fallen_heroes"]
	if active_data.size() > MAX_PARTY_SIZE or (active_data.is_empty() and fallen_data.is_empty()):
		return false
	var restored_party: Array[HeroState] = []
	for active_snapshot in active_data:
		if not (active_snapshot is Dictionary):
			return false
		var active_member: HeroState = HeroState.from_snapshot(active_snapshot)
		if active_member == null or active_member.health <= 0:
			return false
		restored_party.append(active_member)
	var restored_fallen: Array[HeroState] = []
	for fallen_snapshot in fallen_data:
		if not (fallen_snapshot is Dictionary):
			return false
		var fallen_member: HeroState = HeroState.from_snapshot(fallen_snapshot)
		if fallen_member == null or fallen_member.health != 0:
			return false
		restored_fallen.append(fallen_member)
	var hero_index: int = int(snapshot.get("hero_index", -2))
	var inventory_index: int = int(snapshot.get("inventory_member_index", -2))
	if restored_party.is_empty():
		if hero_index != -1:
			return false
	elif hero_index < 0 or hero_index >= restored_party.size():
		return false
	if inventory_index < -1 or inventory_index >= restored_party.size():
		return false
	var locations_data: Array = snapshot["fallen_locations"]
	if locations_data.size() != restored_fallen.size():
		return false
	var restored_locations: Array[Dictionary] = []
	var seen_fallen: Dictionary = {}
	for location in locations_data:
		if not (location is Dictionary):
			return false
		var index: int = int(location.get("fallen_index", -1))
		if index < 0 or index >= restored_fallen.size() or seen_fallen.has(index):
			return false
		if str(location.get("map_id", "")).is_empty():
			return false
		if not (location.get("equipment_at_death") is Dictionary) or not (location.get("shield_durabilities_at_death") is Dictionary):
			return false
		seen_fallen[index] = true
		restored_locations.append({
			"hero": restored_fallen[index],
			"map_id": str(location["map_id"]),
			"position": Vector2i(int(location.get("x", -1)), int(location.get("y", -1))),
			"equipment_at_death": location["equipment_at_death"].duplicate(true),
			"shield_durabilities_at_death": location["shield_durabilities_at_death"].duplicate(true),
			"gold_at_death": int(location.get("gold_at_death", 0))
		})
	var new_carried: Dictionary = snapshot["carried_items"]
	var new_slots: Array = snapshot["inventory_slots"]
	if new_slots.size() != INVENTORY_SLOT_COUNT or not _valid_snapshot_inventory(new_carried, new_slots, restored_party):
		return false
	if not (snapshot.get("steps") is int) and not (snapshot.get("steps") is float):
		return false
	var restored_steps: int = int(snapshot["steps"])
	if restored_steps < 0 or float(snapshot["steps"]) != float(restored_steps):
		return false
	var seed_text: String = str(snapshot.get("random_seed", ""))
	var state_text: String = str(snapshot.get("random_state", ""))
	if not seed_text.is_valid_int() or not state_text.is_valid_int():
		return false
	var restored_slots: Array[String] = []
	for item_id in new_slots:
		restored_slots.append(str(item_id))
	party = restored_party
	fallen_heroes = restored_fallen
	fallen_hero_locations = restored_locations
	hero = restored_party[hero_index] if hero_index >= 0 else null
	inventory_member = restored_party[inventory_index] if inventory_index >= 0 else null
	carried_items = new_carried.duplicate(true)
	_inventory_order = restored_slots
	steps = restored_steps
	keys = int(carried_items.get("key", 0))
	potions = int(carried_items.get("potion", 0))
	trap_random.seed = seed_text.to_int()
	trap_random.state = state_text.to_int()
	_casualty_events.clear()
	_party_damage_events.clear()
	return true


func _valid_snapshot_inventory(counts: Dictionary, bag: Array, members: Array[HeroState]) -> bool:
	var seen: Dictionary = {}
	for count_item_id in counts:
		if typeof(count_item_id) != TYPE_STRING or ItemCatalog.get_item(str(count_item_id)) == null:
			return false
		if typeof(counts[count_item_id]) not in [TYPE_INT, TYPE_FLOAT] or int(counts[count_item_id]) < 0 or float(counts[count_item_id]) != float(int(counts[count_item_id])):
			return false
	for bag_entry in bag:
		if typeof(bag_entry) != TYPE_STRING:
			return false
		var bag_item_id: String = str(bag_entry)
		if bag_item_id.is_empty():
			continue
		var item: ItemDefinition = ItemCatalog.get_item(bag_item_id)
		if item == null or int(counts.get(bag_item_id, 0)) <= 0:
			return false
		if item.stackable and seen.has(bag_item_id):
			return false
		seen[bag_item_id] = int(seen.get(bag_item_id, 0)) + (int(counts[bag_item_id]) if item.stackable else 1)
	for member in members:
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			var equipped_item_id: String = _member_equipment_id(member, slot_id)
			if equipped_item_id.is_empty():
				continue
			if not EquipmentSlotRules.accepts(slot_id, ItemCatalog.get_item(equipped_item_id)):
				return false
			seen[equipped_item_id] = int(seen.get(equipped_item_id, 0)) + 1
	for total_item_id in counts:
		if int(seen.get(total_item_id, 0)) != int(counts[total_item_id]):
			return false
	return true


func enter_map(next_map: DungeonMap) -> bool:
	if is_party_defeated() or next_map == null or next_map.map_id.is_empty():
		return false
	var source_exit: Dictionary = current_exit()
	var source_id: String = map_data.map_id if map_data != null else ""
	var source_kind: String = str(source_exit.get("type", ""))
	var saved: Dictionary = _floor_states.get(next_map.map_id, {})
	var destination: DungeonMap = saved.get("map", next_map)
	if map_data != null and map_data.map_id == next_map.map_id:
		saved = _capture_floor_state()
		destination = map_data
	elif is_editor_test and saved.is_empty():
		destination = DungeonMap.from_dict(next_map.to_dict().duplicate(true))
		if destination == null:
			return false
	var arrival: Vector2i = destination.find_entity_position("player_spawn")
	if source_kind == "stairs_up":
		arrival = _return_arrival_cell(destination)
		if arrival.x < 0:
			return false
	elif not DungeonMap.valid_arrival_cell(destination, arrival):
		return false
	if is_completed and source_kind in ["stairs_down", "stairs_up", "portal"] and DungeonMap.exit_target_id(source_exit) != next_map.map_id:
		return false
	if map_data != null:
		var current: Dictionary = _capture_floor_state()
		current["map"] = map_data
		_floor_states[map_data.map_id] = current
	if source_kind == "stairs_down" and DungeonMap.exit_target_id(source_exit) == next_map.map_id:
		_stairs_history.append({
			"from": source_id,
			"to": next_map.map_id,
			"from_cell": [player_pos.x, player_pos.y],
			"from_exit_id": str(source_exit.get("id", ""))
		})
	elif source_kind == "stairs_up" and not _stairs_history.is_empty():
		_stairs_history.pop_back()
	_pending_return_exit.clear()
	map_data = destination
	ground_loot_containers.clear()
	for container in saved.get("ground_loot", []):
		ground_loot_containers.append(container.duplicate(true))
	claimed_exit_rewards = saved.get("exit_rewards", {}).duplicate(true)
	player_pos = arrival
	removed_entities = saved.get("removed", {}).duplicate(true)
	opened_chests = saved.get("chests", {}).duplicate(true)
	disarmed_traps = saved.get("traps", {}).duplicate(true)
	revealed_traps = saved.get("revealed_traps", {}).duplicate(true)
	pending_chest_id = ""
	pending_door_trap_id = ""
	pending_door_trap_cell = Vector2i(-1, -1)
	activated_triggers = saved.get("triggers", {}).duplicate(true)
	shown_messages = saved.get("messages", {}).duplicate(true)
	encounter_monster_id = ""
	encounter_target = Vector2i(-1, -1)
	is_completed = false
	last_event_message = ""
	_message_events.clear()
	_trigger_events.clear()
	_party_damage_events.clear()
	_casualty_events.clear()
	_init_masks()
	if saved.has("revealed"):
		revealed = saved["revealed"].duplicate(true)
	else:
		_collect_pickups_at(player_pos)
		_activate_triggers_at(player_pos)
		_activate_message_at(player_pos, "enter")
	_refresh_visibility()
	return true


func has_stairs_up() -> bool:
	return map_data != null and not _stairs_history.is_empty() and str(_stairs_history.back().get("to", "")) == map_data.map_id


static func _history_origin(record: Dictionary, fallback: Vector2i) -> Vector2i:
	if not record.has("from_cell"):
		return fallback
	var coords: Variant = record["from_cell"]
	if not (coords is Array) or coords.size() != 2:
		return Vector2i(-1, -1)
	if not ProgressSnapshotCodec._is_integer(coords[0]) or not ProgressSnapshotCodec._is_integer(coords[1]):
		return Vector2i(-1, -1)
	return Vector2i(int(coords[0]), int(coords[1]))


static func _matching_return_stair(map_ref: DungeonMap, cell: Vector2i, exit_id: String, target_id: String) -> bool:
	if map_ref == null or not map_ref.contains(cell.x, cell.y):
		return false
	for entity in map_ref.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) != "stairs_down":
			continue
		if not exit_id.is_empty() and str(entity.get("id", "")) != exit_id:
			continue
		if DungeonMap.exit_target_id(entity) == target_id:
			return true
	return false


static func _return_cell_is_open(map_ref: DungeonMap, cell: Vector2i, removed: Dictionary) -> bool:
	if map_ref == null or map_ref.get_terrain(cell.x, cell.y) != "floor":
		return false
	for entity in map_ref.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) in ["door", "monster"] and not removed.has(str(entity.get("id", ""))):
			return false
	return true


func _return_arrival_cell(destination: DungeonMap) -> Vector2i:
	var invalid := Vector2i(-1, -1)
	if not has_stairs_up() or destination == null or _stairs_history.is_empty():
		return invalid
	var record: Dictionary = _stairs_history.back()
	if str(record.get("from", "")) != destination.map_id:
		return invalid
	var previous: Dictionary = _floor_states.get(destination.map_id, {})
	var old_position: Vector2i = previous.get("position", invalid)
	var cell: Vector2i = _history_origin(record, old_position)
	if not _matching_return_stair(destination, cell, str(record.get("from_exit_id", "")), map_data.map_id):
		return invalid
	if not _return_cell_is_open(destination, cell, previous.get("removed", {})):
		return invalid
	return cell


func known_map(map_id: String) -> DungeonMap:
	if map_data != null and map_data.map_id == map_id:
		return map_data
	var state: Dictionary = _floor_states.get(map_id, {})
	return state.get("map") as DungeonMap


func current_exit() -> Dictionary:
	if not _pending_return_exit.is_empty():
		return _pending_return_exit.duplicate(true)
	if not is_completed:
		return {}
	var stairs: Dictionary = _find_active_entity(player_pos, "stairs_down")
	if not stairs.is_empty():
		return stairs
	return _find_active_entity(player_pos, "portal")


func next_map_id() -> String:
	return DungeonMap.exit_target_id(current_exit())


func next_arrival_cell(destination: DungeonMap) -> Vector2i:
	if str(current_exit().get("type", "")) == "stairs_up":
		return _return_arrival_cell(destination)
	return DungeonMap.exit_target_cell(current_exit(), destination)


func can_enter_next_map(destination: DungeonMap) -> bool:
	if destination == null or destination.map_id != next_map_id():
		return false
	var arrival: Vector2i = next_arrival_cell(destination)
	if str(current_exit().get("type", "")) == "stairs_up":
		return arrival.x >= 0
	return DungeonMap.valid_arrival_cell(destination, arrival)


func cancel_exit_transition() -> void:
	is_completed = false
	_pending_return_exit.clear()


func _init_masks() -> void:
	_revealed_before_debug_open_map.clear()
	revealed.clear()
	visible.clear()
	for y in range(map_data.height):
		var revealed_row: Array = []
		var visible_row: Array = []
		for x in range(map_data.width):
			revealed_row.append(false)
			visible_row.append(false)
		revealed.append(revealed_row)
		visible.append(visible_row)


func contains(x: int, y: int) -> bool:
	return map_data != null and map_data.contains(x, y)


func is_revealed(x: int, y: int) -> bool:
	return contains(x, y) and bool(revealed[y][x])


func is_visible(x: int, y: int) -> bool:
	return contains(x, y) and bool(visible[y][x])


func is_entity_removed(entity: Dictionary) -> bool:
	return removed_entities.has(str(entity.get("id", "")))


func is_chest_open(entity: Dictionary) -> bool:
	return opened_chests.has(str(entity.get("id", "")))


func is_entity_hidden_from_hero(entity: Dictionary) -> bool:
	if str(entity.get("type", "")) == "trap" and is_trap_revealed(entity):
		return false
	return DungeonMap.is_entity_hidden(entity) and (hero == null or not hero.has_vision_effect())


func is_trap_disarmed(entity: Dictionary) -> bool:
	return disarmed_traps.has(str(entity.get("id", "")))


func is_trap_revealed(entity: Dictionary) -> bool:
	return revealed_traps.has(str(entity.get("id", ""))) or is_trap_disarmed(entity)


func entities_at(x: int, y: int) -> Array:
	var result: Array = map_data.entities_at(x, y)
	var container: Dictionary = ground_container_at(Vector2i(x, y))
	if not container.is_empty():
		result.append({"type": "ground_loot", "id": container["id"], "x": x, "y": y})
	return result


func _find_active_entity(cell: Vector2i, kind: String) -> Dictionary:
	for entity in entities_at(cell.x, cell.y):
		if str(entity["type"]) == kind and not is_entity_removed(entity):
			return entity
	return {}


func has_pending_encounter() -> bool:
	return not encounter_monster_id.is_empty()


## Возвращает описание монстра для следующего поединка; старые карты получают базовый тип.
func pending_monster_definitions() -> Array[MonsterDefinition]:
	var result: Array[MonsterDefinition] = []
	if not has_pending_encounter():
		return result
	for entity in map_data.entities:
		if str(entity.get("id", "")) != encounter_monster_id or str(entity.get("type", "")) != "monster":
			continue
		for monster_id in DungeonMap.monster_party_ids(entity):
			result.append(MonsterCatalog.get_monster(monster_id))
		break
	return result


func pending_monster_definition() -> MonsterDefinition:
	var definitions: Array[MonsterDefinition] = pending_monster_definitions()
	return definitions[0] if not definitions.is_empty() else MonsterCatalog.get_monster(MonsterCatalog.DEFAULT_MONSTER_ID)


## Победа снимает монстра только в сессии, затем повторяет вход в клетку
## через обычные правила дверей, сундуков и находок.
func win_pending_encounter() -> bool:
	if not has_pending_encounter():
		return false
	record_casualties()
	if is_party_defeated():
		return false
	var target: Vector2i = encounter_target
	var defeated_id: String = encounter_monster_id
	var defeated: Dictionary = {}
	for entity in map_data.entities:
		if str(entity.get("id", "")) == defeated_id and str(entity.get("type", "")) == "monster":
			defeated = entity
			break
	removed_entities[defeated_id] = true
	encounter_monster_id = ""
	encounter_target = Vector2i(-1, -1)
	var rewards: Array[Dictionary] = []
	if not defeated.is_empty():
		rewards = _resolve_rewards(
			DungeonMap.monster_loot_contents(defeated),
			DungeonMap.monster_loot_is_random(defeated),
			DungeonMap.monster_gold_amount(defeated),
			DungeonMap.monster_item_quantities(defeated))
		for reward in rewards:
			_receive_item(str(reward["item_id"]), int(reward["quantity"]), reward.get("durabilities", []))
		if not rewards.is_empty():
			_activate_message_at(target, "monster_defeated", defeated_id, rewards)
	return move_by(target.x - player_pos.x, target.y - player_pos.y)


## Отдаём события ровно один раз; они не являются всплывающими игровыми сообщениями.
func take_trigger_events() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	for event in _trigger_events:
		pending.append(event)
	_trigger_events.clear()
	return pending


func _activate_triggers_at(cell: Vector2i) -> void:
	for entity in map_data.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) != "trigger":
			continue
		var entity_id := str(entity.get("id", ""))
		if activated_triggers.has(entity_id):
			continue
		activated_triggers[entity_id] = true
		var properties: Dictionary = entity.get("properties", {})
		_trigger_events.append({
			"entity_id": entity_id,
			"event_id": str(properties.get("event_id", "")),
			"position": cell
		})


## Авторские события потребляются контроллером интерфейса, состояние карты не меняется.
func take_message_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = _message_events.duplicate(true)
	_message_events.clear()
	return result


func _activate_message_at(cell: Vector2i, activation: String, target_id: String = "", loot: Array[Dictionary] = []) -> void:
	var message := map_data.message_at(cell.x, cell.y)
	var authored_text := ""
	if not message.is_empty():
		var message_id := str(message.get("id", ""))
		if not shown_messages.has(message_id):
			var properties: Dictionary = message.get("properties", {})
			var stored_activation := str(properties.get("activation", "enter"))
			var stored_target := str(properties.get("target_entity_id", ""))
			var matches := stored_activation == activation and (activation == "enter" or stored_target == target_id)
			# Совместимость: послания на монстрах и сундуках старых карт были привязаны к входу.
			if not matches and stored_activation == "enter" and activation in ["monster_encounter", "chest_open"]:
				matches = true
			if matches:
				authored_text = str(properties.get("text", "")).strip_edges()
				if not authored_text.is_empty():
					shown_messages[message_id] = true
	if not authored_text.is_empty() or not loot.is_empty():
		_message_events.append({"text": authored_text, "activation": activation, "loot": loot.duplicate(true)})


func _append_event_message(message: String) -> void:
	var clean := message.strip_edges()
	if clean.is_empty():
		return
	if last_event_message.is_empty():
		last_event_message = clean
	else:
		last_event_message += "  " + clean


func _activate_trap(trap: TrapDefinition, trap_key: String) -> void:
	var target: HeroState = _random_living_party_member()
	if target == null:
		return
	revealed_traps[trap_key] = true
	var parts: Array[String] = []
	if trap.direct_damage > 0:
		var health_before: int = target.health
		target.take_damage(trap.direct_damage)
		var damage: int = health_before - target.health
		if damage > 0:
			_record_party_damage(target, damage, trap.trap_id)
			parts.append("-%d HP" % damage)
	if target.health > 0 and trap.applies_overworld_status():
		if target.apply_overworld_status(trap.overworld_status_id, trap.overworld_status_label,
			trap.overworld_status_damage, trap.overworld_status_ticks, trap.overworld_status_interval_steps):
			parts.append("%s %d на %d фазы" % [
				trap.overworld_status_label, trap.overworld_status_damage, trap.overworld_status_ticks
			])
	if not parts.is_empty():
		_append_event_message("%s: ловушка «%s», %s." % [
			target.definition.display_name, trap.display_name, " и ".join(parts)
		])
	if trap.disarm_on_trigger:
		disarmed_traps[trap_key] = true


func _activate_traps_at(cell: Vector2i) -> void:
	for entity in map_data.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) != "trap" or is_trap_disarmed(entity):
			continue
		var trap: TrapDefinition = TrapCatalog.from_entity(entity)
		if trap != null and trap.can_attach_to("floor"):
			_activate_trap(trap, str(entity.get("id", "")))


func has_pending_door_trap() -> bool:
	return not pending_door_trap_id.is_empty()


func resolve_pending_door_trap() -> bool:
	if not has_pending_door_trap():
		return false
	var door_id: String = pending_door_trap_id
	var cell: Vector2i = pending_door_trap_cell
	pending_door_trap_id = ""
	pending_door_trap_cell = Vector2i(-1, -1)
	var door: Dictionary = _find_active_entity(cell, "door")
	if door.is_empty() or str(door.get("id", "")) != door_id or not can_enter(cell):
		return false
	var trap: TrapDefinition = TrapCatalog.from_door(door)
	if trap != null and not is_trap_disarmed(door):
		_activate_trap(trap, door_id)
		record_casualties()
		if is_party_defeated():
			return false
	var trap_damage: Array[Dictionary] = _party_damage_events.duplicate(true)
	var trap_message: String = last_event_message
	var delta: Vector2i = cell - player_pos
	var moved: bool = move_by(delta.x, delta.y, true)
	trap_damage.append_array(_party_damage_events)
	_party_damage_events = trap_damage
	if not trap_message.is_empty():
		_append_event_message(trap_message)
	return moved


func can_enter(cell: Vector2i) -> bool:
	return contains(cell.x, cell.y) and map_data.get_terrain(cell.x, cell.y) != "wall"


func move_by(dx: int, dy: int, defer_chest_open: bool = false) -> bool:
	last_event_message = ""
	_trigger_events.clear()
	_party_damage_events.clear()
	if is_party_defeated() or has_pending_encounter() or is_completed or not pending_chest_id.is_empty() or has_pending_door_trap():
		return false
	var target := player_pos + Vector2i(dx, dy)
	if not can_enter(target):
		return false

	# Встреча инициирует поединок. Монстр исчезнет только после победы.
	var monster := _find_active_entity(target, "monster")
	if not monster.is_empty():
		encounter_monster_id = str(monster["id"])
		encounter_target = target
		_activate_message_at(target, "monster_encounter", encounter_monster_id)
		return false

	var door := _find_active_entity(target, "door")
	var opened_door_id := ""
	if not door.is_empty():
		var required_key: String = LockCatalog.required_key(door)
		if int(carried_items.get(required_key, 0)) <= 0:
			last_event_message = "Дверь заперта. Нужен %s ключ." % LockCatalog.label(required_key).to_lower()
			return false
		var trap: TrapDefinition = TrapCatalog.from_door(door)
		if trap != null and not is_trap_disarmed(door):
			pending_door_trap_id = str(door["id"])
			pending_door_trap_cell = target
			_message_events.append({
				"activation": "door_trap", "entity_id": pending_door_trap_id,
				"text": DungeonMap.door_trap_message(door), "loot": [],
				"icon_type": "trap", "icon_id": trap.trap_id
			})
			return false
		_remove_carried_item(required_key, 1)
		opened_door_id = str(door["id"])
		removed_entities[opened_door_id] = true
		last_event_message = "Ключ использован. Дверь открыта!"

	# Проверка сундука после двери: нельзя получить добычу через замок.
	var chest := _find_active_entity(target, "chest")
	if not chest.is_empty() and not is_chest_open(chest) and (DungeonMap.chest_is_random(chest) or not DungeonMap.chest_contents(chest).is_empty()):
		if defer_chest_open:
			pending_chest_id = str(chest["id"])
		else:
			_open_chest(chest)

	var arrival: Vector2i = target
	var local_portal: Dictionary = _find_active_entity(target, "portal_local")
	if not local_portal.is_empty():
		var paired: Vector2i = map_data.local_portal_destination(str(local_portal["id"]))
		if DungeonMap.valid_arrival_cell(map_data, paired):
			arrival = paired
	player_pos = arrival
	target = arrival
	steps += 1
	for member in party_members():
		if member == null or member.health <= 0:
			continue
		member.advance_effects()
		for status_event in member.advance_overworld_statuses():
			var label: String = str(status_event.get("label", ""))
			var amount: int = int(status_event.get("damage", 0))
			if amount > 0:
				_record_party_damage(member, amount, str(status_event.get("status_id", "")))
				_append_event_message("%s: %s, -%d HP" % [member.definition.display_name, label, amount])
	if not is_party_defeated():
		_activate_traps_at(target)
	record_casualties()
	if is_party_defeated():
		_refresh_visibility()
		return true
	_collect_pickups_at(target)
	_activate_triggers_at(target)
	if not opened_door_id.is_empty():
		_activate_message_at(target, "door_open", opened_door_id)
	else:
		_activate_message_at(target, "enter")
	_refresh_visibility()
	var stairs: Dictionary = _find_active_entity(target, "stairs_down")
	if has_stairs_up() and target == map_data.find_entity_position("player_spawn"):
		_pending_return_exit = {
			"type": "stairs_up", "id": "return_stairs",
			"properties": {"target_map_id": str(_stairs_history.back()["from"])}
		}
		is_completed = true
	elif not stairs.is_empty():
		_claim_exit_reward(stairs)
		is_completed = true
	else:
		var portal: Dictionary = _find_active_entity(target, "portal")
		if not portal.is_empty() and not DungeonMap.exit_target_id(portal).is_empty():
			is_completed = true
	return true


## Завершает открытие сундука только после визуального прибытия героя.
func open_pending_chest() -> bool:
	if pending_chest_id.is_empty():
		return false
	var chest_id := pending_chest_id
	pending_chest_id = ""
	var chest := _find_active_entity(player_pos, "chest")
	if chest.is_empty() or str(chest.get("id", "")) != chest_id or is_chest_open(chest):
		return false
	_open_chest(chest)
	return true


## Случайная награда разыгрывается в момент открытия и живёт только в GameSession.
func _resolve_rewards(contents: Array[String], random_mode: bool, gold_amount: int, quantities: Dictionary = {}) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	if random_mode:
		rewards.append(ItemCatalog.roll_loot(trap_random))
	else:
		for item_id in contents:
			var item: ItemDefinition = ItemCatalog.get_item(item_id)
			if item == null:
				continue
			var fallback: int = gold_amount if item_id == "gold" else item.default_quantity
			var quantity: int = clampi(int(quantities.get(item_id, fallback)), 1, 999999 if item_id == "gold" else 9999)
			rewards.append({"item_id": item_id, "quantity": quantity})
	return rewards


func _open_chest(chest: Dictionary) -> void:
	opened_chests[str(chest["id"])] = true
	var rewards: Array[Dictionary] = _resolve_rewards(
		DungeonMap.chest_contents(chest),
		DungeonMap.chest_is_random(chest),
		DungeonMap.chest_gold_amount(chest),
		DungeonMap.chest_item_quantities(chest))
	for reward in rewards:
		_receive_item(str(reward["item_id"]), int(reward["quantity"]))
	_activate_message_at(Vector2i(int(chest["x"]), int(chest["y"])), "chest_open", str(chest["id"]), rewards)


## Общая логика подбора. Описание предмета — Resource, состояние находок — GameSession.
func _receive_item(item_id: String, quantity: int, durabilities: Array = []) -> int:
	if item_id == "key_yellow":
		item_id = "key"
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null or quantity <= 0 or hero == null:
		return 0
	if item.category == ItemDefinition.Category.CURRENCY:
		hero.gold += quantity
		return quantity
	var bag: Array[String] = _inventory_slots_snapshot()
	var equipped: Dictionary = _equipment_snapshot()
	var shield_layout: Dictionary = _shield_layout(bag, equipped)
	var received: int = 0
	var overflow_durabilities: Array = []
	for index in range(quantity):
		var location: String = ""
		if item.stackable and bag.has(item_id):
			location = "stack"
		elif not item.stackable and item.category == ItemDefinition.Category.EQUIPMENT:
			if item.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON and str(equipped["main_hand"]).is_empty():
				if not (item.two_handed and not str(equipped["off_hand"]).is_empty()):
					location = "equipment:main_hand"
			elif item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD and str(equipped["off_hand"]).is_empty():
				var weapon: ItemDefinition = ItemCatalog.get_item(str(equipped["main_hand"]))
				if weapon == null or not weapon.two_handed:
					location = "equipment:off_hand"
		if location.is_empty():
			var free: int = bag.find("")
			if free >= 0:
				location = "bag:%d" % free
				bag[free] = item_id
		if location.is_empty():
			if _is_shield(item_id):
				overflow_durabilities.append(int(durabilities[index]) if index < durabilities.size() else _new_shield_durability(item_id))
			continue
		if location.begins_with("equipment:"):
			equipped[location.trim_prefix("equipment:")] = item_id
		if _is_shield(item_id) and location != "stack":
			shield_layout[location] = int(durabilities[index]) if index < durabilities.size() else _new_shield_durability(item_id)
		received += 1
	if received > 0:
		carried_items[item_id] = int(carried_items.get(item_id, 0)) + received
		_inventory_order = bag
		hero.equipped_weapon_id = str(equipped["main_hand"])
		hero.equipped_shield_id = str(equipped["off_hand"])
		hero._recalculate_equipment_stats()
		if _is_shield(item_id):
			_apply_shield_layout(bag, equipped, shield_layout)
		keys = int(carried_items.get("key", 0))
		potions = int(carried_items.get("potion", 0))
	var overflow: int = quantity - received
	if overflow > 0:
		var entry: Dictionary = {"item_id": item_id, "quantity": overflow}
		if _is_shield(item_id):
			entry["durabilities"] = overflow_durabilities
		_append_ground_loot(player_pos, [entry])
	return received


## Боевой пояс: только расходники, применимые к бойцу вне исполнения фазы.
static func is_combat_item(item: ItemDefinition) -> bool:
	if item == null or item.category != ItemDefinition.Category.CONSUMABLE:
		return false
	return item.consumable_effect in [
		ItemDefinition.ConsumableEffect.HEAL,
		ItemDefinition.ConsumableEffect.ATTACK,
		ItemDefinition.ConsumableEffect.RESIST
	] or (item.consumable_effect == ItemDefinition.ConsumableEffect.NONE and item.healing_amount > 0)


func combat_item_ids() -> Array[String]:
	var result: Array[String] = []
	for key in carried_items:
		var item_id: String = str(key)
		if int(carried_items[item_id]) > 0 and is_combat_item(ItemCatalog.get_item(item_id)):
			result.append(item_id)
	result.sort()
	return result


## Применение через модель. Нельзя использовать предмет в момент проигрывания
## алгоритма; нельзя потратить один флакон дважды.
func use_combat_item(item_id: String, battle: BattleState) -> Dictionary:
	if battle == null or not battle.flow.can_use_item():
		return {"used": false, "message": "Сейчас предмет недоступен."}
	if hero == null or battle.get_hero() == null or battle.get_hero()._hero_snapshot == null:
		return {"used": false, "message": "Герой недоступен."}
	var definition: ItemDefinition = ItemCatalog.get_item(item_id)
	if not is_combat_item(definition):
		return {"used": false, "message": "Предмет нельзя использовать в бою."}
	var outcome: Dictionary = use_item(item_id)
	if bool(outcome.get("used", false)):
		battle.get_hero().sync_consumable_from_hero(hero)
		battle.events.append({"type": "item_used", "actor_id": battle.hero_id,
			"item_id": item_id, "message": outcome.get("message", "")})
	return outcome


## Инвентарь лишь запрашивает действие: предметы и здоровье изменяет игровая сессия.
## Снаряжение не расходуется при надевании.
func equip_item(item_id: String) -> bool:
	if hero == null or int(carried_items.get(item_id, 0)) <= 0:
		return false
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null or item.category != ItemDefinition.Category.EQUIPMENT:
		return false
	var bag: Array[String] = _inventory_slots_snapshot()
	var source: int = bag.find(item_id)
	if source < 0:
		return false
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if EquipmentSlotRules.accepts(slot_id, item) and equipment_item_id(slot_id).is_empty():
			if transfer_inventory_item("bag", source, "equipment", slot_id):
				return true
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if EquipmentSlotRules.accepts(slot_id, item) and equipment_item_id(slot_id) != item_id:
			if transfer_inventory_item("bag", source, "equipment", slot_id):
				return true
	return false


func unequip_item(item_id: String) -> bool:
	if hero == null or item_id.is_empty():
		return false
	var bag: Array[String] = _inventory_slots_snapshot()
	var free: int = bag.find("")
	if free < 0:
		return false
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		if equipment_item_id(slot_id) == item_id:
			return transfer_inventory_item("equipment", slot_id, "bag", free)
	return false


## Выполняется после ответной атаки; удаляем только сломанный экземпляр.
func resolve_broken_shield(member: HeroState = null) -> String:
	var owner: HeroState = member if member != null else hero
	if owner == null or owner.last_shield_broken.is_empty():
		return ""
	var item_id: String = owner.last_shield_broken
	owner.last_shield_broken = ""
	var count: int = int(carried_items.get(item_id, 0))
	if count > 0:
		carried_items[item_id] = count - 1
	return item_id


## Сообщение используется в самом окне инвентаря, не как всплывающий игровой диалог.
func use_item(item_id: String) -> Dictionary:
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	if item == null or int(carried_items.get(item_id, 0)) <= 0:
		return {"used": false, "message": "Этого предмета нет в рюкзаке."}
	if hero == null:
		return {"used": false, "message": "Герой недоступен."}
	var result: Dictionary = hero.apply_potion(item)
	if bool(result.get("used", false)):
		_remove_carried_item(item_id, 1)
		_refresh_visibility()
	return result


func _remove_carried_item(item_id: String, quantity: int) -> bool:
	var current: int = int(carried_items.get(item_id, 0))
	if quantity <= 0 or current < quantity:
		return false
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	var bag: Array[String] = _inventory_slots_snapshot()
	var shield_layout: Dictionary = _shield_layout(bag, _equipment_snapshot()) if hero != null and _is_shield(item_id) else {}
	var equipped_count: int = 0
	for member in party:
		for slot_id in EquipmentSlotRules.SLOT_IDS:
			if _member_equipment_id(member, slot_id) == item_id:
				equipped_count += 1
	if current - quantity < equipped_count:
		return false
	if item != null and not item.stackable:
		var count_in_bag: int = bag.count(item_id)
		if count_in_bag < quantity:
			return false
		for removed in range(mini(count_in_bag, quantity)):
			var index: int = bag.find(item_id)
			bag[index] = ""
			shield_layout.erase("bag:%d" % index)
	elif current == quantity:
		var index: int = bag.find(item_id)
		if index >= 0:
			bag[index] = ""
	carried_items[item_id] = current - quantity
	_inventory_order = bag
	if _is_shield(item_id) and hero != null:
		_apply_shield_layout(bag, _equipment_snapshot(), shield_layout)
	keys = int(carried_items.get("key", 0))
	potions = int(carried_items.get("potion", 0))
	return true


func _collect_pickups_at(cell: Vector2i) -> void:
	for entity in map_data.entities_at(cell.x, cell.y):
		if is_entity_removed(entity):
			continue
		var item_id: String = str(entity.get("type", ""))
		var item := ItemCatalog.get_item(item_id)
		if item == null:
			continue
		var quantity: int = ItemCatalog.quantity_for_entity(entity)
		var received: int = _receive_item(item_id, quantity)
		removed_entities[str(entity["id"])] = true
		if received > 0:
			var pickup_message := "Получено: %s ×%d" % [item.display_name, received]
			_append_event_message(pickup_message)


func set_debug_open_map(enabled: bool) -> void:
	if debug_open_map == enabled:
		return
	debug_open_map = enabled
	if not enabled:
		if _revealed_before_debug_open_map.size() == revealed.size():
			revealed = _revealed_before_debug_open_map.duplicate(true)
		_revealed_before_debug_open_map.clear()
	_refresh_visibility()


func _refresh_visibility() -> void:
	if debug_open_map and _revealed_before_debug_open_map.is_empty():
		_revealed_before_debug_open_map = revealed.duplicate(true)
	for y in range(map_data.height):
		for x in range(map_data.width):
			visible[y][x] = debug_open_map
			if debug_open_map:
				revealed[y][x] = true
	var radius: int = VISION_RADIUS + (hero.vision_bonus if hero != null and hero.has_vision_effect() else 0)
	if debug_open_map:
		for y in range(player_pos.y - radius, player_pos.y + radius + 1):
			for x in range(player_pos.x - radius, player_pos.x + radius + 1):
				if contains(x, y):
					_revealed_before_debug_open_map[y][x] = true
		return
	for y in range(player_pos.y - radius, player_pos.y + radius + 1):
		for x in range(player_pos.x - radius, player_pos.x + radius + 1):
			if contains(x, y):
				visible[y][x] = true
				revealed[y][x] = true


func _claim_exit_reward(stairs: Dictionary) -> void:
	var entity_id: String = str(stairs["id"])
	if claimed_exit_rewards.has(entity_id):
		return
	claimed_exit_rewards[entity_id] = true
	var rewards: Array[Dictionary] = _resolve_rewards(DungeonMap.chest_contents(stairs), false,
		DungeonMap.chest_gold_amount(stairs), DungeonMap.chest_item_quantities(stairs))
	for reward in rewards:
		_receive_item(str(reward["item_id"]), int(reward["quantity"]))
	if not rewards.is_empty():
		_message_events.append({"text": "Награда за прохождение подземелья", "activation": "exit_reward", "loot": rewards})


func progress_snapshot() -> Dictionary:
	if is_editor_test or map_data == null or has_pending_encounter() or not pending_chest_id.is_empty() or has_pending_door_trap() or is_completed:
		return {}
	var party_data: Dictionary = party_state_snapshot()
	if party_data.is_empty():
		return {}
	var floors_data: Dictionary = {}
	for map_id in visited_floor_snapshots():
		var snapshot: Dictionary = floor_state_snapshot(str(map_id))
		var source_map: DungeonMap = known_map(str(map_id))
		if source_map == null:
			return {}
		var encoded: Dictionary = ProgressSnapshotCodec.encode_floor(snapshot)
		encoded["map_signature"] = ProgressSnapshotCodec.map_signature(source_map)
		floors_data[str(map_id)] = encoded
	return {
		"version": ProgressSnapshotCodec.FORMAT_VERSION,
		"current_map_id": map_data.map_id,
		"party": party_data,
		"floors": floors_data,
		"ground_loot_counter": _ground_loot_counter,
		"stairs_history": _stairs_history.duplicate(true)
	}


static func from_progress_snapshot(snapshot: Variant, maps_by_id: Dictionary) -> GameSession:
	if not (snapshot is Dictionary) or not ProgressSnapshotCodec._is_integer(snapshot.get("version")):
		return null
	if int(snapshot["version"]) != ProgressSnapshotCodec.FORMAT_VERSION:
		return null
	var current_id: String = str(snapshot.get("current_map_id", ""))
	var floors_data: Variant = snapshot.get("floors")
	if current_id.is_empty() or not (floors_data is Dictionary) or not floors_data.has(current_id) or not (snapshot.get("party") is Dictionary):
		return null
	var counter_value: Variant = snapshot.get("ground_loot_counter")
	if not ProgressSnapshotCodec._is_integer(counter_value) or int(counter_value) < 0:
		return null
	var history_data: Variant = snapshot.get("stairs_history")
	if not (history_data is Array):
		return null
	var restored_history: Array[Dictionary] = []
	for record in history_data:
		if not (record is Dictionary):
			return null
		if typeof(record.get("from")) != TYPE_STRING or typeof(record.get("to")) != TYPE_STRING:
			return null
		var from_id: String = str(record["from"])
		var to_id: String = str(record["to"])
		if not maps_by_id.has(from_id) or not maps_by_id.has(to_id) or not (maps_by_id[from_id] is DungeonMap) or not (maps_by_id[to_id] is DungeonMap):
			return null
		var normalized: Dictionary = {"from": from_id, "to": to_id}
		if record.has("from_cell"):
			var coords: Variant = record["from_cell"]
			if not (coords is Array) or coords.size() != 2 or not ProgressSnapshotCodec._is_integer(coords[0]) or not ProgressSnapshotCodec._is_integer(coords[1]):
				return null
			normalized["from_cell"] = [int(coords[0]), int(coords[1])]
		if record.has("from_exit_id"):
			if typeof(record["from_exit_id"]) != TYPE_STRING or str(record["from_exit_id"]).is_empty():
				return null
			normalized["from_exit_id"] = record["from_exit_id"]
		restored_history.append(normalized)
	var restored_floors: Dictionary = {}
	for raw_map_id in floors_data:
		if typeof(raw_map_id) != TYPE_STRING or not maps_by_id.has(raw_map_id) or not (maps_by_id[raw_map_id] is DungeonMap):
			return null
		var map_ref: DungeonMap = maps_by_id[raw_map_id]
		if map_ref.map_id != raw_map_id or not DungeonMap.valid_arrival_cell(map_ref, map_ref.find_entity_position("player_spawn")):
			return null
		var raw_floor: Variant = floors_data[raw_map_id]
		if not (raw_floor is Dictionary):
			return null
		if raw_floor.has("map_signature"):
			if typeof(raw_floor["map_signature"]) != TYPE_STRING or str(raw_floor["map_signature"]) != ProgressSnapshotCodec.map_signature(map_ref):
				return null
		var floor_data: Dictionary = ProgressSnapshotCodec.decode_floor(raw_floor, map_ref)
		if floor_data.is_empty():
			return null
		floor_data["map"] = map_ref
		restored_floors[raw_map_id] = floor_data
	for record in restored_history:
		if not restored_floors.has(record["from"]) or not restored_floors.has(record["to"]):
			return null
		var origin: Dictionary = restored_floors[record["from"]]
		var origin_map: DungeonMap = origin["map"]
		var cell: Vector2i = _history_origin(record, origin["position"])
		if not _matching_return_stair(origin_map, cell, str(record.get("from_exit_id", "")), str(record["to"])):
			return null
		if not _return_cell_is_open(origin_map, cell, origin["removed"]):
			return null
		if not record.has("from_cell"):
			record["from_cell"] = [cell.x, cell.y]
		if not record.has("from_exit_id"):
			for entity in origin_map.entities_at(cell.x, cell.y):
				if str(entity.get("type", "")) == "stairs_down" and DungeonMap.exit_target_id(entity) == str(record["to"]):
					record["from_exit_id"] = str(entity["id"])
					break
	var ground_ids: Dictionary = {}
	for floor_id in restored_floors:
		for container in restored_floors[floor_id]["ground_loot"]:
			var container_id: String = str(container["id"])
			if ground_ids.has(container_id):
				return null
			ground_ids[container_id] = true
			if container_id.begins_with("ground_"):
				var counter_text: String = container_id.trim_prefix("ground_")
				if not counter_text.is_valid_int() or int(counter_text) > int(counter_value):
					return null
	var session := GameSession.new()
	if not session.restore_party_state(snapshot["party"]):
		return null
	var current: Dictionary = restored_floors[current_id]
	session.map_data = current["map"]
	session._floor_states = restored_floors.duplicate()
	session._floor_states.erase(current_id)
	session._stairs_history = restored_history
	session._ground_loot_counter = int(counter_value)
	session.player_pos = current["position"]
	for container in current["ground_loot"]:
		session.ground_loot_containers.append(container.duplicate(true))
	session.claimed_exit_rewards = current["exit_rewards"].duplicate(true)
	session.removed_entities = current["removed"].duplicate(true)
	session.opened_chests = current["chests"].duplicate(true)
	session.disarmed_traps = current["traps"].duplicate(true)
	session.revealed_traps = current["revealed_traps"].duplicate(true)
	session.activated_triggers = current["triggers"].duplicate(true)
	session.shown_messages = current["messages"].duplicate(true)
	session._init_masks()
	session.revealed = current["revealed"].duplicate(true)
	session._refresh_visibility()
	return session
