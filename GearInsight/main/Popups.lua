-- GearInsight/main/Popups.lua — 子窗口停靠 / ESC 关闭 / 复制弹窗 / 重载提示
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T = H.T

-- ── 子窗口默认停靠 ──────────────────────────────────────────────
-- 按钮弹出的子窗口默认停靠在主面板右侧，不再叠在主面板正中（省得每次手动拖开）。
-- 只在创建时调用：玩家拖动过(StartMoving 会重锚到 UIParent)后，本次会话保持拖动位置。
-- 主面板隐藏/不存在时回退屏幕居中。SetClampedToScreen 防止主面板靠屏幕右缘时弹出屏外。
function GearInsight:AnchorPopup(f)
    f:SetClampedToScreen(true)
    -- ⛔ 玩家自己拖过就不再接管，否则每次弹出都把他摆好的位置拽回去。
    if f._giUserMoved then return end
    f:ClearAllPoints()
    local p = _G["GearInsightPanelFrame"]
    if p and p:IsShown() then
        f:SetPoint("TOPLEFT", p, "TOPRIGHT", 6, 0)
    else
        f:SetPoint("CENTER")
    end
end

-- ⭐ 2026-08-29：子窗口是**复用**的 frame，AnchorPopup 原来只在创建时跑一次，
-- 于是两种情况下它会永久压在主面板上：
--   ① 第一次弹出时主面板没开 → 落屏幕正中 → 之后一直在那；
--   ② 玩家拖过一次（StartMoving 重锚到 UIParent）→ 脱离面板。
-- 现在改成每次 Show 重新停靠；玩家真拖过的用 _giUserMoved 记住，不再动它。
function GearInsight:HookPopupReanchor(f)
    if f._giReanchorHooked then return end
    f._giReanchorHooked = true
    f:HookScript("OnShow", function(self) GearInsight:AnchorPopup(self) end)
end

-- ── ESC 关闭窗口 ────────────────────────────────────────────────
-- 走 WoW 标准 UISpecialFrames 机制：ESC 按下时游戏自动 Hide 最上层已显示的注册窗口
-- （多层弹窗按 ESC 逐层关闭，全关完才弹游戏菜单）。
-- 匿名 frame 注册到 _G 起全局名；同名重复注册只覆盖 _G 引用不重复进表
-- （ShowExportDialog 等每次新建 frame 的场景靠固定 name 防 UISpecialFrames 无限膨胀）。
-- 注意：战斗 HUD（LiveGuide 卡片/读条高亮/嗜血条）不要注册，ESC 不应关 HUD。
local _escRegistered = {}
function GearInsight:RegisterEscClose(frame, name)
    if not frame then return end
    local gname = frame:GetName() or name
    if not gname then return end
    _G[gname] = frame
    if not _escRegistered[gname] then
        _escRegistered[gname] = true
        tinsert(UISpecialFrames, gname)
    end
end

-- ── Copy popup (consumable name → paste into Auction House search) ───
-- WoW addons can't write the OS clipboard directly; the standard pattern is a
-- highlighted EditBox the player copies with Ctrl+C, then pastes into the AH.
-- ⭐ 提示文字换行后多出来的高度。中文提示基本就一行，英文/德文常常两三行；
-- 弹窗高度写死 130/210 就会把文字顶出去。这里把超出一行的部分补回去。
function GearInsight:_HintExtra(f)
    local h = f and f._hint
    if not h or not h:IsShown() then return 0 end
    local _, size = h:GetFont()
    local one = size or 12
    local extra = (h:GetStringHeight() or one) - one
    return math.max(0, math.floor(extra + 0.5))
end

