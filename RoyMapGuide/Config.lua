local addonName, ns = ...
local mainCategory

-- ========================================================================================================================
-- 颜色转换函数
-- ========================================================================================================================
function ns.HexToRGBA(hexColor)
    if not hexColor or type(hexColor) ~= "string" then
        return 1, 1, 1, 1
    end
    
    hexColor = hexColor:gsub("#", "")
    
    if #hexColor == 6 then
        hexColor = "FF" .. hexColor
    elseif #hexColor == 3 then
        hexColor = "FF" .. hexColor:gsub(".", "%0%0")
    elseif #hexColor ~= 8 then
        return 1, 1, 1, 1
    end
    
    local a = tonumber(hexColor:sub(1, 2), 16) or 255
    local r = tonumber(hexColor:sub(3, 4), 16) or 255
    local g = tonumber(hexColor:sub(5, 6), 16) or 255
    local b = tonumber(hexColor:sub(7, 8), 16) or 255
    
    return r / 255, g / 255, b / 255, a / 255
end

-- ========================================================================================================================
-- 事件分发器
-- ========================================================================================================================
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

function ns.RegisterEventHandler(event, handler)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(eventHandlers[event], handler)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = eventHandlers[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            handler(...)
        end
    end
end)

-- ========================================================================================================================
-- 选项表
-- ========================================================================================================================
local subCategories = {
    ["地图设置"] = { name = "地图设置" },
}
local order = { "地图设置" }

--------------------------------------------------------------------------------
-- 选项函数
--------------------------------------------------------------------------------
-- 地图设置模块
local function markerTypeOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add("TEXT", "文本标记")
    container:Add("ICON", "图标标记")
    return container:GetData()
end

local textOutlineOptions = function()
    local container = Settings.CreateControlTextContainer()
    container:Add("", "无")
    container:Add("OUTLINE", "细轮廓")
    return container:GetData()
end

local function iconGlowOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add("", "无")
    container:Add("GLOW", "外发光")
    return container:GetData()
end

