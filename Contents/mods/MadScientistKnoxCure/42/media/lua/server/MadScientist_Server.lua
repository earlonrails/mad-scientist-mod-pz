-- MadScientist_Server.lua
MadScientist = MadScientist or {}

-- ---------------------------------------------------------------------------
-- Mad Scientist selection.
--
-- Vanilla-sprinter-style behaviour: each zombie gets ONE stable roll stored in
-- modData (madSciRoll, 0..999999). It becomes the Mad Scientist when
-- madSciRoll < currentThreshold, where threshold = 1,000,000 * (percent/100)
-- and percent = the SpawnChancePercent sandbox option (0-100, decimals allowed;
-- e.g. 0.5 = 0.5% of zombies, 0.01 ~= the old 1-in-10,000). Because the roll is
-- fixed but the threshold is read live, RAISING SpawnChancePercent (bigger
-- threshold) lets already-existing zombies qualify and convert; LOWERING it does
-- not un-convert (one-way -- a zombie that already became the scientist stays).
--
-- Evaluated on two cheap triggers (NO per-tick work):
--   * OnZombieCreate  -> covers freshly spawned + virtual zombies realized as
--                        the player moves back into an area.
--   * EveryOneMinute  -> sweeps only the LOADED zombie list (bounded, the ones
--                        near players) and converts any not-yet-decided zombie
--                        that now qualifies; already-decided ones early-out.
-- ---------------------------------------------------------------------------

local MADSCI_ROLL_RANGE = 1000000

--- Current qualifying threshold from the live SpawnChancePercent (0-100).
--- roll < threshold  => this zombie is the Mad Scientist.
function MadScientist.GetSpawnThreshold()
    local percent = MadScientist.GetSandboxVar("SpawnChancePercent", 0.1)
    if not percent or percent <= 0 then return 0 end
    if percent >= 100 then return MADSCI_ROLL_RANGE end
    return MADSCI_ROLL_RANGE * (percent / 100)
end

