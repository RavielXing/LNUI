-- Local action-bar transactions. Never replace Blizzard's global APIs.
GearInsight = GearInsight or {}
local S = {}
GearInsight.LayoutSafety = S
function S.Copy(v, seen)
    if type(v) ~= 'table' then return v end
    seen=seen or {}
    if seen[v] then return seen[v] end
    local out={};seen[v]=out
    for k,x in pairs(v) do out[k]=S.Copy(x,seen) end
    return out
end
local fields = {'layoutKeys','layoutSmart','layoutKeySnap','layoutKeepKeys','layoutSpecial',
    'layoutSpecialDefault','layoutSpellKey','layoutRoleOverride','layoutPageOverride',
    'layoutMacroRole','layoutGroupSlots','layoutGroups','layoutUseQE','layoutLib'}
function S.Preset()
    local index=GetSpecialization and GetSpecialization()
    local out = {version=2,specID=index and GetSpecializationInfo(index) or 0}
    for _, k in ipairs(fields) do
        local value=(GearInsightDB or {})[k]
        if k=='layoutKeys' or k=='layoutSmart' or k=='layoutKeySnap' or k=='layoutLib' or k=='layoutGroupSlots' then
            value=value and value[out.specID]
        end
        out[k] = S.Copy(value)
    end
    return out
end
function S.RestorePreset(p)
    if not p or (p.version ~= 1 and p.version ~= 2) then return end
    GearInsightDB = GearInsightDB or {}
    for _, k in ipairs(fields) do
        if p.version==2 and (k=='layoutKeys' or k=='layoutSmart' or k=='layoutKeySnap' or k=='layoutLib' or k=='layoutGroupSlots') then
            GearInsightDB[k]=GearInsightDB[k] or {}
            GearInsightDB[k][p.specID]=S.Copy(p[k])
        else GearInsightDB[k] = S.Copy(p[k]) end
    end
    GearInsight._smartKeys = {}; GearInsight._slotIdent = {}; GearInsight._formPlans = nil
    if GearInsight.RebuildKeyPool then GearInsight.RebuildKeyPool() end
end
function S.Fail(reason)
    if S.active then error(reason, 0) end
    GearInsight:Print('|cffff5555' .. reason .. '|r')
    return false
end
function S.Bind(key, command)
    local ok = SetBinding(key, command)
    if not ok or (GetBindingAction(key) or '') ~= (command or '') then
        return S.Fail('按键设置失败：' .. tostring(key) .. ' → ' .. tostring(command or '无'))
    end
    return true
end
function S.Save(set)
    if SaveBindings(set) == false then return S.Fail('按键保存失败') end
    -- SaveBindings has no reliable success return on every client; persistence
    -- across reload remains an in-game acceptance check.
    return true
end
function S.MacroBodyEqual(a,b)
    local function normalize(body)
        return (body or ''):gsub("\r\n","\n"):gsub("\r","\n"):gsub("\n+$","")
    end
    return normalize(a)==normalize(b)
