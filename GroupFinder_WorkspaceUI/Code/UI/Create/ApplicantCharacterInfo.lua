local _, GF = ...
GF = GF.GF or GF

GF.ApplicantCharacterInfo = GF.ApplicantCharacterInfo or {}
local CharacterInfo = GF.ApplicantCharacterInfo

local ApplicantCharacterInfo = {
	DIALOG_W = 560,
	DIALOG_MIN_H = 340,
	DIALOG_LINKS_ONLY_H = 218,
	DIALOG_MAX_H = 650,
	DIALOG_BACKGROUND_COLOR = GF.MAIN_WINDOW_BACKGROUND_COLOR
		or { 0, 0, 0, 0.82 },
	PANEL_X = 40,
	PANEL_TOP_Y = -50,
	PANEL_W = 480,
	PANEL_PAD_X = 16,
	PANEL_PAD_TOP = 12,
	PANEL_PAD_BOTTOM = 12,
	CONTENT_X = 40,
	CONTENT_W = 480,
	LABEL_W = 309,
	VALUE_W = 145,
	RAID_PROVIDER_LABEL_W = 234,
	RAID_PROVIDER_VALUE_W = 228,
	VALUE_RIGHT_PAD = 12,
	RUN_LABEL_W = 292,
	RUN_LEVEL_W = 58,
	RUN_STATUS_W = 84,
	RUN_VALUE_GAP = 10,
	ROW_H = 18,
	MAIN_TITLE_ROW_H = 22,
	MAIN_TITLE_FONT_SIZE = 16,
	ROW_FONT_SIZE = 14,
	DIVIDER_H = 12,
	LINK_GAP = 14,
	LINKS_ONLY_TOP_Y = -56,
	BOTTOM_PADDING = 24,
	MAX_PROFILE_ROWS = 22,
	MAX_DUNGEON_ROWS = 8,
	MAIN_WINDOW_DIM_ALPHA = 0.64,
	DIALOG_FRAME_LEVEL = 1000,
	PROFILE_DIVIDER_ATLAS = "RecipeList-Divider",
	PROFILE_DIVIDER_HEIGHT = 3,
	TIMED_BUCKET_UPPER_BY_LEVEL = {
		[12] = 14,
		[10] = 11,
		[7] = 9,
		[4] = 6,
		[2] = 3,
	},
}

