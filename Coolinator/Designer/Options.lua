---@class addonTableCoolinator
local addonTable = select(2, ...)

local function Announce()
  addonTable.CallbackRegistry:TriggerEvent("Designer.Options.SavePreset")
end

local function GetPresets(parent)
  local dropdown = addonTable.CustomiseDialog.Components.GetBasicDropdown(parent, addonTable.Locales.PRESET)
  local details
  function dropdown:SetValue(d)
    details = d
    dropdown.DropDown:SetupMenu(function(_, rootDescription)
      local presets = GetKeysArray(addonTable.Core.GetApplicablePresets(details))
      if #presets > 0 then
        table.sort(presets)
        for _, p in ipairs(presets) do
          local label = p
          if addonTable.Locales[p] then
            label = BLUE_FONT_COLOR:WrapTextInColorCode(addonTable.Locales[p])
          end
          local button = rootDescription:CreateRadio(label, function() return details.preset == p end, function()
            details.preset = p
            addonTable.Core.ApplyPresetToDetails(details)
            Announce()
          end)
          button:AddInitializer(function(button, description, menu)
            if InCombatLockdown() then
              return
            end
            local delete = MenuTemplates.AttachAutoHideButton(button, "transmog-icon-remove")
            delete:SetPoint("RIGHT")
            delete:SetSize(18, 18)
            delete.Texture:SetAtlas("transmog-icon-remove")
            delete:SetScript("OnClick", function()
              menu:Close()
              addonTable.Dialogs.ShowConfirm(addonTable.Locales.CONFIRM_DELETE_PRESET_X:format(label), YES, NO, function()
                addonTable.Core.DeletePreset(p, details, addonTable.Designer.GetCurrent())
                dropdown.DropDown:GenerateMenu()
              end)
            end)
            MenuUtil.HookTooltipScripts(delete, function(tooltip)
              GameTooltip_SetTitle(tooltip, DELETE)
            end)
          end)
        end
        rootDescription:CreateDivider()
      end
      rootDescription:CreateButton(NORMAL_FONT_COLOR:WrapTextInColorCode(addonTable.Locales.CREATE_PRESET), function()
        addonTable.Dialogs.ShowEditBox(addonTable.Locales.ENTER_PRESET_NAME, OKAY, CANCEL, function(value)
          details.preset = value
          addonTable.Core.SavePreset(value, details.___origin or details, true)
          dropdown.DropDown:GenerateMenu()
        end)
      end)
      rootDescription:CreateButton(addonTable.Locales.DETACH_PRESET, function()
        details.preset = nil
        Announce()
      end)
    end)
  end
  dropdown.DropDown:SetDefaultText(GRAY_FONT_COLOR:WrapTextInColorCode(addonTable.Locales.NONE_SET))

  return dropdown
end

local pixelStep = 0.5

local function RoundPixel(pixel)
  return Round(pixel / pixelStep) * pixelStep
end

local GetIconTextPositioning

