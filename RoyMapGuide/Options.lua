local addonName, ns = ...
local L = ns.L

-- ========================================================================
-- 地图设置配置项
-- ========================================================================
local function CityEntry(labelKey, keyPrefix, tooltip, sliderDefault)
    sliderDefault = sliderDefault or 1.0   -- 若未传参则保持 1.0，lnui
    local t = {
        type = "CheckBoxSlider",
        key = "show" .. keyPrefix,
        cbLabel = L[labelKey],
        cbDefault = true,
        cbTooltip = tooltip or nil,
        sliderKey = "scale" .. keyPrefix,
        sliderLabel = L["缩放"],
        sliderDefault = sliderDefault,      -- 使用传入的值，lnui
        sliderMin = 0.5,
        sliderMax = 2.0,
        sliderStep = 0.1,
        sliderTooltip = nil,
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    }
    return t
end

ns.MapOptions = {
    -- 基础功能
    {
        type = "header",
        key = "mapBaseHeader",
        name = L["基础功能"],
    },

    -- 地图缩放
    {
        type = "CheckBoxSlider",
        key = "isMapScale",
        cbLabel = L["启用地图缩放"],
        cbDefault = false,
        cbTooltip = L["调整世界地图框架大小\n\n最大化时不生效"],
        sliderKey = "mapScaleLevel",
        sliderLabel = L["缩放程度"],
        sliderDefault = 1.0,
        sliderMin = 0.5,
        sliderMax = 2.0,
        sliderStep = 0.1,
        sliderTooltip = nil,
        onChange = function(_, _)
            if ns.OnMapScaleChanged then ns.OnMapScaleChanged() end
        end,
    },

    -- 地图ID
    {
        type = "checkbox",
        key = "isMapID",
        name = L["启用地图ID"],
        default = false,
        tooltip = L["在世界地图上显示当前地图ID"],
        onChange = function(_, _)
            if ns.OnMapInfoChanged then ns.OnMapInfoChanged() end
        end,
    },
    {
        type = "color",
        key = "mapIDTextColor",
        name = L["文本颜色"],
        default = "FFFFFFFF",
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnMapIDStyleChanged then ns.OnMapIDStyleChanged() end
        end,
    },
    {
        type = "slider",
        key = "mapIDFontSize",
        name = L["文本大小"],
        default = 14,
        min = 10,
        max = 30,
        step = 1,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnMapIDStyleChanged then ns.OnMapIDStyleChanged() end
        end,
    },
    {
        type = "slider",
        key = "mapIDPositionX",
        name = L["水平移动"],
        default = -300,
        min = -2000,
        max = 2000,
        step = 5,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnMapIDPositionChanged then ns.OnMapIDPositionChanged() end
        end,
    },
    {
        type = "slider",
        key = "mapIDPositionY",
        name = L["垂直移动"],
        default = -220,
        min = -1000,
        max = 1000,
        step = 5,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnMapIDPositionChanged then ns.OnMapIDPositionChanged() end
        end,
    },

    -- 坐标显示
    {
        type = "checkbox",
        key = "isCoords",
        name = L["启用坐标显示"],
        default = false,
        tooltip = L["在世界地图上显示玩家坐标和鼠标坐标"],
        onChange = function(_, _)
            if ns.OnCoordsChanged then ns.OnCoordsChanged() end
        end,
    },
    {
        type = "color",
        key = "coordsTextColor",
        name = L["文本颜色"],
        default = "FFFFFFFF",
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnCoordsStyleChanged then ns.OnCoordsStyleChanged() end
        end,
    },
    {
        type = "slider",
        key = "coordsFontSize",
        name = L["文本大小"],
        default = 14,
        min = 10,
        max = 20,
        step = 1,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnCoordsStyleChanged then ns.OnCoordsStyleChanged() end
        end,
    },
    {
        type = "slider",
        key = "coordsDecimalPlaces",
        name = L["数值精度"],
        default = 1,
        min = 0,
        max = 2,
        step = 1,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnCoordsChanged then ns.OnCoordsChanged() end
        end,
    },
    {
        type = "slider",
        key = "coordsPositionX",
        name = L["水平移动"],
        default = 0,
        min = -2000,
        max = 2000,
        step = 5,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnCoordsPositionChanged then ns.OnCoordsPositionChanged() end
        end,
    },
    {
        type = "slider",
        key = "coordsPositionY",
        name = L["垂直移动"],
        default = -220,
        min = -1000,
        max = 1000,
        step = 5,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnCoordsPositionChanged then ns.OnCoordsPositionChanged() end
        end,
    },

    -- 全地图NPC标记
    {
        type = "header",
        key = "mapMarkersHeader",
        name = L["全地图NPC标记"],
    },

    -- 启用功能
    {
        type = "checkbox",
        key = "isMapMarkers",
        name = L["启用功能"],
        default = true,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersPortal",
        cbLabel = L["传送"],
        cbDefault = true,
        cbTooltip = L["传送门"],
        colorKey = "mapMarkersColorPortal",
        colorLabel = L["传送颜色"],
        colorDefault = "FF00DEFF",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersInn",
        cbLabel = L["旅店"],
        cbDefault = true,
        cbTooltip = nil,
        colorKey = "mapMarkersColorInn",
        colorLabel = nil,
        colorDefault = "FF00FF00",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersOfficial",
        cbLabel = L["商业"],
        cbDefault = true,
        cbTooltip = L["拍卖/银行/黑市"],
        colorKey = "mapMarkersColorOfficial",
        colorLabel = nil,
        colorDefault = "FFFFFF00",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersProfession",
        cbLabel = L["专业"],
        cbDefault = true,
        cbTooltip = nil,
        colorKey = "mapMarkersColorProfession",
        colorLabel = nil,
        colorDefault = "FFFFFFFF",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersService",
        cbLabel = L["服务"],
        cbDefault = true,
        cbTooltip = L["理发/幻化/商栈/物品升级/订单"],
        colorKey = "mapMarkersColorService",
        colorLabel = nil,
        colorDefault = "FFFF00FF",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersStable",
        cbLabel = L["兽栏"],
        cbDefault = true,
        cbTooltip = nil,
        colorKey = "mapMarkersColorStable",
        colorLabel = nil,
        colorDefault = "FFFF9900",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersCollection",
        cbLabel = L["藏品"],
        cbDefault = true,
        cbTooltip = L["坐骑/玩具/宠物/家宅"],
        colorKey = "mapMarkersColorCollection",
        colorLabel = nil,
        colorDefault = "FFFF88CC",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersVendor",
        cbLabel = L["通用商人"],
        cbDefault = true,
        cbTooltip = L["公会商人/外观商人/传家宝商人"],
        colorKey = "mapMarkersColorVendor",
        colorLabel = nil,
        colorDefault = "FFAA33FF",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersUnique",
        cbLabel = L["特殊商人"],
        cbDefault = true,
        cbTooltip = L["暗月马戏团商人/埃匹希斯水晶商人/古怪硬币商人等各种使用特殊货币的商人"],
        colorKey = "mapMarkersColorUnique",
        colorLabel = nil,
        colorDefault = "FF3366FF",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersSpecial",
        cbLabel = L["特殊功能"],
        cbDefault = true,
        cbTooltip = L["经验锁定/化生台/幻形讲坛等具备特殊功能的NPC"],
        colorKey = "mapMarkersColorSpecial",
        colorLabel = nil,
        colorDefault = "FF00FFBB",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersQuartermaster",
        cbLabel = L["军需官"],
        cbDefault = true,
        cbTooltip = L["声望军需官"],
        colorKey = "mapMarkersColorQuartermaster",
        colorLabel = nil,
        colorDefault = "FFFF5000",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersPvp",
        cbLabel = L["PVP相关"],
        cbDefault = true,
        cbTooltip = L["PVP商人/PVP坐骑/木桩"],
        colorKey = "mapMarkersColorPvp",
        colorLabel = nil,
        colorDefault = "FFFF0000",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersInstance",
        cbLabel = L["副本"],
        cbDefault = true,
        cbTooltip = nil,
        colorKey = "mapMarkersColorInstance",
        colorLabel = nil,
        colorDefault = "FFFF0055",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "CheckBoxColor",
        key = "isMapMarkersDelve",
        cbLabel = L["地下堡"],
        cbDefault = true,
        cbTooltip = nil,
        colorKey = "mapMarkersColorDelve",
        colorLabel = nil,
        colorDefault = "FF7777FF",
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },

    -- 配置调整
    {
        type = "header",
        key = "mapMarkersConfigHeader",
        name = L["配置调整"],
    },
    {
        type = "dropdown",
        key = "mapMarkersMode",
        name = L["显示模式"],
        default = "TEXT",
        tooltip = nil,
        options = function()
            local c = Settings.CreateControlTextContainer()
            c:Add("TEXT", L["文本"])
            c:Add("ICON", L["图标"])
            return c:GetData()
        end,
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "slider",
        key = "mapMarkersTextSize",
        name = L["文本大小"],
        default = 14,
        min = 8,
        max = 20,
        step = 1,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "dropdown",
        key = "mapMarkersTextOutline",
        name = L["文本描边"],
        default = "OUTLINE",
        tooltip = nil,
        options = function()
            local c = Settings.CreateControlTextContainer()
            c:Add("", L["无"])
            c:Add("OUTLINE", L["细轮廓"])
            c:Add("THICKOUTLINE", L["粗轮廓"])
            return c:GetData()
        end,
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "slider",
        key = "mapMarkersIconSize",
        name = L["图标大小"],
        default = 20,
        min = 10,
        max = 30,
        step = 1,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "dropdown",
        key = "mapMarkersIconGlow",
        name = L["图标样式"],
        default = "",
        tooltip = nil,
        options = function()
            local c = Settings.CreateControlTextContainer()
            c:Add("", L["无"])
            c:Add("GLOW", L["发光"])
            return c:GetData()
        end,
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "slider",
        key = "mapMarkersFrameLevel",
        name = L["显示层级"],
        default = 2200,
        min = 0,
        max = 5000,
        step = 10,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "slider",
        key = "mapMarkersDynamicOffsetY",
        name = L["原生标记偏移"],
        default = 0,
        min = -20,
        max = 20,
        step = 1,
        tooltip = L["调整POI等原生标记上的文字垂直位置"],
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "slider",
        key = "mapMarkersZoomThreshold",
        name = L["聚合切换阈值"],
        default = 2,
        min = 0,
        max = 8,
        step = 1,
        tooltip = L["控制地图放大时从聚合标记切换成独立标记的缩放级别\n\n原生地图缩放共有8级，对应7次滚轮缩放\n\n值=1-7：放大前显示聚合标记，放大后显示独立标记\n值=0：始终显示独立标记\n值=8：始终显示聚合标记"],
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "checkbox",
        key = "isMapMarkersTooltip",
        name = L["鼠标提示"],
        default = true,--lnui
        tooltip = L["显示标记的额外提示信息"],
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "checkbox",
        key = "isMapMarkersWaypoint",
        name = L["标记路径"],
        default = false,
        tooltip = L["左键点击创建路径点，右键点击取消路径点"],
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "checkbox",
        key = "isMapMarkersProfessionFilter",
        name = L["专业过滤"],
        default = true,--lnui
        tooltip = L["只显示你学习的专业，钓鱼烹饪考古除外"],
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    {
        type = "checkbox",
        key = "isMapMarkersButton",
        name = L["地图开关"],
        default = true,--lnui
        tooltip = L["在大地图上添加一个快捷开关"],
        onChange = function(_, _)
            if ns.OnMapMarkersButtonChanged then ns.OnMapMarkersButtonChanged() end
        end,
    },

    -- 城市区域
    {
        type = "header",
        key = "mapMarkersCityHeader",
        name = L["城市区域"],
    },
    {
        type = "checkbox",
        key = "showAllianceGroup",
        name = L["联盟"],
        default = true,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    CityEntry("暴风城", "Stormwind"),
    CityEntry("铁炉堡", "Ironforge"),
    CityEntry("达纳苏斯", "Darnassus"),
    CityEntry("埃索达", "Exodar"),
    CityEntry("吉尔尼斯", "Gilneas"),
    CityEntry("暴风之盾", "Stormshield"),
    CityEntry("伯拉勒斯", "Boralus"),
    CityEntry("贝拉梅斯", "Belamath"),
    {
        type = "checkbox",
        key = "showHordeGroup",
        name = L["部落"],
        default = true,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    CityEntry("奥格瑞玛", "Orgrimmar"),
    CityEntry("雷霆崖", "ThunderBluff"),
    CityEntry("幽暗城", "Undercity"),
    CityEntry("银月城（燃烧的远征）", "SilvermoonCityTBC"),
    CityEntry("战争之矛", "Warspear"),
    CityEntry("达萨罗", "Dazaralor"),
    {
        type = "checkbox",
        key = "showNeutralGroup",
        name = L["中立"],
        default = true,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    CityEntry("沙塔斯", "Shattrath"),
    CityEntry("达拉然（巫妖王之怒）", "DalaranWLK"),
    CityEntry("达拉然（军团再临）", "DalaranLegion"),
    CityEntry("奥利波斯", "Oribos"),
    CityEntry("瓦德拉肯", "Valdrakken"),
    CityEntry("多恩诺加尔", "Dornogal"),
    CityEntry("千丝之城", "CityofThreads"),
    CityEntry("安德麦", "Undermine"),
    CityEntry("塔扎维什", "Tazavesh"),
    CityEntry("银月城（至暗之夜）", "SilvermoonCityMidnight", nil, 1.2),--lnui
    {
        type = "checkbox",
        key = "showZoneGroup",
        name = L["区域"],
        default = true,
        tooltip = nil,
        onChange = function(_, _)
            if ns.OnMapMarkersChanged then ns.OnMapMarkersChanged() end
        end,
    },
    CityEntry("暗月马戏团", "Darkmoonfaire"),
    CityEntry("千禧阈限（S1赛季）", "TheTimeways", nil, 1.2),--lnui
    CityEntry("暗影界", "Shadowlands", L["兵主之座/堕罪堡/森林之心/极乐堡"]),
    CityEntry("卡兹阿加", "KhazAlgar", L["多恩岛/喧鸣深窟/陨圣峪/艾基-卡赫特/卡雷什"]),
    CityEntry("奎尔萨拉斯", "QuelThalas", L["奎尔丹纳斯岛/永歌森林/祖阿曼/哈籁恩达尔/虚影风暴"], 1.2),--lnui
}

-- ========================================================================
-- 父子联动依赖关系
-- ========================================================================
ns.OptionDependencies = {
    -- -------------------------------------------------------------------
    -- 地图设置
    -- -------------------------------------------------------------------
    isMapID = {
        {
            children = { "mapIDTextColor", "mapIDFontSize", "mapIDPositionX", "mapIDPositionY" },
            enabled = function() return RoyMapGuideDB.isMapID == true end,
        },
    },
    isCoords = {
        {
            children = { "coordsTextColor", "coordsFontSize", "coordsDecimalPlaces", "coordsPositionX", "coordsPositionY" },
            enabled = function() return RoyMapGuideDB.isCoords == true end,
        },
    },

    -- 全地图NPC标记
    isMapMarkers = {
        {
            children = {
                "isMapMarkersPortal", "isMapMarkersInn", "isMapMarkersOfficial",
                "isMapMarkersProfession", "isMapMarkersService", "isMapMarkersStable",
                "isMapMarkersCollection", "isMapMarkersVendor", "isMapMarkersUnique",
                "isMapMarkersSpecial", "isMapMarkersQuartermaster", "isMapMarkersPvp",
                "isMapMarkersInstance", "isMapMarkersDelve",
            },
            enabled = function() return RoyMapGuideDB.isMapMarkers == true end,
        }
    },

    -- 显示模式
    mapMarkersMode = {
        {
            children = { "mapMarkersTextSize", "mapMarkersTextOutline" },
            enabled = function() return RoyMapGuideDB.mapMarkersMode == "TEXT" or RoyMapGuideDB.mapMarkersMode == nil end,
        },
        {
            children = { "mapMarkersIconSize", "mapMarkersIconGlow" },
            enabled = function() return RoyMapGuideDB.mapMarkersMode == "ICON" end,
        },
    },

    -- 城市区域
    showAllianceGroup = {
        {
            children = {
                "showStormwind", "showIronforge", "showDarnassus", "showExodar",
                "showGilneas", "showStormshield", "showBoralus", "showBelamath",
            },
            enabled = function() return RoyMapGuideDB.showAllianceGroup ~= false end,
        },
    },
    showHordeGroup = {
        {
            children = {
                "showOrgrimmar", "showThunderBluff", "showUndercity",
                "showSilvermoonCityTBC", "showWarspear", "showDazaralor",
            },
            enabled = function() return RoyMapGuideDB.showHordeGroup ~= false end,
        },
    },
    showNeutralGroup = {
        {
            children = {
                "showShattrath", "showDalaranWLK", "showDalaranLegion", "showOribos", "showValdrakken",
                "showDornogal", "showCityofThreads", "showUndermine", "showTazavesh", "showSilvermoonCityMidnight",
            },
            enabled = function() return RoyMapGuideDB.showNeutralGroup ~= false end,
        },
    },
    showZoneGroup = {
        {
            children = {
                "showDarkmoonfaire", "showTheTimeways", "showShadowlands", "showKhazAlgar", "showQuelThalas",
            },
            enabled = function() return RoyMapGuideDB.showZoneGroup ~= false end,
        },
    },
}

-- ========================================================================
-- 默认值提取
-- ========================================================================
ns.defaults = {}

local function CollectDefaults(optList)
    for _, opt in ipairs(optList) do
        if opt.type == "CheckBoxColor" then
            if opt.key and opt.cbDefault ~= nil then
                ns.defaults[opt.key] = opt.cbDefault
            end
            if opt.colorKey and opt.colorDefault ~= nil then
                ns.defaults[opt.colorKey] = opt.colorDefault
            end
        elseif opt.type == "CheckBoxSlider" then
            if opt.key and opt.cbDefault ~= nil then
                ns.defaults[opt.key] = opt.cbDefault
            end
            if opt.sliderKey and opt.sliderDefault ~= nil then
                ns.defaults[opt.sliderKey] = opt.sliderDefault
            end
        elseif opt.type == "CheckBoxDropdown" then
            if opt.key and opt.cbDefault ~= nil then
                ns.defaults[opt.key] = opt.cbDefault
            end
            if opt.dropdownKey and opt.dropdownDefault ~= nil then
                ns.defaults[opt.dropdownKey] = opt.dropdownDefault
            end
        elseif opt.type ~= "header" then
            if opt.key and opt.default ~= nil then
                ns.defaults[opt.key] = opt.default
            end
        end
    end
end

CollectDefaults(ns.MapOptions)