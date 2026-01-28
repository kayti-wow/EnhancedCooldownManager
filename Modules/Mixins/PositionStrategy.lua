-- Enhanced Cooldown Manager addon for World of Warcraft
-- Author: Solär
-- Licensed under the GNU General Public License v3.0

local _, ns = ...

--- Positioning strategy interface for bar placement.
---@class PositionStrategyInterface
---@field GetAnchor fun(self: PositionStrategyInterface, addon: table, moduleName: string|nil): Frame, boolean
---@field GetOffsetX fun(self: PositionStrategyInterface, cfg: table): number
---@field GetOffsetY fun(self: PositionStrategyInterface, cfg: table, profile: table, isAnchoredToViewer: boolean): number
---@field GetWidth fun(self: PositionStrategyInterface, cfg: table): number|nil
---@field ApplyPoints fun(self: PositionStrategyInterface, frame: Frame, anchor: Frame, offsetX: number, offsetY: number, opts: table|nil): nil
---@field GetStrategyKey fun(self: PositionStrategyInterface): string

local PositionStrategy = {}
ns.Mixins = ns.Mixins or {}
ns.Mixins.PositionStrategy = PositionStrategy

--- Calculates the anchor frame for a bar module.
--- Chain order: Viewer -> PowerBar -> ResourceBar -> RuneBar.
---
--- When moduleName is nil, returns the bottom-most visible bar (for BuffBars).
--- When moduleName is provided, returns the previous visible bar in chain order
--- (to avoid circular anchoring between bar modules).
---@param addon table The EnhancedCooldownManager addon table
---@param moduleName string|nil Module name to find anchor for (nil = append to bottom)
---@return Frame anchor The frame to anchor to
---@return boolean isAnchoredToViewer True if anchoring directly to the viewer
local function CalculateAnchor(addon, moduleName)
    local viewer = BarFrame.GetViewerAnchor()
    local chain = { "PowerBar", "ResourceBar", "RuneBar" }
    local profile = addon and addon.db and addon.db.profile

    -- Find the stopping point in the chain
    local stopIndex = #chain + 1 -- Default: iterate all (for BuffBars)
    if moduleName then
        for i, name in ipairs(chain) do
            if name == moduleName then
                stopIndex = i
                break
            end
        end
    end

    -- Find the last visible bar before stopIndex
    local lastVisible
    for i = 1, stopIndex - 1 do
        local modName = chain[i]
        local mod = addon and addon[modName]
        local configKey = mod and mod._barConfig and mod._barConfig.configKey
        local cfg = configKey and profile and profile[configKey]
        local isIndependent = cfg and cfg.anchorMode == "independent"
        if not isIndependent and mod and mod.GetFrameIfShown then
            local f = mod:GetFrameIfShown()
            if f then
                lastVisible = f
            end
        end
    end

    if lastVisible then
        return lastVisible, false
    end

    return viewer, true
end


--------------------------------------------------------------------------------
-- ChainStrategy - Automatic positioning in bar stack
--------------------------------------------------------------------------------

local ChainStrategy = {}
ChainStrategy.__index = ChainStrategy

function ChainStrategy:GetStrategyKey()
    return "chain"
end

--- Returns the anchor frame for chain positioning.
--- Uses BarFrame.CalculateAnchor to find the previous visible bar or viewer.
---@param addon table The EnhancedCooldownManager addon table
---@param moduleName string|nil Module name to find anchor for (nil = bottom-most)
---@return Frame anchor The frame to anchor to
---@return boolean isAnchoredToViewer True if anchoring directly to the viewer
function ChainStrategy:GetAnchor(addon, moduleName)
    return CalculateAnchor(addon, moduleName)
end

--- Returns horizontal offset (always 0 for chain mode).
---@param cfg table Module-specific config
---@return number
function ChainStrategy:GetOffsetX(cfg)
    return 0
end

--- Returns vertical offset (negated to create gap below anchor).
--- For top bar (anchored to viewer): uses profile.offsetY + cfg.offsetY
--- For chain bars: uses cfg.offsetY only
---@param cfg table Module-specific config
---@param profile table Full profile table
---@param isAnchoredToViewer boolean True if anchoring to viewer
---@return number
function ChainStrategy:GetOffsetY(cfg, profile, isAnchoredToViewer)
    local BarFrame = ns.Mixins.BarFrame
    if isAnchoredToViewer then
        return -BarFrame.GetTopGapOffset(cfg, profile)
    else
        return -((cfg and cfg.offsetY) or 0)
    end
end

--- Returns width (nil to match anchor width).
---@param cfg table Module-specific config
---@return number|nil
function ChainStrategy:GetWidth(cfg)
    return nil
end

--- Applies anchor points for chain positioning.
--- Uses TOPLEFT + TOPRIGHT anchoring to match anchor width.
---@param frame Frame The frame to position
---@param anchor Frame The anchor frame
---@param offsetX number Horizontal offset (ignored in chain mode)
---@param offsetY number Vertical offset
---@param opts table|nil Optional parameters (ignored for chain)
function ChainStrategy:ApplyPoints(frame, anchor, offsetX, offsetY, opts)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    frame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, offsetY)
end

--------------------------------------------------------------------------------
-- IndependentStrategy - Custom positioning relative to screen center
--------------------------------------------------------------------------------

local IndependentStrategy = {}
IndependentStrategy.__index = IndependentStrategy

function IndependentStrategy:GetStrategyKey()
    return "independent"
end

