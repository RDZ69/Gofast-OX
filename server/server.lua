ESX = exports["es_extended"]:getSharedObject()

local lastRobberyTime = 0  -- Variable pour enregistrer le moment du dernier braquage
local robberyCooldown = Config.delai -- Délai entre les braquages en millisecondes (1 minute = 60 secondes = 60000 millisecondes)

RegisterServerEvent('RDZ:GofastStart')
AddEventHandler('RDZ:GofastStart', function()
    local xPlayer = ESX.GetPlayerFromId(source)  -- Récupérer l'instance du joueur
    local vehicleModel = Config.VehicleModel  -- Modèle du véhicule Faggio
    local spawnCoords = Config.SpawnCoords  -- Coordonnées où le véhicule apparaîtra
    local _source = source

    -- Vérification du nombre minimum de joueurs du job de police en ligne
    local policePlayers = 0
    for _, player in ipairs(GetPlayers()) do
        local playerXPlayer = ESX.GetPlayerFromId(player)
        if playerXPlayer.job.name == 'police' then
            policePlayers = policePlayers + 1
        end
    end

    if policePlayers < Config.MinPoliceOnline then
        xPlayer.showNotification("Il doit y avoir au moins " .. Config.MinPoliceOnline .. " policiers en ligne pour lancer le braquage.")
        return
    end

    -- Vérifier si le délai nécessaire entre les braquages est écoulé
    local currentTime = os.time()  -- Récupérer l'heure actuelle
    local timeSinceLastRobbery = (currentTime * 1000) - lastRobberyTime  -- Calculer le temps écoulé depuis le dernier braquage en millisecondes
    local timeRemaining = robberyCooldown - timeSinceLastRobbery  -- Calculer le temps restant avant le prochain braquage

    if timeSinceLastRobbery >= robberyCooldown then  -- Si le délai entre les braquages est écoulé
        -- Assurez-vous d'importer correctement la fonction de spawn de véhicule depuis une ressource tiers
        TriggerClientEvent('RDZ:SpawnVehicle', xPlayer.source, vehicleModel, spawnCoords)

        -- Notification pour informer le joueur qu'il a 5 minutes pour rendre le vehicule sinon fin du Gofast
        xPlayer.showNotification("Voici votre véhicule à livrer")

        -- Émettre un événement pour mettre à jour le GPS côté client
        TriggerClientEvent('RDZ:GPS', _source)

        -- Notification pour la LSPD
        TriggerClientEvent('RDZ:LSPDnotif', _source)

        -- Marker pour obtenir la récompense
        TriggerClientEvent('RDZ:MarkerFinish', _source)

        -- Mettre à jour le temps du dernier braquage
        lastRobberyTime = currentTime * 1000
    else
        -- Si le joueur doit attendre, envoyer une notification avec le temps restant
        xPlayer.showNotification("Veuillez attendre " .. (timeRemaining / 60000) .. " minutes avant de pouvoir effectuer un nouveau braquage.")
    end
end)

local playerReceivedReward = {}

-- Fonction pour réinitialiser la variable playerReceivedReward
local function ResetPlayerReceivedReward()
    playerReceivedReward = {}
end

-- Boucle pour réinitialiser la variable toutes les minutes
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.delai)  -- Attendre 1 minute
        ResetPlayerReceivedReward()
    end
end)

RegisterServerEvent('RDZ:CheckVehicule')
AddEventHandler('RDZ:CheckVehicule', function()
    local _src = source 
    local xPlayer = ESX.GetPlayerFromId(_src)

    -- Vérifier si le joueur a déjà reçu la récompense pour ce GoFast
    if not playerReceivedReward[_src] then
        -- Récupérer le véhicule dans lequel le joueur est
        local vehicle = GetVehiclePedIsIn(GetPlayerPed(_src), false)

        -- Vérifier si le véhicule est le bon véhicule
        if vehicle and GetEntityModel(vehicle) == GetHashKey(Config.VehicleModel) then
            local rewardType = Config.Reward.Type
            local minReward = Config.Reward.Min
            local maxReward = Config.Reward.Max
            local randomReward = math.random(minReward, maxReward)

            if rewardType == "black_money" then
                xPlayer.addAccountMoney('black_money', randomReward)
                TriggerClientEvent('esx:showNotification', _src, 'Vous avez reçu ' .. randomReward .. ' $ en argent sale.')
            elseif rewardType == "money" then
                xPlayer.addMoney(randomReward)
                TriggerClientEvent('esx:showNotification', _src, 'Vous avez reçu ' .. randomReward .. ' $.')
            end

            -- Définir la variable pour indiquer que le joueur a reçu la récompense
            playerReceivedReward[_src] = true

            -- Déclencher l'événement côté client pour despawn le véhicule
            TriggerClientEvent('RDZ:DespawnVehicle', -1, vehicle)

            -- Déclencher l'événement côté client pour enlever le blip
            TriggerClientEvent('RDZ:RemoveGPS', -1)

            -- Envoyer les détails du GoFast au webhook Discord
            sendGoFastDetails(_src, GetPlayerName(_src), randomReward, rewardType)
        end
    else
        TriggerClientEvent('esx:showNotification', _src, 'Vous avez déjà récupéré votre récompense pour ce GoFast.')
    end
end)


function sendGoFastDetails(playerId, playerName, rewardAmount, rewardType)
    local currentTime = os.date("%Y-%m-%d %H:%M:%S", os.time()) -- Obtenir l'heure locale actuelle
    local data = {
        content = "GoFast :",
        embeds = {{
            description = string.format("**Joueur :** %s (%s)\n**Montant gagné :** %s $%d\n**Type de récompense :** %s\n**Heure :** %s\n**ID :** %d", playerName, playerId, (rewardType == "black_money" and "Argent sale" or "Argent propre"), rewardAmount, rewardType, currentTime, playerId),
            color = 3447003, -- Rouge
            footer = {
                text = "Script par RDZ"
            }
        }}
    }

    PerformHttpRequest(Config.WebhookURL, function(err, text, headers) end, 'POST', json.encode(data), { ['Content-Type'] = 'application/json' })
end