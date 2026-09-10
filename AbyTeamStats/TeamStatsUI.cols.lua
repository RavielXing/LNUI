local _, TS = ...
local L = TS.L

function TS.GetDynamicColumnsForCuttingEdge()
    local tab = TS.TABS[TS.Frame().tabIdx]
    if not tab.dynamic_columns then return tab.ids, tab.names, tab.tips, tab.widths end

    local dynamic_ids = {}
    local dynamic_names = {}
    local dynamic_tips = {}
    local dynamic_widths = {}
    local completed_columns = {}

    if not TS.ui_names or not TS.db.players then
        return tab.ids, tab.names, tab.tips, tab.widths
    end

    for _, name in ipairs(TS.ui_names) do
        local player = TS.db.players[name]
        if player and player.stats then
            for i, idData in ipairs(tab.ids) do
                local completed = false
                if type(idData) == "table" then
                    for _, id in ipairs(idData) do
                        local statId = TS.mirror[id]
                        if statId and player.stats[statId] and player.stats[statId] > 0 then
                            completed = true
                            break
                        end
                    end
                else
                    local statId = TS.mirror[idData]
                    if statId and player.stats[statId] and player.stats[statId] > 0 then
                        completed = true
                    end
                end
                if completed then
                    completed_columns[i] = true
                end
            end
        end
    end

    for i, idData in ipairs(tab.ids) do
        if completed_columns[i] then
            table.insert(dynamic_ids, idData)
            table.insert(dynamic_names, tab.names[i])
            table.insert(dynamic_tips, tab.tips[i])
            table.insert(dynamic_widths, tab.widths[i])
        end
    end

    if #dynamic_ids == 0 then
        table.insert(dynamic_ids, tab.ids[1])
        table.insert(dynamic_names, tab.names[1])
        table.insert(dynamic_tips, tab.tips[1])
        table.insert(dynamic_widths, tab.widths[1])
    end

    return dynamic_ids, dynamic_names, dynamic_tips, dynamic_widths
end

function TS.GetDynamicColumnsForKeystone()
    local tab = TS.TABS[TS.Frame().tabIdx]
    if not tab.dynamic_columns then return tab.ids, tab.names, tab.tips, tab.widths end

    local dynamic_ids = {}
    local dynamic_names = {}
    local dynamic_tips = {}
    local dynamic_widths = {}
    local completed_columns = {}

    if not TS.ui_names or not TS.db.players then
        return tab.ids, tab.names, tab.tips, tab.widths
    end

    for _, name in ipairs(TS.ui_names) do
        local player = TS.db.players[name]
        if player and player.stats then
            for i, idData in ipairs(tab.ids) do
                local completed = false
                if idData ~= 0 then
                    local statId = TS.mirror[idData]
                    if statId and player.stats[statId] and player.stats[statId] > 0 then
                        completed = true
                    end
                end
                if completed then
                    completed_columns[i] = true
                end
            end
        end
    end

    for i, idData in ipairs(tab.ids) do
        if completed_columns[i] or idData == 0 then
            table.insert(dynamic_ids, idData)
            table.insert(dynamic_names, tab.names[i])
            table.insert(dynamic_tips, tab.tips[i])
            table.insert(dynamic_widths, tab.widths[i])
        end
    end

    if #dynamic_ids == 0 then
        table.insert(dynamic_ids, tab.ids[1])
        table.insert(dynamic_names, tab.names[1])
        table.insert(dynamic_tips, tab.tips[1])
        table.insert(dynamic_widths, tab.widths[1])
    end

    return dynamic_ids, dynamic_names, dynamic_tips, dynamic_widths
end

local ExtraColumnCreator = function(col, btn, idx)
    local text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"):SetWordWrap(false):Size(col.width + 1, 28)
    text:SetFontHeight(14)
    return text
end

local ExtraColumnUpdater = function(line, widget, idx, colIdx)
    local tab = TS.TABS[TS.Frame().tabIdx]
    local text, r, g, b = "", 1, 1, 1
    local ids = widget.ids