--- Transforms a plain zombie into the Mad Scientist (outfit, stats, cure item).
--- Idempotent via modData.isMadScientist; only runs the expensive setup once.
function MadScientist.MakeMadScientist(zombie)
    if not zombie then return end
    local modData = zombie:getModData()
    if modData.isMadScientist then return end

    local healthMult = MadScientist.GetSandboxVar("HealthMultiplier", 3.0)
    local damageMult = MadScientist.GetSandboxVar("DamageMultiplier", 1.5)
    local cureGuaranteed = MadScientist.GetSandboxVar("CureGuaranteed", true)

    modData.isMadScientist = true
    modData.madScientistDamageMult = damageMult

    -- Health multiplier
    local currentHealth = zombie:getHealth() or 1.5
    zombie:setHealth(currentHealth * healthMult)

    -- Sprinter: stable roll + live threshold (see MadScientist.ApplySpeed)
    modData.madScientistSprintRoll = MadScientist.RollSprintThreshold()
    MadScientist.ApplySpeed(zombie)

    -- Outfit: dress the zombie in the vanilla "Doctor" outfit. Zombies render
    -- clothing via the outfit/descriptor system, NOT runtime setWornItem --
    -- dressInPersistentOutfit("Doctor") visibly dresses the zombie (confirmed
    -- in-game), whereas dressInNamedOutfit and hand-equipping items via
    -- setWornItem do NOT render on a zombie. "Doctor" is a verified vanilla
    -- outfit name. (TODO: layer an NBC mask on top once the outfit/descriptor
    -- attach path is worked out -- setWornItem equips it on the data model but
    -- it won't render on a zombie.)
    pcall(function() zombie:dressInPersistentOutfit("Doctor") end)

    -- Cure item goes IN the inventory (to loot from the corpse), not worn.
    local inv = zombie:getInventory()
    if inv and cureGuaranteed then
        pcall(function() inv:AddItem("MadScientist.KnoxVirusCure") end)
    end

    print("[MadScientist Mod] Mad Scientist Zombie created! (SprintRoll=" ..
        tostring(modData.madScientistSprintRoll) .. ", HealthMult=" .. tostring(healthMult) .. "x)")
end

--- Assigns the stable roll if missing, then converts the zombie IF it now
--- qualifies under the live threshold. Cheap: an int compare for the common
--- "already decided / doesn't qualify" case. Returns true if it converted.
function MadScientist.EvaluateZombie(zombie)
    if not zombie then return false end
    local modData = zombie:getModData()
    if modData.isMadScientist then return false end       -- already one, done
    if modData.forceMadScientist then
        MadScientist.MakeMadScientist(zombie)
        return true
    end

    -- Stable per-zombie roll, assigned once and persisted in modData.
    -- ZombRand(N) is the real PZ global (returns 0..N-1); if it's somehow
    -- unavailable, fall back to a HIGH roll so the zombie does NOT convert
    -- (never default to 0, which would make every zombie qualify).
    if modData.madSciRoll == nil then
        modData.madSciRoll = ZombRand and ZombRand(MADSCI_ROLL_RANGE) or (MADSCI_ROLL_RANGE - 1)
    end

    if modData.madSciRoll < MadScientist.GetSpawnThreshold() then
        MadScientist.MakeMadScientist(zombie)
        return true
    end
    return false
end

--- Fired when a zombie object is created (fresh spawn or virtual->real).
function MadScientist.OnZombieCreate(zombie)
    MadScientist.EvaluateZombie(zombie)
end

-- Zombies within this many tiles of a player are treated as "on screen" and are
-- NOT converted by the sweep, so you never watch one morph into the scientist
-- in front of you. They convert later off-screen or via the reactivation path.
local MADSCI_VISIBLE_RADIUS = 18

--- True if the zombie is close enough to any active player to likely be on
--- screen. Cheap: a squared-ish distance check per active player (usually 1).
function MadScientist.IsNearAnyPlayer(zombie)
    if not (getNumActivePlayers and IsoUtils and IsoUtils.DistanceTo) then
        return false
    end
    local zx, zy = zombie:getX(), zombie:getY()
    local n = getNumActivePlayers()
    for i = 0, n - 1 do
        local p = getSpecificPlayer(i)
        if p and p:getZ() == zombie:getZ() then
            if IsoUtils.DistanceTo(zx, zy, p:getX(), p:getY()) <= MADSCI_VISIBLE_RADIUS then
                return true
            end
        end
    end
    return false
end

--- Returns a stable per-zombie sprinter roll in 0..99. Stored once when the
--- zombie becomes a Mad Scientist and compared to the CURRENT SprinterPercentage
--- (roll < pct = sprinter), so its identity is fixed but the threshold is live.
function MadScientist.RollSprintThreshold()
    if ZombRand then
        return ZombRand(100) -- 0..99
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

--- Applies the Mad Scientist's current speed type via the real IsoZombie API.
--- Called when a zombie becomes the Mad Scientist and re-applied during the
--- periodic sweep — matching vanilla, which caches each zombie's speedType
--- rather than recomputing it every tick.
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

-- Tracks last-seen SprinterPercentage so existing scientists' speed is only
-- re-applied when it actually changed (otherwise it's left cached).
MadScientist.lastSprinterPct = nil

--- Single cheap periodic pass over the LOADED zombie list (the ones near
--- players; bounded). Does two jobs in one loop so there is only ever one
--- sweep per minute:
---   1. Convert not-yet-decided zombies that now qualify as Mad Scientist
---      (lets existing nearby zombies turn after SpawnChance is lowered).
---   2. If SprinterPercentage changed, re-apply speed to existing scientists.
--- No per-tick work anywhere; each zombie is an int compare + early-out.
function MadScientist.OnPeriodicSweep()
    local cell = getCell and getCell()
    if not cell then return end
    local zombies = cell:getZombieList()
    if not zombies then return end

    local threshold = MadScientist.GetSpawnThreshold()
    local pct = MadScientist.GetSandboxVar("SprinterPercentage", 100)
    local sprinterChanged = (pct ~= MadScientist.lastSprinterPct)
    MadScientist.lastSprinterPct = pct

    -- Nothing to do if no conversions are possible AND sprinter % is unchanged.
    if threshold <= 0 and not sprinterChanged then return end

    for i = 0, zombies:size() - 1 do
        local z = zombies:get(i)
        if z then
            if z:getModData().isMadScientist then
                if sprinterChanged then MadScientist.ApplySpeed(z) end
            elseif threshold > 0 and not MadScientist.IsNearAnyPlayer(z) then
                -- Only convert OFF-SCREEN zombies, so a player never sees one
                -- morph into the Mad Scientist right in front of them.
                MadScientist.EvaluateZombie(z)
            end
        end
    end
end

--- Ensures the Knox Virus Cure is on the corpse when Mad Scientist dies
function MadScientist.OnZombieDead(zombie)
    if not zombie then return end
    if MadScientist.IsMadScientist(zombie) then
        local inv = zombie:getInventory()
        if inv and not inv:contains("MadScientist.KnoxVirusCure") then
            pcall(function() inv:AddItem("MadScientist.KnoxVirusCure") end)
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
-- One cheap sweep/minute (NOT per-tick): converts existing loaded zombies that
-- qualify after SpawnChance is lowered, and re-applies sprinter speed when
-- SprinterPercentage changed. Bounded to the loaded zombie list, int-compare
-- early-outs per zombie.
Events.EveryOneMinute.Add(MadScientist.OnPeriodicSweep)

print("[MadScientist Mod] Server logic registered.")