local WCL_CHARACTER_URL_FMT = "https://%s.warcraftlogs.com/character/%s/%s/%s?utm_source=addon"
local CN_ARMORY_CHARACTER_URL_FMT = "https://wow.blizzard.cn/character/#/%s/%s"
local GLOBAL_ARMORY_CHARACTER_URL_FMT = "https://worldofwarcraft.com/%s/character/%s/%s/%s"
-- 国服官网服务器状态接口公开的正式服中文名与英雄榜 realm slug 快照。
-- 来源：https://webapi.blizzard.cn/wow-armory-server/api/server_status?server_type=wow_mainline
-- 核对日期：2026-08-29；360 个中文服务器名与 slug 均唯一。
local CN_ARMORY_REALM_SLUGS = {
	["火羽山"] = "fire-plume-ridge",
	["迦罗娜"] = "garona",
	["纳沙塔尔"] = "nazjatar",
	["末日祷告祭坛"] = "dooms-vigil",
	["凯恩血蹄"] = "bloodhoof",
	["瑟莱德丝"] = "theradras",
	["卡德加"] = "khadgar",
	["诺兹多姆"] = "nozdormu",
	["泰兰德"] = "tyrande",
	["梦境之树"] = "dream-bough",
	["燃烧之刃"] = "burning-blade",
	["埃霍恩"] = "ahune",
	["格瑞姆巴托"] = "grim-batol",
	["血牙魔王"] = "gorefiend",
	["埃克索图斯"] = "executus",
	["阿尔萨斯"] = "arthas",
	["祖达克"] = "zuldrak",
	["安东尼达斯"] = "antonidas",
	["符文图腾"] = "runetotem",
	["黑暗魅影"] = "dark-phantom",
	["卡德罗斯"] = "khardros",
	["阿斯塔洛"] = "astalor",
	["鬼雾峰"] = "dreadmist-peak",
	["黑暗之矛"] = "darkspear",
	["巨龙之吼"] = "dragonmaw",
	["黑石尖塔"] = "blackrock",
	["罗曼斯"] = "rommath",
	["塞泰克"] = "sethekk",
	["巴尔古恩"] = "baelgun",
	["托尔巴拉德"] = "tol-barad",
	["玛诺洛斯"] = "mannoroth",
	["火烟之谷"] = "dustbelcher",
	["达纳斯"] = "danath-trollbane",
	["金色平原"] = "the-golden-plains",
	["风暴之眼"] = "storm-eye",
	["雷霆号角"] = "thunderhorn",
	["迅捷微风"] = "swiftwind",
	["萨洛拉丝"] = "sacrolash",
	["斩魔者"] = "demonslayer",
	["幽暗沼泽"] = "the-underbog",
	["埃加洛尔"] = "azgalor",
	["鲜血熔炉"] = "blood-furnace",
	["布兰卡德"] = "blanchard",
	["苏塔恩"] = "sutarn",
	["卡拉赞"] = "karazhan",
	["血环"] = "bleeding-hollow",
	["范克里夫"] = "vancleef",
	["银月"] = "silvermoon",
	["羽月"] = "feathermoon",
	["耳语海岸"] = "whispering-shore",
	["玛多兰"] = "madoran",
	["雷斧堡垒"] = "thunder-axe-fortress",
	["凯尔萨斯"] = "kaelthas",
	["冰川之拳"] = "boulderfist",
	["双子峰"] = "twin-peaks",
	["埃苏雷格"] = "azuregos",
	["耐奥祖"] = "nerzhul",
	["地狱之石"] = "fel-rock",
	["火焰之树"] = "firetree",
	["霜之哀伤"] = "frostmourne",
	["遗忘海岸"] = "the-forgotten-coast",
	["神圣之歌"] = "holy-chanter",
	["回音山"] = "echo-ridge",
	["斯坦索姆"] = "stratholme",
	["泰拉尔"] = "taerar",
	["格鲁尔"] = "gruul",
	["穆戈尔"] = "mogor",
	["血色十字军"] = "scarlet-crusade",
	["影牙要塞"] = "shadowfang-keep",
	["艾苏恩"] = "aszune",
	["古尔丹"] = "guldan",
	["血顶"] = "bloodscalp",
	["寒冰皇冠"] = "icecrown",
	["冬泉谷"] = "winterspring",
	["基尔加丹"] = "kiljaeden",
	["奥拉基尔"] = "alakir",
	["伊萨里奥斯"] = "itharius",
	["祖阿曼"] = "zulaman",
	["麦迪文"] = "medivh",
	["月光林地"] = "moonglade",
	["霜狼"] = "frostwolf",
	["迦玛兰"] = "jammalan",
	["狂热之刃"] = "zealot-blade",
	["朵丹尼尔"] = "dordanil",
	["沃金"] = "voljin",
	["芬里斯"] = "fenris",
	["天谴之门"] = "wrath-gate",
	["希雷诺斯"] = "searinox",
	["烈焰荆棘"] = "smolderthorn",
	["蓝龙军团"] = "blue-dragonflight",
	["白银之手"] = "silver-hand",
	["卡扎克"] = "lord-kazzak",
	["戈古纳斯"] = "gorgonnash",
	["激流之傲"] = "river-pride",
	["拉格纳罗斯"] = "ragnaros",
	["巴纳扎尔"] = "balnazzar",
	["红云台地"] = "red-cloud-mesa",
	["爱斯特纳"] = "astranaar",
	["龙骨平原"] = "dragonblight",
	["诺莫瑞根"] = "gnomeregan",
	["艾欧娜尔"] = "eonar",
	["达隆米尔"] = "darrowmere",
	["冬寒"] = "winterchill",
	["刀塔"] = "bladespire",
	["无底海渊"] = "abyssal-depths",
	["自由之风"] = "freewind",
	["阿努巴拉克"] = "anubarak",
	["熊猫酒仙"] = "pandaren",
	["奥特兰克"] = "alterac-mountains",
	["铜龙军团"] = "bronze-dragonflight",
	["普罗德摩"] = "proudmoore",
	["玛洛加尔"] = "marrowgar",
	["金度"] = "jindo",
	["克洛玛古斯"] = "chromaggus",
	["米奈希尔"] = "menethil",
	["无尽之海"] = "the-great-sea",
	["塞拉赞恩"] = "therazane",
	["太阳之井"] = "sunwell",
	["杜隆坦"] = "durotan",
	["暮色森林"] = "duskwood",
	["狂风峭壁"] = "windshear-crag",
	["玛瑟里顿"] = "magtheridon",
	["冰风岗"] = "chillwind-point",
	["密林游侠"] = "rangers",
	["巴瑟拉斯"] = "barthilas",
	["塔纳利斯"] = "tanaris",
	["伊森利恩"] = "isillien",
	["永夜港"] = "nighthaven",
	["黄金之路"] = "gold-road",
	["翡翠梦境"] = "emerald-dream",
	["阿扎达斯"] = "archaedas",
	["石爪峰"] = "stonetalon-peak",
	["奥蕾莉亚"] = "alleria",
	["世界之树"] = "world-tree",
	["万色星辰"] = "kaleidoscope-star",
	["布莱恩"] = "brann",
	["暴风祭坛"] = "altar-of-storms",
	["艾萨拉"] = "azshara",
	["利刃之拳"] = "bladefist",
	["黑翼之巢"] = "blackwing-lair",
	["玛里苟斯"] = "malygos",
	["熵魔"] = "entropius",
	["摩摩尔"] = "murmur",
	["藏宝海湾"] = "booty-bay",
	["阿拉希"] = "arathi",
	["塔伦米尔"] = "tarren-mill",
	["燃烧平原"] = "burning-steppes",
	["风行者"] = "windrunner",
	["库德兰"] = "kurdran",
	["加里索斯"] = "garithos",
	["红龙军团"] = "red-dragonflight",
	["山丘之王"] = "bronzebeard",
	["拉文霍德"] = "ravenholdt",
	["烈焰峰"] = "flame-crest",
	["瓦拉斯塔兹"] = "vaelastrasz",
	["卡珊德拉"] = "cassandra",
	["暗影之月"] = "shadowmoon",
	["萨尔"] = "thrall",
	["伊莫塔尔"] = "immolthar",
	["蜘蛛王国"] = "azjolnerub",
	["塞拉摩"] = "theramore",
	["暗影迷宫"] = "shadow-labyrinth",
	["麦姆"] = "maim",
	["加基森"] = "gadgetzan",
	["黑暗虚空"] = "twisting-nether",
	["格雷迈恩"] = "greymane",
	["红龙女王"] = "alexstrasza",
	["奈萨里奥"] = "neltharion",
	["黑手军团"] = "blackhand",
	["瓦丝琪"] = "vashj",
	["菲拉斯"] = "feralas",
	["诺森德"] = "northrend",
	["哈卡"] = "hakkar",
	["死亡熔炉"] = "deathforge",
	["燃烧军团"] = "burning-legion",
	["奥妮克希亚"] = "onyxia",
	["纳克萨玛斯"] = "naxxramas",
	["海加尔"] = "hyjal",
	["奥斯里安"] = "ossirian",
	["战歌"] = "warsong",
	["夺灵者"] = "soulflayer",
	["风暴之鳞"] = "stormscale",
	["耐普图隆"] = "neptulon",
	["日落沼泽"] = "sundown-marsh",
	["安纳塞隆"] = "anetheron",
	["托塞德林"] = "tortheldrin",
	["凤凰之神"] = "alar",
	["安戈洛"] = "ungoro",
	["德拉诺"] = "draenor",
	["古拉巴什"] = "gurubashi",
	["深渊之巢"] = "deephome",
	["阿格拉玛"] = "aggramar",
	["外域"] = "outland",
	["屠魔山谷"] = "demon-fall-canyon",
	["深渊之喉"] = "abyssal-maw",
	["织亡者"] = "deathweaver",
	["祖尔金"] = "zuljin",
	["破碎岭"] = "crushridge",
	["埃基尔松"] = "akilzon",
	["奎尔萨拉斯"] = "quelthalas",
	["厄祖玛特"] = "ozumat",
	["伊森德雷"] = "ysondre",
	["达斯雷玛"] = "dathremar",
	["雷霆之怒"] = "thunder-bluff",
	["库尔提拉斯"] = "kul-tiras",
	["扎拉赞恩"] = "zalazane",
	["安威玛尔"] = "anvilmar",
	["恐怖图腾"] = "grimtotem",
	["阿克蒙德"] = "archimonde",
	["伊兰尼库斯"] = "eranikus",
	["古加尔"] = "chogall",
	["洛丹伦"] = "lordaeron",
	["黑铁"] = "dark-iron",
	["恶魔之魂"] = "demon-soul",
	["希尔瓦娜斯"] = "sylvanas",
	["大地之怒"] = "deepfury",
	["迪瑟洛克"] = "detheroc",
	["拉文凯斯"] = "ravencrest",
	["加兹鲁维"] = "gazlowe",
	["奥金顿"] = "auchindoun",
	["哈兰"] = "halaa",
	["丹莫德"] = "dun-modr",
	["克苏恩"] = "cthun",
	["通灵学院"] = "scholomance",
	["恶魔之翼"] = "direwing",
	["勇士岛"] = "fray-island",
	["雷霆之王"] = "thunderlord",
	["索拉丁"] = "thoradin",
	["达文格尔"] = "dalvengyr",
	["索瑞森"] = "thaurissan",
	["伊利丹"] = "illidan",
	["尘风峡谷"] = "dustwind-gulch",
	["试炼之环"] = "ring-of-trials",
	["图拉扬"] = "turalyon",
	["塞纳留斯"] = "cenarius",
	["海达希亚"] = "hydraxis",
	["瓦里玛萨斯"] = "varimathras",
	["伊瑟拉"] = "ysera",
	["艾森娜"] = "aessina",
	["轻风之语"] = "whisperwind",
	["月神殿"] = "temple-of-elune",
	["艾莫莉丝"] = "emeriss",
	["布鲁塔卢斯"] = "brutallus",
	["奎尔丹纳斯"] = "quedanas",
	["罗宁"] = "rhonin",
	["埃德萨拉"] = "eldrethalas",
	["菲米丝"] = "felmyst",
	["夏维安"] = "xavian",
	["元素之力"] = "force-of-elemental",
	["加尔"] = "garr",
	["黑龙军团"] = "black-dragonflight",
	["血吼"] = "gorehowl",
	["黑暗之门"] = "dark-portal",
	["盖斯"] = "gyth",
	["弗塞雷迦"] = "explorers-league",
	["安其拉"] = "ahnqiraj",
	["壁炉谷"] = "hearthglen",
	["霍格"] = "hogger",
	["主宰之剑"] = "the-masters-glaive",
	["圣火神殿"] = "shrine-of-the-dormant-flame",
	["桑德兰"] = "thunderaan",
	["亚雷戈斯"] = "arygos",
	["银松森林"] = "silverpine-forest",
	["阿拉索"] = "arathor",
	["阿迦玛甘"] = "agamaggan",
	["奥达曼"] = "uldaman",
	["甜水绿洲"] = "lushwater-oasis",
	["洛肯"] = "loken",
	["海克泰尔"] = "hectae",
	["影之哀伤"] = "shadowmourne",
	["风暴峭壁"] = "storm-peaks",
	["远古海滩"] = "strand-of-the-ancients",
	["瓦拉纳"] = "valanar",
	["冬拥湖"] = "wintergrasp",
	["迪托马斯"] = "destromath",
	["达基萨斯"] = "drakkisath",
	["死亡之翼"] = "deathwing",
	["提瑞斯法"] = "tirisfal-glades",
	["暗影议会"] = "shadow-council",
	["洛萨"] = "lothar",
	["阿卡玛"] = "akama",
	["萨格拉斯"] = "sargeras",
	["巫妖之王"] = "lich-king",
	["基尔罗格"] = "kilrogg",
	["迦顿"] = "geddon",
	["提尔之手"] = "tyrs-hand",
	["风暴之怒"] = "stormrage",
	["萨菲隆"] = "sapphiron",
	["灰谷"] = "ashenvale",
	["大漩涡"] = "maelstrom",
	["布莱克摩"] = "blackmoore",
	["国王之谷"] = "valley-of-kings",
	["白骨荒野"] = "bone-wastes",
	["千针石林"] = "thousand-needles",
	["刺骨利刃"] = "daggerspine",
	["能源舰"] = "the-mechanar",
	["达尔坎"] = "darkhan",
	["鹰巢山"] = "aerie-peak",
	["范达尔鹿盔"] = "staghelm",
	["石锤"] = "stonemaul",
	["末日行者"] = "doomwalker",
	["沙怒"] = "sandfury",
	["玛法里奥"] = "malfurion",
	["法拉希姆"] = "falathim",
	["雏龙之翼"] = "wing-of-the-whelping",
	["血羽"] = "bloodfeather",
	["森金"] = "senjin",
	["天空之墙"] = "skywall",
	["戈提克"] = "gothik",
	["玛维·影歌"] = "maiev-shadowsong",
	["嚎风峡湾"] = "howling-fjord",
	["闪电之刃"] = "lightnings-blade",
	["斯克提斯"] = "skettis",
	["埃雷达尔"] = "eredar",
	["永恒之井"] = "well-of-eternity",
	["雷克萨"] = "rexxar",
	["火喉"] = "firegut",
	["阿古斯"] = "argus",
	["激流堡"] = "stromgarde-keep",
	["艾维娜"] = "aviana",
	["艾露恩"] = "elune",
	["荆棘谷"] = "stranglethorn",
	["拉贾克斯"] = "rajaxx",
	["安苏"] = "anzu",
	["生态船"] = "the-botanica",
	["军团要塞"] = "legion-hold",
	["守护之剑"] = "guardian-blade",
	["瑞文戴尔"] = "rivendare",
	["阿比迪斯"] = "abbendis",
	["踏梦者"] = "dreamwalker",
	["阿曼尼"] = "amani",
	["奈法利安"] = "nefarian",
	["地狱咆哮"] = "hellscream",
	["贫瘠之地"] = "barrens",
	["迦拉克隆"] = "galakrond",
	["奥杜尔"] = "ulduar",
	["普瑞斯托"] = "prestor",
	["逐日者"] = "sunstrider",
	["安格博达"] = "angerboda",
	["冰霜之刃"] = "frostmane",
	["安加萨"] = "angrathar",
	["莱索恩"] = "lethon",
	["亡语者"] = "deathwhisper",
	["克尔苏加德"] = "kelthuzad",
	["奥尔加隆"] = "algalon",
	["达克萨隆"] = "draktharon",
	["阿纳克洛斯"] = "anachronos",
	["黑锋哨站"] = "ebon-watch",
	["熔火之心"] = "molten-core",
	["古达克"] = "gundrak",
	["梅尔加尼"] = "malganis",
	["兰娜瑟尔"] = "lanathel",
	["毁灭之锤"] = "doomhammer",
	["丽丽（四川）"] = "li-li",
	["晴日峰（江苏）"] = "peak-of-serenity",
	["辛达苟萨"] = "sindragosa",
	["暗影裂口"] = "cleft-of-shadow",
	["时光之穴"] = "caverns-of-time",
	["苏拉玛"] = "suramar",
	["瓦里安"] = "varian",
}
local REGION_NAME_FALLBACK = {
	[1] = "US",
	[2] = "KR",
	[3] = "EU",
	[4] = "TW",
	[5] = "CN",
}
local DEFAULT_ARMORY_LOCALE_BY_REGION = {
	cn = "zh-cn",
	eu = "en-gb",
	kr = "ko-kr",
	tw = "zh-tw",
	us = "en-us",
}

