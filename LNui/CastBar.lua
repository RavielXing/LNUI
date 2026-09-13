U1PLUG["CastBar"] = function()

    -- 本地化全局变量（性能优化）
    local PlayerCastingBarFrame = PlayerCastingBarFrame
    local format = string.format
    local GetTime = GetTime
    local UnitCastingInfo = UnitCastingInfo
    local UnitChannelInfo = UnitChannelInfo
    local C_Spell = C_Spell
    local GetUnitEmpowerStageDuration = GetUnitEmpowerStageDuration
    local GetUnitEmpowerHoldAtMaxTime = GetUnitEmpowerHoldAtMaxTime
    local GetUnitEmpowerMinHoldTime = GetUnitEmpowerMinHoldTime
    
    -- 缓存字体（性能优化）
    local font = STANDARD_TEXT_FONT
    
    -- ==========================================
    -- 图标缩放比例
    -- ==========================================
    local ICON_SCALE = 1.12
    
    -- ==========================================
    -- 蓄力技能阶段追踪（唤魔师专用）
    -- ==========================================
    local empowerData = {
        stages = {},           -- 各阶段结束时间
        numStages = 0,         -- 总阶段数
        currentStage = 0,      -- 当前阶段
        holdAtMaxTime = 0,     -- 满蓄保持时间
        minHoldTime = 0,       -- 最小蓄力时间
        isEmpowering = false,  -- 是否正在蓄力
    }
    
    -- 阶段颜色：1段=绿色, 2段=黄色, 3段=红色（模块级常量，避免每次刷新创建新表）
    local STAGE_COLORS = {
        "|cff00FF00",  -- 绿色
        "|cffFFFF00",  -- 黄色
        "|cffFF0000",  -- 红色
    }

    -- 初始化施法条样式
    local function SetupCastBarStyle()
        -- 设置施法条尺寸
        PlayerCastingBarFrame:SetSize(240, 18)
        
        -- 设置闪光效果（施法指针）
        if PlayerCastingBarFrame.Spark then
            -- 调整尺寸：更宽更显眼
            PlayerCastingBarFrame.Spark:SetSize(8, 24)

            -- 确保Spark在所有施法条材质之上渲染
            if PlayerCastingBarFrame.Spark.SetDrawLayer then
                PlayerCastingBarFrame.Spark:SetDrawLayer("OVERLAY", 7)  -- 最高绘制层，优先级7
            end

            -- 增强可见性：使用加法混合模式发光效果
            if PlayerCastingBarFrame.Spark.SetBlendMode then
                PlayerCastingBarFrame.Spark:SetBlendMode("ADD")
            end
        end
        
        -- 设置图标
        if PlayerCastingBarFrame.Icon then
            -- 基础尺寸28，缩放1.1倍后为30.8，取整31
            local iconSize = 28 * ICON_SCALE
            PlayerCastingBarFrame.Icon:SetSize(iconSize, iconSize)
            -- 调整位置偏移，保持与施法条的间距比例
            local iconOffset = -10 * ICON_SCALE
            PlayerCastingBarFrame.Icon:SetPoint("RIGHT", PlayerCastingBarFrame, "LEFT", iconOffset, 0)
            PlayerCastingBarFrame.Icon:Show()
            
            -- ==========================================
            -- 添加圆形遮罩（参考施法条图标.lua的实现）
            -- ==========================================
            if not PlayerCastingBarFrame.IconOverlay then
                local overlay = PlayerCastingBarFrame:CreateTexture(nil, "OVERLAY")
                -- 使用施法条图标.lua相同的遮罩纹理路径
                overlay:SetTexture("Interface\\AddOns\\LNui\\Media\\Icon.png")
                -- 遮罩基础尺寸45，缩放1.1倍后为49.5，取整50
                local overlaySize = 45 * ICON_SCALE
                overlay:SetSize(overlaySize, overlaySize)
                -- 图标位置
                overlay:SetPoint("CENTER", PlayerCastingBarFrame.Icon, "CENTER", 2, 0)
                PlayerCastingBarFrame.IconOverlay = overlay
            else
                -- 更新已有遮罩的尺寸
                local overlaySize = 45 * ICON_SCALE
                PlayerCastingBarFrame.IconOverlay:SetSize(overlaySize, overlaySize)
            end
        end
        
        -- 设置法术名称文本
        if PlayerCastingBarFrame.Text then
            PlayerCastingBarFrame.Text:ClearAllPoints()
            PlayerCastingBarFrame.Text:SetPoint("CENTER")
            PlayerCastingBarFrame.Text:SetFont(font, 14, "OUTLINE")
        end
        
        -- 隐藏边框和背景
        if PlayerCastingBarFrame.TextBorder then
            PlayerCastingBarFrame.TextBorder:SetTexture(nil)
        end
        if PlayerCastingBarFrame.BorderMask then
            PlayerCastingBarFrame.BorderMask:SetTexture(1)
        end
        if PlayerCastingBarFrame.Background then
            PlayerCastingBarFrame.Background:SetTexture(nil)
            PlayerCastingBarFrame.Background:SetAlpha(0)
        end
        
        -- 设置层级
        PlayerCastingBarFrame:SetFrameStrata("TOOLTIP")
    end
    
    -- ==========================================
    -- 蓄力技能数据处理（唤魔师核心功能）
    -- ==========================================
    local function UpdateEmpowerData(unit)
        -- 获取施法信息（12.0 API: 返回表结构）
        local castInfo = UnitCastingInfo(unit)
        if not castInfo then
            empowerData.isEmpowering = false
            empowerData.currentStage = 0
            return false
        end
        
        -- 检查是否为蓄力技能
        -- 12.0 API: 通过 empowerStages 字段判断
        local numStages = castInfo.empowerStages or 0
        if numStages == 0 then
            empowerData.isEmpowering = false
            empowerData.currentStage = 0
            return false
        end
        
        empowerData.isEmpowering = true
        empowerData.numStages = numStages
        
        -- 获取蓄力时间信息
        local startTime = castInfo.startTime / 1000  -- 转换为秒
        local endTime = castInfo.endTime / 1000
        local currentTime = GetTime()
        local elapsed = currentTime - startTime
        
        -- 获取各阶段持续时间
        wipe(empowerData.stages)
        local stageEnd = startTime
        
        for i = 1, numStages do
            -- 12.0 API: GetUnitEmpowerStageDuration(unit, stageIndex)
            local stageDuration = GetUnitEmpowerStageDuration(unit, i - 1) or 0
            stageEnd = stageEnd + (stageDuration / 1000)
            empowerData.stages[i] = stageEnd
        end
        
        -- 获取满蓄保持时间
        empowerData.holdAtMaxTime = (GetUnitEmpowerHoldAtMaxTime(unit) or 0) / 1000
        empowerData.minHoldTime = (GetUnitEmpowerMinHoldTime(unit) or 0) / 1000
        
        -- 计算当前阶段
        empowerData.currentStage = 0
        for i = 1, numStages do
            if currentTime >= empowerData.stages[i] then
                empowerData.currentStage = i
            else
                break
            end
        end
        
        return true
    end
    
    -- ==========================================
    -- 创建或获取冷却时间显示文本
    -- ==========================================
    local function GetCooldownText(self)
        if not self.Cooldown then
            self.Cooldown = self:CreateFontString(nil, "OVERLAY")
            self.Cooldown:SetFont(font, 14, "OUTLINE")
            self.Cooldown:SetJustifyH("RIGHT")
            self.Cooldown:SetPoint("RIGHT", -5, 0)
        end
        return self.Cooldown
    end
    
    -- ==========================================
    -- 创建蓄力阶段指示器（唤魔师专用）
    -- ==========================================
    local function GetEmpowerStageText(self)
        if not self.EmpowerStage then
            self.EmpowerStage = self:CreateFontString(nil, "OVERLAY")
            self.EmpowerStage:SetFont(font, 16, "OUTLINE")
            self.EmpowerStage:SetJustifyH("LEFT")
            self.EmpowerStage:SetPoint("LEFT", 5, 0)
        end
        return self.EmpowerStage
    end
    
    -- ==========================================
    -- 施法计时逻辑
    -- ==========================================
    -- 节流变量：减少每帧调用压力
    local lastCastUpdate = 0
    local function ShowMyCasting(self)
        -- 0.05秒节流，约20fps刷新，足够流畅且大幅降低CPU/GC压力
        local now = GetTime()
        if now - lastCastUpdate < 0.05 then return end
        lastCastUpdate = now

        if not self.maxValue then
            -- 隐藏冷却文本
            if self.Cooldown then
                self.Cooldown:SetText("")
            end
            if self.EmpowerStage then
                self.EmpowerStage:SetText("")
            end
            return
        end
        
        local cooldown = GetCooldownText(self)
        local remaining = self.maxValue - self.value
        
        -- 获取施法信息（12.0 API）
        local castInfo = UnitCastingInfo("player")
        local channelInfo = UnitChannelInfo("player")
        
        if castInfo then
            -- 检查是否为蓄力技能（唤魔师）
            local numStages = castInfo.empowerStages or 0
            if numStages > 0 then
                -- 更新蓄力数据
                UpdateEmpowerData("player")
                
                -- 显示蓄力阶段
                local stageText = GetEmpowerStageText(self)
                local currentStage = empowerData.currentStage
                
                if currentStage > 0 and currentStage <= numStages then
                    local color = STAGE_COLORS[currentStage] or "|cffFFFFFF"
                    stageText:SetText(format("%s%d/%d|r", color, currentStage, numStages))
                else
                    stageText:SetText("")
                end
                
                -- 显示蓄力倒计时
                if remaining > 0 then
                    -- 计算到下一阶段的时间
                    local nextStageTime = 0
                    if currentStage < numStages then
                        local nextStageEnd = empowerData.stages[currentStage + 1]
                        if nextStageEnd then
                            nextStageTime = nextStageEnd - GetTime()
                        end
                    end
                    
                    if nextStageTime > 0 then
                        cooldown:SetText(format("|cff19CCF9%.1f|r / %.1f 秒 (+%.1f)", 
                            remaining, self.maxValue, nextStageTime))
                    else
                        cooldown:SetText(format("|cff19CCF9%.1f|r / %.1f 秒", 
                            remaining, self.maxValue))
                    end
                else
                    cooldown:SetText("")
                end
            else
                -- 普通施法
                if self.EmpowerStage then
                    self.EmpowerStage:SetText("")
                end
                cooldown:SetText(format("|cff19CCF9%.1f|r / %.1f 秒", remaining, self.maxValue))
            end
            
        elseif channelInfo then
            -- 引导法术
            if self.EmpowerStage then
                self.EmpowerStage:SetText("")
            end
            cooldown:SetText(format("|cff19CCF9%.1f|r 秒", self.value))
            
        else
            -- 无施法
            if self.EmpowerStage then
                self.EmpowerStage:SetText("")
            end
            cooldown:SetText("")
        end
    end
    
    -- ==========================================
    -- 事件处理器
    -- ==========================================
    local function OnCastEvent(_, event, unit, ...)
        if unit ~= "player" then return end
        
        -- 确保UI更新（应对其他插件覆盖）
        SetupCastBarStyle()
        
        -- 处理蓄力技能事件
        if event == "UNIT_SPELLCAST_EMPOWER_START" then
            empowerData.isEmpowering = true
            UpdateEmpowerData("player")
            
        elseif event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
            UpdateEmpowerData("player")
            
        elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            empowerData.isEmpowering = false
            empowerData.currentStage = 0
            if PlayerCastingBarFrame.EmpowerStage then
                PlayerCastingBarFrame.EmpowerStage:SetText("")
            end
        end
    end
    
    -- ==========================================
    -- 创建事件监听框架
    -- ==========================================
    local castevent = CreateFrame("Frame")
    
    -- 普通施法事件
    castevent:RegisterEvent("UNIT_SPELLCAST_START")
    castevent:RegisterEvent("UNIT_SPELLCAST_STOP")
    castevent:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    castevent:RegisterEvent("UNIT_SPELLCAST_FAILED")
    castevent:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    
    -- 引导法术事件
    castevent:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    castevent:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    castevent:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    
    -- 蓄力技能事件（唤魔师专用）
    castevent:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    castevent:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
    castevent:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    
    castevent:SetScript("OnEvent", OnCastEvent)
    
    -- ==========================================
    -- 初始化
    -- ==========================================
    SetupCastBarStyle()
    PlayerCastingBarFrame:HookScript("OnUpdate", ShowMyCasting)

end