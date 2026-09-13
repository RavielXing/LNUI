-- 装备装等升级范围，作者：KeiraMetz
-- 更新至 12.1 S2 赛季装等
U1PLUG["ItemUpgradeTooltip"] = function()
do
    -- 6/6 最高装等（S2 赛季）
    local trackMaxItemLevels = {
        -- 简体中文 (国服)
        ["冒险者"] = 282,
        ["老兵"] = 295,
        ["勇士"] = 308,
        ["英雄"] = 321,
        ["神话"] = 334,
        
        -- 繁體中文 (台服)
        ["冒險者"] = 282,
        ["精兵"] = 295,
        ["冠軍"] = 308,
        ["英雄"] = 321,
        ["神話"] = 334,
        
        -- 英文客户端
        ["Adventurer"] = 282,
        ["Veteran"] = 295,
        ["Champion"] = 308,
        ["Hero"] = 321,
        ["Myth"] = 334,
    }

    -- 1/6 起始装等（12.1 S2 赛季所有轨道均为 1/6 ~ 6/6，总跨度 16）
    local trackMinItemLevels = {
        -- 简体中文 (国服)
        ["冒险者"] = 266,
        ["老兵"] = 279,
        ["勇士"] = 292,
        ["英雄"] = 305,
        ["神话"] = 318,
        
        -- 繁體中文 (台服)
        ["冒險者"] = 266,
        ["精兵"] = 279,
        ["冠軍"] = 292,
        ["英雄"] = 305,
        ["神話"] = 318,
        
        -- 英文客户端
        ["Adventurer"] = 266,
        ["Veteran"] = 279,
        ["Champion"] = 292,
        ["Hero"] = 305,
        ["Myth"] = 318,
    }

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, tooltipData)
        local name, link = (tooltip.GetItem or TooltipUtil.GetDisplayedItem)(tooltip)
        if name and name ~= '' then
            if not link or type(link) ~= "string" then
                return
            end
            
            local itemID = tonumber(link:match("item:(%d+)"))
            if not itemID then
                return
            end
            
            local itemUpgradeInfo = C_Item.GetItemUpgradeInfo(link)
            if itemUpgradeInfo and itemUpgradeInfo.trackStringID then
                local maxItemLevel = itemUpgradeInfo.maxItemLevel
                local minItemLevel = itemUpgradeInfo.minItemLevel
                
                -- 过滤 API 可能返回的 0 值
                if not maxItemLevel or maxItemLevel == 0 then maxItemLevel = nil end
                if not minItemLevel or minItemLevel == 0 then minItemLevel = nil end
                
                -- 尝试从装备升级界面 API 获取（允许单独获取 min 或 max）
                if not maxItemLevel or not minItemLevel then
                    if C_ItemUpgrade.GetItemUpgradeItemInfo then
                        local upgradeItemInfo = C_ItemUpgrade.GetItemUpgradeItemInfo()
                        if upgradeItemInfo then
                            if not maxItemLevel then
                                local infoMax = upgradeItemInfo.maxItemLevel
                                if infoMax and infoMax > 0 then
                                    maxItemLevel = infoMax
                                end
                            end
                            if not minItemLevel then
                                local infoMin = upgradeItemInfo.minItemLevel
                                if infoMin and infoMin > 0 then
                                    minItemLevel = infoMin
                                end
                            end
                        end
                    end
                end

                -- 通过轨道名称直接查表（最可靠）
                if not maxItemLevel or not minItemLevel then
                    local trackName = itemUpgradeInfo.trackStringID
                    if trackName then
                        if not maxItemLevel and trackMaxItemLevels[trackName] then
                            maxItemLevel = trackMaxItemLevels[trackName]
                        end
                        if not minItemLevel and trackMinItemLevels[trackName] then
                            minItemLevel = trackMinItemLevels[trackName]
                        end
                    end
                end

                -- 最终 fallback：根据当前装等和等级估算
                -- 12.1 S2 步长模式：+3, +3, +4, +3, +3（总跨度 16）
                if not maxItemLevel then
                    local currentItemLevel = select(4, LNuiCompat.GetItemInfo(link))
                    if currentItemLevel and currentItemLevel > 0 then
                        local currLevel = itemUpgradeInfo.currentLevel or 1
                        local remaining = 6 - currLevel
                        maxItemLevel = currentItemLevel + remaining * 3
                        -- 修正：1/6~3/6 差 1 点（第 3 步为 +4）
                        if currLevel >= 1 and currLevel <= 3 then
                            maxItemLevel = maxItemLevel + 1
                        end
                    else
                        return
                    end
                end

                -- 如果仍缺少最小值，用最大值反推（总跨度 16）
                if maxItemLevel and maxItemLevel > 0 then
                    if not minItemLevel then
                        minItemLevel = maxItemLevel - 16
                    end
                    
                    for _, line in ipairs(tooltipData.lines) do
                        if line.type == Enum.TooltipDataLineType.ItemUpgradeLevel then
                            local text = line.leftText
                            local tooltipLineTextLeft, tooltipLineTextLeftText
                            for i = 1, tooltip:NumLines() do
                                tooltipLineTextLeft = _G[tooltip:GetName().."TextLeft"..i]
                                if tooltipLineTextLeft then
                                    tooltipLineTextLeftText = tooltipLineTextLeft:GetText()
                                    if tooltipLineTextLeftText and tooltipLineTextLeftText == line.leftText then
                                        tooltipLineTextLeft:SetText(string.format("%s (%d - %d)", tooltipLineTextLeftText, minItemLevel, maxItemLevel))
                                        break
                                    end
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end)
end
end