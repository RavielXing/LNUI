local _, GF = ...

GF.FindGroup = {}
local FG = GF.FindGroup

function FG:IsSearchableSelection(node)
	if not node then
		return false
	end
	if GF.NavData and GF.NavData.IsSearchable then
		return GF.NavData.IsSearchable(node)
	end
	return node.categoryID ~= nil
end

function FG:GetSelectionKey(node)
	return node and node.key or nil
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
	local socialType = GF.GetSearchResultSocialType and GF.GetSearchResultSocialType(info, resultID)
	if socialType then
		return socialType
	end
	return nil
end

function FG:RunSearch(selection)
	if not GF.Search or not GF.Search.Run then
		return false
	end
	return GF.Search:Run(selection)
end
