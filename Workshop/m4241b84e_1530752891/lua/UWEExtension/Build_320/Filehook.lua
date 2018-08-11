ModLoader.SetupFileHook( "lua/Balance.lua", "lua/UWEExtension/Build_320/Balance.lua", "post" )
ModLoader.SetupFileHook( "lua/DamageTypes.lua", "lua/UWEExtension/Build_320/DamageTypes.lua", "post" )
ModLoader.SetupFileHook( "lua/Weapons/Marine/Flame.lua", "lua/UWEExtension/Build_320/Flame.lua", "post" )

--Check for diabling global
if gDisableUWEBalance then return end