-- ========================================================================================================================
-- 配置表
-- ========================================================================================================================
local DB = {
    --------------------------------------------------------------------------------
    -- 地图设置模块
    --------------------------------------------------------------------------------
    {
        category = "地图设置",
        items = {
            -- 基础功能
            { type = "SectionHeader", label = "基础功能" },
            { type = "Slider", var = "mapScale", label = "世界地图缩放", default = 1.0, tooltip = "调整世界地图框架大小", min = 0.5, max = 2, step = 0.1 },
            { type = "CheckBox", var = "isShowCoords", label = "启用地图ID和坐标", default = false, tooltip = "在世界地图上显示地图ID以及玩家和鼠标的坐标",  --lnui 
                isMasterConfig = true,
                items = {
                    { type = "Slider", var = "coordsAccuracy", label = "坐标精度", default = 1, tooltip = "坐标显示的小数位数\n0=整数, 1=1位小数, 2=2位小数", min = 0, max = 2, step = 1 },
                    { type = "ColorSwatch", var = "coordsTextColor", label = "文本颜色", default = "FFFFFFFF" },
                    { type = "Slider", var = "coordsFontSize", label = "文本大小", default = 14, min = 10, max = 20, step = 1 },
                    { type = "Slider", var = "coordsVerticalOffset", label = "文本位移丨垂直", default = -220, min = -1000, max = 1000, step = 1 },
                }
            },
            -- 全地图NPC标记
            { type = "SectionHeader", label = "全地图NPC标记" },
            { type = "CheckBox", var = "enableMapMarkers", label = "启用全地图NPC标记", default = true, 
                isMasterConfig = true,
                items = {
                    { var = "mapMarkersPortal", label = "传送", tooltip = "传送/通道" },
                    { var = "mapMarkersInn", label = "旅店" },
                    { var = "mapMarkersOfficial", label = "商业", tooltip = "拍卖/银行/黑市" },
                    { var = "mapMarkersProfession", label = "专业" },
                    { var = "mapMarkersService", label = "服务", tooltip = "理发/幻化/商栈/物品升级/订单/地下堡总部" },
                    { var = "mapMarkersStable", label = "兽栏" },
                    { var = "mapMarkersCollection", label = "藏品", tooltip = "坐骑/玩具/宠物/家宅装饰" },
                    { var = "mapMarkersVendor", label = "通用商人", tooltip = "普通商人/公会商人/外观商人/传家宝商人" },
                    { var = "mapMarkersUnique", label = "特殊商人", tooltip = "墨黑药水/焰火/礼服/要塞图纸/埃匹希斯水晶/黄金挑战/服役勋章/海岛/格里伏塔/社交名媛/冰冻宝珠/变形术/血商/橙装/古怪硬币/盟约升级/青铜锭/血腥硬币/元素涌流/可乐罐" },
                    { var = "mapMarkersSpecial", label = "特殊功能", tooltip = "马戏团专业任务/传送门训练师/克罗米/经验锁定/动画/场景战役/R币/拆解机/排随机本/盟约功能/化生台/幻形讲坛" },
                    { var = "mapMarkersQuartermaster", label = "军需官", tooltip = "声望军需官/盟约军需官" },
                    { var = "mapMarkersPvp", label = "PVP相关", tooltip = "pvp商人/pvp坐骑/木桩" },
                    { var = "mapMarkersInstance", label = "副本" },
                    { var = "mapMarkersDelve", label = "地下堡" },
                }
            },
            { type = "SectionHeader", label = "配置调整" },
            { type = "Slider", var = "globalMarkerSize", label = "全局标记大小", default = 14, min = 8, max = 20, step = 1 },
            { type = "Slider", var = "markerFrameLevel", label = "标记层级", default = 2200, min = 1, max = 5000, step = 1 },
            { type = "Slider", var = "markerZoomThreshold", label = "聚合标记切换阈值", default = 2, min = 0, max = 8, step = 1, tooltip = "控制地图放大时，从聚合标记切换成独立标记的滚轮次数\n\n原生地图缩放共有8级，对应7次滚轮缩放\n\n值=1-7：放大前聚合标记，放大后独立标记\n值=0：始终使用独立标记\n值=8：始终使用聚合标记" },
            { type = "Slider", var = "dynamicMarkerYOffset", label = "原生标记偏移", default = 0, min = -30, max = 30, step = 1, tooltip = "调整覆盖在暴雪原生图标（传送门/地下堡/副本等动态捕获类）上的文本标记的Y轴位置" },
            { type = "DropDown", var = "mapMarkerType", label = "标记显示类型", default = "TEXT", options = markerTypeOptions },--lnui
            { type = "DropDown", var = "mapMarkerTextOutline", label = "文本标记样式", default = "OUTLINE", options = textOutlineOptions },
            { type = "DropDown", var = "mapMarkerIconGlow", label = "图标标记样式", default = "GLOW", options = iconGlowOptions },--lnui
            { type = "CheckBox", var = "mapMarkerTooltips", label = "鼠标提示", default = true, tooltip = "显示标记的额外提示信息" },--lnui
            { type = "CheckBox", var = "enableMarkerWaypoint", label = "标记路径", default = false, tooltip = "左键点击创建路径点，右键点击取消路径点" },
            { type = "CheckBox", var = "mapMarkerProfessionFilter", label = "专业过滤", default = true, tooltip = "只显示你学习的专业，钓鱼烹饪考古除外" },--lnui
            -- 城市标记
            {
                type = "CheckBoxSlider",
                SliderLabel = "",
                CheckBoxDefault = true,
                SliderDefault = 1,
                min = 0.5, max = 2, step = 0.1,
                items = {
                    -- 联盟
                    { type = "SectionHeader", label = "联盟" },
                    { CheckBoxvar = "showStormwind", Slidervar = "scaleStormwind", CheckBoxLabel = "暴风城" },
                    { CheckBoxvar = "showIronforge", Slidervar = "scaleIronforge", CheckBoxLabel = "铁炉堡" },
                    { CheckBoxvar = "showDarnassus", Slidervar = "scaleDarnassus", CheckBoxLabel = "达纳苏斯" },
                    { CheckBoxvar = "showExodar", Slidervar = "scaleExodar", CheckBoxLabel = "埃索达" },
                    { CheckBoxvar = "showGilneas", Slidervar = "scaleGilneas", CheckBoxLabel = "吉尔尼斯" },
                    { CheckBoxvar = "showStormshield", Slidervar = "scaleStormshield", CheckBoxLabel = "暴风之盾" },
                    { CheckBoxvar = "showBoralus", Slidervar = "scaleBoralus", CheckBoxLabel = "伯拉勒斯" },
                    { CheckBoxvar = "showBelamath", Slidervar = "scaleBelamath", CheckBoxLabel = "贝拉梅斯" },
                    -- 部落
                    { type = "SectionHeader", label = "部落" },
                    { CheckBoxvar = "showOrgrimmar", Slidervar = "scaleOrgrimmar", CheckBoxLabel = "奥格瑞玛" },
                    { CheckBoxvar = "showThunderBluff", Slidervar = "scaleThunderBluff", CheckBoxLabel = "雷霆崖" },
                    { CheckBoxvar = "showUndercity", Slidervar = "scaleUndercity", CheckBoxLabel = "幽暗城" },
                    { CheckBoxvar = "showSilvermoonCityTBC", Slidervar = "scaleSilvermoonCityTBC", CheckBoxLabel = "银月城（燃烧的远征）" },
                    { CheckBoxvar = "showWarspear", Slidervar = "scaleWarspear", CheckBoxLabel = "战争之矛" },
                    { CheckBoxvar = "showDazaralor", Slidervar = "scaleDazaralor", CheckBoxLabel = "达萨罗" },
                    -- 中立
                    { type = "SectionHeader", label = "中立" },
                    { CheckBoxvar = "showShattrath", Slidervar = "scaleShattrath", CheckBoxLabel = "沙塔斯" },
                    { CheckBoxvar = "showDalaranWLK", Slidervar = "scaleDalaranWLK", CheckBoxLabel = "达拉然（巫妖王之怒）" },
                    { CheckBoxvar = "showDalaranLegion", Slidervar = "scaleDalaranLegion", CheckBoxLabel = "达拉然（军团再临）" },
                    { CheckBoxvar = "showOribos", Slidervar = "scaleOribos", CheckBoxLabel = "奥利波斯" },
                    { CheckBoxvar = "showSanctumofDomination", Slidervar = "scaleSanctumofDomination", CheckBoxLabel = "兵主之座" },
                    { CheckBoxvar = "showSinfall", Slidervar = "scaleSinfall", CheckBoxLabel = "堕罪堡" },
                    { CheckBoxvar = "showHeartoftheForest", Slidervar = "scaleHeartoftheForest", CheckBoxLabel = "森林之心" },
                    { CheckBoxvar = "showElysianHold", Slidervar = "scaleElysianHold", CheckBoxLabel = "极乐堡" },
                    { CheckBoxvar = "showValdrakken", Slidervar = "scaleValdrakken", CheckBoxLabel = "瓦德拉肯" },
                    { CheckBoxvar = "showDornogal", Slidervar = "scaleDornogal", CheckBoxLabel = "多恩诺嘉尔" },
                    { CheckBoxvar = "showCityofThreads", Slidervar = "scaleCityofThreads", CheckBoxLabel = "千丝之城" },
                    { CheckBoxvar = "showUndermine", Slidervar = "scaleUndermine", CheckBoxLabel = "安德麦" },
                    { CheckBoxvar = "showTazavesh", Slidervar = "scaleTazavesh", CheckBoxLabel = "塔扎维什" },
                    { CheckBoxvar = "showSilvermoonCityMidnight", Slidervar = "scaleSilvermoonCityMidnight", CheckBoxLabel = "银月城（至暗之夜）", SliderDefault = 1.2 },--lnui
                    { CheckBoxvar = "showTheTimeways", Slidervar = "scaleTheTimeways", CheckBoxLabel = "千禧阈限（S1赛季）", SliderDefault = 1.2 },--lnui
                    -- 区域
                    { type = "SectionHeader", label = "区域" },
                    { CheckBoxvar = "showDarkmoonfaire", Slidervar = "scaleDarkmoonfaire", CheckBoxLabel = "暗月马戏团" },
                    { CheckBoxvar = "showIsleofDorn", Slidervar = "scaleIsleofDorn", CheckBoxLabel = "多恩岛" },
                    { CheckBoxvar = "showTheRingingDeeps", Slidervar = "scaleTheRingingDeeps", CheckBoxLabel = "喧鸣深窟" },
                    { CheckBoxvar = "showHallowfall", Slidervar = "scaleHallowfall", CheckBoxLabel = "陨圣峪" },
                    { CheckBoxvar = "showAzjKahet", Slidervar = "scaleAzjKahet", CheckBoxLabel = "艾基-卡赫特" },
                    { CheckBoxvar = "showKAresh", Slidervar = "scaleKAresh", CheckBoxLabel = "卡雷什" },
                    { CheckBoxvar = "showEversongWoods", Slidervar = "scaleEversongWoods", CheckBoxLabel = "永歌森林", SliderDefault = 1.2 },--lnui
                    { CheckBoxvar = "showVoidstorm", Slidervar = "scaleVoidstorm", CheckBoxLabel = "虚影风暴", SliderDefault = 1.2 },--lnui
                    { CheckBoxvar = "showIsleofQuelDanas", Slidervar = "scaleIsleofQuelDanas", CheckBoxLabel = "奎尔丹纳斯岛", SliderDefault = 1.2 },--lnui
                    { CheckBoxvar = "showZulAman", Slidervar = "scaleZulAman", CheckBoxLabel = "祖阿曼", SliderDefault = 1.2 },--lnui
                    { CheckBoxvar = "showHarandar", Slidervar = "scaleHarandar", CheckBoxLabel = "哈籁恩达尔", SliderDefault = 1.2 },--lnui
                    { CheckBoxvar = "showTheDen", Slidervar = "scaleTheDen", CheckBoxLabel = "哈籁恩达尔：大巢穴", SliderDefault = 1.2 },--lnui
                }
            },
        }
    },
}

