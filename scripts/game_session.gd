class_name GameSession
extends RefCounted

## Состояние конкретного прохождения карты. Не изменяет саму карту.

const VISION_RADIUS := 1
## Число одновременных портретов в походном интерфейсе.
const MAX_PARTY_SIZE: int = 4
const INVENTORY_SLOT_COUNT: int = 40

var map_data: DungeonMap
var hero: HeroState
var party: Array[HeroState] = []
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
var activated_triggers: Dictionary = {} # ID сработавших триггеров; обнуляется с новой сессией.
var shown_messages: Dictionary = {} # Авторские сообщения показываются один раз за прохождение.
var _message_events: Array[Dictionary] = []
var _trigger_events: Array[Dictionary] = [] # События последнего хода для игрового контроллера.
var last_event_message: String = ""
var encounter_monster_id: String = ""
var encounter_target := Vector2i(-1, -1)
var debug_open_map: bool = false # Только для теста редактора, никогда не сериализуется.
var revealed: Array = [] # revealed[y][x] = bool
var visible: Array = []  # visible[y][x] = bool
var fallen_encounters: Array = []
var claimed_exit_rewards: Dictionary = {}
var _next_fallen_id: int = 0
var _death_recorded: bool = false
var _floor_states: Dictionary = {} # Состояние посещённых карт только в памяти этого прохождения.



static func start_for(map_ref: DungeonMap, hero_id: String = HeroCatalog.DEFAULT_HERO_ID, open_map: bool = false) -> GameSession:
	if map_ref == null:
		return null
	var spawn := map_ref.find_entity_position("player_spawn")
	if spawn.x < 0 or spawn.y < 0:
		return null
	var session := GameSession.new()
	session.map_data = map_ref
	session.hero = HeroState.new(HeroCatalog.get_hero(hero_id))
	session.party.append(session.hero)
	session.trap_random.randomize()
	session.player_pos = spawn
	session.debug_open_map = open_map
	session._init_masks()
	session._refresh_visibility()
	session._collect_pickups_at(spawn)
	session._activate_triggers_at(spawn)
	session._activate_message_at(spawn, "enter")
	return session


func inventory_slot_ids() -> Array[String]:
	if _inventory_order.size() != INVENTORY_SLOT_COUNT:
		_inventory_order.resize(INVENTORY_SLOT_COUNT)
		_inventory_order.fill("")
	var remaining: Dictionary = {}
	for key in carried_items:
		var item_id: String = str(key)
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item == null:
			continue
		var count: int = int(carried_items[key])
		if count > 0:
			remaining[item_id] = 1 if item.stackable else count
	for index in range(_inventory_order.size()):
		var item_id: String = _inventory_order[index]
		if item_id.is_empty():
			continue
		var count: int = int(remaining.get(item_id, 0))
		if count > 0:
			remaining[item_id] = count - 1
		else:
			_inventory_order[index] = ""
	var ids: Array[String] = []
	for key in remaining:
		ids.append(str(key))
	ids.sort()
	for item_id in ids:
		for entry in range(int(remaining[item_id])):
			var empty_index: int = _inventory_order.find("")
			if empty_index < 0:
				break
			_inventory_order[empty_index] = item_id
	return _inventory_order.duplicate()


func swap_inventory_slots(source: int, destination: int) -> bool:
	if source < 0 or source >= INVENTORY_SLOT_COUNT or destination < 0 or destination >= INVENTORY_SLOT_COUNT:
		return false
	inventory_slot_ids()
	if _inventory_order[source].is_empty():
		return false
	var existing: String = _inventory_order[destination]
	_inventory_order[destination] = _inventory_order[source]
	_inventory_order[source] = existing
	return true


func party_members() -> Array[HeroState]:
	if party.is_empty():
		var fallback: Array[HeroState] = []
		if hero != null:
			fallback.append(hero)
		return fallback
	var result: Array[HeroState] = []
	result.append_array(party)
	return result


func add_party_member(hero_id: String) -> bool:
	if not HeroCatalog.has(hero_id):
		return false
	if party.is_empty() and hero != null:
		party.append(hero)
	if party.size() >= MAX_PARTY_SIZE:
		return false
	var member := HeroState.new(HeroCatalog.get_hero(hero_id))
	party.append(member)
	if hero == null:
		hero = member
	return true


