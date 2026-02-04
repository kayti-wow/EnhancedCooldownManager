-- Enhanced Cooldown Manager addon for World of Warcraft
-- Author: Solär
-- Licensed under the GNU General Public License v3.0

local _, ns = ...

local ECM = ns.Addon
local Util = ns.Util
local C = ns.Constants

local ECMFrame = ns.Mixins.ECMFrame

local TrinketIcons = ECM:NewModule("TrinketIcons", "AceEvent-3.0")
ECM.TrinketIcons = TrinketIcons

---@class ECM_TrinketIconsModule : ECMFrame

---@class ECM_TrinketData
---@field slotId number Inventory slot ID (13 or 14).
---@field itemId number Item ID.
---@field texture string|number Icon texture.
---@field spellId number On-use spell ID.

---@class ECM_TrinketIcon : Button
---@field slotId number Inventory slot ID this icon represents.
---@field Icon Texture The icon texture.
---@field Cooldown Cooldown The cooldown overlay frame.

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local TRINKET_SLOTS = { C.TRINKET_SLOT_1, C.TRINKET_SLOT_2 }

--- Checks if a trinket slot has an on-use effect.
---@param slotId number Inventory slot ID (13 or 14).
---@return ECM_TrinketData|nil trinketData Trinket data if on-use, nil otherwise.
local function GetTrinketData(slotId)
    local itemId = GetInventoryItemID("player", slotId)
    if not itemId then
        return nil
    end

    local spellName, spellId = C_Item.GetItemSpell(itemId)
    if not spellName then
        return nil
    end

    local texture = GetInventoryItemTexture("player", slotId)
    return {
        slotId = slotId,
        itemId = itemId,
        texture = texture,
        spellId = spellId,
    }
end

