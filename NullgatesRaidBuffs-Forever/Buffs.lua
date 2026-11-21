-- Nullgate's Raid Buffs: the buff rules. Which columns to show, how a cell looks, which rank a
-- player can receive and who to buff next. No game calls except through Buffs.IsKnown.
local _, ns = ...

local Buffs = {}
ns.Buffs = Buffs

function Buffs.IsKnown(spellID)
    local known = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown or IsPlayerSpell
    return known ~= nil and known(spellID) == true
end

-- The families whose casting class is in the group (classes: a set of class tokens), in data order.
function Buffs.Columns(classes)
    local list = {}
    for _, family in ipairs(ns.BUFF_FAMILIES) do
        if classes[family.class] then list[#list + 1] = family end
    end
    return list
end

-- When a buff counts as running low: 5 minutes for buffs of half an hour or more, a minute for
-- buffs of ten minutes or more, 30 seconds for shorter ones.
function Buffs.LowAt(duration)
    if duration >= 1800 then return 300 end
    if duration >= 600 then return 60 end
    return 30
end

-- "ok", "low" or "missing" for a buff with `remaining` seconds of `duration` (nil = not there).
-- A buff with no end time (duration 0) is "ok".
function Buffs.Cell(remaining, duration)
    if not remaining then return "missing" end
    if duration and duration > 0 and remaining < Buffs.LowAt(duration) then return "low" end
    return "ok"
end

-- The highest rank you know that a target of `level` can receive (a rank can go on targets down
-- to 10 levels below the level it's learned at). ranks: { { spell, level, duration }, ... }.
function Buffs.RankFor(ranks, level)
    local best
    for _, rank in ipairs(ranks or {}) do
        if Buffs.IsKnown(rank[1]) and rank[2] <= level + 10 then best = rank end
    end
    return best
end

-- The highest rank known regardless of target.
function Buffs.TopRank(ranks)
    local best
    for _, rank in ipairs(ranks or {}) do
        if Buffs.IsKnown(rank[1]) then best = rank end
    end
    return best
end

-- Who to buff next with a family. members: { unit, group, level, reachable, state = "ok"|"low"|"missing" }.
-- Uses the group spell when `groupAt` or more members of one group need it, the group spell is known
-- and you carry its reagent; otherwise the single spell on the first member who needs it.
-- Returns { unit =, spell =, group = true|nil, count = members it covers } or nil.
function Buffs.Next(family, members, reagents, groupAt)
    local needing, byGroup = {}, {}
    for _, m in ipairs(members) do
        if m.reachable and m.state ~= "ok" then
            needing[#needing + 1] = m
            byGroup[m.group] = byGroup[m.group] or {}
            table.insert(byGroup[m.group], m)
        end
    end
    if #needing == 0 then return nil end
    local groupRank = Buffs.TopRank(family.group)
    if groupRank and (family.reagent == 0 or reagents > 0) then
        local bestGroup, bestList
        for group, list in pairs(byGroup) do
            if #list >= groupAt and (not bestList or #list > #bestList or (#list == #bestList and group < bestGroup)) then
                bestGroup, bestList = group, list
            end
        end
        if bestList then
            local lowest = bestList[1].level
            for _, m in ipairs(bestList) do lowest = math.min(lowest, m.level) end
            local rank = Buffs.RankFor(family.group, lowest)
            if rank then return { unit = bestList[1].unit, spell = rank[1], group = true, count = #bestList } end
        end
    end
    for _, m in ipairs(needing) do
        local rank = Buffs.RankFor(family.single, m.level)
        if rank then return { unit = m.unit, spell = rank[1], count = 1 } end
    end
end

-- The families the player can cast (for the buff button), in data order.
function Buffs.Mine(class)
    local list = {}
    for _, family in ipairs(ns.BUFF_FAMILIES) do
        if family.class == class and Buffs.TopRank(family.single) then list[#list + 1] = family end
    end
    return list
end
