-- Configuration
local DEBUG = true
local MAX_NOCLIP_SPEED = 50.0  -- Maximum allowed speed when not in a vehicle (m/s)
local CHECK_INTERVAL = 1000     -- Position check interval in ms
local SPAWN_PROTECTION = 5000   -- 5 seconds of protection after spawn (reduced from 15)

-- Movement state tracking
local lastPositions = {}
local MAX_POSITION_HISTORY = 5  -- Number of positions to keep for movement analysis
local lastPosition = nil
local lastCheck = 0
local spawnTime = GetGameTimer()
local isSpawnProtected = true
local isFirstSpawn = true
local SPAWN_PROTECTION_DURATION = 5000   -- 5 seconds of spawn protection (reduced from 10)

-- Freecam Detection Configuration
local FREECAM_CHECK_INTERVAL = 500      -- ms between camera checks
local FREECAM_MAX_CAM_DISTANCE = 15.0   -- meters camera can be from ped before suspect
local FREECAM_MIN_DURATION = 3000       -- ms the condition must persist to trigger
local FREECAM_COOLDOWN = 15000          -- ms between reports
local freecamSuspectStart = nil
local lastFreecamReport = 0

-- Magic bullet local protection
local lastHealthSnapshot = 0
local lastArmourSnapshot = 0

-- Godmode Detection
local damageTracking = {
    lastHealth = 0,
    lastDamageTime = 0,
    lastDamageSource = nil,
    damageTestInProgress = false,
    lastHealthTestTime = 0,
    consecutiveNoDamageEvents = 0,
    DAMAGE_THRESHOLD = 5,           -- Number of damage events before checking
    DAMAGE_WINDOW = 5000,           -- Time window for damage events in ms
    MELEE_ATTACK_DELAY = 1000,      -- Delay between melee attacks in ms
    damageEvents = {}
}

-- Track damage events
local function trackDamageEvent(amount)
    local currentTime = GetGameTimer()
    
    -- Clean up old events
    for i = #damageTracking.damageEvents, 1, -1 do
        if currentTime - damageTracking.damageEvents[i].time > damageTracking.DAMAGE_WINDOW then
            table.remove(damageTracking.damageEvents, i)
        end
    end
    
    -- Add new damage event
    table.insert(damageTracking.damageEvents, {
        time = currentTime,
        amount = amount
    })
    
    damageTracking.lastDamageTime = currentTime
end

-- Check if player should be taking damage
local function isPlayerDrowning(playerPed)
    -- Check if player is actually drowning (not just swimming)
    if not IsEntityInWater(playerPed) then return false end
    
    -- Check if player is in a vehicle that can go underwater
    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if GetVehicleClass(vehicle) == 14 or GetVehicleClass(vehicle) == 15 then -- Boat or helicopter class
            return false
        end
    end
    
    -- Get player's air level (0-10, where 0 is no air left)
    local air = GetPlayerUnderwaterTimeRemaining(PlayerId()) * 10
    
    -- Only consider it drowning if player is low on air and underwater
    if air < 3.0 and IsPedSwimmingUnderWater(playerPed) then
        return true
    end
    
    -- Also check if player is at surface but out of breath
    if IsPedSwimming(playerPed) and not IsPedSwimmingUnderWater(playerPed) then
        -- If player is at surface but still has low air, they're recovering
        -- Don't count this as drowning to prevent false positives
        return false
    end
    
    return false
end

