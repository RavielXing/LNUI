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
	["轮廓"] = "OUTLINE",
	["粗轮廓"] = "THICKOUTLINE",
};
local DROPDOWN_ANCHORTYPE = {
	["普通跟随"] = "normal",
	["滑鼠跟随"] = "mouse",
	["两者跟随"] = "parent",
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
	["仅当前数值"] = "current",
	["数值"] = "value",
	["数值与百分比"] = "full",
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
	{ type = "Check", var = "showMinimapIcon", label = "启用小地图图示", tip = "Will show a minimap icon for " .. PARENT_MOD_NAME },
	{ type = "Slider", var = "gttScale", label = "提示缩放大小", min = 0.2, max = 4, step = 0.05, y = 10 },
	
	{ type = "Header", label = "Tiptac鼠标提示" },
	{ type = "Check", var = "showUnitTip", label = "启用" .. PARENT_MOD_NAME .. "鼠标提示", tip = "开启后鼠标提示外观将会修改为Tiptac样式.      " .. PARENT_MOD_NAME .. " 中的大部分功能只能在此选项开启时生效. \n注意: 对非英文客户端使用此选项可能会导致问题!" },
	
	{ type = "Check", var = "showStatus", label = "显示<离线>/<暂离>/<勿扰>状态", tip = "Will show the <DC>, <AFK> and <DND> status after the player name", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 },
	{ type = "Check", var = "showTargetedBy", label = "显示选中该目标的角色", tip = "在团队或小队中, 勾选此选项后将显示选中该目标的队友.\n不在队伍时依赖姓名版运作（需开启姓名版：选项-游戏-界面-姓名版）.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
	{ type = "Check", var = "showPlayerGender", label = "显示玩家性别", tip = "This will show the gender of the player. E.g. \"85 Female Blood Elf Paladin\".", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
	{ type = "Check", var = "showCurrentUnitSpeed", label = "显示当前单位速度", tip = "This will show the current speed of the unit after race & class.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end }
};

if (C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then
	tinsert(ttOptionsGeneral, { type = "Check", var = "showMythicPlusDungeonScore", label = "显示传奇+ 地下城分数", tip = "This will show the mythic+ dungeon score of the player.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 });
	tinsert(ttOptionsGeneral, { type = "DropDown", var = "mythicPlusDungeonScoreFormat", label = "地下城分数格式", list = { ["只有分数"] = "dungeonScore", ["分数 + 最高限时层数"] = "both", ["只有最高限时层数"] = "highestSuccessfullRun" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });
end

if (LibFroznFunctions:IsAddOnEnabled("MythicDungeonTools")) then
	tinsert(ttOptionsGeneral, { type = "Check", var = "showMythicPlusForcesFromMDT", label = "显示传奇+的NPC部队来自插件\nMythic Dungeon Tools (MDT)", tip = "This will show the mythic+ forces from addon Mythic Dungeon Tools (MDT) for NPCs.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });
end

option = { type = "Check", var = "showMount", label = "显示坐骑", tip = "This will show the current mount of the player.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 };
if (LibFroznFunctions.hasWoWFlavor.GetMountFromSpellNotPossibleInCombat) then
	option.tip = option.tip .. "\n注记：在战斗中不可用。";
end
tinsert(ttOptionsGeneral, option);

tinsert(ttOptionsGeneral, { type = "Check", var = "showMountCollected", label = "已收藏", tip = "This option makes the tip show an icon indicating if you already have collected the mount.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") end, x = 122 });
tinsert(ttOptionsGeneral, { type = "Check", var = "showMountIcon", label = "图示", tip = "This option makes the tip show the mount icon.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") end, x = 210 });
tinsert(ttOptionsGeneral, { type = "Check", var = "showMountText", label = "名称", tip = "This option makes the tip show the mount name.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") end, x = 122 });
tinsert(ttOptionsGeneral, { type = "Check", var = "showMountSpeed", label = "速度", tip = "This option makes the tip show the mount speed.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") end, x = 210 });
tinsert(ttOptionsGeneral, { type = "Check", var = "showMountSourceIfNotCollected", label = "来源如未收集", tip = "仅显示你未收集坐骑的掉落来源。", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") and (not factory:GetConfigValue("showMountSource")) end, x = 122 });
tinsert(ttOptionsGeneral, { type = "Check", var = "showMountSource", label = "来源", tip = "这将显示所有坐骑的掉落来源。", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") end, x = 122 });
tinsert(ttOptionsGeneral, { type = "Check", var = "showMountLore", label = "知识", tip = "This option makes the tip show the lore of the mount if available.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showMount") end, x = 210 });

tinsert(ttOptionsGeneral, { type = "DropDown", var = "nameType", label = "名字 & 称号", list = { ["只有名字"] = "normal", ["名字 + 称号"] = "title", ["複制自原始提示信息"] = "original", ["玛丽苏协定"] = "marysueprot" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 });
tinsert(ttOptionsGeneral, { type = "DropDown", var = "showRealm", label = "显示单位服务器", list = { ["|cffffa0a0不显示服务器"] = "none", ["显示服务器"] = "show", ["显示服务器在新行"] = "showInNewLine", ["显示 (*) 来代替"] = "asterisk" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });
tinsert(ttOptionsGeneral, { type = "DropDown", var = "showTarget", label = "显示单位目标", list = { ["|cffffa0a0不显示目标"] = "none", ["在名字后"] = "afterName", ["在名字/服务器下面"] = "belowNameRealm", ["末行"] = "last" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });

tinsert(ttOptionsGeneral, { type = "Text", var = "targetYouText", label = "关注你文字", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 });

tinsert(ttOptionsGeneral, { type = "Check", var = "showGuild", label = "显示玩家公会", tip = "This will show the guild of the player.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 });
tinsert(ttOptionsGeneral, { type = "DropDown", var = "showGuildRealm", label = "显示玩家公会\n服务器", tip = "Player guild realm will only be shown if the guild is from a foreign realm.", list = { ["|cffffa0a0Do not show realm"] = "none", ["Show realm"] = "show", ["Show realm in new line"] = "showInNewLine", ["Show (*) instead"] = "asterisk" }, enabled = function(factory) return factory:GetConfigValue("showGuild") end });
tinsert(ttOptionsGeneral, { type = "Check", var = "showGuildRank", label = "显示玩家公会阶级", tip = "In addition to the guild name, with this option on, you will also see their guild rank by title and/or level", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showGuild") end });
tinsert(ttOptionsGeneral, { type = "DropDown", var = "guildRankFormat", label = "公会阶级格式", list = { ["只有抬头"] = "title", ["抬头 + 会阶"] = "both", ["只有会阶"] = "level" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showGuild") and factory:GetConfigValue("showGuildRank") end });
tinsert(ttOptionsGeneral, { type = "Check", var = "showGuildMemberNote", label = "显示玩家公会成员注记", tip = "This will show the guild member note of the player.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });
tinsert(ttOptionsGeneral, { type = "Check", var = "showGuildOfficerNote", label = "显示玩家公会干部注记", tip = "This will show the guild officer note of the player.", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });

tinsert(ttOptionsGeneral, { type = "DropDown", var = "showPlayerLocation", label = "显示玩家位置", tip = "位置数据仅对玩家本人及其队伍成员可用。区域和子区域信息仅对玩家本人可见。只有当玩家所在地图与所在区域不同时，才会显示该玩家的地图。", list = { ["|cffffa0a0不显示"] = "none", ["显示地图/区域/子区域"] = "mapAndZoneAndSubzone", ["显示地图/区域"] = "mapAndZone", ["仅显示地图"] = "map", ["显示区域/子区域"] = "zoneAndSubzone", ["仅显示区域"] = "zone" }, enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 });
tinsert(ttOptionsGeneral, { type = "Check", var = "showPlayerLocationOnlyForeignMap", label = "仅在非本队/自身所属区域地图上\n显示队伍成员的地图位置.", tip = "此设置仅会在未探索或者陌生地图上显示队伍成员的地图位置。", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and LibFroznFunctions:ExistsInTable(factory:GetConfigValue("showPlayerLocation"), { "mapAndZoneAndSubzone", "mapAndZone", "map" }) end });

tinsert(ttOptionsGeneral, { type = "Check", var = "showBattlePetTip", label = "启用战宠提示", tip = "Will show a special tip for both wild and companion battle pets. Might need to be disabled for certain non-English clients", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 });

tinsert(ttOptionsGeneral, { type = "Header", label = "暴雪预设提示信息", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });

tinsert(ttOptionsGeneral, { type = "Check", var = "hidePvpText", label = "隐藏PvP文字", tip = "Strips the PvP line from the tooltip", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });

if (LibFroznFunctions.hasWoWFlavor.specializationAndClassTextInPlayerUnitTip) then
	tinsert(ttOptionsGeneral, { type = "Check", var = "hideSpecializationAndClassText", label = "在单位提示中隐藏专精与职业文字", tip = "Strips the Specialization & Class text from the tooltip", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });
end

if (LibFroznFunctions.hasWoWFlavor.rightClickForFrameSettingsTextInPlayerUnitTip) then
	tinsert(ttOptionsGeneral, { type = "Check", var = "hideRightClickForFrameSettingsText", label = "在单位提示上隐藏右键点击框架设定文字", tip = "Strips the right click for frame settings text from the unit tooltip", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end });
end

-- Colors
local ttOptionsColors = {
	{ type = "Check", var = "enableColorName", label = "启用名字着色", tip = "Turns on or off coloring names", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
	{ type = "Color", var = "colorName", label = "名字颜色", tip = "启动上方选项后在此自定义名称颜色。|cffff0b0b\n注意:该选项仅在你未启用下方两个颜色选项时生效。", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("enableColorName") end },
	{ type = "Check", var = "colorNameByReaction", label = "基于互动关係着色名字", tip = "角色姓名将使用友善/中立/敌对等属性颜色显示\n|cffff0b0b注意:这个选项将覆盖上方自定义名称颜色。", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
	{ type = "Check", var = "colorNameByClass", label = "基于职业颜色着色玩家名字", tip = "角色姓名将会使用职业颜色显示\n|cffff0b0b注意:这个选项将覆盖上方两个名称颜色选项。", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
	
	{ type = "Color", var = "colorGuild", label = "公会颜色", tip = "Color of the guild name, when not using the option to make it the same as reaction color", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showGuild") end, y = 10 },
	{ type = "Color", var = "colorSameGuild", label = "你的公会颜色", tip = "To better recognise players from your guild, you can configure the color of your guild name individually", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showGuild") end, x = 120 },
	{ type = "Check", var = "colorGuildByReaction", label = "按阵营来对公会进行着色", tip = "Guild color will have the same color as the reacion", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("showGuild") end },
	
	{ type = "Color", var = "colorRace", label = "种族和生物类型顔色", tip = "The color of the race and creature type text", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 },
	{ type = "Color", var = "colorLevel", label = "中立等级顔色", tip = "Units you cannot attack will have their level text shown in this color", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
	
	{ type = "Check", var = "factionText", label = "显示单位的阵营文字", tip = "With this option on, the faction text of the unit will be shown as text below the level line", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 },
	{ type = "Check", var = "enableColorFaction", label = "启用阵营文字着色", tip = "Turns on or off coloring faction texts", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("factionText") end },
	{ type = "Color", var = "colorFactionAlliance", label = "联盟阵营文字颜色", tip = "Color of the Alliance faction text", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("factionText") and factory:GetConfigValue("enableColorFaction") end },
	{ type = "Color", var = "colorFactionHorde", label = "部落阵营文字颜色", tip = "Color of the Horde faction text", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("factionText") and factory:GetConfigValue("enableColorFaction") end },
	{ type = "Color", var = "colorFactionNeutral", label = "中立阵营文字颜色", tip = "Color of the Neutral faction text", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("factionText") and factory:GetConfigValue("enableColorFaction") end },
	
	{ type = "Check", var = "classColoredBorder", label = "边框按职业顔色着色", tip = "For players, the border color will be colored to match the color of their class\nNOTE: This option overrides reaction colored border", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end, y = 10 },
	
	{ type = "Header", label = "自订职业颜色" },
	
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
    { type = "Header", label = "提示上显示增益/减益", enabled = function(factory) return factory:GetConfigValue("enableAuras") end },
	
	{ type = "Check", var = "showBuffs", label = "显示单位增益", tip = "Show buffs of the unit", enabled = function(factory) return factory:GetConfigValue("enableAuras") end },
	{ type = "Check", var = "showDebuffs", label = "显示单位减益", tip = "Show debuffs of the unit", enabled = function(factory) return factory:GetConfigValue("enableAuras") end },
	
};

option = { type = "Check", var = "selfAurasOnly", label = "只显示来自你的光环", tip = "This will filter out and only display auras you cast yourself", enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end, y = 10 };
if (LibFroznFunctions.hasWoWFlavor.aurasCooldownCountAndDebuffTypeNotAvailableInCombat) then
    option.tip = option.tip .. ".\n注意：战斗中此功能不可用。该情况下光环不会被过滤";
end
tinsert(ttOptionsAuras, option);

option = { type = "Check", var = "showAuraCooldown", label = "显示冷却模组", tip = "With this option on, you will see a visual progress of the time left on the buff", enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end, y = 10 };
if (LibFroznFunctions.hasWoWFlavor.aurasCooldownCountAndDebuffTypeNotAvailableInCombat) then
    option.tip = option.tip .. ".\n注意：战斗中此功能不可用。";
end
tinsert(ttOptionsAuras, option);

tinsert(ttOptionsAuras, { type = "Check", var = "noCooldownCount", label = "无冷却计时文字", tip = "Tells cooldown enhancement addons, such as OmniCC, not to display cooldown text", enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end });
tinsert(ttOptionsAuras, { type = "Check", var = "auraStackCount", label = "显示堆叠层数", tip = "With this option on, you will see the amount of stacks", enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end });

tinsert(ttOptionsAuras, { type = "Slider", var = "auraSize", label = "光环图示尺寸", min = 8, max = 60, step = 1, enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end, y = 10 });
tinsert(ttOptionsAuras, { type = "Slider", var = "auraMaxRows", label = "最大光环列", min = 1, max = 8, step = 1, enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end });

tinsert(ttOptionsAuras, { type = "Check", var = "aurasAtBottom", label = "将光环图示放在底部而不是顶部", tip = "Puts the aura icons at the bottom of the tip instead of the default top", enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end, y = 10 });
tinsert(ttOptionsAuras, { type = "Slider", var = "auraOffset", label = "光环位置偏移", min = 0, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("enableAuras") and (factory:GetConfigValue("showBuffs") or factory:GetConfigValue("showDebuffs")) end });

-- Anchors
local ttOptionsAnchors = {
	{ type = "DropDown", var = "anchorWorldUnitType", label = "世界单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end },
	{ type = "DropDown", var = "anchorWorldUnitPoint", label = "世界单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end },
	
	{ type = "DropDown", var = "anchorWorldTipType", label = "世界提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 },
	{ type = "DropDown", var = "anchorWorldTipPoint", label = "世界提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end },
	
	{ type = "DropDown", var = "anchorFrameUnitType", label = "框架单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 },
	{ type = "DropDown", var = "anchorFrameUnitPoint", label = "框架单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end },
	
	{ type = "DropDown", var = "anchorFrameTipType", label = "框架提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 },
	{ type = "DropDown", var = "anchorFrameTipPoint", label = "框架提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end },
};

local priority = 0;

if (LibFroznFunctions.hasWoWFlavor.challengeMode) then
	priority = priority + 1;
	tinsert(ttOptionsAnchors, { type = "Header", label = "优先级#" .. priority .. ": 挑战模式中定位覆盖", tip = "Special anchor overrides during challenge mode (Mythic+) in and out of combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });
	
	tinsert(ttOptionsAnchors, { type = "TextOnly", label = "战斗中" });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldUnitDuringChallengeModeInCombat", label = "战斗中挑战模式世界单位", tip = "This option will override the anchor for World Unit during challenge mode (Mythic+) in combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitTypeDuringChallengeModeInCombat", label = "世界单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringChallengeModeInCombat") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitPointDuringChallengeModeInCombat", label = "世界单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringChallengeModeInCombat") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldTipDuringChallengeModeInCombat", label = "战斗中挑战模式世界提示", tip = "This option will override the anchor for World Tip during challenge mode (Mythic+) in combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipTypeDuringChallengeModeInCombat", label = "世界提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringChallengeModeInCombat") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipPointDuringChallengeModeInCombat", label = "世界提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringChallengeModeInCombat") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameUnitDuringChallengeModeInCombat", label = "战斗中挑战模式框架单位", tip = "This option will override the anchor for Frame Unit during challenge mode (Mythic+) in combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitTypeDuringChallengeModeInCombat", label = "框架单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringChallengeModeInCombat") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitPointDuringChallengeModeInCombat", label = "框架单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringChallengeModeInCombat") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameTipDuringChallengeModeInCombat", label = "战斗中挑战模式框架提示", tip = "This option will override the anchor for Frame Tip during challenge mode (Mythic+) in combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipTypeDuringChallengeModeInCombat", label = "框架提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringChallengeModeInCombat") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipPointDuringChallengeModeInCombat", label = "框架提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringChallengeModeInCombat") end });
	
	tinsert(ttOptionsAnchors, { type = "TextOnly", label = "离开战斗", y = 10 });

	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldUnitDuringChallengeMode", label = "非战斗中挑战模式世界单位", tip = "此选项将覆盖M+中脱离战斗状态下的世界单位定位点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitTypeDuringChallengeMode", label = "世界单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringChallengeMode") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitPointDuringChallengeMode", label = "世界单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringChallengeMode") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldTipDuringChallengeMode", label = "非战斗中挑战模式世界提示", tip = "此选项将覆盖M+中脱离战斗状态下的世界提示定位点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipTypeDuringChallengeMode", label = "世界提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringChallengeMode") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipPointDuringChallengeMode", label = "世界提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringChallengeMode") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameUnitDuringChallengeMode", label = "非战斗中挑战模式框架单位", tip = "此选项将覆盖M+中脱离战斗状态下的框架单位定位点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitTypeDuringChallengeMode", label = "框架单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringChallengeMode") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitPointDuringChallengeMode", label = "框架单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringChallengeMode") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameTipDuringChallengeMode", label = "非战斗中挑战模式框架提示", tip = "此选项将覆盖M+中脱离战斗状态下的框架提示定位点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipTypeDuringChallengeMode", label = "框架提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringChallengeMode") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipPointDuringChallengeMode", label = "框架提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringChallengeMode") end });
end

priority = priority + 1;
tinsert(ttOptionsAnchors, { type = "Header", label = "优先级#" .. priority .. ": 副本中定位覆盖", tip = "Special anchor overrides during an instance (Dungeon, Raid, PvP, Arena, Scenario)", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });

tinsert(ttOptionsAnchors, { type = "TextOnly", label = "战斗中" });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldUnitDuringInstanceInCombat", label = "战斗中副本世界单位", tip = "This option will override the anchor for World Unit during an instance (Dungeon, Raid, PvP, Arena, Scenario) in combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitTypeDuringInstanceInCombat", label = "世界单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringInstanceInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitPointDuringInstanceInCombat", label = "世界单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringInstanceInCombat") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldTipDuringInstanceInCombat", label = "战斗中副本世界提示", tip = "此选项将覆盖副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下的世界提示定位点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipTypeDuringInstanceInCombat", label = "世界提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringInstanceInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipPointDuringInstanceInCombat", label = "世界提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringInstanceInCombat") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameUnitDuringInstanceInCombat", label = "战斗中副本框架单位", tip = "此选项将覆盖副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下的框架单位定位点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitTypeDuringInstanceInCombat", label = "框架单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringInstanceInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitPointDuringInstanceInCombat", label = "框架单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringInstanceInCombat") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameTipDuringInstanceInCombat", label = "战斗中副本框架提示", tip = "此选项将覆盖副本（地下城、团队副本、玩家对战（PvP）、竞技场、场景战役）中战斗状态下的框架提示定位点", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipTypeDuringInstanceInCombat", label = "框架提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringInstanceInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipPointDuringInstanceInCombat", label = "框架提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringInstanceInCombat") end });

tinsert(ttOptionsAnchors, { type = "TextOnly", label = "离开战斗", y = 10 });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldUnitDuringInstance", label = "非战斗中副本世界单位", tip = "This option will override the anchor for World Unit during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitTypeDuringInstance", label = "世界单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringInstance") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitPointDuringInstance", label = "世界单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringInstance") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldTipDuringInstance", label = "非战斗中副本世界提示", tip = "This option will override the anchor for World Tip during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipTypeDuringInstance", label = "世界提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringInstance") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipPointDuringInstance", label = "世界提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringInstance") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameUnitDuringInstance", label = "非战斗中副本框架单位", tip = "This option will override the anchor for Frame Unit during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitTypeDuringInstance", label = "框架单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringInstance") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitPointDuringInstance", label = "框架单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringInstance") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameTipDuringInstance", label = "非战斗中副本框架提示", tip = "This option will override the anchor for Frame Tip during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipTypeDuringInstance", label = "框架提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringInstance") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipPointDuringInstance", label = "框架提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringInstance") end });

if (LibFroznFunctions.hasWoWFlavor.skyriding) then
	priority = priority + 1;
	tinsert(ttOptionsAnchors, { type = "Header", label = "优先级#" .. priority .. ": 驭空术定位覆盖", tip = "Special anchor overrides during skyriding", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });

	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldUnitDuringSkyriding", label = "驭空术时世界单位", tip = "This option will override the anchor for World Unit during skyriding", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitTypeDuringSkyriding", label = "世界单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringSkyriding") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitPointDuringSkyriding", label = "世界单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitDuringSkyriding") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldTipDuringSkyriding", label = "驭空术时世界提示", tip = "This option will override the anchor for World Tip during skyriding", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipTypeDuringSkyriding", label = "世界提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringSkyriding") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipPointDuringSkyriding", label = "世界提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipDuringSkyriding") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameUnitDuringSkyriding", label = "驭空术时框架单位", tip = "This option will override the anchor for Frame Unit during skyriding", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitTypeDuringSkyriding", label = "框架单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringSkyriding") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitPointDuringSkyriding", label = "框架单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitDuringSkyriding") end });
	
	tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameTipDuringSkyriding", label = "驭空术时框架提示", tip = "This option will override the anchor for Frame Tip during skyriding", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipTypeDuringSkyriding", label = "框架提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringSkyriding") end });
	tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipPointDuringSkyriding", label = "框架提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipDuringSkyriding") end });
end

priority = priority + 1;
tinsert(ttOptionsAnchors, { type = "Header", label = "优先级#" .. priority .. ": 战斗中定位覆盖", tip = "Special anchor overrides for in combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldUnitInCombat", label = "战斗中世界单位", tip = "This option will override the anchor for World Unit in combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitTypeInCombat", label = "世界单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldUnitPointInCombat", label = "世界单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldUnitInCombat") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideWorldTipInCombat", label = "战斗中世界提示", tip = "This option will override the anchor for World Tip in combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipTypeInCombat", label = "世界提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorWorldTipPointInCombat", label = "世界提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideWorldTipInCombat") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameUnitInCombat", label = "战斗中框架单位", tip = "This option will override the anchor for Frame Unit in combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitTypeInCombat", label = "框架单位类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameUnitPointInCombat", label = "框架单位位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameUnitInCombat") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideFrameTipInCombat", label = "战斗中框架提示", tip = "This option will override the anchor for Frame Tip in combat", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end, y = 10 });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipTypeInCombat", label = "框架提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipInCombat") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorFrameTipPointInCombat", label = "框架提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideFrameTipInCombat") end });

tinsert(ttOptionsAnchors, { type = "Header", label = "其他特别定位覆盖", tip = "Other special anchor overrides", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });

tinsert(ttOptionsAnchors, { type = "Check", var = "enableAnchorOverrideCF", label = "(公会 & 社群) 聊天框架", tip = "This option will override the anchor for (Guild & Community) ChatFrame", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorOverrideCFType", label = "提示类型", list = DROPDOWN_ANCHORTYPE, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideCF") end });
tinsert(ttOptionsAnchors, { type = "DropDown", var = "anchorOverrideCFPoint", label = "提示位置", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableAnchor") and factory:GetConfigValue("enableAnchorOverrideCF") end });

tinsert(ttOptionsAnchors, { type = "Header", label = "滑鼠设定", enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });

tinsert(ttOptionsAnchors, { type = "Slider", var = "mouseOffsetX", label = "Mouse Anchor X Offset", min = -200, max = 200, step = 1, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });
tinsert(ttOptionsAnchors, { type = "Slider", var = "mouseOffsetY", label = "Mouse Anchor Y Offset", min = -200, max = 200, step = 1, enabled = function(factory) return factory:GetConfigValue("enableAnchor") end });

-- Icons
local ttOptionsIcons = {
	{ type = "Header", label = "单位提示图示", enabled = function(factory) return factory:GetConfigValue("enableIcons") end },
};

if (LibFroznFunctions.hasWoWFlavor.unitCanBeSecretValue) then
	tinsert(ttOptionsIcons, { type = "Check", var = "iconUnitIsSecretValue", label = "显示 \"单位为祕密值\"的图示", tip = "如果单位是秘密值，则在提示旁边显示锁定图示", enabled = function(factory) return factory:GetConfigValue("enableIcons") end });
end

tinsert(ttOptionsIcons, { type = "Check", var = "iconRaid", label = "显示团队图示", tip = "在提示旁边显示团队图示", enabled = function(factory) return factory:GetConfigValue("enableIcons") end });
tinsert(ttOptionsIcons, { type = "Check", var = "iconFaction", label = "显示阵营图示", tip = "如果单位标记为PvP，则在提示旁边显示阵营图示", enabled = function(factory) return factory:GetConfigValue("enableIcons") end });
tinsert(ttOptionsIcons, { type = "Check", var = "iconCombat", label = "显示战斗图示", tip = "如果单位在战斗中，则在提示旁显示战斗图示", enabled = function(factory) return factory:GetConfigValue("enableIcons") end });
tinsert(ttOptionsIcons, { type = "Check", var = "iconClass", label = "显示职业图示", tip = "对于玩家来说，这将在工具提示旁边显示职业图示", enabled = function(factory) return factory:GetConfigValue("enableIcons") end });

tinsert(ttOptionsIcons, { type = "Slider", var = "iconSize", label = "图示大小", min = 8, max = 100, step = 1, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) end });
tinsert(ttOptionsIcons, { type = "Slider", var = "iconMaxIcons", label = "最大图示", min = 1, max = 4, step = 1, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) end });
tinsert(ttOptionsIcons, { type = "DropDown", var = "iconAnchor", label = "图示定位", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) end, y = 10 });
tinsert(ttOptionsIcons, { type = "DropDown", var = "iconAnchorHorizontalAlign", label = "水平对齐", list = DROPDOWN_ANCHORHALIGN, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) and (factory:GetConfigValue("iconAnchor") == "TOP" or factory:GetConfigValue("iconAnchor") == "BOTTOM") end });
tinsert(ttOptionsIcons, { type = "DropDown", var = "iconAnchorVerticalAlign", label = "垂直对齐", list = DROPDOWN_ANCHORVALIGN, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) and (factory:GetConfigValue("iconAnchor") == "LEFT" or factory:GetConfigValue("iconAnchor") == "RIGHT") end });
tinsert(ttOptionsIcons, { type = "DropDown", var = "iconAnchorGrowDirection", label = "增长方向", list = DROPDOWN_ANCHORGROWDIRECTION, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) end });
tinsert(ttOptionsIcons, { type = "Slider", var = "iconOffsetX", label = "图示水平偏移", min = -200, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) end });
tinsert(ttOptionsIcons, { type = "Slider", var = "iconOffsetY", label = "图示垂直偏移", min = -200, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("enableIcons") and (factory:GetConfigValue("iconRaid") or factory:GetConfigValue("iconFaction") or factory:GetConfigValue("iconCombat") or factory:GetConfigValue("iconClass")) end });

-- Hiding
local ttOptionsHiding = {};
priority = 0;

if (LibFroznFunctions.hasWoWFlavor.challengeMode) then
	priority = priority + 1;
	tinsert(ttOptionsHiding, { type = "Header", label = "优先级#" .. priority .. ": 挑战模式中隐藏提示" });
	
	tinsert(ttOptionsHiding, { type = "TextOnly", label = "战斗中" });
	
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatWorldUnits", label = "隐藏世界单位", tip = "When you have this option checked, World Units will be hidden during challenge mode (Mythic+) in combat.", y = 10 });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatFrameUnits", label = "隐藏框架单位", tip = "When you have this option checked, Frame Units will be hidden during challenge mode (Mythic+) in combat.", x = 160 });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatWorldTips", label = "隐藏世界提示", tip = "When you have this option checked, World Tips will be hidden during challenge mode (Mythic+) in combat." });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatFrameTips", label = "隐藏框架提示", tip = "When you have this option checked, Frame Tips will be hidden during challenge mode (Mythic+) in combat.", x = 160 });
	
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatUnitTips", label = "隐藏单位提示", tip = "When you have this option checked, Unit Tips will be hidden during challenge mode (Mythic+) in combat.", y = 10 });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatSpellTips", label = "隐藏法术提示", tip = "When you have this option checked, Spell Tips will be hidden during challenge mode (Mythic+) in combat.", x = 160 });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatItemTips", label = "隐藏物品提示", tip = "When you have this option checked, Item Tips will be hidden during challenge mode (Mythic+) in combat." });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatActionTips", label = "隐藏动作条提示", tip = "When you have this option checked, Action Bar Tips will be hidden during challenge mode (Mythic+) in combat." });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeInCombatExpBarTips", label = "隐藏经验条提示", tip = "When you have this option checked, Experience Bar Tips will be hidden during challenge mode (Mythic+) in combat.", x = 160 });
	
	tinsert(ttOptionsHiding, { type = "TextOnly", label = "离开战斗", y = 10 });
	
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeWorldUnits", label = "隐藏世界单位", tip = "When you have this option checked, World Units will be hidden during challenge mode (Mythic+) out of combat.", y = 10 });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeFrameUnits", label = "隐藏框架单位", tip = "When you have this option checked, Frame Units will be hidden during challenge mode (Mythic+) out of combat.", x = 160 });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeWorldTips", label = "隐藏世界提示", tip = "When you have this option checked, World Tips will be hidden during challenge mode (Mythic+) out of combat." });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeFrameTips", label = "隐藏框架提示", tip = "When you have this option checked, Frame Tips will be hidden during challenge mode (Mythic+) out of combat.", x = 160 });
	
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeUnitTips", label = "隐藏单位提示", tip = "When you have this option checked, Unit Tips will be hidden during challenge mode (Mythic+) out of combat.", y = 10 });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeSpellTips", label = "隐藏法术提示", tip = "When you have this option checked, Spell Tips will be hidden during challenge mode (Mythic+) out of combat.", x = 160 });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeItemTips", label = "隐藏物品提示", tip = "When you have this option checked, Item Tips will be hidden during challenge mode (Mythic+) out of combat." });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeActionTips", label = "隐藏动作条提示", tip = "When you have this option checked, Action Bar Tips will be hidden during challenge mode (Mythic+) out of combat." });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringChallengeModeExpBarTips", label = "隐藏经验条提示", tip = "When you have this option checked, Experience Bar Tips will be hidden during challenge mode (Mythic+) out of combat.", x = 160 });
end

