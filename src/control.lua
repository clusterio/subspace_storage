require("util")
require("config")
local mod_gui = require("mod-gui")

local clusterio_api = require("__clusterio_lib__/api")
local lib_compat = require("__clusterio_lib__/compat")

local compat = require("compat")


-- Entities which are not allowed to be placed outside the restriction zone
local restrictedEntities = {
	["subspace-item-injector"] = true,
	["subspace-item-extractor"] = true,
	["subspace-fluid-injector"] = true,
	["subspace-fluid-extractor"] = true,
	["subspace-electricity-injector"] = true,
	["subspace-electricity-extractor"] = true,
}

------------------------------------------------------------
--[[Method that handle creation and deletion of entities]]--
------------------------------------------------------------
function OnBuiltEntity(event)
	-- renamed to .entity in 2.0
	local entity = event.created_entity or event.entity
	if not (entity and entity.valid) then return end

	local player = event.player_index and game.get_player(event.player_index) or nil

	local spawn
	if player and player.valid then
		spawn = game.players[event.player_index].force.get_spawn_position(entity.surface)
	else
		spawn = game.forces["player"].get_spawn_position(entity.surface)
	end
	local x = entity.position.x - spawn.x
	local y = entity.position.y - spawn.y

	local name = entity.name
	if name == "entity-ghost" then name = entity.ghost_name end

	local restrictionEnabled = settings.global["subspace_storage-range-restriction-enabled"].value
	if restrictionEnabled and restrictedEntities[name] then
		local width = settings.global["subspace_storage-zone-width"].value
		local height = settings.global["subspace_storage-zone-height"].value
		if ((width == 0 or (math.abs(x) < width / 2)) and (height == 0 or (math.abs(y) < height / 2))) then
			--only add entities that are not ghosts
			if entity.type ~= "entity-ghost" then
				AddEntity(entity)
			end
		else
			if player and player.valid then
				-- Tell the player what is happening
				if player then
					player.print({
						"subspace_storage.placed-outside-allowed-area", x, y,
						width > 0 and width or "inf", height > 0 and height or "inf"
					})
				end
				-- kill entity, try to give it back to the player though
				if lib_compat.version_ge("1.0.0") then
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
							if lib_compat.version_ge("2.0.0") then
								player.surface.spill_item_stack({
									position = player.position,
									stack = inventory[1],
								})
							else
								player.surface.spill_item_stack(player.position, inventory[1])
							end
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
				if lib_compat.version_ge("1.0.0") then
					entity.mine()
				else
					entity.destroy()
				end
			end
		end
	else
		--only add entities that are not ghosts
		if entity.type ~= "entity-ghost" then
			AddEntity(entity)
		end
	end
end

function AddAllEntitiesOfNames(names)
	for _, surface in pairs(game.surfaces) do
		for _, name in ipairs(names) do
			AddEntities(surface.find_entities_filtered { name = name })
		end
	end
end

function AddEntities(entities)
	for k, entity in pairs(entities) do
		AddEntity(entity)
	end
end

function AddEntity(entity)
	if entity.name == "subspace-item-injector" then
		--add the chests to a lists if these chests so they can be interated over
		table.insert(global.inputChestsData.entitiesData, {
			entity = entity,
			inv = entity.get_inventory(defines.inventory.chest)
		})
	elseif entity.name == "subspace-item-extractor" then
		--add the chests to a lists if these chests so they can be interated over
		table.insert(global.outputChestsData.entitiesData, {
			entity = entity,
			inv = entity.get_inventory(defines.inventory.chest),
		})
	elseif entity.name == "subspace-fluid-injector" then
		--add the chests to a lists if these chests so they can be interated over
		table.insert(global.inputTanksData.entitiesData, {
			entity = entity,
			fluidbox = entity.fluidbox
		})
	elseif entity.name == "subspace-fluid-extractor" then
		--add the chests to a lists if these chests so they can be interated over
		table.insert(global.outputTanksData.entitiesData, {
			entity = entity,
			fluidbox = entity.fluidbox
		})
		--previous version made then inactive which isn't desired anymore
		entity.active = true
	elseif entity.name == INV_COMBINATOR_NAME then
		global.invControls[entity.unit_number] = entity.get_or_create_control_behavior()
		entity.operable=false
	elseif entity.name == "subspace-electricity-injector" then
		table.insert(global.inputElectricityData.entitiesData, {
			entity = entity
		})
	elseif entity.name == "subspace-electricity-extractor" then
		table.insert(global.outputElectricityData.entitiesData, {
			entity = entity,
			bufferSize = entity.electric_buffer_size
		})
	end
end

function RemoveEntity(list, entity)
	for i, v in ipairs(list) do
		if v.entity == entity then
			table.remove(list, i)
			break
		end
	end
end

