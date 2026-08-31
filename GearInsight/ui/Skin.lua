-- Skin.lua — 界面换肤收口模块（0.36）。
-- 三态设计：
--   ElvUI 已加载 → 走 ElvUI 官方 Skins API 自动接管（按钮/边框/关闭钮/滚动条
--                  全部跟随用户 ElvUI 主题，与 Details/DBM 被接管后观感一致）；
--   未加载       → 默认暴雪原生，零变化；
--   （预留）/gi skin 自带扁平主题，后续迭代在本模块内实现。
--
-- 接入方式：不在 30+ 个控件创建点逐一埋调用，而是 Sweep(frame) 递归扫描子树，
-- 按特征识别需要换肤的对象（幂等，_giSkinned 标记防重复），各弹窗 Show 前扫一遍。
-- 动态创建的行内按钮（前5等）在下一次刷新/打开时被扫到。
-- 所有操作 pcall 包裹：换肤失败绝不阻断功能。

GearInsight = GearInsight or {}
local Skin = {}

-- ── ElvUI 探测（惰性，调用时解析；不依赖加载顺序）──────────────────
local function elv()
    if not ElvUI then return nil end
    local ok, E = pcall(unpack, ElvUI)
    if not ok or not E or not E.GetModule then return nil end
    local ok2, S = pcall(E.GetModule, E, "Skins", true)
    return ok2 and S or nil
end

function Skin.Active()
    return elv() ~= nil
end

-- ── 单对象换肤 ──────────────────────────────────────────────────────
-- UIPanelButtonTemplate 按钮：三段纹理键 旧版 Left/Middle/Right，
-- 10.0+ 改为 Left/Center/Right（RedButton atlas 切片）——两代键名都认，
-- 只认 Middle 会导致 12.x 上所有按钮漏 skin（0.37 玩家反馈红色原生按钮）。
local function isPanelButton(o)
    return o:IsObjectType("Button") and o.Left and o.Right and (o.Middle or o.Center)
end

-- UIPanelCloseButton：normal 纹理是 RedButton 系 atlas（10.x+）或旧版关闭钮纹理
local function isCloseButton(o)
    if not o:IsObjectType("Button") then return false end
    local nt = o.GetNormalTexture and o:GetNormalTexture()
    if not nt then return false end
    local atlas = nt.GetAtlas and nt:GetAtlas()
    if atlas and atlas:find("RedButton") then return true end
    local tex = nt.GetTextureFilePath and nt:GetTextureFilePath()
    return type(tex) == "string" and tex:lower():find("closebutton") ~= nil
end

local function skinButton(S, o)
    if o._giSkinned then return end
    o._giSkinned = true
    pcall(S.HandleButton, S, o)
end

local function skinClose(S, o)
    if o._giSkinned then return end
    o._giSkinned = true
    pcall(S.HandleCloseButton, S, o)
end

local function skinScroll(S, o)
    local bar = o.ScrollBar or o.scrollbar
    if not bar or bar._giSkinned then return end
    bar._giSkinned = true
    pcall(S.HandleScrollBar, S, bar)
end

-- 雕花边框容器：有 UI-DialogBox-Border 系 backdrop → 换 ElvUI Transparent 模板，
-- 并把自绘的全幅 BACKGROUND 底色透明化（让 ElvUI 半透明底接管）
local function skinDialog(S, o)
    if o._giSkinned then return end
    if not (o.GetBackdrop and o.SetBackdrop) then return end
    local bd = o:GetBackdrop()
    if not (bd and bd.edgeFile and bd.edgeFile:find("DialogBox")) then return end
    o._giSkinned = true
    pcall(function()
        -- 自绘底色：BACKGROUND 层、铺满整个框体的纯色纹理 → 透明化
        for _, r in ipairs({ o:GetRegions() }) do
            if r:IsObjectType("Texture") and r:GetDrawLayer() == "BACKGROUND" then
                local w, h = r:GetSize()
                local fw, fh = o:GetSize()
                if w >= fw - 2 and h >= fh - 2 then r:SetColorTexture(0, 0, 0, 0) end
            end
        end
        o:SetBackdrop(nil)
        if o.SetTemplate then o:SetTemplate("Transparent") end
    end)
end

-- ── 递归扫描 ────────────────────────────────────────────────────────
local function sweep(S, o, depth)
    if depth > 8 or not o or o._giSweepGuard then return end
    if isCloseButton(o) then
        skinClose(S, o)
    elseif isPanelButton(o) then
        skinButton(S, o)
    elseif o:IsObjectType("ScrollFrame") then
        skinScroll(S, o)
        skinDialog(S, o)
    else
        skinDialog(S, o)
    end
    for _, child in ipairs({ o:GetChildren() }) do
        sweep(S, child, depth + 1)
    end
end

-- 对外入口：弹窗/面板 Show 前调一次。无 ElvUI 时是空操作。
function Skin.Sweep(frame)
    if not frame then return end
    local S = elv()
    if not S then return end
    pcall(sweep, S, frame, 1)
end

GearInsight.Skin = Skin
