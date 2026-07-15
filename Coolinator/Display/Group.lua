---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.GroupMixin = {}

function addonTable.Display.GroupMixin:OnLoad()
  self:SetScript("OnEvent", self.OnEvent)
end

function addonTable.Display.GroupMixin:Disable()
  self:UnregisterAllEvents()
end

function addonTable.Display.GroupMixin:GetDefaultSize()
  return self.width, self.height
end

function addonTable.Display.GroupMixin:SetDefaultSize(width, height)
  self.width, self.height = width, height
end

function addonTable.Display.GroupMixin:ApplySize(width, height)
  self:UpdateVisibility()

  if self.details.layout == "horizontal" then
    local padding = (addonTable.Constants.nativeSize - 4) * self.details.padding
    local activeCount = 0
    for _, w in ipairs(self.children) do
      if not self.autoSize or (w:IsShown() or not w.ShouldCollapse or not w.ShouldCollapse()) then
        activeCount = activeCount + 1
      end
    end
    if activeCount > 0 then
      if width == 0 then
        width = self.width
      end
      width = (width - padding * (activeCount - 1)) / activeCount
      height = height and math.max(self.height, height) or self.height

      for _, w in ipairs(self.children) do
        if w.ApplySize then
          w:ApplySize(width, height)
        end
      end
    end

  elseif self.details.layout == "vertical" then
    local padding = (addonTable.Constants.nativeSize - 4) * self.details.padding
    local activeCount = 0
    for _, w in ipairs(self.children) do
      if not self.autoSize or (w:IsShown() or not w.ShouldCollapse or not w.ShouldCollapse()) then
        activeCount = activeCount + 1
      end
    end
    if activeCount > 0 then
      if height == 0 then
        height = self.height
      end
      height = (height - padding * (activeCount - 1)) / activeCount
      width = width and math.max(self.width, width) or self.width

      for _, w in ipairs(self.children) do
        if w.ApplySize then
          w:ApplySize(width, height)
        end
      end
    end

  else
    width = width and math.max(self.width, width) or self.width
    height = height and math.max(self.height, height) or self.height

    for _, w in ipairs(self.children) do
      if w.ApplySize then
        w:ApplySize(width, height)
      end
    end
  end
end

function addonTable.Display.GroupMixin:ApplyPadding(horizontal, vertical)
  if self.details.layout == "horizontal" then
    local padding = (addonTable.Constants.nativeSize - 4) * self.details.padding
    for _, w in ipairs(self.children) do
      w:ApplyPadding(padding/w:GetScale(), vertical/w:GetScale())
    end
  elseif self.details.layout == "vertical" then
    local padding = (addonTable.Constants.nativeSize - 4) * self.details.padding
    for _, w in ipairs(self.children) do
      w:ApplyPadding(horizontal/w:GetScale(), padding/w:GetScale())
    end
  else
    for _, w in ipairs(self.children) do
      w:ApplyPadding(horizontal/w:GetScale(), vertical/w:GetScale())
    end
  end
end

function addonTable.Display.GroupMixin:Setup(details)
  self.details = details
  self.children = {}
  self.width, self.height = 0, 0
  self.autoSize = addonTable.Config.Get(addonTable.Config.Options.COMPRESS_LAYOUT)

  self:SetupVisibility()
end

if addonTable.Constants.IsMidnightNext then
  function addonTable.Display.GroupMixin:TriggerLayout()
    local parent = self:GetParent()
    if parent.TriggerLayout then
      parent:TriggerLayout()
    else
      self:SetScript("OnUpdate", function()
        self:SetScript("OnUpdate", nil)
        self:Hide()
        self:Show()
      end)
    end
  end
else
  function addonTable.Display.GroupMixin:TriggerLayout()
    self:MarkDirty()
  end
end

function addonTable.Display.GroupMixin:ReanchorForSize()
  for _, child in ipairs(self.children) do
    if child.details.kind == "group" then
      child:ReanchorForSize()
    end
  end

  local offsetSize = addonTable.Constants.nativeSize - 4
  local details = self.details
  if details.layout == "horizontal" then
    local point = "LEFT"
    if details.alignment ~= "CENTER" then
      point = details.alignment .. point
    end
    local maxHeight = 0
    local width = 0
    local padding = details.padding * offsetSize
    for _, child in ipairs(self.children) do
      child:ClearAllPoints()
      PixelUtil.SetPoint(child, point, self, point, width / child:GetScale(), 0)
      local childWidth, childHeight = child:GetWidth(), child:GetHeight()
      maxHeight = math.max(childHeight * child:GetScale(), maxHeight)
      width = width + childWidth * child:GetScale() + padding
    end
    if width > 0 then
      width = width - padding
    end
    PixelUtil.SetSize(self, width, maxHeight)

  elseif details.layout == "vertical" then
    local point = "BOTTOM"
    if details.alignment ~= "CENTER" then
      point = point .. details.alignment
    end
    local padding = details.padding * offsetSize
    local height = 0
    local maxWidth = 0
    local lastChild
    for _, child in ipairs(self.children) do
      child:ClearAllPoints()
      PixelUtil.SetPoint(child, point, self, point, 0, height / child:GetScale())
      local childWidth, childHeight = child:GetWidth(), child:GetHeight()
      maxWidth = math.max(childWidth * child:GetScale(), maxWidth)
      height = height + childHeight * child:GetScale() + padding
      lastChild = child
    end
    if height > 0 then
      height = height - padding
    end
    PixelUtil.SetSize(self, maxWidth, height)
  end
