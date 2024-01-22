local config = {}

config.CRAFTING_FLUID_CATEGORY_NAME = "crafting-fluids"

--item name that electricity uses
config.ELECTRICITY_ITEM_NAME = "electricity"
config.ELECTRICITY_RATIO = 1000000 -- 1.000.000,  1 = 1MJ

config.INV_COMBINATOR_NAME = "subspace-resource-combinator"

config.MAX_FLUID_AMOUNT = 25000
config.TICKS_TO_COLLECT_REQUESTS = 40
config.TICKS_TO_FULFILL_REQUESTS = 20
config.TICKS_TO_COLLECT_AND_FULFILL_REQUESTS = config.TICKS_TO_COLLECT_REQUESTS + config.TICKS_TO_FULFILL_REQUESTS

config.NTH_TICK = 60 * 60

-- Entities which are not allowed to be placed outside the restriction zone
config.restrictedEntities = {
	["subspace-item-injector"] = true,
	["subspace-item-extractor"] = true,
	["subspace-fluid-injector"] = true,
	["subspace-fluid-extractor"] = true,
	["subspace-electricity-injector"] = true,
	["subspace-electricity-extractor"] = true,
}

return config