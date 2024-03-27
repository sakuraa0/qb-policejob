-- Variables
QBCore = exports['qb-core']:GetCoreObject()
isHandcuffed = false
cuffType = 1
isEscorted = false
PlayerJob = {}
local DutyBlips = {}

-- Functions
local function CreateDutyBlips(playerId, playerLabel, playerJob, playerLocation)
    local ped = GetPlayerPed(playerId)
    local blip = GetBlipFromEntity(ped)
    if not DoesBlipExist(blip) then
        if NetworkIsPlayerActive(playerId) then
            blip = AddBlipForEntity(ped)
        else
            blip = AddBlipForCoord(playerLocation.x, playerLocation.y, playerLocation.z)
        end
        SetBlipSprite(blip, 1)
        ShowHeadingIndicatorOnBlip(blip, true)
        SetBlipRotation(blip, math.ceil(playerLocation.w))
        SetBlipScale(blip, 1.0)
        if playerJob == 'police' then
            SetBlipColour(blip, 38)
        else
            SetBlipColour(blip, 5)
        end
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(playerLabel)
        EndTextCommandSetBlipName(blip)
        DutyBlips[#DutyBlips + 1] = blip
    end

    if GetBlipFromEntity(PlayerPedId()) == blip then
        -- Ensure we remove our own blip.
        RemoveBlip(blip)
    end
end

-- Events

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        local player = QBCore.Functions.GetPlayerData()
        PlayerJob = player.job
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local player = QBCore.Functions.GetPlayerData()
    PlayerJob = player.job
    isHandcuffed = false
    TriggerServerEvent('police:server:SetHandcuffStatus', false)
    TriggerServerEvent('police:server:UpdateBlips')
    TriggerServerEvent('police:server:UpdateCurrentCops')

    if player.metadata.tracker then
        local trackerClothingData = {
            outfitData = {
                ['accessory'] = {
                    item = 13,
                    texture = 0
                }
            }
        }
        TriggerEvent('qb-clothing:client:loadOutfit', trackerClothingData)
    else
        local trackerClothingData = {
            outfitData = {
                ['accessory'] = {
                    item = -1,
                    texture = 0
                }
            }
        }
        TriggerEvent('qb-clothing:client:loadOutfit', trackerClothingData)
    end

    if PlayerJob and PlayerJob.type ~= 'leo' then
        if DutyBlips then
            for _, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerServerEvent('police:server:UpdateBlips')
    TriggerServerEvent('police:server:SetHandcuffStatus', false)
    TriggerServerEvent('police:server:UpdateCurrentCops')
    isHandcuffed = false
    isEscorted = false
    PlayerJob = {}
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    if DutyBlips then
        for _, v in pairs(DutyBlips) do
            RemoveBlip(v)
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(newDuty)
    PlayerJob.onduty = newDuty
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    if JobInfo.type ~= 'leo' then
        if DutyBlips then
            for _, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
    end
    PlayerJob = JobInfo
    TriggerServerEvent('police:server:UpdateBlips')
end)

RegisterNetEvent('police:client:sendBillingMail', function(amount)
    SetTimeout(math.random(2500, 4000), function()
        local gender = Lang:t('info.mr')
        if QBCore.Functions.GetPlayerData().charinfo.gender == 1 then
            gender = Lang:t('info.mrs')
        end
        local charinfo = QBCore.Functions.GetPlayerData().charinfo
        TriggerServerEvent('qb-phone:server:sendNewMail', {
            sender = Lang:t('email.sender'),
            subject = Lang:t('email.subject'),
            message = Lang:t('email.message', { value = gender, value2 = charinfo.lastname, value3 = amount }),
            button = {}
        })
    end)
end)

RegisterNetEvent('police:client:UpdateBlips', function(players)
    if PlayerJob and (PlayerJob.type == 'leo' or PlayerJob.type == 'ems') and
            PlayerJob.onduty then
        if DutyBlips then
            for _, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
        if players then
            for _, data in pairs(players) do
                local id = GetPlayerFromServerId(data.source)
                CreateDutyBlips(id, data.label, data.job, data.location)
            end
        end
    end
end)