local function UpdateWidgetPoints(preview, w, snapping, offsetX, offsetY)
  snapping = snapping or 2
  offsetX = offsetX or 0
  offsetY = offsetY or 0
  local left, bottom, width, height = w:GetRect()
  local widgetRect = {left = left + offsetX, bottom = bottom + offsetY, width = width, height = height}
  left, bottom, width, height = preview:GetRect()
  local previewRect = {left = left, bottom = bottom, width = width, height = height}
  local widgetCenter = {x = widgetRect.left + widgetRect.width / 2, y = widgetRect.bottom + widgetRect.height / 2}
  local previewCenter = {x = previewRect.left + previewRect.width / 2, y = previewRect.bottom + previewRect.height / 2}

  local point, x, y = "", 0, 0

  local snapX, snapY, xLock, yLock = 0, 0, false, false
  if math.abs(widgetCenter.y - previewCenter.y) < snapping then
    snapY = previewCenter.y - widgetCenter.y
    point = point
    yLock = true
  elseif widgetCenter.y < previewCenter.y then
    point = "TOP" .. point
    y = widgetRect.bottom + widgetRect.height - previewCenter.y
  else
    point = "BOTTOM" .. point
    y = widgetRect.bottom - previewCenter.y
  end

  if math.abs(widgetCenter.x - previewCenter.x) < snapping then
    snapX = previewCenter.x - widgetCenter.x
    xLock = true
    point = point
  elseif widgetCenter.x < previewCenter.x then
    point = point .. "LEFT"
    x = widgetRect.left - previewCenter.x
  else
    point = point .. "RIGHT"
    x = widgetRect.left + widgetRect.width - previewCenter.x
  end

  if point == "" then
    w.details.anchor = {}
  elseif x == 0 and y == 0 then
    w.details.anchor = {point}
  else
    w.details.anchor = {point, RoundPixel(x), RoundPixel(y)}
  end

  if x ~= 0 then
    snapX = RoundPixel(x) - x
  end
  if y ~= 0 then
    snapY = RoundPixel(y) - y
  end

  -- snapX, snapY used to offset other widgets to keep them all consistent to each other
  -- xLock, yLock used to prevent a widget shifting because its been centered on an axis
  -- (this prevents infinite loops from the shifts bouncing around)
  return snapX, snapY, xLock, yLock
end

local function GenerateOptions(parent, yOffset, xOffset, entries)
  local allFrames = {}

  for _, e in ipairs(entries) do
    local frame
    local function Setter(value)
      if not parent.details then
        return
      end
      local oldValue = e.getter(parent.details)
      e.setter(parent.details, value)
      if type(oldValue) == "table" then
        if not tCompare(oldValue, e.getter(parent.details)) then
          Announce()
        end
      elseif oldValue ~= e.getter(parent.details) then
        Announce()
      end
    end
    local function Getter()
      if not parent.details then
        return
      end
      return e.getter(parent.details)
    end
    if e.hide then
      frame = nil
    elseif e.kind == "slider" then
      if e.valuePattern then
        frame = addonTable.CustomiseDialog.Components.GetSlider(parent, e.label, e.min, e.max, function(val) return e.valuePattern:format(val) end, Setter)
      else
        frame = addonTable.CustomiseDialog.Components.GetSlider(parent, e.label, e.min, e.max, e.formatter, Setter)
      end
    elseif e.kind == "dropdown" then
      frame = addonTable.CustomiseDialog.Components.GetBasicDropdown(parent, e.label, function(value)
        if not parent.details then
          return false
        end
        if type(value) == "table" then
          return tCompare(value, e.getter(parent.details))
        else
          return value == e.getter(parent.details)
        end
      end, Setter)
    elseif e.kind == "checkbox" then
      frame = addonTable.CustomiseDialog.Components.GetCheckbox(parent, e.label, 28 + xOffset, Setter)
    elseif e.kind == "colorPicker" then
      frame = addonTable.CustomiseDialog.Components.GetColorPicker(parent, e.label, 28 + xOffset, Setter)
    elseif e.kind == "colorPickerWithCheckbox" then
      frame = addonTable.CustomiseDialog.Components.GetColorPickerWithCheckbox(parent, e.label, 28 + xOffset, Setter)
    elseif e.kind == "iconTexts" then
      frame = GetIconTextPositioning(parent, 615339)
    elseif e.kind == "presets" then
      frame = GetPresets(parent)
    end

    if frame then
      frame.kind = e.kind
      frame.getInitData = e.getInitData
      frame.Getter = Getter
      if #allFrames == 0 then
        frame:SetPoint("TOP", 0, yOffset)
      else
        frame:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, yOffset)
      end
      table.insert(allFrames, frame)
      yOffset = 0
    elseif e.kind == "spacer" then
      yOffset = -30
    end
  end

  return allFrames
end

