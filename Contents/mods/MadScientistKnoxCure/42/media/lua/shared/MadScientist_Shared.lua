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

-- ---------------------------------------------------------------------------
-- Negative traits granted when the Knox Virus Vaccine is used.
--
-- Single source of truth for: the sandbox option name (one weight slider per
-- trait), the engine trait id passed to getCharacterTraits():add(), the vanilla
-- UI translation key for the display name shown in the halo, the default weight
-- (relative chance; 0 = never), and eligibility gates.
--
-- Trait ids were verified against vanilla B42 scripts on the PC. Note the
-- display<->id inversions: "Puny"=weak, "Weak"=feeble, "Restless Sleeper"=
-- insomniac, "Sleepyhead"=needsmoresleep, "Short of Breath"=asthmatic,
-- "Fast Metabolism"=weightloss.
--
-- Default weights encode the user's chance tiers:
--   normal = 100, "low" = 30, "lower" = 15, "extremely low" = 5.
--
-- Gates (requiresNutrition / requiresSleep / disabledInMP) remove a trait from
-- the eligible pool at selection time when that system is off, so e.g. the
-- weight traits never apply with the nutrition system disabled.
-- ---------------------------------------------------------------------------
MadScientist.NEGATIVE_TRAITS = {
    { opt = "WeightAgoraphobic",   trait = "agoraphobic",    name = "UI_trait_agoraphobic",   weight = 30 },  -- low
    { opt = "WeightAllThumbs",     trait = "allthumbs",      name = "UI_trait_AllThumbs",     weight = 30 },  -- low
    { opt = "WeightClaustrophobic",trait = "claustrophobic", name = "UI_trait_claustro",      weight = 30 },  -- low
    { opt = "WeightDeaf",          trait = "deaf",           name = "UI_trait_deaf",          weight = 15 },  -- lower
    { opt = "WeightClumsy",        trait = "clumsy",         name = "UI_trait_clumsy",        weight = 100 },
    { opt = "WeightConspicuous",   trait = "conspicuous",    name = "UI_trait_Conspicuous",   weight = 100 },
    { opt = "WeightDisorganized",  trait = "disorganized",   name = "UI_trait_Disorganized",  weight = 100, disabledInMP = true },
    { opt = "WeightFastMetabolism",trait = "weightloss",     name = "UI_trait_weightloss",    weight = 100, requiresNutrition = true },
    { opt = "WeightFearOfBlood",   trait = "hemophobic",     name = "UI_trait_Hemophobic",    weight = 100 },
    { opt = "WeightHardOfHearing", trait = "hardofhearing",  name = "UI_trait_hardhear",      weight = 5 },   -- extremely low
    { opt = "WeightHeartyAppetite",trait = "heartyappetite", name = "UI_trait_heartyappetite",weight = 100 },
    { opt = "WeightHighThirst",    trait = "highthirst",     name = "UI_trait_HighThirst",    weight = 100 },
    { opt = "WeightHighWeight",    trait = "overweight",     name = "UI_trait_overweight",    weight = 100, requiresNutrition = true },
    { opt = "WeightIlliterate",    trait = "illiterate",     name = "UI_trait_Illiterate",    weight = 5 },   -- extremely low
    { opt = "WeightLowWeight",     trait = "underweight",    name = "UI_trait_underweight",   weight = 100, requiresNutrition = true },
    { opt = "WeightOutOfShape",    trait = "out of shape",   name = "UI_trait_outofshape",    weight = 100 },
    { opt = "WeightProneToIllness",trait = "pronetoillness", name = "UI_trait_pronetoillness",weight = 100 },
    { opt = "WeightPuny",          trait = "weak",           name = "UI_trait_weak",          weight = 5 },   -- extremely low
    { opt = "WeightReluctantFighter", trait = "cowardly",    name = "UI_trait_cowardly",      weight = 30 },  -- low (Reluctant Fighter = Cowardly)
    { opt = "WeightRestlessSleeper", trait = "insomniac",    name = "UI_trait_Insomniac",     weight = 100, requiresSleep = true },
    { opt = "WeightShortOfBreath", trait = "asthmatic",      name = "UI_trait_Asthmatic",     weight = 100 },
    { opt = "WeightShortSighted",  trait = "shortsighted",   name = "UI_trait_shortsigh",     weight = 100 },
    { opt = "WeightSleepyhead",    trait = "needsmoresleep", name = "UI_trait_MoreSleep",     weight = 100, requiresSleep = true },
    { opt = "WeightSlowHealer",    trait = "slowhealer",     name = "UI_trait_SlowHealer",    weight = 100 },
    { opt = "WeightSlowReader",    trait = "slowreader",     name = "UI_trait_SlowReader",    weight = 100 },
    { opt = "WeightSmoker",        trait = "smoker",         name = "UI_trait_Smoker",        weight = 100 },
    { opt = "WeightSundayDriver",  trait = "sundaydriver",   name = "UI_trait_SundayDriver",  weight = 100 },
    { opt = "WeightThinSkinned",   trait = "thinskinned",    name = "UI_trait_thinskinned",   weight = 100 },
    { opt = "WeightUnfit",         trait = "unfit",          name = "UI_trait_unfit",         weight = 30 },  -- low
    { opt = "WeightVeryHighWeight",trait = "obese",          name = "UI_trait_obese",         weight = 100, requiresNutrition = true },
    { opt = "WeightVeryLowWeight", trait = "very underweight", name = "UI_trait_veryunderweight", weight = 100, requiresNutrition = true },
    { opt = "WeightWeak",          trait = "feeble",         name = "UI_trait_feeble",        weight = 5 },   -- extremely low (display "Weak" = feeble)
    { opt = "WeightWeakStomach",   trait = "weakstomach",    name = "UI_trait_WeakStomach",   weight = 100 },
}

--- True when the game's nutrition system is enabled (weight/metabolism traits).
function MadScientist.IsNutritionEnabled()
    if SandboxVars and SandboxVars.Nutrition ~= nil then
        return SandboxVars.Nutrition == true
    end
    return true -- default on
end

--- True when sleep is enabled (single-player always; MP via SleepAllowed).
function MadScientist.IsSleepEnabled()
    if SandboxVars and SandboxVars.SleepAllowed ~= nil then
        return SandboxVars.SleepAllowed == true
    end
    return true
end

--- True when the current game is multiplayer.
function MadScientist.IsMultiplayer()
    return (isClient and isClient()) or (isServer and isServer()) or false
end

print("[MadScientist Mod] Shared initialized successfully.")
