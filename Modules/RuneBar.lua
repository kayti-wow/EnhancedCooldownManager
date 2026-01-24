local ADDON_NAME, ns = ...
local EnhancedCooldownManager = ns.Addon
local Util = ns.Util

-- Mixins
local BarFrame = ns.Mixins.BarFrame
local Lifecycle = ns.Mixins.Lifecycle
local TickRenderer = ns.Mixins.TickRenderer

local RuneBar = EnhancedCooldownManager:NewModule("RuneBar", "AceEvent-3.0")
EnhancedCooldownManager.RuneBar = RuneBar

--------------------------------------------------------------------------------
-- Domain Logic (DK rune-specific value/config handling)
--------------------------------------------------------------------------------

local function ShouldShowRuneBar()
    local profile = EnhancedCooldownManager.db and EnhancedCooldownManager.db.profile
    local cfg = profile.runeBar
    local _, class = UnitClass("player")
    return cfg and cfg.enabled and class == "DEATHKNIGHT"
end

--- Returns rune bar values.
---@param profile table
---@return number maxRunes
---@return number currentValue
---@return string kind
local function GetResourceValue(profile)
    local cfg = profile and profile.runeBar
    local maxRunes = (cfg and cfg.max)
    assert(maxRunes ~= nil, "Expected max config to be present.")
    assert(type(maxRunes) == "number", "Expected max to be a number.")

    local current = 0
    local now = GetTime()

    for i = 1, maxRunes do
        local start, duration, runeReady = GetRuneCooldown(i)
        if runeReady or (not start or start == 0) or (not duration or duration == 0) then
            current = current + 1
        else
            local elapsed = now - (tonumber(start) or now)
            local dur = tonumber(duration) or 0
            if dur > 0 then
                local pct = math.max(0, math.min(1, elapsed / dur))
                current = current + pct
            end
        end
    end

    return maxRunes, current, "runes"
end

--------------------------------------------------------------------------------
-- Fragmented Bars (DK Runes - individual bars per rune with recharge timers)
--------------------------------------------------------------------------------

--- Creates or returns fragmented sub-bars for runes.
---@param bar Frame
---@param maxSegments number
local function EnsureFragmentedBars(bar, maxSegments)
    local profile = EnhancedCooldownManager.db and EnhancedCooldownManager.db.profile
    local cfg = profile and profile.runeBar
    local gbl = profile and profile.global
    local tex = Util.GetTexture((cfg and cfg.texture) or (gbl and gbl.texture))

    for i = 1, maxSegments do
        if not bar.FragmentedBars[i] then
            local frag = CreateFrame("StatusBar", nil, bar)
            frag:SetFrameLevel(bar:GetFrameLevel() + 1)
            frag:SetStatusBarTexture(tex)
            frag:SetMinMaxValues(0, 1)
            frag:SetValue(0)
            bar.FragmentedBars[i] = frag
        end
        bar.FragmentedBars[i]:Show()
    end

    for i = maxSegments + 1, #bar.FragmentedBars do
        if bar.FragmentedBars[i] then
            bar.FragmentedBars[i]:Hide()
        end
    end
end

