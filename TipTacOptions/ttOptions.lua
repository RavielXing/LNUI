-- create addon
local MOD_NAME = ...;
local PARENT_MOD_NAME = "TipTac";
local f = CreateFrame("Frame",MOD_NAME,UIParent,BackdropTemplateMixin and "BackdropTemplate");	-- 9.0.1: Using BackdropTemplate

-- get libs
local LibFroznFunctions = LibStub:GetLibrary("LibFroznFunctions-1.0");

-- set config
local configDb, cfg = LibFroznFunctions:CreateDbWithLibAceDB("TipTac_Config");

-- constants
local TT_OPTIONS_CATEGORY_LIST_WIDTH = 117;

-- DropDown Lists
local DROPDOWN_FONTFLAGS = {
	["|cffffa0a0无"] = "",
	["细描边"] = "OUTLINE",
	["粗描边"] = "THICKOUTLINE",
};
local DROPDOWN_ANCHORTYPE = {
	["Tiptac锚点"] = "normal",
	["鼠标跟随"] = "mouse",
	["全局跟随"] = "parent",
};

local DROPDOWN_ANCHORPOS = {
	["顶部"] = "TOP",
	["左上"] = "TOPLEFT",
	["右上"] = "TOPRIGHT",
	["底部"] = "BOTTOM",
	["左下"] = "BOTTOMLEFT",
	["右下"] = "BOTTOMRIGHT",
	["左侧"] = "LEFT",
	["右侧"] = "RIGHT",
	["中间"] = "CENTER",
};

local DROPDOWN_ANCHORHALIGN = {
	["左"] = "LEFT",
	["中"] = "CENTER",
	["右"] = "RIGHT",
};

local DROPDOWN_ANCHORVALIGN = {
	["上"] = "TOP",
	["中"] = "MIDDLE",
	["下"] = "BOTTOM",
};

local DROPDOWN_ANCHORGROWDIRECTION = {
	["上"] = "UP",
	["右"] = "RIGHT",
	["下"] = "DOWN",
	["左"] = "LEFT",
};

local DROPDOWN_BARTEXTFORMAT = {
	["|cffffa0a0无"] = "none",
	["百分比"] = "percent",
	["仅显示当前数值"] = "current",
	["数值"] = "value",
	["数值&百分比"] = "full",
	["缺失数值"] = "deficit",
};

-- colors
local TTO_COLOR = {
	text = {
		default = HIGHLIGHT_FONT_COLOR, -- white
		currentProfile = LIGHTYELLOW_FONT_COLOR
	}
};

-- Options -- The "y" value of a category subtable, will further increase the vertical offset position of the item
--
-- hint for layouting options:
-- to set pixel perfect scale for options to adjust option elements:
-- /run local psw, psh = GetPhysicalScreenSize(); local uf = 768 / psh; local uis = UIParent:GetEffectiveScale(); local ttos = uf / uis; _G["TipTacOptions"]:SetScale(ttos);
local activePage = 1;
local options = {};
local option;

