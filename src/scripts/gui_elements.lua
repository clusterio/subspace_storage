local Public = {}
local mod_gui = require("mod-gui")


-------------------
--[[GUI methods]]--
-------------------

local function createElemGui_INTERNAL(pane, guiName, elem_type, loadingList)
	local gui = pane.add{type = "table", name = guiName, column_count = 5}
	for _, item in pairs(loadingList) do
		gui.add{type = "choose-elem-button", elem_type = elem_type, item = item, fluid = item}
	end
	gui.add{type = "choose-elem-button", elem_type = elem_type}
end

local function toggleBWItemListGui(parent)
	if parent["clusterio-black-white-item-list-config"] then
		parent["clusterio-black-white-item-list-config"].destroy()
		return
	end

	local pane = parent.add{type = "frame", name = "clusterio-black-white-item-list-config", direction = "vertical"}
	pane.add{type = "label", caption = {"subspace_storage.item"}}
	pane.add{type = "checkbox", name = "clusterio-is-item-whitelist", caption = {"subspace_storage.whitelist"}, state = global.config.item_is_whitelist}
	createElemGui_INTERNAL(pane, "item-black-white-list", "item", global.config.BWitems)
end

local function toggleBWFluidListGui(parent)
	if parent["clusterio-black-white-fluid-list-config"] then
		parent["clusterio-black-white-fluid-list-config"].destroy()
		return
	end

	local pane = parent.add{type = "frame", name = "clusterio-black-white-fluid-list-config", direction = "vertical"}
	pane.add{type = "label", caption = {"subspace_storage.fluid"}}
	pane.add{type = "checkbox", name = "clusterio-is-fluid-whitelist", caption = {"subspace_storage.whitelist"}, state = global.config.fluid_is_whitelist}
	createElemGui_INTERNAL(pane, "fluid-black-white-list", "fluid", global.config.BWfluids)
end

local function processElemGui(event, toUpdateConfigName)--VERY WIP
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

local function toggleMainConfigGui(parent)
	if parent["clusterio-main-config-gui"] then
		parent["clusterio-main-config-gui"].destroy()
		return
	end

	local pane = parent.add{type = "frame", name = "clusterio-main-config-gui", direction = "vertical"}
	pane.add{type = "button", name = "clusterio-Item-WB-list", caption = {"subspace_storage.item-bw-list"}}
	pane.add{type = "button", name = "clusterio-Fluid-WB-list", caption = {"subspace_storage.fluid-bw-list"}}
end

local function processMainConfigGui(event)
	if event.element.name == "clusterio-Item-WB-list" then
		toggleBWItemListGui(game.players[event.player_index].gui.top)
	elseif event.element.name == "clusterio-Fluid-WB-list" then
		toggleBWFluidListGui(game.players[event.player_index].gui.top)
	end
end

local function makeConfigButton(parent)
	if not parent["clusterio-main-config-gui-toggle-button"] then
		parent.add{type = "sprite-button", name = "clusterio-main-config-gui-toggle-button", sprite="clusterio"}
	end
end


----------------------
--[[Module exports]]--
----------------------

function Public.on_gui_checked_state_changed(event)
	if not (event.element.parent) then
		return
	end

	if event.element.name == "clusterio-is-fluid-whitelist" then
		global.config.fluid_is_whitelist = event.element.state
	elseif event.element.name == "clusterio-is-item-whitelist" then
		global.config.item_is_whitelist = event.element.state
	end
end

function Public.on_gui_click(event)
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
end

function Public.on_gui_elem_changed(event)
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
end

function Public.on_gui_text_changed(event)
	if not (event.element and event.element.valid) then
		return
	end
end

function Public.on_player_joined_game(event)
	if game.players[event.player_index].admin then
		if game.players[event.player_index].gui.top["clusterio-main-config-gui-button"] then
			game.players[event.player_index].gui.top["clusterio-main-config-gui-button"].destroy()
		end

		makeConfigButton(mod_gui.get_button_flow(game.players[event.player_index]))
	end
end

return Public