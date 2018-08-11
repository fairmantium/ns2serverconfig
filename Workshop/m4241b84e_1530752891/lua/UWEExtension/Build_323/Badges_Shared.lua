------------------------------------------
--  Create basic badge tables
------------------------------------------

Log("UWE-EXTENSION Badges_Shared.lua loaded.")

-- Max number of available badge columns
kMaxBadgeColumns = 10

--List of all avaible badges
gBadges = {
    "disabled",
    "none",
    "dev",
    "dev_retired",
    "maptester",
    "playtester",
    "ns1_playtester",
    "constellation",
    "hughnicorn",
    "squad5_blue",
    "squad5_silver",
    "squad5_gold",
    "commander",
    "community_dev",
    "reinforced1",
    "reinforced2",
    "reinforced3",
    "reinforced4",
    "reinforced5",
    "reinforced6",
    "reinforced7",
    "reinforced8",
    "wc2013_supporter",
    "wc2013_silver",
    "wc2013_gold",
    "wc2013_shadow",
    "pax2012",
    "ensl_2017",
    "ensl_nc_2017_blue",
    "ensl_nc_2017_silver",
    "ensl_nc_2017_gold",
    "ensl_wc_gold",
    "ensl_wc_silver",
    "ensl_wc_bronze",
    "tournament_mm_blue",
    "tournament_mm_silver",
    "tournament_mm_gold",
    "ensl_s11_gold",
    "ensl_s11_silver",
    "skulk_challenge_1_bronze",
    "skulk_challenge_1_silver",
    "skulk_challenge_1_gold",
    "skulk_challenge_1_shadow",
    "ensl_nc_2017_late_blue",
    "ensl_nc_2017_late_silver",
    "ensl_nc_2017_late_gold",
    "ensl_s12_d1_gold",
    "ensl_s12_d1_silver",
    "ensl_s12_d1_bronze",
    "ensl_s12_d2_gold",
    "ensl_s12_d2_silver",
    "ensl_s12_d2_bronze",
    "ensl_s12_d3_gold",
    "ensl_s12_d3_silver",
    "ensl_s12_d3_bronze",
}

--Stores information about textures and names of the Badges
local badgeData = {}

