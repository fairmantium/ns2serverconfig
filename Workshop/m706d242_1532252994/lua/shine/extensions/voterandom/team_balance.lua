--[[
	Handles team balancing related stuff.
]]

Shine.LoadPluginFile( "voterandom", "team_optimiser.lua" )

local BalanceModule = {}
local Plugin = Plugin

local Abs = math.abs
local Ceil = math.ceil
local GetOwner = Server.GetOwner
local IsType = Shine.IsType
local Max = math.max
local next = next
local Random = math.random
local TableCopy = table.Copy
local TableMixin = table.Mixin
local TableRemove = table.remove
local TableShallowMerge = table.ShallowMerge
local TableSort = table.sort

local EvenlySpreadTeams = Shine.EvenlySpreadTeams

BalanceModule.DefaultConfig = {
	TeamPreferences = {
		-- How many rounds to remember who got to play their preferred team for.
		MaxHistoryRounds = 5,
		-- The minimum time a round must be played before team preferences are recorded.
		MinRoundLengthToRecordInSeconds = 5 * 60
	}
}

do
	local Validator = Shine.Validator()

	Validator:AddFieldRule( "TeamPreferences.MaxHistoryRounds",
		Validator.IsType( "number", BalanceModule.DefaultConfig.TeamPreferences.MaxHistoryRounds ) )
	Validator:AddFieldRule( "TeamPreferences.MaxHistoryRounds", Validator.Min( 0 ) )

	Validator:AddFieldRule( "TeamPreferences.MinRoundLengthToRecordInSeconds",
		Validator.IsType( "number", BalanceModule.DefaultConfig.TeamPreferences.MinRoundLengthToRecordInSeconds ) )
	Validator:AddFieldRule( "TeamPreferences.MinRoundLengthToRecordInSeconds", Validator.Min( 0 ) )

	BalanceModule.ConfigValidator = Validator
end

Shine.Hook.SetupClassHook( "BotTeamController", "UpdateBots", "UpdateBots", "ActivePre" )

local function GetAverageSkillFunc( Players, Func, TeamNumber )
	local PlayerCount = #Players
	if PlayerCount == 0 then
		return {
			Average = 0,
			Total = 0,
			Count = 0,
			Skills = {}
		}
	end

	local PlayerSkillSum = 0
	local Count = 0
	local Skills = {}

	for i = 1, PlayerCount do
		local Ply = Players[ i ]

		if Ply then
			local Skill = Func( Ply, TeamNumber )
			if Skill then
				Count = Count + 1
				PlayerSkillSum = PlayerSkillSum + Skill

				Skills[ Count ] = Skill
			end
		end
	end

	if Count == 0 then
		return {
			Average = 0,
			Total = 0,
			Count = 0,
			Skills = Skills
		}
	end

	TableSort( Skills, function( A, B )
		return A > B
	end )

	return {
		Average = PlayerSkillSum / Count,
		Total = PlayerSkillSum,
		Count = Count,
		Skills = Skills
	}
end

local DebugMode = false

