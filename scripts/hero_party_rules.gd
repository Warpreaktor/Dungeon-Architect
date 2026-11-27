class_name HeroPartyRules
extends RefCounted

const METADATA_KEY := "hero_party"
const MAX_PARTY_SIZE: int = 4

var restricted := false
var allowed_ids: Array[String] = []
var required_ids: Array[String] = []


static func from_metadata(metadata: Dictionary) -> HeroPartyRules:
	var rules := HeroPartyRules.new()
	if not metadata.has(METADATA_KEY):
		return rules
	var raw: Variant = metadata[METADATA_KEY]
	if not (raw is Dictionary):
		return null
	var allowed: Variant = raw.get("allowed_ids")
	var required: Variant = raw.get("required_ids", [])
	if not (allowed is Array) or allowed.is_empty() or not (required is Array) or required.size() > MAX_PARTY_SIZE:
		return null
	for id in allowed:
		if not (id is String) or not HeroCatalog.has(id) or rules.allowed_ids.has(id):
			return null
		rules.allowed_ids.append(id)
	for id in required:
		if not (id is String) or not rules.allowed_ids.has(id) or rules.required_ids.has(id):
			return null
		rules.required_ids.append(id)
	rules.restricted = true
	return rules


func allows(hero_id: String) -> bool:
	return not restricted or allowed_ids.has(hero_id)


func capacity() -> int:
	return mini(MAX_PARTY_SIZE, allowed_ids.size()) if restricted else MAX_PARTY_SIZE


func accepts_party(ids: Array[String]) -> bool:
	if ids.is_empty() or ids.size() > capacity():
		return false
	var seen: Dictionary = {}
	for id in ids:
		if not allows(id) or seen.has(id):
			return false
		seen[id] = true
	for id in required_ids:
		if not seen.has(id):
			return false
	return true