priority = priority + 1;
tinsert(ttOptionsHiding, { type = "Header", label = "优先级#" .. priority .. ": 副本中隐藏提示" });
tinsert(ttOptionsHiding, { type = "TextOnly", label = "战斗中" });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceWorldUnits", label = "隐藏世界单位", tip = "When you have this option checked, World Units will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario)." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceFrameUnits", label = "隐藏框架单位", tip = "When you have this option checked, Frame Units will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario).", x = 160 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceWorldTips", label = "隐藏世界提示", tip = "When you have this option checked, World Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario)." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceFrameTips", label = "隐藏框架提示", tip = "When you have this option checked, Frame Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario).", x = 160 });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatUnitTips", label = "隐藏单位提示", tip = "When you have this option checked, Unit Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) in combat.", y = 10 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatSpellTips", label = "隐藏法术提示", tip = "When you have this option checked, Spell Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) in combat.", x = 160 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatItemTips", label = "隐藏物品提示", tip = "When you have this option checked, Item Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) in combat." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatActionTips", label = "隐藏动作条提示", tip = "When you have this option checked, Action Bar Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) in combat." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceInCombatExpBarTips", label = "隐藏经验条提示", tip = "When you have this option checked, Experience Bar Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) in combat.", x = 160 });

tinsert(ttOptionsHiding, { type = "TextOnly", label = "离开战斗", y = 10 });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceWorldUnits", label = "隐藏世界单位", tip = "When you have this option checked, World Units will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat.", y = 10 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceFrameUnits", label = "隐藏框架单位", tip = "When you have this option checked, Frame Units will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat.", x = 160 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceWorldTips", label = "隐藏世界提示", tip = "When you have this option checked, World Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceFrameTips", label = "隐藏框架提示", tip = "When you have this option checked, Frame Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat.", x = 160 });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceUnitTips", label = "隐藏单位提示", tip = "When you have this option checked, Unit Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat.", y = 10 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceSpellTips", label = "隐藏法术提示", tip = "When you have this option checked, Spell Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat.", x = 160 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceItemTips", label = "隐藏物品提示", tip = "When you have this option checked, Item Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceActionTips", label = "隐藏动作条提示", tip = "When you have this option checked, Action Bar Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringInstanceExpBarTips", label = "隐藏经验条提示", tip = "When you have this option checked, Experience Bar Tips will be hidden during an instance (Dungeon, Raid, PvP, Arena, Scenario) out of combat.", x = 160 });

