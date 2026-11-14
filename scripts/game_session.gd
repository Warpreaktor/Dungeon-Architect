class_name GameSession
extends RefCounted

## Состояние конкретного прохождения карты. Не изменяет саму карту.

const VISION_RADIUS := 1

var map_data: DungeonMap
var hero: HeroState
var player_pos := Vector2i(-1, -1)
var steps: int = 0
var keys: int = 0
var potions: int = 0
var carried_items: Dictionary = {} # Количество найденных предметов по ID, без интерфейса инвентаря.
var is_completed: bool = false # Выход достигнут в текущем прохождении.
var removed_entities: Dictionary = {} # ID объектов, исчезнувших только в этом прохождении.
var opened_chests: Dictionary = {} # ID открытых сундуков только в этом прохождении.
var activated_triggers: Dictionary = {} # ID сработавших триггеров; обнуляется с новой сессией.
var shown_messages: Dictionary = {} # Авторские сообщения показываются один раз за прохождение.
var _message_events: Array[Dictionary] = []
var _trigger_events: Array[Dictionary] = [] # События последнего хода для игрового контроллера.
var last_event_message: String = ""
var encounter_monster_id: String = ""
var encounter_target := Vector2i(-1, -1)
var revealed: Array = [] # revealed[y][x] = bool
var visible: Array = []  # visible[y][x] = bool


static func start_for(map_ref: DungeonMap) -> GameSession:
	if map_ref == null:
		return null
	var spawn := map_ref.find_entity_position("player_spawn")
	if spawn.x < 0 or spawn.y < 0:
		return null
	var session := GameSession.new()
	session.map_data = map_ref
	session.hero = HeroState.new()
	session.player_pos = spawn
	session._init_masks()
	session._refresh_visibility()
	session._collect_pickups_at(spawn)
	session._activate_triggers_at(spawn)
	session._activate_message_at(spawn, "enter")
	return session


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


func _find_active_entity(cell: Vector2i, kind: String) -> Dictionary:
	for entity in map_data.entities_at(cell.x, cell.y):
		if str(entity["type"]) == kind and not is_entity_removed(entity):
			return entity
	return {}


func has_pending_encounter() -> bool:
	return not encounter_monster_id.is_empty()


## Победа снимает монстра только в сессии, затем повторяет вход в клетку
## через обычные правила дверей, сундуков и находок.
func win_pending_encounter() -> bool:
	if not has_pending_encounter():
		return false
	var target := encounter_target
	removed_entities[encounter_monster_id] = true
	encounter_monster_id = ""
	encounter_target = Vector2i(-1, -1)
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


func _activate_message_at(cell: Vector2i, activation: String, door_id: String = "") -> void:
	var message := map_data.message_at(cell.x, cell.y)
	if message.is_empty():
		return
	var message_id := str(message.get("id", ""))
	if shown_messages.has(message_id):
		return
	var properties: Dictionary = message.get("properties", {})
	if str(properties.get("activation", "enter")) != activation:
		return
	if activation == "door_open" and str(properties.get("target_entity_id", "")) != door_id:
		return
	var text := str(properties.get("text", "")).strip_edges()
	if text.is_empty():
		return
	shown_messages[message_id] = true
	_message_events.append({"text": text, "activation": activation})


func can_enter(cell: Vector2i) -> bool:
	return contains(cell.x, cell.y) and map_data.get_terrain(cell.x, cell.y) != "wall"


func move_by(dx: int, dy: int) -> bool:
	last_event_message = ""
	_trigger_events.clear()
	if has_pending_encounter() or is_completed:
		return false
	var target := player_pos + Vector2i(dx, dy)
	if not can_enter(target):
		return false

	# Встреча инициирует поединок. Монстр исчезнет только после победы.
	var monster := _find_active_entity(target, "monster")
	if not monster.is_empty():
		encounter_monster_id = str(monster["id"])
		encounter_target = target
		return false

	var chest := _find_active_entity(target, "chest")
	if not chest.is_empty() and not is_chest_open(chest) and not DungeonMap.chest_contents(chest).is_empty():
		_open_chest(chest)
		return false # Открытие занимает попытку шага, герой остаётся рядом.

	var door := _find_active_entity(target, "door")
	var opened_door_id := ""
	if not door.is_empty():
		if keys <= 0:
			last_event_message = "Дверь заперта. Нужен ключ."
			return false
		_remove_carried_item("key", 1)
		opened_door_id = str(door["id"])
		removed_entities[opened_door_id] = true
		last_event_message = "Ключ использован. Дверь открыта!"

	player_pos = target
	steps += 1
	_collect_pickups_at(target)
	_activate_triggers_at(target)
	if not opened_door_id.is_empty():
		_activate_message_at(target, "door_open", opened_door_id)
	else:
		_activate_message_at(target, "enter")
	_refresh_visibility()
	# Пока лестница завершает приключение. Позже здесь появится переход на другую карту.
	if not _find_active_entity(target, "stairs_down").is_empty():
		is_completed = true
	return true


func _open_chest(chest: Dictionary) -> void:
	opened_chests[str(chest["id"])] = true
	var contents: Array[String] = DungeonMap.chest_contents(chest)
	var reward_names: PackedStringArray = []
	for item_id in contents:
		var item := ItemCatalog.get_item(item_id)
		if item == null:
			continue
		var quantity: int = DungeonMap.chest_gold_amount(chest) if item_id == "gold" else item.default_quantity
		_receive_item(item_id, quantity)
		if item.category == ItemDefinition.Category.CURRENCY:
			reward_names.append("%d монет" % quantity)
		else:
			reward_names.append(item.display_name.to_lower())
	if not reward_names.is_empty():
		last_event_message = "В сундуке: %s." % ", ".join(reward_names)


## Общая логика подбора. Описание предмета — Resource, состояние находок — GameSession.
func _receive_item(item_id: String, quantity: int) -> void:
	var item := ItemCatalog.get_item(item_id)
	if item == null or quantity <= 0:
		return
	if item.category == ItemDefinition.Category.CURRENCY:
		hero.gold += quantity
	else:
		carried_items[item_id] = int(carried_items.get(item_id, 0)) + quantity
		if item.item_id == "sword":
			hero.equip_weapon(item)
		keys = int(carried_items.get("key", 0))
		potions = int(carried_items.get("potion", 0))


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
		if last_event_message.is_empty():
			last_event_message = pickup_message
		else:
			last_event_message += "  " + pickup_message


func _refresh_visibility() -> void:
	for y in range(map_data.height):
		for x in range(map_data.width):
			visible[y][x] = false
	for y in range(player_pos.y - VISION_RADIUS, player_pos.y + VISION_RADIUS + 1):
		for x in range(player_pos.x - VISION_RADIUS, player_pos.x + VISION_RADIUS + 1):
			if contains(x, y):
				visible[y][x] = true
				revealed[y][x] = true
