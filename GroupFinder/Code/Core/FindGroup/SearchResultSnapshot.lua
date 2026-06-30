local _, GF = ...

local Snapshot = GF.SearchResultSnapshot or {}
GF.SearchResultSnapshot = Snapshot

function Snapshot.GetPrimaryActivityID(info)
	if not info then
		return nil
	end
	if info.activityID then
		return info.activityID
	end
	if not info.activityIDs then
		return nil
	end
	local ok, activityID = pcall(function()
		return info.activityIDs[1]
	end)
	if ok then
		return activityID
	end
	return nil
end

function Snapshot.GetActivityInfo(info, activityID)
	if not activityID or not C_LFGList.GetActivityInfoTable then
		return nil
	end
	local ok, activity = pcall(C_LFGList.GetActivityInfoTable, activityID, info and info.questID, info and info.isWarMode)
	if ok then
		return activity
	end
	return nil
end

function Snapshot.ResolveActivityInfo(info, activityInfo)
	if activityInfo then
		return activityInfo
	end
	local activityID = Snapshot.GetPrimaryActivityID(info)
	if not activityID then
		return nil
	end
	return Snapshot.GetActivityInfo(info, activityID)
end

function Snapshot.ResolveActivityCategory(activityID)
	if not activityID then
		return nil, nil
	end
	local activity = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
	if activity and activity.categoryID then
		return activity.categoryID, activity
	end
	if activity then
		return nil, activity
	end
	if C_LFGList.GetActivityInfo then
		local ok, _, _, categoryID = pcall(C_LFGList.GetActivityInfo, activityID)
		if ok and categoryID then
			return categoryID, activity
		end
	end
	return nil, activity
end

function Snapshot.IsAvailable(info, activityInfo)
	if not info or info.isDelisted == true then
		return false
	end
	if not Snapshot.GetPrimaryActivityID(info) then
		return false
	end
	local activity = Snapshot.ResolveActivityInfo(info, activityInfo)
	if not activity then
		return false
	end
	local maxMembers = tonumber(activity.maxNumPlayers) or 0
	local numMembers = tonumber(info.numMembers) or 0
	return maxMembers <= 0 or numMembers < maxMembers
end

function Snapshot.HydrateEntry(entry, info)
	if not entry then
		return nil
	end
	info = info or entry.info
	local activityID = Snapshot.GetPrimaryActivityID(info)
	if not info or not activityID then
		return entry
	end
	local categoryID, activity = Snapshot.ResolveActivityCategory(activityID)
	entry.activity = activity or Snapshot.GetActivityInfo(info, activityID)
	if categoryID then
		entry.categoryID = categoryID
	elseif entry.activity and entry.activity.categoryID then
		entry.categoryID = entry.activity.categoryID
	end
	return entry
end

function Snapshot.NewEntry(resultID, info)
	if not resultID or not info then
		return nil
	end
	return Snapshot.HydrateEntry({ resultID = resultID, info = info }, info)
end
