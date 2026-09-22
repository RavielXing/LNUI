-- GroupFinder current-build ordinary archive fallback.
--
-- Source: 地下城-实机验证.xlsx, verified in WoW 12.1.0.69382 (zhCN).
-- SHA-256: 52d20da2954b8174a4887bb342ea51098bf9588d8260ad668264d987141ed8d5
--
-- This is a structural/activity identity snapshot, not character authority.
-- A record is emitted only when it has at least one Activity ID; activity
-- names without an ID and instances without any IDs are intentionally absent.
-- Runtime C_LFGList availability must still authorize each concrete ID.

local _, GF = ...

local SNAPSHOT_BUILD = 69382
local SCHEMA_VERSION = 1
local SOURCE_SHA256 = "52d20da2954b8174a4887bb342ea51098bf9588d8260ad668264d987141ed8d5"

local ENCODED = {
	dungeon = {
		[11] = [=[纳洛拉克的洞穴	1721	1721,1722,1723,1952
魔导师平台	1757	1757,1758,1759,1760
迈萨拉洞窟	1761	1761,1762,1763,1764
密谋小径	1749	1749,1750,1751,1950
节点希纳斯	1765	1765,1766,1767,1768
夺目谷	1699	1699,1700,1701,1949
虚空之痕竞技场	1754	1754,1755,1756,1951
风行者之塔	1539	1539,1540,1541,1542
毒牙祭坛	1930	1930,1931,1932,1933]=],
		[10] = [=[千丝之城	1382	1382,1383,1293,1288
圣焰隐修院	1510	1510,1511,1512,1281
暗焰裂口	1275	1275,1276,1277,1282
燧酿酒庄	1507	1507,1508,1509,1286
矶石宝库	1535	1535,1521,1292,1287
破晨号	1518	1518,1519,1291,1285
艾拉-卡拉，回响之城	1278	1278,1279,1280,1284
驭雷栖巢	1308	1308,1309,1310,1283
水闸行动	1547	1547,1548,1549,1550
奥尔达尼生态圆顶	1707	1707,1708,1709,1694]=],
		[9] = [=[艾杰斯亚学院	1157	1157,1158,1159,1160
蕨皮山谷	1161	1161,1162,1163,1164
注能大厅	1165	1165,1166,1167,1168
奈萨鲁斯	1169	1169,1170,1171,1172
红玉新生法池	1173	1173,1174,1175,1176
碧蓝魔馆	1177	1177,1178,1179,1180
诺库德阻击战	1181	1181,1182,1183,1184
奥达曼：提尔的遗产	1185	1185,1186,1187,1188
永恒黎明	1244	1245,1244,1247,1246,1248]=],
		[8] = [=[伤逝剧场	716	716,719,718,717
凋魂之殇	688	688,689,690,691
塞兹仙林的迷雾	700	700,701,702,703
彼界	692	692,693,694,695
晋升高塔	708	708,711,710,709
赎罪大厅	696	696,697,698,699
赤红深渊	704	704,707,706,705
通灵战潮	712	712,715,714,713
塔扎维什，帷纱集市	1711	1711,746
塔扎维什：琳彩天街	1018	1018,1016
塔扎维什：索·莉亚的宏图	1019	1019,1017]=],
		[7] = [=[围攻伯拉勒斯	532	532,535
地渊孢林	541	541,508,644,507
塞塔里斯神庙	503	503,505,645,504
托尔达戈	524	524,527,525,526
暴富矿区！！	540	540,511,646,510
维克雷斯庄园	528	528,531,529,530
自由镇	516	516,519,517,518
诸王之眠	512	512,515,513,514
阿塔达萨	543	543,500,499,502
风暴神殿	520	520,523,521,522
麦卡贡行动	669	682,669,679,684,1616,683]=],
		[6] = [=[噬魂之喉	432	432,442,452
奈萨里奥的巢穴	428	428,448
守望者地窟	431	431,451
执政团之座	484	484,485,486
永夜大教堂	474	474,475
突袭紫罗兰监狱	429	429,439,449
群星庭院	453	453
艾萨拉之眼	425	425,445
英灵殿	427	427,437,447
重返卡拉赞	455	455
魔法回廊	444	444,454
黑心林地	426	426,446
黑鸦堡垒	450	450]=],
		[5] = [=[奥金顿	23	23,31,403
影月墓地	27	27,35,407,1193
恐轨车站	25	25,33,405,183
永茂林地	26	26,34,406,184
血槌炉渣矿井	21	21,29,401,1695
通天峰	24	24,32,404,182
钢铁码头	22	22,30,402,180
黑石塔上层	28	28,36,408]=],
		[4] = [=[围攻砮皂寺	159	159,171
影踪禅院	157	157,165
残阳关	160	160,167
血色修道院	78	78,169
血色大厅	77	77,170
通灵学院	51	51,168
青龙寺	155	155,163,1192
风暴烈酒酿造厂	156	156,164
魔古山宫殿	158	158,166]=],
		[3] = [=[巨石之核	137	137,141,1702
影牙城堡	53	53,149
托维尔失落之城	139	139,147
旋云之巅	138	138,140,1195
时光之末	152	152
暮光审判	154	154
格瑞姆巴托	135	135,143,1294,1290
死亡矿井	18	18,148
永恒之井	153	153
潮汐王座	133	133,146,1274
祖尔格拉布	150	150
祖阿曼	151	151
起源大厅	136	136,142
黑石岩窟	134	134,144]=],
		[2] = [=[乌特加德之巅	102	102,117
乌特加德城堡	101	101,128
冠军的试炼	113	113,129
净化斯坦索姆	107	107,118
古达克	109	109,123
安卡赫特：古代王国	110	110,124
岩石大厅	106	106,121
映像大厅	116	116,132
灵魂洪炉	114	114,130
紫罗兰监狱	111	111,125
艾卓-尼鲁布	103	103,127
萨隆矿坑	115	115,131,1769,1770
达克萨隆要塞	108	108,122
闪电大厅	105	105,120
魔枢	112	112,126
魔环	104	104,119]=],
		[1] = [=[地狱火城墙	67	67,94
塞泰克大厅	75	75,86
奥金尼地穴	74	74,84
奴隶围栏	70	70,90
开启黑暗之门	80	80,88
逃离敦霍尔德	79	79,89
暗影迷宫	76	76,87
法力陵墓	73	73,85
生态船	82	82,97
破碎大厅	69	69,95
禁魔监狱	83	83,96
能源舰	81	81,98
蒸汽地窟	72	72,91
魔导师平台	99	99,100
鲜血熔炉	68	68,93
幽暗沼泽	71	71,92]=],
		[0] = [=[剃刀沼泽	57	57
剃刀高地	58	58
厄运之槌	65	65
哀嚎洞穴	50	50
奥达曼	59	59
影牙城堡	53	53,149
怒焰裂谷	52	52
斯坦索姆	66	66
死亡矿井	18	18,148
玛拉顿	61	61
暴风城监狱	55	55
祖尔法拉克	60	60
血色修道院	78	78,169
血色大厅	77	77,170
诺莫瑞根	56	56
通灵学院	51	51,168
沉没的神庙	62	62
黑暗深渊	54	54
黑石塔下层	64	64
黑石深渊	63	63]=],
	},
	raid = {
		[11] = [=[世界首领（至暗之夜）	1735	1735,1968
梦境裂隙	1778	1778,1779,1780
虚影尖塔	1772	1772,1773,1774
进军奎尔丹纳斯	1775	1775,1776,1777
孢陨幽境	1946	1946,1948,1947
潮缚石窟	2003	2003,2004,2005
烈毒之渊	1955	1955,1956,1957]=],
		[10] = [=[尼鲁巴尔王宫	1505	1505,1506,1504
解放安德麦	1601	1601,1600,1602
法力熔炉：欧米伽	1617	1617,1618,1619]=],
		[9] = [=[化身巨龙牢窟	1189	1189,1190,1191
亚贝鲁斯，焰影熔炉	1235	1235,1236,1237
阿梅达希尔，梦境之愿	1251	1251,1252,1253]=],
		[8] = [=[纳斯利亚堡	720	720,722,721
统御圣所	743	743,744,745
初诞者圣墓	1020	1020,1021,1022]=],
		[7] = [=[奥迪尔	494	494,495,496
达萨罗之战	663	663,664,665
风暴熔炉	668	668,667,666
永恒王宫	672	672,671,670
尼奥罗萨，觉醒之城	687	687,686,685]=],
		[6] = [=[翡翠梦魇	413	413,414,468
勇气试炼	456	456,457,480
暗夜要塞	415	415,416,481
萨格拉斯之墓	479	479,478,492
安托鲁斯，燃烧王座	482	482,483,493]=],
		[5] = [=[悬槌堡	37	37,38,399
黑石铸造厂	39	39,40,400
地狱火堡垒	409	409,410,412]=],
		[4] = [=[魔古山宝库	335	335,337,336,338
恐惧之心	339	339,341,340,342
永春台	343	343,345,344,346
雷电王座	347	347,350,348,349
决战奥格瑞玛	4	4,41,42]=],
		[3] = [=[暮光堡垒	319	319,322,320,321
风神王座	323	323,326,324,325
黑翼血环	313	313,316,317,318
火焰之地	676	676,677
巨龙之魂	331	331,334,332,333]=],
		[2] = [=[纳克萨玛斯	43	43,44
奥杜尔	303	303
十字军的试炼	304	304,306,305,307
冰冠堡垒	46	46,48,47,49
红玉圣殿	308	308,310,309,311]=],
		[1] = [=[卡拉赞	45	45
格鲁尔的巢穴	296	296
玛瑟里顿的巢穴	297	297
毒蛇神殿	298	298
风暴要塞	299	299
黑暗神殿	300	300
太阳之井	301	301]=],
		[0] = [=[熔火之心	9	9
黑翼之巢	293	293
安其拉废墟	294	294
安其拉神殿	295	295]=],
	},
}