-- TeamNumber parameter currently unused, but ready for Hive 2.0
BalanceModule.SkillGetters = {
	GetHiveSkill = function( Ply, TeamNumber )
		local Client = GetOwner( Ply )
		if Client and Client:GetIsVirtual() then
			if DebugMode then
				Client.Skill = Client.Skill or Random( 0, 2500 )
				return Client.Skill
			end
			-- Bots are all equal so there's no reason to consider them.
			return nil
		end

		if Ply.GetPlayerSkill then
			return Ply:GetPlayerSkill()
		end

		return nil
	end,

	-- KA/D Ratio.
	GetKDR = function( Ply, TeamNumber )
		if DebugMode then
			local Client = GetOwner( Ply )
			if Client and Client:GetIsVirtual() then
				Client.Skill = Client.Skill or Random() * 3
				return Client.Skill
			end
		end

		do
			local KDR = Plugin:CallModuleEvent( "GetPlayerKDR", Ply, TeamNumber )
			if KDR then return KDR end
		end

		local Kills = Ply.totalKills
		local Deaths = Ply.totalDeaths
		local Assists = Ply.totalAssists or 0

		if Kills and Deaths then
			if Deaths == 0 then Deaths = 1 end

			return ( Kills + Assists * 0.1 ) / Deaths
		end

		return nil
	end,

	-- Score per minute played.
	GetScore = function( Ply, TeamNumber )
		if DebugMode then
			local Client = GetOwner( Ply )
			if Client and Client:GetIsVirtual() then
				Client.Skill = Client.Skill or Random() * 10
				return Client.Skill
			end
		end

		do
			local ScorePerMinute = Plugin:CallModuleEvent( "GetPlayerScorePerMinute", Ply, TeamNumber )
			if ScorePerMinute then return ScorePerMinute end
		end

		if not Ply.totalScore or not Ply.totalPlayTime then
			return nil
		end

		local PlayTime = Ply.totalPlayTime + ( Ply.playTime or 0 )
		if PlayTime <= 0 then
			return nil
		end

		return Ply.totalScore / ( PlayTime / 60 )
	end
}

BalanceModule.HappinessHistoryFile = "config://shine/temp/shuffle_happiness.json"

function BalanceModule:Initialise()
	self.HappinessHistory = self:LoadHappinessHistory()
	self.TeamStatsCache = {}
end

function BalanceModule:LoadHappinessHistory()
	return Shine.LoadJSONFile( self.HappinessHistoryFile ) or {}
end

function BalanceModule:SaveHappinessHistory()
	Shine.SaveJSONFile( self.HappinessHistory, self.HappinessHistoryFile )
end