local TOOLTIP_LABEL_COLOR = { r = 1, g = 0.82, b = 0 }
local TOOLTIP_TEXT_COLOR = { r = 1, g = 1, b = 1 }
local TOOLTIP_GRAY_COLOR = { r = 0.5, g = 0.5, b = 0.5 }
local TOOLTIP_GREEN_COLOR = { r = 0, g = 1, b = 0 }

local function roleLabel(role)
	local L = GF.L or {}
	if role == "TANK" then
		return L.ROLE_TANK or "坦"
	end
	if role == "HEALER" then
		return L.ROLE_HEAL or "奶"
	end
	if role == "DAMAGER" then
		return L.ROLE_DPS or "DPS"
	end
	return nil
end

local function buildRoleText(memberData)
	if not memberData then
		return nil
	end
	local roles = {}
	for _, role in ipairs({ memberData.role1, memberData.role2, memberData.role3 }) do
		local label = roleLabel(role)
		if label then
			roles[#roles + 1] = label
		end
	end
	if #roles == 0 then
		return nil
	end
	return table.concat(roles, " / ")
end

local function normalizedColor(color, fallback)
	fallback = fallback or TOOLTIP_TEXT_COLOR
	if color and color.r and color.g and color.b then
		return color
	end
	return fallback
end

local function wrapColor(color, text)
	text = tostring(text or "")
	color = normalizedColor(color)
	if color.WrapTextInColorCode then
		return color:WrapTextInColorCode(text)
	end
	return string.format("|cff%02x%02x%02x%s|r",
		math.floor((color.r or 1) * 255 + 0.5),
		math.floor((color.g or 1) * 255 + 0.5),
		math.floor((color.b or 1) * 255 + 0.5),
		text)
end

local function setFontStringTextColor(fontString, color, fallback)
	if not fontString or not fontString.SetTextColor then
		return
	end
	color = normalizedColor(color, fallback or TOOLTIP_TEXT_COLOR)
	fontString:SetTextColor(color.r, color.g, color.b, color.a or 1)
end

local function getClassColor(memberData)
	if memberData and memberData.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[memberData.class] then
		return RAID_CLASS_COLORS[memberData.class]
	end
	return TOOLTIP_TEXT_COLOR
end

local function getDungeonScoreColor(score)
	if score and score > 0 and C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
		return C_ChallengeMode.GetDungeonScoreRarityColor(score) or HIGHLIGHT_FONT_COLOR or TOOLTIP_TEXT_COLOR
	end
	return TOOLTIP_GRAY_COLOR
end

local function getSpecificDungeonScoreColor(score)
	local cache = GF.MythicPlusRatingCache
	local rules = GF.MYTHIC_PLUS_SCORE_COLOR_RULE or {}
	if score and score > 0 and cache and cache.GetScoreColor then
		return cache:GetScoreColor(score, rules.SINGLE_DUNGEON)
			or HIGHLIGHT_FONT_COLOR or TOOLTIP_TEXT_COLOR
	end
	return TOOLTIP_GRAY_COLOR
end

local function safeFormat(formatText, fallback, ...)
	if type(formatText) == "string" then
		local ok, text = pcall(string.format, formatText, ...)
		if ok and text then
			return text
		end
	end
	return string.format(fallback, ...)
end

local function tooltipLocaleText(key, fallback)
	local L = GF.L or {}
	return L[key] or fallback
end

local function tooltipLocaleFormat(key, fallback, ...)
	return safeFormat(tooltipLocaleText(key, fallback), fallback, ...)
end

local function trimApplicantText(text)
	if type(text) ~= "string" then
		return nil
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text ~= "" then
		return text
	end
	return nil
end

local function currentApplicantMenuRealmName()
	local realm = GetNormalizedRealmName and GetNormalizedRealmName()
	if type(realm) ~= "string" or realm == "" then
		realm = GetRealmName and GetRealmName()
	end
	return trimApplicantText(realm)
end

local function splitApplicantCharacterName(name)
	name = trimApplicantText(name)
	if not name then
		return nil, nil
	end
	local characterName, realm = name:match("^([^%-]+)%-(.+)$")
	if not characterName then
		characterName = (Ambiguate and Ambiguate(name, "short")) or name
		realm = currentApplicantMenuRealmName()
	end
	characterName = trimApplicantText(characterName)
	realm = trimApplicantText(realm)
	return characterName, realm
end

local function urlEncodeComponent(text)
	text = tostring(text or "")
	return (text:gsub("([^%w%-%._~])", function(char)
		return string.format("%%%02X", string.byte(char))
	end))
end

local function getCurrentRegionNameToken()
	local regionName = GetCurrentRegionName and GetCurrentRegionName()
	if type(regionName) == "string" and regionName ~= "" then
		return string.upper(regionName)
	end
	local regionID = GetCurrentRegion and GetCurrentRegion()
	regionName = REGION_NAME_FALLBACK[tonumber(regionID) or 0]
	if regionName then
		return regionName
	end
	return "US"
end

local function getCurrentRegionForLinks()
	local regionName = getCurrentRegionNameToken()
	local region = string.lower(regionName)
	return region, regionName == "CN"
end

local function getCurrentArmoryLocale(region)
	local locale = GetLocale and GetLocale()
	if type(locale) == "string" and locale ~= "" then
		local formatted = locale:gsub("^(%l%l)(%u%u)$", "%1-%2"):lower()
		if formatted:find("-", 1, true) then
			return formatted
		end
	end
	return DEFAULT_ARMORY_LOCALE_BY_REGION[region or "us"] or "en-us"
end

local function normalizeApplicantRealmForLink(realm)
	realm = trimApplicantText(realm)
	if realm then
		return realm:gsub("%s+", "")
	end
	return nil
end

local function getApplicantArmoryRealmSlug(realm, isChina)
	realm = normalizeApplicantRealmForLink(realm)
	if not realm then
		return nil
	end
	if isChina then
		return CN_ARMORY_REALM_SLUGS[realm]
	end
	local asciiSlug = realm
		:gsub("(%l)(%u)", "%1-%2")
		:gsub("%s+", "-")
		:gsub("_", "-")
		:gsub("[%'%.]", "")
		:lower()
	if asciiSlug:match("^[%w%-]+$") then
		return asciiSlug
	end
	return urlEncodeComponent(realm)
end

local function getApplicantWclRealm(realm)
	return normalizeApplicantRealmForLink(realm)
end

local function buildApplicantWclUrl(region, characterName, realm)
	local wclRealm = getApplicantWclRealm(realm)
	if not wclRealm then
		return nil
	end
	return string.format(WCL_CHARACTER_URL_FMT, region, region, wclRealm, characterName)
end

local function buildApplicantArmoryInfoUrl(region, isChina, characterName, realm)
	local armoryRealm = getApplicantArmoryRealmSlug(realm, isChina)
	if not armoryRealm then
		return nil
	end
	local encodedCharacterName = urlEncodeComponent(characterName)
	if isChina then
		return string.format(CN_ARMORY_CHARACTER_URL_FMT, armoryRealm, encodedCharacterName)
	end
	return string.format(GLOBAL_ARMORY_CHARACTER_URL_FMT, getCurrentArmoryLocale(region), region, armoryRealm, encodedCharacterName)
end

local function buildApplicantCharacterLinks(name)
	local characterName, realm = splitApplicantCharacterName(name)
	realm = normalizeApplicantRealmForLink(realm)
	if not characterName or not realm then
		return nil
	end
	local region, isChina = getCurrentRegionForLinks()
	local wclUrl = buildApplicantWclUrl(region, characterName, realm)
	local armoryInfoUrl = buildApplicantArmoryInfoUrl(region, isChina, characterName, realm)
	if not wclUrl or not armoryInfoUrl then
		return nil
	end
	return {
		wcl = wclUrl,
		armory = armoryInfoUrl,
	}
end

local function whisperApplicant(name)
	if not name or name == "" then
		return
	end
	if ChatFrameUtil and ChatFrameUtil.SendTell then
		ChatFrameUtil.SendTell(name)
	elseif ChatFrame_OpenChat then
		ChatFrame_OpenChat("/w " .. name .. " ", SELECTED_DOCK_FRAME)
	end
end

local function applyFontStringSizeOverride(fontString, template, size, flags)
	if not fontString or not GF.Font then
		return
	end
	fontString._gfFontSizeOverride = size
	fontString._gfFontFlagsOverride = flags
	if GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fontString, template or fontString._gfFontTemplate or "GameFontNormal")
	end