func is_party_defeated() -> bool:
	for member in party_members():
		if member != null and member.health > 0:
			return false
	return true


func _update_active_hero() -> void:
	if hero != null and hero.health > 0:
		return
	for member in party_members():
		if member != null and member.health > 0:
			hero = member
			return


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
	_party_damage_events.append({"hero_index": index, "damage": damage, "source": source})


func _random_living_party_member() -> HeroState:
	var living: Array[HeroState] = []
	for member in party_members():
		if member != null and member.health > 0:
			living.append(member)
	if living.is_empty():
		return null
	return living[trap_random.randi_range(0, living.size() - 1)]


## Переход между этажами без пересоздания героя и инвентаря.
## Повторное посещение восстанавливает открытые двери, сундуки и исследованные клетки.
func enter_map(next_map: DungeonMap) -> bool:
	if next_map == null or next_map.map_id.is_empty():
		return false
	var spawn := next_map.find_entity_position("player_spawn")
	if spawn.x < 0 or spawn.y < 0 or next_map.get_terrain(spawn.x, spawn.y) == "wall":
		return false
	if map_data != null:
		_floor_states[map_data.map_id] = {
			"map": map_data,
			"fallen": fallen_encounters.duplicate(true),
			"exit_rewards": claimed_exit_rewards.duplicate(true),
			"position": player_pos,
			"removed": removed_entities.duplicate(true),
			"chests": opened_chests.duplicate(true),
			"traps": disarmed_traps.duplicate(true),
			"revealed_traps": revealed_traps.duplicate(true),
			"triggers": activated_triggers.duplicate(true),
			"messages": shown_messages.duplicate(true),
			"revealed": revealed.duplicate(true)
		}
	var saved: Dictionary = _floor_states.get(next_map.map_id, {})
	map_data = saved.get("map", next_map)
	fallen_encounters = saved.get("fallen", []).duplicate(true)
	claimed_exit_rewards = saved.get("exit_rewards", {}).duplicate(true)
	player_pos = saved.get("position", spawn)
	removed_entities = saved.get("removed", {}).duplicate(true)
	opened_chests = saved.get("chests", {}).duplicate(true)
	disarmed_traps = saved.get("traps", {}).duplicate(true)
	revealed_traps = saved.get("revealed_traps", {}).duplicate(true)
	pending_chest_id = ""
	activated_triggers = saved.get("triggers", {}).duplicate(true)
	shown_messages = saved.get("messages", {}).duplicate(true)
	encounter_monster_id = ""
	encounter_target = Vector2i(-1, -1)
	is_completed = false
	last_event_message = ""
	_message_events.clear()
	_trigger_events.clear()
	_party_damage_events.clear()
	_init_masks()
	if saved.has("revealed"):
		revealed = saved["revealed"].duplicate(true)
	else:
		_collect_pickups_at(player_pos)
		_activate_triggers_at(player_pos)
		_activate_message_at(player_pos, "enter")
	_refresh_visibility()
	return true


func next_map_id() -> String:
	if not is_completed:
		return ""
	var stairs := _find_active_entity(player_pos, "stairs_down")
	if stairs.is_empty():
		return ""
	return DungeonMap.stairs_target_id(stairs)


func _init_masks() -> void:
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
	for entity in fallen_encounters:
		if int(entity["x"]) == x and int(entity["y"]) == y:
			result.append(entity)
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
	for entity in map_data.entities + fallen_encounters:
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
	if not has_pending_encounter() or hero == null or hero.health <= 0:
		return false
	var target: Vector2i = encounter_target
	var defeated_id: String = encounter_monster_id
	var defeated: Dictionary = {}
	for entity in map_data.entities + fallen_encounters:
		if str(entity.get("id", "")) == defeated_id and str(entity.get("type", "")) == "monster":
			defeated = entity
			break
	removed_entities[defeated_id] = true
	if defeated.has("fallen_rewards"):
		fallen_encounters.erase(defeated)
	encounter_monster_id = ""
	encounter_target = Vector2i(-1, -1)
	var rewards: Array[Dictionary] = []
	if not defeated.is_empty():
		if defeated.has("fallen_rewards"):
			rewards.assign(defeated["fallen_rewards"])
		else:
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