--scope this properly so the GC can clean up directly afterwards
do
    local function MakeBadgeData2(name, ddsPrefix)
        return {
            name = string.upper(string.format("BADGE_%s", name)),
            unitStatusTexture = string.format("ui/badges/%s.dds", ddsPrefix),
            scoreboardTexture = string.format("ui/badges/%s_20.dds", ddsPrefix),
            columns = 960, --column 7,8,9,10
            isOfficial = true,
        }
    end

    local function MakeBadgeData3(name, ddsPrefix)
        return {
            name = string.upper(string.format("BADGE_%s", name)),
            unitStatusTexture = string.format("ui/badges/%s.dds", ddsPrefix),
            scoreboardTexture = string.format("ui/badges/%s.dds", ddsPrefix),
            columns = 960, --column 7,8,9,10
            isOfficial = true,
        }
    end

    local function MakeBadgeData(name)
        return MakeBadgeData2(name, name)
    end

    local function MakeDLCBadgeInfo(name, ddsPrefix, productId)
        local info = MakeBadgeData3(name, ddsPrefix)

        info.productId = productId

        return info
    end

    local function MakeItemBadgeData(name, itemId)
        local data = MakeBadgeData3(name, name)

        data.itemId = itemId

        return data
    end

    local function MakeItemBadgeData2(name, ddsPrefix, itemId)
        local data = MakeBadgeData3(name, ddsPrefix)

        data.itemId = itemId

        return data
    end
    
    -- Creates a badge whose availability is tied to which player stats.
    -- badgeName is name of badge and prefix for badge file name.
    -- statName is the api name of the steam user stat associated with the badge.
    -- hasBadgeFunction is evaluated with the value of the stat passed as the only paramter.  If it returns true, this
    --      means the badge is available.  False of course means the badge is not available.
    local function MakeStatsBadgeData(badgeName, statName, statType, hasBadgeFunction)
        
        local data = MakeBadgeData(badgeName)
        
        data.statName = statName
        data.statType = statType
        data.hasBadgeFunction = hasBadgeFunction
        
        return data
        
    end
    
    --vanilla badges data
    badgeData["dev"] = MakeBadgeData("dev")
    badgeData["dev_retired"] = MakeBadgeData("dev_retired")
    badgeData["maptester"] = MakeBadgeData("maptester")
    badgeData["playtester"] = MakeBadgeData("playtester")
    badgeData["ns1_playtester"] = MakeBadgeData("ns1_playtester")
    badgeData["constellation"] = MakeBadgeData2("constellation", "constelation")
    badgeData["hughnicorn"] = MakeBadgeData("hughnicorn")
    badgeData["squad5_blue"] = MakeBadgeData("squad5_blue")
    badgeData["squad5_silver"] = MakeBadgeData("squad5_silver")
    badgeData["squad5_gold"] = MakeBadgeData("squad5_gold")
    badgeData["commander"] = MakeBadgeData("commander")
    badgeData["community_dev"] = MakeBadgeData("community_dev")
    badgeData["reinforced1"] = MakeBadgeData2("reinforced1", "game_tier1_blue")
    badgeData["reinforced2"] = MakeBadgeData2("reinforced2", "game_tier2_silver")
    badgeData["reinforced3"] = MakeBadgeData2("reinforced3", "game_tier3_gold")
    badgeData["reinforced4"] = MakeBadgeData2("reinforced4", "game_tier4_diamond")
    badgeData["reinforced5"] = MakeBadgeData2("reinforced5", "game_tier5_shadow")
    badgeData["reinforced6"] = MakeBadgeData2("reinforced6", "game_tier6_onos")
    badgeData["reinforced7"] = MakeBadgeData2("reinforced7", "game_tier7_Insider")
    badgeData["reinforced8"] = MakeBadgeData2("reinforced8", "game_tier8_GameDirector")
    badgeData["wc2013_supporter"] = MakeBadgeData("wc2013_supporter")
    badgeData["wc2013_silver"] = MakeBadgeData("wc2013_silver")
    badgeData["wc2013_gold"] = MakeBadgeData("wc2013_gold")
    badgeData["wc2013_shadow"] = MakeBadgeData("wc2013_shadow")
    badgeData["pax2012"] = MakeDLCBadgeInfo("pax2012", "badge_pax2012", 4931)
    badgeData["ensl_2017"] = MakeItemBadgeData("ensl_2017", 1001)
    badgeData["ensl_nc_2017_blue"] = MakeItemBadgeData("ensl_nc_2017_blue", 1004)
    badgeData["ensl_nc_2017_silver"] = MakeItemBadgeData("ensl_nc_2017_silver", 1003)
    badgeData["ensl_nc_2017_gold"] = MakeItemBadgeData("ensl_nc_2017_gold", 1002)
    badgeData["ensl_wc_gold"] = MakeItemBadgeData("ensl_wc_gold", 1005)
    badgeData["ensl_wc_silver"] = MakeItemBadgeData("ensl_wc_silver", 1006)
    badgeData["ensl_wc_bronze"] = MakeItemBadgeData("ensl_wc_bronze", 1007)
    badgeData["tournament_mm_blue"] = MakeItemBadgeData("tournament_mm_blue", 1008)
    badgeData["tournament_mm_silver"] = MakeItemBadgeData("tournament_mm_silver", 1009)
    badgeData["tournament_mm_gold"] = MakeItemBadgeData("tournament_mm_gold", 1010)
    badgeData["ensl_s11_gold"] = MakeItemBadgeData("ensl_s11_gold", 1011)
    badgeData["ensl_s11_silver"] = MakeItemBadgeData("ensl_s11_silver", 1012)
    badgeData["ensl_nc_2017_late_blue"] = MakeItemBadgeData2("ensl_nc_2017_late_blue", "ensl_nc_2017_blue", 1015)
    badgeData["ensl_nc_2017_late_silver"] = MakeItemBadgeData2("ensl_nc_2017_late_silver", "ensl_nc_2017_silver", 1014)
    badgeData["ensl_nc_2017_late_gold"] = MakeItemBadgeData2("ensl_nc_2017_late_gold", "ensl_nc_2017_gold", 1013)
    badgeData["ensl_s12_d1_gold"] = MakeItemBadgeData2("ensl_s12_d1_gold", "ensl_2018_gold", 1016)
    badgeData["ensl_s12_d1_silver"] = MakeItemBadgeData2("ensl_s12_d1_silver", "ensl_2018_silver", 1017)
    badgeData["ensl_s12_d1_bronze"] = MakeItemBadgeData2("ensl_s12_d1_bronze", "ensl_2018_bronze", 1018)
    badgeData["ensl_s12_d2_gold"] = MakeItemBadgeData2("ensl_s12_d2_gold", "ensl_2018_gold", 1019)
    badgeData["ensl_s12_d2_silver"] = MakeItemBadgeData2("ensl_s12_d2_silver", "ensl_2018_silver", 1020)
    badgeData["ensl_s12_d2_bronze"] = MakeItemBadgeData2("ensl_s12_d2_bronze", "ensl_2018_bronze", 1021)
    badgeData["ensl_s12_d3_gold"] = MakeItemBadgeData2("ensl_s12_d3_gold", "ensl_2018_gold", 1022)
    badgeData["ensl_s12_d3_silver"] = MakeItemBadgeData2("ensl_s12_d3_silver", "ensl_2018_silver", 1023)
    badgeData["ensl_s12_d3_bronze"] = MakeItemBadgeData2("ensl_s12_d3_bronze", "ensl_2018_bronze", 1024)

    -- stats badges
    badgeData["skulk_challenge_1_bronze"] = MakeStatsBadgeData("skulk_challenge_1_bronze", "skulk_challenge_1", "INT",
        function(value)
            return value >= 1
        end)
    badgeData["skulk_challenge_1_silver"] = MakeStatsBadgeData("skulk_challenge_1_silver", "skulk_challenge_1", "INT",
        function(value)
            return value >= 2
        end)
    badgeData["skulk_challenge_1_gold"] = MakeStatsBadgeData("skulk_challenge_1_gold", "skulk_challenge_1", "INT",
        function(value)
            return value >= 3
        end)
    badgeData["skulk_challenge_1_shadow"] = MakeStatsBadgeData("skulk_challenge_1_shadow", "skulk_challenge_1", "INT",
        function(value)
            return value >= 4
        end)

    --custom badges
    local badgeFiles = {}
    local officialFiles = {}

    Shared.GetMatchingFileNames( "ui/badges/*.dds", false, badgeFiles )

    for _, badge in ipairs(gBadges) do
        local data = badgeData[badge]
        if data then
            officialFiles[data.unitStatusTexture] = true
            officialFiles[data.scoreboardTexture] = true
            officialFiles[badge] = true
        end
    end

    for _, badgeFile in ipairs(badgeFiles) do
        if not officialFiles[badgeFile] then
            local _, _, badgeName = string.find( badgeFile, "ui/badges/(.*).dds" )

            if not officialFiles[badgeName] and not badgeData[badgeName] then --avoid custom badges named like official badges
                local badgeId = #gBadges + 1

                gBadges[badgeId] = badgeName

                badgeData[badgeName] = {
                    name = "Custom Badge", --Todo Localize
                    unitStatusTexture = badgeFile,
                    scoreboardTexture = badgeFile,
                    columns = 16, --column 5
                }
            end
        end
    end

    gBadges = enum(gBadges)

    --List of all badges which are assigned to a DLC
    gDLCBadges = {}

    --List of all badges which are assigned to an item
    gItemBadges = {}

    -- List of all badges which are awarded based on the user's steam stats.
    gStatsBadges = {}

    for badgeId, badgeName in ipairs(gBadges) do
        local badgedata = badgeData[badgeName]
        if badgedata then

            if badgedata.productId then
                gDLCBadges[#gDLCBadges+1] = badgeId
            end

            if badgedata.itemId then
                gItemBadges[#gItemBadges+1] = badgeId
            end

            if badgedata.statName then
                gStatsBadges[#gStatsBadges+1] = badgeId
        end

    end
end
end

function Badges_GetBadgeData(badgeId)
    local enumVal = rawget(gBadges, badgeId)
    if not enumVal then return nil end
    return badgeData[enumVal]
end

function Badges_SetName(badgeId, name)
    
    -- ensure badge exists in the enum.
    local enumVal = rawget(gBadges, badgeId)
    if not enumVal then return false end
    
    if not badgeData[gBadges[badgeId]] or not name then return false end

    badgeData[gBadges[badgeId]].name = tostring(name)

    return true
end

-- Returns maximum amount of different badges each player can have selected
function Badges_GetMaxBadges()
    return 10
end

function GetBadgeFormalName(badgename)
    local fullString = badgename and Locale.ResolveString(badgename)

    return fullString or "Custom Badge"
end

--Assign badges based on dlc available
function Badges_FetchBadgesFromDLC(badges, client)
    for _, badgeid in ipairs(gDLCBadges) do
        local data = Badges_GetBadgeData(badgeid)
        if data and GetHasDLC(data.productId, client) then
            badges[#badges + 1] = gBadges[badgeid]
        end
    end

    return badges
end

--Assign badges based on items available
function Badges_FetchBadgesFromItems(badges)
    for _, badgeid in ipairs(gItemBadges) do
        local data = Badges_GetBadgeData(badgeid)
        if data and GetOwnsItem(data.itemId) then
            badges[#badges + 1] = gBadges[badgeid]
        end
    end

    return badges
end

local function GetAreStatsAvailable(client)
    
    if Client then
        return true -- should always be loaded on client, long before they even join a game.
    elseif Server then
        
        if not client then
            return false
        end
        
        for _, badgeId in ipairs(gStatsBadges) do
            
            local data = Badges_GetBadgeData(badgeId)
            if data then
                local apiFunc
                if data.statType == "INT" then
                    apiFunc = Server.GetHasUserStat_Int
                elseif data.statType == "FLOAT" then
                    apiFunc = Server.GetHasUserStat_Float
                end
                
                if apiFunc and apiFunc(client, data.statName) then
                    -- When stats are downloaded from Steam, they're all sent at once.  Therefore if we have at least one
                    -- present, we know we have all we're ever going to get. If some are missing, we'll just discard them,
                    -- but it will generate an error message, as it should.
                    return true
                end
            end
            
        end
        
    end
    
    return false
    
end

-- Assign badges based on user stats
function Badges_FetchBadgesFromStats(badges, client)
    
    -- Don't attempt to retrieve stat data if it's missing -- we'll get errors for that!
    if not GetAreStatsAvailable(client) then
        
        if Server then
            -- Request stats from Steam.  When we receive them, this function will be called again.
            Server.RequestUserStats(client)
        end
        
        return badges
    end
    
    local sanityTest = Server
    
    for _, badgeid in ipairs(gStatsBadges) do
        
        local data = Badges_GetBadgeData(badgeid)
        if data then
            local statValue
            
            if Server then
                
                local apiFunc
                if data.statType == "INT" then
                    apiFunc = Server.GetUserStat_Int
                elseif data.statType == "FLOAT" then
                    apiFunc = Server.GetUserStat_Float
                else
                    assert(false)
                end
                
                statValue = apiFunc(client, data.statName)
                
            elseif Client then
                
                local apiFunc
                if data.statType == "INT" then
                    apiFunc = Client.GetUserStat_Int
                elseif data.statType == "FLOAT" then
                    apiFunc = Client.GetUserStat_Float
                else
                    assert(false)
                end
                
                statValue = apiFunc(data.statName)
                
            else
                assert(false)
            end
            
            local hasBadge = data.hasBadgeFunction(statValue)
            if hasBadge then
                badges[#badges + 1] = gBadges[badgeid]
            end
            
        end
        
    end
    
    return badges
    
end

------------------------------------------
--  Create network message spec
------------------------------------------

--Used to network displayed Badges from Server to Client
function BuildDisplayBadgeMessage(clientId, badge, column)
    return {
        clientId = clientId,
        badge = badge,
        column = column
    }
end

local kBadgesMessage = 
{
    clientId = "entityid",
    badge = "enum gBadges",
    column = string.format("integer (0 to %s)", kMaxBadgeColumns)
}
Shared.RegisterNetworkMessage("DisplayBadge", kBadgesMessage)

--Used to network the badge selection of the client to the server
function BuildSelectBadgeMessage(badge, column)
    return {
        badge = badge,
        column = column
    }
end

local kBadgesMessage =
{
    badge = "enum gBadges",
    column = string.format("integer (0 to %s)", kMaxBadgeColumns)
}
Shared.RegisterNetworkMessage("SelectBadge", kBadgesMessage)

--Used to network the allowed columns of a badge from the server to the client
--columns are represented as bitsmask from right to left: 1 = first column, 2(bin: 10) = second column
function BuildBadgeRowsMessage(badge, columns)
    return {
        badge = badge,
        columns = columns
    }
end

local kBadgeRowsMessage =
{
    badge = "enum gBadges",
    columns = string.format("integer (0 to %s)", 2^(kMaxBadgeColumns+1)-1)
}

Shared.RegisterNetworkMessage("BadgeRows", kBadgeRowsMessage)

--Used to send the badge names to the client
local kBadgeBroadcastMessage =
{
    badge = "enum gBadges",
    name = "string (128)"
}

Shared.RegisterNetworkMessage("BadgeName", kBadgeBroadcastMessage)
