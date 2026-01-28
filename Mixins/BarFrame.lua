-- Enhanced Cooldown Manager addon for World of Warcraft
-- Author: Solär
-- Licensed under the GNU General Public License v3.0

local ADDON_NAME, ns = ...

local BarFrame = {}
ns.Mixins = ns.Mixins or {}
ns.Mixins.BarFrame = BarFrame
local Module = ns.Mixins.Module
local Util = ns.Util
local LSM = LibStub("LibSharedMedia-3.0", true)
local ECM = ns.Addon


---@class Frame
---@class FontString
---@field SetFont fun(self: FontString, fontPath: string, size: number, flags: string)
---@field SetShadowOffset fun(self: FontString, x: number, y: number)
---@field SetShadowColor fun(self: FontString, r: number, g: number, b: number, a: number)
---@class Texture
---@class StatusBar : Frame

---@class ECMBarFrame : Frame
---@field Background Texture
---@field Border Frame
---@field StatusBar StatusBar
---@field TextFrame Frame
---@field TextValue FontString
---@field _defaultHeight number
---@field _lastAnchor Frame
---@field _lastOffsetX number
---@field _lastOffsetY number
---@field _lastMatchAnchorWidth boolean
---@field _lastIsIndependent boolean
---@field _lastHeight number
---@field _lastWidth number
---@field _lastBorderThickness number
---@field SetValue fun(self: ECMBarFrame, minVal: number, maxVal: number, currentVal: number, r: number, g: number, b: number)
---@field SetAppearance fun(self: ECMBarFrame, cfg: table|nil, profile: table|nil): string|nil
---@field SetLayout fun(self: ECMBarFrame, anchor: Frame, offsetX: number|nil, offsetY: number, height: number, width: number|nil, isIndependent: boolean|nil)
---@field ApplyConfig fun(self: ECMBarFrame, module: table): boolean
---@field SetText fun(self: ECMBarFrame, text: string)
---@field SetTextVisible fun(self: ECMBarFrame, shown: boolean)

local LAYOUT_EVENTS = {
    "PLAYER_SPECIALIZATION_CHANGED",
    "UPDATE_SHAPESHIFT_FORM",
    "PLAYER_ENTERING_WORLD",
}

local REFRESH_EVENTS = {
    { event = "UNIT_POWER_UPDATE", handler = "OnUnitPower" },
}

BarFrame.DEFAULT_POWER_BAR_HEIGHT = 20
BarFrame.DEFAULT_RESOURCE_BAR_HEIGHT = 13
BarFrame.DEFAULT_BAR_WIDTH = 250
BarFrame.DEFAULT_BG_COLOR = { 0.08, 0.08, 0.08, 0.65 }
BarFrame.DEFAULT_STATUSBAR_TEXTURE = "Interface\\TARGETINGFRAME\\UI-StatusBar"
BarFrame.VIEWER_ANCHOR_NAME = "EssentialCooldownViewer"

local function GetConfigSection(config, configKey)
    assert(config, "config required")
    assert(configKey, "configKey required")
    return config[configKey]
end

-- Layout Helpers (module-level)

local function FetchLSM(mediaType, key)
    if LSM and LSM.Fetch and key and type(key) == "string" then
        return LSM:Fetch(mediaType, key, true)
    end
    return nil
end

--- Returns the resolved background color from config or defaults.
---@param cfg table|nil Module-specific config
---@param profile table|nil Full profile table
---@return number[] RGBA color array
function BarFrame.GetBgColor(cfg, profile)
    local gbl = profile and profile.global
    return (cfg and cfg.bgColor) or (gbl and gbl.barBgColor) or BarFrame.DEFAULT_BG_COLOR
end

--- Returns the top gap offset for the first bar anchored to the viewer.
--- Combines profile-level gap (chain offset) with module-level offset.
---@param cfg table|nil Module-specific config
---@param profile table|nil Full profile table
---@return number
function BarFrame.GetTopGapOffset(cfg, profile)
    local profileOffset = (profile and profile.offsetY) or 6
    local moduleOffset = (cfg and cfg.offsetY) or 0
    return profileOffset + moduleOffset
end

--- Returns a statusbar texture path (LSM-resolved when available).
---@param textureOverride string|nil
---@return string
function BarFrame.GetTexture(textureOverride)
    if textureOverride and type(textureOverride) == "string" then
        local fetched = FetchLSM("statusbar", textureOverride)
        if fetched then
            return fetched
        end
        if not textureOverride:find("\\") then
            return BarFrame.DEFAULT_STATUSBAR_TEXTURE
        end
        return textureOverride
    end

    return FetchLSM("statusbar", "Blizzard") or BarFrame.DEFAULT_STATUSBAR_TEXTURE