end

local function centerPanelButtonText(button)
	if not button or not button.GetFontString then
		return
	end
	local fs = button:GetFontString()
	if not fs then
		return
	end
	fs:ClearAllPoints()
	fs:SetPoint("CENTER", button, "CENTER", 0, 0)
	fs:SetJustifyH("CENTER")
	if fs.SetJustifyV then
		fs:SetJustifyV("MIDDLE")
	end
	fs:SetWidth(math.max(1, button:GetWidth() or GF.PANEL_BUTTON_STANDARD_W or 72))
	fs:SetHeight(math.max(1, button:GetHeight() or GF.PANEL_BUTTON_H or 22))
end

function ApplicantCharacterInfo.getChallengeModeMapName(challengeModeID, fallback)
	challengeModeID = tonumber(challengeModeID)
	if challengeModeID and challengeModeID > 0 and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
		local ok, name = pcall(C_ChallengeMode.GetMapUIInfo, challengeModeID)
		if ok and type(name) == "string" and name ~= "" then
			return name
		end
	end
	return trimApplicantText(fallback) or ""
end

function ApplicantCharacterInfo.formatCharacterInfoKeyLevel(level)
	level = tonumber(level)
	if not level or level <= 0 then
		return "-"
	end
	return tooltipLocaleFormat("APPLICANT_MYTHIC_PROFILE_KEY_LEVEL_FMT", "+%d", level)
end

function ApplicantCharacterInfo.formatCharacterInfoMilestoneLabel(level)
	level = tonumber(level)
	if not level or level <= 0 then
		return ""
	end
	local upper = ApplicantCharacterInfo.TIMED_BUCKET_UPPER_BY_LEVEL[level]
	if upper then
		return tooltipLocaleFormat("APPLICANT_MYTHIC_PROFILE_TIMED_RANGE_FMT", "Timed +%d-%d Mythic+", level, upper)
	end
	return tooltipLocaleFormat("APPLICANT_MYTHIC_PROFILE_TIMED_MIN_FMT", "Timed %d+ Mythic+", level)
end

function ApplicantCharacterInfo.chooseBetterCharacterInfoRun(current, candidate)
	if not candidate then
		return current
	end
	if not current then
		return candidate
	end
	local currentLevel = tonumber(current.level) or 0
	local candidateLevel = tonumber(candidate.level) or 0
	if candidateLevel > currentLevel then
		return candidate
	end
	if candidateLevel == currentLevel and candidate.timed and not current.timed then
		return candidate
	end
	return current
end

