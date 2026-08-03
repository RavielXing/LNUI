local _, GF = ...

GF.FindGroup = {}
local FG = GF.FindGroup

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

local function getBlocklistRevision(bl)
	return bl and bl.GetRevision and bl:GetRevision() or 0
end

local function cacheBlockedMember(entry, revision, member, row)
	if not entry then
		return
	end
	entry._blockedMemberChecked = true
	entry._blockedMemberRevision = revision
	entry._blockedMember = member
	entry._blockedMemberRow = row
	entry.hasBlockedMember = member ~= nil or nil
end

local function testBlockedMember(bl, member)
	if not member or type(member.name) ~= "string" or member.name == "" then
		return nil, nil
	end
	local row = bl:FindPlayerMatch(member.name)
	if row then
		return member, row
	end
	return nil, nil
end

local function getLaonongFanRevision()
	return GF.GetLaonongFanDirectoryRevision
		and GF.GetLaonongFanDirectoryRevision() or 0
end

local function cacheLaonongFanMember(entry, revision, member)
	if not entry then
		return
	end
	entry._laonongFanChecked = true
	entry._laonongFanRevision = revision
	entry._laonongFanMember = member
	entry.hasLaonongFanMember = member ~= nil or nil
end

local function clearLaonongFanMemberCache(entry)
	if not entry then
		return
	end
	entry._laonongFanChecked = nil
	entry._laonongFanRevision = nil
	entry._laonongFanMember = nil
	entry.hasLaonongFanMember = nil
end

local function getExpectedMemberCount(info)
	local numMembers = tonumber(info and info.numMembers) or 0
	if numMembers < 0 then
		return 0
	end
	return math.floor(numMembers + 0.0001)
end

local function canCacheLaonongMiss(info, loadedCount)
	local expected = getExpectedMemberCount(info)
	if expected <= 0 then
		return true
	end
	return (tonumber(loadedCount) or 0) >= expected
end

local function isSecretPlayerName(name)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, name)
	return ok and secret == true
end

local function isUsableLaonongPlayerName(name)
	return type(name) == "string"
		and not isSecretPlayerName(name)
		and name ~= ""
end

local function isLoadedLaonongMemberInfo(member)
	return type(member) == "table"
		and isUsableLaonongPlayerName(member.name)
end

local function getRealmFromFullName(name)
	if not isUsableLaonongPlayerName(name) then
		return nil
	end
	local _, realm = name:match("^([^%-]+)%-(.+)$")
	return realm
end

local function getLaonongFallbackRealm(member, info)
	if not member or not isUsableLaonongPlayerName(member.name) then
		return nil
	end
	if member.name:find("-", 1, true) then
		return nil
	end
	if member.isLeader and info then
		return getRealmFromFullName(info.leaderName)
	end
	return nil
end

local function testLaonongFanMember(member, info)
	if not member or not isUsableLaonongPlayerName(member.name) then
		return nil
	end
	if GF.IsLaonongFanName
		and GF.IsLaonongFanName(member.name, getLaonongFallbackRealm(member, info), true)
	then
		return member
	end
	return nil
end

function FG:FindBlockedMember(resultID, info, entry)
	local bl = getBlocklist()
	if not bl or not resultID or not info then
		return nil, nil
	end
	local revision = getBlocklistRevision(bl)
	if entry and entry._blockedMemberChecked and entry._blockedMemberRevision == revision then
		return entry._blockedMember, entry._blockedMemberRow
	end
	if entry and entry.players then
		for _, member in ipairs(entry.players) do
			local blockedMember, blockedRow = testBlockedMember(bl, member)
			if blockedMember then
				cacheBlockedMember(entry, revision, blockedMember, blockedRow)
				return blockedMember, blockedRow
			end
		end
		cacheBlockedMember(entry, revision, nil, nil)
		return nil, nil
	end
	if not (C_LFGList and C_LFGList.GetSearchResultPlayerInfo) then
		cacheBlockedMember(entry, revision, nil, nil)
		return nil, nil
	end
	local numMembers = tonumber(info.numMembers) or 0
	for i = 1, numMembers do
		local ok, member = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
		if ok then
			local blockedMember, blockedRow = testBlockedMember(bl, member)
			if blockedMember then
				cacheBlockedMember(entry, revision, blockedMember, blockedRow)
				return blockedMember, blockedRow
			end
		end
	end
	cacheBlockedMember(entry, revision, nil, nil)
	return nil, nil
