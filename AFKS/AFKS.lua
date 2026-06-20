----------------------------------------------
--	The codes are based on ElvUI	    --
----------------------------------------------

local AFKS = CreateFrame("Frame")

local wowVersion
local UIscale = 1
local panelheight = GetScreenHeight() * 0.1

if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
	wowVersion = "classic"
elseif WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
	wowVersion = "bcc"
elseif WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC then
	wowVersion = "wrath" -- CN only
elseif WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC then
	wowVersion = "cata"
elseif WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
	wowVersion = "mop"
elseif WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
	wowVersion = "retail"
end

local eastasian = false

if GetLocale() == "koKR" or GetLocale() == "zhCN" or GetLocale() == "zhTW" then
	eastasian = true
end

--Cache global variables
--Lua functions
local _G = _G
local floor = math.floor
local random = math.random
local type, select = type, select
local tonumber, tostring, pcall = tonumber, tostring, pcall
local pairs = pairs
local issecretvalue = issecretvalue
--WoW API / Variables
--local CloseAllWindows = CloseAllWindows
local CreateFrame = CreateFrame
local GetBattlefieldStatus = GetBattlefieldStatus
local GetGuildInfo = GetGuildInfo
local GetTime = GetTime
local GetZonePVPInfo = C_PvP and C_PvP.GetZonePVPInfo
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local IsInGuild = IsInGuild
local IsShiftKeyDown = IsShiftKeyDown
local MoveViewLeftStart = MoveViewLeftStart
local MoveViewLeftStop = MoveViewLeftStop
local PVEFrame_ToggleFrame = PVEFrame_ToggleFrame
local RemoveExtraSpaces = RemoveExtraSpaces
local UIParent = UIParent
local UnitIsAFK = UnitIsAFK
local UnitFactionGroup = UnitFactionGroup
local UnitIsPVP = UnitIsPVP
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitOnTaxi = UnitOnTaxi
local WantsAlteredForm = C_UnitAuras and C_UnitAuras.WantsAlteredForm
local GetShapeshiftFormID = GetShapeshiftFormID
local GetExpansionDisplayInfo = GetExpansionDisplayInfo
local GetClientDisplayExpansionLevel = GetClientDisplayExpansionLevel
local NewTicker, NewTimer, TimerAfter = C_Timer.NewTicker, C_Timer.NewTimer, C_Timer.After

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

--Retail only API
local GetAtlasInfo = C_Texture and C_Texture.GetAtlasInfo
local PetBattles_IsInBattle = C_PetBattles and C_PetBattles.IsInBattle
local IsRecipeRepeating = C_TradeSkillUI and C_TradeSkillUI.IsRecipeRepeating
local GetStreamInfo = C_Club and C_Club.GetStreamInfo
local GetClubInfo = C_Club and C_Club.GetClubInfo
local GetGlidingInfo = C_PlayerInfo and C_PlayerInfo.GetGlidingInfo

--Retail and Cata and MoP API
local GetNumDayEvents = C_Calendar and C_Calendar.GetNumDayEvents
local GetDayEvent = C_Calendar and C_Calendar.GetDayEvent
local GetSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
local GetLFGInfoServer = GetLFGInfoServer

--Cata and Wrath API
local GetNumTalentTabs = GetNumTalentTabs
local GetTalentTabInfo = GetTalentTabInfo

--Classic only API
local CastingInfo = CastingInfo
local GetClassicExpansionLevel = GetClassicExpansionLevel
local GetCurrentGameModeDisplayInfo = C_GameRules and C_GameRules.GetCurrentGameModeDisplayInfo
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetClassColor = GetClassColor


local animations = {
	[2] = { name = "dance", id = 69, facing = 6, wait = 30, duration = 300 },
	[3] = { name = "lean", id = 1260, facing = 5.8, wait = 10, duration = 600 },
	[4] = { name = "salute", id = 113, facing = 6, wait = 30, duration = 5 },
	[5] = { name = "talk", id = 60, facing = 6.2, wait = 15, duration = 10 },
	[6] = { name = "shy", id = 83, facing = 6.2, wait = 30, duration = 10 },
	[7] = { name = "roar", id = 74, facing = 6, wait = 30, duration = 5 },
	[8] = { name = "bow", id = 66, facing = 6, wait = 30, duration = 7 },
	[9] = { name = "cheer", id = 68, facing = 6, wait = 30, duration = 7 },
	[10] = { name = "applause", id = 80, facing = 6, wait = 30, duration = 7 },
	[11] = { name = "flex", id = 82, facing = 6, wait = 30, duration = 7 },
}

if wowVersion ~= "retail" then
	table.remove(animations, 3)
end

local ignoreKeys = {
	LALT = true,
	LSHIFT = true,
	RSHIFT = true,
}
local printKeys = {
	PRINTSCREEN = true,
}

if IsMacClient() then
	printKeys[_G.KEY_PRINTSCREEN_MAC] = true
end

local isCamp = false

SLASH_AFKSCampToggle1 = "/AFKCAMP"
function SlashCmdList.AFKSCampToggle()
	if isCamp then
		isCamp = false
		print(AFKS_CAMPOFF)
	else
		isCamp = true
		print(AFKS_CAMPON)
	end
end

local public_channels = {
	["retail"] = {26, 42},
	["mop"] = {23, 26},
	["cata"] = {23, 26},
	["wrath"] = {23, 25, 26},
	["bcc"] = {23, 24, 25},
	["classic"] = {23, 24, 25}
}

local default_options = {
	enabled = true,
	hidechat = true,  --lnui
	group = false,
	spin = true,
	animation = 1
}

function AFKS:OnEvent(event, ...)
	if event == "VARIABLES_LOADED" then
		if wowVersion ~= "retail" and C_AddOns.IsAddOnLoaded("Necrosis") then
			return
		end
		AFKS_DB = AFKS_DB or CopyTable(default_options)
		self.options = AFKS_DB
		if not AFKS_DB.animation then
			self.options.animation = default_options.animation -- fetch new option vars
		end
		if not AFKS_DB.spin then
			self.options.spin = default_options.spin -- fetch new option vars
		end

		self:Toggle()
		self:RenderOptions()
		if wowVersion == "classic" and C_GameRules.IsHardcoreActive() then
			self.isHardcore = true
		end
	end

	if event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		if self.isInterrupted then
			TimerAfter(0.5, function() self:SetAFK(false) end)
			self.isInterrupted = false
		end
	elseif event == "UPDATE_BATTLEFIELD_STATUS" or event == "PLAYER_REGEN_DISABLED" or event == "LFG_PROPOSAL_SHOW" or event == "PARTY_INVITE_REQUEST" then
		local arg1 = ...
		if event ~= "UPDATE_BATTLEFIELD_STATUS" or (GetBattlefieldStatus(arg1) == "confirm") then
			self:SetAFK(false)
		end
		
		if event == "PLAYER_REGEN_DISABLED" then
			self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
			if self.isAFK then
				self.isInterrupted = true
			end
		end

		return
	end

	--[[
	if event == "PLAY_MOVIE" then
		self.isCinematic = true
	end
	]]

	if event == "TALKINGHEAD_REQUESTED" and self.isAFK then
		self:SetAFK(false)
	end

	if event == "PLAYER_CONTROL_GAINED" then
		local onTaxi = securecall(UnitOnTaxi, "player")
		local isPVP = securecall(UnitIsPVP, "player")
		if onTaxi and isPVP then
			self:SetAFK(false)
		end
	end

	if not self.options.enabled then
		return
	end

	if _G.CinematicFrame:IsShown() or _G.MovieFrame:IsShown() then
		return
	end

	if self.isHardcore then
		return
	end

	local inGroup = securecall(IsInGroup)
	local inPetBattle = false
	if wowVersion == "retail" or wowVersion == "mop" then
		inPetBattle = securecall(PetBattles_IsInBattle)
	end
	if not self.options.group and (inGroup or inPetBattle) then
		return
	end

	if wowVersion == "retail" then
		local isGliding = securecall(GetGlidingInfo)
		if isGliding then
			return
		end
	end
	local inInstance, instanceType = securecall(IsInInstance)
	if inInstance then
		if instanceType ~= "neighborhood" and instanceType ~= "interior" then -- Housing check
			return
		end
	end

	local isPVP = securecall(UnitIsPVP, "player")
	local zonePVPInfo = securecall(GetZonePVPInfo)
	if isPVP and (zonePVPInfo == "combat" or zonePVPInfo == "contested" or zonePVPInfo == "hostile") then
		return
	end
	local isDeadOrGhost = securecall(UnitIsDeadOrGhost, "player")
	local inCombat = securecall(InCombatLockdown)
	if isDeadOrGhost or inCombat then
		return
	end
	if wowVersion == "retail" then
		local isRecipeRepeating = securecall(IsRecipeRepeating)
		if isRecipeRepeating then
			 --Don't activate afk if player is crafting stuff, check back in 30 seconds
			TimerAfter(30, function() self:OnEvent() end)
			return
		end
		local profFrameShown = false
		if ProfessionsFrame then
			profFrameShown = securecall(ProfessionsFrame.IsShown, ProfessionsFrame)
		end
		local customerFrameShown = false
		if ProfessionsCustomerOrdersFrame then
			customerFrameShown = securecall(ProfessionsCustomerOrdersFrame.IsShown, ProfessionsCustomerOrdersFrame)
		end
		if profFrameShown or customerFrameShown then
			return
		end
	else
		local castingInfo = securecall(CastingInfo)
		if castingInfo then
			 --Don't activate afk if player is crafting stuff, check back in 30 seconds
			TimerAfter(30, function() self:OnEvent() end)
			return
		end
	end
	
	if wowVersion == "retail" or wowVersion == "cata" or wowVersion == "mop" then
		local _, _, isLFG = securecall(GetLFGInfoServer, 1)
		if isLFG then
			return
		end
	end
	
	local isAFK = securecall(UnitIsAFK, "player")
	if isAFK and not self.isAFK then
		local pveFrameShown = false
		if wowVersion == "retail" and PVEFrame then
			pveFrameShown = securecall(PVEFrame.IsShown, PVEFrame)
		end
		if pveFrameShown or isCamp then return end
		self:SetAFK(true)
	elseif not isAFK then
		self:SetAFK(false)
	end
