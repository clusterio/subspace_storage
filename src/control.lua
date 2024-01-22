local config  = require("config")
local Tracker = require("scripts.entity_tracker")
local Global  = require("scripts.global")
local GUI     = require("scripts.gui_elements")
local Updater = require("scripts.updater")

--===============================================================================================--

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

------------------------------
--[[Thing resetting events]]--
------------------------------
script.on_init(function()
	Global.on_init()
	Updater.init()
	Tracker.AddAllEntitiesOfNames(
		{
			"subspace-item-injector",
			"subspace-item-extractor",
			"subspace-fluid-injector",
			"subspace-fluid-extractor",
			config.INV_COMBINATOR_NAME,
			"subspace-electricity-injector",
			"subspace-electricity-extractor"
		})
end)

script.on_load(function()
	Global.on_load()
	Updater.init()
end)

script.on_configuration_changed(Global.on_configuration_changed)

script.on_event(defines.events.on_runtime_mod_setting_changed, Global.on_runtime_mod_setting_changed)


-----------------------------
--[[Thing creation events]]--
-----------------------------
script.on_event(defines.events.on_built_entity, Tracker.OnBuiltEntity)
script.on_event(defines.events.on_robot_built_entity, Tracker.OnBuiltEntity)


----------------------------
--[[Thing killing events]]--
----------------------------
script.on_event(defines.events.on_entity_died, Tracker.OnKilledEntity)
script.on_event(defines.events.on_robot_pre_mined, Tracker.OnKilledEntity)
script.on_event(defines.events.on_pre_player_mined_item, Tracker.OnKilledEntity)
script.on_event(defines.events.script_raised_destroy, Tracker.OnKilledEntity)


----------------------
--[[Zone rendering]]--
----------------------
script.on_event(defines.events.on_player_cursor_stack_changed, Tracker.on_player_cursor_stack_changed)


------------------------
--[[Entities updates]]--
------------------------
script.on_event(defines.events.on_tick, Updater.on_tick)

script.on_nth_tick(config.NTH_TICK, Updater.on_nth_tick)


-------------------
--[[GUI methods]]--
-------------------
script.on_event(defines.events.on_gui_checked_state_changed, GUI.on_gui_checked_state_changed)

script.on_event(defines.events.on_gui_click, GUI.on_gui_checked_state_changed)

script.on_event(defines.events.on_gui_elem_changed, GUI.on_gui_elem_changed)

script.on_event(defines.events.on_gui_text_changed, GUI.on_gui_text_changed)

script.on_event(defines.events.on_player_joined_game, GUI.on_player_joined_game)