--- Returns a table of usable trinkets (those with on-use effects).
---@param moduleConfig table Module configuration.
---@return ECM_TrinketData[] trinkets Array of trinket data.
local function GetUsableTrinkets(moduleConfig)
    local trinkets = {}

    if moduleConfig.showTrinket1 then
        local data = GetTrinketData(C.TRINKET_SLOT_1)
        if data then
            trinkets[#trinkets + 1] = data
        end
    end

    if moduleConfig.showTrinket2 then
        local data = GetTrinketData(C.TRINKET_SLOT_2)
        if data then
            trinkets[#trinkets + 1] = data
        end
    end

    return trinkets
end

--- Creates a single trinket icon frame styled like cooldown viewer icons.
---@param parent Frame Parent frame to attach to.
---@param size number Icon size in pixels.
---@return ECM_TrinketIcon icon The created icon frame.
local function CreateTrinketIcon(parent, size)
    local icon = CreateFrame("Button", nil, parent)
    icon:SetSize(size, size)

    -- Icon texture (the actual item icon) - ARTWORK layer
    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetPoint("CENTER")
    icon.Icon:SetSize(size, size)

    -- Icon mask (rounds the corners) - ARTWORK layer
    icon.Mask = icon:CreateMaskTexture()
    icon.Mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
    icon.Mask:SetPoint("CENTER")
    icon.Mask:SetSize(size, size)
    icon.Icon:AddMaskTexture(icon.Mask)

    -- Cooldown overlay with proper swipe and edge textures
    icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.Cooldown:SetAllPoints()
    icon.Cooldown:SetDrawEdge(true)
    icon.Cooldown:SetDrawSwipe(true)
    icon.Cooldown:SetHideCountdownNumbers(false)
    icon.Cooldown:SetSwipeTexture([[Interface\HUD\UI-HUD-CoolDownManager-Icon-Swipe]], 0, 0, 0, 0.2)
    icon.Cooldown:SetEdgeTexture([[Interface\Cooldown\UI-HUD-ActionBar-SecondaryCooldown]])

    -- Border overlay - OVERLAY layer (1.35x size, centered)
    icon.Border = icon:CreateTexture(nil, "OVERLAY")
    icon.Border:SetAtlas("UI-HUD-CoolDownManager-IconOverlay")
    icon.Border:SetPoint("CENTER")
    icon.Border:SetSize(size * 1.35, size * 1.35)

    -- Shadow overlay
    icon.Shadow = icon:CreateTexture(nil, "OVERLAY")
    icon.Shadow:SetAtlas("UI-CooldownManager-OORshadow")
    icon.Shadow:SetAllPoints()
    icon.Shadow:Hide() -- Only show when out of range (optional)

    return icon
end

--- Updates the cooldown display on a trinket icon.
---@param icon ECM_TrinketIcon The icon to update.
---@param slotId number The inventory slot ID.
local function UpdateIconCooldown(icon, slotId)
    local start, duration, enable = GetInventoryItemCooldown("player", slotId)
    if enable == 1 and duration > 0 then
        icon.Cooldown:SetCooldown(start, duration)
    else
        icon.Cooldown:Clear()
    end
end

--- Gets the icon size from UtilityCooldownViewer's children.
--- Falls back to DEFAULT_TRINKET_ICON_SIZE if viewer is unavailable.
--- The Blizzard icons use a 1.35x overlay, so we measure the visual size
--- (including overlay) and derive the base icon size from that.
---@return number iconSize The icon size in pixels.
local function GetUtilityViewerIconSize()
    local viewer = _G[C.VIEWER_UTILITY]
    if not viewer or not viewer:IsShown() then
        return C.DEFAULT_TRINKET_ICON_SIZE
    end

    local children = { viewer:GetChildren() }
    for _, child in ipairs(children) do
        if child and child:IsShown() then
            local size = child:GetWidth()
            if size and size > 0 then
                -- Blizzard's overlay extends beyond the base frame, making icons
                -- appear larger. Scale up to match the visual appearance.
                return size * 1.35
            end
        end
    end
    return C.DEFAULT_TRINKET_ICON_SIZE
end

--------------------------------------------------------------------------------
-- ECMFrame Overrides
--------------------------------------------------------------------------------

--- Override CreateFrame to create the container for trinket icons.
---@return Frame container The container frame.
function TrinketIcons:CreateFrame()
    local frame = CreateFrame("Frame", "ECMTrinketIcons", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetSize(1, 1) -- Will be resized in UpdateLayout

    -- Pool of icon frames (reused as trinkets change)
    frame._iconPool = {}

    return frame
end

--- Override ShouldShow to check module enabled state and trinket availability.
---@return boolean shouldShow Whether the frame should be shown.
function TrinketIcons:ShouldShow()
    if not ECMFrame.ShouldShow(self) then
        return false
    end

    -- Also hide if UtilityCooldownViewer is not visible
    local utilityViewer = _G[C.VIEWER_UTILITY]
    if not utilityViewer or not utilityViewer:IsShown() then
        return false
    end

    return true
end

--- Override UpdateLayout to position icons relative to UtilityCooldownViewer.
---@return boolean success Whether the layout was applied.
function TrinketIcons:UpdateLayout()
    local frame = self.InnerFrame
    if not frame then
        return false
    end

    local moduleConfig = self.ModuleConfig
    if not moduleConfig then
        return false
    end

    -- Check visibility
    if not self:ShouldShow() then
        frame:Hide()
        return false
    end

    local utilityViewer = _G[C.VIEWER_UTILITY]
    if not utilityViewer then
        frame:Hide()
        return false
    end

    -- Get usable trinkets
    local trinkets = GetUsableTrinkets(moduleConfig)
    local numTrinkets = #trinkets
    local iconSize = GetUtilityViewerIconSize()
    local spacing = C.DEFAULT_TRINKET_ICON_SPACING

    -- Hide all existing icons first
    for _, icon in ipairs(frame._iconPool) do
        icon:Hide()
    end

    -- If no trinkets, restore viewer position and hide container
    if numTrinkets == 0 then
        -- Restore viewer to original position if we have it stored
        if self._viewerOriginalPoint then
            local orig = self._viewerOriginalPoint
            utilityViewer:ClearAllPoints()
            utilityViewer:SetPoint(orig[1], orig[2], orig[3], orig[4], orig[5])
        end
        frame:Hide()
        return false
    end

    -- Calculate container size
    local totalWidth = (numTrinkets * iconSize) + ((numTrinkets - 1) * spacing)
    local totalHeight = iconSize
    frame:SetSize(totalWidth, totalHeight)

    -- Calculate offset to keep visual midpoint centered
    -- The trinket container width plus the gap between viewer and first icon
    local trinketContainerWidth = totalWidth + spacing
    local viewerOffsetX = -(trinketContainerWidth / 2)

    -- Store original viewer position on first call, then apply offset
    if not self._viewerOriginalPoint then
        local point, relativeTo, relativePoint, x, y = utilityViewer:GetPoint()
        self._viewerOriginalPoint = { point, relativeTo, relativePoint, x or 0, y or 0 }
    end

    local orig = self._viewerOriginalPoint
    utilityViewer:ClearAllPoints()
    utilityViewer:SetPoint(orig[1], orig[2], orig[3], orig[4] + viewerOffsetX, orig[5])

    -- Ensure we have enough icons in the pool
    while #frame._iconPool < numTrinkets do
        local icon = CreateTrinketIcon(frame, iconSize)
        frame._iconPool[#frame._iconPool + 1] = icon
    end

    -- Position and configure each icon
    local xOffset = 0
    for i, trinketData in ipairs(trinkets) do
        local icon = frame._iconPool[i]
        icon:SetSize(iconSize, iconSize)
        icon.Icon:SetSize(iconSize, iconSize)
        icon.Mask:SetSize(iconSize, iconSize)
        icon.Border:SetSize(iconSize * 1.35, iconSize * 1.35)
        icon.slotId = trinketData.slotId

        -- Set texture
        icon.Icon:SetTexture(trinketData.texture)

        -- Position
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", frame, "LEFT", xOffset, 0)
        icon:Show()

        -- Update cooldown
        UpdateIconCooldown(icon, trinketData.slotId)

        xOffset = xOffset + iconSize + spacing
    end

    -- Position container to the right of UtilityCooldownViewer
    frame:ClearAllPoints()
    frame:SetPoint("LEFT", utilityViewer, "RIGHT", spacing, 0)
    frame:Show()

    Util.Log(self.Name, "TrinketIcons:UpdateLayout", {
        numTrinkets = numTrinkets,
        iconSize = iconSize,
        spacing = spacing,
        totalWidth = totalWidth,
    })

    return true
end

--- Override Refresh to update cooldown states.
function TrinketIcons:Refresh()
    if not ECMFrame.Refresh(self) then
        return false
    end

    local frame = self.InnerFrame
    if not frame or not frame:IsShown() then
        return false
    end

    -- Update cooldowns on all visible icons
    for _, icon in ipairs(frame._iconPool) do
        if icon:IsShown() and icon.slotId then
            UpdateIconCooldown(icon, icon.slotId)
        end
    end

    return true
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

function TrinketIcons:OnBagUpdateCooldown()
    self:Refresh()
end

function TrinketIcons:OnPlayerEquipmentChanged(_, slotId)
    -- Only update if a trinket slot changed
    if slotId == C.TRINKET_SLOT_1 or slotId == C.TRINKET_SLOT_2 then
        self:ScheduleLayoutUpdate()
    end
end

function TrinketIcons:OnPlayerEnteringWorld()
    self:ScheduleLayoutUpdate()
end

--- Hook the UtilityCooldownViewer to update when it shows/hides or resizes.
function TrinketIcons:HookUtilityViewer()
    local utilityViewer = _G[C.VIEWER_UTILITY]
    if not utilityViewer or self._viewerHooked then
        return
    end

    self._viewerHooked = true

    utilityViewer:HookScript("OnShow", function()
        self:ScheduleLayoutUpdate()
    end)

    utilityViewer:HookScript("OnHide", function()
        -- Restore viewer to original position
        if self._viewerOriginalPoint then
            local orig = self._viewerOriginalPoint
            utilityViewer:ClearAllPoints()
            utilityViewer:SetPoint(orig[1], orig[2], orig[3], orig[4], orig[5])
        end
        if self.InnerFrame then
            self.InnerFrame:Hide()
        end
    end)

    utilityViewer:HookScript("OnSizeChanged", function()
        self:ScheduleLayoutUpdate()
    end)

    Util.Log(self.Name, "Hooked UtilityCooldownViewer")
end

--------------------------------------------------------------------------------
-- Module Lifecycle
--------------------------------------------------------------------------------

function TrinketIcons:OnEnable()
    ECMFrame.AddMixin(self, "TrinketIcons")

    -- Register events
    self:RegisterEvent("BAG_UPDATE_COOLDOWN", "OnBagUpdateCooldown")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnPlayerEquipmentChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    -- Hook the utility viewer after a short delay to ensure Blizzard frames are loaded
    C_Timer.After(0.1, function()
        self:HookUtilityViewer()
        self:ScheduleLayoutUpdate()
    end)

    Util.Log(self.Name, "OnEnable - module enabled")
end

function TrinketIcons:OnDisable()
    self:UnregisterAllEvents()

    -- Restore viewer to original position
    if self._viewerOriginalPoint then
        local utilityViewer = _G[C.VIEWER_UTILITY]
        if utilityViewer then
            local orig = self._viewerOriginalPoint
            utilityViewer:ClearAllPoints()
            utilityViewer:SetPoint(orig[1], orig[2], orig[3], orig[4], orig[5])
        end
    end

    if self.InnerFrame then
        self.InnerFrame:Hide()
    end

    Util.Log(self.Name, "Disabled")
end
