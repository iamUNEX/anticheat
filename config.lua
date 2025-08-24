Config = {}

-- Discord Webhook for logging
Config.DiscordWebhook = 'https://discord.com/api/webhooks/1328467947378708613/H2wdOH1LX5LN4uNDDOg3jm2KcRqSbLoQYabLSjKTjrKlObn_LkoWjR8Vq_MtVioZFdHq'

-- Ratenbegrenzung: Wie viele Events darf ein Spieler pro Sekunde maximal auslösen?
-- Ein normaler Spieler liegt weit unter 10. Cheat-Menüs spammen oft > 30.
Config.RateLimit = 2  -- Reduziert auf 2 pro Sekunde
Config.WarningThreshold = 2 -- Warnschwelle bei 2 Events pro Sekunde

-- Kühlzeit in Sekunden nach einem Kick
Config.KickCooldown = 300  -- 5 Minuten
-- Gnadenfrist nach Join (Sekunden)
Config.GracePeriod = 15

Config.DebugHeartbeat = true

-- Blacklist: Events, die ein Client NIEMALS auslösen sollte.
Config.BlacklistedEvents = {
    -- ESX
    'esx:giveaccountmoney',
    'esx:givemoney',
    'esx_vehicleshop:setVehicleOwned',
    'esx_billing:sendBill',
    'esx_addonaccount:addAccountMoney',
    'esx:spawnVehicle',
    'esx:spawnObject',
    'esx:giveWeapon',
    'esx:addWeapon',
    'esx:setJob',
    'esx:setJob2',
    'esx:setAccountMoney',
    -- QBCore
    'QBCore:Server:SetMoney',
    'QBCore:Server:SetJob',
    'QBCore:Server:AddItem',
    'QBCore:Server:RemoveItem',
    'QBCore:Server:AddMoney',
    -- Andere generische / gefährliche Events
    'TriggerServerEvent',
    'TriggerClientEvent',
    '__internal_ac_proxy_event',
    'adminmenu:allowAll',
    'esx_dmvschool:addLicense',
    'esx_skin:save',
    'esx_weapons:giveWeapon',
    'esx_moneywash:withdraw'
}

-- Sensible Events to monitor (rate-limit/log), but not auto-cancel
-- Add here common framework events that are legitimate but abusable when spam-triggered via cheats.
Config.SensitiveEvents = {
    -- ESX money/account/inventory
    'esx:giveInventoryItem',
    'esx:removeInventoryItem',
    'esx:addInventoryItem',
    'esx:addWeapon',
    'esx:removeWeapon',
    'esx:useItem',
    'esx:onPickup',
    'esx:playerDropped',
    'esx:server:giveVehicle',
    'esx_society:withdrawMoney',
    'esx_society:depositMoney',
    'esx_society:setJob',
    'esx_addoninventory:removeItem',
    'esx_addoninventory:addItem',
    'esx_addonaccount:addMoney',
    'esx_addonaccount:removeMoney',
    -- QBCore
    'QBCore:Server:AddItem',
    'QBCore:Server:RemoveItem',
    'QBCore:Server:AddMoney',
    'QBCore:Server:RemoveMoney',
    'QBCore:Command:SpawnVehicle',
    'QBCore:Server:SetJob',
    -- ox_inventory / ox_lib
    'ox_inventory:buyItem',
    'ox_inventory:sellItem',
    'ox_inventory:addItem',
    'ox_inventory:removeItem',
    -- admin/common dangerous
    'admin:revive',
    'admin:giveitem',
    'admin:setjob',
    'weaponshop:buyWeapon',
    'vehicleshop:buyVehicle',
}