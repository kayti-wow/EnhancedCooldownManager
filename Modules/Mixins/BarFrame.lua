-- Enhanced Cooldown Manager addon for World of Warcraft
-- Author: Solär
-- Licensed under the GNU General Public License v3.0

local _, ns = ...

local Util = ns.Util
local LSM = LibStub("LibSharedMedia-3.0", true)

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

--- BarFrame mixin: Frame creation, layout, appearance, and text overlay.
--- Provides shared frame structure and styling for all bar modules.
--- Methods are attached directly to created frames.
local BarFrame = {}
ns.Mixins = ns.Mixins or {}
ns.Mixins.BarFrame = BarFrame

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

BarFrame.DEFAULT_POWER_BAR_HEIGHT = 20
BarFrame.DEFAULT_RESOURCE_BAR_HEIGHT = 13
BarFrame.DEFAULT_BAR_WIDTH = 250
BarFrame.DEFAULT_BG_COLOR = { 0.08, 0.08, 0.08, 0.65 }
BarFrame.DEFAULT_STATUSBAR_TEXTURE = "Interface\\TARGETINGFRAME\\UI-StatusBar"
BarFrame.VIEWER_ANCHOR_NAME = "EssentialCooldownViewer"

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



BarFrame.Helpers = {
    GetBgColor = BarFrame.GetBgColor,
    GetTopGapOffset = BarFrame.GetTopGapOffset,
    GetTexture = BarFrame.GetTexture,
    GetFontPath = BarFrame.GetFontPath,
    ApplyFont = BarFrame.ApplyFont,
    GetBarHeight = BarFrame.GetBarHeight,
    GetViewerAnchor = BarFrame.GetViewerAnchor,
}

ns.BarHelpers = BarFrame.Helpers
if ns.Addon then
    ns.Addon.BarHelpers = BarFrame.Helpers
end

--------------------------------------------------------------------------------
-- Frame Creation
--------------------------------------------------------------------------------