--- Updates fragmented rune display (individual bars per rune).
--- Only repositions bars when rune ready states change to avoid flickering.
---@param bar Frame
---@param maxRunes number
local function UpdateFragmentedRuneDisplay(bar, maxRunes)
    if not GetRuneCooldown then
        return
    end

    if not bar.FragmentedBars then
        return
    end

    local profile = EnhancedCooldownManager.db and EnhancedCooldownManager.db.profile
    local cfg = profile and profile.runeBar

    local barWidth = bar:GetWidth()
    local barHeight = bar:GetHeight()
    if barWidth <= 0 or barHeight <= 0 then
        return
    end

    bar.StatusBar:SetAlpha(0)

    local r, g, b = cfg.color[1], cfg.color[2], cfg.color[3]
    local readySet = {}
    local cdLookup = {}
    local now = GetTime()

    for i = 1, maxRunes do
        local start, duration, runeReady = GetRuneCooldown(i)
        if runeReady or not start or start == 0 or not duration or duration == 0 then
            readySet[i] = true
        else
            local elapsed = now - start
            local remaining = math.max(0, duration - elapsed)
            local frac = math.max(0, math.min(1, elapsed / duration))
            cdLookup[i] = { remaining = remaining, frac = frac }
        end
    end

    local statesChanged = not bar._lastReadySet
    if not statesChanged then
        for i = 1, maxRunes do
            if (readySet[i] or false) ~= (bar._lastReadySet[i] or false) then
                statesChanged = true
                break
            end
        end
    end

    if statesChanged then
        bar._lastReadySet = readySet

        local readyList = {}
        local cdList = {}
        for i = 1, maxRunes do
            if readySet[i] then
                table.insert(readyList, i)
            else
                table.insert(cdList, { index = i, remaining = cdLookup[i] and cdLookup[i].remaining or math.huge })
            end
        end
        table.sort(cdList, function(a, b) return a.remaining < b.remaining end)

        bar._displayOrder = {}
        for _, idx in ipairs(readyList) do
            table.insert(bar._displayOrder, idx)
        end
        for _, v in ipairs(cdList) do
            table.insert(bar._displayOrder, v.index)
        end

        local cfg = profile and profile.runeBar
        local gbl = profile and profile.global
        local tex = Util.GetTexture((cfg and cfg.texture) or (gbl and gbl.texture))

        -- Use same positioning logic as TickRenderer to avoid sub-pixel gaps
        local step = barWidth / maxRunes
        for pos, runeIndex in ipairs(bar._displayOrder) do
            local frag = bar.FragmentedBars[runeIndex]
            if frag then
                frag:SetStatusBarTexture(tex)
                frag:ClearAllPoints()
                local leftX = Util.PixelSnap((pos - 1) * step)
                local rightX = Util.PixelSnap(pos * step)
                local w = rightX - leftX
                frag:SetSize(w, barHeight)
                frag:SetPoint("LEFT", bar, "LEFT", leftX, 0)
                frag:SetMinMaxValues(0, 1)
                frag:Show()
            end
        end
    end

    for i = 1, maxRunes do
        local frag = bar.FragmentedBars[i]
        if frag then
            if readySet[i] then
                frag:SetValue(1)
                frag:SetStatusBarColor(r, g, b)
            else
                local cd = cdLookup[i]
                frag:SetValue(cd and cd.frac or 0)
                frag:SetStatusBarColor(r * 0.5, g * 0.5, b * 0.5)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Frame Management (uses BarFrame mixin)
--------------------------------------------------------------------------------

--- Returns or creates the rune bar frame.
---@return Frame
function RuneBar:GetFrame()
    if self._frame then
        return self._frame
    end

    Util.Log("RuneBar", "Creating frame")

    local profile = EnhancedCooldownManager.db and EnhancedCooldownManager.db.profile

    -- Create base bar with Background + StatusBar
    self._frame = BarFrame.Create(
        ADDON_NAME .. "RuneBar",
        UIParent,
        Util.DEFAULT_SEGMENT_BAR_HEIGHT
    )

    -- Add ticks frame for segment dividers
    BarFrame.AddTicksFrame(self._frame)

    -- Initialize fragmented bars container
    self._frame.FragmentedBars = {}

    -- Apply initial appearance
    BarFrame.ApplyAppearance(self._frame, profile and profile.runeBar, profile)

    return self._frame
end

--- Marks the rune bar as externally hidden.
---@param hidden boolean
function RuneBar:SetExternallyHidden(hidden)
    Lifecycle.SetExternallyHidden(self, hidden, "RuneBar")
end

--- Returns the frame only if currently shown.
---@return Frame|nil
function RuneBar:GetFrameIfShown()
    return Lifecycle.GetFrameIfShown(self)
end

--------------------------------------------------------------------------------
-- Layout and Rendering
--------------------------------------------------------------------------------

