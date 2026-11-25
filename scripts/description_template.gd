class_name DescriptionTemplate
extends RefCounted


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


static func equipment_properties(item: Resource) -> PackedStringArray:
	var labels: Dictionary = {
		"armor_bonus": "Броня",
		"health_bonus": "HP",
		"strength_bonus": "Сила",
		"agility_bonus": "Ловкость",
		"perception_bonus": "Чутьё",
		"dodge_bonus_percent": "Уклонение",
		"accuracy_bonus_percent": "Меткость",
		"poison_resistance_percent": "Сопротивление яду"
	}
	var lines := PackedStringArray()
	for key in labels:
		var value: int = int(item.get(key))
		if value == 0:
			continue
		var suffix: String = " п.п." if key in ["dodge_bonus_percent", "accuracy_bonus_percent"] else ("%" if key == "poison_resistance_percent" else "")
		lines.append("%s: %s%d%s" % [labels[key], "+" if value > 0 else "", value, suffix])
	return lines


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
