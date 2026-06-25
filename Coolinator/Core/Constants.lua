---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Constants = {
  IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE,
  IsMists = WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC,
  --IsCata = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC,
  IsWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC,
  IsBC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC,
  IsEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC,
  IsClassic = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE,

  IsMidnight = select(4, GetBuildInfo()) >= 120001,

  ButtonFrameOffset = 5,

  DefaultFont = "Arial Narrow",
  FontFamilies = {"roman", "korean", "simplifiedchinese", "traditionalchinese", "russian"},

  DefaultName = "DEFAULT",

  nativeSize = 40,

  GCD = 61304,
}
addonTable.Constants.Events = {
  "SettingChanged",
  "RefreshStateChange",

  "AuraBarsChanged",

  "Layout",
  "Update.SpellIcons",
  "Update.KeyBindings",
  "Update.SpellsDisplay",

  "Designer.Open",
  "Designer.Close",
  "Designer.Options",
  "Designer.Layout",
  "Designer.Reanchor",
}

addonTable.Constants.RefreshReason = {
  Design = 1,
}

addonTable.Constants.ClassResources = {
  -- Death Knight
  ["DEATHKNIGHT"] = {"runes", "runic-power"},
  [250] = {"runes", "runic-power"}, -- Blood
  [251] = {"runes", "runic-power"}, -- Frost
  [252] = {"runes", "runic-power"}, -- Unholy
  [1455] = {},
  -- Demon Hunter
  ["DEMONHUNTER"] = {"fury", "pain"},
  [577] = {"fury"}, -- Havoc,
  [581] = {"pain"}, -- Vengeance
  [1480] = {"pain"}, -- Devourer
  [1456] = {},
  -- Druid
  ["DRUID"] = {"combo-points", "mana", "rage", "energy"},
  [102] = {"astral-power"}, -- Balance
  [103] = {"combo-points", "energy"}, -- Feral
  [104] = {"rage"}, -- Guardian
  [105] = {"mana"}, -- Resto
  [1447] = {},
  -- Evoker
  ["EVOKER"] = {"essence", "mana"},
  [1467] = {"essence", "mana"}, -- Devastation
  [1468] = {"essence", "mana"}, -- Preservation
  [1473] = {"essence", "mana"}, -- Augmentation
  [1465] = {},
  -- Hunter
  ["HUNTER"] = {"focus"},
  [253] = {"focus"}, -- Beast Mastery
  [254] = {"focus"}, -- Marksmanship
  [255] = {"focus", "tip-of-the-spear"}, -- Survival
  [1448] = {"focus"},
  -- Mage
  ["MAGE"] = {"mana", "arcane-charges"},
  [62] = {"arcane-charges", "mana"}, -- Arcane
  [63] = {"mana"}, -- Fire
  [64] = {"mana", "icicles"}, -- Frost
  [1449] = {"mana"},
  -- Monk
  ["MONK"] = {"chi", "energy", "mana", "stagger"},
  [268] = {"stagger", "energy"}, -- Brewmaster
  [270] = {"mana"}, -- Mistweaver
  [269] = {"chi", "energy"}, -- Windwalker
  [1450] = 30,
  -- Paladin
  ["PALADIN"] = {"holy-power", "mana"},
  [65] = {"holy-power","mana"}, -- Holy
  [66] = {"holy-power","mana"}, -- Protection
  [70] = {"holy-power", "mana"}, -- Retribution
  [1451] = {"mana"},
  -- Priest
  ["PRIEST"] = {"mana", "insanity"},
  [256] = {"mana"}, -- Discipline
  [257] = {"mana"}, -- Holy
  [258] = {"mana", "insanity"}, -- Shadow
  [1452] = {"mana"},
  -- Rogue
  ["ROGUE"] = {"energy", "combo-points"},
  [259] = {"energy", "combo-points"}, -- Assassination
  [260] = {"energy", "combo-points"}, -- Outlaw
  [261] = {"energy", "combo-points"}, -- Subtlety
  [1453] = {"energy", "combo-points"},
  -- Shaman
  ["SHAMAN"] = {"maelstrom-weapon", "mana"},
  [262] = {"maelstrom", "mana"}, -- Elemental
  [263] = {"maelstrom-weapon", "mana"}, -- Enhancement
  [264] = {"mana"}, -- Restoration
  [1444] = {"mana"},
  -- Warlock
  ["WARLOCK"] = {"soul-shards", "mana"},
  [265] = {"soul-shards", "mana"}, -- Affliction
  [266] = {"soul-shards", "mana"}, -- Demonology
  [267] = {"soul-shards", "mana"}, -- Destruction
  [1454] = {"soul-shards", "mana"},
  ["WARRIOR"] = {"rage"},
  [71] = {"rage"}, -- Arms
  [72] = {"rage"}, -- Fury
  [73] = {"rage"}, -- Protection
  [1446] = {"rage"},
}

