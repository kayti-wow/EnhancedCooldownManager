-- Enhanced Cooldown Manager addon for World of Warcraft
-- Author: Solär
-- Licensed under the GNU General Public License v3.0

local _, ns = ...
local ECM = ns.Addon
local C = ns.Constants
local Util = ns.Util

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local LAYOUT_EVENTS = {
    PLAYER_MOUNT_DISPLAY_CHANGED = { delay = 0 },
    PLAYER_UPDATE_RESTING = { delay = 0 },
    PLAYER_SPECIALIZATION_CHANGED = { delay = 0 },
    PLAYER_ENTERING_WORLD = { delay = 0.4 },
    PLAYER_TARGET_CHANGED = { delay = 0 },
    PLAYER_REGEN_ENABLED = { delay = 0.1, combatChange = true },
    PLAYER_REGEN_DISABLED = { delay = 0, combatChange = true },
    ZONE_CHANGED_NEW_AREA = { delay = 0.1 },
    ZONE_CHANGED = { delay = 0.1 },
    ZONE_CHANGED_INDOORS = { delay = 0.1 },
    UPDATE_SHAPESHIFT_FORM = { delay = 0 },
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local _ecmFrames = {}
local _globallyHidden = false
local _hideReason = nil
local _inCombat = InCombatLockdown()
local _layoutPending = false
local _lastAlpha = 1

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Iterates over all Blizzard cooldown viewer frames.
--- @param fn fun(frame: Frame, name: string)
local function ForEachBlizzardFrame(fn)
    for _, name in ipairs(C.BLIZZARD_FRAMES) do
        local frame = _G[name]
        if frame then
            fn(frame, name)
        end
    end
end

--- Sets the globally hidden state for all frames (ECMFrames + Blizzard frames).
--- @param hidden boolean Whether to hide all frames
--- @param reason string|nil Reason for hiding ("mounted", "rest", "cvar")
local function SetGloballyHidden(hidden, reason)
    if _globallyHidden == hidden and _hideReason == reason then
        return
    end

    Util.Log("Layout", "SetGloballyHidden", { hidden = hidden, reason = reason })

    _globallyHidden = hidden
    _hideReason = reason

    -- Hide/show Blizzard frames
    ForEachBlizzardFrame(function(frame, name)
        if hidden then
            if frame:IsShown() then
                frame:Hide()
            end
        else
            frame:Show()
        end
    end)

    -- Hide/show ECMFrames
    for _, ecmFrame in pairs(_ecmFrames) do
        ecmFrame:SetHidden(hidden)
    end
end


local function SetAlpha(alpha)
    if _lastAlpha == alpha then
        return
    end

    ForEachBlizzardFrame(function(frame)
        frame:SetAlpha(alpha)
    end)

    for _, ecmFrame in pairs(_ecmFrames) do
        ecmFrame:SetAlpha(alpha)
    end

    _lastAlpha = alpha
end

--- Checks all fade and hide conditions and updates global state.
local function UpdateFadeAndHiddenStates()
    local globalConfig = ECM.db and ECM.db.profile and ECM.db.profile.global
    if not globalConfig then
        return
    end

    -- Check CVar first
    if not C_CVar.GetCVarBool("cooldownViewerEnabled") then
        SetGloballyHidden(true, "cvar")
        return
    end

    -- Check mounted
    if globalConfig.hideWhenMounted and IsMounted() then
        SetGloballyHidden(true, "mounted")
        return
    end

    if not _inCombat and globalConfig.hideOutOfCombatInRestAreas and IsResting() then
        SetGloballyHidden(true, "rest")
        return
    end

    -- No hide reason, show everything
    SetGloballyHidden(false, nil)

    local alpha = 1
    local fadeConfig = globalConfig.outOfCombatFade
    if not _inCombat and fadeConfig and fadeConfig.enabled then
        local shouldSkipFade = false

        if fadeConfig.exceptInInstance then
            local inInstance, instanceType = IsInInstance()
            if inInstance and C.GROUP_INSTANCE_TYPES[instanceType] then
                shouldSkipFade = true
            end
        end

        if not shouldSkipFade and fadeConfig.exceptIfTargetCanBeAttacked and UnitExists("target") and UnitCanAttack("player", "target") then
            shouldSkipFade = true
        end

        if not shouldSkipFade then
            local opacity = fadeConfig.opacity or 100
            alpha = math.max(0, math.min(1, opacity / 100))
        end
    end

    SetAlpha(alpha)
end

--- Calls UpdateLayout on all registered ECMFrames.
local function UpdateAllLayouts()
    for _, ecmFrame in pairs(_ecmFrames) do
        ecmFrame:UpdateLayout()
    end

    -- BuffBars may need to update after other bars reposition
    local BuffBars = ECM.BuffBars
    if BuffBars and BuffBars.UpdateLayout then
        BuffBars:UpdateLayout()
    end
end

--- Schedules a layout update after a delay (debounced).
--- @param delay number Delay in seconds
local function ScheduleLayoutUpdate(delay)
    if _layoutPending then
        return
    end

    _layoutPending = true
    C_Timer.After(delay or 0, function()
        _layoutPending = false
        UpdateFadeAndHiddenStates()
        UpdateAllLayouts()
    end)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Registers an ECMFrame to receive layout update events.
--- @param frame ECMFrame The frame to register
local function RegisterFrame(frame)
    assert(frame and type(frame) == "table" and frame.IsECMFrame, "RegisterFrame: invalid ECMFrame")
    assert(_ecmFrames[frame.Name] == nil, "RegisterFrame: frame with name '" .. frame.Name .. "' is already registered")
    _ecmFrames[frame.Name] = frame
    ECM.Log("Layout", "Frame registered", frame.Name)
end

--------------------------------------------------------------------------------
-- Event Handling
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

-- Register all layout events
for eventName in pairs(LAYOUT_EVENTS) do
    eventFrame:RegisterEvent(eventName)
end
eventFrame:RegisterEvent("CVAR_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    -- Handle CVAR_UPDATE specially
    if event == "CVAR_UPDATE" then
        if arg1 == "cooldownViewerEnabled" then
            ScheduleLayoutUpdate(0)
        end
        return
    end

    local config = LAYOUT_EVENTS[event]
    if not config then
        return
    end

    -- Track combat state
    if config.combatChange then
        _inCombat = (event == "PLAYER_REGEN_DISABLED")
    end

    -- Schedule update with delay
    if config.delay and config.delay > 0 then
        C_Timer.After(config.delay, function()
            UpdateFadeAndHiddenStates()
            UpdateAllLayouts()
        end)
    else
        UpdateFadeAndHiddenStates()
        UpdateAllLayouts()
    end
end)

--------------------------------------------------------------------------------
-- Module Lifecycle
--------------------------------------------------------------------------------

ECM.RegisterFrame = RegisterFrame
ECM.ScheduleLayoutUpdate = ScheduleLayoutUpdate
