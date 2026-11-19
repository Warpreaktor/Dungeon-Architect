class_name BattleCombatLog
extends RefCounted

## Короткие строки для существующей консоли. Только отображение уже
## рассчитанных событий: никаких изменений HP, повторных формул или RNG.


static func participant_name(participant_id: String, hero_name: String, enemy_name: String) -> String:
	match participant_id:
		"hero":
			return hero_name
		"enemy":
			return enemy_name
	return participant_id


static func ability_name(ability_id: String) -> String:
	var definition: AbilityDefinition = AbilityCatalog.get_ability(ability_id)
	return definition.display_name if definition != null else ability_id


static func format_event(event: Dictionary, hero_name: String, enemy_name: String) -> String:
	var kind: String = str(event.get("type", ""))
	var actor: String = participant_name(str(event.get("actor_id", "")), hero_name, enemy_name)
	var target: String = participant_name(str(event.get("target_id", "")), hero_name, enemy_name)
	match kind:
		"tick":
			return "  Такт %d" % int(event.get("tick", 0))
		"attack":
			if bool(event.get("dodged", false)):
				return "    %s → %s: %s, уклонение" % [actor, target,
					ability_name(str(event.get("ability_id", "")))]
			var parts: Array[String] = []
			parts.append("HP −%d (%d/%d)" % [int(event.get("damage", 0)),
				int(event.get("hp_after", 0)), int(event.get("hp_max", 0))])
			var absorbed: int = int(event.get("block_absorbed", 0))
			if absorbed > 0:
				parts.append("блок −%d" % absorbed)
			var armor: int = int(event.get("armor_after", 0))
			if armor > 0:
				parts.append("броня %d" % armor)
			var durability: int = int(event.get("shield_durability_after", -1))
			if durability >= 0:
				parts.append("прочность щита %d" % durability)
			if not str(event.get("shield_broken", "")).is_empty():
				parts.append("щит разбит")
			return "    %s → %s: %s, %s" % [actor, target,
				ability_name(str(event.get("ability_id", ""))), ", ".join(parts)]
		"block":
			return "    %s: %s (защита %d, следующий удар +%d%%)" % [actor,
				ability_name(str(event.get("ability_id", ""))),
				int(event.get("armor", 0)), int(event.get("damage_bonus_percent", 0))]
		"heal":
			return "    %s: %s, +%d HP (%d/%d)" % [actor,
				ability_name(str(event.get("ability_id", ""))), int(event.get("healed", 0)),
				int(event.get("hp_after", 0)), int(event.get("hp_max", 0))]
		"reload":
			return "    %s: Отдых" % actor
		"failed":
			return "    %s: %s не сработал (%s), отдых" % [actor,
				ability_name(str(event.get("ability_id", ""))), str(event.get("reason", "недоступно"))]
		"status_applied":
			return "    %s: %s → %s, эффект %s" % [actor,
				ability_name(str(event.get("ability_id", ""))), target,
				str(event.get("status_id", ""))]
		"status_removed":
			return "    %s: %s, снят эффект %s" % [actor,
				ability_name(str(event.get("ability_id", ""))), str(event.get("status_id", ""))]
		"resource_spent":
			return "    %s: расход %s −%d (осталось %d)" % [actor,
				str(event.get("resource_id", "")), int(event.get("amount", 0)),
				int(event.get("remaining", 0))]
		"wait":
			return "    %s: пропуск действия" % actor
	return ""