local function shouldTakeDamage()
    local playerPed = PlayerPedId()
    local currentTime = GetGameTimer()
    
    -- Check for drowning with more accurate detection
    if isPlayerDrowning(playerPed) then
        -- Only flag for damage if player has been drowning for more than 3 seconds
        damageTracking.drowningStartTime = damageTracking.drowningStartTime or currentTime
        local timeDrowning = currentTime - damageTracking.drowningStartTime
        
        if timeDrowning > 3000 then -- 3 seconds of continuous drowning before checking for damage
            return true, "drowning"
        end
    else
        damageTracking.drowningStartTime = nil
    end
    
    -- Vehicle burnout damage
    if IsPedInAnyVehicle(playerPed, false) and not IsThisModelABoat(GetEntityModel(GetVehiclePedIsIn(playerPed, false))) then
        if IsVehicleInBurnout(GetVehiclePedIsIn(playerPed, false)) then
            return true, "vehicle_burnout"
        end
    end
    
    -- Fire damage
    if IsEntityOnFire(playerPed) then
        return true, "on_fire"
    end
    
    -- Falling damage (only check if falling faster than 20 m/s)
    local velocity = GetEntityVelocity(playerPed)
    local verticalSpeed = math.abs(velocity.z)
    if verticalSpeed > 20.0 and not IsPedInAnyVehicle(playerPed, false) then
        return true, "falling"
    end
    
    -- Recent damage events (within last 1.5 seconds)
    for _, event in ipairs(damageTracking.damageEvents) do
        if currentTime - event.time < 1500 then
            return true, "recent_damage"
        end
    end
    
    return false, "no_damage_expected"
end