local function GetSelectorMarker(frame, isHover)
  local texture = frame:CreateTexture()
  texture:SetTexture("Interface/AddOns/Coolinator/Assets/selection-outline.png")
  texture:SetVertexColor(78/255, 165/255, 252/255, isHover and 0.45 or 0.8)
  texture:SetTextureSliceMargins(45, 45, 45, 45)
  texture:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
  texture:SetScale(0.25)
  texture:SetAllPoints()

  return frame
end

function GetIconTextPositioning(rootParent, iconID)
  local container = CreateFrame("Frame", nil, rootParent)
  container:SetPoint("LEFT")
  container:SetPoint("RIGHT")
  container:SetHeight(300)
  local previewInset = CreateFrame("Frame", nil, container, "InsetFrameTemplate")
  previewInset:SetSize(160, 120)
  previewInset:SetPoint("TOP")

  local preview = CreateFrame("Frame", nil, previewInset)

  preview:SetPoint("TOP")

  preview:SetAllPoints()
  preview:SetFlattensRenderLayers(true)
  preview:SetScale(3)

  preview:SetSize(40, 40)

  local wrapper = CreateFrame("Frame", nil, preview)
  wrapper:SetSize(addonTable.Constants.nativeSize - 4, addonTable.Constants.nativeSize - 4)
  wrapper:SetPoint("CENTER")
  wrapper.Icon = wrapper:CreateTexture(nil, "ARTWORK")
  wrapper.Icon:SetTexture(iconID)
  wrapper.Icon:SetPoint("CENTER")
  wrapper.Icon:SetAllPoints()
  wrapper.Icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

  local expectedTexts = {"keybinding", "count", "cooldown"}

  local widgetOptions = {}
  for _, kind in ipairs(expectedTexts) do
    local optionsContainer = CreateFrame("Frame", nil, container)
    optionsContainer:SetPoint("TOP", preview, "BOTTOM", 0, -30)
    optionsContainer:SetPoint("LEFT")
    optionsContainer:SetPoint("RIGHT")
    optionsContainer:SetHeight(10)
    optionsContainer.allFrames = GenerateOptions(optionsContainer, 0, 0, addonTable.Designer.IconTextsConfig[kind])

    widgetOptions[kind] = optionsContainer
  end

  local titleText = container:CreateFontString(nil, nil, "GameFontHighlightLarge")
  titleText:SetPoint("TOP", previewInset, "BOTTOM", 0, -10)
  titleText:SetJustifyH("RIGHT")
  titleText:SetPoint("RIGHT", -40, 0)
  titleText:SetShadowOffset(1, -1)

  local titleMap = {
    countdown = addonTable.Locales.COUNTDOWN,
    stacks = addonTable.Locales.STACKS,
  }

  local selectedMarker = GetSelectorMarker(CreateFrame("Frame", nil, container), false)
  local hoverMarker = GetSelectorMarker(CreateFrame("Frame", nil, container), true)
  local selection = nil

  local keyboardTrap = CreateFrame("Frame", nil, container)
  keyboardTrap:Hide()

  local function OffsetWidgets(x, y)
    UpdateWidgetPoints(preview, selection, 0.4, x, y)
    Announce()
  end

  keyboardTrap:SetScript("OnKeyDown", function(_, key)
    keyboardTrap:SetPropagateKeyboardInput(false)
    local amount = pixelStep
    if IsShiftKeyDown() then
      amount = amount * 4
    end
    if key == "LEFT" then
      OffsetWidgets(-amount, 0)
    elseif key == "RIGHT" then
      OffsetWidgets(amount, 0)
    elseif key == "UP" then
      OffsetWidgets(0, amount)
    elseif key == "DOWN" then
      OffsetWidgets(0, -amount)
    elseif key == "DELETE" then
      selection.details.visible = false
      Announce()
    else
      keyboardTrap:SetPropagateKeyboardInput(true)
    end
  end)
  keyboardTrap:RegisterEvent("PLAYER_REGEN_ENABLED")
  keyboardTrap:RegisterEvent("PLAYER_REGEN_DISABLED")
  keyboardTrap:SetScript("OnEvent", function(_, event)
    keyboardTrap:SetShown(event == "PLAYER_REGEN_ENABLED" and selection)
  end)

  local function UpdateSelection()
    if selection then
      selectedMarker:Show()
      selectedMarker:SetFrameStrata("HIGH")
      selectedMarker:ClearAllPoints()
      selectedMarker:SetPoint("TOPLEFT", selection, "TOPLEFT", -2, 2)
      selectedMarker:SetPoint("BOTTOMRIGHT", selection, "BOTTOMRIGHT", 2, -2)

      for kind, optionsContainer in pairs(widgetOptions) do
        if kind == selection.kind then
          optionsContainer:Show()
          optionsContainer.details = selection.details
          for _, f in ipairs(optionsContainer.allFrames) do
            if f.getInitData then
              f:Init(f.getInitData(selection.details))
            end
            f:SetValue(f.Getter())
          end
        else
          optionsContainer:Hide()
        end
      end

      titleText:Show()
      titleText:SetText(titleMap[selection.kind])
      keyboardTrap:SetShown(not InCombatLockdown())
    else
      titleText:Hide()
      for _, optionsContainer in pairs(widgetOptions) do
        optionsContainer:Hide()
      end
      selectedMarker:Hide()
      keyboardTrap:Hide()
    end
  end

  local function ToggleSelection(w)
    if selection == w then
      selection = nil
    else
      selection = w
    end
    UpdateSelection()
  end
  local function ForceSelection(w)
    selection = w
    UpdateSelection()
  end

  preview.widgets = {}

  for _, key in ipairs(expectedTexts) do
    local w = CreateFrame("Frame", nil, wrapper)
    w:SetSize(1, 1)
    preview.widgets[key] = w
    w.text = w:CreateFontString(nil, nil, "GameFontNormal")
    w.kind = key
    w:SetMovable(true)
    w:EnableMouse(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnEnter", function()
      hoverMarker:Show()
      hoverMarker:SetFrameStrata("HIGH")
      hoverMarker:ClearAllPoints()
      hoverMarker:SetPoint("TOPLEFT", w, "TOPLEFT", -2, 2)
      hoverMarker:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", 2, -2)
    end)
    w:SetScript("OnLeave", function()
      hoverMarker:Hide()
    end)
    w:SetScript("OnDragStart", function()
      w:StartMoving()
      ForceSelection(w)
    end)
    w:SetScript("OnDragStop", function()
      w:StopMovingOrSizing()
      UpdateWidgetPoints(preview, w, 1)
      ForceSelection(w)
      Announce()
    end)
    w:SetScript("OnMouseUp", function()
      ToggleSelection(w)
    end)
  end

  preview.widgets.cooldown.text:SetText(3)
  preview.widgets.count.text:SetText(2)
  preview.widgets.keybinding.text:SetText("s-2")

  function container:SetValue(details)
    container.details = details.texts
    wrapper.Icon:SetShown(not details.textsOnly)

    local font = addonTable.Config.Get(addonTable.Config.Options.NUMBER_FONT)
    for _, key in ipairs(expectedTexts) do
      local text = preview.widgets[key].text
      local textDetails = details.texts[key]
      if textDetails then
        text:ClearAllPoints()
        text:SetFontObject(addonTable.CurrentNumberFont)
        if font.slug then
          text:SetSmoothScaling(true)
          text:SetTextScale(1)
          text:SetScale(textDetails.scale)
        else
          text:SetSmoothScaling(false)
          text:SetTextScale(textDetails.scale)
          text:SetScale(1)
        end
        text:SetPoint(textDetails.anchor[1] or "CENTER")
        text:SetTextColor(textDetails.color.r, textDetails.color.g, textDetails.color.b)
        if key == "cooldown" then
          if textDetails.showFractions then
            text:SetText("2.9")
          else
            text:SetText("3")
          end
        end
        if textDetails.visible then
          preview.widgets[key]:SetAlpha(1)
        else
          preview.widgets[key]:SetAlpha(0.5)
        end
        local w, h = text:GetSize()
        preview.widgets[key]:SetSize(w * text:GetScale(), h * text:GetScale())
        preview.widgets[key].details = textDetails

        addonTable.Display.ApplyAnchor(preview.widgets[key], {textDetails.anchor[1], textDetails.anchor[2], textDetails.anchor[3]})
      end
    end

    UpdateSelection()
  end

  return container
