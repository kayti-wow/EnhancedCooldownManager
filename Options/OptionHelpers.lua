
local _, ns = ...

local ECM = ns.Addon
local C = ns.Constants

--- Gets a module config value for options with a fallback default.
---@param self ECM_ItemIconsModule
---@param key string
---@param defaultValue boolean
---@return boolean
local function GetOptionValue(self, key, defaultValue)
    local moduleConfig = self.ModuleConfig
    if moduleConfig and moduleConfig[key] ~= nil then
        return moduleConfig[key]
    end

    return defaultValue
end

--- Returns true when non-enable options should be disabled.
---@param self ECM_ItemIconsModule
---@return boolean
local function IsOptionsDisabled(self)
    return not GetOptionValue(self, "enabled", true)
end

ECM.OptionHelpers = {
    IsOptionsDisabled = IsOptionsDisabled,
    GetOptionValue = GetOptionValue,
}
