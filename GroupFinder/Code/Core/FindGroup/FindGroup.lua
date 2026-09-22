local _, GF = ...

GF.FindGroup = {}
local FG = GF.FindGroup

local function accessibleValue(value)
	if type(value) == "nil" then
		return true
	end
	local compat = GF.Compat
	if compat and type(compat.IsAccessibleValue) == "function" then
		return compat.IsAccessibleValue(value) == true
	end
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret == true then
			return false
		end
	end
	return true
end

local function readAccessibleField(owner, key)
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.ReadField) == "function" then
		return snapshot.ReadField(owner, key)
	end
	local compat = GF.Compat
	if compat and type(compat.ReadAccessibleField) == "function" then
		return compat.ReadAccessibleField(owner, key)
	end
	if type(owner) ~= "table" then
		return nil, "unavailable"
	end
	if type(issecretvaluekey) == "function" then
		local ok, secret = pcall(issecretvaluekey, owner, key)
		if not ok then
			return nil, "error"
		end
		if secret == true then
			return nil, "secret"
		end
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok then
		return nil, "error"
	end
	if not accessibleValue(value) then
		return nil, "secret"
	end
	if type(value) == "nil" then
		return nil, "missing"
	end
	return value, "value"
end

local function readAccessibleNumber(owner, key)
	local value = readAccessibleField(owner, key)
	if type(value) == "nil" then
		return nil
	end
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.ToNumber) == "function" then
		return snapshot.ToNumber(value)
	end
	local compat = GF.Compat
	if compat and type(compat.ToAccessibleNumber) == "function" then
		return compat.ToAccessibleNumber(value)
	end
	if not accessibleValue(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	return ok and accessibleValue(number) and type(number) == "number"
		and number or nil
end

function FG:IsMythicPlusWorkspaceActive()
	local view = GF.LFGWorkspaceView
	local reader = view and view.IsMythicPlusActive
	if type(reader) == "function" then
		local ok, active = pcall(reader, view)
		if ok then
			return active == true
		end
	end
	reader = view and view.GetWorkspaceID
	if type(reader) ~= "function" then
		return false
	end
	local ok, workspaceID = pcall(reader, view)
	return ok and workspaceID == (GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus")
end

function FG:IsNetEaseIdentityBrowseEnabled()
	local service = GF.NetEaseIdentityService
	return self:IsMythicPlusWorkspaceActive()
		and service ~= nil
		and type(service.IsEnabled) == "function"
		and service:IsEnabled() == true
end

local function readSearchResultPlayer(resultID, memberIndex)
	local getter = C_LFGList and C_LFGList.GetSearchResultPlayerInfo
	if type(getter) ~= "function" then
		return nil, false
	end
	local diagnostics = GF.SearchMemoryDiagnostics
	if diagnostics and diagnostics.current then
		diagnostics:Add("playerInfoReads", 1)
		if diagnostics.MeasureProtectedFirst then
			return diagnostics:MeasureProtectedFirst(
				"playerInfo", getter, resultID, memberIndex)
		end
	end
	local ok, player = pcall(getter, resultID, memberIndex)
	return ok and player or nil, ok == true
end

function FG:IsSearchableSelection(node)
	if type(node) ~= "table" then
		return false
	end
	local view = GF.LFGWorkspaceView
	local allowsNode = view and view.IsNodeAllowed
	if allowsNode and allowsNode(view, node) == false then
		return false
	end
	local getWorkspace = view and view.GetWorkspaceID
	local workspaceID = getWorkspace and getWorkspace(view)
	local policy = GF.LFGWorkspacePolicy
	local policyAllows = policy and policy.IsSearchableNode
	if policyAllows and policyAllows(policy, workspaceID, node) == false then
		return false
	end
	local isSearchable = GF.NavData and GF.NavData.IsSearchable
	if isSearchable then
		return isSearchable(node) == true
	end
	return node.categoryID ~= nil
end

function FG:GetSelectionKey(node)
	return node and (node.searchKey or node.key) or nil
end

function FG:GetSearchCooldownRemaining(lastSearchAt)
	if not lastSearchAt or not GetTime then
		return 0
	end
	local remain = (GF.SEARCH_COOLDOWN or 3) - (GetTime() - lastSearchAt)
	if remain <= 0 then
		return 0
	end
	return remain
end

function FG:IsFriendListing(info, resultID)
	local socialType = GF.GetSearchResultSocialType and GF.GetSearchResultSocialType(info, resultID)
	return socialType == GF.SOCIAL_TYPE_BNET or socialType == GF.SOCIAL_TYPE_FRIEND
end

function FG:IsCurrentGroupListing(info, resultID)
	return GF.IsCurrentGroupSearchResult
		and GF.IsCurrentGroupSearchResult(info, resultID) == true
end

function FG:IsGuildListing(info, resultID)
	return GF.GetSearchResultSocialType
		and GF.GetSearchResultSocialType(info, resultID) == GF.SOCIAL_TYPE_GUILD
end

function FG:IsSocialListing(info, resultID)
	if GF.IsSocialSearchResult then
		return GF.IsSocialSearchResult(info, resultID)
	end
	return self:IsFriendListing(info, resultID) or self:IsGuildListing(info, resultID)
end

local function getBlocklist()
	local bl = GF.Blocklist
	if not bl or not bl.IsEnabled or not bl:IsEnabled() or not bl.FindPlayerMatch then
		return nil
	end
	return bl
end

local function readableMemberName(member)
	if type(member) ~= "table" then
		return nil
	end
	local name = readAccessibleField(member, "name")
	if type(name) ~= "string" or name == "" then
		return nil
	end
	return name
end

local function testBlockedMember(bl, member)
	local name = readableMemberName(member)
	if not name then
		return nil, nil, false
	end
	local row = bl:FindPlayerMatch(name)
	if row then
		return member, row, true
	end
	return nil, nil, true
end

local function scanBlockedMembers(bl, members, complete)
	if type(members) ~= "table" then
		return nil, nil, false
	end
	local lengthOK, length = pcall(function()
		return #members
	end)
	if not lengthOK or type(length) ~= "number" then
		return nil, nil, false
	end
	for index = 1, length do
		local memberOK, member = pcall(function()
			return members[index]
		end)
		local blockedMember, blockedRow, readable
		if memberOK then
			blockedMember, blockedRow, readable = testBlockedMember(bl, member)
		end
		if blockedMember then
			return blockedMember, blockedRow, true
		end
		complete = complete and memberOK and readable
	end
	return nil, nil, complete == true
end

function FG:FindBlockedMember(resultID, info, entry)
	local bl = getBlocklist()
	if not bl or not info then
		return nil, nil
	end
	local numMembers = readAccessibleNumber(info, "numMembers")
	if numMembers ~= nil and numMembers >= 0 then
		numMembers = math.floor(numMembers + 0.0001)
	else
		numMembers = nil
	end
	local snapshotPlayers = readAccessibleField(info, "_gfBlocklistPlayers")
	local snapshotComplete = readAccessibleField(
		info, "_gfBlocklistPlayersComplete") == true
	local hasPlayerSnapshot = type(snapshotPlayers) == "table"
	if hasPlayerSnapshot then
		local blockedMember, blockedRow, complete = scanBlockedMembers(
			bl, snapshotPlayers, snapshotComplete)
		if blockedMember then
			return blockedMember, blockedRow, true
		end
		if complete then
			return nil, nil, true
		end
	end
	if entry and type(entry.players) == "table" then
		local lengthOK, length = pcall(function()
			return #entry.players
		end)
		local blockedMember, blockedRow, complete = scanBlockedMembers(
			bl, entry.players,
			numMembers ~= nil and lengthOK and type(length) == "number"
				and length >= numMembers)
		if blockedMember then
			return blockedMember, blockedRow, true
		end
		if complete then
			return nil, nil, true
		end
	end
	-- A compact snapshot marks a result from an earlier aggregate scope. The
	-- native result store now belongs to a later scope, so an incomplete snapshot
	-- must fail open instead of reading unrelated player slots by result ID.
	if hasPlayerSnapshot then
		return nil, nil, false
	end
	if not resultID then
		return nil, nil, false
	end
	if not (C_LFGList and C_LFGList.GetSearchResultPlayerInfo) then
		return nil, nil, false
	end
	if numMembers == nil then
		return nil, nil, false
	end
	local complete = true
	for i = 1, numMembers do
		local member, ok = readSearchResultPlayer(resultID, i)
		if ok then
			local blockedMember, blockedRow, readable = testBlockedMember(bl, member)
			if blockedMember then
				return blockedMember, blockedRow, true
			end
			complete = complete and readable
		else
			complete = false
		end
	end
	return nil, nil, complete
end

function FG:FindBlocklistMatch(resultID, info, entry)
	local bl = getBlocklist()
	if not bl or not info then
		return nil, nil, nil, false
	end
	local kind, row
	if resultID then
		kind, row = bl:FindMatch(resultID, info)
	end
	if kind then
		return kind, row, nil, true
	end
	local member, memberRow, complete = self:FindBlockedMember(resultID, info, entry)
	if member then
		return "member", memberRow, member, true
	end
	return nil, nil, nil, complete
end

function FG:ShouldHideBlockedResult(resultID, info, entry)
	return self:FindBlocklistMatch(resultID, info, entry) ~= nil
end

function FG:GetTeamListTestTypeContext(info, entry, resultID)
	local provider = GF.TeamListTestData
	if not (provider and type(provider.GetTypeContext) == "function") then
		return nil
	end
	local ok, context = pcall(
		provider.GetTypeContext, provider, info, entry, resultID)
	return ok and type(context) == "table" and context or nil
end

function FG:GetResultType(info, entry, resultID)
	if not info then
		return nil
	end
	local identityService = GF.NetEaseIdentityService
	local testContext = self:GetTeamListTestTypeContext(info, entry, resultID)
	local identityEnabled
	local currentGroup
	if testContext ~= nil then
		identityEnabled = testContext.identityEnabled == true
		currentGroup = testContext.currentGroup == true
	else
		identityEnabled = self:IsNetEaseIdentityBrowseEnabled()
		currentGroup = self:IsCurrentGroupListing(info, resultID)
	end
	if currentGroup then
		if type(entry) == "table" then
			local blocked = testContext ~= nil
				and testContext.blocked == true
				or testContext == nil
					and self:FindBlocklistMatch(resultID, info, entry) ~= nil
			entry._gfNetEaseHasBlocklist = identityEnabled
				and blocked == true or nil
			if testContext ~= nil then
				entry._gfNetEaseGroupProjection = testContext.groupProjection
			end
			if not identityEnabled then
				entry._gfNetEaseGroupProjection = nil
			end
		end
		return GF.RESULT_TYPE_CURRENT_GROUP
	end
	if identityEnabled then
		local blocked
		if testContext ~= nil then
			blocked = testContext.blocked == true
		else
			blocked = self:FindBlocklistMatch(resultID, info, entry)
		end
		if blocked then
			if type(entry) == "table" then
				entry._gfNetEaseHasBlocklist = true
			end
			return "blacklist"
		end
		if type(entry) == "table" then
			entry._gfNetEaseHasBlocklist = false
		end
		local projection
		if testContext ~= nil then
			projection = testContext.groupProjection
		elseif identityService and identityService.GetGroupProjection then
			projection = identityService:GetGroupProjection(
				resultID, info, entry, { queue = true })
		end
		if type(entry) == "table" then
			entry._gfNetEaseGroupProjection = projection
		end
		if projection and projection.hasNewbie == true then
			return GF.NETEASE_IDENTITY_NEWBIE
		end
		local socialType = GF.GetSearchResultSocialType
			and GF.GetSearchResultSocialType(info, resultID)
		if socialType then
			return socialType
		end
		if entry and entry.hasLeaver == true then
			return "leaver"
		end
		return projection and projection.primaryType or nil
	end
	if type(entry) == "table" then
		entry._gfNetEaseGroupProjection = nil
		entry._gfNetEaseHasBlocklist = nil
	end
	if entry and entry.hasLeaver == true then
		return "leaver"
	end
	local socialType = GF.GetSearchResultSocialType and GF.GetSearchResultSocialType(info, resultID)
	if socialType then
		return socialType
	end
	local playstyle = readAccessibleField(info, "generalPlaystyle")
	return GF.GetResultPlaystyleType
		and GF.GetResultPlaystyleType(playstyle) or nil
end

function FG:RunSearch(selection, context)
	if not GF.Search or not GF.Search.Run then
		return false
	end
	return GF.Search:Run(selection, context)
end
