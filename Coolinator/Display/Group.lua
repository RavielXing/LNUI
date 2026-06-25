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
    width = nil
    height = height and math.max(self.height, height) or self.height
  elseif self.details.layout == "vertical" then
    height = nil
    width = width and math.max(self.width, width) or self.width
  else
    width = width and math.max(self.width, width) or self.width
    height = height and math.max(self.height, height) or self.height
  end

  for _, w in ipairs(self.children) do
    if w.ApplySize then
      w:ApplySize(width, height)
    end
  end
end

function addonTable.Display.GroupMixin:Setup(details)
  self.details = details
  self.width, self.height = 0, 0
end
