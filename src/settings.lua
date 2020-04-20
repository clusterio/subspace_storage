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
}
