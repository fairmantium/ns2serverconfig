function BotTeamController:DisableUpdate()
    self.updateLock = true
end

function BotTeamController:EnableUpdate()
    self.updateLock = false
end

function BotTeamController:UpdateBots()
    PROFILE("BotTeamController:UpdateBots")

    if self.updateLock then return end -- avoid getting called by itself while updating
    self:DisableUpdate()

    if self.MaxBots < 1 then --BotTeamController is disabled
        self:EnableUpdate()
        return
    end

    local team1HumanNum = self:GetPlayerNumbersForTeam(kTeam1Index, true)
    local team2HumanNum = self:GetPlayerNumbersForTeam(kTeam2Index, true)
    local humanCount = team1HumanNum + team2HumanNum

    -- Remove all bots if all humans left the playing teams
    if humanCount == 0 then
        self:RemoveBots(nil, #gServerBots)
        self:EnableUpdate()
        return
    end

    self:UpdateBotsForTeam(kTeam1Index)
    self:UpdateBotsForTeam(kTeam2Index)

    self:EnableUpdate()
end