local function checkGodmode()
    -- Skip check during spawn protection
    if isSpawnProtected then
        if DEBUG and GetGameTimer() % 5000 < 100 then  -- Only log every ~5 seconds to avoid spam
            local remaining = math.ceil((spawnTime + SPAWN_PROTECTION - GetGameTimer()) / 1000)
            if remaining > 0 then
                print("[ANTI-CHEAT] Godmode check skipped (spawn protection - " .. remaining .. "s remaining)")
            end
        end
        return 
    end
    
    local playerPed = PlayerPedId()
    local currentHealth = GetEntityHealth(playerPed)
    local currentTime = GetGameTimer()
    
    -- Check if player should be taking damage
    local shouldDamage, reason = shouldTakeDamage()
    
    -- Check for health regeneration (shouldn't happen without cheats)
    if currentHealth > damageTracking.lastHealth and damageTracking.lastHealth > 0 then
        if DEBUG then
            print(string.format("[ANTI-CHEAT] Health increased from %d to %d (possible godmode)", 
                damageTracking.lastHealth, currentHealth))
        end
        
        TriggerServerEvent('cc_t:cheatDetected', 'godmode', {
            old_health = damageTracking.lastHealth,
            new_health = currentHealth,
            reason = "unexpected_health_increase"
        })
    end
    
    -- Check if player should be taking damage but isn't
    if shouldDamage and currentHealth >= damageTracking.lastHealth then
        damageTracking.consecutiveNoDamageEvents = damageTracking.consecutiveNoDamageEvents + 1
        
        if damageTracking.consecutiveNoDamageEvents >= damageTracking.DAMAGE_THRESHOLD then
            if DEBUG then
                print(string.format("[ANTI-CHEAT] Godmode detected - No damage taken when expected (reason: %s, events: %d)", 
                    reason, damageTracking.consecutiveNoDamageEvents))
            end
            
            TriggerServerEvent('cc_t:cheatDetected', 'godmode', {
                health = currentHealth,
                reason = "no_damage_when_expected",
                expected_damage_reason = reason,
                consecutive_events = damageTracking.consecutiveNoDamageEvents
            })
        end
    else
        damageTracking.consecutiveNoDamageEvents = 0
    end
    
    -- Update last health for next check
    damageTracking.lastHealth = currentHealth
end

-- Function to perform active godmode test
local function performGodmodeTest()
    local currentTime = GetGameTimer()
    local playerPed = PlayerPedId()
    local currentHealth = GetEntityHealth(playerPed)
    
    -- Only run test every 30 seconds and if player has enough health
    if currentTime - damageTracking.lastHealthTestTime > 30000 and currentHealth >= 200 and not damageTracking.damageTestInProgress then
        if DEBUG then
            print("[ANTI-CHEAT] Starting active godmode test")
        end
        
        damageTracking.damageTestInProgress = true
        local originalHealth = currentHealth
        local testStartTime = currentTime
        local testTimeout = 5000  -- 5 seconds max for the test
        local testCompleted = false
        
        -- Store current invincibility state and make player vulnerable
        local wasInvincible = GetPlayerInvincible(PlayerId())
        SetPlayerInvincible(PlayerId(), false)
        
        -- Create a melee attack to damage the player
        local function performMeleeAttack()
            if testCompleted then return end
            
            -- Apply melee damage (5 points) using SetEntityHealth
            local currentHealth = GetEntityHealth(playerPed)
            SetEntityHealth(playerPed, math.max(0, currentHealth - 5))
            
            -- Play hit effect
            StartScreenEffect("HitByKillerBunny", 100, false)
            
            -- Check result after a short delay
            Citizen.SetTimeout(100, function()
                local newHealth = GetEntityHealth(playerPed)
                
                if DEBUG then
                    print(string.format("[ANTI-CHEAT] Godmode test - Old Health: %d, New Health: %d", 
                        originalHealth, newHealth))
                end
                
                -- If health didn't change or increased, possible godmode
                if newHealth >= originalHealth then
                    if DEBUG then
                        print("[ANTI-CHEAT] Godmode detected (health didn't decrease)")
                    end
                    
                    TriggerServerEvent('cc_t:cheatDetected', 'godmode', {
                        old_health = originalHealth,
                        new_health = newHealth,
                        reason = "active_test_failed_melee"
                    })
                end
                
                -- Clean up
                if not testCompleted then
                    testCompleted = true
                    damageTracking.damageTestInProgress = false
                    damageTracking.lastHealthTestTime = GetGameTimer()
                    
                    -- Restore invincibility if it was enabled
                    if wasInvincible then
                        SetPlayerInvincible(PlayerId(), true)
                    end
                end
            end)
        end
        
        -- Perform the melee attack
        performMeleeAttack()
        
        -- Set a timeout to ensure we always clean up
        Citizen.SetTimeout(testTimeout, function()
            if not testCompleted then
                testCompleted = true
                damageTracking.damageTestInProgress = false
                damageTracking.lastHealthTestTime = GetGameTimer()
                
                -- Restore invincibility if it was enabled
                if wasInvincible then
                    SetPlayerInvincible(PlayerId(), true)
                end
                
                if DEBUG then
                    print("[ANTI-CHEAT] Godmode test timed out")
                end
            end
        end)
    end
end

-- Monitor player position and check for noclip
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(CHECK_INTERVAL)
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local currentTime = GetGameTimer()
        local timeSinceSpawn = currentTime - spawnTime
        
        -- Always send position to server (server handles spawn protection)
        TriggerServerEvent('cc_t:updatePosition', {
            x = playerCoords.x,
            y = playerCoords.y,
            z = playerCoords.z,
            inVehicle = IsPedInAnyVehicle(playerPed, false),
            onGround = IsPedOnFoot(playerPed) and not IsPedFalling(playerPed),
            time = currentTime
        })
        
        -- Update spawn protection status
        if isSpawnProtected and timeSinceSpawn >= SPAWN_PROTECTION_DURATION then
            isSpawnProtected = false
            isFirstSpawn = false
            if DEBUG then
                print("[ANTI-CHEAT] Spawn protection ended after 5 seconds")
            end
        end
        
        -- Only run checks if not in spawn protection
        if not isSpawnProtected and timeSinceSpawn >= SPAWN_PROTECTION_DURATION then
            -- Run godmode test periodically
            performGodmodeTest()
            
            -- Get player state
            local inVehicle = IsPedInAnyVehicle(playerPed, false)
            local onGround = not IsPedFalling(playerPed) and not IsPedJumpingOutOfVehicle(playerPed) and not IsPedInParachuteFreeFall(playerPed)
            local inWater = IsEntityInWater(playerPed)
                
            -- Get player speed for movement detection
            local velocity = GetEntityVelocity(playerPed)
            local speed3D = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)
            local speedKmh = speed3D * 3.6  -- Convert to km/h for logging
            
            -- Noclip detection moved to server-side for better security
                
            -- Always send position to server (server handles spawn protection)
            TriggerServerEvent('cc_t:updatePosition', {
                x = playerCoords.x,
                y = playerCoords.y,
                z = playerCoords.z,
                inVehicle = inVehicle,
                onGround = onGround,
                time = currentTime
            })
            
            -- Update position history
            lastPosition = {
                x = playerCoords.x,
                y = playerCoords.y,
                z = playerCoords.z,
                time = currentTime
            }
        end
    end
