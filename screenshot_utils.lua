local Config = Config or {}

-- Function to take a screenshot of a player's screen
function TakePlayerScreenshot(playerId, reason)
    local target = tonumber(playerId)
    if not target then return end
    
    -- Trigger the screenshot on the player's client
    TriggerClientEvent('cc_anticheat:takeScreenshot', target, Config.DiscordWebhook, reason)
end

-- Function to send a message to Discord
function SendToDiscord(webhook, title, description, color, fields, image)
    local embed = {
        {
            ["title"] = title,
            ["description"] = description,
            ["color"] = color or 16711680, -- Red color by default
            ["fields"] = fields or {},
            ["footer"] = {
                ["text"] = "Anti-Cheat System | " .. os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }
    
    if image then
        embed[1]["image"] = {["url"] = image}
    end
    
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', 
        json.encode({
            username = "Anti-Cheat System",
            embeds = embed,
            avatar_url = "https://i.imgur.com/example.png" -- Replace with your logo
        }), 
        { ['Content-Type'] = 'application/json' })
end
