-------------------------------------------------------------
-- StatDiminishing
-- 一、属性递减模块:角色面板悬停属性时显示当前的递减档位与惩罚
-- 二、速度模块:角色面板补一行移动速度,外加屏幕上的速度悬浮窗
-- 三、设置面板:速度模块那套开关(走/sd config或整合包入口)
-------------------------------------------------------------

-------------------------------------------------------------
-- 默认设置
-- 整合包要改默认值,改这一块就够了,别的地方不用动
-------------------------------------------------------------
local DEFAULTS = {
	enabled = true,				-- 插件总开关
	paneSpeed = true,			-- 角色面板"强化属性"里显示移动速度
	speedModule = false,		-- 速度模块总开关
	hud = {
		show = true,			-- 显示速度悬浮窗
		move = true,			-- 悬浮窗里显示移动速度
		glide = true,			-- 悬浮窗里显示驭空术速度(只在滑翔时顶掉移动速度那行)
		scale = 1.2,			-- 整体缩放
		r = 1, g = 0.5, b = 0,	-- 文字颜色
		outline = true,			-- 文字描边
		point = "CENTER",		-- 位置:锚点、相对锚点、偏移
		relPoint = "CENTER",
		x = 0,
		y = -170,
		locked = true,			-- 锁定位置(解锁后可直接拖)
	},
}

-------------------------------------------------------------
-- 公共:本地化、配置读写
-------------------------------------------------------------
local locale = GetLocale()
local L
if locale == "zhCN" then
	L = {
		pctLabel0   = "0% 递减",
		pctLabelFmt = "-%d%% 递减",
		drBracket   = "递减档位",
		cmdOn       = "|cff00ff00StatDiminishing: 已开启|r",
		cmdOff      = "|cffff0000StatDiminishing: 已关闭|r",
		cmdOnNow    = "StatDiminishing: 当前已开启",
		cmdOffNow   = "StatDiminishing: 当前已关闭",
		cmdUsage    = "用法:/sd切换开关|on开|off关|status查状态|config开速度模块设置",
		move        = "移动速度",
		glide       = "驭空术速度",
		title       = "速度模块设置",
		speedOn     = "启用速度模块",
		sectionPane = "角色面板",
		paneSpeed   = "在强化属性里显示移动速度",
		sectionHud  = "速度悬浮窗",
		hudShow     = "显示速度悬浮窗",
		hudMove     = "显示移动速度",
		hudGlide    = "显示驭空术速度",
		hudScale    = "整体缩放",
		hudColor    = "文字颜色",
		hudOutline  = "文字描边",
		hudLocked   = "锁定位置(取消勾选后就能直接拖)",
		hudReset    = "重置位置",
		close       = "关闭",
	}
elseif locale == "zhTW" then
	L = {
		pctLabel0   = "0% 遞減",
		pctLabelFmt = "-%d%% 遞減",
		drBracket   = "遞減檔位",
		cmdOn       = "|cff00ff00StatDiminishing: 已開啟|r",
		cmdOff      = "|cffff0000StatDiminishing: 已關閉|r",
		cmdOnNow    = "StatDiminishing: 目前為開啟",
		cmdOffNow   = "StatDiminishing: 目前為關閉",
		cmdUsage    = "用法:/sd切換開關|on開|off關|status查狀態|config開速度模組設定",
		move        = "移動速度",
		glide       = "飛龍騎術速度",
		title       = "速度模組設定",
		speedOn     = "啟用速度模組",
		sectionPane = "角色資訊",
		paneSpeed   = "在強化屬性裡顯示移動速度",
		sectionHud  = "速度浮動視窗",
		hudShow     = "顯示速度浮動視窗",
		hudMove     = "顯示移動速度",
		hudGlide    = "顯示飛龍騎術速度",
		hudScale    = "整體縮放",
		hudColor    = "文字顏色",
		hudOutline  = "文字描邊",
		hudLocked   = "鎖定位置(取消勾選後就能直接拖)",
		hudReset    = "重設位置",
		close       = "關閉",
	}
else
	L = {
		pctLabel0   = "0% DR",
		pctLabelFmt = "-%d%% DR",
		drBracket   = "DR Bracket",
		cmdOn       = "|cff00ff00StatDiminishing: enabled|r",
		cmdOff      = "|cffff0000StatDiminishing: disabled|r",
		cmdOnNow    = "StatDiminishing: currently enabled",
		cmdOffNow   = "StatDiminishing: currently disabled",
		cmdUsage    = "Usage: /sd toggle | on | off | status | config",
		move        = "Movement Speed",
		glide       = "Skyriding Speed",
		title       = "Speed Module",
		speedOn     = "Enable speed module",
		sectionPane = "Character info",
		paneSpeed   = "Show movement speed in Enhancements",
		sectionHud  = "Speed window",
		hudShow     = "Show speed window",
		hudMove     = "Show movement speed",
		hudGlide    = "Show skyriding speed",
		hudScale    = "Scale",
		hudColor    = "Text color",
		hudOutline  = "Text outline",
		hudLocked   = "Lock position (uncheck to drag)",
		hudReset    = "Reset position",
		close       = "Close",
	}
end


StatDiminishingDB = type(StatDiminishingDB) == "table" and StatDiminishingDB or {}

local function GetOpt(key)
	local value = StatDiminishingDB[key]
	if value == nil then return DEFAULTS[key] end
	return value
end

local function SetOpt(key, value)
	StatDiminishingDB[key] = value
end

local function Enabled()
	return GetOpt("enabled") and true or false
end

local function DB()
	return StatDiminishingDB
end

-- 速度模块插在角色面板那行的提示函数,定义在下面;
-- 属性递减模块要认得出它,别把"移动速度"当成"速度"那一行
local RowOnEnter

