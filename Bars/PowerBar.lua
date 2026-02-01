-- Enhanced Cooldown Manager addon for World of Warcraft
-- Author: Solär
-- Licensed under the GNU General Public License v3.0

local ADDON_NAME, ns = ...
local ECM = ns.Addon
local BarFrame = ns.Mixins.BarFrame
local C = ns.Constants
local PowerBar = ECM:NewModule("PowerBar", "AceEvent-3.0")
ECM.PowerBar = PowerBar

--- Returns the tick marks configured for the current class and spec.
---@return ECM_TickMark[]|nil
function PowerBar:GetCurrentTicks()
    local profile = ECM.db and ECM.db.profile
    local ticksCfg = profile and profile.powerBar and profile.powerBar.ticks
    if not ticksCfg or not ticksCfg.mappings then
        return nil
    end

    local classID = select(3, UnitClass("player"))
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    if not classID or not specID then
        return nil
    end

    local classMappings = ticksCfg.mappings[classID]
    if not classMappings then
        return nil
    end

    return classMappings[specID]
end

--- Updates tick markers on the power bar based on per-class/spec configuration.
---@param bar ECM_PowerBarFrame
---@param resource Enum.PowerType
---@param max number
function PowerBar:UpdateTicks(bar, resource, max)
    local ticks = self:GetCurrentTicks()
    if not ticks or #ticks == 0 then
        bar:HideAllTicks()
        return
    end

    local profile = ECM.db and ECM.db.profile
    local ticksCfg = profile and profile.powerBar and profile.powerBar.ticks
    local defaultColor = ticksCfg and ticksCfg.defaultColor or { r = 1, g = 1, b = 1, a = 0.8 }
    local defaultWidth = ticksCfg and ticksCfg.defaultWidth or 1

    bar:EnsureTicks(#ticks, bar.StatusBar)
    bar:LayoutValueTicks(bar.StatusBar, ticks, max, defaultColor, defaultWidth)
end

--- Updates values: status bar value, text, colors, ticks.
-- function PowerBar:Refresh()
--     local profile = ECM.db and ECM.db.profile
--     local cfg = profile and profile.powerBar
--     if self:IsHidden() or not (cfg and cfg.enabled) then
--         ECM.Log(self:GetName(), "Refresh skipped: bar is hidden or disabled")
--         return
--     end

--     if not ShouldShowPowerBar() then
--         ECM.Log(self:GetName(), "Refresh skipped: ShouldShowPowerBar returned false")
--         if self._frame then
--             self._frame:Hide()
--         end
--         return
--     end

--     local bar = self._frame
--     if not bar then
--         ECM.Log(self:GetName(), "Refresh skipped: frame not created yet")
--         return
--     end

--     if bar.RefreshAppearance then
--         bar:RefreshAppearance()
--     end

--     local resource = UnitPowerType("player")
--     local max, current, displayValue, valueType = GetPrimaryResourceValue(resource, cfg)

--     if not max then
--         ECM.Log(self:GetName(), "Refresh skipped:missing max value", { resource = resource })
--         bar:Hide()
--         return
--     end

--     current = current or 0
--     displayValue = displayValue or 0

--     local color = cfg.colors[resource]
--     local r, g, b = 1, 1, 1
--     if color then
--         r, g, b = color.r, color.g, color.b
--     end
--     bar:SetValue(0, max, current, r, g, b)

--     -- Update text
--     if valueType == "percent" then
--         bar:SetText(string.format("%.0f%%", displayValue))
--     else
--         bar:SetText(tostring(displayValue))
--     end

--     bar:SetTextVisible(cfg.showText ~= false)

--     -- Update ticks
--     -- self:UpdateTicks(bar, resource, max)

--     bar:Show()

--     ECM.Log(self:GetName(), "Refreshed", {
--         resource = resource,
--         max = max,
--         current = current,
--         displayValue = displayValue,
--         valueType = valueType
--     })
-- end

function PowerBar:GetStatusBarValues()
    local resource = UnitPowerType("player")
    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)
    local cfg = self:GetConfigSection()

    if cfg and cfg.showManaAsPercent and resource == Enum.PowerType.Mana then
        return max, current, UnitPowerPercent("player", resource, false, CurveConstants.ScaleTo100), true
    end

    return max, current, current, false
end

function PowerBar:ShouldShow()
    -- Base handles hidden and enabled checks
    local show = BarFrame.ShouldShow(self)
    if show then
        local _, class = UnitClass("player")
        local powerType = UnitPowerType("player")

        -- Hide mana bar for DPS specs, except mage/warlock/caster-form druid
        local role = GetSpecializationRole(GetSpecialization())
        if role == "DAMAGER" and powerType == Enum.PowerType.Mana then
            return C.SHOW_MANABAR_FOR_DPS_CLASSES[class] or false
        end

        return true
    end

    return false
end

function PowerBar:OnEnable()
    BarFrame.AddMixin(PowerBar, "PowerBar")
    BarFrame.OnEnable(self)
    self:RegisterEvent("UNIT_POWER_UPDATE", "ThrottledRefresh")
    ECM.Log(self.Name, "PowerBar:Enabled")
end

function PowerBar:OnDisable()
    self:UnregisterAllEvents()
    BarFrame.OnDisable(self)
    ECM.Log(self.Name, "PowerBar:Disabled")
end
