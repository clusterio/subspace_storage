local Public = {}
local compat = require("compat")
local config = require("config")

local INV_COMBINATOR_NAME = config.INV_COMBINATOR_NAME
local restrictedEntities = config.restrictedEntities


-------------------------------------------------------------
--[[Methods that handle creation and deletion of entities]]--
-------------------------------------------------------------

local function AddEntity(entity)
	local entity_name = entity.name

	if     entity_name == "subspace-item-injector" then
		--add the chests to a lists if these chests so they can be interated over
		table.insert(global.inputChestsData.entitiesData, {
			entity = entity,
			inv = entity.get_inventory(defines.inventory.chest)
		})
	elseif entity_name == "subspace-item-extractor" then
		--add the chests to a lists if these chests so they can be interated over
		table.insert(global.outputChestsData.entitiesData, {
			entity = entity,
			inv = entity.get_inventory(defines.inventory.chest),
		})
	elseif entity_name == "subspace-fluid-injector" then
		--add the chests to a lists if these chests so they can be interated over
		table.insert(global.inputTanksData.entitiesData, {
			entity = entity,
			fluidbox = entity.fluidbox
		})
	elseif entity_name == "subspace-fluid-extractor" then
		--add the chests to a lists if these chests so they can be interated over
		table.insert(global.outputTanksData.entitiesData, {
			entity = entity,
			fluidbox = entity.fluidbox
		})
		--previous version made then inactive which isn't desired anymore
		entity.active = true
	elseif entity_name == INV_COMBINATOR_NAME then
		global.invControls[entity.unit_number] = entity.get_or_create_control_behavior()
		entity.operable = false
	elseif entity_name == "subspace-electricity-injector" then
		table.insert(global.inputElectricityData.entitiesData, {
			entity = entity
		})
	elseif entity_name == "subspace-electricity-extractor" then
		table.insert(global.outputElectricityData.entitiesData, {
			entity = entity,
			bufferSize = entity.electric_buffer_size
		})
	end
end

local function AddEntities(entities)
	for _, entity in pairs(entities) do
		AddEntity(entity)
	end
end

local function RemoveEntity(list, entity)
	for i, v in ipairs(list) do
		if v.entity == entity then
			table.remove(list, i)
			break
		end
	end
end


----------------------
--[[Module exports]]--
----------------------

function Public.AddAllEntitiesOfNames(names)
	for _, surface in pairs(game.surfaces) do
		for _, name in ipairs(names) do
			AddEntities(surface.find_entities_filtered { name = name })
		end
	end
end

function Public.OnBuiltEntity(event)
	local entity = event.created_entity
	if not (entity and entity.valid) then return end

	local name = entity.name
	local isPhisicalBody = true
	if name == "entity-ghost" then
		name = entity.ghost_name
		isPhisicalBody = false
	end

	if not restrictedEntities[name] then
		-- early return for untracked entities
		return
	end

	if global.setting_range_restriction then
		local spawn
		local player = false

		if event.player_index then player = game.players[event.player_index] end

		if player and player.valid then
			spawn = game.players[event.player_index].force.get_spawn_position(entity.surface)
		else
			spawn = game.forces.player.get_spawn_position(entity.surface)
		end
	
		local x = entity.position.x - spawn.x
		local y = entity.position.y - spawn.y
		local width = global.setting_zone_width
		local height = global.setting_zone_height

		if not ((width == 0 or (math.abs(x) < width / 2)) and (height == 0 or (math.abs(y) < height / 2))) then
			if player and player.valid then
				-- Tell the player what is happening
				player.print({
					"subspace_storage.placed-outside-allowed-area", x, y,
					width > 0 and width or "inf", height > 0 and height or "inf"
				})
				-- kill entity, try to give it back to the player though
				if compat.version_ge(1, 0) then
					local inventory = game.create_inventory(1)
					entity.mine {
						inventory = inventory,
						force = true,
					}
					if inventory[1].valid_for_read then
						local player_inventory = player.get_main_inventory()
						if player_inventory then
							local removed = player_inventory.insert(inventory[1])
							inventory[1].count = inventory[1].count - removed
						end
						if inventory[1].valid_for_read then
							player.surface.spill_item_stack(player.position, inventory[1])
						end
					end
					inventory.destroy()
				else
					if not player.mine_entity(entity, true) then
						entity.destroy()
					end
				end
			else
				-- it wasn't placed by a player, we can't tell em whats wrong
				if compat.version_ge(1, 0) then
					entity.mine()
				else
					entity.destroy()
				end
			end

			return
		end
	end
	-- only add entities that are not ghosts
	if isPhisicalBody then
		AddEntity(entity)
	end
end

function Public.OnKilledEntity(event)
	local entity = event.entity
	if entity.type == "entity-ghost" then
		return
	end

	local entity_name = entity.name
	--remove the entities from the tables as they are dead
	if     entity_name == "subspace-item-injector" then
		RemoveEntity(global.inputChestsData.entitiesData, entity)
	elseif entity_name == "subspace-item-extractor" then
		RemoveEntity(global.outputChestsData.entitiesData, entity)
	elseif entity_name == "subspace-fluid-injector" then
		RemoveEntity(global.inputTanksData.entitiesData, entity)
	elseif entity_name == "subspace-fluid-extractor" then
		RemoveEntity(global.outputTanksData.entitiesData, entity)
	elseif entity_name == INV_COMBINATOR_NAME then
		global.invControls[entity.unit_number] = nil
	elseif entity_name == "subspace-electricity-injector" then
		RemoveEntity(global.inputElectricityData.entitiesData, entity)
	elseif entity_name == "subspace-electricity-extractor" then
		RemoveEntity(global.outputElectricityData.entitiesData, entity)
	end
end

function Public.on_player_cursor_stack_changed(event)
	local player = game.players[event.player_index]
	if not player or not player.valid then
		return
	end

	local drawZone = false
	if global.setting_range_restriction then
		local stack = player.cursor_stack
		if stack and stack.valid and stack.valid_for_read then
			if restrictedEntities[stack.name] then
				drawZone = true
			end
		elseif player.cursor_ghost then
			if restrictedEntities[player.cursor_ghost.name] then
				drawZone = true
			end
		end
	end

	if drawZone then
		if not global.zoneDraw[event.player_index] then
			local spawn = player.force.get_spawn_position(player.surface)
			local x0 = spawn.x
			local y0 = spawn.y

			local width = global.setting_zone_width
			local height = global.setting_zone_height
			if width == 0 then width = 2000000 end
			if height == 0 then height = 2000000 end

			global.zoneDraw[event.player_index] = rendering.draw_rectangle {
				color = {r=0.8 , g=0.1, b=0},
				width = 12,
				filled = false,
				left_top = {x0 - width / 2, y0 - height / 2},
				right_bottom = {x0 + width / 2, y0 + height / 2},
				surface = player.surface,
				players = {player},
				draw_on_ground = true,
			}
		end
	else
		if global.zoneDraw[event.player_index] then
			rendering.destroy(global.zoneDraw[event.player_index])
			global.zoneDraw[event.player_index] = nil
		end
	end
end

return Public