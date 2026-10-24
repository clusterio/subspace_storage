require("config")
local compat = require("lib_compat")

for k,v in pairs(data.raw.fluid) do
	if not v.hidden and not v.parameter == true then
		data:extend(
		{
			{
				type = "recipe",
				name = ("get-"..v.name),
				category = not compat.version_ge(2, 1) and CRAFTING_FLUID_CATEGORY_NAME or nil,
				categories = compat.version_ge(2, 1) and { CRAFTING_FLUID_CATEGORY_NAME } or nil,
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
