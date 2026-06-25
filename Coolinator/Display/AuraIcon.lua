---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.AuraIconMixin = {}
function addonTable.Display.AuraIconMixin:OnLoad()
  self:SetSize(addonTable.Constants.nativeSize - 4, addonTable.Constants.nativeSize - 4)
end

local sourceFrames = {}

function addonTable.Display.AuraIconMixin:Setup(sourceWidget, details)
  self.details = details

  if not sourceFrames[sourceWidget] then
    sourceWidget.DebuffBorder:SetParent(addonTable.hiddenFrame)

    local debuffBorder = addonTable.Utilities.InitFrameWithMixin(self, addonTable.Display.AuraDebuffBorderMixin)

    local _, overlay = sourceWidget:GetRegions()
    overlay:Hide()

    sourceFrames[sourceWidget] = {
      source = sourceWidget,
      icon = sourceWidget.Icon,
      count = sourceWidget.Applications.Applications,
      cooldown = sourceWidget.Cooldown,
      debuffBorder = debuffBorder,
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

  widgets.debuffBorder:SetPoint("CENTER")
  widgets.debuffBorder:SetSize(addonTable.Constants.nativeSize, addonTable.Constants.nativeSize)
  widgets.debuffBorder:Setup(details)
  widgets.debuffBorder:SetFrameLevel(self:GetFrameLevel() + 4)

  widgets.cooldown:SetDrawSwipe(details.showSwipe)
  widgets.cooldown:SetCountdownFormatter(addonTable.Display.GetDurationFormatter(details.texts.cooldown.showFractions))

  self:SetShown(widgets.source:IsShown())
end

function addonTable.Display.AuraIconMixin:NotifyActive(state)
  self:SetShown(state)
end

function addonTable.Display.AuraIconMixin:UpdateSource(sourceWidget)
  if sourceWidget == nil then
    self.widgets = nil
  elseif not self.widgets or sourceWidget ~= self.widgets.source then
    self:Setup(sourceWidget, self.details)
  else
    sourceWidget:SetParent(self)
    sourceWidget:ClearAllPoints()
    sourceWidget:SetPoint("CENTER", self)
    self:NotifyActive(sourceWidget:IsShown())
  end
end
