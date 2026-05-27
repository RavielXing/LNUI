U1PLUG["QuickAuctionBuyer"] = function()
-- ==========================================
-- QuickAuctionBuyer - 拍卖行购物助手
-- 衷心感谢 NGA 论坛 冰摇柠檬、雪白的黑牛 两位基于 WeakAuras 制作的版本。
-- 本版改用魔兽世界原生 UI 模板（ButtonFrameTemplate / PanelTabButtonTemplate / UIPanelScrollFrameTemplate / 原生纹理）重制，零外部美术。作者：pectionly @ NGA ，https://nga.178.com/nuke.php?func=ucp&uid=63034626
-- ==========================================

-- ==========================================
-- 布局常量
-- ==========================================
-- 每行显示 5 个图标，自动换行；宽 ≈ 5*ICON_SIZE + 4*ICON_HGAP
local WINDOW_WIDTH       = 330
local WINDOW_HEIGHT      = 540

local ICON_SIZE          = 37            -- ItemButtonTemplate 默认尺寸
local ICON_HGAP          = 14            -- 图标列之间水平间距（略宽，不挤）
local ICON_VGAP          = 26            -- 图标行与行之间的纵向间距（含图标下方文字标签）
local LABEL_GAP          = 4             -- 图标到下方文字的间距
local SECTION_HEADER_H   = 22            -- 子类别标题栏高度

-- 垂直节奏：「标题 ↔ 图标行 ↔ 下一标题」使用同一间距（像素）
local SECTION_V_SPACING    = 16

-- ------------------------------------------------------------------
-- 留白：
--   FRAME_INSET_MARGIN — 深黑 Inset 与外层金属框
--   CONTENT_MARGIN     — 滚动内容区左/上/底与 Inset 内缘；右侧由滚动条贴齐，不再额外留缝
-- ------------------------------------------------------------------
local FRAME_INSET_MARGIN = 12
local CONTENT_MARGIN     = 22
local SCROLLBAR_WIDTH    = 28            -- 原生滚动条占位宽度

-- 滚动子内容宽度：左留白 + 可视区 + 滚动条贴右
local CONTENT_WIDTH = WINDOW_WIDTH - 2 * FRAME_INSET_MARGIN - CONTENT_MARGIN - SCROLLBAR_WIDTH

-- ==========================================
-- 颜色常量（沿用 WoW 标准色）
-- ==========================================
local COLOR_TEXT_NORMAL    = {1.0, 0.82, 0.0}       -- 金色（标题/选中）
local COLOR_TEXT_LIGHT     = {1.0, 1.0, 1.0}        -- 白色（正常文字）
local COLOR_TEXT_DIM       = {0.5, 0.5, 0.5}        -- 灰色（背包中没有）
local COLOR_COUNT          = {0.1, 1.0, 0.1}        -- 绿色（数量提示）

-- 统一比当前模板字号小 1px（最小 8）
local function FontDownOne(fs)
    if not fs or not fs.GetFont then return end
    local fontFile, size, flags = fs:GetFont()
    if fontFile and size then
        fs:SetFont(fontFile, math.max(8, math.floor(size + 0.5) - 1), flags or "")
    end
end

-- ==========================================
-- 数据声明
-- ==========================================
local TAB_DEFS = {
    {key = "consumable", name = "消耗品"},
    {key = "enchant",    name = "装备附魔"},
    {key = "gem",        name = "公函与宝石"},
}

local categoryData = {
    consumable = {},
    enchant    = {},
    gem        = {},
}

local function AddCategory(tabKey, title, buttons)
    table.insert(categoryData[tabKey], {title = title, buttons = buttons})
end

-- ==========================================
-- 数据填充：消耗品
-- ==========================================
AddCategory("consumable", "药水", {
    {label = "红药",   search = "银月城生命药水",  id = {241304, 241305}},
    {label = "蓝药",   search = "光注法力药水",    id = {241300, 241301}},
    {label = "双回",   search = "复苏血清",        id = {241306, 241307}},
    {label = "护盾",   search = "圣光之护",        id = {241286, 241287}},
    {label = "隐身",   search = "虚空遮蔽酊剂",    id = {241302, 241303}},
    {label = "主属性", search = "圣光潜力",        id = {241308, 241309}},
    {label = "主狂",   search = "狂放恣意饮剂",    id = {241292, 241293}},
    {label = "绿字",   search = "鲁莽药水",        id = {241288, 241289}},
    {label = "单体",   search = "狂热药水",        id = {241296, 241297}},
})

