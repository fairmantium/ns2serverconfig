local blue = gBadges.ensl_nc_2017_late_blue
local gold = gBadges.ensl_nc_2017_late_gold

local oldBadges_GetBadgeData = Badges_GetBadgeData
function Badges_GetBadgeData(badgeId)
    local data = oldBadges_GetBadgeData(badgeId)

    if badgeId == blue then
        data.itemId = 1015
    elseif badgeId == gold then
        data.itemId = 1013
    end

    return data
end