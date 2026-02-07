local _,  ns = ...

local constants = {
    TRACE_LOG_MAX = 200,

    -- Internal module names
    POWERBAR = "PowerBar",
    RESOURCEBAR = "ResourceBar",
    RUNEBAR = "RuneBar",
    BUFFBARS = "BuffBars",
    ITEMICONS = "ItemIcons",

    -- Blizzard frame names
    VIEWER = "EssentialCooldownViewer",
    VIEWER_BUFFBAR = "BuffBarCooldownViewer",
    VIEWER_UTILITY = "UtilityCooldownViewer",
    ADDON_ICON_TEXTURE = "Interface\\AddOns\\EnhancedCooldownManager\\Media\\icon",

    -- Default or fallback values for configuration
    DEFAULT_REFRESH_FREQUENCY = 0.066,
    DEFAULT_BAR_HEIGHT = 20,
    DEFAULT_BAR_WIDTH = 250,
    DEFAULT_FREE_ANCHOR_OFFSET_Y = -300,
    DEFAULT_BG_COLOR = { r = 0.08, g = 0.08, b = 0.08, a = 0.65 },
    DEFAULT_STATUSBAR_TEXTURE = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    FALLBACK_TEXTURE = "Interface\\Buttons\\WHITE8X8",

    -- Color constants
    COLOR_BLACK = { r = 0, g = 0, b = 0, a = 1 },
    COLOR_WHITE = { r = 1, g = 1, b = 1, a = 1 },

    -- Module-specific constants and configuration
    POWERBAR_SHOW_MANABAR = { MAGE = true, WARLOCK = true, DRUID = true },
    RESOURCEBAR_SPIRIT_BOMB_SPELLID = 247454,
    RESOURCEBAR_VOID_FRAGMENTS_SPELLID = 1225789, -- tracks progress towards void meta form (35 fragments)
    RESOURCEBAR_COLLAPSING_STAR_SPELLID = 1227702, -- when in void meta, tracks progress towards collapsing star (30 stacks)
    RESOURCEBAR_VENGEANCE_SOULS_MAX = 6 ,
    RUNEBAR_MAX_RUNES = 6,
    BUFFBARS_DEFAULT_COLOR = { r = 0.9, g = 0.9, b = 0.9, a = 1 },
    BUFFBARS_ICON_TEXTURE_REGION_INDEX = 1,  -- TODO: this and the following line might need to go.
    BUFFBARS_ICON_OVERLAY_REGION_INDEX = 3,
    BUFFBARS_TEXT_PADDING = 4,
    GROUP_INSTANCE_TYPES = { party = true, raid = true, arena = true, pvp = true, delve = true }, -- keyed by IsInInstance()[2]

    DEMONHUNTER_CLASS_ID = 12,
    DEMONHUNTER_VENGEANCE_SPEC_INDEX = 2,
    DEMONHUNTER_DEVOURER_SPEC_INDEX = 3,

    -- Trinket slots
    TRINKET_SLOT_1 = 13,
    TRINKET_SLOT_2 = 14,

    -- Consumable item IDs (priority-ordered: best first)
    COMBAT_POTIONS = { 212265, 212264, 212263 },           -- Tempered Potion R3, R2, R1
    HEALTH_POTIONS = { 211880, 211879, 211878,             -- Algari Healing Potion R3, R2, R1
                       212244, 212243, 212242 },            -- Cavedweller's Delight R3, R2, R1
    COMBAT_POTIONS_OPTIONS = {
        { itemId = 212265, showInOptions = true },
        { itemId = 212264, showInOptions = false },
        { itemId = 212263, showInOptions = false },
    },
    HEALTH_POTIONS_OPTIONS = {
        { itemId = 211880, showInOptions = true },
        { itemId = 211879, showInOptions = false },
        { itemId = 211878, showInOptions = false },
        { itemId = 212244, showInOptions = false },
        { itemId = 212243, showInOptions = false },
        { itemId = 212242, showInOptions = false },
    },
    HEALTHSTONE_ITEM_ID = 5512,
    ITEM_ICONS_MAX = 5,

    -- Item icon defaults
    DEFAULT_ITEM_ICON_SIZE = 32,
    DEFAULT_ITEM_ICON_SPACING = 2,
    ITEM_ICON_BORDER_SCALE = 1.35,

    -- Guardrail for measured utility icon spacing (as a factor of icon width)
    -- TODO: this has to go. it's gross.
    ITEM_ICON_MAX_SPACING_FACTOR = 0.6,
    ITEM_ICON_LAYOUT_REMEASURE_DELAY = 0.1,
    ITEM_ICON_LAYOUT_REMEASURE_ATTEMPTS = 2,
    ITEM_ICONS_OPTIONS_PREVIEW_SIZE = 30,
    ITEM_ICONS_OPTIONS_INACTIVE_ALPHA = 0.7,
    ITEM_ICONS_OPTIONS_TRINKET1_ICON_ID = 7137585,
    ITEM_ICONS_OPTIONS_TRINKET2_ICON_ID = 7137586,
    ITEM_ICONS_OPTIONS_FALLBACK_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark",
    ITEM_ICONS_OPTIONS_ARROW_TEXT = "→",
    ITEM_ICONS_OPTIONS_ROW_WIDTH = 2.0,
    ITEM_ICONS_OPTIONS_TOGGLE_WIDTH = 1.1,
    ITEM_ICONS_OPTIONS_PREVIEW_WIDTH = 0.11,
    ITEM_ICONS_OPTIONS_ARROW_WIDTH = 0.048,
    ITEM_ICONS_OPTIONS_STATIC_PREVIEW_WIDTH = 0.25,
    ITEM_ICONS_OPTIONS_ROW_SPACER_ORDER_STEP = 0.01,

    -- Configuration section names
    CONFIG_SECTION_GLOBAL = "global",

    ANCHORMODE_CHAIN = "chain",
    ANCHORMODE_FREE = "free",
}

local BLIZZARD_FRAMES = {
    constants.VIEWER,
    constants.VIEWER_UTILITY,
    "BuffIconCooldownViewer",
    constants.VIEWER_BUFFBAR,
}

local order = { constants.POWERBAR, constants.RESOURCEBAR, constants.RUNEBAR, constants.BUFFBARS }
constants.CHAIN_ORDER = order
constants.BLIZZARD_FRAMES = BLIZZARD_FRAMES

ns.Constants = constants
