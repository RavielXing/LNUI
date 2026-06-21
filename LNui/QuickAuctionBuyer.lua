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
-- 数据
-- ==========================================

local DATA = {
    {
        name = "增益",
        bgColor = "CC6600",
        rows = {
            {
                { id = {241320, 241321}, tag = "全能" },
                { id = {241326, 241327}, tag = "爆击" },
                { id = {241322, 241323}, tag = "精通" },
                { id = {241324, 241325}, tag = "急速" },
                { id = {259085}, tag = "符文" },
            },
            {
                { id = {243735, 243736}, tag = "治疗" },
                { id = {243733, 243734}, tag = "属性" },
                { id = {243737, 243738}, tag = "伤害" },
                { id = {237367, 237369}, tag = "钝器" },
                { id = {237370, 237371}, tag = "利刃" },
                { id = {245879, 245880}, tag = "团本"  },
            }
        }
    },
    {
        name = "食物",
        bgColor = "339933",
        rows = {
            {
                { id = 255845, tag = "主属" },
                { id = 255846, tag = "主属" },
                { id = 242272, tag = "副属" },
                { id = 242273, tag = "副属" },
            },
            {
                { id = 242275, tag = "主属" },
                { id = 255848, tag = "副属" },
                { id = 242274, tag = "副属" },
                { id = 242277, tag = "急速" },
                { id = 242286, tag = "急速" },
                { id = 242278, tag = "爆击" },
                { id = 242283, tag = "爆击" },
                { id = 242287, tag = "爆击" },
            },
            {
                { id = 242276, tag = "全能" },
                { id = 242280, tag = "全能" },
                { id = 242284, tag = "全能" },
                { id = 242281, tag = "精通" },
                { id = 242285, tag = "精通" },
                { id = 242299, tag = "加速" },
                { id = 242298, tag = "加速" },
                { id = 242289, tag = "肉柳" },
            }
        }
    },
    {
        name = "药水",
        bgColor = "8E44AD",
        rows = {
            {
                { id = { 241308, 241309 }, tag = "主属" },
                { id = { 241288, 241289 }, tag = "副属" },
                { id = { 241296, 241297 }, tag = "伤害" },
                { id = { 241286, 241287 }, tag = "护盾" },
                { id = { 241292, 241293 }, tag = "智力" },
                { id = { 241302, 241303 }, tag = "隐形" },
            },
            {
                { id = { 241304, 241305 }, tag = "生命"},
                { id = 241299, tag = "生命" },
                { id = { 241300, 241301 }, tag = "法力" },
                { id = { 241294, 241295 }, tag = "法力" },
                { id = { 241306, 241307 }, tag = "血清" },
                { id = { 241338, 241339 }, tag = "缓落" },
            }
        }
    },
    {
        name = "钻石",
        bgColor = "2266AA",
        rows = {
            {
                { id = {240968, 240969}, tag = "法力" },
                { id = {240970, 240971}, tag = "护甲" },
                { id = {240966, 240967}, tag = "爆效" },
                { id = {240982, 240983}, tag = "主属" },
            }
        }
    },
    {
        name = "血石",
        bgColor = "CC3333",
        rows = {
            {
                { id = 241142, tag = "决心" },
                { id = 241143, tag = "感知" },
                { id = 241144, tag = "坚韧" },
            }
        }
    },
    {
        name = "高级宝石",
        bgColor = "CC6600",
        rows = {
            { 
                { id = {240903,240904}, tag = "爆击" },
                { id = {240907,240908}, tag = "爆精" },
                { id = {240905,240906}, tag = "爆急" },
                { id = {240909,240910}, tag = "爆全" },
                { id = {240895,240896}, tag = "精通" },
                { id = {240897,240898}, tag = "精爆" },
                { id = {240899,240900}, tag = "精急" },
                { id = {240901,240902}, tag = "精全" },
            },
            { 
                { id = {240887,240888}, tag = "急速" },
                { id = {240889,240890}, tag = "急爆" },
                { id = {240891,240892}, tag = "急精" },
                { id = {240893,240894}, tag = "急全" },
                { id = {240911,240912}, tag = "全能" },
                { id = {240913,240914}, tag = "全爆" },
                { id = {240917,240918}, tag = "全精" },
                { id = {240915,240916}, tag = "全急" },
            },
        }
    },
    {
        name = "初级宝石",
        bgColor = "339933",
        rows = {
            { 
                { id = {240871,240872}, tag = "爆击" },
                { id = {240875,240876}, tag = "爆精" },
                { id = {240873,240874}, tag = "爆急" },
                { id = {240877,240878}, tag = "爆全" },
                { id = {240863,240864}, tag = "精通" },
                { id = {240865,240866}, tag = "精爆" },
                { id = {240867,240868}, tag = "精急" },
                { id = {240869,240870}, tag = "精全" },
            },
            { 
                { id = {240855,240856}, tag = "急速" },
                { id = {240857,240858}, tag = "急爆" },
                { id = {240859,240860}, tag = "急精" },
                { id = {240861,240862}, tag = "急全" },
                { id = {240879,240880}, tag = "全能" },
                { id = {240881,240882}, tag = "全爆" },
                { id = {240885,240886}, tag = "全精" },
                { id = {240883,240884}, tag = "全急" },
            },
        }
    },
    {
        name = "附魔 - 武器",
        bgColor = "9933CC",
        rows = {
            {
                { id = {244028, 244029}, tag = "主属" },
                { id = {243970, 243971}, tag = "爆击" },
                { id = {244030, 244031}, tag = "精通" },
                { id = {243972, 243973}, tag = "急速" },
                { id = {244001, 244000}, tag = "全能" },
                { id = {243998, 243999}, tag = "承伤" },
                { id = {243996, 243997}, tag = "治疗" },
                { id = {243968, 243969}, tag = "流血"  },
            },
            {
                { id = {244026, 244027}, tag = "火焰" },
                { id = {257745, 257746}, tag = "鹰眼" },
                { id = {257747, 257748}, tag = "猫眼" },
                { id = {257749, 257750}, tag = "毒弹" },
                { id = {257751, 257752}, tag = "轰弹" },
            }
        }
    },
    {
        name = "附魔 - 头盔",
        bgColor = "9933CC",
        rows = {
            {
                { id = {243980, 243981}, tag = "加速" },
                { id = {243950, 243951}, tag = "吸血" },
                { id = {244006, 244007}, tag = "闪避" },
                { id = {243978, 243979}, tag = "加速" },
                { id = {243948, 243949}, tag = "吸血" },
                { id = {244004, 244005}, tag = "闪避" },
            }
        }
    },
    {
        name = "附魔 - 护肩",
        bgColor = "9933CC",
        rows = {
            {
                { id = {243962, 243963}, tag = "加速" },
                { id = {244020, 244021}, tag = "吸血" },
                { id = {243990, 243991}, tag = "闪避" },
                { id = {243960, 243961}, tag = "加速" },
                { id = {244018, 244019}, tag = "吸血" },
                { id = {243988, 243989}, tag = "闪避" },
            }
        }
    },
    {
        name = "附魔 - 胸甲",
        bgColor = "9933CC",
        rows = {
            {
                { id = {243976, 243977}, tag = "主属" },
                { id = {243974, 243975}, tag = "敏捷" },
                { id = {243946, 243947}, tag = "力量" },
                { id = {244002, 244003}, tag = "智力" },
            }
        }
    },
    {
        name = "附魔 - 腿甲",
        bgColor = "9933CC",
        rows = {
            {
                { id = {244642, 244643}, tag = "护甲" },
                { id = {244640, 244641}, tag = "耐力" },
                { id = {244644, 244645}, tag = "弱效" },
                { id = {240154, 240155}, tag = "法力" },
                { id = {240094, 240095}, tag = "耐力" },
                { id = {240156, 240157}, tag = "弱效" },
            }
        }
    },
    {
        name = "附魔 - 靴子",
        bgColor = "9933CC",
        rows = {
            {
                { id = {244008, 244009}, tag = "加速" },
                { id = {243982, 243983}, tag = "吸血" },
                { id = {243952, 243953}, tag = "闪避" },
            }
        }
    },
    {
        name = "附魔 - 戒指",
        bgColor = "9933CC",
        rows = {
            {
                { id = {243986, 243987}, tag = "爆击" },
                { id = {243958, 243959}, tag = "精通" },
                { id = {244014, 244015}, tag = "急速" },
                { id = {244016, 244017}, tag = "全能" },
                { id = {243956, 243957}, tag = "爆效" },
            },
            {
                { id = {243984, 243985}, tag = "爆击" },
                { id = {243954, 243955}, tag = "精通" },
                { id = {244010, 244011}, tag = "急速" },
                { id = {244012, 244013}, tag = "全能" },
            }
        }
    },
    {
        name = "附魔 - 工具",
        bgColor = "9933CC",
        rows = {
            {
                { id = {244024, 244025}, tag = "奇思" },
                { id = {243966, 243967}, tag = "充裕" },
                { id = {243994, 243995}, tag = "产能" },
                { id = {243964, 243965}, tag = "感知" },
                { id = {244022, 244023}, tag = "熟练" },
                { id = {243992, 243993}, tag = "精细" },
            }
        }
    },
    {
        name = "其他",
        bgColor = "607D8B",
        rows = {
            {
                { id = 219905, tag = "嗜血" },
                { id = {248486, 269586}, tag = "战复" },
                { id = 132514, tag = "修理" },
                { id = 260232, tag = "钥匙"},
                { id = {245799, 245800}, tag = "银月" },
                { id = {245793, 245794}, tag = "奇点"},
                { id = {245795, 245796}, tag = "哈籁" },
                { id = {245797, 245798}, tag = "阿曼" },
            }
        }
    },
    {
        name = "公函 - 武器护甲",
        bgColor = "339933",
        rows = {
            {
                { id = {245789, 245790}, tag = "爆精" },
                { id = {245785, 245786}, tag = "爆急" },
                { id = {245791, 245792}, tag = "爆全" },
                { id = {245783, 245784}, tag = "急精" },
                { id = {245781, 245782}, tag = "急全" },
                { id = {245787, 245788}, tag = "精全" },
            }
        }
    },
    {
        name = "公函 - 专业工具",
        bgColor = "008B8B",
        rows = {
            {
                { id = {245820, 245821}, tag = "速度" },
                { id = {245818, 245819}, tag = "产能" },
                { id = {245814, 245815}, tag = "奇思" },
                { id = {245826, 245827}, tag = "熟练" },
                { id = {245816, 245817}, tag = "充裕" },
                { id = {245824, 245825}, tag = "感知" },
                { id = {245822, 245823}, tag = "精细" },
            }
        }
    },
    {
        name = "美化材料",
        bgColor = "8E44AD",
        rows = {
            {
                { id = {244603, 244604}, tag = "穿山" },
                { id = {244607, 244608}, tag = "孢子" },
                { id = {244674, 244675}, tag = "吞噬" },
                { id = {240166, 240167}, tag = "奥纹" },
                { id = {240164, 240165}, tag = "阳炎" },
            },
            {
                { id = {245871, 245872}, tag = "鲜血" },
                { id = {245875, 245876}, tag = "狩猎" },
                { id = {245877, 245878}, tag = "腐烂" },
                { id = {245873, 245874}, tag = "虚空" },
                { id = {248130}, tag = "清除" },
            }
        }
    },
    {
        name = "工程齿轮",
        bgColor = "2266AA",
        rows = {
            {
                { id = {244697, 244698}, tag = "爆击" },
                { id = {244699, 244700}, tag = "急速" },
                { id = {244703, 244704}, tag = "全能" },
                { id = {244701, 244702}, tag = "精通" },
            }
        }
    },
}

