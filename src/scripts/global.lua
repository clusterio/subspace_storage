local Public = {}
local config = require("config")
local clusterio_api = require("__clusterio_lib__/api")


----------------------
--[[Module exports]]--
----------------------

local function UpdateSettings()
	global.setting_infinity_mode     = settings.global["subspace_storage-infinity-mode"].value
	global.setting_zone_width        = settings.global["subspace_storage-zone-width"].value
	global.setting_zone_height       = settings.global["subspace_storage-zone-height"].value
	global.setting_range_restriction = settings.global["subspace_storage-range-restriction-enabled"].value
	global.setting_max_electricity   = settings.global["subspace_storage-max-electricity"].value
end

local function Reset()
	global.ticksSinceMasterPinged = 601

	global.isConnected = false
	global.prevIsConnected = false

	global.allowedToMakeElectricityRequests = false

	global.workTick = 0

	global.config = global.config or
	{
		BWitems = {},
		item_is_whitelist = false,
		BWfluids = {},
		fluid_is_whitelist = false,
	}

	global.invdata = global.invdata or {}

	rendering.clear("subspace_storage")
	global.zoneDraw = {}

	global.outputList = {}
	global.inputList = {}
	global.itemStorage = {}

	global.useableItemStorage = global.useableItemStorage or {}
	local useableItemStorage = global.useableItemStorage

	for name, entry in pairs(useableItemStorage) do
		if not entry.remainingItems then
			useableItemStorage[name] = nil
		else
			if not entry.initialItemCount then
				entry.initialItemCount = entry.remainingItems
			end
			if not entry.lastPull then
				entry.lastPull = game.tick
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

	global.inputTanksData =
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

	global.invControls = {}
end


----------------------
--[[Module exports]]--
----------------------

function Public.on_init()
	clusterio_api.init()
	UpdateSettings()
	Reset()
end

function Public.on_load()
	clusterio_api.init()
end

function Public.on_configuration_changed(data)
	if not (data.mod_changes and data.mod_changes["subspace_storage"]) then
		return
	end

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
	UpdateSettings()
	Reset()
end

Public.on_runtime_mod_setting_changed = UpdateSettings

return Public