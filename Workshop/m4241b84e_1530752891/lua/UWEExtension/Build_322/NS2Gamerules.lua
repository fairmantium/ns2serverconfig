function NS2Gamerules:OnCommanderLogout(commandStructure, oldCommander)
    if self.gameInfo:GetRookieMode() and self:GetGameState() > kGameState.NotStarted and
            self:GetGameState() < kGameState.Team1Won then
        self.botTeamController:UpdateBotsForTeam(commandStructure:GetTeamNumber())
    end
end