RegisterNetEvent('police:client:policeAlert', function(coords, text)
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street1name = GetStreetNameFromHashKey(street1)
    local street2name = GetStreetNameFromHashKey(street2)
    QBCore.Functions.Notify({ text = text, caption = street1name .. ' ' .. street2name }, 'police')
    PlaySound(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', 0, 0, 1)
    local transG = 250
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blip2 = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blipText = Lang:t('info.blip_text', { value = text })
    SetBlipSprite(blip, 60)
    SetBlipSprite(blip2, 161)
    SetBlipColour(blip, 1)
    SetBlipColour(blip2, 1)
    SetBlipDisplay(blip, 4)
    SetBlipDisplay(blip2, 8)
    SetBlipAlpha(blip, transG)
    SetBlipAlpha(blip2, transG)
    SetBlipScale(blip, 0.8)
    SetBlipScale(blip2, 2.0)
    SetBlipAsShortRange(blip, false)
    SetBlipAsShortRange(blip2, false)
    PulseBlip(blip2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(blipText)
    EndTextCommandSetBlipName(blip)
    while transG ~= 0 do
        Wait(180 * 4)
        transG = transG - 1
        SetBlipAlpha(blip, transG)
        SetBlipAlpha(blip2, transG)
        if transG == 0 then
            RemoveBlip(blip)
            return
        end
    end
end)

RegisterNetEvent('police:client:SendToJail', function(time)
    TriggerServerEvent('police:server:SetHandcuffStatus', false)
    isHandcuffed = false
    isEscorted = false
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    TriggerEvent('prison:client:Enter', time)
end)

RegisterNetEvent('police:client:SendPoliceEmergencyAlert', function()
    local Player = QBCore.Functions.GetPlayerData()
    TriggerServerEvent('police:server:policeAlert', Lang:t('info.officer_down', { lastname = Player.charinfo.lastname, callsign = Player.metadata.callsign }))
    TriggerServerEvent('hospital:server:ambulanceAlert', Lang:t('info.officer_down', { lastname = Player.charinfo.lastname, callsign = Player.metadata.callsign }))
end)

--Added

RegisterNetEvent('police:client:openmenu')
AddEventHandler('police:client:openmenu', function()
    if PlayerJob.type == 'leo' and PlayerJob.onduty then
        lib.showContext('police_menu')
    end
end)


lib.registerContext({
    id = 'police_menu',
    title = 'Police Menu',
    options = {
      {
        title = 'Send to Jail',
        description = 'jail player',
        onSelect = function()
            TriggerEvent('police:client:JailPlayer', source)
        end
      },
      {
        title = 'Release from Jail',
        description = 'remove player',
        onSelect = function()
            TriggerEvent('prison:client:UnjailPerson', source)
        end
      },
      {
        title = 'Clean Blood',
        description = 'Clean Blood',
        onSelect = function()
            TriggerEvent('evidence:client:ClearBlooddropsInArea', source)
        end
      },
      {
        title = 'Seize Money',
        description = 'Seize money',
        onSelect = function()
            TriggerEvent('police:client:SeizeCash', source)
        end
      },
      {
        title = 'Take License Driver',
        description = 'Take license',
        onSelect = function()
            TriggerEvent('police:client:SeizeDriverLicense', source)
        end
      },
      {
        title = 'Objects',
        description = 'Objects Menu!',
        menu = 'object_menu',
        icon = 'bars'
      },
      {
        title = 'Police Secondary Menu',
        description = 'Menu!',
        menu = 'police_menu2',
        icon = 'bars'
      },
      {
        title = 'Police Payments',
        description = 'payments!',
        menu = 'payments_menu',
        icon = 'bars'
      },
    }
})

lib.registerContext({
    id = 'police_menu2',
    title = 'Police Menu',
    options = {
        {
            title = 'Activate Cameras',
            description = 'Activate cameras',
            onSelect = function()
               local input = lib.inputDialog('Activate Cameras', {'Enter Camera ID'})
               if not input then return end
               local cameraId = tonumber(input[1])
               if cameraId then
                   TriggerEvent('police:client:ActiveCamera', cameraId)
               else
                   -- Handle invalid input
                   --print('Invalid camera ID')
               end
            end
        },
        {
            title = 'Flag Plate',
            description = 'Flag or unflag vehicle plate',
            onSelect = function()
                local input = lib.inputDialog('Flag Plate', {'Enter Plate Number', 'Enter Reason (Optional)', 'Remove Flag (Optional)'})
                if not input then return end

                local plate = input[1]:upper()
                local reason = input[2] or 'No reason provided'
                local removeFlag = input[3] and input[3]:lower() == 'remove'

                if removeFlag then
                    TriggerServerEvent('police:server:flagPlate', plate, reason, true)
                else
                    TriggerServerEvent('police:server:flagPlate', plate, reason, false)
                end
            end
        },
        {
            title = 'Depot',
            description = 'Impound a vehicle for a specified price',
            onSelect = function()
                local input = lib.inputDialog('Depot', {'Enter Impound Price'})
                if not input then return end

                local price = tonumber(input[1])
                if not price then
                    print('Invalid price')
                    return
                end

                TriggerServerEvent('police:server:ImpoundVehicle', false, price)
            end
        },
        {
            title = 'Impound',
            description = 'Impound the nearest vehicle',
            onSelect = function()
                TriggerServerEvent('police:server:ImpoundVehicle', true)
            end
        },
        {
            title = 'Plate Info',
            description = 'Get information about a vehicle plate',
            onSelect = function()
                local input = lib.inputDialog('Plate Info', {'Enter Plate Number'})
                if not input then return end
                
                local plate = input[1]:upper()
                TriggerServerEvent('police:server:PlateInfo', plate)
            end
        },
        {
            title = 'Take DNA Sample',
            description = 'Take a DNA sample from a player',
            onSelect = function()
                local input = lib.inputDialog('Take DNA Sample', {'Enter Player ID'})
                if not input then return end
                
                local playerId = tonumber(input[1])
                if not playerId then
                    print('Invalid player ID')
                    return
                end

                TriggerServerEvent('police:server:TakeDNA', playerId)
            end
        },
        {
            title = 'Back',
            description = 'Return to previous menu',
            onSelect = function()
                lib.showContext('police_menu')
            end
        },
    }
})

lib.registerContext({
    id = 'payments_menu',
    title = 'Payments Menu',
    options = {
        {
            title = 'Pay Tow Driver',
            description = 'Pay a tow driver for their services',
            onSelect = function()
                local input = lib.inputDialog('Pay Tow Driver', {'Enter Player ID'})
                if not input then return end

                local playerId = tonumber(input[1])
                if not playerId then
                    print('Invalid player ID')
                    return
                end

                TriggerServerEvent('police:server:PayTow', playerId)
            end
        },
        {
            title = 'Pay Lawyer',
            description = 'Pay a lawyer for their services',
            onSelect = function()
                local input = lib.inputDialog('Pay Lawyer', {'Enter Player ID'})
                if not input then return end

                local playerId = tonumber(input[1])
                if not playerId then
                    print('Invalid player ID')
                    return
                end

                TriggerServerEvent('police:server:PayLawyer', playerId)
            end
        },
        {
            title = 'Issue Fine',
            description = 'Issue a fine to a citizen',
            onSelect = function()
                local input = lib.inputDialog('Issue Fine', {'Enter Player ID', 'Enter Amount'})
                if not input then return end

                local playerId = tonumber(input[1])
                local amount = tonumber(input[2])
                if not playerId or not amount then
                    print('Invalid player ID or amount')
                    return
                end

                TriggerServerEvent('police:server:IssueFine', playerId, amount)
            end
        },
        {
            title = 'Back',
            description = 'Return to previous menu',
            onSelect = function()
                lib.showContext('police_menu')
            end
        },
    }
})

lib.registerContext({
    id = 'object_menu',
    title = 'Object Menu',
    options = {
      {
        title = 'Cone',
        description = 'Spawn Cone',
        onSelect = function()
            TriggerEvent('police:client:spawnCone', source)
        end
      },
      {
        title = 'Barrier',
        description = 'Spawn Barrier',
        onSelect = function()
            TriggerEvent('police:client:spawnBarrier', source)
        end
      },
      {
        title = 'Road Sign',
        description = 'Spawn Road Sign',
        onSelect = function()
            TriggerEvent('police:client:spawnRoadSign', source)
        end
      },
      {
        title = 'Tent',
        description = 'Spawn Tent',
        onSelect = function()
            TriggerEvent('police:client:spawnTent', source)
        end
      },
      {
        title = 'Light',
        description = 'Spawn Light',
        onSelect = function()
            TriggerEvent('police:client:spawnLight', source)
        end
      },
      {
        title = 'Delete Object',
        description = 'Delete Object',
        onSelect = function()
            TriggerEvent('police:client:deleteObject', source)
        end
      },
      {
        title = 'Spikes',
        description = 'Spawn Spike Strip',
        onSelect = function()
            TriggerEvent('police:client:SpawnSpikeStrip', source)
        end
      },
      {
        title = 'Back',
        description = 'Return to previous menu',
        onSelect = function()
            lib.showContext('police_menu')
        end
    },
    }
})



-- Threads
CreateThread(function()
    for _, station in pairs(Config.Locations['stations']) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 60)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 29)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(station.label)
        EndTextCommandSetBlipName(blip)
    end
end)