AddCategory("consumable", "合剂/武器加强", {
    {label = "暴击", search = "破碎残阳合剂",   id = {241326, 241327}},
    {label = "急速", search = "血骑士合剂",     id = {241324, 241325}},
    {label = "全能", search = "萨拉斯抗性合剂", id = {241320, 241321}},
    {label = "精通", search = "魔导师合剂",     id = {241322, 241323}},
    {label = "平衡石", search = "辉耀平衡石",         id = {237367, 237369}},
    {label = "磨刀石", search = "辉耀磨刀石",         id = {237370, 237371}},
    {label = "绿字",   search = "萨拉斯凤凰之油",     id = {243734, 243733}},
    {label = "治疗",   search = "黎明之油",           id = {243735, 243736}},
    {label = "奥术",   search = "私运者的附魔之锋",   id = {243737, 243738}},
})

AddCategory("consumable", "食物/符文", {
    {label = "主属性", search = "异乎寻常的皇家烤肉", id = 255847},
    {label = "副属性", search = "勇士便当",           id = 242274},
    {label = "符文",   search = "虚触强化符文",       id = 259085},
    {label = "主大餐", search = "银月城浮华大餐",     id = 255845},
    {label = "副大餐", search = "盛放筵席",           id = 242273},
})

AddCategory("consumable", "其他", {
    {label = "战鼓",   search = "虚触战鼓",             id = 244639},
    {label = "战复",   search = "应急灵魂链接",         id = {248486, 269586}},
    {label = "修理",   search = "自动铁锤",             id = 132514},
    {label = "开锁",   search = "萨拉斯万能钥匙",       id = 260232},
    {label = "银月",   search = "合约：银月宫廷",       id = {245799, 245800}},
    {label = "奇点",   search = "合约：奇点特勤",       id = {245793, 245794}},
    {label = "哈籁提", search = "合约：哈籁提",         id = {245795, 245796}},
    {label = "阿曼尼", search = "合约：阿曼尼部族",     id = {245797, 245798}},
    {label = "轰击弹", search = "配重轰击弹",     id = {257751, 257752}},
    {label = "毒弹", search = "浸毒弹丸",     id = {257749, 257750}},
})

-- ==========================================
-- 数据填充：装备附魔
-- ==========================================
AddCategory("enchant", "附魔:戒指", {
    {label = "暴击", search = "附魔戒指 - 自然之怒",     id = {243986, 243987}},
    {label = "急速", search = "附魔戒指 - 银月城之捷",   id = {244014, 244015}},
    {label = "精通", search = "附魔戒指 - 祖尔金的精通", id = {243958, 243959}},
    {label = "全能", search = "附魔戒指 - 银月城之韧",   id = {244016, 244017}},
    {label = "暴伤", search = "附魔戒指 - 鹰眼神视",     id = {243956, 243957}},
})

AddCategory("enchant", "附魔:武器", {
    {label = "主属性", search = "附魔武器 - 朗多雷之锐",       id = {244028, 244029}},
    {label = "暴击",   search = "附魔武器 - 加亚莱的精准",     id = {243970, 243971}},
    {label = "急速",   search = "附魔武器 - 狂战士之怒",       id = {243972, 243973}},
    {label = "精通",   search = "附魔武器 - 奥术精通",         id = {244030, 244031}},
    {label = "全能",   search = "附魔武器 - 世界之魂的坚韧",   id = {244000, 244001}},
    {label = "护盾",   search = "附魔武器 - 世界之魂的庇护",   id = {243998, 243999}},
    {label = "治疗",   search = "附魔武器 - 世界之魂的摇篮",   id = {243996, 243997}},
    {label = "流血",   search = "附魔武器 - 哈尔拉兹之力",     id = {243968, 243969}},
    {label = "AOE",    search = "附魔武器 - 辛多雷之焰",       id = {244026, 244027}},
})

AddCategory("enchant", "附魔:头盔", {
    {label = "吸血", search = "附魔头盔 - 强化吸血妖术", id = {243950, 243951}},
    {label = "闪避", search = "附魔头盔 - 强化闪避符文", id = {244006, 244007}},
    {label = "加速", search = "附魔头盔 - 强化加速祝福", id = {243980, 243981}},
})