end

function AFKS:Toggle()
	if(self.options.enabled) then
		self:RegisterEvent("PLAYER_FLAGS_CHANGED", "OnEvent")
		self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
		self:RegisterEvent("PLAYER_CONTROL_GAINED", "OnEvent")
		self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", "OnEvent")
		--self:RegisterEvent("PLAY_MOVIE", "OnEvent")
		if wowVersion == "retail" then
			--self:RegisterEvent("LFG_PROPOSAL_SHOW", "OnEvent")
			self:RegisterEvent("PARTY_INVITE_REQUEST", "OnEvent")
			self:RegisterEvent("TALKINGHEAD_REQUESTED", "OnEvent")
		end
		SetCVar("autoClearAFK", "1")
	else
		self:UnregisterEvent("PLAYER_FLAGS_CHANGED")
		self:UnregisterEvent("PLAYER_REGEN_DISABLED")
		self:UnregisterEvent("PLAYER_CONTROL_GAINED")
		self:UnregisterEvent("UPDATE_BATTLEFIELD_STATUS")
		--self:UnregisterEvent("PLAY_MOVIE")
		if wowVersion == "retail" then
			--self:UnregisterEvent("LFG_PROPOSAL_SHOW")
			self:UnregisterEvent("PARTY_INVITE_REQUEST")
			self:UnregisterEvent("TALKINGHEAD_REQUESTED")
		end
	end
end

local function OnKeyDown(self, key)
	if(ignoreKeys[key]) then return end
	if printKeys[key] then
		Screenshot()
	else
		if securecall(InCombatLockdown) then return end
		AFKS:SetAFK(false)
		TimerAfter(60, function() AFKS:OnEvent() end)
	end
end

local function Chat_MouseDown(self, button)
	if button == "RightButton" then
		AFKS.AFKMode.chatminbar.minimized = true
		AFKS.AFKMode.chatminbar.unreadwhisper = 0
		AFKS.AFKMode.chatminbar.unreadbnet = 0
		AFKS.AFKMode.chatminbar.unreadchannel = 0
		AFKS.AFKMode.chatminbar.unreadguild = 0

		local text = format(AFKS_CHATBAR_TEXT, AFKS.AFKMode.chatminbar.unreadwhisper, AFKS.AFKMode.chatminbar.unreadbnet, AFKS.AFKMode.chatminbar.unreadchannel)
		if securecall(IsInGuild) then
			text = text.." "..format(AFKS_CHATBAR_GUILD, AFKS.AFKMode.chatminbar.unreadguild)
		end
		AFKS.AFKMode.chatminbar.title:SetText(text)
		AFKS.AFKMode.chatminbar.title:Show()
		AFKS.AFKMode.chatminbar:SetBackdropColor(.2, .2, .2, .8)
		self:Hide()
	elseif button == "LeftButton" and securecall(IsShiftKeyDown) then
		self:ClearAllPoints()
		self:SetPoint("BOTTOMLEFT", AFKSFrame, "BOTTOMLEFT", 4, 120)
	end
end

local function Chat_OnMouseWheel(self, delta)
	if delta == 1 then
		if securecall(IsShiftKeyDown) then
			self:ScrollToTop()
		else
			self:ScrollUp()
		end
	elseif delta == -1 then
		if securecall(IsShiftKeyDown) then
			self:ScrollToBottom()
		else
			self:ScrollDown()
		end
	end
end

local function ChatMinBar_MouseDown(self, button)
	if button == "LeftButton" or button == "RightButton" then
		AFKS.AFKMode.chatminbar.minimized = false
		AFKS.AFKMode.chatminbar.title:Hide()
		AFKS.AFKMode.chatminbar:SetBackdropColor(.2, .2, .2, 0)
		AFKS.AFKMode.chat:Show()
	end
end

local function TruncateToMaxLength(text, maxLength)
	local length = strlenutf8(text)
	if ( length > maxLength ) then
		return text:sub(1, maxLength - 2).."..."
	end
	return text
end

local function GetCommunityName(clubId, streamId)
	local communityName = ""
	local streamInfo = GetStreamInfo(clubId, streamId)
	if streamInfo and streamInfo.streamType == 0 then
		local clubInfo = GetClubInfo(clubId)
		communityName = clubInfo and TruncateToMaxLength(clubInfo.shortName or clubInfo.name, 12) or ""
	end
	
	return communityName
end

local canChangeMessage = function(arg1, id)
	if id and arg1 == "" then return id end
end

local function MessageIsProtected(message)
	if issecretvalue and issecretvalue(message) then return true end

	return message and (message ~= gsub(message, "(:?|?)|K(.-)|k", canChangeMessage))
end

--[[
local function GetBNFriendColor(name, id, useBTag)
	local _, _, battleTag, _, _, bnetIDGameAccount = BNGetFriendInfoByID(id)
	local TAG = useBTag and battleTag and strmatch(battleTag,"([^#]+)")
	local Class

	if not bnetIDGameAccount then --dont know how this is possible
		local firstToonClass = getFirstToonClassColor(id)
		if firstToonClass then
			Class = firstToonClass
		else
			return TAG or name
		end
	end

	if not Class then
		_, _, _, _, _, _, _, Class = BNGetGameAccountInfo(bnetIDGameAccount)
	end

	if Class and Class ~= "" then --other non-english locales require this
		for k,v in pairs(LOCALIZED_CLASS_NAMES_MALE) do if Class == v then Class = k;break end end
		for k,v in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do if Class == v then Class = k;break end end
	end

	local CLASS = Class and Class ~= "" and gsub(strupper(Class),"%s","")
	local COLOR = CLASS and classcolors[CLASS]

	return (COLOR and format("|c%s%s|r", COLOR.colorStr, TAG or name)) or TAG or name
end
]]