-------------------------------------------------------------
-- 一、属性递减模块
-------------------------------------------------------------
local CONV = {
	Haste   = { 2.923638162, 2.923638162, 2.923638162, 2.923638162, 2.923638162, 2.923638162, 2.923638162, 2.923638162, 2.923638162, 2.923638162, 2.923638162, 3.06982007, 3.216001978, 3.362183886, 3.508365794, 3.654547702, 3.80072961, 3.946911518, 4.093093426, 4.239275334, 4.283081179, 4.328767379, 4.37638382, 4.425982836, 4.477619303, 4.531350734, 4.587237394, 4.6453424, 4.705731852, 4.768474943, 4.833644101, 4.901315118, 4.971567301, 5.044483622, 5.120150876, 5.198659856, 5.280105527, 5.364587216, 5.452208807, 5.543078954, 5.637311296, 5.735024692, 5.836343461, 5.941397644, 6.050323267, 6.163262635, 6.280364625, 6.401785008, 6.527686779, 6.658240515, 6.793624739, 6.934026317, 7.079640869, 7.230673208, 7.387337794, 7.549859225, 7.718472748, 7.893424797, 8.074973567, 8.263389617, 8.458956505, 8.661971461, 8.8727461, 9.09160717, 9.31889735, 9.554976083, 9.800220469, 10.0550262, 10.31980856, 10.59500345, 10.69418334, 10.79429165, 10.89533707, 10.99732838, 11.10027443, 11.20418416, 11.30906659, 11.41493083, 11.52178606, 11.62964156, 12.99342144, 14.51712849, 16.21951696, 18.12154041, 20.24660954, 22.62088037, 25.27357619, 28.23734722, 31.5486725, 44 },
	Crit    = { 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.209357346, 3.362183886, 3.515010426, 3.667836966, 3.820663507, 3.973490047, 4.126316587, 4.279143127, 4.431969668, 4.477766688, 4.525529532, 4.575310357, 4.627163874, 4.681147453, 4.737321222, 4.795748184, 4.856494328, 4.919628754, 4.985223804, 5.053355196, 5.124102169, 5.197547633, 5.273778332, 5.352885007, 5.434962577, 5.520110324, 5.608432089, 5.70003648, 5.795037088, 5.893552718, 5.995707632, 6.1016318, 6.211461173, 6.325337961, 6.443410936, 6.565835744, 6.692775235, 6.824399815, 6.960887811, 7.102425863, 7.249209331, 7.401442727, 7.559340172, 7.723125876, 7.893034645, 8.069312419, 8.252216833, 8.442017821, 8.638998236, 8.843454528, 9.055697437, 9.276052741, 9.504862042, 9.742483593, 9.989293177, 10.24568504, 10.51207285, 10.78889076, 11.07659452, 11.18028258, 11.28494127, 11.39057967, 11.49720694, 11.60483236, 11.71346526, 11.82311507, 11.93379132, 12.04550361, 12.15826163, 13.58403151, 15.17699796, 16.95676773, 18.94524679, 21.16690997, 23.6491022, 26.42237511, 29.520863, 32.98270306, 46 },
	Mastery = { 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.209357346, 3.362183886, 3.515010426, 3.667836966, 3.820663507, 3.973490047, 4.126316587, 4.279143127, 4.431969668, 4.477766688, 4.525529532, 4.575310357, 4.627163874, 4.681147453, 4.737321222, 4.795748184, 4.856494328, 4.919628754, 4.985223804, 5.053355196, 5.124102169, 5.197547633, 5.273778332, 5.352885007, 5.434962577, 5.520110324, 5.608432089, 5.70003648, 5.795037088, 5.893552718, 5.995707632, 6.1016318, 6.211461173, 6.325337961, 6.443410936, 6.565835744, 6.692775235, 6.824399815, 6.960887811, 7.102425863, 7.249209331, 7.401442727, 7.559340172, 7.723125876, 7.893034645, 8.069312419, 8.252216833, 8.442017821, 8.638998236, 8.843454528, 9.055697437, 9.276052741, 9.504862042, 9.742483593, 9.989293177, 10.24568504, 10.51207285, 10.78889076, 11.07659452, 11.18028258, 11.28494127, 11.39057967, 11.49720694, 11.60483236, 11.71346526, 11.82311507, 11.93379132, 12.04550361, 12.15826163, 13.58403151, 15.17699796, 16.95676773, 18.94524679, 21.16690997, 23.6491022, 26.42237511, 29.520863, 32.98270306, 46 },
	Vers    = { 3.58810138, 3.58810138, 3.58810138, 3.58810138, 3.58810138, 3.58810138, 3.58810138, 3.58810138, 3.58810138, 3.58810138, 3.58810138, 3.767506449, 3.946911518, 4.126316587, 4.305721656, 4.485126725, 4.664531794, 4.843936863, 5.023341932, 5.202747001, 5.25650872, 5.312578146, 5.371016506, 5.431888026, 5.495260053, 5.561203174, 5.629791347, 5.701102037, 5.775216363, 5.852219248, 5.932199578, 6.015250372, 6.101468961, 6.190957172, 6.28382153, 6.38017346, 6.480129511, 6.583811583, 6.691347172, 6.802869625, 6.918518409, 7.038439394, 7.162785157, 7.29171529, 7.425396737, 7.564004143, 7.707720221, 7.856736146, 8.011251956, 8.171476996, 8.337630361, 8.509941389, 8.688650158, 8.874008028, 9.066278202, 9.265736322, 9.4726711, 9.687384978, 9.910194833, 10.14143271, 10.38144662, 10.63060134, 10.8892793, 11.15788153, 11.43682857, 11.72656156, 12.0275433, 12.34025943, 12.66521959, 13.00295878, 13.12467955, 13.24753975, 13.37155004, 13.4967212, 13.62306408, 13.75058965, 13.879309, 14.00923329, 14.1403738, 14.27274192, 15.94647177, 17.81647587, 19.90577082, 22.24007232, 24.8481117, 27.76198954, 31.01757078, 34.65492613, 38.71882534, 54 },
}

