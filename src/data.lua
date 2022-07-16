require("util")
require("config")

require("prototypes/entities")


--adds a recipe to a tech and returns true or if that fails returns false
function AddEntityToTech(techName, name)
	--can't add the recipe to the tech if it doesn't exist
	if data.raw["technology"][techName] ~= nil then
		local effects = data.raw["technology"][techName].effects
		--if another mod removed the effects or made it nil then make a new table to put the recipe in
		effects = effects or {}
		--insert the recipe as an unlock when the research is done
		effects[#effects + 1] = {
			type = "unlock-recipe",
			recipe = name
		}
		--if a new table for the effects is made then the effects has to be attached to the
		-- tech again because the table won't otherwise be owned by the tech
		data.raw["technology"][techName].effects = effects
		return true
	end
	return false
end

-- Do some magic nice stuffs
data:extend(
{
	{
		type = "item-group",
		name = "test-group",
		icon = "__subspace_storage__/graphics/tech.png",
		icon_size = 128,
		inventory_order = "f",
		order = "e"
	},
	{
		type = "item-subgroup",
		name = "chest-subgroup",
		group = "test-group",
		order = "a"
	},
	{
		type = "item-subgroup",
		name = "liquid-subgroup",
		group = "test-group",
		order = "b"
	},
	{
		type = "item-subgroup",
		name = "signal-subgroup",
		group = "test-group",
		order = "c"
	},
	{
		type = "item-subgroup",
		name = "electric-subgroup",
		group = "test-group",
		order = "d"
	}
})

data:extend(
{
	{
		type = "recipe-category",
		name = CRAFTING_FLUID_CATEGORY_NAME
	}
})

-- Virtual signals
data:extend{
	{
		type = "item-subgroup",
		name = "virtual-signal-clusterio",
		group = "signals",
		order = "e"
	},
	{
		type = "virtual-signal",
		name = "signal-localid",
		icon = "__subspace_storage__/graphics/icons/signal_localid.png",
		icon_size = 32,
		subgroup = "virtual-signal-clusterio",
		order = "e[clusterio]-[4localid]"
	},
	{
		type = "virtual-signal",
		name = "signal-unixtime",
		icon = "__subspace_storage__/graphics/icons/signal_unixtime.png",
		icon_size = 32,
		subgroup = "virtual-signal-clusterio",
		order = "e[clusterio]-[5unixtime]"
	},
	{
		type = "virtual-signal",
		name = "electricity",
		icon = "__subspace_storage__/graphics/icons/signal_electricity.png",
		icon_size = 32,
		subgroup = "virtual-signal-clusterio",
		order = "e[clusterio]-[5electricity]"
	},
}

-- Inventory Combinator
local inv = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
local tint = { r = 100, g = 200, b = 255, a = 255 }
inv.name = INV_COMBINATOR_NAME
inv.minable.result = INV_COMBINATOR_NAME
inv.item_slot_count = 2000
for _, sprite in pairs(inv.sprites) do
	sprite.layers[1].tint = tint
	sprite.layers[1].hr_version.tint = tint
end
data:extend{
	inv,
	{
		type = "item",
		name = INV_COMBINATOR_NAME,
		icons = {
			{
				icon = inv.icon,
				tint = tint,
			}
		},
		icon_size = inv.icon_size,
		flags = {},
		subgroup = "signal-subgroup",
		place_result=INV_COMBINATOR_NAME,
		order = "a[items]-b["..INV_COMBINATOR_NAME.."]",
		stack_size = 50,
	},
	{
		type = "recipe",
		name = INV_COMBINATOR_NAME,
		enabled = true, -- TODO do this on a tech somewhere
		ingredients =
		{
			{"constant-combinator", 1},
			{"electronic-circuit", 50}
		},
		result = INV_COMBINATOR_NAME,
		requester_paste_multiplier = 1
	},
}

data:extend(
        {
            {
                type = "sprite",
                name = "clusterio",
                filename = "__subspace_storage__/graphics/icons/clusterio.png",
                priority = "medium",
                width = 128,
                height = 128,
                flags = { "icon" }
            }

        }
)
