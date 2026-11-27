extends RefCounted


static func definition(hero_id: String) -> HeroDefinition:
	var hero: HeroDefinition = HeroCatalog.get_hero(hero_id).duplicate() as HeroDefinition
	hero.unlocked_personal_ability_count = hero.personal_ability_ids.size()
	return hero
