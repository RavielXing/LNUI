RequestProtection = {}
local RP = RequestProtection
local debug = function() end
local submitRequest, doneRequest --private declaration
local stats = {} --各个函数调用状态
local mirror = {} --事件映射回API
local enteredWorld = IsLoggedIn()

--要保护的函数和对应的事件
local PROTECT_LIST = {
    SetAchievementComparisonUnit = {
        event = "INSPECT_ACHIEVEMENT_READY",
        pattern = "UIParent%.lua:%d-: in function `InspectAchievements'",
        guid_getter = function(...) return UnitGUID(...) end,
        timeout = 120,
        interval = 5,
        clear = "ClearAchievementComparisonUnit"
    },
}

local function scheduleOrBlock(schedule, name, reqFuncOrArgs, callback)
    assert(PROTECT_LIST[name], "This function is not protected.")
    local stat = stats[name]
    if stat.timeout or stat.interval then
        if schedule then
            table.insert(stat.queue, {reqFuncOrArgs, callback})
        else
            RunOnNextFrame(callback, false, "blocked")
        end
    else
        submitRequest(name, reqFuncOrArgs, callback, true)
    end
end

function RP:Schedule(name, reqFuncOrArgs, callback)
    scheduleOrBlock(true, name, reqFuncOrArgs, callback)
end

function RP:Call(name, reqFuncOrArgs, callback)
    scheduleOrBlock(false, name, reqFuncOrArgs, callback)
end

-- 使用hooksecurefunc安全地hook函数，避免污染全局函数
RP.origins = RP.origins or {}
RP.hooks = RP.hooks or {}

function RP:hook(name, func)
    assert(type(_G[name])=="function", "Bad arg1, string function name expected")
    assert(type(func)=="function", "Bad arg2, function expected")

    if not RP.origins[name] then
        RP.origins[name] = _G[name]
        RP.hooks[name] = func

        -- 使用hooksecurefunc代替直接替换_G[name]
        hooksecurefunc(name, function(...)
            return RP.hooks[name](...)
        end)
    else
        RP.hooks[name] = func
    end
end

local frame = WW:Frame():RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")

for _name, define in pairs(PROTECT_LIST) do
    --注册对应的事件
    frame:RegisterEvent(define.event)
    --初始化队列
    stats[_name] = {
        callback = nil,
        timeout = nil,
        interval = nil,
        queue = {},
        guid = nil,
    }
    mirror[define.event] = _name

    -- 保存原始clear函数引用，但绝不替换全局函数，避免taint传播
    RP.origins[define.clear] = _G[define.clear]

    -- 可选：仅用于调试观察clear调用
    RP:hook(define.clear, function()
        debug(define.clear, " blocked")
    end)

    -- hook保护的函数，使用hooksecurefunc避免污染ActionButton等安全系统
    -- 注意：hooksecurefunc会在原始函数执行后调用hook，无法阻止原始函数执行
    RP:hook(_name, function(...)
        debug(_name, "called", ...)
        local stat, define = stats[_name], PROTECT_LIST[_name]
        local manual = debugstack():find(define.pattern)

        if manual or (stat.timeout==nil and stat.interval==nil and enteredWorld) then
            local newguid = define.guid_getter(...)
            if stat.guid == newguid then
                --如果两次guid相同，则共用一个，不再发起请求
                return
            end

            if manual then
                doneRequest(_name, false, "interrupted")
            end
            stat.timeout = GetTime() + define.timeout
            stat.interval = nil
            stat.guid = newguid
        else
            debug(_name, ", but blocked")
        end
    end)
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon=="Blizzard_InspectUI" then
            if InspectGuildFrame_Update then
                RP:hook("InspectGuildFrame_Update", function()
                    -- hooksecurefunc已确保原始函数被执行，这里不再手动调用
                    if InspectFrame.unit and GetGuildInfo(InspectFrame.unit) then
                        -- 原始函数已由hooksecurefunc执行
                    end
                end)
            end
        elseif addon=="Blizzard_AchievementUI" then
            if AchievementFrameComparison_UpdateStatusBars then
                RP:hook("AchievementFrameComparison_UpdateStatusBars", function(id)
                    -- hooksecurefunc已确保原始函数被执行，这里不再手动调用
                    if id and id~="summary" then
                        -- 原始函数已由hooksecurefunc执行
                    end
                end)
            end
        end
    elseif event=="PLAYER_ENTERING_WORLD" then
        enteredWorld = true
    elseif event=="PLAYER_LEAVING_WORLD" then
        enteredWorld = false
    elseif mirror[event] then
        doneRequest(mirror[event], true, event, ...)
    end
end)

--minimum interval of 0.05 second
local span,next_t = 0.05, 0
frame:SetScript("OnUpdate", function(self, elapsed)
    if next_t > span then
        next_t = 0
        local now = GetTime()
        --循环判断所有保护的函数
        for _name, stat in pairs(stats) do
            if stat.timeout and now >= stat.timeout then
                debug(_name, "timeout")
                doneRequest(_name, false, "timeout")
            end
            if stat.interval and now >= stat.interval then
                stat.interval = nil
                while stat.timeout == nil and #stat.queue > 0 do
                    submitRequest(_name, unpack(table.remove(stat.queue, 1)))
                end
            end
        end
    else
        next_t = next_t + elapsed
    end
end)

submitRequest = function(name, reqFuncOrArgs, callback, nextFrame)
    local stat, reqType = stats[name], type(reqFuncOrArgs)
    
    -- 在发起请求前调用清理API，使用保存的原始函数引用，避免经过可能被污染的_G
    local define = PROTECT_LIST[name]
    if define and define.clear and RP.origins[define.clear] then
        pcall(RP.origins[define.clear])
    end
    
    if reqType ~= "function" then
        if reqType == "table" then
            _G[name](unpack(reqFuncOrArgs))
        else
            _G[name](reqFuncOrArgs)
        end
    else
        reqFuncOrArgs(_G[name])
        if not stat.timeout then
            if nextFrame then
                RunOnNextFrame(callback, false, "skip")
            else
                xpcall(function () callback(false, "skip") end, geterrorhandler())
            end
        end
    end
    if stat.timeout then stat.callback = callback end
end

doneRequest = function(_name, success, cause, ...)
    local stat = stats[_name]
    if stat.callback then
        xpcall(function () stat.callback(success, cause) end, geterrorhandler())
        stat.callback = nil
    end
    stat.timeout = nil
    stat.interval = GetTime() + PROTECT_LIST[_name].interval
end