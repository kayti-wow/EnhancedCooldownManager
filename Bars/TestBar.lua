
local ADDON_NAME, ns = ...
local ECM = ns.Addon
local Util = ns.Util
local ECMFrame = ns.Mixins.ECMFrame

local C_TESTBAR = "TestBar"
local TestBar = ECM:NewModule(C_TESTBAR, "AceEvent-3.0")
ECM.TestBar = TestBar

-- Owns:
--  Event registration+handling

local function GetPrimaryResourceValue(resource, cfg)
    if not resource then
        return nil, nil, nil, nil
    end

    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)

    if cfg and cfg.showManaAsPercent and resource == Enum.PowerType.Mana then
        return max, current, UnitPowerPercent("player", resource, false, CurveConstants.ScaleTo100), "percent"
    end

    return max, current, current, "number"
end

--- Refreshes the frame if enough time has passed since the last update.
--- Uses the global `updateFrequency` setting to throttle refresh calls.
---@return boolean refreshed True if Refresh() was called, false if skipped due to throttling
function ECMFrame:ThrottledRefresh()
    local profile = ECM.db and ECM.db.profile
    local freq = (profile and profile.updateFrequency) or C.DEFAULT_REFRESH_FREQUENCY
    if GetTime() - (self._lastUpdate or 0) < freq then
        return false
    end

    self:Refresh()
    self._lastUpdate = GetTime()
    return true
end


function TestBar:Refresh(event, unitID, powerType)
    if unitID ~= "player" then
        return
    end

    local configSection = self:GetConfigSection()
    local frame = self:GetInnerFrame()
    local resource = UnitPowerType("player")
    local color = configSection and configSection.colors[resource]
    local max, current, displayValue, valueType = GetPrimaryResourceValue(resource, configSection)
    local r,g,b = color.r, color.g, color.b

    if valueType == "percent" then
        frame:SetText(string.format("%.0f%%", displayValue))
    else
        frame:SetText(tostring(displayValue))
    end

    Util.Log(self:GetName(), "Refresh", {
        resource = resource,
        max = max,
        current = current,
        displayValue = displayValue,
        valueType = valueType,
        text = frame:GetText()
    })

    self.StatusBar:SetMinMaxValues(0, max)
    self.StatusBar:SetValue(current)
    self.StatusBar:SetStatusBarColor(r, g, b)

    frame:SetTextVisible(configSection.showText ~= false)
    frame:Show()

    Util.Log(self:GetName(), "Refreshed")
end

function TestBar:CreateFrame()
    local frame = ECMFrame.CreateFrame(self)

    -- StatusBar for value display
    frame.StatusBar = CreateFrame("StatusBar", nil, frame)
    frame.StatusBar:SetAllPoints()
    frame.StatusBar:SetFrameLevel(frame:GetFrameLevel() + 1)
    Util.Log(self:GetName(), "CreateFrame", "Success")
    return frame
end

function TestBar:OnEnable()
    ECMFrame.AddMixin(self, "PowerBar")

    self:RegisterEvent("UNIT_POWER_UPDATE", "Refresh")

    Util.Log(self:GetName(), "Enabled", {
        layoutEvents=self._layoutEvents,
        refreshEvents=self._refreshEvents
    })
    -- ECM.ViewerHook:RegisterBar()
end

--- Called when the frame is disabled.
--- Unregisters all layout and refresh events.
function ECMFrame:OnDisable()
    -- for _, eventName in ipairs(self._layoutEvents) do
    --     self:UnregisterEvent(eventName)
    -- end

    -- for _, eventConfig in ipairs(self._refreshEvents) do
    --     self:UnregisterEvent(eventConfig.event)
    -- end

    -- Util.Log(self:GetName(), "Disabled", {
    --     layoutEvents=self._layoutEvents,
    --     refreshEvents=self._refreshEvents
    -- })
end