-- General
local ttOptionsGeneral = {
	{ type = "Check", var = "showMinimapIcon", label = "小地图图标", tip = "在小地图旁显示" .. PARENT_MOD_NAME .. "图标" },
	{ type = "Slider", var = "gttScale", label = "鼠标提示比例", min = 0.2, max = 4, step = 0.05, y = 10 },
	
	{ type = "Header", label = "Tiptac鼠标提示" },
	{ type = "Check", var = "showUnitTip", label = "启用" .. PARENT_MOD_NAME .. "鼠标提示", tip = "开启后鼠标提示外观将会修改为Tiptac样式.      " .. PARENT_MOD_NAME .. " 中的大部分功能只能在此选项开启时生效. \n注意: 对非英文客户端使用此选项可能会导致问题!" },
	
	{ type = "Check", var = "showStatus", label = "离线, 离开和忙碌状态", tip = "将在角色名称后面显示<离线>, <离开>和<忙碌>状态", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 },
	{ type = "Check", var = "showTargetedBy", label = "显示选中该目标的角色", tip = "在团队或小队中, 勾选此选项后将显示选中该目标的队友.\n不在队伍时依赖姓名版运作（需开启姓名版：选项-游戏-界面-姓名版）.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
	{ type = "Check", var = "showPlayerGender", label = "角色性别", tip = "这将显示玩家的性别. \n示例: \"85 女性 血精灵 圣骑士\".", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
	{ type = "Check", var = "showCurrentUnitSpeed", label = "当前移动速度", tip = "这将显示在种族&职业加成下当前移动速度.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end }
};

if (C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then
	tinsert(ttOptionsGeneral, { type = "Check", var = "showMythicPlusDungeonScore", label = "显示史诗钥石评分", tip = "这将显示角色的史诗钥石评分.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 });
	tinsert(ttOptionsGeneral, { type = "DropDown", var = "mythicPlusDungeonScoreFormat", label = "钥石评分格式", list = { ["分数"] = "dungeonScore", ["分数 + 最高限时层数"] = "both", ["最高限时层数"] = "highestSuccessfullRun" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });
end

if (LibFroznFunctions:IsAddOnEnabled("MythicDungeonTools")) then
	tinsert(ttOptionsGeneral, { type = "Check", var = "showMythicPlusForcesFromMDT", label = "显示MDT插件敌人分布", tip = "这将显示Mythic Dungeon Tools (MDT)插件的敌人分布情况。", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });
end

option = { type = "Check", var = "showMount", label = "显示坐骑", tip = "这将显示该角色当前坐骑.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 };
if (LibFroznFunctions.hasWoWFlavor.GetMountFromSpellNotPossibleInCombat) then
	option.tip = option.tip .. "\n注意: 战斗中无法使用。";
end
tinsert(ttOptionsGeneral, option);

tinsert(ttOptionsGeneral, { type = "Check", var = "showMountCollected", label = "已收藏", tip = "此选项以图标（√）（×）的方式提示你是否拥有该坐骑.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") end, x = 122, belongsTo = "showMount" });
tinsert(ttOptionsGeneral, { type = "Check", var = "showMountIcon", label = "图标", tip = "这将显示坐骑图标.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") end, x = 210, belongsTo = "showMountCollected" });
tinsert(ttOptionsGeneral, { type = "Check", var = "showMountText", label = "名称", tip = "这将显示坐骑名称.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") end, x = 122, belongsTo = "showMount" });
tinsert(ttOptionsGeneral, { type = "Check", var = "showMountSpeed", label = "速度", tip = "这将显示坐骑奔跑/飞行速度.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") end, x = 210, belongsTo = "showMountText" });
tinsert(ttOptionsGeneral, { type = "Check", var = "showMountSourceIfNotCollected", label = "掉落（未收集）", tip = "仅显示你未收集坐骑的掉落来源.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") and (not factory:GetConfigValue("showMountSource")) end, x = 122, belongsTo = "showMount" });
tinsert(ttOptionsGeneral, { type = "Check", var = "showMountSource", label = "掉落", tip = "这将显示所有坐骑的掉落来源.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") end, x = 122, belongsTo = "showMount" });
tinsert(ttOptionsGeneral, { type = "Check", var = "showMountLore", label = "故事", tip = "这将显示坐骑的背景故事.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") end, x = 210, belongsTo = "showMountSource" });

tinsert(ttOptionsGeneral, { type = "DropDown", var = "nameType", label = "名称 & 状态", list = { ["名称"] = "normal", ["名称 + 头衔"] = "title", ["暴雪默认显示样式"] = "original", ["玛丽苏协议（需要配合RP插件使用）"] = "marysueprot" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 });
tinsert(ttOptionsGeneral, { type = "DropDown", var = "showRealm", label = "所属服务器", tip = "仅对其他服务器角色有效。", list = { ["|cffffa0a0不显示服务器"] = "none", ["服务器名称"] = "show", ["在第二行显示服务器名称"] = "showInNewLine", ["显示(*)替代服务器名称 "] = "asterisk" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });
tinsert(ttOptionsGeneral, { type = "DropDown", var = "showTarget", label = "角色目标", list = { ["|cffffa0a0不显示目标"] = "none", ["显示于第一行"] = "afterName", ["显示于名称下方"] = "belowNameRealm", ["显示于单独一行"] = "last" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });

tinsert(ttOptionsGeneral, { type = "Text", var = "targetYouText", label = "目标是你时显示", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 });

tinsert(ttOptionsGeneral, { type = "Check", var = "showGuild", label = "角色公会", tip = "这将显示角色的公会名称.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 });
tinsert(ttOptionsGeneral, { type = "DropDown", var = "showGuildRealm", label = "公会所属服务器", tip = "仅对其他服务器公会有效。", list = { ["|cffffa0a0不显示服务器"] = "none", ["服务器名称"] = "show", ["在第二行显示服务器名称"] = "showInNewLine", ["显示(*)替代服务器名称"] = "asterisk" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showGuild") end });
tinsert(ttOptionsGeneral, { type = "Check", var = "showGuildRank", label = "角色会阶名称和级别", tip = "启用此选项后您还将看到角色所在公会的会阶名称和级别.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showGuild") end });
tinsert(ttOptionsGeneral, { type = "DropDown", var = "guildRankFormat", label = "会阶格式", list = { ["会阶名称"] = "title", ["会阶名称 + 级别"] = "both", ["级别"] = "level" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showGuild") and factory:GetConfigValue("showGuildRank") end });
tinsert(ttOptionsGeneral, { type = "Check", var = "showGuildMemberNote", label = "角色公会备注", tip = "启用此选项后您将看到角色在公会中的备注.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });
tinsert(ttOptionsGeneral, { type = "Check", var = "showGuildOfficerNote", label = "角色公会官员备注", tip = "启用次选项后您将看到角色在公会中关于官员的备注.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });

tinsert(ttOptionsGeneral, { type = "DropDown", var = "showPlayerLocation", label = "显示玩家位置", tip = "位置数据仅对玩家本人及其队伍成员可用。区域和子区域信息仅对玩家本人可见。只有当玩家所在地图与所在区域不同时，才会显示该玩家的地图。", list = { ["|cffffa0a0不显示"] = "none", ["显示地图/区域/子区域"] = "mapAndZoneAndSubzone", ["显示地图/区域"] = "mapAndZone", ["仅显示地图"] = "map", ["显示区域/子区域"] = "zoneAndSubzone", ["仅显示区域"] = "zone" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 });
tinsert(ttOptionsGeneral, { type = "Check", var = "showPlayerLocationOnlyForeignMap", label = "仅在非本队/自身所属区域地图上\n显示队伍成员的地图位置.", tip = "此设置仅会在未探索或者陌生地图上显示队伍成员的地图位置。", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and LibFroznFunctions:ExistsInTable(factory:GetConfigValue("showPlayerLocation"), { "mapAndZoneAndSubzone", "mapAndZone", "map" }) end });

tinsert(ttOptionsGeneral, { type = "Check", var = "showBattlePetTip", label = "战斗宠物提示", tip = "为野外小宠物战斗显示特有提示.  在非英语客户端内可能需要禁用.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 });

tinsert(ttOptionsGeneral, { type = "Header", label = "暴雪默认提示信息", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });

tinsert(ttOptionsGeneral, { type = "Check", var = "hidePvpText", label = "隐藏暴雪默认PvP信息", tip = "从Tiptac中隐藏暴雪框架的PVP信息栏，改为Tiptac显示模式.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });

if (LibFroznFunctions.hasWoWFlavor.specializationAndClassTextInPlayerUnitTip) then
	tinsert(ttOptionsGeneral, { type = "Check", var = "hideSpecializationAndClassText", label = "隐藏暴雪默认专精和职业信息", tip = "从Tiptac中隐藏暴雪的专精和职业信息栏，改为Tiptac显示模式.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });
end

if (LibFroznFunctions.hasWoWFlavor.rightClickForFrameSettingsTextInUnitTip) then
	tinsert(ttOptionsGeneral, { type = "Check", var = "hideRightClickForFrameSettingsTextInUnitTip", label = "隐藏暴雪默认\"右键点击设置框体\"提示", tip = "从Tiptac中隐藏鼠标指向头像框时底部\"右键点击设置框体\"提示.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });
end

-- Colors
local ttOptionsColors = {
	{ type = "Check", var = "enableColorName", label = "自定义名称颜色", tip = "可使用下方调色板自定义颜色|cffff0b0b\n注意:该选项仅在你未启用下方两个颜色选项时生效.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
	{ type = "Color", var = "colorName", label = "颜色选择", tip = "启动上方选项后在此自定义名称颜色。|cffff0b0b\n注意:该选项仅在你未启用下方两个颜色选项时生效.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("enableColorName") end },
	{ type = "Check", var = "colorNameByReaction", label = "按目标属性颜色显示角色名称", tip = "角色姓名将使用友善/中立/敌对等属性颜色显示\n|cffff0b0b注意:这个选项将覆盖上方自定义名称颜色.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
	{ type = "Check", var = "colorNameByClass", label = "按职业颜色显示角色名称", tip = "角色姓名将会使用职业颜色显示\n|cffff0b0b注意:这个选项将覆盖上方两个名称颜色选项.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
	
	{ type = "Color", var = "colorGuild", label = "公会颜色", tip = "非相同公会的情况下的公会名称颜色.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showGuild") end, y = 10 },
	{ type = "Color", var = "colorSameGuild", label = "相同公会的颜色.", tip = "让你更快识别和你相同公会的角色.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showGuild") end, x = 120, belongsTo = "colorGuild" },
	{ type = "Check", var = "colorGuildByReaction", label = "按阵营显示公会名称颜色", tip = "公会名称颜色基于目标属性的颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showGuild") end },
	
	{ type = "Color", var = "colorRace", label = "种族&生物类型颜色", tip = "可自定义种族与生物类型的文本信息颜色.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 },
	{ type = "Color", var = "colorLevel", label = "中立目标等级颜色", tip = "可自定义不能攻击的目标的等级数字颜色.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
	
	{ type = "Check", var = "factionText", label = "显示阵营信息", tip = "在鼠标提示上显示联盟或者部落的信息", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 },
	{ type = "Check", var = "enableColorFaction", label = "自定义阵营信息颜色", tip = "开启后可在下方自定义阵营信息颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("factionText") end },
	{ type = "Color", var = "colorFactionAlliance", label = "联盟阵营信息颜色", tip = "自定义联盟阵营的颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("factionText") and factory:GetConfigValue("enableColorFaction") end },
	{ type = "Color", var = "colorFactionHorde", label = "部落阵营信息颜色", tip = "自定义部落阵营的颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("factionText") and factory:GetConfigValue("enableColorFaction") end },
	{ type = "Color", var = "colorFactionNeutral", label = "中立阵营信息颜色", tip = "自定义中立阵营的颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("factionText") and factory:GetConfigValue("enableColorFaction") end },
	
	{ type = "Check", var = "classColoredBorder", label = "按职业颜色着色边框", tip = "目标为玩家的角色时，鼠标提示的边框将会与他们的职业所匹配", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end, y = 10 },
	
	{ type = "Header", label = "自定义职业颜色" },
	
	{ type = "Check", var = "enableCustomClassColors", label = "启用自定义职业颜色", tip = "启用后就可以在下面为把每个职业改成你心仪的颜色了" }
};

local numClasses = GetNumClasses();
local firstClass = true;

for i = 1, numClasses do
	local className, classFile = GetClassInfo(i);
	
	if (classFile) then
		local camelCasedClassFile = LibFroznFunctions:CamelCaseText(classFile);
		
		tinsert(ttOptionsColors, { type = "Color", var = "colorCustomClass" .. camelCasedClassFile, label = camelCasedClassFile .. " 颜色", enabled = function(factory) return factory:GetConfigValue("enableCustomClassColors") end, y = (firstClass and 10 or nil) });
		
		firstClass = false;
	end
end

-- Auras
local ttOptionsAuras = {
    { type = "Header", label = "鼠标提示上显示Buff/Debuff", enabled = function(factory) return factory:GetConfigValue("enableAuras") end },

    { type = "Check", var = "showBuffs", label = "显示目标BUFF", tip = "显示目标单位的Buff", enabled = function(factory) return factory:GetConfigValue("enableAuras") end },
    { type = "Check", var = "showDebuffs", label = "显示目标DeBuff", tip = "显示目标单位的DeBuff", enabled = function(factory) return factory:GetConfigValue("enableAuras") end },

};

option = { type = "Check", var = "selfAurasOnly", label = "只显示来源于你的Buff/Debuff", tip = "启用此选项将会过滤掉来源其他人的Buff/Debuff", enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end, y = 10 };
if (LibFroznFunctions.hasWoWFlavor.aurasCooldownCountAndDebuffTypeNotAvailableInCombat) then
    option.tip = option.tip .. ".\n注意：战斗中此功能不可用。该情况下光环不会被过滤";
end
tinsert(ttOptionsAuras, option);

option = { type = "Check", var = "showAuraCooldown", label = "显示冷却计时样式", tip = "启用此选项将可以看到Buff的剩余持续模式", enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end, y = 10 };
if (LibFroznFunctions.hasWoWFlavor.aurasCooldownCountAndDebuffTypeNotAvailableInCombat) then
    option.tip = option.tip .. ".\n注意：战斗中此功能不可用。";
end
tinsert(ttOptionsAuras, option);

tinsert(ttOptionsAuras, { type = "Check", var = "noCooldownCount", label = "隐藏冷却计时文字", tip = "启用此选项将会在使用类似于OmniCC一类插件时屏蔽掉倒数计时文字.|cffff0b0b\n注意:并不是对所有此类型插件都奏效", enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end });
tinsert(ttOptionsAuras, { type = "Check", var = "auraStackCount", label = "显示光环层数", tip = "启用此选项后，你将能看到光环的叠加层数", enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end });

tinsert(ttOptionsAuras, { type = "Slider", var = "auraSize", label = "图标大小", min = 8, max = 60, step = 1, enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end, y = 10 });
tinsert(ttOptionsAuras, { type = "Slider", var = "auraMaxRows", label = "最大图标显示行数", min = 1, max = 8, step = 1, enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end });

tinsert(ttOptionsAuras, { type = "Check", var = "aurasAtBottom", label = "底部显示光环图标", tip = "将光环图标位置放置于TipTac底部以替换默认的放置于顶部", enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end, y = 10 });
tinsert(ttOptionsAuras, { type = "Slider", var = "auraOffset", label = "光环图标位置设置", min = 0, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end });

-- Anchors
local ttOptionsAnchors = {
	{ type = "DropDown", var = "anchorWorldUnitType", label = "世界单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end },
	{ type = "DropDown", var = "anchorWorldUnitPoint", label = "世界单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end },
	
	{ type = "DropDown", var = "anchorWorldTipType", label = "世界提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 },
	{ type = "DropDown", var = "anchorWorldTipPoint", label = "世界提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end },
	
	{ type = "DropDown", var = "anchorFrameUnitType", label = "框架单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 },
	{ type = "DropDown", var = "anchorFrameUnitPoint", label = "框架单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end },
	
	{ type = "DropDown", var = "anchorFrameTipType", label = "框架提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 },
	{ type = "DropDown", var = "anchorFrameTipPoint", label = "框架提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end },
};

local priority = 0;

if (LibFroznFunctions.hasWoWFlavor.challengeMode) then
	priority = priority + 1;
	tinsert(ttOptionsAnchors, { type = "Header", label = "优先级#" .. priority .. ": 大秘境中锚点覆盖", tip = "下方选项可设置在大秘境中战斗/脱战状态下的鼠标锚点覆盖", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });

	tinsert(ttOptionsAnchors, { type = "TextOnly", label = "进入战斗" });

	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldUnitDuringChallengeModeInCombat", label = "大秘境中战斗时的世界单位", tip = "此选项将覆盖大秘境中战斗状态下的世界单位锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitTypeDuringChallengeModeInCombat", label = "世界单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringChallengeModeInCombat") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitPointDuringChallengeModeInCombat", label = "世界单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringChallengeModeInCombat") end });

	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldTipDuringChallengeModeInCombat", label = "大秘境中战斗时的世界提示", tip = "此选项将覆盖大秘境中战斗状态下的世界提示锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipTypeDuringChallengeModeInCombat", label = "世界提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringChallengeModeInCombat") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipPointDuringChallengeModeInCombat", label = "世界提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringChallengeModeInCombat") end });

	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameUnitDuringChallengeModeInCombat", label = "大秘境中战斗时的框架单位", tip = "此选项将覆盖大秘境中战斗状态下的框架单位锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitTypeDuringChallengeModeInCombat", label = "框架单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringChallengeModeInCombat") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitPointDuringChallengeModeInCombat", label = "框架单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringChallengeModeInCombat") end });

	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameTipDuringChallengeModeInCombat", label = "大秘境中战斗时的框架提示", tip = "此选项将覆盖大秘境中战斗状态下的框架提示锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipTypeDuringChallengeModeInCombat", label = "框架提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringChallengeModeInCombat") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipPointDuringChallengeModeInCombat", label = "框架提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringChallengeModeInCombat") end });

	tinsert(ttOptionsAnchors, { type = "TextOnly", label = "脱离战斗", y = 10 });

	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldUnitDuringChallengeMode", label = "大秘境中脱战时的世界单位", tip = "此选项将覆盖大秘境中脱离战斗状态下的世界单位锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitTypeDuringChallengeMode", label = "世界单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringChallengeMode") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitPointDuringChallengeMode", label = "世界单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringChallengeMode") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldTipDuringChallengeMode", label = "大秘境中脱战时的世界提示", tip = "此选项将覆盖大秘境中脱离战斗状态下的世界提示锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipTypeDuringChallengeMode", label = "世界提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringChallengeMode") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipPointDuringChallengeMode", label = "世界提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringChallengeMode") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameUnitDuringChallengeMode", label = "大秘境中脱战时的框架单位", tip = "此选项将覆盖大秘境中脱离战斗状态下的框架单位锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitTypeDuringChallengeMode", label = "框架单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringChallengeMode") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitPointDuringChallengeMode", label = "框架单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringChallengeMode") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameTipDuringChallengeMode", label = "大秘境中脱战时的框架提示", tip = "此选项将覆盖大秘境中脱离战斗状态下的框架提示锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipTypeDuringChallengeMode", label = "框架提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringChallengeMode") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipPointDuringChallengeMode", label = "框架提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringChallengeMode") end });
end

priority = priority + 1;
tinsert(ttOptionsAnchors, { type = "Header", label = "优先级#" .. priority .. ": 副本中锚点覆盖", tip = "下方选项可设置在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗/脱战状态下的鼠标锚点覆盖", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });

tinsert(ttOptionsAnchors, { type = "TextOnly", label = "进入战斗" });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldUnitDuringInstanceInCombat", label = "副本中战斗时的世界单位", tip = "此选项将覆盖副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下的世界单位锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitTypeDuringInstanceInCombat", label = "世界单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringInstanceInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitPointDuringInstanceInCombat", label = "世界单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringInstanceInCombat") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldTipDuringInstanceInCombat", label = "副本中战斗时的世界提示", tip = "此选项将覆盖副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下的世界提示锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipTypeDuringInstanceInCombat", label = "世界提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringInstanceInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipPointDuringInstanceInCombat", label = "世界提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringInstanceInCombat") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameUnitDuringInstanceInCombat", label = "副本中战斗时的框架单位", tip = "此选项将覆盖副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下的框架单位锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitTypeDuringInstanceInCombat", label = "框架单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringInstanceInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitPointDuringInstanceInCombat", label = "框架单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringInstanceInCombat") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameTipDuringInstanceInCombat", label = "副本中战斗时的框架提示", tip = "此选项将覆盖副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下的框架提示锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipTypeDuringInstanceInCombat", label = "框架提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringInstanceInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipPointDuringInstanceInCombat", label = "框架提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringInstanceInCombat") end });

tinsert(ttOptionsAnchors, { type = "TextOnly", label = "脱离战斗", y = 10 });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldUnitDuringInstance", label = "副本中脱战时的世界单位", tip = "此选项将覆盖副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下的世界单位锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitTypeDuringInstance", label = "世界单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringInstance") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitPointDuringInstance", label = "世界单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringInstance") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldTipDuringInstance", label = "副本中脱战时的世界提示", tip = "此选项将覆盖副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下的世界提示锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipTypeDuringInstance", label = "世界提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringInstance") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipPointDuringInstance", label = "世界提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringInstance") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameUnitDuringInstance", label = "副本中脱战时的框架单位", tip = "此选项将覆盖副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下的框架单位锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitTypeDuringInstance", label = "框架单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringInstance") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitPointDuringInstance", label = "框架单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringInstance") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameTipDuringInstance", label = "副本中脱战时的框架提示", tip = "此选项将覆盖副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下的框架提示锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipTypeDuringInstance", label = "框架提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringInstance") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipPointDuringInstance", label = "框架提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringInstance") end });

if (LibFroznFunctions.hasWoWFlavor.skyriding) then
	priority = priority + 1;
	tinsert(ttOptionsAnchors, { type = "Header", label = "优先级#" .. priority .. ": 驭空术时锚点覆盖", tip = "下方选项可设置在驭空术时候鼠标锚点覆盖", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });

	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldUnitDuringSkyriding", label = "驭空术时的世界单位", tip = "此选项将覆盖驭空术时的世界单位的锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitTypeDuringSkyriding", label = "世界单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringSkyriding") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitPointDuringSkyriding", label = "世界单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringSkyriding") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldTipDuringSkyriding", label = "驭空术时的世界提示", tip = "此选项将覆盖驭空术时的世界提示的锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipTypeDuringSkyriding", label = "世界提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringSkyriding") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipPointDuringSkyriding", label = "世界提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringSkyriding") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameUnitDuringSkyriding", label = "驭空术时的框架单位", tip = "此选项将覆盖驭空术时的框架单位的锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitTypeDuringSkyriding", label = "框架单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringSkyriding") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitPointDuringSkyriding", label = "框架单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringSkyriding") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameTipDuringSkyriding", label = "驭空术时的框架提示", tip = "此选项将覆盖驭空术时的框架提示的锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipTypeDuringSkyriding", label = "框架提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringSkyriding") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipPointDuringSkyriding", label = "框架提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringSkyriding") end });
end

priority = priority + 1;
tinsert(ttOptionsAnchors, { type = "Header", label = " 优先级#" .. priority .. ": 战斗状态锚点覆盖", tip = "下方选项可设置在战斗状态的鼠标锚点覆盖", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldUnitInCombat", label = "战斗状态的世界单位", tip = "此选项将覆盖战斗状态的世界单位的锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitTypeInCombat", label = "世界单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitPointInCombat", label = "世界单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitInCombat") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldTipInCombat", label = "战斗状态的世界提示", tip = "此选项将覆盖战斗状态的世界提示的锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipTypeInCombat", label = "世界提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipPointInCombat", label = "世界提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipInCombat") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameUnitInCombat", label = "战斗状态的框架单位", tip = "此选项将覆盖战斗状态的框架单位的锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitTypeInCombat", label = "框架单位模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitPointInCombat", label = "框架单位定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitInCombat") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameTipInCombat", label = "战斗状态的框架提示", tip = "此选项将覆盖战斗状态的框架提示的锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipTypeInCombat", label = "框架提示模式", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipPointInCombat", label = "框架提示定点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipInCombat") end });

tinsert(ttOptionsAnchors, { type = "Header", label = "特殊类型锚点覆盖", tip = "特殊类型（如下）锚点覆盖", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideCF", label = "(公会和社区、即时通讯插件)聊天框", tip = "此选项将更改(公会和社区)聊天框的锚点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorOverrideCFType", label = "提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideCF") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorOverrideCFPoint", label = "提示点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideCF") end });

tinsert(ttOptionsAnchors, { type = "Header", label = "鼠标跟随设置", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });

tinsert(ttOptionsAnchors, { type = "Slider", var = "mouseOffsetX", label = "鼠标跟随X轴偏移值", min = -200, max = 200, step = 1, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });
tinsert(ttOptionsAnchors, { type = "Slider", var = "mouseOffsetY", label = "鼠标跟随Y轴偏移值", min = -200, max = 200, step = 1, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });

-- Icons
local ttOptionsIcons = {
	{ type = "Header", label = "目标单位提示图标", enabled = function(factory) return factory:GetConfigValue("enableIcons") end },
};

if (LibFroznFunctions.hasWoWFlavor.unitCanBeSecretValue) then
	tinsert(ttOptionsIcons, { type = "Check", var = "iconUnitIsSecretValue", label = "显示\"秘密值属性\"图标", tip = "若目标单位属性为秘密值，则在提示旁显示锁定图标", enabled = function(factory) return factory:GetConfigValue("enableIcons") end });
end

tinsert(ttOptionsIcons, { type = "Check", var = "iconRaid", label = "显示团队标记图标", tip = "在提示旁显示团队标记图标", enabled = function(factory) return factory:GetConfigValue("enableIcons") end });
tinsert(ttOptionsIcons, { type = "Check", var = "iconFaction", label = "显示阵营图标", tip = "若目标单位开启PvP状态，则在提示旁显示阵营图标", enabled = function(factory) return factory:GetConfigValue("enableIcons") end });
tinsert(ttOptionsIcons, { type = "Check", var = "iconCombat", label = "显示战斗状态图标", tip = "若目标单位处于战斗状态，则在提示旁显示战斗图标", enabled = function(factory) return factory:GetConfigValue("enableIcons") end });
tinsert(ttOptionsIcons, { type = "Check", var = "iconClass", label = "显示职业图标", tip = "对玩家单位，将在鼠标提示旁显示职业图标", enabled = function(factory) return factory:GetConfigValue("enableIcons") end });

tinsert(ttOptionsIcons, { type = "Slider", var = "iconSize", label = "图标大小", min = 8, max = 100, step = 1, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) end });
tinsert(ttOptionsIcons, { type = "Slider", var = "iconMaxIcons", label = "最大图标数", min = 1, max = 4, step = 1, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) end });
tinsert(ttOptionsIcons, { type = "DropDown", var = "iconAnchor", label = "图标锚点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) end, y = 10 });
tinsert(ttOptionsIcons, { type = "DropDown", var = "iconAnchorHorizontalAlign", label = "水平对齐", list = DROPDOWN_ANCHORHALIGN, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) and (factory:GetConfigValue("iconAnchor") == "TOP" or factory:GetConfigValue("iconAnchor") == "BOTTOM") end });
tinsert(ttOptionsIcons, { type = "DropDown", var = "iconAnchorVerticalAlign", label = "垂直对齐", list = DROPDOWN_ANCHORVALIGN, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) and (factory:GetConfigValue("iconAnchor") == "LEFT" or factory:GetConfigValue("iconAnchor") == "RIGHT") end });
tinsert(ttOptionsIcons, { type = "DropDown", var = "iconAnchorGrowDirection", label = "延展方向", list = DROPDOWN_ANCHORGROWDIRECTION, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) end });
tinsert(ttOptionsIcons, { type = "Slider", var = "iconOffsetX", label = "图标X轴偏移", min = -200, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) end });
tinsert(ttOptionsIcons, { type = "Slider", var = "iconOffsetY", label = "图标Y轴偏移", min = -200, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) end });