-- 三属性(吸血/闪避/速度)换算表,来自simc的item_scaling.inc
local CONV_TERT = {
	Leech     = { 4.584861654, 4.584861654, 4.584861654, 4.584861654, 4.584861654, 4.584861654, 4.584861654, 4.584861654, 4.584861654, 4.584861654, 4.584861654, 4.814104737, 5.04334782, 5.272590902, 5.501833985, 5.731077068, 5.96032015, 6.189563233, 6.418806316, 6.648049399, 6.716745909, 6.788391199, 6.863063502, 6.940844888, 7.021821412, 7.106083269, 7.193724963, 7.284845479, 7.37954847, 7.47794245, 7.580140996, 7.68626297, 7.79643274, 7.91078042, 8.029442126, 8.152560239, 8.280283682, 8.412768221, 8.550176769, 8.692679715, 8.84045527, 8.993689828, 9.152578349, 9.317324759, 9.488142379, 9.665254371, 9.848894204, 10.03930616, 10.23674585, 10.44148076, 10.65379087, 10.87396922, 11.10232257, 11.33917212, 11.58485418, 11.83972097, 12.10414141, 12.37850195, 12.66320749, 12.95868233, 13.26537115, 13.58374006, 13.91427773, 14.25749658, 14.613934, 14.98415366, 15.36874693, 15.76833435, 16.18356716, 16.61512895, 16.77066326, 16.92765353, 17.08611339, 17.24605659, 17.40749702, 17.5704487, 17.73492577, 17.90094251, 18.06851333, 18.23765278, 20.37633812, 22.76582191, 25.43551468, 28.41827584, 31.75081818, 35.47415968, 39.63412842, 44.2819266, 49.47476082, 69.00098495 },
	Avoidance = { 2.445259549, 2.445259549, 2.445259549, 2.445259549, 2.445259549, 2.445259549, 2.445259549, 2.445259549, 2.445259549, 2.445259549, 2.445259549, 2.567522526, 2.689785504, 2.812048481, 2.934311459, 3.056574436, 3.178837414, 3.301100391, 3.423363368, 3.545626346, 3.582264485, 3.620475306, 3.660300534, 3.70178394, 3.74497142, 3.789911077, 3.836653313, 3.885250922, 3.935759184, 3.988235973, 4.042741865, 4.099340251, 4.158097461, 4.219082891, 4.282369134, 4.348032127, 4.416151297, 4.486809718, 4.560094277, 4.636095848, 4.714909477, 4.796634575, 4.881375119, 4.969239871, 5.060342602, 5.154802331, 5.252743575, 5.354296618, 5.459597785, 5.56878974, 5.682021798, 5.799450249, 5.921238704, 6.047558463, 6.178588896, 6.314517852, 6.455542084, 6.601867705, 6.753710662, 6.911297244, 7.074864612, 7.244661363, 7.420948123, 7.603998176, 7.794098131, 7.991548617, 8.196665031, 8.409778322, 8.631235818, 8.861402106, 8.94435374, 9.028081885, 9.112593809, 9.19789685, 9.283998413, 9.370905974, 9.458627076, 9.547169336, 9.636540441, 9.726748149, 10.86738033, 12.14177169, 13.56560783, 15.15641378, 16.9337697, 18.91955183, 21.13820182, 23.61702752, 26.3865391, 36.80052531 },
	Speed     = { 0.764143609, 0.764143609, 0.764143609, 0.764143609, 0.764143609, 0.764143609, 0.764143609, 0.764143609, 0.764143609, 0.764143609, 0.764143609, 0.802350789, 0.84055797, 0.87876515, 0.916972331, 0.955179511, 0.993386692, 1.031593872, 1.069801053, 1.108008233, 1.119457652, 1.131398533, 1.143843917, 1.156807481, 1.170303569, 1.184347211, 1.19895416, 1.214140913, 1.229924745, 1.246323742, 1.263356833, 1.281043828, 1.299405457, 1.318463403, 1.338240354, 1.35876004, 1.38004728, 1.402128037, 1.425029461, 1.448779953, 1.473409212, 1.498948305, 1.525429725, 1.55288746, 1.581357063, 1.610875728, 1.641482367, 1.673217693, 1.706124308, 1.740246794, 1.775631812, 1.812328203, 1.850387095, 1.88986202, 1.93080903, 1.973286829, 2.017356901, 2.063083658, 2.110534582, 2.159780389, 2.210895191, 2.263956676, 2.319046288, 2.37624943, 2.435655666, 2.497358943, 2.561457822, 2.628055726, 2.697261193, 2.769188158, 2.795110544, 2.821275589, 2.847685565, 2.874342766, 2.901249504, 2.928408117, 2.955820961, 2.983490418, 3.011418888, 3.039608797, 3.396056354, 3.794303652, 4.239252446, 4.736379307, 5.29180303, 5.912359947, 6.605688069, 7.3803211, 8.24579347, 11.50016416 },
}

-- 三属性递减档位:10%以内不扣,往上按20%/40%/60%扣,有效值49%封顶
local BRACKETS_TERT = {
	{ size = 10,   penalty = 0 },
	{ size = 5,    penalty = 0.2 },
	{ size = 5,    penalty = 0.4 },
	{ size = 80,   penalty = 0.6 },
	{ size = 99999, penalty = 1.0 },
}

local BRACKETS = {
	{ size = 30,   penalty = 0 },
	{ size = 10,   penalty = 0.1 },
	{ size = 10,   penalty = 0.2 },
	{ size = 10,   penalty = 0.3 },
	{ size = 20,   penalty = 0.4 },
	{ size = 120,  penalty = 0.5 },
	{ size = 99999, penalty = 1.0 },
}

local STATS = {
	[CR_CRIT_SPELL]              = { conv = "Crit",      tert = false, fmt = function() return format(PAPERDOLLFRAME_TOOLTIP_FORMAT, STAT_CRITICAL_STRIKE) end },
	[CR_HASTE_SPELL]             = { conv = "Haste",     tert = false, fmt = function() return format(PAPERDOLLFRAME_TOOLTIP_FORMAT, STAT_HASTE) end },
	[CR_MASTERY]                 = { conv = "Mastery",   tert = false, fmt = function() return format(PAPERDOLLFRAME_TOOLTIP_FORMAT, STAT_MASTERY) end },
	[CR_VERSATILITY_DAMAGE_DONE] = { conv = "Vers",      tert = false, fmt = function() return format(PAPERDOLLFRAME_TOOLTIP_FORMAT, STAT_VERSATILITY) end },
	[CR_LIFESTEAL]               = { conv = "Leech",     tert = true,  fmt = function() return format(PAPERDOLLFRAME_TOOLTIP_FORMAT, STAT_LIFESTEAL) end },
	[CR_AVOIDANCE]               = { conv = "Avoidance", tert = true,  fmt = function() return format(PAPERDOLLFRAME_TOOLTIP_FORMAT, STAT_AVOIDANCE) end },
	[CR_SPEED]                   = { conv = "Speed",     tert = true,  fmt = function() return format(PAPERDOLLFRAME_TOOLTIP_FORMAT, STAT_SPEED) end },
}

local STAT_ORDER = {
	CR_CRIT_SPELL,
	CR_HASTE_SPELL,
	CR_MASTERY,
	CR_VERSATILITY_DAMAGE_DONE,
	CR_LIFESTEAL,
	CR_AVOIDANCE,
	CR_SPEED,
}

local STAT_NAMES = {}
for _, statId in ipairs(STAT_ORDER) do
	local info = STATS[statId]
	if info and info.fmt then
		local ok, name = pcall(info.fmt)
		if ok then
			STAT_NAMES[statId] = name
		end
	end
end

local progressBar = nil
local progressBarBG = nil
local barShownTooltips = {}

