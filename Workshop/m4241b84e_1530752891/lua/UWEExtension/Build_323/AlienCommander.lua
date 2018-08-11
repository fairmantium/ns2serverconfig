-- ======= Copyright (c) 2003-2012, Unknown Worlds Entertainment, Inc. All rights reserved. =====
--
-- lua\AlienCommander.lua
--
--    Created by:   Charlie Cleveland (charlie@unknownworlds.com)
--
-- Handled Commander movement and actions.
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================

Log("UWE-EXTENSION AlienCommander.lua loaded.")

Script.Load("lua/Commander.lua")
Script.Load("lua/CommAbilities/Alien/NutrientMist.lua")
Script.Load("lua/CommAbilities/Alien/Rupture.lua")
Script.Load("lua/CommAbilities/Alien/BoneWall.lua")
Script.Load("lua/CommAbilities/Alien/Contamination.lua")

Script.Load("lua/Alien.lua") -- should already be loaded... but want to make sure it's loaded first.

class 'AlienCommander' (Commander)

AlienCommander.kMapName = "alien_commander"

local networkVars =
{
    shellCount = "private integer (0 to 3)",
    spurCount = "private integer (0 to 3)",
    veilCount = "private integer (0 to 3)",
}

AlienCommander.kOrderClickedEffect = PrecacheAsset("cinematics/alien/order.cinematic")
AlienCommander.kSelectSound = PrecacheAsset("sound/NS2.fev/alien/commander/select")
AlienCommander.kChatSound = PrecacheAsset("sound/NS2.fev/alien/common/chat")
AlienCommander.kUpgradeCompleteSoundName = PrecacheAsset("sound/NS2.fev/alien/voiceovers/upgrade_complete")
AlienCommander.kResearchCompleteSoundName = PrecacheAsset("sound/NS2.fev/alien/voiceovers/research_complete")
AlienCommander.kManufactureCompleteSoundName = PrecacheAsset("sound/NS2.fev/alien/voiceovers/follow_me")
-- TODO: replace with "objective completed" voiceover once it's available
AlienCommander.kObjectiveCompletedSoundName = PrecacheAsset("sound/NS2.fev/alien/skulk/taunt")
AlienCommander.kStructureUnderAttackSound = PrecacheAsset("sound/NS2.fev/alien/voiceovers/structure_under_attack")
AlienCommander.kHarvesterUnderAttackSound = PrecacheAsset("sound/NS2.fev/alien/voiceovers/harvester_under_attack")
AlienCommander.kSoldierNeedsMistSoundName = PrecacheAsset("sound/NS2.fev/alien/voiceovers/need_healing")
AlienCommander.kSoldierNeedsEnzymeSoundName = PrecacheAsset("sound/NS2.fev/alien/voiceovers/need_healing")
AlienCommander.kSoldierNeedsHarvesterSoundName = PrecacheAsset("sound/NS2.fev/alien/voiceovers/more")
AlienCommander.kCragUnderAttackSound = PrecacheAsset("sound/NS2.fev/alien/structures/crag/wound")
AlienCommander.kHydraUnderAttackSound = PrecacheAsset("sound/NS2.fev/alien/structures/hydra/wound")
AlienCommander.kShadeUnderAttackSound = PrecacheAsset("sound/NS2.fev/alien/structures/shade/wound")
AlienCommander.kWhipUnderAttackSound = PrecacheAsset("sound/NS2.fev/alien/structures/whip/wound")
AlienCommander.kLifeformUnderAttackSound = PrecacheAsset("sound/NS2.fev/alien/voiceovers/lifeform_under_attack")
AlienCommander.kCommanderEjectedSoundName = PrecacheAsset("sound/NS2.fev/alien/voiceovers/commander_ejected")