--- Updates layout: positioning, sizing, anchoring, appearance.
function RuneBar:UpdateLayout()
    local result = Lifecycle.CheckLayoutPreconditions(self, "runeBar", ShouldShowRuneBar, "RuneBar")
    if not result then
        Util.Log("RuneBar", "UpdateLayout - preconditions failed")
        return
    end

    Util.Log("RuneBar", "UpdateLayout - preconditions passed")

    self:Enable()

    local profile, cfg = result.profile, result.cfg
    local bar = self:GetFrame()
    local anchor, isFirstBar = Util.GetPreferredAnchor(EnhancedCooldownManager, "RuneBar")
    local viewer = Util.GetViewerAnchor()

    local desiredHeight = Util.GetBarHeight(cfg, profile, Util.DEFAULT_SEGMENT_BAR_HEIGHT)
    local desiredOffsetY = isFirstBar and anchor == viewer
        and -Util.GetTopGapOffset(cfg, profile)
        or 0
    local widthCfg = profile.width or {}
    local desiredWidth = widthCfg.value or 330
    local matchAnchorWidth = widthCfg.auto ~= false

    Util.ApplyLayoutIfChanged(bar, anchor, desiredOffsetY, desiredHeight, desiredWidth, matchAnchorWidth)

    -- Update appearance (background, texture)
    local tex = BarFrame.ApplyAppearance(bar, cfg, profile)
    bar._lastTexture = tex

    -- Get rune info
    local maxRunes, currentValue, kind = GetResourceValue(profile)
    Util.Log("RuneBar", "UpdateLayout - GetRuneBarValues", {
        maxRunes = maxRunes,
        currentValue = currentValue,
        kind = kind
    })

    if not maxRunes or maxRunes <= 0 then
        Util.Log("RuneBar", "UpdateLayout - hiding (no runes)")
        bar:Hide()
        return
    end

    bar._maxSegments = maxRunes
    bar.StatusBar:SetMinMaxValues(0, maxRunes)

    -- Set up fragmented bars for runes
    EnsureFragmentedBars(bar, maxRunes)
    bar._lastReadySet = nil
    bar._displayOrder = nil

    -- Set up ticks using TickRenderer
    local tickCount = math.max(0, maxRunes - 1)
    TickRenderer.EnsureTicks(bar, tickCount, bar.TicksFrame, "ticks")

    Util.Log("RuneBar", "UpdateLayout complete", {
        anchorName = anchor.GetName and anchor:GetName() or "unknown",
        height = desiredHeight,
        maxRunes = maxRunes
    })

    bar:Show()
    TickRenderer.LayoutSegmentTicks(bar, maxRunes, { 0, 0, 0, 1 }, 1, "ticks")

    -- Set up OnUpdate for DK runes (continuous recharge animation)
    if not bar._onUpdateAttached then
        bar._onUpdateAttached = true
        bar:SetScript("OnUpdate", function()
            RuneBar:OnUpdateThrottled()
        end)
    end

    self:Refresh()
end

--- Updates values: rune status and colors.
function RuneBar:Refresh()
    local profile = EnhancedCooldownManager.db and EnhancedCooldownManager.db.profile
    if self._externallyHidden or not (profile and profile.runeBar and profile.runeBar.enabled) then
        return
    end

    if not ShouldShowRuneBar() then
        return
    end

    local bar = self._frame
    if not bar then
        return
    end

    local maxRunes, _, _ = GetResourceValue(profile)
    if not maxRunes or maxRunes <= 0 then
        return
    end

    UpdateFragmentedRuneDisplay(bar, maxRunes)
    TickRenderer.LayoutSegmentTicks(bar, maxRunes, { 0, 0, 0, 1 }, 1, "ticks")
end

--------------------------------------------------------------------------------
-- Event Handling
--------------------------------------------------------------------------------

function RuneBar:OnUpdateThrottled()
    if self._externallyHidden then
        return
    end

    local profile = EnhancedCooldownManager.db and EnhancedCooldownManager.db.profile
    if not (profile and profile.runeBar and profile.runeBar.enabled) then
        return
    end

    Lifecycle.ThrottledRefresh(self, profile, function(mod)
        mod:Refresh()
    end)
end

function RuneBar:OnUnitEvent(event, unit)
    if unit == "player" then
        self:OnUpdateThrottled()
    end
end

--------------------------------------------------------------------------------
-- Module Lifecycle
--------------------------------------------------------------------------------

local LAYOUT_EVENTS = {
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_ENTERING_WORLD",
}

local REFRESH_EVENTS = {
    { event = "RUNE_POWER_UPDATE", handler = "OnUpdateThrottled" },
    { event = "RUNE_TYPE_UPDATE", handler = "OnUpdateThrottled" },
}

local REFRESH_EVENT_NAMES = {
    "RUNE_POWER_UPDATE",
    "RUNE_TYPE_UPDATE",
}

function RuneBar:Enable()
    Lifecycle.Enable(self, "RuneBar", REFRESH_EVENTS)
end

function RuneBar:Disable()
    if self._frame then
        if self._frame._onUpdateAttached then
            self._frame._onUpdateAttached = nil
            self._frame:SetScript("OnUpdate", nil)
        end
    end

    Lifecycle.Disable(self, "RuneBar", REFRESH_EVENT_NAMES)
end

function RuneBar:OnEnable()
    Lifecycle.OnEnable(self, "RuneBar", LAYOUT_EVENTS)
end

function RuneBar:OnDisable()
    Lifecycle.OnDisable(self, "RuneBar", LAYOUT_EVENTS, REFRESH_EVENT_NAMES)
end
