extends SceneTree


func _initialize() -> void:
	for hero_id in HeroCatalog.list_ids():
		var definition: HeroDefinition = HeroCatalog.get_hero(hero_id)
		assert(definition.hero_id == hero_id)
		assert(not definition.display_name.strip_edges().is_empty())
		var state := HeroState.new(definition)
		var snapshot: Dictionary = state.to_snapshot()
		assert(snapshot["hero_id"] == hero_id)
		assert(not snapshot.has("display_name"))
		var original_name: String = definition.display_name
		var changed_name: String = original_name + " II"
		definition.display_name = changed_name
		var restored: HeroState = HeroState.from_snapshot(snapshot)
		var uses_current_name: bool = restored != null and restored.definition == definition and restored.definition.display_name == changed_name
		definition.display_name = original_name
		assert(uses_current_name)
	quit()
