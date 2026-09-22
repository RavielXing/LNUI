local _, GF = ...

-- 聊天消息颜色、格式化与输出。

GF.CHAT_RESET_COLOR_CODE = "|r"
GF.CHAT_ADDON_PREFIX_COLOR_CODE = "|cffffd200"
GF.CHAT_WARNING_PREFIX_COLOR_CODE = GF.CHAT_ADDON_PREFIX_COLOR_CODE
GF.CHAT_WARNING_BODY_COLOR_CODE = "|cffffffff"
GF.CHAT_STATUS_PREFIX_COLOR_CODE = GF.CHAT_ADDON_PREFIX_COLOR_CODE
GF.CHAT_STATUS_BODY_COLOR_CODE = "|cffffffff"
GF.CHAT_STATUS_HIGHLIGHT_COLOR_CODE = "|cffffd200"
GF.CHAT_STATUS_CONFIRM_COLOR_CODE = "|cff00ff00"
GF.CHAT_STATUS_FAILURE_COLOR_CODE = "|cffff4040"
GF.WARNING_COLOR = { 1, 1, 1, 1 }
GF.STATUS_MESSAGE_COLOR = { 1, 1, 1, 1 }

local ADDON_CHAT_PREFIXES = {
	"[魔兽集合石] ",
	"[魔獸集合石] ",
	"[GroupFinder] ",
	"魔兽集合石：",
	"魔獸集合石：",
	"魔兽集合石:",
	"魔獸集合石:",
	"GroupFinder：",
	"GroupFinder:",
}

local function getAddonChatPrefix()
	local addonName = (GF.L and GF.L.ADDON_NAME) or "GroupFinder"
	return "[" .. addonName .. "] "
end