local function Chat_OnEvent(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14)
	local infotype = strsub(event, 10)
	local info = _G.ChatTypeInfo[infotype]

	local GetChatCategory = _G.ChatFrameUtil and _G.ChatFrameUtil.GetChatCategory or _G.Chat_GetChatCategory 
	local GetDecoratedSenderName = _G.ChatFrameUtil and _G.ChatFrameUtil.GetDecoratedSenderName or _G.GetColoredName

	local chatTarget
	local chatGroup = GetChatCategory(infotype)
	if ( chatGroup == "BN_CONVERSATION" ) then
		chatTarget = tostring(arg8)
	elseif ( chatGroup == "WHISPER" or chatGroup == "BN_WHISPER" ) then
		chatTarget = (not issecretvalue or not issecretvalue(arg2)) and strsub(arg2, 1, 2) ~= "|K" and strupper(arg2) or arg2
	end

	local playerLink
	local linkTarget = chatTarget and (":"..chatTarget) or ""
	local texture = ""

	if infotype ~= "BN_WHISPER" and infotype ~= "BN_CONVERSATION" then
		playerLink = format("|Hplayer:%s:%s:%s%s|h", arg2, arg11, chatGroup, linkTarget)
	else
		local accountInfo = _G.C_BattleNet.GetAccountInfoByID(arg13)
		if accountInfo and accountInfo.gameAccountInfo.clientProgram ~= "" then
			texture = _G.BNet_GetClientEmbeddedAtlas(accountInfo.gameAccountInfo.clientProgram, 14, 14)
		end
		playerLink = texture..format("|HBNplayer:%s:%s:%s:%s%s|h", arg2, arg13, arg11, chatGroup, linkTarget)
		if AFKS.AFKMode.chatminbar.minimized then
			AFKS.AFKMode.chatminbar.unreadbnet = AFKS.AFKMode.chatminbar.unreadbnet + 1
			--print("bnet:"..AFKS.AFKMode.chatminbar.unreadbnet)
		end
	end 
	
	local isProtected = MessageIsProtected(arg1)
	if not isProtected then
		arg1 = gsub(arg1, "%%", "%%%%") -- Escape any % characters, as it may otherwise cause an 'invalid option in format' error
		arg1 = RemoveExtraSpaces(arg1) -- Remove groups of many spaces
	end 

	local isMobile = arg14 and _G.ChatFrame_GetMobileEmbeddedTexture(info.r, info.g, info.b)
	local message = format("%s%s", isMobile or "", arg1)

	local coloredName = GetDecoratedSenderName(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14)
	local senderLink = format("%s[%s]|h", playerLink, coloredName)
	local success, body = pcall(format, _G["CHAT_"..infotype.."_GET"].."%s", senderLink, message)
	if not success then return end

	if infotype == "COMMUNITIES_CHANNEL" then
		local prefix, channelCode = arg4:match("(%d+. )(.*)")
		local clubId, streamId = channelCode:match("(%d+)%:(%d+)")
		clubId = tonumber(clubId)
		streamId = tonumber(streamId)

		infotype = _G.Chat_GetCommunitiesChannel(clubId, streamId)
		info = _G.ChatTypeInfo[infotype]
		body = "[" .. prefix .. GetCommunityName(clubId, streamId) .. "] " .. body
		if AFKS.AFKMode.chatminbar.minimized then
			AFKS.AFKMode.chatminbar.unreadchannel = AFKS.AFKMode.chatminbar.unreadchannel + 1
		end
	elseif infotype == "CHANNEL" then
		if arg7 == 1 or arg7 == 2 or arg7 == 22 then
			return
		end
		for k, v in pairs(public_channels[wowVersion]) do
			if arg7 == v then
				return
			end
		end
		info = _G.ChatTypeInfo[infotype..arg8]
		body = "[" .. arg4 .. "]" .. body
		if AFKS.AFKMode.chatminbar.minimized then
			AFKS.AFKMode.chatminbar.unreadchannel = AFKS.AFKMode.chatminbar.unreadchannel + 1
		end
	end

	local accessID = _G.ChatHistory_GetAccessID(chatGroup, chatTarget)
	local typeID = _G.ChatHistory_GetAccessID(infotype, chatTarget, arg12 or arg13)

	if AFKS.AFKMode.chatminbar.minimized then
		if infotype == "WHISPER" then
			AFKS.AFKMode.chatminbar.unreadwhisper = AFKS.AFKMode.chatminbar.unreadwhisper + 1
			--print("whisper:"..AFKS.AFKMode.chatminbar.unreadwhisper)
		elseif infotype == "GUILD" then
			AFKS.AFKMode.chatminbar.unreadguild = AFKS.AFKMode.chatminbar.unreadguild + 1
		end
		local unreadwhisper, unreadbnet, unreadchannel = AFKS.AFKMode.chatminbar.unreadwhisper, AFKS.AFKMode.chatminbar.unreadbnet, AFKS.AFKMode.chatminbar.unreadchannel
		if unreadwhisper > 0 then
			unreadwhisper = "|cffffffff"..unreadwhisper.."|r"
		end
		if unreadbnet > 0 then
			unreadbnet = "|cffffffff"..unreadbnet.."|r"
		end
		if unreadchannel > 0 then
			unreadchannel = "|cffffffff"..unreadchannel.."|r"
		end
		local text = format(AFKS_CHATBAR_TEXT, unreadwhisper, unreadbnet, unreadchannel)
		if securecall(IsInGuild) then
			local unreadguild = AFKS.AFKMode.chatminbar.unreadguild
			if unreadguild > 0 then
				unreadguild = "|cffffffff"..unreadguild.."|r"
			end
			text = text.." "..format(AFKS_CHATBAR_GUILD, unreadguild)
		end

		AFKS.AFKMode.chatminbar.title:SetText(text)
	end

	self:AddMessage(body, info.r, info.g, info.b, info.id, false, accessID, typeID)
end

local function PlayAnimations()
	local option
	if AFKS.options.animation == 1 then -- random
		if wowVersion == "retail" then
			option = animations[random(2,11)]
		else
			option = animations[random(2,10)]
		end
		if option.name == "dance" or option.name == "lean" then
			option.duration = 30
		end
		if option.wait == 30 then
			option.wait = random(10, 25)
		end
	else
		option = animations[AFKS.options.animation]
	end
	
	AFKSPlayerModel.curAnimation = option.name
	AFKSPlayerModel.startTime = GetTime()
	AFKSPlayerModel.duration = option.duration
	AFKSPlayerModel.isIdle = false
	AFKSPlayerModel.idleDuration = option.wait

	AFKSPlayerModel:SetFacing(option.facing)
	AFKSPlayerModel:SetAnimation(option.id)
end

local function FontTemplate(fs, fontSize, outline)
	fontSize = fontSize or 12

	if not outline then
		outline = ""
	end
	fs:SetFont(_G.STANDARD_TEXT_FONT, fontSize, outline)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
end

local function SetTemplate(Frame)
	local blank = "Interface/BUTTONS/WHITE8X8"

	Frame:SetBackdrop({
		bgFile = blank,
		edgeFile = blank,
		tile = false, tileSize = 0, edgeSize = 1,
		insets = { left = -1, right = -1, top = -1, bottom = -1},
	})

	if not Frame.isInsetDone then
		Frame.InsetTop = Frame:CreateTexture(nil, "BORDER")
		Frame.InsetTop:SetPoint("TOPLEFT", Frame, "TOPLEFT", -1, 1)
		Frame.InsetTop:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", 1, -1)
		Frame.InsetTop:SetHeight(1)
		Frame.InsetTop:SetColorTexture(0,0,0)
		Frame.InsetTop:SetDrawLayer("BORDER", -7)

		Frame.InsetBottom = Frame:CreateTexture(nil, "BORDER")
		Frame.InsetBottom:SetPoint("BOTTOMLEFT", Frame, "BOTTOMLEFT", -1, -1)
		Frame.InsetBottom:SetPoint("BOTTOMRIGHT", Frame, "BOTTOMRIGHT", 1, -1)
		Frame.InsetBottom:SetHeight(1)
		Frame.InsetBottom:SetColorTexture(0,0,0)
		Frame.InsetBottom:SetDrawLayer("BORDER", -7)

		Frame.InsetLeft = Frame:CreateTexture(nil, "BORDER")
		Frame.InsetLeft:SetPoint("TOPLEFT", Frame, "TOPLEFT", -1, 1)
		Frame.InsetLeft:SetPoint("BOTTOMLEFT", Frame, "BOTTOMLEFT", 1, -1)
		Frame.InsetLeft:SetWidth(1)
		Frame.InsetLeft:SetColorTexture(0,0,0)
		Frame.InsetLeft:SetDrawLayer("BORDER", -7)

		Frame.InsetRight = Frame:CreateTexture(nil, "BORDER")
		Frame.InsetRight:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", 1, 1)
		Frame.InsetRight:SetPoint("BOTTOMRIGHT", Frame, "BOTTOMRIGHT", -1, -1)
		Frame.InsetRight:SetWidth(1)
		Frame.InsetRight:SetColorTexture(0,0,0)
		Frame.InsetRight:SetDrawLayer("BORDER", -7)

		Frame.InsetInsideTop = Frame:CreateTexture(nil, "BORDER")
		Frame.InsetInsideTop:SetPoint("TOPLEFT", Frame, "TOPLEFT", 1, -1)
		Frame.InsetInsideTop:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -1, 1)
		Frame.InsetInsideTop:SetHeight(1)
		Frame.InsetInsideTop:SetColorTexture(0,0,0)
		Frame.InsetInsideTop:SetDrawLayer("BORDER", -7)

		Frame.InsetInsideBottom = Frame:CreateTexture(nil, "BORDER")
		Frame.InsetInsideBottom:SetPoint("BOTTOMLEFT", Frame, "BOTTOMLEFT", 1, 1)
		Frame.InsetInsideBottom:SetPoint("BOTTOMRIGHT", Frame, "BOTTOMRIGHT", -1, 1)
		Frame.InsetInsideBottom:SetHeight(1)
		Frame.InsetInsideBottom:SetColorTexture(0,0,0)
		Frame.InsetInsideBottom:SetDrawLayer("BORDER", -7)

		Frame.InsetInsideLeft = Frame:CreateTexture(nil, "BORDER")
		Frame.InsetInsideLeft:SetPoint("TOPLEFT", Frame, "TOPLEFT", 1, -1)
		Frame.InsetInsideLeft:SetPoint("BOTTOMLEFT", Frame, "BOTTOMLEFT", -1, 1)
		Frame.InsetInsideLeft:SetWidth(1)
		Frame.InsetInsideLeft:SetColorTexture(0,0,0)
		Frame.InsetInsideLeft:SetDrawLayer("BORDER", -7)

		Frame.InsetInsideRight = Frame:CreateTexture(nil, "BORDER")
		Frame.InsetInsideRight:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -1, -1)
		Frame.InsetInsideRight:SetPoint("BOTTOMRIGHT", Frame, "BOTTOMRIGHT", 1, 1)
		Frame.InsetInsideRight:SetWidth(1)
		Frame.InsetInsideRight:SetColorTexture(0,0,0)
		Frame.InsetInsideRight:SetDrawLayer("BORDER", -7)

		Frame.isInsetDone = true
	end

	Frame:SetBackdropBorderColor(.31, .31, .31)
	if wowVersion == "retail" then
		Frame:SetBackdropColor(.06, .06, .06, 0)
	else
		Frame:SetBackdropColor(.06, .06, .06, .8)
	end