end
-- 宏栏上限：MAX_*_MACROS 是 Blizzard_MacroUI 里的全局，宏界面没打开过时是 nil。
-- ⛔ 09-30 真机：旧兜底写死角色 18 个，而游戏角色宏是 30 个；判断错了建宏静默失败，报成「宏写入校验失败（读回 0 字节）」。
function S.MacroLimits()
    if not MAX_CHARACTER_MACROS then
        local load=(C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
        if load then pcall(load,"Blizzard_MacroUI") end
    end
    return MAX_ACCOUNT_MACROS or 120, MAX_CHARACTER_MACROS or 30
end
function S.MacroSlotsText()
    local aMax,cMax=S.MacroLimits()
    local nA,nC=GetNumMacros()
    return string.format('通用宏 %d/%d、角色宏 %d/%d',nA or 0,aMax,nC or 0,cMax)
end
function S.WriteMacro(index,name,icon,body,perChar)
    -- 事务里记下本次写过的宏名：回滚只恢复这些，⛔ 绝不按名字去改玩家自己的宏（同名宏会被写串，09-30 真机 7 个 Decursive）
    if S.active and S.touched then S.touched[name]=true end
    local returned
    if index and index>0 then returned=EditMacro(index,name,icon,body)
    else returned=CreateMacro(name,icon,body,perChar) end
    -- Editing may change the macro index; never validate a stale slot.
    local resolved=type(returned)=='number' and returned or nil
    if not resolved or GetMacroInfo(resolved)~=name then resolved=GetMacroIndexByName(name) end
    if not (index and index>0) and not (resolved and resolved>0) then
        -- 新建没建出来 = 这一栏其实满了：换另一栏再试一次，还不行就明确报「宏栏已满」
        local aMax,cMax=S.MacroLimits()
        local nA,nC=GetNumMacros()
        if (perChar and (nA or 0)<aMax) or (not perChar and (nC or 0)<cMax) then
            returned=CreateMacro(name,icon,body,not perChar)
            resolved=type(returned)=='number' and returned or nil
            if not resolved or GetMacroInfo(resolved)~=name then resolved=GetMacroIndexByName(name) end
        end
        if not (resolved and resolved>0) then
            return S.Fail('宏栏已满，新建「'..name..'」失败（'..S.MacroSlotsText()..'）：删掉几个不用的宏再试')
        end
    end
    local actualName,_,actual
    if resolved and resolved>0 then actualName,_,actual=GetMacroInfo(resolved) end
    if actualName~=name or not S.MacroBodyEqual(actual,body) then
        GearInsightDB.layoutMacroWriteFailure={name=name,index=index,returned=returned,
            resolved=resolved,expected=body,actual=actual}
        return S.Fail('宏写入校验失败：'..name..'（预期 '..#(body or '')..' 字节，读回 '..#(actual or '')..' 字节）')
    end
    return resolved
end
function S.Bindings()
    local out = {}
    for i=1,GetNumBindings() do
        local cmd = GetBinding(i)
        if cmd and not cmd:match('^HOUSING_') then
            local keys={}
            for _,key in ipairs({select(3,GetBinding(i))}) do
                if GetBindingAction(key)==cmd then keys[#keys+1]=key end
            end
            if #keys>0 then out[cmd]=keys end
        end
    end
    return out
end
function S.WriteBindings(wanted)
    local current,desired,changed=S.Bindings(),{},false
    for cmd,keys in pairs(wanted) do
        -- Older backups contain mutually exclusive housing-context commands.
        -- They must never be applied as normal action-bar bindings.
        if not cmd:match('^HOUSING_') then for _,key in ipairs(keys) do
            if desired[key] and desired[key]~=cmd then
                return S.Fail('备份按键冲突：'..key..' → '..desired[key]..' / '..cmd)
            end
            desired[key]=cmd
        end end
    end
    for cmd,keys in pairs(current) do for _,key in ipairs(keys) do
        if not desired[key] then S.Bind(key,nil);changed=true end
    end end
    for key,cmd in pairs(desired) do
        if (GetBindingAction(key) or '')~=cmd then S.Bind(key,cmd);changed=true end
    end
    if changed then S.Save(2) end
end
function S.Install(G, readSlot, restoreSlot)
    local function capture()
        local snap={slots={},binds=S.Bindings(),preset=S.Preset(),macros={},bindingSet=GetCurrentBindingSet and GetCurrentBindingSet()}
        for i=1,180 do snap.slots[i]=readSlot(i) end
        local aMax,cMax=S.MacroLimits()
        snap.macroMax=aMax+cMax
        for i=1,snap.macroMax do
            local name,icon,body=GetMacroInfo(i)
            if name then snap.macros[i]={name=name,icon=icon,body=body} end
        end
        return snap
    end
    local function rollback(snap)
        local failures={}
        local function attempt(label,fn)
            local ok,result=pcall(fn)
            if not ok or result==false then failures[#failures+1]=label..(not ok and ('：'..tostring(result)) or '：读回不一致') end
        end
        -- ⛔ 只恢复本次事务写过的宏（S.touched）。玩家自己的宏插件从来不改，回滚也绝不写它们：
        --   旧代码对快照里每个宏按「名字」GetMacroIndexByName 找回来比对，同名宏（7 个 Decursive / 3 个 YY）
        --   永远找到第一个 → 把第 2、3 个的正文写进第 1 个（09-30 真机，清空重铺预检失败后的回滚把玩家宏写串）。
        local touched=S.touched or {}
        local originalNames,dup={},{}
        for _,m in pairs(snap.macros) do
            if originalNames[m.name] then dup[m.name]=true end
            originalNames[m.name]=true
        end
        -- 本次新建的宏（快照里没有、且是本次写过的名字）从后往前删
        for i=(snap.macroMax or 150),1,-1 do
            local currentName=GetMacroInfo(i)
            if currentName and touched[currentName] and not originalNames[currentName] then attempt('新增宏 '..currentName,function()
                DeleteMacro(i); return GetMacroInfo(i)~=currentName
            end) end
        end
        for i,m in pairs(snap.macros) do
            if touched[m.name] then
                if dup[m.name] then
                    failures[#failures+1]='宏 '..m.name..'：有同名宏，不自动恢复（请手动检查）'
                else attempt('宏 '..m.name,function()
                    local index=GetMacroIndexByName(m.name)
                    local name,icon,body=GetMacroInfo(index and index>0 and index or i)
                    if name==m.name and icon==m.icon and S.MacroBodyEqual(body,m.body) then return true end
                    return S.WriteMacro(index,m.name,m.icon,m.body,i>(MAX_ACCOUNT_MACROS or 120))~=false
                end) end
            end
        end
        for i=1,180 do attempt('格 '..i,function() return restoreSlot(i,snap.slots[i]) end) end
        attempt('按键',function() S.WriteBindings(snap.binds); return true end)
        S.RestorePreset(snap.preset)
        return failures
    end
    for _,method in ipairs({'ApplyKeyBindings','ApplyLayout','RestoreBars'}) do
        local original=G[method]
        G[method]=function(self,...)
            if S.active then return S.Fail('动作条操作仍在进行') end
            if InCombatLockdown() or (self.InForm and self.InForm()) then return original(self,...) end
            if GetCursorInfo() then self:Print('请先放下光标上的技能或物品，再应用预设。'); return false end
            local snap=capture()
            local args={...}; local previousPrint=self.Print; local messages={}
            self.Print=function(_,message) messages[#messages+1]=message end
            S.active=true; S.touched={}; self._applyingKeys=true
            local ok,result=xpcall(function() return original(self,unpack(args)) end,function(e)return tostring(e)end)
            local failures={}
            if not ok then
                -- Leave transaction checks on: rollback failures must be visible.
                failures=rollback(snap)
            end
            self.Print=previousPrint; S.active=nil; self._applyingKeys=nil
            if ok then
                for _,message in ipairs(messages) do self:Print(message) end
                self._layoutLastResult={ok=true,operation=method}
            else
                self._layoutRecovery=snap
                if #failures>0 then GearInsightDB.layoutOperationRecovery=snap end
                self._layoutLastResult={ok=false,operation=method,error=result,rollbackFailures=failures}
                self:Print('|cffff5555操作未完成：'..result..'|r')
                self:Print(#failures==0 and '已恢复操作前的动作条和按键。' or ('恢复仍有失败，请勿继续应用：'..table.concat(failures,'、')))
            end
            if self._layoutRefresh then self._layoutRefresh() end
            return ok,result
        end
    end
end