-- Hiding
local ttOptionsHiding = {};
priority = 0;

if (LibFroznFunctions.hasWoWFlavor.challengeMode) then
	priority = priority + 1;
	tinsert(ttOptionsHiding, { type = "Header", var = "hideTipsDuringChallengeModeHeader", label = "优先级#" .. priority .. ": 大秘境中的隐藏鼠标提示设置" });
	
	tinsert(ttOptionsHiding, { type = "TextOnly", var = "hideTipsDuringChallengeModeInCombat", label = "进入战斗", belongsTo = "hideTipsDuringChallengeModeHeader" });

	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatWorldUnits", label = "隐藏世界单位", tip = "在大秘境中战斗状态下隐藏世界单位的鼠标提示.", y = 10, belongsTo = "hideTipsDuringChallengeModeInCombat" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatFrameUnits", label = "隐藏框架单位", tip = "在大秘境中战斗状态下隐藏框架单位的鼠标提示.", x = 160, belongsTo = "hideTipsDuringChallengeModeInCombatWorldUnits" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatWorldTips", label = "隐藏世界提示", tip = "在大秘境中战斗状态下隐藏世界提示.", belongsTo = "hideTipsDuringChallengeModeInCombat" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatFrameTips", label = "隐藏框架提示", tip = "在大秘境中战斗状态下隐藏框架提示.", x = 160, belongsTo = "hideTipsDuringChallengeModeInCombatWorldTips" });
	
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatUnitTips", label = "隐藏所有单位提示", tip = "在大秘境中战斗状态下隐藏世界单位和框架单位的鼠标提示.", y = 10, belongsTo = "hideTipsDuringChallengeModeInCombat" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatSpellTips", label = "隐藏法术提示", tip = "在大秘境中战斗状态下隐藏法术和技能的鼠标提示.", x = 160, belongsTo = "hideTipsDuringChallengeModeInCombatUnitTips" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatItemTips", label = "隐藏物品提示", tip = "在大秘境中战斗状态下隐藏物品的鼠标提示.", belongsTo = "hideTipsDuringChallengeModeInCombat" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatActionTips", label = "隐藏动作条提示", tip = "在大秘境中战斗状态下隐藏动作条的鼠标提示.", belongsTo = "hideTipsDuringChallengeModeInCombat" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatExpBarTips", label = "隐藏经验条提示", tip = "在大秘境中战斗状态下隐藏经验条的鼠标提示.", x = 160, belongsTo = "hideTipsDuringChallengeModeInCombatActionTips" });

	tinsert(ttOptionsHiding, { type = "TextOnly", var = "hideTipsDuringChallengeMode", label = "脱离战斗", y = 10, belongsTo = "hideTipsDuringChallengeModeHeader" });

	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeWorldUnits", label = "隐藏世界单位", tip = "在大秘境中脱战状态下隐藏世界单位的鼠标提示.", y = 10, belongsTo = "hideTipsDuringChallengeMode" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeFrameUnits", label = "隐藏框架单位", tip = "在大秘境中脱战状态下隐藏框架单位的鼠标提示.", x = 160, belongsTo = "hideTipsDuringChallengeModeWorldUnits" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeWorldTips", label = "隐藏世界提示", tip = "在大秘境中脱战状态下隐藏世界提示.", belongsTo = "hideTipsDuringChallengeMode" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeFrameTips", label = "隐藏框架提示", tip = "在大秘境中脱战状态下隐藏框架提示.", x = 160, belongsTo = "hideTipsDuringChallengeModeWorldTips" });

	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeUnitTips", label = "隐藏所有单位提示", tip = "在大秘境中脱战状态下隐藏世界单位和框架单位的鼠标提示.", y = 10, belongsTo = "hideTipsDuringChallengeMode" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeSpellTips", label = "隐藏法术提示", tip = "在大秘境中脱战状态下隐藏法术和技能的鼠标提示.", x = 160, belongsTo = "hideTipsDuringChallengeModeUnitTips" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeItemTips", label = "隐藏物品提示", tip = "在大秘境中脱战状态下隐藏物品的鼠标提示.", belongsTo = "hideTipsDuringChallengeMode" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeActionTips", label = "隐藏动作条提示", tip = "在大秘境中脱战状态下隐藏动作条的鼠标提示.", belongsTo = "hideTipsDuringChallengeMode" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeExpBarTips", label = "隐藏经验条提示", tip = "在大秘境中脱战状态下隐藏经验条的鼠标提示.", x = 160, belongsTo = "hideTipsDuringChallengeModeActionTips" });
end

priority = priority + 1;
tinsert(ttOptionsHiding, { type = "Header", var = "hideTipsDuringInstanceHeader", label = "优先级#" .. priority .. ": 副本中的隐藏鼠标提示设置" });

tinsert(ttOptionsHiding, { type = "TextOnly", var = "hideTipsDuringInstanceInCombat", label = "进入战斗", belongsTo = "hideTipsDuringInstanceHeader" });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatWorldUnits", label = "隐藏世界单位", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下隐藏世界单位的鼠标提示.", y = 10, belongsTo = "hideTipsDuringInstanceInCombat" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatFrameUnits", label = "隐藏框架单位", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下隐藏框架单位的鼠标提示.", x = 160, belongsTo = "hideTipsDuringInstanceInCombatWorldUnits" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatWorldTips", label = "隐藏世界提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下隐藏世界提示.", belongsTo = "hideTipsDuringInstanceInCombat" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatFrameTips", label = "隐藏框架提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下隐藏框架提示.", x = 160, belongsTo = "hideTipsDuringInstanceInCombatWorldTips" });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatUnitTips", label = "隐藏所有单位提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下隐藏世界单位和框架单位的鼠标提示.", y = 10, belongsTo = "hideTipsDuringInstanceInCombat" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatSpellTips", label = "隐藏法术提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下隐藏法术和技能的鼠标提示.", x = 160, belongsTo = "hideTipsDuringInstanceInCombatUnitTips" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatItemTips", label = "隐藏物品提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下隐藏物品的鼠标提示.", belongsTo = "hideTipsDuringInstanceInCombat" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatActionTips", label = "隐藏动作条提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下隐藏动作条的鼠标提示." , belongsTo = "hideTipsDuringInstanceInCombat"});
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatExpBarTips", label = "隐藏经验条提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下隐藏经验条的鼠标提示.", x = 160, belongsTo = "hideTipsDuringInstanceInCombatActionTips" });

tinsert(ttOptionsHiding, { type = "TextOnly", var = "hideTipsDuringInstance", label = "脱离战斗", y = 10, belongsTo = "hideTipsDuringInstanceHeader" });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceWorldUnits", label = "隐藏世界单位", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下隐藏世界单位的鼠标提示.", y = 10, belongsTo = "hideTipsDuringInstance" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceFrameUnits", label = "隐藏框架单位", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下隐藏框架单位的鼠标提示.", x = 160, belongsTo = "hideTipsDuringInstanceWorldUnits" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceWorldTips", label = "隐藏世界提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下隐藏世界提示.", belongsTo = "hideTipsDuringInstance" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceFrameTips", label = "隐藏框架提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下隐藏框架提示.", x = 160, belongsTo = "hideTipsDuringInstanceWorldTips" });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceUnitTips", label = "隐藏所有单位提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下隐藏世界单位和框架单位的鼠标提示.", y = 10, belongsTo = "hideTipsDuringInstance" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceSpellTips", label = "隐藏法术提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下隐藏法术和技能的鼠标提示.", x = 160, belongsTo = "hideTipsDuringInstanceUnitTips" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceItemTips", label = "隐藏物品提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下隐藏物品的鼠标提示.", belongsTo = "hideTipsDuringInstance" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceActionTips", label = "隐藏动作条提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下隐藏动作条的鼠标提示.", belongsTo = "hideTipsDuringInstance" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceExpBarTips", label = "隐藏经验条提示", tip = "在副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中脱战状态下隐藏经验条的鼠标提示.", x = 160, belongsTo = "hideTipsDuringInstanceActionTips" });

if (LibFroznFunctions.hasWoWFlavor.skyriding) then
	priority = priority + 1;
	tinsert(ttOptionsHiding, { type = "Header", var = "hideTipsDuringSkyridingHeader", label = "优先级#" .. priority .. ": 在驭空术时隐藏鼠标提示设置" });
	
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingWorldUnits", label = "隐藏世界单位", tip = "在驭空术时隐藏世界单位的鼠标提示.", belongsTo = "hideTipsDuringSkyridingHeader" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingFrameUnits", label = "隐藏框架单位", tip = "在驭空术时隐藏框架单位的鼠标提示.", x = 160, belongsTo = "hideTipsDuringSkyridingWorldUnits" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingWorldTips", label = "隐藏世界提示", tip = "在驭空术时隐藏世界提示.", belongsTo = "hideTipsDuringSkyridingHeader" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingFrameTips", label = "隐藏框架提示", tip = "在驭空术时隐藏框架提示.", x = 160, belongsTo = "hideTipsDuringSkyridingWorldTips" });
	
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingUnitTips", label = "隐藏所有单位提示", tip = "在驭空术时隐藏世界单位和框架单位的鼠标提示.", y = 10, belongsTo = "hideTipsDuringSkyridingHeader" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingSpellTips", label = "隐藏法术提示", tip = "在驭空术时隐藏法术和技能的鼠标提示.", x = 160, belongsTo = "hideTipsDuringSkyridingUnitTips" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingItemTips", label = "隐藏物品提示", tip = "在驭空术时隐藏物品的鼠标提示.", belongsTo = "hideTipsDuringSkyridingHeader" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingActionTips", label = "隐藏动作条提示", tip = "在驭空术时隐藏动作条的鼠标提示.", belongsTo = "hideTipsDuringSkyridingHeader" });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingExpBarTips", label = "隐藏经验条提示", tip = "在驭空术时隐藏经验条条的鼠标提示.", x = 160, belongsTo = "hideTipsDuringSkyridingActionTips" });
end

