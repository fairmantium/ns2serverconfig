local kObservatoryUserURL = "https://observatory.morrolan.ch/player?steam_id="

local team1Skill, team2Skill, team1VictoryP, skillDiff, skillPlayers = 0, 0, 0, 0, 0
local textHeight, teamItemWidth

local originalScoreboardUpdateTeam = GUIScoreboard.UpdateTeam
function GUIScoreboard:UpdateTeam(updateTeam)
	originalScoreboardUpdateTeam(self, updateTeam)
	
	local teamGUIItem = updateTeam["GUIs"]["Background"]
	local teamNumber = updateTeam["TeamNumber"]
	local teamScores = updateTeam["GetScores"]()
	local playerList = updateTeam["PlayerList"]
	
	local teamSumSkill = 0
	local numPlayers = #teamScores
	
	-- Resize the player list if it doesn't match.
	if #playerList ~= numPlayers then
		self:ResizePlayerList(playerList, numPlayers, teamGUIItem)
	end
	
	-- Recount the players so we can exclude bots
	numPlayers = 0
	local currentPlayerIndex = 1
	for index, player in ipairs(playerList) do
		local playerRecord = teamScores[currentPlayerIndex]
		currentPlayerIndex = currentPlayerIndex + 1
		local clientIndex = playerRecord.ClientIndex
		
		-- Swap KDA/KAD
		if CHUDGetOption("kda") and player["Assists"]:GetPosition().x < player["Deaths"]:GetPosition().x then
			local temp = player["Assists"]:GetPosition()
			player["Assists"]:SetPosition(player["Deaths"]:GetPosition())
			player["Deaths"]:SetPosition(temp)
		end
		
		if self.showPlayerSkill and playerRecord.Skill > 0 then
			player["Name"]:SetText(string.format("[%s] %s", playerRecord.Skill, player["Name"]:GetText()))
		end
		
		if playerRecord.SteamId > 0 then

			if playerRecord.Skill >= 0 then
				teamSumSkill = teamSumSkill + playerRecord.Skill
				numPlayers = numPlayers + 1
			end
		end
	end

	if (teamNumber == 1 or teamNumber == 2) and (self.showAvgSkill or self.showProbability)then
		local avgskill = numPlayers > 0 and teamSumSkill/numPlayers or 0
		if teamNumber == 1 then
			team1Skill = avgskill
			skillPlayers = #playerList
			skillDiff = teamSumSkill + avgskill * (skillPlayers- numPlayers)
		elseif teamNumber == 2 then
			team2Skill = avgskill
			skillPlayers = skillPlayers + #playerList
			skillDiff = skillDiff - teamSumSkill - avgskill * (#playerList - numPlayers)

			-- calculate probability of victory
			team1VictoryP = math.min(Round(100 / (1 + math.exp(-skillDiff / (100 * skillPlayers)))), 99)
		end
	end
end

local originalScoreboardInit = GUIScoreboard.Initialize
function GUIScoreboard:Initialize()
	originalScoreboardInit(self)
	
	self.avgSkillItemBg = GUIManager:CreateGraphicItem()
	self.avgSkillItemBg:SetColor(Color(0, 0, 0, 0.75))
	self.avgSkillItemBg:SetLayer(kGUILayerScoreboard)
	self.avgSkillItemBg:SetAnchor(GUIItem.Middle, GUIItem.Top)
	self.scoreboardBackground:AddChild(self.avgSkillItemBg)
	
	self.avgSkillItem2Bg = GUIManager:CreateGraphicItem()
	self.avgSkillItem2Bg:SetColor(Color(0, 0, 0, 0.75))
	self.avgSkillItem2Bg:SetLayer(kGUILayerScoreboard)
	self.avgSkillItem2Bg:SetAnchor(GUIItem.Middle, GUIItem.Top)
	self.scoreboardBackground:AddChild(self.avgSkillItem2Bg)
	
	self.avgSkillItem = GUIManager:CreateTextItem()
	self.avgSkillItem:SetFontName(GUIScoreboard.kGameTimeFontName)
	self.avgSkillItem:SetScale(Vector(1, 1, 1) * GUIScoreboard.kScalingFactor)
	self.avgSkillItem:SetAnchor(GUIItem.Middle, GUIItem.Top)
	self.avgSkillItem:SetTextAlignmentX(GUIItem.Align_Center)
	self.avgSkillItem:SetTextAlignmentY(GUIItem.Align_Center)
	self.avgSkillItem:SetColor(ColorIntToColor(kMarineTeamColor))
	self.avgSkillItem:SetText("")
	self.avgSkillItem:SetLayer(kGUILayerScoreboard)
	GUIMakeFontScale(self.avgSkillItem)
	
	self.avgSkillItem2 = GUIManager:CreateTextItem()
	self.avgSkillItem2:SetFontName(GUIScoreboard.kGameTimeFontName)
	self.avgSkillItem2:SetScale(Vector(1, 1, 1) * GUIScoreboard.kScalingFactor)
	self.avgSkillItem2:SetAnchor(GUIItem.Middle, GUIItem.Top)
	self.avgSkillItem2:SetTextAlignmentX(GUIItem.Align_Center)
	self.avgSkillItem2:SetTextAlignmentY(GUIItem.Align_Center)
	self.avgSkillItem2:SetColor(kRedColor)
	self.avgSkillItem2:SetText("")
	self.avgSkillItem2:SetLayer(kGUILayerScoreboard)
	GUIMakeFontScale(self.avgSkillItem2)
	
	self.avgSkillItemBg:SetIsVisible(false)
	self.avgSkillItem2Bg:SetIsVisible(false)
	
	teamItemWidth = self.teams[1].GUIs.Background:GetSize().x
	textHeight = self.avgSkillItem:GetTextHeight("Avg") * self.avgSkillItem:GetScale().y
	
	self.avgSkillItemBg:SetSize(Vector(teamItemWidth, textHeight+5*GUIScoreboard.kScalingFactor, 0))
	self.avgSkillItem2Bg:SetSize(Vector(teamItemWidth, textHeight+5*GUIScoreboard.kScalingFactor, 0))
end

local originalScoreboardUpdate = GUIScoreboard.Update
function GUIScoreboard:Update(deltaTime)
	
	originalScoreboardUpdate(self, deltaTime)
	
	if self.visible then
		self.centerOnPlayer = CHUDGetOption("sbcenter")

		self.showPlayerSkill = GetGameInfoEntity().showPlayerSkill and not PlayerUI_GetHasGameStarted()
		self.showAvgSkill = GetGameInfoEntity().showAvgSkill
		self.showProbability = GetGameInfoEntity().showProbability


		if self.showAvgSkill or self.showProbability then
			local team1Players = #self.teams[2]["GetScores"]()
			local team2Players = #self.teams[3]["GetScores"]()
			local hasText = false
			
			self.avgSkillItemBg:SetIsVisible(true)
			self.avgSkillItem2Bg:SetIsVisible(true)
			
			self.scoreboardBackground:AddChild(self.avgSkillItem)
			self.scoreboardBackground:AddChild(self.avgSkillItem2)

			local team1Text = ""
			local team2Text = ""

			if self.showAvgSkill then
				team1Text = string.format("Avg. skill: %d", team1Skill)
				team2Text = string.format("Avg. skill: %d", team2Skill)
			end

			if team1Players > 0 and team2Players > 0 then

				if self.showAvgSkill and self.showProbability then
					team1Text = string.format("Avg. skill: %d, Probability of victory: %d%%", team1Skill, team1VictoryP)
					team2Text = string.format("Avg. skill: %d, Probability of victory: %d%%", team2Skill, 100 - team1VictoryP)
				elseif self.showProbability then
					team1Text = string.format("Probability of victory: %d%%", team1VictoryP)
					team2Text = string.format("Probability of victory: %d%%", 100 - team1VictoryP)
				end

				self.avgSkillItem:SetText(team1Text)
				self.avgSkillItem2:SetText(team2Text)
				hasText = true
				
				if teamItemWidth*2 > self.scoreboardBackground:GetSize().x then
					local team1TextWidth = self.avgSkillItem:GetTextWidth(self.avgSkillItem:GetText()) * self.avgSkillItem:GetScale().x
					local team2TextWidth = self.avgSkillItem2:GetTextWidth(self.avgSkillItem2:GetText()) * self.avgSkillItem2:GetScale().x
					
					self.avgSkillItem:SetPosition(Vector(-20*GUIScoreboard.kScalingFactor-team1TextWidth/2, textHeight/2+5*GUIScoreboard.kScalingFactor, 0))
					self.avgSkillItem2:SetPosition(Vector(20*GUIScoreboard.kScalingFactor+team2TextWidth/2, textHeight/2+5*GUIScoreboard.kScalingFactor, 0))
					self.avgSkillItem2Bg:SetIsVisible(false)
				else
					self.avgSkillItemBg:AddChild(self.avgSkillItem)
					self.avgSkillItem2Bg:AddChild(self.avgSkillItem2)
					self.avgSkillItem:SetPosition(Vector(0, textHeight/2+5*GUIScoreboard.kScalingFactor, 0))
					self.avgSkillItem2:SetPosition(Vector(0, textHeight/2+5*GUIScoreboard.kScalingFactor, 0))
				end
			elseif team1Players > 0 then
				self.avgSkillItem:SetText(team1Text)
				self.avgSkillItem:SetPosition(Vector(0, textHeight/2+5*GUIScoreboard.kScalingFactor, 0))
				
				self.avgSkillItem2:SetText("")
				self.avgSkillItem2Bg:SetIsVisible(false)
				
				hasText = true
			elseif team2Players > 0 then
				self.avgSkillItem2:SetText(team2Text)
				self.avgSkillItem2:SetPosition(Vector(0, textHeight/2+5*GUIScoreboard.kScalingFactor, 0))
				
				self.avgSkillItem:SetText("")
				self.avgSkillItemBg:SetIsVisible(false)
				
				hasText = true
			else
				self.avgSkillItem:SetText("")
				self.avgSkillItemBg:SetIsVisible(false)
				
				self.avgSkillItem2:SetText("")
				self.avgSkillItem2Bg:SetIsVisible(false)
			end
			
			local sliderbarBgYSize = GUIScoreboard.kBgMaxYSpace-20*GUIScoreboard.kScalingFactor
			if hasText then
				self.background:SetPosition(Vector(self.background:GetPosition().x, self.background:GetPosition().y+textHeight, 0))
				self.backgroundStencil:SetPosition(Vector(self.backgroundStencil:GetPosition().x, self.backgroundStencil:GetPosition().y+textHeight, 0))
				if self.slidebarBg:GetIsVisible() then
					self.backgroundStencil:SetSize(Vector(self.backgroundStencil:GetSize().x, self.backgroundStencil:GetSize().y-textHeight, 0))
					sliderbarBgYSize = sliderbarBgYSize-textHeight
				end
				
				self.avgSkillItemBg:SetPosition(Vector(self.teams[2].GUIs.Background:GetPosition().x, ConditionalValue(GUIScoreboard.kScalingFactor == 1, 5*GUIScoreboard.kScalingFactor, 0), 0))
				self.avgSkillItem2Bg:SetPosition(Vector(self.teams[3].GUIs.Background:GetPosition().x,  ConditionalValue(GUIScoreboard.kScalingFactor == 1, 5*GUIScoreboard.kScalingFactor, 0), 0))
				
				-- Reposition the slider
				local sliderPos = (self.slidePercentage * self.slidebarBg:GetSize().y/100)
				if sliderPos < self.slidebar:GetSize().y/2 then
					sliderPos = 0
				end
				if sliderPos > self.slidebarBg:GetSize().y - self.slidebar:GetSize().y then
					sliderPos = self.slidebarBg:GetSize().y - self.slidebar:GetSize().y
				end
				self.slidebar:SetPosition(Vector(0, sliderPos, 0))
			end
		end
	end
end

local originalScoreboardSKE = GUIScoreboard.SendKeyEvent
function GUIScoreboard:SendKeyEvent(key, down)
	local ret = originalScoreboardSKE(self, key, down)

	if GetIsBinding(key, "Scoreboard") and not down then
		self.hoverMenu:Hide()
	end

	if self.visible and self.hoverMenu.background:GetIsVisible() then

		local steamId = GetSteamIdForClientIndex(self.hoverPlayerClientIndex) or 0
		local function openObservatoryProf()
			Client.ShowWebpage(string.format("%s%s", kObservatoryUserURL, steamId))
		end

		local found = 0
		local added = false
		local titleColor = Color(0, 0, 0, 0)
		local teamColorBg = Color(0.5, 0.5, 0.5, 0.5)
		local teamColorHighlight = Color(0.75, 0.75, 0.75, 0.75)
		local textColor = Color(1, 1, 1, 1)
		for index, entry in ipairs(self.hoverMenu.links) do
			if not entry.isSeparator then
				local text = entry.link:GetText()
				if text == Locale.ResolveString("SB_MENU_STEAM_PROFILE") then
					teamColorBg = entry.bgColor
					teamColorHighlight = entry.bgHighlightColor
					found = index
				elseif text == "Observatory profile" then
					added = true
				end
			end
		end

		if not added then
			if found > 0 then
				found = found + 1
			else
				found = nil
			end

			-- Don't add the button if we can't find the one we expect
			if found then
				self.hoverMenu:AddButton("Observatory profile", teamColorBg, teamColorHighlight, textColor, openObservatoryProf, found)

				-- Calling the show function will reposition the menu (in case we're out of the window)
				self.hoverMenu:Show()
			end
		end
	end

	return ret
end

local originalLocaleResolveString = Locale.ResolveString
function Locale.ResolveString(resolveString)
	if CHUDGetOption("kda") then
		if resolveString == "SB_ASSISTS" then
			return originalLocaleResolveString("SB_DEATHS")
		elseif resolveString == "SB_DEATHS" then
			return originalLocaleResolveString("SB_ASSISTS")
		else
			return originalLocaleResolveString(resolveString)
		end
	else
		return originalLocaleResolveString(resolveString)
	end
end