-- extra = { label=, onClick= }：串下面再加一个动作按钮（键位页导出 MySlot 串 → 「打开 MySlot」，用户 2026-09-18）
function GearInsight:ShowCopyText(text, hint, title, name, build, extra)
    -- 同内容再点一次 = 关闭（导出装备等按钮第二次点击收起）；内容变了则原位刷新。
    local fc = self._copyFrame
    if fc and fc:IsShown() and fc._txt == text then fc:Hide(); return end
    local f = self._copyFrame
    if not f then
        f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightCopyFrame")
        f:SetSize(600, 130); GearInsight:AnchorPopup(f); GearInsight:HookPopupReanchor(f)
        f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(50)
        f:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.95)
        local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.08, 0.97)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f._giUserMoved = true end)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -14)
        f._title = title
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4); cb:SetScript("OnClick", function() f:Hide() end)
        local edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        edit:SetSize(540, 24); edit:SetPoint("TOP", 0, -46); edit:SetAutoFocus(true)
        edit:SetFontObject("GameFontHighlightSmall")
        edit:SetScript("OnEscapePressed", function(s) s:ClearFocus(); f:Hide() end)
        edit:SetScript("OnEnterPressed", function(s) s:HighlightText() end)
        -- Keep it read-only-ish: restore the text if the user edits it.
        edit:SetScript("OnTextChanged", function(s, userInput)
            if userInput and s:GetText() ~= f._txt then s:SetText(f._txt); s:HighlightText() end
        end)
        f._edit = edit
        -- 第二个可复制框：载入档命名(导入后给天赋配置命名用)
        local nlbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nlbl:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", 0, -12); nlbl:SetText(T("COPY_NAME_LABEL", "命名"))
        f._nameLbl = nlbl
        local nedit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        nedit:SetSize(540, 24); nedit:SetPoint("TOPLEFT", nlbl, "BOTTOMLEFT", 4, -6); nedit:SetAutoFocus(false)
        nedit:SetFontObject("GameFontHighlightSmall")
        nedit:SetScript("OnEscapePressed", function(s) s:ClearFocus(); f:Hide() end)
        nedit:SetScript("OnEnterPressed", function(s) s:HighlightText() end)
        nedit:SetScript("OnEditFocusGained", function(s) s:SetCursorPosition(0); s:HighlightText() end)
        nedit:SetScript("OnTextChanged", function(s, userInput)
            if userInput and s:GetText() ~= f._name then s:SetText(f._name); s:HighlightText() end
        end)
        f._nameEdit = nedit
        local h = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        h:SetWidth(540); h:SetJustifyH("CENTER")
        h:SetWordWrap(true); h:SetMaxLines(3)   -- ⛔ 英文/德文提示比中文长很多，不开换行会顶出弹窗
        f._hint = h
        -- 一键导入按钮(仅天赋模式显示)：走 UI 级 ImportLoadout(用户拍板恢复,
        -- 见 TalentExport.lua 风险注释)，失败降级为"打开面板手动粘贴导入"。
        local imp = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        imp:SetSize(170, 24); imp:SetText(T("TALENT_IMPORT_BTN", "一键导入天赋"))
        imp:SetScript("OnClick", function()
            local ok, msg = GearInsight_TryImportTalents(f._txt, f._name, function(okA, msgA)
                if okA then GearInsight:Print(string.format(T("TALENT_APPLY_DONE", "天赋已应用：%s"), msgA or "?"))
                else GearInsight:Print(T("TALENT_APPLY_FAIL", "天赋未自动应用：") .. (msgA or "?")) end
            end)
            if ok then
                GearInsight:Print(string.format(T("TALENT_IMPORT_OK2", "已导入「%s」，正在自动应用…"), msg or "?"))
                if GearInsight.RefreshClearLoadoutsButton then C_Timer.After(0.5, function() GearInsight:RefreshClearLoadoutsButton() end) end
                f:Hide(); return
            end
            GearInsight:Print(T("TALENT_IMPORT_FAIL", "导入失败：") .. (msg or "?")
                .. T("TALENT_APPLY_FALLBACK", "，已转手动导入"))
            -- 降级：打开天赋面板，玩家 Ctrl+V 手动导入
            local ok2 = GearInsight_OpenTalentImport(f._txt)
            if ok2 then
                GearInsight:Print(T("TALENT_IMPORT_OK", "天赋面板已打开：左下「载入档」→「导入」→ Ctrl+V 粘贴（串没复制就回本窗口 Ctrl+C）"))
            end
        end)
        f._impBtn = imp
        -- 查看天赋树（用户 2026-09-11「像网页版本一样，把天赋预览图形页面做出来」）：ui/TalentTreeView.lua
        local tv = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        tv:SetSize(130, 24); tv:SetText(T("TV_OPEN_BTN", "查看天赋树"))
        tv:SetScript("OnClick", function()
            if GearInsight.ShowTalentTree then GearInsight:ShowTalentTree(f._txt, f._title:GetText(), f._name) end
        end)
        f._treeBtn = tv
        -- 查看装备（用户 2026-09-24「先出这个吧，然后可以多个按钮查看装备」）：天赋库传 build.showGear 才显示
        local gb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        gb:SetSize(110, 24); gb:SetText(T("TPG_GEAR_BTN", "查看装备")); gb:Hide()
        gb:SetScript("OnClick", function() if f._build and f._build.showGear then f._build.showGear(f) end end)
        f._gearBtn = gb
        local xb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        xb:SetSize(170, 24); xb:Hide()
        xb:SetScript("OnClick", function() if f._extraClick then f._extraClick(f._txt) end end)
        f._extraBtn = xb
        self._copyFrame = f
    end
    f._txt = text
    f._build = build
    f._title:SetText(title or T("COPY_TITLE", "去拍卖行购买"))
    f._edit:SetText(text); f._edit:SetCursorPosition(0); f._edit:HighlightText(); f._edit:SetFocus()
    -- ⛔ 提示文字必须在算高度**之前**设好：_HintExtra 靠 GetStringHeight 量行数，
    --    原来这行写在两个 SetHeight 后面，量到的是上一次弹窗的旧文字。
    f._hint:SetText(hint or T("COPY_HINT", "Ctrl+C 复制，到拍卖行搜索框粘贴购买"))
    if name and name ~= "" then
        f._name = name
        f._nameLbl:Show(); f._nameEdit:Show(); f._nameEdit:SetText(name); f._nameEdit:SetCursorPosition(0)
        f._hint:ClearAllPoints(); f._hint:SetPoint("TOP", f._nameEdit, "BOTTOM", 0, -10)
        local hasGear = build and build.showGear
        f._impBtn:Show(); f._impBtn:ClearAllPoints(); f._impBtn:SetPoint("TOP", f._hint, "BOTTOM", hasGear and -128 or -70, -8)
        f._treeBtn:Show(); f._treeBtn:ClearAllPoints(); f._treeBtn:SetPoint("LEFT", f._impBtn, "RIGHT", 8, 0)
        f._gearBtn:ClearAllPoints(); f._gearBtn:SetPoint("LEFT", f._treeBtn, "RIGHT", 8, 0); f._gearBtn:SetShown(hasGear and true or false)
        f:SetHeight(210 + GearInsight:_HintExtra(f))
    else
        f._name = nil
        f._nameLbl:Hide(); f._nameEdit:Hide(); f._impBtn:Hide(); f._treeBtn:Hide(); f._gearBtn:Hide()
        f._hint:ClearAllPoints(); f._hint:SetPoint("TOP", f._edit, "BOTTOM", 0, -10)
        f:SetHeight(130 + GearInsight:_HintExtra(f))
    end
    if extra and extra.label then
        f._extraClick = extra.onClick
        f._extraBtn:SetText(extra.label); f._extraBtn:ClearAllPoints()
        f._extraBtn:SetPoint("TOP", f._hint, "BOTTOM", 0, -8); f._extraBtn:Show()
        f:SetHeight(f:GetHeight() + 34)
    else
        f._extraClick = nil; f._extraBtn:Hide()
    end
    if GearInsight.Skin then GearInsight.Skin.Sweep(f) end
    f:Show()
end

-- WCL 顶尖天赋选择弹窗：团本/冲分/割草 各前5名，点一行复制该套导入串。
-- 一键重载弹窗（启用子插件后要 /reload 才生效）
function GearInsight:ShowReloadPrompt(msg)
    StaticPopupDialogs["GEARINSIGHT_RELOAD"] = StaticPopupDialogs["GEARINSIGHT_RELOAD"] or {
        text = "%s", button1 = T("BTN_RELOAD", "重载界面"), button2 = CANCEL,
        OnAccept = function() ReloadUI() end, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("GEARINSIGHT_RELOAD", msg or "")
end
