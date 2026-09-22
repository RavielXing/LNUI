local _, GF = ...

-- BlacklistRepository is the sole owner of persisted blocklist rows, their
-- leader index, and the revision used by result filtering.
local Repository = {
	leaders = {},
	revision = 0,
}
GF.BlacklistRepository = Repository

local Matcher = GF.BlacklistMatcher

local function now()
	if type(time) == "function" then
		return time()
	end
	if type(GetTime) == "function" then
		return math.floor(GetTime())
	end
	return 0
end

local function formatTimestamp(timestamp)
	local value = tonumber(timestamp) or now()
	if type(date) == "function" then
		return date("%Y-%m-%d %H:%M", value)
	end
	return tostring(value)
end

function Repository:GetDatabase()
	return GF.GetDB()
end

function Repository:GetRows()
	local database = self:GetDatabase()
	return type(database.blocklist) == "table" and database.blocklist or nil
end

function Repository:RepairRows()
	local database = self:GetDatabase()
	if type(database.blocklist) ~= "table" then
		database.blocklist = {}
		return database.blocklist
	end

	local rows = database.blocklist
	local numericKeys, validKeys = {}, {}
	for key, row in pairs(rows) do
		if type(key) == "number" then
			numericKeys[#numericKeys + 1] = key
			if key >= 1 and key % 1 == 0 and type(row) == "table" then
				validKeys[#validKeys + 1] = key
			end
		end
	end
	table.sort(validKeys)
	local validRows = {}
	for _, key in ipairs(validKeys) do
		validRows[#validRows + 1] = rows[key]
	end
	-- Clear all numeric slots before rebuilding; # cannot describe sparse data.
	for _, key in ipairs(numericKeys) do
		rows[key] = nil
	end
	for index, row in ipairs(validRows) do
		rows[index] = row
	end
	return rows
end

function Repository:ClearStandaloneSourceLinks(rows)
	for _, row in ipairs(rows or {}) do
		if type(row) == "table" and row.kind == "leader"
			and Matcher.SourceCreatesStandaloneLeader(row.source)
		then
			row.sourceTitle = nil
		end
	end
end

function Repository:FindLeader(leader, sourceTitle)
	return Matcher.FindLeader(self:GetRows(), leader, sourceTitle)
end

function Repository:FindTitle(title)
	return Matcher.FindTitle(self:GetRows(), title)
end

function Repository:IsTitleParentLeader(title, leader)
	return Matcher.IsTitleParentLeader(self:GetRows(), title, leader)
end

function Repository:PruneRedundantTitleChildren(rows)
	local database = self:GetDatabase()
	local source = rows or self:GetRows() or {}
	local kept = {}
	local removed = false
	for _, row in ipairs(source) do
		local redundant = type(row) == "table" and row.kind == "leader"
			and row.sourceTitle ~= nil
			and Matcher.IsTitleParentLeader(source, row.sourceTitle, row.leader)
		if redundant then
			removed = true
		else
			kept[#kept + 1] = row
		end
	end
	if removed then
		database.blocklist = kept
		return kept, true
	end
	return source, false
end

function Repository:Rebuild(enabled)
	local rows = self:RepairRows()
	self:ClearStandaloneSourceLinks(rows)
	if enabled == true then
		rows = self:PruneRedundantTitleChildren(rows)
	end

	local leaders = {}
	if enabled == true then
		for _, row in ipairs(rows) do
			local leader = type(row) == "table"
				and Matcher.NormalizeLeader(row.leader) or nil
			local supported = type(row) == "table"
				and (row.kind == "leader" or row.kind == "title")
			if leader ~= nil and supported then
				leaders[leader] = true
			end
		end
	end
	self.leaders = leaders
	self:BumpRevision()
	return leaders
end

function Repository:BumpRevision()
	self.revision = 1 + (self.revision or 0)
	return self.revision
end

function Repository:GetRevision()
	return self.revision or 0
end

function Repository:GetLeaderIndex()
	return self.leaders
end

function Repository:IndexLeader(leader)
	local normalized = Matcher.NormalizeLeader(leader)
	if normalized == nil then
		return false
	end
	self.leaders[normalized] = true
	return true
end

function Repository:HasLeader(leader)
	local normalized = Matcher.NormalizeLeader(leader)
	return normalized ~= nil and self.leaders[normalized] == true
end

function Repository:Touch(row, options)
	if type(row) ~= "table" then
		return false
	end
	local fields = type(options) == "table" and options or {}
	local timestamp = now()
	row.addedAt = tonumber(row.addedAt) or timestamp
	row.updatedAt = timestamp
	row.time = formatTimestamp(timestamp)
	if type(fields.source) == "string" and fields.source ~= "" then
		row.source = fields.source
	end
	if type(fields.key) == "string" and fields.key ~= "" then
		row.key = fields.key
	elseif row.kind == "leader" then
		row.key = row.key or Matcher.BuildLeaderKey(row.leader)
	end
	if fields.clearSourceTitle == true then
		row.sourceTitle = nil
	elseif Matcher.IsUsableText(fields.sourceTitle) then
		row.sourceTitle = fields.sourceTitle
	end
	local label = Matcher.Trim(fields.displayLabel)
	if label ~= "" then
		row.displayLabel = label
	end
	local note = Matcher.Trim(fields.note)
	if note ~= "" then
		row.note = note
	elseif fields.forceNote == true then
		row.note = Matcher.DefaultNoteForSource(fields.source)
	end
	return true
end

function Repository:FindExisting(kind, leader, title)
	if kind == "leader" then
		return self:FindLeader(leader)
	end
	if kind == "title" then
		return self:FindTitle(title)
	end
	return nil
end

function Repository:CreateRow(kind, leader, title, note, options)
	local timestamp = now()
	local row = {
		leader = leader or title,
		kind = kind,
		addedAt = timestamp,
		updatedAt = timestamp,
		time = formatTimestamp(timestamp),
	}
	if kind == "leader" then
		row.key = Matcher.BuildLeaderKey(leader)
	end
	if Matcher.IsUsableText(title) then
		row.title = title
	end
	local customNote = Matcher.Trim(note)
	if customNote ~= "" and not Matcher.IsSystemNote(kind, customNote, GF.L) then
		row.note = customNote
	elseif options.forceNote == true then
		row.note = Matcher.DefaultNoteForSource(options.source)
	end
	if type(options.source) == "string" and options.source ~= "" then
		row.source = options.source
	end
	if Matcher.IsUsableText(options.sourceTitle) then
		row.sourceTitle = options.sourceTitle
	end
	local label = Matcher.Trim(options.displayLabel)
	if label ~= "" then
		row.displayLabel = label
	end
	return row
end

function Repository:Add(kind, leader, title, note, options)
	local fields = type(options) == "table" and options or {}
	local normalizedLeader = Matcher.NormalizeLeader(leader)
	local validLeader = kind == "leader" and normalizedLeader ~= nil
	local validTitle = kind == "title" and Matcher.IsUsableText(title)
	if not validLeader and not validTitle then
		return nil
	end
	local rows = self:RepairRows()
	local existing = self:FindExisting(kind, normalizedLeader, title)
	if existing then
		local update = {
			displayLabel = fields.displayLabel,
			note = note,
		}
		if kind == "leader" then
			update.source = fields.source
			update.sourceTitle = fields.sourceTitle
			update.clearSourceTitle = fields.clearSourceTitle
			update.forceNote = fields.forceNote
		end
		self:Touch(existing, update)
		return existing, true
	end
	local row = self:CreateRow(
		kind, normalizedLeader, title, note, fields)
	table.insert(rows, 1, row)
	return row, false
end

function Repository:GetTitleChildren(titleEntry)
	local children = {}
	local title = type(titleEntry) == "table" and titleEntry.title or nil
	if not Matcher.IsUsableText(title) then
		return children
	end
	local seen = {}
	local parentLeader = Matcher.NormalizeLeader(titleEntry.leader)
	if parentLeader ~= nil then
		seen[parentLeader] = true
	end
	for _, row in ipairs(self:GetRows() or {}) do
		local child = type(row) == "table" and row.kind == "leader"
			and Matcher.SafeTextEquals(row.sourceTitle, title)
		local leader = child and Matcher.NormalizeLeader(row.leader) or nil
		if leader ~= nil and not seen[leader] then
			seen[leader] = true
			children[#children + 1] = row
		end
	end
	return children
end

function Repository:ParseTimestamp(row)
	if type(row) ~= "table" then
		return 0
	end
	local value = tonumber(row.updatedAt or row.addedAt)
	if value and value > 0 then
		return value
	end
	if type(row.time) == "string" then
		local year, month, day, hour, minute = row.time:match(
			"^(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+)$")
		if year and type(time) == "function" then
			return time({
				year = tonumber(year), month = tonumber(month),
				day = tonumber(day), hour = tonumber(hour),
				min = tonumber(minute), sec = 0,
			}) or 0
		end
	end
	return 0
end

function Repository:EnsurePresentationFields(row, fallbackKey)
	local timestamp = self:ParseTimestamp(row)
	if timestamp <= 0 then
		timestamp = now()
	end
	row.key = row.key or fallbackKey
	row.addedAt = tonumber(row.addedAt) or timestamp
	row.updatedAt = tonumber(row.updatedAt) or timestamp
	row.time = row.time or formatTimestamp(timestamp)
	return timestamp
end

function Repository:FindByKey(key)
	if key == nil then
		return nil
	end
	for index, row in ipairs(self:GetRows() or {}) do
		local rowKey = row.key
			or (row.kind == "leader" and Matcher.BuildLeaderKey(row.leader))
			or ("row:" .. tostring(index))
		if rowKey == key then
			row.key = rowKey
			return row, index
		end
	end
	return nil
end

function Repository:ResolveRow(entryOrKey)
	if type(entryOrKey) == "table" then
		return entryOrKey._row or entryOrKey
	end
	return self:FindByKey(entryOrKey)
end

function Repository:SetNote(entryOrKey, note)
	local row = self:ResolveRow(entryOrKey)
	if row == nil then
		return false
	end
	row.note = tostring(note or "")
	self:Touch(row, {})
	return true, row
end

function Repository:Remove(entryOrKey)
	local database = self:GetDatabase()
	local target = self:ResolveRow(entryOrKey)
	if target == nil then
		return false
	end
	local title = target.kind == "title" and target.title or nil
	local kept, found = {}, false
	for _, row in ipairs(self:GetRows() or {}) do
		local remove = row == target
			or (title ~= nil and Matcher.SafeTextEquals(row.sourceTitle, title))
		if remove then
			found = found or row == target
		else
			kept[#kept + 1] = row
		end
	end
	if not found then
		return false
	end
	database.blocklist = kept
	return true, target
end

function Repository:Clear()
	local database = self:GetDatabase()
	if type(database) ~= "table" then
		return false, 0
	end
	if type(database.blocklist) ~= "table" then
		database.blocklist = {}
		return true, 0
	end

	local rows = database.blocklist
	local keys = {}
	local removedCount = 0
	for key, row in pairs(rows) do
		keys[#keys + 1] = key
		if type(key) == "number" and key >= 1 and key % 1 == 0
			and type(row) == "table"
		then
			removedCount = removedCount + 1
		end
	end
	for index = 1, #keys do
		rows[keys[index]] = nil
	end
	return true, removedCount
end
