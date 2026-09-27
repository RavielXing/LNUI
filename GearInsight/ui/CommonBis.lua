-- Separate empirical bracket. Never overwrite high-key rankings or stat targets.
local T = GearInsight.Helpers.T
function GearInsight.CommonBisRows(key)
    local source = GearInsight.BisData and GearInsight.BisData.mplusCommon
    local spec = source and source.specs and source.specs[key]
    local rows = {}
    for slot, group in pairs(spec and spec.slots or {}) do
        for rank, candidate in ipairs(group.candidates or {}) do
            rows[#rows+1] = { slot=tonumber(slot), rank=rank, item=candidate, sampleN=group.sampleN }
        end
    end
    table.sort(rows,function(a,b) return a.slot == b.slot and a.rank < b.rank or a.slot < b.slot end)
    return rows, spec, source
end

function GearInsight:ShowCommonBis()
    local snapshot = self.SavedVars and self.SavedVars.Save and self.SavedVars:Save()
    local key = snapshot and snapshot.class and snapshot.spec and (snapshot.class.."/"..snapshot.spec)
    local rows, spec, source = self.CommonBisRows(key)
    local f = self._commonBisFrame
    if not f then
        f=CreateFrame("Frame","GearInsightCommonBis",UIParent,"BackdropTemplate")
        f:SetSize(610,550); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
        f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        f:SetBackdropColor(.035,.045,.065,.98); f:SetBackdropBorderColor(.55,.45,.22,1)
        f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true)
        f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
        local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4)
        f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); f.title:SetPoint("TOPLEFT",18,-18)
        f.info=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.info:SetPoint("TOPLEFT",18,-48); f.info:SetWidth(554); f.info:SetJustifyH("LEFT")
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",16,-108); scroll:SetPoint("BOTTOMRIGHT",-34,18)
        local body=CreateFrame("Frame",nil,scroll); body:SetWidth(550); scroll:SetScrollChild(body)
        f.body,f.scroll,f.rows=body,scroll,{}
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="GearInsightCommonBis" end
        self._commonBisFrame=f
    end
    f.title:SetText(T("COMMON_BIS_TITLE","常规 · 实战装备参考"))
    f.info:SetText(spec and string.format(T("COMMON_BIS_BASIS","+%d · 排名 %d–%d · %d 位角色\n按部位展示实穿比例，非模拟最优；戒指/饰品每人可贡献两件。"),source.keyLevel,source.rankingRange[1],source.rankingRange[2],spec.sampleN)
        or T("COMMON_BIS_EMPTY","当前专精暂无常规装备样本，不使用高层数据替代。"))
    for _, row in ipairs(f.rows) do row:Hide() end
    for i,data in ipairs(rows) do
        local row=f.rows[i]
        if not row then
            row=CreateFrame("Button",nil,f.body); row:SetSize(550,44)
            row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(32,32); row.icon:SetPoint("LEFT",4,0)
            row.name=row:CreateFontString(nil,"OVERLAY","GameFontHighlight"); row.name:SetPoint("LEFT",44,5); row.name:SetWidth(365); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
            row.meta=row:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); row.meta:SetPoint("LEFT",44,-12)
            row.pct=row:CreateFontString(nil,"OVERLAY","GameFontNormal"); row.pct:SetPoint("RIGHT",-8,0)
            row:SetScript("OnEnter",function(s)
                GameTooltip:SetOwner(s,"ANCHOR_RIGHT")
                if s.link then GameTooltip:SetHyperlink(s.link) else GameTooltip:SetItemByID(s.itemId) end
                GameTooltip:AddLine(T("COMMON_BIS_EXAMPLE","展示一份真实穿戴样本，不代表该物品所有装等。"),.65,.7,.8,true); GameTooltip:Show()
            end)
            row:SetScript("OnLeave",function() GameTooltip:Hide() end)
            f.rows[i]=row
        end
        local item=data.item
        row.itemId=item.itemId; row.link=nil
        local bonus=item.observedExample and item.observedExample.bonusIDs
        if bonus and #bonus>0 and self.LinkMid then row.link="item:"..item.itemId..self.LinkMid()..#bonus..":"..table.concat(bonus,":") end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(i-1)*44)
        row.icon:SetTexture((C_Item.GetItemIconByID and C_Item.GetItemIconByID(item.itemId)) or (item.icon and ("Interface\\Icons\\"..item.icon)) or 134400)
        row.name:SetText((C_Item.GetItemNameByID and C_Item.GetItemNameByID(item.itemId)) or item.itemName or tostring(item.itemId))
        local slotName=({[1]=HEADSLOT,[2]=NECKSLOT,[3]=SHOULDERSLOT,[5]=CHESTSLOT,[6]=WAISTSLOT,[7]=LEGSSLOT,[8]=FEETSLOT,[9]=WRISTSLOT,[10]=HANDSSLOT,[11]=FINGER0SLOT,[13]=TRINKET0SLOT,[15]=BACKSLOT,[16]=MAINHANDSLOT,[17]=SECONDARYHANDSLOT})[data.slot] or tostring(data.slot)
        row.meta:SetText(string.format("%s · #%d · %d/%d",slotName,data.rank,item.count,data.sampleN))
        row.pct:SetText(string.format("%.1f%%",item.usagePct)); row:Show()
    end
    f.body:SetHeight(math.max(1,#rows*44)); f.scroll:SetVerticalScroll(0); f:Show()
end