addonTable.Constants.KindToLabel = {
  ["bar"] = addonTable.Locales.BAR,
  ["icon"] = addonTable.Locales.ICON,
  ["group"] = addonTable.Locales.GROUP,
}

addonTable.Constants.BarResourceLabelMap = {
  ["class"] = addonTable.Locales.CLASS,
  ["aura"] = addonTable.Locales.AURA,
  ["ability"] = addonTable.Locales.ABILITY,
}

addonTable.Constants.BarClassResourceLabelMap = {
  ["runes"] = RUNES,
  ["runic-power"] = RUNIC_POWER,
  ["fury"] = FURY,
  ["pain"] = POWER_TYPE_PAIN,
  ["mana"] = MANA,
  ["rage"] = RAGE,
  ["astral-power"] = POWER_TYPE_LUNAR_POWER,
  ["combo-points"] = COMBO_POINTS,
  ["energy"] = ENERGY,
  ["essence"] = POWER_TYPE_ESSENCE,
  ["focus"] = FOCUS,
  ["arcane-charges"] = ARCANE_CHARGES,
  ["icicles"] = addonTable.Locales.ICICLES,
  ["chi"] = CHI,
  ["holy-power"] = HOLY_POWER,
  ["insanity"] = INSANITY,
  ["maelstrom"] = MAELSTROM,
  ["maelstrom-weapon"] = addonTable.Locales.MAELSTROM_WEAPON,
  ["soul-shards"] = SOUL_SHARDS,
  ["stagger"] = STAGGER,
  ["tip-of-the-spear"] = addonTable.Locales.TIP_OF_THE_SPEAR,
}

addonTable.Constants.IconResourceLabelMap = {
  ["aura"] = addonTable.Locales.AURA,
  ["ability"] = addonTable.Locales.ABILITY,
  ["item"] = addonTable.Locales.ITEM,
  ["equipment"] = addonTable.Locales.EQUIPMENT,
}

addonTable.Constants.AurasFromItems = {
  -- Light's Potential
  [1236616] = {
    itemIDs = {
      [241309] = true,
      [241308] = true,
      [245897] = true,
      [245898] = true,
    },
    duration = 30,
    deathPersistent = false,
  },
  -- Light's Preservation
  [1235568] = {
    itemIDs = {
      [241287] = true,
      [241286] = true,
    },
    duration = 30,
    deathPersistent = false,
  },
  -- Shrouded in Void
  [1236551] = {
    itemIDs = {
      [241303] = 12, -- 12s
      [241302] = 18, -- 18s
    },
    duration = -1,
    deathPersistent = false,
  },
  -- Potion of Recklessness
  [1236994] = {
    itemIDs = {
      [241289] = true,
      [241288] = true,
    },
    duration = 30,
    deathPersistent = false,
  },
  -- Potion of Zealotry
  [1238443] = {
    itemIDs = {
      [245900] = true,
      [245901] = true,
      [241297] = true,
      [241296] = true,
    },
    duration = 30,
    deathPersistent = false,
  },
  -- Draught of Rampant Abandon
  [1236998] = {
    itemIDs = {
      [241293] = true,
      [241292] = true,
    },
    duration = 30,
    deathPersistent = false,
  },
  -- Enlightened
  [1236652] = {
    itemIDs = {
      [241339] = 6,
      [241338] = 13,
    },
    duration = -1,
    deathPersistent = false,
  }
}
