--[[
    Shine Rookies Only - Shared
]]
local Shine = Shine
local Plugin = {}

Shine:RegisterExtension( "rookiesonly", Plugin, {
    Base = "hiveteamrestriction",
    BlacklistKeys = {
        BuildBlockMessage = true,
        OnFirstThink = true
    }
} )

