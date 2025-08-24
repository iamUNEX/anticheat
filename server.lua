-- ##################################################################
-- # Anti-Cheat System - Server Side
-- ##################################################################

-- Check if a player is active and connected
local function isPlayerActive(playerId)
    return GetPlayerPing(playerId) ~= 0
end

-- Initialize player data tables
local playerData = {}
local playerSpawnTimes = {}
local playerPositions = {}

-- Detection cooldown system to prevent multiple detections
local detectionCooldowns = {}
local DETECTION_COOLDOWN = 5000  -- 5 seconds cooldown between detections

-- Load config
local Config = Config or {}

-- Function to check if player is in detection cooldown
local function isInDetectionCooldown(playerId)
    local currentTime = GetGameTimer()
    local lastDetection = detectionCooldowns[playerId] or 0
    return (currentTime - lastDetection) < DETECTION_COOLDOWN
end

-- Function to set detection cooldown
local function setDetectionCooldown(playerId)
    detectionCooldowns[playerId] = GetGameTimer()
end

-- ##################################################################
-- # Event Key System (Standard Anti-Cheat Protection) - FIXED VERSION
-- ##################################################################

-- Store valid event keys for each event
local validEventKeys = {}
local eventKeyTimestamps = {}

-- Generate a unique key for an event
local function generateEventKey()
    local timestamp = GetGameTimer()
    local random = math.random(100000, 999999)
    return string.format("ac_%d_%d", timestamp, random)
end

-- Register a new event key for a specific event
local function registerEventKey(eventName)
    if not validEventKeys[eventName] then
        validEventKeys[eventName] = {}
    end
    
    local key = generateEventKey()
    table.insert(validEventKeys[eventName], key)
    
    -- Clean up old keys (keep only last 5)
    if #validEventKeys[eventName] > 5 then
        table.remove(validEventKeys[eventName], 1)
    end
    
    if DEBUG then
        print(string.format('[ANTI-CHEAT] Generated key for event %s: %s', eventName, key))
    end
    
    return key
end

-- Check if an event key is valid
local function isValidEventKey(eventName, key)
    if not validEventKeys[eventName] then
        if DEBUG then
            print(string.format('[ANTI-CHEAT] No keys registered for event: %s', eventName))
        end
        return false
    end
    
    if not key or type(key) ~= 'string' then
        if DEBUG then
            print(string.format('[ANTI-CHEAT] Invalid key type for event %s: %s', eventName, type(key)))
        end
        return false
    end
    
    -- Check if key exists in valid keys
    for i, validKey in ipairs(validEventKeys[eventName]) do
        if validKey == key then
            if DEBUG then
                print(string.format('[ANTI-CHEAT] Valid key found and removed for event %s: %s', eventName, key))
            end
            -- Remove used key to prevent reuse
            table.remove(validEventKeys[eventName], i)
            return true
        end
    end
    
    if DEBUG then
        print(string.format('[ANTI-CHEAT] Invalid key for event %s: %s', eventName, key))
        print(string.format('[ANTI-CHEAT] Available keys for %s: %s', eventName, table.concat(validEventKeys[eventName], ', ')))
    end
    
    return false
end

-- Hook into RegisterNetEvent to automatically generate keys for EXTERNAL events only
local _RegisterNetEvent = RegisterNetEvent
RegisterNetEvent = function(eventName)
    if eventName then
        -- Only generate keys for events NOT registered by cc_t
        local currentResource = GetCurrentResourceName()
        if currentResource ~= 'cc_t' then
            registerEventKey(eventName)
            
            if DEBUG then
                print(string.format('[ANTI-CHEAT] Event %s registered by %s, key generated', eventName, currentResource))
            end
        else
            if DEBUG then
                print(string.format('[ANTI-CHEAT] Event %s registered by cc_t, NO key required', eventName))
            end
        end
    end
    return _RegisterNetEvent(eventName)
end