end)

-- Magic Bullet Detection (client-side evidence)
local MAGICBULLET_TRACE_FLAGS = 1 -- world only for strict cover detection

-- Small helpers
local function normalize(vec)
    local mag = math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
    if mag == 0 then return { x = 0.0, y = 0.0, z = 0.0 } end
    return { x = vec.x / mag, y = vec.y / mag, z = vec.z / mag }
end

local function vecSub(a, b)
    return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

local function dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

local function isAimReasonable(attacker, victim)
    if not DoesEntityExist(attacker) or not DoesEntityExist(victim) then return true end
    local atkFwd = GetEntityForwardVector(attacker)
    local atkPos = GetEntityCoords(attacker)
    local vicPos = GetEntityCoords(victim)
    local dir = normalize(vecSub(vicPos, atkPos))
    local angleDot = dot(atkFwd, dir)
    local dist = #(vector3(vicPos.x, vicPos.y, vicPos.z) - vector3(atkPos.x, atkPos.y, atkPos.z))
    if dist <= 8.0 then return true end
    return angleDot >= 0.25
end

-- Multi-ray robust LOS check, allow hitting victim or their vehicle
local function hasClearLos(attacker, victim)
    if not DoesEntityExist(attacker) or not DoesEntityExist(victim) then return true end

    if HasEntityClearLosToEntity(attacker, victim, MAGICBULLET_TRACE_FLAGS) then
        return true
    end

    local BONES = { 0x796E, 0x60F1, 0x2E28 } -- head, spine3, pelvis
    local atkHead = GetPedBoneCoords(attacker, 0x796E, 0.0, 0.0, 0.0)
    for _, targetBone in ipairs(BONES) do
        local vic = GetPedBoneCoords(victim, targetBone, 0.0, 0.0, 0.0)
        local offsets = {
            { x = 0.0, y = 0.0, z = 0.0 },
            { x = 0.0, y = 0.05, z = 0.15 },
            { x = 0.0, y = -0.05, z = -0.15 }
        }
        for _, off in ipairs(offsets) do
            local toX, toY, toZ = vic.x + off.x, vic.y + off.y, vic.z + off.z
            local handle = StartShapeTestRay(
                atkHead.x, atkHead.y, atkHead.z,
                toX, toY, toZ,
                MAGICBULLET_TRACE_FLAGS, attacker, 7
            )
            local _, hit, _, _, entityHit = GetShapeTestResultIncludingMaterial(handle)
            if hit ~= 1 then
                return true
            end
            if entityHit == victim then
                return true
            end
            if IsPedAPlayer(victim) then
                local veh = GetVehiclePedIsIn(victim, false)
                if veh ~= 0 and entityHit == veh then
                    return true
                end
            end
        end
    end
    return false
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local victim = args[1]
    local attacker = args[2]
    local weaponHash = args[4]
    if attacker == 0 or victim == 0 then return end
    if not DoesEntityExist(attacker) or not DoesEntityExist(victim) then return end
    if not IsPedAPlayer(victim) or not IsPedAPlayer(attacker) then return end

    local attackerPlayer = NetworkGetPlayerIndexFromPed(attacker)
    local victimPlayer = NetworkGetPlayerIndexFromPed(victim)
    if attackerPlayer == -1 or victimPlayer == -1 then return end

    local attackerServerId = GetPlayerServerId(attackerPlayer)
    local victimServerId = GetPlayerServerId(victimPlayer)

    -- Only process for armed (ballistic) attacker; skip unarmed/melee
    if not IsPedArmed(attacker, 6) then return end

    -- Weapon spoof client-side evidence: attacker not shooting or local weapon mismatch
    local isShooting = IsPedShooting(attacker)
    local selectedWeapon = GetSelectedPedWeapon(attacker)
    local WEAPON_EVIDENCE_COOLDOWN = 800
    _G_cc_weaponEvidenceCooldown = _G_cc_weaponEvidenceCooldown or {}
    local key = tostring(attackerServerId) .. ':' .. tostring(victimServerId)
    local nowTs = GetGameTimer()
    local lastTs = _G_cc_weaponEvidenceCooldown[key] or 0
    if (nowTs - lastTs) > WEAPON_EVIDENCE_COOLDOWN then
        if (not isShooting) or (selectedWeapon ~= weaponHash) then
            _G_cc_weaponEvidenceCooldown[key] = nowTs
            TriggerServerEvent('cc_t:weaponSpoofEvidence', attackerServerId, victimServerId, weaponHash, {
                is_shooting = isShooting,
                selected_weapon = selectedWeapon
            })
        end
    end

    -- Check LOS and aim sanity; report if either fails
    local losClear = hasClearLos(attacker, victim)
    local aimOk = isAimReasonable(attacker, victim)
    if (not losClear) or (not aimOk) then
        local atkPos = GetEntityCoords(attacker)
        local vicPos = GetEntityCoords(victim)
        TriggerServerEvent('cc_t:magicBulletEvidence', attackerServerId, victimServerId, weaponHash, {
            atk = { x = atkPos.x, y = atkPos.y, z = atkPos.z },
            vic = { x = vicPos.x, y = vicPos.y, z = vicPos.z },
            los = losClear,
            aim_ok = aimOk
        })

        -- If I am the victim, immediately restore health/armor to block wallbang effects locally
        if victim == PlayerPedId() then
            local currentHealth = GetEntityHealth(victim)
            local currentArmour = GetPedArmour(victim)
            if lastHealthSnapshot > 0 and currentHealth < lastHealthSnapshot then
                SetEntityHealth(victim, lastHealthSnapshot)
            end
            if currentArmour < lastArmourSnapshot then
                SetPedArmour(victim, lastArmourSnapshot)
            end
            if DEBUG then
                print('[ANTI-CHEAT] Magic bullet damage reverted locally (blocked LOS or aim off)')
            end
        end
    end
