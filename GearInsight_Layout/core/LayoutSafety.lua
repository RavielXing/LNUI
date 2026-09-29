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
function S.WriteMacro(index,name,icon,body,perChar)
    local returned
    if index and index>0 then returned=EditMacro(index,name,icon,body)
    else returned=CreateMacro(name,icon,body,perChar) end
    -- Editing may change the macro index; never validate a stale slot.
    local resolved=type(returned)=='number' and returned or nil
    if not resolved or GetMacroInfo(resolved)~=name then resolved=GetMacroIndexByName(name) end
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
        for i=1,(MAX_ACCOUNT_MACROS or 120)+(MAX_CHARACTER_MACROS or 18) do
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
        -- New macros occupy the tail of each scope. Delete them backwards before
        -- restoring existing indices and contents.
        local originalNames={}
        for _,m in pairs(snap.macros) do originalNames[m.name]=true end
        for i=(MAX_ACCOUNT_MACROS or 120)+(MAX_CHARACTER_MACROS or 18),1,-1 do
            local currentName=GetMacroInfo(i)
            if currentName and not originalNames[currentName] then attempt('新增宏 '..i,function()
                DeleteMacro(i); return GetMacroInfo(i)==nil
            end) end
        end
        for i,m in pairs(snap.macros) do attempt('宏 '..m.name,function()
            local index=GetMacroIndexByName(m.name)
            local name,icon,body=GetMacroInfo(index and index>0 and index or i)
            if name==m.name and icon==m.icon and S.MacroBodyEqual(body,m.body) then return true end
            return S.WriteMacro(index,m.name,m.icon,m.body,i>(MAX_ACCOUNT_MACROS or 120))~=false
        end) end
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
            S.active=true; self._applyingKeys=true
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
