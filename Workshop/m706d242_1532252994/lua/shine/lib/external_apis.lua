--[[
	Handles external API endpoints, such as the Steam API.
]]

local Shine = Shine

local OSTime = os.time
local StringFormat = string.format
local tostring = tostring

local APIs = {
	Steam = {
		URL = "http://api.steampowered.com/",
		Params = {
			key = tostring
		},
		GlobalRequestParams = {},
		APIKey = "key",
		EndPoints = {
			-- Determines if a player is playing with a family shared account.
			-- Callback returns the NS2ID of the player sharing the game, or false if the player owns the game.
			IsPlayingSharedGame = {
				Protocol = "GET",
				URL = "IPlayerService/IsPlayingSharedGame/v0001/",
				Params = {
					steamid = Shine.NS2IDTo64
				},
				DefaultRequestParams = {
					appid_playing = "4920",
					format = "json"
				},
				GetCacheKey = function( Params ) return tostring( Params.steamid ) end,
				ResponseTransformer = function( Response )
					-- Do not cache on invalid JSON.
					if not Response then return nil end

					local Lender = Response.lender_steamid
					if not Lender or Lender == "0" then return false end

					return Shine.SteamID64ToNS2ID( Lender )
				end
			}
		}
	}
}

local APICallers = {}

do
	local Decode = json.decode
	local next = next
	local pairs = pairs
	local setmetatable = setmetatable
	local TableShallowMerge = table.ShallowMerge

	--[[
		Registers an endpoint under the given API.

		Data should contain the following fields:
		- CacheLifeTime: If provided, the amount of time, in seconds, to cache responses.

		- DefaultRequestParams: If provided, a table of query parameters that should always
		  be sent with every request to this endpoint.

		- GetCacheKey: If provided, should be a function that returns a single string that
		  uniquely identifies the given request parameters for this endpoint. If not provided,
		  the end point's results will not be cached.

		- Params: A table of functions which receive a single value, and return a string.
		  These will be used to convert the provided request parameters.

		- Protocol: The protocol the API requires, e.g. "GET" or "POST".

		- ResponseTransformer: A function that receives the JSON object from the response,
		  and should return a value representing the response. The value returned will also
		  be the value cached if a cache key is provided for the request. Returning nil will
		  prevent the response being cached.

		- URL: The path to append to the API's primary URL.
	]]
	local function RegisterEndPoint( APIName, EndPointName, Data )
		local APIData = APIs[ APIName ]
		if not APIData then
			error( "Attempted to register an endpoint before its API", 2 )
		end

		APIData.EndPoints[ EndPointName ] = Data
		APICallers[ APIName ] = APICallers[ APIName ] or {}

		local URL = APIData.URL..Data.URL

		-- Inherit the base API definition's parameters automatically.
		if Data.DefaultRequestParams then
			setmetatable( Data.DefaultRequestParams, { __index = APIData.GlobalRequestParams } )
		end

		local Params = TableShallowMerge( Data.Params, {} )
		TableShallowMerge( APIData.Params, Params )

		Data.CacheLifeTime = Data.CacheLifeTime or APIData.CacheLifeTime

		APICallers[ APIName ][ EndPointName ] = function( RequestParams, Callbacks, Attempts )
			Attempts = Attempts or 1

			-- Inherit the base API definition's global request parameters (e.g. for an API key).
			setmetatable( RequestParams, { __index = Data.DefaultRequestParams or APIData.GlobalRequestParams } )

			-- Parse the request parameters using the set converters.
			local FinalParams = {}
			for Key, Transformer in pairs( Params ) do
				if not RequestParams[ Key ] then
					error( StringFormat( "Missing request parameter: '%s'", Key ), 2 )
				end

				FinalParams[ Key ] = Transformer( RequestParams[ Key ] )
			end

			-- Pass the transformed JSON response through to the OnSuccess callback.
			local OldOnSuccess = Callbacks.OnSuccess
			Callbacks.OnSuccess = function( Response )
				OldOnSuccess( Data.ResponseTransformer( Decode( Response ) ) )
			end

			if next( FinalParams ) then
				Shine.HTTPRequestWithRetry( URL, Data.Protocol, FinalParams, Callbacks, Attempts )
			else
				Shine.HTTPRequestWithRetry( URL, Data.Protocol, Callbacks, Attempts )
			end
		end
	end
	Shine.RegisterExternalAPIEndPoint = RegisterEndPoint

	local function RegisterAPI( APIName, APIData )
		for EndPointName, Data in pairs( APIData.EndPoints ) do
			RegisterEndPoint( APIName, EndPointName, Data )
		end
	end

	--[[
		Registers an external API.

		Data should contain the following fields:
		- APIKey: Determines the request parameter that represents the API key for this API. If provided,
		  a matching key for the API's name in the base config will be mapped to this request parameter
		  under the "GlobalRequestParams" table.

		- CacheLifeTime: If provided, the amount of time, in seconds, to cache responses for all endpoints
		  under this API (except those that provide their own value).

		- EndPoints: A table of endpoint definitions (see above).

		- GlobalRequestParams: If provided, a table of parameters to use as defaults for all requests
		  under this API. Useful for a single global API key.

		- Params: If provided, a list of parameters that are always required, e.g. an API key.

		- URL: The base URL all endpoints start with.
	]]
	function Shine.RegisterExternalAPI( APIName, Data )
		Data.EndPoints = Data.EndPoints or {}
		APIs[ APIName ] = Data

		RegisterAPI( APIName, Data )
	end

	for APIName, APIData in pairs( APIs ) do
		RegisterAPI( APIName, APIData )
	end