end)

-- Snapshot my health/armor continuously for local restore on illegal hits
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            lastHealthSnapshot = GetEntityHealth(ped)
            lastArmourSnapshot = GetPedArmour(ped)
        end
    end
end)

-- Weapon spoof proactive verification (detect before damage happens)
Citizen.CreateThread(function()
    local REPORT_COOLDOWN = 200
    local lastReport = 0
    local lastWeapon = 0
    while true do
        Citizen.Wait(100)

        -- Skip during spawn protection
        if isSpawnProtected then goto continue end

        local ped = PlayerPedId()
        if not DoesEntityExist(ped) then goto continue end

        local armed = IsPedArmed(ped, 6)
        local aiming = IsPlayerFreeAiming(PlayerId()) or IsControlPressed(0, 25)
        local shooting = IsPedShooting(ped)

        if armed then
            local w = GetSelectedPedWeapon(ped)
            local now = GetGameTimer()
            local shouldReport = (w ~= 0) and (
                (w ~= lastWeapon) or (aiming or shooting) or ((now - lastReport) > REPORT_COOLDOWN)
            )
            if shouldReport then
                lastReport = now
                lastWeapon = w
                local ammo = GetAmmoInPedWeapon(ped, w)
                TriggerServerEvent('cc_t:verifyWeapon', w, {
                    aiming = aiming,
                    shooting = shooting,
                    ammo = ammo
                })
            end
        end

        ::continue::
    end
end)