local TABS = {
    { name = "消耗品", categories = {"增益", "食物", "药水", "其他"} },
    { name = "宝石", categories = {"钻石", "血石", "高级宝石", "初级宝石"} },
    { name = "附魔", categories = {"附魔 - 武器", "附魔 - 头盔", "附魔 - 护肩", "附魔 - 胸甲", "附魔 - 腿甲", "附魔 - 靴子", "附魔 - 戒指", "附魔 - 工具"} },
    { name = "制造", categories = {"公函 - 武器护甲", "公函 - 专业工具", "美化材料", "工程齿轮"} },
}

-- 按 tab 组织的数据缓存
local tabData = {}

-- 构建 tabData：将 DATA 中的分类按 TABS 重组
for _, tabInfo in ipairs(TABS) do
    local sections = {}
    for _, catName in ipairs(tabInfo.categories) do
        for _, d in ipairs(DATA) do
            if d.name == catName then
                table.insert(sections, d)
                break
            end
        end
    end
    tabData[tabInfo.name] = sections
end

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

-- 获取物品名称用于搜索
local function GetItemSearchName(itemID)
    if C_Item and C_Item.GetItemInfo then
        local name = C_Item.GetItemInfo(itemID)
        if name then return name end
    end
    if GetItemInfo then
        local name = select(1, GetItemInfo(itemID))
        if name then return name end
    end
    return nil