func _activate_traps_at(cell: Vector2i) -> void:
	for entity in map_data.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) != "trap" or is_trap_disarmed(entity):
			continue
		var trap: TrapDefinition = TrapCatalog.from_entity(entity)
		if trap == null:
			continue
		var target: HeroState = _random_living_party_member()
		if target == null:
			continue
		revealed_traps[str(entity.get("id", ""))] = true
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
					trap.overworld_status_label,
					trap.overworld_status_damage,
					trap.overworld_status_ticks
				])
		if not parts.is_empty():
			_append_event_message("%s: ловушка «%s», %s." % [
				target.definition.display_name, trap.display_name, " и ".join(parts)
			])
		if trap.disarm_on_trigger:
			disarmed_traps[str(entity.get("id", ""))] = true


func can_enter(cell: Vector2i) -> bool:
	return contains(cell.x, cell.y) and map_data.get_terrain(cell.x, cell.y) != "wall"


func move_by(dx: int, dy: int, defer_chest_open: bool = false) -> bool:
	last_event_message = ""
	_trigger_events.clear()
	_party_damage_events.clear()
	if is_party_defeated() or has_pending_encounter() or is_completed or not pending_chest_id.is_empty():
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

	player_pos = target
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
	_update_active_hero()
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
	# Пока лестница завершает приключение. Позже здесь появится переход на другую карту.
	var stairs: Dictionary = _find_active_entity(target, "stairs_down")
	if not stairs.is_empty():
		_claim_exit_reward(stairs)
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
		rewards.append(ItemCatalog.roll_loot())
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
func _receive_item(item_id: String, quantity: int, durabilities: Array = []) -> void:
	if item_id == "key_yellow":
		item_id = "key"
	var item := ItemCatalog.get_item(item_id)
	if item == null or quantity <= 0:
		return
	if item.category == ItemDefinition.Category.CURRENCY:
		hero.gold += quantity
	else:
		carried_items[item_id] = int(carried_items.get(item_id, 0)) + quantity
		if item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD:
			for index in range(quantity):
				if index < durabilities.size():
					var values: Array = hero.shield_durabilities.get(item_id, [])
					values.append(int(durabilities[index]))
					hero.shield_durabilities[item_id] = values
				else:
					hero.register_shield(item)
		if item.category == ItemDefinition.Category.EQUIPMENT:
			# Первая находка заполняет пустой слот; следующую можно надеть вручную.
			if item.equipment_slot == ItemDefinition.EquipmentSlot.WEAPON and hero.equipped_weapon_id.is_empty():
				hero.equip_item(item)
			elif item.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD and hero.equipped_shield_id.is_empty():
				hero.equip_item(item)
		keys = int(carried_items.get("key", 0))
		potions = int(carried_items.get("potion", 0))


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
## Снаряжение остаётся в рюкзаке и не расходуется при надевании.
func equip_item(item_id: String) -> bool:
	if hero == null or int(carried_items.get(item_id, 0)) <= 0:
		return false
	return hero.equip_item(ItemCatalog.get_item(item_id))


func unequip_item(item_id: String) -> bool:
	if hero == null:
		return false
	return hero.unequip_item(item_id)


## Выполняется после ответной атаки; удаляем только сломанный экземпляр.
func resolve_broken_shield() -> String:
	if hero == null or hero.last_shield_broken.is_empty():
		return ""
	var item_id: String = hero.last_shield_broken
	hero.last_shield_broken = ""
	_remove_carried_item(item_id, 1)
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
	carried_items[item_id] = current - quantity
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
		_receive_item(item_id, quantity)
		removed_entities[str(entity["id"])] = true
		# Это запись в свёрнутую техническую консоль, не всплывающее игровое сообщение.
		var pickup_message := "Получено: %s ×%d" % [item.display_name, quantity]
		_append_event_message(pickup_message)


func _refresh_visibility() -> void:
	for y in range(map_data.height):
		for x in range(map_data.width):
			visible[y][x] = debug_open_map
			if debug_open_map:
				revealed[y][x] = true
	if debug_open_map:
		return
	var radius: int = VISION_RADIUS + (hero.vision_bonus if hero != null and hero.has_vision_effect() else 0)
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