--- Creates a base resource bar frame with Background and StatusBar.
--- Modules can add additional elements (text, ticks, fragments) after creation.
--- Core methods (SetValue, SetAppearance) are attached directly to the bar.
---@param frameName string Unique frame name
---@param parent Frame Parent frame (typically UIParent)
---@param defaultHeight number Default bar height
---@return Frame bar The created bar frame with .Background and .StatusBar
function BarFrame.Create(frameName, parent, defaultHeight)
    assert(type(frameName) == "string", "frameName must be a string")

    local bar = CreateFrame("Frame", frameName, parent or UIParent)
    ---@cast bar ECMBarFrame
    bar:SetFrameStrata("MEDIUM")
    local resolvedDefaultHeight = defaultHeight or BarFrame.DEFAULT_RESOURCE_BAR_HEIGHT
    bar:SetHeight(Util.PixelSnap(resolvedDefaultHeight))

    -- Store default height for ApplyConfig to use
    bar._defaultHeight = resolvedDefaultHeight

    -- Background texture
    bar.Background = bar:CreateTexture(nil, "BACKGROUND")
    bar.Background:SetAllPoints()

    -- Optional border frame (shown when cfg.border.enabled)
    bar.Border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.Border:SetFrameLevel(bar:GetFrameLevel() + 2)
    bar.Border:Hide()

    -- StatusBar for value display
    bar.StatusBar = CreateFrame("StatusBar", nil, bar)
    bar.StatusBar:SetAllPoints()
    bar.StatusBar:SetFrameLevel(bar:GetFrameLevel() + 1)

    -- Attach methods directly to bar

    --- Updates the StatusBar value and color.
    ---@param self ECMBarFrame
    ---@param minVal number Minimum value
    ---@param maxVal number Maximum value
    ---@param currentVal number Current value
    ---@param r number Red component (0-1)
    ---@param g number Green component (0-1)
    ---@param b number Blue component (0-1)
    function bar:SetValue(minVal, maxVal, currentVal, r, g, b)
        self.StatusBar:SetMinMaxValues(minVal, maxVal)
        self.StatusBar:SetValue(currentVal)
        self.StatusBar:SetStatusBarColor(r, g, b)
    end

    --- Applies appearance settings (background color, statusbar texture) to a bar.
    ---@param self ECMBarFrame
    ---@param cfg table|nil Module-specific config
    ---@param profile table|nil Full profile
    ---@return string|nil texture The applied texture path
    function bar:SetAppearance(cfg, profile)
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
    function bar:SetLayout(anchor, offsetX, offsetY, height, width, isIndependent)
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
    function bar:SetLayoutWithStrategy(strategy, anchor, offsetX, offsetY, height, width)
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

    --- Applies complete configuration from profile.
    --- Handles preconditions internally - no coupling to Lifecycle.
    ---
    --- Uses PositionStrategy to handle anchor mode differences:
    --- - chain: Anchors below previous bar, matches anchor width
    --- - independent: Anchors to screen center, uses explicit width
    ---@param self ECMBarFrame Bar instance
    ---@param module table Module reference
    ---@return boolean success True if layout applied, false if preconditions failed
    function bar:ApplyConfig(module)
        local addon = ns.Addon
        local barConfig = module._barConfig
        local configKey = barConfig.configKey

        -- 1. Check preconditions (moved from Lifecycle)
        local profile = addon and addon.db and addon.db.profile
        if not profile then
            Util.Log(barConfig.name, "ApplyConfig skipped - no profile")
            return false
        end

        if module._externallyHidden then
            self:Hide()
            return false
        end

        local cfg = profile[configKey]
        if not (cfg and cfg.enabled) then
            self:Hide()
            return false
        end

        if barConfig.shouldShow and not barConfig.shouldShow() then
            self:Hide()
            Util.Log(barConfig.name, "ApplyConfig skipped - shouldShow returned false")
            return false
        end

        -- 2. Create strategy and delegate positioning logic
        local PositionStrategy = ns.Mixins.PositionStrategy
        local strategy = PositionStrategy.Create(cfg, false)

        local anchor, isAnchoredToViewer = strategy:GetAnchor(addon, barConfig.name)
        local offsetX = strategy:GetOffsetX(cfg)
        local offsetY = strategy:GetOffsetY(cfg, profile, isAnchoredToViewer)
        local width = strategy:GetWidth(cfg)
        local height = BarFrame.GetBarHeight(cfg, profile, self._defaultHeight)

        Util.Log(barConfig.name, "Applying layout", {
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

        -- 4. Call module override if defined
        if module.OnLayoutComplete then
            local shouldContinue = module:OnLayoutComplete(self, cfg, profile)
            if shouldContinue == false then
                return false
            end
        end

        return true
    end

    bar:Hide()
    return bar
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
    function bar:SetText(text)
        if self.TextValue then
            self.TextValue:SetText(text)
        end
    end

    --- Shows or hides the text overlay.
    ---@param self ECMBarFrame
    ---@param shown boolean Whether to show the text
    function bar:SetTextVisible(shown)
        if self.TextFrame then
            self.TextFrame:SetShown(shown)
        end
    end

    return bar.TextValue
end


function BarFrame:SetExternallyHidden(hidden)
    local isHidden = not not hidden
    if self._externallyHidden ~= isHidden then
        self._externallyHidden = isHidden
        Util.Log(config.name, "SetExternallyHidden", { hidden = self._externallyHidden })
    end
    if self._externallyHidden and self._frame then
        self._frame:Hide()
    end
end

function BarFrame:GetFrameIfShown()
    local f = self._frame
    if self._externallyHidden or not f or not f:IsShown() then
        return nil
    end
    return f
end

--------------------------------------------------------------------------------
-- Module Setup (orchestrates Lifecycle + bar-specific config)
--------------------------------------------------------------------------------

--- Sets up a bar module with UpdateLayout and integrates with Lifecycle.
---@param module table AceModule to configure
---@param config table Configuration:
---   - configKey: string - Profile config key (e.g., "powerBar")
---   - shouldShow: function|nil - Visibility check
---   - name: string - Module name for logging
---   - layoutEvents: string[] - Events that trigger UpdateLayout
---   - refreshEvents: table[] - Events that trigger refresh
---   - onDisable: function|nil - Optional cleanup
function BarFrame.Setup(module, config)
    local Lifecycle = ns.Mixins.Lifecycle

    -- 1. Call Lifecycle.Setup for generic event handling
    Lifecycle.Setup(module, {
        name = config.name,
        layoutEvents = config.layoutEvents,
        refreshEvents = config.refreshEvents,
        onDisable = config.onDisable,
    })

    -- 2. Store bar-specific config on module
    module._barConfig = {
        configKey = config.configKey,
        shouldShow = config.shouldShow,
        name = config.name,
    }

    -- 3. Inject bar-specific UpdateLayout

end

function BarFrame:OnUpdateLayout()
    local bar = self:GetFrame()
    if bar:ApplyConfig(self) then
        bar:Show()
        self:Refresh()
    end
end