if (LibFroznFunctions.hasWoWFlavor.skyriding) then
	priority = priority + 1;
	tinsert(ttOptionsHiding, { type = "Header", label = "优先级#" .. priority .. ": 在驭空术时隐藏提示" });
	
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingWorldUnits", label = "隐藏世界单位", tip = "When you have this option checked, World Units will be hidden during skyriding." });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingFrameUnits", label = "隐藏框架单位", tip = "When you have this option checked, Frame Units will be hidden during skyriding.", x = 160 });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingWorldTips", label = "隐藏世界提示", tip = "When you have this option checked, World Tips will be hidden during skyriding." });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingFrameTips", label = "隐藏框架提示", tip = "When you have this option checked, Frame Tips will be hidden during skyriding.", x = 160 });
	
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingUnitTips", label = "隐藏单位提示", tip = "When you have this option checked, Unit Tips will be hidden during skyriding.", y = 10 });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingSpellTips", label = "隐藏法术提示", tip = "When you have this option checked, Spell Tips will be hidden during skyriding.", x = 160 });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingItemTips", label = "隐藏物品提示", tip = "When you have this option checked, Item Tips will be hidden during skyriding." });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingActionTips", label = "隐藏动作条提示", tip = "When you have this option checked, Action Bar Tips will be hidden during skyriding." });
	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsDuringSkyridingExpBarTips", label = "隐藏经验条提示", tip = "When you have this option checked, Experience Bar Tips will be hidden during skyriding.", x = 160 });