end

--- Returns a font file path (LSM-resolved when available).
---@param fontKey string|nil
---@param fallback string|nil
---@return string
function BarFrame.GetFontPath(fontKey, fallback)
    local fallbackPath = fallback or "Interface\\AddOns\\EnhancedCooldownManager\\media\\Fonts\\Expressway.ttf"

    return FetchLSM("font", fontKey) or fallbackPath
end

--- Applies font settings to a FontString.
---@param fontString FontString
---@param profile table|nil Full profile table
function BarFrame.ApplyFont(fontString, profile)
    if not fontString or not fontString.SetFont then
        return
    end

    local gbl = profile and profile.global
    local fontPath = BarFrame.GetFontPath(gbl and gbl.font)
    local fontSize = (gbl and gbl.fontSize) or 11
    local fontOutline = (gbl and gbl.fontOutline) or "OUTLINE"

    if fontOutline == "NONE" then
        fontOutline = ""
    end

    fontString:SetFont(fontPath, fontSize, fontOutline)

    if fontString.SetShadowOffset then
        local hasShadow = gbl and gbl.fontShadow
        if hasShadow then
            fontString:SetShadowColor(0, 0, 0, 1)
            fontString:SetShadowOffset(1, -1)
        else
            fontString:SetShadowOffset(0, 0)
        end
    end
end

--- Returns the bar height from config or defaults.
---@param cfg table|nil Module-specific config
---@param profile table|nil Full profile table
---@param defaultHeight number Default height if not configured
---@return number
function BarFrame.GetBarHeight(cfg, profile, defaultHeight)
    local gbl = profile and profile.global
    local height = (cfg and cfg.height) or (gbl and gbl.barHeight) or defaultHeight
    return Util.PixelSnap(height)
end

--------------------------------------------------------------------------------
-- Anchor Helpers
--------------------------------------------------------------------------------

--- Returns the base viewer anchor frame (even if it's currently hidden).
---@return Frame
function BarFrame.GetViewerAnchor()
    local viewer = _G[BarFrame.VIEWER_ANCHOR_NAME]
    if viewer then
        return viewer
    end
    return UIParent
end

-- BarFrame.Helpers = {
--     GetBgColor = BarFrame.GetBgColor,
--     GetTopGapOffset = BarFrame.GetTopGapOffset,
--     GetTexture = BarFrame.GetTexture,
--     GetFontPath = BarFrame.GetFontPath,
--     ApplyFont = BarFrame.ApplyFont,
--     GetBarHeight = BarFrame.GetBarHeight,
--     GetViewerAnchor = BarFrame.GetViewerAnchor,
-- }

-- ns.BarHelpers = BarFrame.Helpers
-- if ns.Addon then
--     ns.Addon.BarHelpers = BarFrame.Helpers
-- end

-- Attach methods directly to bar

--- Updates the StatusBar value and color.
---@param self ECMBarFrame
---@param minVal number Minimum value
---@param maxVal number Maximum value
---@param currentVal number Current value
---@param r number Red component (0-1)
---@param g number Green component (0-1)
---@param b number Blue component (0-1)
function BarFrame:SetValue(minVal, maxVal, currentVal, r, g, b)
    self.StatusBar:SetMinMaxValues(minVal, maxVal)
    self.StatusBar:SetValue(currentVal)
    self.StatusBar:SetStatusBarColor(r, g, b)
end

--- Applies appearance settings (background color, statusbar texture) to a bar.
---@param self ECMBarFrame
---@param cfg table|nil Module-specific config
---@param profile table|nil Full profile
---@return string|nil texture The applied texture path
function BarFrame:SetAppearance(cfg, profile)
    local bgColor = BarFrame.GetBgColor(cfg, profile)
    if self.Background and self.Background.SetColorTexture then
        self.Background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    end

    local gbl = profile and profile.global
    local tex = BarFrame.GetTexture((cfg and cfg.texture) or (gbl and gbl.texture))
    if self.StatusBar and self.StatusBar.SetStatusBarTexture then
        self.StatusBar:SetStatusBarTexture(tex)
    end

    local border = self.Border
    local borderCfg = cfg and cfg.border
    if border and borderCfg and borderCfg.enabled then
        local thickness = borderCfg.thickness or 1
        local color = borderCfg.color or {}
        if self._lastBorderThickness ~= thickness then
            border:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = thickness,
            })
            self._lastBorderThickness = thickness
        end
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", -thickness, thickness)
        border:SetPoint("BOTTOMRIGHT", thickness, -thickness)
        border:SetBackdropBorderColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
        border:Show()
    elseif border then
        border:Hide()
    end

    return tex
