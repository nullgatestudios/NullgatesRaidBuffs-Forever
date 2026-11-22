-- Nullgate's Raid Buffs: reading the group and its buffs.
local _, ns = ...

local Scan = {}
ns.Scan = Scan

function Scan.SpellName(spellID)
    if not spellID or spellID == 0 then return nil end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return GetSpellInfo and (GetSpellInfo(spellID)) or nil
end

-- Forever won't let addons read some auras (secret values, usually in combat): asking for one is an
-- error, and hidden fields can't be compared. Returns the aura, nil past the last one, or false when
-- the game is hiding it.
local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) == true end
local function ReadAura(unit, i)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local S = C_Secrets
        if S and S.ShouldUnitAuraIndexBeSecret and S.ShouldUnitAuraIndexBeSecret(unit, i, "HELPFUL") then return false end
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok then return false end
        if a and (IsSecret(a.name) or IsSecret(a.expirationTime) or IsSecret(a.duration) or IsSecret(a.sourceUnit)
            or IsSecret(a.spellId)) then return false end
        return a
    end
    local name, _, _, _, duration, expires, caster, _, _, spellId = UnitBuff(unit, i)
    if not name then return nil end
    return { name = name, duration = duration, expirationTime = expires, sourceUnit = caster, spellId = spellId }
end

-- The last full read of each unit, used while the game hides its auras.
local lastRead = {} -- [unit] = { name, at, auras }

local function LastRead(unit, now)
    local last, name, auras = lastRead[unit], UnitName(unit), {}
    if last and not IsSecret(name) and last.name == name then
        for buff, a in pairs(last.auras) do
            local remaining = a.remaining - (now - last.at)
            if remaining > 0 then auras[buff] = { remaining = remaining, duration = a.duration } end
        end
    end
    return auras
end

-- Every helpful aura on a unit: [name] = { remaining (math.huge for no end), duration }. While the
-- game hides the unit's auras, the last full read is used.
function Scan.Auras(unit, now)
    local auras = {}
    for i = 1, 40 do
        local a = ReadAura(unit, i)
        if a == nil then break end
        if a == false then return LastRead(unit, now) end
        local name, duration, expires = a.name, a.duration, a.expirationTime
        if name then
            local remaining = (expires and expires > 0) and (expires - now) or math.huge
            local old = auras[name]
            if not old or remaining > old.remaining then auras[name] = { remaining = remaining, duration = duration or 0 } end
        end
    end
    local name = UnitName(unit)
    lastRead[unit] = { name = not IsSecret(name) and name or nil, at = now, auras = auras }
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
            -- Forever can return the range as secret values, which can't be tested: then it's unknown.
            local inRange, checked = UnitInRange(unit)
            local secret = issecretvalue and (issecretvalue(inRange) or issecretvalue(checked))
            if not secret and checked and not inRange then reachable = false end
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