end

local function SetSpecPanel()
	local function SetLeftEndColor(specid)
		local ColorBySpecID = {
			-- Death Knight
			[250] = {0.078, 0.078, 0.078},
			[251] = {0.019, 0.131, 0.203},
			[252] = {0.075, 0.087, 0.027},

			-- Demon Hunter
			[577] = {0.049, 0.099, 0.081},
			[581] = {0.07, 0.055, 0.18},
			[1480] = {0.047, 0.031, 0.137},

			-- Druid
			[102] = {0.086, 0.1, 0.243},
			[103] = {0.077, 0.112, 0.178},
			[104] = {0.189, 0.0902, 0.029},
			[105] = {0.058, 0.086, 0.002},

			-- Evoker
			[1467] = {0.1, 0.063, 0.1},
			[1468] = {0.087, 0.146, 0.131},
			[1473] = {0.083, 0.075, 0.051},

			-- Hunter
			[253] = {0.09, 0.101, 0.271},
			[254] = {0.066, 0.09, 0.043},
			[255] = {0.166, 0.131, 0.123},

			-- Mage
			[62] = {0.075, 0.026, 0.171},
			[63] = {0.095, 0.064, 0.017},
			[64] = {0.062, 0.078, 0.145},

			-- Monk
			[268] = {0.082, 0.09, 0},
			[269] = {0.125, 0.1, 0.16},
			[270] = {0.118, 0.149, 0.255},

			-- Paladin
			[65] = {0.094, 0.072, 0.042},
			[66] = {0.176, 0.0615, 0.121},
			[70] = {0.184, 0.145, 0.047},

			-- Priest
			[256] = {0.066, 0.086, 0.1},
			[257] = {0.173, 0.143, 0.1195},
			[258] = {0.083, 0.068, 0.077},

			-- Rogue
			[259] = {0.087, 0.058, 0.041},
			[260] = {0.043, 0.086, 0.082},
			[261] = {0.058, 0.039, 0.065},

			-- Shaman
			[262] = {0.04, 0.078, 0.152},
			[263] = {0.068, 0.074, 0.191},
			[264] = {0.082, 0.086, 0.121},

			-- Warlock
			[265] = {0.095, 0.075, 0.254},
			[266] = {0.078, 0.078, 0.074},
			[267] = {0.114, 0.055, 0.027},

			-- Warrior
			[71] = {0.05, 0.078, 0.082},
			[72] = {0.055, 0.061, 0.07},
			[73] = {0.1, 0.078, 0.071},
		}

		local r, g, b = unpack(ColorBySpecID[specid])
		AFKS.AFKMode.bottom.leftendtex:SetColorTexture(r, g, b)
		AFKS.AFKMode.bottom.leftendtex:SetSize(GetScreenWidth() - 1567, panelheight - 3)
		AFKS.AFKMode.bottom.leftendtex:Show()
	end

	local SpecIDToBackgroundAtlas = {
		-- Death Knight
		[250] = "talents-background-deathknight-blood",
		[251] = "talents-background-deathknight-frost",
		[252] = "talents-background-deathknight-unholy",

		-- Demon Hunter
		[577] = "talents-background-demonhunter-havoc",
		[581] = "talents-background-demonhunter-vengeance",
		[1480] = "talents-background-demonhunter-devourer",

		-- Druid
		[102] = "talents-background-druid-balance",
		[103] = "talents-background-druid-feral",
		[104] = "talents-background-druid-guardian",
		[105] = "talents-background-druid-restoration",

		-- Evoker
		[1467] = "talents-background-evoker-devastation",
		[1468] = "talents-background-evoker-preservation",
		[1473] = "talents-background-evoker-augmentation",

		-- Hunter
		[253] = "talents-background-hunter-beastmastery",
		[254] = "talents-background-hunter-marksmanship",
		[255] = "talents-background-hunter-survival",

		-- Mage
		[62] = "talents-background-mage-arcane",
		[63] = "talents-background-mage-fire",
		[64] = "talents-background-mage-frost",

		-- Monk
		[268] = "talents-background-monk-brewmaster",
		[269] = "talents-background-monk-windwalker",
		[270] = "talents-background-monk-mistweaver",

		-- Paladin
		[65] = "talents-background-paladin-holy",
		[66] = "talents-background-paladin-protection",
		[70] = "talents-background-paladin-retribution",

		-- Priest
		[256] = "talents-background-priest-discipline",
		[257] = "talents-background-priest-holy",
		[258] = "talents-background-priest-shadow",

		-- Rogue
		[259] = "talents-background-rogue-assassination",
		[260] = "talents-background-rogue-outlaw",
		[261] =  "talents-background-rogue-subtlety",

		-- Shaman
		[262] = "talents-background-shaman-elemental",
		[263] = "talents-background-shaman-enhancement",
		[264] = "talents-background-shaman-restoration",

		-- Warlock
		[265] = "talents-background-warlock-affliction",
		[266] = "talents-background-warlock-demonology",
		[267] = "talents-background-warlock-destruction",

		-- Warrior
		[71] = "talents-background-warrior-arms",
		[72] = "talents-background-warrior-fury",
		[73] = "talents-background-warrior-protection",
	}

	local panel_offset = {
		[63] = 0.059, -- Fire Mage
		[64] = 0.099, -- Frost Mage
		[65] = 0.034, -- Holy Paladin
		[66] = 0.059, -- Protect Paladin
		[70] = 0.124, -- Ret Paladin
		[71] = 0.091, -- Arms Warrior
		[72] = 0.054, -- Fury Warrior
		[73] = 0.086, -- Protect Warrior
		[102] = 0.055, -- Balance Druid
		[103] = 0.086, -- Feral Druid
		[104] = 0.08, -- Guardian Druid
		[105] = 0.059, -- Resto Druid
		[250] = 0.025, -- Blood DK
		[251] = 0.048, -- Frost DK
		[252] = 0.166, -- Unholy DK
		[253] = 0.048, -- Beast Hunter
		[254] = 0.054, -- Marksmanship Hunter
		[255] = 0.106, -- Survival Hunter
		[256] = 0.061, -- Discipline Priest
		[259] = 0.069, -- Assassination Rogue
		[261] = 0.113, -- Subtlety Rogue
		[262] = 0.086, -- Elemental Shaman
		[263] = 0.048, -- Enhancement Shaman
		[264] = 0.086, -- Resto Shaman
		[265] = 0.069, -- Affl Warlock
		[266] = 0.014, -- Demon Warlock
		[267] = 0.079, -- Dest Warlock
		[268] = 0.074, -- Brew Monk
		[269] = 0.064, -- Wind Monk
		[577] = 0.051, -- Havoc DH
		[581] = 0.071, -- Vengeance DH
		[1480] = 0.174, -- Devourer DH
		[1467] = 0.063, -- Devast Evoker
		[1468] = 0.072, -- Preserv Evoker
		[1473] = 0.072, -- Augment Evoker
	}

	local model_yoffset = {
		[1] = 30, -- Human
		[2] = -15, -- Orc
		[3] = -10, -- Dwarf
		[5] = 10, -- Undead
		[6] = 35, -- Tauren
		[8] = 10, -- Troll
		[9] = -10, -- Goblin
		[11] = 8, -- Draenei
		[24] = 0, -- Pandaren (Neutral)
		[25] = 0, -- Pandaren (Alliance)
		[26] = 0, -- Pandaren (Horde)
		[28] = 25, -- Highmountain
		[30] = 20, -- Lightforged
		[31] = 5, -- Zandalari
		[32] = 15, -- Kul Tiran
		[34] = -20, -- Dark Iron Dwarf
		[85] = 10, -- Earthen
	}

	local needs_to_resize = {
		[3] = 1.6,
		[8] = 1.8,
		[9] = 1.7,
		[24] = 1.5,
		[25] = 1.5,
		[26] = 1.5,
		[28] = 1.8,
		[32] = 1.8,
		[34] = 1.6
	}

	local yoffset = GetScreenHeight() * 0.1 - 102.4
	if yoffset < 0 then
		yoffset = yoffset * 2.3
	else
		yoffset = yoffset * 3.5
	end
	
	local raceid = select(3, UnitRace("player"))

	if needs_to_resize[raceid] then
		AFKS.AFKMode.bottom.model:SetSize(GetScreenWidth() * needs_to_resize[raceid], GetScreenHeight() * needs_to_resize[raceid])
	end

	if raceid == 22 then -- Worgen
		local wantsAltered = securecall(WantsAlteredForm, "player")
		if wantsAltered then
			AFKS.AFKMode.bottom.model:SetSize(GetScreenWidth() * 1.8, GetScreenHeight() * 1.8)
			yoffset = yoffset + 30
		else
			AFKS.AFKMode.bottom.model:SetSize(GetScreenWidth() * 2, GetScreenHeight() * 2)
			yoffset = yoffset + -7
		end
	elseif raceid == 52 or raceid == 70 then -- Dracthyr
		local wantsAltered = securecall(WantsAlteredForm, "player")
		if wantsAltered then
			AFKS.AFKMode.bottom.model:SetSize(GetScreenWidth() * 1.7, GetScreenHeight() * 1.7)
			yoffset = yoffset + 30
		else
			AFKS.AFKMode.bottom.model:SetSize(GetScreenWidth() * 2, GetScreenHeight() * 2)
			yoffset = yoffset + -7
		end
	else
		if model_yoffset[raceid] then
			yoffset = yoffset + model_yoffset[raceid]
		end
	end

	if select(2, UnitClass("player")) == "DRUID" then
		local formID = securecall(GetShapeshiftFormID)
		if formID == 5 then -- Bear form
			AFKS.AFKMode.bottom.model:SetSize(GetScreenWidth() * 1, GetScreenHeight() * 1)
			yoffset = yoffset + -120
		elseif formID == 1 then -- Cat form
			AFKS.AFKMode.bottom.model:SetSize(GetScreenWidth() * 2, GetScreenHeight() * 2)
			yoffset = yoffset - 135
		elseif formID == 27 or formID == 29 then -- Flying form
			AFKS.AFKMode.bottom.model:SetSize(GetScreenWidth() * 1.4, GetScreenHeight() * 1.4)
			yoffset = yoffset + -10
		elseif formID == 31 or formID == 35 then -- Moonkin form
			AFKS.AFKMode.bottom.model:SetSize(GetScreenWidth() * 2, GetScreenHeight() * 2)
			yoffset = yoffset + -55
		elseif formID == 36 then -- Treant form
			AFKS.AFKMode.bottom.model:SetSize(GetScreenWidth() * 1.2, GetScreenHeight() * 1.2)
			yoffset = yoffset + -30
		else
			if needs_to_resize[raceid] then
				AFKS.AFKMode.bottom.model:SetSize(GetScreenWidth() * needs_to_resize[raceid], GetScreenHeight() * needs_to_resize[raceid])
			else
				AFKS.AFKMode.bottom.model:SetSize(GetScreenWidth() * 2, GetScreenHeight() * 2)
			end
		end
	end
	AFKS.AFKMode.bottom.modelHolder:ClearAllPoints()
	AFKS.AFKMode.bottom.modelHolder:SetPoint("BOTTOMRIGHT", AFKS.AFKMode.bottom, "BOTTOMRIGHT", -220, 265 + yoffset)

	local specid = select(1, GetSpecializationInfo(GetSpecialization()))
	local atlasname = specid and SpecIDToBackgroundAtlas[specid]
	local offset = panel_offset[specid] or 0.049	-- default offset 0.049
	local info = atlasname and GetAtlasInfo(atlasname)

	if info then
		local scaleFactor = 16.93 / ( GetScreenWidth() / panelheight )
		local fixedHeight = (info.bottomTexCoord - info.topTexCoord) * scaleFactor
		local top = info.topTexCoord + offset
		local bottom = top + fixedHeight

		AFKS.AFKMode.bottom:SetBackdropColor(.06, .06, .06, 0)
		AFKS.AFKMode.bottom.specpanel:Show()
		AFKS.AFKMode.bottom.specpanel:SetTexture(info.file)
		AFKS.AFKMode.bottom.specpanel:SetTexCoord(info.leftTexCoord, info.rightTexCoord, top, bottom)
		if GetScreenWidth() - 1567 > 0 then
			SetLeftEndColor(specid)
		else
			AFKS.AFKMode.bottom.leftendtex:Hide()
		end
	else
		AFKS.AFKMode.bottom:SetBackdropColor(.06, .06, .06, .8)
		AFKS.AFKMode.bottom.specpanel:Hide()
		AFKS.AFKMode.bottom.leftendtex:Hide()
	end