end

--- Applies layout (anchor, position, size) only if changed.
--- Caches layout state to avoid unnecessary frame updates.
---@param self ECMBarFrame
---@param anchor Frame Frame to anchor to (for vertical position)
---@param offsetX number|nil Horizontal offset (default 0)
---@param offsetY number Vertical offset from anchor
---@param height number Desired bar height
---@param width number|nil Desired bar width. If nil, width matches viewer width.
--- @param isIndependent boolean|nil Whether the bar is positioned relative to screen center
function BarFrame:SetLayout(anchor, offsetX, offsetY, height, width, isIndependent)
    local shouldMatchWidth = width == nil and not isIndependent
    offsetX = offsetX or 0
    isIndependent = isIndependent == true

    local layoutChanged = self._lastAnchor ~= anchor
        or self._lastOffsetX ~= offsetX
        or self._lastOffsetY ~= offsetY
        or self._lastMatchAnchorWidth ~= shouldMatchWidth
        or self._lastIsIndependent ~= isIndependent

    if layoutChanged then
        self:ClearAllPoints()
        if isIndependent then
            self:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
        elseif shouldMatchWidth then
            self:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offsetX, offsetY)
            self:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", offsetX, offsetY)
        else
            self:SetPoint("TOP", anchor, "BOTTOM", offsetX, offsetY)
        end
        self._lastAnchor = isIndependent and UIParent or anchor
        self._lastOffsetX = offsetX
        self._lastOffsetY = offsetY
        self._lastMatchAnchorWidth = shouldMatchWidth
        self._lastIsIndependent = isIndependent
    end

    if self._lastHeight ~= height then
        self:SetHeight(height)
        self._lastHeight = height
    end

    if not shouldMatchWidth and width ~= nil and self._lastWidth ~= width then
        self:SetWidth(width)
        self._lastWidth = width
    elseif shouldMatchWidth then
        self._lastWidth = nil
    end
end

--- Applies layout using a positioning strategy.
--- Internal method used by ApplyConfig and BuffBars.
---@param self ECMBarFrame Bar instance
---@param strategy table Position strategy instance
---@param anchor Frame Anchor frame
---@param offsetX number Horizontal offset
---@param offsetY number Vertical offset
---@param height number Bar height
---@param width number|nil Bar width (nil = match anchor)
function BarFrame:SetLayoutWithStrategy(strategy, anchor, offsetX, offsetY, height, width)
    local shouldMatchWidth = width == nil
    local isIndependent = strategy:GetStrategyKey():find("independent") ~= nil

    local layoutChanged = self._lastAnchor ~= anchor
        or self._lastOffsetX ~= offsetX
        or self._lastOffsetY ~= offsetY
        or self._lastMatchAnchorWidth ~= shouldMatchWidth
        or self._lastIsIndependent ~= isIndependent

    if layoutChanged then
        strategy:ApplyPoints(self, anchor, offsetX, offsetY)
        self._lastAnchor = isIndependent and UIParent or anchor
        self._lastOffsetX = offsetX
        self._lastOffsetY = offsetY
        self._lastMatchAnchorWidth = shouldMatchWidth
        self._lastIsIndependent = isIndependent
    end

    if self._lastHeight ~= height then
        self:SetHeight(height)
        self._lastHeight = height
    end

    if not shouldMatchWidth and width ~= nil and self._lastWidth ~= width then
        self:SetWidth(width)
        self._lastWidth = width
    elseif shouldMatchWidth then
        self._lastWidth = nil
    end
end

--- Adds a text overlay to an existing bar frame.
--- Creates TextFrame container and TextValue FontString.
--- Text methods (SetText, SetTextVisible) are attached to the bar.
---@param bar ECMBarFrame Bar frame to add text overlay to
---@param profile table|nil Profile for font settings
---@return FontString textValue The created FontString
function BarFrame.AddTextOverlay(bar, profile)
    assert(bar, "bar frame required")

    ---@cast bar ECMBarFrame

    local textFrame = CreateFrame("Frame", nil, bar)
    textFrame:SetAllPoints(bar)
    textFrame:SetFrameLevel(bar.StatusBar:GetFrameLevel() + 10)
    bar.TextFrame = textFrame

    local textValue = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    textValue:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
    textValue:SetJustifyH("CENTER")
    textValue:SetJustifyV("MIDDLE")
    textValue:SetText("0")
    bar.TextValue = textValue

    if profile then
        BarFrame.ApplyFont(bar.TextValue, profile)
    end

    -- Attach text methods

    --- Sets the text value on a bar with text overlay.
    ---@param self ECMBarFrame
    ---@param text string Text to display
    function BarFrame:SetText(text)
        if self.TextValue then
            self.TextValue:SetText(text)
        end
    end

    --- Shows or hides the text overlay.
    ---@param self ECMBarFrame
    ---@param shown boolean Whether to show the text
    function BarFrame:SetTextVisible(shown)
        if self.TextFrame then
            self.TextFrame:SetShown(shown)
        end
    end

    return bar.TextValue
