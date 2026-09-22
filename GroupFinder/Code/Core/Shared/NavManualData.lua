-- GroupFinder manually maintained navigation placement overrides.
--
-- This table is intentionally small and hand-edited. Runtime C_LFGList
-- enumeration normally decides whether an activity exists; records here only
-- override expansion placement, visible label, and sort order for runtime
-- entries that Blizzard/DB2 data places incorrectly after a game update.
-- Explicit LEGACY_*_FALLBACKS are the only exceptions and must revalidate the
-- current client info against their narrow category/group/map/Journal contract.
--
-- Maintenance fields:
--   expansionIndex: target expansion bucket from GetExpansionName(index)
--   groupID: LFG activity group ID for normal dungeon/raid instances
--   activityID: LFG activity ID for solo activities such as world bosses
--   mapID: optional exact game-map identity for runtime replacement records
--   label: optional visible override for solo activity rows
--   orderIndex: optional sort key inside the expansion; high values place
--               LFG-only solo activities after Encounter Journal instances
--
-- NAV_CATALOG_SUPPLEMENT is a separate, post-Encounter-Journal fallback.
-- It carries additive placement metadata for a newer client without giving
-- those records the higher priority of an explicit manual override. Ordinary
-- archive groups still require a current EntryCreation-style activity query;
-- version-gated seed data contributes group candidates, never authorization.

local _, GF = ...

GF.NAV_MANUAL_CATALOG = {
	raid = {
		expansions = {},
	},
	dungeon = {
		expansions = {},
	},
}

-- Retail 12.1 exposes Val and Naigtal's normal/Heroic quest activities as
-- four flat entries inside the Midnight quest group. These stable IDs only
-- rearrange leaves already returned by the live C_LFGList query; they never
-- authorize an unavailable activity. Parent labels are derived from the
-- current client's localized activity names in NavData.
GF.NAV_QUEST_MANUAL_ACTIVITY_FAMILIES = {
	[397] = {
		{ labelActivityID = 1964, activityIDs = { 1964, 1970 } }, -- Val
		{ labelActivityID = 1965, activityIDs = { 1965, 1974 } }, -- Naigtal
	},
}

-- Retail exposes these legacy dungeons as one generic premade activity while
-- the Encounter Journal presents multiple entrance-specific instances. Allow
-- the authorized activity to match every corresponding Journal row, then let
-- NavCatalog collapse those matches into one runtime-named parent. The activity
-- is still required to come from the live C_LFGList availability query.
GF.NAV_CATALOG_REUSABLE_JOURNAL_ACTIVITIES = {
	dungeon = {
		[65] = true, -- Dire Maul
		[66] = true, -- Stratholme
	},
	raid = {},
}

-- The Encounter Journal lists these revamped Classic dungeons in both their
-- later expansion tier and Classic, while the premade Group Finder exposes one
-- shared activity group. Once that group has been authorized by the current
-- client, allow the exact Journal map/name duplicate to reuse it instead of
-- turning the second projection into a false unavailable row.
GF.NAV_CATALOG_REUSABLE_JOURNAL_GROUPS = {
	dungeon = {
		[5] = true,  -- The Deadmines
		[18] = true, -- Shadowfang Keep
		[19] = true, -- Scarlet Halls
		[30] = true, -- Scarlet Monastery
		[31] = true, -- Scholomance
	},
	raid = {},
}

-- These archived dungeon groups can be omitted from every availability query
-- made while GroupFinder builds its archive. Use their stable legacy activity
-- IDs only after all live sources are empty, and only when the current client's
-- GetActivityInfoTable() still validates the exact dungeon category/group.
-- The Classic Blackfathom/Blackrock instances are separate group-less
-- activities in NAV_CATALOG and must never reuse current Draenor groups 6/7/8.
GF.NAV_CATALOG_LEGACY_GROUP_ACTIVITY_FALLBACKS = {
	dungeon = {
		[5] = { 18, 148 },
		[18] = { 51, 168, 1339, 1340 },
		[19] = { 53, 149 },
		[30] = { 77, 170, 1335, 1336 },
		[31] = { 78, 169, 1337, 1338 },
	},
	raid = {},
}

