class_name DescriptionTemplate
extends RefCounted

const QUALITY_COLOR: Color = Color("#e6c99a")


static func numeric_values(resource: Resource, prefix: String = "") -> Dictionary:
	var values: Dictionary = {}
	if resource == null:
		return values
	for property in resource.get_property_list():
		if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (int(property["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var name: String = str(property["name"])
		var value: Variant = resource.get(name)
		if value is int or value is float:
			values[prefix + name] = value
	return values


static func number(value: Variant) -> String:
	if value is float:
		if is_equal_approx(value, roundf(value)):
			return str(roundi(value))
		return str(value).replace(".", ",")
	return str(value)


static func render(template: String, values: Dictionary) -> String:
	var formatted: Dictionary = {}
	for key in values:
		formatted[key] = number(values[key])
	return template.format(formatted)


static func unresolved_tokens(text: String) -> PackedStringArray:
	var pattern := RegEx.new()
	pattern.compile("\\{[a-zA-Z_][a-zA-Z_0-9]*\\}")
	var result := PackedStringArray()
	for token in pattern.search_all(text):
		result.append(token.get_string())
	return result


static func escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]")


static func colored(value: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), escape_bbcode(value)]


static func equipment_value(item: ItemDefinition, instance: ItemInstance, field: String, value: String, rich: bool = false) -> String:
	if rich and ItemMagicCatalog.quality_value(item, instance, field) > ItemMagicCatalog.quality_value(item, null, field):
		return colored(value, QUALITY_COLOR)
	return value


static func equipment_properties(item: ItemDefinition, instance: ItemInstance = null, rich: bool = false) -> PackedStringArray:
	var lines := PackedStringArray()
	if item == null:
		return lines
	for key in CharacterStats.EQUIPMENT_FIELDS:
		var value: int = ItemMagicCatalog.effective_value(item, instance, key)
		if value == 0:
			continue
		var suffix: String = " п.п." if key in ["dodge_bonus_percent", "accuracy_bonus_percent"] else ("%" if key == "poison_resistance_percent" else "")
		var formatted: String = ("+" if value > 0 else "") + number(value) + suffix
		lines.append("%s: %s" % [CharacterStats.EQUIPMENT_LABELS[key], equipment_value(item, instance, key, formatted, rich)])
	var damage: int = ItemMagicCatalog.effective_value(item, instance, "weapon_damage")
	if damage > 0:
		lines.append("Урон оружия: %s (%s)" % [equipment_value(item, instance, "weapon_damage", number(damage), rich), "дальний" if item.weapon_kind == ItemDefinition.WeaponKind.RANGED else "ближний"])
	var block: int = ItemMagicCatalog.effective_value(item, instance, "defense_bonus")
	if block > 0:
		lines.append("Блок: %s" % equipment_value(item, instance, "defense_bonus", "+" + number(block), rich))
	var maximum: int = ItemMagicCatalog.effective_value(item, instance, "max_durability")
	if maximum > 0:
		var current: int = instance.durability if instance != null else maximum
		lines.append("Прочность: %d / %s" % [current, equipment_value(item, instance, "max_durability", number(maximum), rich)])
	return lines


static func comparison(before: Dictionary, after: Dictionary) -> PackedStringArray:
	var changes := PackedStringArray()
	for key in CharacterStats.COMPARISON_FIELDS:
		var delta: float = float(after.get(key, 0)) - float(before.get(key, 0))
		if is_zero_approx(delta):
			continue
		var suffix: String = " п.п." if key in CharacterStats.PERCENT_FIELDS else ""
		changes.append("%s: %s%s%s" % [CharacterStats.COMPARISON_LABELS[key], "+" if delta > 0 else "", number(delta), suffix])
	return changes


static func comparison_details(before: Dictionary, after: Dictionary) -> PackedStringArray:
	var changes := PackedStringArray()
	for key in CharacterStats.COMPARISON_FIELDS:
		var previous: float = float(before.get(key, 0))
		var proposed: float = float(after.get(key, 0))
		var delta: float = proposed - previous
		if is_zero_approx(delta):
			continue
		var suffix: String = " п.п." if key in CharacterStats.PERCENT_FIELDS else ""
		changes.append("%s: %s%s → %s%s (%s%s%s)" % [
			CharacterStats.COMPARISON_LABELS[key], number(previous), suffix,
			number(proposed), suffix, "+" if delta > 0 else "", number(delta), suffix
		])
	return changes


static func quantity(value: int, singular: String, few: String, many: String) -> String:
	var last: int = absi(value) % 10
	var last_pair: int = absi(value) % 100
	var word: String = many
	if last_pair < 11 or last_pair > 14:
		if last == 1:
			word = singular
		elif last >= 2 and last <= 4:
			word = few
	return "%d %s" % [value, word]


static func phases(value: int) -> String:
	return quantity(value, "фазу", "фазы", "фаз")
