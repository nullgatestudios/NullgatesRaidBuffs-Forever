-- Nullgate's Raid Buffs: /nbuffs check, the in-game self test (phase 0 of PLAN.md).
-- Every result goes to chat and to NullgatesRaidBuffsDB.check, so the log can be copied from
-- WTF\Account\<account>\<realm>\<character>\SavedVariables\NullgatesRaidBuffs-Forever.lua.
--
--   1. Which calls exist, the buff names the addon looks for, your buffs as the addon reads them
--      (name, time left, duration) and what each group member's range check says.
--   2. Your buff button's plan, and which ranks of your buffs you know.
local _, ns = ...

local Check = {}
ns.Check = Check

local LOG_LIMIT = 400

local function Log(text)
    local db = ns.db
    if db then
        db.check = db.check or {}
        if #db.check >= LOG_LIMIT then table.remove(db.check, 1) end
        db.check[#db.check + 1] = text
    end
    print("|cff00c0ffNullgate's Raid Buffs check:|r " .. text)
    if NullgateReport then NullgateReport.Update("raid-buffs") end
end
Check.Log = Log

-- Opens the report window every Nullgate addon shares (NullgateReport.lua) with this check's log,
-- ready to copy and paste into the report form on our website.
function Check.ShowReport()
    local L = ns.L
    return NullgateReport.Show({
        slug = "raid-buffs", name = "Nullgate's Raid Buffs", addon = "NullgatesRaidBuffs-Forever", command = "/nbuffs check",
        lines = function() return ns.db and ns.db.check end,
        title = L["Bug report"], selectAll = L["Select all"], selectLink = L["Select link"],
        help = L["Press Ctrl+C to copy this report, then paste it into a new report at the link below, with a few words on what happened."],
    })
end

local function Exists(path)
    local value = _G
    for part in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return false end
        value = value[part]
    end
    return type(value) == "function"
end

function Check.Run()
    if ns.db then ns.db.check = {} end
    local _, class = UnitClass("player")
    Log(string.format("client %s, build %s, interface %s; class %s, level %s; data build %s",
        tostring(GetBuildInfo and select(1, GetBuildInfo())), tostring(GetBuildInfo and select(2, GetBuildInfo())),
        tostring(GetBuildInfo and select(4, GetBuildInfo())), tostring(class), tostring(UnitLevel("player")),
        tostring(ns.BUFF_DATA_BUILD)))
    local calls = {}
    for _, name in ipairs({ "C_UnitAuras.GetAuraDataByIndex", "UnitBuff", "UnitInRange", "GetRaidRosterInfo", "C_Spell.GetSpellName",
        "C_SpellBook.IsSpellKnown", "SendChatMessage" }) do
        calls[#calls + 1] = name .. "=" .. (Exists(name) and "yes" or "no")
    end
    Log("calls: " .. table.concat(calls, " "))
    for _, family in ipairs(ns.BUFF_FAMILIES) do
        local names = ns.Scan.FamilyNames(family)
        Log(string.format("%s: looks for %s / %s (%ds)", family.key, tostring(names[1]), tostring(names[2]), family.single[#family.single][3]))
    end
    local auras = {}
    for name, a in pairs(ns.Scan.Auras("player", GetTime())) do
        auras[#auras + 1] = string.format("%s (%s of %ss)", name, a.remaining == math.huge and "no end" or string.format("%.0fs", a.remaining), tostring(a.duration))
    end
    Log("your buffs: " .. (#auras > 0 and table.concat(auras, "; ") or "none"))
    for _, m in ipairs(ns.Scan.Members()) do
        local inRange, checked = UnitInRange(m.unit)
        if issecretvalue and issecretvalue(inRange) then inRange = "secret" end
        if issecretvalue and issecretvalue(checked) then checked = "secret" end
        Log(string.format("member %s (%s, %s, level %s, group %s): UnitInRange %s/%s, reachable %s", m.unit, tostring(m.name),
            tostring(m.class), tostring(m.level), tostring(m.group), tostring(inRange), tostring(checked), tostring(m.reachable)))
    end
    local family = ns.Button.Family()
    if family then
        local known = {}
        for _, rank in ipairs(family.single) do known[#known + 1] = rank[1] .. "=" .. (ns.Buffs.IsKnown(rank[1]) and "known" or "no") end
        for _, rank in ipairs(family.group) do known[#known + 1] = rank[1] .. "=" .. (ns.Buffs.IsKnown(rank[1]) and "known" or "no") end
        local plan = ns.Button.Plan(family)
        Log(string.format("your buff %s: ranks %s; reagent %d carried; next: %s", family.key, table.concat(known, " "),
            ns.Scan.ItemCount(family.reagent), plan and string.format("%s on %s%s", plan.spell, plan.unit, plan.group and " (group)" or "") or "nobody"))
    else
        Log("you know none of the grid's buffs, so there's no buff button")
    end
    Check.ShowReport()
end
