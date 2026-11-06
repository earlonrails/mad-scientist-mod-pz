-- MadScientist_Client.lua
MadScientist = MadScientist or {}

--- Handler for using/injecting the Knox Virus Vaccine
function MadScientist.UseCure(player, item)
    if not player or not item then return end

    -- Play injection audio effect
    if player:getEmitter() then
        player:getEmitter():playSound("Inject")
    end

    -- Clear Knox Virus infection using ONLY verified B42 BodyDamage API.
    -- B41 methods setInfectionLevel / setFoodSicknessLevel / setPoisonLevel do
    -- NOT exist in B42 (calling them is "tried to call nil" and crashes). The
    -- B42 cure path is: clear the infected flag, zero the infection timers, and
    -- RestoreToFullHealth() (which also resets the body parts / wounds).
    local bodyDamage = player:getBodyDamage()
    if bodyDamage then
        pcall(function() bodyDamage:setInfected(false) end)
        pcall(function() bodyDamage:setInfectionTime(-1) end)
        pcall(function() bodyDamage:setInfectionMortalityDuration(-1) end)
        pcall(function() bodyDamage:setInfectionGrowthRate(0) end)
        -- Clear wound infection on each body part (B42: setWoundInfectionLevel).
        local bodyParts = bodyDamage:getBodyParts()
        if bodyParts then
            for i = 0, bodyParts:size() - 1 do
                local part = bodyParts:get(i)
                if part then
                    pcall(function() part:SetInfected(false) end)
                    pcall(function() part:setWoundInfectionLevel(-1) end)
                end
            end
        end
        pcall(function() bodyDamage:RestoreToFullHealth() end)
    end

    -- Visual feedback text above player (green = good; addGoodText is the only
    -- working colored halo call in B42 -- the colored addText overloads crash).
    if HaloTextHelper and HaloTextHelper.addGoodText then
        HaloTextHelper.addGoodText(player, getText("IGUI_MadScientist_Cured"))
    end
    player:Say("The vaccine worked... The Knox Virus has been neutralized!")

    -- Side effect: the experimental vaccine inflicts a random negative trait the
    -- player doesn't already have, chosen by the configurable per-trait weights.
    MadScientist.GrantRandomNegativeTrait(player)

    -- Consume the syringe item
    local inv = player:getInventory()
    if inv then
        inv:Remove(item)
    end
end

--- Picks one eligible negative trait by weighted random and applies it, then
--- shows a halo naming the trait. Eligible = positive weight, not already owned,
--- and not gated out by the nutrition/sleep/MP checks. No-op if none eligible.
function MadScientist.GrantRandomNegativeTrait(player)
    if not player then return end
    local traits = player.getCharacterTraits and player:getCharacterTraits()
    if not traits then return end

    local nutrition = MadScientist.IsNutritionEnabled()
    local sleep = MadScientist.IsSleepEnabled()
    local mp = MadScientist.IsMultiplayer()

    -- Build the weighted eligible pool.
    local pool, total = {}, 0
    for _, t in ipairs(MadScientist.NEGATIVE_TRAITS) do
        -- Resolve the engine's canonical trait type via the definition, so we
        -- feed hasTrait/add exactly what getType() returns (avoids any id-string
        -- drift); fall back to the raw id if the lookup is unavailable.
        local traitType = t.trait
        if CharacterTraitDefinition and CharacterTraitDefinition.getCharacterTraitDefinition then
            local def = CharacterTraitDefinition.getCharacterTraitDefinition(t.trait)
            if def and def.getType then traitType = def:getType() end
        end

        local weight = MadScientist.GetSandboxVar(t.opt, t.weight)
        local eligible = weight and weight > 0
        if eligible and t.requiresNutrition and not nutrition then eligible = false end
        if eligible and t.requiresSleep and not sleep then eligible = false end
        if eligible and t.disabledInMP and mp then eligible = false end
        if eligible and player:hasTrait(traitType) then eligible = false end
        if eligible then
            total = total + weight
            pool[#pool + 1] = { t = t, traitType = traitType, weight = weight }
        end
    end

    if total <= 0 or #pool == 0 then return end

    -- Weighted pick: roll 0..total-1 and walk the cumulative weights.
    local roll = ZombRand and ZombRand(total) or (math.random(total) - 1)
    local chosen
    local acc = 0
    for _, entry in ipairs(pool) do
        acc = acc + entry.weight
        if roll < acc then chosen = entry break end
    end
    chosen = chosen or pool[#pool]

    traits:add(chosen.traitType)

    -- Halo naming the trait they got (red/bad, since it's a drawback).
    if HaloTextHelper and HaloTextHelper.addBadText then
        local traitName = getText(chosen.t.name)
        HaloTextHelper.addBadText(player, getText("IGUI_MadScientist_GotTrait", traitName))
    end
end

--- Add context menu option when right-clicking the Knox Virus Vaccine in inventory
function MadScientist.OnFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local vaccineItem = nil

    for _, itemData in ipairs(items) do
        local item = itemData
        if type(itemData) == "table" and itemData.items then
            item = itemData.items[1]
        end

        if item and (item:getFullType() == "MadScientist.KnoxVirusCure" or item:getType() == "KnoxVirusCure") then
            vaccineItem = item
            break
        end
    end

    if vaccineItem then
        local optionName = getText("ContextMenu_MadScientist_InjectCure") or "Inject Knox Virus Vaccine"
        context:addOption(optionName, player, MadScientist.UseCure, vaccineItem)
    end
end

-- Register Client Event Hooks
Events.OnFillInventoryObjectContextMenu.Add(MadScientist.OnFillInventoryObjectContextMenu)

print("[MadScientist Mod] Client logic registered.")