if tab.tab == "坚韧钥石（第1赛季）" then
    if ids == 0 then
        local player = line.player
        local score = player.mscore or 0  -- 关键修改：没有分数时显示0
        local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
        text, r, g, b = score, color.r, color.g, color.b
    else
            text = TeamStatsUI_GetAchievementOrStaticText(line.player, ids)
            if text == "?" then
                r,g,b = 0.5,0.5,0.5
            elseif text == "-" then
                r,g,b = 1,0.2,0.2
            else
                r,g,b = 0.5,1,0.5
            end
        end
    elseif tab.special == "season_mythic" then
        if ids == 0 then
            local player = line.player
            local color = C_ChallengeMode.GetDungeonScoreRarityColor(player.mscore or 0)
            text, r, g, b = player.mscore or "?", color.r, color.g, color.b
        else
            local data = TS.temp_data[line.player_name]
            data = data and data["mythic"]
            if data then
                text = data[ids] or "-"
                if text == "-" then
                    r,g,b = 1,0.2,0.2
                end
            else
                text, r, g, b = "?", 0.5,0.5,0.5
            end
        end
    elseif type(ids) == "table" then
        local progress, max, total = TeamStatsUI_GetAchievementOrStaticText(line.player, ids)
        if progress == 0 then
            text,r,g,b = "-",1,0.2,0.2
        elseif tab.any_done then
            text = "|cff7fff7f★|r"
        elseif type(progress)=="string" and progress:find("^0%([0-9]+%)") then
            text = "|cff959697".. progress .. "|r/" .. max
        else
            text = "|cff7fff7f".. progress .. "|r/" .. max
        end
    else
        text = TeamStatsUI_GetAchievementOrStaticText(line.player, ids)
        if text == "?" then
            r,g,b = 0.5,0.5,0.5
        elseif text == "-" then
            r,g,b = 1,0.2,0.2
        elseif text == "1" then
            r,g,b = 1,0.5,0
        else
            r,g,b = 0.5,1,0.5
        end
    end
    widget:SetText(text)
    widget:SetTextColor(r,g,b)
end

local function compare(n1, n2, prop)
    if TS.names[n1] and not TS.names[n2] then return true, nil, true end
    if TS.names[n2] and not TS.names[n1] then return false, nil, true end
    local p1=TS.db.players[n1]
    local p2=TS.db.players[n2]
    if p1 == nil and p2 == nil then return n1 < n2 end
    if p1 == nil and p2 ~= nil then return false, nil, true end
    if p1 ~= nil and p2 == nil then return true, nil, true end
    local v1, v2
    if prop == "realm" then
        v1 = select(3, n1:find("%-(.+)$"))
        v2 = select(3, n2:find("%-(.+)$"))
    else
        v1, v2 = p1[prop], p2[prop]
    end
    if v1 == v2 then return n1 < n2, true end
    if v1 == nil and v2 ~= nil then return false, nil, true end
    if v1 ~= nil and v2 == nil then return true, nil, true end
    return v1 < v2
end

local function sortFixColumn(self)
    local id = self.id
    if self.sortFunc then
        if (TS.currSort==id) then TS.currSort=-id else TS.currSort=id end
        TS.currSortFunc = self.sortFunc
        table.sort(TS.ui_names, self.sortFunc)
        TS.Frame().scroll.update()
    end
end