AddCategory("enchant", "附魔:胸甲", {
    {label = "主属性", search = "附魔胸甲 - 世界之魂印记", id = {243976, 243977}},
    {label = "敏捷",   search = "附魔胸甲 - 护根者印记",   id = {243974, 243975}},
    {label = "力耐",   search = "附魔胸甲 - 纳洛拉克印记", id = {243946, 243947}},
    {label = "智法",   search = "附魔胸甲 - 魔导师印记",   id = {244002, 244003}},
})

AddCategory("enchant", "附魔:护肩", {
    {label = "吸血", search = "附魔护肩 - 银月城治愈",     id = {244020, 244021}},
    {label = "闪避", search = "附魔护肩 - 阿梅达希尔之赐", id = {243990, 243991}},
    {label = "加速", search = "附魔护肩 - 埃基尔松的迅捷", id = {243962, 243963}},
})

AddCategory("enchant", "附魔:腿部", {
    {label = "力敏耐", search = "森林猎手的护甲片", id = {244640, 244641}},
    {label = "力敏甲", search = "血骑士的护甲片",   id = {244642, 244643}},
    {label = "智法",   search = "奥纹魔线",         id = {240154, 240155}},
    {label = "智耐",   search = "阳炎丝绸魔线",         id = {240094, 240133}},
})

AddCategory("enchant", "附魔:靴子", {
    {label="闪避耐", search="附魔靴子 - 山猫之敏", id={243952, 243953}},
    {label="吸血耐", search="附魔靴子 - 莎拉达希尔之根", id={243982, 243983}},
    {label="加速耐", search="附魔靴子 - 远行者的狩猎", id={244008, 244009}},
})

AddCategory("enchant", "附魔:工具", {
    {label="产能", search="附魔工具 - 哈籁尼尔产能", id={243994, 243995}},
    {label="感知", search="附魔工具 - 阿曼尼感知", id={243964, 243965}},
})

-- ==========================================
-- 数据填充：公函与宝石
-- ==========================================
AddCategory("gem", "萨拉斯公函", {
    {label = "全 急", search = "曙光之萨拉斯公函", id = {245781, 245782}},
    {label = "急 精", search = "灼光之萨拉斯公函", id = {245783, 245784}},
    {label = "急 暴", search = "燎火之萨拉斯公函", id = {245785, 245786}},
    {label = "暴 精", search = "无双之萨拉斯公函", id = {245789, 245790}},
    {label = "暴 全", search = "快刀之萨拉斯公函", id = {245791, 245792}},
    {label = "全 精", search = "谐律之萨拉斯公函", id = {245787, 245788}},
})

AddCategory("gem", "美化材料", {
    {label = "穿山甲", search = "圣佑穿山甲护符",   id = {244603, 244604}},
    {label = "孢子",   search = "原始孢子缚带",     id = {244607, 244608}},
    {label = "吞噬",   search = "吞噬绑带",         id = {244674, 244675}},
    {label = "鲜血",   search = "暗月徽记：鲜血",   id = {245871, 245872}},
    {label = "狩猎",   search = "暗月徽记：狩猎",   id = {245875, 245876}},
    {label = "腐烂",   search = "暗月徽记：腐烂",   id = {245877, 245878}},
    {label = "虚空",   search = "暗月徽记：虚空",   id = {245873, 245874}},
    {label = "奥纹",   search = "奥纹内衬",   id = {240166, 240167}},
    {label = "阳炎",   search = "阳炎丝绸内衬",   id = {240164, 240165}},
    {label = "幸运",   search = "幸运钥匙串",       id = 248130},
})

AddCategory("gem", "永歌钻石", {
    {label = "主属性", search = "费解之永歌钻石", id = {240982, 240983}},
    {label = "暴伤",   search = "强能之永歌钻石", id = {240966, 240967}},
    {label = "法力",   search = "御土之永歌钻石", id = {240968, 240969}},
    {label = "护甲",   search = "坚韧之永歌钻石", id = {240970, 240971}},
})

