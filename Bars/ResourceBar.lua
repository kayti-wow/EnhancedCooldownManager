-- Enhanced Cooldown Manager addon for World of Warcraft
-- Author: Solär
-- Licensed under the GNU General Public License v3.0

local ADDON_NAME, ns = ...
local ECM = ns.Addon
local Util = ns.Util

local BarFrame = ns.Mixins.BarFrame

local ResourceBar = ECM:NewModule("ResourceBar", "AceEvent-3.0")
ECM.ResourceBar = ResourceBar

local C_SPECID_DH_HAVOC = 1
local C_SPECID_DH_DEVOURER = 3

--------------------------------------------------------------------------------
-- Domain Logic (module-specific value/config handling)
--------------------------------------------------------------------------------

-- Discrete power types that should be shown as resources
local discretePowerTypes = {
    [Enum.PowerType.ComboPoints] = true,
    [Enum.PowerType.Chi] = true,
    [Enum.PowerType.HolyPower] = true,
    [Enum.PowerType.SoulShards] = true,
    [Enum.PowerType.Essence] = true,
}

--- Returns the discrete power type for the current player, if any.
---@return Enum.PowerType|nil powerType
local function GetDiscretePowerType()
    local _, class = UnitClass("player")

    for powerType in pairs(discretePowerTypes) do
        local max = UnitPowerMax("player", powerType)
        if max and max > 0 then
            if class == "DRUID" then
                local formIndex = GetShapeshiftForm()
                if formIndex == 2 then
                    return powerType
                end
            else
                return powerType
            end
        end
    end
    return nil
end

--- Returns whether the Devourer DH is in void meta form.
---@return boolean|nil isVoidMeta
local function GetDevourerVoidMetaState()
    local _, class = UnitClass("player")
    if class ~= "DEMONHUNTER" or GetSpecialization() ~= C_SPECID_DH_DEVOURER then
        return nil
    end

    local collapsingStar = C_UnitAuras.GetUnitAuraBySpellID("player", 1227702)
    if collapsingStar then
        return true
    end

    local voidFragments = C_UnitAuras.GetUnitAuraBySpellID("player", 1225789)
    if voidFragments then
        return false
    end

    return false
end

--- Returns resource bar values based on class/power type.
---@param profile table
---@return number|nil maxResources
---@return number|nil currentValue
---@return Enum.PowerType|string|nil kind
---@return boolean|nil isVoidMeta
local function GetValues(profile)
    local cfg = profile and profile.resourceBar
    local _, class = UnitClass("player")

    -- Special: DH Souls (aura-based stacks)
    if class == "DEMONHUNTER" then
        if GetSpecialization() == C_SPECID_DH_DEVOURER then
            -- Devourer is tracked by two spells. One is while not in void meta, and the second is while in it.
            local voidFragments = C_UnitAuras.GetUnitAuraBySpellID("player", 1225789)
            local collapsingStar = C_UnitAuras.GetUnitAuraBySpellID("player", 1227702)
            if collapsingStar then
                return 6, (collapsingStar.applications or 0) / 5, "souls", true
            end
            if voidFragments then
                return 7, (voidFragments.applications or 0) / 5, "souls", false
            end
            -- Transition gap: default to non-meta state so the color resets reliably.
            return 7, 0, "souls", false
        else
            -- Havoc and vengeance use the same type of soul fragments
            local maxSouls = (cfg and cfg.demonHunterSoulsMax) or 5
            local count = C_Spell.GetSpellCastCount(247454) or 0
            return maxSouls, count, "souls", nil
        end
    end

    -- Everything else that's supported is a first-class resource
    local powerType = GetDiscretePowerType()
    if powerType then
        local max = UnitPowerMax("player", powerType) or 0
        local current = UnitPower("player", powerType) or 0
        return max, current, powerType, nil
    end

    return nil, nil, nil, nil
end

--------------------------------------------------------------------------------
-- ECMFrame/BarFrame Overrides
--------------------------------------------------------------------------------

function ResourceBar:ShouldShow()
    local config = self:GetConfigSection()
    local _, class = UnitClass("player")
    local discretePower = GetDiscretePowerType()
    return not self._hidden and config.enabled and (class == "DEMONHUNTER" or discretePower ~= nil)
end

function ResourceBar:GetStatusBarValues()
    local profile = ECM.db and ECM.db.profile
    local maxResources, currentValue, kind, isVoidMeta = GetValues(profile)

    if not maxResources or maxResources <= 0 then
        return 0, 1, 0, false
    end

    currentValue = currentValue or 0
    return currentValue, maxResources, currentValue, false
end

--------------------------------------------------------------------------------
-- Layout and Refresh
--------------------------------------------------------------------------------