function TS.SetupColumns(f)
    local targetBtnOnEnter = function(self)
        if self.line.player and self.line.player.unknown then
            self.tooltipLines = self.tooltipLines or {}
            self.tooltipLines[1] = self.line.player.name or "未知目标"
            self.tooltipLines[2] = "无法安全读取该成员"
            CoreUIShowTooltip(self, "ANCHOR_LEFT")
        else
            for n, v in pairs(TS.db.players) do
                if v == self.line.player then
                    self.tooltipLines = self.tooltipLines or {}
                    self.tooltipLines[1] = n
                    self.tooltipLines[2] = "Ctrl点击观察"
                    CoreUIShowTooltip(self, "ANCHOR_LEFT")
                    break
                end
            end
        end
        self.line:LockHighlight()
    end
    local targetBtnOnLeave = function(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        self.line:UnlockHighlight()
    end
    local legendBtnOnEnter = function(self)
        self.line:LockHighlight()
        if not self._link then return end
        ShoppingTooltip1:SetOwner(self, "ANCHOR_LEFT");
        ShoppingTooltip1:SetHyperlink(self._link);
        ShoppingTooltip1:Show();
    end
    local legendBtnOnLeave = function(self)
        if ShoppingTooltip1:GetOwner() == self then ShoppingTooltip1:Hide() end
        self.line:UnlockHighlight()
    end

    TS.cols = {
        {
            header = function(btn, col)
                local cb = WW(btn):CheckButton(nil, "UICheckButtonTemplate"):Size(24,24):BL(0,-3):un()
                CoreUIEnableTooltip(cb, "全选/取消全选", "选择玩家用于发布通告")
                cb:SetScript("OnClick", function(self)
                    local state = self:GetChecked();
                    for i=1,#TS.ui_names do
                        if TS.db.players[TS.ui_names[i]] then
                            TS.db.players[TS.ui_names[i]].selected = state;
                        end
                    end
                    f.scroll.update();
                end)
            end,
            headerSpan = 1,
            width = 20,
            offset = {1,-2},
            create = function(col,b,idx)
                TS.UIPlayerSelected = TS.UIPlayerSelected or function(self) self:GetParent().player.selected = self:GetChecked() end
                return b:CheckButton(nil, "UICheckButtonTemplate"):Size(col.width,20):SetScript("OnClick", TS.UIPlayerSelected);
            end,
            layout = function(parent) end,
            update = function(line, widget, idx, colIdx)
                widget:SetChecked(not not line.player.selected);
            end,
        },
        {
            header = L["HeaderPlayerName"],
            headerSpan = 2,
            width = 100,
            sort = function(a,b)
                local r, equal, force = compare(a, b, "realm")
                if equal then r, equal, force = compare(a, b, "name") end
                if TS.currSort > 0 or force then return r else return not r end
            end,
            create = function(col,btn,idx) return btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"):SetJustifyH("CENTER"):Size(col.width, 24) end,
            update = function(line, widget, idx, colIdx)
                local fullName = TS.ui_names[idx]
                if not InCombatLockdown() then
                    local target = line.target
                    if not target or target:GetObjectType() ~= "Button" then
                        target = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
                        target.line = line
                        target:RegisterForClicks("AnyUp", "AnyDown")
                        target:SetAttribute("type", "macro")
                        target:SetAttribute("ctrl-type1", "macro")
                        target:SetFrameStrata("HIGH")
                        target:SetScript("OnEnter", targetBtnOnEnter)
                        target:SetScript("OnLeave", targetBtnOnLeave)
                        line.target = target
                    end
                    target:ClearAllPoints()
                    target:SetParent(line)
                    target:SetPoint("TOPLEFT", line, "TOPLEFT", TS.cols[1].width+2, 0)
                    target:SetPoint("BOTTOMRIGHT", line, 0, 0)
                    if not (line.player and line.player.unknown) and fullName and fullName:find("%-") then -- 确保名字包含服务器
                        target:SetAttribute("macrotext", "/target "..fullName)
                        -- 使用安全的宏，检查目标是否可观察
                        target:SetAttribute("ctrl-macrotext1", "/cleartarget\n/target "..fullName.."\n/run if UnitExists('target') and CanInspect('target') then InspectUnit('target') else U1Message('无法观察 "..fullName.."') end")
                    else
                        target:SetAttribute("macrotext", "")
                        target:SetAttribute("ctrl-macrotext1", "/run U1Message('无效的玩家名称')")
                    end
                    target:Show()
                end
                if line.player and line.player.unknown then
                    widget:SetText(line.player.name or "未知目标")
                    widget:SetTextColor(0.5, 0.5, 0.5)
                elseif TS.names[TS.ui_names[idx]] then
                    CoreUISetTextWithClassColor(widget, line.player.name, line.player.class)
                else
                    if not line.player.name then
                        widget:SetText(TS.ui_names[idx]:gsub("%-.+$", ""))
                    else
                        widget:SetText(line.player.name)
                    end
                    widget:SetTextColor(0.5, 0.5, 0.5)
                end
            end,
        },
        {
            width = 40,
            create = function(col,btn,idx) return btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"):SetFontHeight(12):SetJustifyH("CENTER"):Size(col.width, 24) end,
            update = function(line, widget, idx, colIdx)
                if line.player and line.player.unknown then
                    widget:SetText("-")
                else
                    widget:SetText(TS.ui_names[idx]:gsub("^.+%-", ""))
                    widget:SetText("-"..string.utf8sub(TS.ui_names[idx]:gsub("^.+%-", ""), 1, 2))
                end
                if TS.names[TS.ui_names[idx]] then
                    widget:SetTextColor(255,255,0)
                else
                    widget:SetTextColor(0.5, 0.5, 0.5)
                end
            end,
        },
        {
            header = L["HeaderClass"],
            headerSpan = 2,
            width = 16,
            offset = {3,-2},
            sort = function(a,b)
                local r, equal, force = compare(a, b, "class")
                if equal then r, equal, force = compare(a, b, "talent1") end
                if TS.currSort > 0 or force then return r else return not r end
            end,
            create = function(col,btn,idx) return btn:Texture(nil, "ARTWORK", "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"):Size(16, 16) end,
            update = function(line, widget, idx, colIdx)
                local icon = line.player.class and CLASS_ICON_TCOORDS[line.player.class]
                if icon then widget:SetAlpha(1) widget:SetTexCoord(unpack(icon)) else widget:SetAlpha(0) end
            end,
        },
        {
            width = 40,
            create = function(col,btn,idx) return btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"):SetJustifyH("CENTER"):Size(col.width, 24) end,
            update = function(line, widget, idx, colIdx)
                local player = line.player
                local talent = player.talent1
                CoreUISetTextWithClassColor(widget, talent and talent:sub(1,6) or (player.inspected and "无" or "?"), line.player.class)
                if not player.inspected then widget:SetTextColor(0.5,0.5,0.5,1) end
            end,
        },
        {
            header = L["HeaderGS"],
            headerSpan = 1,
            width = 75,
            tip = "身上当前装备的平均物品等级",
            sort = function(a,b)
                local r, equal, force = compare(a, b, "gs")
                if TS.currSort > 0 or force then return r else return not r end
            end,
            create = function(col,btn,idx) return btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"):SetJustifyH("CENTER"):Size(col.width, 24) end,
            update = function(line, widget, idx, colIdx)
                local player = line.player
                local gems = "|cff7f7f7f(?)|r"
                if player.gem_info then
                    local _, _, count = player.gem_info:find("%d/(%d)")
                    count = count or 0
                    gems = "|cffffffff("..count..")|r"
                end
                widget:SetText(player.gs and format("%s%.1f", (player.bad and "|cffffd200*|r" or ""), player.gs) or "?")
                if not player.gsGot then widget:SetTextColor(0.5,0.5,0.5) else widget:SetTextColor(1,1,1) end

                local r, b, g = U1GetInventoryLevelColor(player.gs)
                if not player.gsGot then widget:SetTextColor(0.5,0.5,0.5,1) else widget:SetTextColor(r,b,g) end
            end
        },
        {
            header = "引领",
            headerSpan = 1,
            onlyTab1 = 1,
            width = 48,
            tip = "当前版本相关的英雄难度通关副本成就（引领潮流），同战网共享，跨角色。绿色为有，灰色为没有",
            create = function(col,btn,idx) return btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"):SetFontHeight(14):SetJustifyH("CENTER"):Size(col.width, 24) end,
            update = function(line, widget, idx, colIdx)
                local player = line.player
                if not player.compared then
                    widget:SetText("?")
                    widget:SetTextColor(0.5,0.5,0.5)
                else
                    local VBOSSES = TS.VERSION_BOSSES
                    local stats = player.stats
                    local s = ""
                    for i=1, #VBOSSES, 2 do
                        local id, bossname = VBOSSES[i], VBOSSES[i+1]
                        local statId = TS.mirror[id]
                        local text = stats and stats[statId] or 0
                        s = s .. (text > 0 and "|cff7fff7f" or "|cff959697") .. bossname .. "|r"
                    end
                    widget:SetText(s)
                end
            end
        },
        {
            header = "钥石评分",
            headerSpan = 1,
            onlyTab1 = 1,
            width = 64,
            tip = "角色当前赛季的史诗钥石评分",
            sort = function(a,b)
                local r, equal, force = compare(a, b, "mscore")
                if TS.currSort > 0 or force then return r else return not r end
            end,
            create = function(col,btn,idx) return btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"):SetJustifyH("CENTER"):Size(col.width, 24) end,
            update = function(line, widget, idx, colIdx)
                local player = line.player
                widget:SetText(player.mscore or "?")
                local color = C_ChallengeMode.GetDungeonScoreRarityColor(player.mscore or 0)
                widget:SetTextColor(color.r, color.g, color.b)
            end
        },
    }

    TS.NUM_FIX_COLUMNS = #TS.cols

    local MAX_INFOS = 0
    for _, v in next, TS.TABS do
        local numCols = v.dynamic_columns and #v.ids or #(v.specialIDs or v.ids)
        MAX_INFOS = max(MAX_INFOS, numCols)
    end
    for i=1, MAX_INFOS do
        table.insert(TS.cols, {
            width = TS.DEFAULT_COL_WIDTH,
            header = true,
            create = ExtraColumnCreator,
            update = ExtraColumnUpdater,
        })
    end
    local defaultOffset = {1,0}
    for i, col in ipairs(TS.cols) do
        if not col.offset then col.offset=defaultOffset end
        if not col.width then col.width = TS.DEFAULT_COL_WIDTH end
    end

    f.headers={}
    local TAB_OFFSET = -1
    local left = 2
    for i, col in ipairs(TS.cols) do
        if i>TS.NUM_FIX_COLUMNS and not TS.NUM_FIX_HEADERS then TS.NUM_FIX_HEADERS=#f.headers end
        if col.header then
            local id = #f.headers+1
            local btn = TplColumnButton(f, nil, TS.COLUMN_BUTTON_HEIGHT):SetScript("OnClick", sortFixColumn):un()
            WW(btn:GetFontString()):SetFontHeight(14):un()
            btn.id = id
            btn.sortFunc = col.sort
            table.insert(f.headers, btn)
            if i > TS.NUM_FIX_COLUMNS then
                CoreUIEnableTooltip(btn)
            elseif col.tip then
                CoreUIEnableTooltip(btn, type(col.header)=="string" and col.header or "说明", col.tip)
            end
        end
        left = left + col.offset[1] + (col.width or TS.DEFAULT_COL_WIDTH)
    end
end