-- Global event interceptor that checks for valid keys - ONLY for external events
Citizen.CreateThread(function()
    -- Wait for other resources to register their events
    Citizen.Wait(5000)
    
    if DEBUG then
        print(string.format('[ANTI-CHEAT] Starting event key verification for %d events', #validEventKeys))
    end
    
    -- Intercept all registered events to check keys
    for eventName, _ in pairs(validEventKeys) do
        if DEBUG then
            print(string.format('[ANTI-CHEAT] Setting up key verification for: %s', eventName))
        end
        
        AddEventHandler(eventName, function(...)
            local src = source
            if src and src > 0 then
                local args = {...}
                local hasValidKey = false
                
                if DEBUG then
                    print(string.format('[ANTI-CHEAT] Event %s triggered by player %d, checking key...', eventName, src))
                end
                
                -- Check if any argument contains a valid key
                for i, arg in ipairs(args) do
                    if type(arg) == 'string' and isValidEventKey(eventName, arg) then
                        hasValidKey = true
                        if DEBUG then
                            print(string.format('[ANTI-CHEAT] Valid key found in argument %d for event %s', i, eventName))
                        end
                        break
                    end
                end
                
                if not hasValidKey then
                    if DEBUG then
                        print(string.format('[ANTI-CHEAT] NO VALID KEY FOUND for event %s from player %d - KICKING!', eventName, src))
                    end
                    
                    -- No valid key found - kick player
                    SafeKickPlayer(src, 'Anti-Cheat: Invalid Event Key', {
                        ['Event'] = eventName,
                        ['Reason'] = 'missing_or_invalid_key'
                    })
                    CancelEvent()
                    return
                else
                    if DEBUG then
                        print(string.format('[ANTI-CHEAT] Event %s from player %d passed key verification', eventName, src))
                    end
                end
            end
        end)
        
        if DEBUG then
            print(string.format('[ANTI-CHEAT] Key verification active for event: %s', eventName))
        end
    end
    
    if DEBUG then
        print(string.format('[ANTI-CHEAT] Event key system active for %d events', #validEventKeys))
    end
end)

-- Function to get current valid key for an event (for server-side use)
function GetEventKey(eventName)
    return registerEventKey(eventName)
end

-- Function to refresh event key (for server-side use)
function RefreshEventKey(eventName)
    if validEventKeys[eventName] then
        validEventKeys[eventName] = {}
    end
    return registerEventKey(eventName)
end

-- Function to manually add an event to key protection (for external use)
function AddEventToKeyProtection(eventName)
    if eventName and not validEventKeys[eventName] then
        registerEventKey(eventName)
        if DEBUG then
            print(string.format('[ANTI-CHEAT] Manually added event %s to key protection', eventName))
        end
    end
end

-- Function to remove an event from key protection (for external use)
function RemoveEventFromKeyProtection(eventName)
    if eventName and validEventKeys[eventName] then
        validEventKeys[eventName] = nil
        if DEBUG then
            print(string.format('[ANTI-CHEAT] Removed event %s from key protection', eventName))
        end
    end
end

-- Function to test the key system (for debugging)
function TestEventKeySystem()
    if DEBUG then
        print('[ANTI-CHEAT] Testing event key system...')
        print(string.format('[ANTI-CHEAT] Total events with keys: %d', #validEventKeys))
        for eventName, keys in pairs(validEventKeys) do
            print(string.format('[ANTI-CHEAT] Event: %s, Keys: %d', eventName, #keys))
        end
    end
end

-- Function to force refresh all event keys (for debugging)
function RefreshAllEventKeys()
    if DEBUG then
        print('[ANTI-CHEAT] Refreshing all event keys...')
    end
    for eventName, _ in pairs(validEventKeys) do
        RefreshEventKey(eventName)
    end
end

-- Old event wrapper system removed - Event Key System handles all protection

-- Event Key System is now the primary protection - no need for complex wrappers

-- Resource Origin Verification removed - Event Key System handles all protection

-- Event Rate Limiting removed - Event Key System handles all protection

-- ##################################################################
-- # ADDITIONAL SECURITY: Manual Event Protection
-- ##################################################################

-- You can manually add specific events to key protection if needed
-- Example: AddEventToKeyProtection('esx:giveInventoryItem')
-- Example: AddEventToKeyProtection('QBCore:Server:AddItem')

-- You can also test the system with: TestEventKeySystem()
-- And refresh all keys with: RefreshAllEventKeys()

-- Function to safely kick a player with screenshot
function SafeKickPlayer(playerId, reason, extraData)
    if not isPlayerActive(playerId) then return end
    
    -- Check if player is in detection cooldown
    if isInDetectionCooldown(playerId) then
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Skipping kick for player %d - in detection cooldown", playerId))
        end
        return
    end
    
    -- Set detection cooldown to prevent multiple kicks
    setDetectionCooldown(playerId)
    
    -- Get player identifiers
    local identifiers = GetPlayerIdentifiers(playerId)
    local steamHex = "Not Linked"
    local discordId = "Not Linked"
    local fivem = "Not Linked"
    
    for _, v in pairs(identifiers) do
        if string.find(v, "steam:") then
            steamHex = v
        elseif string.find(v, "discord:") then
            discordId = "<@" .. string.gsub(v, "discord:", "") .. ">"
        elseif string.find(v, "fivem:") then
            fivem = v
        end
    end
    
    -- Get player name and Steam name if available
    local playerName = GetPlayerName(playerId) or "Unknown"
    local steamName = GetPlayerName(playerId) or "Unknown"
    
    -- Prepare embed data
    local embedData = {
        {
            ["color"] = 16711680, -- Red color
            ["title"] = "🚨 Anti-Cheat Detection 🚨",
            ["fields"] = {
                {
                    ["name"] = "Player",
                    ["value"] = playerName,
                    ["inline"] = true
                },
                {
                    ["name"] = "Player ID",
                    ["value"] = tostring(playerId),
                    ["inline"] = true
                },
                {
                    ["name"] = "Steam Hex",
                    ["value"] = "`" .. tostring(steamHex) .. "`",
                    ["inline"] = false
                },
                {
                    ["name"] = "Discord",
                    ["value"] = discordId,
                    ["inline"] = true
                },
                {
                    ["name"] = "FiveM ID",
                    ["value"] = "`" .. tostring(fivem) .. "`",
                    ["inline"] = true
                },
                {
                    ["name"] = "Reason",
                    ["value"] = "```" .. tostring(reason) .. "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "Timestamp",
                    ["value"] = os.date("%Y-%m-%d %H:%M:%S"),
                    ["inline"] = true
                }
            },
            ["footer"] = {
                ["text"] = "Anti-Cheat System | " .. os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }
    
    -- Add extra data if provided (like distance for teleport/noclip)
    if extraData and type(extraData) == "table" then
        for k, v in pairs(extraData) do
            table.insert(embedData[1]["fields"], {
                ["name"] = k,
                ["value"] = tostring(v),
                ["inline"] = true
            })
        end
    end
    
    -- Send to Discord webhook
    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({
        username = 'Anti-Cheat',
        embeds = embedData,
        avatar_url = 'https://i.imgur.com/7NQ8cQn.png'
    }), { ['Content-Type'] = 'application/json' })
    
    -- Trigger screenshot event on client
    TriggerClientEvent('cc_anticheat:takeScreenshot', playerId, {
        reason = reason,
        playerName = playerName,
        steamHex = steamHex,
        discordId = discordId,
        extraData = extraData
    })
    
    -- Kick the player after a short delay to allow screenshot to be taken
    SetTimeout(1000, function()
        if isPlayerActive(playerId) then
            DropPlayer(playerId, reason)
        end
    end)
end

-- Event to process the screenshot from client
RegisterNetEvent('cc_anticheat:processScreenshot')
AddEventHandler('cc_anticheat:processScreenshot', function(imageUrl, reason, playerName, playerId, playerCoords)
    local _source = source
    
    -- Get player identifiers
    local identifiers = GetPlayerIdentifiers(_source)
    local steamHex = ""
    for _, identifier in ipairs(identifiers) do
        if string.find(identifier, 'steam:') then
            steamHex = identifier
            break
        end
    end
    
    -- Prepare the embed
    local embed = {
        {
            ["title"] = "Player Kicked by Anti-Cheat",
            ["description"] = string.format("**Player:** %s\n**ID:** %s\n**Steam Hex:** %s\n**Reason:** %s\n**Coordinates:** x=%.2f, y=%.2f, z=%.2f", 
                playerName, playerId, steamHex, reason, 
                playerCoords.x, playerCoords.y, playerCoords.z),
            ["color"] = 16711680, -- Red
            ["footer"] = {
                ["text"] = "Anti-Cheat System | " .. os.date("%Y-%m-%d %H:%M:%S")
            },
            ["image"] = {
                ["url"] = imageUrl
            }
        }
    }
    
    -- Send to Discord
    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) 
        if err ~= 200 then
            print('[ANTI-CHEAT] Failed to send screenshot to Discord: ' .. tostring(err))
        end
    end, 'POST', 
        json.encode({
            username = "Anti-Cheat System",
            embeds = embed,
            avatar_url = "https://i.imgur.com/example.png" -- Replace with your logo
        }), 
        { ['Content-Type'] = 'application/json' })
end)

-- ##################################################################
-- # Magic Bullet Detection & Prevention
-- ##################################################################

-- Track violations per attacker to escalate quickly
local magicBulletViolations = {}
-- attackerId -> { [victimNetId] = { ts=number, los=bool, aim_ok=bool, count=number } }
local recentMagicEvidence = {}
local MAGIC_EVIDENCE_WINDOW = 1800      -- ms window to match evidence to damage
local MAGIC_VIOLATION_TIMEOUT = 15000   -- window to count repeats (ms)
local MAGIC_MAX_VIOLATIONS = 1          -- kick on first confirmed violation

-- Safe wrapper for server natives that might be unavailable
local function safeGetSelectedWeapon(ped)
    if type(GetSelectedPedWeapon) ~= 'function' then return 0 end
    local ok, weapon = pcall(GetSelectedPedWeapon, ped)
    if ok then return weapon or 0 end
    return 0
end

-- Robust multi-ray obstruction check (world-only mask) with multiple victim bones
local function isWorldBlockingBetween(attackerPed, victimEntity)
    if attackerPed == 0 or victimEntity == 0 then return false end
    local atkHead = GetPedBoneCoords(attackerPed, 0x796E, 0.0, 0.0, 0.0)
    local bones = { 0x796E, 0x60F1, 0x2E28 } -- head, spine3, pelvis
    local offsets = {
        { x = 0.0, y = 0.0, z = 0.0 },
        { x = 0.0, y = 0.05, z = 0.15 },
        { x = 0.0, y = -0.05, z = -0.15 }
    }

    local function getTargetCoords(entity, bone)
        if IsEntityAPed(entity) then
            return GetPedBoneCoords(entity, bone, 0.0, 0.0, 0.0)
        else
            local pos = GetEntityCoords(entity)
            return vector3(pos.x, pos.y, pos.z + 0.9)
        end
    end

    for _, bone in ipairs(bones) do
        local target = getTargetCoords(victimEntity, bone)
        for _, off in ipairs(offsets) do
            local toX, toY, toZ = target.x + off.x, target.y + off.y, target.z + off.z
            -- Use world-only mask (1) to detect map cover strictly
            local handle = StartShapeTestRay(
                atkHead.x, atkHead.y, atkHead.z,
                toX, toY, toZ,
                1, attackerPed, 7
            )
            local _, hit, _, _, entityHit = GetShapeTestResult(handle)
            if hit ~= 1 then
                return false
            end
            if entityHit == victimEntity then
                return false
            end
            if IsEntityAPed(victimEntity) then
                local veh = GetVehiclePedIsIn(victimEntity, false)
                if veh ~= 0 and entityHit == veh then
                    return false
                end
            end
        end
    end
    -- Every ray was obstructed by world/other entity → blocked
    return true
end

-- Server-side aim sanity using heading (2D)
local function isAimReasonable(attackerPed, victimEntity)
    if attackerPed == 0 or victimEntity == 0 then return true end
    local atk = GetEntityCoords(attackerPed)
    local vic = GetEntityCoords(victimEntity)
    local dx, dy = (vic.x - atk.x), (vic.y - atk.y)
    local dist2d = math.sqrt(dx * dx + dy * dy)
    if dist2d <= 8.0 then return true end
    local heading = GetEntityHeading(attackerPed) or 0.0
    local rad = math.rad(heading)
    local fwdX, fwdY = -math.sin(rad), math.cos(rad)
    if dist2d == 0 then return true end
    local dirX, dirY = dx / dist2d, dy / dist2d
    local dot2d = (fwdX * dirX) + (fwdY * dirY)
    return dot2d >= 0.25
end

-- Utility: ensure table and decay by time
local function getMagicData(attackerId)
    local now = GetGameTimer()
    local data = magicBulletViolations[attackerId]
    if not data or (now - (data.last or 0)) > MAGIC_VIOLATION_TIMEOUT then
        data = { count = 0, last = now }
        magicBulletViolations[attackerId] = data
    end
    data.last = now
    return data
end

-- Server receives client-side evidence when LOS was blocked
RegisterNetEvent('cc_t:magicBulletEvidence')
AddEventHandler('cc_t:magicBulletEvidence', function(attackerServerId, victimServerId, weaponHash, pos)
    local src = source
    -- Basic trust: only accept reports about own damage events, or from victim perspective
    if src ~= attackerServerId and src ~= victimServerId then return end

    -- Validate that both players exist
    if not isPlayerActive(attackerServerId) or not isPlayerActive(victimServerId) then return end

    local victimPed = GetPlayerPed(victimServerId)
    if victimPed == 0 then return end
    local victimNetId = NetworkGetNetworkIdFromEntity(victimPed)
    if not recentMagicEvidence[attackerServerId] then
        recentMagicEvidence[attackerServerId] = {}
    end
    local now = GetGameTimer()
    local entry = recentMagicEvidence[attackerServerId][victimNetId]
    if entry and (now - (entry.ts or 0)) <= MAGIC_EVIDENCE_WINDOW then
        entry.count = (entry.count or 1) + 1
        entry.ts = now
        entry.los = pos and pos.los or false
        entry.aim_ok = pos and pos.aim_ok or false
    else
        recentMagicEvidence[attackerServerId][victimNetId] = {
            ts = now,
            los = pos and pos.los or false,
            aim_ok = pos and pos.aim_ok or false,
            count = 1
        }
    end
end)

-- ##################################################################
-- # Weapon Spoof Detection (client evidence + server verification)
-- ##################################################################

-- Track recent spoof evidence per attacker->victim
local recentWeaponSpoof = {} -- attackerId -> { [victimId] = { ts=number, weapon=hash, is_shooting=bool, selected=hash, count=number } }
local WEAPON_SPOOF_WINDOW = 1500

RegisterNetEvent('cc_t:weaponSpoofEvidence')
AddEventHandler('cc_t:weaponSpoofEvidence', function(attackerId, victimId, weaponHash, payload)
    local src = source
    if src ~= attackerId and src ~= victimId then return end
    if not isPlayerActive(attackerId) or not isPlayerActive(victimId) then return end
    local now = GetGameTimer()
    recentWeaponSpoof[attackerId] = recentWeaponSpoof[attackerId] or {}
    local entry = recentWeaponSpoof[attackerId][victimId]
    if entry and (now - (entry.ts or 0)) <= WEAPON_SPOOF_WINDOW then
        entry.count = (entry.count or 1) + 1
        entry.ts = now
        entry.weapon = weaponHash
        entry.is_shooting = payload and payload.is_shooting or false
        entry.selected = payload and payload.selected_weapon or 0
    else
        recentWeaponSpoof[attackerId][victimId] = {
            ts = now,
            weapon = weaponHash,
            is_shooting = payload and payload.is_shooting or false,
            selected = payload and payload.selected_weapon or 0,
            count = 1
        }
    end
end)

-- Immediate weapon verification: kick on spoof without needing damage
RegisterNetEvent('cc_t:verifyWeapon')
AddEventHandler('cc_t:verifyWeapon', function(clientWeapon, payload)
    local src = source
    if not isPlayerActive(src) then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    -- If native IsPedArmed is unavailable in this environment, rely on weapon presence
    local armed = true
    if type(IsPedArmed) == 'function' then
        local ok, res = pcall(IsPedArmed, ped, 6)
        armed = ok and res or true
    end
    if not armed then return end

    local serverSelected = safeGetSelectedWeapon(ped)
    local aiming = payload and payload.aiming or false
    local shooting = payload and payload.shooting or false
    local ammo = payload and tonumber(payload.ammo or 0) or 0

    -- Debounced, persistence-based spoof detection to avoid false positives
    _cc_weaponVerify = _cc_weaponVerify or {}
    local s = _cc_weaponVerify[src]
    local now = GetGameTimer()
    if not s then
        s = {
            lastClient = 0,
            lastServer = 0,
            lastChange = 0,
            mismatchCount = 0,
            zeroServerCount = 0,
            lastMismatch = 0
        }
        _cc_weaponVerify[src] = s
    end

    if clientWeapon ~= s.lastClient then
        s.lastClient = clientWeapon
        s.lastChange = now
        s.mismatchCount = 0
        s.zeroServerCount = 0
    end
    s.lastServer = serverSelected

    local inGrace = (now - (s.lastChange or 0)) < 500 -- shorten grace to detect faster
    local mismatch = false
    if clientWeapon ~= 0 then
        if serverSelected ~= 0 and clientWeapon ~= serverSelected then
            mismatch = true
        end
    end

    if (now - (s.lastMismatch or 0)) > 1000 then
        s.mismatchCount = 0
        s.zeroServerCount = 0
    end

    if mismatch and not inGrace then
        s.mismatchCount = s.mismatchCount + 1
        s.lastMismatch = now
        local confirm = false
        -- Require sustained mismatch while shooting only
        if shooting and s.mismatchCount >= 2 then
            confirm = true
        end
        if confirm then
            SafeKickPlayer(src, 'Anti-Cheat: Weapon Spoof Detected', {
                ['ClientWeapon'] = tostring(clientWeapon),
                ['ServerWeapon'] = tostring(serverSelected),
                ['Mismatches'] = tostring(s.mismatchCount),
                ['Aiming'] = tostring(aiming),
                ['Shooting'] = tostring(shooting),
                ['Ammo'] = tostring(ammo)
            })
            return
        end
    end
end)

-- Prevent damage server-side based on recent client evidence
AddEventHandler('weaponDamageEvent', function(sender, data)
    local attackerId = sender
    if not isPlayerActive(attackerId) then return end
    if not data or not data.victimNetId then return end

    local victimEntity = NetworkGetEntityFromNetworkId(data.victimNetId)
    if victimEntity == 0 then return end

    local attackerPed = GetPlayerPed(attackerId)
    if attackerPed == 0 then return end

    -- First: strict server-side LOS check vs world (multi-ray)
    local blockedByWorld = isWorldBlockingBetween(attackerPed, victimEntity)

    -- Aim sanity (server-side)
    local aimOk = isAimReasonable(attackerPed, victimEntity)

    -- Second: if not blocked, also allow client evidence to strengthen decision
    local blockedByEvidence = false
    local evidenceForAttacker = recentMagicEvidence[attackerId]
    if evidenceForAttacker then
        local ev = evidenceForAttacker[data.victimNetId]
        if ev and (GetGameTimer() - (ev.ts or 0)) <= MAGIC_EVIDENCE_WINDOW then
            -- Require at least one recent report AND either LOS=false or aim_ok=false
            if (ev.los == false) or (ev.aim_ok == false) then
                blockedByEvidence = true
            end
            -- decay counter and clear to avoid double-use
            evidenceForAttacker[data.victimNetId] = nil
        end
    end

    local shouldBlock = false
    if blockedByWorld then
        shouldBlock = true
    elseif blockedByEvidence and (not aimOk) then
        -- Only trust client evidence when server also sees aim is unreasonable
        shouldBlock = true
    end

    -- Third: weapon spoof verification - client evidence and server-side weapon mismatch
    local spoofEvidence = false
    local victimOwner = 0
    local ok, owner = pcall(function() return NetworkGetEntityOwner(victimEntity) end)
    if ok and owner then victimOwner = owner end
    if recentWeaponSpoof[attackerId] then
        local spoofForVictim = victimOwner > 0 and recentWeaponSpoof[attackerId][victimOwner] or nil
        if spoofForVictim and (GetGameTimer() - (spoofForVictim.ts or 0)) <= WEAPON_SPOOF_WINDOW then
            if (not spoofForVictim.is_shooting) or (spoofForVictim.selected ~= data.weaponType) then
                spoofEvidence = true
            end
            recentWeaponSpoof[attackerId][victimOwner] = nil
        end
    end
    local serverMismatch = false
    local selected = safeGetSelectedWeapon(attackerPed)
    if selected ~= 0 and data.weaponType and (selected ~= data.weaponType) then
        serverMismatch = true
    end

    if shouldBlock or spoofEvidence or serverMismatch then
        data.damage = 0.0
        CancelEvent()
        local track = getMagicData(attackerId)
        track.count = track.count + 1
        if DEBUG then
            print(string.format('[ANTI-CHEAT] Damage blocked (%s%s%s) from %d -> victimNet %d (aimOk=%s, serverWeapon=%s, eventWeapon=%s)', 
                blockedByWorld and 'world' or (blockedByEvidence and 'evidence' or 'clean'),
                spoofEvidence and '+weaponSpoof' or '',
                serverMismatch and '+serverMismatch' or '',
                attackerId, data.victimNetId, tostring(aimOk), tostring(selected), tostring(data.weaponType)))
        end
        if track.count >= MAGIC_MAX_VIOLATIONS then
            local reason = 'Anti-Cheat: Magic Bullet Detected'
            if spoofEvidence or serverMismatch then
                reason = 'Anti-Cheat: Weapon Spoof Detected'
            end
            SafeKickPlayer(attackerId, reason, {
                ['VictimNetId'] = tostring(data.victimNetId),
                ['Weapon'] = tostring(data.weaponType)
            })
            magicBulletViolations[attackerId] = nil
        end
        return true
    end
end)

-- List of blocked object hashes (tuning props, tubes, etc.)
local BLOCKED_OBJECTS = {
    -- Tuning Props
    GetHashKey('imp_prop_impexp_rack_01'),
    GetHashKey('imp_prop_impexp_rack_02'),
    GetHashKey('imp_prop_impexp_rack_03'),
    GetHashKey('imp_prop_impexp_rack_04'),
    GetHashKey('imp_prop_impexp_rack_05'),
    GetHashKey('imp_prop_impexp_rack_06'),
    GetHashKey('imp_prop_impexp_rack_07'),
    GetHashKey('imp_prop_impexp_rack_08'),
    GetHashKey('imp_prop_impexp_rack_09'),
    GetHashKey('imp_prop_impexp_rack_10'),
    -- Tubes and other suspicious objects
    GetHashKey('prop_ld_ferris_wheel'),
    GetHashKey('prop_roller_car_01'),
    GetHashKey('prop_roller_car_02'),
    GetHashKey('p_cablecar_s'),
    GetHashKey('stt_prop_stunt_tube_l'),
    GetHashKey('stt_prop_stunt_tube_crn'),
    GetHashKey('stt_prop_stunt_tube_crn_5d'),
    GetHashKey('stt_prop_stunt_tube_m'),
    GetHashKey('stt_prop_stunt_tube_s'),
    GetHashKey('stt_prop_stunt_track_bumps'),
    GetHashKey('stt_prop_stunt_track_cutout'),
    GetHashKey('stt_prop_stunt_track_dwuturn'),
    GetHashKey('stt_prop_stunt_track_fork'),
    GetHashKey('stt_prop_stunt_track_funnel'),
    GetHashKey('stt_prop_stunt_track_hill'),
    GetHashKey('stt_prop_stunt_track_jump'),
    GetHashKey('stt_prop_stunt_track_otake'),
    GetHashKey('stt_prop_stunt_track_slope15'),
    GetHashKey('stt_prop_stunt_track_slope30'),
    GetHashKey('stt_prop_stunt_track_slope45'),
    GetHashKey('stt_prop_stunt_track_start'),
    GetHashKey('stt_prop_stunt_track_straight'),
    GetHashKey('stt_prop_stunt_track_straightice'),
    GetHashKey('stt_prop_stunt_track_turn'),
    GetHashKey('stt_prop_stunt_track_uturn'),
    -- Cages
    GetHashKey('prop_dog_cage_01'),
    GetHashKey('prop_dog_cage_02')
}

-- Convert to a set for faster lookups
local BLOCKED_OBJECTS_SET = {}
for _, hash in ipairs(BLOCKED_OBJECTS) do
    BLOCKED_OBJECTS_SET[hash] = true
end

-- Enhanced server-side prop checking
local function isRestrictedModel(model)
    return BLOCKED_OBJECTS_SET[model] or false
end

-- Function to safely delete an entity
local function safeDeleteEntity(entity)
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
        return true
    end
    return false
end

-- Function to check and delete restricted objects
local function cleanupRestrictedObjects()
    local objects = GetGamePool('CObject')
    local count = 0
    local deletedEntities = {}
    
    -- First pass: Collect all restricted objects and their owners
    for _, entity in ipairs(objects) do
        if DoesEntityExist(entity) then
            local model = GetEntityModel(entity)
            if model and isRestrictedModel(model) then
                local owner = NetworkGetEntityOwner(entity) or 0
                local netId = NetworkGetNetworkIdFromEntity(entity)
                
                if not deletedEntities[netId] then
                    -- Use model hash as name since GetEntityArchetypeName doesn't exist in server context
                    deletedEntities[netId] = {
                        entity = entity,
                        model = model,
                        owner = owner,
                        name = string.format('Model_%d', model), -- Use model hash as name
                        timestamp = GetGameTimer()
                    }
                    count = count + 1
                end
            end
        end
    end
    
    -- Second pass: Process collected entities
    for netId, data in pairs(deletedEntities) do
        if DoesEntityExist(data.entity) then
            -- Log the detection
            local ownerInfo = data.owner > 0 and 
                string.format('owned by %s (ID: %s)', 
                    GetPlayerName(data.owner) or 'Unknown', 
                    GetPlayerIdentifier(data.owner, 0) or 'Unknown') or 
                'no owner (server created)'
                
            print(string.format('[ANTI-CHEAT] Removing restricted object: %s (Model: %s) %s', 
                data.name, 
                data.model,
                ownerInfo))
            
            -- Kick the player if they own the object
            if data.owner > 0 then
                SafeKickPlayer(data.owner, 'Anti-Cheat System: Anti Object Spawn.')
            end
            
            -- Delete the entity
            safeDeleteEntity(data.entity)
        end
    end
    
    if count > 0 and DEBUG then
        print(string.format('[ANTI-CHEAT] Cleanup completed: %d restricted objects removed', count))
    end
    
    -- Return the count of deleted objects
    return count
end

-- Explosion detection system
local explosionTimestamps = {}
local vehicleExplosionCount = {}
local lastExplosionCleanup = 0
local MAX_EXPLOSIONS = 4             -- Maximum allowed explosions in time window
local EXPLOSION_TIME_WINDOW = 5000   -- 5 seconds time window

-- Handle explosion events
AddEventHandler('explosionEvent', function(sender, ev)
    local playerId = source
    if not playerId or playerId == 0 then return end
    
    local currentTime = GetGameTimer()
    
    -- Initialize explosion tracking for this player if not exists
    if not explosionTimestamps[playerId] then
        explosionTimestamps[playerId] = {}
        vehicleExplosionCount[playerId] = 0
    end
    
    -- Check if explosion is from a vehicle
    local ped = GetPlayerPed(playerId)
    if not ped or not DoesEntityExist(ped) then return end
    
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then  -- 0 means not in a vehicle
        -- Check if it's a vehicle explosion (type 3 is vehicle explosion)
        if ev.explosionType == 3 or ev.explosionType == 4 or ev.explosionType == 5 or 
           ev.explosionType == 25 or ev.explosionType == 32 or ev.explosionType == 33 then
            
            -- Add current explosion to tracking
            table.insert(explosionTimestamps[playerId], currentTime)
            vehicleExplosionCount[playerId] = vehicleExplosionCount[playerId] + 1
            
            -- Clean up old explosions (older than our time window)
            local validExplosions = {}
            for _, timestamp in ipairs(explosionTimestamps[playerId]) do
                if currentTime - timestamp <= EXPLOSION_TIME_WINDOW then
                    table.insert(validExplosions, timestamp)
                end
            end
            explosionTimestamps[playerId] = validExplosions
            
            -- Debug log
            if DEBUG then
                print(string.format("[ANTI-CHEAT] Vehicle explosion detected from player %d (Count: %d/%d)", 
                    playerId, #validExplosions, MAX_EXPLOSIONS))
            end
            
            -- Check if player has exceeded the explosion limit
            if #explosionTimestamps[playerId] >= MAX_EXPLOSIONS then
                -- Get player info for logging
                local playerName = GetPlayerName(playerId) or "Unknown"
                local identifiers = GetPlayerIdentifiers(playerId) or {}
                
                -- Log the violation
                print(string.format("[ANTI-CHEAT] Player %s (ID: %d) detected for explosion spam (Count: %d in %dms)", 
                    playerName, playerId, #explosionTimestamps[playerId], EXPLOSION_TIME_WINDOW))
                
                -- Kick the player
                DropPlayer(playerId, "Anti-Cheat: Vehicle explosion spam detected")
                
                -- Delete the vehicle
                if DoesEntityExist(vehicle) then
                    DeleteEntity(vehicle)
                end
                
                -- Reset their explosion count
                explosionTimestamps[playerId] = {}
                vehicleExplosionCount[playerId] = 0
            end
        end
    end
    
    -- Clean up old data periodically (every 30 seconds)
    if currentTime - lastExplosionCleanup > 30000 then
        for pid, timestamps in pairs(explosionTimestamps) do
            local valid = {}
            for _, ts in ipairs(timestamps) do
                if currentTime - ts <= EXPLOSION_TIME_WINDOW then
                    table.insert(valid, ts)
                end
            end
            explosionTimestamps[pid] = valid
            
            -- If no valid timestamps, remove the player's entry
            if #valid == 0 then
                explosionTimestamps[pid] = nil
                if vehicleExplosionCount[pid] then
                    vehicleExplosionCount[pid] = nil
                end
            end
        end
        lastExplosionCleanup = currentTime
    end
end)

-- Monitor object creation events
AddEventHandler('entityCreating', function(entity, cancel)
    if not DoesEntityExist(entity) then return end
    
    local entityType = GetEntityType(entity)
    if entityType ~= 3 then return end -- Only check objects (type 3)
    
    local model = GetEntityModel(entity)
    if not model then return end
    
    if BLOCKED_OBJECTS_SET[model] then
        -- Delete the entity instead of calling undefined cancel()
        DeleteEntity(entity)
        
        local owner = NetworkGetEntityOwner(entity)
        if owner and owner > 0 then
            local playerName = GetPlayerName(owner) or 'Unknown'
            local playerId = GetPlayerIdentifier(owner, 0) or 'Unknown'
            
            -- Log the blocked object with just the model number since we can't get the name server-side
            print(string.format('[ANTI-CHEAT] Blocked and deleted restricted object (Model: %s) by %s (ID: %s)', 
                model, 
                playerName,
                playerId))
            
            -- Kick the player
            DropPlayer(owner, 'Anti-Cheat System: Anti Object Spawn.')
        end
    end
end)

-- ##################################################################
-- # Movement Detection System
-- ##################################################################

-- Movement detection settings
local MAX_WALKING_SPEED = 8.0       -- Maximum normal walking speed (m/s)
local MAX_RUNNING_SPEED = 12.0      -- Maximum normal running speed (m/s)
local MAX_SPRINTING_SPEED = 20.0    -- Maximum normal sprinting speed (m/s) with some buffer
local MAX_VEHICLE_SPEED = 60.0      -- Maximum normal vehicle speed (m/s)
local MAX_FREE_FALL_SPEED = 80.0    -- Maximum free fall speed (m/s)

-- Detection thresholds
local SUSPICIOUS_SPEED = 50.0       -- Speed above which to check for teleport (m/s)
local TELEPORT_THRESHOLD = 15.0     -- Distance that triggers teleport check (meters)
local MAX_VERTICAL_MOVEMENT = 5.0   -- Maximum allowed vertical movement in one check
local CHECK_INTERVAL = 1000         -- Check interval in ms

-- Explosion detection
local MAX_EXPLOSIONS = 4            -- Maximum allowed explosions in time window
local EXPLOSION_TIME_WINDOW = 5000  -- Time window in ms to track explosions
local explosionTimestamps = {}      -- Track explosion timestamps per player
local vehicleExplosionCount = {}    -- Track explosion counts per player
local lastExplosionCleanup = 0      -- Last cleanup time
local SPAWN_PROTECTION_DURATION = 5000   -- 5 seconds of spawn protection (reduced from 10)
local MAX_VALID_DISTANCE = 1000.0   -- Reduced maximum valid distance (1000m)
local IGNORE_DISTANCE = 500.0       -- Increased ignore distance for map teleports
local TELEPORT_COOLDOWN = 1000      -- Reduced cooldown after teleport (ms)
local TELEPORT_SPEED_THRESHOLD = 100.0  -- Speed that's definitely a teleport (m/s)
local lastTeleportTime = {}         -- Track last teleport time per player

-- Calculate distance between two coordinates
local function getDistance(pos1, pos2)
    return #(vector3(pos1.x, pos1.y, pos1.z) - vector3(pos2.x, pos2.y, pos2.z))
end

-- Helper function to check for teleporting or noclip
local function checkMovement(playerId, newPos, oldPos)
    -- Check if we have valid position data with all required fields
    if not oldPos or type(oldPos) ~= 'table' or not oldPos.coords or type(oldPos.coords) ~= 'table' or
       not newPos or type(newPos) ~= 'table' or not newPos.coords or type(newPos.coords) ~= 'table' then
        return
    end
    
    -- Skip if the position data is invalid (0,0,0 or extremely large values)
    local function isValidPosition(pos)
        if not pos or not pos.coords then return false end
        local x, y, z = pos.coords.x or 0, pos.coords.y or 0, pos.coords.z or 0
        return math.abs(x) < 10000 and math.abs(y) < 10000 and math.abs(z) < 10000
    end
    
    if not isValidPosition(oldPos) or not isValidPosition(newPos) then
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Invalid position data for player %d - old: %s, new: %s", 
                playerId, json.encode(oldPos), json.encode(newPos)))
        end
        return false, "invalid_position"
    end
    
    -- Ensure we have valid coordinate values
    local function isValidCoord(coord)
        return type(coord) == 'number' and coord == coord and coord ~= math.huge and coord ~= -math.huge
    end
    
    if not (isValidCoord(newPos.coords.x) and isValidCoord(newPos.coords.y) and isValidCoord(newPos.coords.z) and
            isValidCoord(oldPos.coords.x) and isValidCoord(oldPos.coords.y) and isValidCoord(oldPos.coords.z)) then
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Invalid coordinate values for player %d", playerId))
        end
        return false, "invalid_coordinate_values"
    end
    
    -- Skip first update after spawn or if it's the initial position
    if oldPos.isFirstUpdate or (oldPos.coords.x == 0 and oldPos.coords.y == 0 and oldPos.coords.z == 0) then
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Skipping first position update for player %d (initial spawn)", playerId))
        end
        return false, "first_update"
    end
    
    -- Check cooldown after last teleport
    if lastTeleportTime[playerId] and (GetGameTimer() - lastTeleportTime[playerId]) < TELEPORT_COOLDOWN then
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Player %d in teleport cooldown", playerId))
        end
        return false, "teleport_cooldown"
    end
    
    -- Skip if this is the first valid position after spawn
    if not playerData[playerId] or not playerData[playerId].hasValidPosition then
        if not playerData[playerId] then
            playerData[playerId] = {}
        end
        playerData[playerId].hasValidPosition = true
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Marking first valid position for player %d", playerId))
        end
        return false, "initial_position"
    end
    
    -- Extract coordinates with type checking
    local oldCoords = oldPos.coords or {}
    local newCoords = newPos.coords or {}
    
    -- Check if coordinates are valid numbers
    local function isValidCoord(c)
        return type(c) == 'number' and c == c -- Check for NaN
    end
    
    if not (isValidCoord(newCoords.x) and isValidCoord(newCoords.y) and isValidCoord(newCoords.z) and
            isValidCoord(oldCoords.x) and isValidCoord(oldCoords.y) and isValidCoord(oldCoords.z)) then
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Invalid coordinate values for player %d", playerId))
        end
        return false, "invalid_coordinate_values"
    end
    
    -- Calculate distance and speed
    local dx = newPos.coords.x - oldPos.coords.x
    local dy = newPos.coords.y - oldPos.coords.y
    local dz = newPos.coords.z - oldPos.coords.z
    
    local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
    local timeDiff = (newPos.time - oldPos.time) / 1000.0  -- Convert to seconds
    
    -- Get or initialize player data
    if not playerData[playerId] then
        playerData[playerId] = {
            lastPos = {coords = {x = 0, y = 0, z = 0}, time = newPos.time},
            lastUpdate = newPos.time,
            spawnTime = newPos.time,
            spawnProtected = true,
            initialized = true
        }
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Initialized player data for %d with spawn protection", playerId))
        end
    end
    
    -- Get player data
    local pData = playerData[playerId]
    
    -- Skip checks if still in spawn protection
    if pData.spawnProtected then
        if DEBUG and newPos.time % 2000 < 50 then  -- Log every ~2 seconds to reduce spam
            print(string.format("[ANTI-CHEAT] Player %d in spawn protection (skipping checks)", playerId))
        end
        -- Mark that we've had our first valid position
        pData.hasValidPosition = true
        return
    end
    
    -- Only validate distance if we have valid previous position and time difference
    -- Also ensure we're not in spawn protection (double check)
    if timeDiff > 0 and distance > MAX_VALID_DISTANCE and not pData.spawnProtected and not pData.isInSpawnProtection then
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Invalid position jump for player %d: %.2fm (Max allowed: %.2fm, Time: %.2fs)", 
                playerId, distance, MAX_VALID_DISTANCE, timeDiff))
        end
        return true, "Anti-Cheat System: Anti Teleport"
    end
    
    -- Skip teleport check for very large distances (map teleports)
    if distance < IGNORE_DISTANCE then
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Map teleport detected: %.2fm (Ignoring)", distance))
        end
        return
    end
    
    local speed = timeDiff > 0 and (distance / timeDiff) or 0
    
    -- Get player state
    
    -- Get vehicle and ground state from client-provided data
    local inVehicle = newPos.inVehicle or false
    local onGround = newPos.onGround or false
    local inAir = not onGround and not inVehicle
    
    -- Check for teleport by speed (very high speed = definitely teleport)
    -- Only trigger teleport at very high speeds (500+ m/s) to prevent false positives
    if speed > 500.0 and distance > 200.0 then  -- Increased from 175.0 to 200.0 to match higher speed threshold
        -- Get player info for better logging
        local playerName = GetPlayerName(playerId) or "Unknown"
        local identifiers = GetPlayerIdentifiers(playerId) or {}
        local steamHex = ""
        for _, v in ipairs(identifiers) do
            if string.find(v, "steam:") then
                steamHex = v
                break
            end
        end
        
        -- Log the detection with more details
        if inVehicle then
            print(string.format("^1[ANTI-CHEAT] [KICK] %s (ID: %d, %s) - Vehicle Teleport Detected - Speed: %.2f m/s, Distance: %.2f m^7", 
                playerName, playerId, steamHex, speed, distance))
            return true, "Vehicle Teleport Detected", distance, speed
        else
            print(string.format("^1[ANTI-CHEAT] [KICK] %s (ID: %d, %s) - Teleport Detected (On Foot) - Speed: %.2f m/s, Distance: %.2f m^7", 
                playerName, playerId, steamHex, speed, distance))
            return true, "Anti-Cheat System: Teleport Detected", distance, speed
        end
    end
    
    -- Check for teleport by distance (for slower but still impossible movements)
    if distance > TELEPORT_THRESHOLD and distance < IGNORE_DISTANCE then
        -- Teleport detection for on-foot players
        if not inVehicle and onGround then
            if speed > MAX_SPRINTING_SPEED * 1.5 then
                if DEBUG then
                    print(string.format("[ANTI-CHEAT] Player %d possible teleport detected (Distance: %.2f m, Speed: %.2f m/s, On Foot)", 
                        playerId, distance, speed))
                end
                return true, "Anti-Cheat System: Teleport Detected", distance, speed
            end
        -- Teleport detection for vehicles
        elseif inVehicle then
            if speed > MAX_VEHICLE_SPEED * 1.5 and distance > 20.0 then
                if DEBUG then
                    print(string.format("[ANTI-CHEAT] Player %d possible vehicle teleport detected (Distance: %.2f m, Speed: %.2f m/s)", 
                        playerId, distance, speed))
                end
                return true, "Anti-Cheat System: Vehicle Teleport Detected", distance, speed
            end
        end
    end
    
    -- First check for teleport at very high speeds (over 500 m/s)
    if speed > 500.0 and distance > 200.0 then
        -- Get player info for better logging
        local playerName = GetPlayerName(playerId) or "Unknown"
        local identifiers = GetPlayerIdentifiers(playerId) or {}
        local steamHex = ""
        for _, v in ipairs(identifiers) do
            if string.find(v, "steam:") then
                steamHex = v
                break
            end
        end
        
        -- Log the detection with more details
        if inVehicle then
            print(string.format("^1[ANTI-CHEAT] [KICK] %s (ID: %d, %s) - Vehicle Teleport Detected - Speed: %.2f m/s, Distance: %.2f m^7", 
                playerName, playerId, steamHex, speed, distance))
            return true, "Vehicle Teleport Detected"
        else
            print(string.format("^1[ANTI-CHEAT] [KICK] %s (ID: %d, %s) - Teleport Detected (On Foot) - Speed: %.2f m/s, Distance: %.2f m^7", 
                playerName, playerId, steamHex, speed, distance))
            return true, "Anti-Cheat System: Teleport Detected"
        end
    end
    
    -- Only check for noclip if speed is reasonable (under 100 m/s)
    if speed < 175.0 and not inVehicle then
        local verticalMovement = math.abs(dz)
        local horizontalDistance = math.sqrt(dx * dx + dy * dy)
        local verticalRatio = verticalMovement / (horizontalDistance + 0.0001) -- Avoid division by zero
        
        -- Check noclip at moderate speeds (8.5 - 100 m/s)
        if speed > 8.5 then
            -- More precise noclip detection with adjusted thresholds
            local isNoclip = false
            local reason = ""
            
            -- Check for vertical movement patterns
            if verticalRatio > 1.2 and verticalMovement > 1.0 then  -- More vertical than horizontal movement
                isNoclip = true
                reason = "Excessive vertical movement"
            -- Check for straight up/down movement
            elseif verticalMovement > 5.0 and horizontalDistance < 1.0 then
                isNoclip = true
                reason = "Straight vertical movement"
            -- Check for hovering - use client-provided vehicle status
            elseif verticalMovement < 0.5 and not onGround and not inVehicle then
                isNoclip = true
                reason = "Hovering in mid-air"
            end
            
            if isNoclip then
                if DEBUG then
                    print(string.format("[ANTI-CHEAT] Player %d possible noclip detected - %s (Vertical: %.2fm, Horizontal: %.2fm, Speed: %.2f m/s, Ratio: %.2f)", 
                        playerId, reason, verticalMovement, horizontalDistance, speed, verticalRatio))
                end
                return true, "Noclip Detected"
            end
        end
    end
    
    -- Speed hack detection (only when not in vehicle and on ground)
    if not inVehicle and onGround then
        if speed > MAX_SPRINTING_SPEED then
            if DEBUG then
                print(string.format("[ANTI-CHEAT] Player %d possible speedhack detected (Speed: %.2f m/s, On Foot)", 
                    playerId, speed))
            end
            return true, "Speedhack Detected (On Foot)", distance, speed
        end
    -- Vehicle speed check
    elseif inVehicle then
        if speed > MAX_VEHICLE_SPEED then
            if DEBUG then
                print(string.format("[ANTI-CHEAT] Player %d possible vehicle speedhack detected (Speed: %.2f m/s)", 
                    playerId, speed))
            end
            return true, "Vehicle Speedhack Detected", distance, speed
        end
    end
    
    return false, "clean"
end

-- Handle position updates from client
RegisterNetEvent('cc_t:updatePosition')
AddEventHandler('cc_t:updatePosition', function(posData)
    local src = source
    if not posData or not posData.x or not posData.y or not posData.z then 
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Invalid position data from player %d", src))
        end
        return 
    end
    
    local currentTime = GetGameTimer()
    
    -- Initialize or update player data
    if not playerPositions[src] then
        -- First position update - initialize with spawn protection
        playerPositions[src] = {
            lastPos = {coords = {x = 0, y = 0, z = 0}, time = currentTime},
            lastUpdate = currentTime,
            spawnTime = currentTime,
            spawnProtected = true,
            hasValidPosition = false,
            positionHistory = {}
        }
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Initialized player data for %d with spawn protection", src))
        end
        
        -- Don't process first position update to avoid false positives
        return
    end
    
    local playerData = playerPositions[src]
    
    -- Ensure all required fields exist
    playerData.spawnTime = playerData.spawnTime or currentTime
    playerData.spawnProtected = playerData.spawnProtected ~= false -- Default to true if not set
    
    -- Initialize lastUpdate if it doesn't exist
    if not playerData.lastUpdate then
        playerData.lastUpdate = currentTime
    end
    
    -- Track spawn protection status
    local timeSinceSpawn = currentTime - playerData.spawnTime
    local isInSpawnProtection = timeSinceSpawn < 5000   -- 5 seconds protection (reduced from 10)
    
    -- Store the spawn protection state in player data for later use
    playerData.isInSpawnProtection = isInSpawnProtection
    
    -- Update spawn protection status if needed
    if playerData.spawnProtected ~= isInSpawnProtection then
        playerData.spawnProtected = isInSpawnProtection
        if DEBUG then
        if isInSpawnProtection then
        print(string.format("[ANTI-CHEAT] Spawn protection active for player %d (%.1f seconds remaining)", 
        src, (5000 - timeSinceSpawn)/1000))
            else
                print(string.format("[ANTI-CHEAT] Spawn protection ended for player %d (%.1fs total)", 
                    src, timeSinceSpawn/1000))
            end
        end
    end
    
    -- Skip if we just updated recently (within CHECK_INTERVAL/2 when in protection)
    local minUpdateInterval = isInSpawnProtection and (CHECK_INTERVAL / 2) or CHECK_INTERVAL
    if (currentTime - (playerData.lastUpdate or 0)) < minUpdateInterval then
        return
    end
    
    -- Update lastUpdate time
    playerData.lastUpdate = currentTime
    
    -- Prepare new position data
    local newPos = {
        coords = {
            x = posData.x,
            y = posData.y,
            z = posData.z
        },
        time = currentTime,
        inVehicle = posData.inVehicle,
        onGround = posData.onGround
    }
    
    -- Skip movement checks if still in spawn protection
    local timeSinceSpawn = currentTime - playerData.spawnTime
    local isInSpawnProtection = timeSinceSpawn < 5000   -- 5 seconds protection (reduced from 15)
    
    -- Update spawn protection status
    if playerData.spawnProtected ~= isInSpawnProtection then
        playerData.spawnProtected = isInSpawnProtection
        if DEBUG then
            if isInSpawnProtection then
                print(string.format("[ANTI-CHEAT] Spawn protection active for player %d (%.1f seconds remaining)", 
                    src, (5000 - timeSinceSpawn)/1000))
            else
                print(string.format("[ANTI-CHEAT] Spawn protection ended for player %d (%.1fs total)", 
                    src, timeSinceSpawn/1000))
            end
        end
    end
    
    -- Skip movement checks if still in spawn protection or if we don't have a valid position yet
    if playerData.spawnProtected or not playerData.hasValidPosition then
        if not playerData.hasValidPosition then
            -- This is our first valid position after spawn protection
            playerData.hasValidPosition = true
            if DEBUG then
                print(string.format("[ANTI-CHEAT] First valid position for player %d after spawn", src))
            end
        end
        
        -- Update last position but don't perform checks
        playerData.lastPos = newPos
        playerData.lastUpdate = currentTime
        return
    end
    
    -- Only perform movement checks if we have valid previous position
    if playerData.lastPos and playerData.lastPos.coords and 
       playerData.lastPos.coords.x ~= 0 and playerData.lastPos.coords.y ~= 0 and 
       playerData.lastPos.coords.z ~= 0 then
        
        -- Calculate speed and distance for logging and detection
        local dx = newPos.coords.x - playerData.lastPos.coords.x
        local dy = newPos.coords.y - playerData.lastPos.coords.y
        local dz = newPos.coords.z - playerData.lastPos.coords.z
        
        local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
        local timeDiff = (newPos.time - playerData.lastPos.time) / 1000.0  -- Convert to seconds
        local speed = timeDiff > 0 and (distance / timeDiff) or 0
        local speedKmh = speed * 3.6  -- Convert to km/h for logging
        
        -- Log player speed every second
        if DEBUG and currentTime % 1000 < 50 then  -- Log every second
            local playerName = GetPlayerName(src) or "Unknown"
            print(string.format("[ANTI-CHEAT] Player %s (ID: %d) speed: %.2f m/s (%.1f km/h) - Vehicle: %s, Ground: %s", 
                playerName, src, speed, speedKmh, tostring(newPos.inVehicle), tostring(newPos.onGround)))
        end
        
        -- Enhanced server-side noclip detection
        local isNoclip = false
        local noclipReason = ""
        
        -- 1. Speed-based noclip detection (over 75 m/s without vehicle = noclip)
        if not newPos.inVehicle and speed > 75.0 then
            isNoclip = true
            noclipReason = "speed_over_75ms_without_vehicle"
        end
        
        -- 2. Vertical movement detection (excessive vertical movement)
        local verticalMovement = math.abs(dz)
        local horizontalDistance = math.sqrt(dx * dx + dy * dy)
        local verticalRatio = verticalMovement / (horizontalDistance + 0.0001) -- Avoid division by zero
        
        if not newPos.inVehicle and speed > 8.5 and verticalRatio > 1.2 and verticalMovement > 1.0 then
            isNoclip = true
            noclipReason = "excessive_vertical_movement"
        end
        
        -- 3. Straight vertical movement detection
        if not newPos.inVehicle and verticalMovement > 5.0 and horizontalDistance < 1.0 then
            isNoclip = true
            noclipReason = "straight_vertical_movement"
        end
        
        -- 4. Hovering detection (only at high speeds)
        if not newPos.inVehicle and speed > 50.0 and not onGround and not isFalling and verticalMovement < 0.5 then
            isNoclip = true
            noclipReason = "hovering_in_mid_air"
        end
        
        -- If noclip detected, kick the player
        if isNoclip then
            local playerName = GetPlayerName(src) or "Unknown"
            local identifiers = GetPlayerIdentifiers(src) or {}
            local steamHex = ""
            for _, v in ipairs(identifiers) do
                if string.find(v, "steam:") then
                    steamHex = v
                    break
                end
            end
            
            if DEBUG then
                print(string.format("[ANTI-CHEAT] NOCLIP DETECTED - Player %s (ID: %d, %s) - %s - Speed: %.2f m/s (%.1f km/h)", 
                    playerName, src, steamHex, noclipReason, speed, speedKmh))
            end
            
            -- Kick the player for noclip
            SafeKickPlayer(src, "Anti-Cheat: Noclip Detected", {
                ["Speed"] = string.format("%.2f m/s (%.1f km/h)", speed, speedKmh),
                ["Distance"] = string.format("%.2f meters", distance),
                ["Time"] = string.format("%.2f seconds", timeDiff),
                ["Vehicle"] = tostring(newPos.inVehicle),
                ["Ground"] = tostring(newPos.onGround),
                ["Vertical Movement"] = string.format("%.2f meters", verticalMovement),
                ["Horizontal Distance"] = string.format("%.2f meters", horizontalDistance),
                ["Vertical Ratio"] = string.format("%.2f", verticalRatio),
                ["Reason"] = noclipReason
            })
            return
        end

        local isTeleport, reason, distance, speed = checkMovement(src, newPos, playerData.lastPos)
        if isTeleport then
            -- Only enforce teleport detection if not in spawn protection
            if not playerData.spawnProtected then
                -- Handle teleport detection
                local playerName = GetPlayerName(src) or "Unknown"
                local identifiers = GetPlayerIdentifiers(src) or {}
                local steamHex = ""
                for _, v in ipairs(identifiers) do
                    if string.find(v, "steam:") then
                        steamHex = v
                        break
                    end
                end
                
                print(string.format("^1[ANTI-CHEAT] [KICK] %s (ID: %d, %s) - %s - Speed: %.2f m/s, Distance: %.2f m^7", 
                    playerName, src, steamHex, reason, speed or 0, distance or 0))
                
                -- Kick the player
                DropPlayer(src, "Cheating detected: " .. (reason or "Unknown"))
                return
            elseif DEBUG then
                print(string.format("[ANTI-CHEAT] [IGNORED] Player %d teleport during spawn protection (%.1fm, %.1fm/s)", 
                    src, distance or 0, speed or 0))
            end
        end
    end
    
    -- Update last position
    playerData.lastPos = newPos
    playerData.lastUpdate = currentTime
end)

-- Handle cheat detection from client
RegisterNetEvent('cc_t:cheatDetected')
AddEventHandler('cc_t:cheatDetected', function(cheatType, data)
    local src = source
    
    if not isPlayerActive(src) then return end
    
    -- Check if player is in detection cooldown
    if isInDetectionCooldown(src) then
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Skipping client detection for player %d - in detection cooldown", src))
        end
        return
    end
    
    -- Get player info for logging
    local playerName = GetPlayerName(src) or "Unknown"
    local identifiers = GetPlayerIdentifiers(src)
    local steamHex = ""
    for _, v in pairs(identifiers) do
        if string.find(v, "steam:") then
            steamHex = v
            break
        end
    end
    
    -- Log the detection
    if DEBUG then
        if cheatType == 'noclip' then
            print(string.format("[ANTI-CHEAT] Player %s (ID: %d, %s) detected using noclip (Speed: %.2f m/s)", 
                playerName, src, steamHex, data.speed or 0))
        elseif cheatType == 'godmode' then
            print(string.format("[ANTI-CHEAT] Player %s (ID: %d, %s) detected using godmode (Reason: %s, Health: %s)",
                playerName, src, steamHex, data.reason or "unknown", tostring(data.health)))
        end
    end
    
    -- Take action against cheater with screenshot
    if cheatType == 'freecam' then
        -- Freecam is often used to scout; warn and log first, then escalate if repeated quickly
        local details = data or {}
        local reason = string.format('Freecam suspected (camDist=%.2f allowed=%.2f veh=%s dur=%dms)', 
            tonumber(details.cam_distance or 0.0), tonumber(details.allowed_distance or 0.0), tostring(details.in_vehicle), tonumber(details.duration_ms or 0))
        print(string.format('[ANTI-CHEAT] Player %s (ID: %d) %s', playerName, src, reason))
        -- Optional: immediate kick if desired; uncomment next line to enforce
        -- return SafeKickPlayer(src, 'Anti-Cheat: Freecam Detected', { ["Camera Distance"] = string.format('%.2f m', tonumber(details.cam_distance or 0.0)) })
        -- Send a warning to the client
        SafeKickPlayer(src, "Anti-Cheat: Freecam Detected")
        return
    end
    SafeKickPlayer(src, "Anti-Cheat: " .. cheatType .. " Detected")
end)

-- Handle disabled client events (to prevent errors)
RegisterNetEvent('cc_t:noclip_detected')
AddEventHandler('cc_t:noclip_detected', function()
    -- This event is disabled to prevent conflicts
    if DEBUG then
        print("[ANTI-CHEAT] Ignoring disabled noclip_detected event from client")
    end
end)

RegisterNetEvent('cc_t:teleport_detected')
AddEventHandler('cc_t:teleport_detected', function(distance)
    -- This event is disabled to prevent conflicts
    if DEBUG then
        print(string.format("[ANTI-CHEAT] Ignoring disabled teleport_detected event from client (distance: %.2f)", distance or 0))
    end
end)

-- ##################################################################
-- # Heartbeat System
-- ##################################################################

-- Configuration
local HEARTBEAT_INTERVAL = 5000     -- 5 seconds between checks
local HEARTBEAT_TIMEOUT = 30000     -- 30 seconds until kick
local KICK_MESSAGE = "Anti-Cheat System: Anti Resource Stop."
local DEBUG = true                  -- Enable debug logging

-- Player data storage
local playerHeartbeats = {}

-- Handle incoming heartbeats from clients
RegisterNetEvent('cc_t:heartbeat')
AddEventHandler('cc_t:heartbeat', function()
    local src = source
    
    -- Initialize heartbeat data if it doesn't exist
    if not playerHeartbeats[src] then
        playerHeartbeats[src] = {
            lastBeat = GetGameTimer(),
            active = true
        }
    else
        playerHeartbeats[src].lastBeat = GetGameTimer()
        playerHeartbeats[src].active = true
    end
    
    -- Acknowledge the heartbeat
    TriggerClientEvent('cc_t:heartbeatPong', src)
    
    if DEBUG then
        print(string.format("[HB] Received heartbeat from player %d (Last: %dms ago)", 
            src, GetGameTimer() - playerHeartbeats[src].lastBeat))
    end
end)

-- Handle client-reported heartbeat failures
RegisterNetEvent('cc_t:heartbeatFailed')
AddEventHandler('cc_t:heartbeatFailed', function()
    local src = source
    if DEBUG then
        print(string.format("[HB] Client %d reported heartbeat failure", src))
    end
    
    if isPlayerActive(src) then
        DropPlayer(src, KICK_MESSAGE)
    end
    playerHeartbeats[src] = nil
end)

-- Handle player joining
AddEventHandler('playerJoining', function()
    local src = source
    playerHeartbeats[src] = {
        lastBeat = GetGameTimer(),
        active = true
    }
    playerSpawnTimes[src] = GetGameTimer()
    if DEBUG then
        print(string.format("[HB] Player %d joined, initializing heartbeat and spawn protection", src))
    end
end)

-- Clean up all player data on disconnect
AddEventHandler('playerDropped', function(reason)
    local src = source
    if playerHeartbeats[src] then
        if DEBUG then
            print(string.format("[HB] Player %d disconnected: %s", src, reason or "no reason"))
        end
        playerHeartbeats[src] = nil
        playerSpawnTimes[src] = nil
        playerPositions[src] = nil
    end
end)

-- Main heartbeat check loop
Citizen.CreateThread(function()
    while true do
        local currentTime = GetGameTimer()
        
        -- Get currently active players
        local activePlayers = {}
        for _, playerId in ipairs(GetPlayers()) do
            playerId = tonumber(playerId)
            if isPlayerActive(playerId) then
                activePlayers[playerId] = true
                -- Initialize heartbeat if it doesn't exist
                if not playerHeartbeats[playerId] then
                    playerHeartbeats[playerId] = {
                        lastBeat = currentTime,
                        active = true
                    }
                    if DEBUG then
                        print(string.format("[HB] Initialized heartbeat for player %d", playerId))
                    end
                end
            end
        end
        
        -- Check each tracked player
        for playerId, data in pairs(playerHeartbeats) do
            -- Clean up disconnected players
            if not activePlayers[playerId] then
                if DEBUG then
                    print(string.format("[HB] Cleaning up disconnected player: %d", playerId))
                end
                playerHeartbeats[playerId] = nil
            -- Check for timeouts on connected players
            else
                local timeSinceBeat = currentTime - data.lastBeat
                if timeSinceBeat > HEARTBEAT_TIMEOUT then
                    if DEBUG then
                        print(string.format("[HB] Kicking player %d - no heartbeat for %dms", 
                            playerId, timeSinceBeat))
                    end
                    if isPlayerActive(playerId) then
                        DropPlayer(playerId, KICK_MESSAGE)
                    end
                    playerHeartbeats[playerId] = nil
                elseif DEBUG and timeSinceBeat > (HEARTBEAT_INTERVAL * 1.5) then
                    -- Only log if we're significantly behind schedule
                    print(string.format("[HB] Player %d last beat: %dms ago", 
                        playerId, timeSinceBeat))
                end
            end
        end
        
        Citizen.Wait(HEARTBEAT_INTERVAL)
    end
end)

-- ##################################################################
-- # Continuous Speed Monitoring System
-- ##################################################################

-- Player speed tracking
local playerSpeedData = {}

-- Function to calculate distance between two coordinates
local function calculateDistance(pos1, pos2)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    local dz = pos1.z - pos2.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- Function to check player speed and detect noclip
local function checkPlayerSpeed(playerId)
    print(string.format("[ANTI-CHEAT] checkPlayerSpeed called for player %d", playerId))
    
    if not isPlayerActive(playerId) then 
        print(string.format("[ANTI-CHEAT] Player %d is not active in checkPlayerSpeed", playerId))
        return 
    end
    
    local ped = GetPlayerPed(playerId)
    if not DoesEntityExist(ped) then 
        print(string.format("[ANTI-CHEAT] Player %d ped does not exist in checkPlayerSpeed", playerId))
        return 
    end
    
    local currentTime = GetGameTimer()
    local currentCoords = GetEntityCoords(ped)
    -- Server-side vehicle check using GetVehiclePedIsIn
    local vehicle = GetVehiclePedIsIn(ped, false)
    local inVehicle = vehicle ~= 0
    
    -- Initialize player speed data if not exists
    if not playerSpeedData[playerId] then
        print(string.format("[ANTI-CHEAT] Initializing speed data for player %d (first join)", playerId))
        playerSpeedData[playerId] = {
            lastPos = currentCoords,
            lastTime = currentTime,
            lastSpeed = 0,
            lastSpeedKmh = 0,
            joinTime = currentTime  -- Store join time
        }
        return
    end
    
    -- Check grace period (5 seconds after join)
    local timeSinceJoin = currentTime - playerSpeedData[playerId].joinTime
    if timeSinceJoin < 5000 then  -- 5 seconds grace period
        print(string.format("[ANTI-CHEAT] Player %d in grace period - timeSinceJoin: %.2f seconds", playerId, timeSinceJoin/1000))
        -- Update position but skip detection
        playerSpeedData[playerId].lastPos = currentCoords
        playerSpeedData[playerId].lastTime = currentTime
        return
    end
    
    local speedData = playerSpeedData[playerId]
    local timeDiff = (currentTime - speedData.lastTime) / 1000.0  -- Convert to seconds
    
                    -- Check if we have a reasonable time difference (0.1 to 10 seconds)
    print(string.format("[ANTI-CHEAT] Player %d timeDiff: %.2f seconds", playerId, timeDiff))
    if timeDiff > 0.1 and timeDiff < 10.0 then
        print(string.format("[ANTI-CHEAT] Player %d timeDiff OK - processing speed check", playerId))
        
        local distance = calculateDistance(currentCoords, speedData.lastPos)
            local speed = timeDiff > 0 and (distance / timeDiff) or 0
            local speedKmh = speed * 3.6  -- Convert to km/h
            
            -- Get player info for logging
            local playerName = GetPlayerName(playerId) or "Unknown"
            local identifiers = GetPlayerIdentifiers(playerId) or {}
            local steamHex = ""
            for _, v in ipairs(identifiers) do
                if string.find(v, "steam:") then
                    steamHex = v
                    break
                end
            end
            
            -- Log player speed every second (always log)
            print(string.format("[ANTI-CHEAT] SPEED LOG: Player %s (ID: %d) - Speed: %.2f m/s (%.1f km/h) - Distance: %.2f m - TimeDiff: %.2f s - Coords: %.2f, %.2f, %.2f - Vehicle: %s", 
                playerName, playerId, speed, speedKmh, distance, timeDiff,
                currentCoords.x, currentCoords.y, currentCoords.z, 
                tostring(inVehicle)))
        
        -- Enhanced teleport and noclip detection
        local isTeleport = false
        local isNoclip = false
        local teleportReason = ""
        local noclipReason = ""
        
        -- 1. TELEPORT DETECTION (Priority 1) - Very high speeds = teleport
        if speed > 300.0 and distance > 50.0 then
            isTeleport = true
            teleportReason = "speed_over_300ms"
        end
        
        -- Calculate movement variables for all detection types
        local verticalMovement = math.abs(currentCoords.z - speedData.lastPos.z)
        local horizontalDistance = math.sqrt(
            (currentCoords.x - speedData.lastPos.x)^2 + 
            (currentCoords.y - speedData.lastPos.y)^2
        )
        local verticalRatio = horizontalDistance > 0 and (verticalMovement / horizontalDistance) or 0
        local onGround = true  -- Assume on ground for server-side check
        local isFalling = currentCoords.z < speedData.lastPos.z
        
        -- 2. NOCLIP DETECTION (Priority 2) - Skip if teleport already detected
        if not isTeleport then
            -- Speed-based noclip detection (80-300 m/s without vehicle = noclip)
            if not inVehicle and speed > 80.0 and speed <= 300.0 then
                isNoclip = true
                noclipReason = "speed_over_80ms_without_vehicle"
            end
            
            -- Vertical movement detection (excessive vertical movement)
            -- Only detect if NOT falling and speed is very high (over 100 m/s)
            if not inVehicle and speed > 100.0 and verticalRatio > 1.2 and verticalMovement > 1.0 and not isFalling then
                isNoclip = true
                noclipReason = "excessive_vertical_movement"
            end
            
            -- Straight vertical movement detection (only at high speeds)
            if not inVehicle and speed > 50.0 and verticalMovement > 10.0 and horizontalDistance < 1.0 then
                isNoclip = true
                noclipReason = "straight_vertical_movement"
            end
            
            -- Hovering detection (only at high speeds)
            if not inVehicle and speed > 50.0 and not onGround and not isFalling and verticalMovement < 0.5 then
                isNoclip = true
                noclipReason = "hovering_in_mid_air"
            end
        end
        
        -- If teleport detected, kick the player (Priority 1)
        if isTeleport then
            print(string.format("[ANTI-CHEAT] TELEPORT DETECTED - Player %s (ID: %d, %s) - %s - Speed: %.2f m/s (%.1f km/h) - Coords: %.2f, %.2f, %.2f", 
                playerName, playerId, steamHex, teleportReason, speed, speedKmh,
                currentCoords.x, currentCoords.y, currentCoords.z))
            
            -- Kick the player for teleport
            SafeKickPlayer(playerId, "Anti-Cheat: Teleport Detected", {
                ["Speed"] = string.format("%.2f m/s (%.1f km/h)", speed, speedKmh),
                ["Distance"] = string.format("%.2f meters", distance),
                ["Time"] = string.format("%.2f seconds", timeDiff),
                ["Vehicle"] = tostring(inVehicle),
                ["Coordinates"] = string.format("X: %.2f, Y: %.2f, Z: %.2f", 
                    currentCoords.x, currentCoords.y, currentCoords.z),
                ["Reason"] = teleportReason
            })
            return
        end
        
        -- If noclip detected, kick the player (Priority 2) - ONLY if not teleport
        if isNoclip and not isTeleport then
            print(string.format("[ANTI-CHEAT] NOCLIP DETECTED - Player %s (ID: %d, %s) - %s - Speed: %.2f m/s (%.1f km/h) - Coords: %.2f, %.2f, %.2f", 
                playerName, playerId, steamHex, noclipReason, speed, speedKmh,
                currentCoords.x, currentCoords.y, currentCoords.z))
            
            -- Kick the player for noclip
            SafeKickPlayer(playerId, "Anti-Cheat: Noclip Detected", {
                ["Speed"] = string.format("%.2f m/s (%.1f km/h)", speed, speedKmh),
                ["Distance"] = string.format("%.2f meters", distance),
                ["Time"] = string.format("%.2f seconds", timeDiff),
                ["Vehicle"] = tostring(inVehicle),
                ["Ground"] = tostring(onGround),
                ["Vertical Movement"] = string.format("%.2f meters", verticalMovement),
                ["Horizontal Distance"] = string.format("%.2f meters", horizontalDistance),
                ["Vertical Ratio"] = string.format("%.2f", verticalRatio),
                ["Coordinates"] = string.format("X: %.2f, Y: %.2f, Z: %.2f", 
                    currentCoords.x, currentCoords.y, currentCoords.z),
                ["Reason"] = noclipReason
            })
            return
        end
        
        -- Update speed data
        speedData.lastPos = currentCoords
        speedData.lastTime = currentTime
        speedData.lastSpeed = speed
        speedData.lastSpeedKmh = speedKmh
    end
end

-- Continuous speed monitoring thread
Citizen.CreateThread(function()
    print("[ANTI-CHEAT] Starting continuous speed monitoring system...")
    
    while true do
        Citizen.Wait(1000) -- Check every second
        
        local currentTime = GetGameTimer()
        local activePlayers = GetPlayers()
        
        print(string.format("[ANTI-CHEAT] MONITORING: Checking %d active players at %d", #activePlayers, currentTime))
        
        -- Get all active players
        for _, playerId in ipairs(activePlayers) do
            playerId = tonumber(playerId)
            if isPlayerActive(playerId) then
                print(string.format("[ANTI-CHEAT] Calling checkPlayerSpeed for player %d", playerId))
                checkPlayerSpeed(playerId)
            else
                print(string.format("[ANTI-CHEAT] Player %d is not active", playerId))
            end
        end
        
        -- Clean up disconnected players
        for playerId, _ in pairs(playerSpeedData) do
            if not isPlayerActive(playerId) then
                playerSpeedData[playerId] = nil
                print(string.format("[ANTI-CHEAT] Cleaned up speed data for disconnected player %d", playerId))
            end
        end
    end
end)

-- Additional robust monitoring system
Citizen.CreateThread(function()
    print("[ANTI-CHEAT] Starting additional robust monitoring system...")
    
    while true do
        Citizen.Wait(1000) -- Every second
        
        local currentTime = GetGameTimer()
        local players = GetPlayers()
        
        for _, playerId in ipairs(players) do
            playerId = tonumber(playerId)
            
            if isPlayerActive(playerId) then
                local ped = GetPlayerPed(playerId)
                if DoesEntityExist(ped) then
                    local coords = GetEntityCoords(ped)
                    local playerName = GetPlayerName(playerId) or "Unknown"
                    
                    -- Simple position logging every second
                    print(string.format("[ANTI-CHEAT] POSITION: Player %s (ID: %d) at %.2f, %.2f, %.2f - Time: %d", 
                        playerName, playerId, coords.x, coords.y, coords.z, currentTime))
                end
            end
        end
    end
end)

-- ##################################################################
-- # Car Detection System
-- ##################################################################

-- Vehicle tracking for car detection
local vehicleExplosionData = {}
local vehicleSpawnData = {}
local vehicleEntityData = {} -- Track vehicle entities for cleanup

-- Function to check car explosion/spawn limits
local function checkCarLimits(playerId, eventType)
    if not isPlayerActive(playerId) then return end
    
    local currentTime = GetGameTimer()
    
    -- Initialize data if not exists
    if not vehicleExplosionData[playerId] then
        vehicleExplosionData[playerId] = {
            explosions = {},
            lastCleanup = currentTime
        }
    end
    
    if not vehicleSpawnData[playerId] then
        vehicleSpawnData[playerId] = {
            spawns = {},
            lastCleanup = currentTime
        }
    end
    
    if not vehicleEntityData[playerId] then
        vehicleEntityData[playerId] = {
            vehicles = {},
            lastCleanup = currentTime
        }
    end
    
    -- Clean up old data (older than 4 seconds)
    local function cleanupOldData(data, currentTime)
        local validEntries = {}
        for _, timestamp in ipairs(data) do
            if (currentTime - timestamp) <= 4000 then  -- 4 seconds
                table.insert(validEntries, timestamp)
            end
        end
        return validEntries
    end
    
    -- Clean up old vehicle entities (older than 4 seconds)
    local function cleanupOldVehicles(vehicles, currentTime)
        local validVehicles = {}
        for _, vehicleData in ipairs(vehicles) do
            if (currentTime - vehicleData.timestamp) <= 4000 then  -- 4 seconds
                table.insert(validVehicles, vehicleData)
            else
                -- Delete old vehicle if it still exists
                if DoesEntityExist(vehicleData.entity) then
                    DeleteEntity(vehicleData.entity)
                end
            end
        end
        return validVehicles
    end
    
    -- Check explosion limits
    if eventType == "explosion" then
        vehicleExplosionData[playerId].explosions = cleanupOldData(vehicleExplosionData[playerId].explosions, currentTime)
        table.insert(vehicleExplosionData[playerId].explosions, currentTime)
        
        if #vehicleExplosionData[playerId].explosions >= 5 then
            local playerName = GetPlayerName(playerId) or "Unknown"
            local identifiers = GetPlayerIdentifiers(playerId) or {}
            local steamHex = ""
            for _, v in ipairs(identifiers) do
                if string.find(v, "steam:") then
                    steamHex = v
                    break
                end
            end
            
            print(string.format("[ANTI-CHEAT] CAR EXPLOSION SPAM DETECTED - Player %s (ID: %d, %s) - %d explosions in 4 seconds - Cleaning up all vehicles", 
                playerName, playerId, steamHex, #vehicleExplosionData[playerId].explosions))
            
            -- Clean up all vehicles in the time window
            if vehicleEntityData[playerId] then
                local deletedCount = 0
                for _, vehicleData in ipairs(vehicleEntityData[playerId].vehicles) do
                    if DoesEntityExist(vehicleData.entity) then
                        DeleteEntity(vehicleData.entity)
                        deletedCount = deletedCount + 1
                    end
                end
                print(string.format("[ANTI-CHEAT] Deleted %d vehicles for player %d", deletedCount, playerId))
            end
            
            SafeKickPlayer(playerId, "Anti-Cheat: Car Explosion Spam Detected", {
                ["Explosions"] = string.format("%d explosions", #vehicleExplosionData[playerId].explosions),
                ["Vehicles Deleted"] = string.format("%d vehicles", deletedCount or 0),
                ["Time Window"] = "4 seconds",
                ["Reason"] = "vehicle_explosion_spam"
            })
            
            -- Reset all data after kick
            vehicleExplosionData[playerId] = nil
            vehicleEntityData[playerId] = nil
            return
        end
    end
    
    -- Check spawn limits
    if eventType == "spawn" then
        vehicleSpawnData[playerId].spawns = cleanupOldData(vehicleSpawnData[playerId].spawns, currentTime)
        table.insert(vehicleSpawnData[playerId].spawns, currentTime)
        
        if #vehicleSpawnData[playerId].spawns >= 5 then
            local playerName = GetPlayerName(playerId) or "Unknown"
            local identifiers = GetPlayerIdentifiers(playerId) or {}
            local steamHex = ""
            for _, v in ipairs(identifiers) do
                if string.find(v, "steam:") then
                    steamHex = v
                    break
                end
            end
            
            print(string.format("[ANTI-CHEAT] CAR SPAWN SPAM DETECTED - Player %s (ID: %d, %s) - %d spawns in 4 seconds - Cleaning up all vehicles", 
                playerName, playerId, steamHex, #vehicleSpawnData[playerId].spawns))
            
            -- Clean up all vehicles in the time window
            if vehicleEntityData[playerId] then
                local deletedCount = 0
                for _, vehicleData in ipairs(vehicleEntityData[playerId].vehicles) do
                    if DoesEntityExist(vehicleData.entity) then
                        DeleteEntity(vehicleData.entity)
                        deletedCount = deletedCount + 1
                    end
                end
                print(string.format("[ANTI-CHEAT] Deleted %d vehicles for player %d", deletedCount, playerId))
            end
            
            SafeKickPlayer(playerId, "Anti-Cheat: Car Spawn Spam Detected", {
                ["Spawns"] = string.format("%d spawns", #vehicleSpawnData[playerId].spawns),
                ["Vehicles Deleted"] = string.format("%d vehicles", deletedCount or 0),
                ["Time Window"] = "4 seconds",
                ["Reason"] = "vehicle_spawn_spam"
            })
            
            -- Reset all data after kick
            vehicleSpawnData[playerId] = nil
            vehicleEntityData[playerId] = nil
            return
        end
    end
end

-- Enhanced explosion detection with car detection
local originalExplosionHandler = AddEventHandler
AddEventHandler('explosionEvent', function(sender, ev)
    local playerId = source
    if not playerId or playerId == 0 then return end
    
    local currentTime = GetGameTimer()
    
    -- Check if explosion is from a vehicle
    local ped = GetPlayerPed(playerId)
    if not ped or not DoesEntityExist(ped) then return end
    
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then  -- 0 means not in a vehicle
        -- Check if it's a vehicle explosion (type 3 is vehicle explosion)
        if ev.explosionType == 3 or ev.explosionType == 4 or ev.explosionType == 5 or 
           ev.explosionType == 25 or ev.explosionType == 32 or ev.explosionType == 33 then
            
            -- Advanced vehicle explosion detection
            local vehicleHealth = GetEntityHealth(vehicle)
            local vehicleMaxHealth = GetEntityMaxHealth(vehicle)
            local healthPercentage = (vehicleHealth / vehicleMaxHealth) * 100
            
            -- If vehicle has high health (>80%) and explodes, it's suspicious
            if healthPercentage > 80.0 then
                local playerName = GetPlayerName(playerId) or "Unknown"
                local identifiers = GetPlayerIdentifiers(playerId) or {}
                local steamHex = ""
                for _, v in ipairs(identifiers) do
                    if string.find(v, "steam:") then
                        steamHex = v
                        break
                    end
                end
                
                print(string.format("[ANTI-CHEAT] INSTANT VEHICLE EXPLOSION DETECTED - Player %s (ID: %d, %s) - Vehicle Health: %.1f%% - Explosion Type: %d", 
                    playerName, playerId, steamHex, healthPercentage, ev.explosionType))
                
                SafeKickPlayer(playerId, "Anti-Cheat: Instant Vehicle Explosion Detected", {
                    ["Vehicle Health"] = string.format("%.1f%%", healthPercentage),
                    ["Explosion Type"] = string.format("%d", ev.explosionType),
                    ["Reason"] = "instant_vehicle_explosion"
                })
                
                return -- Skip normal car detection for instant explosions
            end
            
            -- Call car detection for normal vehicle explosions
            checkCarLimits(playerId, "explosion")
        end
    end
end)

-- Vehicle spawn detection
AddEventHandler('entityCreating', function(entity, cancel)
    if not DoesEntityExist(entity) then return end
    
    local entityType = GetEntityType(entity)
    if entityType ~= 2 then return end -- Only check vehicles (type 2)
    
    local owner = NetworkGetEntityOwner(entity)
    if owner and owner > 0 then
        -- Track vehicle entity for cleanup
        if not vehicleEntityData[owner] then
            vehicleEntityData[owner] = {
                vehicles = {},
                lastCleanup = GetGameTimer()
            }
        end
        
        -- Add vehicle to tracking
        table.insert(vehicleEntityData[owner].vehicles, {
            entity = entity,
            timestamp = GetGameTimer()
        })
        
        -- Call car detection
        checkCarLimits(owner, "spawn")
        
        -- Check for driverless fast vehicles
        Citizen.CreateThread(function()
            Citizen.Wait(100) -- Wait 100ms for vehicle to fully spawn
            
            if DoesEntityExist(entity) then
                local vehicle = entity
                local driver = GetPedInVehicleSeat(vehicle, -1) -- Driver seat
                local speed = GetEntitySpeed(vehicle)
                local speedKmh = speed * 3.6
                
                -- If vehicle is driverless and moving fast, delete it
                if driver == 0 and speedKmh > 50.0 then -- 50 km/h threshold
                    local playerName = GetPlayerName(owner) or "Unknown"
                    local identifiers = GetPlayerIdentifiers(owner) or {}
                    local steamHex = ""
                    for _, v in ipairs(identifiers) do
                        if string.find(v, "steam:") then
                            steamHex = v
                            break
                        end
                    end
                    
                    print(string.format("[ANTI-CHEAT] DRIVERLESS FAST VEHICLE DETECTED - Player %s (ID: %d, %s) - Speed: %.1f km/h - Deleting vehicle", 
                        playerName, owner, steamHex, speedKmh))
                    
                    -- Delete the vehicle
                    DeleteEntity(vehicle)
                    
                    -- Kick the player for suspicious vehicle spawning
                    SafeKickPlayer(owner, "Anti-Cheat: Anti Vehicle Spawn", {
                        ["Vehicle Speed"] = string.format("%.1f km/h", speedKmh),
                        ["Reason"] = "driverless_fast_vehicle_spawn"
                    })
                end
            end
        end)
    end
end)

-- ##################################################################
-- # Simple Super Punch Detection System (like txAdmin)
-- ##################################################################

-- Track player damage for super punch detection
local playerDamageData = {}
local playerKillData = {}

-- Weapon damage limits (realistic values)
local WEAPON_DAMAGE_LIMITS = {
    [GetHashKey('WEAPON_UNARMED')] = 25,        -- Fists: max 25 damage
    [GetHashKey('WEAPON_KNUCKLE')] = 35,        -- Brass knuckles: max 35 damage
    [GetHashKey('WEAPON_KNIFE')] = 50,          -- Knife: max 50 damage
    [GetHashKey('WEAPON_NIGHTSTICK')] = 30,     -- Nightstick: max 30 damage
    [GetHashKey('WEAPON_HAMMER')] = 40,         -- Hammer: max 40 damage
    [GetHashKey('WEAPON_BAT')] = 45,            -- Baseball bat: max 45 damage
    [GetHashKey('WEAPON_CROWBAR')] = 35,        -- Crowbar: max 35 damage
    [GetHashKey('WEAPON_GOLFCLUB')] = 40,       -- Golf club: max 40 damage
    [GetHashKey('WEAPON_BOTTLE')] = 20,         -- Bottle: max 20 damage
    [GetHashKey('WEAPON_DAGGER')] = 45,         -- Dagger: max 45 damage
    [GetHashKey('WEAPON_HATCHET')] = 55,        -- Hatchet: max 55 damage
    [GetHashKey('WEAPON_MACHETE')] = 60,        -- Machete: max 60 damage
    [GetHashKey('WEAPON_SWITCHBLADE')] = 40,    -- Switchblade: max 40 damage
    [GetHashKey('WEAPON_WRENCH')] = 30,         -- Wrench: max 30 damage
    [GetHashKey('WEAPON_BATTLEAXE')] = 65,      -- Battle axe: max 65 damage
    [GetHashKey('WEAPON_POOLCUE')] = 35,        -- Pool cue: max 35 damage
    [GetHashKey('WEAPON_STONE_HATCHET')] = 60,  -- Stone hatchet: max 60 damage
    [GetHashKey('WEAPON_CANDYCANE')] = 15       -- Candy cane: max 15 damage
}

-- Convert to a set for faster lookups
local MELEE_WEAPONS_SET = {}
for weaponHash, _ in pairs(WEAPON_DAMAGE_LIMITS) do
    MELEE_WEAPONS_SET[weaponHash] = true
end

-- Function to check if a weapon is melee
local function isMeleeWeapon(weaponHash)
    return MELEE_WEAPONS_SET[weaponHash] or false
end

-- Function to get maximum allowed damage for a weapon
local function getMaxAllowedDamage(weaponHash)
    return WEAPON_DAMAGE_LIMITS[weaponHash] or 25 -- Default to 25 for unknown melee weapons
end

-- Function to get player distance
local function getPlayerDistance(player1Id, player2Id)
    if not isPlayerActive(player1Id) or not isPlayerActive(player2Id) then
        return math.huge
    end
    
    local ped1 = GetPlayerPed(player1Id)
    local ped2 = GetPlayerPed(player2Id)
    
    if not DoesEntityExist(ped1) or not DoesEntityExist(ped2) then
        return math.huge
    end
    
    local coords1 = GetEntityCoords(ped1)
    local coords2 = GetEntityCoords(ped2)
    
    local dx = coords1.x - coords2.x
    local dy = coords1.y - coords2.y
    local dz = coords1.z - coords2.z
    
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- Convert to a set for faster lookups
local MELEE_WEAPONS_SET = {}
for weaponHash, _ in pairs(WEAPON_DAMAGE_LIMITS) do
    MELEE_WEAPONS_SET[weaponHash] = true
end

-- Function to check if a weapon is melee
local function isMeleeWeapon(weaponHash)
    return MELEE_WEAPONS_SET[weaponHash] or false
end

-- Simple function to check for super punch (like txAdmin)
local function checkSuperPunch(attackerId, victimId, damage, weaponHash)
    if not isPlayerActive(attackerId) or not isPlayerActive(victimId) then
        return false, "invalid_players"
    end
    
    -- Check if it's a melee weapon
    if not isMeleeWeapon(weaponHash) then
        return false, "not_melee_weapon"
    end
    
    -- Get maximum allowed damage for this weapon
    local maxAllowedDamage = getMaxAllowedDamage(weaponHash)
    
    -- Check if damage exceeds the weapon's limit
    if damage > maxAllowedDamage then
        return true, "super_punch_damage", string.format("Damage %.1f exceeds weapon limit %.1f", damage, maxAllowedDamage)
    end
    
    return false, "normal_damage"
end

-- Initialize player data tables
local function initializePlayerData(playerId)
    if not playerDamageData[playerId] then
        playerDamageData[playerId] = {
            violations = 0,
            lastAttack = 0
        }
    end
end

-- Handle damage events for super punch detection
AddEventHandler('weaponDamageEvent', function(sender, data)
    local attackerId = sender
    if not isPlayerActive(attackerId) then return end
    
    -- Initialize player data
    initializePlayerData(attackerId)
    
    local currentTime = GetGameTimer()
    local weaponHash = data.weaponType or 0
    local damage = data.damage or 0
    local victimNetId = data.victimNetId or 0
    
    if victimNetId == 0 then return end
    
    local victimEntity = NetworkGetEntityFromNetworkId(victimNetId)
    if victimEntity == 0 then return end
    
    -- Get victim player ID
    local victimId = 0
    for _, playerId in ipairs(GetPlayers()) do
        playerId = tonumber(playerId)
        if isPlayerActive(playerId) then
            local ped = GetPlayerPed(playerId)
            if DoesEntityExist(ped) and ped == victimEntity then
                victimId = playerId
                break
            end
        end
    end
    
    if victimId == 0 then return end
    
    -- Get victim health before damage
    local victimPed = GetPlayerPed(victimId)
    local victimHealth = GetEntityHealth(victimPed) + damage  -- Health before damage
    
    -- Calculate distance between attacker and victim
    local distance = getPlayerDistance(attackerId, victimId)
    
    -- Check for super punch (simple damage check)
    local isSuperPunch, punchReason, punchDetails = checkSuperPunch(attackerId, victimId, damage, weaponHash)
    
    if isSuperPunch then
        local playerName = GetPlayerName(attackerId) or "Unknown"
        local victimName = GetPlayerName(victimId) or "Unknown"
        local identifiers = GetPlayerIdentifiers(attackerId) or {}
        local steamHex = ""
        for _, v in ipairs(identifiers) do
            if string.find(v, "steam:") then
                steamHex = v
                break
            end
        end
        
        -- Log the detection
        print(string.format("^1[ANTI-CHEAT] [SUPER PUNCH DETECTED] %s (ID: %d, %s) -> %s (ID: %d) - %s - Damage: %.1f, Weapon: %s^7", 
            playerName, attackerId, steamHex, victimName, victimId, punchDetails, damage, tostring(weaponHash)))
        
        -- Increment violation count
        playerDamageData[attackerId].violations = playerDamageData[attackerId].violations + 1
        
        -- Kick player immediately for super punch
        SafeKickPlayer(attackerId, "Anti-Cheat: Super Punch Detected", {
            ["Attack Type"] = "Super Punch",
            ["Damage"] = string.format("%.1f", damage),
            ["Weapon"] = string.format("%s", weaponHash),
            ["Violations"] = string.format("%d", playerDamageData[attackerId].violations),
            ["Details"] = punchDetails
        })
        
        -- Reset violation count after kick
        playerDamageData[attackerId].violations = 0
        
        -- Block the damage
        data.damage = 0.0
        CancelEvent()
        return true
    end
    
    -- Update attack tracking
    playerDamageData[attackerId].lastAttack = GetGameTimer()
end)

-- Handle player death events for additional verification
AddEventHandler('playerDeath', function(victimId, attackerId, weaponHash)
    if not isPlayerActive(victimId) then return end
    
    -- Initialize player data for attacker if available
    if attackerId and attackerId > 0 and isPlayerActive(attackerId) then
        initializePlayerData(attackerId)
        
        -- Check if it was a melee kill
        if isMeleeWeapon(weaponHash) then
            local playerName = GetPlayerName(attackerId) or "Unknown"
            local victimName = GetPlayerName(victimId) or "Unknown"
            local identifiers = GetPlayerIdentifiers(attackerId) or {}
            local steamHex = ""
            for _, v in ipairs(identifiers) do
                if string.find(v, "steam:") then
                    steamHex = v
                    break
                end
            end
            
            -- Log the melee kill
            print(string.format("[ANTI-CHEAT] [MELEE KILL] %s (ID: %d, %s) killed %s (ID: %d) with melee weapon - Weapon: %s", 
                playerName, attackerId, steamHex, victimName, victimId, tostring(weaponHash)))
        end
    end
end)

-- Clean up player data on disconnect
AddEventHandler('playerDropped', function(reason)
    local src = source
    if playerDamageData[src] then
        playerDamageData[src] = nil
    end
    if playerKillData[src] then
        playerKillData[src] = nil
    end
end)

-- Simple super punch detection (like txAdmin)
-- This system only checks weapon damage limits and kicks immediately

-- Block any damage events that might bypass normal checks
-- Simple super punch detection system complete

-- Simple super punch detection system complete

-- Simple super punch detection system complete

-- Simple super punch detection system complete

-- Simple super punch detection system complete

-- Simple super punch detection system complete