fx_version 'cerulean'
game 'gta5'

description 'sniffle Anticheat - Advanced Anti-Cheat with Screenshot Evidence'

author 'Your Name'
version '1.1.0'

-- Shared configuration
shared_scripts {
    'config.lua'  -- Shared configuration variables
}

-- Server-side scripts
server_scripts {
    '@mysql-async/lib/MySQL.lua',  -- Required for MySQL operations
    'server.lua',                 -- Main server-side anti-cheat logic
    'screenshot_utils.lua'        -- Screenshot utility functions
}

-- Client-side scripts
client_scripts {
    'client.lua',          -- Main client-side anti-cheat logic
    'clickMonitor.js'      -- Click monitoring for anti-cheat
}

-- Dependencies
dependencies {
    'oxmysql',                    -- Required for database operations
    'screenshot-basic',           -- Required for taking screenshots
    'mysql-async'                 -- Required for async MySQL operations
    -- 'es_extended'              -- If you're using ESX framework (uncomment if needed)
}

-- UI files (if you add any)
-- ui_page 'html/index.html'
-- files {
--     'html/index.html',
--     'html/style.css',
--     'html/script.js'
-- }
