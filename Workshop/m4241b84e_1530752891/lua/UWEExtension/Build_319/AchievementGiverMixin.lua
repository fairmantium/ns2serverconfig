function AchievementGiverMixin:OnConstruct(builder, newFraction, oldFraction)
    if not (self:isa("Hive") or self:isa("Extractor")) then return end

    if not self.constructContributions then
        self.constructContributions = {}
        self.constructContributors = {}
    end

    if builder and GetAreFriends(self, builder) then
        local builderId = builder:GetId()

        if not self.constructContributions[builderId] then
            self.constructContributions[builderId] = 0
            table.insert(self.constructContributors, builderId)
        end

        self.constructContributions[builderId] = self.constructContributions[builderId] + (newFraction - oldFraction)
    end
end

function AchievementGiverMixin:OnConstructionComplete(builder)
    --reward if player contributed more than 33%
    if self.constructContributors then
        for i = 1, #self.constructContributors do
            local builderId = self.constructContributors[i]
            local constructionFraction = self.constructContributions[builderId]

            if constructionFraction > 0.33 then
                local builder = Shared.GetEntity(builderId)
                local client = builder and builder.GetClient and builder:GetClient()

                if client then
                    if self:isa("Extractor") then
                        builder:AddBuildResTowers()
                    else -- Hive
                        Server.SetAchievement(client, "Short_1_7")
                    end
                end
            end
        end

        self.constructContributors = nil
        self.constructContributions = nil
    end
end