local function splitAddonChatMessage(msg)
	msg = tostring(msg or "")
	-- 诊断标题也是品牌前缀，不能再额外加一份普通品牌标题。
	local leadingColor = msg:match("^|[cC]%x%x%x%x%x%x%x%x")
		or msg:match("^|[cC][nN][%w_]+:")
	local candidate = leadingColor and msg:sub(#leadingColor + 1) or msg
	local function remainingBody(remainder)
		remainder = remainder:gsub("^%s+", "")
		if remainder:match("^|[rR]") then
			return remainder:gsub("^|[rR]%s*", "")
		end
		return (leadingColor or "") .. remainder
	end
	local heading, remainder = candidate:match("^%[([^%]]+)%]%s*(.*)$")
	if heading then
		for _, name in ipairs({ "魔兽集合石", "魔獸集合石", "GroupFinder" }) do
			if heading == name or heading:sub(1, #name + 1) == name .. "-" then
				local localizedName = (GF.L and GF.L.ADDON_NAME) or "GroupFinder"
				return "[" .. localizedName .. heading:sub(#name + 1) .. "] ",
					remainingBody(remainder)
			end
		end
	end
	for _, prefix in ipairs(ADDON_CHAT_PREFIXES) do
		if candidate:sub(1, #prefix) == prefix then
			return getAddonChatPrefix(), remainingBody(candidate:sub(#prefix + 1))
		end
	end
	local prefix = getAddonChatPrefix()
	return prefix, msg
end

local function colorWrap(colorCode, text)
	return (colorCode or "") .. tostring(text or "") .. (GF.CHAT_RESET_COLOR_CODE or "|r")
end

-- 登录公告按客户端语言取文案，不跟随插件界面语言或调试语言。
-- 单次输出由 RuntimeLifecycle 的登录门负责；这里只渲染一条本地消息。
function GF.ShowLoginMessage()
	local localeKey = GF.Locale and GF.Locale:GetSystemLocaleKey()
	local L
	if localeKey == "zhCN" then
		L = GF.locale_zhCN
	elseif localeKey == "zhTW" then
		L = GF.locale_zhTW
	end
	local message = L and L.LOGIN_COMMUNITY_MESSAGE
	local frame = DEFAULT_CHAT_FRAME
	if not message or message == "" or not (frame and frame.AddMessage) then
		return false
	end
	local text = colorWrap(GF.CHAT_ADDON_PREFIX_COLOR_CODE, "[" .. L.ADDON_NAME .. "]")
		.. " " .. colorWrap("|cff00e5ff", message)
	frame:AddMessage(text)
	return true
end

local function isAccessibleNonSecretChatText(value)
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
	return type(value) == "string"
end

local semanticRules = {}
local function addSemanticRules(words, color, standalone)
	for _, word in ipairs(words) do
		semanticRules[#semanticRules + 1] = {
			word = word, color = color, english = word:match("^%a") ~= nil,
			standalone = standalone == true or word == "是" or word == "否",
		}
	end
end
addSemanticRules({
	"已开启", "已启用", "已開啟", "已啟用", "开启", "启用", "開啟", "啟用",
	"确认", "确定", "確認", "確定", "接受", "成功", "是",
	"enabled", "on", "confirm", "confirmed", "accept", "accepted", "success", "yes",
}, GF.CHAT_STATUS_CONFIRM_COLOR_CODE)
addSemanticRules({
	"已关闭", "已禁用", "已關閉", "已停用", "关闭", "禁用", "關閉", "停用",
	"未开启", "未启用", "未開啟", "未啟用", "已清理", "已清除",
	"拒绝", "拒絕", "取消", "不可用", "失败", "失敗", "否",
	"disabled", "off", "decline", "declined", "reject", "rejected",
	"cancel", "cancelled", "canceled", "unavailable", "failed", "failure", "no",
	"not enabled", "not available", "cleared",
}, GF.CHAT_STATUS_FAILURE_COLOR_CODE)
-- 疑问或尚未确认不能被局部匹配成一次肯定操作。
addSemanticRules({ "是否", "能否", "否则", "否則", "未确认", "未確認",
	"未确定", "未確定", "无法确认", "無法確認", "not confirmed" }, false)

-- Lua 的 lower 不转换西里尔字母；明确列出文案大小写并按完整词匹配。
addSemanticRules({ "включено", "Включено", "подтверждено", "Подтверждено",
	"принято", "Принято", "успешно", "Успешно", "да", "Да" },
	GF.CHAT_STATUS_CONFIRM_COLOR_CODE, true)
addSemanticRules({ "отключено", "Отключено", "не включено", "Не включено",
	"отклонено", "Отклонено", "отменено", "Отменено", "недоступно", "Недоступно",
	"ошибка", "Ошибка", "нет", "Нет" }, GF.CHAT_STATUS_FAILURE_COLOR_CODE, true)
addSemanticRules({ "не подтверждено", "Не подтверждено" }, false, true)

local separators = { "，", "。", "；", "：", "（", "）", "「", "」", "【", "】", "«", "»", "—" }
local function isStandaloneValue(text, first, last)
	local before, after = text:sub(1, first - 1), text:sub(last + 1)
	local left = before == "" or before:match("[%s%p]$") ~= nil
	local right = after == "" or after:match("^[%s%p]") ~= nil
	for _, separator in ipairs(separators) do
		left = left or before:sub(-#separator) == separator
		right = right or after:sub(1, #separator) == separator
	end
	return left and right
end

local function colorPlainStatus(text, currentColor)
	local output, cursor, lower = {}, 1, text:lower()
	while cursor <= #text do
		local chosen, first, last
		for _, rule in ipairs(semanticRules) do
			local startAt = cursor
			while startAt <= #text do
				local a, b = (rule.english and lower or text):find(rule.word, startAt, true)
				if not a then break end
				local boundary = not rule.english or
					(not text:sub(a - 1, a - 1):match("[%w_]")
					and not text:sub(b + 1, b + 1):match("[%w_]"))
				if boundary and (not rule.standalone or isStandaloneValue(text, a, b)) then
					if not first or a < first or (a == first and b > last) then
						chosen, first, last = rule, a, b
					end
					break
				end
				startAt = b + 1
			end
		end
		if not chosen then
			output[#output + 1] = text:sub(cursor)
			break
		end
		output[#output + 1] = text:sub(cursor, first - 1)
		local matched = text:sub(first, last)
		output[#output + 1] = chosen.color
			and (chosen.color .. matched .. "|r" .. currentColor) or matched
		cursor = last + 1
	end
	return table.concat(output)
end

local function formatChatBody(body, semantic)
	local white = GF.CHAT_STATUS_BODY_COLOR_CODE
	local output, cursor, currentColor = { white }, 1, white
	while cursor <= #body do
		local pipe = body:find("|", cursor, true) or (#body + 1)
		local plain = body:sub(cursor, pipe - 1)
		-- 已染色的名字/标题/版本原样保留；独立状态词仍服从红绿语义。
		local plainState = plain:match("^%s*(.-)%s*$")
		local colorSemantic = semantic and currentColor == white
		if semantic and not colorSemantic then
			for _, rule in ipairs(semanticRules) do
				if plainState:lower() == rule.word then colorSemantic = true; break end
			end
		end
		output[#output + 1] = colorSemantic and colorPlainStatus(plain, currentColor) or plain
		if pipe > #body then break end
		local tail = body:sub(pipe)
		local color = tail:match("^|[cC]%x%x%x%x%x%x%x%x")
			or tail:match("^|[cC][nN][%w_]+:")
		local code = body:sub(pipe + 1, pipe + 1)
		local tokenEnd
		if color then
			currentColor = color
			output[#output + 1] = color
			tokenEnd = pipe + #color - 1
		elseif code == "r" or code == "R" then
			currentColor = white
			output[#output + 1] = body:sub(pipe, pipe + 1) .. white
			tokenEnd = pipe + 1
		elseif code == "H" or code == "T" or code == "A" or code == "K" then
			-- 不改写链接载荷/显示名、纹理/Atlas 参数或隐私字符串。
			local closing = "|" .. code:lower()
			local ending = body:find(closing, pipe + 2, true)
			if code == "H" and ending then ending = body:find(closing, ending + 2, true) end
			tokenEnd = ending and ending + 1 or #body
			output[#output + 1] = body:sub(pipe, tokenEnd)
		else
			tokenEnd = math.min(pipe + 1, #body)
			output[#output + 1] = body:sub(pipe, tokenEnd)
		end
		cursor = tokenEnd + 1
	end
	output[#output + 1] = GF.CHAT_RESET_COLOR_CODE
	return table.concat(output)
end

function GF.FormatWarningMessage(msg)
	if not isAccessibleNonSecretChatText(msg) or msg == "" then
		return nil
	end
	local prefix, body = splitAddonChatMessage(msg)
	return colorWrap(GF.CHAT_WARNING_PREFIX_COLOR_CODE, prefix)
		.. formatChatBody(body, true)
end

function GF.NormalizeTopNoticeMessage(msg)
	local ok, text = pcall(function()
		if msg == nil then
			return nil
		end
		local normalized = tostring(msg)
		if type(normalized) ~= "string" or normalized == "" then
			return nil
		end
		-- Toast 文字由 FontString 的默认金色统一着色，不能保留调用方的
		-- 内联颜色，也不能把旧聊天格式中的插件标题带到屏幕顶部。
		normalized = normalized:gsub("|[cC]%x%x%x%x%x%x%x%x", "")
		normalized = normalized:gsub("|[cC][nN][%w_]+:", "")
		normalized = normalized:gsub("|[rR]", "")
		for _, prefix in ipairs(ADDON_CHAT_PREFIXES) do
			if normalized:sub(1, #prefix) == prefix then
				normalized = normalized:sub(#prefix + 1)
				break
			end
		end
		local localePrefix = getAddonChatPrefix()
		if normalized:sub(1, #localePrefix) == localePrefix then
			normalized = normalized:sub(#localePrefix + 1)
		end
		local trimmed = normalized:match("^%s*(.-)%s*$") or ""
		return trimmed ~= "" and trimmed or nil
	end)
	if not ok then
		return nil
	end
	return text
end

function GF.ShowWarningMessage(msg, frame)
	local nativeErrorFrame = rawget(_G, "UIErrorsFrame")
	if frame == nil or (nativeErrorFrame and frame == nativeErrorFrame) then
		local text = GF.NormalizeTopNoticeMessage(msg)
		if not text then
			return false
		end
		if type(GF.ShowTopNotice) == "function" then
			return GF.ShowTopNotice(text, { source = "warning" }) == true
		end
		-- 正常加载顺序中 TopNoticeToast 已存在；若 UI 模块未能建立，
		-- 退回聊天框而不是重新借用 Blizzard 的 UIErrorsFrame。
		local fallbackFrame = rawget(_G, "DEFAULT_CHAT_FRAME")
		if fallbackFrame and fallbackFrame.AddMessage then
			fallbackFrame:AddMessage(GF.FormatWarningMessage(msg)
				or GF.FormatWarningMessage(text), 1, 1, 1, 1)
			return true
		end
		return false
	end

	local text = GF.FormatWarningMessage(msg)
	if not text then
		return false
	end
	if frame and frame.AddMessage then
		frame:AddMessage(text, 1, 1, 1, 1)
		return true
	end
	return false
end
function GF.FormatStatusMessage(msg, opts)
	if not isAccessibleNonSecretChatText(msg) or msg == "" then
		return nil
	end
	opts = opts or {}
	local prefix, body = splitAddonChatMessage(msg)
	local bodyText = formatChatBody(body, opts.semantic ~= false)
	return colorWrap(GF.CHAT_STATUS_PREFIX_COLOR_CODE, prefix) .. bodyText
end

function GF.ShowStatusMessage(msg, opts)
	if not isAccessibleNonSecretChatText(msg) then
		return
	end
	local ok, text = pcall(GF.FormatStatusMessage, msg, opts)
	if not ok or not isAccessibleNonSecretChatText(text) then
		return
	end
	opts = opts or {}
	local frame = opts.frame or DEFAULT_CHAT_FRAME
	if frame and frame.AddMessage then
		local color = GF.STATUS_MESSAGE_COLOR or { 1, 1, 1, 1 }
		frame:AddMessage(text, color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
	end
end