priority = priority + 1;
tinsert(ttOptionsHiding, { type = "Header", var = "hideTipsInCombatHeader", label = "优先级#" .. priority .. ": 在战斗状态隐藏鼠标提示设置" });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatWorldUnits", label = "隐藏世界单位", tip = "在战斗状态隐藏世界单位的鼠标提示.", belongsTo = "hideTipsInCombatHeader" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatFrameUnits", label = "隐藏框架单位", tip = "在战斗状态隐藏框架单位的鼠标提示.", x = 160, belongsTo = "hideTipsInCombatWorldUnits" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatWorldTips", label = "隐藏世界提示", tip = "在战斗状态隐藏世界提示.", belongsTo = "hideTipsInCombatHeader" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatFrameTips", label = "隐藏框架提示", tip = "在战斗状态隐藏框架提示.", x = 160, belongsTo = "hideTipsInCombatWorldTips" });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatUnitTips", label = "隐藏所有单位提示", tip = "在战斗状态隐藏世界单位和框架单位的鼠标提示.", y = 10, belongsTo = "hideTipsInCombatHeader" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatSpellTips", label = "隐藏法术提示", tip = "在战斗状态隐藏法术和技能的鼠标提示.", x = 160, belongsTo = "hideTipsInCombatUnitTips" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatItemTips", label = "隐藏物品提示", tip = "在战斗状态隐藏物品的鼠标提示.", belongsTo = "hideTipsInCombatHeader" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatActionTips", label = "隐藏动作条提示", tip = "在战斗状态隐藏动作条的鼠标提示", belongsTo = "hideTipsInCombatHeader" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatExpBarTips", label = "隐藏经验条提示", tip = "在战斗状态隐藏经验条条的鼠标提示.", x = 160, belongsTo = "hideTipsInCombatActionTips" });

tinsert(ttOptionsHiding, { type = "Header", var = "hideTipsHeader", label = "优先级#" .. priority .. ": 在非战斗状态隐藏鼠标提示设置" });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsWorldUnits", label = "隐藏世界单位", tip = "在非战斗状态隐藏世界单位的鼠标提示.", belongsTo = "hideTipsHeader" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsFrameUnits", label = "隐藏框架单位", tip = "在非战斗状态隐藏框架单位的鼠标提示.", x = 160, belongsTo = "hideTipsWorldUnits" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsWorldTips", label = "隐藏世界提示", tip = "在非战斗状态隐藏世界提示.", belongsTo = "hideTipsHeader" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsFrameTips", label = "隐藏框架提示", tip = "在非战斗状态隐藏框架提示.", x = 160, belongsTo = "hideTipsWorldTips" });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsUnitTips", label = "隐藏所有单位提示", tip = "在非战斗状态隐藏世界单位和框架单位的鼠标提示.", y = 10, belongsTo = "hideTipsHeader" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsSpellTips", label = "隐藏法术提示", tip = "在非战斗状态隐藏法术和技能的鼠标提示.", x = 160, belongsTo = "hideTipsUnitTips" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsItemTips", label = "隐藏物品提示", tip = "在非战斗状态隐藏物品的鼠标提示.", belongsTo = "hideTipsHeader" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsActionTips", label = "隐藏动作条提示", tip = "在非战斗状态隐藏动作条的鼠标提示.", belongsTo = "hideTipsHeader" });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsExpBarTips", label = "隐藏经验条提示", tip = "在非战斗状态隐藏经验条条的鼠标提示.", x = 160, belongsTo = "hideTipsActionTips" });

if (LibFroznFunctions:IsAddOnEnabled("Blizzard_EncounterJournal")) then
	tinsert(ttOptionsHiding, { type = "Header", label = "隐藏其他提示" });

	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsEJDungeonRaidSetItemsSTT", label = "在冒险指南中隐藏地下城/团队副本/套装物品\n的购物提示", tip = "勾选此选项后，冒险指南中的地下城/团队副本/套装物品购物时已装备或已拥有的提示将被隐藏。" });
end

tinsert(ttOptionsHiding, { type = "Header", label = "其他" });

tinsert(ttOptionsHiding, { type = "DropDown", var = "showHiddenModifierKey", label = "长按\n始终显示提示", list = { ["Shift"] = "shift", ["Ctrl"] = "ctrl", ["Alt"] = "alt", ["|cffffa0a0None"] = "无" } });
tinsert(ttOptionsHiding, { type = "TextOnly", label = "", y = -12 }); -- spacer for multi-line label above

