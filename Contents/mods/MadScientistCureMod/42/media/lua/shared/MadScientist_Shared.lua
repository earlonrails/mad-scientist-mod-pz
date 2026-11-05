-- MadScientist_Shared.lua
MadScientist = MadScientist or {}

--- Returns sandbox configuration value with fallback default
function MadScientist.GetSandboxVar(varName, defaultValue)
    if SandboxVars and SandboxVars.MadScientist and SandboxVars.MadScientist[varName] ~= nil then
        return SandboxVars.MadScientist[varName]
    end
    return defaultValue
end

--- Checks if a character/zombie is designated as a Mad Scientist
function MadScientist.IsMadScientist(zombie)
    if not zombie then return false end
    local modData = zombie:getModData()
    return modData and modData.isMadScientist == true
end

print("[MadScientist Mod] Shared initialized successfully.")
