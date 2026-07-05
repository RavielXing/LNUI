local _, core = ...
local L = core.L
local floor,ceil,format,tostring=floor,ceil,format,tostring
local pairs,ipairs,next,wipe,assert,type,tinsert,select,tremove,GetTime,setmeta,rawg = pairs,ipairs,next,wipe,assert,type,tinsert,select,tremove,GetTime,setmetatable, rawget
local n2s_small,n2s_big,n2s_float,n2s_format,n2s_pad_cache={},{},{},{"%.1f","%.2f","%.3f","%.4f","%.5f",[0]="%d"},{"0","00","000","0000","00000"}
for i=0, 100 do n2s_small[i] = tostring(i) end
for i=0, 9 do for j=0, 9 do n2s_float[i+j/10] = format("%.1f", i+j/10) end end

_empty_table = {};
_temp_table = {};

---复制数据,如果不提供toTable则新建一个
function u1copy(fromTable, toTable)
    toTable = toTable or {}
    if not fromTable then return end
    for k,v in pairs(fromTable) do
        toTable[k] = v;
    end
    return toTable;
end
copy = copy or u1copy

function deepmix(targetTable, dataTable)
    for k, v in pairs(dataTable) do
        if type(v) == "table" and type(targetTable[k]) == "table" then
            deepmix(targetTable[k], v)
        else
            targetTable[k] = v
        end
    end
end

---删除数组里的元素
function tremovedata(t, data)
    for i=#t,1,-1 do
        if t[i]==data then
            tremove(t, i)
        end
    end
end

---增加数据保证不重复, 如果插入了返回true
function tinsertdata(array, data)
    for i=1,#array do
        if(array[i]==data) then return end
    end
    tinsert(array, data);
    return true;
end

--- table1 has all table2 keys and values are same
function tcovers(table1, table2)
    for k,v in pairs(table2) do
        if v ~= table1[k] then
            return false
        end
    end
    return true
end

--将一个字符串中的正则特殊字符换掉
function escape_pattern(str)
    return str:gsub("%%", "%%%%"):gsub("%-","%%-"):gsub("%+","%%+"):gsub("%.","%%."):gsub("%[", "%%["):gsub("%]", "%%]"):gsub("%(", "%%("):gsub("%)", "%%)");
end
--忽略大小写的gsub
function nocase(s)
    return string.gsub(escape_pattern(s), "%a", function (c)
        return string.format("[%s%s]", string.lower(c),
            string.upper(c))
    end)
end
function uncolor(s)
    return s and s:gsub("|c%x%x%x%x%x%x%x%x(.-)|r", "%1") or nil
end
local function ExtractColorValueFromHex(str, index)
	return tonumber(str:sub(index, index + 1), 16) / 255;
end
function hex2rgba(hexColor)
    if #hexColor == 8 then
        local a, r, g, b = ExtractColorValueFromHex(hexColor, 1), ExtractColorValueFromHex(hexColor, 3), ExtractColorValueFromHex(hexColor, 5), ExtractColorValueFromHex(hexColor, 7);
        return r, g, b, a;
    else
        error("format should be AARRGGBB")
    end
end

function CoreBuildLocale(debug)
    return setmeta({ _DEBUG = debug and {} or nil }, {
        __index = function(self, key)
            if(debug) then tinsert(self._DEBUG, key) end
            return key
        end,
        __call = function(self, key) return self[key]  end
    })
end

function SetOrHookScript(target,eventName,func)
	if target:GetScript(eventName) then
		return target:HookScript(eventName,func)
	else
		return target:SetScript(eventName,func)
	end
end

--[[
	 xpcall safecall implementation
]]
local xpcall = xpcall

local function errorhandler(err)
    return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
    local code = [[
		local xpcall, eh = ...
		local method, ARGS
		local function call() return method(ARGS) end

		local function dispatch(func, ...)
			method = func
			if not method then return end
			ARGS = ...
			return xpcall(call, eh)
		end

		return dispatch
	]]

    local ARGS = {}
    for i = 1, argCount do ARGS[i] = "arg"..i end
    code = code:gsub("ARGS", table.concat(ARGS, ", "))
    return assert(loadstring(code, "safecall Dispatcher["..argCount.."]"))(xpcall, errorhandler)
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
    local dispatcher = CreateDispatcher(argCount)
    rawset(self, argCount, dispatcher)
    return dispatcher
end})
Dispatchers[0] = function(func)
    return xpcall(func, errorhandler)
end

function safecall(func, ...)
    return Dispatchers[select("#", ...)](func, ...)
end

---固定位数,相当于%02d里的02,基本不需要调用,通过n2s即可
function n2s_pad(str, length)
    length = length - #str
    if length > 0 then return n2s_pad_cache[length]..str else return str end
end
local n2s_02d = {} for i=0, 100 do n2s_02d[i]=format("%02d", i) end
---快速转换数字到字符串的
function n2s(n, pad, useceil)
    if n >= 0 then
        if n <= 100 then
            if pad then
                if pad==2 then return n2s_02d[n] end
                local str = n2s_small[n] or n2s_small[(useceil and ceil or floor)(n)]
                pad = pad - #str if pad > 0 then return n2s_pad_cache[pad]..str else return str end
            else
                return n2s_small[n] or n2s_small[(useceil and ceil or floor)(n)]
            end
        elseif n <=10000 then
            local n2s_res = n2s_big[n]
            if not n2s_res then
                n = (useceil and ceil or floor)(n)
                n2s_res = n2s_big[n]
                if not n2s_res then
                    n2s_res = format("%d", n)
                    n2s_big[(useceil and ceil or floor)(n)] = n2s_res
                end
            end
            if pad then
                pad = pad - #n2s_res if pad > 0 then return n2s_pad_cache[pad]..n2s_res else return n2s_res end
            else
                return n2s_res
            end
        else
            return format("%d", n)
        end
    else
        return ""..n --overflow
    end
end

---小数转换，与n2s区别是为了少一次判断，另外只节省1/4的效率, 100以下的一位小数会很快
function f2s(n, radius)
    radius = radius or 0
    if n>=0 and n<=100 and radius<=1 then
        if radius == 0 then
            return n2s_small[floor(n+0.5)]
        else
            local n2s_res = n2s_float[floor(n*10+.5)/10]
            if not n2s_res then
                n2s_res = format("%.1f", n)
                n2s_float[n] = n2s_res
            end
            return n2s_res
        end
    else
        return format(n2s_format[radius] or n2s_format[0], n)
    end