function ApplicantCharacterInfo.addCharacterInfoDungeonRecord(profile, record)
	if not (profile and record) then
		return
	end
	record.level = tonumber(record.level)
	if not record.level or record.level <= 0 then
		return
	end
	record.mapName = trimApplicantText(record.mapName)
	if not record.mapName then
		return
	end
	profile.hasData = true
	profile.bestOverall = ApplicantCharacterInfo.chooseBetterCharacterInfoRun(profile.bestOverall, record)
	for i = 1, #profile.dungeonRecords do
		local existing = profile.dungeonRecords[i]
		local sameMap = (record.mapID and existing.mapID and record.mapID == existing.mapID)
			or (record.mapName == existing.mapName)
		if sameMap then
			profile.dungeonRecords[i] = ApplicantCharacterInfo.chooseBetterCharacterInfoRun(existing, record)
			return
		end
	end
	profile.dungeonRecords[#profile.dungeonRecords + 1] = record
end

function ApplicantCharacterInfo.setCharacterInfoOverall(profile, score)
	score = tonumber(score)
	if not score or score <= 0 then
		return
	end
	profile.hasData = true
	if not profile.overall or score > profile.overall then
		profile.overall = score
	end
end

function ApplicantCharacterInfo.normalizeBlizzardCharacterInfoRun(detail)
	if type(detail) ~= "table" then
		return nil
	end
	local level = tonumber(detail.bestRunLevel)
	if not level or level <= 0 then
		return nil
	end
	local mapID = detail.challengeModeID or detail.mapChallengeModeID or detail.mapID
	local mapName = ApplicantCharacterInfo.getChallengeModeMapName(mapID, detail.mapName)
	return {
		mapID = tonumber(mapID),
		mapName = mapName,
		level = level,
		timed = detail.finishedSuccess ~= false,
		upgrades = tonumber(detail.bestLevelIncrement) or 0,
		mapScore = tonumber(detail.mapScore),
	}
end

function ApplicantCharacterInfo.applyBlizzardCharacterInfoData(profile, memberData)
	if not (profile and memberData) then
		return
	end
	local detail = memberData.mplusProfileDetail
	if type(detail) ~= "table" and memberData.ratingKind == "mplus" then
		detail = memberData.ratingDetail
	end
	if type(detail) ~= "table" then
		return
	end
	ApplicantCharacterInfo.setCharacterInfoOverall(profile, detail.overall)
	ApplicantCharacterInfo.addCharacterInfoDungeonRecord(profile, ApplicantCharacterInfo.normalizeBlizzardCharacterInfoRun(detail.currentDungeon or detail))
	ApplicantCharacterInfo.addCharacterInfoDungeonRecord(profile, ApplicantCharacterInfo.normalizeBlizzardCharacterInfoRun(detail.bestOverallScore))
end

function ApplicantCharacterInfo.tryGetRaiderIOProfile(rio, characterName, realm, region)
	if not (rio and type(rio.GetProfile) == "function" and characterName and realm) then
		return nil
	end
	local ok, profile = pcall(rio.GetProfile, characterName, realm, region)
	if ok and type(profile) == "table" and type(profile.mythicKeystoneProfile) == "table" then
		return profile
	end
	local normalizedRealm = normalizeApplicantRealmForLink(realm)
	if normalizedRealm and normalizedRealm ~= realm then
		ok, profile = pcall(rio.GetProfile, characterName, normalizedRealm, region)
		if ok and type(profile) == "table" and type(profile.mythicKeystoneProfile) == "table" then
			return profile
		end
	end
	ok, profile = pcall(rio.GetProfile, characterName .. "-" .. realm, nil, region)
	if ok and type(profile) == "table" and type(profile.mythicKeystoneProfile) == "table" then
		return profile
	end
	return nil
end

function ApplicantCharacterInfo.getApplicantRaiderIOProfile(name)
	local rio = _G and _G.RaiderIO
	if not (rio and type(rio.GetProfile) == "function") then
		return nil
	end
	local characterName, realm = splitApplicantCharacterName(name)
	if not characterName or not realm then
		return nil
	end
	local region = string.lower(getCurrentRegionNameToken() or "")
	return ApplicantCharacterInfo.tryGetRaiderIOProfile(rio, characterName, realm, region)
end

function ApplicantCharacterInfo.applyRaiderIOCharacterInfoData(profile, name)
	local rioProfile = ApplicantCharacterInfo.getApplicantRaiderIOProfile(name)
	local keystoneProfile = rioProfile and rioProfile.mythicKeystoneProfile
	if not (profile and type(keystoneProfile) == "table") then
		return
	end
	if keystoneProfile.blocked or keystoneProfile.blockedPurged then
		return
	end
	ApplicantCharacterInfo.setCharacterInfoOverall(profile, keystoneProfile.currentScore or (keystoneProfile.mplusCurrent and keystoneProfile.mplusCurrent.score))

	if type(keystoneProfile.sortedMilestones) == "table" then
		for i = 1, #keystoneProfile.sortedMilestones do
			local milestone = keystoneProfile.sortedMilestones[i]
			local level = milestone and tonumber(milestone.level)
			local text = milestone and milestone.text
			if level and level > 0 and text and text ~= "" then
				profile.hasData = true
				profile.milestones[#profile.milestones + 1] = {
					level = level,
					text = tostring(text),
				}
			end
		end
	end

	local maxDungeon = keystoneProfile.maxDungeon
	if maxDungeon and tonumber(keystoneProfile.maxDungeonLevel) and tonumber(keystoneProfile.maxDungeonLevel) > 0 then
		local mapID = tonumber(maxDungeon.keystone_instance)
		local fallbackName = maxDungeon.name or maxDungeon.shortNameLocale or maxDungeon.shortName
		ApplicantCharacterInfo.addCharacterInfoDungeonRecord(profile, {
			mapID = mapID,
			mapName = ApplicantCharacterInfo.getChallengeModeMapName(mapID, fallbackName),
			level = tonumber(keystoneProfile.maxDungeonLevel),
			timed = (tonumber(keystoneProfile.maxDungeonUpgrades) or 0) > 0,
			upgrades = tonumber(keystoneProfile.maxDungeonUpgrades) or 0,
		})
	end

	if type(keystoneProfile.sortedDungeons) == "table" then
		for i = 1, #keystoneProfile.sortedDungeons do
			if #profile.dungeonRecords >= ApplicantCharacterInfo.MAX_DUNGEON_ROWS then
				break
			end
			local sortedDungeon = keystoneProfile.sortedDungeons[i]
			local level = sortedDungeon and tonumber(sortedDungeon.level)
			local dungeon = sortedDungeon and sortedDungeon.dungeon
			if level and level > 0 and dungeon then
				local mapID = tonumber(dungeon.keystone_instance)
				local fallbackName = dungeon.name or dungeon.shortNameLocale or dungeon.shortName
				ApplicantCharacterInfo.addCharacterInfoDungeonRecord(profile, {
					mapID = mapID,
					mapName = ApplicantCharacterInfo.getChallengeModeMapName(mapID, fallbackName),
					level = level,
					timed = (tonumber(sortedDungeon.chests) or 0) > 0,
					upgrades = tonumber(sortedDungeon.chests) or 0,
				})
			end
		end
	end
end

function ApplicantCharacterInfo.buildApplicantCharacterInfoProfile(name, memberData)
	local profile = {
		overall = nil,
		bestOverall = nil,
		milestones = {},
		dungeonRecords = {},
		hasData = false,
	}
	ApplicantCharacterInfo.applyRaiderIOCharacterInfoData(profile, name)
	ApplicantCharacterInfo.applyBlizzardCharacterInfoData(profile, memberData)
	table.sort(profile.dungeonRecords, function(a, b)
		local aLevel = tonumber(a.level) or 0
		local bLevel = tonumber(b.level) or 0
		if aLevel == bLevel then
			return tostring(a.mapName or "") < tostring(b.mapName or "")
		end
		return aLevel > bLevel
	end)
	return profile
end

function ApplicantCharacterInfo.formatCharacterInfoRunValue(record, includeMapName)
	if not record then
		return wrapColor(TOOLTIP_GRAY_COLOR, "-")
	end
	local levelColor = record.timed and TOOLTIP_GREEN_COLOR or TOOLTIP_GRAY_COLOR
	local text = wrapColor(levelColor, ApplicantCharacterInfo.formatCharacterInfoKeyLevel(record.level))
	if includeMapName and record.mapName and record.mapName ~= "" then
		text = text .. " " .. wrapColor(getSpecificDungeonScoreColor(record.mapScore), record.mapName)
	end
	return text
end

function ApplicantCharacterInfo.formatCharacterInfoRunLevel(record)
	local level = record and tonumber(record.level)
	if not level or level <= 0 then
		return "-"
	end
	return tooltipLocaleFormat("APPLICANT_MYTHIC_PROFILE_RUN_LEVEL_FMT", "%d", level)
end

function ApplicantCharacterInfo.formatCharacterInfoRunStatus(record)
	if not record then
		return tooltipLocaleText("APPLICANT_MYTHIC_PROFILE_OVER_TIME", "Over time"), TOOLTIP_GRAY_COLOR
	end
	if record.timed then
		local upgrades = tonumber(record.upgrades) or 0
		local level = tonumber(record.level) or 0
		local baseLevel = level - upgrades
		if upgrades > 0 and baseLevel > 0 then
			return tooltipLocaleFormat("APPLICANT_MYTHIC_PROFILE_TIMED_UPGRADE_FMT", "%d + %d timed", baseLevel, upgrades), TOOLTIP_GREEN_COLOR
		end
		return tooltipLocaleText("APPLICANT_MYTHIC_PROFILE_TIMED", "Timed"), TOOLTIP_GREEN_COLOR
	end
	return tooltipLocaleText("APPLICANT_MYTHIC_PROFILE_OVER_TIME", "Over time"), TOOLTIP_GRAY_COLOR
end

function ApplicantCharacterInfo.addCharacterInfoLine(rows, label, value, labelColor, valueColor, height, fullWidth)
	local row = {
		label = label,
		value = value,
		labelColor = labelColor or TOOLTIP_LABEL_COLOR,
		valueColor = valueColor or TOOLTIP_TEXT_COLOR,
		height = height or ApplicantCharacterInfo.ROW_H,
		fullWidth = fullWidth,
	}
	rows[#rows + 1] = row
	return row
end

function ApplicantCharacterInfo.addCharacterInfoSpacer(rows)
	rows[#rows + 1] = {
		divider = true,
		height = ApplicantCharacterInfo.DIVIDER_H,
	}
end

function ApplicantCharacterInfo.stripLabelSuffix(label)
	label = tostring(label or "")
	label = label:gsub("%s+$", "")
	return label:gsub("[:：]%s*$", "")
end

function ApplicantCharacterInfo.getMode(memberData)
	local activityInfo = memberData and memberData.activityInfo
	local categoryID = activityInfo and activityInfo.categoryID
	if categoryID == GF.CAT_DUNGEON or (activityInfo and activityInfo.isMythicPlusActivity) then
		return "mplus"
	end
	if categoryID == GF.CAT_RAID or (activityInfo and activityInfo.isCurrentRaidActivity) then
		return "raid"
	end
	return "links"
end

function ApplicantCharacterInfo.appendRaidBasicInfoRows(rows, memberData)
	local L = GF.L or {}
	if memberData and memberData.level and memberData.level > 0 then
		ApplicantCharacterInfo.addCharacterInfoLine(rows,
			ApplicantCharacterInfo.stripLabelSuffix(LEVEL or L.APPLICANT_LEVEL_FMT or "Level"),
			tostring(memberData.level),
			TOOLTIP_LABEL_COLOR,
			TOOLTIP_TEXT_COLOR)
	end
	local specClass = ""
	if memberData and memberData.specName and memberData.specName ~= "" then
		specClass = memberData.specName
	end
	if memberData and memberData.localizedClass and memberData.localizedClass ~= "" then
		specClass = specClass .. memberData.localizedClass
	end
	if specClass ~= "" then
		local classColor = getClassColor(memberData)
		ApplicantCharacterInfo.addCharacterInfoLine(rows,
			L.COL_APP_CLASS or "Spec",
			wrapColor(classColor, specClass),
			TOOLTIP_LABEL_COLOR,
			TOOLTIP_TEXT_COLOR)
	end
	local roleText = buildRoleText(memberData)
	if roleText and roleText ~= "" then
		ApplicantCharacterInfo.addCharacterInfoLine(rows,
			L.COL_APP_ROLE or "Role",
			roleText,
			TOOLTIP_LABEL_COLOR,
			TOOLTIP_TEXT_COLOR)
	end
	if memberData and memberData.ilvl and memberData.ilvl > 0 then
		ApplicantCharacterInfo.addCharacterInfoLine(rows,
			L.COL_ILVL or ITEM_LEVEL or "Item Level",
			tostring(memberData.ilvl),
			TOOLTIP_LABEL_COLOR,
			TOOLTIP_TEXT_COLOR)
	end
end

function ApplicantCharacterInfo.appendRows(target, source)
	for i = 1, #source do
		target[#target + 1] = source[i]
	end
end

function ApplicantCharacterInfo.buildApplicantRaidInfoRows(name, memberData)
	local L = GF.L or {}
	local rows = {}
	local mainTitle = ApplicantCharacterInfo.addCharacterInfoLine(rows,
		L.APPLICANT_RAID_PROGRESS_TITLE or "Raid Progress",
		"",
		TOOLTIP_LABEL_COLOR,
		TOOLTIP_LABEL_COLOR,
		ApplicantCharacterInfo.MAIN_TITLE_ROW_H,
		true)
	mainTitle.align = "CENTER"
	mainTitle.fontSize = ApplicantCharacterInfo.MAIN_TITLE_FONT_SIZE
	ApplicantCharacterInfo.appendRaidBasicInfoRows(rows, memberData)

	local providerRows, hasProvider
	if GF.ApplicantRaidTooltip and GF.ApplicantRaidTooltip.BuildCharacterInfoRows then
		providerRows, hasProvider = GF.ApplicantRaidTooltip.BuildCharacterInfoRows(name, memberData)
	end
	if providerRows and #providerRows > 0 then
		ApplicantCharacterInfo.addCharacterInfoSpacer(rows)
		ApplicantCharacterInfo.appendRows(rows, providerRows)
	else
		ApplicantCharacterInfo.addCharacterInfoSpacer(rows)
		ApplicantCharacterInfo.addCharacterInfoLine(rows,
			L.APPLICANT_RAID_PROGRESS_NO_DATA or "No raid progress data",
			"",
			TOOLTIP_GRAY_COLOR,
			TOOLTIP_GRAY_COLOR,
			ApplicantCharacterInfo.ROW_H,
			true)
	end
	return rows, hasProvider
end

function ApplicantCharacterInfo.buildApplicantCharacterInfoRows(name, memberData)
	local L = GF.L or {}
	local profile = ApplicantCharacterInfo.buildApplicantCharacterInfoProfile(name, memberData)
	local rows = {}
	if not profile.hasData then
		ApplicantCharacterInfo.addCharacterInfoLine(rows, L.APPLICANT_MYTHIC_PROFILE_NO_DATA or "No Mythic+ profile data available", "", TOOLTIP_GRAY_COLOR, TOOLTIP_GRAY_COLOR, ApplicantCharacterInfo.ROW_H, true)
		return rows
	end

	local mainTitle = ApplicantCharacterInfo.addCharacterInfoLine(rows, L.APPLICANT_MYTHIC_PROFILE_OVERVIEW or "Mythic+ Info", "", TOOLTIP_LABEL_COLOR, TOOLTIP_LABEL_COLOR, ApplicantCharacterInfo.MAIN_TITLE_ROW_H, true)
	mainTitle.align = "CENTER"
	mainTitle.fontSize = ApplicantCharacterInfo.MAIN_TITLE_FONT_SIZE
	local scoreText = profile.overall and profile.overall > 0
		and wrapColor(getDungeonScoreColor(profile.overall), tostring(profile.overall))
		or wrapColor(TOOLTIP_GRAY_COLOR, "-")
	ApplicantCharacterInfo.addCharacterInfoLine(rows, L.APPLICANT_MYTHIC_PROFILE_SCORE or "Mythic+ Rating", scoreText, TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
	ApplicantCharacterInfo.addCharacterInfoLine(rows, L.APPLICANT_MYTHIC_PROFILE_BEST_RUN or "Best Run", ApplicantCharacterInfo.formatCharacterInfoRunValue(profile.bestOverall, true), TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR)

	if #profile.milestones > 0 then
		ApplicantCharacterInfo.addCharacterInfoSpacer(rows)
		ApplicantCharacterInfo.addCharacterInfoLine(rows, L.APPLICANT_MYTHIC_PROFILE_TIMED_RECORDS or "Timed Run Records", "", TOOLTIP_LABEL_COLOR, TOOLTIP_LABEL_COLOR, ApplicantCharacterInfo.ROW_H, true)
		for i = 1, #profile.milestones do
			local milestone = profile.milestones[i]
			local label = ApplicantCharacterInfo.formatCharacterInfoMilestoneLabel(milestone.level)
			if label ~= "" then
				ApplicantCharacterInfo.addCharacterInfoLine(rows, label, tostring(milestone.text), TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR)
			end
		end
	end

	if #profile.dungeonRecords > 0 then
		ApplicantCharacterInfo.addCharacterInfoSpacer(rows)
		ApplicantCharacterInfo.addCharacterInfoLine(rows, L.APPLICANT_MYTHIC_PROFILE_BEST_DUNGEON_RECORDS or "Best Dungeon Records", "", TOOLTIP_LABEL_COLOR, TOOLTIP_LABEL_COLOR, ApplicantCharacterInfo.ROW_H, true)
		local count = math.min(#profile.dungeonRecords, ApplicantCharacterInfo.MAX_DUNGEON_ROWS)
		for i = 1, count do
			local record = profile.dungeonRecords[i]
			local statusText, statusColor = ApplicantCharacterInfo.formatCharacterInfoRunStatus(record)
			local row = ApplicantCharacterInfo.addCharacterInfoLine(rows, record.mapName, ApplicantCharacterInfo.formatCharacterInfoRunLevel(record), TOOLTIP_TEXT_COLOR, record.timed and TOOLTIP_GREEN_COLOR or TOOLTIP_GRAY_COLOR)
			row.runResult = statusText
			row.runResultColor = statusColor
		end
	end
	return rows
end

function ApplicantCharacterInfo.applyProfilePanelStyle(panel)
	if not panel then
		return false
	end
	if panel.SetBackdrop then
		panel:SetBackdrop(nil)
	end
	if GF.UI and GF.UI.ApplyControlCardChrome then
		local chrome = GF.UI.ApplyControlCardChrome(panel, {
			state = "normal",
			displayMargin = GF.CONTROL_FRAME_DISPLAY_MARGIN or 8,
		})
		if chrome then
			if GF.UI.SetControlCardChromeShown then
				GF.UI.SetControlCardChromeShown(panel, true)
			end
			return true
		end
	end
	if panel.SetBackdrop then
		panel:SetBackdrop({
			bgFile = GF.WHITE_TEXTURE,
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false,
			edgeSize = 12,
			insets = {
				left = 3,
				right = 3,
				top = 3,
				bottom = 3,
			},
		})
		panel:SetBackdropColor(0.015, 0.012, 0.008, 0.66)
		panel:SetBackdropBorderColor(0.55, 0.43, 0.18, 0.78)
	end
	return false
end

local function applyProfileDividerStyle(divider)
	if not divider then
		return false
	end
	local color = GF.BROWSE_HEADER_TEXT_COLOR or { 1, 0.82, 0, 1 }
	local hasAtlas = GF.UI
		and GF.UI.TrySetAtlas
		and GF.UI.TrySetAtlas(
			divider,
			ApplicantCharacterInfo.PROFILE_DIVIDER_ATLAS,
			false)
	if not hasAtlas then
		if divider.SetColorTexture then
			divider:SetColorTexture(
				color[1] or 1,
				color[2] or 0.82,
				color[3] or 0,
				color[4] or 1)
		else
			divider:SetTexture(GF.WHITE_TEXTURE)
			divider:SetVertexColor(
				color[1] or 1,
				color[2] or 0.82,
				color[3] or 0,
				color[4] or 1)
		end
		divider:SetHeight(1)
		return false
	end
	divider:SetHeight(ApplicantCharacterInfo.PROFILE_DIVIDER_HEIGHT)
	divider:SetVertexColor(
		color[1] or 1,
		color[2] or 0.82,
		color[3] or 0,
		color[4] or 1)
	return true
end

function ApplicantCharacterInfo.createApplicantCharacterInfoRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(ApplicantCharacterInfo.CONTENT_W, ApplicantCharacterInfo.ROW_H)
	row.label = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	row.label:SetPoint("LEFT", row, "LEFT", ApplicantCharacterInfo.PANEL_PAD_X, 0)
	row.label:SetSize(ApplicantCharacterInfo.LABEL_W, ApplicantCharacterInfo.ROW_H)
	row.label:SetJustifyH("LEFT")
	if row.label.SetWordWrap then
		row.label:SetWordWrap(false)
	end
	applyFontStringSizeOverride(row.label, "GameFontHighlightSmall", 14, "")

	row.value = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.value:SetSize(ApplicantCharacterInfo.VALUE_W, ApplicantCharacterInfo.ROW_H)
	row.value:SetJustifyH("RIGHT")
	if row.value.SetWordWrap then
		row.value:SetWordWrap(false)
	end
	applyFontStringSizeOverride(row.value, "GameFontHighlightSmall", 14, "")
	row.runResult = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	row.runResult:SetSize(ApplicantCharacterInfo.RUN_STATUS_W, ApplicantCharacterInfo.ROW_H)
	row.runResult:SetJustifyH("RIGHT")
	if row.runResult.SetWordWrap then
		row.runResult:SetWordWrap(false)
	end
	applyFontStringSizeOverride(row.runResult, "GameFontHighlightSmall", 14, "")
	row.rule = row:CreateTexture(nil, "ARTWORK")
	applyProfileDividerStyle(row.rule)
	row.rule:Hide()
	row:Hide()
	return row
end

function ApplicantCharacterInfo.applyApplicantCharacterInfoRows(frame, rows)
	if not frame then
		return ApplicantCharacterInfo.PANEL_TOP_Y
	end
	rows = rows or {}
	local panel = frame.profilePanel or frame
	if frame.profilePanel then
		frame.profilePanel:Show()
	end
	local y = -ApplicantCharacterInfo.PANEL_PAD_TOP
	local usedHeight = ApplicantCharacterInfo.PANEL_PAD_TOP
	for i = 1, ApplicantCharacterInfo.MAX_PROFILE_ROWS do
		local row = frame.profileRows and frame.profileRows[i]
		local data = rows[i]
		if row and data then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
			row:SetSize(ApplicantCharacterInfo.CONTENT_W, data.height or ApplicantCharacterInfo.ROW_H)
			row.label:ClearAllPoints()
			row.value:ClearAllPoints()
			if row.rule then
				row.rule:ClearAllPoints()
				row.rule:Hide()
			end
			if data.divider then
				row.label:SetText("")
				row.label:Hide()
				row.value:SetText("")
				row.value:Hide()
				row.runResult:SetText("")
				row.runResult:Hide()
				row.rule:SetPoint("LEFT", row, "LEFT", ApplicantCharacterInfo.PANEL_PAD_X, 0)
				row.rule:SetPoint("RIGHT", row, "RIGHT", -ApplicantCharacterInfo.PANEL_PAD_X, 0)
				row.rule:Show()
			elseif data.fullWidth then
				row.label:SetPoint("LEFT", row, "LEFT", ApplicantCharacterInfo.PANEL_PAD_X, 0)
				row.label:SetSize(ApplicantCharacterInfo.CONTENT_W - (ApplicantCharacterInfo.PANEL_PAD_X * 2), data.height or ApplicantCharacterInfo.ROW_H)
				row.label:SetJustifyH(data.align or "LEFT")
				applyFontStringSizeOverride(row.label, "GameFontNormal", data.fontSize or ApplicantCharacterInfo.ROW_FONT_SIZE, "")
				row.label:Show()
				row.value:Hide()
				row.runResult:SetText("")
				row.runResult:Hide()
				row.label:SetText(data.label or "")
				setFontStringTextColor(row.label, data.labelColor, TOOLTIP_LABEL_COLOR)
			elseif data.runResult then
				row.label:SetPoint("LEFT", row, "LEFT", ApplicantCharacterInfo.PANEL_PAD_X, 0)
				row.label:SetSize(ApplicantCharacterInfo.RUN_LABEL_W, data.height or ApplicantCharacterInfo.ROW_H)
				row.label:SetJustifyH("LEFT")
				applyFontStringSizeOverride(row.label, "GameFontHighlightSmall", ApplicantCharacterInfo.ROW_FONT_SIZE, "")
				row.label:SetText(data.label or "")
				setFontStringTextColor(row.label, data.labelColor, TOOLTIP_TEXT_COLOR)
				row.label:Show()

				row.value:SetPoint("RIGHT", row, "RIGHT", -(ApplicantCharacterInfo.VALUE_RIGHT_PAD + ApplicantCharacterInfo.RUN_STATUS_W + ApplicantCharacterInfo.RUN_VALUE_GAP), 0)
				row.value:SetSize(ApplicantCharacterInfo.RUN_LEVEL_W, data.height or ApplicantCharacterInfo.ROW_H)
				applyFontStringSizeOverride(row.value, "GameFontHighlightSmall", ApplicantCharacterInfo.ROW_FONT_SIZE, "")
				row.value:SetText(data.value or "")
				setFontStringTextColor(row.value, data.valueColor, TOOLTIP_TEXT_COLOR)
				row.value:Show()

				row.runResult:SetPoint("RIGHT", row, "RIGHT", -ApplicantCharacterInfo.VALUE_RIGHT_PAD, 0)
				row.runResult:SetSize(ApplicantCharacterInfo.RUN_STATUS_W, data.height or ApplicantCharacterInfo.ROW_H)
				applyFontStringSizeOverride(row.runResult, "GameFontHighlightSmall", ApplicantCharacterInfo.ROW_FONT_SIZE, "")
				row.runResult:SetText(data.runResult or "")
				setFontStringTextColor(row.runResult, data.runResultColor, TOOLTIP_TEXT_COLOR)
				row.runResult:Show()
			elseif data.wideValue then
				row.label:SetPoint("LEFT", row, "LEFT", ApplicantCharacterInfo.PANEL_PAD_X, 0)
				row.label:SetSize(ApplicantCharacterInfo.RAID_PROVIDER_LABEL_W, data.height or ApplicantCharacterInfo.ROW_H)
				row.label:SetJustifyH("LEFT")
				applyFontStringSizeOverride(row.label, "GameFontHighlightSmall", ApplicantCharacterInfo.ROW_FONT_SIZE, "")
				row.label:SetText(data.label or "")
				setFontStringTextColor(row.label, data.labelColor, TOOLTIP_TEXT_COLOR)
				row.label:Show()

				row.value:SetPoint("RIGHT", row, "RIGHT", -ApplicantCharacterInfo.VALUE_RIGHT_PAD, 0)
				row.value:SetSize(ApplicantCharacterInfo.RAID_PROVIDER_VALUE_W - ApplicantCharacterInfo.VALUE_RIGHT_PAD, data.height or ApplicantCharacterInfo.ROW_H)
				row.value:SetJustifyH("RIGHT")
				applyFontStringSizeOverride(row.value, "GameFontHighlightSmall", ApplicantCharacterInfo.ROW_FONT_SIZE, "")
				row.value:SetText(data.value or "")
				setFontStringTextColor(row.value, data.valueColor, TOOLTIP_TEXT_COLOR)
				row.value:Show()

				row.runResult:SetText("")
				row.runResult:Hide()
			else
				row.label:SetPoint("LEFT", row, "LEFT", ApplicantCharacterInfo.PANEL_PAD_X, 0)
				row.label:SetSize(ApplicantCharacterInfo.LABEL_W, data.height or ApplicantCharacterInfo.ROW_H)
				row.label:SetJustifyH("LEFT")
				applyFontStringSizeOverride(row.label, "GameFontHighlightSmall", ApplicantCharacterInfo.ROW_FONT_SIZE, "")
				row.label:Show()
				row.value:SetPoint("RIGHT", row, "RIGHT", -ApplicantCharacterInfo.VALUE_RIGHT_PAD, 0)
				row.value:SetSize(ApplicantCharacterInfo.VALUE_W - ApplicantCharacterInfo.VALUE_RIGHT_PAD, data.height or ApplicantCharacterInfo.ROW_H)
				row.value:SetJustifyH("RIGHT")
				applyFontStringSizeOverride(row.value, "GameFontHighlightSmall", ApplicantCharacterInfo.ROW_FONT_SIZE, "")
				row.value:SetText(data.value or "")
				setFontStringTextColor(row.value, data.valueColor, TOOLTIP_TEXT_COLOR)
				row.value:Show()
				row.runResult:SetText("")
				row.runResult:Hide()
				row.label:SetText(data.label or "")
				setFontStringTextColor(row.label, data.labelColor, TOOLTIP_LABEL_COLOR)
			end
			row:Show()
			y = y - (data.height or ApplicantCharacterInfo.ROW_H)
			usedHeight = usedHeight + (data.height or ApplicantCharacterInfo.ROW_H)
		elseif row then
			row:Hide()
		end
	end
	usedHeight = usedHeight + ApplicantCharacterInfo.PANEL_PAD_BOTTOM
	if frame.profilePanel then
		frame.profilePanel:SetHeight(usedHeight)
	end
	return ApplicantCharacterInfo.PANEL_TOP_Y - usedHeight
end

function ApplicantCharacterInfo.hideApplicantCharacterInfoRows(frame)
	if not frame then
		return
	end
	if frame.profilePanel then
		frame.profilePanel:Hide()
	end
	for i = 1, ApplicantCharacterInfo.MAX_PROFILE_ROWS do
		local row = frame.profileRows and frame.profileRows[i]
		if row then
			row:Hide()
		end
	end
end

local function setMainWindowDimmed(dialog, dimmed)
	local mainController = GF.MainFrame
	local mainFrame = mainController and mainController.frame
	if not (mainFrame and mainFrame.SetAlpha) then
		return
	end
	if dimmed then
		if mainController.CanApplyPresentationAlpha
			and not mainController:CanApplyPresentationAlpha()
		then
			return
		end
		if dialog._previousMainAlpha == nil then
			dialog._previousMainAlpha = mainFrame.GetAlpha
				and mainFrame:GetAlpha() or 1
		end
		mainFrame:SetAlpha(ApplicantCharacterInfo.MAIN_WINDOW_DIM_ALPHA)
	elseif dialog._previousMainAlpha ~= nil then
		local previous = tonumber(dialog._previousMainAlpha) or 1
		dialog._previousMainAlpha = nil
		mainFrame:SetAlpha(previous)
	end
end

local function applyDialogTopLayer(dialog)
	if not dialog then
		return
	end
	if dialog.SetFrameStrata then
		dialog:SetFrameStrata("DIALOG")
	end
	if dialog.SetFrameLevel then
		dialog:SetFrameLevel(ApplicantCharacterInfo.DIALOG_FRAME_LEVEL)
	end
	local closeButton = dialog.ClosePanelButton
	if closeButton and closeButton.SetFrameLevel then
		closeButton:SetFrameLevel(
			ApplicantCharacterInfo.DIALOG_FRAME_LEVEL + 20)
	end
	if dialog.Raise then
		dialog:Raise()
	end
end

local function ensureApplicantCharacterInfoDialog()
	if ApplicantCharacterInfo.characterInfoDialog then
		return ApplicantCharacterInfo.characterInfoDialog
	end
	local L = GF.L or {}
	local dialog = GF.UI.CreateSatelliteSettingsFrame({
		name = "GroupFinderAddonApplicantCharacterInfoDialog",
		width = ApplicantCharacterInfo.DIALOG_W,
		height = ApplicantCharacterInfo.DIALOG_MIN_H,
		title = L.APPLICANT_CHARACTER_INFO_TITLE or "角色信息",
		levelOffset = 18,
		backgroundColor = ApplicantCharacterInfo.DIALOG_BACKGROUND_COLOR,
	})
	if GF.UI.RegisterSatellitePanelSkin then
		GF.UI.RegisterSatellitePanelSkin(dialog)
	end
	dialog._gfFollowMainFrameRaise = true
	dialog._gfOnSatelliteFrameLayersApplied = function(self)
		applyDialogTopLayer(self)
	end
	applyDialogTopLayer(dialog)
	if dialog.SetToplevel then
		dialog:SetToplevel(true)
	end

	dialog.profilePanel = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
	dialog.profilePanel:SetPoint("TOPLEFT", dialog, "TOPLEFT", ApplicantCharacterInfo.PANEL_X, ApplicantCharacterInfo.PANEL_TOP_Y)
	dialog.profilePanel:SetWidth(ApplicantCharacterInfo.PANEL_W)
	ApplicantCharacterInfo.applyProfilePanelStyle(dialog.profilePanel)

	dialog.profileRows = {}
	for i = 1, ApplicantCharacterInfo.MAX_PROFILE_ROWS do
		dialog.profileRows[i] = ApplicantCharacterInfo.createApplicantCharacterInfoRow(dialog.profilePanel)
	end

	dialog.wclLabel = GF.UI.CreateFontString(dialog, "OVERLAY", "GameFontNormal")
	dialog.wclLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", ApplicantCharacterInfo.CONTENT_X, -92)
	dialog.wclLabel:SetText(L.APPLICANT_COPY_WCL_LINK or "复制 WCL 链接")
	applyFontStringSizeOverride(dialog.wclLabel, "GameFontNormal", 13, "")

	dialog.wclInput, dialog.wclEdit = GF.UI.CreateSelectableCopyInput(dialog, ApplicantCharacterInfo.CONTENT_W)
	dialog.wclInput:SetPoint("TOPLEFT", dialog.wclLabel, "BOTTOMLEFT", 0, -6)
	dialog.wclEdit:SetJustifyH("LEFT")
	GF.UI.ConfigureReadonlyCopyEdit(dialog, dialog.wclInput, dialog.wclEdit)

	dialog.armoryLabel = GF.UI.CreateFontString(dialog, "OVERLAY", "GameFontNormal")
	dialog.armoryLabel:SetPoint("TOPLEFT", dialog.wclInput, "BOTTOMLEFT", 0, -12)
	dialog.armoryLabel:SetText(L.APPLICANT_COPY_ARMORY_LINK or "复制英雄榜信息")
	applyFontStringSizeOverride(dialog.armoryLabel, "GameFontNormal", 13, "")

	dialog.armoryInput, dialog.armoryEdit = GF.UI.CreateSelectableCopyInput(dialog, ApplicantCharacterInfo.CONTENT_W)
	dialog.armoryInput:SetPoint("TOPLEFT", dialog.armoryLabel, "BOTTOMLEFT", 0, -6)
	dialog.armoryEdit:SetJustifyH("LEFT")
	GF.UI.ConfigureReadonlyCopyEdit(dialog, dialog.armoryInput, dialog.armoryEdit)

	dialog.closeButton = GF.UI.CreatePanelButton(dialog, CLOSE or "Close", GF.PANEL_BUTTON_STANDARD_W or 72)
	dialog.closeButton:SetPoint("TOP", dialog.armoryInput, "BOTTOM", 0, -14)
	centerPanelButtonText(dialog.closeButton)
	dialog.closeButton:SetScript("OnClick", function()
		dialog:Hide()
	end)
	dialog:HookScript("OnShow", function(self)
		setMainWindowDimmed(self, true)
	end)
	dialog:HookScript("OnHide", function(self)
		setMainWindowDimmed(self, false)
	end)

	ApplicantCharacterInfo.characterInfoDialog = dialog
	return dialog
end

local function raiseApplicantDialogToTop(dialog)
	if GF.UI and GF.UI.ApplySatelliteFrameLayers then
		GF.UI.ApplySatelliteFrameLayers()
	end
	applyDialogTopLayer(dialog)
end

local function openApplicantCharacterInfoDialog(name, links, memberData)
	links = links or buildApplicantCharacterLinks(name)
	if not links then
		return
	end
	local L = GF.L or {}
	local dialog = ensureApplicantCharacterInfoDialog()
	GF.UI.PresentSatelliteFrame(dialog, {
		title = L.APPLICANT_CHARACTER_INFO_TITLE or "角色信息",
		offsetY = 20,
		prepare = function(frame)
			local mode = ApplicantCharacterInfo.getMode(memberData)
			local rows
			if mode == "mplus" then
				rows = ApplicantCharacterInfo.buildApplicantCharacterInfoRows(name, memberData)
			elseif mode == "raid" then
				rows = ApplicantCharacterInfo.buildApplicantRaidInfoRows(name, memberData)
			end

			local linkTopY
			local minHeight = ApplicantCharacterInfo.DIALOG_MIN_H
			if rows and #rows > 0 then
				local contentBottomY = ApplicantCharacterInfo.applyApplicantCharacterInfoRows(frame, rows)
				linkTopY = contentBottomY - ApplicantCharacterInfo.LINK_GAP
			else
				ApplicantCharacterInfo.hideApplicantCharacterInfoRows(frame)
				linkTopY = ApplicantCharacterInfo.LINKS_ONLY_TOP_Y
				minHeight = ApplicantCharacterInfo.DIALOG_LINKS_ONLY_H
			end
			local buttonHeight = GF.PANEL_BUTTON_H or 22
			local linkBlockHeight = 13 + 6 + 26 + 12 + 13 + 6 + 26 + 14 + buttonHeight + ApplicantCharacterInfo.BOTTOM_PADDING
			local desiredHeight = math.max(minHeight, math.min(ApplicantCharacterInfo.DIALOG_MAX_H, -linkTopY + linkBlockHeight))
			frame:SetSize(ApplicantCharacterInfo.DIALOG_W, desiredHeight)

			frame.wclLabel:SetText(L.APPLICANT_COPY_WCL_LINK or "复制 WCL 链接")
			frame.wclLabel:ClearAllPoints()
			frame.wclLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", ApplicantCharacterInfo.CONTENT_X, linkTopY)
			frame.armoryLabel:SetText(L.APPLICANT_COPY_ARMORY_LINK or "复制英雄榜信息")
			frame.wclEdit._gfExpectedText = links.wcl or ""
			frame.wclEdit:SetText(links.wcl or "")
			frame.wclEdit:SetCursorPosition(0)
			frame.armoryEdit._gfExpectedText = links.armory or ""
			frame.armoryEdit:SetText(links.armory or "")
			frame.armoryEdit:SetCursorPosition(0)
		end,
		onShown = function(frame)
			frame.wclEdit:SetFocus()
			frame.wclEdit:HighlightText()
		end,
	})
	raiseApplicantDialogToTop(dialog)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if dialog:IsShown() then
				dialog.wclEdit:SetFocus()
				dialog.wclEdit:HighlightText()
			end
		end)
	end
end

function CharacterInfo:BuildLinks(name)
	return buildApplicantCharacterLinks(name)
end

function CharacterInfo:Open(name, links, memberData)
	return openApplicantCharacterInfoDialog(name, links, memberData)
end

function CharacterInfo:Whisper(name)
	return whisperApplicant(name)
end