AddCategory("gem", "急速/全能宝石", {
    {label = "全能", search = "无瑕万能榄石",   id = {240893, 240894}},
    {label = "精通", search = "无瑕精湛榄石",   id = {240891, 240892}},
    {label = "暴击", search = "无瑕致命榄石",   id = {240889, 240890}},
    {label = "急速", search = "无瑕迅捷青金石", id = {240915, 240916}},
    {label = "暴击", search = "无瑕致命青金石", id = {240913, 240914}},
    {label = "精通", search = "无瑕精湛青金石", id = {240917, 240918}},
})

AddCategory("gem", "暴击/精通宝石", {
    {label = "急速", search = "无瑕迅捷榴石", id = {240905, 240906}},
    {label = "全能", search = "无瑕万能榴石", id = {240909, 240910}},
    {label = "精通", search = "无瑕精湛榴石", id = {240907, 240908}},
    {label = "急速", search = "无瑕迅捷紫晶", id = {240899, 240900}},
    {label = "暴击", search = "无瑕致命紫晶", id = {240897, 240898}},
    {label = "全能", search = "无瑕万能紫晶", id = {240901, 240902}},
})

AddCategory("gem", "工程齿轮", {
    {label = "暴击", search = "通量齿轮", id = {244697, 244698}},
    {label = "急速", search = "滑油齿轮", id = {244699, 244700}},
    {label = "全能", search = "吻合齿轮", id = {244703, 244704}},
    {label = "精通", search = "完美齿轮", id = {244701, 244702}},
})

-- ==========================================
-- 工具函数
-- ==========================================
local function GetItemCountSafe(itemID)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID, false, false, false) or 0
    elseif GetItemCount then
        return GetItemCount(itemID) or 0
    end
    return 0
end

local function GetItemNameSafe(itemID)
    if C_Item and C_Item.GetItemInfo then
        return (select(1, C_Item.GetItemInfo(itemID))) or ("物品" .. tostring(itemID))
    end
    return "物品" .. tostring(itemID)
end

local function GetItemIconSafe(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    if GetItemIcon then
        return GetItemIcon(itemID)
    end
    return nil
end

-- 品质、物品等级（用于 Tooltip 里多 ID 数量颜色区分）
local function GetItemQualitySafe(itemID)
    if C_Item and C_Item.GetItemQualityByID then
        local q = C_Item.GetItemQualityByID(itemID)
        if q ~= nil then return q end
    end
    if GetItemInfo then
        return select(3, GetItemInfo(itemID)) or 0
    end
    return 0
end

local function GetItemLevelSafe(itemID)
    if GetItemInfo then
        return select(4, GetItemInfo(itemID)) or 0
    end
    return 0
end

-- Tooltip 右侧数量：高品质暗金、低品质灰白
local COLOR_TIP_COUNT_HIGH = {0.72, 0.54, 0.18}
local COLOR_TIP_COUNT_LOW  = {0.78, 0.78, 0.82}

-- 在拍卖行的搜索框里填入物品名并触发搜索
local function SearchItem(itemName)
    local ah = AuctionHouseFrame or AuctionFrame
    if not ah or not ah:IsShown() then return end

    if ah.SearchBar and ah.SearchBar.SearchBox then
        ah.SearchBar.SearchBox:SetText(itemName)
        if ah.SearchBar.Search then
            pcall(function() ah.SearchBar:Search() end)
        elseif ah.SearchBar.SearchButton then
            pcall(function() ah.SearchBar.SearchButton:Click() end)
        end
    end
end

-- ==========================================
-- 主框架（使用 ButtonFrameTemplate：自带标题、关闭按钮、肖像、嵌入面板）
-- ==========================================
local frame = CreateFrame("Frame", "QuickAuctionBuyerFrame", UIParent, "ButtonFrameTemplate")
frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
frame:SetPoint("CENTER")
frame:SetFrameStrata("LOW")
frame:Hide()
frame:SetClampedToScreen(true)

-- 拖拽
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

-- 标题（兼容新旧版本：现代 WoW 用 SetTitle，旧版直接写 TitleText）
if frame.SetTitle then
    frame:SetTitle("购物助手")
elseif frame.TitleText then
    frame.TitleText:SetText("购物助手")
elseif _G[frame:GetName() .. "TitleText"] then
    _G[frame:GetName() .. "TitleText"]:SetText("购物助手")
end

-- ==========================================
-- 彻底移除左上角肖像 + 金色圆环
-- ==========================================
local function ScrubElement(r)
    if not r then return end
    if r.SetAlpha then r:SetAlpha(0) end
    if r.SetTexture then pcall(r.SetTexture, r, nil) end
    if r.Hide then r:Hide() end
end

if ButtonFrameTemplate_HidePortrait then
    ButtonFrameTemplate_HidePortrait(frame)
end
if frame.PortraitContainer then
    frame.PortraitContainer:Hide()
    local function ScrubPortraitSubtree(f)
        if not f then return end
        for i = 1, f:GetNumRegions() do
            ScrubElement(select(i, f:GetRegions()))
        end
        for i = 1, f:GetNumChildren() do
            ScrubPortraitSubtree(select(i, f:GetChildren()))
        end
    end
    ScrubPortraitSubtree(frame.PortraitContainer)
end

for _, name in ipairs({
    "PortraitFrame", "portraitFrame", "PortraitFrameBg", "Portrait", "portrait",
}) do
    ScrubElement(frame[name])
end
for i = 1, frame:GetNumRegions() do
    local region = select(i, frame:GetRegions())
    local rname = region.GetName and region:GetName()
    if rname and rname:lower():find("portrait") then
        ScrubElement(region)
    end
end

-- 标题：无肖像后居中顶栏
local titleText = frame.TitleText
    or (frame.TitleContainer and frame.TitleContainer.TitleText)
    or _G[(frame:GetName() or "") .. "TitleText"]
if titleText then
    titleText:ClearAllPoints()
    titleText:SetPoint("TOP", frame, "TOP", 0, -6)
    FontDownOne(titleText)
end

-- Inset：与外层金属框四边等距，并设置拍卖行背景纹理
if frame.Inset then
    frame.Inset:ClearAllPoints()
    frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_INSET_MARGIN, -18)
    frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -FRAME_INSET_MARGIN, FRAME_INSET_MARGIN)
    
    -- 设置拍卖行背景纹理 AuctionHouseFrameBg
    if not frame.Inset.Bg then
        frame.Inset.Bg = frame.Inset:CreateTexture(nil, "BACKGROUND")
        frame.Inset.Bg:SetAllPoints(frame.Inset)
    end
    frame.Inset.Bg:SetTexture("Interface\\AuctionFrame\\AuctionHouseFrameBg")
    frame.Inset.Bg:SetTexCoord(0, 1, 0, 1)