-- Retail can retire every legacy activity ID above while Blizzard's native
-- EntryCreation Activity Finder still discovers the current activity after a
-- localized text query. Only these explicitly verified Classic identities may
-- use that fourth-argument path. The returned current activity may be grouped
-- differently or group-less, but must still match the exact dungeon category,
-- localized base name, and game map before it is authorized.
GF.NAV_CATALOG_LEGACY_GROUP_SEARCH_FALLBACKS = {
	dungeon = {},
	raid = {},
}

-- Retail's native Activity Finder can select and publish Blackwing Lair even
-- when an archive-building candidate stage drops it. Keep this exception
-- narrower than the ordinary solo candidate table: the final Journal boundary
-- must re-confirm the current ID through availability, and its current info must
-- still be a group-less raid whose localized base name matches the Encounter
-- Journal instance on the exact legacy map.
GF.NAV_CATALOG_LEGACY_SOLO_ACTIVITY_FALLBACKS = {
	dungeon = {},
	raid = {
		[293] = { mapID = 469 }, -- Blackwing Lair
	},
}

-- Encounter Journal exposes the regional world-boss collections as raid
-- instances. Several of those instances intentionally share MapID with the
-- first real raid of the expansion (Pandaria/Terrace, Draenor/Highmaul,
-- Broken Isles/Emerald Nightmare, Azeroth/Uldir), so map matching cannot
-- identify their entity type. JournalInstance IDs are the stable structural
-- boundary; activity IDs only supply the live LFG range and localized
-- "World Bosses" label. Static IDs never authorize an unavailable activity.
GF.NAV_CATALOG_WORLD_BOSS_CONTAINERS = {
	raid = {
		{ expansionIndex = 4, journalInstanceID = 322, activityIDs = { 397 } },
		{ expansionIndex = 5, journalInstanceID = 557, activityIDs = { 398 } },
		{ expansionIndex = 6, journalInstanceID = 822, activityIDs = { 458, 1674 } },
		{ expansionIndex = 7, journalInstanceID = 1028, activityIDs = { 657 } },
		{ expansionIndex = 8, journalInstanceID = 1192, activityIDs = { 723 } },
		{ expansionIndex = 9, journalInstanceID = 1205, activityIDs = { 1146 } },
		{ expansionIndex = 10, journalInstanceID = 1278, activityIDs = { 1289 } },
		{ expansionIndex = 11, journalInstanceID = 1312, activityIDs = { 1735, 1968 } },
	},
}

local supportsMidnight121 = GF.Compat
	and GF.Compat.IsInterfaceAtLeast
	and GF.Compat.IsInterfaceAtLeast(GF.INTERFACE_MIDNIGHT_12_1_0 or 120100)

-- The generated table is enabled only for 12.1+ ordinary archives and supplies
-- candidate group keys. NavCatalog still requires current EntryCreation-style
-- GetAvailableActivities() authorization and strict category/group validation;
-- exact season catalogs do not read these candidates or archive exclusions.
GF.NAV_CATALOG_ACTIVITY_SEEDS = supportsMidnight121
	and GF.NAV_CATALOG_ACTIVITY_SEEDS_121 or {
	dungeon = {},
	raid = {},
}

GF.NAV_CATALOG_ARCHIVE_EXCLUDED_GROUPS = supportsMidnight121
	and GF.NAV_CATALOG_ARCHIVE_EXCLUDED_GROUPS_121 or {
	dungeon = {},
	raid = {},
}

GF.NAV_CATALOG_SUPPLEMENT = {
	raid = {
		expansions = supportsMidnight121 and {
			{
				expansionIndex = 11,
				instances = {
					{ groupID = 429, orderIndex = 5, season = true },
					{ groupID = 424, orderIndex = 6, season = true },
				},
			},
		} or {},
	},
	dungeon = {
		expansions = supportsMidnight121 and {
			{
				expansionIndex = 11,
				instances = {
					{ groupID = 420, orderIndex = 9 },
				},
			},
		} or {},
	},
}

return GF.NAV_MANUAL_CATALOG
