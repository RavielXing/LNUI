---@class addonTableCoolinator
local addonTable = select(2, ...)

local textsByKey = {
  Duration = "duration",
  Name = "name",
}

addonTable.Display.AuraStatusBarMixin = {}
function addonTable.Display.AuraStatusBarMixin:OnLoad()
  self:SetIgnoringChildrenForBounds(true)
  self:SetCollapsesLayout(true)
end

local sourceFrames = {}

function addonTable.Display.AuraStatusBarMixin:Setup(sourceWidget, details)
  local statusBar = sourceWidget.Bar

  if not sourceFrames[sourceWidget] then
    sourceWidget.DebuffBorder:SetParent(addonTable.hiddenFrame)
    statusBar.BarBG:SetParent(addonTable.hiddenFrame)
    statusBar.Pip:SetParent(addonTable.hiddenFrame)
    sourceWidget.Icon:SetParent(addonTable.hiddenFrame)

    local background = statusBar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local borderWrapper = CreateFrame("Frame", nil, statusBar)
    borderWrapper:SetAllPoints()
    local border = borderWrapper:CreateTexture(nil, "BORDER")
    border:SetPoint("CENTER")
    local borderMask = statusBar:CreateMaskTexture()
    borderMask:SetAllPoints()
    local textsContainer = CreateFrame("Frame", nil, statusBar)
    textsContainer:SetAllPoints()
    statusBar.Name:SetParent(textsContainer)
    textsContainer.Name = statusBar.Name
    statusBar.Duration:SetParent(textsContainer)
    textsContainer.Duration = statusBar.Duration

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

    statusBar.Name:SetWordWrap(false)
    statusBar.Duration:SetWordWrap(false)

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
      name = statusBar.Name,
      textsContainer = textsContainer,
    }
  end

  local widgets = sourceFrames[sourceWidget]
  sourceWidget:SetParent(self)

  self.widgets = widgets

  self.TextsContainer = widgets.textsContainer
  self.statusBar = widgets.statusBar

  widgets.source:SetMouseMotionEnabled(addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))

  self.rawWidth, self.rawHeight, self.borderWidth, self.borderHeight, self.lowerScale = addonTable.Display.ApplyStatusBar(details, statusBar, widgets.border, widgets.borderMask, widgets.background)

  widgets.borderWrapper:SetFrameLevel(widgets.statusBar:GetFrameLevel() + 2)
  widgets.textsContainer:SetFrameLevel(widgets.statusBar:GetFrameLevel() + 4)

  widgets.duration:SetFontObject(addonTable.CurrentNumberFont)
  widgets.name:SetFontObject(addonTable.CurrentNumberFont)

  addonTable.Display.ApplyTexts(self, details, textsByKey, self.lowerScale)

  widgets.icon:SetShown(details.icon.show)

  self:SetShown(widgets.source:IsShown())
  if self:IsShown() then
    self:ApplyPadding(self.paddingH or 0, self.paddingV or 0)
  else
    self:SetSize(0.001, 0.001)
  end

  self.details = details
end

function addonTable.Display.AuraStatusBarMixin:UpdateSource(sourceWidget)
  if sourceWidget ~= self.widgets.source then
    self:Setup(sourceWidget, self.details)
  else
    sourceWidget:SetParent(self)
    sourceWidget:SetAllPoints(self)
    for key, settingsKey in pairs(textsByKey) do
      self.TextsContainer[key]:SetShown(self.details.texts[settingsKey].visible)
    end
    self:NotifyActive(sourceWidget:IsShown())
  end
end

function addonTable.Display.AuraStatusBarMixin:GetDefaultSize()
  return self.rawWidth * self.details.scale, self.rawHeight * self.details.scale
end

function addonTable.Display.AuraStatusBarMixin:ApplySize(width, height)
  width = width or self.lastWidth
  height = height or self.lastHeight
  self.lastWidth, self.lastHeight = width, height
  local sizing = addonTable.Display.GetSizingForStatusBar(self, width, height)
  PixelUtil.SetSize(self, sizing.rawWidth, sizing.rawHeight)
  PixelUtil.SetSize(self.widgets.statusBar, sizing.statusWidth * self.lowerScale, sizing.statusHeight * self.lowerScale)
  PixelUtil.SetSize(self.widgets.border, sizing.borderWidth * self.lowerScale, sizing.borderHeight  * self.lowerScale)
  self.sizingWidth, self.sizingHeight = sizing.rawWidth, sizing.rawHeight
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
  else
    self.widgets.icon:SetPoint(self.details.icon.position == "left" and "BOTTOM" or "TOP")
    self.widgets.statusBar:SetPoint(self.details.icon.position == "left" and "TOP" or "BOTTOM")
  end

  addonTable.Display.SizeTextsForBar(self, self.details, textsByKey, self.lowerScale)

  self.widgets.source:SetAllPoints(self)
end

function addonTable.Display.AuraStatusBarMixin:NotifyActive(state)
  if state ~= self:IsShown() then
    self:SetShown(state)
    if state then
      self:ApplyPadding(self.paddingH or 0, self.paddingV or 0)
    else
      self:SetSize(0.001, 0.001)
    end
    if self:GetParent().TriggerLayout then
      self:GetParent():TriggerLayout()
    end
  end
end

function addonTable.Display.AuraStatusBarMixin:ApplyPadding(horizontal, vertical)
  horizontal = horizontal or self.paddingH
  vertical = vertical or self.paddingV
  self.paddingH = horizontal
  self.paddingV = vertical
  PixelUtil.SetSize(self, self.sizingWidth + horizontal, self.sizingHeight + vertical)
end