local function GetProgressBar()
	if not progressBar then
		progressBar = CreateFrame("StatusBar", nil, UIParent)
		progressBar:SetHeight(4)
		progressBar:SetWidth(100)
		progressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
		progressBarBG = progressBar:CreateTexture(nil, "BACKGROUND")
		progressBarBG:SetTexture("Interface\\Buttons\\WHITE8X8")
		progressBarBG:SetColorTexture(0.5, 0.5, 0.5, 0.8)
		progressBarBG:SetHeight(2)
		progressBarBG:SetPoint("TOPLEFT", progressBar, "TOPLEFT", 0, -1)
		progressBarBG:SetPoint("TOPRIGHT", progressBar, "TOPRIGHT", 0, -1)
		progressBar:Hide()
	end
	return progressBar
end

-- 惩罚分档上色:0纯绿,15%以下黄绿,25%以下黄,再往上橙红
local function PenaltyColor(penalty)
	if penalty <= 0 then return 0, 1 end
	if penalty < 0.15 then return 0.5, 1 end
	if penalty < 0.25 then return 1, 1 end
	return 1, 0.3
end

-- 就认"递减档位"这一行,顺便当"这提示处理过了"的标记
local function FindDrLine(tooltip)
	for i = 1, tooltip:NumLines() do
		local left = _G["GameTooltipTextLeft"..i]
		local text = left and left:GetText()
		-- 战斗/副本里tooltip的文字可能是secret,直接比会报错(attempt to compare a secret string value)
		if text and not issecretvalue(text) and text == L.drBracket then return i end
	end
end

local function ShowInfo(tooltip, bracketRating, bracketMax, pctLabel, bracketPenalty)
	local r, g = PenaltyColor(bracketPenalty)
	local valueText = bracketRating .. " / " .. bracketMax .. " (" .. pctLabel .. ")"

	local drLineIndex = FindDrLine(tooltip)
	if not drLineIndex then
		tooltip:AddDoubleLine(L.drBracket, valueText, r, g, 0, r, g, 0)
		tooltip:AddLine(" ")
		drLineIndex = tooltip:NumLines() - 1
	else
		-- 属性变了就原地改数值,不重复加行,也不把玩家正在看的提示关掉
		local left = _G["GameTooltipTextLeft"..drLineIndex]
		local right = _G["GameTooltipTextRight"..drLineIndex]
		if left then left:SetTextColor(r, g, 0) end
		if right then
			right:SetText(valueText)
			right:SetTextColor(r, g, 0)
		end
	end

	local blankLine = _G["GameTooltipTextLeft"..(drLineIndex + 1)]

	local ratio = 0
	if bracketMax and bracketMax > 0 then
		ratio = math.max(0, math.min(1, bracketRating / bracketMax))
	end

	local bar = GetProgressBar()
	bar:SetFrameStrata(tooltip:GetFrameStrata())
	bar:SetFrameLevel(tooltip:GetFrameLevel() + 1)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(ratio)
	bar:SetStatusBarColor(r, g, 0)
	bar:SetHeight(4)

	if blankLine then
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", blankLine, "TOPLEFT", 0, -5)
	end

	if not barShownTooltips[tooltip] then
		barShownTooltips[tooltip] = true
		bar:SetWidth(100)
		C_Timer.After(0, function()
			if tooltip:IsShown() then
				local w = tooltip:GetWidth()
				if w and w > 50 then
					bar:SetWidth(w - 24)
				end
				bar:Show()
				if progressBarBG then progressBarBG:Show() end
			end
		end)
	else
		local w = tooltip:GetWidth()
		if w and w > 50 then
			bar:SetWidth(w - 24)
		end
		if tooltip:IsShown() then bar:Show() end
	end
end

GameTooltip:HookScript("OnHide", function()
	barShownTooltips[GameTooltip] = nil
	if progressBar then progressBar:Hide() end
end)
local function GetTrueRating(statId)
	local rating = GetCombatRating(statId)
	if not rating or (issecretvalue and issecretvalue(rating)) then
		return
	end
	local level = math.max(UnitLevel("player"), 1)
	local info = STATS[statId]
	local convTable = info.tert and CONV_TERT or CONV
	local brackets = info.tert and BRACKETS_TERT or BRACKETS
	-- 表是按等级索引的,这级没有就直接不显示,拿别的等级凑只会算错
	local conv = convTable[info.conv][level]
	if not conv then return end

	local percent = rating / conv
	local bracketRating, bracketMax, bracketPenalty = 0, 0, 0
	local trueRating = 0

	for _, b in ipairs(brackets) do
		if percent < b.size then
			bracketRating = math.floor(0.5 + percent * conv)
			bracketMax = math.floor(0.5 + b.size * conv)
			bracketPenalty = b.penalty
			trueRating = trueRating + percent * conv * (1 - b.penalty)
			break
		else
			trueRating = trueRating + b.size * conv * (1 - b.penalty)
			percent = percent - b.size
		end
	end

	trueRating = math.floor(0.5 + 100 * trueRating) / 100
	local pctLabel = bracketPenalty > 0 and string.format(L.pctLabelFmt, bracketPenalty * 100) or L.pctLabel0

	return trueRating, bracketRating, bracketMax, pctLabel, bracketPenalty
end

local function IsBadSource(tooltip)
	local owner = tooltip:GetOwner()
	if not owner then return false end
	local name = owner.GetName and owner:GetName() or ""
	return name:find("Merchant") or name:find("Profession") or name:find("Container") or name:find("Bank")
end

local function IsStatRow(tooltip)
	local owner = tooltip:GetOwner()
	if not owner then return false end
	-- 速度模块自己插的"移动速度"那行不算属性行
	if RowOnEnter and owner.onEnterFunc == RowOnEnter then return false end
	-- 角色面板的属性行/专精行才有这些字段,普通法术/技能tooltip的owner没有
	return owner.onEnterFunc ~= nil or owner.tooltip ~= nil or owner.tooltip2 ~= nil
end

-- 认第一行是哪个属性;skipId跳过另一条路管的那项(精通走OnTooltipSetSpell,得单独处理)
local function FindStatId(skipId)
	local text = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
	if not text or issecretvalue(text) then return end

	text = text:gsub("^%s+", "")

	for _, statId in ipairs(STAT_ORDER) do
		local statName = STAT_NAMES[statId]
		if statId ~= skipId and statName then
			local s = text:find(statName, 1, true)
			if s and s <= 11 then return statId end
		end
	end
end

-- 重算并写回去;拿不到数(secret)时GetTrueRating返回nil,那就啥也不干
local function ApplyStat(tooltip, statId)
	local trueRating, bracketRating, bracketMax, pctLabel, bracketPenalty = GetTrueRating(statId)
	if trueRating then
		ShowInfo(tooltip, bracketRating, bracketMax, pctLabel, bracketPenalty)
	end
end