end

-- ==========================================
-- 按钮状态管理
-- ==========================================
local allButtons = {}

local function UpdateButtonState(btn)
    if not btn or not btn.itemIDs then return end

    local total = 0
    for _, itemID in ipairs(btn.itemIDs) do
        total = total + GetItemCountSafe(itemID)
    end

    if total > 0 then
        btn.icon:SetDesaturated(false)
        btn.icon:SetVertexColor(1, 1, 1, 1)
        btn.label:SetTextColor(unpack(COLOR_TEXT_LIGHT))
        btn.Count:SetText(total)
        btn.Count:SetTextColor(unpack(COLOR_COUNT))
        btn.Count:Show()
    else
        btn.icon:SetDesaturated(true)
        btn.icon:SetVertexColor(0.6, 0.6, 0.6, 1)
        btn.label:SetTextColor(unpack(COLOR_TEXT_DIM))
        btn.Count:Hide()
    end
end

local function RefreshAllButtons()
    for _, btn in ipairs(allButtons) do
        UpdateButtonState(btn)
    end
end

-- ==========================================
-- 创建一个图标按钮（手工组装，使用原生纹理与字体对象）
-- 结构：
--   底层暗色衬底 → 图标 → 高亮纹理（OVERLAY ADD） → 按下纹理
--   外圈 1px 暗色细边（让相邻图标视觉分离）
--   右下角数量文字（NumberFontNormal）
--   下方文字标签（GameFontHighlightSmall）
-- ==========================================
local function CreateIconButton(parent, btnData)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(ICON_SIZE, ICON_SIZE)

    -- 整理 itemIDs
    if type(btnData.id) == "table" then
        btn.itemIDs = btnData.id
    elseif btnData.id then
        btn.itemIDs = {btnData.id}
    else
        btn.itemIDs = {}
    end
    btn.searchName = btnData.search

    -- 取第一个有效图标路径
    local iconPath = "Interface\\Icons\\INV_Misc_QuestionMark"
    for _, id in ipairs(btn.itemIDs) do
        local p = GetItemIconSafe(id)
        if p then iconPath = p; break end
    end

    -- 暗色衬底（防止图标出现镂空）
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1)

    -- 图标本体
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(iconPath)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- 裁掉 Blizzard 图标固有的圆角
    btn.icon = icon

    -- 1px 暗色细边（4 条 ColorTexture）
    local function MakeEdge()
        local t = btn:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0, 0, 0, 0.9)
        return t
    end
    local eT, eB, eL, eR = MakeEdge(), MakeEdge(), MakeEdge(), MakeEdge()
    eT:SetPoint("TOPLEFT");     eT:SetPoint("TOPRIGHT");    eT:SetHeight(1)
    eB:SetPoint("BOTTOMLEFT");  eB:SetPoint("BOTTOMRIGHT"); eB:SetHeight(1)
    eL:SetPoint("TOPLEFT");     eL:SetPoint("BOTTOMLEFT");  eL:SetWidth(1)
    eR:SetPoint("TOPRIGHT");    eR:SetPoint("BOTTOMRIGHT"); eR:SetWidth(1)

    -- 鼠标悬停高亮（原生白色高亮纹理 + ADD 混合）
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local hl = btn:GetHighlightTexture()
    if hl then hl:SetAllPoints() end

    -- 按下视觉
    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    local pushed = btn:GetPushedTexture()
    if pushed then pushed:SetAllPoints() end

    -- 数量文字（右下角）
    local count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    count:Hide()
    FontDownOne(count)
    btn.Count = count

    -- 图标下方的标签
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOP", btn, "BOTTOM", 0, -LABEL_GAP)
    label:SetText(btnData.label)
    label:SetTextColor(unpack(COLOR_TEXT_LIGHT))
    FontDownOne(label)
    btn.label = label

    -- 点击：在拍卖行搜索
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function()
        SearchItem(btnData.search)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    -- 鼠标悬停：显示物品名 + 各 ID 在背包数量
    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(btnData.search, 1, 1, 1)
        GameTooltip:AddLine("点击在拍卖行搜索此物品", 0.7, 0.7, 0.7)

        if #self.itemIDs > 1 then
            local rows = {}
            for _, id in ipairs(self.itemIDs) do
                local count = GetItemCountSafe(id)
                if count > 0 then
                    table.insert(rows, {
                        name    = GetItemNameSafe(id),
                        count   = count,
                        quality = GetItemQualitySafe(id),
                        ilvl    = GetItemLevelSafe(id),
                    })
                end
            end
            if #rows > 0 then
                GameTooltip:AddLine(" ")
                local bestIdx = 1
                if #rows > 1 then
                    for i = 2, #rows do
                        if rows[i].quality > rows[bestIdx].quality then
                            bestIdx = i
                        elseif rows[i].quality == rows[bestIdx].quality
                            and rows[i].ilvl > rows[bestIdx].ilvl then
                            bestIdx = i
                        end
                    end
                end
                for i, r in ipairs(rows) do
                    local cr, cg, cb
                    if #rows == 1 then
                        -- 仅一种有货：按该物品品质，稀有及以上算「高」
                        if r.quality >= 3 then
                            cr, cg, cb = unpack(COLOR_TIP_COUNT_HIGH)
                        else
                            cr, cg, cb = unpack(COLOR_TIP_COUNT_LOW)
                        end
                    else
                        if i == bestIdx then
                            cr, cg, cb = unpack(COLOR_TIP_COUNT_HIGH)
                        else
                            cr, cg, cb = unpack(COLOR_TIP_COUNT_LOW)
                        end
                    end
                    -- 名称与数量同色（高品质暗金 / 低品质灰白）
                    GameTooltip:AddDoubleLine(r.name, tostring(r.count), cr, cg, cb, cr, cg, cb)
                end
            end
        end
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", GameTooltip_Hide)

    table.insert(allButtons, btn)
    UpdateButtonState(btn)

    return btn