-- Freecam detection thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(FREECAM_CHECK_INTERVAL)

        -- Skip during spawn protection
        if isSpawnProtected then
            freecamSuspectStart = nil
            goto continue
        end

        local playerPed = PlayerPedId()
        if not DoesEntityExist(playerPed) then
            freecamSuspectStart = nil
            goto continue
        end

        -- Ignore safe states
        if IsPauseMenuActive() or IsPlayerSwitchInProgress() or IsPlayerDead(PlayerId()) then
            freecamSuspectStart = nil
            goto continue
        end

        -- Get ped and camera positions
        local pedCoords = GetEntityCoords(playerPed)
        local camCoords = GetFinalRenderedCamCoord()

        -- Distance between ped and camera
        local dx = camCoords.x - pedCoords.x
        local dy = camCoords.y - pedCoords.y
        local dz = camCoords.z - pedCoords.z
        local camDistance = math.sqrt(dx*dx + dy*dy + dz*dz)

        -- Consider in-vehicle cinematic camera: when in vehicle and cam is far, allow more distance
        local inVehicle = IsPedInAnyVehicle(playerPed, false)
        local allowedDistance = inVehicle and (FREECAM_MAX_CAM_DISTANCE * 2.0) or FREECAM_MAX_CAM_DISTANCE

        if camDistance > allowedDistance then
            if not freecamSuspectStart then
                freecamSuspectStart = GetGameTimer()
            end

            local elapsed = GetGameTimer() - freecamSuspectStart
            if elapsed >= FREECAM_MIN_DURATION then
                -- Rate limit reports
                local now = GetGameTimer()
                if (now - lastFreecamReport) > FREECAM_COOLDOWN then
                    lastFreecamReport = now
                    if DEBUG then
                        print(string.format('[ANTI-CHEAT] Freecam suspected: camDist=%.2f allowed=%.2f duration=%dms', camDistance, allowedDistance, elapsed))
                    end
                    TriggerServerEvent('cc_t:cheatDetected', 'freecam', {
                        cam_distance = camDistance,
                        allowed_distance = allowedDistance,
                        in_vehicle = inVehicle,
                        duration_ms = elapsed
                    })
                end
            end
        else
            freecamSuspectStart = nil
        end

        ::continue::
    end
end)

-- Anti Godmode
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Check for damage events
        local playerPed = PlayerPedId()
        local currentHealth = GetEntityHealth(playerPed)
        
        -- Detect damage taken
        if damageTracking.lastHealth > 0 and currentHealth < damageTracking.lastHealth then
            local damageAmount = damageTracking.lastHealth - currentHealth
            trackDamageEvent(damageAmount)
            
            if DEBUG then
                print(string.format("[ANTI-CHEAT] Damage detected: %d (new health: %d)", 
                    damageAmount, currentHealth))
            end
        end
        
        -- Update last health
        damageTracking.lastHealth = currentHealth
    end
end)

-- Start godmode detection
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check every second
        checkGodmode()
    end
end)

-- Set spawn time when player spawns
AddEventHandler('playerSpawned', function()
    spawnTime = GetGameTimer()
    isSpawnProtected = true
    lastPosition = GetEntityCoords(PlayerPedId())
    lastCheck = GetGameTimer()
    if DEBUG then
        print("[ANTI-CHEAT] Player spawned, spawn protection active for " .. (SPAWN_PROTECTION_DURATION/1000) .. " seconds")
    end
    
    -- Disable spawn protection after the timer expires
    Citizen.SetTimeout(SPAWN_PROTECTION_DURATION + 1000, function()
        isSpawnProtected = false
        if DEBUG then
            print("[ANTI-CHEAT] Spawn protection ended")
        end
    end)
end)

RegisterNetEvent('cc_t:warning')
AddEventHandler('cc_t:warning', function(message)
    TriggerEvent('chat:addMessage', {
        color = {255, 255, 0},
        multiline = false,
        args = {"WARNING", message}
    })
end)

-- Screenshot event handler
RegisterNetEvent('cc_anticheat:takeScreenshot')
AddEventHandler('cc_anticheat:takeScreenshot', function(webhook, reason)
    local playerPed = PlayerPedId()
    local playerName = GetPlayerName(PlayerId())
    local playerId = GetPlayerServerId(PlayerId())
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Take the screenshot
    exports['screenshot-basic']:requestScreenshotUpload(webhook, 'files[]', function(data)
        local image = json.decode(data)
        if image and image.attachments and image.attachments[1] then
            -- Send additional information to the server
            TriggerServerEvent('cc_anticheat:processScreenshot', 
                image.attachments[1].url, 
                reason,
                playerName,
                playerId,
                playerCoords
            )
        end
    end)
end)

