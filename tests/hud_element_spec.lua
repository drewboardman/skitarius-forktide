local fixture = require("tests.support.charge_release_fixture")

describe("hud element", function()
    it("does not rebuild the colour table when the colour is unchanged", function()
        local f = fixture("none", 100, 50)
        local style = f.hud._widgets_by_name.forktide.style.icon

        f.hud:set_color(255, 255, 255, 255)
        local first = style.color
        f.hud:set_color(255, 255, 255, 255)
        assert.are.equal(first, style.color)
    end)

    it("replaces the colour table when the colour changes", function()
        local f = fixture("none", 100, 50)
        local style = f.hud._widgets_by_name.forktide.style.icon

        f.hud:set_color(255, 255, 255, 255)
        local first = style.color
        f.hud:set_color(255, 255, 195, 0)
        assert.are_not.equal(first, style.color)
        assert.are.same({ 255, 255, 195, 0 }, style.color)
    end)

    it("resolves the precomputed path for a known icon", function()
        local f = fixture("none", 100, 50)
        local content = f.hud._widgets_by_name.forktide.content

        f.hud:set_icon("circumstances/special_waves_01")
        assert.are.equal("content/ui/materials/icons/circumstances/special_waves_01", content.icon)
    end)

    it("falls back to building a path for an unknown icon", function()
        local f = fixture("none", 100, 50)
        local content = f.hud._widgets_by_name.forktide.content

        f.hud:set_icon("circumstances/custom_icon")
        assert.are.equal("content/ui/materials/icons/circumstances/custom_icon", content.icon)
    end)

    it("applies visibility only when it changes", function()
        local f = fixture("none", 100, 50)
        local style = f.hud._widgets_by_name.forktide.style.icon

        f.hud:set_visible(false)
        assert.is_false(style.visible)
        f.hud:set_visible(true)
        assert.is_true(style.visible)
    end)
end)
