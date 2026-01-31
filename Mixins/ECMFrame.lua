-- Enhanced Cooldown Manager addon for World of Warcraft
-- Author: Solär
-- Licensed under the GNU General Public License v3.0

local _, ns = ...
local ECM = ns.Addon
local Util = ns.Util
local C = ns.Constants

local ECMFrame = {}
ns.Mixins = ns.Mixins or {}
ns.Mixins.ECMFrame = ECMFrame

---@class ECM_LayoutCache Cached layout state for change detection.
---@field anchor Frame|nil Last anchor frame.
---@field offsetX number|nil Last horizontal offset.
---@field offsetY number|nil Last vertical offset.
---@field width number|nil Last applied width.
---@field height number|nil Last applied height.
---@field anchorPoint AnchorPoint|nil Last anchor point.
---@field anchorRelativePoint AnchorPoint|nil Last relative anchor point.
---@field mode "chain"|"independent"|nil Last positioning mode.

---@class RefreshEvent
---@field event string WoW event name to listen for
---@field handler string Name of the handler method on the frame

---@class ECMFrame : AceModule
---@field _name string Internal name of the frame
---@field _config table|nil Reference to the frame's configuration profile section
---@field _layoutEvents string[] List of WoW events that trigger layout updates
---@field _refreshEvents RefreshEvent[] List of events and handlers for refresh triggers
---@field _lastUpdate number|nil Timestamp of the last throttled refresh
---@field _layoutCache ECM_LayoutCache|nil Cached layout parameters.
---@field GetName fun(self: ECMFrame): string Gets the frame name.
----@field GetConfig fun(self: ECMFrame): table Gets the frame configuration.
---@field GetGlobalConfig fun(self: ECMFrame): table Gets the global configuration section.
---@field GetConfigSection fun(self: ECMFrame): table Gets the specific config section for this frame.
---@field ThrottledRefresh fun(self: ECMFrame): boolean Refreshes the frame if enough time has passed since the last update.
---@field OnEnable fun(self: ECMFrame) Called when the frame is enabled.
---@field OnDisable fun(self: ECMFrame) Called when the frame is disabled.
---@field UpdateLayout fun(self: ECMFrame) Updates the visual layout of the frame.
---@field Refresh fun(self: ECMFrame) Refreshes the frame's display state.
---@field OnConfigChanged fun(self: ECMFrame) Called when the frame's configuration has changed.
---@field OnUpdateLayout fun(self: ECMFrame) Updates the visual layout of the frame.
---@field SetConfig fun(self: ECMFrame, config: table) Sets the configuration table for this frame.
---@field ApplyLayout fun(self: ECMFrame): boolean Applies layout parameters.
---@field AddMixin fun(target: table, name: string, profile: table, layoutEvents?: string[], refreshEvents?: RefreshEvent[]) Applies the Module mixin to a target table.

--- Determine the correct anchor for this specific frame in the fixed order.
local function CalculateChainLayout(frameName, config)
    -- Find the ideal position
    local stopIndex = #C.CHAIN_ORDER + 1
    if frameName then
        for i, name in ipairs(C.CHAIN_ORDER) do
            if name == frameName then
                stopIndex = i
                break
            end
        end
    end

    -- Work backwards to identify the first valid frame to anchor to.
    -- Valid frames are those that are enabled and visible.
    for i = stopIndex - 1, 1, -1 do
        local barName = C.CHAIN_ORDER[i]
        local barModule = ECM:GetModuleByName(barName)
        if barModule and barModule:IsEnabled() then
            local barFrame = barModule:GetBarFrame()
            if barFrame and barFrame:IsVisible() then
                return barFrame
            end
        end
    end

    -- If none of the preceeding frames in the chain are valid, anchor to the viewer as the first.
    return _G[C.VIEWER] or UIParent
end

--- Gets the name of the frame.
---@return string name Name of the frame, or "?" if not set
function ECMFrame:GetName()
    return self._name or "?"
end

function ECMFrame:GetConfig()
    assert(false, "Deprecated. Use GetGlobalConfig or GetConfigSection.")
end

--- Gets the configuration table for this frame.
--- Asserts if the config has not been set via `AddMixin` or `SetConfig`.
---@return table config The frame's configuration table
function ECMFrame:GetGlobalConfig()
    assert(self._config, "config not set for frame " .. self:GetName())
    return self._config[C.CONFIG_SECTION_GLOBAL]
end

--- Gets the specific configuration section for this frame.
---@return table configSection The frame's specific configuration section
function ECMFrame:GetConfigSection()
    assert(self._config, "config not set for frame " .. self:GetName())
    assert(self._configKey, "configKey not set for frame " .. self:GetName())
    return self._config[self._configKey]
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

--- Called when the frame is enabled.
--- Registers all configured layout and refresh events.
function ECMFrame:OnEnable()
    assert(self._layoutEvents, "layoutEvents not set for frame " .. self:GetName())
    assert(self._refreshEvents, "refreshEvents not set for frame " .. self:GetName())

    self._lastUpdate = GetTime()

    for _, eventConfig in ipairs(self._refreshEvents) do
        self:RegisterEvent(eventConfig.event, eventConfig.handler)
    end

    for _, eventName in ipairs(self._layoutEvents) do
        self:RegisterEvent(eventName, "UpdateLayout")
    end

    Util.Log(self:GetName(), "Enabled", {
        layoutEvents=self._layoutEvents,
        refreshEvents=self._refreshEvents
    })
end

