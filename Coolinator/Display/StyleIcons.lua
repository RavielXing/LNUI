---@class addonTableCoolinator
local addonTable = select(2, ...)

local function SetupText(fontString, details)
  local font = addonTable.Config.Get(addonTable.Config.Options.NUMBER_FONT)
  local text = fontString:GetText()
  fontString:ClearText()
  fontString:SetFontObject(addonTable.CurrentNumberFont)
  if font.flags.slug then
    fontString:SetScale(font.size * details.scale)
    fontString:SetTextScale(1)
    addonTable.Display.ApplyAnchor(fontString, details.anchor, 1/details.scale/font.size)
    fontString:SetWidth(addonTable.Constants.nativeSize * details.widthLimit / details.scale / font.size)
    fontString:SetSmoothScaling(true)
  else
    fontString:SetScale(1)
    fontString:SetTextScale(font.size * details.scale)
    addonTable.Display.ApplyAnchor(fontString, details.anchor, 1)
    fontString:SetWidth(addonTable.Constants.nativeSize * details.widthLimit)
    fontString:SetSmoothScaling(false)
  end
  fontString:SetTextColor(details.color.r, details.color.g, details.color.b)
  local alignment = details.anchor[1] == nil and "CENTER" or details.anchor[1]:match("RIGHT") or details.anchor[1]:match("LEFT") or "CENTER"
  fontString:SetJustifyH(alignment)
  fontString:SetText(text)

  fontString:SetShown(details.visible)
end

local function Compare(a, b)
end

function addonTable.Display.StyleIcon(styleSettings, parent, icon, count, keybinding, maskedTextures, cooldowns)
  local details = parent.details

  local font = addonTable.Config.Get(addonTable.Config.Options.NUMBER_FONT)
  local styleID = {
    id = styleSettings.id,
    font = font,
    texts = details.texts,
    textsOnly = details.textsOnly,
    showIcon = details.showIcon,
  }
  if parent.styleSet and tCompare(styleID, parent.styleSet, 5) and icon == parent.Icon then
    return
  end
  if icon ~= parent.Icon then
    parent.Icon = icon
  end
  if not parent.border then
    parent.borderWrapper = CreateFrame("Frame", nil, parent)
    parent.borderWrapper:SetAllPoints(parent)
    parent.borderWrapper:SetFrameLevel(count:GetParent():GetFrameLevel())
    parent.border = parent.borderWrapper:CreateTexture()
    parent.border:SetPoint("CENTER")
    parent.Mask = parent:CreateMaskTexture()
  end

  for _, c in ipairs(cooldowns) do
    local text = c.widget:GetRegions()
    SetupText(text, details.texts.cooldown)
    c.widget:SetHideCountdownNumbers(not c.text and details.texts.cooldown.visible)
  end
  SetupText(count, details.texts.count)
  if keybinding then
    SetupText(keybinding, details.texts.keybinding)
  end

  parent.Mask:SetAllPoints(icon)

  parent.Icon = icon

  for _, t in ipairs(maskedTextures) do
    if t:GetNumMaskTextures() > 0 then
      for i = t:GetNumMaskTextures(), 1, -1 do
        local m = t:GetMaskTexture(i)
        t:RemoveMaskTexture(m)
      end
    end
  end

  local mask = parent.Mask
  mask:SetBlockingLoadsRequested(true)

  if styleSettings.id == "square" then
    local asset = addonTable.Assets.IconBorders["Cooli: 1px"]
    mask:SetTexture(asset.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    parent.border:SetTexture(asset.file)
    parent.border:SetVertexColor(0, 0, 0)
    parent.border:SetSize(addonTable.Constants.nativeSize, addonTable.Constants.nativeSize)
    for _, c in ipairs(cooldowns) do
      if c.widget:GetDrawSwipe() then
        c.widget:SetSwipeTexture(asset.mask)
      end
    end
  else--if styleSettings.id == "blizzard" then
    mask:SetTexture("Interface/AddOns/Coolinator/Assets/IconBorders/blizzard-mask.png", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    parent.border:SetTexture("Interface/AddOns/Coolinator/Assets/IconBorders/blizzard.png")
    parent.border:SetVertexColor(1, 1, 1)
    parent.border:SetSize(50+5, 50+5)
    for _, c in ipairs(cooldowns) do
      if c.widget:GetDrawSwipe() then
        c.widget:SetSwipeTexture("Interface/HUD/UI-HUD-CoolDownManager-Icon-Swipe")
      end
    end
  end

  for _, t in ipairs(maskedTextures) do
    t:AddMaskTexture(mask)
  end

  icon:SetShown(details.showIcon)
  parent.border:SetShown(details.showIcon)

  parent.styleSet = CopyTable(styleID)
end