end

local isDruid = UnitClassBase("player") == "DRUID"

local visibilityStates = {
  ["on-mount"] = {
    events = {"PLAYER_MOUNT_DISPLAY_CHANGED"},
    checker = function()
      return IsMounted() or isDruid and GetShapeshiftForm() == 3
    end,
  },
  ["off-mount"] = {
    events = {"PLAYER_MOUNT_DISPLAY_CHANGED"},
    checker = function()
      return not (IsMounted() or isDruid and GetShapeshiftForm() == 3)
    end,
  },
  ["skyriding"] = {
    events = {"PLAYER_ENTERING_WORLD"},
    checker = function()
      return IsAdvancedFlyableArea()
    end,
  },
  ["in-combat"] = {
    events = {"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"},
    checker = function(event)
      return event == "PLAYER_REGEN_DISABLED" or InCombatLockdown()
    end,
  },
  ["out-of-combat"] = {
    events = {"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"},
    checker = function(event)
      return event ~= "PLAYER_REGEN_DISABLED" and not InCombatLockdown()
    end,
  },
  ["has-target"] = {
    events = {"PLAYER_TARGET_CHANGED"},
    checker = function()
      return UnitExists("target") and not UnitCanAssist("player", "target")
    end
  },
  ["no-target"] = {
    events = {"PLAYER_TARGET_CHANGED"},
    checker = function()
      return not UnitExists("target") or UnitCanAssist("player", "target")
    end
  },
  ["loc-world"] = {
    events = {"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "INSTANCE_GROUP_SIZE_CHANGED"},
    checker = function()
      return not IsInInstance()
    end,
  },
  ["loc-dungeon"] = {
    events = {"PLAYER_ENTERING_WORLD"},
    checker = function()
      return select(2, GetInstanceInfo()) == "party"
    end,
  },
  ["loc-raid"] = {
    events = {"PLAYER_ENTERING_WORLD"},
    checker = function()
      return select(2, GetInstanceInfo()) == "raid"
    end,
  },
  ["loc-pvp"] = {
    events = {"PLAYER_ENTERING_WORLD"},
    checker = function()
      local t = select(2, GetInstanceInfo())
      return t == "pvp" or t == "arena"
    end,
  },
  ["loc-delve"] = {
    events = {"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "INSTANCE_GROUP_SIZE_CHANGED"},
    checker = function()
      local difficultyID = select(3, GetInstanceInfo())
      return difficultyID == 208
    end,
  },
}
function addonTable.Display.GroupMixin:SetupVisibility()
  if not self.details.visibility or self.details.layout == "standalone" then
    return
  end

  for _, state in ipairs(self.details.visibility) do
    for _, condition in ipairs(state.conditions) do
      for _, event in ipairs(visibilityStates[condition].events) do
        self:RegisterEvent(event)
      end
    end
  end
end

function addonTable.Display.GroupMixin:IndirectHide()
  self:SetSize(0.0001, 0.0001)
  self:Hide()
  self:GetParent():MarkDirty()
end

function addonTable.Display.GroupMixin:IndirectShow()
  self:SetSize(self.width, self.height)
  self:Show()
  self:GetParent():MarkDirty()
end

function addonTable.Display.GroupMixin:UpdateVisibility(eventName)
  if not self.details.visibility or #self.details.visibility == 0 or self.details.layout == "standalone" then
    self:SetSize(self.width, self.height)
    return
  end

  local any = false
  for _, state in ipairs(self.details.visibility) do
    local all = true
    for _, condition in ipairs(state.conditions) do
      all = all and visibilityStates[condition].checker(eventName)
      if not all then
        break
      end
    end

    if all then
      if state.action == "fade" then
        self:SetAlpha(self.details.alpha * 0.5)

        if not self:IsShown() then
          self:IndirectShow()
        end
      elseif state.action == "hide" then
        self:SetAlpha(self.details.alpha)
        self:IndirectHide()
      elseif state.action == "show" then
        self:SetAlpha(self.details.alpha)
        self:IndirectShow()
      end
      any = true
      break
    end
  end

  if not any then
    self:SetAlpha(self.details.alpha)
    self:IndirectShow()
  end
end

function addonTable.Display.GroupMixin:OnEvent(eventName)
  self:UpdateVisibility(eventName)
end
