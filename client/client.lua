ESX = exports["es_extended"]:getSharedObject()

local ped = nil

Citizen.CreateThread(function()
    local pedModel = GetHashKey (Config.Ped)

    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Wait(1)
    end

    ped = CreatePed(4, pedModel, Config.PedSpawnCoords.x, Config.PedSpawnCoords.y, Config.PedSpawnCoords.z, Config.PedSpawnCoords.h, false, true)
    SetEntityHeading(ped, Config.PedSpawnCoords.h)
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CLIPBOARD", 0, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAbility(ped, 0)
    SetPedCanSwitchWeapon(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
end)

lib.registerContext({
  id = 'RDZ:Gofast',
  title = 'Gofast',
  options = {
    {
    title = 'Commencer le Gofast',
    icon = 'fa-solid fa-car',
    event = 'RDZ:StartGofast'
    },
  }
})

------------------------ ox target

exports.ox_target:addBoxZone({
  coords =  vec3(Config.Menu.x, Config.Menu.y, Config.Menu.z + 1),

  size = vec3(1, 1, 1),
  rotation = 45,
  debug = drawZones,
  options = {
      {
          name = 'box',
          event = 'RDZ:MenuGofast',
          icon = 'fa-regular fa-user',
          label = "Gofast - RDZ",
      }
  }
}) 


RegisterNetEvent('RDZ:MenuGofast')
AddEventHandler('RDZ:MenuGofast', function()
    lib.showContext('RDZ:Gofast')
end)

RegisterNetEvent('RDZ:StartGofast')
AddEventHandler('RDZ:StartGofast', function()
    TriggerServerEvent('RDZ:GofastStart')
end)

RegisterNetEvent('RDZ:SpawnVehicle')
AddEventHandler('RDZ:SpawnVehicle', function(vehicleModel, spawnCoords)
    local playerPed = PlayerPedId()
    local heading = Config.SpawnCoords.h

    -- Charger le modèle du véhicule
    ESX.Game.SpawnVehicle(vehicleModel, spawnCoords, heading, function(vehicle)
        -- Si le véhicule est créé avec succès
        SetVehicleOnGroundProperly(vehicle)
        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleNumberPlateText(vehicle, "LSS-RDZ")
        TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
    end)
end)

local gpsBlip = nil -- Variable globale pour stocker l'ID du blip GPS ajouté

RegisterNetEvent('RDZ:GPS')
AddEventHandler('RDZ:GPS', function()
    -- Supprimer le blip GPS précédent si nécessaire
    if gpsBlip ~= nil then
        RemoveBlip(gpsBlip)
    end

    -- Nouvelles coordonnées GPS
    local newGPSX14 = Config.GPS.x  -- Remplacez par les nouvelles coordonnées X
    local newGPSY14 = Config.GPS.y  -- Remplacez par les nouvelles coordonnées Y

    -- Ajouter un nouveau blip GPS avec les nouvelles coordonnées et la couleur rouge
    gpsBlip = AddBlipForCoord(newGPSX14, newGPSY14)
    SetBlipColour(gpsBlip, 1)  -- 1 pour la couleur rouge
    SetBlipRoute(gpsBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Destination | Gofast")
    EndTextCommandSetBlipName(gpsBlip)
end)

RegisterNetEvent('RDZ:RemoveGPS')
AddEventHandler('RDZ:RemoveGPS', function()
    -- Supprimer le blip GPS s'il existe
    if gpsBlip ~= nil then
        RemoveBlip(gpsBlip)
        gpsBlip = nil
    end

    -- Supprimer le waypoint s'il est actif
    if IsWaypointActive() then
        SetWaypointOff()
    end
end)

RegisterNetEvent('RDZ:MarkerFinish')
AddEventHandler('RDZ:MarkerFinish', function()
    local point = lib.points.new({
        coords = vector3(Config.MarkerCoords),  -- Coordonnées du point
        distance = 5,  -- Distance de détection du point
    })
    
    local marker = lib.marker.new({
        coords = vector3(Config.MarkerCoords),  -- Coordonnées du marqueur
        type = Config.TypeMarker,  -- Type de marqueur
        width = 0.50, -- Largeur du marker
        height = 0.50, -- Hauteur du marker
        color = { r = 0, g = 60, b = 255, a = 200 },
    })
    
    function point:nearby()
        marker:draw()
        
        if self.currentDistance < 1.0 then
            if not lib.isTextUIOpen() then
                lib.showTextUI("Appuyez sur E pour rendre le vehicule")
            end
            
            if IsControlJustPressed(0, 51) then  -- 51 correspond à la touche 'E'
                local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)  -- Récupère le véhicule dans lequel le joueur est
                local vehicleModel = GetEntityModel(vehicle)  -- Récupère le modèle du véhicule
                
                if vehicleModel == GetHashKey(Config.VehicleModel) then  -- Vérifie si le modèle du véhicule correspond au modèle spécifié dans la configuration
                    -- Code à exécuter lorsque le joueur appuie sur 'E' près du marqueur et est dans le bon véhicule
                    TriggerServerEvent('RDZ:CheckVehicule') -- Déclencher l'événement pour commencer le braquage Brinks
                else
                    lib.notify({ description = "Vous devez être dans le bon véhicule pour rendre le véhicule." })
                end
            end
        else
            if lib.isTextUIOpen() then
                lib.hideTextUI()
            end
        end
    end
end)

RegisterNetEvent('RDZ:DespawnVehicle')
AddEventHandler('RDZ:DespawnVehicle', function()
    local playerPed = GetPlayerPed(-1)
    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            Citizen.Wait(1000)  -- Attendre 1 seconde
            DeleteVehicle(vehicle)
        end
    end
end)

RegisterNetEvent('RDZ:LSPDnotif')
AddEventHandler('RDZ:LSPDnotif', function()
    local playerXPlayer = ESX.GetPlayerFromId(player)

    -- Vérifier si le joueur est un policier
    if playerXPlayer.job.name == 'police' == 'police' then
        PlaySoundFrontend(-1, "Start_Squelch", "CB_RADIO_SFX", 1)
        PlaySoundFrontend(-1, "OOB_Start", "GTAO_FM_Events_Soundset", 1)

        -- Afficher la notification avancée uniquement pour les policiers
        ESX.ShowAdvancedNotification('LSPD', 'Indic - LSPD', 'D\'après nos info un GoFast à commencé', 'CHAR_CALL911', 8)
    end
end)