if U1IsAddonEnabled and U1IsAddonEnabled("Battle Pet Current Stats") then return end
--[[------------------------------------------------------------
## Title: Battle Pet Current Stats
## Notes: Displays the stats of battle pets in play during a pet battle.
## Notes-zhCN: 在默认的对战界面上显示双方当前激活宠物的攻击、速度和血量，以便做好预判。
## Author: Gello
## Version: 1.0.2 - 2016.8.13
---------------------------------------------------------------]]
local frame = CreateFrame("Frame")
frame.notSetUp = true
frame.texCoords = {Power={0,.5,0,.5}, Speed={0,.5,.5,1}, Health={.5,1,.5,1}}

-- 12.1: 字体回退检测，避免文件不存在时反复查询文件系统导致内存/性能开销
local function GetValidFontPath()
    local customFont = "Interface\\AddOns\\LNui\\7.0\\BattlePetCurrentStats_Aziti.ttf"
    local testFont = CreateFont("BattlePetStatsFontTest")
    testFont:SetFont(customFont, 15, "")
    local actualFont = testFont:GetFont()
    if actualFont then
        return customFont
    else
        -- 回退到系统默认字体
        return "Fonts\\ARKai_T.ttf"
    end
end
local validFontPath = GetValidFontPath()

frame:SetScript("OnEvent",function(self,event,...)
  if self.notSetUp and IsAddOnLoaded("Blizzard_PetBattleUI") then
    self:SetUpWidgets()
  else
    self:UpdateWidgets()
  end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

function frame:CreateWidget(parent,widgetType,anchor,xoff)
  local widget = CreateFrame("Frame",nil,parent)
  widget:SetSize(15,15)
  widget.icon = widget:CreateTexture(nil,"OVERLAY")
  widget.icon:SetAllPoints(true)
  widget.icon:SetTexture("Interface\\PetBattles\\PetBattle-StatIcons")
  if frame.texCoords[widgetType] then
    widget.icon:SetTexCoord(unpack(frame.texCoords[widgetType]))
  end
  widget.text = widget:CreateFontString(nil,"ARTWORK")
  -- 12.1: 使用经过存在性检测的字体路径，避免无效文件查询
  widget.text:SetFont(validFontPath, 15, "")
  widget.text:SetPoint("LEFT",widget.icon,"RIGHT",1,0)
  widget:SetPoint("TOP",parent,anchor,xoff,-1)
  return widget
end

function frame:SetUpWidgets()
  self.notSetUp = nil
  self.widgets = {}
  for i=1,2 do
    self.widgets[i] = {}
    local parent = i==1 and PetBattleFrame.ActiveAlly or PetBattleFrame.ActiveEnemy
    local anchor = i==1 and "BOTTOMRIGHT" or "BOTTOMLEFT"
    local offset = i==1 and -170 or 10
    self.widgets[i].Health = i==1 and self:CreateWidget(parent,"Health",anchor,offset+120) or self:CreateWidget(parent,"Health",anchor,offset+4)
    self.widgets[i].Power = i==1 and self:CreateWidget(parent,"Power",anchor,offset+60) or self:CreateWidget(parent,"Power",anchor,offset+80)
    self.widgets[i].Speed = i==1 and self:CreateWidget(parent,"Speed",anchor,offset+0) or self:CreateWidget(parent,"Speed",anchor,offset+138)
  end
  self:UnregisterEvent("ADDON_LOADED")
  self:RegisterEvent("PET_BATTLE_AURA_APPLIED")
  self:RegisterEvent("PET_BATTLE_AURA_CHANGED")
  self:RegisterEvent("PET_BATTLE_AURA_CANCELED")
  self:RegisterEvent("PET_BATTLE_HEALTH_CHANGED")
  self:RegisterEvent("PET_BATTLE_PET_CHANGED")
  self:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")
end

function frame:UpdateWidgets()
  if not self.widgets then return end
  for i=1,2 do
    local pet = C_PetBattles.GetActivePet(i)
    if pet then
      local health = C_PetBattles.GetHealth(i,pet)
      local maxHealth = C_PetBattles.GetMaxHealth(i,pet)
      if health and maxHealth and maxHealth > 0 then
        self.widgets[i].Health.text:SetText(format("%.1f%%",health*100/maxHealth))
      end
      self.widgets[i].Power.text:SetText(C_PetBattles.GetPower(i,pet) or "")
      self.widgets[i].Speed.text:SetText(C_PetBattles.GetSpeed(i,pet) or "")
    end
  end
end