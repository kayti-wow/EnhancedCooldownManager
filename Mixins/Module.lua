-- Enhanced Cooldown Manager addon for World of Warcraft
-- Author: Solär
-- Licensed under the GNU General Public License v3.0

local _, ns = ...
local ECM = ns.Addon
local Util = ns.Util
local Module = {}
ns.Mixins = ns.Mixins or {}
ns.Mixins.Module = Module

local DEFAULT_REFRESH_FREQUENCY = 0.066

--- Gets the name of the module.
--- @return string Name of the module
function Module:GetName()
    return self._name or "?"
end

function Module:GetConfig()
    return self._config
end

--- Refreshes the module if enough time has passed since the last update.
--- @param module table Module to refresh
--- @return boolean True if refreshed, false if skipped due to throttling
function Module:ThrottledRefresh(module)
    if module._paused then
        return false
    end

    local profile = ECM.db and ECM.db.profile
    local freq = (profile and profile.updateFrequency) or DEFAULT_REFRESH_FREQUENCY
    if GetTime() - (module._lastUpdate or 0) < freq then
        return false
    end

    module:Refresh()
    module._lastUpdate = GetTime()
    return true
end

function Module:SetPaused(paused)
    self._paused = paused
end

function Module:Enable()
    self._lastUpdate = GetTime()

    for _, eventConfig in ipairs(self._refreshEvents) do
        self:RegisterEvent(eventConfig.event, eventConfig.handler)
    end

    for _, eventName in ipairs(self._layoutEvents) do
        self:RegisterEvent(eventName, "UpdateLayout")
    end

    -- Register ourselves with the viewer hook to respond to global events
    ECM.ViewerHook:RegisterBar(self)

    self:OnEnable()

    ECM.ViewerHook:ScheduleLayoutUpdate(0.1)
end

function Module:Disable()
    for _, eventName in ipairs(self._layoutEvents) do
        self:UnregisterEvent(eventName)
    end

    for _, eventConfig in ipairs(self._refreshEvents) do
        self:UnregisterEvent(eventConfig.event)
    end

    local frame = self._frame
    if frame then
        frame:Hide()
    end

    self:OnDisable()

    Util.Log(self:GetName(), "Disabled")
end

function Module:UpdateLayout()
end

function Module:Refresh()
end

function Module:SetConfig(config)
    self._config = config
end

---@class RefreshEvent
---@field event string Event name
---@field handler string Handler method name

--- Adds the EventListener mixin to the target module.
--- @param target table Module to add the mixin to
--- @param layoutEvents string[]|nil List of layout events
--- @param refreshEvents RefreshEvent[]|nil List of refresh events
function Module.AddMixin(target, name, layoutEvents, refreshEvents)
    for k, v in pairs(Module) do
        if type(v) == "function" then
            target[k] = v
        end
    end

    target._name = name
    target._layoutEvents = layoutEvents or {}
    target._refreshEvents = refreshEvents or {}
end
