ModLoader.SetupFileHook( "lua/bots/Bot.lua", "lua/UWEExtension/Build_322/Bot.lua", "replace" )
ModLoader.SetupFileHook( "lua/bots/BotTeamController.lua", "lua/UWEExtension/Build_322/BotTeamController.lua", "post" )
ModLoader.SetupFileHook( "lua/bots/PlayerBot.lua", "lua/UWEExtension/Build_322/PlayerBot.lua", "post" )
ModLoader.SetupFileHook( "lua/VotingAddCommanderBots.lua", "lua/UWEExtension/Build_322/VotingAddCommanderBots.lua", "replace")
ModLoader.SetupFileHook( "lua/NS2Gamerules.lua", "lua/UWEExtension/Build_322/NS2Gamerules.lua", "post")

ModLoader.SetupFileHook( "lua/Marine.lua", "lua/UWEExtension/Build_322/Marine.lua", "post" )
ModLoader.SetupFileHook( "lua/StunMixin.lua", "lua/UWEExtension/Build_322/StunMixin.lua", "post" )

gUWEBalanceLoaded = false

--Check for diabling global
if gDisableUWEBalance then return end