local function ProcessTooltip(tooltip, skipId)
	if not Enabled() then return end
	if tooltip ~= GameTooltip then return end
	if IsBadSource(tooltip) or not IsStatRow(tooltip) then return end

	local statId = FindStatId(skipId)
	if statId then
		ApplyStat(tooltip, statId)
	end
end

-- 精通是OnTooltipSetSpell触发的,别的属性是OnShow
GameTooltip:HookScript("OnShow", function(tooltip) ProcessTooltip(tooltip, CR_MASTERY) end)
if TooltipDataProcessor and Enum.TooltipDataType and Enum.TooltipDataType.Spell then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip)
		if tooltip == GameTooltip then ProcessTooltip(tooltip, nil) end
	end)
end

-- 属性变了就刷新那一行;只碰自己加过行的提示,不认识的别动
local function RefreshDrInfo()
	if not Enabled() then
		if progressBar then progressBar:Hide() end
		return
	end
	if not GameTooltip:IsShown() then return end
	if not barShownTooltips[GameTooltip] then return end -- 没给这提示加过行,别管
	if not FindDrLine(GameTooltip) then return end

	local statId = FindStatId(nil)
	if statId then
		ApplyStat(GameTooltip, statId)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("COMBAT_RATING_UPDATE")
events:RegisterEvent("UNIT_STATS")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event, unit)
	if event == "UNIT_STATS" and unit ~= "player" then return end
	RefreshDrInfo()
end)

-- 给整合包用的总开关,不装整合包就用/sd
function StatDiminishing_SetEnabled(on)
	SetOpt("enabled", on and true or false)
	if not Enabled() then
		if progressBar then progressBar:Hide() end
	elseif GameTooltip:IsShown() then
		RefreshDrInfo()
	end
	-- 速度那部分在后面的文件里,没加载就跳过
	if StatDiminishing_RefreshFeatures then StatDiminishing_RefreshFeatures() end
end