function BalanceModule:EndGame( Gamerules, WinningTeam, Players )
	if not self.HasShuffledThisRound then return end

	local LastTeamLookup = self.LastShuffleTeamLookup
	local LastPreferences = self.LastShufflePreferences
	if not LastPreferences then return end

	local MinRoundLength = self.Config.TeamPreferences.MinRoundLengthToRecordInSeconds
	if not Gamerules.gameStartTime
	or ( Shared.GetTime() - Gamerules.gameStartTime ) < MinRoundLength then
		return
	end

	local RoundData = {}

	for i = 1, #Players do
		local Player = Players[ i ]
		local Client = Player:GetClient()
		if Client then
			local SteamID = Client:GetUserId()
			local ShuffledTeam = LastTeamLookup[ SteamID ]
			local Preference = LastPreferences[ SteamID ]
			local EndOfRoundTeam = Player:GetTeamNumber()

			if ShuffledTeam == EndOfRoundTeam and IsType( Preference, "number" ) then
				-- Remember this player's preference vs the team they ended up on.
				RoundData[ tostring( SteamID ) ] = Preference == EndOfRoundTeam
				self.Logger:Debug( "%s was on team %d vs being shuffled to %d and having a preference of %d",
					SteamID, EndOfRoundTeam, ShuffledTeam, Preference )
			end
		end
	end

	self.HappinessHistory[ #self.HappinessHistory + 1 ] = RoundData

	local MaxHistoryRounds = self.Config.TeamPreferences.MaxHistoryRounds
	while #self.HappinessHistory > MaxHistoryRounds do
		TableRemove( self.HappinessHistory, 1 )
	end

	self:SaveHappinessHistory()
end

function BalanceModule:AssignPlayers( TeamMembers, SortTable, Count, NumTargets, TeamSkills, RankFunc )
	local Add = Random() >= 0.5 and 1 or 0
	local Team = 1 + Add
	local MaxForTeam = Ceil( ( NumTargets + #TeamMembers[ 1 ] + #TeamMembers[ 2 ] ) * 0.5 )

	local function GetAverages( Team, JoiningSkill )
		local Skills = TeamSkills[ Team ]
		return Skills.Average, ( Skills.Total + JoiningSkill ) / ( Skills.Count + 1 )
	end

	local Sorted = {}

	-- First pass, place unassigned players onto the team with the lesser average skill rating.
	for i = 1, Count do
		if SortTable[ i ] then
			local Player = SortTable[ i ]
			local TeamToJoin = Team
			local OtherTeam = ( Team % 2 ) + 1

			if #TeamMembers[ Team ] < MaxForTeam then
				if #TeamMembers[ OtherTeam ] < MaxForTeam then
					local OtherAverage, TheirNewAverage = GetAverages( OtherTeam, RankFunc( Player, OtherTeam ) )
					local OurAverage, NewAverage = GetAverages( Team, RankFunc( Player, Team ) )

					if OurAverage > OtherAverage then
						if TheirNewAverage > OtherAverage then
							TeamToJoin = OtherTeam
							Team = OtherTeam
						end
					end
				end
			else
				TeamToJoin = OtherTeam
			end

			local TeamTable = TeamMembers[ TeamToJoin ]

			TeamTable[ #TeamTable + 1 ] = Player
			Sorted[ Player ] = true

			local SkillSum = TeamSkills[ TeamToJoin ].Total + RankFunc( Player, TeamToJoin )
			local PlayerCount = TeamSkills[ TeamToJoin ].Count + 1
			local AverageSkill = SkillSum / PlayerCount

			TeamSkills[ TeamToJoin ].Average = AverageSkill
			TeamSkills[ TeamToJoin ].Total = SkillSum
			TeamSkills[ TeamToJoin ].Count = PlayerCount
		end
	end

	return Sorted
end

function BalanceModule:UpdateBots()
	if self.OptimisingTeams then return false end
	if self.HasShuffledThisRound and not self.Config.ApplyToBots then return false end
end

local function DebugLogTeamMembers( Logger, self, TeamMembers )
	local TeamMemberOutput = {
		self:AsLogOutput( TeamMembers[ 1 ] ),
		self:AsLogOutput( TeamMembers[ 2 ] )
	}

	Logger:Debug( "Assigned team members:\n%s", table.ToString( TeamMemberOutput ) )
end

function BalanceModule:GetHistoricHappinessWeight( Player )
	local RoundHistory = self.HappinessHistory
	local Client = Player:GetClient()
	if not Client then return 1 end

	local Weight = 1
	local SteamID = tostring( Client:GetUserId() )
	for i = 1, #RoundHistory do
		local Round = RoundHistory[ i ]
		local WasHappy = Round[ SteamID ]
		if WasHappy ~= nil then
			-- For every round they got the team they wanted, halve their weighting.
			-- For every round they did not get the team they wanted, double their weighting.
			-- This means that players that consistently get what they want will be less able to offset
			-- unhappy players, and those that consistently do not get what they want will quickly grow
			-- to have a far larger weighting than anyone else.
			Weight = Weight * ( WasHappy and 0.5 or 2 )
			self.Logger:Trace( "%s was %s in round %d, making their weight %s",
				SteamID, WasHappy and "happy" or "not happy", i, Weight )
		end
	end

	return Weight
end

function BalanceModule:GetWeightedHappiness( Player, TeamPreference, TeamAssigned )
	if not IsType( TeamPreference, "number" ) then return 0 end

	local HistoricWeighting = self:GetHistoricHappinessWeight( Player )
	if TeamPreference == TeamAssigned then
		return HistoricWeighting
	end

	return -HistoricWeighting
end

local function TeamMembersContainCommander( TeamMembers )
	for i = 1, 2 do
		local Team = TeamMembers[ i ]
		for j = 1, #Team do
			local Player = Team[ j ]
			if Player and Player:isa( "Commander" ) then
				return true
			end
		end
	end
	return false
end

--[[
	Can only apply this optimisation if we are using a single skill value.
	If a player has a different skill depending on which team they are on,
	swapping will have dire consequences.

	Also, commanders must not be swapped if configured to ignore them, so
	there also must be no commanders present in the teams if ignoring is enabled.
]]
function BalanceModule:ShouldOptimiseHappiness( TeamMembers )
	return not self.Config.UseTeamSkills
		and not ( self.Config.IgnoreCommanders and TeamMembersContainCommander( TeamMembers ) )
end

do
	local Exp = math.exp
	local Max = math.max

	-- These are derived from many simulated team optimisations.
	-- They produce a good balance between average and standard deviation
	-- without favouring either too much.
	local AVERAGE_BOUND = 75
	local STDDEV_BOUND = 150

	local function TeamCost( AverageDiff, StdDiff )
		-- The idea here is that, if the average or standard deviation differences grow
		-- beyond an acceptable level (defined by the bounds above), their exponentials
		-- will start to grow and easily cancel out any minor improvements in the other
		-- parameter.
		return AverageDiff * Exp( Max( AverageDiff - AVERAGE_BOUND, 0 ) )
			+ StdDiff * Exp( Max( StdDiff - STDDEV_BOUND, 0 ) )
	end

	BalanceModule.OptimisationIterations = {
		{
			-- Legacy method, uses hard rules to determine if a swap
			-- is valid.
			TakeSwapImmediately = false
		},
		{
			-- New cost-based method, usually ends up with a more balanced team composition.
			SwapPassesRequirements = function( self, AverageDiff, StdDiff )
				local NewCost = TeamCost( AverageDiff, StdDiff )
				local CurrentCost = self.CurrentPotentialState.Cost
				if not CurrentCost or CurrentCost > NewCost then
					return true, NewCost
				end
				return false
			end,
			TakeSwapImmediately = true
		}
	}

	function BalanceModule:GetCostForOptimiser( Optimiser )
		local State = Optimiser.CurrentPotentialState
		return TeamCost( State.AverageDiffBefore, State.StdDiffBefore )
	end

	function BalanceModule:GetCostFromDiff( AverageDiff, StdDiff )
		return TeamCost( AverageDiff, StdDiff )
	end
end

function BalanceModule:OptimiseTeams( TeamMembers, RankFunc, TeamSkills )
	-- Sanity check, make sure both team tables have even counts.
	Shine.EqualiseTeamCounts( TeamMembers )

	local function GetNumPasses( self )
		return next( TeamMembers.TeamPreferences ) and 2 or 1
	end

	local IgnoreCommanders = self.Config.IgnoreCommanders
	local function IsValidForSwap( self, Player, Pass )
		return ( Pass == 2 or not TeamMembers.TeamPreferences[ Player ] )
			and not ( IgnoreCommanders and Player:isa( "Commander" ) )
	end

	local Iterations = self.OptimisationIterations
	local Results = {}

	for i = 1, #Iterations do
		local Iteration = Iterations[ i ]

		local IterationTeamMembers = TableCopy( TeamMembers )
		local IterationTeamSkills = TableCopy( TeamSkills )

		local Optimiser = self.TeamOptimiser( IterationTeamMembers, IterationTeamSkills, RankFunc )
		Optimiser.GetNumPasses = GetNumPasses
		Optimiser.IsValidForSwap = IsValidForSwap

		TableShallowMerge( Iteration, Optimiser, true )
		TableMixin( self.Config, Optimiser, {
			"StandardDeviationTolerance",
			"AverageValueTolerance"
		} )

		Optimiser:Optimise()

		Results[ i ] = {
			Iteration = i,
			Cost = self:GetCostForOptimiser( Optimiser ),
			TeamMembers = IterationTeamMembers,
			TeamSkills = IterationTeamSkills
		}
	end

	TableSort( Results, function( A, B )
		return A.Cost < B.Cost
	end )

	local BestResult = Results[ 1 ]
	for i = 1, 2 do
		TeamMembers[ i ] = BestResult.TeamMembers[ i ]
		TeamSkills[ i ] = BestResult.TeamSkills[ i ]
	end

	self.Logger:Debug( "Iteration %d produced the best result with cost %s",
		BestResult.Iteration, BestResult.Cost )
	self.Logger:Debug( "After optimisation:" )
	self.Logger:IfDebugEnabled( DebugLogTeamMembers, self, TeamMembers )

	if self:ShouldOptimiseHappiness( TeamMembers ) then
		self:OptimiseHappiness( TeamMembers )

		self.Logger:Debug( "After happiness optimisation:" )
		self.Logger:IfDebugEnabled( DebugLogTeamMembers, self, TeamMembers )
	else
		self.LastShufflePreferences = nil
	end
end

--[[
	This method attempts to satisfy player team preference by judging how many people
	have the team they want vs. how many do not.

	For each player, a weighting is applied to their happiness based on how many times
	in recent history they have been on the team they prefer. Those that have been on the
	team they want often have a lower weight, and vice-versa.
]]
function BalanceModule:OptimiseHappiness( TeamMembers )
	local TotalHappiness = 0
	local Preferences = TeamMembers.TeamPreferences

	-- Collect the total happiness of the server population.
	-- A player who is on the team they do not want has a happiness of -1 * historic happiness factor.
	-- A player who is on the team they do want has a happiness of 1 * historic happiness factor.
	-- The sum produces an overall idea of how happy everyone is.
	local PreferenceLookup = {}
	for i = 1, 2 do
		local Team = TeamMembers[ i ]
		for j = 1, #Team do
			local Player = Team[ j ]
			local Preference = Preferences[ Player ]
			local Client = Player:GetClient()
			if Client then
				PreferenceLookup[ Client:GetUserId() ] = Preference
			end

			local PlayerHappiness = self:GetWeightedHappiness( Player, Preference, i )
			TotalHappiness = TotalHappiness + PlayerHappiness
			self.Logger:Trace( "Player %s has happiness %s", Client and Client:GetUserId() or Player, PlayerHappiness )
		end
	end

	self.Logger:Debug( "Total happiness of server population is: %s", TotalHappiness )

	self.LastShufflePreferences = PreferenceLookup

	-- If there are more weighted unhappy players than happy, swap the teams around entirely.
	-- This will put all the people who are not happy with their team onto the team they want, and vice-versa.
	if TotalHappiness < 0 then
		self.Logger:Debug( "Swapping teams due to happiness..." )
		TeamMembers[ 1 ], TeamMembers[ 2 ] = TeamMembers[ 2 ], TeamMembers[ 1 ]
	end

	return TotalHappiness
end

function BalanceModule:SortPlayersByRank( TeamMembers, SortTable, Count, NumTargets, RankFunc, NoSecondPass )
	local TeamSkills = {
		GetAverageSkillFunc( TeamMembers[ 1 ], RankFunc ),
		GetAverageSkillFunc( TeamMembers[ 2 ], RankFunc )
	}

	local Sorted = self:AssignPlayers( TeamMembers, SortTable, Count, NumTargets, TeamSkills, RankFunc )

	-- If you want/need to control number of players on teams, this is the best point to do it.
	Shine.Hook.Call( "PreShuffleOptimiseTeams", TeamMembers )

	if NoSecondPass then
		return Sorted
	end

	-- Update the team skill values in case the team members table was modified by the event.
	for i = 1, 2 do
		TeamSkills[ i ] = GetAverageSkillFunc( TeamMembers[ i ], RankFunc )
	end

	self:OptimiseTeams( TeamMembers, RankFunc, TeamSkills )

	return Sorted
end

local function GetFallbackTargets( Targets, Sorted )
	local FallbackTargets = {}

	for i = 1, #Targets do
		local Player = Targets[ i ]

		if Player and not Sorted[ Player ] then
			FallbackTargets[ #FallbackTargets + 1 ] = Player
			Sorted[ Player ] = true
		end
	end

	return FallbackTargets
end

function BalanceModule:AddPlayersRandomly( Targets, NumPlayers, TeamMembers )
	while NumPlayers > 0 and #TeamMembers[ 1 ] ~= #TeamMembers[ 2 ] do
		NumPlayers = NumPlayers - 1

		local Team = #TeamMembers[ 1 ] < #TeamMembers[ 2 ] and 1 or 2
		local TeamTable = TeamMembers[ Team ]
		local Player = Targets[ #Targets ]

		TeamTable[ #TeamTable + 1 ] = Player
		Targets[ #Targets ] = nil
	end

	if NumPlayers == 0 then return end

	local TeamSequence = math.GenerateSequence( NumPlayers, { 1, 2 } )

	for i = 1, NumPlayers do
		local Player = Targets[ i ]
		if Player then
			local TeamTable = TeamMembers[ TeamSequence[ i ] ]

			TeamTable[ #TeamTable + 1 ] = Player
		end
	end
end

BalanceModule.NormalisedScoreFactor = 2000

function BalanceModule:NormaliseSkills( ScoreTable, Max )
	-- Normalise KDR/Score amount to be similar values to Hive skill.
	-- This allows the optimise method to not have to worry about different scales.
	for i = 1, #ScoreTable do
		local Data = ScoreTable[ i ]
		local Skill = Data.Skill
		Data.Skill = Skill / Max * self.NormalisedScoreFactor
		ScoreTable[ Data.Player ] = Data.Skill
		ScoreTable[ i ] = Data.Player
	end
end

function BalanceModule:SortByScore( Gamerules, Targets, TeamMembers, Silent, RankFunc )
	local ScoreTable = {}
	local RandomTable = {}

	local Max = 0
	for i = 1, #Targets do
		local Player = Targets[ i ]

		if Player then
			local Score = RankFunc( Player )
			if Score then
				ScoreTable[ #ScoreTable + 1 ] = { Player = Player, Skill = Score }
				if Score > Max then
					Max = Score
				end
			else
				RandomTable[ #RandomTable + 1 ] = Player
			end
		end
	end

	self:NormaliseSkills( ScoreTable, Max )

	local ScoreSortCount = #ScoreTable
	if ScoreSortCount > 0 then
		--Make sure we ignore the second pass if we're a fallback for skill sorting.
		self:SortPlayersByRank( TeamMembers, ScoreTable, ScoreSortCount, #Targets, function( Player, TeamNumber )
			return ScoreTable[ Player ]
		end, Silent )
	end

	local RandomTableCount = #RandomTable

	if RandomTableCount > 0 then
		self:AddPlayersRandomly( RandomTable, RandomTableCount, TeamMembers )
	end

	self.Logger:Debug( "After SortByScore:" )
	self.Logger:IfDebugEnabled( DebugLogTeamMembers, self, TeamMembers )

	EvenlySpreadTeams( Gamerules, TeamMembers )
end

BalanceModule.ShufflingModes = {
	-- Random only.
	[ Plugin.ShuffleMode.RANDOM ] = function( self, Gamerules, Targets, TeamMembers, Silent )
		self:AddPlayersRandomly( Targets, #Targets, TeamMembers )

		self.Logger:Debug( "After AddPlayersRandomly:" )
		self.Logger:IfDebugEnabled( DebugLogTeamMembers, self, TeamMembers )

		EvenlySpreadTeams( Gamerules, TeamMembers )

		if not Silent then
			self:Print( "Teams were sorted randomly." )
		end
	end,
	-- Score based if available, random if not.
	[ Plugin.ShuffleMode.SCORE ] = function( self, Gamerules, Targets, TeamMembers, Silent )
		self:SortByScore( Gamerules, Targets, TeamMembers, Silent, self.SkillGetters.GetScore )

		if not Silent then
			self:Print( "Teams were sorted based on score per minute." )
		end
	end,

	-- KDR based works identically to score, the score data is what is different.
	[ Plugin.ShuffleMode.KDR ] = function( self, Gamerules, Targets, TeamMembers, Silent )
		self:SortByScore( Gamerules, Targets, TeamMembers, Silent, self.SkillGetters.GetKDR )

		if not Silent then
			self:Print( "Teams were sorted based on KDR." )
		end
	end,

	-- Hive data based. Relies on UWE's ranking data to be correct for it to work.
	[ Plugin.ShuffleMode.HIVE ] = function( self, Gamerules, Targets, TeamMembers )
		local SortTable = {}
		local Count = 0
		local Sorted = {}

		local RankFunc = self.SkillGetters.GetHiveSkill
		local TargetCount = #Targets

		for i = 1, TargetCount do
			local Player = Targets[ i ]
			local Skill = Max( RankFunc( Player, 1 ) or 0, RankFunc( Player, 2 ) or 0 )
			if Skill > 0 then
				Count = Count + 1
				SortTable[ Count ] = Player
			end
		end

		local Sorted = self:SortPlayersByRank( TeamMembers, SortTable, Count,
			TargetCount, self.SkillGetters.GetHiveSkill )

		self:Print( "Teams were sorted based on Hive skill ranking." )

		-- If some players have rank 0 or no rank data, sort them with the fallback instead.
		local FallbackTargets = GetFallbackTargets( Targets, Sorted )
		if #FallbackTargets > 0 then
			self.ShufflingModes[ self.Config.FallbackMode ]( self, Gamerules,
				FallbackTargets, TeamMembers, true )

			return
		end

		EvenlySpreadTeams( Gamerules, TeamMembers )
	end
}

do
	local Sqrt = math.sqrt
	local TableEmpty = table.Empty

	local function GetStandardDeviation( Players, Average, RankFunc, TeamNumber )
		local Sum = 0
		local RealCount = 0

		for i = 1, #Players do
			local Player = Players[ i ]
			if Player then
				local Skill = RankFunc( Player, TeamNumber )

				if Skill then
					RealCount = RealCount + 1
					Sum = Sum + ( Skill - Average ) ^ 2
				end
			end
		end

		if RealCount == 0 then
			return 0
		end

		return Sqrt( Sum / RealCount )
	end

	function BalanceModule:GetAverageSkill( Players, TeamNumber, RankFunc )
		return GetAverageSkillFunc( Players, RankFunc or self.SkillGetters.GetHiveSkill, TeamNumber )
	end

	function BalanceModule:ClearStatsCache()
		TableEmpty( self.TeamStatsCache )
	end

	function BalanceModule:PostJoinTeam()
		self:ClearStatsCache()
	end

	function BalanceModule:ClientDisconnect()
		self:ClearStatsCache()
	end

	function BalanceModule:GetTeamStats( RankFunc )
		RankFunc = RankFunc or self.SkillGetters.GetHiveSkill

		if self.TeamStatsCache[ RankFunc ] then
			-- Keep a cache of team stats as computing it can be expensive.
			-- The cache is cleared whenever team composition changes.
			return self.TeamStatsCache[ RankFunc ]
		end

		local Marines = GetEntitiesForTeam( "Player", 1 )
		local Aliens = GetEntitiesForTeam( "Player", 2 )

		local MarineSkill = self:GetAverageSkill( Marines, 1 )
		MarineSkill.StandardDeviation = GetStandardDeviation( Marines, MarineSkill.Average,
			RankFunc, 1 )

		local AlienSkill = self:GetAverageSkill( Aliens, 2 )
		AlienSkill.StandardDeviation = GetStandardDeviation( Aliens, AlienSkill.Average,
			RankFunc, 2 )

		local TeamStats
		if self.LastShuffleTeamLookup then
			local NumMatchingTeams = 0
			local NumTotal = 0
			local Counted = {}
			local function CountMatching( Player )
				if not Player.GetClient or not Player:GetClient() or not Player.GetTeamNumber then return end

				local Client = Player:GetClient()
				local SteamID = Client:GetUserId()
				if Counted[ SteamID ] then return end

				Counted[ SteamID ] = true

				local OldTeam = self.LastShuffleTeamLookup[ SteamID ]
				NumTotal = NumTotal + 1

				if Player:GetTeamNumber() == OldTeam then
					NumMatchingTeams = NumMatchingTeams + 1
				end
			end

			Shine.Stream( Shine.GetAllPlayers() ):ForEach( CountMatching )

			TeamStats = {
				MarineSkill, AlienSkill,
				TotalPlayers = NumTotal,
				NumMatchingTeams = NumMatchingTeams
			}
		else
			TeamStats = {
				MarineSkill, AlienSkill
			}
		end

		self.TeamStatsCache[ RankFunc ] = TeamStats

		return TeamStats
	end
end

Plugin:AddModule( BalanceModule )
