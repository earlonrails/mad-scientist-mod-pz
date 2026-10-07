-- MadScientist_Server.lua
MadScientist = MadScientist or {}

--- Spawns and configures the Mad Scientist zombie when a zombie object is initialized
function MadScientist.OnZombieCreate(zombie)
    if not zombie then return end

    local modData = zombie:getModData()

    -- Avoid double processing
    if modData.processedMadScientist then return end
    modData.processedMadScientist = true

    -- Get sandbox options
    local spawnChance = MadScientist.GetSandboxVar("SpawnChance", 10000)
    local isSprinter = MadScientist.GetSandboxVar("IsSprinter", true)
    local healthMult = MadScientist.GetSandboxVar("HealthMultiplier", 3.0)
    local damageMult = MadScientist.GetSandboxVar("DamageMultiplier", 1.5)
    local cureGuaranteed = MadScientist.GetSandboxVar("CureGuaranteed", true)

    -- Determine if this zombie becomes the Mad Scientist
    local isSpecialSpawn = false
    if modData.forceMadScientist then
        isSpecialSpawn = true
    else
        -- ZomboidRandom(N) returns integer from 0 to N-1
        if ZomboidRandom and spawnChance > 0 then
            isSpecialSpawn = (ZomboidRandom(spawnChance) == 0)
        end
    end

    if not isSpecialSpawn then return end

    -- Mark as Mad Scientist
    modData.isMadScientist = true
    modData.madScientistDamageMult = damageMult

    -- 1. Apply Health Multiplier
    local currentHealth = zombie:getHealth() or 1.5
    zombie:setHealth(currentHealth * healthMult)

    -- 2. Apply Sprinter Trait
    if isSprinter then
        if zombie.setVariable then
            zombie:setVariable("bSprinter", true)
            zombie:setVariable("IsSprinter", "true")
            zombie:setVariable("sprinter", "true")
        end
        if zombie.makeSprinter then
            pcall(function() zombie:makeSprinter() end)
        end
    end

    -- 3. Visual & Outfit Setup
    pcall(function()
        zombie:dressInNamedOutfit("Doctor")
    end)

    local inv = zombie:getInventory()
    if inv then
        -- Inject scientist attire items
        inv:AddItem("Base.LabCoat")
        inv:AddItem("Base.Glasses_Reading")
        inv:AddItem("Base.Gloves_Surgical")
        inv:AddItem("Base.Mask_Surgical")

        -- 4. Inject Knox Virus Vaccine Syringe
        if cureGuaranteed then
            inv:AddItem("MadScientist.KnoxVirusCure")
        end
    end

    print("[MadScientist Mod] Mad Scientist Zombie spawned! (Sprinter=" .. tostring(isSprinter) .. ", HealthMult=" .. tostring(healthMult) .. "x)")
end

--- Ensures the Knox Virus Vaccine is on the corpse when Mad Scientist dies
function MadScientist.OnZombieDead(zombie)
    if not zombie then return end
    if MadScientist.IsMadScientist(zombie) then
        local inv = zombie:getInventory()
        if inv and not inv:contains("MadScientist.KnoxVirusCure") then
            inv:AddItem("MadScientist.KnoxVirusCure")
        end
    end
end

--- Custom attack handler to apply damage multiplier on player hit
function MadScientist.OnZombieHitPlayer(zombie, player, bodyPartType, damage)
    if zombie and player and MadScientist.IsMadScientist(zombie) then
        local modData = zombie:getModData()
        local damageMult = modData.madScientistDamageMult or MadScientist.GetSandboxVar("DamageMultiplier", 1.5)
        if damageMult and damageMult > 1.0 then
            local bodyDamage = player:getBodyDamage()
            if bodyDamage then
                -- Apply additional damage tick based on multiplier
                local extraDamage = damage * (damageMult - 1.0)
                bodyDamage:ReduceGeneralHealth(extraDamage)
            end
        end
    end
end

-- Register Event Handlers
Events.OnZombieCreate.Add(MadScientist.OnZombieCreate)
Events.OnZombieDead.Add(MadScientist.OnZombieDead)

print("[MadScientist Mod] Server logic registered.")
