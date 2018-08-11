-- ======= Copyright (c) 2012, Unknown Worlds Entertainment, Inc. All rights reserved. ==========
--
-- lua\ServerConfig.lua
--
--    Created by:   Brian Cronin (brianc@unknownworlds.com)
--
-- ========= For more information, visit us at http:\\www.unknownworlds.com =====================

Shared.Message("UWE-EXTENSION ServerConfig.lua loaded.")

Script.Load("lua/Seasons.lua")
Script.Load("lua/ConfigFileUtility.lua")

-- How often to update key/value pairs on the server.
local kKeyValueUpdateRate = 5

-- The last time key value pairs were updated.
local lastKeyValueUpdateTime = 0

local configFileName = "ServerConfig.json"

local defaultConfig =
{
    settings =
    {
        rookie_only = false,
        rookie_only_bots = 12,
        filler_bots = 12,
        force_even_teams_on_join = true,
        auto_team_balance =
        {
            enabled = true,
            enabled_on_unbalance_amount = 2,
            enabled_after_seconds = 10
        },
        end_round_on_team_unbalance = 0.4,
        end_round_on_team_unbalance_check_after_time = 300,
        end_round_on_team_unbalance_after_warning_time = 30,
        auto_kick_afk_time = 300,
        auto_kick_afk_capacity = 0.5,
        voting =
        {
            votekickplayer = true,
            votekick_bantime = 2,
            votechangemap = true, 
            voteresetgame = true, 
            voterandomizerr = true, 
            votingforceeventeams = true,
            voteaddcommanderbots = true
        },
        auto_vote_add_commander_bots = true,
        alltalk = false,
        pregamealltalk = false,
        hiveranking = true,
        use_own_consistency_config = false,
        consistency_enabled = true,
        jit_maxmcode=35000,
        jit_maxtrace=20000,
        mod_backup_servers = {},
        mod_backup_before_steam = false,
        dyndns = "",
        enabledyndns = false,
        quickplay_ready = true,
        season = "",
        season_month = 0,
        max_http_requests = 8,
        debug_bot_manager = false,
    },
    tags = { "" }
}

local config = LoadConfigFile(configFileName, defaultConfig, true)
Server.SetModBackupServers(config.settings.mod_backup_servers, config.settings.mod_backup_before_steam)

--Auto Seasons
do
    SetServerSeason(config.settings.season, config.season_month)

    if config.settings.quickplay_ready == false then
        Shared.Message("Tagged server as unavailable for quick play as set by the server config.")
        Server.DisableQuickPlay()
    end
    
    if not Server.SetMaxHttpRequestsLimit(config.settings.max_http_requests) then
        Log("Failed to set HTTP requests limit, using default value of 8. Verify value is in range of [0 - 20]")
    end
end

local reservedSlotsConfigFileName = "ReservedSlotsConfig.json"
local reservedSlotsDefaultConfig = { 
    amount = 0, 
    ids = { }
}
local reservedSlotsConfig = LoadConfigFile(reservedSlotsConfigFileName, reservedSlotsDefaultConfig)

function Server.GetConfigSetting(name)

    if config.settings then
        return config.settings[name]
    end

end

local kServerIp = IPAddressToString(Server.GetIpAddress())
do
    -- Add the tags to the server if they exist in the file.
    if config.tags then

        for t = 1, #config.tags do

            if not type(config.tags[t]) == "string" then
                Shared.Message("Warning: Tags in " .. configFileName .. " must be strings")
            else
                Server.AddTag(config.tags[t])
            end

        end

    end

    --set up the dyndns
    local dyndns = Server.GetConfigSetting("enabledyndns") and Server.GetConfigSetting("dyndns") or ""
    if dyndns ~= "" then
        kServerIp = dyndns
        Server.SetKeyValue("sv_dyndns", dyndns)
    end
end

--Returns the server's ip address or dns as string
function Server.GetIpAddress()
    return kServerIp
end

function Server.GetHasTag(tag)

    for i = 1, #config.tags do
        if config.tags[i] == tag then
            return true
        end
    end

    return false

end

function Server.GetIsRookieFriendly()
    return Server.GetHasTag("rookie")
end

--[[
 * This can be used to override a setting. This will
 * not be saved to the config setting.
]]
function Server.SetConfigSetting(name, setting)
    config.settings[name] = setting
end

Event.Hook("Console_debug_bot_manager", function(client, state)
    config.settings["debug_bot_manager"] = (state == "true")
    Log("setting debug_bot_manager to %s", config.settings.debug_bot_manager)
end)

function Server.SaveConfigSettings()
    SaveConfigFile(configFileName, config)
end

function Server.GetReservedSlotsConfig()
    return reservedSlotsConfig
end

function Server.SaveReservedSlotsConfig()
    SaveConfigFile(reservedSlotsConfigFileName, reservedSlotsConfig)
end

--[[
 * This function should be called once per tick. It will update continuous data
]]
local function UpdateServerConfig()

    if Shared.GetSystemTime() - lastKeyValueUpdateTime >= kKeyValueUpdateRate then

        -- This isn't used by the server browser, but it is used by stats monitoring systems    
        Server.SetKeyValue("tickrate", ToString(math.floor(Server.GetFrameRate())))
        Server.SetKeyValue("ent_count", ToString(Shared.GetEntitiesWithClassname("Entity"):GetSize()))
        lastKeyValueUpdateTime = Shared.GetSystemTime()
             
    end
    
end


Event.Hook("UpdateServer", UpdateServerConfig)

