local _, GF = ...

-- 聊天消息颜色、格式化与输出。

GF.CHAT_RESET_COLOR_CODE = "|r"
GF.CHAT_ADDON_PREFIX_COLOR_CODE = "|cff34ff99"
GF.CHAT_WARNING_PREFIX_COLOR_CODE = GF.CHAT_ADDON_PREFIX_COLOR_CODE
GF.CHAT_WARNING_BODY_COLOR_CODE = "|cffff80ff"
GF.CHAT_STATUS_PREFIX_COLOR_CODE = GF.CHAT_ADDON_PREFIX_COLOR_CODE
GF.CHAT_STATUS_BODY_COLOR_CODE = "|cffffffff"
GF.CHAT_STATUS_HIGHLIGHT_COLOR_CODE = "|cffffd200"
GF.CHAT_STATUS_CONFIRM_COLOR_CODE = "|cff00ff00"
GF.CHAT_STATUS_FAILURE_COLOR_CODE = "|cffff4040"
GF.WARNING_COLOR = { 1, 0.5, 1, 1 }
GF.STATUS_MESSAGE_COLOR = { 1, 1, 1, 1 }

local ADDON_CHAT_PREFIXES = {
	"队伍查找器：",
	"隊伍查找器：",
	"队伍查找器:",
	"隊伍查找器:",
	"GroupFinder:",
}

local function getAddonChatPrefix()
	local addonName = (GF.L and GF.L.ADDON_NAME) or "GroupFinder"
	return addonName == "队伍查找器" and (addonName .. "：") or (addonName .. ":")
end

local function splitAddonChatMessage(msg)
	msg = tostring(msg or "")
	for _, prefix in ipairs(ADDON_CHAT_PREFIXES) do
		if msg:sub(1, #prefix) == prefix then
			return prefix, msg:sub(#prefix + 1)
		end
	end
	local prefix = getAddonChatPrefix()
	local separator = prefix == "GroupFinder:" and " " or ""
	return prefix, separator .. msg
end

local function colorWrap(colorCode, text)
	return (colorCode or "") .. tostring(text or "") .. (GF.CHAT_RESET_COLOR_CODE or "|r")
end

local function escapePattern(text)
	return (tostring(text or ""):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local STATUS_SEMANTIC_PHRASES = {
	{ "已开启", GF.CHAT_STATUS_CONFIRM_COLOR_CODE },
	{ "已启用", GF.CHAT_STATUS_CONFIRM_COLOR_CODE },
	{ "确认", GF.CHAT_STATUS_CONFIRM_COLOR_CODE },
	{ "成功", GF.CHAT_STATUS_CONFIRM_COLOR_CODE },
	{ "是", GF.CHAT_STATUS_CONFIRM_COLOR_CODE },
	{ "已关闭", GF.CHAT_STATUS_FAILURE_COLOR_CODE },
	{ "已禁用", GF.CHAT_STATUS_FAILURE_COLOR_CODE },
	{ "不可用", GF.CHAT_STATUS_FAILURE_COLOR_CODE },
	{ "失败", GF.CHAT_STATUS_FAILURE_COLOR_CODE },
	{ "否", GF.CHAT_STATUS_FAILURE_COLOR_CODE },
}

local STATUS_SEMANTIC_WORDS = {
	{ "enabled", GF.CHAT_STATUS_CONFIRM_COLOR_CODE },
	{ "on", GF.CHAT_STATUS_CONFIRM_COLOR_CODE },
	{ "confirm", GF.CHAT_STATUS_CONFIRM_COLOR_CODE },
	{ "confirmed", GF.CHAT_STATUS_CONFIRM_COLOR_CODE },
	{ "success", GF.CHAT_STATUS_CONFIRM_COLOR_CODE },
	{ "yes", GF.CHAT_STATUS_CONFIRM_COLOR_CODE },
	{ "disabled", GF.CHAT_STATUS_FAILURE_COLOR_CODE },
	{ "off", GF.CHAT_STATUS_FAILURE_COLOR_CODE },
	{ "unavailable", GF.CHAT_STATUS_FAILURE_COLOR_CODE },
	{ "failed", GF.CHAT_STATUS_FAILURE_COLOR_CODE },
	{ "failure", GF.CHAT_STATUS_FAILURE_COLOR_CODE },
	{ "no", GF.CHAT_STATUS_FAILURE_COLOR_CODE },
}

local function colorStatusSemantics(body)
	body = tostring(body or "")
	if body:find("|c", 1, true) or body:find("|r", 1, true) then
		return colorWrap(GF.CHAT_STATUS_BODY_COLOR_CODE, body)
	end
	local bodyColor = GF.CHAT_STATUS_BODY_COLOR_CODE or ""
	local resetToBody = (GF.CHAT_RESET_COLOR_CODE or "|r") .. bodyColor
	for _, rule in ipairs(STATUS_SEMANTIC_PHRASES) do
		local phrase, colorCode = rule[1], rule[2]
		body = body:gsub(escapePattern(phrase), (colorCode or "") .. phrase .. resetToBody)
	end
	for _, rule in ipairs(STATUS_SEMANTIC_WORDS) do
		local word, colorCode = rule[1], rule[2]
		local function replace(match)
			return (colorCode or "") .. match .. resetToBody
		end
		local pattern = "%f[%a]" .. word .. "%f[%A]"
		body = body:gsub(pattern, replace)
		local capitalized = word:sub(1, 1):upper() .. word:sub(2)
		body = body:gsub("%f[%a]" .. capitalized .. "%f[%A]", replace)
	end
	return bodyColor .. body .. (GF.CHAT_RESET_COLOR_CODE or "|r")
end

function GF.FormatWarningMessage(msg)
	if not msg or msg == "" then
		return nil
	end
	local prefix, body = splitAddonChatMessage(msg)
	return colorWrap(GF.CHAT_WARNING_PREFIX_COLOR_CODE, prefix)
		.. colorWrap(GF.CHAT_WARNING_BODY_COLOR_CODE, body)
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
			fallbackFrame:AddMessage(text, 1, 0.82, 0, 1)
			return true
		end
		return false
	end

	local text = GF.FormatWarningMessage(msg)
	if not text then
		return false
	end
	if frame and frame.AddMessage then
		local color = GF.WARNING_COLOR or { 1, 0.82, 0, 1 }
		frame:AddMessage(text, color[1] or 1, color[2] or 0.5, color[3] or 1, color[4] or 1)
		return true
	end
	return false
end
function GF.FormatStatusMessage(msg, opts)
	if not msg or msg == "" then
		return nil
	end
	opts = opts or {}
	local prefix, body = splitAddonChatMessage(msg)
	local bodyText = opts.semantic and colorStatusSemantics(body) or colorWrap(GF.CHAT_STATUS_BODY_COLOR_CODE, body)
	return colorWrap(GF.CHAT_STATUS_PREFIX_COLOR_CODE, prefix) .. bodyText
end

function GF.ShowStatusMessage(msg, opts)
	local text = GF.FormatStatusMessage(msg, opts)
	if not text then
		return
	end
	opts = opts or {}
	local frame = opts.frame or DEFAULT_CHAT_FRAME
	if frame and frame.AddMessage then
		local color = GF.STATUS_MESSAGE_COLOR or { 1, 1, 1, 1 }
		frame:AddMessage(text, color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
	end
end