function OnKilledEntity(event)
	local entity = event.entity
	if entity.type ~= "entity-ghost" then
		--remove the entities from the tables as they are dead
		if entity.name == "subspace-item-injector" then
			RemoveEntity(global.inputChestsData.entitiesData, entity)
		elseif entity.name == "subspace-item-extractor" then
			RemoveEntity(global.outputChestsData.entitiesData, entity)
		elseif entity.name == "subspace-fluid-injector" then
			RemoveEntity(global.inputTanksData.entitiesData, entity)
		elseif entity.name == "subspace-fluid-extractor" then
			RemoveEntity(global.outputTanksData.entitiesData, entity)
		elseif entity.name == INV_COMBINATOR_NAME then
			global.invControls[entity.unit_number] = nil
		elseif entity.name == "subspace-electricity-injector" then
			RemoveEntity(global.inputElectricityData.entitiesData, entity)
		elseif entity.name == "subspace-electricity-extractor" then
			RemoveEntity(global.outputElectricityData.entitiesData, entity)
		end
	end
end


-----------------------------
--[[Thing creation events]]--
-----------------------------
script.on_event(defines.events.on_built_entity, function(event)
	OnBuiltEntity(event)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	OnBuiltEntity(event)
end)


----------------------------
--[[Thing killing events]]--
----------------------------
script.on_event(defines.events.on_entity_died, function(event)
	OnKilledEntity(event)
end)

script.on_event(defines.events.on_robot_pre_mined, function(event)
	OnKilledEntity(event)
end)

script.on_event(defines.events.on_pre_player_mined_item, function(event)
	OnKilledEntity(event)
end)

script.on_event(defines.events.script_raised_destroy, function(event)
	OnKilledEntity(event)
end)


------------------------
--[[Clusterio events]]--
------------------------
local function RegisterClusterioEvents()
	script.on_event(clusterio_api.events.on_instance_updated, UpdateInvCombinators)
end

------------------------------
--[[Thing resetting events]]--
------------------------------
script.on_init(function()
	-- 2.0 compatibility
	if lib_compat.version_ge("2.0.0") then
		global = storage
	end
	clusterio_api.init()
	RegisterClusterioEvents()
	Reset()
end)

script.on_load(function()
	-- 2.0 compatibility
	if lib_compat.version_ge("2.0.0") then
		global = storage
	end
	clusterio_api.init()
	RegisterClusterioEvents()
end)

script.on_configuration_changed(function(data)
	if data.mod_changes and data.mod_changes["subspace_storage"] then
		if global.hasInfiniteResources ~= nil then
			log("Migrating global.hasInfiniteResources = " .. tostring(global.hasInfiniteResources))
			settings.global["subspace_storage-infinity-mode"] = { value = global.hasInfiniteResources }
			global.hasInfiniteResources = nil
		end
		if global.maxElectricity ~= nil then
			log("Migrating global.maxElectricity = " .. tostring(global.maxElectricity))
			settings.global["subspace_storage-max-electricity"] = { value = global.maxElectricity }
			global.maxElectricity = nil
		end
		Reset()
	end
end)

function Reset()
	global.ticksSinceMasterPinged = 601
	global.isConnected = false
	global.prevIsConnected = false
	global.allowedToMakeElectricityRequests = false
	global.workTick = 0

	if global.config == nil then
		global.config =
		{
			BWitems = {},
			item_is_whitelist = false,
			BWfluids = {},
			fluid_is_whitelist = false,
		}
	end
	if global.invdata == nil then
		global.invdata = {}
	end

	rendering.clear("subspace_storage")
	global.zoneDraw = {}

	global.outputList = {}
	global.inputList = {}
	global.itemStorage = {}
	if not global.useableItemStorage then
		global.useableItemStorage = {}
	end
	for name, qualities in pairs(global.useableItemStorage) do
		for quality, entry in pairs(qualities) do
			if not entry.remainingItems then
				global.useableItemStorage[name][quality] = nil
			else
				if not entry.initialItemCount then
					entry.initialItemCount = entry.remainingItems
				end
				if not entry.lastPull then
					entry.lastPull = game.tick
				end
			end
		end
	end

	global.inputChestsData =
	{
		entitiesData = { pos = 0 },
	}
	global.outputChestsData =
	{
		entitiesData = { pos = 0 },
		requests = {},
		requestsLL = nil
	}

	gbal.iutTanksData =
	{
		entitiesData = { pos = 0 },
	}
	global.outputTanksData =
	{
		entitiesData = { pos = 0 },
		requests = {},
		requestsLL = nil
	}

	global.inputElectricityData =
	{
		entitiesData = { pos = 0 },
	}
	global.outputElectricityData =
	{
		entitiesData = { pos = 0 },
		requests = {},
		requestsLL = nil
	}
	global.lastElectricityUpdate = 0

	gl.invControls = {}

	AddAllEntitiesOfNames(
	{
		"subspace-item-injector",
		"subspace-item-extractor",
		"subspace-fluid-injector",
		"subspace-fluid-extractor",
		INV_COMBINATOR_NAME,
		"subspace-electricity-injector",
		"subspace-electricity-extractor"
	})
end