local function clientBuild()
	local build = GF.Compat and tonumber(GF.Compat.build)
	if build then
		return build
	end
	if type(GetBuildInfo) == "function" then
		local ok, _, value = pcall(GetBuildInfo)
		if ok then
			return tonumber(value)
		end
	end
	return nil
end

local function decodeActivityIDs(encoded)
	local activityIDs = {}
	for value in tostring(encoded or ""):gmatch("%d+") do
		activityIDs[#activityIDs + 1] = tonumber(value)
	end
	return activityIDs
end

local function decodeKind(kind)
	local section = { expansions = {} }
	for expansionIndex = 11, 0, -1 do
		local instances = {}
		local encoded = ENCODED[kind] and ENCODED[kind][expansionIndex] or ""
		for line in encoded:gmatch("[^\n]+") do
			local label, labelActivityID, activityList =
				line:match("^(.-)\t(%d+)\t([%d,]+)$")
			local activityIDs = decodeActivityIDs(activityList)
			if label and #activityIDs > 0 then
				instances[#instances + 1] = {
					labelZhCN = label,
					labelActivityID = tonumber(labelActivityID),
					activityIDs = activityIDs,
					orderIndex = #instances + 1,
				}
			end
		end
		section.expansions[#section.expansions + 1] = {
			expansionIndex = expansionIndex,
			instances = instances,
		}
	end
	return section
end

local function buildCatalog(build)
	build = tonumber(build)
	if build == nil or build < SNAPSHOT_BUILD then
		return nil
	end
	return {
		dungeon = decodeKind("dungeon"),
		raid = decodeKind("raid"),
	}
end

local Data = GF.NavCatalogFallbackData or {}
GF.NavCatalogFallbackData = Data

function Data.GetCatalogForBuild(build)
	return buildCatalog(build)
end

function Data.GetCatalog()
	return GF.NAV_CATALOG_ACTIVITY_FALLBACK
end

function Data.GetSnapshotBuild()
	return SNAPSHOT_BUILD
end

function Data.GetSchemaVersion()
	return SCHEMA_VERSION
end

function Data.GetSourceSHA256()
	return SOURCE_SHA256
end

GF.NAV_CATALOG_ACTIVITY_FALLBACK = buildCatalog(clientBuild())

return GF.NAV_CATALOG_ACTIVITY_FALLBACK
