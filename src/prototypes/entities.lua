local icons = require("entity_icons")
local pictures = require("entity_pictures")


-- We copy certain properties from the vanilla steel chest and storage tank
local steel_chest = data.raw["container"]["steel-chest"]
local storage_tank = data.raw["storage-tank"]["storage-tank"]

local function subspace_interactor_entity(options)
	local entity = {
		name = options.name,
		icon = icons[options.name],
		icon_size = 64, icon_mipmaps = 4,
		flags = {"placeable-player", "player-creation"},
		minable = { mining_time = 4, result = options.name },
		max_health = 500,
		corpse = nil,
		dying_explosion = nil,
		collision_box = {{-3.7, -3.7}, {3.7, 3.7}},
		selection_box = {{-4, -4}, {4, 4}},
		damaged_trigger_effect = steel_chest.damaged_trigger_effect,
		resistances = {
			{ type = "fire", percent = 90 },
			{ type = "impact", percent = 60 },
		},
		fast_replaceable_group = "subspace-interactor",
		vehicle_impact_sound = steel_chest.vehicle_impact_sound,
		circuit_wire_connection_point = nil,
		circuit_connector_sprites = nil,
		circuit_wire_max_distance = nil,
	}

	for key, value in pairs(options.entity_properties) do
		entity[key] = value
	end

	data:extend {
		{
			type = "recipe",
			name = options.name,
			enabled = true,
			ingredients = options.ingredients,
			result = options.name,
			requester_paste_multiplier = options.requester_paste_multiplier or 4,
		},
		{
			type = "item",
			name = options.name,
			icon = icons[options.name],
			icon_size = 64, icon_mipmaps = 4,
			subgroup = options.subgroup,
			order = "a[items]-b[" .. options.name .. "]",
			place_result = options.name,
			stack_size = options.stack_size or 50,
		},
		entity,
	}
end

---------------------------------
--[[Make subspace interactors]]--
---------------------------------

local standard_recipe = {
	{"steel-chest", 1},
	{"electronic-circuit", 50}
}

subspace_interactor_entity {
	name = "subspace-item-extractor",
	ingredients = standard_recipe,
	subgroup = "chest-subgroup",
	entity_properties = {
		type = "logistic-container",
		inventory_size = 60,
		logistic_mode = "buffer",
		logistic_slots_count = 18,
		render_not_in_network_icon = false,
		open_sound = steel_chest.open_sound,
		close_sound = steel_chest.open_sound,
		animation_sound = nil,
		opened_duration = logistic_chest_opened_duration,
		picture = pictures["subspace-item-extractor"],
	},
}

subspace_interactor_entity {
	name = "subspace-item-injector",
	ingredients = standard_recipe,
	subgroup = "chest-subgroup",
	entity_properties = {
		type = "container",
		inventory_size = 60,
		open_sound = steel_chest.open_sound,
		close_sound = steel_chest.open_sound,
		picture = pictures["subspace-item-injector"],
	},
}

subspace_interactor_entity {
	name = "subspace-fluid-injector",
	ingredients = standard_recipe,
	subgroup = "liquid-subgroup",
	entity_properties = {
		type = "storage-tank",
		fluid_box = {
			production_type = "input",
			base_area = 250,
			pipe_covers = pipecoverspictures(),
			pipe_connections = {
				{ type = "input", position = {-4.5, -2.5} },
				{ type = "input", position = {-4.5, 2.5} },
				{ type = "input", position = {-2.5, 4.5} },
				{ type = "input", position = {2.5, 4.5} },
				{ type = "input", position = {4.5, 2.5} },
				{ type = "input", position = {4.5, -2.5} },
				{ type = "input", position = {2.5, -4.5} },
				{ type = "input", position = {-2.5, -4.5} },
			},
		},
		window_bounding_box = {{-0.125, 0.6875}, {0.1875, 1.1875}},
		pictures = {
			picture = pictures["subspace-fluid-injector"],
			window_background = storage_tank.pictures.window_background,
			fluid_background = storage_tank.pictures.fluid_background,
			flow_sprite = storage_tank.pictures.flow_sprite,
			gas_flow = storage_tank.pictures.gas_flow,
		},
		flow_length_in_ticks = 360,
		working_sound = storage_tank.working_sound,
		open_sound = storage_tank.open_sound,
		close_sound = storage_tank.close_sound,
		water_reflection = nil,
	},
}

