local _, SELFAQ = ...

local merge = SELFAQ.merge
local initSV = SELFAQ.initSV
local L = SELFAQ.L

-- 配置 --

SELFAQ.version = "1.0.1"

SELFAQ.enableDebug = false

-- 获取当前角色名字
SELFAQ.player = UnitName("player")

-- 操作的装备栏
SELFAQ.slots = {}
SELFAQ.slotFrames = {}


SELFAQ.slotToName = {
	[1] = L["Head"],
	[2] = L["Neck"],
	[3] = L["Shoulder"],
	[5] = L["Chest"],
	[6] = L["Waist"],
	[7] = L["Legs"],
	[8] = L["Feet"],
	[9] = L["Wrist"],
	[10] = L["Hands"],
	[11] = L["Finger "]..1,
	[12] = L["Finger "]..2,
	[13] = L["Trinket "]..1,
	[14] = L["Trinket "]..2,
	[15] = L["Back"],
	[16] = L["MainHand"],
	[17] = L["OffHand"],
	[18] = L["Ranged"],
}

SELFAQ.slotName = {
	[1] = "HeadSlot",
	[2] = "NeckSlot",
	[3] = "ShoulderSlot",
	[15] = "BackSlot",
	[5] = "ChestSlot",
	[9] = "WristSlot",
	[10] = "HandsSlot",
	[6] = "WaistSlot",
	[7] = "LegsSlot",
	[8] = "FeetSlot",
	[11] = "Finger0Slot",
	[12] = "Finger1Slot",
	[13] = "Trinket0Slot",
	[14] = "Trinket1Slot",
	[16] = "MainHandSlot",
	[17] = "SecondaryHandSlot",
	[18] = "RangedSlot",
}

SELFAQ.gearSlots = {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18}