end

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
    frame.Inset.Bg:SetTexture("Interface\AuctionFrame\AuctionHouseFrameBg")
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
local function CreateIconButton(parent, itemData)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(ICON_SIZE, ICON_SIZE)

    -- 整理 itemIDs
    local itemIDs
    if type(itemData.id) == "table" then
        itemIDs = itemData.id
    elseif itemData.id then
        itemIDs = {itemData.id}
    else
        itemIDs = {}
    end
    btn.itemIDs = itemIDs
    btn.tag = itemData.tag or ""

    -- 取第一个有效图标路径
    local iconPath = "Interface\Icons\INV_Misc_QuestionMark"
    for _, id in ipairs(itemIDs) do
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
    btn:SetHighlightTexture("Interface\Buttons\ButtonHilight-Square", "ADD")
    local hl = btn:GetHighlightTexture()
    if hl then hl:SetAllPoints() end

    -- 按下视觉
    btn:SetPushedTexture("Interface\Buttons\UI-Quickslot-Depress")
    local pushed = btn:GetPushedTexture()
    if pushed then pushed:SetAllPoints() end

    -- 数量文字（右下角）
    local count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    count:Hide()
    FontDownOne(count)
    btn.Count = count

    -- 图标下方的标签（使用 tag 作为标签文字）
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOP", btn, "BOTTOM", 0, -LABEL_GAP)
    label:SetText(itemData.tag or "")
    label:SetTextColor(unpack(COLOR_TEXT_LIGHT))
    FontDownOne(label)
    btn.label = label

    -- 点击：在拍卖行搜索（使用第一个有效物品名称）
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function()
        local searchName = nil
        for _, id in ipairs(itemIDs) do
            searchName = GetItemSearchName(id)
            if searchName then break end
        end
        if searchName then
            SearchItem(searchName)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)

    -- 鼠标悬停：显示物品名 + 各 ID 在背包数量
    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        -- 显示第一个有效物品的名称，或 tag
        local firstName = nil
        for _, id in ipairs(self.itemIDs) do
            firstName = GetItemSearchName(id)
            if firstName then break end
        end
        GameTooltip:SetText(firstName or self.tag, 1, 1, 1)
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
        local header = CreateSectionHeader(content, section.name)
        header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        header:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        y = y - SECTION_HEADER_H - SECTION_V_SPACING

        for _, row in ipairs(section.rows) do
            local numButtons = #row
            local numRows = math.ceil(numButtons / ITEMS_PER_ROW)

            for i, item in ipairs(row) do
                local btn = CreateIconButton(content, item)
                local col = (i - 1) % ITEMS_PER_ROW
                local rowNum = math.floor((i - 1) / ITEMS_PER_ROW)
                local x = rowStartX + col * (ICON_SIZE + ICON_HGAP)
                local btnY = y - rowNum * (ICON_SIZE + ICON_VGAP)
                btn:SetPoint("TOPLEFT", content, "TOPLEFT", x, btnY)
            end

            y = y - (numRows * (ICON_SIZE + ICON_VGAP))
        end

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
local TAB_DEFS = TABS      -- 兼容旧代码

-- Inset 父容器（兼容性兜底）
local insetParent = frame.Inset or frame.inset or frame
do
    for i, info in ipairs(TAB_DEFS) do
        local container = CreateFrame("Frame", nil, insetParent)
        container:SetAllPoints(insetParent)
        container:Hide()

        local _, content = CreateScrollContent(container)
        BuildCategoryContent(content, tabData[info.name])

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
miIcon:SetTexture("Interface\Icons\INV_Misc_Coin_01")
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

minimizeIcon:SetHighlightTexture("Interface\Buttons\ButtonHilight-Square", "ADD")
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
    frame:SetPoint("TOPLEFT", ah, "TOPRIGHT", 0, 0)
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
-- SLASH_QUICKAUCTION1 = "/qa"
-- SlashCmdList["QUICKAUCTION"] = function(msg)
    -- msg = (msg or ""):lower()
    -- if msg == "show" then
        -- ShowMain()
    -- elseif msg == "hide" then
        -- HideAll()
    -- else
        -- print("|cffffff00[购物助手]|r 命令列表：")
        -- print("  /qa show  - 显示窗口")
        -- print("  /qa hide  - 隐藏窗口")
    -- end
-- end

end
