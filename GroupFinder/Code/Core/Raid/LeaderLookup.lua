local _, GF = ...

-- A lookup belongs to one local browse selection and one live chat handshake.
-- Native result IDs never cross the addon-message boundary.
local Lookup = { serial = 0, fulfilledRequests = setmetatable({}, { __mode = "k" }) }
GF.RaidLeaderLookup = Lookup

function Lookup:GetTarget(selection)
	if selection == nil and GF.FindGroupTab then
		selection = GF.FindGroupTab:GetSelection()
	end
	return selection and selection._gfRaidLeaderLookup or nil
end

function Lookup:IsCurrent(target)
	local chat = GF.RaidSeekingChatService
	local contact = target and chat and chat:GetContact(target.contactKey)
	return contact ~= nil and contact.name == target.name
		and contact.activityID == target.activityID
		and contact.token == target.token and contact.session == target.session
		and contact.generation == target.generation
end

function Lookup:ShouldShowRequest(target)
	if not self:IsCurrent(target) then return false end
	local conversation = GF.RaidSeekingChatService:Get(target.contactKey)
	local request = conversation and conversation.applicationRequest
	-- Only the request explicitly opened by View Team owns this strip. A later
	-- incoming request must not turn an ordinary lookup into a persistent banner.
	if not request or request ~= target.applicationRequest then return false end
	if self.fulfilledRequests[conversation] == request then return false, "fulfilled" end
	local applications = GF.ApplicationService
	if applications then
		-- Only a confirmed native application to this exact leader fulfills the request.
		-- Opening/cancelling the signup dialog or an unreadable result does not.
		for _, resultID in ipairs(applications:ReadApplicationIDs() or {}) do
			local state = applications:ReadApplicationSnapshot(resultID)
			if state.known and (state.appStatus == "applied" or state.appStatus == "invited"
				or state.appStatus == "inviteaccepted") then
				local info = GF.SearchResultSnapshot.GetSearchResultInfo(resultID)
				if self:Matches(target, info) then
					self.fulfilledRequests[conversation] = request
					return false, "fulfilled"
				end
			end
		end
	end
	return true
end

function Lookup:Resolve(contactKey)
	local chat, nav = GF.RaidSeekingChatService, GF.NavData
	local contact = chat and chat:GetContact(contactKey)
	if not contact then return nil, "expired" end
	local found
	local function visit(node, depth)
		if not node or node.disabled or depth > 4 or found then return end
		if nav.EnsureChildren then nav.EnsureChildren(node) end
		if node.isLeaf and nav.ResolveCreateActivityID(node) == contact.activityID then
			found = node; return
		end
		for _, child in ipairs(node.children or {}) do visit(child, depth + 1) end
	end
	visit(nav and nav.FindNodeByKey("season_raid"), 0)
	if not found then return nil, "activity_unavailable" end
	self.serial = self.serial + 1
	local selection = {}
	for key, value in pairs(found) do selection[key] = value end
	contact.contactKey, contact.baseNode = contactKey, found
	local conversation = chat:Get(contactKey)
	contact.applicationRequest = conversation and conversation.applicationRequest
	selection.searchKey = (found.searchKey or found.key) .. ":leader:" .. self.serial
	selection._gfRaidLeaderLookup = contact
	return selection
end

function Lookup:Matches(target, info)
	if not self:IsCurrent(target) then return false end
	local read = GF.SearchResultSnapshot.ReadField
	if read(info, "isDelisted") ~= false then return false end
	local leader = read(info, "leaderName")
	-- A short native name is local-realm only; never append the target's realm.
	leader = GF.RaidSeekingChatService:NormalizeName(leader)
	if not leader or leader:lower() ~= target.name:lower() then return false end
	local activities = read(info, "activityIDs")
	if type(activities) ~= "table" then return false end
	for index = 1, 32 do
		local id = read(activities, index)
		if id == nil then break end
		if id == target.activityID then return true end
	end
	return false
end

function Lookup:CanApply(resultID)
	local target = self:GetTarget()
	if not target then return true end
	local info = GF.SearchResultSnapshot.GetSearchResultInfo(resultID)
	return self:Matches(target, info)
end