script.on_event(defines.events.on_tick, function(event)

	--If the mod isn't connected then still pretend that it's
	--so items requests and removals can be fulfilled
	if settings.global["subspace_storage-infinity-mode"].value then
		global.ticksSinceMasterPinged = 0
	end

	global.ticksSinceMasterPinged = global.ticksSinceMasterPinged + 1
	if global.ticksSinceMasterPinged < 300 then
		global.isConnected = true


		if global.prevIsConnected == false then
			global.workTick = 0
		end

		if global.workTick == 0 then
			--importing electricity should be limited because it requests so
			--much at once. If it wasn't limited then the electricity could
			--make small burst of requests which requests >10x more than it needs
			--which could temporarily starve other networks.
			--Updating every 4 seconds give two chances to give electricity in
			--the 10 second period.
			local timeSinceLastElectricityUpdate = game.tick - global.lastElectricityUpdate
			global.allowedToMakeElectricityRequests = timeSinceLastElectricityUpdate > 60 * 3.5
		end

		--First retrieve requests and then fulfill them
		if global.workTick >= 0 and global.workTick < TICKS_TO_COLLECT_REQUESTS then
			if global.workTick == 0 then
				ResetRequestGathering()
			end
			RetrieveGetterRequests(global.allowedToMakeElectricityRequests, TICKS_TO_COLLECT_REQUESTS - global.workTick)
		elseif global.workTick >= TICKS_TO_COLLECT_REQUESTS and global.workTick < TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS then
			if global.workTick == TICKS_TO_COLLECT_REQUESTS then
				UpdateUseableStorage()
				PrepareToFulfillRequests()
				ResetFulfillRequestIterators()
			end
			local ticksLeft = (TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS) - global.workTick
			FulfillGetterRequests(global.allowedToMakeElectricityRequests, ticksLeft)
		end

		--Emptying putters will continiously happen
		--while requests are gathered and fulfilled
		if global.workTick >= 0 and global.workTick < TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS then
			if global.workTick == 0 then
				ResetPutterIterators()
			end
			EmptyPutters((TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS) - global.workTick)
		end

		if     global.workTick == TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS + 0 then
			ExportInputList()
			global.workTick = global.workTick + 1
		elseif global.workTick == TICKS_TO_COLLECT_REQUESTS + TICKS_TO_FULFILL_REQUESTS + 1 then
			ExportOutputList()

			--Restart loop
			global.workTick = 0
			if global.allowedToMakeElectricityRequests then
				global.lastElectricityUpdate = game.tick
			end
		else
			global.workTick = global.workTick + 1
		end
	else
		global.isConnected = false
	end
	global.prevIsConnected = global.isConnected
end)

-- Return items stuck in useableItemStorage
script.on_nth_tick(60*60, function(event)
	if not settings.global["subspace_storage-infinity-mode"].value then
		local staleTick = game.tick - 60 * 60
		for itemName, qualities in pairs(global.useableItemStorage) do
			for quality, entry in pairs(qualities) do
				if entry.lastPull < staleTick and entry.remainingItems > 0 then
					AddItemToInputList(itemName, entry.remainingItems, quality)
					entry.remainingItems = 0
				end
			end
		end
	end
end)

function UpdateUseableStorage()
	for itemName, qualities in pairs(global.itemStorage) do
		for quality, count in pairs(qualities) do
			GiveItemsToUseableStorage(itemName, count, quality)
			global.useableItemStorage[itemName][quality].initialItemCount = global.useableItemStorage[itemName][quality].remainingItems
		end
	end
	global.itemStorage = {}
end


----------------------------------------
--[[Getter and setter update methods]]--
----------------------------------------
function ResetRequestGathering()
	global.outputChestsData.entitiesData.pos = 0
	global.outputChestsData.requests = {}

	global.outputTanksData.entitiesData.pos = 0
	global.outputTanksData.requests = {}

	global.outputElectricityData.entitiesData.pos = 0
	global.outputElectricityData.requests = {}
end

function ResetFulfillRequestIterators()
	global.outputChestsData.requestsLL.pos = 0
	global.outputTanksData.requestsLL.pos = 0
	global.outputElectricityData.requestsLL.pos = 0
end

function ResetPutterIterators()
	global.inputChestsData.entitiesData.pos = 0
	global.inputTanksData.entitiesData.pos = 0
	global.inputElectricityData.entitiesData.pos = 0
end

function PrepareToFulfillRequests()
	global.outputChestsData.requestsLL      = PrepareRequests(global.outputChestsData.requests     , true)
	global.outputTanksData.requestsLL       = PrepareRequests(global.outputTanksData.requests      , false)
	global.outputElectricityData.requestsLL = PrepareRequests(global.outputElectricityData.requests, false)
end

