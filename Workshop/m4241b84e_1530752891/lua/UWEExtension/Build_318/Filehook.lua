ModLoader.SetupFileHook( "lua/Seasons.lua", "lua/UWEExtension/Build_318/Seasons.lua", "post" )

gUWEBalanceLoaded = false

--Check for diabling global
if gDisableUWEBalance then return end