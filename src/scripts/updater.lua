local Public = {}
local compat = require("compat")
local config = require("config")
local clusterio_api = require("__clusterio_lib__/api")

local ELECTRICITY_ITEM_NAME = config.ELECTRICITY_ITEM_NAME
local ELECTRICITY_RATIO = config.ELECTRICITY_RATIO
local MAX_FLUID_AMOUNT = config.MAX_FLUID_AMOUNT
local TICKS_TO_COLLECT_REQUESTS = config.TICKS_TO_COLLECT_REQUESTS
local TICKS_TO_FULFILL_REQUESTS = config.TICKS_TO_FULFILL_REQUESTS
local TICKS_TO_COLLECT_AND_FULFILL_REQUESTS = config.TICKS_TO_COLLECT_AND_FULFILL_REQUESTS
local NTH_TICK = config.NTH_TICK


----------------------------------------
--[[Getter and setter update methods]]--
----------------------------------------

local function isFluidLegal(name)
	for _, itemName in pairs(global.config.BWfluids) do
		if itemName == name then
			return global.config.fluid_is_whitelist
		end
	end
	return not global.config.fluid_is_whitelist
end

local function isItemLegal(name)
	for _, itemName in pairs(global.config.BWitems) do
		if itemName == name then
			return global.config.item_is_whitelist
		end
	end
	return not global.config.item_is_whitelist
end

local function ResetRequestGathering()
	global.outputChestsData.entitiesData.pos = 0
	global.outputChestsData.requests = {}

	global.outputTanksData.entitiesData.pos = 0
	global.outputTanksData.requests = {}

	global.outputElectricityData.entitiesData.pos = 0
	global.outputElectricityData.requests = {}
end

local function ResetFulfillRequestIterators()
	global.outputChestsData.requestsLL.pos = 0
	global.outputTanksData.requestsLL.pos = 0
	global.outputElectricityData.requestsLL.pos = 0
end

local function ResetPutterIterators()
	global.inputChestsData.entitiesData.pos = 0
	global.inputTanksData.entitiesData.pos = 0
	global.inputElectricityData.entitiesData.pos = 0
end

local function PrepareRequests(array, shouldSort)
	local requests = { pos = 0 }
	for itemName, requestInfo in pairs(array) do
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
			table.insert(requests, request)
		end
	end

	return requests
end

local function PrepareToFulfillRequests()
	global.outputChestsData.requestsLL      = PrepareRequests(global.outputChestsData.requests     , true)
	global.outputTanksData.requestsLL       = PrepareRequests(global.outputTanksData.requests      , false)
	global.outputElectricityData.requestsLL = PrepareRequests(global.outputElectricityData.requests, false)
end

-- Iterates through a sequence over a number of separate runs
local function partial_ipairs(list, runs_left)
	local function iterator(state, pos)
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

