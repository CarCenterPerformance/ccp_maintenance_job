ESX = exports["es_extended"]:getSharedObject()

RegisterNetEvent('stadtwerke:giveReward', function(amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    xPlayer.addMoney(amount)
end)