SLASH_STATDIMINISHING1 = "/sd"
SlashCmdList["STATDIMINISHING"] = function(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
	if msg == "" then
		StatDiminishing_SetEnabled(not Enabled())
		print(Enabled() and L.cmdOn or L.cmdOff)
	elseif msg == "on" then
		StatDiminishing_SetEnabled(true)
		print(L.cmdOn)
	elseif msg == "off" then
		StatDiminishing_SetEnabled(false)
		print(L.cmdOff)
	elseif msg == "status" then
		print(Enabled() and L.cmdOnNow or L.cmdOffNow)
	elseif msg == "config" or msg == "设置" then
		if StatDiminishing_OpenConfig then StatDiminishing_OpenConfig() end
	else
		print(L.cmdUsage)
	end
end


-------------------------------------------------------------
-- 二、速度模块
-- 角色面板"强化属性"最后补一行移动速度,外加屏幕上的速度悬浮窗
-- 12.x战斗和副本里GetUnitSpeed返回的是secret值,不能拿来做运算也不能拼接,
-- 所以数字一律交给AbbreviateNumbers转成字符串,再原样塞给FontString(思路来自NGA的飞飞125)
-------------------------------------------------------------
local BASE_SPEED = BASE_MOVEMENT_SPEED or 7

-- AbbreviateNumbers的档位:7码/秒当100%,保留一位小数
local SPEED_PERCENT_1 = {
	breakpointData = {
		{ breakpoint = 0, abbreviation = "%", significandDivisor = 0.006999, fractionDivisor = 10, abbreviationIsGlobal = false },
	},
}
-- 驭空术给的本来就是百分比数字(65~100),不用换算
local SPEED_PERCENT_0 = {
	breakpointData = {
		{ breakpoint = 0, abbreviation = "%", significandDivisor = 1, fractionDivisor = 1, abbreviationIsGlobal = false },
	},
}

-- 描边只有细(1像素)和粗(2像素)两档,对应暴雪自己的OUTLINE和THICKOUTLINE
local OUTLINE_FLAGS = { "OUTLINE", "THICKOUTLINE" }

local HUD_WIDTH, HUD_HEIGHT = 150, 26

local HUD_BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

function StatDiminishing_GetSpeedOpt(key)
	local hud = DB().hud
	if type(hud) ~= "table" then return DEFAULTS.hud[key] end
	local value = hud[key]
	if value == nil then return DEFAULTS.hud[key] end
	return value
end

function StatDiminishing_SetSpeedOpt(key, value)
	local db = DB()
	if type(db.hud) ~= "table" then db.hud = {} end
	db.hud[key] = value
end

local function IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

-- 速度模块的总开关,默认值看上面的DEFAULTS
function StatDiminishing_IsSpeedOn()
	return GetOpt("speedModule") and true or false
end

function StatDiminishing_SetSpeedOn(on)
	SetOpt("speedModule", on and true or false)
	StatDiminishing_RefreshFeatures()
end

-- 模块开关之外,插件本身的总开关(/sd或163UI那行)也算数
function StatDiminishing_IsSpeedRunning()
	return StatDiminishing_IsSpeedOn() and Enabled()
end

-- secret的值只能原样转成字符串,不能参与运算;普通值就自己算
local function SpeedText(value, opts, toPercent)
	if IsSecret(value) then
		if AbbreviateNumbers then return AbbreviateNumbers(value, opts) end
		return "--"
	end
	if type(value) ~= "number" then return "--" end
	if toPercent then return format("%.1f%%", value / BASE_SPEED * 100) end
	return format("%.0f%%", value)
end

-------------------------------------------------------------
-- 速度悬浮窗
-- 外面这层只管拖动和位置,缩放挂在里面的content上,
-- 这样放大缩小时是围着框体中心来的,跟拖动位置无关
-------------------------------------------------------------
local hud = CreateFrame("Frame", "StatDiminishingSpeedHud", UIParent)
hud:SetSize(HUD_WIDTH, HUD_HEIGHT)
hud:SetFrameStrata("MEDIUM")
hud:SetClampedToScreen(true)
hud:SetMovable(true)
hud:Hide()

local content = CreateFrame("Frame", nil, hud, "BackdropTemplate")
content:SetSize(HUD_WIDTH, HUD_HEIGHT)
content:SetPoint("CENTER", hud, "CENTER", 0, 0)

local FONT_PATH, FONT_SIZE = GameFontHighlight:GetFont()
FONT_PATH = FONT_PATH or STANDARD_TEXT_FONT
FONT_SIZE = FONT_SIZE or 12

-- 三格空格的宽度,量一次就够
local measure = content:CreateFontString(nil, "BACKGROUND")
measure:SetFont(FONT_PATH, FONT_SIZE, "")
measure:SetText("   ")
local TEXT_GAP = measure:GetStringWidth()

-- 带描边的字串,宽度里会把描边那几像素算进去,居中挂就会把整串字往左压一点,
-- 结果描边只出现在左边,看着像投影;补偏移不能补满(补满就换右边冒出来),
-- 取宽度差的四分之一正好落在中间
measure:SetText("移动")
measure:SetFont(FONT_PATH, FONT_SIZE, "")
local plainWidth = measure:GetStringWidth()
measure:SetFont(FONT_PATH, FONT_SIZE, "OUTLINE")
local OUTLINE_SHIFT = (measure:GetStringWidth() - plainWidth) / 4
if OUTLINE_SHIFT <= 0 then OUTLINE_SHIFT = 0.4 end
measure:SetText("")

-- 描边走暴雪自己的OUTLINE:同一串字、同一个字号再画一份压在下层,
-- 它的填充被正本盖住,只漏出暴雪渲染的那圈描边;锚点取正文中心所以不会偏
local function NewText(previous)
	local text = content:CreateFontString(nil, "OVERLAY")
	if previous then
		text:SetPoint("LEFT", previous, "RIGHT", TEXT_GAP, 0)
	else
		text:SetPoint("LEFT", content, "LEFT", 6, 0)
	end
	text:SetFont(FONT_PATH, FONT_SIZE, "")
	local outline = content:CreateFontString(nil, "BORDER")
	outline:SetPoint("CENTER", text, "CENTER", 0, 0)
	outline:SetFont(FONT_PATH, FONT_SIZE, "OUTLINE")
	text.outline = outline
	return text
end

local moveLabel = NewText()
local moveValue = NewText(moveLabel)
local glideLabel = NewText()
local glideValue = NewText(glideLabel)
local allTexts = { moveLabel, moveValue, glideLabel, glideValue }
local outlineOn = true

-- 只改颜色,不动别的(色板拖动时只走这一支)
local function ApplyColor()
	local r, g, b = StatDiminishing_GetSpeedOpt("r"), StatDiminishing_GetSpeedOpt("g"), StatDiminishing_GetSpeedOpt("b")
	for _, text in ipairs(allTexts) do
		text:SetTextColor(r, g, b)
		text.outline:SetTextColor(r, g, b)
	end
end

-- 描边开关和描边层的偏移(字体的OUTLINE标志在NewText里设过一次就不动了)
local function ApplyStyle()
	local shift = tonumber(StatDiminishing_GetSpeedOpt("outlineShift")) or OUTLINE_SHIFT
	outlineOn = StatDiminishing_GetSpeedOpt("outline") and true or false
	ApplyColor()
	for _, text in ipairs(allTexts) do
		text.outline:SetPoint("CENTER", text, "CENTER", shift, 0)
	end
end

local function SetText(text, value)
	text:SetText(value)
	text.outline:SetText(value)
end

local function SetTextShown(text, shown)
	text:SetShown(shown)
	text.outline:SetShown(shown and outlineOn)
end

-- 位置原样存暴雪的锚点,不做任何换算
local function ApplyPosition()
	hud:ClearAllPoints()
	hud:SetPoint(StatDiminishing_GetSpeedOpt("point"), UIParent, StatDiminishing_GetSpeedOpt("relPoint"),
		StatDiminishing_GetSpeedOpt("x"), StatDiminishing_GetSpeedOpt("y"))
end

-- 缩放挂在居中的content上:不管外面这层挂在哪,放大缩小都是围着框体中心走
local function ApplyScale()
	content:SetScale(StatDiminishing_GetSpeedOpt("scale"))
end

local function ApplyLocked()
	if StatDiminishing_GetSpeedOpt("locked") then
		content:SetBackdrop(nil)
		content:EnableMouse(false)
	else
		content:SetBackdrop(HUD_BACKDROP)
		content:SetBackdropColor(0, 0, 0, 0.45)
		content:SetBackdropBorderColor(1, 1, 1, 0.6)
		content:EnableMouse(true)
	end
end

-- 鼠标挂在content上(它是缩放过的,点了跟着缩放走),真正移动的是外面那层
content:RegisterForDrag("LeftButton")

content:SetScript("OnDragStart", function()
	if StatDiminishing_GetSpeedOpt("locked") then return end
	hud:StartMoving()
end)

content:SetScript("OnDragStop", function()
	hud:StopMovingOrSizing()
	-- 原样存暴雪的锚点,不做任何换算
	local point, _, relPoint, x, y = hud:GetPoint()
	if point then
		StatDiminishing_SetSpeedOpt("point", point)
		StatDiminishing_SetSpeedOpt("relPoint", relPoint)
		StatDiminishing_SetSpeedOpt("x", x)
		StatDiminishing_SetSpeedOpt("y", y)
	end
end)


-- 注意:文本可能是secret字符串,拿到之后除了SetText什么都别做
local currentLine
local function UpdateSpeedHud()
	if not StatDiminishing_IsSpeedRunning() or not StatDiminishing_GetSpeedOpt("show") then
		currentLine = nil
		hud:Hide()
		return
	end

	local isGliding, forwardSpeed
	if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
		isGliding, _, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
	end

	-- 驭空术飞着的时候只看驭空术速度,地面速度那行让位
	local gliding = false
	if not (issecretvalue and issecretvalue(isGliding)) then
		gliding = isGliding and true or false
	end
	local line
	if gliding then
		if StatDiminishing_GetSpeedOpt("glide") then line = "glide" end
	elseif StatDiminishing_GetSpeedOpt("move") and GetUnitSpeed then
		line = "move"
	end

	if line ~= currentLine then
		currentLine = line
		SetTextShown(moveLabel, line == "move")
		SetTextShown(moveValue, line == "move")
		SetTextShown(glideLabel, line == "glide")
		SetTextShown(glideValue, line == "glide")
		if line == "move" then
			SetText(moveLabel, L.move)
		elseif line == "glide" then
			SetText(glideLabel, L.glide)
		end
	end

	if line == "move" then
		SetText(moveValue, SpeedText(select(2, GetUnitSpeed("player")), SPEED_PERCENT_1, true))
		hud:Show()
	elseif line == "glide" then
		SetText(glideValue, SpeedText(forwardSpeed, SPEED_PERCENT_0, false))
		hud:Show()
	else
		hud:Hide()
	end
end

local elapsed = 0
hud:SetScript("OnUpdate", function(_, delta)
	elapsed = elapsed + delta
	if elapsed < 0.15 then return end
	elapsed = 0
	UpdateSpeedHud()
end)

function StatDiminishing_RefreshSpeedHud()
	ApplyStyle()
	ApplyScale()
	ApplyPosition()
	ApplyLocked()
	currentLine = nil
	UpdateSpeedHud()
end

-------------------------------------------------------------
-- 角色面板"强化属性"最后那行移动速度
-------------------------------------------------------------
-- 暴雪自己留了MOVESPEED的定义但没往分类里放,不过它的算法要在暴雪那边跑才安全,
-- 我们这边自己写一份:只转字符串不做运算,插到强化属性最后
local ROW_STAT = "DSM_MOVESPEED"

RowOnEnter = function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(format(PAPERDOLLFRAME_TOOLTIP_FORMAT, STAT_MOVEMENT_SPEED))
	GameTooltip:AddLine(SpeedText(select(2, GetUnitSpeed("player")), SPEED_PERCENT_1, true))
	GameTooltip:Show()
end

local function RowUpdate(statFrame, unit)
	if unit ~= "player" or not GetUnitSpeed then
		statFrame:Hide()
		return
	end
	-- 这里不能判断text是真是假,它可能是secret字符串
	PaperDollFrame_SetLabelAndText(statFrame, STAT_MOVEMENT_SPEED, SpeedText(select(2, GetUnitSpeed(unit)), SPEED_PERCENT_1, true), false, 0)
	statFrame.onEnterFunc = RowOnEnter
	statFrame.UpdateTooltip = RowOnEnter
	statFrame:Show()
end

-- 这两张表要等暴雪的界面文件加载完才有,没有就等下一个事件再试
local function RegisterPaneStat()
	if type(PAPERDOLL_STATINFO) ~= "table" then return false end
	if not PAPERDOLL_STATINFO[ROW_STAT] then
		PAPERDOLL_STATINFO[ROW_STAT] = { updateFunc = RowUpdate }
	end
	return true
end

local paneRow = { stat = ROW_STAT }

function StatDiminishing_ShouldShowPaneSpeed()
	return GetOpt("paneSpeed") and true or false
end

local function GetEnhancementStats()
	if type(PAPERDOLL_STATCATEGORIES) ~= "table" then return nil end
	for _, category in ipairs(PAPERDOLL_STATCATEGORIES) do
		if category.categoryFrame == "EnhancementsCategory" and type(category.stats) == "table" then
			return category.stats
		end
	end
end

-- 返回true表示列表被改过
local function SyncPaneRow()
	local stats = GetEnhancementStats()
	if not stats then return false end

	local index
	for i, entry in ipairs(stats) do
		if entry == paneRow then index = i break end
	end

	local want = StatDiminishing_IsSpeedRunning() and StatDiminishing_ShouldShowPaneSpeed()
	if want and not index then
		if not RegisterPaneStat() then return false end
		tinsert(stats, paneRow)
		return true
	elseif not want and index then
		tremove(stats, index)
		return true
	end
	return false
end

-- 面板开着的时候改开关才需要重建;战斗和副本里属性值是secret,这时候不去碰暴雪的刷新
local function RefreshStatsPane()
	if not (PaperDollFrame_UpdateStats and CharacterStatsPane and CharacterStatsPane.statsFramePool) then return end
	if not (CharacterFrame and CharacterFrame:IsShown()) then return end
	if InCombatLockdown and InCombatLockdown() then return end
	-- 副本/团本这种受限环境即使不在战斗也可能返回secret,这时候让暴雪自己刷
	if issecretvalue and GetUnitSpeed then
		local _, runSpeed = GetUnitSpeed("player")
		if runSpeed and issecretvalue(runSpeed) then return end
	end
	PaperDollFrame_UpdateStats()
end

local injected = false
local function TryInject()
	if injected then return end
	if not GetEnhancementStats() then return end
	if not RegisterPaneStat() then return end
	injected = true
	if SyncPaneRow() then RefreshStatsPane() end
end

function StatDiminishing_SetPaneSpeed(on)
	DB().paneSpeed = on and true or false
	if SyncPaneRow() then
		RefreshStatsPane()
	end
end

-- 模块/插件总开关变了以后重新对一遍(不动存档,存档只由玩家改设置时写)
function StatDiminishing_RefreshFeatures()
	if SyncPaneRow() then RefreshStatsPane() end
	StatDiminishing_RefreshSpeedHud()
	if StatDiminishing_UpdateOptionsGating then StatDiminishing_UpdateOptionsGating() end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		StatDiminishing_RefreshSpeedHud()
	elseif event == "ADDON_LOADED" then
		StatDiminishing_RefreshSpeedHud()
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- 战斗中跳过的那次面板重建,出了战斗补上
		RefreshStatsPane()
		return
	end
	TryInject()
end)


