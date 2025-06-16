local ESX = exports["es_extended"]:getSharedObject()
local originalSkin = nil
local onDuty = false
local jobStarted = false
local currentRound = 1
local activePoints = {}
local currentRepairBlips = {}

local clothingSlots = {
    tshirt_1 = nil,
    tshirt_2 = nil,
    torso_1 = nil,
    torso_2 = nil,
    arms = nil,
    pants_1 = nil,
    pants_2 = nil,
    shoes_1 = nil,
    shoes_2 = nil
}

-- NPC Setup
Citizen.CreateThread(function()
    RequestModel(Config.NPC.ped)
    while not HasModelLoaded(Config.NPC.ped) do
        Citizen.Wait(10)
    end
    local npc = CreatePed(4, Config.NPC.ped, Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z - 1.0, Config.NPC.heading, false, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    FreezeEntityPosition(npc, true)
end)

-- Marker & Interaktion
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist = #(coords - Config.NPC.coords)

        if dist < 2.0 then
            DrawText3D(Config.NPC.coords, "[E] Stadtwerke Job")

            if IsControlJustReleased(0, 38) then -- E
                if not jobStarted then
                    openStartMenu()
                else
                    openJobMenu()
                end
            end
        else
            Citizen.Wait(500)
        end
    end
end)

-- ox_lib Menü für Jobstart
function openStartMenu()
    lib.registerContext({
        id = 'job_start_menu',
        title = 'Stadtwerke Job',
        options = {
            {
                title = 'Job annehmen',
                icon = 'check',
                onSelect = function()
                    startJob()
                end,
            }
        }
    })
    lib.showContext('job_start_menu')
end

-- ox_lib Menü während Job
function openJobMenu()
    if #activePoints > 0 then
        -- Punkte offen: Nur Abbrechen
        lib.registerContext({
            id = 'job_active_menu',
            title = 'Job läuft',
            options = {
                {
                    title = 'Job abbrechen',
                    icon = 'times',
                    onSelect = function()
                        endJob(true)
                    end,
                }
            }
        })
        lib.showContext('job_active_menu')
    else
        -- Punkte erledigt: Weitermachen oder Geld erhalten
        lib.registerContext({
            id = 'job_finish_menu',
            title = 'Aufgabe erledigt',
            options = {
                {
                    title = 'Weitermachen',
                    icon = 'repeat',
                    onSelect = function()
                        currentRound = currentRound + 1
                        spawnRepairBlips()
                        lib.notify({title = 'Job', description = 'Neue Reparaturpunkte sind gesetzt.', type = 'inform'})
                    end,
                },
                {
                    title = 'Geld erhalten',
                    icon = 'money-bill-wave',
                    onSelect = function()
                        endJob(false)
                    end,
                }
            }
        })
        lib.showContext('job_finish_menu')
    end
end

-- Job starten: Kleidung speichern + WorkClothes anziehen + Blips setzen
function startJob()
    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        originalSkin = skin
        onDuty = true
        jobStarted = true
        currentRound = 1
        activePoints = {}

        applyWorkClothes(skin)
        spawnRepairBlips()
        lib.notify({title = 'Stadtwerke', description = 'Fahre zu den Reparaturpunkten!', type = 'inform'})
    end)
end

function applyWorkClothes(skin)
    local sex = skin.sex or 0
    local clothes = sex == 0 and Config.WorkClothes.male or Config.WorkClothes.female

    for k, slot in pairs(clothingSlots) do
        local drawable = clothes[k] or 0
        local textureKey = k .. "_1"
        local texture = clothes[textureKey] or 0

        local maxDrawable = GetNumberOfPedDrawableVariations(PlayerPedId(), slot) - 1
        if drawable > maxDrawable or drawable < 0 then drawable = 0 end

        local maxTexture = GetNumberOfPedTextureVariations(PlayerPedId(), slot, drawable) - 1
        if texture > maxTexture or texture < 0 then texture = 0 end

        skin[k] = drawable
        skin[textureKey] = texture
    end

    TriggerEvent('skinchanger:loadClothes', skin, clothes)
end

-- Blips erzeugen
function spawnRepairBlips()
    removeRepairBlips()
    activePoints = {}

    for i, point in ipairs(Config.RepairPoints) do
        table.insert(activePoints, point)
        local blip = AddBlipForCoord(point.x, point.y, point.z)
        SetBlipSprite(blip, 402)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.7)
        SetBlipColour(blip, 3)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Reparaturpunkt")
        EndTextCommandSetBlipName(blip)
        table.insert(currentRepairBlips, blip)
    end
end

function removeRepairBlips()
    for _, blip in pairs(currentRepairBlips) do
        RemoveBlip(blip)
    end
    currentRepairBlips = {}
end

-- Reparatur-Interaktion
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5)
        if onDuty and jobStarted and #activePoints > 0 then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            for i = #activePoints, 1, -1 do
                local point = activePoints[i]
                local dist = #(coords - point)
                if dist < 2.0 then
                    DrawText3D(point, "[E] Reparieren")
                    if IsControlJustReleased(0, 38) then
                        repairAtPoint(i)
                    end
                end
            end
        else
            Citizen.Wait(1000)
        end
    end
end)

function repairAtPoint(index)
    local ped = PlayerPedId()
    local anim = Config.Animation

    RequestAnimDict(anim.lib)
    while not HasAnimDictLoaded(anim.lib) do Citizen.Wait(0) end

    TaskPlayAnim(ped, anim.lib, anim.anim, 8.0, -8.0, 5000, 0, 0, false, false, false)
    lib.notify({title = 'Job', description = 'Reparatur läuft...', type = 'inform'})

    Citizen.SetTimeout(5000, function()
        ClearPedTasks(ped)
        table.remove(activePoints, index)
        RemoveBlip(currentRepairBlips[index])
        table.remove(currentRepairBlips, index)

        lib.notify({title = 'Job', description = 'Reparatur abgeschlossen!', type = 'success'})

        if #activePoints == 0 then
            lib.notify({title = 'Job', description = 'Alle Punkte erledigt! Zurück zum NPC.', type = 'success'})
        end
    end)
end

-- 3D Text Funktion
function DrawText3D(coords, text)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z + 0.5)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 120)
    end
end

-- Job beenden, Kleidung zurückgeben, Blips löschen
function endJob(aborted)
    onDuty = false
    jobStarted = false
    removeRepairBlips()
    activePoints = {}

    if originalSkin ~= nil then
        TriggerEvent('skinchanger:loadSkin', originalSkin)
        Citizen.Wait(500)
        TriggerEvent('skinchanger:loadSkin', originalSkin)
        originalSkin = nil
    end

    if aborted then
        lib.notify({title = 'Job', description = 'Job abgebrochen. Kein Geld erhalten.', type = 'error'})
    else
        local payout = Config.BasePayment * currentRound
        TriggerServerEvent('ccp_maintenance:pay', payout)
        lib.notify({title = 'Job', description = 'Du hast $'..payout..' erhalten.', type = 'success'})
    end

    currentRound = 1
end