subspace_interactor_entity {
	name = "subspace-fluid-extractor",
	ingredients = standard_recipe,
	subgroup = "liquid-subgroup",
	entity_properties = {
		type = "assembling-machine",
		fluid_boxes = {
			{
				production_type = "output",
				pipe_covers = pipecoverspictures(),
				base_area = 250,
				base_level = 1,
				pipe_connections = {
					{ type = "output", position = {-4.5, -2.5} },
					{ type = "output", position = {-4.5, 2.5} },
					{ type = "output", position = {-2.5, 4.5} },
					{ type = "output", position = {2.5, 4.5} },
					{ type = "output", position = {4.5, 2.5} },
					{ type = "output", position = {4.5, -2.5} },
					{ type = "output", position = {2.5, -4.5} },
					{ type = "output", position = {-2.5, -4.5} },
				},
			},
			off_when_no_fluid_recipe = false,
		},
		working_sound = nil,
		open_sound = storage_tank.open_sound,
		close_sound = storage_tank.close_sound,
		animation = pictures["subspace-fluid-extractor"],
		crafting_categories = {CRAFTING_FLUID_CATEGORY_NAME},
		crafting_speed = 1,
		energy_source = {
			type = "electric",
			usage_priority = "secondary-input",
			emissions_per_minute = 2,
		},
		energy_usage = "1kW",
		ingredient_count = 1,
		module_specification = nil,
		allowed_effects = nil,
	},
}

subspace_interactor_entity {
	name = "subspace-electricity-injector",
	ingredients = {
		{"accumulator", 2000},
		{"advanced-circuit", 50},
		{"substation", 50},
		{"satellite", 1}
	},
	requester_paste_multiplier = 1,
	subgroup = "electric-subgroup",
	stack_size = 5,
	entity_properties = {
		type = "accumulator",
		energy_source = {
			type = "electric",
			buffer_capacity = "10GJ",
			usage_priority = "tertiary",
			input_flow_limit = "1GW",
			output_flow_limit = "0kW"
		},
		picture = pictures["subspace-electricity-injector"],
		charge_animation = nil,
		water_reflection = nil,
		charge_cooldown = 30,
		charge_light = nil,
		discharge_animation = nil,
		discharge_cooldown = 60,
		discharge_light = nil,
		open_sound = storage_tank.open_sound,
		close_sound = storage_tank.close_sound,
		working_sound = nil,
		default_output_signal = {type = "virtual", name = "signal-A"},
	}
}

subspace_interactor_entity {
	name = "subspace-electricity-extractor",
	ingredients = {
		{"accumulator", 2000},
		{"advanced-circuit", 50},
		{"substation", 50},
		{"satellite", 1}
	},
	requester_paste_multiplier = 1,
	subgroup = "electric-subgroup",
	stack_size = 5,
	entity_properties = {
		type = "accumulator",
		energy_source = {
			type = "electric",
			buffer_capacity = "10GJ",
			usage_priority = "tertiary",
			input_flow_limit = "0kW",
			output_flow_limit = "1GW"
		},
		picture = pictures["subspace-electricity-extractor"],
		charge_animation = nil,
		water_reflection = nil,
		charge_cooldown = 30,
		charge_light = nil,
		discharge_animation = nil,
		discharge_cooldown = 60,
		discharge_light = nil,
		open_sound = storage_tank.open_sound,
		close_sound = storage_tank.close_sound,
		working_sound = nil,
		default_output_signal = {type = "virtual", name = "signal-A"},
	},
}
