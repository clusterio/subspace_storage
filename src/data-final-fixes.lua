local config = require("config")

for k,v in pairs(data.raw.fluid) do
	if not v.hidden then
		data:extend(
		{
			{
				type = "recipe",
				name = ("get-"..v.name),
				category = config.CRAFTING_FLUID_CATEGORY_NAME,
				energy_required = 1,
				subgroup = "fill-barrel",
				order = "b[fill-crude-oil-barrel]",
				enabled = true,
				ingredients = {},
				results=
				{
					{type="fluid", name=v.name, amount=0}
				}
			}
		})
	end
end