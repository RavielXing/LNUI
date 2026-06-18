local addonName, ns = ...
local L = ns.L
if GetLocale() == "zhCN" then return end

L["全地图NPC标记"] = "World Map NPC Guide"
L["更新记录"] = "Changelog"
L["地图设置"] = "Map Settings"
L["基础功能"] = "Basic Features"
L["启用地图缩放"] = "Enable Map Zoom"
L["调整世界地图框架大小\n\n最大化时不生效"] = "Resize the world map frame.\n\nHas no effect when maximized."
L["缩放程度"] = "Zoom Level"
L["启用地图ID"] = "Enable Map ID"
L["在世界地图上显示当前地图ID"] = "Display the current map ID on the world map"
L["启用坐标显示"] = "Enable Coordinates"
L["在世界地图上显示玩家坐标和鼠标坐标"] = "Display player and cursor coordinates on the world map"
L["数值精度"] = "Decimal Places"
L["文本颜色"] = "Text Color"
L["文本大小"] = "Font Size"
L["水平移动"] = "Position X"
L["垂直移动"] = "Position Y"
L["全地图NPC标记"] = "World Map NPC Guide"
L["启用功能"] = "Enable"
L["传送"] = "Portal"
L["传送门"] = "Portals"
L["旅店"] = "Inn"
L["商业"] = "Commerce"
L["拍卖/银行/黑市"] = "Auction / Bank / Black Market"
L["专业"] = "Profession"
L["服务"] = "Services"
L["理发/幻化/商栈/物品升级/订单"] = "Barber / Transmog / Trading Post / Upgrade / Orders"
L["兽栏"] = "Stable"
L["藏品"] = "Collections"
L["坐骑/玩具/宠物/家宅"] = "Mounts / Toys / Pets / Housing"
L["通用商人"] = "General Vendor"
L["公会商人/外观商人/传家宝商人"] = "Guild / Appearance / Heirloom Vendors"
L["特殊商人"] = "Special Vendor"
L["暗月马戏团商人/埃匹希斯水晶商人/古怪硬币商人等各种使用特殊货币的商人"] = "Vendors using special currencies: Darkmoon Faire, Ephemeral Crystals, Odd Coins, and more"
L["特殊功能"] = "Special Features"
L["经验锁定/化生台/幻形讲坛等具备特殊功能的NPC"] = "NPCs with unique functions: XP Lock, Wardrobe, Transmogrification Podium, etc."
L["军需官"] = "Quartermaster"
L["声望军需官"] = "Reputation Quartermaster"
L["PVP相关"] = "PvP"
L["PVP商人/PVP坐骑/木桩"] = "PvP Vendors / PvP Mounts / Training Dummy"
L["副本"] = "Instance"
L["地下堡"] = "Delve"
L["配置调整"] = "Layout Settings"
L["显示模式"] = "Display Mode"
L["文本"] = "Text"
L["图标"] = "Icon"
L["文本描边"] = "Text Outline"
L["无"] = "None"
L["细轮廓"] = "Thin Outline"
L["粗轮廓"] = "Thick Outline"
L["图标大小"] = "Icon Size"
L["图标样式"] = "Icon Style"
L["发光"] = "Glow"
L["显示层级"] = "Frame Level"
L["原生标记偏移"] = "Native Pin Offset"
L["调整POI等原生标记上的文字垂直位置"] = "Adjust the vertical position of text on native pins such as POIs"
L["聚合切换阈值"] = "Aggregate Switch Threshold"
L["控制地图放大时从聚合标记切换成独立标记的缩放级别\n\n原生地图缩放共有8级，对应7次滚轮缩放\n\n值=1-7：放大前显示聚合标记，放大后显示独立标记\n值=0：始终显示独立标记\n值=8：始终显示聚合标记"] =
    "Controls the zoom level at which aggregate pins switch to individual pins.\n\nThe map has 8 zoom levels (7 scroll steps).\n\n1-7: show aggregate below threshold, individual above\n0: always show individual\n8: always show aggregate"
