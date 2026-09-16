---@class Data
local Data = select(2, ...)

if not Data.L then
  Data.L = setmetatable({}, {
    __index = function(_, k)
      return k
    end,
  })
  print("|cffff0000BattleGroundEnemiesFixed|r: Locales.lua failed to load. Reinstall the addon.")
end
local L = Data.L

local GetClassInfo = GetClassInfo
local GetNumSpecializationsForClassID = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID
  or GetNumSpecializationsForClassID
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID
local IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

Data.PlayerRoles = { "TANK", "HEALER", "DAMAGER" }

Data.RaceNameToToken = {}
do
  local playableRaces = {
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    22,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    34,
    35,
    36,
    37,
    52,
    70,
    84,
    85,
    86,
    91,
  }
  for i = 1, #playableRaces do
    local info = C_CreatureInfo.GetRaceInfo(playableRaces[i])
    if info and info.raceName and info.clientFileString then
      Data.RaceNameToToken[info.raceName] = info.clientFileString
    end
  end
end

Data.CyrillicToRomanian = { -- source Wikipedia: https://en.wikipedia.org/wiki/Romanization_of_Russian
  ["А"] = "a",
  ["а"] = "a",
  ["Б"] = "b",
  ["б"] = "b",
  ["В"] = "v",
  ["в"] = "v",
  ["Г"] = "g",
  ["г"] = "g",
  ["Д"] = "d",
  ["д"] = "d",
  ["Е"] = "e",
  ["е"] = "e",
  ["Ё"] = "e",
  ["ё"] = "e",
  ["Ж"] = "zh",
  ["ж"] = "zh",
  ["З"] = "z",
  ["з"] = "z",
  ["И"] = "i",
  ["и"] = "i",
  ["Й"] = "i",
  ["й"] = "i",
  ["К"] = "k",
  ["к"] = "k",
  ["Л"] = "l",
  ["л"] = "l",
  ["М"] = "m",
  ["м"] = "m",
  ["Н"] = "n",
  ["н"] = "n",
  ["О"] = "o",
  ["о"] = "o",
  ["П"] = "p",
  ["п"] = "p",
  ["Р"] = "r",
  ["р"] = "r",
  ["С"] = "s",
  ["с"] = "s",
  ["Т"] = "t",
  ["т"] = "t",
  ["У"] = "u",
  ["у"] = "u",
  ["Ф"] = "f",
  ["ф"] = "f",
  ["Х"] = "kh",
  ["х"] = "kh",
  ["Ц"] = "ts",
  ["ц"] = "ts",
  ["Ч"] = "ch",
  ["ч"] = "ch",
  ["Ш"] = "sh",
  ["ш"] = "sh",
  ["Щ"] = "shch",
  ["щ"] = "shch",
  ["Ъ"] = "ie",
  ["ъ"] = "ie",
  ["Ы"] = "y",
  ["ы"] = "y",
  ["Ь"] = "",
  ["ь"] = "",
  ["Э"] = "e",
  ["э"] = "e",
  ["Ю"] = "iu",
  ["ю"] = "iu",
  ["Я"] = "ia",
  ["я"] = "ia",
}

Data.Buttons = {
  Target = TARGET,
  Focus = SET_FOCUS,
  Custom = L.UserDefined,
}

Data.ObjectiveAndRespawnPosition = {
  Left = L.LEFT,
  Right = L.RIGHT,
  LeftToTargetCounter = L.LeftToTargetCounter,
}

Data.DisplayType = {
  Frame = L.Frame,
  Countdowntext = L.Countdowntext,
}

Data.DebuffTypes = {
  HELPFUL = {
    Magic = L.Magic,
  },
  HARMFUL = {
    Magic = L.Magic,
    Disease = L.Disease,
    Poison = L.Poison,
    Curse = L.Curse,
  },
}
Data.RandomDebuffType = {} -- for testmode

do
  local i = 1
  local DebuffTypeColor = DebuffTypeColor
    or {
      ["Magic"] = { r = 0.20, g = 0.60, b = 1.00 },
      ["Curse"] = { r = 0.60, g = 0.00, b = 1.00 },
      ["Disease"] = { r = 0.60, g = 0.40, b = 0 },
      ["Poison"] = { r = 0.00, g = 0.60, b = 0 },
      ["none"] = { r = 0.80, g = 0, b = 0 },
    }
  for engName, color in pairs(DebuffTypeColor) do
    Data.RandomDebuffType[i] = engName
    i = i + 1
  end