end

priority = priority + 1;
tinsert(ttOptionsHiding, { type = "Header", label = "优先级#" .. priority .. ": 战斗中隐藏提示" });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatWorldUnits", label = "隐藏世界单位", tip = "When you have this option checked, World Units will be hidden in combat." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatFrameUnits", label = "隐藏框架单位", tip = "When you have this option checked, Frame Units will be hidden in combat.", x = 160 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatWorldTips", label = "隐藏世界提示", tip = "When you have this option checked, World Tips will be hidden in combat." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatFrameTips", label = "隐藏框架提示", tip = "When you have this option checked, Frame Tips will be hidden in combat.", x = 160 });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatUnitTips", label = "隐藏单位提示", tip = "When you have this option checked, Unit Tips will be hidden in combat.", y = 10 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatSpellTips", label = "隐藏法术提示", tip = "When you have this option checked, Spell Tips will be hidden in combat.", x = 160 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatItemTips", label = "隐藏物品提示", tip = "When you have this option checked, Item Tips will be hidden in combat." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatActionTips", label = "隐藏动作条提示", tip = "When you have this option checked, Action Bar Tips will be hidden in combat." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsInCombatExpBarTips", label = "隐藏经验条提示", tip = "When you have this option checked, Experience Bar Tips will be hidden in combat.", x = 160 });

tinsert(ttOptionsHiding, { type = "Header", label = "优先级#" .. priority .. ": 战斗外隐藏提示" });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsWorldUnits", label = "隐藏世界单位", tip = "When you have this option checked, World Units will be hidden." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsFrameUnits", label = "隐藏框架单位", tip = "When you have this option checked, Frame Units will be hidden.", x = 160 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsWorldTips", label = "隐藏世界提示", tip = "When you have this option checked, World Tips will be hidden." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsFrameTips", label = "隐藏框架提示", tip = "When you have this option checked, Frame Tips will be hidden.", x = 160 });

tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsUnitTips", label = "隐藏单位提示", tip = "When you have this option checked, Unit Tips will be hidden.", y = 10 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsSpellTips", label = "隐藏法术提示", tip = "When you have this option checked, Spell Tips will be hidden.", x = 160 });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsItemTips", label = "隐藏物品提示", tip = "When you have this option checked, Item Tips will be hidden." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsActionTips", label = "隐藏动作条提示", tip = "When you have this option checked, Action Bar Tips will be hidden." });
tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsExpBarTips", label = "隐藏经验条提示", tip = "When you have this option checked, Experience Bar Tips will be hidden.", x = 160 });

if (LibFroznFunctions:IsAddOnEnabled("Blizzard_EncounterJournal")) then
	tinsert(ttOptionsHiding, { type = "Header", label = "隐藏其他提示" });

	tinsert(ttOptionsHiding, { type = "Check", var = "hideTipsEJDungeonRaidSetItemsSTT", label = "为地城/团队副本/套装物品隐藏购物提示\n在冒险日志中", tip = "When you have this option checked, Shopping Tips of Dungeon/Raid/Set Items in Adventure Guide will be hidden." });
end

tinsert(ttOptionsHiding, { type = "Header", label = "其他" });

tinsert(ttOptionsHiding, { type = "DropDown", var = "showHiddenModifierKey", label = "当按下\n快捷按键时\n仍然显示隐藏的提示", list = { ["Shift"] = "shift", ["Ctrl"] = "ctrl", ["Alt"] = "alt", ["|cffffa0a0None"] = "无" } });
tinsert(ttOptionsHiding, { type = "TextOnly", label = "", y = -12 }); -- spacer for multi-line label above