end

local ExternalAPIHandler = {
	Cache = {},
	Queue = Shine.Queue()
}
Shine.ExternalAPIHandler = ExternalAPIHandler

-- Only cache to disk on the server, not the client.
if Server then
	local APICacheFile = "config://shine/ExternalAPICache.json"

	-- Default cache life time is 1 day. APIs and their endpoints may override this.
	ExternalAPIHandler.CacheLifeTime = 60 * 60 * 24

	function ExternalAPIHandler:SaveCache()
		if not next( self.Cache ) and not self.LoadedFromDisk then return end

		Shine.SaveJSONFile( self.Cache, APICacheFile )
	end

	-- Delete any cached responses older than the cache life time.
	local function TrimCache( Cache )
		local Time = OSTime()

		-- Horrible nested loops, but it's only run once on startup.
		for APIName, EndPointCaches in pairs( Cache ) do
			for EndPointName, EndPointCache in pairs( EndPointCaches ) do
				for CacheKey, CacheEntry in pairs( EndPointCache ) do
					if CacheEntry.ExpiryTime < Time then
						EndPointCache[ CacheKey ] = nil
					end
				end

				if not next( EndPointCache ) then
					EndPointCaches[ EndPointName ] = nil
				end
			end

			if not next( EndPointCaches ) then
				Cache[ APIName ] = nil
			end
		end
	end

	Shine.Hook.Add( "PostloadConfig", "ExternalAPIHandlerCache", function()
		local DiskCache = Shine.LoadJSONFile( APICacheFile )
		ExternalAPIHandler.Cache = DiskCache or ExternalAPIHandler.Cache
		ExternalAPIHandler.LoadedFromDisk = DiskCache ~= false

		TrimCache( ExternalAPIHandler.Cache )

		for Name, Key in pairs( Shine.Config.APIKeys ) do
			local APIData = APIs[ Name ]
			if Key ~= "" and APIData and APIData.GlobalRequestParams then
				APIData.GlobalRequestParams[ APIData.APIKey or "key" ] = Key
			end
		end
	end )

	Shine.Hook.Add( "MapChange", "ExternalAPIHandlerCache", function()
		ExternalAPIHandler:SaveCache()
	end )
end

--[[
	Returns the requested API definition, if it exists.
]]
function ExternalAPIHandler:GetAPI( APIName )
	return APIs[ APIName ]
end

--[[
	Returns true if the given API has an API key global request parameter stored, as defined
	by the "APIKey" entry in the API's definition.
]]
function ExternalAPIHandler:HasAPIKey( APIName )
	local APIData = APIs[ APIName ]
	if not APIData then return false end

	return ( APIData.GlobalRequestParams and APIData.GlobalRequestParams[ APIData.APIKey ] ) ~= nil
end

--[[
	Returns the requested endpoint definition, if it exists.
]]
function ExternalAPIHandler:GetEndPoint( APIName, EndPointName )
	return APIs[ APIName ] and APIs[ APIName ].EndPoints[ EndPointName ]
end