end

Data.AllPositions = {
  TOPLEFT = L.TOPLEFT,
  TOP = L.TOP,
  TOPRIGHT = L.TOPRIGHT,
  LEFT = L.LEFT,
  CENTER = L.CENTER,
  RIGHT = L.RIGHT,
  BOTTOMLEFT = L.BOTTOMLEFT,
  BOTTOM = L.BOTTOM,
  BOTTOMRIGHT = L.BOTTOMRIGHT,
}

Data.BasicPositions = {
  LEFT = L.LEFT,
  RIGHT = L.RIGHT,
}

Data.HorizontalDirections = {
  leftwards = L.Leftwards,
  rightwards = L.Rightwards,
}
Data.VerticalDirections = {
  upwards = L.Upwards,
  downwards = L.Downwards,
}

Data.SpellPriorities = {}

Data.BattlegroundspezificBuffs =
  { --key = mapID, value = table with key = faction(0 for horde, 1 for alliance) value spellId of the flag, minecart
    [1339] = { -- Warsong Gulch, used to be mapID 443 before BFA
      [0] = 156621, -- Alliance Flag
      [1] = 156618, -- Horde Flag
    },
    [1460] = { -- Warsong Gulch, used in Classic, TBCC
      [0] = 301091, -- Alliance Flag
      [1] = 301089, -- Horde Flag
    },
    [112] = { -- Eye of the Storm, used to be mapID 482 before BFA
      [0] = 34976, -- Netherstorm Flag
      [1] = 34976, -- Netherstorm Flag
    },
    [1956] = { -- Eye of the Storm, TBCC
      [0] = 34976, -- Netherstorm Flag
      [1] = 34976, -- Netherstorm Flag
    },
    [397] = { -- Eye of the Storm (mapID RBG only? Not sure why there are two map IDs for Eye of the Storm), used to be mapID 813 before BFA
      [0] = 34976, -- Netherstorm Flag
      [1] = 34976, -- Netherstorm Flag
    },
    [206] = { -- Twin Peaks, used to be mapID 626 before BFA
      [0] = 156621, -- Alliance Flag
      [1] = 156618, -- Horde Flag
    },
    [2345] = { -- Deephaul Ravine added in Patch 11.0.2
      [0] = 434339, -- Deephaul Crystal
      [1] = 434339, -- Deephaul Crystal
    },
    [417] = { -- Temple of Kotmogu, used to be mapID 856 before BFA
      [0] = 121164, -- Orb of Power, Blue
      [1] = 121175, -- Orb of Power, Purple
      [2] = 121176, -- Orb of Power, Green
      [3] = 121177, -- Orb of Power, Orange
    },
  }

local trinketCD
if IsRetail or UnitLevel("player") >= 70 then
  trinketCD = 120
else
  trinketCD = 300
end

Data.TrinketData = {
  [195710] = { cd = 180 }, -- 1: Honorable Medallion, 3. min. CD, detected by Combatlog
  [42292] = { cd = trinketCD, itemID = 37865 }, -- 2: Medallion of the Alliance, Medallion of the Horde used in Classic, TBC, and probably some other Expansions  2 min. CD, detected by Combatlog, should show as Medaillon; used in TBC etc
  [208683] = { cd = 120 }, -- 2: Gladiator's Medallion, 2 min. CD, detected by Combatlog
  [336126] = { cd = 120 }, -- 2: Gladiator's Medallion, 2 min. CD, Shadowlands Update
  --	[195901] = {cd = 60, fileID = GetSpellTexture(214027)			},		-- 3: Adaptation, 1 min. CD, detected by Aura 195901
  --	[214027] = {cd = 60												},		-- 3: Adaptation, 1 min. CD, detected by Aura 195901, for the Arena_cooldownupdate
  --	[336135] = {cd = 60												},		-- 3: Adaptation, 1 min. CD, Shadowlands Update
  --	[336139] = {cd = 60, fileID = GetSpellTexture(214027)			},		-- 3: Adapted, 1 min. CD, Shadowlands Update
  [196029] = { cd = false }, -- 4: Relentless, passive, no CD
  [336128] = { cd = false }, -- 4: Relentless, passive, no CD, Shadowlands Update
  [363117] = { cd = false }, -- 5: Gladiator's Fastidious Resolve, Added in Shadowlands Patch 9.2
}

