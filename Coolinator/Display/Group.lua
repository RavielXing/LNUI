---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.GroupMixin = {}

function addonTable.Display.GroupMixin:OnLoad()
end

function addonTable.Display.GroupMixin:Disable()
end

function addonTable.Display.GroupMixin:GetDefaultSize()
  return self.width, self.height
end

function addonTable.Display.GroupMixin:SetDefaultSize(width, height)
  self.width, self.height = width, height
end

function addonTable.Display.GroupMixin:ApplySize(width, height)
  self:SetSize(self.width, self.height)

  if self.details.layout == "horizontal" then
    local padding = (addonTable.Constants.nativeSize - 4) * self.details.padding
    width = (width - padding * (#self.details.entries - 1)) / #self.details.entries
    height = height and math.max(self.height, height) or self.height

    for _, w in ipairs(self.children) do
      if w.ApplySize then
        w:ApplySize(width, height)
      end
    end

    local point = "LEFT"
    if self.details.alignment ~= "CENTER" then
      point = self.details.alignment .. point
    end
    local newWidth = 0
    for _, child in ipairs(self.children) do
      child:ClearAllPoints()
      PixelUtil.SetPoint(child, point, self, point, newWidth / child:GetScale(), 0)
      local childWidth = child:GetWidth()
      if not self.autoSize or child:IsShown() and childWidth > 0 then
        newWidth = newWidth + childWidth * child:GetScale() + padding
      end
    end
    PixelUtil.SetWidth(self, newWidth - padding)

  elseif self.details.layout == "vertical" then
    local padding = (addonTable.Constants.nativeSize - 4) * self.details.padding
    width = (height - padding * (#self.details.entries - 1)) / #self.details.entries
    width = width and math.max(self.width, width) or self.width

    for _, w in ipairs(self.children) do
      if w.ApplySize then
        w:ApplySize(width, height)
      end
    end

    local point = "BOTTOM"
    if self.details.alignment ~= "CENTER" then
      point = point .. self.details.alignment
    end
    local newHeight = 0
    for _, child in ipairs(self.children) do
      child:ClearAllPoints()
      PixelUtil.SetPoint(child, point, self, point, 0, newHeight / child:GetScale())
      local childHeight = child:GetHeight()
      if not self.autoSize or child:IsShown() and childHeight > 0 then
        newHeight = newHeight + childHeight * child:GetScale() + padding
      end
    end
    PixelUtil.SetHeight(self, newHeight - padding)

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

function addonTable.Display.GroupMixin:Setup(details)
  self.details = details
  self.width, self.height = 0, 0
  self.autoSize = addonTable.Config.Get(addonTable.Config.Options.COMPRESS_LAYOUT)
end