end

-- function BarFrame:OnUpdateLayout()
--     local bar = self:GetOrCreateFrame()
--     if bar:ApplyConfig(self) then
--         bar:Show()
--         self:Refresh()
--     end
-- end

-- function BarFrame:SetExternallyHidden(hidden)
--     local isHidden = not not hidden
--     if self._externallyHidden ~= isHidden then
--         self._externallyHidden = isHidden
--         Util.Log(self:GetName(), "SetExternallyHidden", { hidden = self._externallyHidden })
--     end
-- end

function BarFrame:OnPaused(paused)
    self:_prevSetPaused(paused)
    if paused then
        self._frame:Hide()
    else
        -- TODO: update layout
        self._frame:Show()
    end
end

function BarFrame:GetFrameIfShown()
    local f = self._frame
    if self._externallyHidden or not f or not f:IsShown() then
        return nil
    end
    return f
end

function BarFrame:GetOrCreateFrame()
    if not self._frame then
        self._frame = self:CreateFrame()
    end
    return self._frame
end

function BarFrame:UpdateLayout()
    local profile = self:GetConfig()
    local cfg = GetConfigSection(profile, self._configKey)

    local PositionStrategy = ns.Mixins.PositionStrategy
    local strategy = PositionStrategy.Create(cfg, false)

    local anchor, isAnchoredToViewer = strategy:GetAnchor(addon, self:GetName())
    local offsetX = strategy:GetOffsetX(cfg)
    local offsetY = strategy:GetOffsetY(cfg, profile, isAnchoredToViewer)
    local width = strategy:GetWidth(cfg)
    local height = BarFrame.GetBarHeight(cfg, profile, self._defaultHeight)

    Util.Log(self:GetName(), "Applying layout", {
        strategy = strategy:GetStrategyKey(),
        anchor = anchor:GetName() or tostring(anchor),
        offsetX = offsetX,
        offsetY = offsetY,
        height = height,
        width = width or "auto",
    })

    -- 3. Apply layout and appearance
    self:SetLayoutWithStrategy(strategy, anchor, offsetX, offsetY, height, width)
    self:SetAppearance(cfg, profile)


    -- TODO: should show?
    -- TODO: should refresh?

    -- -- 4. Call module override if defined
    -- if module.OnLayoutComplete then
    --     local shouldContinue = module:OnLayoutComplete(self, cfg, profile)
    --     if shouldContinue == false then
    --         return false
    --     end
    -- end

    -- return true
end

function BarFrame:CreateFrame()
    local profile = ECM.db and ECM.db.profile
    local name = ADDON_NAME .. self:GetName()
    local frame = CreateFrame("Frame", name, UIParent)

    frame:SetFrameStrata("MEDIUM")
    local barHeight = profile and profile.global.barHeight or BarFrame.DEFAULT_RESOURCE_BAR_HEIGHT
    frame:SetHeight(Util.PixelSnap(barHeight))

    frame.Background = frame:CreateTexture(nil, "BACKGROUND")
    frame.Background:SetAllPoints()

    -- Optional border frame (shown when cfg.border.enabled)
    frame.Border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.Border:SetFrameLevel(frame:GetFrameLevel() + 2)
    frame.Border:Hide()

    -- StatusBar for value display
    frame.StatusBar = CreateFrame("StatusBar", nil, frame)
    frame.StatusBar:SetAllPoints()
    frame.StatusBar:SetFrameLevel(frame:GetFrameLevel() + 1)

    return frame
end

function BarFrame.AddMixin(module, name, configKey, extraLayoutEvents, extraRefreshEvents)
    local layoutEvents = Util.MergeUniqueLists(LAYOUT_EVENTS, extraLayoutEvents or {})
    local refreshEvents = Util.MergeUniqueLists(REFRESH_EVENTS, extraRefreshEvents or {})

    Module.AddMixin(
        module,
        name,
        layoutEvents,
        refreshEvents)

    module._configKey = configKey
    module._prevSetPaused = module.SetPaused
end
