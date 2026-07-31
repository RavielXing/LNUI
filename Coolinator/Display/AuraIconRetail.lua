---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.AuraIconMixin = {}
function addonTable.Display.AuraIconMixin:OnLoad()
  self:SetIgnoringChildrenForBounds(true)
  self:SetSize(addonTable.Constants.nativeSize - 4, addonTable.Constants.nativeSize - 4)
end

local sourceFrames = {}

function addonTable.Display.AuraIconMixin:Setup(sourceWidget, details)
  self.details = details

  if not sourceFrames[sourceWidget] then
    sourceWidget.DebuffBorder:SetParent(addonTable.hiddenFrame)

    local debuffBorder = addonTable.Utilities.InitFrameWithMixin(sourceWidget, addonTable.Display.AuraDebuffBorderMixin)
    debuffBorder:SetPoint("CENTER", sourceWidget.Icon)
    debuffBorder:SetSize(addonTable.Constants.nativeSize, addonTable.Constants.nativeSize)

    local glow = addonTable.Utilities.InitFrameWithMixin(sourceWidget, addonTable.Display.GlowMixin)
    glow:SetAllPoints(sourceWidget.Icon)

    local _, _, overlay = sourceWidget:GetRegions()
    overlay:SetParent(addonTable.hiddenFrame)

    sourceFrames[sourceWidget] = {
      source = sourceWidget,
      icon = sourceWidget.Icon,
      count = sourceWidget.Applications.Applications,
      cooldown = sourceWidget.Cooldown,
      debuffBorder = debuffBorder,
      glow = glow,
    }
  end

  sourceWidget:SetParent(self)
  sourceWidget:ClearAllPoints()
  sourceWidget:SetPoint("CENTER", self)

  self:Show()

  local widgets = sourceFrames[sourceWidget]
  self.widgets = widgets

  widgets.source:SetMouseMotionEnabled(addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))
  self:SetMouseMotionEnabled(addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))
  addonTable.Display.StyleIcon({id  = details.style}, self, widgets.icon, widgets.count, nil, {widgets.icon}, {{swipe = true, text = true, widget = widgets.cooldown}})

  widgets.glow:SetShown(addonTable.Constants.GlowsMap[details.whenActive] ~= nil)
  if widgets.glow:IsShown() then
    widgets.glow:SetAsset(addonTable.Constants.GlowsMap[details.whenActive], details.glowColor, details.glowReverse)
  end

  widgets.debuffBorder:Setup(details)
  widgets.debuffBorder:SetFrameLevel(self:GetFrameLevel() + 2)
  widgets.glow:SetFrameLevel(self:GetFrameLevel() + 3)
  widgets.source.Applications:SetFrameLevel(self:GetFrameLevel() + 4)

  widgets.cooldown:SetDrawSwipe(details.showSwipe)
  widgets.cooldown:SetCountdownFormatter(addonTable.Display.GetDurationFormatter(details.texts.cooldown.showFractions))

  self:SetShown(widgets.source:IsShown())
  if self:IsShown() then
    self:ApplyPadding(self.paddingH or 0, self.paddingV or 0)
  else
    self:SetSize(0.001, 0.001)
  end
end

function addonTable.Display.AuraIconMixin:NotifyActive(state)
  if state ~= self:IsShown() then
    self:SetShown(state)
    if state then
      self:ApplyPadding(self.paddingH, self.paddingV)
    else
      self:SetSize(0.001, 0.001)
    end
    if self:GetParent().TriggerLayout then
      self:GetParent():TriggerLayout()
    end
  end
end

function addonTable.Display.AuraIconMixin:GetDefaultSize()
  local dim = addonTable.Constants.nativeSize - 4
  return dim, dim
end

function addonTable.Display.AuraIconMixin:ApplyPadding(horizontal, vertical)
  self.paddingH, self.paddingV = horizontal, vertical
  if not self:IsShown() then
    return
  end
  self:SetSize(addonTable.Constants.nativeSize - 4 + horizontal, addonTable.Constants.nativeSize - 4 + vertical)
end

function addonTable.Display.AuraIconMixin:UpdateSource(sourceWidget)
  if sourceWidget == nil then
    self.widgets = nil
    self:Hide()
  elseif not self.widgets or sourceWidget ~= self.widgets.source then
    self:Setup(sourceWidget, self.details)
  else
    sourceWidget:SetParent(self)
    sourceWidget:ClearAllPoints()
    sourceWidget:SetPoint("CENTER", self)
    local color = self.details.swipeColor
    self.widgets.cooldown:SetSwipeColor(color.r, color.g, color.b, color.a)
    self.widgets.icon:SetShown(self.details.showIcon)
    self.widgets.cooldown:SetHideCountdownNumbers(not self.details.texts.cooldown.visible)
    self:NotifyActive(sourceWidget:IsShown())
  end
end

function addonTable.Display.AuraIconMixin:IgnoreForSizing()
  return true
end
