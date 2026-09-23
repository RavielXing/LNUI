-- GearInsight/main/Panel.lua — 主面板开关
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T = H.T

-- ── Panel: ensure / toggle ───────────────────────────────────────────
function GearInsight:TogglePanel()
    -- ⛔ 唯一真相源是框体自己的可见性，不是我们维护的 _panelVisible。
    --    只要有任何一条没走按钮的隐藏路径（ESC/别的代码 f:Hide()/报错中断），
    --    那个标志就会变陈旧，然后 /gi 表现成「按了没反应」
    --    （2026-09-01 用户：「打/gi 打不开了」）。
    if self._panelFrame and self._panelFrame:IsShown() then
        self._panelFrame:Hide()
        self._panelVisible = false
        return
    end
    local ok, err = pcall(self._ensurePanel, self)
    if not ok then
        self:Print(T("PANEL_INIT_FAIL", "面板初始化失败: ") .. tostring(err))
        return
    end
    if not self._panelFrame or not self._upgradeRows then return end
    -- ⛔ 刷新报错不许拖着面板一起打不开：包 pcall，出错就把错打到聊天框，
    --    面板照常显示（内容可能是旧的，但至少人能看见、能反馈错误原文）。
    local okR, errR = pcall(self.RefreshData, self)
    if not okR then
        self:Print("|cFFFF6666[GearInsight] 刷新出错：|r " .. tostring(errR))
    end
    self._panelFrame:Show()
    self._panelVisible = true
    -- 重新打开时把当前页签再选一遍：天赋/心愿单这类页身是「选页签时才构建/显示」的，
    -- 面板关掉再开若没人重选，页签亮着、页身是空的（2026-09-10 用户截图）。
    if self._selectMainTab and self._mainTabKey then
        pcall(self._selectMainTab, self._mainTabKey)
    end
    -- Show() 之后立刻回读一次：如果还是没显示，说明有别的东西把它按住了，
    -- 直接把状态打出来，别让用户面对「点了没反应」还什么都看不到。
    if not self._panelFrame:IsShown() then
        self:Print("|cFFFF6666[GearInsight]|r 面板 Show() 后仍未显示："
            .. " parent=" .. tostring(self._panelFrame:GetParent() and self._panelFrame:GetParent():GetName())
            .. " parentShown=" .. tostring(self._panelFrame:GetParent() and self._panelFrame:GetParent():IsShown())
            .. " alpha=" .. tostring(self._panelFrame:GetAlpha()))
    end
end
