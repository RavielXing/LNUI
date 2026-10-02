local _, GF = ...

-- RuntimePolicy owns the local, release-bound decision that determines whether
-- this official build initializes its business runtime for the current
-- character.  Identifiers are stored only as SHA-256 digests; this is a
-- privacy and accidental-edit boundary, not a claim that client Lua is
-- tamper-proof.
GF.RuntimePolicy = GF.RuntimePolicy or {}
local Policy = GF.RuntimePolicy

Policy.REVISION = "2026-09-30.3"
Policy.DENIED_REASON = "GF-ACCESS-001"

local EXPECTED_ENTRY_COUNT = 18
local EXPECTED_SET_DIGEST =
	"cb7c59271173992b51f1180a19c8e406e7c02ee66ed25eea0e4bc9de0b6a6046"

local deniedIdentityDigests = {
	["b7b7a36d3949f142162e9a2ad5befb2e2f4a5b7fce2fcf5ddec66992a4214714"] = true,
	["2452a92897067830e5c757b64ad289b69fc2517d19116f130e91e814c4e52ebc"] = true,
	["352c70df6362422adb99de731bfa5acf9ab07f72cfb544dd766d8a6ffabc8426"] = true,
	["401dd48072b23422d1ffb3a93e6ef864b80a7bc180565e3fabcaf5291dcfe0d6"] = true,
	["5e66e3bee4596286810f6457d86e27f4bd0ed21bb9da29e40feaf090a490cf24"] = true,
	["d607e51fb197d88cd1037cbb77d5fc0c034d16f25d7c52c6348fc2f6f4725c07"] = true,
	["5255f6d729ad50ad9b3ce3a5eb3bd3a7ecfed73c125a318d0a16e6919b5f9f08"] = true,
	["d16187305b1786a028cdb05817582ebea075edf912e382ac74e996574711a188"] = true,
	["4fe9a8ca5d30b5e408042aac59c0d48ab3eee65d896aaaadce930e051d3aa9ac"] = true,
	["5915c667d176da57b7f604f1fba480cd8863ac9d7dbf86702bf3cc0c9e06c2f7"] = true,
	["e44b154a23ec3d6d7c08b791c4be4348c0497f1e0d398915fbe2be77767f0fd9"] = true,
	["1e5674c91ffacd838195e62cb06189c422800d8a81d7f22e11fafef9f19d00cc"] = true,
	["e93f66a4d10563722e3361bd586f64bf1c2afbf355b6aa38fb8b1cb70b5a0bc3"] = true,
	["b2070050d6976ec05abb3678f59a0e148d92609cb30392443d476bdf46dabdb2"] = true,
	["243ca3fe88706cc9ef8e2bae9c6061c92d9e353215ae51131f83c99aef3f64d5"] = true,
	["35d429f604e534bb706ae1f91107ddfccef8ae155ee3b4ef602053c2dd8e5ec2"] = true,
	["c4a60818a5e9e814845bb0b31aef9089fe1a04c73967f0273a79f170cecb9153"] = true,
	["7115269f8d4551130a68da02000c5320425269274878b4f944992599c2b21028"] = true,
}

local SHA256_CONSTANTS = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
	0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
	0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
	0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
	0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
	0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
	0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
	0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
	0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local SHA256_INITIAL = {
	0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
	0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
}

local UINT32 = 4294967296

local function readableString(value)
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret == true then
			return nil
		end
	end
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible == false then
			return nil
		end
	end
	if type(value) ~= "string" then
		return nil
	end
	local ok, trimmed = pcall(string.match, value, "^%s*(.-)%s*$")
	return ok and trimmed ~= "" and trimmed or nil
end

local function normalizeRealm(realm)
	realm = readableString(realm)
	if not realm then
		return nil
	end
	local ok, normalized = pcall(function()
		return realm:gsub("%s+", "")
			:gsub("（", "(")
			:gsub("）", ")")
	end)
	return ok and normalized ~= "" and normalized or nil
end

function Policy:NormalizeIdentity(character, realm)
	character = readableString(character)
	realm = normalizeRealm(realm)
	if not character or not realm or character:find("-", 1, true) then
		return nil
	end
	local ok, identity = pcall(string.lower, character .. "-" .. realm)
	return ok and identity or nil
end

function Policy:GetCurrentIdentity()
	if type(UnitName) ~= "function" then
		return nil, "missing-unit-name-api"
	end
	local ok, character, realm = pcall(UnitName, "player")
	if not ok then
		return nil, "player-name-unavailable"
	end
	character = readableString(character)
	realm = normalizeRealm(realm)
	if not realm and type(GetNormalizedRealmName) == "function" then
		local realmOK, value = pcall(GetNormalizedRealmName)
		realm = realmOK and normalizeRealm(value) or nil
	end
	if not realm and type(GetRealmName) == "function" then
		local realmOK, value = pcall(GetRealmName)
		realm = realmOK and normalizeRealm(value) or nil
	end
	local identity = self:NormalizeIdentity(character, realm)
	return identity, identity and nil or "player-identity-unavailable"
end

local function unsigned(value)
	return value % UINT32
end

local function resolveBitLibrary()
	local library = _G.bit or _G.bit32
	if type(library) ~= "table"
		or type(library.band) ~= "function"
		or type(library.bor) ~= "function"
		or type(library.bxor) ~= "function"
		or type(library.bnot) ~= "function"
		or type(library.lshift) ~= "function"
		or type(library.rshift) ~= "function"
	then
		return nil
	end
	return library
end

