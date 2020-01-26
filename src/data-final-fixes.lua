require("config")

for k,v in pairs(data.raw.fluid) do
	data:extend(
	{
		{
			type = "recipe",
			name = ("get-"..v.name),
			icon = v.icon,
			icon_size = v.icon_size,
			category = CRAFTING_FLUID_CATEGORY_NAME,
			--localised_name = {v.name},
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
