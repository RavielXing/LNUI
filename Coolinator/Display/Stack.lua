---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.StackMixin = {}

function addonTable.Display.StackMixin:OnLoad()
end

function addonTable.Display.StackMixin:Disable()
end

function addonTable.Display.StackMixin:GetDefaultSize()
  return self.width, self.height
end

function addonTable.Display.StackMixin:SetDefaultSize(width, height)
  self.width, self.height = width, height
end

function addonTable.Display.StackMixin:Setup(details)
  self.details = details
  self.children = {}
  self.width, self.height = 0, 0
  self.autoSize = addonTable.Config.Get(addonTable.Config.Options.COMPRESS_LAYOUT)
end

function addonTable.Display.StackMixin:ApplySize(width, height)
  for _, child in ipairs(self.children) do
    if child.ApplySize then
      child:ApplySize(self.width, self.height)
    end
  end
end
