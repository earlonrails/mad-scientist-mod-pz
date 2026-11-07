-- MadScientist_Debug.lua
MadScientist = MadScientist or {}

--- Debug function to spawn a Mad Scientist zombie next to player
function MadScientist.SpawnTestScientist()
    local player = getPlayer()
    if not player then return end

    local square = player:getSquare()
    if not square then return end

    local x = square:getX() + 1
    local y = square:getY() + 1
    local z = square:getZ()

    local zombie = addZombie(x, y, z)
    if zombie then
        local modData = zombie:getModData()
        modData.forceMadScientist = true
        MadScientist.OnZombieCreate(zombie)
        player:Say("[Debug] Spawned Mad Scientist Zombie at (" .. x .. ", " .. y .. ")!")
    end
end

--- Debug function to add Knox Virus Cure syringe directly to inventory
function MadScientist.GiveTestCure()
    local player = getPlayer()
    if not player then return end

    local inv = player:getInventory()
    if inv then
        inv:AddItem("MadScientist.KnoxVirusCure")
        player:Say("[Debug] Added Knox Virus Cure to inventory!")
    end
end