end

local function GenerateKindOptions(parent, options)
  local container = CreateFrame("Frame", nil, parent)

  local tabManager = CreateFrame("Frame", nil, container)
  tabManager:SetPoint("TOP", 0, -5)
  tabManager:SetPoint("LEFT")
  tabManager:SetPoint("RIGHT")
  tabManager:SetHeight(30)

  local tabs = {}
  local tabMap = {}
  local function InitTab(tab, tabButton, label)
    tab:SetPoint("LEFT")
    tab:SetPoint("RIGHT")
    tab:SetHeight(300)
    tab.button = tabButton
    tabButton.kind = label
    tabButton.label = label
    tab.resourceSpecificSettings = {}

    tabMap[label] = tab
    table.insert(tabs, tab)
  end
  local paths = {
    ["*"] = {
      ["*"] = {}
    }
  }
  local tabsPool = CreateObjectPool(function()
    return addonTable.CustomiseDialog.Components.GetTab(tabManager)
  end, Pool_HideAndClearAnchors)
  local wrappersPool = CreateFramePool("Frame", container)

  container:SetPoint("TOPLEFT", addonTable.Constants.ButtonFrameOffset, -25)
  container:SetPoint("BOTTOMRIGHT")
  for k1, l1 in pairs(options) do
    for k2, l2 in pairs(l1) do
      for _, tabDetails in ipairs(l2) do
        local c = CreateFrame("Frame", nil, container)
        c.label = tabDetails.label
        c:Hide()
        c:SetPoint("LEFT")
        c:SetPoint("RIGHT")
        c.allFrames = GenerateOptions(c, 0, 0, tabDetails.entries)
        function c:UpdateOptions(details)
          c.details = details

          for _, f in ipairs(c.allFrames) do
            if f.getInitData then
              f:Init(f.getInitData(c.details))
            end
            if f.SetValue then
              f:SetValue(f.Getter())
            end
          end
        end
        if not paths[k1] then
          paths[k1] = {}
        end
        if not paths[k1][k2] then
          paths[k1][k2] = {}
        end
        table.insert(paths[k1][k2], c)
      end
    end
  end

  function container:SetTab(label)
    PanelTemplates_SelectTab(tabMap[label].button)
    for _, t in ipairs(tabs ) do
      t:Hide()
      if t.children[1].label ~= label then
        PanelTemplates_DeselectTab(t.button)
      end
    end
    tabMap[label]:Show()
    for _, child in ipairs(tabMap[label].children) do
      child:UpdateOptions(container.details)
    end
  end

  local previousPath = ""

  local function SetupPath(details)
    local newPath = details.resource and (details.resource.kind .. "$" .. (details.resource.resource or "")) or "ALL"
    if newPath == previousPath then
      return
    end
    local rootListing = paths["*"]["*"]
    for _, t in ipairs(tabs) do
      for _, child in ipairs(t.children) do
        child:Hide()
      end
    end
    tabsPool:ReleaseAll()
    wrappersPool:ReleaseAll()
    tabs = {}
    tabMap = {}
    for _, entry in ipairs(rootListing) do
      local wrapper = wrappersPool:Acquire()
      wrapper.button = tabsPool:Acquire()
      wrapper.button:SetText(entry.label)
      wrapper.button:GetScript("OnShow")(wrapper.button) -- auto size
      wrapper.button:Show()
      wrapper:SetAllPoints()
      wrapper.children = {entry}
      entry:SetParent(wrapper)
      entry:SetPoint("TOP", wrapper, 0, -35)
      entry:Show()
      entry:SetHeight(entry.allFrames[1]:GetTop() - entry.allFrames[#entry.allFrames]:GetBottom())
      tabMap[entry.label] = wrapper
      table.insert(tabs, wrapper)
    end
    if details.resource and paths[details.resource.kind] then
      for _, entry in ipairs(paths[details.resource.kind]["*"] or {}) do
        if tabMap[entry.label] then
          local wrapper = tabMap[entry.label]
          entry:SetParent(wrapper)
          entry:SetPoint("TOP", wrapper.children[#wrapper.children], "BOTTOM", 0, -30)
          entry:Show()
          table.insert(wrapper.children, entry)
        else
          local wrapper = wrappersPool:Acquire()
          wrapper.button = tabsPool:Acquire()
          wrapper.button:SetText(entry.label)
          wrapper.button:GetScript("OnShow")(wrapper.button) -- auto size
          wrapper.button:Show()
          wrapper:SetAllPoints()
          wrapper.children = {entry}
          entry:SetParent(wrapper)
          entry:Show()
          entry:SetPoint("TOP", wrapper, 0, -35)
          tabMap[entry.label] = wrapper
          table.insert(tabs, wrapper)
        end
        entry:SetHeight(entry.allFrames[1]:GetTop() - entry.allFrames[#entry.allFrames]:GetBottom())
      end
      if paths[details.resource.kind][details.resource.resource] then
        for _, entry in ipairs(paths[details.resource.kind][details.resource.resource] or {}) do
          if tabMap[entry.label] then
            local wrapper = tabMap[entry.label]
            entry:SetParent(wrapper)
            entry:SetPoint("TOP", wrapper.children[#wrapper.children], "BOTTOM", 0, -30)
            entry:Show()
            table.insert(wrapper.children, entry)
          else
            local wrapper = wrappersPool:Acquire()
            wrapper.button = tabsPool:Acquire()
            wrapper.button:SetText(entry.label)
            wrapper.button:GetScript("OnShow")(wrapper.button) -- auto size
            wrapper.button:Show()
            wrapper:SetAllPoints()
            wrapper.children = {entry}
            entry:SetParent(wrapper)
            entry:Show()
            entry:SetPoint("TOP", wrapper, 0, -35)
            tabMap[entry.label] = wrapper
            table.insert(tabs, wrapper)
          end
          entry:SetHeight(entry.allFrames[1]:GetTop() - entry.allFrames[#entry.allFrames]:GetBottom())
        end
      end
    end
    for _, t in ipairs(tabs) do
      t.button:SetScript("OnClick", function()
        container:SetTab(t.children[1].label)
      end)
    end
    previousPath = newPath
  end

  function container:UpdateOptions(details)
    SetupPath(details)
    container.details = details
    local any = false
    local lastTab
    for _, t in ipairs(tabs) do
      if t:IsShown() then
        any = true
        PanelTemplates_SelectTab(t.button)
        for _, child in ipairs(t.children) do
          child:UpdateOptions(details)
        end
      end
      if not lastTab then
        t.button:SetPoint("TOPLEFT", 20, 0)
      else
        t.button:SetPoint("TOPLEFT", lastTab, "TOPRIGHT", 5, 0)
      end
      lastTab = t.button
    end
    if not any then
      tabs[1].button:Click()
    end
  end

  return container
end

local function GetMetaDetails(detailsList)
  if #detailsList <= 1 then
    return detailsList[1]
  end
  local mapping = {}
  local lastTbl = {}
  local detailsMeta = {
    __newindex = function(tbl, index, value)
      for _, d in ipairs(detailsList) do
        d[index] = value
      end
    end,
    __index = function(tbl, index)
      if index == "___origin" then
        return detailsList[1]
      end
      if type(detailsList[1][index]) == "table" and not index:match("[Cc]olor") then
        if mapping[index] and lastTbl[index] == detailsList[1][index] then
          return mapping[index]
        end
        local list = {}
        for _, details in ipairs(detailsList) do
          table.insert(list, details[index])
        end
        lastTbl[index] = detailsList[1][index]
        mapping[index] = GetMetaDetails(list)
        return mapping[index]
      else
        return detailsList[1][index]
      end
    end,
  }
  local details = {}
  setmetatable(details, detailsMeta)

  return details
end

local optionsFrames = {}
function addonTable.Designer.GenerateOptionsFromDetails(detailsList)
  if optionsFrames[addonTable.Config.Get(addonTable.Config.Options.CURRENT_SKIN)] then
    local frame = optionsFrames[addonTable.Config.Get(addonTable.Config.Options.CURRENT_SKIN)]
    local oldDetails = frame.details
    frame.details = GetMetaDetails(detailsList)
    if frame.details and (frame.details ~= oldDetails or not frame:IsShown()) then
      frame:Show()
      frame:Update()
    else
      frame:Hide()
    end
    return
  end

  local frame = addonTable.CustomiseDialog.Components.GetContentFrame(
    "CoolinatorDesignerOptionsDialog" .. addonTable.Config.Get(addonTable.Config.Options.CURRENT_SKIN),
    600, 550
  )
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", 10, -10)
  optionsFrames[addonTable.Config.Get(addonTable.Config.Options.CURRENT_SKIN)] = frame

  local function SetTitle()
    local label = addonTable.Constants.KindToLabel[frame.details.kind]
    if frame.details.kind == "bar" and frame.details.resource then
      label = label .. " - " .. addonTable.Constants.BarResourceLabelMap[frame.details.resource.kind]
      if frame.details.resource.kind == "class" then
        label = label .. " - " .. addonTable.Constants.BarClassResourceLabelMap[frame.details.resource.resource]
      end
    elseif frame.details.kind == "icon" then
      label = label .. " - " .. addonTable.Constants.IconResourceLabelMap[frame.details.resource.kind]
    end
    frame:SetTitle(addonTable.Locales.CUSTOMISE_COOLINATOR_X:format(label))
  end

  local containers = {}
  for kind, o in pairs(addonTable.Designer.WidgetConfiguration) do
    containers[kind] = GenerateKindOptions(frame, o)
    containers[kind]:Hide()
  end

  function frame:Update()
    if not frame.details then
      self:Hide()
      return
    end
    local any = false
    SetTitle()
    for kind, c in pairs(containers) do
      c.details = frame.details
      if frame.details.kind == kind then
        c:Show()
        c:UpdateOptions(frame.details)
      else
        c:Hide()
      end
      any = any or c:IsShown()
    end
    if not any then
      frame:Hide()
    end
  end

  addonTable.CallbackRegistry:RegisterCallback("Designer.Close", function()
    frame:Hide()
  end)

  addonTable.CallbackRegistry:RegisterCallback("Designer.Layout", function()
    if frame:IsVisible() then
      frame:Update()
    end
  end)

  addonTable.CallbackRegistry:RegisterCallback("Designer.Options.SavePreset", function()
    if frame.details and frame.details.preset then
      addonTable.Core.SavePreset(frame.details.preset, frame.details.___origin or frame.details, true)
    end
    addonTable.CallbackRegistry:TriggerEvent("Designer.Layout")
  end)

  frame:SetScript("OnHide", function()
    for kind, c in pairs(containers) do
      c:Hide()
    end
  end)

  frame.details = GetMetaDetails(detailsList)

  frame:Show()
  frame:Update()
end