local function packWord(value)
	value = unsigned(value)
	local b1 = math.floor(value / 0x1000000) % 0x100
	local b2 = math.floor(value / 0x10000) % 0x100
	local b3 = math.floor(value / 0x100) % 0x100
	local b4 = value % 0x100
	return string.char(b1, b2, b3, b4)
end

local function wordFromBytes(message, offset)
	local b1, b2, b3, b4 = message:byte(offset, offset + 3)
	return ((b1 * 0x100 + b2) * 0x100 + b3) * 0x100 + b4
end

function Policy:SHA256(message)
	if type(message) ~= "string" then
		return nil, "invalid-hash-input"
	end
	local bits = resolveBitLibrary()
	if not bits then
		return nil, "bit-library-unavailable"
	end
	local band, bor, bxor, bnot =
		bits.band, bits.bor, bits.bxor, bits.bnot
	local lshift, rshift = bits.lshift, bits.rshift
	local function rotateRight(value, amount)
		return bor(rshift(value, amount), lshift(value, 32 - amount))
	end
	local function xor3(a, b, c)
		return bxor(bxor(a, b), c)
	end

	local byteLength = #message
	local bitLength = byteLength * 8
	local zeroPadding = (56 - (byteLength + 1) % 64) % 64
	local highLength = math.floor(bitLength / UINT32)
	local lowLength = bitLength % UINT32
	message = message .. string.char(0x80)
		.. string.rep(string.char(0), zeroPadding)
		.. packWord(highLength) .. packWord(lowLength)

	local hash = {}
	for index = 1, #SHA256_INITIAL do
		hash[index] = SHA256_INITIAL[index]
	end
	local words = {}
	for blockStart = 1, #message, 64 do
		for index = 1, 16 do
			words[index] = wordFromBytes(
				message, blockStart + (index - 1) * 4)
		end
		for index = 17, 64 do
			local previous15 = words[index - 15]
			local previous2 = words[index - 2]
			local sigma0 = xor3(
				rotateRight(previous15, 7),
				rotateRight(previous15, 18),
				rshift(previous15, 3))
			local sigma1 = xor3(
				rotateRight(previous2, 17),
				rotateRight(previous2, 19),
				rshift(previous2, 10))
			words[index] = unsigned(words[index - 16] + sigma0
				+ words[index - 7] + sigma1)
		end

		local a, b, c, d = hash[1], hash[2], hash[3], hash[4]
		local e, f, g, h = hash[5], hash[6], hash[7], hash[8]
		for index = 1, 64 do
			local sum1 = xor3(
				rotateRight(e, 6), rotateRight(e, 11), rotateRight(e, 25))
			local choose = bxor(band(e, f), band(bnot(e), g))
			local temp1 = unsigned(h + sum1 + choose
				+ SHA256_CONSTANTS[index] + words[index])
			local sum0 = xor3(
				rotateRight(a, 2), rotateRight(a, 13), rotateRight(a, 22))
			local majority = xor3(band(a, b), band(a, c), band(b, c))
			local temp2 = unsigned(sum0 + majority)
			h, g, f, e, d, c, b, a =
				g, f, e, unsigned(d + temp1), c, b, a,
				unsigned(temp1 + temp2)
		end

		hash[1] = unsigned(hash[1] + a)
		hash[2] = unsigned(hash[2] + b)
		hash[3] = unsigned(hash[3] + c)
		hash[4] = unsigned(hash[4] + d)
		hash[5] = unsigned(hash[5] + e)
		hash[6] = unsigned(hash[6] + f)
		hash[7] = unsigned(hash[7] + g)
		hash[8] = unsigned(hash[8] + h)
	end

	local digest = {}
	for index = 1, #hash do
		digest[index] = string.format("%08x", unsigned(hash[index]))
	end
	return table.concat(digest)
end

function Policy:HashIdentity(identity)
	return self:SHA256(identity)
end

function Policy:IsDigestDenied(digest)
	return type(digest) == "string"
		and deniedIdentityDigests[digest] == true
end

function Policy:Validate()
	local entries = {}
	for digest, enabled in pairs(deniedIdentityDigests) do
		if enabled ~= true or type(digest) ~= "string"
			or #digest ~= 64 or digest:find("[^0-9a-f]")
		then
			return false, "invalid-entry"
		end
		entries[#entries + 1] = digest
	end
	if #entries ~= EXPECTED_ENTRY_COUNT then
		return false, "entry-count-mismatch"
	end
	table.sort(entries)
	local digest, reason = self:SHA256(table.concat(entries))
	if not digest then
		return false, reason
	end
	if digest ~= EXPECTED_SET_DIGEST then
		return false, "entry-set-mismatch"
	end
	return true
end

function Policy:EvaluateCurrentPlayer()
	local valid, validationReason = self:Validate()
	if not valid then
		self.status = "invalid"
		self.reason = validationReason
		return self.status, self.reason
	end
	local identity, identityReason = self:GetCurrentIdentity()
	if not identity then
		self.status = "pending"
		self.reason = identityReason
		return self.status, self.reason
	end
	local digest, hashReason = self:HashIdentity(identity)
	if not digest then
		self.status = "invalid"
		self.reason = hashReason
		return self.status, self.reason
	end
	if self:IsDigestDenied(digest) then
		self.status = "denied"
		self.reason = self.DENIED_REASON
	else
		self.status = "allowed"
		self.reason = nil
	end
	return self.status, self.reason
end

function Policy:GetStatus()
	return self.status or "pending", self.reason
end

function Policy:IsAllowed()
	return self.status == "allowed"
end

function Policy:GetSummary()
	return {
		revision = self.REVISION,
		entryCount = EXPECTED_ENTRY_COUNT,
		status = self.status or "pending",
		reason = self.reason,
	}
end