func _fallen_loot() -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var gold: int = 0
	for member in party_members():
		gold += member.gold
	if gold > 0:
		rewards.append({"item_id": "gold", "quantity": gold})
	for item_id in carried_items:
		var quantity: int = int(carried_items[item_id])
		if quantity <= 0:
			continue
		var reward: Dictionary = {"item_id": item_id, "quantity": quantity}
		var values: Array = []
		for member in party_members():
			values.append_array(member.shield_durabilities.get(item_id, []))
		if not values.is_empty():
			reward["durabilities"] = values.slice(0, quantity)
		rewards.append(reward)
	return rewards


func _fallen_slot(cell: Vector2i, spawn: Vector2i) -> Dictionary:
	if not can_enter(cell) or not _find_active_entity(cell, "door").is_empty():
		return {}
	var monster: Dictionary = _find_active_entity(cell, "monster")
	if not monster.is_empty():
		if monster.has("fallen_rewards") and DungeonMap.monster_party_ids(monster).size() < DungeonMap.MAX_MONSTERS_PER_ENCOUNTER:
			return {"entity": monster}
		return {}
	if cell == spawn:
		return {}
	return {"cell": cell}


func _nearest_fallen_slot(origin: Vector2i, spawn: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [origin]
	var visited: Dictionary = {}
	visited[origin] = true
	var cursor: int = 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		var slot: Dictionary = _fallen_slot(cell, spawn)
		if not slot.is_empty():
			return slot
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor: Vector2i = cell + direction
			if visited.has(neighbor) or not can_enter(neighbor) or not _find_active_entity(neighbor, "door").is_empty():
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	if visited.has(spawn):
		return _fallen_slot(spawn, Vector2i(-1, -1))
	return {}


func record_defeat() -> bool:
	if _death_recorded:
		return true
	if hero == null or hero.health > 0:
		return false
	var spawn: Vector2i = map_data.find_entity_position("player_spawn")
	var original: Array = fallen_encounters.duplicate(true)
	var original_counter: int = _next_fallen_id
	var rewards: Array[Dictionary] = _fallen_loot()
	for index in range(party_members().size()):
		var slot: Dictionary = _nearest_fallen_slot(player_pos, spawn)
		if slot.is_empty():
			fallen_encounters = original
			_next_fallen_id = original_counter
			return false
		var encounter: Dictionary
		if slot.has("entity"):
			encounter = slot["entity"]
			var properties: Dictionary = encounter["properties"]
			var extra: Array = properties.get("monster_ids", [])
			extra.append("skeleton")
			properties["monster_ids"] = extra
		else:
			var cell: Vector2i = slot["cell"]
			_next_fallen_id += 1
			encounter = {"id": "fallen_%d" % _next_fallen_id, "type": "monster", "x": cell.x, "y": cell.y,
				"properties": {"monster_id": "skeleton", "loot_mode": "fixed"}, "fallen_rewards": []}
			fallen_encounters.append(encounter)
		if index == 0:
			encounter["fallen_rewards"].append_array(rewards)
	carried_items.clear()
	_inventory_order.clear()
	keys = 0
	potions = 0
	for member in party_members():
		member.gold = 0
		member.unequip_item(member.equipped_weapon_id)
		member.unequip_item(member.equipped_shield_id)
		member.shield_durabilities.clear()
	_death_recorded = true
	return true


func resurrect_party() -> bool:
	if not _death_recorded and not record_defeat():
		return false
	var spawn: Vector2i = map_data.find_entity_position("player_spawn")
	if not can_enter(spawn):
		return false
	var restored: Array[HeroState] = []
	for member in party_members():
		var fresh := HeroState.new(member.definition)
		fresh.learned_ability_ids.assign(member.learned_ability_ids)
		fresh.saved_action_slots.assign(member.saved_action_slots)
		restored.append(fresh)
	party = restored
	hero = party[0]
	player_pos = spawn
	encounter_monster_id = ""
	encounter_target = Vector2i(-1, -1)
	pending_chest_id = ""
	is_completed = false
	_death_recorded = false
	_message_events.clear()
	_trigger_events.clear()
	_party_damage_events.clear()
	last_event_message = ""
	_refresh_visibility()
	return true