end

LibStub("AceTimer-3.0"):Embed(core)
function CoreScheduleTimer(repeating, delay, callback, arg)
    if(repeating)then
        return core:ScheduleRepeatingTimer(callback, delay, arg)
    else
        return core:ScheduleTimer(callback, delay, arg)
    end
end
function CoreCancelTimer(handle, silent)
    return core:CancelTimer(handle, silent);
end
local allTimers = {}
function CoreScheduleBucket(timerName, delay, callback, arg)
    if allTimers[timerName] then
        CoreCancelTimer(allTimers[timerName])
    end
    local timer = CoreScheduleTimer(false, delay, function(...) allTimers[timerName] = nil callback(...) end, arg)
    allTimers[timerName] = timer
    return timer
end

function CoreCancelBucket(timerName)
    if allTimers[timerName] then
        CoreCancelTimer(allTimers[timerName])
    end
end

core.frame = CreateFrame("Frame")
local runOnNextCount = 0
local runOnNextFrame = {}
local runOnNextKeyCount = 0
local runOnNextKey = setmetatable({}, {__newindex = function(t, k, v) rawset(t, k, v) runOnNextKeyCount=runOnNextKeyCount+1 end})
core.frame:SetScript("OnUpdate", function(self)
    if runOnNextKeyCount > 0 then
        for k,v in next, runOnNextKey do
            safecall(v, k);
            runOnNextKey[k] = nil
        end
        runOnNextKeyCount = 0;
    end
    if runOnNextCount > 0 then
        --通过oldCount可以解决func里继续runOnNextFrame的
        local oldCount = runOnNextCount
        for i=1, oldCount do
            local v = runOnNextFrame[i];
            if v[1] then
                safecall(v[1], select(2, unpack(v)));
            end
            wipe(v);
        end
        runOnNextCount = runOnNextCount - oldCount;
        --将后面新加的复制到列表前面
        for i=1, runOnNextCount do
            u1copy(runOnNextFrame[i+runOnNextCount], runOnNextFrame[i]);
            wipe(runOnNextFrame[i+runOnNextCount]);
        end
    end
end)

---下一帧调用的功能, 用于某些hook的时候要保证在过程之后运行的情况
function RunOnNextFrame(func, ...)
    --assert(type(func)=="function", "Parameter must be function.")
    runOnNextCount = runOnNextCount+1;
    local data=runOnNextFrame[runOnNextCount];
    if(not data)then
        data={};
        runOnNextFrame[runOnNextCount]=data;
    end
    data[1]=func;
    for i=1,select("#", ...) do
        data[i+1]=select(i, ...);
    end
end

function RunOnNextFrameKey(key, func)
    runOnNextKey[key] = func;
end

function RunOnNextFrameKeyCancel(key)
    runOnNextKey[key] = nil;
end

---简单的时间分发机制
--@param addon 具有addon:EVENT的对象.
local CoreDispatchEventFunc;
function CoreDispatchEvent(frame, addon)
    frame.addon = addon or frame;
    CoreDispatchEventFunc = CoreDispatchEventFunc or function(self, event, ...)
        local func = self.addon[event];
        if(type(func)=="function")then
            func(self.addon, event, ...);
        else
            func = self.addon.DEFAULT_EVENT;
            --assert(type(func)=="function", "没有事件["..event.."]的处理函数.");
            if(type(func)~="function") then
                print("No function for ["..event.."]");
                return
            end
            func(self.addon, event, ...);
        end
    end
    frame:SetScript("OnEvent", CoreDispatchEventFunc);
end

local eventRegistration = {}
function CoreAddEvent(event)
    eventRegistration[event] = eventRegistration[event] or {};