end

local function SetSpecIcon()
	if UnitLevel("player") >= 10 then
		if wowVersion == "retail" then
			local _, _, _, specicon = select(1, GetSpecializationInfo(GetSpecialization())) 
			if specicon then
				AFKS.AFKMode.bottom.specicon:SetTexture(specicon)
				AFKS.AFKMode.bottom.specicon:Show()
			else
				AFKS.AFKMode.bottom.specicon:Hide()
			end
		elseif wowVersion == "mop" then
			local specicon = select(4, GetSpecializationInfo(GetSpecialization()))
			if specicon then
				AFKS.AFKMode.bottom.specicon:SetTexture(specicon)
				AFKS.AFKMode.bottom.specicon:Show()
			else
				AFKS.AFKMode.bottom.specicon:Hide()
			end
		elseif wowVersion == "cata" then
			local talent_points = {}
			local spent = 0
			local specicon

			for i = 1, GetNumTalentTabs() do
				talent_points[i] = {}
				talent_points[i]["icon"] = select(4, GetTalentTabInfo(i))
				talent_points[i]["spent"] = select(5, GetTalentTabInfo(i))
			end
			for k, v in pairs(talent_points) do
				if k == 1 then
					spent = v["spent"]
					specicon = v["icon"]
				else
					if v["spent"] > spent then
						specicon = v["icon"]
						spent = v["spent"]
					end
				end
			end
			if specicon then
				AFKS.AFKMode.bottom.specicon:SetTexture(specicon)
				AFKS.AFKMode.bottom.specicon:Show()
			else
				AFKS.AFKMode.bottom.specicon:Hide()
			end
		else
			-- BCC Anniversary and Era Classic
			local maxPoints = -1
			local primaryTalent
		
			for i = 1, GetNumTalentTabs() do
				local spentPoints = select(5, GetTalentTabInfo(i))
				if spentPoints >= maxPoints then
					maxPoints = spentPoints
					primaryTalent = i
				end
			end

			AFKS.AFKMode.bottom.specicon:SetTexture(select(4, GetTalentTabInfo(primaryTalent)))
			AFKS.AFKMode.bottom.specicon:Show()
		end
	else
		AFKS.AFKMode.bottom.specicon:Hide()
	end
end

local function SetDate(weekday_str, weekday_num)
	local weekday
	if eastasian then
		local localized_weekday = {
			_G.WEEKDAY_SUNDAY,
			_G.WEEKDAY_MONDAY,
			_G.WEEKDAY_TUESDAY,
			_G.WEEKDAY_WEDNESDAY,
			_G.WEEKDAY_THURSDAY,
			_G.WEEKDAY_FRIDAY,
			_G.WEEKDAY_SATURDAY,
		}

		weekday = localized_weekday[weekday_num+1]
	else
		weekday = weekday_str
	end

	if weekday_num == 6 then -- Sat
		weekday = "|cFF2b59FF"..weekday.."|r"
	elseif weekday_num == 0 then -- Sun
		weekday = "|cFFFF2b2b"..weekday.."|r"
	end

	if eastasian then -- East Asian date format check
		AFKS.AFKMode.bottom.date:SetText(format(AFKS_DATEFORMAT, date("%Y"), date("%m"), date("%d"), weekday))
	else
		AFKS.AFKMode.bottom.date:SetText(format(AFKS_DATEFORMAT, date("%b"), date("%d"), date("%Y"), weekday))
	end
end

local function GetCalendarSchedule(day, hour)
	for i = 1, GetNumDayEvents(0, day) do
		local event = GetDayEvent(0, day, i)
		if issecrettable and issecrettable(event) then break end
		if event and event.calendarType == "PLAYER" and event.startTime.hour > hour then
			if event.inviteStatus == 2 or event.inviteStatus == 4 then
				return
			end

			if event.inviteStatus == 1 then
				AFKS.AFKMode.bottom.schedule:SetTextColor(0, 1, 0)
			end
			AFKS.AFKMode.bottom.calendaricon:SetTexture(event.iconTexture)
			local minute = event.startTime.minute
			if event.startTime.minute < 10 then
				minute = "0"..minute
			end

			local ampm
			if event.startTime.hour < 12 then
				ampm = _G.TIMEMANAGER_AM
			else
				ampm = _G.TIMEMANAGER_PM
				if event.startTime.hour > 12 then
					event.startTime.hour = event.startTime.hour - 12
				end
			end

			if eastasian then
				AFKS.AFKMode.bottom.schedule:SetText("("..ampm.." "..event.startTime.hour..":"..minute..") "..event.title)
			else
				AFKS.AFKMode.bottom.schedule:SetText(event.title.." in "..event.startTime.hour..":"..minute.." "..ampm)
			end
			break
		end
	end                   