--[[
	Internal function, throws an error if the given API and endpoint do not exist.
]]
function ExternalAPIHandler:VerifyEndPoint( APIName, EndPointName )
	local EndPoint = self:GetEndPoint( APIName, EndPointName )
	if not EndPoint then
		error( StringFormat( "Attempted to use a non-existent API endpoint (%s.%s)", APIName, EndPointName ), 3 )
	end
	return EndPoint
end

--[[
	Returns the value cached for the given API, endpoint and request parameters.
	This will be nil if no value is stored.
]]
function ExternalAPIHandler:GetCachedValue( APIName, EndPointName, Params )
	local EndPoint = self:VerifyEndPoint( APIName, EndPointName )

	-- Endpoints decide how their parameters should map in the cache (if at all).
	local CacheKey = EndPoint.GetCacheKey and EndPoint.GetCacheKey( Params )
	local EndPointCache = self.Cache[ APIName ] and self.Cache[ APIName ][ EndPointName ]
	if not EndPointCache or CacheKey == nil then
		return nil
	end

	-- Refresh the expiry time on access.
	local CacheEntry = EndPointCache[ CacheKey ]
	if CacheEntry then
		local Time = OSTime()

		-- Expire if it's past the expiry time, don't refresh.
		if CacheEntry.ExpiryTime <= Time then
			EndPointCache[ CacheKey ] = nil
			return nil
		end

		CacheEntry.ExpiryTime = Time + ( EndPoint.CacheLifeTime or self.CacheLifeTime )
	end

	return CacheEntry and CacheEntry.Value
end

do
	local OnError = Shine.BuildErrorHandler( "External API callback error" )
	local TableBuild = table.Build
	local unpack = unpack
	local xpcall = xpcall

	--[[
		Adds a value to the request cache for the given API/endpoint.

		Cached values have a fixed lifetime, after which they expire if they have not
		been accessed or updated.
	]]
	function ExternalAPIHandler:AddToCache( APIName, EndPointName, Params, Result )
		if Result == nil then return end

		local EndPoint = self:GetEndPoint( APIName, EndPointName )
		local CacheKey = EndPoint.GetCacheKey and EndPoint.GetCacheKey( Params )
		if CacheKey == nil then return end

		local Cached = TableBuild( self.Cache, APIName, EndPointName )
		Cached[ CacheKey ] = {
			Value = Result,
			ExpiryTime = OSTime() + ( EndPoint.CacheLifeTime or self.CacheLifeTime )
		}
	end

	--[[
		Performs a request to a registered external API URL.

		Inputs:
			1. APIName - The name of the API.
			2. EndPointName - The name of the endpoint under the API.
			3. Params - The request parameters, endpoint dependent.
			4. Callbacks - A table containing functions "OnSuccess", "OnFailure" and
			   optionally "OnTimeout". "OnSuccess" receives the response from the API (transformed by
			   the endpoint definition).
			5. Attempts - Optional maximum number of retry attempts, defaults to only 1 attempt.
	]]
	function ExternalAPIHandler:PerformRequest( APIName, EndPointName, Params, Callbacks, Attempts )
		local EndPoint = self:VerifyEndPoint( APIName, EndPointName )
		local Caller = APICallers[ APIName ][ EndPointName ]

		-- Cache the result and advance the queue on success.
		local OldOnSuccess = Callbacks.OnSuccess
		Callbacks.OnSuccess = function( Result )
			self:AddToCache( APIName, EndPointName, Params, Result )

			xpcall( OldOnSuccess, OnError, Result )

			self:ProcessQueue()
		end

		-- Advance the queue on failure.
		local OldOnFailure = Callbacks.OnFailure
		Callbacks.OnFailure = function()
			xpcall( OldOnFailure, OnError )

			self:ProcessQueue()
		end

		self.Queue:Add( {
			Caller = Caller,
			Args = { Params, Callbacks, Attempts }
		} )

		-- Waiting on previous request(s) to finish.
		if self.Queue:GetCount() > 1 then return end

		self:ProcessQueue()
	end

	local OnQueueError = Shine.BuildErrorHandler( "External API call error" )

	--[[
		Internal function, do not call. This is called automatically as requests
		are added and satisfied.

		Advances the request queue, if there are still requests pending.
	]]
	function ExternalAPIHandler:ProcessQueue()
		local Queued = self.Queue:Pop()
		if not Queued then return end

		-- If the function fails, skip it and go to the next entry.
		local Success = xpcall( Queued.Caller, OnQueueError, unpack( Queued.Args ) )
		if not Success then
			self:ProcessQueue()
		end
	end
end
