-- Nullgate's Raid Buffs: reading the group and its buffs.
local _, ns = ...

local Scan = {}
ns.Scan = Scan

function Scan.SpellName(spellID)
    if not spellID or spellID == 0 then return nil end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return GetSpellInfo and (GetSpellInfo(spellID)) or nil
end

-- Every helpful aura on a unit: [name] = { remaining (nil for no end), duration }.
function Scan.Auras(unit, now)
    local auras = {}
    for i = 1, 40 do
        local name, duration, expires
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not a then break end
            name, duration, expires = a.name, a.duration, a.expirationTime
        else
            local n, _, _, _, d, e = UnitBuff(unit, i)
            if not n then break end
            name, duration, expires = n, d, e
        end
        if name then
            local remaining = (expires and expires > 0) and (expires - now) or math.huge
            local old = auras[name]
            if not old or remaining > old.remaining then auras[name] = { remaining = remaining, duration = duration or 0 } end
        end
    end
    return auras
end

-- The group: { unit, name, class, level, group, reachable } for you and every member.
function Scan.Members()
    local list = {}
    local function Add(unit, group)
        if not UnitExists(unit) then return end
        local _, class = UnitClass(unit)
        local reachable = UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)
        if reachable and not UnitIsUnit(unit, "player") then
            local inRange, checked = UnitInRange(unit)
            if checked and not inRange then reachable = false end
        end
        list[#list + 1] = { unit = unit, name = UnitName(unit), class = class, level = UnitLevel(unit), group = group,
                            reachable = reachable }
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local _, _, group = GetRaidRosterInfo(i)
            Add("raid" .. i, group or 1)
        end
    else
        Add("player", 1)
        for i = 1, GetNumSubgroupMembers() do Add("party" .. i, 1) end
    end
    table.sort(list, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

-- The localized names a family's buff shows under (single and group spells).
local familyNames = {}
function Scan.FamilyNames(family)
    if not familyNames[family.key] then
        familyNames[family.key] = { Scan.SpellName(family.single[1] and family.single[1][1]), Scan.SpellName(family.group[1] and family.group[1][1]) }
    end
    return familyNames[family.key]
end

-- A family's buff on a unit (from Scan.Auras): remaining, duration, or nil.
function Scan.Find(auras, names)
    local best
    for _, name in ipairs(names) do
        local a = name and auras[name]
        if a and (not best or a.remaining > best.remaining) then best = a end
    end
    if best then return best.remaining, best.duration end
end

local blessingNames, flaskNames
function Scan.HasBlessing(auras)
    if not blessingNames then
        blessingNames = {}
        for _, id in ipairs(ns.BLESSING_SPELLS) do blessingNames[#blessingNames + 1] = Scan.SpellName(id) end
    end
    return Scan.Find(auras, blessingNames)
end

function Scan.HasFlask(auras)
    if not flaskNames then
        flaskNames = {}
        for _, id in ipairs(ns.FLASK_SPELLS) do flaskNames[#flaskNames + 1] = Scan.SpellName(id) end
    end
    return Scan.Find(auras, flaskNames)
end

function Scan.HasWellFed(auras)
    return Scan.Find(auras, { Scan.SpellName(ns.WELL_FED_SPELL) })
end

function Scan.ItemCount(itemID)
    if not itemID or itemID == 0 then return 0 end
    local count = (C_Item and C_Item.GetItemCount) or GetItemCount
    return (count and count(itemID)) or 0
end