end

local function GetWoWLogo()
	local expansion
	local rltype
	if wowVersion ~= "retail" then
		rltype = _G.LE_RELEASE_TYPE_CLASSIC or _G.Enum.ReleaseType.Classic
	end
	if wowVersion == "retail" then
		expansion = GetExpansionDisplayInfo(GetClientDisplayExpansionLevel())
	elseif wowVersion == "mop" then
		expansion = GetExpansionDisplayInfo(GetClassicExpansionLevel(), rltype)
	elseif wowVersion == "wrath" or wowVersion == "cata" then -- CN Only
		expansion = GetExpansionDisplayInfo(GetClientDisplayExpansionLevel(), rltype)
	else
		expansion = GetCurrentGameModeDisplayInfo()
	end
	return expansion and expansion.logo
end

function AFKS:RenderOptions()
	local panel = CreateFrame("Frame", "AFKS_OptionPanel")
	panel.name = "AFKS"

	local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)

	local title = panel:CreateFontString("ARTWORK", nil, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetText("AFKS")

	local enable = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
	enable:SetPoint("TOPLEFT", 10, -35)
	enable.Text:SetText(AFKS_ENABLED_TEXT)
	enable.tooltip = AFKS_ENABLED_TOOLTIP
	enable:HookScript("OnClick", function(_, btn, down)
		self.options.enabled = enable:GetChecked()
		self:Toggle()
	end)
	enable:SetChecked(self.options.enabled)

	local hidechat = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
	hidechat:SetPoint("TOPLEFT", 10, -65)
	hidechat.Text:SetText(AFKS_HIDECHAT_TEXT)
	hidechat.tooltip = AFKS_HIDECHAT_TOOLTIP
	hidechat:HookScript("OnClick", function(_, btn, down)
		self.options.hidechat = hidechat:GetChecked()
	end)
	hidechat:SetChecked(self.options.hidechat)

	local group = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
	group:SetPoint("TOPLEFT", 10, -95)
	group.Text:SetText(AFKS_GROUP_TEXT)
	group.tooltip = AFKS_GROUP_TOOLTIP
	group:HookScript("OnClick", function(_, btn, down)
		self.options.group = group:GetChecked()
	end)
	group:SetChecked(self.options.group)

	local spin = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
	spin:SetPoint("TOPLEFT", 10, -125)
	spin.Text:SetText(AFKS_SPIN_TEXT)
	spin.tooltip = AFKS_SPIN_TOOLTIP
	spin:HookScript("OnClick", function(_, btn, down)
		self.options.spin = spin:GetChecked()
	end)
	spin:SetChecked(self.options.spin)

	local animationLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	animationLabel:SetPoint("TOPLEFT", panel.CheckButton, "TOPLEFT", 0, -30) 
	animationLabel:SetText(AFKS_ANIMATION_TEXT)

	local function OnClick(value)
		AFKS.options.animation = value
	end
	
	local animation = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
	animation:SetPoint("TOPLEFT", animationLabel, "TOPLEFT", 0, -20)
	if wowVersion ~= "retail" then
		animation:SetWidth(100)
	end
	animation:SetTooltip(function(tooltip)
		GameTooltip_AddNormalLine(tooltip, AFKS_ANIMATION_TOOLTIP)
	end)
	animation:SetSelectionText(function(selections)
		local optiontext = {
			[1] = AFKS_ANIMATION_RANDOM,
			[2] = AFKS_ANIMATION_DANCE,
			[3] = AFKS_ANIMATION_LEAN,
			[4] = AFKS_ANIMATION_SALUTE,
			[5] = AFKS_ANIMATION_TALK,
			[6] = AFKS_ANIMATION_SHY,
			[7] = AFKS_ANIMATION_ROAR,
			[8] = AFKS_ANIMATION_BOW,
			[9] = AFKS_ANIMATION_CHEER,
			[10] = AFKS_ANIMATION_APPLAUSE,
			[11] = AFKS_ANIMATION_FLEX
		}
		if wowVersion ~= "retail" then
			table.remove(optiontext, 3)
		end
		return optiontext[AFKS.options.animation]
	end)

	if wowVersion == "retail" then
		MenuUtil.CreateButtonMenu(animation,
			{AFKS_ANIMATION_RANDOM, OnClick, 1},
			{AFKS_ANIMATION_DANCE, OnClick, 2},
			{AFKS_ANIMATION_LEAN, OnClick, 3},
			{AFKS_ANIMATION_SALUTE, OnClick, 4},
			{AFKS_ANIMATION_TALK, OnClick, 5},
			{AFKS_ANIMATION_SHY, OnClick, 6},
			{AFKS_ANIMATION_ROAR, OnClick, 7},
			{AFKS_ANIMATION_BOW, OnClick, 8},
			{AFKS_ANIMATION_CHEER, OnClick, 9},
			{AFKS_ANIMATION_APPLAUSE, OnClick, 10},
			{AFKS_ANIMATION_FLEX, OnClick, 11}
		)
	else
		MenuUtil.CreateButtonMenu(animation,
			{AFKS_ANIMATION_RANDOM, OnClick, 1},
			{AFKS_ANIMATION_DANCE, OnClick, 2},
			{AFKS_ANIMATION_SALUTE, OnClick, 3},
			{AFKS_ANIMATION_TALK, OnClick, 4},
			{AFKS_ANIMATION_SHY, OnClick, 5},
			{AFKS_ANIMATION_ROAR, OnClick, 6},
			{AFKS_ANIMATION_BOW, OnClick, 7},
			{AFKS_ANIMATION_CHEER, OnClick, 8},
			{AFKS_ANIMATION_APPLAUSE, OnClick, 9},
			{AFKS_ANIMATION_FLEX, OnClick, 10}
		)
	end
	
	Settings.RegisterAddOnCategory(category)
	category.ID = panel.name
end

function AFKS:Init()
	local logo = GetWoWLogo()
	local class = select(2, UnitClass("player"))

	UIscale = UIParent:GetScale()
	if panelheight < 102 then -- Adjust to 102.4 in small resolution
		panelheight = 102.4
	end

	self.AFKMode = CreateFrame("Frame", "AFKSFrame")
	self.AFKMode:SetFrameLevel(1)
	self.AFKMode:SetScale(UIscale)
	self.AFKMode:SetAllPoints(UIParent)
	self.AFKMode:Hide()
	self.AFKMode:EnableKeyboard(true)
	self.AFKMode:SetScript("OnKeyDown", OnKeyDown)

	self.AFKMode.exitpanel = CreateFrame("Frame", nil, self.AFKMode)
	self.AFKMode.exitpanel:SetSize(30, 30)
	self.AFKMode.exitpanel:SetPoint("TOPRIGHT", self.AFKMode, "TOPRIGHT", 0, 0)
	self.AFKMode.exitbutton = CreateFrame("Button", nil, self.AFKMode.exitpanel, "UIPanelCloseButton")
	self.AFKMode.exitbutton:SetSize(25, 25)
	self.AFKMode.exitbutton:SetPoint("CENTER", self.AFKMode.exitpanel, 0, 0)
	self.AFKMode.exitbutton:Hide()
	self.AFKMode.exitbutton:SetScript("OnClick", function()
		UIParent:Show()
		AFKS.AFKMode:Hide()
		MoveViewLeftStop()

		AFKS.timer:Cancel()
		if AFKS.animTimer then
			AFKS.animTimer:Cancel()
		end
		AFKS.AFKMode.bottom.timer:SetText("00:00")

		AFKS.AFKMode.exitbutton:Hide()
		AFKS.AFKMode.chat:UnregisterAllEvents()
		AFKS.AFKMode.chat:Clear()

		AFKS.isAFK = false
		--AFKS.isCinematic = false
	end)
	self.AFKMode.exitpanel:SetScript("OnMouseDown", function() AFKS.AFKMode.exitbutton:Show() end)

	self.AFKMode.chat = CreateFrame("ScrollingMessageFrame", nil, self.AFKMode)
	self.AFKMode.chat:SetSize(500, 300)
	self.AFKMode.chat:SetPoint("BOTTOMLEFT", self.AFKMode, "BOTTOMLEFT", 4, 120)
	FontTemplate(self.AFKMode.chat, 18)
	self.AFKMode.chat:SetJustifyH("LEFT")
	self.AFKMode.chat:SetMaxLines(500)
	self.AFKMode.chat:SetClampedToScreen(true)
	self.AFKMode.chat:EnableMouseWheel(true)
	self.AFKMode.chat:SetFading(false)
	self.AFKMode.chat:SetMovable(true)
	self.AFKMode.chat:EnableMouse(true)
	self.AFKMode.chat:RegisterForDrag("LeftButton")
	self.AFKMode.chat:SetScript("OnDragStart", self.AFKMode.chat.StartMoving)
	self.AFKMode.chat:SetScript("OnDragStop", self.AFKMode.chat.StopMovingOrSizing)
	self.AFKMode.chat:SetScript("OnMouseDown", Chat_MouseDown)
	self.AFKMode.chat:SetScript("OnMouseWheel", Chat_OnMouseWheel)
	self.AFKMode.chat:SetScript("OnEvent", Chat_OnEvent)

	self.AFKMode.bottom = CreateFrame("Frame", nil, self.AFKMode, BackdropTemplateMixin and "BackdropTemplate")
	self.AFKMode.bottom:SetFrameLevel(0)
	SetTemplate(self.AFKMode.bottom)
	self.AFKMode.bottom:SetPoint("BOTTOM", self.AFKMode, "BOTTOM", 0, -2)
	self.AFKMode.bottom:SetWidth(GetScreenWidth() + 4)
	self.AFKMode.bottom:SetHeight(panelheight)

	self.AFKMode.bottom.logo = self.AFKMode:CreateTexture(nil, "OVERLAY")
	self.AFKMode.bottom.logo:SetSize(192, 192)  --lnui
	self.AFKMode.bottom.logo:SetPoint("CENTER", self.AFKMode.bottom, "CENTER", 0, 40)  --lnui
	self.AFKMode.bottom.logo:SetTexture("Interface/AddOns/!!!163UI!!!/Textures/UI2-logo")  --lnui

	self.AFKMode.chatminbar = CreateFrame("Frame", nil, self.AFKMode, BackdropTemplateMixin and "BackdropTemplate")
	self.AFKMode.chatminbar:SetPoint("BOTTOMLEFT", self.AFKMode.bottom, "TOPLEFT", 0, 2)
	self.AFKMode.chatminbar:SetSize(350, 20)
	self.AFKMode.chatminbar:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = nil,
		tile = false, tileSize = 0, edgeSize = 0,
	})
	self.AFKMode.chatminbar:SetBackdropColor(.2, .2, .2, .0)
	self.AFKMode.chatminbar:SetScript("OnMouseDown", ChatMinBar_MouseDown)

	self.AFKMode.chatminbar.title = self.AFKMode.chatminbar:CreateFontString(nil, "OVERLAY")
	self.AFKMode.chatminbar.title:SetPoint("CENTER", self.AFKMode.chatminbar, "CENTER", 0, 0)
	FontTemplate(self.AFKMode.chatminbar.title, 20, "OUTLINE")

	local text = format(AFKS_CHATBAR_TEXT, 0, 0, 0)
	if IsInGuild() then
		text = text.." "..format(AFKS_CHATBAR_GUILD, 0)
	end
	self.AFKMode.chatminbar.title:SetText(text)
	self.AFKMode.chatminbar.title:SetTextColor(.6, .6, .6)
	self.AFKMode.chatminbar.title:Hide()

	if wowVersion == "retail" then
		local yoffset = panelheight - 102.4
		if yoffset < 0 then
			yoffset = 0
		end

		self.AFKMode.bottom.specpanel = self.AFKMode.bottom:CreateTexture(nil, "BACKGROUND")
		self.AFKMode.bottom.specpanel:SetSize(1, 1)--lnui,去掉天赋背景
		self.AFKMode.bottom.leftend = CreateFrame("Frame", nil, self.AFKMode.bottom)		
		self.AFKMode.bottom.leftendtex = self.AFKMode.bottom.leftend:CreateTexture(nil, "BACKGROUND")		
		-- self.AFKMode.bottom.specpanel:SetPoint("RIGHT", self.AFKMode.bottom, "BOTTOMRIGHT", 0, -285 + yoffset)
		-- self.AFKMode.bottom.leftendtex:SetPoint("LEFT", self.AFKMode.bottom, "LEFT", 0, 0)
		-- self.AFKMode.bottom.leftendtex:SetTexture("Interface/BUTTONS/WHITE8X8")
	end

	if wowVersion == "retail" or wowVersion == "cata" or wowVersion == "mop" then
		self.AFKMode.bottom.schedule = self.AFKMode.bottom:CreateFontString(nil, "OVERLAY")
		FontTemplate(self.AFKMode.bottom.schedule, 20, "OUTLINE")
		self.AFKMode.bottom.schedule:SetPoint("BOTTOMLEFT", self.AFKMode.bottom.logo, "BOTTOMRIGHT", 200, 0)
		self.AFKMode.bottom.schedule:SetTextColor(1, 1, 1)
		self.AFKMode.bottom.calendaricon = self.AFKMode.bottom:CreateTexture(nil, "OVERLAY")
		self.AFKMode.bottom.calendaricon:SetPoint("RIGHT", self.AFKMode.bottom.schedule, "LEFT", 0, 0)
		self.AFKMode.bottom.calendaricon:SetSize(40, 40)
	end

	local factionGroup = UnitFactionGroup("player")
	local size, offsetX, offsetY = 140, -20, -16
	local nameOffsetX, nameOffsetY = -10, -28
	local ratio = tonumber(strsub(GetMonitorAspectRatio(), 0, 3))
	if ratio == 1.6 then
		nameOffsetY = -45 -- 16:10 monitor ratio fix
	end
	if factionGroup == "Neutral" then
		factionGroup = "Panda"
		size, offsetX, offsetY = 90, 15, 10
		nameOffsetX, nameOffsetY = 20, -5
		if ratio == 1.6 then
			nameOffsetY = -22 -- a chinese font size is bigger than others
		end
	end

	if wowVersion == "retail" then
		self.AFKMode.bottom.faction = self.AFKMode.bottom.leftend:CreateTexture(nil, "OVERLAY")
	else
		self.AFKMode.bottom.faction = self.AFKMode.bottom:CreateTexture(nil, "OVERLAY")
	end
	self.AFKMode.bottom.faction:SetPoint("BOTTOMLEFT", self.AFKMode.bottom, "BOTTOMLEFT", offsetX, offsetY)
	self.AFKMode.bottom.faction:SetTexture("Interface\\Timer\\"..factionGroup.."-Logo")
	self.AFKMode.bottom.faction:SetSize(size, size)

	if wowVersion == "retail" then
		self.AFKMode.bottom.name = self.AFKMode.bottom.leftend:CreateFontString(nil, "OVERLAY")
	else
		self.AFKMode.bottom.name = self.AFKMode.bottom:CreateFontString(nil, "OVERLAY")
	end
	FontTemplate(self.AFKMode.bottom.name, 20, "OUTLINE")
	self.AFKMode.bottom.name:SetText(format("%s-%s", UnitName("player"), GetRealmName()))
	self.AFKMode.bottom.name:SetPoint("TOPLEFT", self.AFKMode.bottom.faction, "TOPRIGHT", nameOffsetX, nameOffsetY)
	self.AFKMode.bottom.name:SetTextColor(RAID_CLASS_COLORS[class].r, RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b)

	if wowVersion == "retail" then
		self.AFKMode.bottom.specicon = self.AFKMode.bottom.leftend:CreateTexture(nil, "OVERLAY")
	else
		self.AFKMode.bottom.specicon = self.AFKMode.bottom:CreateTexture(nil, "OVERLAY")
	end
	self.AFKMode.bottom.specicon:SetPoint("CENTER", self.AFKMode.bottom.name, "RIGHT", 15, -2)
	self.AFKMode.bottom.specicon:SetSize(25, 25)
	self.AFKMode.bottom.specicon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	if wowVersion == "retail" then
		self.AFKMode.bottom.guild = self.AFKMode.bottom.leftend:CreateFontString(nil, "OVERLAY")
	else
		self.AFKMode.bottom.guild = self.AFKMode.bottom:CreateFontString(nil, "OVERLAY")
	end
	FontTemplate(self.AFKMode.bottom.guild, 20, "OUTLINE")
	self.AFKMode.bottom.guild:SetText(AFKS_NOGUILD)
	self.AFKMode.bottom.guild:SetPoint("TOPLEFT", self.AFKMode.bottom.name, "BOTTOMLEFT", 0, -6)
	self.AFKMode.bottom.guild:SetTextColor(0.7, 0.7, 0.7)

	if wowVersion == "retail" then
		self.AFKMode.bottom.timer = self.AFKMode.bottom.leftend:CreateFontString(nil, "OVERLAY")
	else
		self.AFKMode.bottom.timer = self.AFKMode.bottom:CreateFontString(nil, "OVERLAY")
	end
	FontTemplate(self.AFKMode.bottom.timer, 20, "OUTLINE")
	self.AFKMode.bottom.timer:SetText("00:00")
	self.AFKMode.bottom.timer:SetPoint("TOPLEFT", self.AFKMode.bottom.guild, "BOTTOMLEFT", 0, -6)
	self.AFKMode.bottom.timer:SetTextColor(0.7, 0.7, 0.7)

	self.AFKMode.bottom.date = self.AFKMode.bottom:CreateFontString(nil, "OVERLAY")
	FontTemplate(self.AFKMode.bottom.date, 20, "OUTLINE")
	self.AFKMode.bottom.date:SetPoint("RIGHT", self.AFKMode.bottom, "RIGHT", -10, 25)
	self.AFKMode.bottom.date:SetTextColor(0.7, 0.7, 0.7)

	self.AFKMode.bottom.time = self.AFKMode.bottom:CreateFontString(nil, "OVERLAY")
	FontTemplate(self.AFKMode.bottom.time, 20, "OUTLINE")
	self.AFKMode.bottom.time:SetPoint("CENTER", self.AFKMode.bottom.date, "CENTER", 0, -50)
	self.AFKMode.bottom.time:SetTextColor(0.7, 0.7, 0.7)

	--Use this frame to control position of the model
	self.AFKMode.bottom.modelHolder = CreateFrame("Frame", nil, self.AFKMode.bottom)
	self.AFKMode.bottom.modelHolder:SetSize(150, 150)
	if wowVersion == "retail" then
		self.AFKMode.bottom.modelHolder:SetPoint("BOTTOMRIGHT", self.AFKMode.bottom, "BOTTOMRIGHT", -220, 265)
	else
		self.AFKMode.bottom.modelHolder:SetPoint("BOTTOMRIGHT", self.AFKMode.bottom, "BOTTOMRIGHT", -220, 220)
	end

	self.AFKMode.bottom.model = CreateFrame("PlayerModel", "AFKSPlayerModel", self.AFKMode.bottom.modelHolder)
	self.AFKMode.bottom.model:SetPoint("CENTER", self.AFKMode.bottom.modelHolder, "CENTER")
	self.AFKMode.bottom.model:SetSize(GetScreenWidth() * 2, GetScreenHeight() * 2)
	self.AFKMode.bottom.model:SetCamDistanceScale(4.5) --Since the model frame is huge, we need to zoom out quite a bit.
	self.AFKMode.bottom.model:SetFacing(6)
	self.AFKMode.bottom.model:SetScript("OnUpdate", function(self)
		if self.isIdle then return end

		local timePassed = GetTime() - self.startTime
		if timePassed >= self.duration then
			self:SetAnimation(0)
			self.isIdle = true

			AFKS.animTimer = NewTimer(self.idleDuration, PlayAnimations)
		end
	end)

	self.isInterrupted = false
	--self.isCinematic = false

	self:SetScript("OnEvent", function(event, ...)
		self:OnEvent(...)
	end)