--Added

lib.addKeybind({
    name = "policemenu",
    description = "Police Menu",
    defaultKey = "F6",
    onPressed = function(self)
        TriggerEvent('police:client:openmenu')
    end,
})

if Config.targetuseall then

    local bones = {
        "seat_dside_f",
        "seat_pside_f",
        "seat_dside_r",
        "seat_pside_r",
        "door_dside_f",
        "door_dside_r",
        "door_pside_f",
        "door_pside_r",
      }
      
      exports['qb-target']:AddTargetBone(bones, {
        options = {
          {
            type = "client",
            event = 'police:client:PutPlayerInVehicle',
            icon = "fas fa-user-plus",
            label = "Sentar Pessoa no carro",
            job = {["police"] = 0, ["sasp"] = 0, ["saspr"] = 0, ["bcso"] = 0},
          },
          {
            type = "client",
            event = "police:client:SetPlayerOutVehicle",
            icon = "fas fa-user-minus",
            label = "Tirar do carro",
            job = {["police"] = 0, ["sasp"] = 0, ["saspr"] = 0, ["bcso"] = 0},
          },
          {
            type = "client",
            event = "police:client:ImpoundVehicle",
            icon = "fas fa-car",
            label = "Apreender Veiculo",
            job = {["police"] = 0, ["sasp"] = 0, ["saspr"] = 0, ["bcso"] = 0},
          },
          {
            type = "client",
            event = "police:client:EscortPlayer",
            icon = "fas fa-car",
            label = "Escoltar Player",
            job = {["police"] = 0, ["sasp"] = 0, ["saspr"] = 0, ["bcso"] = 0},
          },
          {
            type = "client",
            event = "police:client:CuffPlayer",
            icon = "fas fa-car",
            label = "Algemar Jogador",
            job = {["police"] = 0, ["sasp"] = 0, ["saspr"] = 0, ["bcso"] = 0},
          },
          {
            type = "client",
            event = "police:client:SeizeDriverLicense",
            icon = "fas fa-car",
            label = "Retirar Carta",
            job = {["police"] = 0, ["sasp"] = 0, ["saspr"] = 0, ["bcso"] = 0},
          },
          {
            type = "client",
            event = "qb-trunk:client:GetIn",
            icon = "fas fa-user-secret",
            label = "Entrar no porta malas",
          },
          {
            type = "client",
            event = "sk-garage:client:ParkVehicle",
            label = 'Guardar Carro',
            icon = 'fas fa-chevron-circle-up',
          },
        },
        distance = 3.0,
      })
      
end