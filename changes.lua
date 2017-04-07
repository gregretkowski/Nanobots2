--[[
ConfigurationChangedData
Table with the following fields:
old_version :: string (optional): Old version of the map. Present only when loading map version other than the current version.
new_version :: string (optional): New version of the map. Present only when loading map version other than the current version.
mod_changes :: dictionary string → ModConfigurationChangedData: Dictionary of mod changes. It is indexed by mod name.
ModConfigurationChangedData
Table with the following fields:
old_version :: string: Old version of the mod. May be nil if the mod wasn't previously present (i.e. it was just added).
new_version :: string: New version of the mod. May be nil if the mod is no longer present (i.e. it was just removed).
--]]
local mod_name = MOD.name or "not-set"
local migrations = {"1.2.0", "1.2.3", "1.6.6"}
local changes = {}

--Mark all migrations as complete during Init.
function changes.on_init(version)
    local list = {}
    for _, migration in ipairs(migrations) do
        list[migration] = version
    end
    return list
end

function changes.on_configuration_changed(event)
    --game.print(serpent.block(global._changes, {comment=false}))
    changes["map-change-always-first"]()
    if event.data.mod_changes then
        changes["any-change-always-first"]()
        if event.data.mod_changes[mod_name] then
            local this_mod_changes = event.data.mod_changes[mod_name]
            changes.on_mod_changed(this_mod_changes)
            game.print(mod_name..": changed from ".. tostring(this_mod_changes.old_version) .. " to " .. tostring(this_mod_changes.new_version))
        end
        changes["any-change-always-last"]()
    end
    changes["map-change-always-last"]()
end

function changes.on_mod_changed(this_mod_changes)
    global._changes = global._changes or {}
    --local old = this_mod_changes.old_version or MOD.version or "0.0.0"
    local migration_index = 1
    -- Find the last installed version
    for i, ver in ipairs(migrations) do
        if global._changes[ver] then
            migration_index = i + 1
        end
    end
    changes["mod-change-always-first"]()
    for i = migration_index, #migrations do
        if changes[migrations[i]] then
            changes[migrations[i]](this_mod_changes)
            global._changes[migrations[i]] = this_mod_changes.old_version or "0.0.0"
            game.print(mod_name..": Migration complete for ".. migrations[i])
        end
    end
    changes["mod-change-always-last"]()
end

-------------------------------------------------------------------------------
--[[Always run these before any migrations]]
changes["map-change-always-first"] = function()
end

changes["any-change-always-first"] = function()
end

changes["mod-change-always-first"] = function()
end

-------------------------------------------------------------------------------
--[[Version change code make sure to include the version in
--migrations table above.]]--

--Major changes made
changes["1.2.0"] = function ()
    global.current_index = 1
    global.config = global.config or table.deepcopy(MOD.config.control)
    remote.call("nanobots", "reset_config")
end

--Minor changes to reformat the changes made table
changes["1.2.3"] = function ()
    for _, history in pairs({"1.2.2", "1.2.1", "1.2.0"}) do
        if global._changes[history] and type(global._changes[history]) == "table" and global._changes[history].from then
            global._changes[history] = global._changes[history].from
        end
    end
end

--Major changes, add in player and force global tables
local robointerface = require("scripts/robointerface")
local Queue = require("scripts/queue")
local Player = require("scripts/player")
local Force = require("scripts/force")
changes["1.6.6"] = function ()
    global.forces = Force.init()
    global.players = Player.init()
    global.robointerfaces = robointerface.init()
    global.config.ticks_per_queue = 12
    global.config.loglevel = MOD.config.control.loglevel or 0
    global.config.inside_area_radius = MOD.config.control.inside_area_radius or 60
    global.config.nano_emmiter_queues_per_cycle = MOD.config.control.nano_emitter_queues_per_cycle or 80
    global.config.poll_rate = global.config.tick_mod or MOD.config.control.tick_mod or 60
    global.config.tick_mod = nil
    global.config.run_ticks = nil
    global.nano_queue = Queue.new()
    global.cell_queue = {}
    local old_queue = table.deepcopy(global.queued)
    local next_tick = Queue.next(game.tick, "player")
    if old_queue and type(old_queue) == "table" and old_queue.next then
        for _, qdata in pairs(old_queue) do
            if type("qdata") == "table" and qdata.action then
                Queue.insert(next_tick(), qdata)
            end
        end
    end
    --Cleanup un-needed changes
    global.queued = nil
    --global.networks = nil
    global._changes["1.6.0"] = nil
    global._changes["1.6.1"] = nil
    global._changes["1.6.2"] = nil
    global._changes["1.6.3"] = nil
    global._changes["1.6.4"] = nil
    global._changes["1.6.5"] = nil
end

-------------------------------------------------------------------------------
--[[Always run these at the end ]]--

changes["mod-change-always-last"] = function()
end

changes["any-change-always-last"] = function()
end

changes["map-change-always-last"] = function()
end

-------------------------------------------------------------------------------
return changes