--- Called when the frame is disabled.
--- Unregisters all layout and refresh events.
function ECMFrame:OnDisable()
    assert(self._layoutEvents, "layoutEvents not set for frame " .. self:GetName())
    assert(self._refreshEvents, "refreshEvents not set for frame " .. self:GetName())

    for _, eventName in ipairs(self._layoutEvents) do
        self:UnregisterEvent(eventName)
    end

    for _, eventConfig in ipairs(self._refreshEvents) do
        self:UnregisterEvent(eventConfig.event)
    end

    Util.Log(self:GetName(), "Disabled", {
        layoutEvents=self._layoutEvents,
        refreshEvents=self._refreshEvents
    })
end

--- Updates the visual layout of the frame.
--- Override this method in concrete frames to handle layout changes.
function ECMFrame:UpdateLayout()
    local frameName = self:GetName()
    local config = self:GetConfigSection()
    local anchorMode = config.anchorMode

    if anchorMode == "chain" then
        local anchor = CalculateChainLayout(frameName, config)

    elseif anchorMode == "independent" then

    else
        ECM:Print("Unknown anchor mode: " .. tostring(anchorMode))
        return false
    end

    local anchor = module_config:GetAnchorFrame()
    local offsetX, offsetY = module_config:GetOffsets()
    local width, height = module_config:GetDimensions()
    local anchorPoint, anchorRelativePoint = module_config:GetAnchorPoints()
    local mode = module_config:GetPositioningMode()

    return self:ApplyLayoutInternal(anchor, offsetX, offsetY, width, height, anchorPoint, anchorRelativePoint, mode)
end

--- Updates the visual layout of the frame.
--- Override this method in concrete frames to handle layout changes.
function ECMFrame:OnUpdateLayout()
end

--- Refreshes the frame's display state.
--- Override this method in concrete frames to update visual state.
function ECMFrame:Refresh()
end

--- Called when the frame's configuration has changed.
--- Override this method to respond to configuration updates.
function ECMFrame:OnConfigChanged()
end

--- Sets the configuration table for this frame.
---@param config table The configuration table to use
function ECMFrame:SetConfig(config)
    assert(config, "config required")
    self._config = config
    self:OnConfigChanged()
end

--- Applies layout parameters to a frame, caching state to reduce updates.
---@param anchor Frame The anchor frame to attach to.
---@param offsetX number Horizontal offset from the anchor point.
---@param offsetY number Vertical offset from the anchor point.
---@param width number|nil Width to set on the frame, or nil to skip.
---@param height number|nil Height to set on the frame, or nil to skip.
---@param anchorPoint AnchorPoint|nil Anchor point on the frame (default "TOPLEFT").
---@param anchorRelativePoint AnchorPoint|nil Relative point on the anchor (default "BOTTOMLEFT").
---@param mode "chain"|"independent"|nil Positioning mode identifier.
---@return boolean changed True if layout changed
function ECMFrame:ApplyLayoutInternal(anchor, offsetX, offsetY, width, height, anchorPoint, anchorRelativePoint, mode)
    assert(self, "frame required")
    assert(anchor, "anchor required")

    offsetX = offsetX or 0
    offsetY = offsetY or 0
    anchorPoint = anchorPoint or "TOPLEFT"
    anchorRelativePoint = anchorRelativePoint or "BOTTOMLEFT"
    local layoutCache = self._layoutCache or {}

    local layoutChanged = layoutCache.anchor ~= anchor
        or layoutCache.offsetX ~= offsetX
        or layoutCache.offsetY ~= offsetY
        or layoutCache.anchorPoint ~= anchorPoint
        or layoutCache.anchorRelativePoint ~= anchorRelativePoint
        or layoutCache.mode ~= mode

    if layoutChanged then
        self:ClearAllPoints()
        if mode == "chain" then
            self:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offsetX, offsetY)
            self:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", offsetX, offsetY)
        else
            assert(anchor ~= nil, "anchor required for independent mode")
            self:SetPoint(anchorPoint, anchor, anchorRelativePoint, offsetX, offsetY)
        end

        layoutCache.anchor = anchor
        layoutCache.offsetX = offsetX
        layoutCache.offsetY = offsetY
        layoutCache.anchorPoint = anchorPoint
        layoutCache.anchorRelativePoint = anchorRelativePoint
        layoutCache.mode = mode
    end

    if height and layoutCache.height ~= height then
        self:SetHeight(height)
        layoutCache.height = height
        layoutChanged = true
    elseif height == nil then
        layoutCache.height = nil
    end

    if width and layoutCache.width ~= width then
        self:SetWidth(width)
        layoutCache.width = width
        layoutChanged = true
    elseif width == nil then
        layoutCache.width = nil
    end

    return layoutChanged
end


--- Applies the frame mixin to a target table.
--- Copies all mixin methods that the target doesn't already have,
--- preserving frame-specific overrides of UpdateLayout, Refresh, etc.
---@param target table frame table to add the mixin to
---@param name string Name of the frame
---@param profile table Configuration profile table
---@param layoutEvents? string[] List of WoW events that trigger layout updates
---@param refreshEvents? RefreshEvent[] List of refresh event configurations
function ECMFrame.AddMixin(target, name, profile, layoutEvents, refreshEvents)
    assert(target, "target required")
    assert(name, "name required")
    assert(profile, "profile required")

    -- Only copy methods that the target doesn't already have.
    -- This preserves frame-specific overrides of UpdateLayout, Refresh, etc.
    for k, v in pairs(ECMFrame) do
        if type(v) == "function" and target[k] == nil then
            target[k] = v
        end
    end

    target._name = name
    target._layoutEvents = layoutEvents or {}
    target._refreshEvents = refreshEvents or {}
    target._config = profile
    target._configKey = name
    target._layoutCache = {}
end
