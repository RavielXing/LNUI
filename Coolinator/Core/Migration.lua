---@class addonTableCoolinator
local addonTable = select(2, ...)

local function GetColor(rgb)
  local color = CreateColorFromRGBHexString(rgb)
  return {r = color.r, g = color.g, b = color.b}
end

local function AddAlignment(group)
  if group.kind == "group" then
    if group.layout ~= "standalone" then
      group.alignment = "CENTER"
    end
    for _, entry in ipairs(group.entries) do
      AddAlignment(entry)
    end
  end
end

function addonTable.Core.RemoveDeadGroups(group)
  for i = #group.entries, 1, -1 do
    local entry = group.entries[i]
    if entry.kind == "group" then
      addonTable.Core.RemoveDeadGroups(entry)
      if #entry.entries == 0 then
        table.remove(group.entries, i)
      end
    end
  end
end

local function AddStylev3(group)
  for i = #group.entries, 1, -1 do
    local entry = group.entries[i]
    if entry.kind == "group" then
      AddStylev3(entry)
    elseif entry.kind == "icon" then
      entry.style = "blizzard"
    end
  end
end

local function UseBaseSpellsv4(group)
  for i = #group.entries, 1, -1 do
    local entry = group.entries[i]
    if entry.kind == "group" then
      UseBaseSpellsv4(entry)
    elseif entry.kind == "icon" and entry.resource.kind == "ability" then
      entry.resource.spellID = C_Spell.GetBaseSpell(entry.resource.spellID)
    elseif entry.kind == "icon" and entry.resource.kind == "aura" then
      entry.resource.spellID = C_Spell.GetBaseSpell(entry.resource.spellID)
    end
  end
end

local function Textsv6(group)
  for i = #group.entries, 1, -1 do
    local entry = group.entries[i]
    if entry.kind == "group" then
      Textsv6(entry)
    elseif entry.kind == "icon" then
      entry.showTooltips = true
      entry.texts = {
        cooldown = {
          anchor = {},
          scale = Round(14/12 * 100) / 100,
          color = GetColor("FFFFFF"),
          visible = true,
          showFractions = false,
        },
        count = {
          anchor = {"BOTTOMLEFT", -2, -2},
          scale = Round(11/12 * 100) / 100,
          color = GetColor("FFFFFF"),
          visible = true,
        }
      }
    end
  end
end

local function Textsv7(group)
  for i = #group.entries, 1, -1 do
    local entry = group.entries[i]
    if entry.kind == "group" then
      Textsv7(entry)
    elseif entry.kind == "icon" then
      entry.showTooltips = nil
      entry.texts.keybinding = {
        anchor = {"TOPRIGHT", 18, 18},
        scale = Round(13/12 * 100) / 100,
        color = GetColor("b3b3b3"),
        visible = true,
        widthLimit = 0.8,
      }
      entry.texts.count = {
        anchor = {"BOTTOMRIGHT", 18, -18},
        scale = 1,
        color = GetColor("ffffff"),
        visible = true,
        widthLimit = 0.8,
      }
      entry.texts.cooldown = {
        anchor = {},
        scale = Round(20/12 * 100) / 100,
        color = GetColor("FFFFFF"),
        visible = true,
        showFractions = false,
        widthLimit = 0.9,
      }
    end
  end
end

local function Iconsv9(group)
  for i = #group.entries, 1, -1 do
    local entry = group.entries[i]
    if entry.kind == "group" then
      Iconsv9(entry)
    elseif entry.kind == "icon" then
      if entry.resource.kind == "ability" then
        entry.desaturateCooldown = false
      end
      entry.showSwipe = true
    end
  end
end

local function Iconsv10(group)
  for i = #group.entries, 1, -1 do
    local entry = group.entries[i]
    if entry.kind == "group" then
      Iconsv10(entry)
    elseif entry.kind == "icon" then
      entry.showIcon = not entry.textsOnly
      entry.showSwipe = not entry.textsOnly
      entry.textsOnly = nil
    end
  end
end

local function Iconsv11(group)
  for i = #group.entries, 1, -1 do
    local entry = group.entries[i]
    if entry.kind == "group" then
      Iconsv11(entry)
    elseif entry.kind == "bar" and entry.resource.kind == "class" then
      entry.icon = nil
    end
  end
end

local steps = {
  AddAlignment,
  addonTable.Core.RemoveDeadGroups,
  AddStylev3,
  UseBaseSpellsv4,
  UseBaseSpellsv4,
  Textsv6,
  Textsv7,
  Textsv7,
  Iconsv9,
  Iconsv10,
  Iconsv11,
}

function addonTable.Core.UpgradeDesign(design)
  if not design.version then
    design.version = 0
  end
  for index, callback in ipairs(steps) do
    if design.version < index then
      callback(design)
    end
  end
  design.version = #steps
end

function addonTable.Core.MigrateSettings()
  addonTable.Core.AutoGenerateLayout()

  for _, specDetails in pairs(addonTable.Config.Get(addonTable.Config.Options.DESIGNS)) do
    for _, design in pairs(specDetails) do
      addonTable.Core.UpgradeDesign(design)
    end
  end

  local presets = addonTable.Config.Get(addonTable.Config.Options.PRESETS)
  local presetsGrouped = addonTable.Core.GetPresetsGrouped(presets)
  addonTable.Core.UpgradeDesign(presetsGrouped)
  presets.version = presetsGrouped.version
end