-- ========================================================================================================================
-- 回调函数
-- ========================================================================================================================
local callbackMap = {
    --------------------------------------------------------------------------------
    -- 地图设置模块回调
    --------------------------------------------------------------------------------
    -- 基础功能回调
    ["mapScale"] = function(value) ns:SetMapScale(value) end,
    ["isShowCoords"] = function() ns:ToggleCoordsDisplay() end,
    ["coordsAccuracy"] = function() ns:UpdateCoordsDisplay() end,
    ["coordsTextColor"] = function() ns:UpdateCoordsTextColor() end,
    ["coordsFontSize"] = function(value) ns:UpdateCoordsFontSize(value) end,
    ["coordsVerticalOffset"] = function() ns:UpdateCoordsVerticalOffset() end,
    -- 全地图NPC标记回调
    ["enableMapMarkers"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersPortal"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersInn"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersOfficial"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersProfession"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersService"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersStable"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersCollection"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersVendor"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersUnique"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersSpecial"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersQuartermaster"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersPvp"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersInstance"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkersDelve"] = function() ns:ToggleMapMarkers() end,
    -- 配置调整回调
    ["globalMarkerSize"] = function() ns:ToggleMapMarkers() end,
    ["markerFrameLevel"] = function() ns:ToggleMapMarkers() end,
    ["markerZoomThreshold"] = function() ns:ToggleMapMarkers() end,
    ["dynamicMarkerYOffset"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkerType"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkerTextOutline"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkerIconGlow"] = function() ns:ToggleMapMarkers() end,
    ["mapMarkerTooltips"] = function() ns:ToggleMapMarkers() end,
    ["enableMarkerWaypoint"] = function(value) ns:ToggleMarkerWaypoint(value) end,
    ["mapMarkerProfessionFilter"] = function() ns:ToggleMapMarkers() end,
    -- 联盟
    ["showStormwind"] = function() ns:ToggleMapMarkers() end,
    ["scaleStormwind"] = function() ns:ToggleMapMarkers() end,
    ["showIronforge"] = function() ns:ToggleMapMarkers() end,
    ["scaleIronforge"] = function() ns:ToggleMapMarkers() end,
    ["showDarnassus"] = function() ns:ToggleMapMarkers() end,
    ["scaleDarnassus"] = function() ns:ToggleMapMarkers() end,
    ["showExodar"] = function() ns:ToggleMapMarkers() end,
    ["scaleExodar"] = function() ns:ToggleMapMarkers() end,
    ["showGilneas"] = function() ns:ToggleMapMarkers() end,
    ["scaleGilneas"] = function() ns:ToggleMapMarkers() end,
    ["showStormshield"] = function() ns:ToggleMapMarkers() end,
    ["scaleStormshield"] = function() ns:ToggleMapMarkers() end,
    ["showBoralus"] = function() ns:ToggleMapMarkers() end,
    ["scaleBoralus"] = function() ns:ToggleMapMarkers() end,
    ["showBelamath"] = function() ns:ToggleMapMarkers() end,
    ["scaleBelamath"] = function() ns:ToggleMapMarkers() end,
    -- 部落
    ["showOrgrimmar"] = function() ns:ToggleMapMarkers() end,
    ["scaleOrgrimmar"] = function() ns:ToggleMapMarkers() end,
    ["showThunderBluff"] = function() ns:ToggleMapMarkers() end,
    ["scaleThunderBluff"] = function() ns:ToggleMapMarkers() end,
    ["showUndercity"] = function() ns:ToggleMapMarkers() end,
    ["scaleUndercity"] = function() ns:ToggleMapMarkers() end,
    ["showSilvermoonCityTBC"] = function() ns:ToggleMapMarkers() end,
    ["scaleSilvermoonCityTBC"] = function() ns:ToggleMapMarkers() end,
    ["showWarspear"] = function() ns:ToggleMapMarkers() end,
    ["scaleWarspear"] = function() ns:ToggleMapMarkers() end,
    ["showDazaralor"] = function() ns:ToggleMapMarkers() end,
    ["scaleDazaralor"] = function() ns:ToggleMapMarkers() end,
    -- 中立城市
    ["showShattrath"] = function() ns:ToggleMapMarkers() end,
    ["scaleShattrath"] = function() ns:ToggleMapMarkers() end,
    ["showDalaranWLK"] = function() ns:ToggleMapMarkers() end,
    ["scaleDalaranWLK"] = function() ns:ToggleMapMarkers() end,
    ["showDalaranLegion"] = function() ns:ToggleMapMarkers() end,
    ["scaleDalaranLegion"] = function() ns:ToggleMapMarkers() end,
    ["showOribos"] = function() ns:ToggleMapMarkers() end,
    ["scaleOribos"] = function() ns:ToggleMapMarkers() end,
    ["showSanctumofDomination"] = function() ns:ToggleMapMarkers() end,
    ["scaleSanctumofDomination"] = function() ns:ToggleMapMarkers() end,
    ["showSinfall"] = function() ns:ToggleMapMarkers() end,
    ["scaleSinfall"] = function() ns:ToggleMapMarkers() end,
    ["showHeartoftheForest"] = function() ns:ToggleMapMarkers() end,
    ["scaleHeartoftheForest"] = function() ns:ToggleMapMarkers() end,
    ["showElysianHold"] = function() ns:ToggleMapMarkers() end,
    ["scaleElysianHold"] = function() ns:ToggleMapMarkers() end,
    ["showValdrakken"] = function() ns:ToggleMapMarkers() end,
    ["scaleValdrakken"] = function() ns:ToggleMapMarkers() end,
    ["showDornogal"] = function() ns:ToggleMapMarkers() end,
    ["scaleDornogal"] = function() ns:ToggleMapMarkers() end,
    ["showCityofThreads"] = function() ns:ToggleMapMarkers() end,
    ["scaleCityofThreads"] = function() ns:ToggleMapMarkers() end,
    ["showUndermine"] = function() ns:ToggleMapMarkers() end,
    ["scaleUndermine"] = function() ns:ToggleMapMarkers() end,
    ["showTazavesh"] = function() ns:ToggleMapMarkers() end,
    ["scaleTazavesh"] = function() ns:ToggleMapMarkers() end,
    ["showSilvermoonCityMidnight"] = function() ns:ToggleMapMarkers() end,
    ["scaleSilvermoonCityMidnight"] = function() ns:ToggleMapMarkers() end,
    ["showTheTimeways"] = function() ns:ToggleMapMarkers() end,
    ["scaleTheTimeways"] = function() ns:ToggleMapMarkers() end,
    -- 地图区域
    ["showDarkmoonfaire"] = function() ns:ToggleMapMarkers() end,
    ["scaleDarkmoonfaire"] = function() ns:ToggleMapMarkers() end,
    ["showIsleofDorn"] = function() ns:ToggleMapMarkers() end,
    ["scaleIsleofDorn"] = function() ns:ToggleMapMarkers() end,
    ["showTheRingingDeeps"] = function() ns:ToggleMapMarkers() end,
    ["scaleTheRingingDeeps"] = function() ns:ToggleMapMarkers() end,
    ["showHallowfall"] = function() ns:ToggleMapMarkers() end,
    ["scaleHallowfall"] = function() ns:ToggleMapMarkers() end,
    ["showAzjKahet"] = function() ns:ToggleMapMarkers() end,
    ["scaleAzjKahet"] = function() ns:ToggleMapMarkers() end,
    ["showKAresh"] = function() ns:ToggleMapMarkers() end,
    ["scaleKAresh"] = function() ns:ToggleMapMarkers() end,
    ["showEversongWoods"] = function() ns:ToggleMapMarkers() end,
    ["scaleEversongWoods"] = function() ns:ToggleMapMarkers() end,
    ["showVoidstorm"] = function() ns:ToggleMapMarkers() end,
    ["scaleVoidstorm"] = function() ns:ToggleMapMarkers() end,
    ["showIsleofQuelDanas"] = function() ns:ToggleMapMarkers() end,
    ["scaleIsleofQuelDanas"] = function() ns:ToggleMapMarkers() end,
    ["showZulAman"] = function() ns:ToggleMapMarkers() end,
    ["scaleZulAman"] = function() ns:ToggleMapMarkers() end,
    ["showHarandar"] = function() ns:ToggleMapMarkers() end,
    ["scaleHarandar"] = function() ns:ToggleMapMarkers() end,
    ["showTheDen"] = function() ns:ToggleMapMarkers() end,
    ["scaleTheDen"] = function() ns:ToggleMapMarkers() end,
}

-- 回调函数分发器
local function OnSettingChanged(setting, value)
    local variable = setting:GetVariable()
    
    local callback = callbackMap[variable]
    if callback then
        callback(value)
    end
end

-- ========================================================================================================================
-- 斜杠命令
-- ========================================================================================================================
SLASH_RoyMapGuide1 = "/rmg"
SlashCmdList["RoyMapGuide"] = function()
    if Settings and mainCategory then
        Settings.OpenToCategory(mainCategory:GetID())
    end
end

-- ========================================================================================================================
-- 数据初始化
-- ========================================================================================================================
local function initializeSettings()
    RoyMapGuideDB = RoyMapGuideDB or {}
    
    -- 统一初始化所有配置变量
    for _, categoryEntry in ipairs(DB) do
        if categoryEntry.items then
            -- 获取公共参数
            local defaultType = categoryEntry.type
            local defaultValue = categoryEntry.default
        
            local function initItems(items, parentType, parentDefaults)
                for _, entry in ipairs(items) do
                    -- 嵌套组
                    if entry.items then
                        if entry.isMasterConfig and entry.type == "CheckBox" then
                            -- 初始化父级 CheckBox 变量
                            if entry.var and RoyMapGuideDB[entry.var] == nil then
                                local value = entry.default
                                if value == nil then
                                    value = parentDefaults and parentDefaults.default
                                end
                                if value == nil then
                                    value = true
                                end
                                RoyMapGuideDB[entry.var] = value
                            end
                            
                            -- 递归处理嵌套组
                            initItems(entry.items, entry.type, entry)
                        else
                            -- 普通嵌套组继续递归
                            initItems(entry.items, entry.type, entry)
                        end

                    else
                        -- 确定实际type参数
                        local actualType = entry.type or parentType or defaultType
                    
                        -- 确定实际default参数（配置自身 > 父级 > 全局）
                        local function getDefaultValue(field)
                            if entry[field] ~= nil then
                                return entry[field]
                            elseif parentDefaults and parentDefaults[field] ~= nil then
                                return parentDefaults[field]
                            else
                                return defaultValue
                            end
                        end
                        
                        if actualType == "SectionHeader" then
                        
                        elseif actualType == "CheckBox" then
                            if entry.var and RoyMapGuideDB[entry.var] == nil then
                                RoyMapGuideDB[entry.var] = getDefaultValue("default")
                            end
                        
                        elseif actualType == "Slider" then
                            if entry.var and RoyMapGuideDB[entry.var] == nil then
                                RoyMapGuideDB[entry.var] = getDefaultValue("default")
                            end
                        
                        elseif actualType == "DropDown" then
                            if entry.var and RoyMapGuideDB[entry.var] == nil then
                                RoyMapGuideDB[entry.var] = getDefaultValue("default")
                            end
                        
                        elseif actualType == "ColorSwatch" then
                            if entry.var and RoyMapGuideDB[entry.var] == nil then
                                RoyMapGuideDB[entry.var] = getDefaultValue("default")
                            end
                        
                        elseif actualType == "CheckBoxSlider" then
                            if entry.CheckBoxvar and RoyMapGuideDB[entry.CheckBoxvar] == nil then
                                local value = getDefaultValue("CheckBoxDefault")
                                RoyMapGuideDB[entry.CheckBoxvar] = value
                            end
                            if entry.Slidervar and RoyMapGuideDB[entry.Slidervar] == nil then
                                local value = getDefaultValue("SliderDefault")
                                RoyMapGuideDB[entry.Slidervar] = value
                            end
                        
                        elseif actualType == "CheckBoxDropDown" then
                            if entry.CheckBoxvar and RoyMapGuideDB[entry.CheckBoxvar] == nil then
                                local value = getDefaultValue("CheckBoxDefault")
                                RoyMapGuideDB[entry.CheckBoxvar] = value
                            end
                            if entry.DropDownvar and RoyMapGuideDB[entry.DropDownvar] == nil then
                                local value = getDefaultValue("DropDownDefault")
                                RoyMapGuideDB[entry.DropDownvar] = value
                            end
                        end
                    end
                end
            end
            
            initItems(categoryEntry.items)
        end
    end
    
    --------------------------------------------------------------------------------
    -- 创建设置界面
    --------------------------------------------------------------------------------
    local MainSettingFrame = CreateFrame("Frame")
    
    -- 创建标题
    local header = MainSettingFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOP", 0, -20)
    header:SetText("RoyMapGuide")
    header:SetTextColor(1, 0.8, 0)
    header:SetFont(STANDARD_TEXT_FONT, 30, "OUTLINE")
    
    local subtitle = MainSettingFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOP", header, "BOTTOM", 0, -10)
    subtitle:SetText("地图标记增强")
    subtitle:SetTextColor(0.6, 0.8, 1)
    subtitle:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")

    -- 装饰线
    local line = MainSettingFrame:CreateLine()
    line:SetColorTexture(0.8, 0.6, 0, 0.6)
    line:SetThickness(1.5)
    line:SetStartPoint("TOPLEFT", 20, -90)
    line:SetEndPoint("TOPRIGHT", -20, -90)

    -- 更新记录标题
    local changelogTitle = MainSettingFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    changelogTitle:SetPoint("TOP", line, "BOTTOM", 0, -15)
    changelogTitle:SetWidth(600)
    changelogTitle:SetJustifyH("LEFT")
    changelogTitle:SetText("更新记录")
    changelogTitle:SetTextColor(1, 0.8, 0)

    -- 创建滚动框架容器
    local changelogScrollFrame = CreateFrame("ScrollFrame", nil, MainSettingFrame, "UIPanelScrollFrameTemplate")
    changelogScrollFrame:SetPoint("TOP", changelogTitle, "BOTTOM", 0, -10)
    changelogScrollFrame:SetPoint("LEFT", 30, 0)     -- 父框架左边距
    changelogScrollFrame:SetPoint("RIGHT", -50, 0)   -- 父框架右边距
    changelogScrollFrame:SetHeight(400)              -- 滚动框架高度（超出范围即可滚动）

    -- 创建实际内容滚动框架
    local changelogScrollChild = CreateFrame("Frame")
    changelogScrollFrame:SetScrollChild(changelogScrollChild)
    changelogScrollChild:SetWidth(570)

    -- 创建更新记录文本
    local changelog = changelogScrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    changelog:SetPoint("TOPLEFT", changelogScrollChild, "TOPLEFT", 10, -10)
    changelog:SetWidth(570)
    changelog:SetJustifyH("LEFT")
    changelog:SetSpacing(10)
    changelog:SetText([[
【2026.4.22】v1.5.5
・添加12.0.5支持
・代码结构重构优化中

【2026.4.3】v1.5.4
・补充银月城（至暗之夜）黑市和家宅标记

【2026.4.2】v1.5.3
・补充地下堡幻日广场

【2026.3.27】v1.5.2
・补充永歌森林区域地图上的地下堡黑暗回廊

【2026.3.27】v1.5.1
・补充地下堡黑暗回廊

【2026.3.23】v1.5
・添加标记创建路径点功能，左键创建，右键取消
・添加原生标记文本偏移功能
・修复已知标记错误

【2026.3.20】v1.4
标记
・补充时间流、千禧阈限、宿敌地下堡、剥皮稀有标记
代码
・调整地图ID和坐标功能的配置结构为父子配置

【2026.3.16】v1.3
标记
・修复启用专业过滤后，部分专业不显示的问题
代码
・修复父子配置中父级配置默认值不生效的问题

【2026.3.15】v1.2
标记
・完善12.0银月城（至暗之夜）和4大区域标记
・补回银月城（燃烧的远征）标记
・更改两个达拉然主城名称，使用标准版本名称而非区域名称
・暂时移除卡兹阿加和银月城（至暗之夜）的时间流传送门
功能
・添加地图缩放功能
・添加MapID、玩家坐标和鼠标坐标显示，可调颜色、大小、位置
・添加标记层级更改
・添加标记缩放阈值，用于切换聚合标记和独立标记
・添加地图开关功能，左键开关标记，右键图文切换
代码
・添加父子配置联动，目前仅限单一控件
・完全重构当前所有标记数据结构
・添加动态捕获逻辑，用于捕获暴雪原生地图标记（当前为poi/maplink/副本/地下堡4类）
・修复获取坐标内存泄露
・其他代码优化和修复

【2026.2.28】v1.1
・添加12.0主城标记（临时版）

【2026.2.11】v1.0
・插件版
]])
    changelog:SetTextColor(0.5, 0.5, 0.5)

    local textHeight = changelog:GetStringHeight()
    changelogScrollChild:SetHeight(textHeight + 30)

    -- 创建边框背景纹理
    local borderFrame = CreateFrame("Frame", nil, changelogScrollFrame, "BackdropTemplate")

    -- 设置边框上下扩展距离
    borderFrame:SetPoint("TOPLEFT", changelogScrollFrame, "TOPLEFT", 0, 0)
    borderFrame:SetPoint("BOTTOMRIGHT", changelogScrollFrame, "BOTTOMRIGHT", 0, 0)
    borderFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",     -- 背景纹理
        -- edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",     -- 边框纹理
        -- edgeSize = 20,
        -- insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    borderFrame:SetBackdropColor(0, 0, 0, 0.8)     -- 背景颜色和透明度
    borderFrame:SetFrameStrata("BACKGROUND")

    -- 注册主设置类别
    mainCategory = Settings.RegisterCanvasLayoutCategory(MainSettingFrame, "RoyMapGuide")
    Settings.RegisterAddOnCategory(mainCategory)
    
    -- 注册子类别
    for _, v in ipairs(order) do
        local category = subCategories[v]
        category.handle, category.layout = Settings.RegisterVerticalLayoutSubcategory(mainCategory, category.name)
    end

    --------------------------------------------------------------------------------
    -- 通用创建函数
    --------------------------------------------------------------------------------
    local function createSliderOptions(entry)
        local options = Settings.CreateSliderOptions(entry.min, entry.max, entry.step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            if entry.step and entry.step < 1 then
                return string.format("%.1f", value)
            else
                return string.format("%.0f", value)
            end
        end)
        return options
    end
    
    local function createSetting(category, variable, variableType, label, default, getFunc, setFunc)
        local setting = Settings.RegisterProxySetting(category, variable, variableType, label, default, getFunc, setFunc)
        setting:SetValueChangedCallback(OnSettingChanged)
        return setting
    end

    --------------------------------------------------------------------------------
    -- 创建设置项
    --------------------------------------------------------------------------------
    for _, categoryEntry in ipairs(DB) do
        local catInfo = subCategories[categoryEntry.category]
        if catInfo and categoryEntry.items then
            local defaultType = categoryEntry.type
            
            -- 递归函数创建设置项
            local function createItems(items, parentType, parentEntry, parentInitializer)
                for _, entry in ipairs(items) do
                    if entry.items then
                        if entry.isMasterConfig and entry.type == "CheckBox" then
                            local parentControlInitializer
                            
                            if entry.type == "CheckBox" then
                                -- 创建父级CheckBox
                                local mergedEntry = {}
                                if parentEntry then
                                    for k, v in pairs(parentEntry) do
                                        if k ~= "items" and k ~= "type" and k ~= "isMasterConfig" then
                                            mergedEntry[k] = v
                                        end
                                    end
                                end
                                for k, v in pairs(entry) do
                                    if k ~= "items" and k ~= "isMasterConfig" then
                                        mergedEntry[k] = v
                                    end
                                end
                                mergedEntry.type = "CheckBox"
                                
                                if not mergedEntry.var then
                                    error("Master CheckBox missing 'var' field")
                                end
                                
                                local setting = createSetting(
                                    catInfo.handle, mergedEntry.var, "boolean", 
                                    mergedEntry.label or "Unknown", mergedEntry.default or false,
                                    function() return RoyMapGuideDB[mergedEntry.var] end,
                                    function(value) RoyMapGuideDB[mergedEntry.var] = value end
                                )
                                parentControlInitializer = Settings.CreateCheckbox(catInfo.handle, setting, mergedEntry.tooltip)
                                
                                -- 子配置缩进
                                if parentInitializer and parentControlInitializer and parentControlInitializer.SetParentInitializer then
                                    parentControlInitializer:SetParentInitializer(parentInitializer, function() return true end)
                                end
                            end
                            
                            createItems(entry.items, entry.type, entry, parentControlInitializer or parentInitializer)
                            
                        else
                            -- 普通嵌套组继续递归
                            createItems(entry.items, entry.type, entry, parentInitializer)
                        end
                        
                    elseif entry.type == "SectionHeader" then
                        if entry.label then
                            local initializer = CreateSettingsListSectionHeaderInitializer(entry.label)
                            catInfo.layout:AddInitializer(initializer)
                        end
                        
                    else
                        -- 确定实际使用的type
                        local actualType = entry.type or parentType or defaultType
                        
                        local mergedEntry = {}
                        if parentEntry and not entry.isMasterConfig then
                            for k, v in pairs(parentEntry) do
                                if k ~= "items" and k ~= "type" and k ~= "isMasterConfig" then
                                    mergedEntry[k] = v
                                end
                            end
                        end
                        for k, v in pairs(entry) do
                            mergedEntry[k] = v
                        end
                        mergedEntry.type = actualType
                        
                        local initializer
                        local setting
                        
                        if actualType == "CheckBox" or actualType == "Slider" or actualType == "DropDown" or actualType == "ColorSwatch" then
                            if not mergedEntry.var then return end
                            
                            -- 勾选框
                            if actualType == "CheckBox" then
                                setting = createSetting(
                                    catInfo.handle, mergedEntry.var, "boolean", 
                                    mergedEntry.label or "Unknown", mergedEntry.default or false,
                                    function() return RoyMapGuideDB[mergedEntry.var] end,
                                    function(value) RoyMapGuideDB[mergedEntry.var] = value end
                                )
                                initializer = Settings.CreateCheckbox(catInfo.handle, setting, mergedEntry.tooltip)
                                
                            -- 滑动条
                            elseif actualType == "Slider" then
                                setting = createSetting(
                                    catInfo.handle, mergedEntry.var, "number", 
                                    mergedEntry.label or "Unknown", mergedEntry.default or 0,
                                    function() return RoyMapGuideDB[mergedEntry.var] end,
                                    function(value) RoyMapGuideDB[mergedEntry.var] = value end
                                )
                                local options = createSliderOptions(mergedEntry)
                                initializer = Settings.CreateSlider(catInfo.handle, setting, options, mergedEntry.tooltip)
                                
                            -- 下拉菜单
                            elseif actualType == "DropDown" then
                                setting = createSetting(
                                    catInfo.handle, mergedEntry.var, type(mergedEntry.default), 
                                    mergedEntry.label or "Unknown", mergedEntry.default,
                                    function() return RoyMapGuideDB[mergedEntry.var] end,
                                    function(value) RoyMapGuideDB[mergedEntry.var] = value end
                                )
                                initializer = Settings.CreateDropdown(catInfo.handle, setting, mergedEntry.options, mergedEntry.tooltip)
                                
                            -- 颜色选择器
                            elseif actualType == "ColorSwatch" then
                                setting = createSetting(
                                    catInfo.handle, mergedEntry.var, "string", 
                                    mergedEntry.label or "Unknown", mergedEntry.default or "FFFFFFFF",
                                    function() return RoyMapGuideDB[mergedEntry.var] end,
                                    function(value) RoyMapGuideDB[mergedEntry.var] = value end
                                )
                                initializer = Settings.CreateColorSwatch(catInfo.handle, setting, mergedEntry.hasOpacity, mergedEntry.tooltip)
                            end
                            
                            -- 设置父子关系
                            if parentInitializer and initializer and initializer.SetParentInitializer then
                                local function findMasterParent(entry)
                                    if entry and entry.isMasterConfig and entry.type == "CheckBox" and entry.var then
                                        return entry
                                    elseif entry and entry.parent then
                                        return findMasterParent(entry.parent)
                                    end
                                    return nil
                                end
                                
                                local masterParent = findMasterParent(parentEntry)
                                if masterParent then
                                    initializer:SetParentInitializer(parentInitializer, function()
                                        return RoyMapGuideDB[masterParent.var]
                                    end)
                                else
                                    initializer:SetParentInitializer(parentInitializer, function() return true end)
                                end
                            end
                        
                        -- 勾选框+滑动条
                        elseif actualType == "CheckBoxSlider" then
                            if not mergedEntry.CheckBoxvar or not mergedEntry.Slidervar then return end
                            
                            local cbSetting = createSetting(
                                catInfo.handle, mergedEntry.CheckBoxvar, "boolean",
                                mergedEntry.CheckBoxLabel or "Unknown", mergedEntry.CheckBoxDefault or false,
                                function() return RoyMapGuideDB[mergedEntry.CheckBoxvar] end,
                                function(value) RoyMapGuideDB[mergedEntry.CheckBoxvar] = value end
                            )
                            
                            local sliderSetting = createSetting(
                                catInfo.handle, mergedEntry.Slidervar, "number",
                                mergedEntry.SliderLabel or "Unknown", mergedEntry.SliderDefault or 0,
                                function() return RoyMapGuideDB[mergedEntry.Slidervar] end,
                                function(value) RoyMapGuideDB[mergedEntry.Slidervar] = value end
                            )
                            
                            local options = createSliderOptions(mergedEntry)
                            local cbSliderInitializer = CreateSettingsCheckboxSliderInitializer(
                                cbSetting, mergedEntry.CheckBoxLabel or "Unknown", mergedEntry.CheckBoxTooltip,
                                sliderSetting, options, mergedEntry.SliderLabel or "Unknown", mergedEntry.SliderTooltip
                            )
                            catInfo.layout:AddInitializer(cbSliderInitializer)
                            
                        -- 勾选框+下拉菜单
                        elseif actualType == "CheckBoxDropDown" then
                            if not mergedEntry.CheckBoxvar or not mergedEntry.DropDownvar then return end
                            
                            local cbSetting = createSetting(
                                catInfo.handle, mergedEntry.CheckBoxvar, "boolean",
                                mergedEntry.CheckBoxLabel or "Unknown", mergedEntry.CheckBoxDefault or false,
                                function() return RoyMapGuideDB[mergedEntry.CheckBoxvar] end,
                                function(value) RoyMapGuideDB[mergedEntry.CheckBoxvar] = value end
                            )
                            
                            local dropdownSetting = createSetting(
                                catInfo.handle, mergedEntry.DropDownvar, type(mergedEntry.DropDownDefault),
                                mergedEntry.DropDownLabel or "Unknown", mergedEntry.DropDownDefault,
                                function() return RoyMapGuideDB[mergedEntry.DropDownvar] end,
                                function(value) RoyMapGuideDB[mergedEntry.DropDownvar] = value end
                            )
                            
                            local cbDropdownInitializer = CreateSettingsCheckboxDropdownInitializer(
                                cbSetting, mergedEntry.CheckBoxLabel or "Unknown", mergedEntry.CheckBoxTooltip,
                                dropdownSetting, mergedEntry.options, mergedEntry.DropDownLabel or "Unknown", mergedEntry.DropDownTooltip
                            )
                            catInfo.layout:AddInitializer(cbDropdownInitializer)
                        end
                    end
                end
            end
            
            createItems(categoryEntry.items, nil, nil, nil)
        end
    end
end

-- ========================================================================================================================
-- 事件处理
-- ========================================================================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == addonName then
        initializeSettings()
    end
end)