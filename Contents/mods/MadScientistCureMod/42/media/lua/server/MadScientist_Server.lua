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

    -- 2. Give this zombie a STABLE sprinter roll (0-99), mirroring vanilla's
    --    SprinterPercentage. The roll is fixed per zombie; whether it's actually
    --    a sprinter is decided each tick by comparing the roll to the CURRENT
    --    percentage. So raising/lowering the setting mid-game flips already-
    --    spawned Mad Scientists live (like vanilla), without random flicker.
    modData.madScientistSprintRoll = MadScientist.RollSprintThreshold()
    MadScientist.ApplySpeed(zombie)

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

    print("[MadScientist Mod] Mad Scientist Zombie spawned! (SprintRoll=" .. tostring(modData.madScientistSprintRoll) .. ", HealthMult=" .. tostring(healthMult) .. "x)")
end

--- Returns a stable per-zombie sprinter roll in 0..99. Stored once at spawn and
--- compared to the CURRENT SprinterPercentage each tick (roll < pct = sprinter),
--- so a zombie's identity is fixed but the threshold is live, like vanilla.
function MadScientist.RollSprintThreshold()
    if ZomboidRandom then
        return ZomboidRandom(100) -- 0..99
    end
    return 0 -- fallback: treat as sprinter for any pct > 0
end

--- True if this Mad Scientist should currently be a sprinter, from its stable
--- roll vs the live SprinterPercentage.
function MadScientist.ShouldSprint(zombie)
    local modData = zombie:getModData()
    local pct = MadScientist.GetSandboxVar("SprinterPercentage", 100)
    if pct <= 0 then return false end
    if pct >= 100 then return true end
    local roll = modData.madScientistSprintRoll
    if roll == nil then
        -- Legacy/missing roll: assign one now so behaviour stays stable.
        roll = MadScientist.RollSprintThreshold()
        modData.madScientistSprintRoll = roll
    end
    return roll < pct
end

--- Enforces the Mad Scientist's current speed type via the real IsoZombie API.
--- Applies the Mad Scientist's current speed type via the real IsoZombie API.
--- Called at spawn and only re-applied when SprinterPercentage changes (see
--- MadScientist.OnSprinterPctChanged) — matching vanilla, which caches each
--- zombie's speedType rather than recomputing it every tick.
function MadScientist.ApplySpeed(zombie)
    if not zombie then return end
    local wantSprinter = MadScientist.ShouldSprint(zombie)

    -- Compare against the engine's own speed-type constants rather than magic
    -- numbers, so this stays correct if the enum values differ. Skip the call
    -- when the zombie is already at the desired speed.
    if zombie.getSpeedType and IsoZombie then
        local current = zombie:getSpeedType()
        if wantSprinter and IsoZombie.SPEED_SPRINTER ~= nil
            and current == IsoZombie.SPEED_SPRINTER then
            return
        end
        if (not wantSprinter) and IsoZombie.SPEED_SHAMBLER ~= nil
            and current == IsoZombie.SPEED_SHAMBLER then
            return
        end
    end

    if wantSprinter then
        if zombie.doSprinter then zombie:doSprinter() end
    else
        if zombie.doShambler then zombie:doShambler() end
    end
end

-- Tracks the last-seen SprinterPercentage so we only sweep zombies on a change.
MadScientist.lastSprinterPct = nil

--- Periodic cheap check: if SprinterPercentage changed since last time, sweep
--- the currently-loaded zombies once and re-apply speed to Mad Scientists.
--- This mirrors vanilla's cached model (no per-tick work) while still making a
--- mid-game setting change take effect on already-spawned Mad Scientists.
function MadScientist.OnSprinterPctChanged()
    local pct = MadScientist.GetSandboxVar("SprinterPercentage", 100)
    if pct == MadScientist.lastSprinterPct then return end
    MadScientist.lastSprinterPct = pct

    local cell = getCell and getCell()
    if not cell then return end
    local zombies = cell:getZombieList()
    if not zombies then return end
    for i = 0, zombies:size() - 1 do
        local z = zombies:get(i)
        if z and MadScientist.IsMadScientist(z) then
            MadScientist.ApplySpeed(z)
        end
    end
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
-- Cheap periodic check (not per-tick) to re-apply speed only when the
-- SprinterPercentage sandbox option changes mid-game, mirroring vanilla.
Events.EveryOneMinute.Add(MadScientist.OnSprinterPctChanged)

print("[MadScientist Mod] Server logic registered.")