-------------------------------------------------------------
-- 三、设置面板
-- 全部用暴雪自带控件,不依赖任何库;点关闭或者按Esc都能关
-------------------------------------------------------------
local frame = CreateFrame("Frame", "StatDiminishingOptionsFrame", UIParent, "BackdropTemplate")
frame:SetSize(400, 470)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:Hide()
tinsert(UISpecialFrames, "StatDiminishingOptionsFrame")

local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -16)
title:SetText(L.title)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

local refreshers = {}
local gated = {}
local lastRow

-- 两层灰:level1跟速度模块总开关,level2再跟悬浮窗自己的开关
local function Gate(level, row, interactive)
	tinsert(gated, { level = level, row = row, widget = interactive })
end

local function UpdateGated()
	local moduleOn = StatDiminishing_IsSpeedRunning and StatDiminishing_IsSpeedRunning()
	local hudOn = moduleOn and StatDiminishing_GetSpeedOpt("show") and true or false
	for _, item in ipairs(gated) do
		local on = (item.level == 2) and hudOn or moduleOn
		item.row:SetAlpha(on and 1 or 0.4)
		if item.widget then
			if on then item.widget:Enable() else item.widget:Disable() end
		end
	end
end

-- 插件总开关(/sd、163UI那行)变了以后,面板上的灰化也要跟着变
function StatDiminishing_UpdateOptionsGating()
	UpdateGated()
end

local function NextRow(gap)
	local row = CreateFrame("Frame", nil, frame)
	row:SetSize(348, 24)
	if lastRow then
		row:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -(gap or 6))
	else
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -50)
	end
	lastRow = row
	return row
end

local function Section(text, level)
	local row = NextRow(12)
	Gate(level or 1, row)
	local fontString = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	fontString:SetPoint("LEFT", row, "LEFT", 2, 0)
	fontString:SetTextColor(1, 0.82, 0)
	fontString:SetText(text)
end

