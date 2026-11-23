-- Nullgate's Raid Buffs: tests for the buff data, cells, ranks and who to buff next.
-- Run from the repository root:  lua tests/run.lua   (Lua 5.1 or newer)

local source = debug.getinfo(1, "S").source or ""
local script = source:match("^@(.*)$") or "tests/run.lua"
local scriptDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local root = (scriptDir:match("^(.*)[/\\][^/\\]*$") or ".") .. "/NullgatesRaidBuffs-Forever/"

local ns = {}
local function Load(file) assert(loadfile(root .. file), "cannot load " .. file)("NullgatesRaidBuffs-Forever", ns) end
Load("Data/Buffs.lua")
Load("Buffs.lua")
local B = ns.Buffs

local checks, failures = 0, 0
local function EQ(got, want, name)
    checks = checks + 1
    if got ~= want then
        failures = failures + 1
        print(string.format("FAIL %s: expected %s, got %s", name, tostring(want), tostring(got)))
    end
end

local function Family(key) for _, f in ipairs(ns.BUFF_FAMILIES) do if f.key == key then return f end end end

-- --- The data: Forever durations ------------------------------------------------------
EQ(type(ns.BUFF_DATA_BUILD), "string", "the data names its client build")
EQ(Family("fortitude").single[#Family("fortitude").single][3], 3600, "Forever: Power Word: Fortitude lasts an hour")
EQ(Family("intellect").single[1][3], 3600, "Forever: Arcane Intellect lasts an hour")
EQ(Family("wild").single[1][3], 3600, "Forever: Mark of the Wild lasts an hour")
EQ(Family("shadow").single[1][3], 600, "Shadow Protection lasts 10 minutes")
EQ(Family("shadow").group[1][3], 1200, "Prayer of Shadow Protection lasts 20 minutes")
EQ(Family("fortitude").reagent, 17028, "Prayer of Fortitude uses Holy Candles")
EQ(#Family("thorns").group, 0, "Thorns has no group version")
EQ(#ns.BLESSING_SPELLS >= 6, true, "every blessing name for the blessing column (Forever 1.60.1.71037 removed Light and Salvation)")
EQ(ns.WELL_FED_SPELL > 0 and #ns.FLASK_SPELLS > 0, true, "consumable buffs")

-- --- Columns ----------------------------------------------------------------------------
local cols = B.Columns({ PRIEST = true, WARRIOR = true })
EQ(#cols, 3, "a priest in the group: Fortitude, Spirit and Shadow Protection columns")
EQ(#B.Columns({ WARRIOR = true, ROGUE = true }), 0, "no buffing classes: no columns")

-- --- Cells -------------------------------------------------------------------------------
EQ(B.Cell(nil, 3600), "missing", "no buff: missing")
EQ(B.Cell(1800, 3600), "ok", "half an hour left of an hour: fine")
EQ(B.Cell(240, 3600), "low", "4 minutes left of an hour: low")
EQ(B.Cell(240, 600), "ok", "4 minutes left of 10: fine")
EQ(B.Cell(50, 600), "low", "under a minute of 10: low")
EQ(B.Cell(math.huge, 0), "ok", "a buff with no end: fine")

-- --- Ranks ----------------------------------------------------------------------------------
local known = {}
B.IsKnown = function(id) return known[id] == true end
local fort = Family("fortitude")
for _, r in ipairs(fort.single) do known[r[1]] = true end
EQ(B.RankFor(fort.single, 60)[1], 10938, "a level 60 gets rank 6")
EQ(B.RankFor(fort.single, 30)[2], 36, "a level 30 can take the rank learned at 36 (up to 10 above)")
EQ(B.RankFor(fort.single, 5)[2], 12, "a level 5 gets the rank learned at 12")
EQ(B.TopRank(fort.group), nil, "Prayer of Fortitude not known yet")

-- --- Who next ---------------------------------------------------------------------------------
local function M(unit, group, state, reachable, level)
    return { unit = unit, group = group, level = level or 60, reachable = reachable ~= false, state = state }
end
local members = { M("raid1", 1, "ok"), M("raid2", 1, "missing"), M("raid3", 2, "missing", false), M("raid4", 2, "low") }
local plan = B.Next(fort, members, 0, 3)
EQ(plan.unit, "raid2", "the first reachable player who needs it")
EQ(plan.group, nil, "with the single spell")
EQ(B.Next(fort, { M("raid1", 1, "ok"), M("raid3", 2, "missing", false) }, 0, 3), nil, "nobody reachable needs it: nothing")

for _, r in ipairs(fort.group) do known[r[1]] = true end
members = { M("raid1", 1, "missing"), M("raid2", 1, "missing"), M("raid3", 1, "low"), M("raid4", 2, "missing") }
plan = B.Next(fort, members, 10, 3)
EQ(plan.group and plan.count == 3 and plan.spell == fort.group[2][1], true, "three in group 1 need it: Prayer of Fortitude")
plan = B.Next(fort, members, 0, 3)
EQ(plan.group, nil, "no candles: the single spell instead")
plan = B.Next(fort, members, 10, 4)
EQ(plan.group, nil, "fewer than the setting: the single spell")
members[1].level, members[2].level = 40, 60
plan = B.Next(fort, members, 10, 3)
EQ(plan.spell, fort.group[1][1], "a level 40 in the group: the group rank they can take")

local thorns = Family("thorns")
for _, r in ipairs(thorns.single) do known[r[1]] = true end
plan = B.Next(thorns, { M("party1", 1, "missing"), M("party2", 1, "missing"), M("player", 1, "missing") }, 0, 3)
EQ(plan.group, nil, "Thorns has no group spell: single")

EQ(#B.Mine("PRIEST"), 1, "a priest who knows only Fortitude has one buff for the button")

print(string.format("%d checks, %d failure(s)", checks, failures))
if failures > 0 then os.exit(1) end
