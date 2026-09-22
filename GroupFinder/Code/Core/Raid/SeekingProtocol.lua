local _, GF = ...

-- Public channel data is untrusted text, never executable Lua or a native
-- applicant/result ID. Keep parsing independent from frames and game state.
local Protocol = {}
GF.RaidSeekingProtocol = Protocol
Protocol.PREFIX = "GFRS1:"
Protocol.MAX_PACKET_BYTES = 240
Protocol.MAX_BODY_BYTES = 1800
Protocol.MAX_PARTS = 12
Protocol.MAX_NOTE_BYTES = 120
Protocol.TTL = 180
Protocol.ASSEMBLY_TTL = 30
Protocol.MAX_SPECS = 4

function Protocol.Text(value)
	if GF.Compat and not GF.Compat.IsAccessibleValue(value) then return nil end
	return type(value) == "string" and value or nil
end

function Protocol.Integer(value, low, high)
	if GF.Compat and not GF.Compat.IsAccessibleValue(value) then return nil end
	local number = tonumber(value)
	return number and number == math.floor(number) and number >= low and number <= high and number or nil
end

function Protocol.FullName(value)
	value = Protocol.Text(value)
	if not value or #value > 160 or value:find("[|%c~%%]") then return nil end
	local name, realm = value:match("^([^%s%-]+)%-(.+)$")
	if not name or not realm then return nil end
	realm = realm:gsub("%s", "")
	return realm ~= "" and name .. "-" .. realm or nil
end

function Protocol.Truncate(text, limit)
	text = Protocol.Text(text) or ""
	if #text <= limit then return text end
	local finish = limit + 1
	while finish > 1 and text:byte(finish) >= 128 and text:byte(finish) < 192 do
		finish = finish - 1
	end
	return text:sub(1, finish - 1)
end

function Protocol.Display(text)
	return ((Protocol.Text(text) or ""):gsub("|", "||"):gsub("[%c]", " "))
end

function Protocol.CopySpecIDs(value)
	if type(value) ~= "table" then return nil end
	local ids, seen, count = {}, {}, 0
	for index, id in pairs(value) do
		id = Protocol.Integer(id, 1, 10000)
		if not Protocol.Integer(index, 1, Protocol.MAX_SPECS) or not id or seen[id] then return nil end
		ids[index], seen[id], count = id, true, count + 1
	end
	if #ids ~= count then return nil end
	table.sort(ids)
	return ids
end

function Protocol.GetSpecIDs(member)
	if member.specIDs then return member.specIDs end
	return member.specID and member.specID > 0 and { member.specID } or {}
end

function Protocol.HasSpec(member, specID)
	for _, id in ipairs(Protocol.GetSpecIDs(member)) do if id == specID then return true end end
	return false
end

