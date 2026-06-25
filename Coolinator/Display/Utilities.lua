---@class addonTableCoolinator
local addonTable = select(2, ...)

local LSM = LibStub("LibSharedMedia-3.0")

function addonTable.Display.ApplyStatusBar(details, statusBar, border, borderMask, background)
  local borderDetails = LSM:Fetch("ninesliceborder", details.border.asset, true) or LSM:Fetch("ninesliceborder", "Cooli: 1px")
  assert(borderDetails)
  local borderSliceDetails = LSM:Fetch("nineslice", borderDetails.nineslice)
  assert(borderSliceDetails)
  local foregroundAsset = LSM:Fetch("statusbar", details.foreground.asset, true) or LSM:Fetch("statusbar", "Cooli: Solid White")
  local backgroundAsset = LSM:Fetch("statusbar", details.background.asset, true) or LSM:Fetch("statusbar", "Cooli: Solid White")

  local rawWidth, rawHeight = details.width * addonTable.Assets.BarBordersSize.width, details.height * addonTable.Assets.BarBordersSize.height
  if details.layout == "vertical" then
    local tmp = rawWidth
    rawWidth = rawHeight
    rawHeight = tmp
    statusBar:SetOrientation("VERTICAL")
  else
    statusBar:SetOrientation("HORIZONTAL")
  end
  local borderWidth = rawWidth + (borderSliceDetails.padding.left + borderSliceDetails.padding.right) / 2
  local borderHeight = rawHeight + (borderSliceDetails.padding.top + borderSliceDetails.padding.bottom) / 2

  statusBar:SetStatusBarTexture(foregroundAsset)
  statusBar:GetStatusBarTexture():SetDrawLayer("ARTWORK")
  statusBar:SetScale(borderSliceDetails.scaleModifier * details.scale)
  statusBar:GetStatusBarTexture():SetVertexColor(details.foreground.color.r, details.foreground.color.g, details.foreground.color.b)

  local lowerScale = 1/borderSliceDetails.scaleModifier

  background:SetTexture(backgroundAsset)
  background:SetVertexColor(details.background.color.r, details.background.color.g, details.background.color.b, details.background.color.a)

  border:SetTexture(borderSliceDetails.file)
  border:SetVertexColor(details.border.color.r, details.border.color.g, details.border.color.b, details.border.color.a)
  border:SetTextureSliceMargins(borderSliceDetails.margins.left, borderSliceDetails.margins.top, borderSliceDetails.margins.right, borderSliceDetails.margins.bottom)
  if border:GetParent() ~= statusBar and border:GetParent():GetParent() ~= statusBar then
    border:SetScale(borderSliceDetails.scaleModifier * details.scale)
  end

  statusBar:GetStatusBarTexture():RemoveMaskTexture(borderMask)
  background:RemoveMaskTexture(borderMask)

  local maskDetails = borderDetails.mask
  borderMask:SetBlockingLoadsRequested(true)
  borderMask:SetTexture(maskDetails.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  borderMask:SetTextureSliceMargins(maskDetails.margins.left, maskDetails.margins.top, maskDetails.margins.right, maskDetails.margins.bottom)

  statusBar:GetStatusBarTexture():AddMaskTexture(borderMask)
  background:AddMaskTexture(borderMask)

  return rawWidth, rawHeight, borderWidth, borderHeight, lowerScale
end

function addonTable.Display.GeneratePool(mixin, template)
  return CreateFramePool("Frame", UIParent, template or "CoolinatorPropagateMouseClicksTemplate", function(_, frame)
    frame:SetScript("OnShow", nil)
    frame:SetScript("OnHide", nil)
    frame:SetScript("OnSizeChanged", nil)
    if frame.Disable then
      frame:Disable()
    end
    frame:SetParent(UIParent)
    frame:ClearAllPoints()
    frame:Hide()
  end, false, function(frame)
    Mixin(frame, mixin)
    frame:OnLoad()
  end)
end

function addonTable.Display.ApplyAnchor(frame, anchor, scale)
  scale = scale or 1
  frame:ClearAllPoints()
  if #anchor == 0 then
    frame:SetPoint("CENTER")
  elseif #anchor == 3 then
    PixelUtil.SetPoint(frame, anchor[1], frame:GetParent(), "CENTER", anchor[2] * scale, anchor[3] * scale)
  elseif #anchor == 2 then
    PixelUtil.SetPoint(frame, "CENTER", frame:GetParent(), "CENTER", anchor[1] * scale, anchor[2] * scale)
  elseif #anchor == 1 then
    frame:SetPoint(anchor[1], frame:GetParent(), "CENTER")
  end
end

do
  local fractional = C_StringUtil.CreateNumericRuleFormatter()
  fractional:SetBreakpoints({
    {
      threshold = 0,
      step = 0.1,
      format = "%.1f",
    },
    {
      threshold = 3,
      step = 1,
      format = "%d",
    },
    {
      threshold = 60,
      format = COOLDOWN_DURATION_MIN,
      components = {
        {
          div = 60,
          step = 1,
        }
      }
    }
  })

  local basic = C_StringUtil.CreateNumericRuleFormatter()
  basic:SetBreakpoints({
    {
      threshold = 0,
      step = 1,
      format = "%d",
    },
    {
      threshold = 60,
      format = COOLDOWN_DURATION_MIN,
      components = {
        {
          div = 60,
          step = 1,
        }
      }
    }
  })

  function addonTable.Display.GetDurationFormatter(isFractional)
    return isFractional and fractional or basic
  end
end

function addonTable.Display.GetSizingForStatusBar(frame, width, height)
  local rawWidth, rawHeight = frame.rawWidth * frame.details.scale, frame.rawHeight * frame.details.scale
  if frame.details.autoSize then
    if frame.details.layout == "horizontal" then
      rawWidth = width or rawWidth
    end
    if frame.details.layout == "vertical" then
      rawHeight = height or rawHeight
    end
  end
  local statusWidth, statusHeight = frame.rawWidth, frame.rawHeight
  local borderWidth, borderHeight = frame.borderWidth, frame.borderHeight
  local iconSize = 0
  if frame.details.icon and frame.details.icon.show then
    if frame.details.layout == "vertical" then
      iconSize = frame.rawWidth * frame.details.scale
      local offset = (frame.borderHeight - frame.rawHeight) / 2 + 1 + iconSize
      local new = rawHeight - offset
      if new >= addonTable.Assets.BarBordersSize.width * 0.1 then
        statusHeight = new / frame.details.scale
        borderHeight = borderHeight + (rawHeight - offset - frame.rawHeight * frame.details.scale) / frame.details.scale
      else
        iconSize = 0
      end
    else
      iconSize = frame.rawHeight * frame.details.scale
      local offset = (frame.borderWidth - frame.rawWidth) / 2 + 1 + iconSize
      local new = rawWidth - offset
      if new >= addonTable.Assets.BarBordersSize.width * 0.1 then
        statusWidth = new / frame.details.scale
        borderWidth = borderWidth + (rawWidth - offset - frame.rawWidth * frame.details.scale) / frame.details.scale
      else
        iconSize = 0
      end
    end
  else
    statusWidth, statusHeight = rawWidth / frame.details.scale, rawHeight / frame.details.scale
    borderWidth = borderWidth + (statusWidth - frame.rawWidth)
    borderHeight = borderHeight + (statusHeight - frame.rawHeight)
  end
  return {
    rawWidth = rawWidth, rawHeight = rawHeight,
    statusWidth = statusWidth, statusHeight = statusHeight,
    borderWidth = borderWidth, borderHeight = borderHeight,
    iconSize = iconSize
  }
end