--- Returns UIParent for independent positioning.
---@param addon table The EnhancedCooldownManager addon table
---@param moduleName string|nil Module name (ignored for independent)
---@return Frame anchor Always UIParent
---@return boolean isAnchoredToViewer Always false
function IndependentStrategy:GetAnchor(addon, moduleName)
    return UIParent, false
end

--- Returns horizontal offset from config.
---@param cfg table Module-specific config
---@return number
function IndependentStrategy:GetOffsetX(cfg)
    return (cfg and cfg.offsetX) or 0
end

--- Returns vertical offset from config (no negation).
---@param cfg table Module-specific config
---@param profile table Full profile table
---@param isAnchoredToViewer boolean (ignored for independent)
---@return number
function IndependentStrategy:GetOffsetY(cfg, profile, isAnchoredToViewer)
    return (cfg and cfg.offsetY) or 0
end

--- Returns width from config or default.
---@param cfg table Module-specific config
---@return number
function IndependentStrategy:GetWidth(cfg)
    local Util = ns.Util
    local BarFrame = ns.Mixins.BarFrame
    return Util.PixelSnap((cfg and cfg.width) or BarFrame.DEFAULT_BAR_WIDTH)
end

--- Applies anchor points for independent positioning.
--- Uses CENTER anchoring relative to UIParent.
---@param frame Frame The frame to position
---@param anchor Frame The anchor frame (should be UIParent)
---@param offsetX number Horizontal offset
---@param offsetY number Vertical offset
---@param opts table|nil Optional parameters (ignored for independent)
function IndependentStrategy:ApplyPoints(frame, anchor, offsetX, offsetY, opts)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", anchor, "CENTER", offsetX, offsetY)
end

--------------------------------------------------------------------------------
-- BuffBarChainStrategy - Chain positioning with optional position preservation
--------------------------------------------------------------------------------

local BuffBarChainStrategy = {}
BuffBarChainStrategy.__index = BuffBarChainStrategy
setmetatable(BuffBarChainStrategy, { __index = ChainStrategy })

function BuffBarChainStrategy:GetStrategyKey()
    return "buffbar_chain"
end

--- BuffBars always passes moduleName = nil to get bottom-most anchor.
---@param addon table The EnhancedCooldownManager addon table
---@param moduleName string|nil Always nil for BuffBars
---@return Frame anchor The frame to anchor to
---@return boolean isAnchoredToViewer True if anchoring directly to the viewer
function BuffBarChainStrategy:GetAnchor(addon, moduleName)
    return CalculateAnchor(addon, nil)
end

--- Applies anchor points for buff bar chain positioning.
--- Matches anchor width using TOPLEFT + TOPRIGHT anchoring.
---@param frame Frame The frame to position
---@param anchor Frame The anchor frame
---@param offsetX number Horizontal offset (ignored)
---@param offsetY number Vertical offset
---@param opts table|nil Optional: { preservePosition = boolean }
function BuffBarChainStrategy:ApplyPoints(frame, anchor, offsetX, offsetY, opts)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    frame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, offsetY)
end

--------------------------------------------------------------------------------
-- BuffBarIndependentStrategy - Independent with position preservation
--------------------------------------------------------------------------------

local BuffBarIndependentStrategy = {}
BuffBarIndependentStrategy.__index = BuffBarIndependentStrategy
setmetatable(BuffBarIndependentStrategy, { __index = IndependentStrategy })

function BuffBarIndependentStrategy:GetStrategyKey()
    return "buffbar_independent"
end

--- Applies anchor points for independent buff bar positioning.
--- Uses TOP anchor (not CENTER) to preserve vertical position when switching from chain mode.
---@param frame Frame The frame to position
---@param anchor Frame The anchor frame (UIParent)
---@param offsetX number Horizontal offset
---@param offsetY number Vertical offset (calculated from current position)
---@param opts table|nil Optional: { preservePosition = boolean }
function BuffBarIndependentStrategy:ApplyPoints(frame, anchor, offsetX, offsetY, opts)
    local preservePosition = opts and opts.preservePosition or false

    if preservePosition then
        -- Preserve current position when switching from chain to independent
        local top = frame:GetTop()
        local centerX = frame:GetCenter()
        local parentCenterX = UIParent:GetCenter()

        if top and centerX and parentCenterX then
            local calculatedOffsetX = centerX - parentCenterX
            local calculatedOffsetY = top - UIParent:GetTop()
            frame:ClearAllPoints()
            frame:SetPoint("TOP", UIParent, "TOP", calculatedOffsetX, calculatedOffsetY)
            return
        end
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOP", anchor, "TOP", offsetX, offsetY)
end

--------------------------------------------------------------------------------
-- Factory Function
--------------------------------------------------------------------------------

--- Creates a positioning strategy based on config.
--- For bar modules: returns ChainStrategy or IndependentStrategy based on cfg.anchorMode.
--- For BuffBars: returns BuffBarChainStrategy or BuffBarIndependentStrategy.
---@param cfg table Configuration with anchorMode field
---@param isBuffBar boolean|nil True if creating strategy for BuffBars
---@return table strategy Strategy instance
function PositionStrategy.Create(cfg, isBuffBar)
    local anchorMode = (cfg and cfg.anchorMode) or "chain"

    if isBuffBar then
        if anchorMode == "chain" then
            return setmetatable({}, BuffBarChainStrategy)
        else
            return setmetatable({}, BuffBarIndependentStrategy)
        end
    else
        if anchorMode == "chain" then
            return setmetatable({}, ChainStrategy)
        else
            return setmetatable({}, IndependentStrategy)
        end
    end
end
