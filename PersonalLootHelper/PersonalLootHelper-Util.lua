-- Keys for the waitFrames and waitTables arrays
PLH_WAIT_FOR_ENABLE_OR_DISABLE = 1
PLH_WAIT_FOR_INSPECT = 2

local waitFrames = {}
local waitTables = {}

local function GetNameWithoutSpacesInRealm(name)
	if name == nil or string.find(name, '-') == nil then
		return name
	else
		local shortname, realm = name:match('(.+)-(.+)')
		realm = realm:gsub("%s+","")
		return shortname .. '-' .. realm
	end
end

function PLH_GetFullName(name)
    if name == nil then
        return nil
    end

    -- 使用 pcall 捕获可能由 secret 字符串引发的错误
    local success, result = pcall(function()
        local processedName = name

        -- 如果名称包含 realm（带 '-'），则去除 realm 中的空格
        if string.find(processedName, '-') then
            local shortname, realm = processedName:match('(.+)-(.+)')
            if realm then
                realm = realm:gsub("%s+", "")
                processedName = shortname .. '-' .. realm
            end
        else
            -- 没有 realm，尝试通过 GUID 获取完整名称（包含 realm）
            local guid = UnitGUID(processedName)
            if guid then
                local shortname, realm = UnitNameFromGUID(guid)
                if not realm or realm == '' then
                    realm = GetRealmName()
                end
                if shortname then
                    processedName = shortname .. (realm and ('-' .. realm) or '')
                end
                -- 若无法获取，则保持原名称
            end
        end

        return processedName
    end)

    if success then
        return result
    else
        -- 出错时（例如 secret 字符串）返回原始名称，避免崩溃
        return name
    end
end

local function CanUseRaidWarning()
	return UnitIsGroupLeader('player') or UnitIsRaidOfficer('player')
end

local function GetBroadcastChannel(isHighPriority)
	local channel
	if IsInGroup() then
		if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
			if CanUseRaidWarning() and isHighPriority then 
				channel = 'RAID_WARNING'
			else
				channel = 'INSTANCE_CHAT'
			end
		elseif IsInRaid() then
			if CanUseRaidWarning() and isHighPriority then 
				channel = 'RAID_WARNING'
			else
				channel = 'RAID'
			end
		else	
			channel = 'PARTY'
		end
	else
		channel = 'EMOTE'  -- for testing purposes
	end
	return channel
end

local function GetColoredMessage(message, color)
	if message ~= nil then
		message = color .. message   							-- set desired color at the start
		message = string.gsub(message, '|r', '|r' .. color)		-- set to our color if the message sets color to default (ex: end of an item link)
		message = message .. _G.FONT_COLOR_CODE_CLOSE			-- set color back to default
	end
	return message
end

function PLH_SendBroadcast(message, isHighPriority)
	SendChatMessage('|TInterface/AddOns/PersonalLootHelper/laonong:20|t|cff19CCF9[老农整合包]:|r ' .. message, GetBroadcastChannel(isHighPriority))
end	

function PLH_SendWhisper(message, person)
	SendChatMessage('|TInterface/AddOns/PersonalLootHelper/laonong:20|t|cff19CCF9[老农整合包]:|r ' .. message, 'WHISPER', nil, person)
end

function PLH_SendAlert(message)
	if not message then return end
	print(GetColoredMessage('|TInterface/AddOns/PersonalLootHelper/laonong:20|t|cff19CCF9[老农整合包]:|r ', _G.YELLOW_FONT_COLOR_CODE) .. GetColoredMessage(message, _G.GREEN_FONT_COLOR_CODE))
end	

function PLH_SendUserMessage(message)
	if not message then return end
	print(GetColoredMessage('|TInterface/AddOns/PersonalLootHelper/laonong:20|t|cff19CCF9[老农整合包]:|r ', _G.YELLOW_FONT_COLOR_CODE) .. GetColoredMessage(message, _G.LIGHTYELLOW_FONT_COLOR_CODE))
end	

function PLH_SendDebugMessage(message)
	if not message then return end
	if PLH_PREFS[PLH_PREFS_DEBUG] then
		print(GetColoredMessage('|TInterface/AddOns/PersonalLootHelper/laonong:20|t|cff19CCF9[老农整合包]:|r ', _G.YELLOW_FONT_COLOR_CODE) .. GetColoredMessage(message, _G.GRAY_FONT_COLOR_CODE))
	end		
end	

-- Returns the message that would be whispered when player requests an item
function PLH_GetWhisperMessage(itemLink, message)
	if message == nil then
		message = PLH_PREFS[PLH_PREFS_WHISPER_MESSAGE]
	end
	return message:gsub('%%item', itemLink)
end

-- Waits for delay seconds before executing func
-- the waitType parameter allows us to have multiple wait loops going on at once; pass in a unique ID for each possible type of wait loop
function PLH_wait(waitType, delay, func, ...)
	if (type(delay) == 'number' and type(func) == 'function') then
		if waitTables[waitType] == nil then
			waitTables[waitType] = {}
		end
		if waitFrames[waitType] == nil then
			waitFrames[waitType] = CreateFrame('Frame', 'PLH_WaitFrame' .. waitType, UIParent)
			waitFrames[waitType]:SetScript('onUpdate', function (self, elapse)
				local count = #waitTables[waitType]
				local i = 1
				while i <= count do
					local waitRecord = tremove(waitTables[waitType], i)
					local d = tremove(waitRecord, 1)
					local f = tremove(waitRecord, 1)
					local p = tremove(waitRecord, 1)
					if d > elapse then
						tinsert(waitTables[waitType], i, {d - elapse, f, p})
						i = i + 1
					else
						count = count - 1
						f(unpack(p))
					end
				end
			end);
		end
		tinsert(waitTables[waitType], {delay, func, {...}});
	else
		print('Bad types in PLH_wait')
	end
end

function PLH_PreemptWait(waitType)
	local waiting = #waitTables[waitType] ~= nil and #waitTables[waitType] > 0
	waitTables[waitType] = {}
	return waiting
end