end

-- ==========================================
-- 子类别标题（金色文字 + 一根细金线分隔）
-- ==========================================
local function CreateSectionHeader(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(SECTION_HEADER_H)

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", f, "LEFT", 0, 0)
    label:SetText(text)
    label:SetTextColor(unpack(COLOR_TEXT_NORMAL))
    FontDownOne(label)

    -- 标题右侧延伸到容器边的金色细分割线（原生 ColorTexture，无外部素材）
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", label, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    line:SetColorTexture(0.6, 0.5, 0.3, 0.6)

    return f
end

-- ==========================================
-- 创建一个 tab 内容滚动区
-- ==========================================
local function CreateScrollContent(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    -- 左/上/底：CONTENT_MARGIN；右：滚动条紧贴黑色内容区右缘（仅让出 SCROLLBAR_WIDTH，无额外右留白）
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTENT_MARGIN, -CONTENT_MARGIN)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, CONTENT_MARGIN)

    -- 滚动条与 sf 右缘 0 间距，整体贴齐 Inset 右侧
    if sf.ScrollBar then
        sf.ScrollBar:ClearAllPoints()
        sf.ScrollBar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 0, -CONTENT_MARGIN)
        sf.ScrollBar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 0, CONTENT_MARGIN)
    end

    local content = CreateFrame("Frame", nil, sf)
    sf:SetScrollChild(content)
    content:SetSize(CONTENT_WIDTH, 10)

    return sf, content
