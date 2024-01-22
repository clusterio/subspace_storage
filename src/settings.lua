local config = require("config")

data:extend {
	{
		type = "bool-setting",
		name = "subspace_storage-range-restriction-enabled",
		setting_type = "runtime-global",
		order = "a1",
		default_value = true,
	},
	{
		type = "int-setting",
		name = "subspace_storage-zone-width",
		setting_type = "runtime-global",
		order = "b1",
		minimum_value = 0,
		default_value = 400,
	},
	{
		type = "int-setting",
		name = "subspace_storage-zone-height",
		setting_type = "runtime-global",
		order = "b2",
		minimum_value = 0,
		default_value = 400,
	},
	{
		type = "double-setting",
		name = "subspace_storage-max-electricity",
		setting_type = "runtime-global",
		order = "b3",
		default_value = 100000000000000 / config.ELECTRICITY_RATIO --100TJ assuming a ratio of 1.000.000
	},
	{
		type = "bool-setting",
		name = "subspace_storage-infinity-mode",
		setting_type = "runtime-global",
		order = "c1",
		default_value = false,
	},
}
