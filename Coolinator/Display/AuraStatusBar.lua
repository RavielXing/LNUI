---@class addonTableCoolinator
local addonTable = select(2, ...)

local LSM = LibStub("LibSharedMedia-3.0")

addonTable.Display.AuraStatusBarMixin = {}
function addonTable.Display.AuraStatusBarMixin:OnLoad()
end

local sourceFrames = {}

function addonTable.Display.AuraStatusBarMixin:Setup(sourceWidget, details)
  local statusBar = sourceWidget.Bar

  if not sourceFrames[sourceWidget] then
    sourceWidget.DebuffBorder:SetParent(addonTable.hiddenFrame)
    statusBar.BarBG:SetParent(addonTable.hiddenFrame)
    statusBar.Pip:SetParent(addonTable.hiddenFrame)
    sourceWidget.Icon:SetParent(addonTable.hiddenFrame)
    statusBar.Name:SetParent(addonTable.hiddenFrame)

    statusBar.Duration:SetSmoothScaling(true)
    local file, height, flags = statusBar.Duration:GetFont()
    statusBar.Duration:SetFont(file, height, "OUTLINE SLUG")

    local background = statusBar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local borderWrapper = CreateFrame("Frame", nil, statusBar)
    borderWrapper:SetAllPoints()
    local border = borderWrapper:CreateTexture(nil, "BORDER")
    border:SetPoint("CENTER")
    local borderMask = statusBar:CreateMaskTexture()
    borderMask:SetAllPoints()

    local icon = CreateFrame("Frame", nil, sourceWidget)
    icon:SetSize(30, 30)
    icon.Icon = sourceWidget.Icon.Icon
    icon.Icon:SetParent(icon)
    local mask = icon.Icon:GetMaskTexture(1)
    if mask then
      icon.Icon:RemoveMaskTexture(mask)
    end
    icon.Icon:SetAllPoints()
    icon.Mask = icon:CreateMaskTexture()
    icon.Mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
    icon.Mask:SetAllPoints()
    icon.Icon:AddMaskTexture(icon.Mask)
    icon.Applications = sourceWidget.Icon.Applications
    icon.Applications:SetParent(icon)
    icon.Applications:ClearAllPoints()
    icon.Applications:SetSize(30, 10)
    icon.Applications:SetPoint("BOTTOMRIGHT", -5, 5)

    local debuffBorder = addonTable.Utilities.InitFrameWithMixin(self, addonTable.Display.AuraDebuffBorderMixin)
    debuffBorder:SetAllPoints(icon)

    sourceFrames[sourceWidget] = {
      icon = icon,
      statusBar = statusBar,
      background = background,
      border = border,
      debuffBorder = debuffBorder,
      borderWrapper = borderWrapper,
      borderMask = borderMask,
      duration = statusBar.Duration,
      source = sourceWidget,
    }
  end

  local widgets = sourceFrames[sourceWidget]
  sourceWidget:SetParent(self)
  self.widgets = widgets
  widgets.source:SetMouseMotionEnabled(addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))

  self.rawWidth, self.rawHeight, self.borderWidth, self.borderHeight, self.lowerScale = addonTable.Display.ApplyStatusBar(details, statusBar, widgets.border, widgets.borderMask, widgets.background)

  widgets.borderWrapper:SetFrameLevel(widgets.statusBar:GetFrameLevel() + 2)

  widgets.duration:SetScale(self.lowerScale)
  widgets.duration:SetFontObject(addonTable.CurrentNumberFont)
  local font = addonTable.Config.Get(addonTable.Config.Options.NUMBER_FONT)
  if font.flags.slug then
    widgets.duration:SetScale(14/12)
    widgets.duration:SetTextScale(1)
  else
    widgets.duration:SetScale(1)
    widgets.duration:SetTextScale(14/12)
  end

  widgets.icon:SetShown(details.icon.show)

  self:SetShown(widgets.source:IsShown())

  self.details = details
end

function addonTable.Display.AuraStatusBarMixin:UpdateSource(sourceWidget)
  if sourceWidget ~= self.widgets.source then
    self:Setup(sourceWidget, self.details)
  else
    sourceWidget:SetParent(self)
    sourceWidget:SetAllPoints(self)
    self:NotifyActive(sourceWidget:IsShown())
  end
end

function addonTable.Display.AuraStatusBarMixin:GetDefaultSize()
  return PixelUtil.ConvertPixelsToUIForRegion(self.rawWidth * self.details.scale, self), PixelUtil.ConvertPixelsToUIForRegion(self.rawHeight * self.details.scale, self)
end

function addonTable.Display.AuraStatusBarMixin:ApplySize(width, height)
  local sizing = addonTable.Display.GetSizingForStatusBar(self, width, height)
  PixelUtil.SetSize(self, sizing.rawWidth, sizing.rawHeight)
  PixelUtil.SetSize(self.widgets.statusBar, sizing.statusWidth * self.lowerScale, sizing.statusHeight * self.lowerScale)
  PixelUtil.SetSize(self.widgets.border, sizing.borderWidth * self.lowerScale, sizing.borderHeight  * self.lowerScale)
  if sizing.iconSize > 0 then
    self.widgets.icon:Show()
    PixelUtil.SetSize(self.widgets.icon, sizing.iconSize, sizing.iconSize)
  else
    self.widgets.icon:Hide()
  end

  PixelUtil.SetPoint(self.widgets.icon.Applications, "BOTTOMRIGHT", self.widgets.icon, "BOTTOMRIGHT", -5, 5)

  self.widgets.icon:ClearAllPoints()
  self.widgets.statusBar:ClearAllPoints()
  self.widgets.duration:ClearAllPoints()
  if self.details.layout == "horizontal" then
    self.widgets.icon:SetPoint(self.details.icon.position == "left" and "LEFT" or "RIGHT")
    self.widgets.statusBar:SetPoint(self.details.icon.position == "left" and "RIGHT" or "LEFT")
    self.widgets.duration:SetPoint("RIGHT", self.widgets.statusBar, -8, 0)
  else
    self.widgets.icon:SetPoint(self.details.icon.position == "left" and "BOTTOM" or "TOP")
    self.widgets.statusBar:SetPoint(self.details.icon.position == "left" and "TOP" or "BOTTOM")
    self.widgets.duration:SetPoint("BOTTOM", self.widgets.statusBar, 0, 8)
  end

  self.widgets.source:SetAllPoints(self)
end

function addonTable.Display.AuraStatusBarMixin:NotifyActive(state)
  self:SetShown(state)
end
