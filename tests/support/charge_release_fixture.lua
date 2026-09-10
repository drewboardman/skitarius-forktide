local function fixture(mode, global_threshold, weapon_threshold)
    local charge = { charge_level = 0, max_charge = 1 }
    local inputs = { action_two_hold = true }
    local hud
    local hud_handle
    local velocity_vector = { 3.5, 0, 0 }
    local extensions = {
        weapon_system = { _action_module_charge_component = charge },
        unit_data_system = { read_component = function() return nil end },
        visual_loadout_system = {
            _inventory_component = {
                wielded_slot = "slot_secondary",
                __data = {{ slot_secondary = "content/items/weapons/player/ranged/forcestaff_p2_m1" }},
            },
        },
        locomotion_system = { current_velocity = function() return velocity_vector end },
    }
    -- Stable player table: the real engine returns a cached player, so the
    -- fixture must not allocate here or it would pollute the benchmarks.
    local player = { player_unit = {}, unit_is_alive = function() return true end }
    local env = setmetatable({
        class = function() return {} end,
        get_mod = function()
            return {
                get = function() end,
                hook_require = function() end,
                add_require_path = function() end,
            }
        end,
        require = function(name)
            if name == "scripts/settings/equipment/weapon_templates/weapon_templates"
                or name == "scripts/utilities/ammo" then
                return {}
            end
            if name == "scripts/settings/ui/ui_workspace_settings" then
                return { screen = {} }
            end
            if name == "scripts/managers/ui/ui_widget" then
                return { create_definition = function() return {} end }
            end
            error("Unexpected game dependency: " .. name)
        end,
        Managers = {
            player = { local_player_safe = function() return player end },
            time = { time = function() return 0 end },
            ui = {
                get_hud = function()
                    return hud_handle
                end,
            },
        },
        ScriptUnit = { has_extension = function(_, name) return extensions[name] end },
        Vector3 = {
            length = function(vector)
                return math.sqrt(vector[1] * vector[1] + vector[2] * vector[2] + vector[3] * vector[3])
            end,
        },
    }, { __index = _G })
    local function load_module(name)
        local chunk = assert(loadfile("scripts/mods/Forktide/modules/" .. name .. ".lua"))
        setfenv(chunk, env)
        return chunk()
    end
    local function instance(methods)
        return setmetatable({}, { __index = methods })
    end
    local mod = {
        settings = { always_charge = true, always_charge_threshold = global_threshold },
        armoury = load_module("ForktideArmoury"),
        charge_release = load_module("ForktideChargeRelease"),
    }
    mod.ready = function() return true end
    mod.kill_sequence = function() end
    local engram = instance(load_module("ForktideEngram"))
    local weapon = instance(load_module("ForktideWeaponManager"))
    local binds = instance(load_module("ForktideBindManager"))
    local omnissiah = instance(load_module("ForktideOmnissiah"))
    mod.engram, mod.weapon_manager = engram, weapon
    engram:init(mod)
    weapon:init(mod)
    weapon.generates_peril_wrapper = function() return false end
    binds.bind_data = { override_primary = { RANGED = {
        forcestaff_p2_m1 = { automatic_fire = mode, auto_charge_threshold = weapon_threshold },
    } } }
    binds.input_value = function(_, input) return inputs[input] or false end
    binds.input = {}
    binds.active_binds = { override_primary = false }
    binds.engram = engram
    weapon:set_bind_manager(binds)
    engram:set_weapon_manager(weapon)
    engram:set_bind_manager(binds)
    engram:kill_engram()
    weapon:refresh_weapon()
    omnissiah:init(mod)
    omnissiah:set_bind_manager(binds)
    -- Real HUD element driven by the real widget manager, so HUD benchmarks
    -- include the actual string concatenation and color-table allocations.
    hud = instance(load_module("HudElementForktide"))
    hud._widgets_by_name = {
        forktide = {
            style = { icon = { size = { 50, 50 }, visible = false, color = { 255, 255, 255, 255 } } },
            content = { icon = "content/ui/materials/icons/circumstances/maelstrom_01" },
        },
    }
    hud_handle = {
        element = function(_, name)
            if name == "HudElementForktide" then return hud end
        end,
    }
    local widget = instance(load_module("ForktideWidgetManager"))
    widget.mod = mod
    widget.bind_manager = binds
    widget.type = "color"
    widget.active = true
    return {
        engram = engram,
        weapon = weapon,
        binds = binds,
        omnissiah = omnissiah,
        widget = widget,
        hud = hud,
        settings = mod.settings,
        inputs = inputs,
        charge = charge,
        equip = function(slot, path)
            local inventory = extensions.visual_loadout_system._inventory_component
            inventory.wielded_slot = slot
            inventory.__data[1][slot] = path
        end,
        release_at = function(level)
            charge.charge_level = level
            return omnissiah:resolve_conflicts("action_one_pressed", false, nil, "charge", nil) == true
        end,
    }
end

return fixture