AlienCommander.kMoveToWaypointSoundName = PrecacheAsset("sound/NS2.fev/alien/voiceovers/follow_me")
AlienCommander.kAttackOrderSoundName = PrecacheAsset("sound/NS2.fev/alien/voiceovers/game_start")
AlienCommander.kBuildStructureSound = PrecacheAsset("sound/NS2.fev/alien/voiceovers/follow_me")
AlienCommander.kHealTarget = PrecacheAsset("sound/NS2.fev/alien/voiceovers/need_healing")

AlienCommander.kSpendResourcesSoundName =  PrecacheAsset("sound/NS2.fev/alien/commander/spend_nanites")
AlienCommander.kSpendTeamResourcesSoundName =  PrecacheAsset("sound/NS2.fev/alien/commander/spend_metal")
AlienCommander.kBoneWallSpawnSound = PrecacheAsset("sound/NS2.fev/alien/common/infestation_spikes")
AlienCommander.kShiftHatch = PrecacheAsset("sound/NS2.fev/alien/structures/shift/recall")
AlienCommander.kHealWaveSound = PrecacheAsset("sound/NS2.fev/alien/common/frenzy")
AlienCommander.kShadeInkSound = PrecacheAsset("sound/NS2.fev/alien/structures/whip/fury")
AlienCommander.kCreateCystSound = PrecacheAsset("sound/NS2.fev/alien/commander/DI_drop_2D")
AlienCommander.kCreateMistSound = PrecacheAsset("sound/NS2.fev/alien/commander/catalyze_2D")
AlienCommander.kRupterSound = PrecacheAsset("sound/NS2.fev/alien/structures/generic_spawn_large")
AlienCommander.kContaminationSound = PrecacheAsset("sound/NS2.fev/alien/gorge/babbler_ball_hit")

local kHoverSound = PrecacheAsset("sound/NS2.fev/alien/commander/hover")

local function GetNearest(self, className)

    local ents = GetEntitiesForTeam(className, self:GetTeamNumber())
    Shared.SortEntitiesByDistance(self:GetOrigin(), ents)
    
    return ents[1]

end

if Client then

    local function CreateCursorLight()

        local cursorLight = Client.CreateRenderLight()
        cursorLight:SetType(RenderLight.Type_Point)
        cursorLight:SetCastsShadows(true)
        cursorLight:SetRadius(8)
        cursorLight:SetIntensity(3)
        cursorLight:SetColor(Color(1, 0.2, 0, 1))
        return cursorLight
        
    end
    
    ClientResources.AddResource("CursorLight", "AlienCommander", CreateCursorLight, Client.DestroyRenderLight)
    
end

function AlienCommander:OnCreate()

    Commander.OnCreate(self)
    
    if Server then 
        
        local mask = bit.bor(kRelevantToReadyRoom, kRelevantToTeam2Unit, kRelevantToTeam2Commander)        
        self:SetExcludeRelevancyMask(mask)    
    
    end

end

-- Copy over some functions from Alien.lua for alien commander.  This probably should be a mixin...
AlienCommander.GetUpgradeLevel = Alien.GetUpgradeLevel
AlienCommander.GetVeilLevel = Alien.GetVeilLevel
AlienCommander.GetSpurLevel = Alien.GetSpurLevel
AlienCommander.GetShellLevel = Alien.GetShellLevel

function AlienCommander:GetSelectionSound()
    return AlienCommander.kSelectSound
end

function AlienCommander:GetHoverSound()
    return kHoverSound
end

function AlienCommander:GetTeamType()
    return kAlienTeamType
end

function AlienCommander:GetOrderConfirmedEffect()
    return AlienCommander.kOrderClickedEffect
end

function AlienCommander:GetSpendResourcesSoundName()
    return AlienCommander.kSpendResourcesSoundName
end

function AlienCommander:GetSpendTeamResourcesSoundName()
    return AlienCommander.kSpendTeamResourcesSoundName
end