end

function FG:FindLaonongFanMember(resultID, info, entry)
	if not resultID or not info or not GF.IsLaonongFanName then
		return nil
	end
	if not (GF.IsLaonongFanDirectoryReady and GF.IsLaonongFanDirectoryReady()) then
		clearLaonongFanMemberCache(entry)
		return nil
	end
	local revision = getLaonongFanRevision()
	if entry and entry._laonongFanChecked and entry._laonongFanRevision == revision then
		return entry._laonongFanMember
	end
	clearLaonongFanMemberCache(entry)
	if entry and entry.players then
		local loadedCount = 0
		for _, member in ipairs(entry.players) do
			if isLoadedLaonongMemberInfo(member) then
				loadedCount = loadedCount + 1
			end
			local laonongFanMember = testLaonongFanMember(member, info)
			if laonongFanMember then
				cacheLaonongFanMember(entry, revision, laonongFanMember)
				return laonongFanMember
			end
		end
		if canCacheLaonongMiss(info, loadedCount) then
			cacheLaonongFanMember(entry, revision, nil)
		end
		return nil
	end
	if not (C_LFGList and C_LFGList.GetSearchResultPlayerInfo) then
		clearLaonongFanMemberCache(entry)
		return nil
	end
	local numMembers = getExpectedMemberCount(info)
	local loadedCount = 0
	for i = 1, numMembers do
		local ok, member = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
		if ok and isLoadedLaonongMemberInfo(member) then
			loadedCount = loadedCount + 1
			local laonongFanMember = testLaonongFanMember(member, info)
			if laonongFanMember then
				cacheLaonongFanMember(entry, revision, laonongFanMember)
				return laonongFanMember
			end
		end
	end
	if canCacheLaonongMiss(info, loadedCount) then
		cacheLaonongFanMember(entry, revision, nil)
	else
		clearLaonongFanMemberCache(entry)
	end
	return nil
end

function FG:CacheLaonongFanMember(entry, member)
	if not entry or not member
		or not isUsableLaonongPlayerName(member.name)
		or not (GF.IsLaonongFanDirectoryReady and GF.IsLaonongFanDirectoryReady())
	then
		return false
	end
	local revision = getLaonongFanRevision()
	local cached = entry._laonongFanMember
	if entry._laonongFanChecked
		and entry._laonongFanRevision == revision
		and cached
		and isUsableLaonongPlayerName(cached.name)
		and isUsableLaonongPlayerName(member.name)
		and cached.name == member.name
	then
		return false
	end
	cacheLaonongFanMember(entry, revision, member)
	return true
end

function FG:InvalidateLaonongFanMemberCache(entry)
	clearLaonongFanMemberCache(entry)
end

function FG:GetResultType(info, entry, resultID)
	if not info then
		return nil
	end
	if resultID and GF.Blocklist and GF.Blocklist.FindMatch
		and GF.Blocklist:FindMatch(resultID, info) then
		return "blacklist"
	end
	if resultID and self:FindBlockedMember(resultID, info, entry) then
		return "blacklist"
	end
	if entry and entry.hasLeaver == true then
		return "leaver"
	end
	if self:IsCurrentGroupListing(info, resultID) then
		return GF.RESULT_TYPE_CURRENT_GROUP
	end
	local socialType = GF.GetSearchResultSocialType and GF.GetSearchResultSocialType(info, resultID)
	if socialType then
		return socialType
	end
	if resultID and self:FindLaonongFanMember(resultID, info, entry) then
		return GF.SOCIAL_TYPE_LAONONG
	end
	return nil
end

function FG:GetResultDisplayType(info, entry, resultID, resultType)
	resultType = resultType or self:GetResultType(info, entry, resultID)
	if resultType == GF.SOCIAL_TYPE_BNET
		or resultType == GF.SOCIAL_TYPE_GUILD
		or resultType == GF.SOCIAL_TYPE_FRIEND then
		if resultID and self:FindLaonongFanMember(resultID, info, entry) then
			return GF.SOCIAL_TYPE_LAONONG
		end
	end
	return resultType
end

function FG:RunSearch(selection, context)
	if not GF.Search or not GF.Search.Run then
		return false
	end
	return GF.Search:Run(selection, context)
end
