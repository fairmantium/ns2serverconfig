ModLoader.SetupFileHook( "lua/OrderSelfMixin.lua", "lua/UWEExtension/Build_319/OrderSelfMixin.lua", "post" )
ModLoader.SetupFileHook( "lua/Badges_Shared.lua", "lua/UWEExtension/Build_319/Badges_Shared.lua", "post" )
ModLoader.SetupFileHook( "lua/AchievementGiverMixin.lua", "lua/UWEExtension/Build_319/AchievementGiverMixin.lua", "post" )
ModLoader.SetupFileHook( "lua/Marine.lua", "lua/UWEExtension/Build_319/Marine.lua", "replace" )
ModLoader.SetupFileHook( "lua/MarineActionFinderMixin.lua", "lua/UWEExtension/Build_319/MarineActionFinderMixin.lua", "replace" )

gUWEBalanceLoaded = false

--Check for diabling global
if gDisableUWEBalance then return end