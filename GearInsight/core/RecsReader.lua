-- RecsReader.lua
-- Reads the GearInsightRecsDB saved variable written by the Companion App
-- and exposes helpers that the panel uses to prefer live recommendations.

GearInsight = GearInsight or {}

local RecsReader = {}

-- Slot-name string → numeric slot ID used everywhere else in the addon
local SLOT_NAME_TO_ID = {
    HEAD      = 1,
    NECK      = 2,
    SHOULDER  = 3,
    CHEST     = 5,
    WAIST     = 6,
    LEGS      = 7,
    FEET      = 8,
    WRIST     = 9,
    HANDS     = 10,
    FINGER_1  = 11,
    FINGER1   = 11,
    FINGER_2  = 12,
    FINGER2   = 12,
    TRINKET_1 = 13,
    TRINKET1  = 13,
    TRINKET_2 = 14,
    TRINKET2  = 14,
    BACK      = 15,
    MAIN_HAND = 16,
    MAINHAND  = 16,
    OFF_HAND  = 17,
    OFFHAND   = 17,
}

-- Returns live recommendations table or nil if unavailable / stale.
-- Stale = timestamp older than 30 minutes (1800 seconds).
function RecsReader:GetRecs()
    if not GearInsightRecsDB then return nil end
    local age = time() - (GearInsightRecsDB.timestamp or 0)
    if age > 1800 then return nil end
    return GearInsightRecsDB
end

-- Returns true when fresh live recommendations are available.
function RecsReader:HasFreshRecs()
    return self:GetRecs() ~= nil
end

-- Returns the age of the live recs in seconds, or nil if unavailable.
function RecsReader:GetRecsAge()
    if not GearInsightRecsDB then return nil end
    return time() - (GearInsightRecsDB.timestamp or 0)
end

-- Converts the live recommendations list into the bisBySlot table format
-- expected by the panel (keyed by numeric slot ID).
-- Each slot entry is a single-element list so the existing loop works unchanged.
-- Entry shape: { itemId, itemName, ilvl, source, improvementPct }
function RecsReader:GetBisBySlot()
    local recs = self:GetRecs()
    if not recs or not recs.recommendations then return nil end

    local bisBySlot = {}
    for _, rec in ipairs(recs.recommendations) do
        local slotId = SLOT_NAME_TO_ID[rec.slot]
        if slotId then
            -- Build an entry compatible with BisData bisBySlot entries
            local entry = {
                itemId        = rec.suggestedItemId,
                itemName      = rec.itemName or ("Item#" .. tostring(rec.suggestedItemId)),
                ilvl          = rec.ilvl or 0,
                source        = rec.source or "",
                stats         = rec.stats or nil,
                improvementPct = rec.improvementPct,
                -- Mark origin so the panel can adjust tooltip copy
                _fromLiveRecs = true,
            }
            -- Use a list so downstream for-loop over cand works identically
            if not bisBySlot[slotId] then
                bisBySlot[slotId] = {}
            end
            table.insert(bisBySlot[slotId], entry)
        end
    end
    return bisBySlot
end

GearInsight.RecsReader = RecsReader