-- build options
local options = {
	-- General
	{
		category = "综合",
		options = ttOptionsGeneral
	},
	-- Colors
	{
		category = "颜色",
		options = ttOptionsColors
	},
	-- Reactions
	{
		category = "目标信息",
		options = {
			{ type = "Check", var = "reactColoredBorder", label = "按目标声望关系着色边框", tip = "对于玩家而言，边框颜色将依据单位的声望友好/中立/敌对关系进行着色\n注意:此选项会被职业颜色边框功能覆盖.", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			{ type = "Check", var = "reactIcon", label = "图标显示目标信息", tip = "将在鼠标提示内显示的等级位置添加一个图标显示目标信息", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			
			{ type = "Check", var = "reactText", label = "显示目标信息文本", tip = "将在鼠标提示内添加目标信息文本,你可以在下方选择颜色.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 },
			{ type = "Color", var = "colorReactText", label = "目标属性文本颜色", tip = "你可以在这里选择目标信息文本的颜色.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("reactText") end },
			
			{ type = "Check", var = "reactColoredText", label = "目标信息文本颜色基于下方属性设置", tip = "目标信息文本颜色将基于下方属性分类颜色显示.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("reactText") end },
			
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.tapped, label = "低等级目标颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.hostile, label = "敌对目标颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.caution, label = "高等级目标颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.neutral, label = "中立目标颜色" , enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.friendlyPlayer, label = "友善玩家角色颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.friendlyPvPPlayer, label = "开启PVP的友善玩家角色颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.friendlyNPC, label = "NPC声望友善颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.honoredNPC, label = "NPC声望尊敬颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.reveredNPC, label = "NPC声望崇敬颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.exaltedNPC, label = "NPC声望崇拜颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.dead, label = "已死亡目标颜色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
		}
	},
	-- BG Color
	{
		category = "背景颜色",
		options = {
			{ type = "Check", var = "reactColoredBackdrop", label = "背景颜色基于目标属性", tip = "如果需要鼠标提示的背景色将被取决于自定义的目标状态属性颜色，请开启此选项；关闭此选项，鼠标提示的背景色将会使用背景标签页设置的颜色.", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.tapped, label = "低等级目标颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end, y = 10 },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.hostile, label = "敌对目标颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.caution, label = "高等级目标颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.neutral, label = "中立目标颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.friendlyPlayer, label = "友善玩家角色颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.friendlyPvPPlayer, label = "开启PVP的友善玩家角色颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.friendlyNPC, label = "NPC声望友善颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.honoredNPC, label = "NPC声望尊敬颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.reveredNPC, label = "NPC声望崇敬颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.exaltedNPC, label = "NPC声望崇拜颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.dead, label = "已死亡目标颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
		}
	},
	-- Backdrop
	{
		category = "背景",
		enabled = { type = "Check", var = "enableBackdrop", tip = "打开或关闭背景的所有更改\n注意:重新加载UI(/Reload)后设置才会生效." },
		options = {
			{ type = "DropDown", var = "tipBackdropBG", label = "背景材质", media = "background", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			{ type = "DropDown", var = "tipBackdropBGLayout", label = "背景材质样式", list = { ["重复铺垫"] = "tile", ["拉伸铺垫"] = "stretch" }, enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			{ type = "DropDown", var = "tipBackdropEdge", label = "边框材质", media = "border", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },

			{ type = "Slider", var = "backdropEdgeSize", label = "背景边缘大小", min = -20, max = 64, step = 0.5, enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end, y = 10 },
			{ type = "Slider", var = "backdropInsets", label = "背景插图", min = -20, max = 20, step = 0.5, enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			{ type = "Check", var = "pixelPerfectBackdrop", label = "像素完美的背景边缘尺寸和插图", tip = "背景边缘大小和插图与实际像素相对应", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end, y = 10 },
			
			{ type = "Color", var = "tipColor", label = "鼠标提示背景颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end, y = 10 },
			{ type = "Color", var = "tipBorderColor", label = "鼠标提示边框颜色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end, x = 160, belongsTo = "tipColor" },
			{ type = "Check", var = "gradientTip", label = "显示渐变工具提示", tip = "在提示顶部显示一个小渐变区域, 为其添加一个小的3D效果. 如果您有Skinner这样的插件, 您可能希望禁用它以避免冲突", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			{ type = "Color", var = "gradientColor", label = "渐变颜色", tip = "选择渐变的基色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("gradientTip") end, x = 160, belongsTo = "gradientTip" },
			{ type = "Slider", var = "gradientHeight", label = "渐变高度", min = 0, max = 64, step = 0.5, enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("gradientTip") end },
		}
	},
	-- Font
	{
		category = "字体",
		enabled = { type = "Check", var = "modifyFonts", tip = "如果想更改" .. PARENT_MOD_NAME .. " 字体样式请开启此选项.|cffff0b0b\n注意:如果你有加载类似于ClearFont的插件,请关闭此选项以避免冲突." },
		options = {
			{ type = "DropDown", var = "fontFace", label = "字体", media = "font", enabled = function(factory) return factory:GetConfigValue("modifyFonts") end },
			{ type = "DropDown", var = "fontFlags", label = "字体样式", list = DROPDOWN_FONTFLAGS, enabled = function(factory) return factory:GetConfigValue("modifyFonts") end },
			{ type = "Slider", var = "fontSize", label = "字体大小", min = 6, max = 29, step = 1, enabled = function(factory) return factory:GetConfigValue("modifyFonts") end },
			
			{ type = "Slider", var = "fontSizeDeltaHeader", label = "标题字体大小缩放", min = -10, max = 10, step = 1, enabled = function(factory) return factory:GetConfigValue("modifyFonts") end, y = 10 },
			{ type = "Slider", var = "fontSizeDeltaSmall", label = "目标名称字体大小缩放", min = -10, max = 10, step = 1, enabled = function(factory) return factory:GetConfigValue("modifyFonts") end },
		}
	},
	-- Classify
	{
		category = "生物类型",
		options = {
			{ type = "Text", var = "classification_minus", label = "负等级" },
			{ type = "Text", var = "classification_trivial", label = "弱小" },
			{ type = "Text", var = "classification_normal", label = "普通" },
			{ type = "Text", var = "classification_elite", label = "精英" },
			{ type = "Text", var = "classification_worldboss", label = "首领" },
			{ type = "Text", var = "classification_rare", label = "稀有" },
			{ type = "Text", var = "classification_rareelite", label = "稀有精英" },
		}
	},
	-- Fading
	{
		category = "特效",
		options = {
			{ type = "Header", label = "单位提示渐隐淡出" },
			
			{ type = "Check", var = "overrideFade", label = "无视默认游戏鼠标提示特效", tip = "启用此选项将无视默认的游戏鼠标提示渐隐.|cffff0b0b\n注意：如出现了渐出渐入相关问题，请关闭此选项." },
			
			{ type = "Slider", var = "preFadeTime", label = "消失延迟时间", min = 0, max = 5, step = 0.05, enabled = function(factory) return factory:GetConfigValue("overrideFade") end, y = 10 },
			{ type = "Slider", var = "fadeTime", label = "渐出时间", min = 0, max = 5, step = 0.05, enabled = function(factory) return factory:GetConfigValue("overrideFade") end },
			
			{ type = "Header", label = "例外" },
			
			{ type = "Check", var = "hideWorldTips", label = "世界物品信息提示立即隐藏", tip = "启用此选项将使世界物品提示在鼠标移开物品之后立即消失.（例如：邮箱、药草、矿脉等）|cffff0b0b\n注意：并不是作用在所有世界物品上." },
		}
	},
	-- Bars
	{
		category = "信息条",
		enabled = { type = "Check", var = "enableBars", tip = "启用Tiptac鼠标提示信息条" },
		options = {
			{ type = "Header", label = "生命值", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			
			{ type = "Check", var = "healthBar", label = "显示生命条", tip = "将会显示目标的生命条." .. (LibFroznFunctions.hasWoWFlavor.unitCanBeSecretValue and ".\n注意：若目标单位为秘密值属性，将降级使用原生默认血条。" or ""), enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			{ type = "DropDown", var = "healthBarText", label = "生命条文本", list = DROPDOWN_BARTEXTFORMAT, enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("healthBar") end },
			{ type = "Color", var = "healthBarColor", label = "生命条颜色", tip = "生命条的颜色. 如果启用了右边的选项此颜色将不会用作于鼠标提示信息上", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("healthBar") end },
			{ type = "Check", var = "healthBarClassColor", label = "生命条职业染色", tip = "启用此选项将会使生命条以角色职业色显示", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("healthBar") end, y = 2, x = 130, belongsTo = "healthBarColor" },
			--{ type = "Check", var = "hideDefaultBar", label = "隐藏默认生命条", tip = "启用此选项以隐藏默认生命条", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			{ type = "Check", var = "hideDefaultBar", label = "隐藏默认生命条", tip = "启用此选项以隐藏默认生命条" .. (LibFroznFunctions.hasWoWFlavor.unitCanBeSecretValue and ".\n注意：若该单位为秘密值属性且已启用血条显示，则降级使用原生默认血条。" or ""), enabled = function(factory) return factory:GetConfigValue("enableBars") end },			
			
			{ type = "Header", label = "法力值", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			
			{ type = "Check", var = "manaBar", label = "显示法力条", tip = "如果目标有法力将会显示法力条.", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			{ type = "DropDown", var = "manaBarText", label = "法力条文本", list = DROPDOWN_BARTEXTFORMAT, enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("manaBar") end },
			{ type = "Color", var = "manaBarColor", label = "法力条颜色", tip = "The color of the mana bar", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("manaBar") end },
			
			{ type = "Header", label = "其他类型资源", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			
			{ type = "Check", var = "powerBar", label = "显示能量、怒气、符文或集中值信息条", tip = "如果目标单位使用能量、怒气、符文能量或集中值则会显示能量信息条.", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			{ type = "DropDown", var = "powerBarText", label = "能量条信息模式", list = DROPDOWN_BARTEXTFORMAT, enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("powerBar") end },
			
			{ type = "Header", label = "施法条", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			
			{ type = "Check", var = "castBar", label = "显示施法条", tip = "当目标施法时在鼠标提示中显示目标施法条.", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			{ type = "Check", var = "castBarAlwaysShow", label = "始终显示施法条", tip = "无论目标有没有施法都显示施法条", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end, x = 130, belongsTo = "castBar" },
			{ type = "Color", var = "castBarCastingColor", label = "施法条颜色", tip = "选择施法条颜色r", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end, y = 10 },
			{ type = "Color", var = "castBarChannelingColor", label = "引导法术颜色", tip = "选择引导法术颜色", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end },
			{ type = "Color", var = "castBarChargingColor", label = "蓄力法术颜色", tip = "选择蓄力法术颜色", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end },
			{ type = "Color", var = "castBarCompleteColor", label = "施放完成颜色", tip = "法术施放完成颜色", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end },
			{ type = "Color", var = "castBarFailColor", label = "施放失败颜色", tip = "法术施放中断/失败颜色", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end },
			{ type = "Color", var = "castBarSparkColor", label = "Sprak法术颜色", tip = "The spark color of the cast bar", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end },
		
			{ type = "Header", var = "unitTipBarsOthersHeader", label = "其他单位提示", enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end },
		
			{ type = "Check", var = "barsCondenseValues", label = "显示缩写数值", tip = "启用此选项以缩写的数值作用于信息条上.(例如:57254将会被显示为57.3K)", enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar")) end },
			
			{ type = "DropDown", var = "barFontFace", label = "字体", media = "font", enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end, y = 10 },
			{ type = "DropDown", var = "barFontFlags", label = "字体样式", list = DROPDOWN_FONTFLAGS, enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end },
			{ type = "Slider", var = "barFontSize", label = "字体大小", min = 6, max = 29, step = 1, enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end },
			
			{ type = "DropDown", var = "barTexture", label = "信息条材质", media = "statusbar", enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end, y = 10 },
			{ type = "Slider", var = "barHeight", label = "信息条高度", min = 1, max = 50, step = 1, enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end },
			
			{ type = "Check", var = "barEnableTipMinimumWidth", label = "信息条宽度设置", tip = "启用后可设置信息条宽度，信息条最小宽度和鼠标提示宽度相同.", enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end, y = 10 },
			{ type = "Slider", var = "barTipMinimumWidth", label = "信息条宽度", min = 10, max = 500, step = 5, enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) and factory:GetConfigValue("barEnableTipMinimumWidth") end },
		}
	},
	-- Auras
	{
		category = "光环",
		enabled = { type = "Check", var = "enableAuras", tip = "启用鼠标提示Buff/Debuff" },
		options = ttOptionsAuras
	},
	-- Icon
	{
		category = "图标",
		enabled = { type = "Check", var = "enableIcons", tip = "启用鼠标提示额外图标" },
		options = ttOptionsIcons
	},
	-- Anchors
	{
		category = "锚点",
		enabled = { type = "Check", var = "enableAnchor", tip = "启用锚点位置设置，关闭将使用暴雪默认位置" },
		options = ttOptionsAnchors
	},
	-- Hiding
	{
		category = "隐藏提示",
		options = ttOptionsHiding
	},
	-- Hyperlink
	{
		category = "超链接",
		enabled = { type = "Check", var = "enableChatHoverTips", label = "启用聊天框悬停超链接", tip = "将鼠标悬停在聊天框中的某个链接上时, 无需点击即可显示工具提示" }
 	},
};

-- TipTacTalents Support
local TipTacTalents = _G[PARENT_MOD_NAME .. "Talents"];

if (TipTacTalents) then
	local tttOptions = {
		{ type = "Header", label = "专精", enabled = function(factory) return factory:GetConfigValue("t_enable") end }
	};
	
	option = { type = "Check", var = "t_showTalents", label = "显示专精", tip = "当目标为玩家角色时将会显示天赋专精信息", enabled = function(factory) return factory:GetConfigValue("t_enable") end };
	if (not LibFroznFunctions.hasWoWFlavor.talentsAvailableForInspectedUnit) then
		option.tip = option.tip .. ".\n注意: 在经典怀旧服中，无法查看其他玩家的天赋，只能显示自己的天赋（10级时可用）";
	end
	tinsert(tttOptions, option);
	
	if (LibFroznFunctions.hasWoWFlavor.roleIconAvailable) then
		tinsert(tttOptions, { type = "Check", var = "t_showRoleIcon", label = "显示职责图标", tip = "将在鼠标提示内显示职责图标(坦克, 输出, 治疗)", enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showTalents") end });
	end
	if (LibFroznFunctions.hasWoWFlavor.talentIconAvailable) then
		tinsert(tttOptions, { type = "Check", var = "t_showTalentIcon", label = "显示专精图标", tip = "将在鼠标提示内显示专精图标", enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showTalents") end });
	end
	
	tinsert(tttOptions, { type = "Check", var = "t_showTalentText", label = "显示天赋点数", tip = "将在鼠标提示内显示目标角色在该专精的天赋点数配置", enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showTalents") end, y = 10 });
	tinsert(tttOptions, { type = "Check", var = "t_colorTalentTextByClass", label = "按职业颜色显示专精文本颜色", tip = "启用此选项后, 专精文本颜色将按职业颜色着色", enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showTalents") and factory:GetConfigValue("t_showTalentText") end });
	
	if (LibFroznFunctions.hasWoWFlavor.numTalentTrees > 0) then
		if (LibFroznFunctions.hasWoWFlavor.numTalentTrees == 2) then
			tinsert(tttOptions, { type = "DropDown", var = "t_talentFormat", label = "专精文本样式", list = { ["|ccf0070DD元素 |ccfffff77(31/30)"] = 1, ["|ccf0070DD元素"] = 2, ["|ccfffff7731/30"] = 3,}, enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showTalents") and factory:GetConfigValue("t_showTalentText") end }); -- not supported with MoP changes
		else
			tinsert(tttOptions, { type = "DropDown", var = "t_talentFormat", label = "专精文本样式", list = { ["|ccf0070DD元素|ccfffff77 (57/14/0)"] = 1, ["|ccf0070DD元素"] = 2, ["|ccfffff7757/14/0"] = 3,}, enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showTalents") and factory:GetConfigValue("t_showTalentText") end }); -- not supported with MoP changes
		end
	end
	
	tinsert(tttOptions, { type = "Header", label = "平均装等", enabled = function(factory) return factory:GetConfigValue("t_enable") end });
	
	tinsert(tttOptions, { type = "Check", var = "t_showAverageItemLevel", label = "显示平均装等(AIL)", tip = "将在鼠标提示内显示其他玩家的平均装等(AIL)", enabled = function(factory) return factory:GetConfigValue("t_enable") end });
	
	tinsert(tttOptions, { type = "Check", var = "t_showGearScore", label = "显示GearScore评分", tip = "将在鼠标提示内显示目标角色GearScore评分", enabled = function(factory) return factory:GetConfigValue("t_enable") end, y = 10 });
	tinsert(tttOptions, { type = "DropDown", var = "t_gearScoreAlgorithm", label = "GearScore算法", list = { ["TacoTip"] = { value = LFF_GEAR_SCORE_ALGORITHM.TacoTip, tip = "使用TacoTip鼠标提示插件的计算方法" }, ["TipTac"] = { value = LFF_GEAR_SCORE_ALGORITHM.TipTac, tip = "使用".. PARENT_MOD_NAME .. "鼠标提示插件的计算方法" },}, tip = "选择GearScore评分计算方法", enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showGearScore") end });
	
	tinsert(tttOptions, { type = "Check", var = "t_colorAILAndGSTextByQuality", label = "装等文本颜色和装备品质相同", tip = "绿装绿色、蓝装蓝色、紫装紫色。", enabled = function(factory) return factory:GetConfigValue("t_enable") and (factory:GetConfigValue("t_showAverageItemLevel") or factory:GetConfigValue("t_showGearScore")) end, y = 10 });

	tinsert(tttOptions, { type = "Header", label = "其他选项" });

	tinsert(tttOptions, { type = "Check", var = "t_talentOnlyInParty", label = "只显示在团队或小队中玩家角色的\n专精和装等信息", tip = "如启用此选项, 只有处于你所在团队或小队中时才会显示玩家专精和装等信息", enabled = function(factory) return factory:GetConfigValue("t_enable") and (factory:GetConfigValue("t_showTalents") or factory:GetConfigValue("t_showAverageItemLevel") or factory:GetConfigValue("t_showGearScore")) end });
	tinsert(tttOptions, { type = "Check", var = "t_talentDontShowOutOfRange", label = "不显示超出距离玩家角色的专精和\n装等信息", tip = "如启用此选项, 将不会显示超出距离以外玩家的专精和装等信息，并且会提示 \"超出距离\" ", enabled = function(factory) return factory:GetConfigValue("t_enable") and (factory:GetConfigValue("t_showTalents") or factory:GetConfigValue("t_showAverageItemLevel") or factory:GetConfigValue("t_showGearScore")) end, y = 10 });
	
	tinsert(options, {
		category = "专精 & 装等",
		enabled = { type = "Check", var = "t_enable", tip = "打开或关闭TipTacTalents插件的所有功能" },
		options = tttOptions
	});
end

-- TipTacItemRef Support -- Az: this category page is full -- Frozn45: added scroll frame to config options. the scroll bar appears automatically, if content doesn't fit completely on the page.
local TipTacItemRef = _G[PARENT_MOD_NAME .. "ItemRef"];

if (TipTacItemRef) then
	local ttifOptions = {
		{ type = "Color", var = "if_infoColor", label = "额外信息颜色", tip = "选择物品信息在鼠标提示内的文本颜色", enabled = function(factory) return factory:GetConfigValue("if_enable") end },

		{ type = "Check", var = "if_itemQualityBorder", label = "显示物品品质颜色边框", tip = "启用此选项将会使TipTac物品提示的边框基于选中的物品品质", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 },
		{ type = "Check", var = "if_showItemLevel", label = "显示物品等级", tip = "在鼠标提示中显示物品等级(与物品编号组合).\n注意:这将删除鼠标提示中默认显示的物品等级文本", enabled = function(factory) return factory:GetConfigValue("if_enable") end },
		{ type = "Check", var = "if_showItemId", label = "显示物品ID", tip = "在鼠标提示中显示物品编号(与物品等级组合)", enabled = function(factory) return factory:GetConfigValue("if_enable") end, x = 160, belongsTo = "if_showItemLevel" }
	};
	
	if (LibFroznFunctions.hasWoWFlavor.relatedExpansionForItemAvailable) then
		tinsert(ttifOptions, { type = "Check", var = "if_showExpansionIcon", label = "显示资料片图标", tip = "在鼠标提示内以图标方式显示物品源自哪个版本", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
		tinsert(ttifOptions, { type = "Check", var = "if_showExpansionName", label = "显示资料片名称", tip = "在鼠标提示内以文本方式显示物品源自哪个版本", enabled = function(factory) return factory:GetConfigValue("if_enable") end, x = 160, belongsTo = "if_showExpansionIcon" });
	end

	tinsert(ttifOptions, { type = "Check", var = "if_showItemEnchantId", label = "显示物品附魔ID", tip = "在物品提示窗口中显示物品附魔ID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showItemEnchantInfo", label = "显示物品附魔信息", tip = "在物品提示窗口中显示物品附魔详细信息", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_showKeystoneRewardLevel", label = "显示钥石(每周)奖励等级", tip = "对于钥石提示显示其奖励级别和每周奖励级别", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showKeystoneTimeLimit", label = "显示钥石时间限制", tip = "对于钥石提示显示副本时间限制", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showKeystoneAffixInfo", label = "显示钥石词缀信息", tip = "对于钥石提示显示词缀信息", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_modifyKeystoneTips", label = "更改钥石提示", tip = "更改钥石提示以显示更多信息\n警告:可能与其它钥石插件冲突", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_spellColoredBorder", label = "显示技能&法术颜色边框", tip = "当显示技能提示时，提示边框将显示标准的技能颜色", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showSpellIdAndRank", label = "显示技能&法术ID与类型", tip = "在鼠标提示中显示技能编号与技能类型", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_auraSpellColoredBorder", label = "显示光环提示颜色边框", tip = "当启用显示Buff或Debuff时, 提示边框将显示标准的法术颜色", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showAuraSpellIdAndRank", label = "显示光环技能&法术ID和等级", tip = "对于Buff和Debuff提示，显示它们的技能编号和技能等级", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showMawPowerId", label = "显示心能之力编号", tip = "对于技能和光环提示，显示它们的心能之力编号", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_showAuraCaster", label = "显示技能的施放者", tip = "当鼠标选中Buff/Debuff时将会在额外一行当中显示施放者", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_colorAuraCasterByReaction", label = "根据目标属性颜色显示施放者名称", tip = "Buff/Debuff施放者文本颜色基于目标属性\n注意: 此选项会被下方职业颜色选项所覆盖", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showAuraCaster") end });
	tinsert(ttifOptions, { type = "Check", var = "if_colorAuraCasterByClass", label = "根据目标职业颜色显示施放者名称", tip = "Buff/Debuff施放者文本颜色基于目标职业\n注意: 此选项会被下方职业颜色选项所覆盖", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showAuraCaster") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_showNpcId", label = "显示NPC ID", tip = "鼠标提示中显示NPC和战斗宠物的编号", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showMountId", label = "显示坐骑ID", tip = "鼠标提示中显示坐骑ID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });

	if (LibFroznFunctions:IsAddOnEnabled("Blizzard_GlyphUI")) then
		tinsert(ttifOptions, { type = "Check", var = "if_showGlyphId", label = "显示字符ID", tip = "显示字符提示信息中的字符ID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	end
	
	tinsert(ttifOptions, { type = "Check", var = "if_questDifficultyBorder", label = "显示任务提示颜色边框", tip = "当启用并且显示任务提示时，提示边框将具有任务难度的颜色", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showQuestLevel", label = "显示任务等级", tip = "对于任务工具提示，显示他们的任务等级(与任务编号相结合)", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showQuestId", label = "显示任务ID", tip = "对于任务工具提示，显示他们的任务编号(与任务等级相结合)", enabled = function(factory) return factory:GetConfigValue("if_enable") end, x = 160, belongsTo = "if_showQuestLevel" });
	
	tinsert(ttifOptions, { type = "Check", var = "if_currencyQualityBorder", label = "显示货币及其品质颜色边框提示", tip = "当启用显示货币提示时，提示边框将显示货币品质的颜色", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showCurrencyId", label = "显示货币ID", tip = "货币物品将显示其编号", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_achievmentColoredBorder", label = "显示成就提示颜色边框", tip = "当启用显示成就提示时，提示边框将显示标准成就颜色", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showAchievementIdAndCategoryId", label = "显示成就ID与分类", tip = "在成就鼠标提示中显示成就编号与分类", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_modifyAchievementTips", label = "修改成就鼠标提示", tip = "更改成就工具提示以显示更多信息\n警告：可能与其他成就插件冲突", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_battlePetQualityBorder", label = "显示战斗宠物品质颜色边框", tip = "当启用显示战斗宠物提示时，提示边框将具有战斗宠物的颜色", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showBattlePetLevel", label = "显示战斗宠物等级", tip = "在战斗宠物对战中显示它们的宠物等级(与宠物编号相结合)", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_battlePetAbilityColoredBorder", label = "显示战斗宠物技能提示颜色边框", tip = "当启用并且显示战斗宠物能力提示时，提示边框将显示标准的战斗宠物技能颜色", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showBattlePetAbilityId", label = "显示战斗宠物技能ID", tip = "在战斗宠物技能提示中显示技能的编号", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_transmogAppearanceItemQualityBorder", label = "显示幻化物品品质颜色边框", tip = "当启用时幻化物品提示将按物品品质显示颜色边框", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showTransmogAppearanceItemId", label = "显示幻化物品ID", tip = "在幻化物品提示中显示物品的编号", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_transmogIllusionColoredBorder", label = "显示武器附魔品质颜色边框", tip = "当启用时武器附魔提示将按武器附魔品质显示颜色边框", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showTransmogIllusionId", label = "显示武器附魔ID", tip = "在武器附魔提示中显示武器附魔的编号", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_transmogSetQualityBorder", label = "显示幻化套装品质颜色边框", tip = "当启用时幻化套装提示将按套装品质显示颜色边框", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showTransmogSetId", label = "显示幻化套装ID", tip = "在套装提示中显示幻化套装编号", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_conduitQualityBorder", label = "显示导灵器品质颜色边框", tip = "当启用时导灵器提示将按导灵器品质显示颜色边框", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showConduitItemLevel", label = "显示传导器物品等级", tip = "在显示导灵器提示时显示导灵器的物品等级(与导灵器编号相结合)", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showConduitId", label = "显示导灵器ID", tip = "在显示导灵器提示时显示导灵器的编号(与导灵器物品等级相结合)", enabled = function(factory) return factory:GetConfigValue("if_enable") end, x = 160, belongsTo = "if_showConduitItemLevel" });
	
	tinsert(ttifOptions, { type = "Check", var = "if_azeriteEssenceQualityBorder", label = "显示艾泽拉斯之心精华提示颜色边框", tip = "在艾泽拉斯之心精华提示中显示艾泽里特之力颜色边框", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showAzeriteEssenceId", label = "显示艾泽拉斯之心精华ID", tip = "在艾泽拉斯之心提示中显示精华编号", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_runeforgePowerColoredBorder", label = "显示传说之力颜色边框", tip = "当启用时冒险指南中传说之力提示将按传说之力品质显示颜色边框", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showRuneforgePowerId", label = "显示传说之力ID", tip = "在传说之力提示中显示传说之力编号", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_flyoutColoredBorder", label = "显示带有颜色边框的弹出式工具提示", tip = "在弹出式工具中显示技能颜色边框", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showFlyoutId", label = "显示弹出式工具ID", tip = "对于弹出式工具提示显示其弹出式工具编号", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_petActionColoredBorder", label = "显示宠物动作提示颜色边框", tip = "当启用显示宠物动作提示时，提示边框将显示标准的技能颜色", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showPetActionId", label = "显示宠物动作ID", tip = "对于弹出工具提示显示其宠物动作编号", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_showInstanceLockDifficulty", label = "显示副本锁定难度", tip = "For instance lock tooltips, show their difficulty", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	
	tinsert(ttifOptions, { type = "Header", label = "图标", tip = "关于工具提示图标的设置", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_showIcon", label = "显示图标材质与堆叠数量(可用时)", tip = "在鼠标提示中显示图标. 对于物品在可用时将显示其堆叠数量", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_smartIcons", label = "智能图标外观", tip = "启用时, TipTacItemRef将根据提示的显示位置确定是否需要图标. 例如, 它不会显示在操作栏或包槽上, 因为它们已经显示了一个图标", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	tinsert(ttifOptions, { type = "Check", var = "if_smartIconsShowStackCount", label = "始终显示可堆叠计数的图标", tip = "启用后，若存在堆叠计数，则将始终显示该图标。", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") and factory:GetConfigValue("if_smartIcons") end });
	tinsert(ttifOptions, { type = "DropDown", var = "if_stackCountToTooltip", label = "显示堆叠数量", list = { ["|cffffa0a0不显示"] = "none", ["永远显示"] = "always", ["只有图标不显示时"] = "noicon" }, enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showIconId", label = "显示图标ID", tip = "在鼠标提示中显示图标编号", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_borderlessIcons", label = "无边图标", tip = "启用此选项将会去掉图标的边框", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	tinsert(ttifOptions, { type = "Slider", var = "if_iconSize", label = "图标大小", min = 16, max = 128, step = 1, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	tinsert(ttifOptions, { type = "DropDown", var = "if_iconAnchor", label = "图标锚点", tip = "图标的锚点", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	tinsert(ttifOptions, { type = "DropDown", var = "if_iconTooltipAnchor", label = "图标提示锚点", tip = "图标的提示锚点.", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	tinsert(ttifOptions, { type = "Slider", var = "if_iconOffsetX", label = "图标X轴位置", min = -200, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	tinsert(ttifOptions, { type = "Slider", var = "if_iconOffsetY", label = "图标Y轴位置", min = -200, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	
	if (LibFroznFunctions.hasWoWFlavor.ShoppingTooltipHasCompareHeader) then
		tinsert(ttifOptions, { type = "Header", label = "购物提示对比标题", tip = "关于购物提示对比标题（已装备/已拥有）的设置", enabled = function(factory) return factory:GetConfigValue("if_enable") end });

		tinsert(ttifOptions, { type = "DropDown", var = "if_modifyShoppingTooltipCH", label = "对比标题设置", list = { ["|cffffa0a0显示对比文字"] = "doNothing", ["隐藏对比文字"] = "alwaysHideCH", ["有图标时隐藏对比文字"] = { value = "hideCHIfIcon", disabled = function(factory) return not factory:GetConfigValue("if_showIcon") end } }, enabled = function(factory) return factory:GetConfigValue("if_enable") end });
		tinsert(ttifOptions, { type = "Check", var = "if_modifyIconOffsetForCH", label = "调整图标X/Y轴偏移量", tip = "调整图标 X/Y 偏移量，避免与购物提示对比标题重叠", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
		tinsert(ttifOptions, { type = "Slider", var = "if_iconOffsetX_CH", label = "图标X轴偏移量", min = -200, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") and factory:GetConfigValue("if_modifyIconOffsetForCH") end });
		tinsert(ttifOptions, { type = "Check", var = "if_iconOffsetX_CH_addCHWidth", label = "增加对比标题宽度", tip = "动态增加购物提示对比标题的宽度", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") and factory:GetConfigValue("if_modifyIconOffsetForCH") end });
		tinsert(ttifOptions, { type = "Slider", var = "if_iconOffsetY_CH", label = "图标Y轴偏移量", min = -200, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") and factory:GetConfigValue("if_modifyIconOffsetForCH") end });
	end

	if (LibFroznFunctions.hasWoWFlavor.clickForSettingsTextInCurrencyTip) then
		tinsert(ttifOptions, { type = "Header", label = "从提示中移除默认文字", enabled = function(factory) return factory:GetConfigValue("if_enable") end });

		tinsert(ttifOptions, { type = "Check", var = "if_hideClickForSettingsTextInCurrencyTip", label = "从当前提示中隐藏 \"点击设置\" 文字", tip = "Strips the \"click for settings\" text from the currency tooltip", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	end

	tinsert(options, {
		category = "物品信息",
		enabled = { type = "Check", var = "if_enable", tip = "启用或者关闭ItemRef修改鼠标提示" },
		options = ttifOptions
	});
end

-- Layouts
tinsert(options, {
	category = "布局模板",
	btnResetDisabled = true,
	options = {
		{ type = "Header", label = "可用配置文件" },

		{ type = "TextOnly", var = "func_currentProfile", get = function() return "当前配置: " .. TTO_COLOR.text.currentProfile:WrapTextInColorCode(configDb:GetCurrentProfile()); end, set = function() end },

		{ type = "DropDown", label = "切换配置文件", init = TipTacLayouts.SwitchProfile_Init, enabled = function(factory) return #LibFroznFunctions:GetProfilesFromDbFromLibAceDB(configDb, true) >= 1 end },

		{ type = "Header", label = "改变当前配置" },

		{ type = "DropDown", label = "从其他配置文件\n复制设置", init = TipTacLayouts.CopyProfile_Init, enabled = function(factory) return #LibFroznFunctions:GetProfilesFromDbFromLibAceDB(configDb, true) >= 1 end },

		{ type = "DropDown", label = "加载预定义布局\n模板", init = TipTacLayouts.LoadLayout_Init },
--		{ type = "Text", label = "Save Layout", func = nil },
--		{ type = "DropDown", label = "Delete Layout", init = TipTacLayouts.DeleteLayout_Init },

		{ type = "Button", var = "func_ExportSettings", label = "导出设置", width = 140, click = TipTacLayouts.ExportSettings_SelectValue, y = 10 },
		{ type = "Button", label = "导入设置", width = 140, click = TipTacLayouts.ImportSettings_SelectValue, x = 163, belongsTo = "func_ExportSettings" },

		{ type = "Button", label = "重置当配配置为默认值", width = 303, click = TipTacLayouts.ResetProfile_SelectValue, y = 10 },

		{ type = "Header", label = "管理配置文件" },

		{ type = "Text", var = "func_createNewProfile", get = function() return ""; end, set = TipTacLayouts.CreateProfile_SelectValue, label = "使用默认设置\n创建一个新的\n配置文件" },
		{ type = "DropDown", label = "删除配置文件", init = TipTacLayouts.DeleteProfile_Init, tip = "无法删除 \"默认\" 配置文件.", enabled = function(factory) return #LibFroznFunctions:GetProfilesFromDbFromLibAceDB(configDb, true, true) >= 1 end },
	}
});

--------------------------------------------------------------------------------------------------------
--                                          Initialize Frame                                          --
--------------------------------------------------------------------------------------------------------

tinsert(UISpecialFrames, f:GetName()); -- hopefully no taint

f.options = options;

f:SetSize(360 + TT_OPTIONS_CATEGORY_LIST_WIDTH,398);
f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = 1, tileSize = 16, edgeSize = 16, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
f:SetBackdropColor(0.1,0.22,0.35,1);
f:SetBackdropBorderColor(0.1,0.1,0.1,1);
f:EnableMouse(true);
f:SetMovable(true);
f:SetFrameStrata("DIALOG");
f:SetToplevel(true);
f:SetClampedToScreen(true);
f:SetScript("OnShow", function(self)
	f.searchBox:SetText("");
	f.searchBox:ClearFocus();

	self:BuildCategoryList();
	self:BuildCategoryPage();
end);
f:Hide();

f.outline = CreateFrame("Frame",nil,f,BackdropTemplateMixin and "BackdropTemplate");	-- 9.0.1: Using BackdropTemplate
f.outline:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = 1, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
f.outline:SetBackdropColor(0.1,0.1,0.2,1);
f.outline:SetBackdropBorderColor(0.8,0.8,0.9,0.4);
f.outline:SetPoint("TOPLEFT",12,-12);
f.outline:SetPoint("BOTTOMLEFT",12,12);
f.outline:SetWidth(TT_OPTIONS_CATEGORY_LIST_WIDTH);

f:SetScript("OnMouseDown",f.StartMoving);
f:SetScript("OnMouseUp",function(self) self:StopMovingOrSizing(); cfg.optionsLeft = self:GetLeft(); cfg.optionsBottom = self:GetBottom(); end);

if (cfg.optionsLeft) and (cfg.optionsBottom) then
	f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",cfg.optionsLeft,cfg.optionsBottom);
else
	f:SetPoint("CENTER");
end

f.header = f:CreateFontString(nil,"ARTWORK","GameFontHighlight");
f.header:SetFont(GameFontNormal:GetFont(),22,"THICKOUTLINE");
f.header:SetPoint("TOPLEFT",f.outline,"TOPRIGHT",9,-4);
f.header:SetText(CreateTextureMarkup("Interface\\AddOns\\" .. PARENT_MOD_NAME .. "\\media\\tiptac_logo", 256, 256, nil, nil, 0, 1, 0, 1) .. " " .. PARENT_MOD_NAME.."设置");

f.vers = f:CreateFontString(nil,"ARTWORK","GameFontNormalSmall");
f.vers:SetPoint("TOPRIGHT",-15,-15);
local versionTipTac = C_AddOns.GetAddOnMetadata(PARENT_MOD_NAME, "Version");
local versionWoW, build = GetBuildInfo();
f.vers:SetText(PARENT_MOD_NAME .. ": " .. versionTipTac .. "\nWoW: " .. versionWoW);
f.vers:SetTextColor(1,1,0.5);

local function SearchBox_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:AddLine("搜索全部分类", 1, 1, 1);
	GameTooltip:AddLine("可检索所有设置项的名称及提示说明内容", nil, nil, nil, 1);
	GameTooltip:Show();
end

local function SearchBox_OnLeave(self)
	GameTooltip:Hide();
end

local function SearchBox_OnTextChanged(self)
	f:BuildCategoryPage();
end

f.searchBox = CreateFrame("EditBox", nil, f, "SearchBoxTemplate");
f.searchBox:SetSize(160, 20);
f.searchBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -42);
f.searchBox:SetAutoFocus(false);
f.searchBox.Instructions:SetText("搜索全部分类");
f.searchBox:SetScript("OnEnter", SearchBox_OnEnter);
f.searchBox:SetScript("OnLeave", SearchBox_OnLeave);
f.searchBox:HookScript("OnTextChanged", function(self, userInput)
	if (userInput) then
		SearchBox_OnTextChanged(self);
	end
end);
f.searchBox.clearButton:HookScript("OnClick", function(self)
	SearchBox_OnTextChanged(self:GetParent());
end);
f.searchBox:HookScript("OnEscapePressed", function(self)
	self:SetText("");
	self:ClearFocus();

	f:BuildCategoryPage();
end);


local function Anchor_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:AddLine("Tiptac锚点", 1, 1, 1);
	GameTooltip:AddLine("点击显示/隐藏" .. PARENT_MOD_NAME .. "的锚点指示器，你可以将它移动到你需要的位置。", nil, nil, nil, 1);
	GameTooltip:Show();
end

local function Anchor_OnLeave(self)
	GameTooltip:Hide();
end

f.btnAnchor = CreateFrame("Button",nil,f,"UIPanelButtonTemplate");
f.btnAnchor:SetSize(75,24);
f.btnAnchor:SetPoint("BOTTOMLEFT",f.outline,"BOTTOMRIGHT",9,1);
local TipTac = _G[PARENT_MOD_NAME];
f.btnAnchor:SetScript("OnClick",function() TipTac:SetShown(not TipTac:IsShown()) end);
f.btnAnchor:SetScript("OnEnter", Anchor_OnEnter);
f.btnAnchor:SetScript("OnLeave", Anchor_OnLeave);
f.btnAnchor:SetText("锚点");

local function Reset_OnClick(self)
	for index, option in ipairs(f.options[activePage].options or {}) do
		if (option.var) then
			cfg[option.var] = nil;	-- when cleared, they will read the default value from the metatable
		end
	end
	configDb:RegisterDefaults(configDb.defaults);
	TipTac:ApplyConfig();

	f:BuildCategoryList();
	f:BuildCategoryPage();
end

local function Reset_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:AddLine("恢复默认设置", 1, 1, 1);
	GameTooltip:AddLine("将当前页面选项重置为默认设置。", nil, nil, nil, 1);
	GameTooltip:Show();
end

local function Reset_OnLeave(self)
	GameTooltip:Hide();
end

f.btnReset = CreateFrame("Button",nil,f,"UIPanelButtonTemplate");
f.btnReset:SetSize(75,24);
f.btnReset:SetPoint("LEFT",f.btnAnchor,"RIGHT",9,0);
f.btnReset:SetScript("OnClick",Reset_OnClick);
f.btnReset:SetScript("OnEnter", Reset_OnEnter);
f.btnReset:SetScript("OnLeave", Reset_OnLeave);
f.btnReset:SetText("默认");

local function Misc_OnClick(self)
	ToggleDropDownMenu(1, nil, f.btnMisc.dropDownMenu, f.btnMisc, 0, 0);
end

local function Misc_SettingsDropDownOnClick(dropDownMenuButton, arg1, arg2)
	-- close dropdown
	CloseDropDownMenus();
end

local function Misc_ReportDropDownOnClick(dropDownMenuButton, arg1, arg2)
	-- build url
	local url;
	
	if (arg1 == "reportBug") then
		if (arg2 == "onGitHub") then
			url = LibFroznFunctions:ReplaceText("https://github.com/frozn/TipTac/issues/new?template=1_bug_report.yml&labels=1_bug&version-tiptac={versionTipTac}&version-wow={versionWoW}", {
				["{versionTipTac}"] = versionTipTac,
				["{versionWoW}"] = versionWoW
			});
		elseif (arg2 == "onCurseForge") then
			url = "https://www.curseforge.com/wow/addons/tiptac-reborn/comments";
		end
	elseif (arg1 == "requestFeature") then
		if (arg2 == "onGitHub") then
			url = "https://github.com/frozn/TipTac/issues/new?template=2_feature_request.yml&labels=1_enhancement";
		elseif (arg2 == "onCurseForge") then
			url = "https://www.curseforge.com/wow/addons/tiptac-reborn/comments";
		end
	end
	
	-- set icon
	local iconFile;
	
	if (arg2 == "onGitHub") then
		iconFile = "Interface\\AddOns\\" .. PARENT_MOD_NAME .. "\\media\\github";
	elseif (arg2 == "onCurseForge") then
		iconFile = "Interface\\AddOns\\" .. PARENT_MOD_NAME .. "\\media\\curseforge";
	end
	
	-- open popup with url
	if (url) then
		LibFroznFunctions:ShowPopupWithTextAndEditBox({
			prompt = "在浏览器打开此链接：",
			lockedText = url,
			iconFile = iconFile,
			acceptButtonText = "关闭",
			onShowHandler = function(self, data)
				-- fix icon position
				local alertIcon = (self.AlertIcon or _G[self:GetName() .. "AlertIcon"]);
				
				if (not alertIcon) then
					return;
				end
				
				alertIcon:ClearAllPoints();

				if (self.Resize) then -- GameDialogMixin:Resize() available since tww 11.2.0
					alertIcon:SetPoint("LEFT", 24, 7);
				else
					alertIcon:SetPoint("LEFT", 24, 5);
				end
			end	
		});
	end
	
	-- close dropdown
	CloseDropDownMenus();
end

local function Misc_DropDownOnInitialize(dropDownMenu, level, menuList)
	local list = LibFroznFunctions:CreatePushArray();
	
	if (level == 1) then
		list:Push({
			iconText = { "Interface\\HelpFrame\\HelpIcon-Bug", 64, 64, nil, nil, 0.1875, 0.78125, 0.1875, 0.78125 },
			text = "反馈错误",
			menuList = "reportBug"
		});
		list:Push({
			iconText = { "Interface\\HelpFrame\\HelpIcon-Suggestion", 64, 64, nil, nil, 0.21875, 0.765625, 0.234375, 0.78125 },
			text = "提交需求",
			menuList = "requestFeature"
		});
		list:Push({
			iconText = { "Interface\\AddOns\\" .. PARENT_MOD_NAME .. "\\media\\CommonIcons", 64, 64, nil, nil, 0.126465, 0.251465, 0.504883, 0.754883 },
			text = "取消",
			func = Misc_SettingsDropDownOnClick,
			arg1 = "cancel"
		});
	elseif (menuList == "reportBug") then
		list:Push({
			iconText = { "Interface\\AddOns\\" .. PARENT_MOD_NAME .. "\\media\\github", 32, 32, nil, nil, 0, 1, 0, 1 },
			text = "GitHub (推荐)",
			func = Misc_ReportDropDownOnClick,
			arg1 = "reportBug",
			arg2 = "onGitHub"
		});
		list:Push({
			iconText = { "Interface\\AddOns\\" .. PARENT_MOD_NAME .. "\\media\\curseforge", 32, 32, nil, nil, 0, 1, 0, 1 },
			text = "CurseForge",
			func = Misc_ReportDropDownOnClick,
			arg1 = "reportBug",
			arg2 = "onCurseForge"
		});
	elseif (menuList == "requestFeature") then
		list:Push({
			iconText = { "Interface\\AddOns\\" .. PARENT_MOD_NAME .. "\\media\\github", 32, 32, nil, nil, 0, 1, 0, 1 },
			text = "GitHub (推荐)",
			func = Misc_ReportDropDownOnClick,
			arg1 = "requestFeature",
			arg2 = "onGitHub"
		});
		list:Push({
			iconText = { "Interface\\AddOns\\" .. PARENT_MOD_NAME .. "\\media\\curseforge", 32, 32, nil, nil, 0, 1, 0, 1 },
			text = "CurseForge",
			func = Misc_ReportDropDownOnClick,
			arg1 = "requestFeature",
			arg2 = "onCurseForge"
		});
	end
	
	if (list:GetCount() > 0) then
		for _, item in ipairs(list) do
			local info = UIDropDownMenu_CreateInfo();
			
			info.text = (item.iconText and (CreateTextureMarkup(unpack(item.iconText)) .. " ") or "") .. item.text;
			
			if (item.menuList) then
				info.hasArrow = true;
				info.menuList = item.menuList;
				info.keepShownOnClick = true;
			else
				info.func = item.func;
				info.arg1 = item.arg1;
				info.arg2 = item.arg2;
			end
			
			info.notCheckable = true;
			
			UIDropDownMenu_AddButton(info, level);
		end
	end
end

local function Misc_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:AddLine("其他", 1, 1, 1);
	GameTooltip:AddLine("反馈错误或者提交需求。", nil, nil, nil, 1);
	GameTooltip:Show();
end

local function Misc_OnLeave(self)
	GameTooltip:Hide();
end

f.btnMisc = CreateFrame("Button",nil,f,"UIPanelButtonTemplate");
f.btnMisc:SetSize(75,24);
f.btnMisc:SetPoint("LEFT",f.btnReset,"RIGHT",9,0);
f.btnMisc:SetScript("OnClick", Misc_OnClick);
f.btnMisc:SetScript("OnEnter", Misc_OnEnter);
f.btnMisc:SetScript("OnLeave", Misc_OnLeave);
f.btnMisc:SetText("其他");

f.btnMisc.dropDownMenu = CreateFrame("Frame", nil, f.btnMisc, "UIDropDownMenuTemplate");
UIDropDownMenu_Initialize(f.btnMisc.dropDownMenu, Misc_DropDownOnInitialize, "MENU");

f.btnClose = CreateFrame("Button",nil,f,"UIPanelButtonTemplate");
f.btnClose:SetSize(75,24);
f.btnClose:SetPoint("LEFT",f.btnMisc,"RIGHT",10,0);
f.btnClose:SetScript("OnClick",function() f:Hide(); end);
f.btnClose:SetText("关闭");

local function SetScroll(value)
	local status = f.scrollFrame.status or f.scrollFrame.localstatus;
	local viewheight = f.scrollFrame:GetHeight();
	local height = f.content:GetHeight();
	local offset;

	if viewheight > height then
		offset = 0;
	else
		offset = floor((height - viewheight) / 1000.0 * value);
	end
	f.content:ClearAllPoints();
	f.content:SetPoint("TOPLEFT", 0, offset);
	f.content:SetPoint("TOPRIGHT", 0, offset);
	status.offset = offset;
	status.scrollvalue = value;
end

local function MoveScroll(self, value)
	local status = f.scrollFrame.status or f.scrollFrame.localstatus;
	local height, viewheight = f.scrollFrame:GetHeight(), f.content:GetHeight();

	if self.scrollBarShown then
		local diff = height - viewheight;
		local delta = 1;
		if value < 0 then
			delta = -1;
		end
		f.scrollBar:SetValue(min(max(status.scrollvalue + delta*(1000/(diff/45)),0), 1000));
	end
end

local function FixScroll(self)
	if self.updateLock then return end
	self.updateLock = true;
	local status = f.scrollFrame.status or f.scrollFrame.localstatus;
	local height, viewheight = f.scrollFrame:GetHeight(), f.content:GetHeight();
	local offset = status.offset or 0;
	-- Give us a margin of error of 2 pixels to stop some conditions that i would blame on floating point inaccuracys
	-- No-one is going to miss 2 pixels at the bottom of the frame, anyhow!
	if viewheight < height + 2 then
		if self.scrollBarShown then
			self.scrollBarShown = nil;
			f.scrollBar:Hide();
			f.scrollBar:SetValue(0);
			local scrollFrameBottomRightPoint, scrollFrameBottomRightRelativeTo, scrollFrameBottomRightRelativePoint, scrollFrameBottomRightXOfs, scrollFrameBottomRightYOfs = f.scrollFrame:GetPoint(3);
			scrollFrameBottomRightXOfs = -13;
			f.scrollFrame:SetPoint(scrollFrameBottomRightPoint, scrollFrameBottomRightRelativeTo, scrollFrameBottomRightRelativePoint, scrollFrameBottomRightXOfs, scrollFrameBottomRightYOfs);
			if f.content.original_width then
				f.content:SetWidth(f.content.original_width);
			end
		end
	else
		if not self.scrollBarShown then
			self.scrollBarShown = true;
			f.scrollBar:Show();
			local scrollFrameBottomRightPoint, scrollFrameBottomRightRelativeTo, scrollFrameBottomRightRelativePoint, scrollFrameBottomRightXOfs, scrollFrameBottomRightYOfs = f.scrollFrame:GetPoint(3);
			scrollFrameBottomRightXOfs = -33;
			f.scrollFrame:SetPoint(scrollFrameBottomRightPoint, scrollFrameBottomRightRelativeTo, scrollFrameBottomRightRelativePoint, scrollFrameBottomRightXOfs, scrollFrameBottomRightYOfs);
			if f.content.original_width then
				f.content:SetWidth(f.content.original_width - 20);
			end
		end
		local value = (offset / (viewheight - height) * 1000);
		if value > 1000 then value = 1000 end
		f.scrollBar:SetValue(value);
		SetScroll(value);
		if value < 1000 then
			f.content:ClearAllPoints();
			f.content:SetPoint("TOPLEFT", 0, offset);
			f.content:SetPoint("TOPRIGHT", 0, offset);
			status.offset = offset;
		end
	end
	self.updateLock = nil;
end

local function FixScrollOnUpdate(frame)
	frame:SetScript("OnUpdate", nil);
	FixScroll(frame);
end

local function ScrollFrame_OnMouseWheel(frame, value)
	MoveScroll(frame, value);
end

local function ScrollFrame_OnSizeChanged(frame)
	frame:SetScript("OnUpdate", FixScrollOnUpdate);
end

f.scrollFrame = CreateFrame("ScrollFrame", nil, f);
f.scrollFrame.status = {};
f.scrollFrame:SetPoint("TOP", f.searchBox, "BOTTOM", 0, -8);
f.scrollFrame:SetPoint("LEFT", f.outline, "RIGHT", 0, 9);
f.scrollFrame:SetPoint("BOTTOM", f.btnClose, "TOP", 0, 9);
f.scrollFrame:SetPoint("RIGHT", f, "RIGHT", -13, 0);
f.scrollFrame:EnableMouseWheel(true);
f.scrollFrame:SetScript("OnMouseWheel", ScrollFrame_OnMouseWheel);
f.scrollFrame:SetScript("OnSizeChanged", ScrollFrame_OnSizeChanged);

local function ScrollBar_OnScrollValueChanged(frame, value)
	SetScroll(value);
end

f.scrollBar = CreateFrame("Slider", nil, f.scrollFrame, "UIPanelScrollBarTemplate");
f.scrollBar:SetPoint("TOPLEFT", f.scrollFrame, "TOPRIGHT", 4, -16);
f.scrollBar:SetPoint("BOTTOMLEFT", f.scrollFrame, "BOTTOMRIGHT", 4, 16);
f.scrollBar:SetMinMaxValues(0, 1000);
f.scrollBar:SetValueStep(1);
f.scrollBar:SetValue(0);
f.scrollBar:SetWidth(16);
f.scrollBar:Hide();
-- set the script as the last step, so it doesn't fire yet
f.scrollBar:SetScript("OnValueChanged", ScrollBar_OnScrollValueChanged);

f.scrollBg = f.scrollBar:CreateTexture(nil, "BACKGROUND");
f.scrollBg:SetAllPoints(f.scrollBar);
f.scrollBg:SetColorTexture(0, 0, 0, 0.4);

--Container Support
f.content = CreateFrame("Frame", nil, f.scrollFrame)
f.content:SetHeight(400);
f.content:SetScript("OnSizeChanged", function(self, ...)
	ScrollFrame_OnSizeChanged(f.scrollFrame, ...);
end);
f.scrollFrame:SetScrollChild(f.content);
f.content:SetPoint("TOPLEFT");
f.content:SetPoint("TOPRIGHT");

--------------------------------------------------------------------------------------------------------
--                                        Build Option Category                                       --
--------------------------------------------------------------------------------------------------------

-- Get Setting
local function GetConfigValue(self,var)
	return cfg[var];
end

-- called when a setting is changed, do not allow
local function SetConfigValue(self,var,value,noBuildCategoryPage)
	if (not self.isBuildingOptions) then
		cfg[var] = value;
		local TipTac = _G[PARENT_MOD_NAME];
		TipTac:ApplyConfig();
		if (not noBuildCategoryPage) then
			f:BuildCategoryPage(true);
			f:BuildCategoryList();
		end
	end
end

-- determine options to display (search box or current category)
local function addOptionToCategoryOptionMatchesFn(category, categoryOptionMatches, option)
	-- check if option has already been added
	for _, categoryOptionMatch in ipairs(categoryOptionMatches) do
		if (categoryOptionMatch == option) then
			return;
		end
	end

	-- add belongsTo option before if available
	local belongsTo = option.belongsTo;

	if (belongsTo) then
		for _, _option in ipairs(category.options or {}) do
			if (_option.var == belongsTo) then
				addOptionToCategoryOptionMatchesFn(category, categoryOptionMatches, _option);
				break;
			end
		end
	end

	-- add option
	tinsert(categoryOptionMatches, option);
end

local function GetOptionsToShow()
	local optionsToShow;

	local searchText = f.searchBox:GetText();
	local searchWords = {};
	for word in strlower(searchText):gmatch("%S+") do
		tinsert(searchWords, word);
	end

	local searchActive = (#searchWords > 0);

	if (searchActive) then
		optionsToShow = {};

		for _, category in ipairs(f.options) do
			local categoryOptionMatches = {};

			for _, option in ipairs(category.options or {}) do
				if (option.type) and (option.type ~= "Header") and (option.type ~= "TextOnly") then
					-- use label if present. otherwise call get() for dynamic label.
					local labelText = (option.label) or (option.get and LibFroznFunctions:RemoveColorsFromText(option.get(f.factory, option.var)));

					if (labelText) and (labelText ~= "") then
						local haystack = strlower(labelText .. " " .. (option.tip or ""));
						local matched = true;

						for _, word in ipairs(searchWords) do
							if (not haystack:find(word, 1, true)) then
								matched = false;
								break;
							end
						end

						if (matched) then
							addOptionToCategoryOptionMatchesFn(category, categoryOptionMatches, option);
						end
					end
				end
			end

			if (#categoryOptionMatches > 0) then
				tinsert(optionsToShow, { type = "Header", label = "分类：" .. category.category });

				for _, _option in ipairs(categoryOptionMatches) do
					tinsert(optionsToShow, _option);
				end
			end
		end

		if (#optionsToShow == 0) then
			optionsToShow = { { type = "TextOnly", label = "未找到匹配设置项。" } };
		end
	else
		optionsToShow = f.options[activePage].options;
	end

	return optionsToShow, searchActive;
end


-- create new factory instance
local factory = AzOptionsFactory:New(f.content,GetConfigValue,SetConfigValue);
f.factory = factory; 

-- Build Page
function f:BuildCategoryPage(noUpdateScrollFrame)
	-- update scroll frame
	if (not noUpdateScrollFrame) then
		f.scrollBar:SetValue(0);
	end

	-- determine options to display (search box or current category)
	local optionsToShow, searchActive = GetOptionsToShow();
	
	-- build page
	factory:BuildOptionsPage(optionsToShow, f.content, 0, 0);
	
	-- set new content height
	local contentChildren = { f.content:GetChildren() };
	local newContentHeight = nil;
	local contentChildMostBottom = nil;
	
	for index, contentChild in ipairs(contentChildren) do
		local contentChildTopLeftPoint, contentChildTopLeftRelativeTo, contentChildTopLeftRelativePoint, contentChildTopLeftXOfs, contentChildTopLeftYOfs = contentChild:GetPoint();
		if (contentChild:IsShown()) and ((not newContentHeight) or (-contentChildTopLeftYOfs >= newContentHeight)) then
			newContentHeight = -contentChildTopLeftYOfs;
			contentChildMostBottom = contentChild;
		end
	end
	
	local finalContentHeight = (newContentHeight or 0) + (contentChildMostBottom and contentChildMostBottom:GetHeight() or 0);
	
	f.content:SetHeight(finalContentHeight > 0 and finalContentHeight or 1);

	-- disable btnReset if search active or page has it disabled
	f.btnReset:SetEnabled((not searchActive) and (not f.options[activePage].btnResetDisabled));
end

--------------------------------------------------------------------------------------------------------
--                                        Options Category List                                       --
--------------------------------------------------------------------------------------------------------

local listButtons = {};

local function CategoryButton_OnClick(self,button)
	f.searchBox:SetText("");
	f.searchBox:ClearFocus();
	if (not listButtons[activePage].check.option) or (GetConfigValue(f.factory, listButtons[activePage].check.option.var)) then
		listButtons[activePage].text:SetTextColor(1, 0.82, 0);
	else
		listButtons[activePage].text:SetTextColor(0.5, 0.5, 0.5);
	end
	listButtons[activePage]:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight");
	listButtons[activePage]:GetHighlightTexture():SetAlpha(0.3);
	listButtons[activePage]:UnlockHighlight();
	activePage = self.index;
	if (not self.check.option) or (GetConfigValue(f.factory, self.check.option.var)) then
		self.text:SetTextColor(1, 1, 1);
	else
		self.text:SetTextColor(0.5, 0.5, 0.5);
	end
	self:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
	self:GetHighlightTexture():SetAlpha(0.7);
	self:LockHighlight();
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);	-- "igMainMenuOptionCheckBoxOn"
	f:BuildCategoryPage();
end

local function CheckButton_OnClick(self, button)
	local checked = (self:GetChecked() and true or false); -- WoD patch made GetChecked() return bool instead of 1/nil
	local b = self:GetParent();
	
	SetConfigValue(f.factory, self.option.var, checked);
	
	CategoryButton_OnClick(b, button);
	
	if (checked) then
		b.text:SetTextColor(1, 1, 1);
	else
		b.text:SetTextColor(0.5, 0.5, 0.5);
	end
end

local function CheckButton_OnEnter(self)
	if (self.option.tip) then
		GameTooltip:SetOwner(self,"ANCHOR_RIGHT");
		GameTooltip:AddLine(self.option.label,1,1,1);
		GameTooltip:AddLine(self.option.tip,nil,nil,nil,1);
		GameTooltip:Show();
	end
end

local function CheckButton_OnLeave(self)
	GameTooltip:Hide();
end

local buttonWidth = (f.outline:GetWidth() - 8);
local function CreateCategoryButtonEntry(parent)
	local b = CreateFrame("Button",nil,parent);
	b:SetSize(buttonWidth,18);
	b:SetScript("OnClick",CategoryButton_OnClick);
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight");
	b:GetHighlightTexture():SetAlpha(0.3);
	b.text = b:CreateFontString(nil,"ARTWORK","GameFontNormal");
	b.text:SetPoint("LEFT",3,0);
	b.check = CreateFrame("CheckButton", nil, b);
	b.check:SetPoint("TOPLEFT", buttonWidth - 22, 2);
	b.check:SetPoint("BOTTOMRIGHT", 0, -2);
	b.check:SetScript("OnClick", CheckButton_OnClick);
	b.check:SetScript("OnEnter", CheckButton_OnEnter);
	b.check:SetScript("OnLeave", CheckButton_OnLeave);
	b.check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up");
	b.check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down");
	b.check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight");
	b.check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled");
	b.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");
	b.check:Hide();
	tinsert(listButtons, b);
	return b;
end

-- Build Category List
function f:BuildCategoryList()
	for index, table in ipairs(f.options) do
		local button = listButtons[index] or CreateCategoryButtonEntry(f.outline);
		button.text:SetText(table.category);
		button.text:SetTextColor(1,0.82,0);
		if (table.enabled) then
			local option = table.enabled;
			local cfgValue = GetConfigValue(f.factory, option.var);
			button.check.option = option;
			if (not option.label) then
				option.label = table.category;
			end
			button.check:SetChecked(cfgValue);
			local enabled = (not option.enabled) or (not not option.enabled(f.factory, button.check, option, cfgValue));
			button.check:SetEnabled(enabled);
			if (not cfgValue) or (not enabled) then
				button.text:SetTextColor(0.5, 0.5, 0.5);
			end
			button.check:Show();
		end
		button.index = index;
		if (index == 1) then
			button:SetPoint("TOPLEFT",f.outline,"TOPLEFT",5,-6);
		else
			button:SetPoint("TOPLEFT",listButtons[index - 1],"BOTTOMLEFT");
		end
		if (index == activePage) then
			if (not button.check.option) or (GetConfigValue(f.factory, button.check.option.var)) then
				button.text:SetTextColor(1, 1, 1);
			else
				button.text:SetTextColor(0.5, 0.5, 0.5);
			end
			button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
			button:GetHighlightTexture():SetAlpha(0.7);
			button:LockHighlight();
		end
	end
end