end

-- ==========================================
-- 把一个 tab 的所有子类别铺到 content 中（每行 5 个，自动换行）
-- ==========================================
local function BuildCategoryContent(content, sections)
    local rowStartX = 0
    local y = 0
    local numSections = #sections
    local ITEMS_PER_ROW = 5  -- 每行固定显示 5 个

    for secIdx, section in ipairs(sections) do
        local header = CreateSectionHeader(content, section.title)
        header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        header:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        y = y - SECTION_HEADER_H - SECTION_V_SPACING

        local numButtons = #section.buttons
        local numRows = math.ceil(numButtons / ITEMS_PER_ROW)

        for i, btnData in ipairs(section.buttons) do
            local btn = CreateIconButton(content, btnData)
            local col = (i - 1) % ITEMS_PER_ROW
            local row = math.floor((i - 1) / ITEMS_PER_ROW)
            local x = rowStartX + col * (ICON_SIZE + ICON_HGAP)
            local btnY = y - row * (ICON_SIZE + ICON_VGAP)
            btn:SetPoint("TOPLEFT", content, "TOPLEFT", x, btnY)
        end

        y = y - (numRows * (ICON_SIZE + ICON_VGAP))

        if secIdx < numSections then
            y = y - SECTION_V_SPACING
        end
    end

    content:SetHeight(math.max(10, math.abs(y) + CONTENT_MARGIN))
end

-- ==========================================
-- 构建每个 tab 的内容容器（直接挂在 frame.Inset 上）
-- ==========================================
local tabContents = {}     -- tabIndex -> 容器 Frame
-- Inset 父容器（兼容性兜底）
local insetParent = frame.Inset or frame.inset or frame
do
    for i, info in ipairs(TAB_DEFS) do
        local container = CreateFrame("Frame", nil, insetParent)
        container:SetAllPoints(insetParent)
        container:Hide()

        -- 所有数据 tab（消耗品、装备附魔、公函与宝石）统一使用滚动条
        local _, content = CreateScrollContent(container)
        BuildCategoryContent(content, categoryData[info.key])

        tabContents[i] = container
    end
end

-- ==========================================
-- 底部 Tab 按钮（原生 PanelTabButtonTemplate）
-- ==========================================
local function ShowTab(tabID)
    PanelTemplates_SetTab(frame, tabID)
    for i, c in ipairs(tabContents) do
        if i == tabID then c:Show() else c:Hide() end
    end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

local prevTab
for i, info in ipairs(TAB_DEFS) do
    local tab = CreateFrame("Button", "QuickAuctionBuyerFrameTab" .. i, frame, "PanelTabButtonTemplate")
    tab:SetID(i)
    tab:SetText(info.name)
    -- PanelTemplates_TabResize(tab, padding, absoluteSize, minWidth, maxWidth, absoluteTextSize)
    -- padding=24 给中文留够呼吸空间；minWidth=64 防止短词标签太挤
    PanelTemplates_TabResize(tab, 24, nil, 64)
    tab:SetScript("OnClick", function(self)
        ShowTab(self:GetID())
    end)
    local tabFs = tab.Text or tab.FontString
    if tabFs then FontDownOne(tabFs) end

    if i == 1 then
        tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 6, 2)
    else
        -- PanelTabButtonTemplate 自带 ~16px 透明端帽，所以用 +4 让相邻 tab 视觉间隔约 4px
        tab:SetPoint("LEFT", prevTab, "RIGHT", 4, 0)
    end
    prevTab = tab
