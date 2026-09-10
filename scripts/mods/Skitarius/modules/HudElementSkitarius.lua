local mod = get_mod("Skitarius")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local ui_definitions = {
    scenegraph_definition = {
        screen = UIWorkspaceSettings.screen,
        skitarius_container = {
            parent = "screen",
            vertical_alignment = "bottom",
            horizontal_alignment = "right",
            size = { 50, 50 },
            position = {
                -370,
                -100,
                10
            }
        }
    },
    widget_definitions = {
        skitarius = UIWidget.create_definition({
            {
                style_id = "icon",
                value_id = "icon",
                pass_type = "texture",
                value = "content/ui/materials/icons/circumstances/maelstrom_01",
                style = {
                    size = { nil, nil },
                }
            }
        }, "skitarius_container")
    }
}

local HudElementSkitarius = class("HudElementSkitarius", "HudElementBase")

HudElementSkitarius.init = function(self, parent, draw_layer, start_scale)
    HudElementSkitarius.super.init(self, parent, draw_layer, start_scale, ui_definitions)
    self:set_size(mod:get("hud_element_size"))
    self:set_icon("circumstances/maelstrom_01")
    self:set_visible(false)
end

-- update_hud runs every frame, so the setters below avoid rebuilding the icon
-- path and the colour table when the displayed state has not actually changed.
local ICON_PATHS = {
    ["circumstances/maelstrom_01"] = "content/ui/materials/icons/circumstances/maelstrom_01",
    ["circumstances/maelstrom_02"] = "content/ui/materials/icons/circumstances/maelstrom_02",
    ["circumstances/special_waves_01"] = "content/ui/materials/icons/circumstances/special_waves_01",
}

HudElementSkitarius.set_visible = function(self, vis)
    local style = self._widgets_by_name.skitarius.style.icon
    if style.visible ~= vis then
        style.visible = vis
    end
end

HudElementSkitarius.set_color = function(self, a, r, g, b)
    local style = self._widgets_by_name.skitarius.style.icon
    local color = style.color
    if color and color[1] == a and color[2] == r and color[3] == g and color[4] == b then
        return
    end
    style.color = { a, r, g, b }
end

HudElementSkitarius.set_size = function(self, side_length)
    local widget_size = self._widgets_by_name.skitarius.style.icon.size
    widget_size[1] = side_length
    widget_size[2] = side_length
end

HudElementSkitarius.set_icon = function(self, icon)
    local content = self._widgets_by_name.skitarius.content
    local icon_path = ICON_PATHS[icon] or ("content/ui/materials/icons/" .. icon)
    if content.icon ~= icon_path then
        content.icon = icon_path
    end
end

--[[ Icon References ]
    circumstances/maelstrom_01 : Skull with normal eyes
    circumstances/maelstrom_02 : Skull with red eyes

--]]

return HudElementSkitarius
