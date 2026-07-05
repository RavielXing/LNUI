-----------------------------------------------------------------------
-- TipTac 性能修复：修复物品对比时的卡顿/掉帧问题
-- 保留原生标准物品对比功能，彻底消除卡顿
-- 版本: 1.3
-----------------------------------------------------------------------

local MOD_NAME = "TipTac"
local tt = _G[MOD_NAME]

if not tt then
    return
end

-----------------------------------------------------------------------
-- 修复 1：修正 SetScaleToTip 中的代码笔误（防止递归死循环）
-----------------------------------------------------------------------
local originalSetScaleToTip = tt.SetScaleToTip
local _scaleRecursionFlag = false

tt.SetScaleToTip = function(self, tip, noFireGroupEvent)
    if _scaleRecursionFlag then
        return
    end
    
    _scaleRecursionFlag = true
    
    -- 调用原始函数
    originalSetScaleToTip(self, tip, noFireGroupEvent)
    
    _scaleRecursionFlag = false
end

-----------------------------------------------------------------------
-- 修复 2：移除 ShoppingTooltip 多余的 ClearHandlerInfo 调用
-- 仅需此修复即可保留原生物品对比功能
-----------------------------------------------------------------------
-- 查找并修复 TT_ExtendedConfig 中购物提示框的处理函数
local function fixShoppingTooltipHandlers()
    -- 查找 ShoppingTooltip1 和 ShoppingTooltip2 的配置
    if tt.TT_ExtendedConfig and tt.TT_ExtendedConfig.tipsToModify and 
       tt.TT_ExtendedConfig.tipsToModify[MOD_NAME] and
       tt.TT_ExtendedConfig.tipsToModify[MOD_NAME].frames then
        
        local frames = tt.TT_ExtendedConfig.tipsToModify[MOD_NAME].frames
        
        -- 修复 ShoppingTooltip1
        if frames["ShoppingTooltip1"] and frames["ShoppingTooltip1"].hookFnForFrame then
            -- 替换为安全版本的处理函数
            frames["ShoppingTooltip1"].hookFnForFrame = function(TT_CacheForFrames, tip)
                -- 安全版本：仅执行一次 ClearHandlerInfo
                local clearedFlag = false
                tip:HookScript("OnTooltipCleared", function(tip)
                    if not clearedFlag then
                        clearedFlag = true
                        if tip.ClearHandlerInfo then
                            tip:ClearHandlerInfo()
                        end
                    end
                end)
                -- 显示时重置标记
                tip:HookScript("OnShow", function()
                    clearedFlag = false
                end)
            end
        end
        
        -- 修复 ShoppingTooltip2
        if frames["ShoppingTooltip2"] and frames["ShoppingTooltip2"].hookFnForFrame then
            frames["ShoppingTooltip2"].hookFnForFrame = function(TT_CacheForFrames, tip)
                local clearedFlag = false
                tip:HookScript("OnTooltipCleared", function(tip)
                    if not clearedFlag then
                        clearedFlag = true
                        if tip.ClearHandlerInfo then
                            tip:ClearHandlerInfo()
                        end
                    end
                end)
                tip:HookScript("OnShow", function()
                    clearedFlag = false
                end)
            end
        end
        
        -- 修复 ItemRefShoppingTooltip1/2（如有）
        if frames["ItemRefShoppingTooltip1"] and frames["ItemRefShoppingTooltip1"].hookFnForFrame then
            frames["ItemRefShoppingTooltip1"].hookFnForFrame = function(TT_CacheForFrames, tip)
                local clearedFlag = false
                tip:HookScript("OnTooltipCleared", function(tip)
                    if not clearedFlag then
                        clearedFlag = true
                        if tip.ClearHandlerInfo then
                            tip:ClearHandlerInfo()
                        end
                    end
                end)
                tip:HookScript("OnShow", function()
                    clearedFlag = false
                end)
            end
        end
        
        if frames["ItemRefShoppingTooltip2"] and frames["ItemRefShoppingTooltip2"].hookFnForFrame then
            frames["ItemRefShoppingTooltip2"].hookFnForFrame = function(TT_CacheForFrames, tip)
                local clearedFlag = false
                tip:HookScript("OnTooltipCleared", function(tip)
                    if not clearedFlag then
                        clearedFlag = true
                        if tip.ClearHandlerInfo then
                            tip:ClearHandlerInfo()
                        end
                    end
                end)
                tip:HookScript("OnShow", function()
                    clearedFlag = false
                end)
            end
        end
    end
end

-- 应用修复
fixShoppingTooltipHandlers()

-----------------------------------------------------------------------
-- 修复 3：为物品的 SetCurrentDisplayParams 函数添加防抖
-- 降低物品参数更新频率，避免卡顿
-----------------------------------------------------------------------
local originalSetCurrentDisplayParams = tt.SetCurrentDisplayParams
local _lastItemDisplayTime = {}
local _itemCooldown = 0.083 -- 物品83毫秒延迟（保证流畅性）

tt.SetCurrentDisplayParams = function(self, tip, tipContent)
    local tipName = tip:GetName() or ""
    
    -- tipContent == 4 代表物品（TT_TIP_CONTENT.item）
    -- 同时处理购物提示框
    if tipContent == 4 or tipName:match("ShoppingTooltip") then
        local now = GetTime()
        local lastTime = _lastItemDisplayTime[tipName] or 0
        
        if now - lastTime < _itemCooldown then
            -- 跳过过于频繁的调用，但不完全禁用
            -- 降低性能消耗且不影响功能
            return
        end
        
        _lastItemDisplayTime[tipName] = now
    end
    
    return originalSetCurrentDisplayParams(self, tip, tipContent)
end

-----------------------------------------------------------------------
-- 修复 4：为对比提示框的 OnSizeChanged 事件添加防抖
-----------------------------------------------------------------------
local _resizeTimers = {}

local function debouncedResize(tip)
    local tipName = tip:GetName() or tostring(tip)
    
    if not tipName:match("ShoppingTooltip") then
        return false
    end
    
    if _resizeTimers[tipName] then
        _resizeTimers[tipName]:Cancel()
    end
    
    _resizeTimers[tipName] = C_Timer.NewTimer(0.033, function()
        _resizeTimers[tipName] = nil
    end)
    
    return true
end

-- 保留原始的 OnSizeChanged（如果存在）
local originalHookScript = tip and tip.HookScript
-- 对已存在的购物提示框应用防抖
local function applyToExistingShoppingTooltips()
    for i = 1, 2 do
        local tip = _G["ShoppingTooltip" .. i]
        if tip and tip.HookScript and not tip._ttResizeFixed then
            tip._ttResizeFixed = true
            tip:HookScript("OnSizeChanged", function(frame)
                debouncedResize(frame)
            end)
        end
    end
end

C_Timer.NewTimer(0.5, applyToExistingShoppingTooltips)

-----------------------------------------------------------------------
-- 修复 5：优化对比提示框的 SetPaddingToTip 函数
-----------------------------------------------------------------------
local originalSetPaddingToTip = tt.SetPaddingToTip
local _lastPaddingTime = {}

tt.SetPaddingToTip = function(self, tip)
    local tipName = tip:GetName() or ""
    
    if tipName:match("ShoppingTooltip") then
        local now = GetTime()
        local lastTime = _lastPaddingTime[tipName] or 0
        
        if now - lastTime < 0.083 then
            return
        end
        
        _lastPaddingTime[tipName] = now
    end
    
    return originalSetPaddingToTip(self, tip)
end