end

do
	AFKS:RegisterEvent("VARIABLES_LOADED")

	AFKS:Init()

	if LFGListInviteDialog_Show then
		hooksecurefunc ("LFGListInviteDialog_Show", function()
			if not securecall(InCombatLockdown) then
				AFKS:SetAFK(false)
			end
		end)
	end

	if wowVersion == "retail" then
		AddonCompartmentFrame:RegisterAddon({
			text = "AFKS",
			icon = "Interface\\AddOns\\AFKS\\AFKS-icon.tga",
			notCheckable = true,
			func = function()
				_G.Settings.OpenToCategory("AFKS")
			end,
		})
	end
end

function AFKS:UpdateTimer()
	self.AFKMode.bottom.time:SetText(format("%s", GameTime_GetLocalTime(true)))

	local curtime = GetTime() - self.startTime
	self.AFKMode.bottom.timer:SetText(format("%02d:%02d", floor(curtime/60), curtime % 60))

	if date("%H") == "23" and date("%M") == "59" and tonumber(date("%S")) >= 55 then
		SetDate(date("%a"), tonumber(date("%w")))
		if wowVersion == "retail" or wowVersion == "cata" or wowVersion == "mop" then
			GetCalendarSchedule(tonumber(date("%d")), tonumber(date("%H")))
		end
	end