function ResourceBar:Refresh(force)
    -- Base refresh checks (enabled, hidden, etc.)
    local continue = ECMFrame.Refresh(self, force)
    if not continue then
        Util.Log(self.Name, "ResourceBar:Refresh", "Skipping refresh (base checks)")
        return false
    end

    local profile = ECM.db and ECM.db.profile
    local globalConfig = self:GetGlobalConfig()
    local cfg = self:GetConfigSection()
    local frame = self:GetInnerFrame()

    -- Get resource values
    local maxResources, currentValue, kind, isVoidMeta = GetValues(profile)
    if not maxResources or maxResources <= 0 then
        Util.Log(self.Name, "ResourceBar:Refresh", "No resources available, hiding")
        frame:Hide()
        return false
    end

    currentValue = currentValue or 0
    local isDevourer = (kind == "souls" and GetSpecialization() == C_SPECID_DH_DEVOURER)

    -- Determine color (ResourceBar-specific logic for DH souls)
    local color = cfg.colors and cfg.colors[kind]
    if isDevourer then
        if isVoidMeta then
            color = cfg.colors and cfg.colors.devourerMeta
        else
            color = cfg.colors and cfg.colors.devourerNormal
        end
    end

    -- Track void meta state changes
    if isDevourer then
        self._lastVoidMeta = not not isVoidMeta
    else
        self._lastVoidMeta = nil
    end

    local r, g, b = 1, 1, 1
    if color then
        r, g, b = color.r, color.g, color.b
    end

    -- Update StatusBar
    frame.StatusBar:SetMinMaxValues(0, maxResources)
    frame.StatusBar:SetValue(currentValue)
    frame.StatusBar:SetStatusBarColor(r, g, b)

    -- Set texture
    local tex = Util.GetTexture((cfg and cfg.texture) or (globalConfig and globalConfig.texture))
    if tex then
        frame.StatusBar:SetStatusBarTexture(tex)
    end

    -- Handle text and ticks based on resource type
    local showText = cfg.showText ~= false
    if isDevourer then
        -- Devourer shows value as text (multiply by 5 for fragment count), no ticks
        if showText and frame.TextValue then
            local displayValue = math.floor(currentValue * 5)
            frame:SetText(tostring(displayValue))
            Util.ApplyFont(frame.TextValue, profile)
        end
        frame:SetTextVisible(showText)
        self:HideAllTicks("tickPool")
    else
        -- Normal resources show ticks (dividers), optionally show numeric value as text
        if showText and frame.TextValue then
            frame:SetText(tostring(math.floor(currentValue)))
            Util.ApplyFont(frame.TextValue, profile)
        end
        frame:SetTextVisible(showText)

        -- Render tick dividers between resources
        local tickCount = math.max(0, maxResources - 1)
        self:EnsureTicks(tickCount, frame.TicksFrame, "tickPool")
        self:LayoutResourceTicks(maxResources, { r = 0, g = 0, b = 0, a = 1 }, 1, "tickPool")
    end

    frame:Show()
    Util.Log(self.Name, "ResourceBar:Refresh", {
        maxResources = maxResources,
        currentValue = currentValue,
        kind = kind,
        isDevourer = isDevourer,
        isVoidMeta = isVoidMeta,
        showText = showText,
        r = r, g = g, b = b,
    })

    return true
end

--------------------------------------------------------------------------------
-- Event Handling
--------------------------------------------------------------------------------

function ResourceBar:OnUnitAura(event, unit)
    if unit ~= "player" then
        return
    end

    if self:_MaybeRefreshForVoidMetaStateChange() then
        return
    end

    self:ThrottledRefresh()
end

function ResourceBar:OnUnitPower(event, unit)
    if unit ~= "player" then
        return
    end

    if self:_MaybeRefreshForVoidMetaStateChange() then
        return
    end

    self:ThrottledRefresh()
end

--- Forces an immediate refresh when Devourer void meta state changes.
---@return boolean refreshed
function ResourceBar:_MaybeRefreshForVoidMetaStateChange()
    local isVoidMeta = GetDevourerVoidMetaState()
    if isVoidMeta == nil then
        return false
    end

    if self._lastVoidMeta == nil then
        self._lastVoidMeta = isVoidMeta
        return false
    end

    if isVoidMeta ~= self._lastVoidMeta then
        self._lastVoidMeta = isVoidMeta
        self:Refresh(true)
        self._lastUpdate = GetTime()
        return true
    end

    return false
end

--------------------------------------------------------------------------------
-- Module Lifecycle
--------------------------------------------------------------------------------

function ResourceBar:OnEnable()
    BarFrame.AddMixin(self, "ResourceBar")

    -- Register events with dedicated handlers
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    self:RegisterEvent("UNIT_POWER_FREQUENT", "OnUnitPower")
end

function ResourceBar:OnDisable()
    self:UnregisterAllEvents()
end
