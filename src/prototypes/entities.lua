local compat = require("compat")
local icons = require("entity_icons")
local pictures = require("entity_pictures")

-- Transform pictures to always use hr_version layer in 2.0
if compat.version_ge(2, 0) then
	for key, value in pairs(pictures) do
		for _, layer in pairs(value.layers) do
			if layer.hr_version then
				for property, value in pairs(layer.hr_version) do
					layer[property] = value
				end
				layer.hr_version = nil
			end
		end
	end
end

-- We copy certain properties from the vanilla steel chest and storage tank
local steel_chest = data.raw["container"]["steel-chest"]
local storage_tank = data.raw["storage-tank"]["storage-tank"]

-- Circuit connector helpers are defined in lualib/circuit-connector-sprites
-- but due to the shared lua env for data stage it just exists as a global.
local connector_definition = { variation = 25, main_offset = {1.875, 1}, shadow_offset = {4.5, 2.5625} }
local interactor_circuit_connector_1_way = circuit_connector_definitions.create(
	universal_connector_template,
	{
		connector_definition,
	}
)

local interactor_circuit_connector_4_way = circuit_connector_definitions.create(
	universal_connector_template,
	{
		connector_definition,
		connector_definition,
		connector_definition,
		connector_definition,
	}
)


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
	}

	if options.circuit_connector then
		entity.circuit_wire_connection_points = options.circuit_connector.points
		entity.circuit_wire_connection_point = options.circuit_connector.points
		entity.circuit_connector_sprites = options.circuit_connector.sprites
		entity.circuit_wire_max_distance = 9
	end

	for key, value in pairs(options.entity_properties) do
		entity[key] = value
	end

	data:extend {
		{
			type = "recipe",
			name = options.name,
			enabled = true,
			ingredients = options.ingredients,
			results = {{type = "item", name = options.name, amount = 1}},
			requester_paste_multiplier = options.requester_paste_multiplier or 4,
		},
		{
			type = "item",
			name = options.name,
			icon = icons[options.name],
			icon_size = 64, icon_mipmaps = 4,
			subgroup = options.subgroup,
			order = options.order,
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
	{type = "item", name = "steel-chest", amount = 1},
	{type = "item", name = "electronic-circuit", amount = 50}
}

subspace_interactor_entity {
	name = "subspace-item-extractor",
	ingredients = standard_recipe,
	subgroup = "subspace_storage-interactor",
	order = "b[extractor]-a[subspace-item-extractor]",
	entity_properties = {
		type = "logistic-container",
		inventory_size = 60,
		logistic_mode = "buffer",
		logistic_slots_count = not compat.version_ge(1, 1) and 18 or nil,
		render_not_in_network_icon = false,
		open_sound = steel_chest.open_sound,
		close_sound = steel_chest.open_sound,
		animation_sound = nil,
		opened_duration = logistic_chest_opened_duration,
		picture = pictures["subspace-item-extractor"],
	},
	circuit_connector = interactor_circuit_connector_1_way,
}

subspace_interactor_entity {
	name = "subspace-item-injector",
	ingredients = standard_recipe,
	subgroup = "subspace_storage-interactor",
	order = "a[injector]-a[subspace-item-injector]",
	entity_properties = {
		type = "container",
		inventory_size = 60,
		open_sound = steel_chest.open_sound,
		close_sound = steel_chest.open_sound,
		picture = pictures["subspace-item-injector"],
	},
	circuit_connector = interactor_circuit_connector_1_way,
}

subspace_interactor_entity {
	name = "subspace-fluid-injector",
	ingredients = standard_recipe,
	subgroup = "subspace_storage-interactor",
	order = "a[injector]-b[subspace-fluid-injector]",
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
	circuit_connector = interactor_circuit_connector_4_way,
}

subspace_interactor_entity {
	name = "subspace-fluid-extractor",
	ingredients = standard_recipe,
	subgroup = "subspace_storage-interactor",
	order = "b[extractor]-b[subspace-fluid-extractor]",
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

local electricity_injector_ingredients = {
	{type = "item", name = "accumulator", amount = 2000},
	{type = "item", name = "advanced-circuit", amount = 50},
	{type = "item", name = "substation", amount = 50},
}
if compat.version_ge(2, 0) then
	-- The ingredients previously used for the satellite
	electricity_injector_ingredients[1].amount = 2100 -- add 100 to the accumulator amount
	table.insert(electricity_injector_ingredients, {type = "item", name = "low-density-structure", amount = 100})
	table.insert(electricity_injector_ingredients, {type = "item", name = "processing-unit", amount = 100})
	table.insert(electricity_injector_ingredients, {type = "item", name = "radar", amount = 100})
	table.insert(electricity_injector_ingredients, {type = "item", name = "rocket-fuel", amount = 50})
	table.insert(electricity_injector_ingredients, {type = "item", name = "solar-panel", amount = 100})
else
	table.insert(electricity_injector_ingredients, {type = "item", name = "satellite", amount = 1})
end

subspace_interactor_entity {
	name = "subspace-electricity-injector",
	ingredients = electricity_injector_ingredients,
	requester_paste_multiplier = 1,
	subgroup = "subspace_storage-interactor",
	order = "a[injector]-c[subspace-electricity-injector]",
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
	},
	circuit_connector = interactor_circuit_connector_1_way,
}

subspace_interactor_entity {
	name = "subspace-electricity-extractor",
	ingredients = electricity_injector_ingredients,
	requester_paste_multiplier = 1,
	subgroup = "subspace_storage-interactor",
	order = "b[extractor]-c[subspace-electricity-extractor]",
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
