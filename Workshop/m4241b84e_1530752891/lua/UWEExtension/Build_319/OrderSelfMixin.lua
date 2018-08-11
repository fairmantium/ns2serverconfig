-- Fixed that auto-repair orders where issues whioch are now a liitle redudant.
--
-- Find closest structure with health less than the kPriorityAttackHealthScalar, otherwise just closest matching kPriorityAttackTargets, otherwise closest structure.
--
local kFindStructureRange = 20
local kFindFriendlyPlayersRange = 15

function OrderSelfMixin:FindBuildOrder(structuresNearby)

    if self.GetCheckForAutoConstructOrder and not self:GetCheckForAutoConstructOrder() then
        return false
    end

    local closestStructure
    local closestStructureDist = Math.infinity

    for _, structure in ipairs(structuresNearby) do

        local verticalDist = structure:GetOrigin().y - self:GetOrigin().y

        if verticalDist < 3 then

            local structureDist = (structure:GetOrigin() - self:GetOrigin()):GetLengthSquared()
            local closerThanClosest = structureDist < closestStructureDist

            if closerThanClosest and not structure:GetIsBuilt() and structure:GetCanConstruct(self) then

                if not structure:isa( "PowerPoint" ) or ( structure.buildFraction < 1 or structure:HasConsumerRequiringPower() ) then
                    closestStructure = structure
                    closestStructureDist = structureDist
                end
            end

        end

    end

    if HasMixin( closestStructure, "PowerConsumer" ) then

        local powerSources = GetEntitiesWithMixin("PowerSource")
        Shared.SortEntitiesByDistance(closestStructure:GetOrigin(), powerSources)
        for _, structure in ipairs(powerSources) do
            if structure:GetCanPower(closestStructure) then
                if not structure:GetIsBuilt() and not structure:GetIsPowering() and structure:GetCanConstruct(self) then
                    closestStructure = structure;
                end
                break
            end
        end
    end

    if closestStructure then
        return kTechId.None ~= self:GiveOrder(kTechId.AutoConstruct, closestStructure:GetId(), closestStructure:GetOrigin(), nil, true, false)
    end

    return false

end

--
-- Find closest structure with health less than the kPriorityAttackHealthScalar, otherwise just closest matching kPriorityAttackTargets, otherwise closest structure.
--
function OrderSelfMixin:FindWeldOrder(entitiesNearby)

    local closestStructure
    local closestStructureDist = Math.infinity

    if self:isa("Marine") and not self:GetWeapon(Welder.kMapName) then
        return
    end

    -- Do not give weld orders during combat.
    if GetAnyNearbyUnitsInCombat(self:GetOrigin(), 12, self:GetTeamNumber()) then
        return
    end

    for _, entity in ipairs(entitiesNearby) do

        if entity ~= self then

            local entityDist = (entity:GetOrigin() - self:GetOrigin()):GetLengthSquared()
            local closerThanClosest = entityDist < closestStructureDist

            local weldAble = false

            if self:isa("Marine") then

                -- Weld friendly players if their armor is below 75%.
                -- Weld non-players when they are below 50%.
                weldAble = HasMixin(entity, "Weldable")
                weldAble = weldAble and (((entity:isa("Player") and not entity:isa("Spectator")) and entity:GetArmorScalar() < 0.75) or
                        (not entity:isa("Player") and entity:GetArmorScalar() < 0.5))

            end

            if self:isa("Gorge") then
                weldAble = entity:GetHealthScalar() < 1 and entity:isa("Player")
            end

            if HasMixin(entity, "Construct") and not entity:GetIsBuilt() then
                weldAble = false
            end

            if entity.GetCanBeHealed and not entity:GetCanBeHealed() then
                weldAble = false
            end

            if closerThanClosest and weldAble then

                closestStructure = entity
                closestStructureDist = entityDist

            end

        end

    end

    if closestStructure then

        local orderTechId = kTechId.AutoWeld
        if self:isa("Gorge") then
            orderTechId = kTechId.AutoHeal
        end

        return kTechId.None ~= self:GiveOrder(orderTechId, closestStructure:GetId(), closestStructure:GetOrigin(), nil, true, false)
    end

    return false

end

function OrderSelfMixin:GetCanOverwriteOrderType(orderType)
    return orderType == kTechId.AutoHeal or orderType == kTechId.AutoWeld
end

function OrderSelfMixin:_UpdateOrderSelf()

    local alive = not HasMixin(self, "Live") or self:GetIsAlive()
    if alive and (not self:GetHasOrder() or self:GetCanOverwriteOrderType(self:GetCurrentOrder():GetType()) ) then

        local friendlyStructuresNearby = GetEntitiesWithMixinForTeamWithinRange("Construct", self:GetTeamNumber(), self:GetOrigin(), kFindStructureRange)
        self:FindBuildOrder(friendlyStructuresNearby)

    end

    -- Continue forever.
    return true

end

