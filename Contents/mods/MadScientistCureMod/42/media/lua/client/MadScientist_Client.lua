-- MadScientist_Client.lua
MadScientist = MadScientist or {}

--- Handler for using/injecting the Knox Virus Vaccine
function MadScientist.UseCure(player, item)
    if not player or not item then return end

    -- Play injection audio effect
    if player:getEmitter() then
        player:getEmitter():playSound("Inject")
    end

    -- Clear Knox Virus Infection
    local bodyDamage = player:getBodyDamage()
    if bodyDamage then
        bodyDamage:setInfected(false)
        bodyDamage:setInfectionLevel(0)
        bodyDamage:setInfectionTime(-1)
        bodyDamage:setInfectionMortalityDuration(-1)
        bodyDamage:setFoodSicknessLevel(0)
        bodyDamage:setPoisonLevel(0)

        -- Clear infection from individual body parts
        local bodyParts = bodyDamage:getBodyParts()
        if bodyParts then
            for i = 0, bodyParts:size() - 1 do
                local part = bodyParts:get(i)
                if part then
                    part:setInfectedWound(false)
                end
            end
        end
    end

    -- Visual feedback text above player
    if HaloTextHelper and HaloTextHelper.addTextWithColor then
        HaloTextHelper.addTextWithColor(player, "KNOX VIRUS CURED!", 0.1, 0.9, 0.2)
    end
    player:Say("The vaccine worked... The Knox Virus has been neutralized!")

    -- Consume the syringe item
    local inv = player:getInventory()
    if inv then
        inv:Remove(item)
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