end

frame.numTabs = #TAB_DEFS
ShowTab(1)

-- ==========================================
-- 最小化图标（关闭主框架后停在拍卖行右侧）
-- ==========================================
local minimizeIcon = CreateFrame("Button", "QuickAuctionBuyerMinimizeIcon", UIParent)
minimizeIcon:SetSize(40, 40)
minimizeIcon:SetFrameStrata("HIGH")
minimizeIcon:Hide()

local miBg = minimizeIcon:CreateTexture(nil, "BACKGROUND")
miBg:SetAllPoints()
miBg:SetColorTexture(0, 0, 0, 1)

local miIcon = minimizeIcon:CreateTexture(nil, "ARTWORK")
miIcon:SetPoint("TOPLEFT", 1, -1)
miIcon:SetPoint("BOTTOMRIGHT", -1, 1)
miIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
miIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

-- 1px 暗色细边
for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
    local t = minimizeIcon:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0, 0, 0, 1)
    if side == "TOP" or side == "BOTTOM" then
        t:SetHeight(1)
        t:SetPoint(side .. "LEFT")
        t:SetPoint(side .. "RIGHT")
    else
        t:SetWidth(1)
        t:SetPoint("TOP" .. side)
        t:SetPoint("BOTTOM" .. side)
    end
end

minimizeIcon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
local miHL = minimizeIcon:GetHighlightTexture()
if miHL then miHL:SetAllPoints() end

minimizeIcon:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("购物助手", 1, 1, 1)
    GameTooltip:AddLine("点击展开", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
minimizeIcon:HookScript("OnLeave", GameTooltip_Hide)

-- ==========================================
-- 拍卖行联动 / 事件
-- ==========================================
local isMinimized = false

local function PositionByAuctionHouse()
    local ah = AuctionHouseFrame or AuctionFrame
    if not ah then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", ah, "TOPRIGHT", 0, 0)--lnui，主界面位置
    minimizeIcon:ClearAllPoints()
    minimizeIcon:SetPoint("TOPLEFT", ah, "TOPRIGHT", 5, -2)
end

local function ShowMain()
    isMinimized = false
    minimizeIcon:Hide()
    PositionByAuctionHouse()
    frame:Show()
end

local function ShowMinimized()
    isMinimized = true
    frame:Hide()
    PositionByAuctionHouse()
    minimizeIcon:Show()
end

local function HideAll()
    frame:Hide()
    minimizeIcon:Hide()
end

-- 关闭按钮：缩小成图标而不是真正关闭
if frame.CloseButton then
    frame.CloseButton:SetScript("OnClick", function()
        ShowMinimized()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    end)
end

minimizeIcon:SetScript("OnClick", function()
    ShowMain()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
end)

frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event)
    if event == "AUCTION_HOUSE_SHOW" then
        if isMinimized then
            ShowMinimized()
        else
            ShowMain()
        end
        RefreshAllButtons()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        HideAll()
    elseif event == "BAG_UPDATE" then
        RefreshAllButtons()
    elseif event == "PLAYER_LOGIN" then
        RefreshAllButtons()
    end
end)

-- 实时跟踪：拍卖行存在但插件被隐藏过时自动恢复，拍卖行关闭后兜底
local watcher = CreateFrame("Frame")
watcher.elapsed = 0
watcher:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 1.0 then return end
    self.elapsed = 0

    local ah = AuctionHouseFrame or AuctionFrame
    if ah and ah:IsShown() then
        if not frame:IsShown() and not minimizeIcon:IsShown() then
            if isMinimized then ShowMinimized() else ShowMain() end
        end
    else
        HideAll()
    end
end)

-- ==========================================
-- 斜杠命令
-- ==========================================
SLASH_QUICKAUCTION1 = "/qa"
SlashCmdList["QUICKAUCTION"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "show" then
        ShowMain()
    elseif msg == "hide" then
        HideAll()
    else
        print("|cffffff00[购物助手]|r 命令列表：")
        print("  /qa show  - 显示窗口")
        print("  /qa hide  - 隐藏窗口")
    end
end

end