local function readSpecIDs(value)
	value = tostring(value)
	if value == "0" then return {} end
	local ids = {}
	for id in value:gmatch("[^,]+") do ids[#ids + 1] = id end
	ids = Protocol.CopySpecIDs(ids)
	if not ids or #ids == 0 or table.concat(ids, ",") ~= value then return nil end
	return ids
end

local function escape(value)
	return tostring(value):gsub("[%%~%c|]", function(c) return string.format("%%%02X", c:byte()) end)
end

function Protocol.Encode(fields)
	local parts = {}
	if type(fields) ~= "table" or #fields > 96 then return nil end
	for index, value in ipairs(fields) do
		if type(value) ~= "string" and type(value) ~= "number" then return nil end
		parts[index] = escape(value)
	end
	local body = table.concat(parts, "~")
	return #body <= Protocol.MAX_BODY_BYTES and body or nil
end

function Protocol.Decode(body)
	if type(body) ~= "string" or #body > Protocol.MAX_BODY_BYTES or body:find("[%c|]") then return nil end
	local fields = {}
	for field in (body .. "~"):gmatch("(.-)~") do
		if #fields >= 96 or field:gsub("%%%x%x", ""):find("%%") then return nil end
		fields[#fields + 1] = field:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
	end
	return fields
end

function Protocol.Packets(session, sequence, fields)
	local body = Protocol.Encode(fields)
	if not body or body == "" or not Protocol.Text(session) or not session:match("^[%w]+$") or #session > 24
		or not Protocol.Integer(sequence, 1, 2147483647) then return nil end
	-- Reserve the longest allowed header so each UTF-8 fragment is bounded.
	local header = Protocol.PREFIX .. session .. ":" .. sequence .. ":12:12:"
	local capacity, chunks = Protocol.MAX_PACKET_BYTES - #header, {}
	while #body > 0 do
		local part = Protocol.Truncate(body, capacity)
		if #part == 0 or #chunks >= Protocol.MAX_PARTS then return nil end
		chunks[#chunks + 1] = part
		body = body:sub(#part + 1)
	end
	local packets = {}
	for index, chunk in ipairs(chunks) do
		packets[index] = Protocol.PREFIX .. session .. ":" .. sequence .. ":" .. index .. ":" .. #chunks .. ":" .. chunk
	end
	return packets
end

function Protocol.ParsePacket(packet)
	packet = Protocol.Text(packet)
	if not packet or #packet > Protocol.MAX_PACKET_BYTES then return nil end
	local session, sequence, index, total, chunk = packet:match("^GFRS1:([%w]+):(%d+):(%d+):(%d+):(.*)$")
	sequence = Protocol.Integer(sequence, 1, 2147483647)
	index, total = Protocol.Integer(index, 1, Protocol.MAX_PARTS), Protocol.Integer(total, 1, Protocol.MAX_PARTS)
	if not session or #session > 24 or not sequence or not index or not total or index > total
		or chunk == "" or chunk:find("[%c|]") then return nil end
	return { session = session, sequence = sequence, index = index, total = total, chunk = chunk }
end

function Protocol.RecordFields(record, project, region)
	local progress = {}
	for _, entry in ipairs(record.progress or {}) do
		progress[#progress + 1] = entry.activityID .. ":" .. entry.done .. ":" .. entry.total
	end
	local fields = { "U", project, region, record.revision, record.mode,
		table.concat(record.activityIDs, ","), record.note, #record.members, table.concat(progress, ",") }
	for _, member in ipairs(record.members) do
		local ids = Protocol.GetSpecIDs(member)
		for _, value in ipairs({ member.name, member.classID or 0, #ids > 0 and table.concat(ids, ",") or "0",
			member.roles or 0, member.itemLevel or 0, member.level or 0,
			member.faction or "?" }) do fields[#fields + 1] = value end
	end
	return fields
end

-- Boss detail is an optional B message. Keep the original U record readable
-- by older clients; bind the supplement to its sender/session/revision/activity.
function Protocol.ReadBossData(text, done, total)
	if not Protocol.Text(text) or #text > 600 or not Protocol.Integer(total, 1, 50)
		or not Protocol.Integer(done, 0, total) then return nil end
	local bosses, seen, parts, killed = {}, {}, {}, 0
	for value in text:gmatch("[^,]+") do
		local id, state = value:match("^(%d+):([01])$")
		id = Protocol.Integer(id, 1, 10000000)
		if not id or seen[id] or #bosses >= total then return nil end
		seen[id] = true
		parts[#parts + 1] = id .. ":" .. state
		bosses[#bosses + 1] = { id = id, defeated = state == "1" }
		if state == "1" then killed = killed + 1 end
	end
	if #bosses ~= total or killed ~= done or table.concat(parts, ",") ~= text then return nil end
	return bosses
end

function Protocol.BossData(entry)
	local parts = {}
	for _, boss in ipairs(entry.bosses or {}) do
		local id = Protocol.Integer(boss.id, 1, 10000000)
		if not id or (boss.defeated ~= true and boss.defeated ~= false) then return nil end
		parts[#parts + 1] = id .. ":" .. (boss.defeated and "1" or "0")
	end
	local text = table.concat(parts, ",")
	return Protocol.ReadBossData(text, entry.done, entry.total) and text or nil
end

function Protocol.ReadRecord(fields, sender, session, now)
	local revision = Protocol.Integer(fields[4], 1, 2147483647)
	local count = Protocol.Integer(fields[8], 1, 5)
	local note = Protocol.Text(fields[7])
	if not revision or not count or #fields ~= 9 + count * 7
		or not note or #note > Protocol.MAX_NOTE_BYTES or note:find("[%c|]")
		or (fields[5] ~= "solo" and fields[5] ~= "party")
		or (fields[5] == "solo" and count ~= 1) then return nil end
	local activityIDs, seen = {}, {}
	for value in fields[6]:gmatch("[^,]+") do
		local id = Protocol.Integer(value, 1, 10000000)
		if not id or seen[id] or #activityIDs >= 24 then return nil end
		seen[id] = true; activityIDs[#activityIDs + 1] = id
	end
	if #activityIDs == 0 or table.concat(activityIDs, ",") ~= fields[6] then return nil end
	local progress, progressKeys, progressParts = {}, {}, {}
	for text in fields[9]:gmatch("[^,]+") do
		local id, done, total = text:match("^(%d+):(%d+):(%d+)$")
		id, done, total = Protocol.Integer(id, 1, 10000000), Protocol.Integer(done, 0, 50), Protocol.Integer(total, 1, 50)
		if not id or not done or not total or done > total or not seen[id] or progressKeys[id] then return nil end
		progressKeys[id] = true
		progressParts[#progressParts + 1] = id .. ":" .. done .. ":" .. total
		progress[#progress + 1] = { activityID = id, done = done, total = total }
	end
	if table.concat(progressParts, ",") ~= fields[9] then return nil end
	local members, names = {}, {}
	for index = 1, count do
		local base = 9 + (index - 1) * 7
		local name = Protocol.FullName(fields[base + 1])
		local classID = Protocol.Integer(fields[base + 2], 1, 30)
		local specIDs = readSpecIDs(fields[base + 3])
		local roles = Protocol.Integer(fields[base + 4], 0, 7)
		local itemLevel = Protocol.Integer(fields[base + 5], 0, 10000)
		local level = Protocol.Integer(fields[base + 6], 1, 1000)
		local faction = fields[base + 7]
		if not name or names[name:lower()] or not classID or not specIDs or not roles
			or not itemLevel or not level or (faction ~= "Alliance" and faction ~= "Horde" and faction ~= "?") then return nil end
		names[name:lower()] = true
		members[index] = { name = name, classID = classID, specID = specIDs[1] or 0, specIDs = specIDs, roles = roles,
			itemLevel = itemLevel, level = level, faction = faction }
	end
	if members[1].name:lower() ~= sender:lower() then return nil end
	return { owner = sender, key = sender:lower(), session = session, revision = revision,
		mode = fields[5], note = note, activityIDs = activityIDs, members = members, progress = progress,
		updatedAt = now, expiresAt = now + Protocol.TTL }
end

function Protocol.HasRole(mask, bitValue)
	return math.floor((mask or 0) / bitValue) % 2 == 1
end