Data.Classes = {}
Data.RolesToSpec = { HEALER = {}, TANK = {}, DAMAGER = {} } --for Testmode only
Data.ClassList = {} -- For TBCC Testmode only

do
  local specIdToRessource = {
    --Death Knight
    [250] = "RUNIC_POWER", --Blood
    [251] = "RUNIC_POWER", --Frost
    [252] = "RUNIC_POWER", --Unholy
    --Demon Hunter
    [577] = "FURY", --Havoc
    [581] = "PAIN", --Vengeance
    --Druid
    [102] = "LUNAR_POWER", --Balance
    [103] = "ENERGY", --Feral Combat
    [104] = "RAGE", --Guardian
    [105] = "MANA", --Restoration
    --Evoker (primary power bar is Mana; Essence pips are a separate UI element)
    [1467] = "MANA", --Devastation
    [1468] = "MANA", --Preservation
    [1473] = "MANA", --Augmentation
    --Hunter
    [253] = "FOCUS", --Beast Mastery
    [254] = "FOCUS", --Marksmanship
    [255] = "FOCUS", --Survival
    --Mage
    [62] = "MANA", --Arcane
    [63] = "MANA", --Fire
    [64] = "MANA", --Frost
    --Monk
    [268] = "ENERGY", --Brewmaster
    [269] = "ENERGY", --Windwalker
    [270] = "MANA", --Mistweaver
    --Paladin
    [65] = "MANA", --Holy
    [66] = "MANA", --Protection
    [70] = "MANA", --Retribution
    --Priest
    [256] = "MANA", --Discipline
    [257] = "MANA", --Holy
    [258] = "INSANITY", --Shadow
    --Rogue
    [259] = "ENERGY", --Assassination
    [260] = "ENERGY", --Outlaw
    [261] = "ENERGY", --Subtlety
    --Shaman,
    [262] = "MAELSTROM", --Elemental
    [263] = "MAELSTROM", --Enhancement
    [264] = "MANA", --Restoration
    --Warlock
    [265] = "MANA", --Affliction
    [266] = "MANA", --Demonology
    [267] = "MANA", --Destruction
    --Warrior
    [71] = "RAGE", --Arms
    [72] = "RAGE", --Fury
    [73] = "RAGE", --Protection
  }

  local ClassRessources = { --used for TBCC
    WARRIOR = "RAGE",
    PALADIN = "MANA",
    HUNTER = "MANA",
    ROGUE = "ENERGY",
    PRIEST = "MANA",
    SHAMAN = "MANA",
    MAGE = "MANA",
    WARLOCK = "MANA",
    DRUID = "MANA",
    MONK = "ENERGY",
    DEATHKNIGHT = "RUNIC_POWER",
    DEMONHUNTER = "FURY",
    EVOKER = "MANA",
  }

  for classID = 1, GetNumClasses() do --example classes[EnglishClass][SpecName].
    local _, classToken = GetClassInfo(classID)
    if classToken then
      Data.Classes[classToken] = { Ressource = ClassRessources[classToken] } -- for Classic, TBCC Wrath, and any other expansions without specs and some brawls

      if GetNumSpecializationsForClassID and GetSpecializationInfoByID and GetSpecialization then --HasSpeccs
        for i = 1, GetNumSpecializationsForClassID(classID) do
          local specID, maleSpecName, _, icon, role = GetSpecializationInfoForClassID(classID, i, 2) -- male version

          Data.Classes[classToken][maleSpecName] =
            { roleID = role, specID = specID, specIcon = icon, Ressource = specIdToRessource[specID] }
          table.insert(Data.RolesToSpec[role], { classToken = classToken, specName = maleSpecName }) --for testmode

          --if specName == "Танцующий с ветром" then specName = "Танцующая с ветром" end -- fix for russian bug, fix added on 2017.08.27
          local _, specName = GetSpecializationInfoForClassID(classID, i, 3) -- female version
          if not Data.Classes[classToken][specName] then --there is a female version of that specName
            Data.Classes[classToken][specName] = Data.Classes[classToken][maleSpecName]
          end
        end
      else
        table.insert(Data.ClassList, classToken)
      end
    end
  end
end