end

function AFKS:SetAFK(status)
	if status then
		local currUIscale = UIParent:GetScale()

		if UIscale ~= currUIscale then
			UIscale = currUIscale
			panelheight = GetScreenHeight() * 0.1
			if panelheight < 102 then -- Adjust to 102.4 in small resolution
				panelheight = 102.4
			end

			local yoffset = panelheight - 102.4

			self.AFKMode:SetScale(UIscale)
			self.AFKMode.bottom:SetWidth(GetScreenWidth() + 4)
			self.AFKMode.bottom:SetHeight(panelheight)
			self.AFKMode.bottom.model:SetSize(GetScreenWidth() * 2, GetScreenHeight() * 2)

			if wowVersion == "retail" then
				if yoffset < 0 then
					yoffset = 0
				end
				self.AFKMode.bottom.specpanel:SetPoint("RIGHT", self.AFKMode.bottom, "BOTTOMRIGHT", 0, -285 + yoffset)
			else
				if yoffset > 0 then
					yoffset = yoffset + 30
				else
					yoffset = yoffset - 30
				end
				self.AFKMode.bottom.modelHolder:ClearAllPoints()
				self.AFKMode.bottom.modelHolder:SetPoint("BOTTOMRIGHT", self.AFKMode.bottom, "BOTTOMRIGHT", -220, 220 + yoffset)
			end
		end

		if self.options.spin then
			MoveViewLeftStart(0.035)
		else
			MoveViewLeftStop()
		end
		self.AFKMode:Show()
		--CloseAllWindows()
		UIParent:Hide()

		SetDate(date("%a"), tonumber(date("%w")))
		self.AFKMode.bottom.time:SetText(format("%s", GameTime_GetLocalTime(true)))

		if securecall(IsInGuild) then
			local guildName, guildRankName = GetGuildInfo("player")
			self.AFKMode.bottom.guild:SetText(format("%s-%s", guildName, guildRankName))
		else
			self.AFKMode.bottom.guild:SetText(AFKS_NOGUILD)
		end

		SetSpecIcon()

		if wowVersion == "retail" then
			SetSpecPanel()
			if PlayerIsTimerunning then
				local isTimerunning = securecall(PlayerIsTimerunning)
				if isTimerunning then
					local expansion = GetExpansionDisplayInfo(6)
					self.AFKMode.bottom.logo:SetTexture("Interface/AddOns/!!!163UI!!!/Textures/UI2-logo")  --lnui
				end
			end
		end

		if wowVersion == "retail" or wowVersion == "cata" or wowVersion == "mop" then
			GetCalendarSchedule(tonumber(date("%d")), tonumber(date("%H")))
		end

		self.AFKMode.bottom.model.curAnimation = "wave"
		self.AFKMode.bottom.model.startTime = GetTime()
		self.AFKMode.bottom.model.duration = 2.3
		self.AFKMode.bottom.model:SetUnit("player")
		self.AFKMode.bottom.model.isIdle = nil
		self.AFKMode.bottom.model:SetAnimation(67)
		self.AFKMode.bottom.model.idleDuration = 25
		self.startTime = GetTime()
		self.timer = NewTicker(1, function() self:UpdateTimer() end)

		if self.AFKMode.chatminbar.minimized then
			self.AFKMode.chatminbar.unreadwhisper = 0
			self.AFKMode.chatminbar.unreadbnet = 0
			self.AFKMode.chatminbar.unreadchannel = 0
			self.AFKMode.chatminbar.unreadguild = 0

			local text = format(AFKS_CHATBAR_TEXT, AFKS.AFKMode.chatminbar.unreadwhisper, AFKS.AFKMode.chatminbar.unreadbnet, AFKS.AFKMode.chatminbar.unreadchannel)
			if securecall(IsInGuild) then
				text = text.." "..format(AFKS_CHATBAR_GUILD, AFKS.AFKMode.chatminbar.unreadguild)
			end
		end

		if self.options.hidechat then
			self.AFKMode.chat:UnregisterAllEvents()
			self.AFKMode.chat:Clear()
		else
			self.AFKMode.chat:RegisterEvent("CHAT_MSG_WHISPER")
			self.AFKMode.chat:RegisterEvent("CHAT_MSG_BN_WHISPER")
			self.AFKMode.chat:RegisterEvent("CHAT_MSG_GUILD")
			self.AFKMode.chat:RegisterEvent("CHAT_MSG_CHANNEL")

			if wowVersion == "retail" then
				self.AFKMode.chat:RegisterEvent("CHAT_MSG_COMMUNITIES_CHANNEL")
			end
		end

		self.isAFK = true
	elseif not status and self.isAFK then
		UIParent:Show()
		self.AFKMode:Hide()
		if wowVersion == "retail" then
			local hasNewMail = securecall(HasNewMail)
			if hasNewMail then
				MinimapCluster.IndicatorFrame.MailFrame.MailIcon:Show()
			end
		end

		MoveViewLeftStop()
		self.timer:Cancel()
		if self.animTimer then self.animTimer:Cancel() end

		self.AFKMode.bottom.timer:SetText("00:00")
		self.AFKMode.exitbutton:Hide()
		self.AFKMode.chat:UnregisterAllEvents()
		self.AFKMode.chat:Clear()

		if wowVersion == "retail" and PVEFrame:IsShown() then --odd bug, frame is blank
			PVEFrame_ToggleFrame()
			PVEFrame_ToggleFrame()
		end

		self.isAFK = false
		--self.isCinematic = false
	end
end