local function MakeCheck(text, getter, setter, level)
	local row = NextRow()
	local check = CreateFrame("CheckButton", nil, row)
	if level then Gate(level, row, check) end
	check:SetSize(24, 24)
	check:SetPoint("LEFT", row, "LEFT", 0, 0)
	check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	check:SetHitRectInsets(0, -300, 0, 0)
	local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("LEFT", check, "RIGHT", 4, 0)
	check:SetFontString(label)
	check:SetText(text)
	check:SetScript("OnClick", function(self)
		setter(self:GetChecked() and true or false)
	end)
	tinsert(refreshers, function() check:SetChecked(getter() and true or false) end)
end

local function MakeSlider(text, min, max, decimals, getter, setter, formatText, level)
	local row = NextRow()
	local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("LEFT", row, "LEFT", 4, 0)
	label:SetText(text)

	local slider = CreateFrame("Slider", nil, row)
	if level then Gate(level, row, slider) end
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(150, 16)
	slider:SetMinMaxValues(min, max)
	slider:SetValueStep(10 ^ -decimals)
	slider:SetObeyStepOnDrag(true)
	slider:SetPoint("LEFT", label, "RIGHT", 16, 0)
	slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	local background = slider:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
	background:SetAllPoints(true)

	local valueText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)

	local factor = 10 ^ decimals
	local updating = false
	local function Round(value)
		return floor(value * factor + 0.5) / factor
	end
	slider:SetScript("OnValueChanged", function(_, value)
		value = Round(value)
		valueText:SetText(formatText(value))
		if updating then return end
		setter(value)
	end)
	tinsert(refreshers, function()
		updating = true
		slider:SetValue(getter())
		updating = false
	end)
end

local function MakeColorRow(text, keyR, keyG, keyB, level)
	local row = NextRow()
	local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("LEFT", row, "LEFT", 4, 0)
	label:SetText(text)

	local swatch = CreateFrame("Button", nil, row)
	if level then Gate(level, row, swatch) end
	swatch:SetSize(22, 22)
	swatch:SetPoint("LEFT", label, "RIGHT", 16, 0)
	swatch:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	local texture = swatch:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints(true)

	local function UpdateSwatch()
		texture:SetColorTexture(StatDiminishing_GetSpeedOpt(keyR), StatDiminishing_GetSpeedOpt(keyG), StatDiminishing_GetSpeedOpt(keyB), 1)
	end

	swatch:SetScript("OnClick", function()
		if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then return end
		local oldR, oldG, oldB = StatDiminishing_GetSpeedOpt(keyR), StatDiminishing_GetSpeedOpt(keyG), StatDiminishing_GetSpeedOpt(keyB)
		ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
		ColorPickerFrame:SetupColorPickerAndShow({
			r = oldR, g = oldG, b = oldB,
			hasOpacity = false,
			swatchFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB()
				StatDiminishing_SetSpeedOpt(keyR, r)
				StatDiminishing_SetSpeedOpt(keyG, g)
				StatDiminishing_SetSpeedOpt(keyB, b)
				UpdateSwatch()
				ApplyColor()
			end,
			cancelFunc = function()
				StatDiminishing_SetSpeedOpt(keyR, oldR)
				StatDiminishing_SetSpeedOpt(keyG, oldG)
				StatDiminishing_SetSpeedOpt(keyB, oldB)
				UpdateSwatch()
				ApplyColor()
			end,
		})
	end)
	tinsert(refreshers, UpdateSwatch)
end

MakeCheck(L.speedOn, function()
	return StatDiminishing_IsSpeedOn and StatDiminishing_IsSpeedOn()
end, function(value)
	if StatDiminishing_SetSpeedOn then StatDiminishing_SetSpeedOn(value) end
	UpdateGated()
end)

Section(L.sectionPane)
MakeCheck(L.paneSpeed, function()
	return StatDiminishing_ShouldShowPaneSpeed and StatDiminishing_ShouldShowPaneSpeed()
end, function(value)
	if StatDiminishing_SetPaneSpeed then StatDiminishing_SetPaneSpeed(value) end
end, 1)

Section(L.sectionHud)
MakeCheck(L.hudShow, function()
	return StatDiminishing_GetSpeedOpt("show")
end, function(value)
	StatDiminishing_SetSpeedOpt("show", value)
	currentLine = nil
	UpdateSpeedHud()
	UpdateGated()
end, 1)
MakeCheck(L.hudMove, function()
	return StatDiminishing_GetSpeedOpt("move")
end, function(value)
	StatDiminishing_SetSpeedOpt("move", value)
	currentLine = nil
	UpdateSpeedHud()
end, 2)
MakeCheck(L.hudGlide, function()
	return StatDiminishing_GetSpeedOpt("glide")
end, function(value)
	StatDiminishing_SetSpeedOpt("glide", value)
	currentLine = nil
	UpdateSpeedHud()
end, 2)

MakeSlider(L.hudScale, 0.5, 2, 2, function()
	return StatDiminishing_GetSpeedOpt("scale")
end, function(value)
	StatDiminishing_SetSpeedOpt("scale", value)
	ApplyScale()
end, function(value)
	return format("%d%%", value * 100)
end, 2)

MakeColorRow(L.hudColor, "r", "g", "b", 2)
MakeCheck(L.hudOutline, function()
	return StatDiminishing_GetSpeedOpt("outline")
end, function(value)
	StatDiminishing_SetSpeedOpt("outline", value)
	ApplyStyle()
	currentLine = nil
	UpdateSpeedHud()
end, 2)

MakeCheck(L.hudLocked, function()
	return StatDiminishing_GetSpeedOpt("locked")
end, function(value)
	StatDiminishing_SetSpeedOpt("locked", value)
	ApplyLocked()
end, 2)

do
	local row = NextRow()
	local reset = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	Gate(2, row, reset)
	reset:SetSize(110, 22)
	reset:SetPoint("LEFT", row, "LEFT", 4, 0)
	reset:SetText(L.hudReset)
	reset:SetScript("OnClick", function()
		StatDiminishing_SetSpeedOpt("point", DEFAULTS.hud.point)
		StatDiminishing_SetSpeedOpt("relPoint", DEFAULTS.hud.relPoint)
		StatDiminishing_SetSpeedOpt("x", DEFAULTS.hud.x)
		StatDiminishing_SetSpeedOpt("y", DEFAULTS.hud.y)
		ApplyPosition()
	end)
end

local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
closeButton:SetSize(100, 22)
closeButton:SetPoint("BOTTOMRIGHT", -24, 16)
closeButton:SetText(L.close)
closeButton:SetScript("OnClick", function() frame:Hide() end)

function StatDiminishing_OpenConfig()
	for _, refresh in ipairs(refreshers) do
		refresh()
	end
	UpdateGated()
	frame:Show()
end

function StatDiminishing_ToggleConfig()
	if frame:IsShown() then
		frame:Hide()
	else
		StatDiminishing_OpenConfig()
	end
end
