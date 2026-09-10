local ForktideWidgetManager = class("ForktideWidgetManager")

local forktide_hud_element = {
    package = "packages/ui/views/inventory_background_view/inventory_background_view",
    use_hud_scale = true,
    class_name = "HudElementForktide",
    filename = "Forktide/scripts/mods/Forktide/modules/HudElementForktide",
    visibility_groups = {
        "alive",
        "communication_wheel",
        "tactical_overlay"
    }
}

SETTINGS = {
    hud_element = true,
    hud_element_size = true,
    hud_element_type = true,
}

local _add_hud_element = function(element_pool)
    local found_key, _ = table.find_by_key(element_pool, "class_name", forktide_hud_element.class_name)
    if found_key then
        element_pool[found_key] = forktide_hud_element
    else
        table.insert(element_pool, forktide_hud_element)
    end
end

ForktideWidgetManager.init = function(self, mod)
    self.mod = mod
    self.active = mod:get("hud_element") or false
    self.size = mod:get("hud_element_size") or 50
    self.type = mod:get("hud_element_type") or "color"
    -- Inject HUD element
    mod:add_require_path(forktide_hud_element.filename)
    mod:hook_require("scripts/ui/hud/hud_elements_player_onboarding", _add_hud_element)
    mod:hook_require("scripts/ui/hud/hud_elements_player", _add_hud_element)
end

ForktideWidgetManager.set_bind_manager = function(self, bind_manager)
    self.bind_manager = bind_manager
end

--  ╔═╗╔═╗╔╦╗╔╦╗╦╔╗╔╔═╗╔═╗
--  ╚═╗║╣  ║  ║ ║║║║║ ╦╚═╗
--  ╚═╝╚═╝ ╩  ╩ ╩╝╚╝╚═╝╚═╝

ForktideWidgetManager.widget_setting = function(self, setting_name)
    return SETTINGS[setting_name]
end

ForktideWidgetManager.set_widget_setting = function(self, setting_name)
    local value = self.mod:get(setting_name)
    if setting_name == "hud_element" then
        self:set_status(value)
    elseif setting_name == "hud_element_size" then
        self:set_size(value)
    elseif setting_name == "hud_element_type" then
        self:set_type(value)
    end
end

ForktideWidgetManager.set_status = function(self, status)
    self.active = status
end

ForktideWidgetManager.set_size = function(self, size)
    local hud_element = self:get_hud_element()
    if hud_element then
        hud_element:set_size(size or 50)
    end
end

ForktideWidgetManager.set_type = function(self, type)
    self.type = type
end

--  ╦ ╦╦ ╦╔╦╗  ╔╦╗╔═╗╔╗╔╔═╗╔═╗╔═╗╔╦╗╔═╗╔╗╔╔╦╗
--  ╠═╣║ ║ ║║  ║║║╠═╣║║║╠═╣║ ╦║╣ ║║║║╣ ║║║ ║ 
--  ╩ ╩╚═╝═╩╝  ╩ ╩╩ ╩╝╚╝╩ ╩╚═╝╚═╝╩ ╩╚═╝╝╚╝ ╩ 

ForktideWidgetManager.get_hud_element = function(self)
    local hud = Managers.ui:get_hud()
    return hud and hud:element("HudElementForktide")
end

-- Set HUD element state based on mod status
ForktideWidgetManager.update_hud = function(self)
    local hud_element = self:get_hud_element()
    if hud_element then
        if self.active then
            -- If HUD setting is enabled and mod is enabled, make the icon visible
            if self.mod:ready() then
                -- If a keybind is actively intercepting input, show red icon
                if self.bind_manager and self.bind_manager:any_binds() then
                    -- Change active icon based on HUD type
                    if self.type == "icon" then
                        hud_element:set_icon("circumstances/special_waves_01")
                        hud_element:set_color(255,255,255,255)
                    elseif self.type == "color" then
                        hud_element:set_icon("circumstances/maelstrom_02")
                        hud_element:set_color(255,255,255,255)
                    elseif self.type == "icon_color" then
                        hud_element:set_icon("circumstances/special_waves_01")
                        hud_element:set_color(255,255,195,0)
                    else
                        hud_element:set_icon("circumstances/maelstrom_02")
                        hud_element:set_color(255,255,255,255)
                    end
                    hud_element:set_visible(true)
                -- If no keybind is pressed, show normal icon
                else
                    -- Change inactive icon based on HUD type
                    if self.type == "icon" then
                        hud_element:set_icon("circumstances/maelstrom_01")
                        hud_element:set_color(255,255,255,255)
                    else
                        hud_element:set_icon("circumstances/maelstrom_01")
                        hud_element:set_color(255,255,255,255)
                    end
                    hud_element:set_visible(true)
                end
            -- Hide element when mod is disabled
            else
                hud_element:set_visible(false)
            end
        -- Hide element when HUD setting is disabled
        else
            hud_element:set_visible(false)
        end
    end
end

return ForktideWidgetManager