L["显示标记的额外提示信息"] = "Show additional tooltip info on markers"
L["鼠标提示"] = "Tooltip"
L["标记路径"] = "Waypoint"
L["左键点击创建路径点，右键点击取消路径点"] = "Left-click to create a waypoint, right-click to remove it"
L["专业过滤"] = "Profession Filter"
L["只显示你学习的专业，钓鱼烹饪考古除外"] = "Only show professions you have learned, except Fishing, Cooking, and Archaeology"
L["地图开关"] = "Map Toggle Button"
L["在大地图上添加一个快捷开关"] = "Add a toggle button to the world map"
L["缩放"] = "Scale"
L["城市区域"] = "Cities & Zones"
L["联盟"] = "Alliance"
L["部落"] = "Horde"
L["中立"] = "Neutral"
L["区域"] = "Zone"
L["暴风城"] = "Stormwind"
L["铁炉堡"] = "Ironforge"
L["达纳苏斯"] = "Darnassus"
L["埃索达"] = "Exodar"
L["吉尔尼斯"] = "Gilneas"
L["暴风之盾"] = "Stormshield"
L["伯拉勒斯"] = "Boralus"
L["贝拉梅斯"] = "Belamath"
L["奥格瑞玛"] = "Orgrimmar"
L["雷霆崖"] = "Thunder Bluff"
L["幽暗城"] = "Undercity"
L["银月城（燃烧的远征）"] = "Silvermoon City (TBC)"
L["战争之矛"] = "Warspear"
L["达萨罗"] = "Dazar'alor"
L["沙塔斯"] = "Shattrath"
L["达拉然（巫妖王之怒）"] = "Dalaran (WotLK)"
L["达拉然（军团再临）"] = "Dalaran (Legion)"
L["奥利波斯"] = "Oribos"
L["瓦德拉肯"] = "Valdrakken"
L["多恩诺加尔"] = "Dornogal"
L["千丝之城"] = "City of Threads"
L["安德麦"] = "Undermine"
L["塔扎维什"] = "Tazavesh"
L["银月城（至暗之夜）"] = "Silvermoon City (Midnight)"
L["暗月马戏团"] = "Darkmoon Faire"
L["千禧阈限（S1赛季）"] = "The Timeways (Season 1)"
L["暗影界"] = "Shadowlands"
L["兵主之座/堕罪堡/森林之心/极乐堡"] = "Oribos / Sinfall / Heart of the Forest / Elysian Hold"
L["卡兹阿加"] = "Khaz Algar"
L["多恩岛/喧鸣深窟/陨圣峪/艾基-卡赫特/卡雷什"] = "Isle of Dorn / Ringing Deeps / Hallowfall / Azj-Kahet / Khaz-Goroth"
L["奎尔萨拉斯"] = "Quel'Thalas"
L["奎尔丹纳斯岛/永歌森林/祖阿曼/哈籁恩达尔/虚影风暴"] = "Quel'Danas / Eversong Woods / Zul'Aman / Hallowfall / Ghostlands"
L["地图ID: "] = "Map ID: "
L["玩家："] = "Player: "
L["鼠标："] = "Cursor: "
L["文"] = "T"
L["图"] = "I"
L["地图标记开关"] = "Map Markers Toggle"
L["左键：标记开关"] = "L: Toggle markers"
L["右键：切换模式"] = "R: Switch display mode"
L["地图标记数据库加载失败"] = "Map marker database failed to load"
L["changelog"] = [[
[2026.6.17] v1.6.3
- Update toc for 12.0.7

[2026.6.7] v1.6.2
- Restored Darkmoon Island markers
- Added Revival Catalyst marker in Valdrakken

[2026.5.31] v1.6.1
- Reordered TOC file entries

[2026.5.31] v1.6
Markers
- Added ritual site markers and various other new markers
- Temporarily removed Darkmoon Island markers; will be restored when the Faire returns
Features
- Added marker color customization
- Added toggle for the map zoom feature
Code
- Fixed map coordinate errors and improved coordinate rendering performance
- Reworked marker templates, icons, and scaling; fixed several incorrect markers
- Full addon restructure
- Reordered configuration options
- Added localization support (currently only the settings UI has been localized)

[2026.4.22] v1.5.5
- Update toc for 12.0.5

[2026.4.3] v1.5.4
- Added Black Market and Housing markers for Silvermoon City (Midnight)

[2026.4.2] v1.5.3
- Added Delve: Sunstrider Arcade

[2026.3.27] v1.5.2
- Added Delve: The Dark Corridors on the Eversong Woods zone map

[2026.3.27] v1.5.1
- Added Delve: The Dark Corridors

[2026.3.23] v1.5
- Added waypoint support for markers: left-click to create, right-click to remove
- Added native pin text offset option
- Fixed various known marker errors

[2026.3.20] v1.4
Markers
- Added markers for The Timeways, The Timeways (Mythic), Nemesis Delves, and Skinning rares
Code
- Converted Map ID and Coordinates settings to parent-child configuration

[2026.3.16] v1.3
Markers
- Fixed an issue where some professions were not displayed when Profession Filter was enabled
Code
- Fixed an issue where default values for parent settings were not applied correctly

[2026.3.15] v1.2
Markers
- Completed markers for Silvermoon City (Midnight) and the four major zones in patch 12.0
- Restored Silvermoon City (TBC) markers
- Renamed the two Dalaran cities to use their standard expansion names instead of zone names
- Temporarily removed The Timeways portals in Khaz Algar and Silvermoon City (Midnight)
Features
- Added map zoom
- Added Map ID, player coordinates, and cursor coordinates display with adjustable color, size, and position
- Added marker frame level control
- Added aggregate switch threshold to toggle between aggregate and individual pins
- Added map toggle button: left-click to toggle markers, right-click to switch between text and icon mode
Code
- Added parent-child configuration support (currently limited to single controls)
- Fully restructured all marker data
- Added dynamic capture logic for Blizzard native map pins (currently: POI, Map Link, Instance, Delve)
- Fixed memory leak in coordinate retrieval
- Various other code fixes and optimizations

[2026.2.28] v1.1
- Added patch 12.0 capital city markers (preliminary)

[2026.2.11] v1.0
- Initial release
]]