-- build options
local options = {
	-- General
	{
		category = "通用",
		options = ttOptionsGeneral
	},
	-- Colors
	{
		category = "顔色",
		options = ttOptionsColors
	},
	-- Reactions
	{
		category = "互动",
		options = {
			{ type = "Check", var = "reactColoredBorder", label = "边框基于单位互动着色", ttip = "For players, the border color will be colored based on the unit's reaction\nNOTE: This option is overridden by class colored border", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			{ type = "Check", var = "reactIcon", label = "以图示显示与目标互动关係", tip = "This option makes the tip show the unit's reaction as an icon right behind the level", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			
			{ type = "Check", var = "reactText", label = "以文字显示与目标互动关係", tip = "With this option on, the reaction of the unit will be shown as text below the level line", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 },
			{ type = "Color", var = "colorReactText", label = "单位互动关係文字颜色", tip = "Color of the unit's reaction as text, when not using the option to make it the same as reaction color", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("reactText") end },			
			{ type = "Check", var = "reactColoredText", label = "基于单位互动关係着色互动文字", tip = "With this option on, the unit's reaction as text will be based on unit's reaction", enabled = function(factory) return factory:GetConfigValue("showUnitTip") and factory:GetConfigValue("reactText") end },
			
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.tapped, label = "已被接触顔色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end, y = 10 },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.hostile, label = "敌对顔色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.caution, label = "警告顔色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.neutral, label = "中立顔色" , enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.friendlyPlayer, label = "友好玩家顔色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.friendlyPvPPlayer, label = "友好PVP玩家顔色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.friendlyNPC, label = "友好NPC顔色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.honoredNPC, label = "尊敬NPC顔色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.reveredNPC, label = "崇敬NPC顔色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.exaltedNPC, label = "崇拜NPC顔色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
			{ type = "Color", var = "colorReactText" .. LFF_UNIT_REACTION_INDEX.dead, label = "死亡顔色", enabled = function(factory) return factory:GetConfigValue("showUnitTip") end },
		}
	},
	-- BG Color
	{
		category = "背景颜色",
		options = {
			{ type = "Check", var = "reactColoredBackdrop", label = "背景基于单位互动着色", tip = "If you want the tip's background color to be determined by the unit's reaction towards you, enable this. With the option off, the background color will be the one selected on the 'Backdrop' page", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.tapped, label = "已被接触顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end, y = 10 },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.hostile, label = "敌对顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.caution, label = "警告顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.neutral, label = "中立顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.friendlyPlayer, label = "友好玩家顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.friendlyPvPPlayer, label = "友好PVP玩家顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.friendlyNPC, label = "友好NPC顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.honoredNPC, label = "尊敬NPC顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.reveredNPC, label = "崇敬NPC顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.exaltedNPC, label = "崇拜NPC顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
			{ type = "Color", var = "colorReactBack" .. LFF_UNIT_REACTION_INDEX.dead, label = "死亡顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("reactColoredBackdrop") end },
		}
	},
	-- Backdrop
	{
		category = "背景",
		enabled = { type = "Check", var = "enableBackdrop", tip = "启用背景修改\n注意: 重载UI (/reload) 是必须的以让设定套用效果" },
		options = {
			{ type = "DropDown", var = "tipBackdropBG", label = "背景材质", media = "background", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			{ type = "DropDown", var = "tipBackdropBGLayout", label = "背景材质布局", list = { ["重複适应提示"] = "tile", ["伸展适应提示"] = "stretch" }, enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			{ type = "DropDown", var = "tipBackdropEdge", label = "边框材质", media = "border", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			
			{ type = "Slider", var = "backdropEdgeSize", label = "背景边缘大小", min = -20, max = 64, step = 0.5, enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end, y = 10 },
			{ type = "Slider", var = "backdropInsets", label = "背景崁入", min = -20, max = 20, step = 0.5, enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			{ type = "Check", var = "pixelPerfectBackdrop", label = "像素完美的背景边缘和插入", tip = "Backdrop Edge Size and Insets corresponds to real pixels", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end, y = 10 },
			
			{ type = "Color", var = "tipColor", label = "提示背景顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end, y = 10 },
			{ type = "Color", var = "tipBorderColor", label = "提示边框顔色", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end, x = 160 },
			{ type = "Check", var = "gradientTip", label = "显示渐变提示", tip = "在提示顶部显示一个小渐变区域, 为其添加一个小的3D效果. 如果您有Skinner这样的插件, 您可能希望禁用它以避免衝突", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") end },
			{ type = "Color", var = "gradientColor", label = "渐变顔色", tip = "Select the base color for the gradient", enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("gradientTip") end, x = 160 },
			{ type = "Slider", var = "gradientHeight", label = "渐变高度", min = 0, max = 64, step = 0.5, enabled = function(factory) return factory:GetConfigValue("enableBackdrop") and factory:GetConfigValue("gradientTip") end },
		}
	},
	-- Font
	{
		category = "字型",
		enabled = { type = "Check", var = "modifyFonts", tip = "为让 " .. PARENT_MOD_NAME .. " 更改游戏提示字体模板，从而更改用户界面中的所有工具提示，您必须启用此选项。\n注意: 如果您有插件，例如clearfont，则可能与此选项相抵触。" },
		options = {
			{ type = "DropDown", var = "fontFace", label = "字型名称", media = "font", enabled = function(factory) return factory:GetConfigValue("modifyFonts") end },
			{ type = "DropDown", var = "fontFlags", label = "字型样式", list = DROPDOWN_FONTFLAGS, enabled = function(factory) return factory:GetConfigValue("modifyFonts") end },
			{ type = "Slider", var = "fontSize", label = "字型大小", min = 6, max = 29, step = 1, enabled = function(factory) return factory:GetConfigValue("modifyFonts") end },
			
			{ type = "Slider", var = "fontSizeDeltaHeader", label = "标题字型大小差异", min = -10, max = 10, step = 1, enabled = function(factory) return factory:GetConfigValue("modifyFonts") end, y = 10 },
			{ type = "Slider", var = "fontSizeDeltaSmall", label = "内文字型大小差异", min = -10, max = 10, step = 1, enabled = function(factory) return factory:GetConfigValue("modifyFonts") end },
		}
	},
	-- Classify
	{
		category = "单位分类",
		options = {
			{ type = "Text", var = "classification_minus", label = "仆从" },
			{ type = "Text", var = "classification_trivial", label = "小喽啰" },
			{ type = "Text", var = "classification_normal", label = "普通" },
			{ type = "Text", var = "classification_elite", label = "精英" },
			{ type = "Text", var = "classification_worldboss", label = "首领" },
			{ type = "Text", var = "classification_rare", label = "稀有" },
			{ type = "Text", var = "classification_rareelite", label = "稀有精英" },
		}
	},
	-- Fading
	{
		category = "渐隐",
		options = {
			{ type = "Header", label = "单位提示渐隐澹出" },
			
			{ type = "Check", var = "overrideFade", label = "启用覆写预设单位提示单位提示渐隐澹出", tip = "Overrides the default fadeout function of the GameTooltip for units. If you are seeing problems regarding fadeout, please disable." },
			
			{ type = "Slider", var = "preFadeTime", label = "退出时间", min = 0, max = 5, step = 0.05, enabled = function(factory) return factory:GetConfigValue("overrideFade") end, y = 10 },
			{ type = "Slider", var = "fadeTime", label = "澹出时间", min = 0, max = 5, step = 0.05, enabled = function(factory) return factory:GetConfigValue("overrideFade") end },
			
			{ type = "Header", label = "其他" },
			
			{ type = "Check", var = "hideWorldTips", label = "立即隐藏世界框架提示", tip = "This option will make most tips which appear from objects in the world disappear instantly when you take the mouse off the object. Examples such as mailboxes, herbs or chests.\nNOTE: Does not work for all world objects." },
		}
	},
	-- Bars
	{
		category = "条列",
		enabled = { type = "Check", var = "enableBars", tip = "启用单位提示的条列" },
		options = {
			{ type = "Header", label = "单位提示生命条", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			
			{ type = "Check", var = "healthBar", label = "显示生命条", tip = "Will show a health bar of the unit." .. (LibFroznFunctions.hasWoWFlavor.unitCanBeSecretValue and ".\nNOTE: Fallback to the default health bar, if the unit is a secret value." or ""), enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			{ type = "DropDown", var = "healthBarText", label = "生命条文字", list = DROPDOWN_BARTEXTFORMAT, enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("healthBar") end },
			{ type = "Color", var = "healthBarColor", label = "生命条颜色", tip = "The color of the health bar. Has no effect for players with the option above enabled", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("healthBar") end },
			{ type = "Check", var = "healthBarClassColor", label = "生命条按职业着色", tip = "This options colors the health bar in the same color as the player class", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("healthBar") end, y = 2, x = 130 },
			{ type = "Check", var = "hideDefaultBar", label = "隐藏预设生命条", tip = "Check this to hide the default health bar" .. (LibFroznFunctions.hasWoWFlavor.unitCanBeSecretValue and ".\nNOTE: Fallback to the default health bar, if the unit is a secret value and showing a health bar is enabled." or ""), enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			
			{ type = "Header", label = "单位提示法力条", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			
			{ type = "Check", var = "manaBar", label = "显示法力条", tip = "If the unit has mana, a mana bar will be shown.", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			{ type = "DropDown", var = "manaBarText", label = "法力条文字", list = DROPDOWN_BARTEXTFORMAT, enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("manaBar") end },
			{ type = "Color", var = "manaBarColor", label = "法力条顔色", tip = "The color of the mana bar", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("manaBar") end },
			
			{ type = "Header", label = "单位提示条：其他类型能量条", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			
			{ type = "Check", var = "powerBar", label = "显示其他类型能量\n(例如：怒气, 符文能量或集中值)", tip = "If the unit uses other power types than mana (e.g. energy, rage, runic power or focus), a bar for that will be shown.", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			{ type = "DropDown", var = "powerBarText", label = "能量条文字", list = DROPDOWN_BARTEXTFORMAT, enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("powerBar") end },
			
			{ type = "Header", label = "单位提示条：施法条", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			
			{ type = "Check", var = "castBar", label = "显示施法条", tip = "Will show a cast bar of the unit.", enabled = function(factory) return factory:GetConfigValue("enableBars") end },
			{ type = "Check", var = "castBarAlwaysShow", label = "永远显示施法条", tip = "Check this to always show the cast bar", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end, x = 130 },
			{ type = "Color", var = "castBarCastingColor", label = "施法条施放颜色", tip = "The casting color of the cast bar", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end, y = 10 },
			{ type = "Color", var = "castBarChannelingColor", label = "施法条通道颜色", tip = "The channeling color of the cast bar", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end },
			{ type = "Color", var = "castBarChargingColor", label = "施法条充能颜色", tip = "The charging color of the cast bar", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end },
			{ type = "Color", var = "castBarCompleteColor", label = "施法条完成颜色", tip = "The complete color of the cast bar", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end },
			{ type = "Color", var = "castBarFailColor", label = "施法条失败颜色", tip = "The fail color of the cast bar", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end },
			{ type = "Color", var = "castBarSparkColor", label = "施法条火花颜色", tip = "The spark color of the cast bar", enabled = function(factory) return factory:GetConfigValue("enableBars") and factory:GetConfigValue("castBar") end },
		
			{ type = "Header", label = "单位提示条：其他", enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end },
		
			{ type = "Check", var = "barsCondenseValues", label = "显示精简的条列数值", tip = "You can enable this option to condense values shown on the bars. It does this by showing 57254 as 57.3k as an example", enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar")) end },
			
			{ type = "DropDown", var = "barFontFace", label = "字型名称", media = "font", enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end, y = 10 },
			{ type = "DropDown", var = "barFontFlags", label = "字型样式", list = DROPDOWN_FONTFLAGS, enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end },
			{ type = "Slider", var = "barFontSize", label = "字型大小", min = 6, max = 29, step = 1, enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end },
			
			{ type = "DropDown", var = "barTexture", label = "条列材质", media = "statusbar", enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end, y = 10 },
			{ type = "Slider", var = "barHeight", label = "条列高度", min = 1, max = 50, step = 1, enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end },
			
			{ type = "Check", var = "barEnableTipMinimumWidth", label = "如果显示条列启用提示最小宽度", tip = "Check this to enable a minimum width for the tooltip if showing bars, so that numbers are not cut off.", enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) end, y = 10 },
			{ type = "Slider", var = "barTipMinimumWidth", label = "提示最小宽度", min = 10, max = 500, step = 5, enabled = function(factory) return factory:GetConfigValue("enableBars") and (factory:GetConfigValue("healthBar") or factory:GetConfigValue("manaBar") or factory:GetConfigValue("powerBar") or factory:GetConfigValue("castBar")) and factory:GetConfigValue("barEnableTipMinimumWidth") end },
		}
	},
	-- Auras
	{
		category = "光环",
		enabled = { type = "Check", var = "enableAuras", tip = "启用单位的光环提示" },
		options = ttOptionsAuras
	},
	-- Icons
	{
		category = "图示",
		enabled = { type = "Check", var = "enableIcons", tip = "切换所有提示旁的额外图示" },
		options = ttOptionsIcons
	},
	-- Anchors
	{
		category = "定位",
		enabled = { type = "Check", var = "enableAnchor", tip = "切换所有定位的修改" },
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
		enabled = { type = "Check", var = "enableChatHoverTips", label = "启用 (公会 & 社群) 聊天框悬停超链接", tip = "When hovering the mouse over a link in the (Guild & Community) Chatframe, show the tooltip without having to click on it" }
	},
};

-- TipTacTalents Support
local TipTacTalents = _G[PARENT_MOD_NAME .. "Talents"];

if (TipTacTalents) then
	local tttOptions = {
		{ type = "Header", label = "天赋", enabled = function(factory) return factory:GetConfigValue("t_enable") end }
	};
	
	option = { type = "Check", var = "t_showTalents", label = "显示天赋", tip = "This option makes the tip show the talent specialization of other players", enabled = function(factory) return factory:GetConfigValue("t_enable") end };
	if (not LibFroznFunctions.hasWoWFlavor.talentsAvailableForInspectedUnit) then
		option.tip = option.tip .. ".\nNOTE: Inspecting other players' talents isn't available in Classic Era. Only own talents (available at level 10) will be shown.";
	end
	tinsert(tttOptions, option);
	
	if (LibFroznFunctions.hasWoWFlavor.roleIconAvailable) then
		tinsert(tttOptions, { type = "Check", var = "t_showRoleIcon", label = "显示角色类型图示", tip = "This option makes the tip show the role icon (tank, damager, healer)", enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showTalents") end });
	end
	if (LibFroznFunctions.hasWoWFlavor.talentIconAvailable) then
		tinsert(tttOptions, { type = "Check", var = "t_showTalentIcon", label = "显示天赋图示", tip = "This option makes the tip show the talent icon", enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showTalents") end });
	end
	
	tinsert(tttOptions, { type = "Check", var = "t_showTalentText", label = "显示天赋文字", tip = "This option makes the tip show the talent text", enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showTalents") end, y = 10 });
	tinsert(tttOptions, { type = "Check", var = "t_colorTalentTextByClass", label = "根据职业着色天赋文字", tip = "With this option on, talent text is colored by their class color", enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showTalents") and factory:GetConfigValue("t_showTalentText") end });
	
	if (LibFroznFunctions.hasWoWFlavor.numTalentTrees > 0) then
		if (LibFroznFunctions.hasWoWFlavor.numTalentTrees == 2) then
			tinsert(tttOptions, { type = "DropDown", var = "t_talentFormat", label = "天赋文字格式", list = { ["Elemental (31/30)"] = 1, ["Elemental"] = 2, ["31/30"] = 3,}, enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showTalents") and factory:GetConfigValue("t_showTalentText") end }); -- not supported with MoP changes
		else
			tinsert(tttOptions, { type = "DropDown", var = "t_talentFormat", label = "天赋文字格式", list = { ["Elemental (57/14/0)"] = 1, ["Elemental"] = 2, ["57/14/0"] = 3,}, enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showTalents") and factory:GetConfigValue("t_showTalentText") end }); -- not supported with MoP changes
		end
	end
	
	tinsert(tttOptions, { type = "Header", label = "平均装等", enabled = function(factory) return factory:GetConfigValue("t_enable") end });
	
	tinsert(tttOptions, { type = "Check", var = "t_showAverageItemLevel", label = "显示平均装等 (AIL)", tip = "This option makes the tip show the average item level (AIL) of other players", enabled = function(factory) return factory:GetConfigValue("t_enable") end });
	
	tinsert(tttOptions, { type = "Check", var = "t_showGearScore", label = "显示装备分数", tip = "This option makes the tip show the GearScore of other players", enabled = function(factory) return factory:GetConfigValue("t_enable") end, y = 10 });
	tinsert(tttOptions, { type = "DropDown", var = "t_gearScoreAlgorithm", label = "装备分数演算法", list = { ["TacoTip"] = { value = 1, tip = "The de-facto standard algorithm from addon TacoTip" }, ["TipTac"] = { value = 2, tip = PARENT_MOD_NAME .. "'s own implementation to simply calculate the GearScore is used here. This is the sum of all item levels weighted by performance per item level above/below base level of first tier set of current expansion, inventory type and item quality. Inventory slots for shirt, tabard and ranged are excluded." },}, tip = "Switch between different GearScore implementations", enabled = function(factory) return factory:GetConfigValue("t_enable") and factory:GetConfigValue("t_showGearScore") end });
	
	tinsert(tttOptions, { type = "Check", var = "t_colorAILAndGSTextByQuality", label = "根据品质颜色来着色\n平均装等与装备分数文字", tip = "With this option on, average item level and GearScore text is colored by the quality", enabled = function(factory) return factory:GetConfigValue("t_enable") and (factory:GetConfigValue("t_showAverageItemLevel") or factory:GetConfigValue("t_showGearScore")) end, y = 10 });
	
	tinsert(tttOptions, { type = "Header", label = "其他" });
		
	tinsert(tttOptions, { type = "Check", var = "t_talentOnlyInParty", label = "只为队伍与团队成员\n显示天赋与平均装等", tip = "When you enable this, only talents and average item level of players in your party or raid will be requested and shown.", enabled = function(factory) return factory:GetConfigValue("t_enable") and (factory:GetConfigValue("t_showTalents") or factory:GetConfigValue("t_showAverageItemLevel") or factory:GetConfigValue("t_showGearScore")) end });
	tinsert(tttOptions, { type = "Check", var = "t_talentDontShowOutOfRange", label = "不显示距离外玩家的\n天赋与平均装等", tip = "When you enable this, talents and average item level of players who are out of range won't be shown, suppressing the \"out of range\" message.", enabled = function(factory) return factory:GetConfigValue("t_enable") and (factory:GetConfigValue("t_showTalents") or factory:GetConfigValue("t_showAverageItemLevel") or factory:GetConfigValue("t_showGearScore")) end, y = 10 });
	
	tinsert(options, {
		category = "天赋/装等",
		enabled = { type = "Check", var = "t_enable", tip = "切换TipTacTalents插件的功能" },
		options = tttOptions
	});
end

-- TipTacItemRef Support -- Az: this category page is full -- Frozn45: added scroll frame to config options. the scroll bar appears automatically, if content doesn't fit completely on the page.
local TipTacItemRef = _G[PARENT_MOD_NAME .. "ItemRef"];

if (TipTacItemRef) then
	local ttifOptions = {
		{ type = "Color", var = "if_infoColor", label = "信息顔色", tip = "The color of the various tooltip lines added by these options", enabled = function(factory) return factory:GetConfigValue("if_enable") end },

		{ type = "Check", var = "if_itemQualityBorder", label = "显示按品质对边框进行着色的物品提示", tip = "When enabled and the tip is showing an item, the tip border will have the color of the item's quality", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 },
		{ type = "Check", var = "if_showItemLevel", label = "显示物品等级", tip = "对于物品工具提示，显示其物品等级（与物品编号结合）。 \n注意：这将删除工具提示所显示的预设物品等级文字", enabled = function(factory) return factory:GetConfigValue("if_enable") end },
		{ type = "Check", var = "if_showItemId", label = "显示物品编号", tip = "对于物品工具提示，显示其物品编号（与物品等级结合）", enabled = function(factory) return factory:GetConfigValue("if_enable") end, x = 160 }
	};
	
	if (LibFroznFunctions.hasWoWFlavor.relatedExpansionForItemAvailable) then
		tinsert(ttifOptions, { type = "Check", var = "if_showExpansionIcon", label = "显示资料片图示", tip = "For item tooltips, show their expansion icon", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
		tinsert(ttifOptions, { type = "Check", var = "if_showExpansionName", label = "显示资料片名称", tip = "For item tooltips, show their expansion name", enabled = function(factory) return factory:GetConfigValue("if_enable") end, x = 160 });
	end

	tinsert(ttifOptions, { type = "Check", var = "if_showItemEnchantId", label = "显示物品附魔编号", tip = "For item tooltips, show their enchantID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showItemEnchantInfo", label = "显示物品附魔说明", tip = "For item tooltips, show the enchant description", enabled = function(factory) return factory:GetConfigValue("if_enable") end });

	tinsert(ttifOptions, { type = "Check", var = "if_showKeystoneRewardLevel", label = "显示钥石 (每周) 奖励等级", tip = "For keystone tooltips, show their rewardLevel and weeklyRewardLevel", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showKeystoneTimeLimit", label = "显示钥石时间限制", tip = "For keystone tooltips, show the instance timeLimit", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showKeystoneAffixInfo", label = "显示钥石词缀资讯", tip = "For keystone tooltips, show the affix infos", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_modifyKeystoneTips", label = "更改钥石提示", tip = "更改钥石的工具提示以显示更多资讯\n注意: 有可能与其他钥石插件衝突", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_spellColoredBorder", label = "显示法术提示包含边框着色r", tip = "When enabled and the tip is showing a spell, the tip border will have the standard spell color", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showSpellIdAndRank", label = "显示法术编号 & 等级", tip = "For spell tooltips, show their spellID and spellRank/subtext", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_auraSpellColoredBorder", label = "显示光环提示包含边框着色", tip = "When enabled and the tip is showing a buff or debuff, the tip border will have the standard spell color", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showAuraSpellIdAndRank", label = "显示光环法术编号 & 等级", tip = "For buff and debuff tooltips, show their spellID and spellRank/subtext", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showMawPowerId", label = "显示渊喉能量编号", tip = "For spell and aura tooltips, show their mawPowerID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_showAuraCaster", label = "光环提示显示施法者", tip = "When showing buff and debuff tooltips, it will add an extra line, showing who cast the specific aura", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_colorAuraCasterByReaction", label = "根据阵营着色光环提示的施法者", tip = "Aura tooltip caster color will have the same color as the reaction\nNOTE: This option is overridden by class colored aura tooltip caster for players", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showAuraCaster") end });
	tinsert(ttifOptions, { type = "Check", var = "if_colorAuraCasterByClass", label = "根据玩家职业颜色来着色光环提示施法者", tip = "With this option on, color aura tooltip caster for players are colored by their class color\nNOTE: This option overrides reaction colored aura tooltip caster for players", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showAuraCaster") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_showNpcId", label = "显示NPC编号", tip = "For npc or battle pet tooltips, show their npcID", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showMountId", label = "显示坐骑编号", tip = "For item, spell and aura tooltips, show their mountID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });

	if (LibFroznFunctions:IsAddOnEnabled("Blizzard_GlyphUI")) then
		tinsert(ttifOptions, { type = "Check", var = "if_showGlyphId", label = "显示标志编号", tip = "For glyph tooltips, show their glyphID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	end
	
	tinsert(ttifOptions, { type = "Check", var = "if_questDifficultyBorder", label = "显示任务提示包含难度边框着色", tip = "When enabled and the tip is showing a quest, the tip border will have the color of the quest's difficulty", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showQuestLevel", label = "显示任务等级", tip = "For quest tooltips, show their questLevel (Combines with questID)", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showQuestId", label = "显示任务编号", tip = "For quest tooltips, show their questID (Combines with questLevel)", enabled = function(factory) return factory:GetConfigValue("if_enable") end, x = 160 });
	
	tinsert(ttifOptions, { type = "Check", var = "if_currencyQualityBorder", label = "显示货币提示包含品质边框着色", tip = "When enabled and the tip is showing a currency, the tip border will have the color of the currency's quality", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showCurrencyId", label = "显示货币编号", tip = "Currency items will now show their ID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_achievmentColoredBorder", label = "显示成就提示包含边框着色", tip = "When enabled and the tip is showing an achievement, the tip border will have the the standard achievement color", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showAchievementIdAndCategoryId", label = "显示成就编号 & 类别", tip = "On achievement tooltips, the achievement ID as well as the category will be shown", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_modifyAchievementTips", label = "修改成就提示", tip = "Changes the achievement tooltips to show a bit more information\nWarning: Might conflict with other achievement addons", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_battlePetQualityBorder", label = "显示战宠提示包含品质边框着色", tip = "When enabled and the tip is showing a battle pet, the tip border will have the color of the battle pet's quality", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showBattlePetLevel", label = "显示战宠等级", tip = "For battle bet tooltips, show their petLevel (Combines with npcID)", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_battlePetAbilityColoredBorder", label = "显示战宠技能提示包含边框着色", tip = "When enabled and the tip is showing a battle pet ability, the tip border will have the the standard battle pet ability color", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showBattlePetAbilityId", label = "显示战宠技能编号", tip = "For battle bet ability tooltips, show their abilityID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_transmogAppearanceItemQualityBorder", label = "显示塑形外观物品提示包含品质边框着色", tip = "When enabled and the tip is showing an transmog appearance item, the tip border will have the color of the transmog appearance item's quality", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showTransmogAppearanceItemId", label = "显示塑形外观物品编号", tip = "For transmog appearance item tooltips, show their itemID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_transmogIllusionColoredBorder", label = "显示塑形幻象提示包含边框着色", tip = "When enabled and the tip is showing a transmog illusion, the tip border will have the the standard transmog illusion color", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showTransmogIllusionId", label = "显示塑形幻象编号", tip = "For transmog illusion tooltips, show their illusionID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_transmogSetQualityBorder", label = "显示塑形外观套装提示包含品质边框着色", tip = "When enabled and the tip is showing an transmog set, the tip border will have the color of the transmog set's quality", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showTransmogSetId", label = "显示塑形套装编号", tip = "For transmog set tooltips, show their setID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_conduitQualityBorder", label = "显示传导器提示包含品质边框着色", tip = "When enabled and the tip is showing a conduit, the tip border will have the color of the conduit's quality", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showConduitItemLevel", label = "显示传导器物品等级", tip = "For conduit tooltips, show their itemLevel (Combines with conduitID)", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showConduitId", label = "显示传导器编号", tip = "For conduit tooltips, show their conduitID (Combines with conduit itemLevel)", enabled = function(factory) return factory:GetConfigValue("if_enable") end, x = 160 });
	
	tinsert(ttifOptions, { type = "Check", var = "if_azeriteEssenceQualityBorder", label = "显示艾泽莱精华提示包含品质边框着色", tip = "When enabled and the tip is showing an azerite essence, the tip border will have the color of the azerite essence's quality", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showAzeriteEssenceId", label = "显示艾泽莱精华编号", tip = "For azerite essence tooltips, show their essenceID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_runeforgePowerColoredBorder", label = "显示符文鎔铸能量提示包含边框着色", tip = "When enabled and the tip is showing a runeforge power, the tip border will have the the standard runeforge power color", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showRuneforgePowerId", label = "显示符文鎔铸能量编号", tip = "For runeforge power tooltips, show their runeforgePowerID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_flyoutColoredBorder", label = "显示弹出提示包含边框着", tip = "When enabled and the tip is showing a flyout, the tip border will have the the standard spell color", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showFlyoutId", label = "显示弹出编号", tip = "For flyout tooltips, show their flyoutID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_petActionColoredBorder", label = "显示宠物动作提示包含边框着色", tip = "When enabled and the tip is showing a pet action, the tip border will have the the standard spell color", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	tinsert(ttifOptions, { type = "Check", var = "if_showPetActionId", label = "显示宠物动作编号", tip = "For flyout tooltips, show their petActionID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_showInstanceLockDifficulty", label = "显示副本锁定难度", tip = "For instance lock tooltips, show their difficulty", enabled = function(factory) return factory:GetConfigValue("if_enable") end, y = 10 });
	
	tinsert(ttifOptions, { type = "Header", label = "图示", tip = "关于提示图示的设定", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	
	tinsert(ttifOptions, { type = "Check", var = "if_showIcon", label = "显示图示材质及计数 (当可用时)", tip = "Shows an icon next to the tooltip. For items, the stack count will also be shown", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_smartIcons", label = "智能显示图示", tip = "When enabled, TipTacItemRef will determine if an icon is needed, based on where the tip is shown. It will not be shown on actionbars or bag slots for example, as they already show an icon", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	tinsert(ttifOptions, { type = "Check", var = "if_smartIconsShowStackCount", label = "当堆叠计数可用时总是显示图示", tip = "When eabled, the icon will always be shown if a stack count is available.", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") and factory:GetConfigValue("if_smartIcons") end });
	tinsert(ttifOptions, { type = "DropDown", var = "if_stackCountToTooltip", label = "显示堆叠计数于\n工具提示", list = { ["|cffffa0a0不显示"] = "none", ["永远显示"] = "always", ["只有图示不显示时"] = "noicon" }, enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_showIconId", label = "显示图示编号", tip = "For tooltips with icon, show their iconID", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	tinsert(ttifOptions, { type = "Check", var = "if_borderlessIcons", label = "无边框图示", tip = "Turn off the border on icons", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	tinsert(ttifOptions, { type = "Slider", var = "if_iconSize", label = "图示尺寸", min = 16, max = 128, step = 1, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	tinsert(ttifOptions, { type = "DropDown", var = "if_iconAnchor", label = "图示定位", tip = "The anchor of the icon", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	tinsert(ttifOptions, { type = "DropDown", var = "if_iconTooltipAnchor", label = "图示提示定位", tip = "The anchor of the tooltip that the icon should anchor to.", list = DROPDOWN_ANCHORPOS, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	tinsert(ttifOptions, { type = "Slider", var = "if_iconOffsetX", label = "图示水平位置", min = -200, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
	tinsert(ttifOptions, { type = "Slider", var = "if_iconOffsetY", label = "图示垂直位置", min = -200, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });

	if (LibFroznFunctions.hasWoWFlavor.ShoppingTooltipHasCompareHeader) then
		tinsert(ttifOptions, { type = "Header", label = "考虑购物工具提示比较标题", tip = "Settings about shopping tooltip compare header", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
		
		tinsert(ttifOptions, { type = "DropDown", var = "if_modifyShoppingTooltipCH", label = "修改比较标题", list = { ["|cffffa0a0啥也不做"] = "doNothing", ["总是隐藏比较标题"] = "alwaysHideCH", ["如果图示显示则隐藏"] = { value = "hideCHIfIcon", disabled = function(factory) return not factory:GetConfigValue("if_showIcon") end } }, enabled = function(factory) return factory:GetConfigValue("if_enable") end });
		tinsert(ttifOptions, { type = "Check", var = "if_modifyIconOffsetForCH", label = "修改图示 X/Y 偏移", tip = "Modify the X/Y offset of the icon to prevent overlapping with the shopping tooltip compare header", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") end });
		tinsert(ttifOptions, { type = "Slider", var = "if_iconOffsetX_CH", label = "图示 X 偏移", min = -200, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") and factory:GetConfigValue("if_modifyIconOffsetForCH") end });
		tinsert(ttifOptions, { type = "Check", var = "if_iconOffsetX_CH_addCHWidth", label = "为比较标题增加宽度", tip = "Dynamically add the width of the shopping tooltip compare header", enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") and factory:GetConfigValue("if_modifyIconOffsetForCH") end });
		tinsert(ttifOptions, { type = "Slider", var = "if_iconOffsetY_CH", label = "图示 Y 偏移", min = -200, max = 200, step = 0.5, enabled = function(factory) return factory:GetConfigValue("if_enable") and factory:GetConfigValue("if_showIcon") and factory:GetConfigValue("if_modifyIconOffsetForCH") end });
	end

	if (LibFroznFunctions.hasWoWFlavor.clickForSettingsTextInCurrencyTip) then
		tinsert(ttifOptions, { type = "Header", label = "卸下工具提示的预设文字", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
		
		tinsert(ttifOptions, { type = "Check", var = "if_hideClickForSettingsTextInCurrencyTip", label = "从货币提示中隐藏 \"点击来设定\" 的文字", tip = "Strips the \"click for settings\" text from the currency tooltip", enabled = function(factory) return factory:GetConfigValue("if_enable") end });
	end
	
	tinsert(options, {
		category = "物品参考",
		enabled = { type = "Check", var = "if_enable", tip = "切换TipTacItemRef插件的全部功能" },
		options = ttifOptions
	});
end

-- Layouts
tinsert(options, {
	category = "布局",
	btnResetDisabled = true,
	options = {
		{ type = "Header", label = "可用设定档" },
		
		{ type = "TextOnly", var = "func_currentProfile", get = function() return "当前设定档: " .. TTO_COLOR.text.currentProfile:WrapTextInColorCode(configDb:GetCurrentProfile()); end, set = function() end },
		
		{ type = "DropDown", label = "切换设定档", init = TipTacLayouts.SwitchProfile_Init, enabled = function(factory) return #LibFroznFunctions:GetProfilesFromDbFromLibAceDB(configDb, true) >= 1 end },
		
		{ type = "Header", label = "更换当前设定档" },
		
		{ type = "DropDown", label = "複制设定从\n其他设定档", init = TipTacLayouts.CopyProfile_Init, enabled = function(factory) return #LibFroznFunctions:GetProfilesFromDbFromLibAceDB(configDb, true) >= 1 end },
		
		{ type = "DropDown", label = "载入预定义\n布局范本", init = TipTacLayouts.LoadLayout_Init },
--		{ type = "Text", label = "Save Layout", func = nil },
--		{ type = "DropDown", label = "Delete Layout", init = TipTacLayouts.DeleteLayout_Init },
		
		{ type = "Button", label = "导出设定", width = 140, click = TipTacLayouts.ExportSettings_SelectValue, y = 10 },
		{ type = "Button", label = "导入设定", width = 140, click = TipTacLayouts.ImportSettings_SelectValue, x = 163 },
		
		{ type = "Button", label = "重设当前设定档回预设值", width = 303, click = TipTacLayouts.ResetProfile_SelectValue, y = 10 },
		
		{ type = "Header", label = "管理设定档" },
		
		{ type = "Text", var = "func_createNewProfile", get = function() return ""; end, set = TipTacLayouts.CreateProfile_SelectValue, label = "建立新设定档\n使用预设的设定" },
		{ type = "DropDown", label = "删除设定档", init = TipTacLayouts.DeleteProfile_Init, tip = "The \"Default\" profile can't be deleted.", enabled = function(factory) return #LibFroznFunctions:GetProfilesFromDbFromLibAceDB(configDb, true, true) >= 1 end },
	}
});

--------------------------------------------------------------------------------------------------------
--                                          Initialize Frame                                          --
--------------------------------------------------------------------------------------------------------

tinsert(UISpecialFrames, f:GetName()); -- hopefully no taint

f.options = options;

f:SetSize(360 + TT_OPTIONS_CATEGORY_LIST_WIDTH,378);
f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = 1, tileSize = 16, edgeSize = 16, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
f:SetBackdropColor(0.1,0.22,0.35,1);
f:SetBackdropBorderColor(0.1,0.1,0.1,1);
f:EnableMouse(true);
f:SetMovable(true);
f:SetFrameStrata("DIALOG");
f:SetToplevel(true);
f:SetClampedToScreen(true);
f:SetScript("OnShow",function(self) self:BuildCategoryList(); self:BuildCategoryPage(); end);
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
f.header:SetText(CreateTextureMarkup("Interface\\AddOns\\" .. PARENT_MOD_NAME .. "\\media\\tiptac_logo", 256, 256, nil, nil, 0, 1, 0, 1) .. " " .. PARENT_MOD_NAME.." 选项");

f.vers = f:CreateFontString(nil,"ARTWORK","GameFontNormalSmall");
f.vers:SetPoint("TOPRIGHT",-15,-15);
local versionTipTac = C_AddOns.GetAddOnMetadata(PARENT_MOD_NAME, "Version");
local versionWoW, build = GetBuildInfo();
f.vers:SetText(PARENT_MOD_NAME .. ": " .. versionTipTac .. "\nWoW: " .. versionWoW);
f.vers:SetTextColor(1,1,0.5);

local function Anchor_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:AddLine("Anchor", 1, 1, 1);
	GameTooltip:AddLine("点击来切换 " .. PARENT_MOD_NAME .. "的可见性以及定位，来设定预设提示定位的位置。", nil, nil, nil, 1);
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
f.btnAnchor:SetText("定位点");

local function Reset_OnClick(self)
	for index, option in ipairs(f.options[activePage].options or {}) do
		if (option.var) then
			cfg[option.var] = nil;	-- when cleared, they will read the default value from the metatable
		end
	end
	configDb:RegisterDefaults(configDb.defaults);
	TipTac:ApplyConfig();
	f:BuildCategoryPage();
	f:BuildCategoryList();
end

local function Reset_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:AddLine("Defaults", 1, 1, 1);
	GameTooltip:AddLine("重置当前页面的选项回到预设值。", nil, nil, nil, 1);
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
f.btnReset:SetText("Defaults");

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
		LibFroznFunctions:ShowPopupWithText({
			prompt = "Open this link in your web browser:",
			lockedText = url,
			iconFile = iconFile,
			acceptButtonText = "Close",
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
			text = "反馈问题",
			menuList = "reportBug"
		});
		list:Push({
			iconText = { "Interface\\HelpFrame\\HelpIcon-Suggestion", 64, 64, nil, nil, 0.21875, 0.765625, 0.234375, 0.78125 },
			text = "功能请求",
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
			text = "在GitHub (推荐)",
			func = Misc_ReportDropDownOnClick,
			arg1 = "reportBug",
			arg2 = "onGitHub"
		});
		list:Push({
			iconText = { "Interface\\AddOns\\" .. PARENT_MOD_NAME .. "\\media\\curseforge", 32, 32, nil, nil, 0, 1, 0, 1 },
			text = "在CurseForge",
			func = Misc_ReportDropDownOnClick,
			arg1 = "reportBug",
			arg2 = "onCurseForge"
		});
	elseif (menuList == "requestFeature") then
		list:Push({
			iconText = { "Interface\\AddOns\\" .. PARENT_MOD_NAME .. "\\media\\github", 32, 32, nil, nil, 0, 1, 0, 1 },
			text = "在GitHub (推荐)",
			func = Misc_ReportDropDownOnClick,
			arg1 = "requestFeature",
			arg2 = "onGitHub"
		});
		list:Push({
			iconText = { "Interface\\AddOns\\" .. PARENT_MOD_NAME .. "\\media\\curseforge", 32, 32, nil, nil, 0, 1, 0, 1 },
			text = "在CurseForge",
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
	GameTooltip:AddLine("杂项", 1, 1, 1);
	GameTooltip:AddLine("反馈问题或功能请求。", nil, nil, nil, 1);
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
f.btnMisc:SetText("杂项");

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
f.scrollFrame:SetPoint("TOP", f.header, "BOTTOM", 0, -12);
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

-- create new factory instance
local factory = AzOptionsFactory:New(f.content,GetConfigValue,SetConfigValue);
f.factory = factory; 

-- Build Page
function f:BuildCategoryPage(noUpdateScrollFrame)
	-- update scroll frame
	if (not noUpdateScrollFrame) then
		f.scrollBar:SetValue(0);
	end
	
	-- build page
	factory:BuildOptionsPage(f.options[activePage].options, f.content, 0, 0);
	
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
	
	-- disable btnReset if necessary
	f.btnReset:SetEnabled(not f.options[activePage].btnResetDisabled);
end

--------------------------------------------------------------------------------------------------------
--                                        Options Category List                                       --
--------------------------------------------------------------------------------------------------------

local listButtons = {};

local function CategoryButton_OnClick(self,button)
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
