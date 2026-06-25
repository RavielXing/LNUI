---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.BaseLayoutManagerMixin = {}
function addonTable.Display.BaseLayoutManagerMixin:OnLoad()
  self.toArrange = {}
end

function addonTable.Display.BaseLayoutManagerMixin:GetIcon(details)
  assert(false)
end

function addonTable.Display.BaseLayoutManagerMixin:GetBar(details)
  assert(false)
end

function addonTable.Display.BaseLayoutManagerMixin:Delayout()
  assert(false)
end

function addonTable.Display.BaseLayoutManagerMixin:Layout()
  assert(false)
end

local function AnchorStandalone(widget, anchor)
  local point, relativeTo, relativePoint, offsetX, offsetY = unpack(anchor)
  PixelUtil.SetPoint(widget, point, relativeTo, relativePoint, offsetX/widget:GetScale(), offsetY/widget:GetScale())
end

function addonTable.Display.BaseLayoutManagerMixin:GetGroup(details)
  local wrapper = self.groupPool:Acquire()
  wrapper:Show()
  wrapper:SetAlpha(details.layout == "standalone" and 1 or details.alpha)
  wrapper:SetScale(details.layout == "standalone" and 1 or details.scale)
  wrapper:Setup(details)
  wrapper.children = {}
  wrapper.details = details
  for _, entry in ipairs(details.entries) do
    if entry.kind == "icon" then
      local icon = self:GetIcon(entry)
      if icon then
        icon:SetScale(entry.scale)
        icon:SetAlpha(entry.alpha)
        icon:SetParent(wrapper)
        table.insert(wrapper.children, icon)
      end
      if details.layout == "standalone" then
        AnchorStandalone(wrapper, entry.anchor)
      end
    elseif entry.kind == "bar" then
      local bar = self:GetBar(entry)
      if bar then
        bar:SetParent(wrapper)
        bar:SetAlpha(entry.alpha)
        table.insert(wrapper.children, bar)
        if details.layout == "standalone" then
          AnchorStandalone(bar, entry.anchor)
        end
      end
    elseif entry.kind == "group" then
      local subWrapper = self:GetGroup(entry)
      table.insert(wrapper.children, subWrapper)
      subWrapper:SetParent(wrapper)
      if details.layout == "standalone" then
        AnchorStandalone(subWrapper, entry.anchor)
      end
    end
  end

  self:ArrangeGroup(wrapper, details)

  return wrapper
end

function addonTable.Display.BaseLayoutManagerMixin:NotifyLayoutChange(wrapper)
  if not self.autoSize or self.pending or self.toArrange[wrapper] or not wrapper.details then
    return
  end
  local levels = {}
  while wrapper.details.layout ~= "standalone" do
    table.insert(levels, wrapper)
    wrapper = wrapper:GetParent()
  end
  for index, w in ipairs(levels) do
    self.toArrange[w] = index
  end

  self:SetScript("OnUpdate", function()
    local wrappers = GetKeysArray(self.toArrange)
    table.sort(wrappers, function(a, b)
      return self.toArrange[a] < self.toArrange[b]
    end)
    self.pending = true
    for _, w in ipairs(wrappers) do
      self:ArrangeGroup(w, w.details)
    end
    self.pending = false
    self.toArrange = {}
    self:SetScript("OnUpdate", nil)
  end)
end

function addonTable.Display.BaseLayoutManagerMixin:AddHooksForChanges(children)
  if not self.autoSize then
    for _, child in ipairs(children) do
      child:SetScript("OnShow", nil)
      child:SetScript("OnHide", nil)
      child:SetScript("OnSizeChanged", nil)
    end

    return
  end

  for _, child in ipairs(children) do
    child:SetScript("OnShow", function()
      self:NotifyLayoutChange(child:GetParent())
    end)
    child:SetScript("OnHide", function()
      self:NotifyLayoutChange(child:GetParent())
    end)
    child:SetScript("OnSizeChanged", function()
      self:NotifyLayoutChange(child:GetParent())
    end)
  end
end

function addonTable.Display.BaseLayoutManagerMixin:ArrangeGroup(wrapper, details)
  local offsetSize = addonTable.Constants.nativeSize - 4

  if details.layout == "horizontal" then
    local point = "LEFT"
    if details.alignment ~= "CENTER" then
      point = details.alignment .. point
    end
    local maxHeight = 0
    local width = 0
    for _, child in ipairs(wrapper.children) do
      child:ClearAllPoints()
      PixelUtil.SetPoint(child, point, wrapper, point, width / child:GetScale(), 0)
      local childWidth, childHeight
      if child.GetDefaultSize then
        childWidth, childHeight = child:GetDefaultSize()
      else
        childWidth, childHeight = child:GetWidth(), child:GetHeight()
      end
      if not self.autoSize or child:IsShown() and childWidth > 0 then
        maxHeight = math.max(childHeight * child:GetScale(), maxHeight)
        width = width + childWidth * child:GetScale() + details.padding * offsetSize
      end
    end
    if #wrapper.children > 0 then
      width = width - details.padding * offsetSize
    end
    PixelUtil.SetSize(wrapper, width, maxHeight)
    wrapper:SetDefaultSize(width, maxHeight)

    self:AddHooksForChanges(wrapper.children)
  elseif details.layout == "vertical" then
    local point = "BOTTOM"
    if details.alignment ~= "CENTER" then
      point = point .. details.alignment
    end
    local height = 0
    local maxWidth = 0
    for _, child in ipairs(wrapper.children) do
      child:ClearAllPoints()
      PixelUtil.SetPoint(child, point, wrapper, point, 0, height / child:GetScale())
      local childWidth, childHeight = child:GetWidth(), child:GetHeight()
      if child.GetDefaultSize then
        childWidth, childHeight = child:GetDefaultSize()
      else
        childWidth, childHeight = child:GetWidth(), child:GetHeight()
      end
      if not self.autoSize or child:IsShown() and childHeight > 0 then
        maxWidth = math.max(childWidth * child:GetScale(), maxWidth)
        height = height + childHeight * child:GetScale() + details.padding * offsetSize
      end
    end
    if #wrapper.children > 0 then
      height = height - details.padding * offsetSize
    end
    PixelUtil.SetSize(wrapper, maxWidth, height)
    wrapper:SetDefaultSize(maxWidth, height)

    self:AddHooksForChanges(wrapper.children)
  else -- standalone
    wrapper:ApplySize(0, 0)
  end
end