end
function CoreRegisterEvent(event, obj)
    local reg = eventRegistration[event];
    assert(reg, "No event '"..event.."' is defined.");
    tinsert(reg, (WW and WW.un) and WW:un(obj) or obj._F or obj);
    if event == "INIT_COMPLETED" and U1IsInitComplete() then
        local obj = reg[#reg]
        safecall(obj[event], obj);
    end
end
function CoreUnregisterEvent(event, obj)
    local reg = eventRegistration[event];
    assert(reg, "No event '"..event.."' is defined.");
    tremovedata(reg, WW and WW:un(obj) or obj._F or obj);
end
function CoreUnregisterAllEvents(obj)
    for k, v in pairs(eventRegistration) do
        CoreUnregisterEvent(k, obj);
    end
end
function CoreFireEvent(event, ...)
    --debug("event fired", event);
    local reg = eventRegistration[event];
    if(reg)then
        for i=1, #reg do
            local obj = reg[i]
            safecall(obj[event], obj, ...);
        end
    end
end

--在某个插件存在时调用，如果不存在，则等其加载
function CoreDependCall(addon, func, ...)
    local func = type(func) == "function" and func or _G[func];
    local func = type(func) == "function" and func or _G[func];
    if(C_AddOns.IsAddOnLoaded(addon) and type(func)=="function") then
        func(...)
    else
        local params = {...}
        CoreOnEvent("ADDON_LOADED", function(event, name)
            if(name:lower() == addon:lower())then
                func(unpack(params));
                return true;
            end
        end)
    end
end

--离开战斗后调用的函数，不支持参数
local leaveCombatCalls = {}
function CoreLeaveCombatCall(key, message, func)
    local func = type(func) == "function" and func or _G[func];
    assert(type(func)=="function", "param #2 should be function or function name.")
    if not InCombatLockdown() then
        safecall(func, key)
    else
        if message then U1Message(message) end
        leaveCombatCalls[key] = func;
    end
end

---CoreOnEvent("VARIABLE_LOADED", func(event, ...) return "REMOVE!" end);
---callback return true to remove.
local eventFuncs = {}
local eventBucket, checkBucket = {}, false --eventBucket[event] = { {[1]=func, [2]=interval, [3]=timeLeft, [4]=needEndCall,}, ...}
core.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
core.frame:SetScript("OnEvent", function(self, event, ...)
    if event=="PLAYER_REGEN_ENABLED" then
        for key, func in next, leaveCombatCalls do safecall(func, key) end
        wipe(leaveCombatCalls);
    end
    local eventTable = eventFuncs[event];
    if eventTable then
        local i = 1;
        while i<=#eventTable do
            local status, result = safecall(eventTable[i], event, ...);
            if status and result then
                tremove(eventTable, i);
            else
                i = i + 1;
            end
        end
    end
    local eventTable = eventBucket[event]
    if eventTable then
        for i=1,#eventTable do
            local v=eventTable[i]
            local timer = v[3]
            if timer == nil then
                safecall(v[1], event)
                v[3] = v[2] --重置timer为interval
                --v[4] = nil 这个不需要运行，必然是nil
            else
                v[4] = 1 --表示有未调用的，将在时间到后执行
            end
        end
    end
end)
CoreScheduleTimer(true, 0.2, function()
    if not checkBucket then return end
    for event, eventTable in pairs(eventBucket) do
        for i = 1, #eventTable do
            local v = eventTable[i]
            local timer = v[3];
            if timer then
                timer = timer - 0.1
                if timer<=0 then
                    if v[4] then
                        safecall(v[1], event);
                        v[4] = nil;
                        timer = v[2]; --继续保护
                    else
                        timer = nil
                    end
                end
                v[3] = timer
            end
        end
    end
end)

--第三个参数是为了利用模拟事件机制，在!!!163UI!!!以外调用时需添加
function CoreOnEvent(event, func, frame)
    if frame then
        if type(frame)=="table" then
            frame:RegisterEvent(event);
            frame[event] = func;
        else
            local f = CreateFrame("Frame");
            CoreDispatchEvent(f)
            f:RegisterEvent(event);
            f[event] = func;
            return f;
        end
    end

    if(not core.frame:IsEventRegistered(event)) then
        core.frame:RegisterEvent(event);
    end
    local eventTable = eventFuncs[event];
    if(eventTable==nil)then eventTable={} eventFuncs[event]=eventTable end
    tinsert(eventTable, func);
end

---注册一个最大调用间隔为interval的事件，暂时没有反注册机制
--而且，注意func只能接受一个参数event,不能接受其他的
function CoreOnEventBucket(event, interval, func)
    if(not core.frame:IsEventRegistered(event)) then
        core.frame:RegisterEvent(event);
    end
    local eventTable = eventBucket[event];
    if(eventTable==nil) then eventTable={} eventBucket[event]=eventTable end
    tinsert(eventTable, {func, interval, 0})
    checkBucket = next(eventBucket) and true
end

local petBattleHideFrames = {}
CoreOnEvent("PET_BATTLE_OPENING_START", function()
    for frame, _ in pairs(petBattleHideFrames) do
        frame._previous_state = frame:IsShown()
        if not issecurevariable(frame, "Show") and not frame._163show then
            frame._163show = frame.Show
            frame.Show = noop
        end
        frame:Hide()
    end
end)

CoreOnEvent("PET_BATTLE_CLOSE", function()
    for frame, _ in pairs(petBattleHideFrames) do
        if frame._163show then
            frame.Show = frame._163show
            frame._163show = nil
        end
        if frame._previous_state then
            frame:Show()
            frame._previous_state = nil
        end
    end
end)

function CoreHideOnPetBattle(frame)
    if not frame or not frame.Show then return end
    petBattleHideFrames[frame] = true
end

---转换为浏览器地址
function EncodeURL(obj)
    local currentIndex = 1;
    local charArray = {}
    while currentIndex <= #obj do
        local char = string.byte(obj, currentIndex);
        charArray[currentIndex] = char
        currentIndex = currentIndex + 1
    end
    local converchar = "";
    for _, char in ipairs(charArray) do
        converchar = converchar..string.format("%%%X", char)
    end
    return converchar;
end

--不需要恢复的非安全Hook
function CoreRawHook(obj, name, func, isscript)
    if type(obj) == "string" then name, func, isscript, obj = obj, name, func, _G end
    if DEBUG_MODE and not isscript and name:find("^On") then print(L["忘记设置isscript了？"], name) end
    if isscript then
        local origin = obj:GetScript(name)
        if not origin then
            obj:SetScript(name, func)
        else
            obj:SetScript(name, function(...) origin(...) return func(...) end)
        end
    else
        local origin = obj[name]
        if not origin then
            obj[name] = func
        else
            obj[name] = function(...) local a1,a2,a3,a4,a5,a6,a7,a8,a9 = origin(...) func(...) return a1,a2,a3,a4,a5,a6,a7,a8,a9 end
        end
    end
end
CoreGlobalHooks = {}
--注意，如果在Cfg里执行togglehook那么会导致cpu占用被算到!!!163UI!!!上
--可以重复hook和togglehook, self是一个用来保存hook指针的对象
--当需要把一个操作屏蔽时, disable里调用hook(nil, name, noop);
--然后enable里调用unhook(nil, name), 保证重复hook不会丢失origin
--存在store._copies[name]说明unhook了, 可以rehook
function hook(store, name, func)
    assert(type(_G[name])=="function", "Bad arg1, string function name expected")
    assert(type(func)=="function", "Bad arg2, function expected")

    store = store or CoreGlobalHooks;

    store._origins = store._origins or {}
    store._hooks = store._hooks or {}
    store._copies = store._copies or {} --hook的备份

    if not store._origins[name] then
        store._origins[name] = _G[name]
        _G[name] = function(...) return store._hooks[name](...) end
    end

    store._hooks[name] = func
end
function unhook(store, name)
    store = store or CoreGlobalHooks;
    if not store._origins or not store._origins[name] then return end --尚未hook过
    if store._copies and store._copies[name] then return end --不能重复的unhook, 会导致hook丢失
    store._copies[name] = store._hooks[name];
    store._hooks[name] = store._origins[name];
end
function rehook(store, name, func)
    store = store or CoreGlobalHooks;
    if not store._origins or not store._origins[name] then
        --尚未hook过
        if(func)then hook(store, name, func) end
        return
    end
    if not store._copies or not store._copies[name] then return end --尚未unhook过
    store._hooks[name] = store._copies[name]
    store._copies[name] = nil;
end
function togglehook(store, name, func, tohook)
    if tohook then rehook(store, name, func) else unhook(store, name) end
end
---secure和script共用的hook方法
--@param hooktype hooksecurefunc/HookScript
--@param store 用来保存hook的信息以便unhook
--@param object hooksecure(object) or object:HookScript里的object
--@param name 全局函数名或ScriptHandler名
--@param func 要hook的函数
--@param tohook 是否hook
function toggleposthook(hooktype, store, object, name, func, tohook)
    assert(type(store)=="table", "para #1 store must be a table.")
    if object == nil then object = "NIL" end
    store[object] = store[object] or {}
    if not store[object][name] then
        --只在第一次进行具体的hook操作
        store[object][name] = {func, tohook }
        --所有的都是
        local func = function(...) if(store[object][name][2]) then store[object][name][1](...) end end
        if hooktype =="hooksecurefunc" then
            if object == "NIL" then
                hooksecurefunc(name, func)
            else
                hooksecurefunc(object, name, func)
            end
        else
            object:HookScript(name, func)
        end
    else
        store[object][name][1] = func
        store[object][name][2] = tohook
    end
end
function togglesecurehook(store, object, name, func, tohook) return toggleposthook("hooksecurefunc", store, object, name, func, tohook) end
function togglescripthook(store, object, name, func, tohook) return toggleposthook("HookScript", store, object, name, func, tohook) end

function CoreCall(funcName, ...)
    local func = _G[funcName]
    return func and func(...);
end

--- 自动判断是SetScript还是HookScript，如果提供keep参数，则会防止SetScript冲掉原来的Hook
function CoreHookScript(frame, scriptName, func, keep)
    if( frame:GetScript(scriptName) ) then
        frame:HookScript(scriptName, func);
    else
        frame:SetScript(scriptName, func);
    end
    if keep then
        hooksecurefunc(frame, "SetScript", function(self, name)
            if name==scriptName then
                self:HookScript(scriptName, func)
            end
        end)
    end
end

local function createEnumAndHookClosure(creationFuncHook)
    local flag = "_aby_hooked"
    return function (pool, includeInactive)
        RunNextFrame(function()
            for one in pool:EnumerateActive() do
                if not one[flag] then
                    creationFuncHook(one, pool.frameType, pool.frameTemplate)
                    one[flag] = true
                end
            end
            if includeInactive ~= "includeInactive" then return end
            for _, one in pool:EnumerateInactive() do
                if not one[flag] then
                    creationFuncHook(one, pool.frameType, pool.frameTemplate)
                    one[flag] = true
                end
            end
        end)
    end
end
--- @param creationFuncHook function(obj, frameType, template) 新创建对象时会调用此方法
function CoreUIHookPoolCollection(poolCollection, creationFuncHook)
    local enumAndHook = createEnumAndHookClosure(creationFuncHook)
    for poolKey, pool in pairs(poolCollection.pools) do
        hooksecurefunc(pool, "creationFunc", enumAndHook)
        enumAndHook(pool, "includeInactive")
    end
    hooksecurefunc(poolCollection, "CreatePool", function(self, frameType, parent, template, resetterFunc, forbidden, specialization)
        local pool = self:GetPool(template, specialization)
        if pool then
            hooksecurefunc(pool, "creationFunc", enumAndHook)
        end
    end)
end

function CoreUIHookPool(pool, creationFuncHook)
    local enumAndHook = createEnumAndHookClosure(creationFuncHook)
    hooksecurefunc(pool, "creationFunc", enumAndHook)
    enumAndHook(pool, "includeInactive")
end

--[[------------------------------------------------------------
 TimeCache
---------------------------------------------------------------]]
do
    local tcache = {}
    local tcache_expires = {}
    function CoreCacheSet(key, value, duration)
        tcache[key] = value
        if value == nil then
            tcache_expires[key] = nil
        else
            tcache_expires[key] = GetTime() + duration
        end
    end
    function CoreCacheGet(key)
        local et = tcache_expires[key]
        if et then
            if type(et) == "table" then error("Cached value is a list") end
            if et >= GetTime() then
                return tcache[key]
            else
                tcache[key] = nil
                tcache_expires[key] = nil
            end
        end
    end
    function CoreCacheListSet(key, value, duration)
        tcache[key] = tcache[key] or {}
        tcache[key][#tcache[key]+1] = value
        tcache_expires[key] = tcache_expires[key] or {}
        tcache_expires[key][#tcache_expires[key]+1] = GetTime() + duration
    end
    function CoreCacheListRemove(key, index)
        local et = tcache_expires[key]
        if et then
            if type(et) ~= "table" then error("Cached value is not a list") end
            table.remove(et, index)
            table.remove(tcache[key], index)
        end
    end
    function CoreCacheListGet(key)
        local et = tcache_expires[key]
        if et then
            if type(et) ~= "table" then error("Cached value is not a list") end
            local i = 1
            while( i <= #et ) do
                if et[i] < GetTime() then
                    table.remove(et, i)
                    table.remove(tcache[key], i)
                else
                    i = i + 1
                end
            end
        end
        return tcache[key]
    end
    CoreScheduleTimer(true, 10, function()
        for k,v in pairs(tcache_expires) do
            if type(v) == "table" then
                CoreCacheListGet(k)
            else
                CoreCacheGet(k)
            end
        end
    end)
end

--[[
hooksecurefunc(Minimap, "SetBlipTexture", function(self, ...) self._blipTexture = ... end)
function CoreIsTextureExists(name)
    local old = Minimap._blipTexture or "interface\\minimap\\objecticons"
    local status = pcall(Minimap.SetBlipTexture, Minimap, name)
    Minimap:SetBlipTexture(old)
    return status
end
--]]

core.frame.tex = core.frame:CreateTexture()
function CoreIsTextureExists(picAddOn, name)
    return false --select(5, GetAddOnInfo(picAddOn))~="MISSING" and U1IsAddonRegistered(name) and not U1GetAddonInfo(name).nopic;
end

function CoreEncodeHTML(s, keepColor)
    if not keepColor then
        s = s:gsub("|c%x%x%x%x%x%x%x%x%[(.-)%]|r", "%1"):gsub("|c%x%x%x%x%x%x%x%x(.-)|r", "%1")
    end
    s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    return s;
end

function CoreIsFrameIntersects(frame1, frame2)
    --左下角为0, bottom > top 不向交
    if frame1:GetLeft() == nil or frame1:GetTop() == nil then return false end
    if frame2:GetLeft() == nil or frame2:GetTop() == nil then return false end

    return not (
        frame1:GetLeft() > frame2:GetRight() or
        frame1:GetRight() < frame2:GetLeft() or
        frame1:GetTop() < frame2:GetBottom() or
        frame1:GetBottom() > frame2:GetTop()
    );
end

--[[------------------------------------------------------------
自定义荣誉称号
---------------------------------------------------------------]]
core.funcs = {} --for Donators
U1STAFF={
    ["加冰的茉莉茶-伊森利恩"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的橙汁-伊森利恩"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的可乐-伊森利恩"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的鲜橙多-伊森利恩"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的喜茶-伊森利恩"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的龙井茶-伊森利恩"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的二锅头-末日行者"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的酸梅汁-末日行者"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的雪碧-末日行者"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的牛奶-末日行者"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的苹果汁-末日行者"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的柚子茶-末日行者"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的竹叶青-雷霆之王"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的玉米汁-雷霆之王"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的雪碧-雷霆之王"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的酒鬼酒-雷霆之王"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的茅台-雷霆之王"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的优酪乳-雷霆之王"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的红牛-雷霆之王"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r", ["加冰的柠檬汁-伊森利恩"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00整|r|cff96ff00合|r|cff3cff00包|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r",
    ["养一只小月亮-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r", ["一抹微笑-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r", ["小桃婲-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r", ["梨涡浅浅-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r", ["雨淇-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r", ["龙莉娅-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r", ["我的棒棒糖呢-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r", ["小芙-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r", ["小芙蝶-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r", ["杨梅-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r", ["小桑果-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r", ["西梅-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r", ["奶黄包-伊森利恩"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00小|r|cff3cff00芙|r|cff00ffd2蝶|r|cFFFFFF00★|r",
    ["身騎白馬-霜之哀伤"]="|cFFFFFF00★|r|cffff5900Wow114.com|r|cffffb300魔兽导航及资料站|r|cFFFFFF00★|r", ["到此為止-霜之哀伤"]="|cFFFFFF00★|r|cffff5900Wow114.com|r|cffffb300魔兽导航及资料站|r|cFFFFFF00★|r", ["行走的魚-霜之哀伤"]="|cFFFFFF00★|r|cffff5900Wow114.com|r|cffffb300魔兽导航及资料站|r|cFFFFFF00★|r", ["尋人啟事-霜之哀伤"]="|cFFFFFF00★|r|cffff5900Wow114.com|r|cffffb300魔兽导航及资料站|r|cFFFFFF00★|r", ["以上皆非-霜之哀伤"]="|cFFFFFF00★|r|cffff5900Wow114.com|r|cffffb300魔兽导航及资料站|r|cFFFFFF00★|r", ["你敢不敢-霜之哀伤"]="|cFFFFFF00★|r|cffff5900Wow114.com|r|cffffb300魔兽导航及资料站|r|cFFFFFF00★|r",
    ["丶红酥手丶-死亡之翼"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300哥|r|cfff0ff00的|r|cff96ff00资|r|cffffb300深|r|cfff0ff00舔|r|cff96ff00狗|r|cFFFFFF00★|r",
    ["冷调丶-斯坦索姆"]="|cFFFFFF00★|r|cffff5900整|r|cffffb300点|r|cfff0ff00薯|r|cff96ff00条|r|cFFFFFF00★|r",
    ["Zireael-泰兰德"]="|cFFFFFF00★|r|cffff5900KeiraMetz|r|cffffb300@|r|cfff0ff00NGA|r|cff96ff00-|r|cff3cff00资|r|cffFF6BED深|r|cffffb300插|r|cfff0ff00件|r|cff96ff00专|r|cff3cff00家|r|cFFFFFF00★|r",
    ["猪头洋-罗宁"]="|cFFFFFF00★|r|cffff5900艾|r|cffffb300泽|r|cfff0ff00拉|r|cff96ff00斯|r|cffffb300救|r|cfff0ff00世|r|cff96ff00主|r|cFFFFFF00★|r", ["扑街仔-罗宁"]="|cFFFFFF00★|r|cffff5900艾|r|cffffb300泽|r|cfff0ff00拉|r|cff96ff00斯|r|cffffb300救|r|cfff0ff00世|r|cff96ff00主|r|cFFFFFF00★|r",
    ["妖乀月-白银之手"]="|cFFFFFF00★|r|cffff5900闻|r|cffffb300名|r|cfff0ff00遐|r|cff96ff00迩|r|cff3cff00的|r|cffFF6BED艾|r|cffff5900泽|r|cffffb300拉|r|cfff0ff00斯|r|cff96ff00守|r|cffffb300护|r|cfff0ff00之|r|cff96ff00神|r|cFFFFFF00★|r",
    ["小科科很威武-凤凰之神"]="|cFFFFFF00★|r|cffff5900神|r|cffffb300话|r|cfff0ff00粉|r|cff96ff00丝|r|cFFFFFF00★|r",
    ["東皇太一-霜之哀伤"]="|cFFFFFF00★|r|cffff5900双|r|cffffb300持|r|cfff0ff00灰|r|cff96ff00烬|r|cff3cff00使|r|cffFF6BED者|r|cFFFFFF00★|r", ["黛迪-永恒之井"]="|cFFFFFF00★|r|cffff5900看|r|cffffb300我|r|cfff0ff00眼|r|cff96ff00色|r|cff3cff00行|r|cffFF6BED事|r|cFFFFFF00★|r", ["知心大姐姐-霜之哀伤"]="|cFFFFFF00★|r|cffff5900敏|r|cffffb300感|r|cfff0ff00且|r|cff96ff00善|r|cff3cff00变|r|cFFFFFF00★|r", ["玄乎套-霜之哀伤"]="|cFFFFFF00★|r|cffff5900别|r|cffffb300整|r|cfff0ff00那|r|cff96ff00个|r|cff3cff00玄|r|cffFF6BED乎|r|cffffb300套|r|cFFFFFF00★|r", ["柳如嫣-永恒之井"]="|cFFFFFF00★|r|cffff5900龙|r|cffffb300傲|r|cfff0ff00天|r|cFFFFFF00★|r",
    ["芭万希-无尽之海"]="|cFFFFFF00★|r|cffff5900魔|r|cffffb300兽|r|cfff0ff00世|r|cff96ff00界|r|cff3cff00人|r|cffFF6BED美|r|cffff5900心|r|cffffb300善|r|cfff0ff00玩|r|cff96ff00家|r|cFFFFFF00★|r",
    ["愛辣椒的熊寶-伊森利恩"]="|cFFFFFF00★|r|cffff5900明|r|cffffb300哥|r|cfff0ff00天|r|cff96ff00天|r|cff3cff00向|r|cffFF6BED上|r|cFFFFFF00★|r", ["熊寶丶愛辣椒-伊森利恩"]="|cFFFFFF00★|r|cffff5900明|r|cffffb300哥|r|cfff0ff00天|r|cff96ff00天|r|cff3cff00向|r|cffFF6BED上|r|cFFFFFF00★|r",
    ["离酱嘤嘤樱丶-国王之谷"]="|cFFFFFF00★|r|cffff5900单|r|cffffb300体|r|cfff0ff00矮|r|cff96ff00人|r|cFFFFFF00★|r",
    ["影踪酒仙-凤凰之神"]="|cFFFFFF00★|r|cffff5900影|r|cffffb300踪|r|cfff0ff00派|r|cff96ff00掌|r|cff3cff00门|r|cFFFFFF00★|r",
    ["回忆中的旧时-翡翠梦境"]="|cFFFFFF00★|r|cffff5900耐|r|cffffb300瑟|r|cfff0ff00瑞|r|cff96ff00尔|r|cff3cff00遗|r|cffFF6BED民|r|cFFFFFF00★|r",
    ["兜糖嘤嘤樱丶-国王之谷"]="|cFFFFFF00★|r|cffff5900萌|r|cffffb300新|r|cFFFFFF00★|r",
    ["闹闹卝条子-暗影之月"]="|cFFFFFF00★|r|cffff5900老|r|cffffb300农|r|cfff0ff00赞|r|cff96ff00美|r|cff3cff00者|r|cFFFFFF00★|r",
    ["梅塔特隆-加里索斯"]="|cFFFFFF00★|r|cffff5900手|r|cffffb300残|r|cfff0ff00大|r|cff96ff00领|r|cff3cff00主|r|cFFFFFF00★|r",
    ["梦里奔跑的树-回音山"]="|cFFFFFF00★|r|cffff5900沐|r|cffffb300风|r|cFFFFFF00★|r", ["姝荼染尘-霜之哀伤"]="|cFFFFFF00★|r|cffff5900沐|r|cffffb300风|r|cFFFFFF00★|r",
    ["帝火剑-国王之谷"]="|cFFFFFF00★|r|cffff5900防|r|cffffb300爆|r|cfff0ff00战|r|cFFFFFF00★|r",
    ["暴躁滴牙牙-死亡之翼"]="|cFFFFFF00★|r|cffff5900艾|r|cffffb300泽|r|cfff0ff00拉|r|cff96ff00斯|r|cff3cff00路|r|cff96ff00盲|r|cFFFFFF00★|r",
    ["傲雪灬牛牛-克尔苏加德"]="|cFFFFFF00★|r|cffff5900大|r|cffffb300德|r|cfff0ff00鲁|r|cff96ff00伊|r|cFFFFFF00★|r",
    ["草东-白银之手"]="|cFFFFFF00★|r|cffFF7D00GroupFinder（队伍查找器）|r|cff00ffd2 - |r|cffFF6BED作|r|cffFF546A者|r|cFFFFFF00★|r",
}

--抖音主播名单
U1STAFFDY={
    ["斜月如霜-伊森利恩"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00just one|r|cFFFFFF00★|r",
    ["冰曦乄格格-死亡之翼"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00格格 yoyobart（抖音号：15646843）|r|cFFFFFF00★|r", ["格格乄孜萱-死亡之翼"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00格格 yoyobart（抖音号：15646843）|r|cFFFFFF00★|r",
    ["全体起立-蓝龙军团"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00黑黑的黑|r|cFFFFFF00★|r",
    ["买买点穴-冰风岗"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00小鱼人买买（魔兽世界）|r|cFFFFFF00★|r",
    ["月隐雷灬-死亡之翼"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00LoRexxar|r|cFFFFFF00★|r", ["炎色雷灬-死亡之翼"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00LoRexxar|r|cFFFFFF00★|r",
    ["髦血尪-血色十字军"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00腿毛妇人|r|cFFFFFF00★|r",
    ["魔兽小恶龙-伊森利恩"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽小恶龙|r|cFFFFFF00★|r", ["魔兽小恶龙-神圣之歌"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽小恶龙|r|cFFFFFF00★|r", ["魔兽小恶龙-罗宁"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽小恶龙|r|cFFFFFF00★|r", ["魔兽小恶龙啊-白银之手"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽小恶龙|r|cFFFFFF00★|r", ["小恶龙啵啵酱-索瑞森"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽小恶龙|r|cFFFFFF00★|r",
    ["老张头子-白银之手"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00老张头子（魔兽世界）|r|cFFFFFF00★|r", ["老张头来了-白银之手"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00老张头子（魔兽世界）|r|cFFFFFF00★|r",
    ["穆禹千骑、-凤凰之神"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00熊小仙|r|cFFFFFF00★|r",
    ["圣光丶血蹄-闪电之刃"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00鲨鱼辣椒（魔兽世界）|r|cFFFFFF00★|r", ["鲨鱼丶辣椒-闪电之刃"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00鲨鱼辣椒（魔兽世界）|r|cFFFFFF00★|r", ["牛牛向前冲-闪电之刃"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00鲨鱼辣椒（魔兽世界）|r|cFFFFFF00★|r",
    ["凹凸丶-无尽之海"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00凹凸丶|r|cFFFFFF00★|r",
    ["晴天丶飞雪-诺莫瑞根"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00晴天飞雪（魔兽世界）|r|cFFFFFF00★|r",
    ["抖音老妖魔獣-罗宁"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00老妖魔兽|r|cFFFFFF00★|r",
    ["老衲饮酒-血色十字军"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00王王老五（魔兽世界）|r|cFFFFFF00★|r", ["王老五丶-血色十字军"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00王王老五（魔兽世界）|r|cFFFFFF00★|r", ["莽撞人小王-血色十字军"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00王王老五（魔兽世界）|r|cFFFFFF00★|r", ["莽撞人王某人-血色十字军"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00王王老五（魔兽世界）|r|cFFFFFF00★|r",
    ["墨緯-红龙军团"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00爱玩游戏的小明同学|r|cFFFFFF00★|r",
    ["黄瓜呀丶-燃烧之刃"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00黄瓜-魔兽世界|r|cFFFFFF00★|r",
    ["感到幸福-凤凰之神"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00感到幸福|r|cFFFFFF00★|r",
    ["闪耀波丽露-冰霜之刃"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽米拉珍（擦边主播）|r|cFFFFFF00★|r", ["米拉丶赛利翁-冰霜之刃"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽米拉珍（擦边主播）|r|cFFFFFF00★|r", ["魔人米拉珍-主宰之剑"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽米拉珍（擦边主播）|r|cFFFFFF00★|r", ["范伟打天下丶-破碎岭"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽米拉珍（擦边主播）|r|cFFFFFF00★|r", ["斩男涩-破碎岭"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽米拉珍（擦边主播）|r|cFFFFFF00★|r", ["渣女培训手册-破碎岭"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽米拉珍（擦边主播）|r|cFFFFFF00★|r", ["米拉珍喜悦-白银之手"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽米拉珍（擦边主播）|r|cFFFFFF00★|r", ["带派不老铁-破碎岭"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽米拉珍（擦边主播）|r|cFFFFFF00★|r", ["老蒯吃饭啦-破碎岭"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽米拉珍（擦边主播）|r|cFFFFFF00★|r",
    ["抖音丶玄灵沐-无尽之海"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00玄灵沐沐（魔兽世界）|r|cFFFFFF00★|r", ["玄灵沐沐-无尽之海"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00玄灵沐沐（魔兽世界）|r|cFFFFFF00★|r",
    ["冬瓜骑士-轻风之语"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00冬瓜仔|r|cFFFFFF00★|r",
    ["灬影子灬-燃烧之刃"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00影子魔兽|r|cFFFFFF00★|r", ["吃配吃土-燃烧之刃"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00影子魔兽|r|cFFFFFF00★|r",
    ["文人魔客-罗宁"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00文人魔客|r|cFFFFFF00★|r", ["文人魔客-凤凰之神"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00文人魔客|r|cFFFFFF00★|r", ["文人魔客-白银之手"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00文人魔客|r|cFFFFFF00★|r",
    ["离人心上秋-燃烧之刃"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00懒惰的小樱|r|cFFFFFF00★|r",
    ["穿名堂丶-白银之手"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00小名战士|r|cFFFFFF00★|r",
    ["深秋-戈提克"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00艾泽拉斯的野男人|r|cFFFFFF00★|r", ["南宫恨-戈提克"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00艾泽拉斯的野男人|r|cFFFFFF00★|r",
    ["套路过张柏芝-凤凰之神"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00Even|r|cFFFFFF00★|r", ["爱慕过张柏芝-凤凰之神"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00Even|r|cFFFFFF00★|r", ["我就伸伸-凤凰之神"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00Even|r|cFFFFFF00★|r", ["迷恋过张柏芝-白银之手"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00Even|r|cFFFFFF00★|r", ["不能射的秘密-白银之手"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00Even|r|cFFFFFF00★|r", ["丿心上人灬-白银之手"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00Even|r|cFFFFFF00★|r",
    ["华丽华尔兹-燃烧之刃"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00芯馨|r|cFFFFFF00★|r",
    ["马尔戈隆-加尔"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00随风@黑骑士|r|cFFFFFF00★|r",
    ["瘾大-迅捷微风"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00瘾大|r|cFFFFFF00★|r",
    ["一只璇璇酱-燃烧之刃"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00璇璇酱（魔兽世界版）|r|cFFFFFF00★|r",
    ["三十瓦-白银之手"]="|cFFFFFF00★|r|cffff5900抖|r|cffffb300音|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00肖小月|r|cFFFFFF00★|r",
}

--B站主播名单
U1STAFFBZ={
    ["胖尔萨斯-迦拉克隆"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00魔兽海川|r|cFFFFFF00★|r",
    ["戚家军-无尽之海"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00武僧戚家军|r|cFFFFFF00★|r",
    ["山川神冢丶-亡语者"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00山川神冢|r|cFFFFFF00★|r",
    ["Bigmage-白银之手"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00HWiNFO|r|cFFFFFF00★|r", ["至此已成艺术-死亡之翼"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00HWiNFO|r|cFFFFFF00★|r",
    ["铁牛小和尚-贫瘠之地"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00铁牛爸爸666|r|cFFFFFF00★|r",
    ["光之尘曦-凤凰之神"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00诶哟-北风嘛|r|cFFFFFF00★|r", ["乜芝麻的烧饼-末日行者"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00诶哟-北风嘛|r|cFFFFFF00★|r", ["真的不会法斯-罗宁"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00诶哟-北风嘛|r|cFFFFFF00★|r", ["神奇皮卡丘-凤凰之神"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00诶哟-北风嘛|r|cFFFFFF00★|r", ["潇潇北风-凤凰之神"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00诶哟-北风嘛|r|cFFFFFF00★|r", ["丷池寒枫丷-凤凰之神"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00诶哟-北风嘛|r|cFFFFFF00★|r", ["落叶蘸秋风-格瑞姆巴托"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00诶哟-北风嘛|r|cFFFFFF00★|r", ["從未被超越-罗宁"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00诶哟-北风嘛|r|cFFFFFF00★|r", ["真的不会木诗-布兰卡德"]="|cFFFFFF00★|r|cffff5900B|r|cffffb300站|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00诶哟-北风嘛|r|cFFFFFF00★|r",
}

--斗鱼主播名单
U1STAFFDYZ={
	["昭昭素月明-燃烧之刃"]="|cFFFFFF00★|r|cffff5900斗|r|cffffb300鱼|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00无虞zzz|r|cFFFFFF00★|r", ["岁岁不知春-白银之手"]="|cFFFFFF00★|r|cffff5900斗|r|cffffb300鱼|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00无虞zzz|r|cFFFFFF00★|r",
	["小天真-伊森利恩"]="|cFFFFFF00★|r|cffff5900斗|r|cffffb300鱼|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00小天真么么哒（魔兽世界第一大美女）|r|cFFFFFF00★|r",
	["圣亞爱乐-试炼之环"]="|cFFFFFF00★|r|cffff5900斗|r|cffffb300鱼|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00圣亚爱乐|r|cFFFFFF00★|r",
	["记忆酱-凤凰之神"]="|cFFFFFF00★|r|cffff5900斗|r|cffffb300鱼|r|cfff0ff00主|r|cff96ff00播|r|cff3cff00：|r|cffFF7D00寂寞de记忆|r|cFFFFFF00★|r",
}

function U1AddDonatorTitle(self, partOrFullName, returnOnly)
    if self._ChangingByAbyUI then return end
    if partOrFullName then
        if not partOrFullName:find("%-") then
            partOrFullName = partOrFullName .. "-" .. GetRealmName()
        end
        local aby = U1GetDonatorTitles(partOrFullName)
        if aby then self:AddLine(aby, 0.1,0.8,0.98) end  --显示颜色
        if not self.fadeOut then self._ChangingByAbyUI = 1 self:Show() self._ChangingByAbyUI = nil end
    end
end

RunOnNextFrame(function()
    CoreRegisterEvent("INIT_COMPLETED", { INIT_COMPLETED = function()
        CoreScheduleTimer(false, 1, function()
            --【修改1】修复副本中secret value报错：用pcall包裹TooltipUtil.GetDisplayedUnit
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip, tData)
                -- 12.0副本中unit可能为secret value，TooltipUtil.GetDisplayedUnit内部调用UnitName会报错
                local ok, _, unit = pcall(TooltipUtil.GetDisplayedUnit, tip)
                if not ok or not unit then return end
                if issecretvalue and issecretvalue(unit) then return end
                local ok2, isPlayer = pcall(UnitIsPlayer, unit)
                if not ok2 or not isPlayer then return end --or not self:IsVisible()
                U1AddDonatorTitle(tip, U1UnitFullName(unit))
            end)
            hooksecurefunc(GameTooltip, "Show", function(self)
                local owner = self:GetOwner()
                if owner and owner.GetMemberInfo then
                    local memberInfo = owner:GetMemberInfo()
                    if memberInfo then
                        U1AddDonatorTitle(self, memberInfo.name)
                    end
                end
            end)
        end)
    end })
end)

local debugFrame = CreateFrame("Frame")
local fpsStartTime, fpsCount, fpsTotalCount, fpsTotalTime = nil, 0, 0, 0 --战斗帧数统计
debugFrame:SetScript("OnUpdate", function(self)
    if fpsStartTime then fpsCount = fpsCount + 1 end
end)

debugFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
debugFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
debugFrame:SetScript("OnEvent", function(self, event, ...)
    if event=="PLAYER_REGEN_ENABLED" then
        if fpsStartTime and DEBUG_MODE then
            local time = GetTime() - fpsStartTime;
            local fps = fpsCount / time
            fpsTotalCount = fpsTotalCount + fpsCount
            fpsTotalTime = fpsTotalTime + time
            fpsStartTime = nil
            if time>10 then
                U1Message(format("本次战斗帧数: %.1f，平均: %.1f", fpsCount/time, fpsTotalCount/fpsTotalTime))
            end
            fpsCount = 0
        end
    elseif event=="PLAYER_REGEN_DISABLED" then
        fpsStartTime = GetTime()
    end
end)

--将一个数字保存进cvar里.只支持整数
function CoreSetParaParam(cvar, data, start, len)
    local c = GetCVar(cvar)
    local p = c:find("%.")
    local frac = strsub(c, p + 1);
    --如果前面位数不够则补零，比如从第3位开始，但是只有1位，则补一个0
    if frac:len() < start - 1 then
        frac = frac..strrep("0", start - 1 - frac:len());
    end
    frac = strsub(frac, 1, start-1)..format("%0"..len.."d", data)..strsub(frac, start + len)
    SetCVar(cvar, c:sub(1, p)..frac);
end
function CoreGetParaParam(cvar, start, len)
    local c = GetCVar(cvar)
    local p = c:find("%.")
    if not p then return 0 end
    local frac = strsub(c, p + 1);
    --如果前面位数不够则补零，比如从第3位开始，但是只有1位，则补一个0
    if frac:len() < start + len - 1 then
        frac = frac..strrep("0", start + len - 1 - frac:len());
    end
    return tonumber(strsub(frac, start, start + len - 1));
end

--- 此方法是为了防止战斗中初次调用时，会无法设置
function CoreUIGetUIPanelWindowInfo(frame, name)
	if ( not frame:GetAttribute("UIPanelLayout-defined") ) then
	    local info = UIPanelWindows[frame:GetName()];
	    if ( not info ) then
			return;
	    end
		frame:SetAttribute("UIPanelLayout-defined", true);
	    for name,value in pairs(info) do
			frame:SetAttribute("UIPanelLayout-"..name, value);
		end
	end
	return frame:GetAttribute("UIPanelLayout-"..name);
end

------------ from RunSecond --------------
--防止战斗中初次调用时，会无法设置
if CoreUIGetUIPanelWindowInfo then
    for k, v in pairs(UIPanelWindows) do
        if _G[k] then CoreUIGetUIPanelWindowInfo(_G[k], "area"); end
    end
end


-- 避免误操作关闭taint的插件
if(StaticPopupDialogs) then
    StaticPopupDialogs["ADDON_ACTION_FORBIDDEN"].OnAccept = function() end
end

hooksecurefunc("AddonTooltip_Update", function(owner)
	local name, title, notes, _, _, security = C_AddOns.GetAddOnInfo(owner:GetID());
	if title then AddonTooltip:AddLine(L["目录"] .. ": " .. name) end
end)

--[[------------------------------------------------------------
Addon Support
---------------------------------------------------------------]]
--用来检查数据的版本
function U1CheckVersionedData(data, version)
    if data and data._build and data._version then
        local c1, c2 = strsplit(".", (GetBuildInfo()))
        local d1, d2 = strsplit(".", data._build)
        if c1==d1 and c2==d2 and data._version==version then
            return true
        end
    end
end

function U1SaveVersionedData(data, version)
    data._build = GetBuildInfo()
    data._version = version
end

--【修改2】修复副本中secret value报错：用pcall包裹UnitName
function U1UnitFullName(unit)
    local ok, name, realm = pcall(UnitName, unit)
    if not ok or not name then return nil end
    return name .. "-" .. (realm and realm~="" and realm or GetRealmName())
end