-- Heartbeat System Configuration
local HEARTBEAT_INTERVAL = 5000 -- 5 seconds between heartbeats
local MAX_MISSED_PINGS = 3       -- Maximum allowed missed pings before disconnecting
local RECONNECT_ATTEMPTS = 3     -- Number of reconnect attempts before giving up

-- Heartbeat state
local isHeartbeatActive = false
local lastServerResponse = 0
local missedPings = 0
local reconnectAttempts = 0
local heartbeatTimeout = nil

-- Debug logging
local function debugLog(message, ...)
    if DEBUG then
        print(string.format('[HB] ' .. message, ...))
    end
end

-- Handle server pong response
RegisterNetEvent('cc_t:heartbeatPong')
AddEventHandler('cc_t:heartbeatPong', function()
    lastServerResponse = GetGameTimer()
    
    if missedPings > 0 then
        reconnectAttempts = 0
        missedPings = 0
        debugLog('Reconnected to server after %d missed pings', missedPings)
    end
    
    -- Reset the reconnect attempts counter on successful response
    if reconnectAttempts > 0 then
        reconnectAttempts = 0
        debugLog('Successfully reconnected to server')
    end
end)

-- Send heartbeat to server
local function sendHeartbeat()
    if not isHeartbeatActive then return end
    
    local currentTime = GetGameTimer()
    local timeSinceLastResponse = currentTime - lastServerResponse
    
    -- Check if we've missed too many pings
    if timeSinceLastResponse > (HEARTBEAT_INTERVAL * (MAX_MISSED_PINGS + 1)) then
        missedPings = missedPings + 1
        reconnectAttempts = reconnectAttempts + 1
        
        if reconnectAttempts > RECONNECT_ATTEMPTS then
            debugLog('Failed to reconnect after %d attempts, disconnecting...', reconnectAttempts)
            TriggerServerEvent('cc_t:heartbeatFailed')
            return
        end
        
        debugLog('No server response for %dms (Attempt %d/%d)', 
            timeSinceLastResponse, reconnectAttempts, RECONNECT_ATTEMPTS)
    end
    
    -- Send the heartbeat
    TriggerServerEvent('cc_t:heartbeat')
    
    -- Schedule the next heartbeat
    if heartbeatTimeout then
        ClearTimeout(heartbeatTimeout)
    end
    
    heartbeatTimeout = SetTimeout(HEARTBEAT_INTERVAL, sendHeartbeat)
end

-- Initialize the heartbeat system
local function initHeartbeat()
    -- Clear any existing timeouts
    if heartbeatTimeout then
        ClearTimeout(heartbeatTimeout)
        heartbeatTimeout = nil
    end
    
    -- Reset state
    isHeartbeatActive = true
    lastServerResponse = GetGameTimer()
    missedPings = 0
    reconnectAttempts = 0
    
    -- Start the heartbeat loop
    sendHeartbeat()
    debugLog('Heartbeat system started')
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    isHeartbeatActive = false
    if heartbeatTimeout then
        ClearTimeout(heartbeatTimeout)
        heartbeatTimeout = nil
    end
    debugLog('Heartbeat system stopped')
end)

-- Start the heartbeat when the player is ready
Citizen.CreateThread(function()
    -- Wait for the player to be fully loaded
    while not NetworkIsPlayerActive(PlayerId()) do
        Citizen.Wait(1000)
    end
    
    -- Small delay to ensure everything is ready
    Citizen.Wait(2000)
    
    -- Initialize the heartbeat system
    initHeartbeat()
    
    -- Re-initialize if the player respawns
    AddEventHandler('playerSpawned', function()
        Citizen.Wait(3000) -- Wait a bit after spawn
        if not isHeartbeatActive then
            initHeartbeat()
        end
    end)
end)

-- Notify server after player fully loaded
AddEventHandler('playerSpawned', function()
    Citizen.SetTimeout(3000, function() -- wait 3s after spawn
        TriggerServerEvent('cc_t:spawned')
    end)
end)