-- Iterates through a sequence over a number of separate runs
function partial_ipairs(list, runs_left)
	function iterator(state, pos)
		if pos >= state.endpoint or pos >= #state.list then
			return nil, nil
		end
		return pos + 1, state.list[pos + 1]
	end

	local pos = list.pos
	local endpoint = pos + math.max(0, math.ceil((#list - pos) / runs_left))
	list.pos = endpoint
	return iterator, { list = list, endpoint = endpoint }, pos
end

function RetrieveGetterRequests(allowedToGetElectricityRequests, ticksLeft)
	local chestData = global.outputChestsData.entitiesData
	for _, data in partial_ipairs(chestData, ticksLeft) do
		GetOutputChestRequest(global.outputChestsData.requests, data)
	end

	local tankData = global.outputTanksData.entitiesData
	for _, data in partial_ipairs(tankData, ticksLeft) do
		GetOutputTankRequest(global.outputTanksData.requests, data)
	end

	if allowedToGetElectricityRequests then
		local electricityData = global.outputElectricityData.entitiesData
		for _, data in partial_ipairs(electricityData, ticksLeft) do
			GetOutputElectricityRequest(global.outputElectricityData.requests, data)
		end
	end
end

function FulfillGetterRequests(allowedToGetElectricityRequests, ticksLeft)
	local chestRequests = global.outputChestsData.requestsLL
	for _, data in partial_ipairs(chestRequests, ticksLeft) do
		EvenlyDistributeItems(data, OutputChestInputMethod)
	end

	local tankRequests = global.outputTanksData.requestsLL
	for _, data in partial_ipairs(tankRequests, ticksLeft) do
		EvenlyDistributeItems(data, OutputTankInputMethod)
	end

	if allowedToGetElectricityRequests then
		local electricityRequests = global.outputElectricityData.requestsLL
		for _, data in partial_ipairs(electricityRequests, ticksLeft) do
			EvenlyDistributeItems(data, OutputElectricityinputMethod)
		end
	end
end

function EmptyPutters(ticksLeft)
	local chestData = global.inputChestsData.entitiesData
	for _, data in partial_ipairs(chestData, ticksLeft) do
		HandleInputChest(data)
	end

	local tankData = global.inputTanksData.entitiesData
	for _, data in partial_ipairs(tankData, ticksLeft) do
		HandleInputTank(data)
	end

	local electricityData = global.inputElectricityData.entitiesData
	for _, data in partial_ipairs(electricityData, ticksLeft) do
		HandleInputElectricity(data)
	end
end


function HandleInputChest(entityData)
	local entity = entityData.entity
	local inventory = entityData.inv
	if entity.valid then
		--get the content of the chest
		local items = inventory.get_contents()
		for _, item in pairs(items) do
			if isItemLegal(item.name) then
				local removed = inventory.remove({name = item.name, count = item.count, quality = item.quality})
				AddItemToInputList(item.name, removed, item.quality)
			end
		end
	end
end

function HandleInputTank(entityData)
	local entity  = entityData.entity
	local fluidbox = entityData.fluidbox
	if entity.valid then
		--get the content of the chest
		local fluid = fluidbox[1]
		if fluid ~= nil and fluid.amount > 0 then
			if isFluidLegal(fluid.name) then
				if fluid.amount > 1 then
					local fluid_taken = math.ceil(fluid.amount) - 1
					AddItemToInputList(fluid.name, fluid_taken, "normal")
					fluid.amount = fluid.amount - fluid_taken
					fluidbox[1] = fluid
				else
					local signal = entity.get_signal(
						{name = "signal-P", type = "virtual"},
						defines.wire_connector_id.circuit_red,
						defines.wire_connector_id.circuit_green
					)
					if signal == 1 then
						fluidbox[1] = nil
					end
				end
			end
		end
	end
end

function HandleInputElectricity(entityData)
	--if there is too much energy in the network then stop outputting more
	local limit = settings.global["subspace_storage-max-electricity"].value
	if
		limit >= 0
		and global.invdata
		and global.invdata[ELECTRICITY_ITEM_NAME]
		and global.invdata[ELECTRICITY_ITEM_NAME] >= limit
	then
		return
	end

	local entity = entityData.entity
	if entity.valid then
		local energy = entity.energy
		local availableEnergy = math.floor(energy / ELECTRICITY_RATIO)
		if availableEnergy > 0 then
			AddItemToInputList(ELECTRICITY_ITEM_NAME, availableEnergy, "normal")
			entity.energy = energy - (availableEnergy * ELECTRICITY_RATIO)
		end
	end
end

function GetOutputChestRequest(requests, entityData)
	local entity = entityData.entity
	local chestInventory = entityData.inv
	--Don't insert items into the chest if it's being deconstructed
	--as that just leads to unnecessary bot work
	if entity.valid and not entity.to_be_deconstructed(entity.force) then
		local slotsLeft = 60
		local filters = lib_compat.version_ge("2.0.0") and entity.get_logistic_point()[1].filters or {}

		--Go though each request slot
		local loopCount = lib_compat.version_ge("2.0.0") and #filters or entity.request_slot_count
		for i = 1, loopCount do
			local requestItem = lib_compat.version_ge("2.0.0") and filters[i] or entity.get_request_slot(i)

			--Some request slots may be empty and some items are not allowed
			--to be imported
			if isItemLegal(requestItem.name) then
				local itemsInChest
				if lib_compat.version_ge("2.0.0") then
					itemsInChest = chestInventory.get_item_count({name = requestItem.name, quality = requestItem.quality})
				else
					itemsInChest = chestInventory.get_item_count(requestItem.name)
				end

				--If there isn't enough items in the chest
				local missingAmount = requestItem.count - itemsInChest
				--But don't request more than the chest can hold
				--this will still request too much if you have a lot of different requests for 20k
				local stackSize
				if lib_compat.version_ge("2.0.0") then
					stackSize = prototypes.item[requestItem.name].stack_size
				else
					stackSize = game.item_prototypes[requestItem.name].stack_size
				end
				missingAmount = math.min(missingAmount, slotsLeft * stackSize)
				if missingAmount > 0 then
					slotsLeft = slotsLeft - math.ceil(missingAmount / stackSize)
					local entry = AddRequestToTable(requests, requestItem.name, missingAmount, entity, requestItem.quality)
					entry.inv = chestInventory
				end
			end
		end
	end
end

function GetOutputTankRequest(requests, entityData)
	local entity = entityData.entity
	local fluidbox = entityData.fluidbox
	--The type of fluid the tank should output
	--is determined by the recipe set in the  entity.
	--If no recipe is set then it shouldn't output anything

	if entity.valid then
		local recipe = entity.get_recipe()
		if recipe == nil then
			return
		end
		--Get name of the fluid to output
		local fluidName = recipe.products[1].name
		--Some fluids may be illegal. If that's the case then don't process them
		if isFluidLegal(fluidName) then
			--Either get the current fluid or reset it to the requested fluid
			local fluid = fluidbox[1] or {name = fluidName, amount = 0}

			--If the current fluid isn't the correct fluid
			--then remove that fluid
			if fluid.name ~= fluidName then
				fluid = {name = fluidName, amount = 0}
			end

			local missingFluid = math.max(math.ceil(fluidbox.get_capacity(1) - fluid.amount), 0)
			--If the entity is missing fluid than add a request for fluid
			if missingFluid > 0 then
				local entry = AddRequestToTable(requests, fluidName, missingFluid, entity)
				entry.fluidbox = fluidbox
			end
		end
	end
end

function GetOutputElectricityRequest(requests, entityData)
	local entity = entityData.entity
	local bufferSize = entityData.bufferSize
	if entity.valid then
		local energy = entity.energy
		local missingElectricity = math.floor((bufferSize - energy) / ELECTRICITY_RATIO)
		if missingElectricity > 0 then
			local entry = AddRequestToTable(requests, ELECTRICITY_ITEM_NAME, missingElectricity, entity)
			entry.energy = energy
		end
	end
end

function OutputChestInputMethod(request, itemName, evenShareOfItems)
	if request.storage.valid then
		local itemsToInsert =
		{
			name = itemName,
			count = evenShareOfItems,
			quality = request.quality,
		}

		return request.inv.insert(itemsToInsert)
	else
		return 0
	end
end

function OutputTankInputMethod(request, fluidName, evenShareOfFluid)
	if request.storage.valid then
		local fluid = request.fluidbox[1] or {name = fluidName, amount = 0}
		fluid.amount = fluid.amount + evenShareOfFluid

		--Need to set steams heat because otherwise it's too low
		if fluid.name == "steam" then
			fluid.temperature = 165
		end

		request.fluidbox[1] = fluid
		return evenShareOfFluid
	else
		return 0
	end
end

function OutputElectricityinputMethod(request, _, evenShare)
	if request.storage.valid then
		request.storage.energy = request.energy + (evenShare * ELECTRICITY_RATIO)
		return evenShare
	else
		return 0
	end
end


function PrepareRequests(itemIdentifierToRequestinfoMap, shouldSort)
	local requests = { pos = 0 }
	for itemName, qualities in pairs(itemIdentifierToRequestinfoMap) do
		for _quality, requestInfo in pairs(qualities) do
			if shouldSort then
				--To be able to distribute it fairly, the requesters need to be sorted in order of how
				--much they are missing, so the requester with the least missing of the item will be first.
				--If this isn't done then there could be items leftover after they have been distributed
				--even though they could all have been distributed if they had been distributed in order.
				table.sort(requestInfo.requesters, function(left, right)
					return left.missingAmount < right.missingAmount
				end)
			end

			for i = 1, #requestInfo.requesters do
				local request = requestInfo.requesters[i]
				request.itemName = itemName
				request.requestedAmount = requestInfo.requestedAmount
				request.quality = requestInfo.quality
				table.insert(requests, request)
			end
		end
	end

	return requests
end

function AddRequestToTable(requests, itemName, missingAmount, storage, quality)
	if quality == nil then
		quality = "normal"
	end
	--If this is the first entry for this item type then
	--create a table for this item type first
	if requests[itemName] == nil or requests[itemName][quality] == nil then
		requests[itemName] = requests[itemName] or {}
		requests[itemName][quality] =
		{
			requestedAmount = 0,
			requesters = {}
		}
	end

	local itemEntry = requests[itemName][quality]

	itemEntry.quality = quality
	--Add missing item to the count and add this chest inv to the list
	itemEntry.requestedAmount = itemEntry.requestedAmount + missingAmount
	itemEntry.requesters[#itemEntry.requesters + 1] =
	{
		storage = storage,
		missingAmount = missingAmount
	}

	return itemEntry.requesters[#itemEntry.requesters]
end

function EvenlyDistributeItems(request, functionToInsertItems)
	--Take the required item count from storage or how much storage has
	local itemCount = RequestItemsFromUseableStorage(request.itemName, request.requestedAmount, request.quality)

	--need to scale all the requests according to how much of the requested items are available.
	--Can't be more than 100% because otherwise the chests will overfill
	local avaiableItemsRatio = math.min(GetInitialItemCount(request.itemName, request.quality) / request.requestedAmount, 1)
	--Floor is used here so no chest uses more than its fair share.
	--If they used more then the last entity would get less which would be
	--an issue with +1000 entities requesting items.
	local chestHold = math.floor(request.missingAmount * avaiableItemsRatio)
	--If there is less items than requests then floor will return zero and thus not
	--distributes the remaining items. Thus here the mining is set to 1 but still
	--it can't be set to 1 if there is no more items to distribute, which is what
	--the last min corresponds to.
	chestHold = math.max(chestHold, 1)
	chestHold = math.min(chestHold, itemCount)

	--If there wasn't enough items to fulfill the whole request
	--then ask for more items from outside the game
	local missingItems = request.missingAmount - chestHold
	if missingItems > 0 then
		AddItemToOutputList(request.itemName, missingItems, request.quality)
	end

	if itemCount > 0 then
		--No need to insert 0 of something
		if chestHold > 0 then
			local insertedItemsCount = functionToInsertItems(request, request.itemName, chestHold)
			itemCount = itemCount - insertedItemsCount
		end

		--In some cases it's possible for the entity to not use up
		--all the items.
		--In those cases the items should be put back into storage.
		if itemCount > 0 then
			GiveItemsToUseableStorage(request.itemName, itemCount, request.quality)
		end
	end

end


----------------------------------------
--[[Methods that talk with Clusterio]]--
----------------------------------------
function ExportInputList()
	local items = {}
	for name, qualities in pairs(global.inputList) do
		for quality, count in pairs(qualities) do
			table.insert(items, {name, count, quality})
		end
	end
	global.inputList = {}
	if #items > 0 then
		clusterio_api.send_json("subspace_storage:output", items)
	end
end

function ExportOutputList()
	local items = {}
	for name, qualities in pairs(global.outputList) do
		for quality, count in pairs(qualities) do
			table.insert(items, {name, count, quality})
		end
	end
	global.outputList = {}
	if #items > 0 then
		clusterio_api.send_json("subspace_storage:orders", items)
	end
end

function Import(data)
	local items = lib_compat.json_to_table(data)
	log("[Import] Received items: " .. serpent.line(items))
	for _, item in ipairs(items) do
		GiveItemsToStorage(item[1], item[2], item[3])
	end
end

function UpdateInvData(data, full)
	if full then
		global.invdata = {}
	end
	local items = lib_compat.json_to_table(data)
	for _, item in ipairs(items) do
		global.invdata[item[1]..":"..item[3]] = item
	end
	UpdateInvCombinators()
end

---------------------------------
--[[Update combinator methods]]--
---------------------------------

function AreTablesSame(tableA, tableB)
	if tableA == nil and tableB ~= nil then
		return false
	elseif tableA ~= nil and tableB == nil then
		return false
	elseif tableA == nil and tableB == nil then
		return true
	end

	if TableWithKeysLength(tableA) ~= TableWithKeysLength(tableB) then
		return false
	end

	for keyA, valueA in pairs(tableA) do
		local valueB = tableB[keyA]
		if type(valueA) == "table" and type(valueB) == "table" then
			if not AreTablesSame(valueA, valueB) then
				return false
			end
		elseif type(valueA) ~= type(valueB) then
			return false
		elseif valueA ~= valueB then
			return false
		end
	end

	return true
end

function TableWithKeysLength(tableA)
	local count = 0
	for k, v in pairs(tableA) do
		count = count + 1
	end
	return count
end

function UpdateInvCombinators()
	-- Update all inventory Combinators
	-- Prepare a frame from the last inventory report, plus any virtuals
	local invframe = {}
	local instance_id = clusterio_api.get_instance_id()
	if instance_id then
		-- Clamp to 32-bit to avoid error raised by Factorio
		instance_id = math.min(instance_id, 0x7fffffff)
		instance_id = math.max(instance_id, -0x80000000)
		table.insert(invframe,{count=instance_id,index=#invframe+1,signal={name="signal-localid",type="virtual"}})
	end

	local items = lib_compat.version_ge("2.0.0") and prototypes.item or game.item_prototypes
	local fluids = lib_compat.version_ge("2.0.0") and prototypes.fluid or game.fluid_prototypes
	local virtuals = lib_compat.version_ge("2.0.0") and prototypes.virtual_signal or game.virtual_signal_prototypes
	if global.invdata then
		for _identifier, data in pairs(global.invdata) do
			-- If data is a number, then its still in the pre 2.0 format - force delete to migrate to new format
			if type(data) == "number" then
				global.invdata = {}
				return
			end
			-- Combinator signals are limited to a max value of 2^31-1
			local name = data[1]
			local count = math.min(data[2], 0x7fffffff)
			local quality = data[3]
			-- Split code for 1.1 and 2.0
			if lib_compat.version_ge("2.0.0") then
				if items[name] then
					invframe[#invframe+1] = {min=count, value={type="item", name=name, quality=quality}}
				elseif fluids[name] then
					invframe[#invframe+1] = {min=count, value={type="fluid", name=name, quality=quality}}
				elseif virtuals[name] then
					invframe[#invframe+1] = {min=count, value={type="virtual", name=name, quality=quality}}
				end
			else
				-- Combinator signals are limited to a max value of 2^31-1
				if items[name] then
					invframe[#invframe+1] = {count=count, index=#invframe+1, signal={name=name, type="item"}}
				elseif fluids[name] then
					invframe[#invframe+1] = {count=count, index=#invframe+1, signal={name=name, type="fluid"}}
				elseif virtuals[name] then
					invframe[#invframe+1] = {count=count, index=#invframe+1, signal={name=name, type="virtual"}}
				end
			end
		end
	end

	for i,invControl in pairs(global.invControls) do
		if lib_compat.version_ge("2.0.0") then
			if invControl.valid then
				local section = invControl.get_section(1)
				if section == nil then
					section = invControl.add_section()
				end
				section.filters = invframe
				section.active = true
				invControl.enabled = true
			end
		else
			if invControl.valid then
				compat.set_parameters(invControl, invframe)
				invControl.enabled=true
			end
		end
	end
end


---------------------
--[[Remote things]]--
---------------------
remote.add_interface("clusterio",
{
	printStorage = function()
		local items = ""
		for itemName, itemCount in pairs(global.itemStorage) do
			items = items.."\n"..itemName..": "..tostring(itemCount)
		end
		game.print(items)
	end,
	reset = Reset,
})


--------------------
--[[Misc methods]]--
--------------------
function RequestItemsFromUseableStorage(itemName, itemCount, quality)
	--if infinite resources then the whole request is approved
	if settings.global["subspace_storage-infinity-mode"].value then
		return itemCount
	end

	--if result is nil then there is no items in storage
	--which means that no items can be given
	if global.useableItemStorage[itemName] == nil or global.useableItemStorage[itemName][quality] == nil then
		return 0
	end
	--if the number of items in storage is lower than the number of items
	--requested then take the number of items there are left otherwise take the requested amount
	local itemsTakenFromStorage = math.min(global.useableItemStorage[itemName][quality].remainingItems, itemCount)
	global.useableItemStorage[itemName][quality].remainingItems = global.useableItemStorage[itemName][quality].remainingItems - itemsTakenFromStorage
	global.useableItemStorage[itemName][quality].lastPull = game.tick

	return itemsTakenFromStorage
end

function GetInitialItemCount(itemName, quality)
	--this method is used so the mod knows hopw to distribute
	--the items between all entities. If infinite resources is enabled
	--then all entities should get their requests fulfilled-
	--To simulate that this method returns 1mil which should be enough
	--for all entities to fulfill their whole item request
	if settings.global["subspace_storage-infinity-mode"].value then
		return 1000000 --1.000.000
	end

	if global.useableItemStorage[itemName] == nil or global.useableItemStorage[itemName][quality] == nil then
		return 0
	end
	return global.useableItemStorage[itemName][quality].initialItemCount
end

function GiveItemsToUseableStorage(itemName, itemCount, quality)
	if global.useableItemStorage[itemName] == nil or global.useableItemStorage[itemName][quality] == nil then
		global.useableItemStorage[itemName] = global.useableItemStorage[itemName] or {}
		global.useableItemStorage[itemName][quality] = {
			initialItemCount = 0,
			remainingItems = 0,
			lastPull = game.tick,
		}
	end
	global.useableItemStorage[itemName][quality].remainingItems = global.useableItemStorage[itemName][quality].remainingItems + itemCount
end

function GiveItemsToStorage(itemName, itemCount, quality)
	--if this is called for the first time for an item then the result
	--is nil. if that's the case then set the result to 0 so it can
	--be used in arithmetic operations
	global.itemStorage[itemName] = global.itemStorage[itemName] or {}
	global.itemStorage[itemName][quality] = (global.itemStorage[itemName][quality] or 0) + itemCount
end

function AddItemToInputList(itemName, itemCount, quality)
	if settings.global["subspace_storage-infinity-mode"].value then
		return
	end
	global.inputList[itemName] = global.inputList[itemName] or {}
	global.inputList[itemName][quality] = (global.inputList[itemName][quality] or 0) + itemCount
end

function AddItemToOutputList(itemName, itemCount, quality)
	global.outputList[itemName] = global.outputList[itemName] or {}
	global.outputList[itemName][quality] = (global.outputList[itemName][quality] or 0) + itemCount
end

function isFluidLegal(name)
	for _,itemName in pairs(global.config.BWfluids) do
		if itemName==name then
			return global.config.fluid_is_whitelist
		end
	end
	return not global.config.fluid_is_whitelist
end

function isItemLegal(name)
	for _,itemName in pairs(global.config.BWitems) do
		if itemName==name then
			return global.config.item_is_whitelist
		end
	end
	return not global.config.item_is_whitelist
end


-------------------
--[[GUI methods]]--
-------------------
function createElemGui_INTERNAL(pane, guiName, elem_type, loadingList)
	local gui = pane.add{type = "table", name = guiName, column_count = 5}
	for _, item in pairs(loadingList) do
		gui.add{type = "choose-elem-button", elem_type = elem_type, item = item, fluid = item}
	end
	gui.add{type = "choose-elem-button", elem_type = elem_type}
end

function toggleBWItemListGui(parent)
	if parent["clusterio-black-white-item-list-config"] then
        parent["clusterio-black-white-item-list-config"].destroy()
        return
    end

	local pane = parent.add{type = "frame", name = "clusterio-black-white-item-list-config", direction = "vertical"}
	pane.add{type = "label", caption = {"subspace_storage.item"}}
	pane.add{type = "checkbox", name = "clusterio-is-item-whitelist", caption = {"subspace_storage.whitelist"}, state = global.config.item_is_whitelist}
	createElemGui_INTERNAL(pane, "item-black-white-list", "item", global.config.BWitems)
end

function toggleBWFluidListGui(parent)
	if parent["clusterio-black-white-fluid-list-config"] then
        parent["clusterio-black-white-fluid-list-config"].destroy()
        return
    end

	local pane = parent.add{type = "frame", name = "clusterio-black-white-fluid-list-config", direction = "vertical"}
	pane.add{type = "label", caption = {"subspace_storage.fluid"}}
	pane.add{type = "checkbox", name = "clusterio-is-fluid-whitelist", caption = {"subspace_storage.whitelist"}, state = global.config.fluid_is_whitelist}
	createElemGui_INTERNAL(pane, "fluid-black-white-list", "fluid", global.config.BWfluids)
end

function processElemGui(event, toUpdateConfigName)--VERY WIP
	local parent = event.element.parent
	if event.element.elem_value == nil then
		event.element.destroy()
	else
		parent.add{type = "choose-elem-button", elem_type=parent.children[1].elem_type}
	end

	global.config[toUpdateConfigName] = {}
	for _, guiElement in pairs(parent.children) do
		if guiElement.elem_value ~= nil then
			table.insert(global.config[toUpdateConfigName], guiElement.elem_value)
		end
	end
end

function toggleMainConfigGui(parent)
	if parent["clusterio-main-config-gui"] then
        parent["clusterio-main-config-gui"].destroy()
        return
    end

	local pane = parent.add{type = "frame", name = "clusterio-main-config-gui", direction = "vertical"}
	pane.add{type = "button", name = "clusterio-Item-WB-list", caption = {"subspace_storage.item-bw-list"}}
	pane.add{type = "button", name = "clusterio-Fluid-WB-list", caption = {"subspace_storage.fluid-bw-list"}}
end

function processMainConfigGui(event)
	if event.element.name == "clusterio-Item-WB-list" then
		toggleBWItemListGui(game.players[event.player_index].gui.top)
	elseif event.element.name == "clusterio-Fluid-WB-list" then
		toggleBWFluidListGui(game.players[event.player_index].gui.top)
	end
end

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
	if not (event.element.parent) then
		return
	end

	if event.element.name == "clusterio-is-fluid-whitelist" then
		global.config.fluid_is_whitelist = event.element.state
	elseif event.element.name == "clusterio-is-item-whitelist" then
		global.config.item_is_whitelist = event.element.state
	end
end)

script.on_event(defines.events.on_gui_click, function(event)
	if not (event.element and event.element.valid) then
		return
	end
	if not (event.element.parent) then
		return
	end

	if event.element.parent.name == "clusterio-main-config-gui" then
		processMainConfigGui(event)
	elseif event.element.name == "clusterio-main-config-gui-toggle-button" then
		local player = game.players[event.player_index]
		toggleMainConfigGui(player.gui.top)
	end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
	if not (event.element and event.element.valid) then
		return
	end
	if not (event.element.parent) then
		return
	end

	if event.element.parent.name == "item-black-white-list" then
		processElemGui(event,"BWitems")
	elseif event.element.parent.name == "fluid-black-white-list" then
		processElemGui(event,"BWfluids")
	end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
	if not (event.element and event.element.valid) then
		return
	end
end)

function makeConfigButton(parent)
	if not parent["clusterio-main-config-gui-toggle-button"] then
		parent.add{type = "sprite-button", name = "clusterio-main-config-gui-toggle-button", sprite="clusterio"}
    end
end


--------------------------
--[[Some random events]]--
--------------------------
script.on_event(defines.events.on_player_joined_game,function(event)
	if game.players[event.player_index].admin then
		if game.players[event.player_index].gui.top["clusterio-main-config-gui-button"] then
			game.players[event.player_index].gui.top["clusterio-main-config-gui-button"].destroy()
		end

		makeConfigButton(mod_gui.get_button_flow(game.players[event.player_index]))
	end
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
	local player = game.players[event.player_index]
	if not player or not player.valid then
		return
	end

	local restrictionEnabled = settings.global["subspace_storage-range-restriction-enabled"].value
	local drawZone = false
	if restrictionEnabled then
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

			local width = settings.global["subspace_storage-zone-width"].value
			local height = settings.global["subspace_storage-zone-height"].value
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
			if lib_compat.version_ge("2.0.0") then
				global.zoneDraw[event.player_index].destroy()
			else
				rendering.destroy(global.zoneDraw[event.player_index])
			end
			global.zoneDraw[event.player_index] = nil
		end
	end
end)