local function AddRequestToTable(requests, itemName, missingAmount, storage)
	--If this is the first entry for this item type then
	--create a table for this item type first
	if requests[itemName] == nil then
		requests[itemName] =
		{
			requestedAmount = 0,
			requesters = {}
		}
	end

	local itemEntry = requests[itemName]

	--Add missing item to the count and add this chest inv to the list
	itemEntry.requestedAmount = itemEntry.requestedAmount + missingAmount
	itemEntry.requesters[#itemEntry.requesters + 1] =
	{
		storage = storage,
		missingAmount = missingAmount
	}

	return itemEntry.requesters[#itemEntry.requesters]
end

local function GetOutputChestRequest(requests, entityData)
	local entity = entityData.entity
	local chestInventory = entityData.inv
	--Don't insert items into the chest if it's being deconstructed
	--as that just leads to unnecessary bot work
	if entity.valid and not entity.to_be_deconstructed(entity.force) then
		local slotsLeft = 60
		--Go though each request slot
		for i = 1, entity.request_slot_count do
			local requestItem = entity.get_request_slot(i)

			--Some request slots may be empty and some items are not allowed
			--to be imported
			if requestItem ~= nil and isItemLegal(requestItem.name) then
				local itemsInChest = chestInventory.get_item_count(requestItem.name)

				--If there isn't enough items in the chest
				local missingAmount = requestItem.count - itemsInChest
				--But don't request more than the chest can hold
				local stackSize = game.item_prototypes[requestItem.name].stack_size
				missingAmount = math.min(missingAmount, slotsLeft * stackSize)
				if missingAmount > 0 then
					slotsLeft = slotsLeft - math.ceil(missingAmount / stackSize)
					local entry = AddRequestToTable(requests, requestItem.name, missingAmount, entity)
					entry.inv = chestInventory
				end
			end
		end
	end
end

local function GetOutputTankRequest(requests, entityData)
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

			local missingFluid = math.max(math.ceil(MAX_FLUID_AMOUNT - fluid.amount), 0)
			--If the entity is missing fluid than add a request for fluid
			if missingFluid > 0 then
				local entry = AddRequestToTable(requests, fluidName, missingFluid, entity)
				entry.fluidbox = fluidbox
			end
		end
	end
end

local function GetOutputElectricityRequest(requests, entityData)
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

local function RetrieveGetterRequests(allowedToGetElectricityRequests, ticksLeft)
	local outputChestsData = global.outputChestsData
	local chestData = outputChestsData.entitiesData
	local chestRequests = outputChestsData.requests
	for _, data in partial_ipairs(chestData, ticksLeft) do
		GetOutputChestRequest(chestRequests, data)
	end

	local outputTanksData = global.outputTanksData
	local tankData = outputTanksData.entitiesData
	local tankRequests = outputTanksData.requests
	for _, data in partial_ipairs(tankData, ticksLeft) do
		GetOutputTankRequest(tankRequests, data)
	end

	if allowedToGetElectricityRequests then
		local outputElectricityData = global.outputElectricityData
		local electricityData = outputElectricityData.entitiesData
		local electricityRequests = outputElectricityData.requests
		for _, data in partial_ipairs(electricityData, ticksLeft) do
			GetOutputElectricityRequest(electricityRequests, data)
		end
	end
end

local function RequestItemsFromUseableStorage(itemName, itemCount)
	--if infinite resources then the whole request is approved
	if global.setting_infinity_mode then
		return itemCount
	end

  local useableItemStorage = global.useableItemStorage
	--if result is nil then there is no items in storage
	--which means that no items can be given
	if useableItemStorage[itemName] == nil then
		return 0
	end
	--if the number of items in storage is lower than the number of items
	--requested then take the number of items there are left otherwise take the requested amount
	local itemsTakenFromStorage = math.min(useableItemStorage[itemName].remainingItems, itemCount)
	useableItemStorage[itemName].remainingItems = useableItemStorage[itemName].remainingItems - itemsTakenFromStorage
	useableItemStorage[itemName].lastPull = game.tick

	return itemsTakenFromStorage
end

local function GetInitialItemCount(itemName)
	--this method is used so the mod knows hopw to distribute
	--the items between all entities. If infinite resources is enabled
	--then all entities should get their requests fulfilled-
	--To simulate that this method returns 1mil which should be enough
	--for all entities to fulfill their whole item request
	if global.setting_infinity_mode then
		return 1000000 --1.000.000
	end

  local useableItemStorage = global.useableItemStorage
	if useableItemStorage[itemName] == nil then
		return 0
	end
	return useableItemStorage[itemName].initialItemCount
end

local function AddItemToOutputList(itemName, itemCount)
	global.outputList[itemName] = (global.outputList[itemName] or 0) + itemCount
end

local function GiveItemsToUseableStorage(itemName, itemCount)
  local useableItemStorage = global.useableItemStorage
	if useableItemStorage[itemName] == nil then
		useableItemStorage[itemName] =
		{
			initialItemCount = 0,
			remainingItems = 0,
			lastPull = game.tick,
		}
	end
	useableItemStorage[itemName].remainingItems = useableItemStorage[itemName].remainingItems + itemCount
end

local function UpdateUseableStorage()
  local useableItemStorage = global.useableItemStorage
	for k, v in pairs(global.itemStorage) do
		GiveItemsToUseableStorage(k, v)
		useableItemStorage[k].initialItemCount = useableItemStorage[k].remainingItems
	end
	global.itemStorage = {}
end

local function EvenlyDistributeItems(request, functionToInsertItems)
	--Take the required item count from storage or how much storage has
	local itemCount = RequestItemsFromUseableStorage(request.itemName, request.requestedAmount)

	--need to scale all the requests according to how much of the requested items are available.
	--Can't be more than 100% because otherwise the chests will overfill
	local avaiableItemsRatio = math.min(GetInitialItemCount(request.itemName) / request.requestedAmount, 1)
	--Floor is used here so no chest uses more than its fair share.
	--If they used more then the last entity would bet less which would be
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
		AddItemToOutputList(request.itemName, missingItems)
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
			GiveItemsToUseableStorage(request.itemName, itemCount)
		end
	end

end

local function OutputChestInputMethod(request, itemName, evenShareOfItems)
	if request.storage.valid then
		local itemsToInsert =
		{
			name = itemName,
			count = evenShareOfItems
		}

		return request.inv.insert(itemsToInsert)
	else
		return 0
	end
end

local function OutputTankInputMethod(request, fluidName, evenShareOfFluid)
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

local function OutputElectricityinputMethod(request, _, evenShare)
	if request.storage.valid then
		request.storage.energy = request.energy + (evenShare * ELECTRICITY_RATIO)
		return evenShare
	else
		return 0
	end
end

local function FulfillGetterRequests(allowedToGetElectricityRequests, ticksLeft)
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

local function AddItemToInputList(itemName, itemCount)
	if global.setting_infinity_mode then
		return
	end
	global.inputList[itemName] = (global.inputList[itemName] or 0) + itemCount
end

local function HandleInputChest(entityData)
	local entity = entityData.entity
	local inventory = entityData.inv
	if entity.valid then
		--get the content of the chest
		local items = inventory.get_contents()
		for itemName, itemCount in pairs(items) do
			if isItemLegal(itemName) then
				AddItemToInputList(itemName, itemCount)
				inventory.remove({name = itemName, count = itemCount})
			end
		end
	end
end

local function HandleInputTank(entityData)
	local entity  = entityData.entity
	local fluidbox = entityData.fluidbox
	if entity.valid then
		--get the content of the chest
		local fluid = fluidbox[1]
		if fluid ~= nil and fluid.amount > 0 then
			if isFluidLegal(fluid.name) then
				if fluid.amount > 1 then
					local fluid_taken = math.ceil(fluid.amount) - 1
					AddItemToInputList(fluid.name, fluid_taken)
					fluid.amount = fluid.amount - fluid_taken
					fluidbox[1] = fluid
				else
					if entity.get_merged_signal({name="signal-P",type="virtual"}) == 1 then
						fluidbox[1] = nil
					end
				end
			end
		end
	end
end

local function HandleInputElectricity(entityData)
	--if there is too much energy in the network then stop outputting more
	local limit = global.setting_max_electricity
	local invdata = global.invdata
	if
		limit >= 0
		and invdata
		and invdata[ELECTRICITY_ITEM_NAME]
		and invdata[ELECTRICITY_ITEM_NAME] >= limit
	then
		return
	end

	local entity = entityData.entity
	if entity.valid then
		local energy = entity.energy
		local availableEnergy = math.floor(energy / ELECTRICITY_RATIO)
		if availableEnergy > 0 then
			AddItemToInputList(ELECTRICITY_ITEM_NAME, availableEnergy)
			entity.energy = energy - (availableEnergy * ELECTRICITY_RATIO)
		end
	end
end

local function EmptyPutters(ticksLeft)
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


---------------------------------
--[[Update combinator methods]]--
---------------------------------

local function TableWithKeysLength(tableA)
	local count = 0
	for k, v in pairs(tableA) do
		count = count + 1
	end
	return count
end

local function AreTablesSame(tableA, tableB)
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


----------------------------------------
--[[Methods that talk with Clusterio]]--
----------------------------------------

local function ExportInputList()
	local items = {}
	for name, count in pairs(global.inputList) do
		table.insert(items, {name, count})
	end
	global.inputList = {}
	if #items > 0 then
		clusterio_api.send_json("subspace_storage:output", items)
	end
end

local function ExportOutputList()
	local items = {}
	for name, count in pairs(global.outputList) do
		table.insert(items, {name, count})
	end
	global.outputList = {}
	if #items > 0 then
		clusterio_api.send_json("subspace_storage:orders", items)
	end
end

local function GiveItemsToStorage(itemName, itemCount)
	--if this is called for the first time for an item then the result
	--is nil. if that's the case then set the result to 0 so it can
	--be used in arithmetic operations
	global.itemStorage[itemName] = global.itemStorage[itemName] or 0
	global.itemStorage[itemName] = global.itemStorage[itemName] + itemCount
end

local function Import(data)
	local items = game.json_to_table(data)
	for _, item in ipairs(items) do
		GiveItemsToStorage(item[1], item[2])
	end
end

local function UpdateInvCombinators()
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

	local items = game.item_prototypes
	local fluids = game.fluid_prototypes
	local virtuals = game.virtual_signal_prototypes
	if global.invdata then
		for name, count in pairs(global.invdata) do
			-- Combinator signals are limited to a max value of 2^31-1
			count = math.min(count, 0x7fffffff)
			if items[name] then
				invframe[#invframe+1] = {count=count,index=#invframe+1,signal={name=name,type="item"}}
			elseif fluids[name] then
				invframe[#invframe+1] = {count=count,index=#invframe+1,signal={name=name,type="fluid"}}
			elseif virtuals[name] then
				invframe[#invframe+1] = {count=count,index=#invframe+1,signal={name=name,type="virtual"}}
			end
		end
	end

	for _, invControl in pairs(global.invControls) do
		if invControl.valid then
			compat.set_parameters(invControl, invframe)
			invControl.enabled = true
		end
	end

end

local function UpdateInvData(data, full)
	if full then
		global.invdata = {}
	end
	local items = game.json_to_table(data)
	for _, item in ipairs(items) do
		global.invdata[item[1]] = item[2]
	end
	UpdateInvCombinators()
end

local function RegisterClusterioEvents()
	script.on_event(clusterio_api.events.on_instance_updated, UpdateInvCombinators)
end

----------------------
--[[Module exports]]--
----------------------

function Public.init()  
  RegisterClusterioEvents()
end

function Public.on_tick(event)
	--If the mod isn't connected then still pretend that it's
	--so items requests and removals can be fulfilled
	if global.setting_infinity_mode then
		global.ticksSinceMasterPinged = 0
	end

	global.ticksSinceMasterPinged = global.ticksSinceMasterPinged + 1
	if global.ticksSinceMasterPinged < 300 then
		global.isConnected = true

		if global.prevIsConnected == false then
			global.workTick = 0
		end

		local _workTick = global.workTick

		if _workTick == 0 then
			--importing electricity should be limited because it requests so
			--much at once. If it wasn't limited then the electricity could
			--make small burst of requests which requests >10x more than it needs
			--which could temporarily starve other networks.
			--Updating every 4 seconds give two chances to give electricity in
			--the 10 second period.
			local timeSinceLastElectricityUpdate = game.tick - global.lastElectricityUpdate
			global.allowedToMakeElectricityRequests = timeSinceLastElectricityUpdate > 60 * 3.5
		end

		local allowedToMakeElectricityRequests = global.allowedToMakeElectricityRequests

		--First retrieve requests and then fulfill them
		if _workTick >= 0 and _workTick < TICKS_TO_COLLECT_REQUESTS then
			if _workTick == 0 then
				ResetRequestGathering()
			end
			RetrieveGetterRequests(allowedToMakeElectricityRequests, TICKS_TO_COLLECT_REQUESTS - _workTick)
		elseif _workTick >= TICKS_TO_COLLECT_REQUESTS and _workTick < TICKS_TO_COLLECT_AND_FULFILL_REQUESTS then
			if _workTick == TICKS_TO_COLLECT_REQUESTS then
				UpdateUseableStorage()
				PrepareToFulfillRequests()
				ResetFulfillRequestIterators()
			end
			local ticksLeft = TICKS_TO_COLLECT_AND_FULFILL_REQUESTS - _workTick
			FulfillGetterRequests(allowedToMakeElectricityRequests, ticksLeft)
		end

		--Emptying putters will continiously happen
		--while requests are gathered and fulfilled
		if _workTick >= 0 and _workTick < TICKS_TO_COLLECT_AND_FULFILL_REQUESTS then
			if _workTick == 0 then
				ResetPutterIterators()
			end
			EmptyPutters(TICKS_TO_COLLECT_AND_FULFILL_REQUESTS - _workTick)
		end

		if     _workTick == TICKS_TO_COLLECT_AND_FULFILL_REQUESTS + 0 then
			ExportInputList()
			global.workTick = _workTick + 1
		elseif _workTick == TICKS_TO_COLLECT_AND_FULFILL_REQUESTS + 1 then
			ExportOutputList()

			--Restart loop
			global.workTick = 0
			if allowedToMakeElectricityRequests then
				global.lastElectricityUpdate = game.tick
			end
		else
			global.workTick = _workTick + 1
		end
	else
		global.isConnected = false
	end
	global.prevIsConnected = global.isConnected
end

-- Return items stuck in useableItemStorage
function Public.on_nth_tick(event)
	if not global.setting_infinity_mode then
		local staleTick = game.tick - NTH_TICK
		for itemName, entry in pairs(global.useableItemStorage) do
			if entry.lastPull < staleTick and entry.remainingItems > 0 then
				AddItemToInputList(itemName, entry.remainingItems)
				entry.remainingItems = 0
			end
		end
	end
end

return Public