function AlienCommander:SetSelectionCircleMaterial(entity)
 
    if HasMixin(entity, "Construct") and not entity:GetIsBuilt() then
    
        SetMaterialFrame("alienBuild", entity.buildFraction)

    else

        -- Allow entities without health to be selected (infest nodes)
        local healthPercent = 1
        if(entity.health ~= nil and entity.maxHealth ~= nil) then
            healthPercent = entity.health / entity.maxHealth
        end
        
        SetMaterialFrame("alienHealth", healthPercent)
        
    end
   
end

function AlienCommander:GetChatSound()
    return AlienCommander.kChatSound
end

function AlienCommander:GetPlayerStatusDesc()
    return kPlayerStatus.Commander
end

function AlienCommander:OnProcessMove(input)

    Commander.OnProcessMove(self, input)
    
    if Server then
    
        UpdateAbilityAvailability(self, self.tierOneTechId, self.tierTwoTechId, self.tierThreeTechId)
        
        self.shellCount = Clamp( #GetEntitiesForTeam("Shell", self:GetTeamNumber()), 0, 3)
        self.spurCount = Clamp( #GetEntitiesForTeam("Spur", self:GetTeamNumber()), 0, 3)
        self.veilCount = Clamp( #GetEntitiesForTeam("Veil", self:GetTeamNumber()), 0, 3) 
        
    end
    
end

local function SelectNearest(self, className)

    local nearestEnt = GetNearest(self, className)
    
    if nearestEnt then

        if Client then
        
            DeselectAllUnits(self:GetTeamNumber())
            nearestEnt:SetSelected(self:GetTeamNumber(), true, false)
            
            return true
        
        elseif Server then
        
            DeselectAllUnits(self:GetTeamNumber())
            nearestEnt:SetSelected(self:GetTeamNumber(), true, false)
            Server.SendNetworkMessage(self, "SelectAndGoto", BuildSelectAndGotoMessage(nearestEnt:GetId()), true)
            
            return true
            
        end
    
    end
    
    return false

end

function AlienCommander:OnUpdateRender()

    if self:GetIsLocalPlayer() then
    
        -- get mouse target and create a dark cloud effect in case it's an enemy
        local mouseX, mouseY = Client.GetCursorPosScreen()
        local pickVec = CreatePickRay(self, mouseX, mouseY)
        local trace = Shared.TraceRay(self:GetOrigin(), self:GetOrigin() + pickVec * 1000, CollisionRep.Select, PhysicsMask.CommanderSelect, EntityFilterOne(self))
        
        local cursorLight = ClientResources.GetResource("CursorLight")
        cursorLight:SetCoords(Coords.GetTranslation(trace.endPoint + trace.normal * 0.5))
        
    end
    
end

if Server then

    local function GetIsPheromone(techId)    
        return techId == kTechId.ThreatMarker or techId == kTechId.LargeThreatMarker or techId ==  kTechId.NeedHealingMarker or techId == kTechId.WeakMarker or techId == kTechId.ExpandingMarker    
    end

    function AlienCommander:BuildCystChain(start)
        local cystPoints, parent, normals = GetCystPoints(start)

        local team = self:GetTeam()
        local cost = math.max(0, #cystPoints * kCystCost)

        if cost <= team:GetTeamResources() and parent ~= nil then

            local previousParent
            local createdCysts = 0

            for i = 1, #cystPoints do

                local cyst = CreateEntity(Cyst.kMapName, cystPoints[i], self:GetTeamNumber())
                cyst:SetCoords(AlignCyst(Coords.GetTranslation(cystPoints[i]), normals[i]))

                cyst:SetImmuneToRedeploymentTime(0.05)

                if not cyst:GetIsConnected() and previousParent then
                    cyst:ChangeParent(previousParent)
                end

                previousParent = cyst
                createdCysts = createdCysts + 1

            end

            if createdCysts > 0 then
                team:AddTeamResources(-createdCysts * kCystCost)
                return true
            end
        end
    end
    
    function AlienCommander:ProcessTechTreeAction(techId, pickVec, orientation, worldCoordsSpecified, targetId, shiftDown)

        local success = false
    
        if techId == kTechId.Cyst then

            local trace = GetCommanderPickTarget(self, pickVec, worldCoordsSpecified, true, false)

            if trace.fraction ~= 1 then
            
                local legalBuildPosition, position, _, errorString = GetIsBuildLegal(techId, trace.endPoint, orientation, kStructureSnapRadius, self)
                
                if legalBuildPosition then
                    self:BuildCystChain(position)
                end
                
                if errorString then
                
                    local commander = self:isa("Commander") and self or self:GetOwner()                
                    if commander then
                    
                        if Server then
                            local message = BuildCommanderErrorMessage(errorString, position)
                            Server.SendNetworkMessage(commander, "CommanderError", message, true)  
                        end
                    
                    end
                
                end
 
            end
        
        else        
            success = Commander.ProcessTechTreeAction(self, techId, pickVec, orientation, worldCoordsSpecified, targetId, shiftDown)            
        end

        if success then
        
            local soundToPlay
            
            if techId == kTechId.ShiftHatch then
                soundToPlay = AlienCommander.kShiftHatch
            elseif techId == kTechId.BoneWall then
                soundToPlay = AlienCommander.kBoneWallSpawnSound
            elseif techId == kTechId.HealWave then
                soundToPlay = AlienCommander.kHealWaveSound
            elseif techId == kTechId.ShadeInk then
                soundToPlay = AlienCommander.kShadeInkSound  
            elseif techId == kTechId.Cyst then
                soundToPlay = AlienCommander.kCreateCystSound
            elseif techId == kTechId.NutrientMist then
                soundToPlay = AlienCommander.kCreateMistSound    
            elseif techId == kTechId.Rupture then
                soundToPlay = AlienCommander.kRupterSound    
            elseif techId == kTechId.Contamination then
                soundToPlay = AlienCommander.kContaminationSound    
            end

            if soundToPlay then                
                Shared.PlayPrivateSound(self, soundToPlay, nil, 1.0, self:GetOrigin())                
            end

        end    
    
    end
    
    -- check if a notification should be send for successful actions
    function AlienCommander:ProcessTechTreeActionForEntity(techNode, position, normal, pickVec, orientation, entity, trace, targetId)
    
        local techId = techNode:GetTechId()
        local success = false
        local keepProcessing = false
        local processForEntity = true
        
        if not entity and ( techId == kTechId.ShadeInk or techId == kTechId.HealWave ) then
        
            local className = techId == kTechId.HealWave and "Crag" or "Shade"
            entity = GetNearest(self, className)
            processForEntity = entity ~= nil
            
        end

        if techId == kTechId.Cyst then
            success = self:BuildCystChain(position)
        elseif techId == kTechId.SelectDrifter then
        
            SelectNearest(self, "Drifter")

        elseif GetIsPheromone(techId) then
        
            success = CreatePheromone(techId, position, self:GetTeamNumber()) ~= nil
            keepProcessing = false
        end
        
        if success then
        
            local location = GetLocationForPoint(position)
            local locationName = location and location:GetName() or ""
            self:TriggerNotification(Shared.GetStringIndex(locationName), techId)

        elseif processForEntity then
            success, keepProcessing = Commander.ProcessTechTreeActionForEntity(self, techNode, position, normal, pickVec, orientation, entity, trace, targetId)
        end
        
        return success, keepProcessing
        
    end
    
end

function AlienCommander:GetTechAllowed(techId, techNode)

    local allowed, canAfford = Commander.GetTechAllowed(self, techId, techNode)
    
    if techId == kTechId.SelectDrifter then
    
        allowed = true
        canAfford = true
        
    elseif techId == kTechId.SelectShift then
    
        allowed = GetNearest(self, "Shift") ~= nil
        canAfford = true
    
    elseif techId == kTechId.HealWave then
    
        allowed = GetNearest(self, "Crag") ~= nil
    
    elseif techId == kTechId.ShadeInk then
    
        allowed = GetNearest(self, "Shade") ~= nil

    end    
    
    return allowed, canAfford
    
end    

function AlienCommander:GetCanSeeConstructIcon(ofEntity)

    if ofEntity:isa("Cyst") then
        return ofEntity.underConstruction    
    end

    return true
    
end

function AlienCommander:GetIsInQuickMenu(techId)
    return Commander.GetIsInQuickMenu(self, techId) or techId == kTechId.MarkersMenu
end

local gAlienMenuButtons =
{
    [kTechId.BuildMenu] = { kTechId.Cyst, kTechId.Harvester, kTechId.DrifterEgg, kTechId.Hive,
                            kTechId.ThreatMarker, kTechId.NeedHealingMarker, kTechId.ExpandingMarker, kTechId.None },
                            
    [kTechId.AdvancedMenu] = { kTechId.Crag, kTechId.Shade, kTechId.Shift, kTechId.Whip,
                               kTechId.Shell, kTechId.Veil, kTechId.Spur, kTechId.None },

    [kTechId.AssistMenu] = { kTechId.HealWave, kTechId.ShadeInk, kTechId.SelectShift, kTechId.SelectDrifter,
                             kTechId.NutrientMist, kTechId.Rupture, kTechId.BoneWall, kTechId.Contamination }
}

local gAlienMenuIds = {}
do
    for menuId, _ in pairs(gAlienMenuButtons) do
        gAlienMenuIds[#gAlienMenuIds+1] = menuId
    end
end

function AlienCommander:GetButtonTable()
    return gAlienMenuButtons
end

function AlienCommander:GetMenuIds()
    return gAlienMenuIds
end

-- Top row always the same. Alien commander can override to replace.
function AlienCommander:GetQuickMenuTechButtons(techId)

    -- Top row always for quick access.
    local alienTechButtons = { kTechId.BuildMenu, kTechId.AdvancedMenu, kTechId.AssistMenu, kTechId.RootMenu }
    local menuButtons = gAlienMenuButtons[techId]

    if not menuButtons then
    
        -- Make sure all slots are initialized so entities can override simply.
        menuButtons = { kTechId.None, kTechId.None, kTechId.None, kTechId.None, kTechId.None, kTechId.None, kTechId.None, kTechId.None }
        
    end
    
    table.copy(menuButtons, alienTechButtons, true)
    
    -- Return buttons and true/false if we are in a quick-access menu.
    return alienTechButtons
    
end

function AlienCommander:SetCurrentTech(techId)

    if techId == kTechId.SelectDrifter then
    
        if not SelectNearest(self, "Drifter") then
            SelectNearest(self, "DrifterEgg")
        end
        return
        
    elseif techId == kTechId.SelectHallucinations then

        SelectAllHallucinations(self)
        return
        
    elseif techId == kTechId.SelectShift then
    
        SelectNearest(self, "Shift")
        self:SetCurrentTech(kTechId.ShiftEcho)
        return
        
    elseif techId == kTechId.LifeFormMenu then
        for _,hive in ipairs(GetEntitiesForTeam("Hive", self:GetTeamNumber())) do
            if hive:GetIsSelected() then
                DeselectAllUnits(self:GetTeamNumber())
                hive:GetEvolutionChamber():SetSelected(self:GetTeamNumber(), true, false)
                return
            end
        end

    elseif techId == kTechId.Return then
        for _,hive in ipairs(GetEntitiesForTeam("Hive", self:GetTeamNumber())) do
            if hive:GetEvolutionChamber():GetIsSelected() then
                DeselectAllUnits(self:GetTeamNumber())
                hive:SetSelected(self:GetTeamNumber(), true, false)
                return
            end
        end
    end
    
    Commander.SetCurrentTech(self, techId)

end

Shared.LinkClassToMap("AlienCommander", AlienCommander.kMapName, networkVars)
