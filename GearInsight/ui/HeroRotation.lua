-- Exact hero tree + encounter reference; no mixed-tree or mixed-encounter fallback.
local T=GearInsight.Helpers.T
function GearInsight.ResolveHeroReference(key, hero, scene)
    local contexts=GearInsightRotationHero and GearInsightRotationHero[key]
    local meta=GearInsightRotationHeroMeta or {}
    for english,localized in pairs(meta.heroNames or {}) do
        if hero==localized or (type(localized)=="table" and (hero==localized.cn or hero==localized.zhCN or hero==localized.zhTW)) then hero=english; break end
    end
    local block=contexts and contexts[scene] and contexts[scene][hero]
    if not block or block.status~="ready" or (block.n or 0)<3 then return nil,hero,block end
    return block,hero
end

function GearInsight:ShowHeroRotation()
    local snapshot=self.SavedVars and self.SavedVars:Save()
    local key=snapshot and snapshot.class and snapshot.spec and (snapshot.class.."/"..snapshot.spec)
    local contexts=key and GearInsightRotationHero and GearInsightRotationHero[key]
    if not contexts then self:Print(T("HERO_ROT_NODATA","当前专精暂无按英雄树拆分的循环数据，不使用混合流派替代。")); return true end
    local f=self._heroRotationFrame
    if f and f:IsShown() then f:Hide(); return true end
    if not f then
        f=CreateFrame("Frame","GearInsightHeroRotation",UIParent,"BackdropTemplate")
        f:SetSize(610,550); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
        f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        f:SetBackdropColor(.035,.045,.065,.98); f:SetBackdropBorderColor(.55,.45,.22,1)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
        local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4)
        f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); f.title:SetPoint("TOPLEFT",18,-18)
        f.scene=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.scene:SetSize(554,25); f.scene:SetPoint("TOPLEFT",18,-49)
        f.info=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.info:SetPoint("TOPLEFT",18,-84); f.info:SetWidth(554); f.info:SetJustifyH("LEFT")
        local sf=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); sf:SetPoint("TOPLEFT",16,-133); sf:SetPoint("BOTTOMRIGHT",-34,18)
        local body=CreateFrame("Frame",nil,sf); body:SetWidth(550); sf:SetScrollChild(body)
        f.body,f.scroll,f.rows=body,sf,{}
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="GearInsightHeroRotation" end
        self._heroRotationFrame=f
        f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED"); f:RegisterEvent("TRAIT_CONFIG_UPDATED")
        f:SetScript("OnEvent",function() f:Hide() end) -- 重新打开读取当前英雄树，避免换天赋后仍展示旧树。
    end
    local sceneKeys={}; for scene in pairs(contexts) do sceneKeys[#sceneKeys+1]=scene end; table.sort(sceneKeys)
    if not f.sceneKey or not contexts[f.sceneKey] then f.sceneKey=sceneKeys[1] end
    local meta=GearInsightRotationHeroMeta or {}
    local function sceneName(scene) return (meta.scenes and meta.scenes[scene]) or scene end
    local function render()
        local block,hero,missing=self.ResolveHeroReference(key,snapshot.heroTalent,f.sceneKey)
        f.title:SetText(T("HERO_ROT_TITLE","当前英雄天赋 · 循环参考").." · "..(snapshot.heroTalent or "—"))
        f.scene:SetText(sceneName(f.sceneKey))
        for _,row in ipairs(f.rows) do row:Hide() end
        local lines={}
        if block then
            f.info:SetText(string.format(T("HERO_ROT_BASIS","当前英雄树 · %d 份有效战斗\n施法频率与覆盖率是该场景实战统计，不代表固定起手顺序。"),block.n))
            for _,kind in ipairs({"casts","buffs","debuffs"}) do
                local group={}
                for name,value in pairs(block[kind] or {}) do group[#group+1]={name=name,value=value,kind=kind} end
                table.sort(group,function(a,b) return a.value==b.value and a.name<b.name or a.value>b.value end)
                for _,line in ipairs(group) do lines[#lines+1]=line end
            end
        else
            f.info:SetText(string.format(T("HERO_ROT_MISSING","当前英雄树在此场景样本不足（%d/3），不套用另一英雄树的数据。\n请切换具体场景；未提供混合树的起手或 AI 解读。"),missing and missing.n or 0))
        end
        for i,line in ipairs(lines) do
            local row=f.rows[i]
            if not row then
                row=CreateFrame("Button",nil,f.body); row:SetSize(550,38)
                row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetPoint("LEFT",4,0); row.icon:SetSize(28,28)
                row.name=row:CreateFontString(nil,"OVERLAY","GameFontHighlight"); row.name:SetPoint("LEFT",42,0); row.name:SetWidth(350); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
                row.value=row:CreateFontString(nil,"OVERLAY","GameFontNormal"); row.value:SetPoint("RIGHT",-8,0)
                row:SetScript("OnEnter",function(s) if s.spellID then GameTooltip:SetOwner(s,"ANCHOR_RIGHT"); GameTooltip:SetSpellByID(s.spellID); GameTooltip:Show() end end)
                row:SetScript("OnLeave",function() GameTooltip:Hide() end)
                f.rows[i]=row
            end
            local id=meta.spells and meta.spells[line.name]
            local si=id and C_Spell.GetSpellInfo(id)
            row.spellID=id; row.icon:SetTexture(si and si.iconID or 134400)
            row.name:SetText((si and si.name or line.name)..(line.kind=="buffs" and " · BUFF" or line.kind=="debuffs" and " · DEBUFF" or ""))
            row.value:SetText(string.format(line.kind=="casts" and T("HERO_ROT_CPM","%.1f 次/分") or "%.1f%%",line.value))
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(i-1)*38); row:Show()
        end
        f.body:SetHeight(math.max(1,#lines*38)); f.scroll:SetVerticalScroll(0)
    end
    f.scene:SetScript("OnClick",function(button)
        MenuUtil.CreateContextMenu(button,function(_,menu)
            for _,scene in ipairs(sceneKeys) do menu:CreateRadio(sceneName(scene),function() return f.sceneKey==scene end,function() f.sceneKey=scene; render() end) end
        end)
    end)
    render(); f:Show(); return true
end
